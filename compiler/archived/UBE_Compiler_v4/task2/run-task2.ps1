[CmdletBinding()]
param([string]$OutputDirectory = '')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$taskRoot = $PSScriptRoot
$v4Root = [IO.Path]::GetFullPath((Join-Path $taskRoot '..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $v4Root '..\..\..'))
$allowedOutputRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'bootstrap\out'))
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $allowedOutputRoot 'v4-task2'
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
$allowedPrefix = $allowedOutputRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $output.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Task 2 output must remain below bootstrap/out: $output"
}
[IO.Directory]::CreateDirectory($output) | Out-Null

$utf8 = [Text.UTF8Encoding]::new($false)
$target = 'x86_64-w64-windows-gnu'
$compiler = Join-Path $repoRoot 'bootstrap\out\ube-v3-production-stage1.exe'
$clang = 'C:\Program Files\LLVM\bin\clang.exe'
$runtime = Join-Path $repoRoot 'bootstrap\out\bootstrap_runtime.o'
$unicodeRuntime = Join-Path $repoRoot 'bootstrap\out\bootstrap_unicode_runtime.o'
$project = Join-Path $v4Root 'UBE_Compiler_v4.UBE'
$caseRoot = Join-Path $v4Root 'tests\task02-shell\cases'
$validator = Join-Path $v4Root 'task0\validate-manifests.ps1'
$shell = Join-Path $output 'ube-v4-task2.exe'
$shellLlvm = Join-Path $output 'ube-v4-task2.ll'
$shellRepeatLlvm = Join-Path $output 'ube-v4-task2-repeat.ll'
$nativeLlvm = Join-Path $output 'ube-v4-task2-native-intermediate.ll'
$projectArgument = 'compiler/archived/UBE_Compiler_v4/tests/task02-shell/cases/fixtures/shell-input.UBE'
$emptyArgument = 'compiler/archived/UBE_Compiler_v4/tests/task02-shell/cases/fixtures/empty-input.UBE'
$missingArgument = 'bootstrap/out/v4-task2/missing-input.UBE'
$caseOutputRoot = Join-Path $output 'cases'
[IO.Directory]::CreateDirectory($caseOutputRoot) | Out-Null

foreach ($required in @($compiler, $clang, $runtime, $unicodeRuntime, $project, $validator)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Task 2 prerequisite is missing: $required"
    }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-RepoRelativePath([string]$Path) {
    $absolute = [IO.Path]::GetFullPath($Path)
    $prefix = $repoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the repository: $absolute"
    }
    return $absolute.Substring($prefix.Length).Replace('\', '/')
}

