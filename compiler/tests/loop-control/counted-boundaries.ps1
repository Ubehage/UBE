param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube counted boundaries '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$report=New-Object Collections.Generic.List[string]
Write-Output "Evidence: $evidence"
function Record([string]$Message){$report.Add($Message);Write-Output $Message;[IO.File]::WriteAllLines((Join-Path $evidence 'report.txt'),$report,$utf)}
function Run([string]$Executable,[string[]]$Arguments,[string]$Name) {
 $out=Join-Path $evidence ($Name+'.stdout');$err=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$Executable;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$out;RedirectStandardError=$err}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try {
  $null=$p.Handle
  if(-not $p.WaitForExit(60000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $Name"}
  $p.Refresh()
  if($null -eq $p.ExitCode){throw "Missing exit: $Name"}
  return [pscustomobject]@{Code=$p.ExitCode;Log=([IO.File]::ReadAllText($out,$utf)+[IO.File]::ReadAllText($err,$utf))}
 }finally{$p.Dispose()}
}
function Project([string]$Name,[string]$Body,[string]$Optimization='0') {
 $source=Join-Path $evidence ($Name+'.bas')
 [IO.File]::WriteAllText($source,"UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`n"+$Body,$utf)
 $manifest=Join-Path $evidence ($Name+'.UBE')
 [IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$Optimization`"`r`nSource = `"$Name.bas`"`r`n",$utf)
 return $manifest
}
function Machine([string]$Path) {
 $bytes=[IO.File]::ReadAllBytes($Path)
 if($bytes.Length -lt 90 -or $bytes[0] -ne 77 -or $bytes[1] -ne 90){throw 'Invalid DOS header'}
 $offset=[BitConverter]::ToInt32($bytes,60)
 if($offset -lt 64 -or $offset -gt $bytes.Length-26){throw 'Invalid PE offset'}
 if([BitConverter]::ToUInt32($bytes,$offset) -ne 17744 -or [BitConverter]::ToUInt16($bytes,$offset+4) -ne 34404 -or [BitConverter]::ToUInt16($bytes,$offset+24) -ne 523){throw 'Expected AMD64 PE32+'}
}
$body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'counted-errors.bas'),$utf)
foreach($opt in @('0','2')) {
 foreach($negative in @($false,$true)) {
  $name='runtime-o'+$opt+'-negative'+[int]$negative
  $text=$body
  if($negative){$text=$text.Replace('If HeaderFailure(1) <> 0','If HeaderFailure(1) <> 1')}
  $manifest=Project $name $text $opt
  $exe=Join-Path $evidence ($name+'.exe')
  $r=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang) ($name+'-build')
  if($r.Code -ne 0 -or $r.Log -notmatch 'BUILD OK'){throw "Build failed: $name $($r.Log)"}
  Machine $exe
  $r=Run $exe @() ($name+'-run')
  $expected=[int]$negative
  if($r.Code -ne $expected){throw "Runtime assertion: $name expected $expected got $($r.Code)"}
  Record "PASS $name AMD64 execution exit=$expected"
 }
}
$cases=@(
 @('cross-if',"Dim Index As Long`r`nFor Index = 1 To 2`r`nIf True Then`r`nNext Index`r`nEnd If"),
 @('cross-do',"Dim Index As Long`r`nDim Inner As Long`r`nFor Index = 1 To 2`r`nDo`r`nFor Inner = 1 To 2`r`nNext Inner,Index`r`nLoop"),
 @('trailing-next-comma',"Dim Index As Long`r`nDim Inner As Long`r`nFor Index = 1 To 2`r`nFor Inner = 1 To 2`r`nNext Inner,"),
 @('constant-counter',"Const Index As Long = 1`r`nFor Index = 1 To 2`r`nNext"),
 @('unexpected-next',"Next"),
 @('deep-for',("Dim Index As Long`r`n"+('For Index = 1 To 2'+"`r`n")*70+('Next'+"`r`n")*70))
)
$recovery=Project 'recovery' "Public Function Main() As Long`r`nDim Index As Long`r`nFor Index = 1 To 2`r`nExit Loop`r`nNext`r`nMain = Index`r`nEnd Function"
$reference=Join-Path $evidence 'reference.ll'
$r=Run $CompilerExe @('--emit-llvm',$recovery,$reference) 'reference'
if($r.Code -ne 0){throw "Recovery reference failed $($r.Log)"}
$hash=(Get-FileHash -LiteralPath $reference -Algorithm SHA256).Hash
foreach($case in $cases) {
 $name=$case[0];$manifest=Project $name ("Public Function Main() As Long`r`n"+$case[1]+"`r`nEnd Function")
 foreach($mode in @('--emit-llvm','--build')) {
  $output=Join-Path $evidence ($name+$(if($mode -eq '--build'){'.exe'}else{'.ll'}))
  [IO.File]::WriteAllText($output,'PRESERVE',$utf)
  $arguments=@($mode,$manifest,$output);if($mode -eq '--build'){$arguments+=@('--clang',$Clang)}
  $r=Run $CompilerExe $arguments ($name+$mode)
  if($r.Code -ne 1 -or $r.Log -notmatch 'E_' -or $r.Log -notmatch ([regex]::Escape($name+'.bas')+':\d+:\d+') -or [IO.File]::ReadAllText($output,$utf) -cne 'PRESERVE'){throw "Controlled rejection/preservation failed: $name $mode $($r.Log)"}
  if($name -eq 'deep-for' -and $r.Log -notmatch 'E_LIMIT|8/4/7'){throw "Depth was not rejected by the syntax-depth diagnostic: $($r.Log)"}
 }
 $after=Join-Path $evidence ($name+'-recovery.ll')
 $r=Run $CompilerExe @('--emit-llvm',$recovery,$after) ($name+'-recovery')
 if($r.Code -ne 0 -or (Get-FileHash -LiteralPath $after -Algorithm SHA256).Hash -cne $hash){throw "Recovery differs: $name $($r.Log)"}
 if(@(Get-ChildItem -LiteralPath $evidence -Force -Filter '*.ube-*').Count -ne 0){throw "Leaked publication stages after $name"}
 Record "PASS $name located rejection in emit/build, preserved outputs and deterministic recovery"
}
Record 'PASS counted boundary gate: 4 native executions and 6 malformed/depth/recovery cases; full language/lifetime qualification remains separate.'
