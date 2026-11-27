param([Parameter(Mandatory=$true)][string]$CompilerExe)
$ErrorActionPreference='Stop'
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube floating format '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false)
$modules=@('BinaryFloatText','BinaryFloatValues','BinaryFloat','InvariantNumbers','ByteText','Utf8','BufferPrimitives','FilePrimitives')
foreach($module in $modules){Copy-Item -LiteralPath (Join-Path $PSScriptRoot "../../../std-lib/src/portable/$module.bas") -Destination $evidence}
$original=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'TextFormatting.bas'))
foreach($level in @('0','2')) {
 foreach($negative in @($false,$true)) {
  $source=$original
  if($negative){$source=$source.Replace('If Used <> 1 Or','If Used <> 2 Or')}
  [IO.File]::WriteAllText((Join-Path $evidence 'TextFormatting.bas'),$source,$utf)
  $manifest="UBE-Project 1`r`nName = `"FloatText`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
  foreach($module in ($modules+@('TextFormatting'))){$manifest+="Source = `"$module.bas`"`r`n"}
  $project=Join-Path $evidence 'Probe.UBE'
  [IO.File]::WriteAllText($project,$manifest,$utf)
  $exe=Join-Path $evidence "Probe-$level-$negative.exe"
  & $CompilerExe --build $project $exe
  if($LASTEXITCODE -ne 0){throw 'Build failed'}
  & $exe
  $expected=0;if($negative){$expected=2}
  if($LASTEXITCODE -ne $expected){throw "Unexpected result $LASTEXITCODE; expected $expected; evidence $evidence"}
 }
}
Write-Output "PASS O0/O2 focused floating formatting and changed-text oracle; evidence: $evidence"
