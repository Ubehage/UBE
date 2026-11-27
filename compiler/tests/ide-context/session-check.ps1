param([string]$CompilerExe='', [string]$Clang='C:\Program Files\LLVM\bin\clang.exe', [switch]$HostOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=[Text.UTF8Encoding]::new($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube ide session '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$results=New-Object Collections.Generic.List[object]
Write-Output "Evidence: $evidence"
$hostExe=Join-Path $evidence 'SessionHost.exe'
$compilerParameters=New-Object CodeDom.Compiler.CompilerParameters
$compilerParameters.CompilerOptions='/platform:x64'
$compilerParameters.OutputAssembly=$hostExe
$compilerParameters.GenerateExecutable=$true
$compilerParameters.GenerateInMemory=$false
$null=$compilerParameters.ReferencedAssemblies.Add('System.dll')
Add-Type -Path (Join-Path $PSScriptRoot 'SessionHost.cs') -CompilerParameters $compilerParameters
$diagnostic="UBE: E_IDE_CONTEXT: this IDE-run executable requires a live UBE IDE session; rebuild for standalone execution.`r`n"
function Require([bool]$Condition,[string]$Message) { if(-not $Condition){throw $Message} }
function Start-TestProcess([string]$File,[string[]]$Arguments,[string]$Name) {
 $options=@{FilePath=$File;PassThru=$true;WindowStyle='Hidden';RedirectStandardOutput=(Join-Path $evidence ($Name+'.stdout'));RedirectStandardError=(Join-Path $evidence ($Name+'.stderr'))}
 if($Arguments.Count){$options.ArgumentList=($Arguments | ForEach-Object {'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 $null=$p.Handle
 return $p
}
function Finish-TestProcess($Process,[string]$Name,[int]$Milliseconds=120000) {
 if(-not $Process.WaitForExit($Milliseconds)){$Process.Kill();$null=$Process.WaitForExit(5000);throw "Deadline: $Name"}
 $Process.Refresh();Require ($null -ne $Process.ExitCode) "Missing exit code: $Name"
 return [pscustomobject]@{Code=$Process.ExitCode;Out=[IO.File]::ReadAllText((Join-Path $evidence ($Name+'.stdout')),$utf);Error=[IO.File]::ReadAllText((Join-Path $evidence ($Name+'.stderr')),$utf)}
}
function Run([string]$File,[string[]]$Arguments,[string]$Name) {
 $p=Start-TestProcess $File $Arguments $Name
 try{return Finish-TestProcess $p $Name}finally{$p.Dispose()}
}
function Host([string]$Target,[string]$Mode,[string]$Lifetime,[string]$Name) {
 $childOut=Join-Path $evidence ($Name+'.child.stdout');$childErr=Join-Path $evidence ($Name+'.child.stderr');$ready=Join-Path $evidence ($Name+'.ready')
 $run=Run $hostExe @($Target,$Mode,$Lifetime,$childOut,$childErr,$ready) $Name
 Require ($run.Code -eq 0 -and $run.Error -eq '') "Host failed: $Name $($run.Code) $($run.Error)"
 if($Mode -eq 'collision') {Require ($run.Out -ceq "COLLISION_REJECTED`r`n") 'Collision was not refused';return}
 $expectedStatus=''
 if($Lifetime -eq 'suspend-close'){$expectedStatus="STATUS=IDE session ended before resume; child terminated without running source.`r`n"}
 Require ($run.Out -cmatch ('\ACHILD=([0-9]+)\r\nMEMBER=1\r\nJOB_INHERIT=0\r\n'+[regex]::Escape($expectedStatus)+'EXIT=([0-9]+)\r\n\z')) "Unexpected host report: $Name $($run.Out)"
 return [pscustomobject]@{Code=[uint32]$Matches[2];Out=[IO.File]::ReadAllText($childOut,$utf);Error=[IO.File]::ReadAllText($childErr,$utf)}
}
function Record([string]$Name) {$results.Add([pscustomobject]@{Name=$Name;Pass=$true});Write-Output "PASS $Name"}
function Assert-Marker([string]$Path,[bool]$Present) {
 Require ((Test-Path -LiteralPath $Path) -eq $Present) "Initializer sentinel presence differs: $Path"
 if($Present){$bytes=[IO.File]::ReadAllBytes($Path);Require ($bytes.Length -eq 1 -and $bytes[0] -eq 42) 'Initializer sentinel bytes differ'}
}
function Clear-Marker([string]$Path) {if(Test-Path -LiteralPath $Path){Remove-Item -LiteralPath $Path}}
function Resume-Source([string]$Target,[string]$Marker,[string]$Name) {
 $childOut=Join-Path $evidence ($Name+'.child.stdout');$childErr=Join-Path $evidence ($Name+'.child.stderr');$ready=Join-Path $evidence ($Name+'.ready')
 $owner=Start-TestProcess $hostExe @($Target,'valid','debug',$childOut,$childErr,$ready) $Name
 $child=$null
 try {
  $deadline=[DateTime]::UtcNow.AddSeconds(30)
  while(-not (Test-Path -LiteralPath $ready)){if($owner.HasExited -or [DateTime]::UtcNow -ge $deadline){throw 'Debug readiness deadline'};Start-Sleep -Milliseconds 10}
  $child=[Diagnostics.Process]::GetProcessById([int][IO.File]::ReadAllText($ready,$utf));$null=$child.Handle
  Require (-not $child.HasExited) 'Paused child is not alive';Assert-Marker $Marker $false
  [IO.File]::WriteAllText(($ready+'.resume'),'resume',$utf)
  $run=Finish-TestProcess $owner $Name
  Require ($run.Code -eq 0 -and $run.Error -eq '' -and $run.Out -cmatch '\ACHILD=[0-9]+\r\nMEMBER=1\r\nJOB_INHERIT=0\r\nSTATUS=DEBUG_RESUMED\r\nEXIT=0\r\n\z') 'Resumed source did not succeed under its retained session'
  Require ([IO.File]::ReadAllText($childOut,$utf) -eq '' -and [IO.File]::ReadAllText($childErr,$utf) -eq '') 'Resumed source emitted unexpected output'
  Assert-Marker $Marker $true;Clear-Marker $Marker;Record $Name
 } finally {
  if(-not $owner.HasExited){$owner.Kill();$null=$owner.WaitForExit(5000)};$owner.Dispose()
  if($null -ne $child){if(-not $child.HasExited){$child.Kill();$null=$child.WaitForExit(5000)};$child.Dispose()}
 }
}
function Kill-Owner([string]$Target,[string]$Lifetime,[string]$Marker,[string]$Name) {
 $childOut=Join-Path $evidence ($Name+'.child.stdout');$childErr=Join-Path $evidence ($Name+'.child.stderr');$ready=Join-Path $evidence ($Name+'.ready')
 $owner=Start-TestProcess $hostExe @($Target,'valid',$Lifetime,$childOut,$childErr,$ready) $Name
 $child=$null
 try {
  $deadline=[DateTime]::UtcNow.AddSeconds(30)
  while(-not (Test-Path -LiteralPath $ready)) {if($owner.HasExited -or [DateTime]::UtcNow -ge $deadline){throw "Owner readiness failed: $Name"};Start-Sleep -Milliseconds 10}
  $pidText=[IO.File]::ReadAllText($ready,$utf)
  $child=[Diagnostics.Process]::GetProcessById([int]$pidText);$null=$child.Handle
  if($Lifetime -eq 'running') {
   while(-not (Test-Path -LiteralPath $Marker)) {if($child.HasExited -or [DateTime]::UtcNow -ge $deadline){throw "Source initializer readiness failed: $Name"};Start-Sleep -Milliseconds 10}
   # Creation can precede the write; wait for its exact ready byte, not elapsed time.
   do {try{$readyBytes=[IO.File]::ReadAllBytes($Marker);if($readyBytes.Length -eq 1){break}}catch [IO.IOException]{};if([DateTime]::UtcNow -ge $deadline){throw 'Initializer write deadline'};Start-Sleep -Milliseconds 10}while($true)
   Assert-Marker $Marker $true
  } else {Assert-Marker $Marker $false}
  Require (-not $child.HasExited) "Child not alive before owner termination: $Name"
  $owner.Kill();Require ($owner.WaitForExit(5000)) 'Owner did not terminate'
  Require ($child.WaitForExit(5000)) "Job child survived host exit: $Name"
  $child.Refresh();Require ($null -ne $child.ExitCode) 'Missing terminated child status'
  Require ([IO.File]::ReadAllText($childOut,$utf) -eq '' -and [IO.File]::ReadAllText($childErr,$utf) -eq '') "Unexpected source output: $Name"
  Assert-Marker $Marker ($Lifetime -eq 'running')
  Record $Name
 } finally {
  if(-not $owner.HasExited){$owner.Kill();$null=$owner.WaitForExit(5000)}
  $owner.Dispose()
  if($null -ne $child){if(-not $child.HasExited){$child.Kill();$null=$child.WaitForExit(5000)};$child.Dispose()}
 }
}
$success=$false
try {
 # Qualifies the fixture independently of compiler/runtime implementation.
 $smoke=Join-Path $evidence 'HostChild.exe'
 $smokeParameters=New-Object CodeDom.Compiler.CompilerParameters
 $smokeParameters.CompilerOptions='/platform:x64'
 $smokeParameters.OutputAssembly=$smoke
 $smokeParameters.GenerateExecutable=$true
 $smokeParameters.GenerateInMemory=$false
 Add-Type -TypeDefinition 'public static class HostChild { public static int Main() { return 42; } }' -CompilerParameters $smokeParameters
 $run=Host $smoke 'valid' 'normal' 'host-smoke'
 Require ($run.Code -eq 42 -and $run.Out -eq '' -and $run.Error -eq '') 'Host smoke did not retain exact child result'
 Record 'host-smoke'
 Host $smoke 'collision' 'normal' 'host-collision';Record 'host-collision'
 $unused=Join-Path $evidence 'host-unused.marker'
 Kill-Owner $smoke 'paused' $unused 'host-paused-death'
 if($HostOnly){$success=$true;return}
 Require (-not [string]::IsNullOrWhiteSpace($CompilerExe)) 'CompilerExe required for source acceptance'
 $template=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'session-probe.bas'),$utf)
 foreach($level in @('0','2')) {
  $binaries=@{};$markers=@{}
  foreach($kind in @('standalone','hosted','wrong-value','escaping-failure','running')) {
   $name="o$level-$kind";$marker=Join-Path $evidence ($name+'.marker');$markers[$kind]=$marker
   $pathBytes=$utf.GetBytes($marker);$pathLines=@("Dim Path(0 To $($pathBytes.Length-1)) As Byte");$pathHelpers=@()
   for($start=0;$start -lt $pathBytes.Length;$start+=24){
    $helper='FillPath'+$start;$pathLines+="Call $helper(Path)"
    $pathHelpers+="Private Sub $helper(ByRef Path() As Byte)";$pathHelpers+='On Error GoTo Failed'
    for($index=$start;$index -lt [Math]::Min($start+24,$pathBytes.Length);$index++){$pathHelpers+="Path($index) = $($pathBytes[$index])"}
    $pathHelpers+=@('Exit Sub','Failed:','Err.Raise Err.Number','End Sub')
   }
   $source=$template.Replace("' SENTINEL PATH",($pathLines -join "`r`n"))
   $source=$source.Replace('Private Function InitializeSource() As Long',(($pathHelpers -join "`r`n")+"`r`nPrivate Function InitializeSource() As Long"))
   $hosted=$kind -ne 'standalone';$expectedContext='False';$expectedBranch='0';$mode='--build'
   if($hosted){$expectedContext='True';$expectedBranch='1';$mode='--build-ide'}
   $source=$source.Replace('EXPECTED_CONTEXT',$expectedContext).Replace('EXPECTED_BRANCH',$expectedBranch)
   if($kind -eq 'wrong-value'){$source=$source.Replace('Initialized <> 42','Initialized <> 43')}
   if($kind -eq 'escaping-failure'){$source=$source.Replace("' HELPER BODY",'Err.Raise 5')}
   if($kind -eq 'running'){$source=$source.Replace("' RUN BODY","Do`r`nCall YieldThread()`r`nLoop")}
   [IO.File]::WriteAllText((Join-Path $evidence ($name+'.bas')),$source,$utf)
   $manifest=Join-Path $evidence ($name+'.UBE')
   $manifestLines=@('UBE-Project 1','Name = "Probe"','Kind = "Exe"','Startup = "Main"',"Optimization = `"$level`"","Source = `"$name.bas`"")
   [IO.File]::WriteAllLines($manifest,$manifestLines,$utf)
   $binary=Join-Path $evidence ($name+'.exe');$binaries[$kind]=$binary
   $run=Run $CompilerExe @($mode,$manifest,$binary,'--clang',$Clang) ($name+'-build')
   Require ($run.Code -eq 0 -and $run.Error -eq '') "Build failed: $name $($run.Out) $($run.Error)"
  }
  $run=Run $binaries['standalone'] @() "o$level-standalone-direct"
  Require ($run.Code -eq 0 -and $run.Out -eq '' -and $run.Error -eq '') 'Standalone context failed'
  Assert-Marker $markers['standalone'] $true;Clear-Marker $markers['standalone'];Record "o$level-standalone-direct"
  foreach($kind in @('standalone','hosted','wrong-value','escaping-failure')) {
   $run=Host $binaries[$kind] 'valid' 'normal' "o$level-$kind-valid"
   $expected=0;if($kind -eq 'wrong-value'){$expected=7};if($kind -eq 'escaping-failure'){$expected=99}
   Require ($run.Code -eq $expected -and $run.Out -eq '' -and $run.Error -eq '') "Hosted result differs for $kind"
   Assert-Marker $markers[$kind] $true;Clear-Marker $markers[$kind];Record "o$level-$kind-valid"
  }
  $run=Host $binaries['hosted'] 'uppercase' 'normal' "o$level-uppercase-valid"
  Require ($run.Code -eq 0 -and $run.Out -eq '' -and $run.Error -eq '') 'Uppercase hexadecimal session identity failed'
  Assert-Marker $markers['hosted'] $true;Clear-Marker $markers['hosted'];Record "o$level-uppercase-valid"
  Resume-Source $binaries['hosted'] $markers['hosted'] "o$level-debug-resume"
  $run=Run $binaries['hosted'] @() "o$level-reject-direct"
  Require ($run.Code -eq 125 -and $run.Out -eq '' -and $run.Error -ceq $diagnostic) 'Direct IDE artifact did not reject before source initialization'
  Assert-Marker $markers['hosted'] $false;Record "o$level-reject-direct"
  foreach($mode in @('missing','malformed','stale','unrelated','wrongflags')) {
   $run=Host $binaries['hosted'] $mode 'normal' "o$level-reject-$mode"
   Require ($run.Code -eq 125 -and $run.Out -eq '' -and $run.Error -ceq $diagnostic) "Guard rejection differs: $mode $($run.Code) $($run.Error)"
   Assert-Marker $markers['hosted'] $false;Record "o$level-reject-$mode"
  }
  $run=Host $binaries['hosted'] 'valid' 'suspend-close' "o$level-ended-before-resume"
  Require ($run.Out -eq '' -and $run.Error -eq '') 'Suspended child executed after session close'
  Assert-Marker $markers['hosted'] $false;Record "o$level-ended-before-resume"
  Kill-Owner $binaries['hosted'] 'paused' $markers['hosted'] "o$level-host-exit-paused"
  Kill-Owner $binaries['running'] 'running' $markers['running'] "o$level-host-exit-running"
 }
 $success=$true
} finally {
 $report=@{Success=$success;HostOnly=[bool]$HostOnly;Results=$results.ToArray();HostSHA256=(Get-FileHash $hostExe).Hash}
 if($CompilerExe){$report.CompilerSHA256=(Get-FileHash $CompilerExe).Hash}
 [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),($report|ConvertTo-Json -Depth 5),$utf)
}
Write-Output "PASS: $($results.Count) IDE session checks. Evidence: $evidence"
