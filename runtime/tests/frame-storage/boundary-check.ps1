param([Parameter(Mandatory=$true)][string]$CompilerExe,[switch]$Baseline)
$ErrorActionPreference='Stop'
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube frame boundary '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $artifacts
$utf8=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $artifacts"
$counts=@(119,120,4096);if($Baseline){$counts=@(119,120)}
foreach($count in $counts){foreach($level in @(0,2)){
 $name="Frame-$count-$level";$source=Join-Path $artifacts ($name+'.bas')
 $text="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`nPublic Function Main() As Long`r`nDim Values(0 To $($count-1)) As Long`r`nOn Error GoTo Failed`r`nValues(0) = 11`r`nValues($($count-1)) = 29`r`nMain = Values(0) + Values($($count-1)) - 40`r`nExit Function`r`nFailed:`r`nMain = 90`r`nEnd Function`r`n"
 [IO.File]::WriteAllText($source,$text,$utf8)
 $project=Join-Path $artifacts ($name+'.UBE')
 $manifest="UBE-Project 1`r`nName = `"FrameProbe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`nSource = `"$name.bas`"`r`n"
 [IO.File]::WriteAllText($project,$manifest,$utf8)
 $exe=Join-Path $artifacts ($name+'.exe')
 $ErrorActionPreference='Continue'
 $log=(& $CompilerExe --build $project $exe 2>&1 | Out-String)
 $ErrorActionPreference='Stop'
 if($Baseline -and $count -eq 120){
  if($LASTEXITCODE -eq 0 -or $log -notmatch '6/50'){throw "Expected narrow frame admission rejection: $log"}
  Write-Output "PASS baseline O$level 129-cell frame rejected6/50 (120 payload +4 descriptor +1 result +4 controls)"
 }else{
  if($LASTEXITCODE -ne 0){throw "Frame build failed: $log"}
  & $exe
  if($LASTEXITCODE -ne 0){throw "Frame execution failed: $LASTEXITCODE"}
  Write-Output "PASS O$level $($count+9)-cell frame admitted and returned0"
 }
}}
