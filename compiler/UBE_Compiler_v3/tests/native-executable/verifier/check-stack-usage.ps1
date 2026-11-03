param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-frame-probe.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$ir = Join-Path $OutputDirectory 'stack-usage.ll'
$object = Join-Path $OutputDirectory 'stack-usage.o'
& $Clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -S -emit-llvm $source -o $ir
if ($LASTEXITCODE -ne 0) { throw 'IR emission failed' }
& $Clang --target=x86_64-w64-windows-gnu -O2 -fstack-usage -c -x ir $ir -o $object
if ($LASTEXITCODE -ne 0) { throw 'IR object generation failed' }
$report = [IO.File]::ReadAllText((Join-Path $OutputDirectory 'stack-usage.su'))
function Check-Report([string] $text) {
    $callee = [regex]::Match($text, '(?m):guarded_callee\s+(\d+)\s+static\s*$')
    $caller = [regex]::Match($text, '(?m):guarded_caller\s+(\d+)\s+static\s*$')
    if (-not $callee.Success -or -not $caller.Success) { return $false }
    return [long]$callee.Groups[1].Value -ge 8192 -and [long]$caller.Groups[1].Value -lt 8192
}
if (-not (Check-Report $report)) { throw 'Unexpected stack-usage report' }
$mutated = $report.Replace('guarded_callee','TEMP_STACK_NAME').Replace('guarded_caller','guarded_callee').Replace('TEMP_STACK_NAME','guarded_caller')
if (Check-Report $mutated) { throw 'Comparator accepted swapped function names' }
Write-Output $report.Trim()
$dynamicSource = Join-Path $PSScriptRoot 'dynamic-stack-probe.c'
$dynamicIr = Join-Path $OutputDirectory 'dynamic-stack.ll'
$dynamicObject = Join-Path $OutputDirectory 'dynamic-stack.o'
& $Clang --target=x86_64-w64-windows-gnu -std=c17 -O2 -S -emit-llvm $dynamicSource -o $dynamicIr
if ($LASTEXITCODE -ne 0) { throw 'Dynamic IR emission failed' }
& $Clang --target=x86_64-w64-windows-gnu -O2 -fstack-usage -c -x ir $dynamicIr -o $dynamicObject
if ($LASTEXITCODE -ne 0) { throw 'Dynamic IR compilation failed' }
$dynamicReport = [IO.File]::ReadAllText((Join-Path $OutputDirectory 'dynamic-stack.su'))
function Check-Dynamic([string] $text) { return $text -match '(?m):dynamic_frame\s+\d+\s+dynamic\s*$' }
if (-not (Check-Dynamic $dynamicReport) -or (Check-Dynamic ($dynamicReport -replace 'dynamic\s*$', 'static'))) { throw 'Dynamic classification or control failed' }
Write-Output $dynamicReport.Trim()
Write-Output 'Static and dynamic reports passed; swapped-function and wrong-class controls rejected.'