function ConvertTo-NativeArgument([AllowEmptyString()][string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Normalize-ProcessText([string]$Value) {
    return $Value.Replace("`r`n", "`n").TrimEnd("`r", "`n")
}

function Invoke-Shell([string[]]$Arguments) {
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $shell
    $startInfo.Arguments = (($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' ')
    $startInfo.WorkingDirectory = $repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        $process.Dispose()
        throw 'Task 2 shell process did not start'
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    if (-not $process.WaitForExit(10000)) {
        $process.Kill()
        $process.WaitForExit()
        $process.Dispose()
        throw 'Task 2 shell process exceeded the ten-second timeout'
    }
    $process.Refresh()
    $result = [ordered]@{
        exit = $process.ExitCode
        stdout = Normalize-ProcessText $stdout
        stderr = Normalize-ProcessText $stderr
        cpu_ms = [Math]::Round($process.TotalProcessorTime.TotalMilliseconds, 3)
        peak_working_set_bytes = [Int64]$process.PeakWorkingSet64
    }
    $process.Dispose()
    return $result
}

$manifests = @(Get-ChildItem -LiteralPath $caseRoot -Filter '*.case' -File | Sort-Object FullName)
if ($manifests.Count -eq 0) { throw 'Task 2 has no case manifests' }
$manifestIds = @{}
$manifestSpecs = @{}
foreach ($manifest in $manifests) {
    $validation = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -Path $manifest.FullName 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Invalid Task 2 case manifest $($manifest.FullName): $validation" }
    $idLine = Get-Content -LiteralPath $manifest.FullName | Where-Object { $_ -cmatch '^Id = "([a-z0-9-]+)"$' } | Select-Object -First 1
    if ($null -eq $idLine -or $idLine -cnotmatch '^Id = "([a-z0-9-]+)"$') { throw "Case has no parseable Id: $($manifest.FullName)" }
    $id = $Matches[1]
    if ($manifestIds.ContainsKey($id)) { throw "Duplicate Task 2 case Id: $id" }
    $manifestIds[$id] = Get-RepoRelativePath $manifest.FullName
    $fields = @{}
    foreach ($line in Get-Content -LiteralPath $manifest.FullName) {
        if ($line -cnotmatch '^([A-Za-z][A-Za-z0-9.]*) = (.+)$') { continue }
        $name = $Matches[1]
        $raw = $Matches[2]
        if ($raw -cmatch '^[0-9]+$') {
            $fields[$name] = [UInt64]::Parse($raw, [Globalization.CultureInfo]::InvariantCulture)
        }
        elseif (-not $fields.ContainsKey($name)) {
            $fields[$name] = ($raw | ConvertFrom-Json)
        }
    }
    $manifestSpecs[$id] = $fields
}

& $compiler '--emit-llvm' $project $target $shellLlvm
if ($LASTEXITCODE -ne 0) { throw 'v3 failed to emit Task 2 shell LLVM' }
& $compiler '--emit-llvm' $project $target $shellRepeatLlvm
if ($LASTEXITCODE -ne 0 -or (Get-Sha256 $shellLlvm) -cne (Get-Sha256 $shellRepeatLlvm)) {
    throw 'Task 2 shell LLVM was not deterministic across repeated builds'
}
& $compiler '--build-native' $project $target $clang $runtime $unicodeRuntime $shell $nativeLlvm
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $shell -PathType Leaf)) {
    throw 'v3 failed to build the native Task 2 shell'
}

$caseResults = [Collections.Generic.List[object]]::new()
function Test-ShellCase {
    param(
        [string]$Id,
        [string[]]$Arguments,
        [int]$ExpectedExit,
        [AllowEmptyString()][string]$ExpectedStdout,
        [AllowEmptyString()][string]$ExpectedStderr,
        [string]$ArtifactPath = '',
        [ValidateSet('required','absent','not-applicable')][string]$Artifact = 'not-applicable',
        [int]$Repeat = 1,
        [switch]$PrecreateArtifact
    )
    if (-not $manifestIds.ContainsKey($Id)) { throw "No validated manifest for case $Id" }
    $spec = $manifestSpecs[$Id]
    if ([int]$spec['Expected.Exit'] -ne $ExpectedExit -or $spec['Expected.Artifact'] -cne $Artifact -or
        [int]$spec['Repeat'] -ne $Repeat -or $spec['Expected.Stdout'] -cne $ExpectedStdout -or
        $spec['Expected.Stderr'] -cne $ExpectedStderr) {
        throw "Runner expectations drifted from the validated manifest for case $Id"
    }
    if (-not [string]::IsNullOrEmpty($ArtifactPath)) {
        $declaredArtifactPath = if ($spec.ContainsKey('Expected.ArtifactPath')) { $spec['Expected.ArtifactPath'] } else { '' }
        if ($declaredArtifactPath -cne (Get-RepoRelativePath $ArtifactPath)) {
            throw "Runner artifact path drifted from the validated manifest for case $Id"
        }
    }
    $artifactHashes = [Collections.Generic.List[string]]::new()
    $runs = [Collections.Generic.List[object]]::new()
    for ($run = 1; $run -le $Repeat; $run += 1) {
        if (-not [string]::IsNullOrEmpty($ArtifactPath)) {
            $parent = Split-Path -Parent $ArtifactPath
            [IO.Directory]::CreateDirectory($parent) | Out-Null
            if ($PrecreateArtifact) {
                [IO.File]::WriteAllText($ArtifactPath, 'stale-artifact', $utf8)
            }
        }
        $result = Invoke-Shell $Arguments
        if ($result.exit -ne $ExpectedExit -or $result.stdout -cne $ExpectedStdout -or $result.stderr -cne $ExpectedStderr) {
            throw "Case $Id run $run failed. Exit=$($result.exit) stdout=[$($result.stdout)] stderr=[$($result.stderr)]"
        }
        $exists = -not [string]::IsNullOrEmpty($ArtifactPath) -and (Test-Path -LiteralPath $ArtifactPath -PathType Leaf)
        if ($Artifact -ceq 'required' -and -not $exists) { throw "Case $Id did not publish its required artifact" }
        if ($Artifact -ceq 'absent' -and $exists) { throw "Case $Id left a false-success artifact" }
        if ($exists) { $artifactHashes.Add((Get-Sha256 $ArtifactPath)) }
        $runs.Add($result)
    }
    if (@($artifactHashes | Sort-Object -Unique).Count -gt 1) { throw "Case $Id produced nondeterministic artifact bytes" }
    $caseResults.Add([ordered]@{
        id = $Id
        manifest = $manifestIds[$Id]
        manifest_sha256 = Get-Sha256 (Join-Path $repoRoot $manifestIds[$Id])
        result = 'passed'
        expected_exit = $ExpectedExit
        arguments = $Arguments
        expected_stdout = $ExpectedStdout
        expected_stderr = $ExpectedStderr
        repetitions = $Repeat
        artifact_sha256 = if ($artifactHashes.Count -eq 0) { '' } else { $artifactHashes[0] }
        runs = $runs
    })
}

$recordPath = Join-Path $caseOutputRoot 'task2-shell-publish/output.record'
Test-ShellCase -Id 'task2-shell-check' -Arguments @($projectArgument, $target) -ExpectedExit 0 `
    -ExpectedStdout "UBE Compiler v4 shell: accepted $projectArgument for $target" -ExpectedStderr ''
Test-ShellCase -Id 'task2-shell-publish' -Arguments @('--emit-shell-record', $projectArgument, $target, (Get-RepoRelativePath $recordPath)) `
    -ExpectedExit 0 -ExpectedStdout '' -ExpectedStderr '' -ArtifactPath $recordPath -Artifact required -Repeat 3
Test-ShellCase -Id 'task2-shell-usage' -Arguments @() -ExpectedExit 2 `
    -ExpectedStdout "usage: ube-v4 [--test-fault allocation|tool|write|cancel] <project.UBE> <target-triple>`n       ube-v4 [--test-fault allocation|tool|write|cancel] --emit-shell-record <project.UBE> <target-triple> <output.record>" -ExpectedStderr ''
Test-ShellCase -Id 'task2-shell-target' -Arguments @($projectArgument, 'unsupported-target') -ExpectedExit 2 `
    -ExpectedStdout 'error UBE6001: unsupported Task 2 target: unsupported-target' -ExpectedStderr ''
$emptyOutput = Join-Path $caseOutputRoot 'task2-shell-empty-input/output.record'
Test-ShellCase -Id 'task2-shell-empty-input' -Arguments @('--emit-shell-record', $emptyArgument, $target, (Get-RepoRelativePath $emptyOutput)) -ExpectedExit 1 `
    -ExpectedStdout "$emptyArgument`: error UBE6002: project control file is empty or unreadable" -ExpectedStderr '' -ArtifactPath $emptyOutput -Artifact absent
$insideFiller = 'x' * (4096 - $projectArgument.Length - $target.Length)
Test-ShellCase -Id 'task2-shell-argument-limit-inside' -Arguments @($projectArgument, $target, $insideFiller) -ExpectedExit 2 `
    -ExpectedStdout "usage: ube-v4 [--test-fault allocation|tool|write|cancel] <project.UBE> <target-triple>`n       ube-v4 [--test-fault allocation|tool|write|cancel] --emit-shell-record <project.UBE> <target-triple> <output.record>" -ExpectedStderr ''
Test-ShellCase -Id 'task2-shell-argument-limit' -Arguments @(('x' * 4097), $target) -ExpectedExit 2 `
    -ExpectedStdout 'error UBE6000: command arguments exceed the 4096-byte session limit' -ExpectedStderr ''
$allocationOutput = Join-Path $caseOutputRoot 'task2-shell-allocation-fault/output.record'
Test-ShellCase -Id 'task2-shell-allocation-fault' -Arguments @('--test-fault', 'allocation', '--emit-shell-record', $projectArgument, $target, (Get-RepoRelativePath $allocationOutput)) -ExpectedExit 1 `
    -ExpectedStdout "$projectArgument`: error UBE6005: injected phase allocation failure" -ExpectedStderr '' -ArtifactPath $allocationOutput -Artifact absent
$toolOutput = Join-Path $caseOutputRoot 'task2-shell-tool-fault/output.record'
Test-ShellCase -Id 'task2-shell-tool-fault' -Arguments @('--test-fault', 'tool', '--emit-shell-record', $projectArgument, $target, (Get-RepoRelativePath $toolOutput)) -ExpectedExit 1 `
    -ExpectedStdout "$projectArgument`: error UBE6006: injected tool failure" -ExpectedStderr '' -ArtifactPath $toolOutput -Artifact absent
$cancelOutput = Join-Path $caseOutputRoot 'task2-shell-cancel/output.record'
Test-ShellCase -Id 'task2-shell-cancel' -Arguments @('--test-fault', 'cancel', '--emit-shell-record', $projectArgument, $target, (Get-RepoRelativePath $cancelOutput)) -ExpectedExit 1 `
    -ExpectedStdout "$projectArgument`: error UBE6004: compiler session cancelled" -ExpectedStderr '' -ArtifactPath $cancelOutput -Artifact absent
$writeFaultPath = Join-Path $caseOutputRoot 'task2-shell-write-fault/output.record'
Test-ShellCase -Id 'task2-shell-write-fault' -Arguments @('--test-fault', 'write', '--emit-shell-record', $projectArgument, $target, (Get-RepoRelativePath $writeFaultPath)) `
    -ExpectedExit 1 -ExpectedStdout "$(Get-RepoRelativePath $writeFaultPath): error UBE6007: injected output publication failure" -ExpectedStderr '' `
    -ArtifactPath $writeFaultPath -Artifact absent -PrecreateArtifact
$missingOutput = Join-Path $caseOutputRoot 'task2-shell-missing-input/output.record'
Test-ShellCase -Id 'task2-shell-missing-input' -Arguments @('--emit-shell-record', $missingArgument, $target, (Get-RepoRelativePath $missingOutput)) -ExpectedExit 66 `
    -ExpectedStdout '' -ExpectedStderr "UBE runtime: cannot open for reading: $missingArgument" -ArtifactPath $missingOutput -Artifact absent
$hostCleanupPath = $caseOutputRoot
Test-ShellCase -Id 'task2-shell-cleanup-host-failure' -Arguments @('--emit-shell-record', $projectArgument, $target, (Get-RepoRelativePath $hostCleanupPath)) `
    -ExpectedExit 1 -ExpectedStdout "$(Get-RepoRelativePath $hostCleanupPath): error UBE6008: could not remove the previous output artifact" -ExpectedStderr ''

$sortedCases = @($caseResults | Sort-Object { $_.id })
$sourcePaths = @($project) + @(Get-Content -LiteralPath $project | Where-Object { $_ -cmatch '^Source = "(.+)"$' } | ForEach-Object {
    if ($_ -cmatch '^Source = "(.+)"$') { Join-Path $v4Root $Matches[1] }
})
$supportManifest = Join-Path $v4Root 'support\UBECompilerSupport.UBE'
$supportSourcePaths = @($supportManifest) + @(Get-Content -LiteralPath $supportManifest | Where-Object { $_ -cmatch '^Source = "(.+)"$' } | ForEach-Object {
    if ($_ -cmatch '^Source = "(.+)"$') { Join-Path (Split-Path -Parent $supportManifest) $Matches[1] }
})
$evidence = [ordered]@{
    format = 'ube-v4-verified-build-1'
    roadmap_task = 2
    build_identity = 'v4-task2-session-shell-1'
    status = 'passed'
    bootstrap = [ordered]@{ compiler = Get-RepoRelativePath $compiler; sha256 = Get-Sha256 $compiler }
    inputs = [ordered]@{
        sources = @($sourcePaths | ForEach-Object { [ordered]@{ path = Get-RepoRelativePath $_; sha256 = Get-Sha256 $_ } })
        compiler_support_sources = @($supportSourcePaths | ForEach-Object { [ordered]@{ path = Get-RepoRelativePath $_; sha256 = Get-Sha256 $_ } })
        case_manifests = @($manifests | ForEach-Object { [ordered]@{ path = Get-RepoRelativePath $_.FullName; sha256 = Get-Sha256 $_.FullName } })
        dependency_manifest = [ordered]@{ path = 'compiler/archived/UBE_Compiler_v4/TASK1_DEPENDENCIES.json'; sha256 = Get-Sha256 (Join-Path $v4Root 'TASK1_DEPENDENCIES.json') }
        grammar = [ordered]@{ path = 'lang-doc/grammar/ube.ebnf'; sha256 = Get-Sha256 (Join-Path $repoRoot 'lang-doc\grammar\ube.ebnf') }
        library = @('UBECompilerSupport@0.2.0-v4t4')
        available_not_linked = @('UBECore@0.1.0-rp8')
        intrinsic = 'ube-intrinsic-abi-1; 15 compiler-support hooks; zero new ABI names'
        runtime = @((Get-Sha256 $runtime), (Get-Sha256 $unicodeRuntime))
    }
    environment = [ordered]@{
        host = 'windows-x86-64'
        target = $target
        os = [Environment]::OSVersion.VersionString
        architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        clang = (& $clang '--version' | Select-Object -First 1)
    }
    execution = [ordered]@{ requested_jobs = 1; effective_jobs = 1; schedule = 'sequential-reference'; timeout_ms = 10000 }
    cases = $sortedCases
    measurements = [ordered]@{
        case_count = $sortedCases.Count
        phase_work_units = 3
        shell_llvm_bytes = (Get-Item -LiteralPath $shellLlvm).Length
        shell_native_bytes = (Get-Item -LiteralPath $shell).Length
        maximum_case_cpu_ms = ($sortedCases.runs.cpu_ms | Measure-Object -Maximum).Maximum
        maximum_case_peak_working_set_bytes = ($sortedCases.runs.peak_working_set_bytes | Measure-Object -Maximum).Maximum
        native_container_reproducibility = 'not-applicable until the Task 9/12 linker and fixed-point gates'
    }
    artifacts = [ordered]@{
        shell = [ordered]@{ path = Get-RepoRelativePath $shell; sha256 = Get-Sha256 $shell }
        llvm = [ordered]@{ path = Get-RepoRelativePath $shellLlvm; sha256 = Get-Sha256 $shellLlvm }
        deterministic_record_sha256 = Get-Sha256 $recordPath
    }
    cleanup = [ordered]@{
        live_resources = 0
        false_success_artifacts = 0
        write_fault_artifact_absent = -not (Test-Path -LiteralPath $writeFaultPath)
        host_cleanup_rejection_preserved_directory = Test-Path -LiteralPath $hostCleanupPath -PathType Container
    }
}
$evidencePath = Join-Path $output 'verified-build.json'
$temporaryEvidence = Join-Path $output ".verified-build-$PID.tmp"
[IO.File]::WriteAllText($temporaryEvidence, ($evidence | ConvertTo-Json -Depth 10) + "`n", $utf8)
Move-Item -LiteralPath $temporaryEvidence -Destination $evidencePath -Force
Write-Host "Task 2 shell gate passed: $evidencePath"
