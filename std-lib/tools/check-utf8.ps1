param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/utf8/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$paths = @('std-lib/tools/check-utf8.ps1','std-lib/src/portable/Utf8.bas',
    'std-lib/tests/utf8/entry.bas','std-lib/tests/utf8/adapters.ll',
    'std-lib/tests/utf8/probe.c','std-lib/tests/utf8/cases.json','std-lib/tests/utf8/allocation-probe.h',
    'runtime/bootstrap_runtime.c','bootstrap/tools/verification.ps1')
$inputs = @($paths | ForEach-Object { Get-ArtifactIdentity (Join-Path $root $_) })
$commands = @()
$checks = @()
$measurements = @()
$selection = $null
$success = $false
$failure = $null
try {
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($property in $selection.PSObject.Properties) {
        if ($property.Name -ne 'schema' -and (Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256) { throw "Selection changed: $($property.Name)" }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected compiler did not pass its acceptance gate' }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted input changed: $($identity.path)" }
    }
    $stages = @((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    $stageOne = @($accepted.artifacts | Where-Object path -CEQ $stages[0])
    if ($stageOne.Count -ne 1 -or (Get-ArtifactIdentity $stages[0]).sha256 -cne $stageOne[0].sha256) { throw 'Stage one identity differs' }
    $suite = Get-Content (Join-Path $root 'std-lib/tests/utf8/cases.json') -Raw | ConvertFrom-Json
    $module = [IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/Utf8.bas')).Replace("`r`n","`n")
    $lines = $module -split "`n"
    if ($lines[0] -cne 'UBE SOURCE 1 MODULE' -or $lines[1] -cne 'Attribute UBE_Name = "Utf8"') { throw 'Unexpected source envelope' }
    $body = ($lines[2..($lines.Count - 1)] -join "`n")
    $source = Join-Path $run 'utf8.bas'
    [IO.File]::WriteAllText($source,$body + "`n" + [IO.File]::ReadAllText((Join-Path $root 'std-lib/tests/utf8/entry.bas')),(New-Object Text.UTF8Encoding($false)))
    $checks += 'exact library body; only the two documented envelope lines removed'
    $instrumentedRuntime = Join-Path $run 'instrumented-runtime.o'
    $instrument = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-c',
        '-include',(Join-Path $root 'std-lib/tests/utf8/allocation-probe.h'),(Join-Path $root 'runtime/bootstrap_runtime.c'),'-o',$instrumentedRuntime) $root 30
    $commands += $instrument
    if ($instrument.timedOut -or $instrument.exit -ne 0) { throw "Runtime instrumentation failed: $($instrument.stderr)" }
    $hashes = @()
    for ($index = 0; $index -lt 2; $index++) {
        $stem = Join-Path $run ('stage' + ($index + 1))
        $ir = $stem + '.ll'
        $compile = Invoke-BoundedProcess $stages[$index] @($source,$ir) $root 15
        $commands += $compile
        if ($compile.timedOut -or $compile.exit -ne 0 -or -not (Test-Path -LiteralPath $ir)) { throw "Emission failed: $($compile.stdout)$($compile.stderr)" }
        $raw = [IO.File]::ReadAllText($ir)
        $signatures = @('void @ube.p0\(ptr %arg\.\d+\)',
            'i1 @ube.p1\(ptr %arg\.\d+, i8 %arg\.\d+, ptr %arg\.\d+, ptr %arg\.\d+\)',
            'i1 @ube.p2\(ptr %arg\.\d+\)',
            'void @ube.p3\(ptr %arg\.\d+, ptr %arg\.\d+\)',
            'void @ube.p4\(%ube\.type\.0 %arg\.\d+\)',
            'void @ube.p5\(ptr %arg\.\d+, i32 %arg\.\d+\)')
        foreach ($signature in $signatures) {
            if ([regex]::Matches($raw,('(?m)^define ' + $signature + ' \{')).Count -ne 1) { throw "Unexpected adapter signature: $signature" }
        }
        if ($raw -match '(?m)^\s+.*call.*@(malloc|calloc|realloc|ube_array_redim|ube_gc_allocate|ube_string_\w+)\(') { throw 'Unexpected allocation/string operation in decoder IR' }
        $checks += "stage $($index + 1): adapter signatures; no allocation/string calls in raw IR"
        $adapted = $stem + '-probe.ll'
        if ([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1) { throw 'Expected exactly one entry wrapper' }
        [IO.File]::WriteAllText($adapted,$raw.Replace('define i32 @main(', 'define i32 @decoder_test_entry(') + "`n" + [IO.File]::ReadAllText((Join-Path $root 'std-lib/tests/utf8/adapters.ll')),(New-Object Text.UTF8Encoding($false)))
        foreach ($mode in @('accepted','instrumented')) {
        $exe = $stem + '-' + $mode + '.exe'
        $runtime = $selection.runtime.path
        $extra = @()
        $expected = $suite.expectedStdout.Replace('PASS allocations:0','PASS runtime:accepted')
        if ($mode -eq 'instrumented') {
            $runtime = $instrumentedRuntime
            $extra = @('-DPROBE_ALLOCATIONS=1')
            $expected = $suite.expectedStdout
        }
        $linkArguments = @('--target=x86_64-w64-windows-gnu','-O2','-std=c11',
            $adapted,(Join-Path $root 'std-lib/tests/utf8/probe.c'),$runtime,$selection.unicodeRuntime.path,
            '-o',$exe) + $extra
        $link = Invoke-BoundedProcess $selection.clang.path $linkArguments $root 30
        $commands += $link
        if ($link.timedOut -or $link.exit -ne 0) { throw "Probe link failed: $($link.stderr)" }
        $native = Invoke-BoundedProcess $exe @() $root 60
        $commands += $native
        if ($native.timedOut -or $native.exit -ne $suite.exit -or $native.stdout -cne $expected -or $native.stderr -notmatch '^MEASURE sequential-feed-calls:(\d+)\n$') { throw "Native oracle failed: $($native | ConvertTo-Json -Compress -Depth 4)" }
        $allocationCount = $null
        if ($mode -eq 'instrumented') { $allocationCount = 0 }
        $measurements += [pscustomobject]@{ stage = $index + 1; runtime = $mode; sequentialFeedCalls = [long]$Matches[1];
            elapsedMs = $native.elapsedMs; sampledPeakWorkingSetBytes = $native.sampledPeakWorkingSetBytes;
            stateBytes = 16; stateAlignment = 4; allocations = $allocationCount; workerCount = 4; workerIterations = 10000 }
        $checks += "stage $($index + 1) $mode runtime: exact scalar/malformed/state/Err/concurrency/layout oracles"
        }
        $hashes += (Get-ArtifactIdentity $ir).sha256
    }
    if ($hashes[0] -cne $hashes[1]) { throw 'Stage raw LLVM differs' }
    $checks += 'byte-identical raw LLVM through both accepted stages'
    foreach ($identity in $inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Proof input changed: $($identity.path)" }
    }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ schema = 'ube-utf8-proof-1'; success = $success; failure = $failure;
        acceptedSelection = $selection; inputs = $inputs; checks = $checks; measurements = $measurements;
        commands = $commands; artifacts = @(Get-ChildItem -LiteralPath $run -File | ForEach-Object { Get-ArtifactIdentity $_.FullName }) } |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) UTF-8 acceptance assertions through both accepted v2 stages."
