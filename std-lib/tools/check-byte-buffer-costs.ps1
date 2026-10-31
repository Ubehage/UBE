param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/byte-buffer-costs/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$paths = @('std-lib/tools/check-byte-buffer-costs.ps1','std-lib/src/portable/Utf8.bas','std-lib/src/portable/ByteBuffer.bas',
    'std-lib/tests/byte-buffer/metrics.c','std-lib/tests/byte-buffer/metrics-entry.bas','std-lib/tests/byte-buffer/metrics-adapters.ll',
    'std-lib/tests/byte-buffer/ORACLES.md','std-lib/BYTE-BUFFER-CONTRACT.md',
    'runtime/bootstrap_runtime.c','runtime/value_storage.h','std-lib/tests/managed-storage/copy-probe.h',
    'std-lib/tests/byte-storage/allocation-probe.h','bootstrap/tools/verification.ps1')
$inputs = @($paths | ForEach-Object { Get-ArtifactIdentity (Join-Path $root $_) })
$commands = @(); $checks = @(); $measurements = @()
$selection = $null; $success = $false; $failure = $null
# Independent budgets fixed before invoking a compiler or executable.
$budgets = [pscustomobject]@{ sizes = @(1,8,9,16,17,64,65,256,4096,65536);
    growthCopiedBytes = 'strictly less than 2*N'; capacity = '8 for N<=8; otherwise N<=capacity<2*N';
    growthAllocations = 'one actual successful payload calloc per capacity change; sequence 8,16,32,...';
    snapshotCopiedBytes = 'at most 2*N; current independent prepare/publication must execute exactly 2*N';
    memory = 'after collection, exactly current capacities plus measured allocation headers; zero payload and tracked allocation delta after scope';
    noWork = 'satisfied reserve, clear, queries and UTF-8 validation: zero allocator requests and payload copy leaves';
    workers = 4; roundsPerWorker = 32; workerWaitMs = 20000 }
