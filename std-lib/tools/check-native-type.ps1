param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $PSScriptRoot 'value-probes.ps1')
. (Join-Path $PSScriptRoot 'native-type-cases.ps1')
$fixtures = Join-Path $root 'std-lib/tests/native-type/proposed'
$suite = Get-Content (Join-Path $fixtures 'cases.json') -Raw | ConvertFrom-Json
$run = Join-Path $root ('bootstrap/out/native-type/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands = New-Object 'System.Collections.Generic.List[object]'
$checks = New-Object 'System.Collections.Generic.List[object]'
$selection = $null
$stageOneIdentity = $null
$inputs = @()
$success = $false
$failure = $null
$diagnostics = @{
    'managed-representation'='UBE3231'; 'native-field'='UBE3231';
    'wrong-pack-parameter'='UBE3232'; 'byref-pack'='UBE3232'; 'wrong-unpack-result'='UBE3232';
    'unknown-role'='UBE3230'; 'missing-binding'='UBE3232'; 'wrong-binding-target'='UBE3230';
    'duplicate-binding'='UBE3230'; 'conflicting-role'='UBE3230'; 'second-pack'='UBE3232';
    'implicit-storage-conversion'='UBE3208'; 'payload-field-access'='UBE3200';
    'representation-byref'='UBE3203'; 'ordering'='UBE3200';
    'negative-pack-constant'='UBE3220'; 'large-pack-constant'='UBE3220';
    'different-native-type'='UBE3208'; 'different-native-byref'='UBE3203';
    'self-representation'='UBE3231'; 'nested-representation'='UBE3231';
    'wrong-pack-result'='UBE3232'; 'different-native-equality'='UBE3200';
    'unterminated-native-type'='UBE2111'; 'intrinsic-body'='UBE3230';
    'ordinary-empty-record'='UBE2113'; 'implicit-unpack'='UBE3201'; 'primitive-name-collision'='UBE3231';
    'registered-name-without-binding'='UBE3232'; 'registered-signature-mismatch'='UBE3232';
    'cross-module-binding'='UBE3232'; 'cross-module-type-end'='UBE3231'; 'cross-module-intrinsic-end'='UBE3232';
    'implicit-print'='UBE3233'; 'implicit-condition'='UBE3210'; 'implicit-arithmetic'='UBE3200'
}
try {
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($identity in @($selection.manifest,$selection.compiler,$selection.runtime,$selection.unicodeRuntime,$selection.clang)) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Selected v2 artifact changed: $($identity.path)" }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected v2 has not passed its source-built gate' }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted compiler input changed: $($identity.path)" }
    }
    $stage1 = Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
    $stageOneIdentity = @($accepted.artifacts | Where-Object { $_.path -ceq $stage1 })
    if ($stageOneIdentity.Count -ne 1 -or (Get-ArtifactIdentity $stage1).sha256 -cne $stageOneIdentity[0].sha256) { throw 'Stage-one identity differs' }
    $stages = @($stage1,$selection.compiler.path)
    $inputPaths = @((Join-Path $PSScriptRoot 'check-native-type.ps1'),(Join-Path $PSScriptRoot 'native-type-cases.ps1'),
        (Join-Path $PSScriptRoot 'value-probes.ps1'),(Join-Path $root 'bootstrap/tools/verification.ps1'),
        (Join-Path $root 'std-lib/tests/native-type/baseline/layout-and-error.c')) +
        @(Get-ChildItem -LiteralPath $fixtures -File | ForEach-Object { $_.FullName })
    $inputs = @($inputPaths | ForEach-Object { Get-ArtifactIdentity $_ })
    $rendered = @(Write-NativeTypeCases $fixtures (Join-Path $run 'cases') $suite)
    foreach ($render in $rendered) {
        $case = $render.specification
        $records = @()
        $hashes = @()
        for ($index = 0; $index -lt $stages.Count; $index++) {
            $stageNumber = $index + 1
            $stem = Join-Path $run ($case.name + '-stage' + $stageNumber)
            $ir = $stem + '.ll'
            $record = Invoke-BoundedProcess $stages[$index] @($render.project,$ir) $root 15
            $commands.Add($record)
            if ($record.timedOut) { throw "Native case timed out: $($case.name)" }
            $records += $record
            if ($case.expect -eq 'reject') {
                if (-not $diagnostics.ContainsKey($case.name)) { throw "No diagnostic oracle: $($case.name)" }
                if ($record.exit -ne 1 -or (Test-Path -LiteralPath $ir) -or ($record.stdout + $record.stderr) -notmatch ('error ' + $diagnostics[$case.name] + ':')) {
                    throw "Native rejection failed: $($case.name): $($record | ConvertTo-Json -Compress -Depth 5)"
                }
            } else {
                if ($record.exit -ne 0 -or -not (Test-Path -LiteralPath $ir)) { throw "Native emission failed: $($case.name): $($record.stdout)$($record.stderr)" }
                $raw = [IO.File]::ReadAllText($ir)
                if (Get-ProofOption $case 'requiresPackInstructions' $true) {
                    foreach ($instruction in $suite.nativeOracle.requiredIrInstructions) {
                        if ($raw -notmatch ('= ' + [regex]::Escape($instruction) + ' ')) { throw "Missing native instruction: $($case.name): $instruction" }
                    }
                }
                if ($raw -match '(?m)^\s+.*call.*@(malloc|calloc|realloc|ube_array_redim|ube_gc_allocate)\(') { throw 'Unexpected allocation call in scalar native proof' }
                $payload = @{Byte='i8'; Integer='i16'; Long='i32'}[$case.storage]
                $stdout = Get-ProofOption $case 'stdout' $suite.nativeOracle.stdout
                $stdout += Get-ProofOption $case 'stdoutSuffix' ''
                $finalErr = Get-ProofOption $case 'finalErr' $suite.nativeOracle.finalErr
                $expected = "layout:$($case.size):$($case.alignment)`n" + $stdout + "err:$finalErr`n"
                $null = Invoke-ValueLayoutProbe -Root $root -Selection $selection -RawIr $ir -OutputStem $stem -PayloadType $payload -Size $case.size -Alignment $case.alignment -InitialErr $suite.nativeOracle.initialErr -FinalErr $finalErr -ExpectedStdout $expected -ExpectedExit $suite.nativeOracle.exit -Adapter (Join-Path $root 'std-lib/tests/native-type/baseline/layout-and-error.c') -CommandLog $commands
                $hashes += (Get-ArtifactIdentity $ir).sha256
                $checks.Add([pscustomobject]@{ name = $case.name; stage = $stageNumber; assertion = 'native values/layout/Err/IR operations'; passed = $true })
            }
        }
        if ($case.expect -eq 'reject') {
            if ($records[0].stdout -cne $records[1].stdout -or $records[0].stderr -cne $records[1].stderr) { throw "Stage diagnostics differ: $($case.name)" }
            $checks.Add([pscustomobject]@{ name = $case.name; assertion = 'exact diagnostic category, no artifact, identical stage diagnostics'; passed = $true })
        } else {
            if ($hashes[0] -cne $hashes[1]) { throw "Stage LLVM differs: $($case.name)" }
            $checks.Add([pscustomobject]@{ name = $case.name; assertion = 'byte-identical raw LLVM'; passed = $true })
        }
        Write-Output ("PASS $($case.name): $($case.expect)")
    }
    foreach ($identity in $inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw 'Native proof input changed during execution' }
    }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ schema = 'ube-native-value-proof-1'; success = $success; failure = $failure;
        acceptedSelection = $selection; stageOne = $stageOneIdentity; inputs = $inputs;
        artifacts = @(Get-ChildItem -LiteralPath $run -Recurse -File | ForEach-Object { Get-ArtifactIdentity $_.FullName });
        checks = @($checks.ToArray()); commands = @($commands.ToArray()) } |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) native-value acceptance assertions."
