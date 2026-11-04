param([string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$output = Join-Path $root ('bootstrap/out/error-record/' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($output) | Out-Null
$commands = [Collections.Generic.List[object]]::new()
$inputs = @('bootstrap/runtime/error_support.c','bootstrap/runtime/bootstrap_runtime.c',
    'bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c',
    'bootstrap/runtime/windows/file_output.c',
    'bootstrap/runtime/windows/thread_primitives.c','bootstrap/tests/error_support_probe.c',
    'bootstrap/tests/error_state_probe.c','bootstrap/tests/integer_failure_probe.c',
    'bootstrap/tests/integer_storage_probe.c','bootstrap/tools/verification.ps1' |
    ForEach-Object { Get-ArtifactIdentity (Join-Path $root $_) })
$inputs += Get-ArtifactIdentity $PSCommandPath
$inputs += Get-ArtifactIdentity $Clang
$success = $false
$failure = $null
function Run([string[]]$Arguments, [int]$Expected = 0, [string]$Program = $Clang) {
    $record = Invoke-BoundedProcess $Program $Arguments $root 60
    $commands.Add($record)
    if ($record.timedOut -or $record.exit -ne $Expected) {
        throw "Unexpected result: $($record | ConvertTo-Json -Compress -Depth 5)"
    }
    return $record
}
try {
    $common = @('--no-default-config','--target=x86_64-w64-windows-gnu',
        '-std=c17','-Wall','-Wextra','-Wpedantic','-Werror')
    foreach ($mode in @('Full','None')) {
        $debug = @(if ($mode -eq 'Full') { '-g'; '-gdwarf-4' } else { '-g0' })
        foreach ($control in @($false,$true)) {
            $exe = Join-Path $output "record-$mode-$control.exe"
            $flags = @(if ($control) { '-DWRONG_STACK_ERROR_CONTROL' })
            $null = Run ($common + @('-O2') + $debug + $flags + @(
                (Join-Path $root 'bootstrap/tests/error_support_probe.c'),'-o',$exe))
            $record = Run @() ([int]$control) $exe
            if (-not $control -and ($record.stdout -cne "error record fields, clear, wrap, bounded text and specialized setter passed`n" -or $record.stderr)) {
                throw 'Record oracle did not complete'
            }
            if ($control -and $record.stderr -cne "record oracle failed: 2`n") { throw 'Wrong-error control failed for an unrelated reason' }
        }
        foreach ($stale in @(@('DESCRIPTION',9),@('SOURCE',10))) {
            $exe = Join-Path $output ("record-$mode-stale-" + $stale[0] + '.exe')
            $null = Run ($common + @('-O2') + $debug + @(
                ('-DSTALE_ERROR_' + $stale[0] + '_CONTROL'),
                (Join-Path $root 'bootstrap/tests/error_support_probe.c'),'-o',$exe))
            $record = Run @() 1 $exe
            if ($record.stderr -cne ("record oracle failed: " + $stale[1] + "`n")) {
                throw 'Stale error information control failed for an unrelated reason'
            }
        }
    }
    # Preserve the ordinary unoptimized bootstrap build and existing callers.
    $runtime = Join-Path $output 'bootstrap_runtime.o'
    $null = Run ($common + @('-c',(Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c'),'-o',$runtime))
    foreach ($probe in @('error_state','integer_failure','integer_storage')) {
        $exe = Join-Path $output "$probe.exe"
        $null = Run ($common + @((Join-Path $root "bootstrap/tests/${probe}_probe.c"),$runtime,'-o',$exe))
        $null = Run @() 0 $exe
    }
    foreach ($item in $inputs) {
        if ((Get-ArtifactIdentity $item.path).sha256 -cne $item.sha256) { throw "Changed input: $($item.path)" }
    }
    $success = $true
} catch { $failure = $_.ToString(); throw }
finally {
    $artifacts = @(Get-ChildItem -LiteralPath $output -File | ForEach-Object { Get-ArtifactIdentity $_.FullName })
    [pscustomobject]@{success=$success;failure=$failure;inputs=$inputs;commands=$commands.ToArray();artifacts=$artifacts} |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $output 'report.json') -Encoding UTF8
    Write-Output "Evidence: $output"
}
