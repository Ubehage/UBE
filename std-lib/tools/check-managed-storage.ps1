param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/managed-storage/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$paths = @('runtime/bootstrap_runtime.c','runtime/value_storage.h','std-lib/tests/managed-storage/substrate.c',
    'std-lib/tests/managed-storage/error-bookkeeping.c',
    'std-lib/tests/managed-storage/copy-probe.h',
    'compiler/UBE_Compiler_v3/tests/parser/probes/runtime-regression/check.ps1',
    'compiler/UBE_Compiler_v3/tests/parser/probes/runtime-regression/probe.c',
    'compiler/UBE_Compiler_v3/tests/parser/probes/runtime-regression/runtime-observed.c',
    'compiler/UBE_Compiler_v3/tests/parser/probes/runtime-regression/allocation-probe.h',
    'std-lib/tests/byte-storage/allocation-probe.h','std-lib/tools/check-managed-storage.ps1','bootstrap/tools/verification.ps1')
$inputs = @($paths | ForEach-Object { Get-ArtifactIdentity (Join-Path $root $_) })
$commands = @()
$checks = @()
$success = $false
$failure = $null
$selection = $null
$sourceBuildCurrent = $false
$nestedReports = @()
try {
    $selectionIdentity = Get-ArtifactIdentity $SelectionPath
    $inputs += $selectionIdentity
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($item in @($selection.manifest,$selection.compiler,$selection.runtime,$selection.clang,$selection.unicodeRuntime)) {
        if ((Get-ArtifactIdentity $item.path).sha256 -cne $item.sha256) { throw "Selected artifact changed: $($item.path)" }
    }
    $inputs += @($selection.manifest,$selection.compiler,$selection.runtime,$selection.clang,$selection.unicodeRuntime)
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected source build did not pass its acceptance gate' }
    foreach ($item in @($selection.compiler,$selection.runtime,$selection.unicodeRuntime)) {
        $manifestArtifact = @($accepted.artifacts | Where-Object path -CEQ $item.path)
        if ($manifestArtifact.Count -ne 1 -or $manifestArtifact[0].sha256 -cne $item.sha256) {
            throw "Selected artifact differs from the immutable accepted manifest: $($item.path)"
        }
    }
    $checks += [pscustomobject]@{ assertion = 'selected compiler and runtime object identities match the immutable accepted manifest'; passed = $true }
    $runtimeSource = Join-Path $root 'runtime/bootstrap_runtime.c'
    $runtimeIdentity = @($accepted.inputs | Where-Object path -CEQ $runtimeSource)
    if ($runtimeIdentity.Count -gt 1) { throw 'Selected manifest duplicates the runtime source identity' }
    if ($runtimeIdentity.Count -eq 1 -and $runtimeIdentity[0].sha256 -ceq (Get-ArtifactIdentity $runtimeSource).sha256) {
        foreach ($item in $accepted.inputs) {
            if ((Get-ArtifactIdentity $item.path).sha256 -cne $item.sha256) { throw "Source-build input changed: $($item.path)" }
        }
        $inputs += @($accepted.inputs)
        $sourceBuildCurrent = $true
        $checks += [pscustomobject]@{ assertion = 'immutable selected source manifest matches the tested runtime and all source-build input identities'; passed = $true }
    }
    $productionIr = Join-Path $run 'production-runtime.ll'
    $production = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-S','-emit-llvm',
        (Join-Path $root 'runtime/bootstrap_runtime.c'),'-o',$productionIr) $root 30
    $commands += $production
    if ($production.timedOut -or $production.exit -ne 0) { throw $production.stderr }
    $productionText = [IO.File]::ReadAllText($productionIr)
    if ($productionText -match 'probe_value_copy|UBE_VALUE_OBSERVE_COPY|__emutls' -or
        $productionText -notmatch '(?m)^@ube_thread_error = internal thread_local global %struct\.ube_error_state\b' -or
        $productionText -notmatch '(?m)^%struct\.ube_value_copy_range = type \{ ptr, ptr, ptr, i64 \}\r?$') {
        throw 'Default runtime retains observation overhead or lacks the native allocation-free error TLS record'
    }
    $checks += [pscustomobject]@{ assertion = 'default production runtime has no copy-observer overhead; error record is native LLVM thread_local with no emutls allocation'; passed = $true }
    $runtime = Join-Path $run 'runtime.o'
    $compile = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-c',
        '-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),(Join-Path $root 'runtime/bootstrap_runtime.c'),'-o',$runtime) $root 30
    $commands += $compile
    if ($compile.timedOut -or $compile.exit -ne 0) { throw $compile.stderr }
    $exe = Join-Path $run 'substrate.exe'
    $link = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra',
        (Join-Path $root 'std-lib/tests/managed-storage/substrate.c'),$runtime,$selection.unicodeRuntime.path,'-o',$exe) $root 30
    $commands += $link
    if ($link.timedOut -or $link.exit -ne 0) { throw $link.stderr }
    $native = Invoke-BoundedProcess $exe @() $root 15
    $commands += $native
    if ($native.timedOut -or $native.exit -ne 0 -or $native.stdout -notmatch '^PASS managed substrate assertions:(\d+)\n$' -or $native.stderr -cne '') { throw ($native | ConvertTo-Json -Compress -Depth 4) }
    $checks += [pscustomobject]@{ assertion = 'independent values/nested array tracing/borrow lifetime and bounds/cleanup/retry/failure-atomic partial copy and snapshot workspace/neutral private reads/allocation-free zero and neutral assignment/bounded traversal/allocation-free scalar records/four concurrent independent workers/atomic Byte span overlap and validation/actual payload-copy observation'; assertions = [long]$Matches[1]; passed = $true }
    $roots = Invoke-BoundedProcess $exe @('roots') $root 15
    $commands += $roots
    if ($roots.timedOut -or $roots.exit -ne 0 -or $roots.stdout -cne "PASS managed root limit:1048576`n" -or $roots.stderr -cne '') { throw ($roots | ConvertTo-Json -Compress -Depth 4) }
    $checks += [pscustomobject]@{ assertion = 'exact root capacity; failed registration/resize preserve value; every root leaves and capacity recovers'; roots = 1048576; passed = $true }
    $traceRecovery = Invoke-BoundedProcess $exe @('bookkeeping') $root 15
    $commands += $traceRecovery
    if ($traceRecovery.timedOut -or $traceRecovery.exit -ne 0 -or $traceRecovery.stdout -cne "PASS recoverable trace bookkeeping`n" -or $traceRecovery.stderr -cne '') { throw ($traceRecovery | ConvertTo-Json -Compress -Depth 4) }
    $regressionScript = Join-Path $root 'compiler/UBE_Compiler_v3/tests/parser/probes/runtime-regression/check.ps1'
    $powershell = (Get-Process -Id $PID).Path
    $inputs += Get-ArtifactIdentity $powershell
    $regression = Invoke-BoundedProcess $powershell @('-NoProfile','-File',$regressionScript,'-SelectionPath',$SelectionPath) $root 120
    $commands += $regression
    if ($regression.timedOut -or $regression.exit -ne 0 -or $regression.stderr -cne '') { throw ($regression | ConvertTo-Json -Compress -Depth 4) }
    $evidence = [regex]::Matches($regression.stdout,'(?m)^Evidence: ([^\r\n]+)\r?$')
    if ($evidence.Count -ne 1) { throw 'Expected one independent runtime-regression report' }
    $regressionReportPath = [IO.Path]::GetFullPath($evidence[0].Groups[1].Value)
    $regressionRoot = [IO.Path]::GetFullPath((Join-Path $root 'bootstrap/out/runtime-regression')) + [IO.Path]::DirectorySeparatorChar
    if (-not $regressionReportPath.StartsWith($regressionRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Runtime-regression report escaped its expected output directory' }
    $regressionReport = [IO.File]::ReadAllText($regressionReportPath) | ConvertFrom-Json
    $modes = @($regressionReport.checks | Where-Object { $_.PSObject.Properties.Name -contains 'mode' } | ForEach-Object mode)
    if (-not $regressionReport.success -or -not $regressionReport.regressionPassed -or $regressionReport.beforeFixReproduction -or
        $modes.Count -ne 4 -or ($modes -join ',') -cne 'trace-first,trace-partial,retry-success,fresh-error') { throw 'Independent runtime regression did not pass all four fixed-body modes' }
    $nestedReports += Get-ArtifactIdentity $regressionReportPath
    $inputs += @($regressionReport.inputs)
    $checks += [pscustomobject]@{ assertion = 'trace-bookkeeping failure returns Err7 with complete rooted values retained, lock released and later cleanup; four independent native recovery/error-publication regressions pass'; nestedReport = $nestedReports[-1]; modes = $modes; passed = $true }
    $errorExe = Join-Path $run 'error-bookkeeping.exe'
    $errorLink = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra',
        (Join-Path $root 'std-lib/tests/managed-storage/error-bookkeeping.c'),$runtime,$selection.unicodeRuntime.path,'-o',$errorExe) $root 30
    $commands += $errorLink
    if ($errorLink.timedOut -or $errorLink.exit -ne 0) { throw $errorLink.stderr }
    $errorNormal = Invoke-BoundedProcess $errorExe @('normal') $root 5
    $commands += $errorNormal
    if ($errorNormal.timedOut -or $errorNormal.exit -ne 0 -or $errorNormal.stdout -cne "returned Err:7 failed-calloc:0`n" -or $errorNormal.stderr -cne '') {
        throw ($errorNormal | ConvertTo-Json -Compress -Depth 4)
    }
    $checks += [pscustomobject]@{ assertion = 'fresh-thread first error publication records Err7 without allocating FLS error bookkeeping'; passed = $true }
    $errorDenied = Invoke-BoundedProcess $errorExe @() $root 5
    $commands += $errorDenied
    if ($errorDenied.timedOut -or $errorDenied.exit -ne 0 -or $errorDenied.stdout -cne "returned Err:7 failed-calloc:0`n" -or $errorDenied.stderr -cne '') {
        throw ($errorDenied | ConvertTo-Json -Compress -Depth 4)
    }
    $checks += [pscustomobject]@{ assertion = 'first error publication remains recoverable under denied calloc, never allocates bookkeeping, and returns Err7 rather than terminating or silently returning Err0'; passed = $true }
    foreach ($item in $inputs) {
        if ((Get-ArtifactIdentity $item.path).sha256 -cne $item.sha256) { throw "Input changed: $($item.path)" }
    }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ schema = 'ube-managed-storage-substrate-1'; success = $success; failure = $failure; inputs = $inputs;
        acceptedSelection = $selection; sourceBuildCurrent = $sourceBuildCurrent;
        commands = $commands; checks = $checks;
        artifacts = @($nestedReports) + @(Get-ChildItem -LiteralPath $run -File | ForEach-Object { Get-ArtifactIdentity $_.FullName });
        limits = 'C substrate proof only; compiler integration and UBECore owned buffer remain pending' } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: managed storage substrate and controlled bookkeeping exhaustion."
