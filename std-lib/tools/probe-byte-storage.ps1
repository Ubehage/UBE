param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/byte-storage/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$fixtures = Join-Path $root 'std-lib/tests/byte-storage'
$paths = @((Join-Path $PSScriptRoot 'probe-byte-storage.ps1'),(Join-Path $root 'bootstrap/tools/verification.ps1'),
    (Join-Path $root 'runtime/bootstrap_runtime.c')) + @(Get-ChildItem $fixtures -File | ForEach-Object FullName)
$inputs = @($paths | ForEach-Object { Get-ArtifactIdentity $_ })
$commands = @()
$obligations = @()
$completed = $false
$failure = $null
$selection = $null
try {
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($property in $selection.PSObject.Properties) {
        if ($property.Name -ne 'schema' -and (Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256) { throw "Selection changed: $($property.Name)" }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected tool is not accepted' }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted input changed: $($identity.path)" }
    }
    $stages = @((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    $stageOne = @($accepted.artifacts | Where-Object path -CEQ $stages[0])
    if ($stageOne.Count -ne 1 -or (Get-ArtifactIdentity $stages[0]).sha256 -cne $stageOne[0].sha256) { throw 'Stage one identity differs' }
    $expected = Get-Content (Join-Path $fixtures 'obligations.json') -Raw | ConvertFrom-Json
    $runtime = Join-Path $run 'instrumented-runtime.o'
    $compileRuntime = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-c',
        '-include',(Join-Path $fixtures 'allocation-probe.h'),(Join-Path $root 'runtime/bootstrap_runtime.c'),'-o',$runtime) $root 30
    $commands += $compileRuntime
    if ($compileRuntime.timedOut -or $compileRuntime.exit -ne 0) { throw $compileRuntime.stderr }
    for ($index = 0; $index -lt 2; $index++) {
        foreach ($name in @('array-copy','record-copy')) {
            $ir = Join-Path $run ("stage$($index + 1)-$name.ll")
            $record = Invoke-BoundedProcess $stages[$index] @((Join-Path $fixtures ($name + '.bas')),$ir) $root 15
            $commands += $record
            $passed = $false
            if (-not $record.timedOut -and $record.exit -eq 0 -and (Test-Path -LiteralPath $ir)) {
                $exe = $ir + '.exe'
                $link = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',$ir,
                    $selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe) $root 30
                $commands += $link
                if ($link.timedOut -or $link.exit -ne 0) { throw $link.stderr }
                $native = Invoke-BoundedProcess $exe @() $root 15
                $commands += $native
                $passed = -not $native.timedOut -and $native.exit -eq $expected.copy.exit -and $native.stdout -ceq $expected.copy.stdout -and $native.stderr -ceq $expected.copy.stderr
            }
            $obligations += [pscustomobject]@{ stage = $index + 1; name = $name; passed = $passed; emission = $record }
        }
        $stem = Join-Path $run ("stage$($index + 1)-local")
        $record = Invoke-BoundedProcess $stages[$index] @((Join-Path $fixtures 'local-array.bas'),($stem + '.ll')) $root 15
        $commands += $record
        if ($record.timedOut -or $record.exit -ne 0) { throw $record.stdout }
        $raw = [IO.File]::ReadAllText(($stem + '.ll'))
        if ([regex]::Matches($raw,'(?m)^define void @ube.p0\(\) \{').Count -ne 1 -or [regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1) { throw 'Unexpected local-array adapter signature' }
        [IO.File]::WriteAllText(($stem + '-probe.ll'),$raw.Replace('define i32 @main(', 'define i32 @storage_test_entry(') + "`n" +
            "define void @test_make_bytes() {`n  call void @ube.p0()`n  ret void`n}`n",(New-Object Text.UTF8Encoding($false)))
        $exe = $stem + '.exe'
        $link = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11',
            ($stem + '-probe.ll'),(Join-Path $fixtures 'probe.c'),$runtime,$selection.unicodeRuntime.path,'-o',$exe) $root 30
        $commands += $link
        if ($link.timedOut -or $link.exit -ne 0) { throw $link.stderr }
        $lifetime = Invoke-BoundedProcess $exe @() $root 15
        $commands += $lifetime
        $passed = -not $lifetime.timedOut -and $lifetime.exit -eq 0 -and $lifetime.stdout -match 'live-after-return-and-collect:0 ' -and $lifetime.stderr -ceq ''
        $obligations += [pscustomobject]@{ stage = $index + 1; name = 'scope-and-collection'; passed = $passed; actual = $lifetime }
        foreach ($mode in @('retry','oom')) {
            $oracle = $expected.allocationRetry
            $name = 'allocation-collection-retry'
            if ($mode -eq 'oom') { $oracle = $expected.allocationFailure; $name = 'recoverable-allocation-failure' }
            $record = Invoke-BoundedProcess $exe @($mode) $root 15
            $commands += $record
            $passed = -not $record.timedOut -and $record.exit -eq $oracle.exit -and $record.stdout -ceq "returned err:$($oracle.err) live:$($oracle.live)`n" -and $record.stderr -ceq ''
            $obligations += [pscustomobject]@{ stage = $index + 1; name = $name; passed = $passed; actual = $record }
        }
    }
    foreach ($identity in $inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Probe input changed: $($identity.path)" }
    }
    $completed = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ schema = 'ube-byte-storage-probe-1'; diagnosticCompleted = $completed; failure = $failure;
        acceptedSelection = $selection; inputs = $inputs; obligations = $obligations; commands = $commands;
        artifacts = @(Get-ChildItem -LiteralPath $run -File | ForEach-Object { Get-ArtifactIdentity $_.FullName }) } |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $completed) { throw $failure }
$passedCount = @($obligations | Where-Object passed).Count
Write-Output "Diagnostic completed: $passedCount/$($obligations.Count) target obligations passed. Failed obligations remain unqualified."
