param([Parameter(Mandatory=$true)][string]$CompilerExe)
$ErrorActionPreference='Stop'
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube floating integer '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../../../std-lib/src/portable/BinaryFloatValues.bas') -Destination $evidence
$original=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'IntegerConversion.bas'))
foreach($level in @('0','2')) {
 foreach($negative in @($false,$true)) {
  $source=$original
  if($negative){$source=$source.Replace('If Value <> 0 Then Main = 2','If Value <> 1 Then Main = 2')}
  [IO.File]::WriteAllText((Join-Path $evidence 'IntegerConversion.bas'),$source,$utf)
  $manifest=@"
UBE-Project 1
Name = "FloatInteger"
Kind = "Exe"
Startup = "Main"
Optimization = "$level"
Source = "BinaryFloatValues.bas"
Source = "IntegerConversion.bas"
"@
  $project=Join-Path $evidence 'Probe.UBE'
  [IO.File]::WriteAllText($project,$manifest,$utf)
  $exe=Join-Path $evidence "Probe-$level-$negative.exe"
  & $CompilerExe --build $project $exe
  if($LASTEXITCODE -ne 0){throw 'Build failed'}
  & $exe
  $expected=0;if($negative){$expected=2}
  if($LASTEXITCODE -ne $expected){throw "Unexpected result $LASTEXITCODE; expected $expected"}
 }
}
Write-Output "PASS O0/O2 integer conversion cases and changed-rounding oracle; evidence: $evidence"
