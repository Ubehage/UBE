param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [switch]$AdmissionBaseline,
 [switch]$Counted,
 [switch]$Floating,
 [switch]$Managed,
 [switch]$Resources,
 [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube loop control '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
function Run([string]$Exe,[string[]]$Arguments,[string]$Name) {
 $stdout=Join-Path $evidence ($Name+'.stdout');$stderr=Join-Path $evidence ($Name+'.stderr')
 $quoted=@($Arguments|ForEach-Object{'"'+$_+'"'})
 $options=@{FilePath=$Exe;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
 if($quoted.Count -gt 0){$options.ArgumentList=$quoted -join ' '}
 $p=Start-Process @options
 try {
  $null=$p.Handle
  if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $Name"}
  $p.Refresh()
  if($null -eq $p.ExitCode){throw "Missing exit code: $Name"}
  return [pscustomobject]@{Code=$p.ExitCode;Log=([IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr))}
 } finally {$p.Dispose()}
}
function Project([string]$Name,[string]$Body,[string]$Optimization='0') {
 $source="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`n"+$Body
 [IO.File]::WriteAllText((Join-Path $evidence ($Name+'.bas')),$source,$utf)
 $path=Join-Path $evidence ($Name+'.UBE')
 [IO.File]::WriteAllText($path,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$Optimization`"`r`nSource = `"$Name.bas`"`r`n",$utf)
 return $path
}
function Reject([string]$Name,[string]$Body,[string]$Location='') {
 $project=Project $Name $Body
 $output=Join-Path $evidence ($Name+'.ll')
 [IO.File]::WriteAllText($output,'SENTINEL',$utf)
 $r=Run $CompilerExe @('--emit-llvm',$project,$output) $Name
 if($r.Code -eq 0 -or $r.Log -notmatch 'E_' -or [IO.File]::ReadAllText($output) -cne 'SENTINEL'){throw "Rejection/preservation failed: $Name $($r.Log)"}
 if($Location -ne '' -and -not $r.Log.Contains($Name+'.bas:'+ $Location)){throw "Wrong diagnostic location: $Name $($r.Log)"}
 Write-Output "PASS rejected $Name; $($r.Log.Trim())"
}
if($AdmissionBaseline) {
 foreach($probe in @(
  @('exit-loop',"Do`r`nExit Loop`r`nLoop"),
  @('while',"While False`r`nWend"),
  @('for',"Dim Index As Long`r`nFor Index = 1 To 2`r`nNext Index"),
  @('for-each',"Dim Values(0 To 1) As Long`r`nDim Item As Long`r`nFor Each Item In Values`r`nNext Item"),
  @('synclock',"Dim Value As Long`r`nSyncLock Value`r`nEnd SyncLock")
 )) {Reject $probe[0] ("Public Function Main() As Long`r`n"+$probe[1]+"`r`nEnd Function")}
}
Reject 'outside-loop' "Public Function Main() As Long`r`nExit Loop`r`nEnd Function" '4:6'
Reject 'caller-loop' "Private Sub Helper()`r`nExit Loop`r`nEnd Sub`r`nPublic Function Main() As Long`r`nDo`r`nHelper`r`nExit Do`r`nLoop`r`nEnd Function" '4:6'
Reject 'after-loop' "Public Function Main() As Long`r`nDo`r`nExit Do`r`nLoop`r`nExit Loop`r`nEnd Function" '7:6'
$fixtures=@('do','while')
if($Counted){$fixtures+=@('for')}
if($Floating){$fixtures+=@('for-floating')}
if($Managed){$fixtures+=@('managed-local')}
if($Resources){$fixtures+=@('resource')}
if($Counted) {
 foreach($probe in @(
  @('wrong-next',"Dim Index As Long`r`nDim Other As Long`r`nFor Index = 1 To 2`r`nNext Other"),
  @('nested-counter',"Dim Index As Long`r`nFor Index = 1 To 2`r`nFor Index = 1 To 2`r`nNext Index,Index"),
  @('extra-next',"Dim Index As Long`r`nFor Index = 1 To 2`r`nNext Index,Index"),
  @('no-for',"Exit For"),
  @('boolean-counter',"Dim Flag As Boolean`r`nFor Flag = False To True`r`nNext Flag"),
  @('missing-to',"Dim Index As Long`r`nFor Index = 1`r`nNext Index"),
  @('missing-step',"Dim Index As Long`r`nFor Index = 1 To 2 Step`r`nNext Index"),
  @('wrong-for-exit',"Do`r`nExit For`r`nLoop")
 )) {Reject $probe[0] ("Public Function Main() As Long`r`n"+$probe[1]+"`r`nEnd Function")}
}
if($AdmissionBaseline){$fixtures=@('do')}
else {
 Reject 'wrong-do-exit' "Public Function Main() As Long`r`nWhile True`r`nExit Do`r`nWend`r`nEnd Function" '5:6'
 Reject 'wrong-while-exit' "Public Function Main() As Long`r`nDo`r`nExit While`r`nLoop`r`nEnd Function" '5:6'
 Reject 'mismatched-wend' "Public Function Main() As Long`r`nDo`r`nWend`r`nEnd Function" '5:1'
 Reject 'mismatched-loop' "Public Function Main() As Long`r`nWhile True`r`nLoop`r`nEnd Function" '5:1'
}
foreach($fixture in $fixtures) {
$body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ($fixture+'-control.bas')),$utf)
if($AdmissionBaseline){$body="Public Function Main() As Long`r`nDo`r`nExit Do`r`nLoop`r`nEnd Function"}
foreach($opt in @('0','2')) {
 foreach($control in @($false,$true)) {
  $name=$fixture+'-o'+$opt+'-control'+[int]$control
  $text=$body
  if($control){
   if($AdmissionBaseline){$text=$text.Replace('Public Function Main() As Long',"Public Function Main() As Long`r`nMain = 99")}
   else {$text=$text.Replace('If Count <> 1 Or','If Count <> 2 Or')}
   if($fixture -eq 'for'){$text=$body.Replace('If Count <> 3 Or Trace <> 123','If Count <> 4 Or Trace <> 123')}
   if($fixture -eq 'for-floating'){$text=$body.Replace('If Count <> 3 Or Narrow','If Count <> 4 Or Narrow')}
   if($fixture -eq 'managed-local'){$text=$body.Replace('If Kept <> "loop-local"','If Kept <> "changed-expectation"')}
   if($fixture -eq 'resource'){$text=$body.Replace('If Progress <> 1 Then Main = 1','If Progress <> 2 Then Main = 1')}
  }
  if($fixture -eq 'resource') {
   $pathBytes=[Text.Encoding]::ASCII.GetBytes($name+'.bin')
   $setup='Dim Path(0 To '+($pathBytes.Length-1)+") As Byte`r`n"
   for($i=0;$i -lt $pathBytes.Length;$i++){$setup+='Path('+$i+') = '+$pathBytes[$i]+"`r`n"}
   $text=$text.Replace("' PATH SETUP",$setup)
  }
  $project=Project $name $text $opt
  $exe=Join-Path $evidence ($name+'.exe')
  $r=Run $CompilerExe @('--build',$project,$exe,'--clang',$Clang) ($name+'-build')
  if($r.Code -ne 0 -or $r.Log -notmatch 'BUILD OK'){throw "Build failed: $name $($r.Log)"}
  $r=Run $exe @() ($name+'-run')
  $expected=0;if($control){$expected=1;if($AdmissionBaseline){$expected=99}}
  if($r.Code -ne $expected){throw "Execution failed: $name expected $expected got $($r.Code)"}
  if($fixture -eq 'resource') {
   $bytes=[IO.File]::ReadAllBytes((Join-Path $evidence ($name+'.bin')))
   if($bytes.Length -ne 2 -or $bytes[0] -ne 41 -or $bytes[1] -ne 42){throw "Wrong retained resource contents: $name"}
  }
  Write-Output "PASS $name exit=$expected"
 }
}
}
Write-Output 'PASS requested loop fixtures; full Exit Loop qualification remains separate.'
