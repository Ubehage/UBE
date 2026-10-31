param(
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$fixtures = Join-Path $root 'std-lib/tests/foundation'
$suite = Get-Content -LiteralPath (Join-Path $fixtures 'cases.json') -Raw | ConvertFrom-Json
$outputRoot = Join-Path $root 'bootstrap/out/foundation'
# A fresh child avoids deleting backups, reusing stale output or concurrent runs.
$run = Join-Path $outputRoot ([Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands = New-Object 'System.Collections.Generic.List[object]'
$results = New-Object 'System.Collections.Generic.List[object]'
$inputs = New-Object 'System.Collections.Generic.List[object]'
$tools = New-Object 'System.Collections.Generic.List[object]'
$qualified = @()
$provenance = @()
$stageComparisons = @()
$restoredAvailability = @()
$completed = $false
$failure = $null

function Get-Identity([string]$Path) { Get-ArtifactIdentity $Path }



function Invoke-Bounded {
    param([string]$File, [string[]]$ArgumentList = @(), [int]$Seconds = 15)
    $record = Invoke-BoundedProcess $File $ArgumentList $root $Seconds
    $commands.Add($record)
    return $record
}

function Assert-ToolSuccess($Record, [string]$Action) {
    if ($Record.timedOut -or $Record.exit -ne 0) {
        throw "$Action failed: exit=$($Record.exit), timeout=$($Record.timedOut); $($Record.stderr)"
    }
}

try {
    if ($suite.schema -ne 1 -or $suite.target -ne 'x86_64-w64-windows-gnu') {
        throw 'Unsupported foundation case schema or target'
    }
    $gcc = (Get-Command gcc -ErrorAction Stop).Source
    $gxx = (Get-Command g++ -ErrorAction Stop).Source
    foreach ($file in @($gcc, $gxx, $Clang)) {
        $identity = Get-Identity $file
        $version = Invoke-Bounded $file @('--version')
        Assert-ToolSuccess $version 'Tool version query'
        $tools.Add([pscustomobject]@{ identity = $identity; version = $version.stdout })
    }
    $sourceFiles = @('lexer.cpp','unicode.cpp','parser.cpp','semantic.cpp','codegen.cpp','main.cpp') |
        ForEach-Object { Join-Path $root "bootstrap/src/$_" }
    $headers = @(Get-ChildItem -LiteralPath (Join-Path $root 'bootstrap/include') -Recurse -File)
    $runtimeSource = Join-Path $root 'runtime/bootstrap_runtime.c'
    $unicodeSource = Join-Path $root 'runtime/bootstrap_unicode_runtime.cpp'
    $inputPaths = @($sourceFiles) + @($headers.FullName) + @($runtimeSource, $unicodeSource,
        (Join-Path $root 'compiler/UBE_Compiler_v2/Main.bas'),
        (Join-Path $root 'compiler/UBE_Compiler_v2/UBE_Compiler_v2.UBE'),
        (Join-Path $PSScriptRoot 'check-foundation.ps1')) +
        @((Join-Path $root 'bootstrap/tools/verification.ps1')) +
        @(Get-ChildItem -LiteralPath $fixtures -File | ForEach-Object { $_.FullName })
    foreach ($file in $inputPaths) { $inputs.Add((Get-Identity $file)) }

    $seed = Join-Path $run 'ubec.exe'
    $runtime = Join-Path $run 'bootstrap_runtime.o'
    $unicode = Join-Path $run 'bootstrap_unicode_runtime.o'
    $common = @('-std=c++17','-Wall','-Wextra','-Wpedantic','-Werror','-I',
        (Join-Path $root 'bootstrap/include'))
    Write-Output 'Building only the current small seed and runtime (no archived compiler).'
    $build = Invoke-Bounded $gxx ($common + $sourceFiles + @('-o', $seed)) 60
    Assert-ToolSuccess $build 'Seed build'
    $build = Invoke-Bounded $gcc @('-std=c17','-Wall','-Wextra','-Wpedantic','-Werror',
        '-c', $runtimeSource, '-o', $runtime) 60
    Assert-ToolSuccess $build 'Runtime build'
    $build = Invoke-Bounded $gxx ($common + @('-c', $unicodeSource, '-o', $unicode)) 60
    Assert-ToolSuccess $build 'Unicode runtime build'
    $compilers = @([pscustomobject]@{ name = 'current-seed'; path = $seed; seed = $true })
    $restoredCandidates = @(
        [pscustomobject]@{ name = 'restored-v2-stage1'; path = (Join-Path $root 'bootstrap/out/ube-stage1-v2.exe'); seed = $false },
        [pscustomobject]@{ name = 'restored-v2-stage2'; path = (Join-Path $root 'bootstrap/out/ube-stage2-v2.exe'); seed = $false }
    )
    foreach ($candidate in $restoredCandidates) {
        $available = Test-Path -LiteralPath $candidate.path
        $restoredAvailability += [pscustomobject]@{ name = $candidate.name; available = $available }
        if ($available) { $compilers += $candidate }
        else { Write-Output "Skipping unavailable backup artifact: $($candidate.name)" }
    }
    foreach ($file in @($runtime, $unicode) + @($compilers.path)) {
        $tools.Add([pscustomobject]@{ identity = (Get-Identity $file); version = $null })
    }
    $manifestPath = Join-Path $root 'bootstrap/out/v2-bootstrap-manifest.json'
    if (Test-Path -LiteralPath $manifestPath) {
        $inputs.Add((Get-Identity $manifestPath))
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $comparisons = @(
            @('v2-source', (Join-Path $root 'compiler/UBE_Compiler_v2/Main.bas'), $manifest.inputs.source),
            @('v2-project', (Join-Path $root 'compiler/UBE_Compiler_v2/UBE_Compiler_v2.UBE'), $manifest.inputs.project),
            @('runtime-source', $runtimeSource, $manifest.inputs.runtime_source),
            @('unicode-runtime-source', $unicodeSource, $manifest.inputs.unicode_runtime_source)
        )
        if (Test-Path -LiteralPath $restoredCandidates[0].path) {
            $comparisons += ,@('restored-v2-stage1', $restoredCandidates[0].path, $manifest.artifacts.stage1)
        }
        if (Test-Path -LiteralPath $restoredCandidates[1].path) {
            $comparisons += ,@('restored-v2-stage2', $restoredCandidates[1].path, $manifest.artifacts.stage2)
        }
        foreach ($comparison in $comparisons) {
            $actual = (Get-Identity $comparison[1]).sha256
            $provenance += [pscustomobject]@{ name = $comparison[0];
                recorded = $comparison[2]; actual = $actual; matches = ($actual -ceq $comparison[2]) }
        }
    }

    foreach ($compiler in $compilers) {
        $directory = Join-Path $run $compiler.name
        New-Item -ItemType Directory -Path $directory | Out-Null
        foreach ($case in $suite.cases) {
            $source = Join-Path $fixtures $case.source
            $ir = Join-Path $directory ($case.name + '.ll')
            $executable = Join-Path $directory ($case.name + '.exe')
            $problems = New-Object 'System.Collections.Generic.List[string]'
            $irHash = $null
            $repeatHash = $null
            $native = $null
            $arguments = @($source, $ir)
            if ($compiler.seed) { $arguments = @('--emit-llvm', $source, $ir) }
            $emission = Invoke-Bounded $compiler.path $arguments
            if ($emission.timedOut) { $problems.Add('Compiler timed out') }
            elseif ($case.expect -eq 'reject') {
                if ($emission.exit -le 0 -or $emission.exit -gt 125) { $problems.Add('No controlled diagnostic exit') }
                if ([string]::IsNullOrWhiteSpace($emission.stdout + $emission.stderr)) { $problems.Add('No diagnostic text') }
                if ($null -ne $case.PSObject.Properties['diagnosticPattern']) {
                    if (($emission.stdout + $emission.stderr) -notmatch $case.diagnosticPattern) {
                        $problems.Add('Diagnostic does not identify the required rejection')
                    }
                }
                if (Test-Path -LiteralPath $ir) { $problems.Add('Rejected source published LLVM') }
            } elseif ($case.expect -eq 'native') {
                if ($emission.exit -ne 0 -or -not (Test-Path -LiteralPath $ir)) {
                    $problems.Add('Required native case did not emit LLVM')
                } else {
                    $irHash = (Get-Identity $ir).sha256
                    if ($null -ne $case.PSObject.Properties['irPattern']) {
                        if ([IO.File]::ReadAllText($ir) -notmatch $case.irPattern) {
                            $problems.Add('Emitted storage does not match required width')
                        }
                    }
                    $repeatIr = Join-Path $directory ($case.name + '.repeat.ll')
                    $arguments = @($source, $repeatIr)
                    if ($compiler.seed) { $arguments = @('--emit-llvm', $source, $repeatIr) }
                    $repeat = Invoke-Bounded $compiler.path $arguments
                    if ($repeat.timedOut -or $repeat.exit -ne 0 -or -not (Test-Path -LiteralPath $repeatIr)) {
                        $problems.Add('Repeat emission failed')
                    } else {
                        $repeatHash = (Get-Identity $repeatIr).sha256
                        if ($irHash -cne $repeatHash) { $problems.Add('Repeat LLVM differs') }
                    }
                    $link = Invoke-Bounded $Clang @('--target=x86_64-w64-windows-gnu','-O2',
                        '-x','ir',$ir,'-x','none',$runtime,$unicode,'-o',$executable) 30
                    if ($link.timedOut -or $link.exit -ne 0 -or -not (Test-Path -LiteralPath $executable)) {
                        $problems.Add('Native link failed')
                    } else {
                        $native = Invoke-Bounded $executable
                        if ($native.timedOut) { $problems.Add('Native program timed out') }
                        if ($native.exit -ne $case.exit) { $problems.Add('Native exit differs') }
                        if ($native.stdout -cne $case.stdout) { $problems.Add('Native stdout differs') }
                        if ($native.stderr -cne '') { $problems.Add('Unexpected native stderr') }
                    }
                }
            } else { throw "Unknown expectation: $($case.expect)" }
            $result = [pscustomobject]@{
                compiler = $compiler.name; case = $case.name; group = $case.group
                passed = ($problems.Count -eq 0); problems = @($problems.ToArray())
                compile = $emission; irSha256 = $irHash; repeatIrSha256 = $repeatHash
                native = $native
            }
            $results.Add($result)
            $label = 'FAIL'
            if ($result.passed) { $label = 'PASS' }
            Write-Output "$($compiler.name) $($case.name): $label ($($case.group))"
        }
    }
    foreach ($compiler in $compilers) {
        $failed = @($results | Where-Object {
            $_.compiler -eq $compiler.name -and $_.group -eq 'subset' -and -not $_.passed
        })
        if ($failed.Count -eq 0) { $qualified += $compiler.name }
    }
    foreach ($case in $suite.cases) {
        $pair = @($results | Where-Object {
            $_.case -eq $case.name -and $_.compiler -like 'restored-v2-*'
        })
        if ($pair.Count -eq 2 -and $null -ne $pair[0].irSha256 -and $null -ne $pair[1].irSha256) {
            $stageComparisons += [pscustomobject]@{ case = $case.name;
                equal = ($pair[0].irSha256 -ceq $pair[1].irSha256) }
        }
    }
    $completed = $true
    if ($qualified -notcontains 'current-seed') { throw 'Current-source seed did not satisfy the bounded subset' }
} catch {
    $failure = $_.Exception.Message
} finally {
    $report = [ordered]@{
        schema = 1; recordedUtc = [DateTime]::UtcNow.ToString('o'); target = $suite.target
        powershell = $PSVersionTable.PSVersion.ToString(); completed = $completed
        failure = $failure; subsetQualified = @($qualified); inputs = @($inputs.ToArray())
        tools = @($tools.ToArray()); results = @($results.ToArray()); commands = @($commands.ToArray())
        restoredManifestComparison = @($provenance); restoredStageIrComparisons = @($stageComparisons)
        restoredArtifactAvailability = @($restoredAvailability)
        limitations = @('No self-hosting or restored-v2 source reproduction',
            'No full language, native-type extension, GC, Err, concurrency or scaling proof',
            'Process elapsedMs is diagnostic timing, not an allocation/work/memory measurement',
            'Target-probe failures are unmet obligations, not passing compatibility tests')
    }
    $reportPath = Join-Path $run 'report.json'
    $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Output "Evidence: $reportPath"
}
if ($null -ne $failure) { throw $failure }
Write-Output ('Bounded subset qualified: ' + ($qualified -join ', '))
Write-Output 'Read target-probe failures before choosing any additional dependency.'