function Invoke-Recorded([string]$File,[string[]]$Arguments = @(),[int]$Timeout = 60) {
    $record = Invoke-BoundedProcess $File $Arguments $root $Timeout
    $script:commands += $record
    if ($record.timedOut -or $record.exit -ne 0) { throw "Byte-buffer cost process failed: $($record | ConvertTo-Json -Compress -Depth 5)" }
    return $record
}
try {
    $inputs += Get-ArtifactIdentity $SelectionPath
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($property in $selection.PSObject.Properties) {
        if ($property.Name -ne 'schema') {
            if ((Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256) { throw "Selected artifact changed: $($property.Name)" }
            $inputs += $property.Value
        }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected compiler has not passed its source acceptance gate' }
    foreach ($identity in @($selection.compiler,$selection.runtime,$selection.unicodeRuntime)) {
        $artifact = @($accepted.artifacts | Where-Object path -CEQ $identity.path)
        if ($artifact.Count -ne 1 -or $artifact[0].sha256 -cne $identity.sha256) { throw 'Selected artifact differs from immutable accepted source manifest' }
    }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted source input changed: $($identity.path)" }
    }
    $runtimeInput = @($accepted.inputs | Where-Object path -CEQ (Join-Path $root 'runtime/bootstrap_runtime.c'))
    if ($runtimeInput.Count -ne 1 -or $runtimeInput[0].sha256 -cne (Get-ArtifactIdentity (Join-Path $root 'runtime/bootstrap_runtime.c')).sha256) { throw 'Instrumented runtime source differs from accepted runtime source' }
    $inputs += @($accepted.inputs)
    $stage1 = Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
    $stageOne = @($accepted.artifacts | Where-Object path -CEQ $stage1)
    if ($stageOne.Count -ne 1 -or (Get-ArtifactIdentity $stage1).sha256 -cne $stageOne[0].sha256) { throw 'Stage-one compiler identity differs' }
    $inputs += $stageOne[0]
    $body = ''
    foreach ($name in @('Utf8','ByteBuffer')) {
        $module = [IO.File]::ReadAllText((Join-Path $root ('std-lib/src/portable/' + $name + '.bas'))).Replace("`r`n","`n")
        $lines = $module -split "`n"
        if ($lines[0] -cne 'UBE SOURCE 1 MODULE' -or $lines[1] -cne ('Attribute UBE_Name = "' + $name + '"')) { throw 'Unexpected library envelope' }
        $body += ($lines[2..($lines.Count - 1)] -join "`n") + "`n"
    }
    $source = Join-Path $run 'metrics.bas'
    [IO.File]::WriteAllText($source,$body + [IO.File]::ReadAllText((Join-Path $root 'std-lib/tests/byte-buffer/metrics-entry.bas')),(New-Object Text.UTF8Encoding($false)))
    $instrumented = Join-Path $run 'observed-runtime.o'
    $null = Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-c',
        '-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),(Join-Path $root 'runtime/bootstrap_runtime.c'),'-o',$instrumented)
    $hashes = @()
    $stages = @($stage1,$selection.compiler.path)
    for ($index = 0; $index -lt 2; ++$index) {
        $stem = Join-Path $run ('stage' + ($index + 1))
        $ir = $stem + '.ll'
        $null = Invoke-Recorded $stages[$index] @($source,$ir)
        $raw = [IO.File]::ReadAllText($ir)
        foreach ($signature in @('void @ube.p0\(ptr [^)]+\)','i1 @ube.p1\(ptr [^,]+, i8 [^,]+, ptr [^,]+, ptr [^)]+\)',
            'i1 @ube.p2\(ptr [^)]+\)','i32 @ube.p7\(ptr [^)]+\)','i32 @ube.p8\(ptr [^)]+\)',
            'i1 @ube.p9\(ptr [^,]+, i32 [^)]+\)','i1 @ube.p10\(ptr [^,]+, i8 [^)]+\)',
            'i1 @ube.p11\(ptr [^,]+, ptr [^,]+, i32 [^,]+, i32 [^)]+\)',
            'i1 @ube.p12\(ptr [^)]+\)','i1 @ube.p13\(ptr [^,]+, ptr [^)]+\)',
            'i1 @ube.p14\(ptr [^,]+, ptr [^)]+\)','i1 @ube.p15\(i8 [^,]+, i1 [^)]+\)')) {
            if ([regex]::Matches($raw,'(?m)^define ' + $signature + ' \{\r?$').Count -ne 1) { throw "Unrecognized typed UBE bridge: $signature" }
        }
        if ([regex]::Matches($raw,'(?m)^%ube\.type\.0 = type \{ i32, i32, i32, i1 \}\r?$').Count -ne 1 -or
            [regex]::Matches($raw,'(?m)^%ube\.type\.1 = type \{ ptr, i32 \}\r?$').Count -ne 1) { throw 'Unrecognized decoder or ByteBuffer record fields' }
        if ([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1) { throw 'Unrecognized executable entry wrapper' }
        $adapted = [regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @metrics_unused_entry(')
        $adapted = [regex]::Replace($adapted,'(?m)^define i1 @ube\.p1\(','define i1 @metrics_feed_body(')
        $adapted = [regex]::Replace($adapted,'(?m)^define i1 @ube\.p2\(','define i1 @metrics_finish_body(')
        $adapted += "`n" + [IO.File]::ReadAllText((Join-Path $root 'std-lib/tests/byte-buffer/metrics-adapters.ll'))
        $adaptedIr = $stem + '-adapted.ll'
        [IO.File]::WriteAllText($adaptedIr,$adapted,(New-Object Text.UTF8Encoding($false)))
        $exe = $stem + '-observed.exe'
        $linkArgs = @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$adaptedIr,'-x','c',
            (Join-Path $root 'std-lib/tests/byte-buffer/metrics.c'),'-std=c11','-Wall','-Wextra','-Werror','-x','none')
        $null = Invoke-Recorded $selection.clang.path ($linkArgs + @($instrumented,$selection.unicodeRuntime.path,'-o',$exe))
        $native = Invoke-Recorded $exe
        if ($native.stderr -cne '') { throw "Cost oracle stderr: $($native.stderr)" }
        $output = @($native.stdout.TrimEnd("`r","`n") -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
        if ($output.Count -ne $budgets.sizes.Count + 1 -or $output[-1] -notmatch '^PASS byte-buffer costs assertions:(\d+)$') { throw 'Unrecognized cost result shape' }
        $assertions = [long]$Matches[1]
        for ($m = 0; $m -lt $budgets.sizes.Count; ++$m) {
            $measurement = $output[$m] | ConvertFrom-Json
            if ($measurement.n -ne $budgets.sizes[$m] -or $measurement.growthCopiedBytes -ge 2 * $measurement.n -or
                $measurement.snapshotCopiedBytes -gt 2 * $measurement.n) { throw 'Independent cost summary oracle failed' }
            $measurements += [pscustomobject]@{ stage = $index + 1; actual = $measurement; sampledProcessPeakWorkingSetBytes = $native.sampledPeakWorkingSetBytes }
        }
        $checks += [pscustomobject]@{ stage = $index + 1; assertion = 'actual native allocation/copy/zero-request/lifetime budgets, failure atomicity and four concurrent independent workers'; assertions = $assertions; passed = $true }
        $acceptedExe = $stem + '-accepted-runtime.exe'
        $null = Invoke-Recorded $selection.clang.path ($linkArgs + @($selection.runtime.path,$selection.unicodeRuntime.path,'-o',$acceptedExe))
        $functional = Invoke-Recorded $acceptedExe @('functional')
        if ($functional.stdout -cne "PASS byte-buffer exact accepted runtime subset`n" -or $functional.stderr -cne '') { throw 'Exact accepted runtime subset oracle failed' }
        $checks += [pscustomobject]@{ stage = $index + 1; assertion = 'same typed module bodies also pass append/snapshot/reuse/stale-Err/cleanup subset linked to exact accepted uninstrumented runtime'; passed = $true }
        $hashes += (Get-ArtifactIdentity $ir).sha256
    }
    if ($hashes[0] -cne $hashes[1]) { throw 'Byte-buffer cost raw LLVM differs between accepted stages' }
    $checks += [pscustomobject]@{ assertion = 'byte-identical raw LLVM through both accepted source-built stages'; passed = $true }
    foreach ($identity in $inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Proof input changed: $($identity.path)" }
    }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ schema = 'ube-byte-buffer-cost-proof-1'; success = $success; failure = $failure;
        acceptedSelection = $selection; inputs = $inputs; budgets = $budgets; checks = $checks; measurements = $measurements; commands = $commands;
        limits = 'Ordinary Utf8/ByteBuffer module bodies, not full Library manifest. calloc counters measure successful requested zero-initialization bytes, not physical CPU stores. Requested live/peak bytes exclude allocator/OS overhead and fixed test tracking storage. Sampled process working set includes harness/runtime and is reported separately. Native C caller threads qualify independent instances and immutable shared bytes, not a UBE scheduler. Mutable sharing and opaque immutable Text remain unqualified.';
        artifacts = @(Get-ChildItem -LiteralPath $run -File | ForEach-Object { Get-ArtifactIdentity $_.FullName }) } |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) byte-buffer cost/ownership/concurrency assertions through both accepted stages."
