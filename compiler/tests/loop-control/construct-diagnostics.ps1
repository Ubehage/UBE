# Rejection locations follow the offending target/name token or unmatched delimiter.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=[Text.UTF8Encoding]::new($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube construct diagnostics '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $evidence
Write-Output "Evidence: $evidence"
$report=New-Object Collections.Generic.List[string]
function Record([string]$Text){$report.Add($Text);Write-Output $Text;[IO.File]::WriteAllLines((Join-Path $evidence 'report.txt'),$report,$utf)}
function Run([string[]]$Arguments,[string]$Name){
 $out=Join-Path $evidence ($Name+'.stdout');$err=Join-Path $evidence ($Name+'.stderr')
 $quoted=($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' '
 $p=Start-Process -FilePath $CompilerExe -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
 try{$null=$p.Handle;if(-not $p.WaitForExit(30000)){$p.Kill();throw "Deadline: $Name"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing exit code: $Name"};return [pscustomobject]@{Code=$p.ExitCode;Log=([IO.File]::ReadAllText($out,$utf)+[IO.File]::ReadAllText($err,$utf))}}finally{$p.Dispose()}
}
function Project([string]$Name,[string]$Body){
 $source="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`nPublic Function Main() As Long`r`n"+$Body+"`r`nEnd Function`r`n"
 [IO.File]::WriteAllText((Join-Path $evidence ($Name+'.bas')),$source,$utf)
 $manifest=Join-Path $evidence ($Name+'.UBE')
 [IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nSource = `"$Name.bas`"`r`n",$utf)
 return $manifest
}
$newline="`r`n"
$counter=@('Dim Values(0 To 1) As Long','Dim Item As Long','For Each Item In Values','Next Item') -join $newline
$next=@('Dim Values(0 To 1) As Long','Dim Item As Variant','Dim Other As Variant','For Each Item In Values','Next Other') -join $newline
$crossing=@('Dim Values(0 To 1) As Long','Dim Outer As Variant','Dim Inner As Variant','Dim Guard As Object','For Each Outer In Values','SyncLock Guard','For Each Inner In Values','Next Inner,Outer','End SyncLock','Next Outer') -join $newline
$delimiter=@('Dim Guard As Object','SyncLock Guard','End If') -join $newline
$exit=@('Dim Guard As Object','SyncLock Guard','Exit Loop','End SyncLock') -join $newline
$target=@('Dim Guard As Long','SyncLock Guard','End SyncLock') -join $newline
$afterEach=@('Dim Values(0 To 1) As Long','Dim Item As Variant','Dim Guard As Object','SyncLock Guard','For Each Item In Values','Next Item','Exit Loop','End SyncLock') -join $newline
$cases=@(
 @{Name='scalar-counter';Body=$counter;Valid=$counter.Replace('Item As Long','Item As Variant');Location='6:10';Category='E_COMPILE'},
 @{Name='next-mismatch';Body=$next;Valid=$next.Replace('Next Other','Next Item');Location='8:6';Category='E_COMPILE'},
 @{Name='next-crosses-lock';Body=$crossing;Valid=$crossing.Replace('Next Inner,Outer','Next Inner');Location='11:11';Category='E_LOAD'},
 @{Name='wrong-lock-delimiter';Body=$delimiter;Valid=$delimiter.Replace('End If','End SyncLock');Location='6:5';Category='E_LOAD'},
 @{Name='exit-without-loop';Body=$exit;Valid=$exit.Replace('Exit Loop','Main = 0');Location='6:6';Category='E_LOAD'},
 @{Name='scalar-lock-target';Body=$target;Valid=$target.Replace('Guard As Long','Guard As Object');Location='5:10';Category='E_COMPILE'},
 @{Name='exit-after-each';Body=$afterEach;Valid=$afterEach.Replace('Exit Loop','Main = 0');Location='10:6';Category='E_LOAD'}
)
$recovery=Project 'recovery' (@('Dim Values(0 To 1) As Long','Dim Item As Variant','Dim Guard As Object','For Each Item In Values','SyncLock Guard','Exit Loop','End SyncLock','Next Item') -join $newline)
$reference=Join-Path $evidence 'reference.ll'
$result=Run @('--emit-llvm',$recovery,$reference) 'reference'
if($result.Code -ne 0 -or $result.Log -notmatch 'EMIT OK'){throw "Recovery fixture failed: $($result.Log)"}
$hash=(Get-FileHash -LiteralPath $reference -Algorithm SHA256).Hash
foreach($case in $cases){
 $manifest=Project $case.Name $case.Body
 foreach($mode in @('--emit-llvm','--build')){
  $suffix='ll';if($mode -eq '--build'){$suffix='exe'}
  $output=Join-Path $evidence ($case.Name+'.'+$suffix)
  [IO.File]::WriteAllText($output,'PRESERVE',$utf)
  $arguments=@($mode,$manifest,$output);if($mode -eq '--build'){$arguments+=@('--clang',$Clang)}
  $result=Run $arguments ($case.Name+$mode)
  if($result.Code -ne 1 -or -not $result.Log.Contains($case.Category) -or -not $result.Log.Contains($case.Name+'.bas:'+$case.Location) -or [IO.File]::ReadAllText($output,$utf) -cne 'PRESERVE'){throw "Expected located rejection and unchanged output: $($case.Name) $mode $($result.Log)"}
 }
 # A single correction must admit the matching construct, excluding unrelated rejection causes.
 $control=Project ($case.Name+'-valid') $case.Valid
 $result=Run @('--emit-llvm',$control,(Join-Path $evidence ($case.Name+'-valid.ll'))) ($case.Name+'-valid')
 if($result.Code -ne 0 -or $result.Log -notmatch 'EMIT OK'){throw "Corrected control failed: $($case.Name) $($result.Log)"}
 $after=Join-Path $evidence ($case.Name+'-recovery.ll')
 $result=Run @('--emit-llvm',$recovery,$after) ($case.Name+'-recovery')
 if($result.Code -ne 0 -or (Get-FileHash -LiteralPath $after -Algorithm SHA256).Hash -cne $hash){throw "Recovery changed: $($case.Name) $($result.Log)"}
 if(@(Get-ChildItem -LiteralPath $evidence -Force -Filter '*.ube-*').Count){throw "Leaked publication stage: $($case.Name)"}
 Record "PASS $($case.Name): emit/build rejection at $($case.Location), preserved outputs, corrected control and deterministic recovery"
}
Record 'PASS 7 construct diagnostic cases; runtime locking and enumeration semantics are checked separately.'
