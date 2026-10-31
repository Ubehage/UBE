param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $PSScriptRoot 'value-probes.ps1')
$fixtures = Join-Path $root 'std-lib/tests/native-type/baseline'
$suite = Get-Content -LiteralPath (Join-Path $fixtures 'cases.json') -Raw | ConvertFrom-Json
$run = Join-Path $root ('bootstrap/out/value-record/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands = New-Object 'System.Collections.Generic.List[object]'
$checks = New-Object 'System.Collections.Generic.List[object]'
$inputs = @()
$success = $false
$failure = $null
$selection = $null
$stageOneIdentity = $null
function Invoke-Recorded([string]$File, [string[]]$Values = @()) {
    $record = Invoke-BoundedProcess $File $Values $root 30
    $commands.Add($record)
    if ($record.timedOut) { throw "Process timed out: $File" }
    return $record
}
try {
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($identity in @($selection.manifest,$selection.compiler,$selection.runtime,$selection.unicodeRuntime,$selection.clang)) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Selected v2 artifact changed: $($identity.path)" }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected v2 did not pass its source-built gate' }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted compiler input changed: $($identity.path)" }
    }
    $stage1 = Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
    $identity = @($accepted.artifacts | Where-Object { $_.path -ceq $stage1 })
    if ($identity.Count -ne 1 -or (Get-ArtifactIdentity $stage1).sha256 -cne $identity[0].sha256) { throw 'Stage-one identity differs' }
    $stageOneIdentity = $identity[0]
    $stages = @($stage1, $selection.compiler.path)
    $paths = @((Join-Path $PSScriptRoot 'check-value-record.ps1'), (Join-Path $PSScriptRoot 'value-probes.ps1'),
        (Join-Path $root 'bootstrap/tools/verification.ps1')) +
        @(Get-ChildItem -LiteralPath $fixtures -File | ForEach-Object { $_.FullName })
    $inputs = @($paths | ForEach-Object { Get-ArtifactIdentity $_ })
    $renamed = Join-Path $run 'renamed'
    New-Item -ItemType Directory -Path $renamed | Out-Null
    foreach ($file in @('Main.bas','ValueRecord.bas','ValueRecord.UBE')) {
        $text = [IO.File]::ReadAllText((Join-Path $fixtures $file))
        $text = $text.Replace('RecordOctet','RenamedOctet').Replace('MakeRecord','ConstructValue').Replace('ChangeCopy','MutateArgument').Replace('ChangeStorage','MutateCaller').Replace('TrySetRecord','TryWriteValue')
        [IO.File]::WriteAllText((Join-Path $renamed $file),$text,(New-Object Text.UTF8Encoding($false)))
    }
    foreach ($variant in @($fixtures,$renamed)) {
        $name = 'original'
        if ($variant -ceq $renamed) { $name = 'renamed' }
        $hashes = @()
        for ($index = 0; $index -lt $stages.Count; $index++) {
            $stageNumber = $index + 1
            $ir = Join-Path $run ("$name-stage$stageNumber.ll")
            $emission = Invoke-Recorded $stages[$index] @((Join-Path $variant $suite.native.project),$ir)
            if ($emission.exit -ne 0 -or -not (Test-Path -LiteralPath $ir)) { throw "Record emission failed: $($emission.stdout)$($emission.stderr)" }
            $raw = [IO.File]::ReadAllText($ir)
            if ($raw -notmatch 'define %ube\.type\.\d+ @') { throw 'No record-valued procedure result found' }
            $null = Invoke-ValueLayoutProbe -Root $root -Selection $selection -RawIr $ir -OutputStem (Join-Path $run "$name-stage$stageNumber") -Adapter (Join-Path $fixtures 'layout-and-error.c') -ExpectedStdout $suite.native.stdout -ExpectedExit $suite.native.exit -CommandLog $commands
            $hashes += (Get-ArtifactIdentity $ir).sha256
            $checks.Add([pscustomobject]@{ variant = $name; stage = $stageNumber;
                assertion = 'exact native values, target size/alignment and stale Err'; passed = $true })
        }
        if ($hashes[0] -cne $hashes[1]) { throw 'Stages emitted different raw record LLVM' }
        $checks.Add([pscustomobject]@{ variant = $name; assertion = 'byte-identical raw LLVM'; passed = $true })
    }
    foreach ($case in $suite.negative) {
        $records = @()
        for ($index = 0; $index -lt $stages.Count; $index++) {
            $stageNumber = $index + 1
            $ir = Join-Path $run ("negative-stage$stageNumber-" + $case.source + '.ll')
            $record = Invoke-Recorded $stages[$index] @((Join-Path $fixtures $case.source),$ir)
            if ($record.exit -ne 1 -or (Test-Path -LiteralPath $ir) -or
                ($record.stdout + $record.stderr).IndexOf($case.diagnostic,[StringComparison]::Ordinal) -lt 0) {
                throw "Record rejection failed: $($record | ConvertTo-Json -Compress -Depth 5)"
            }
            $records += $record
        }
        if ($records[0].stdout -cne $records[1].stdout -or $records[0].stderr -cne $records[1].stderr) { throw 'Rejection diagnostics differ' }
        $checks.Add([pscustomobject]@{ source = $case.source; assertion = 'controlled rejection, no artifact, identical stage diagnostics'; passed = $true })
    }
    foreach ($identity in $inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw 'Proof input changed during execution' }
    }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ scope = 'existing field-only records; proposed native mechanism not implemented';
        success = $success; failure = $failure; inputs = $inputs;
        acceptedSelection = $selection; stageOne = $stageOneIdentity;
        artifacts = @(Get-ChildItem -LiteralPath $run -Recurse -File | ForEach-Object { Get-ArtifactIdentity $_.FullName });
        checks = @($checks.ToArray()); commands = @($commands.ToArray()) } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) record-baseline assertions. Opaque native metadata remains unproved."
