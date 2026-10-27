param(
    [int]$Repetitions = 3,
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$taskRoot = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $taskRoot '..\..\..')).Path
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot 'bootstrap\out\v4-task0'
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
$allowedOutputRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'bootstrap\out'))
$allowedPrefix = $allowedOutputRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $output.StartsWith($allowedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Task 0 output must remain below bootstrap/out: $output"
}
if ($Repetitions -lt 2 -or $Repetitions -gt 20) {
    throw 'Task 0 repetitions must be from 2 through 20'
}

$utf8 = [Text.UTF8Encoding]::new($false)
$prototypeSource = Join-Path $taskRoot 'prototype\parser_prototype.cpp'
$prototypeExe = Join-Path $output 'parser_prototype.exe'
$caseRoot = Join-Path $taskRoot 'cases'
$parserCaseRoot = Join-Path $caseRoot 'parser'
$validator = Join-Path $taskRoot 'validate-manifests.ps1'
$v3 = Join-Path $repoRoot 'compiler\release-previews\ube-v3-rp8-windows-x86_64-x86_64-w64-windows-gnu.exe'
$target = 'x86_64-w64-windows-gnu'

function Get-RelativeRepoPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $absolute = [IO.Path]::GetFullPath($Path)
    $rootPrefix = $repoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside the repository: $absolute"
    }
    return $absolute.Substring($rootPrefix.Length).Replace('\', '/')
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )
    [IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Invoke-ManifestValidation {
    param([string]$Path, [int]$ExpectedExit, [string]$ExpectedText)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $result = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator -Path $Path 2>&1
        $exit = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    $text = ($result | ForEach-Object { $_.ToString() }) -join "`n"
    if ($exit -ne $ExpectedExit) {
        throw "Manifest validator exit $exit, expected $ExpectedExit for $Path`: $text"
    }
    if (-not [string]::IsNullOrEmpty($ExpectedText) -and $text -notmatch [regex]::Escape($ExpectedText)) {
        throw "Manifest validator output did not contain '$ExpectedText' for $Path`: $text"
    }
    return [ordered]@{
        path = Get-RelativeRepoPath $Path
        expected_exit = $ExpectedExit
        actual_exit = $exit
        output_sha256 = if ($text.Length -eq 0) { '' } else {
            $bytes = $utf8.GetBytes($text)
            $sha = [Security.Cryptography.SHA256]::Create()
            try { ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') } finally { $sha.Dispose() }
        }
    }
}

function New-GeneratedSource {
    param([string]$Name, [int]$Statements, [int]$ParenthesisDepth)
    $path = Join-Path $output "$Name.bas"
    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"$Name`"`n`nPublic Sub Main()`n    Dim Index As Long`n")
    if ($ParenthesisDepth -gt 0) {
        [void]$builder.Append('    Print ')
        [void]$builder.Append(('(' * $ParenthesisDepth))
        [void]$builder.Append('"depth"')
        [void]$builder.Append((')' * $ParenthesisDepth))
        [void]$builder.Append("`n")
    }
    for ($index = 0; $index -lt $Statements; $index += 1) {
        [void]$builder.Append("    Index = Index + 1`n")
    }
    [void]$builder.Append("End Sub`n")
    Write-Utf8File -Path $path -Content $builder.ToString()
    return $path
}

function ConvertTo-NativeArgument {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
        return $Value
    }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-Prototype {
    param([string]$Mode, [string]$InputPath, [string]$Name, [int]$Run)
    $arguments = @('--mode', $Mode, '--input', $InputPath, '--max-depth', '64')
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $prototypeExe
    $startInfo.Arguments = (($arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        $process.Dispose()
        throw "Prototype process did not start for $Name/$Mode"
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $cpuMilliseconds = $process.TotalProcessorTime.TotalMilliseconds
    $peakWorkingSet = $process.PeakWorkingSet64
    $process.Dispose()
    if ($exitCode -ne 0) {
        throw "Prototype failed for $Name/$Mode with exit $exitCode`: $stderr"
    }
    try {
        $measurement = $stdout | ConvertFrom-Json
    }
    catch {
        throw "Prototype emitted malformed JSON for $Name/$Mode`: $stdout"
    }
    if ($measurement.format -cne 'ube-v4-task0-parser-measurement-1') {
        throw "Prototype emitted the wrong format for $Name/$Mode"
    }
    return [ordered]@{
        name = $Name
        mode = $Mode
        run = $Run
        input = Get-RelativeRepoPath $InputPath
        input_sha256 = Get-Sha256 $InputPath
        accepted = [bool]$measurement.accepted
        input_bytes = [int64]$measurement.input_bytes
        tokens = [int64]$measurement.tokens
        nodes = [int64]$measurement.nodes
        edges = [int64]$measurement.edges
        syntax_bytes = [int64]$measurement.syntax_bytes
        nodes_per_token = if ($measurement.tokens -eq 0) { 0.0 } else { [double]$measurement.nodes / [double]$measurement.tokens }
        bytes_per_token = if ($measurement.tokens -eq 0) { 0.0 } else { [double]$measurement.syntax_bytes / [double]$measurement.tokens }
        work = [int64]$measurement.work
        work_per_token = if ($measurement.tokens -eq 0) { 0.0 } else { [double]$measurement.work / [double]$measurement.tokens }
        recoveries = [int64]$measurement.recoveries
        max_depth = [int64]$measurement.max_depth
        grammar_coverage = [int64]$measurement.grammar_coverage
        span_hash = $measurement.span_hash.ToString().ToUpperInvariant()
        semantic_hash = $measurement.semantic_hash.ToString().ToUpperInvariant()
        diagnostics = @($measurement.diagnostics)
        prototype_elapsed_us = [int64]$measurement.elapsed_us
        process_cpu_ms = [math]::Round($cpuMilliseconds, 3)
        peak_working_set_bytes = [int64]$peakWorkingSet
        stderr = $stderr
    }
}

function Get-StableMeasurement {
    param($Measurement)
    return [ordered]@{
        accepted = $Measurement.accepted
        input_bytes = $Measurement.input_bytes
        tokens = $Measurement.tokens
        nodes = $Measurement.nodes
        edges = $Measurement.edges
        syntax_bytes = $Measurement.syntax_bytes
        work = $Measurement.work
        recoveries = $Measurement.recoveries
        max_depth = $Measurement.max_depth
        grammar_coverage = $Measurement.grammar_coverage
        span_hash = $Measurement.span_hash
        semantic_hash = $Measurement.semantic_hash
        diagnostics = @($Measurement.diagnostics)
        stderr = $Measurement.stderr
    }
}

function Assert-EqualJson {
    param($Left, $Right, [string]$Purpose)
    $leftJson = $Left | ConvertTo-Json -Depth 10 -Compress
    $rightJson = $Right | ConvertTo-Json -Depth 10 -Compress
    if ($leftJson -cne $rightJson) {
        throw "$Purpose mismatch`nLEFT: $leftJson`nRIGHT: $rightJson"
    }
}

function Assert-VerifiedBuildShape {
    param($Record, [string]$Purpose)
    $expected = @(
        'format', 'roadmap_task', 'build_identity', 'status', 'bootstrap',
        'inputs', 'environment', 'execution', 'cases', 'measurements',
        'artifacts', 'cleanup'
    )
    $actual = @($Record.PSObject.Properties.Name)
    if (($actual -join '|') -cne ($expected -join '|')) {
        throw "$Purpose has incorrect top-level fields/order: $($actual -join ', ')"
    }
    if ($Record.format -cne 'ube-v4-verified-build-1') {
        throw "$Purpose has unsupported format $($Record.format)"
    }
    if (@('passed', 'failed', 'cancelled') -cnotcontains $Record.status) {
        throw "$Purpose has invalid status $($Record.status)"
    }
    if ($null -eq $Record.cleanup -or $null -eq $Record.cases -or $null -eq $Record.measurements) {
        throw "$Purpose omits required evidence collections"
    }
}

function Test-Task0Documentation {
    $v4Root = Split-Path -Parent $taskRoot
    foreach ($markdown in Get-ChildItem -LiteralPath $v4Root -Recurse -Filter '*.md' -File) {
        $contents = Get-Content -Raw -LiteralPath $markdown.FullName
        foreach ($match in [regex]::Matches($contents, '\[[^\]]*\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value
            if ($target -match '^[a-z]+://' -or $target.StartsWith('#')) {
                continue
            }
            $pathPart = ($target -split '#', 2)[0].Trim('<', '>')
            if ($pathPart.Length -eq 0) {
                continue
            }
            $linkedPath = [IO.Path]::GetFullPath((Join-Path $markdown.DirectoryName $pathPart))
            if (-not (Test-Path -LiteralPath $linkedPath)) {
                throw "Broken local Markdown link in $($markdown.FullName): $target"
            }
        }
    }
    $roadmap = Get-Content -Raw -LiteralPath (Join-Path $v4Root 'ROADMAP.md')
    $task0Start = $roadmap.IndexOf('### Task 0:', [StringComparison]::Ordinal)
    $task1Start = $roadmap.IndexOf('### Task 1:', [StringComparison]::Ordinal)
    if ($task0Start -lt 0 -or $task1Start -le $task0Start) {
        throw 'Cannot locate the Task 0 roadmap section'
    }
    $task0Section = $roadmap.Substring($task0Start, $task1Start - $task0Start)
    if ($task0Section -match '(?m)^- \[(?: |~|!)\]') {
        throw 'Task 0 roadmap contains an incomplete or blocked item'
    }
    # Later roadmap tasks are allowed to create production files. Task 0 stays
    # isolated because its explicit input inventory below contains only the
    # prototype, grammar, manifests, and fixtures; it never consumes v4 source.
}

function Publish-JsonAtomically {
    param([string]$Path, $Record, [switch]$InjectBeforeRename)
    $temporary = "$Path.partial"
    $json = $Record | ConvertTo-Json -Depth 12
    Write-Utf8File -Path $temporary -Content ($json + "`n")
    try {
        if ($InjectBeforeRename) {
            throw 'injected publication failure before rename'
        }
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    catch {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
        throw
    }
}

try {
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    $compiler = Get-Command g++ -ErrorAction Stop
    $compilerVersion = (& $compiler.Source --version | Select-Object -First 1).ToString()
    Test-Task0Documentation

    $manifestResults = @(
        Invoke-ManifestValidation -Path (Join-Path $caseRoot 'format\minimal.case') -ExpectedExit 0 -ExpectedText 'task0-format-minimal'
        Invoke-ManifestValidation -Path (Join-Path $parserCaseRoot 'parser-comparison.case') -ExpectedExit 0 -ExpectedText 'task0-parser-comparison'
        Invoke-ManifestValidation -Path (Join-Path $caseRoot 'format\duplicate-id.case.invalid') -ExpectedExit 1 -ExpectedText 'duplicate singleton field Id'
        Invoke-ManifestValidation -Path (Join-Path $caseRoot 'format\escaping-path.case.invalid') -ExpectedExit 1 -ExpectedText 'escapes the case directory'
    )
    $exampleRecord = Get-Content -Raw -LiteralPath (Join-Path $taskRoot 'formats\verified-build.example.json') | ConvertFrom-Json
    Assert-VerifiedBuildShape -Record $exampleRecord -Purpose 'checked-in verified-build example'

    $compileOutput = & $compiler.Source '-std=c++17' '-Wall' '-Wextra' '-Wpedantic' '-Werror' `
        $prototypeSource '-o' $prototypeExe 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Task 0 prototype failed to compile: $($compileOutput -join "`n")"
    }

    $emptyPath = Join-Path $output 'Task0Empty.bas'
    Write-Utf8File -Path $emptyPath -Content ''
    $generatedInputs = @(
        [ordered]@{ name = 'empty'; path = $emptyPath; accepted = $false },
        [ordered]@{ name = 'depth-32'; path = New-GeneratedSource -Name 'Task0Depth32' -Statements 0 -ParenthesisDepth 32; accepted = $true },
        [ordered]@{ name = 'depth-65'; path = New-GeneratedSource -Name 'Task0Depth65' -Statements 0 -ParenthesisDepth 65; accepted = $false },
        [ordered]@{ name = 'scale-100'; path = New-GeneratedSource -Name 'Task0Scale100' -Statements 100 -ParenthesisDepth 0; accepted = $true },
        [ordered]@{ name = 'scale-1000'; path = New-GeneratedSource -Name 'Task0Scale1000' -Statements 1000 -ParenthesisDepth 0; accepted = $true },
        [ordered]@{ name = 'scale-5000'; path = New-GeneratedSource -Name 'Task0Scale5000' -Statements 5000 -ParenthesisDepth 0; accepted = $true }
    )
    $inputs = @(
        [ordered]@{ name = 'minimal'; path = Join-Path $parserCaseRoot 'minimal.bas'; accepted = $true },
        [ordered]@{ name = 'representative'; path = Join-Path $parserCaseRoot 'representative.bas'; accepted = $true },
        [ordered]@{ name = 'malformed-truncated'; path = Join-Path $parserCaseRoot 'malformed-truncated.bas'; accepted = $false }
    ) + $generatedInputs

    $measurements = [Collections.Generic.List[object]]::new()
    foreach ($input in $inputs) {
        foreach ($mode in @('table', 'hybrid')) {
            $firstStable = $null
            for ($run = 1; $run -le $Repetitions; $run += 1) {
                $measurement = Invoke-Prototype -Mode $mode -InputPath $input.path -Name $input.name -Run $run
                if ($measurement.accepted -ne $input.accepted) {
                    throw "Unexpected acceptance for $($input.name)/$mode`: $($measurement.accepted)"
                }
                $stable = Get-StableMeasurement $measurement
                if ($null -eq $firstStable) {
                    $firstStable = $stable
                } else {
                    Assert-EqualJson -Left $firstStable -Right $stable -Purpose "deterministic rerun $($input.name)/$mode"
                }
                $measurements.Add([PSCustomObject]$measurement)
            }
        }
        $table = $measurements | Where-Object { $_.name -ceq $input.name -and $_.mode -ceq 'table' } | Select-Object -First 1
        $hybrid = $measurements | Where-Object { $_.name -ceq $input.name -and $_.mode -ceq 'hybrid' } | Select-Object -First 1
        Assert-EqualJson -Left ([ordered]@{
            accepted = $table.accepted; recoveries = $table.recoveries; span_hash = $table.span_hash
            semantic_hash = $table.semantic_hash; diagnostics = @($table.diagnostics)
        }) -Right ([ordered]@{
            accepted = $hybrid.accepted; recoveries = $hybrid.recoveries; span_hash = $hybrid.span_hash
            semantic_hash = $hybrid.semantic_hash; diagnostics = @($hybrid.diagnostics)
        }) -Purpose "parser-mode observable parity $($input.name)"
    }

    $representativeTable = $measurements | Where-Object { $_.name -ceq 'representative' -and $_.mode -ceq 'table' } | Select-Object -First 1
    $representativeHybrid = $measurements | Where-Object { $_.name -ceq 'representative' -and $_.mode -ceq 'hybrid' } | Select-Object -First 1
    if ($representativeHybrid.syntax_bytes -ge [math]::Floor($representativeTable.syntax_bytes * 0.5)) {
        throw 'Hybrid representation did not reduce representative syntax bytes by at least 50%'
    }
    if ($representativeHybrid.nodes -ge [math]::Floor($representativeTable.nodes * 0.5)) {
        throw 'Hybrid representation did not reduce representative syntax nodes by at least 50%'
    }
    if ($representativeHybrid.grammar_coverage -lt 15) {
        throw 'Representative fixture did not exercise at least 15 prototype productions'
    }

    foreach ($mode in @('table', 'hybrid')) {
        $scale = @($measurements | Where-Object { $_.mode -ceq $mode -and $_.run -eq 1 -and $_.name -like 'scale-*' })
        $minimum = ($scale | Measure-Object -Property work_per_token -Minimum).Minimum
        $maximum = ($scale | Measure-Object -Property work_per_token -Maximum).Maximum
        if ($minimum -le 0 -or ($maximum / $minimum) -gt 1.20) {
            throw "$mode parser work/token scaling exceeded the 1.20 bound: min=$minimum max=$maximum"
        }
    }

    $v3Cases = @(
        [ordered]@{ name = 'minimal'; project = Join-Path $parserCaseRoot 'minimal.UBE'; expected_exit = 0 },
        [ordered]@{ name = 'representative'; project = Join-Path $parserCaseRoot 'representative.UBE'; expected_exit = 0 },
        [ordered]@{ name = 'malformed-truncated'; project = Join-Path $parserCaseRoot 'malformed-truncated.UBE'; expected_exit = 1 }
    )
    $v3Results = [Collections.Generic.List[object]]::new()
    foreach ($case in $v3Cases) {
        $v3Output = & $v3 '--dump-syntax' $case.project $target 2>&1
        $v3Exit = $LASTEXITCODE
        $v3Text = ($v3Output | ForEach-Object { $_.ToString() }) -join "`n"
        if ($v3Exit -ne $case.expected_exit) {
            throw "V3 differential exit mismatch for $($case.name): $v3Exit expected $($case.expected_exit)`n$v3Text"
        }
        $prototypeAccepted = ($measurements | Where-Object { $_.name -ceq $case.name -and $_.mode -ceq 'hybrid' } | Select-Object -First 1).accepted
        if ($prototypeAccepted -ne ($v3Exit -eq 0)) {
            throw "V3/prototype acceptance mismatch for $($case.name)"
        }
        $v3Results.Add([PSCustomObject][ordered]@{
            name = $case.name
            project = Get-RelativeRepoPath $case.project
            project_sha256 = Get-Sha256 $case.project
            exit = $v3Exit
            output_sha256 = if ($v3Text.Length -eq 0) { '' } else {
                $bytes = $utf8.GetBytes($v3Text)
                $sha = [Security.Cryptography.SHA256]::Create()
                try { ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') } finally { $sha.Dispose() }
            }
        })
    }

    $faultDirectory = Join-Path $output 'publication-fault'
    New-Item -ItemType Directory -Force -Path $faultDirectory | Out-Null
    $faultTarget = Join-Path $faultDirectory 'must-not-exist.json'
    if (Test-Path -LiteralPath $faultTarget) { Remove-Item -LiteralPath $faultTarget -Force }
    $publicationFailureObserved = $false
    try {
        Publish-JsonAtomically -Path $faultTarget -Record ([ordered]@{ format = 'fault-probe' }) -InjectBeforeRename
    }
    catch {
        $publicationFailureObserved = $_.Exception.Message -ceq 'injected publication failure before rename'
    }
    if (-not $publicationFailureObserved -or (Test-Path -LiteralPath $faultTarget) -or
        (Test-Path -LiteralPath "$faultTarget.partial")) {
        throw 'Publication failure injection left a false-success or partial artifact'
    }

    $inputRecords = @($inputs | ForEach-Object {
        [ordered]@{
            path = Get-RelativeRepoPath $_.path
            sha256 = Get-Sha256 $_.path
            generated = $_.path.StartsWith($output, [StringComparison]::OrdinalIgnoreCase)
        }
    })
    $caseRecords = @(
        [ordered]@{
            id = 'task0-format-minimal'
            result = 'passed'
            repetitions = 2
            manifest_sha256 = Get-Sha256 (Join-Path $caseRoot 'format\minimal.case')
        },
        [ordered]@{
            id = 'task0-parser-comparison'
            result = 'passed'
            repetitions = $Repetitions
            manifest_sha256 = Get-Sha256 (Join-Path $parserCaseRoot 'parser-comparison.case')
            differential_level = 1
            normalizer = 'task0-acceptance-recovery-v1'
        }
    )
    $record = [ordered]@{
        format = 'ube-v4-verified-build-1'
        roadmap_task = 0
        build_identity = 'v4-task0-parser-decision-1'
        status = 'passed'
        bootstrap = [ordered]@{
            compiler = Get-RelativeRepoPath $v3
            sha256 = Get-Sha256 $v3
        }
        inputs = [ordered]@{
            prototype = [ordered]@{ path = Get-RelativeRepoPath $prototypeSource; sha256 = Get-Sha256 $prototypeSource }
            manifests = @($manifestResults)
            fixtures = $inputRecords
            grammar = [ordered]@{
                path = 'lang-doc/grammar/ube.ebnf'
                sha256 = Get-Sha256 (Join-Path $repoRoot 'lang-doc\grammar\ube.ebnf')
            }
            library = 'not-applicable: Task 0 prototype has no UBE library dependency'
            intrinsic = 'not-applicable: Task 0 prototype has no UBE intrinsic dependency'
            runtime = 'C++17 prototype process only; not a v4 runtime contract'
        }
        environment = [ordered]@{
            host = 'windows-x86-64'
            target = 'syntax-only'
            os = [Environment]::OSVersion.VersionString
            architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
            tools = @($compilerVersion, $PSVersionTable.PSVersion.ToString())
        }
        execution = [ordered]@{
            requested_jobs = 1
            effective_jobs = 1
            repetitions = $Repetitions
            schedules = @('ordinal-input-mode-run')
            faults = @('publication-before-rename')
        }
        cases = $caseRecords
        measurements = @($measurements)
        artifacts = @(
            [ordered]@{
                path = Get-RelativeRepoPath $prototypeExe
                sha256 = Get-Sha256 $prototypeExe
                size_bytes = (Get-Item -LiteralPath $prototypeExe).Length
            },
            [ordered]@{ name = 'v3-differential'; results = @($v3Results) }
        )
        cleanup = [ordered]@{
            live_resources = 0
            false_success_artifacts = 0
            injected_publication_failure_clean = $true
            passed = $true
        }
    }
    $recordForValidation = $record | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    Assert-VerifiedBuildShape -Record $recordForValidation -Purpose 'generated verified-build record'
    $measurementPath = Join-Path $output 'task0-parser-measurements.json'
    $verifiedPath = Join-Path $output 'verified-build.json'
    Publish-JsonAtomically -Path $measurementPath -Record ([ordered]@{
        format = 'ube-v4-task0-parser-evidence-1'
        decision_candidate = 'selective-hybrid'
        measurements = @($measurements)
        v3_differential = @($v3Results)
    })
    Publish-JsonAtomically -Path $verifiedPath -Record $record
    Write-Host "Task 0 parser comparison passed."
    Write-Host "Evidence: $measurementPath"
    Write-Host "Verified-build record: $verifiedPath"
    exit 0
}
catch {
    [Console]::Error.WriteLine("Task 0 runner failed: $($_.Exception.Message)")
    exit 1
}
