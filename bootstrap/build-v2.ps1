param([string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'tools/verification.ps1')
$run = Join-Path $PSScriptRoot ('out/v2/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands = New-Object 'System.Collections.Generic.List[object]'
$checks = New-Object 'System.Collections.Generic.List[object]'
$inputs = @()
$toolIdentities = @()
$success = $false
$failure = $null
$timer = [Diagnostics.Stopwatch]::StartNew()

function Invoke-Recorded([string]$File, [string[]]$Values = @(), [int]$Timeout = 30) {
    $record = Invoke-BoundedProcess $File $Values $root $Timeout
    $commands.Add($record)
    return $record
}
function Assert-Success($Record, [string]$Action) {
    if ($Record.timedOut -or $Record.exit -ne 0) {
        throw "$Action failed (exit $($Record.exit), timeout $($Record.timedOut)): $($Record.stdout)$($Record.stderr)"
    }
}
function Assert-EqualIr([string]$First, [string]$Second, [string]$Name) {
    $left = Get-ArtifactIdentity $First
    $right = Get-ArtifactIdentity $Second
    if ($left.bytes -ne $right.bytes -or $left.sha256 -cne $right.sha256) { throw "$Name LLVM differs" }
    $checks.Add([pscustomobject]@{ name = $Name; assertion = 'byte-identical LLVM'; sha256 = $left.sha256; passed = $true })
}
function Link-Native([string]$Ir, [string]$Executable) {
    $record = Invoke-Recorded $Clang @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$Ir,
        '-x','none',$runtime,$unicode,'-o',$Executable)
    Assert-Success $record "Link $Ir"
}
function Test-Positive([string]$Source, [string]$Name, [string]$Expected, [int]$Exit = 0, [string[]]$Patterns = @()) {
    $irPaths = @()
    foreach ($compiler in $stages) {
        $ir = Join-Path $run ($compiler.name + '-' + $Name + '.ll')
        $exe = Join-Path $run ($compiler.name + '-' + $Name + '.exe')
        $emission = Invoke-Recorded $compiler.path @($Source, $ir)
        Assert-Success $emission "Emit $Name"
        if (-not (Test-Path -LiteralPath $ir)) { throw "$Name produced no LLVM" }
        foreach ($pattern in $Patterns) {
            if ([IO.File]::ReadAllText($ir) -notmatch $pattern) { throw "$Name missing LLVM assertion: $pattern" }
        }
        Link-Native $ir $exe
        $record = Invoke-Recorded $exe
        if ($record.timedOut -or $record.exit -ne $Exit -or $record.stdout -cne $Expected -or $record.stderr -cne '') {
            throw "$Name native oracle failed: $($record | ConvertTo-Json -Compress -Depth 5)"
        }
        $checks.Add([pscustomobject]@{ name = $Name; compiler = $compiler.name;
            assertion = 'exact native stdout/exit, empty stderr and LLVM patterns'; passed = $true })
        $irPaths += $ir
    }
    Assert-EqualIr $irPaths[0] $irPaths[1] $Name
}
function Test-Negative([string]$Source, [string]$Name, [string]$Diagnostic, [int]$Exit = 1) {
    $records = @()
    foreach ($compiler in $stages) {
        $ir = Join-Path $run ($compiler.name + '-' + $Name + '.ll')
        $record = Invoke-Recorded $compiler.path @($Source, $ir)
        if ($record.timedOut -or $record.exit -ne $Exit -or
            ($record.stdout + $record.stderr).IndexOf($Diagnostic, [StringComparison]::Ordinal) -lt 0 -or
            (Test-Path -LiteralPath $ir)) {
            throw "$Name rejection failed: $($record | ConvertTo-Json -Compress -Depth 5)"
        }
        $records += $record
    }
    if ($records[0].stdout -cne $records[1].stdout -or $records[0].stderr -cne $records[1].stderr) {
        throw "$Name stage diagnostics differ"
    }
    $checks.Add([pscustomobject]@{ name = $Name;
        assertion = 'both stages: exact error status, expected diagnostic, no output; identical diagnostics'; passed = $true })
}

try {
    $gcc = (Get-Command gcc -ErrorAction Stop).Source
    $gxx = (Get-Command g++ -ErrorAction Stop).Source
    foreach ($tool in @($gcc,$gxx,$Clang)) {
        $version = Invoke-Recorded $tool @('--version')
        Assert-Success $version 'Tool version'
        $toolIdentities += [pscustomobject]@{ identity = (Get-ArtifactIdentity $tool); version = $version.stdout }
    }
    $inputPaths = @(
        (Get-ChildItem (Join-Path $root 'bootstrap/src') -File).FullName
        (Get-ChildItem (Join-Path $root 'bootstrap/include') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'bootstrap/tests') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'compiler/UBE_Compiler_v1') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'compiler/UBE_Compiler_v2') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'compiler/UBE_Compiler_v3') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'std-lib/tests/foundation') -File).FullName
        (Get-ChildItem (Join-Path $root 'std-lib/tests/native-type') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'std-lib/tests/managed-storage') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'std-lib/tests/utf8') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'std-lib/tests/byte-buffer') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'std-lib/tests/file-bytes') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'std-lib/tests/unicode') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'std-lib/data/unicode') -Recurse -File).FullName
        (Get-ChildItem (Join-Path $root 'std-lib/src') -Recurse -File).FullName
        (Join-Path $root 'std-lib/UBECore.UBE')
        (Join-Path $root 'std-lib/BYTE-BUFFER-CONTRACT.md')
        (Join-Path $root 'std-lib/FILE-BYTES-CONTRACT.md')
        (Join-Path $root 'std-lib/THREADS-CONTRACT.md')
        (Join-Path $root 'compiler/UBE_Compiler_v3/CONCURRENCY-BOOTSTRAP.md')
        (Join-Path $root 'std-lib/tools/check-native-type.ps1')
        (Join-Path $root 'std-lib/tools/check-value-record.ps1')
        (Join-Path $root 'std-lib/tools/native-type-cases.ps1')
        (Join-Path $root 'std-lib/tools/value-probes.ps1')
        (Join-Path $root 'std-lib/tools/check-managed-values.ps1')
        (Join-Path $root 'std-lib/tools/check-managed-storage.ps1')
        (Join-Path $root 'std-lib/tools/check-utf8.ps1')
        (Join-Path $root 'std-lib/tools/check-byte-buffer.ps1')
        (Join-Path $root 'std-lib/tools/check-byte-buffer-costs.ps1')
        (Join-Path $root 'std-lib/tools/check-file-bytes.ps1')
        (Join-Path $root 'std-lib/tools/check-unicode.ps1')
        (Join-Path $root 'std-lib/tools/generate-unicode.ps1')
        (Join-Path $root 'std-lib/UNICODE-CONTRACT.md')
        (Join-Path $root 'std-lib/tests/byte-storage/allocation-probe.h')
        (Join-Path $PSScriptRoot 'build-v2.ps1')
        (Join-Path $PSScriptRoot 'compile-v2.ps1')
        (Join-Path $PSScriptRoot 'tools/verification.ps1')
        (Join-Path $root 'runtime/bootstrap_runtime.c')
        (Join-Path $root 'runtime/value_storage.h')
        (Join-Path $root 'runtime/bootstrap_unicode_runtime.cpp')
    )
    $inputs = @($inputPaths | Where-Object {
        [IO.Path]::GetExtension($_) -in @('.bas','.cls','.UBE','.c','.cpp','.h','.hpp','.ps1','.json','.ll') -or
        $_ -eq (Join-Path $root 'std-lib/THREADS-CONTRACT.md') -or
        $_ -eq (Join-Path $root 'compiler/UBE_Compiler_v3/CONCURRENCY-BOOTSTRAP.md') -or
        $_ -eq (Join-Path $root 'std-lib/BYTE-BUFFER-CONTRACT.md') -or
        $_ -eq (Join-Path $root 'std-lib/tests/byte-buffer/ORACLES.md') -or
        $_ -eq (Join-Path $root 'std-lib/FILE-BYTES-CONTRACT.md') -or
        $_ -eq (Join-Path $root 'std-lib/tests/file-bytes/ORACLES.md') -or
        $_ -eq (Join-Path $root 'compiler/UBE_Compiler_v2/tests/source-reference/CONTRACT.md') -or
        $_ -eq (Join-Path $root 'compiler/UBE_Compiler_v2/tests/entry-admission/CONTRACT.md') -or
        $_ -eq (Join-Path $root 'compiler/UBE_Compiler_v3/SOURCE-INPUT-CONTRACT.md') -or
        $_ -eq (Join-Path $root 'compiler/UBE_Compiler_v3/tests/source-input/ORACLES.md') -or
        $_ -eq (Join-Path $root 'compiler/UBE_Compiler_v3/SCANNER-CONTRACT.md') -or
        $_ -eq (Join-Path $root 'compiler/UBE_Compiler_v3/tests/scanner/native/ORACLES.md') -or
        $_ -eq (Join-Path $root 'std-lib/UNICODE-CONTRACT.md') -or
        $_ -eq (Join-Path $root 'std-lib/tests/unicode/ORACLES.md') -or
        $_.StartsWith((Join-Path $root 'std-lib/data/unicode/'),[StringComparison]::OrdinalIgnoreCase)
    } | Sort-Object -Unique | ForEach-Object { Get-ArtifactIdentity $_ })
    $common = @('-std=c++17','-Wall','-Wextra','-Wpedantic','-Werror','-I',(Join-Path $PSScriptRoot 'include'))
    $lex = @((Join-Path $PSScriptRoot 'src/lexer.cpp'), (Join-Path $PSScriptRoot 'src/unicode.cpp'))
    $parse = $lex + @((Join-Path $PSScriptRoot 'src/parser.cpp'))
    $semantic = $parse + @((Join-Path $PSScriptRoot 'src/semantic.cpp'))
    $backend = $semantic + @((Join-Path $PSScriptRoot 'src/codegen.cpp'))
    $seed = Join-Path $run 'ubec.exe'
    $runtime = Join-Path $run 'bootstrap_runtime.o'
    $unicode = Join-Path $run 'bootstrap_unicode_runtime.o'
    Write-Output 'Building current seed/runtime and running seed regressions.'
    Assert-Success (Invoke-Recorded $gxx ($common + $backend + @((Join-Path $PSScriptRoot 'src/main.cpp'),'-o',$seed)) 60) 'Seed build'
    Assert-Success (Invoke-Recorded $clang @('--target=x86_64-w64-windows-gnu','-std=c17','-Wall','-Wextra','-Wpedantic','-Werror','-c',(Join-Path $root 'runtime/bootstrap_runtime.c'),'-o',$runtime) 60) 'Runtime build'
    Assert-Success (Invoke-Recorded $gxx ($common + @('-c',(Join-Path $root 'runtime/bootstrap_unicode_runtime.cpp'),'-o',$unicode)) 60) 'Unicode runtime build'
    $unitSources = @($lex, $parse, $semantic, $backend)
    $unitNames = @('lexer','parser','semantic','codegen')
    for ($index = 0; $index -lt $unitNames.Count; $index++) {
        $name = $unitNames[$index]
        $exe = Join-Path $run ($name + '-tests.exe')
        Assert-Success (Invoke-Recorded $gxx ($common + $unitSources[$index] + @((Join-Path $PSScriptRoot "tests/${name}_tests.cpp"),'-o',$exe)) 60) "$name test build"
        Assert-Success (Invoke-Recorded $exe) "$name tests"
        $checks.Add([pscustomobject]@{ name = "seed-$name"; assertion = 'inherited C++ suite'; passed = $true })
    }
    foreach ($probe in @('error_state','integer_failure','integer_storage')) {
        $exe = Join-Path $run ($probe + '-probe.exe')
        Assert-Success (Invoke-Recorded $gcc @('-std=c17','-Wall','-Wextra','-Wpedantic','-Werror',
            (Join-Path $PSScriptRoot "tests/${probe}_probe.c"),$runtime,'-o',$exe) 60) "$probe build"
        $record = Invoke-Recorded $exe
        Assert-Success $record "$probe assertions"
        if ($record.stdout -cne ($probe.Replace('_',' ') + " probe passed`n") -or $record.stderr -cne '') { throw "$probe output differs" }
        $checks.Add([pscustomobject]@{ name = $probe; assertion = 'runtime assertions and exact output'; passed = $true })
    }
    Write-Output 'Building v2 stage one, stage two and the current-source LLVM fixed point.'
    $v2 = Join-Path $root 'compiler/UBE_Compiler_v2'
    $project = Join-Path $v2 'UBE_Compiler_v2.UBE'
    $ir1 = Join-Path $run 'v2-stage1.ll'
    $ir2 = Join-Path $run 'v2-stage2.ll'
    $ir3 = Join-Path $run 'v2-stage3.ll'
    $stage1 = Join-Path $run 'ube-stage1-v2.exe'
    $stage2 = Join-Path $run 'ube-stage2-v2.exe'
    Assert-Success (Invoke-Recorded $seed @('--emit-llvm',(Join-Path $v2 'Main.bas'),$ir1)) 'Seed emits v2'
    Link-Native $ir1 $stage1
    Assert-Success (Invoke-Recorded $stage1 @($project,$ir2) 60) 'v2 self compilation'
    Link-Native $ir2 $stage2
    Assert-Success (Invoke-Recorded $stage2 @($project,$ir3) 60) 'v2 repeat self compilation'
    Assert-EqualIr $ir2 $ir3 'v2-fixed-point'
    $stages = @([pscustomobject]@{ name = 'stage1'; path = $stage1 },[pscustomobject]@{ name = 'stage2'; path = $stage2 })
    Write-Output 'Checking existing and independent native/rejection oracles through both stages.'
    Test-Positive (Join-Path $v2 'tests/showcase_sub.bas') 'showcase-sub' "Hello `"quoted`" from UBE Compiler v2\lexer`n"
    Test-Positive (Join-Path $v2 'tests/showcase_function.bas') 'showcase-function' "Function Main from UBE Compiler v2`n" 12
    Test-Positive (Join-Path $v2 'tests/backend_features.bas') 'backend-features' "backend-features`n" 8
    Test-Positive (Join-Path $v2 'tests/multi_module.UBE') 'multi-module' "multi-module`n" 7
    $foundation = Join-Path $v2 'tests/foundation'
    $cases = Get-Content -LiteralPath (Join-Path $foundation 'cases.json') -Raw | ConvertFrom-Json
    foreach ($case in $cases.positive) {
        $patterns = @()
        if ($null -ne $case.PSObject.Properties['irPatterns']) { $patterns = @($case.irPatterns) }
        Test-Positive (Join-Path $foundation $case.source) ([IO.Path]::GetFileNameWithoutExtension($case.source)) $case.stdout $case.exit $patterns
    }
    foreach ($case in $cases.negative) {
        Test-Negative (Join-Path $foundation $case.source) ([IO.Path]::GetFileNameWithoutExtension($case.source)) $case.diagnostic
    }
    $basic = Join-Path $root 'std-lib/tests/foundation'
    $basicCases = Get-Content -LiteralPath (Join-Path $basic 'cases.json') -Raw | ConvertFrom-Json
    foreach ($case in $basicCases.cases) {
        if ($case.name -eq 'embedded-zero') { continue }
        if ($case.expect -eq 'native') {
            $patterns = @()
            if ($null -ne $case.PSObject.Properties['irPattern']) { $patterns = @($case.irPattern) }
            Test-Positive (Join-Path $basic $case.source) ('foundation-' + $case.name) $case.stdout $case.exit $patterns
        } else {
            # Existing cases require a diagnostic, not an inherited compiler wording.
            Test-Negative (Join-Path $basic $case.source) ('foundation-' + $case.name) 'error'
        }
    }
    $negativeCases = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tests/v2-negative-cases.json') -Raw | ConvertFrom-Json
    foreach ($case in $negativeCases) {
        Test-Negative (Join-Path $v2 $case.source) ('inherited-' + [IO.Path]::GetFileNameWithoutExtension($case.source)) $case.diagnostic $case.exit
    }
    Test-Negative (Join-Path $run 'does-not-exist.bas') 'missing-file' 'cannot open for reading' 66
    $nulSource = Join-Path $run 'embedded-nul.bas'
    [IO.File]::WriteAllBytes($nulSource, [byte[]](83,117,98,32,77,97,105,110,40,41,10,0,69,110,100,32,83,117,98,10))
    Test-Negative $nulSource 'nul-file' 'text file contains an embedded NUL byte' 66
    $invalidUtf8 = Join-Path $run 'invalid-utf8.bas'
    [IO.File]::WriteAllBytes($invalidUtf8, [byte[]](255,10))
    Test-Negative $invalidUtf8 'invalid-utf8' 'source is not valid UTF-8'
    $loneCr = Join-Path $run 'lone-cr.bas'
    [IO.File]::WriteAllBytes($loneCr, [byte[]](83,117,98,32,77,97,105,110,40,41,13,69))
    Test-Negative $loneCr 'lone-cr' 'lone carriage return is not a valid line ending'
    $deep = Join-Path $run 'deep-expression.bas'
    $expression = ((1..5000 | ForEach-Object { '1' }) -join '+')
    [IO.File]::WriteAllText($deep, "Function Main() As Long`nPrint $expression`nMain = 0`nEnd Function`n")
    Test-Negative $deep 'deep-expression' 'expression exceeds the bootstrap depth limit'
    $nested = Join-Path $run 'nested-expression.bas'
    [IO.File]::WriteAllText($nested, ("Function Main() As Long`nPrint " + ('(' * 5000) + '1' + (')' * 5000) + "`nMain = 0`nEnd Function`n"))
    Test-Negative $nested 'nested-expression' 'expression exceeds the bootstrap depth limit'
    $unary = Join-Path $run 'deep-unary.bas'
    [IO.File]::WriteAllText($unary, ("Function Main() As Long`nPrint " + ('-' * 5000) + "1`nMain = 0`nEnd Function`n"))
    Test-Negative $unary 'deep-unary' 'expression exceeds the bootstrap depth limit'
    $ordinary = Join-Path $run 'ordinary-expression.bas'
    $expression = ((1..64 | ForEach-Object { '1' }) -join '+')
    [IO.File]::WriteAllText($ordinary, "Function Main() As Long`nPrint $expression`nMain = 0`nEnd Function`n")
    Test-Positive $ordinary 'ordinary-expression' "64`n"
    foreach ($compiler in $stages) {
        $usage = Invoke-Recorded $compiler.path
        if ($usage.exit -ne 2 -or $usage.timedOut -or $usage.stdout -notmatch '^usage:') { throw 'Usage rejection failed' }
        $writeFailure = Invoke-Recorded $compiler.path @((Join-Path $v2 'tests/showcase_sub.bas'),$run)
        if ($writeFailure.exit -ne 73 -or $writeFailure.timedOut) { throw 'Output failure was not controlled' }
    }
    $checks.Add([pscustomobject]@{ name = 'process-errors'; assertion = 'usage and output failures through both stages'; passed = $true })
    Write-Output 'Preserving v1 bootstrap showcases and rejection cases.'
    $v1 = Join-Path $root 'compiler/UBE_Compiler_v1'
    $v1Ir = Join-Path $run 'v1.ll'
    $v1Exe = Join-Path $run 'ube-stage1-v1.exe'
    Assert-Success (Invoke-Recorded $seed @('--emit-llvm',(Join-Path $v1 'Main.bas'),$v1Ir)) 'v1 seed compile'
    Link-Native $v1Ir $v1Exe
    foreach ($case in @(@('showcase_sub.bas',"Hello from UBE stage one`n",0), @('showcase_function.bas',"Function Main from UBE stage one`n",9))) {
        $ir = Join-Path $run ('v1-' + $case[0] + '.ll')
        $exe = Join-Path $run ('v1-' + $case[0] + '.exe')
        Assert-Success (Invoke-Recorded $v1Exe @((Join-Path $v1 ('tests/' + $case[0])),$ir)) 'v1 emit'
        Link-Native $ir $exe
        $record = Invoke-Recorded $exe
        if ($record.timedOut -or $record.exit -ne $case[2] -or $record.stdout -cne $case[1] -or $record.stderr -cne '') { throw 'v1 native oracle failed' }
    }
    foreach ($name in @('missing_print.bas','unterminated_print.bas','unsupported_backslash.bas','missing_function_result.bas')) {
        $ir = Join-Path $run ('v1-' + $name + '.ll')
        $record = Invoke-Recorded $v1Exe @((Join-Path $v1 ('tests/' + $name)),$ir)
        if ($record.timedOut -or $record.exit -ne 1 -or (Test-Path -LiteralPath $ir) -or [string]::IsNullOrWhiteSpace($record.stdout + $record.stderr)) { throw 'v1 rejection failed' }
    }
    $checks.Add([pscustomobject]@{ name = 'v1'; assertion = 'two exact native and four controlled rejection cases'; passed = $true })
    foreach ($inputIdentity in $inputs) {
        if ((Get-ArtifactIdentity $inputIdentity.path).sha256 -cne $inputIdentity.sha256) { throw "Input changed during build: $($inputIdentity.path)" }
    }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    $timer.Stop()
    $artifacts = @(Get-ChildItem -LiteralPath $run -File | Where-Object { $_.Extension -in @('.exe','.o','.ll') } | ForEach-Object { Get-ArtifactIdentity $_.FullName })
    $manifest = [ordered]@{ schema = 'ube-v2-foundation-1'; success = $success; failure = $failure;
        target = 'x86_64-w64-windows-gnu'; optimization = '-O2'; powershell = $PSVersionTable.PSVersion.ToString();
        recordedUtc = [DateTime]::UtcNow.ToString('o'); elapsedMs = $timer.ElapsedMilliseconds;
        inputs = $inputs; tools = $toolIdentities; artifacts = $artifacts;
        checks = @($checks.ToArray()); commands = @($commands.ToArray());
        limits = @('Bounded bootstrap subset, not complete UBE language or managed native-value support',
            'No restored compiler binary used', 'Process sampling is not allocation, scaling or concurrency proof') }
    $manifestPath = Join-Path $run 'manifest.json'
    $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-Output "Manifest: $manifestPath"
}
if (-not $success) { throw $failure }
$current = [ordered]@{ schema = 'ube-v2-current-1'; manifest = (Get-ArtifactIdentity $manifestPath);
    compiler = (Get-ArtifactIdentity $stage2); seed = (Get-ArtifactIdentity $seed);
    runtime = (Get-ArtifactIdentity $runtime); unicodeRuntime = (Get-ArtifactIdentity $unicode);
    clang = (Get-ArtifactIdentity $Clang) }
# Qualify additional mechanisms before publishing the accepted tool. Nested
# proofs bind to an immutable source-bootstrap snapshot, not a mutable locator.
$sourceManifestPath = Join-Path $run 'source-manifest.json'
[IO.File]::Copy($manifestPath,$sourceManifestPath)
$current.manifest = Get-ArtifactIdentity $sourceManifestPath
$candidatePath = Join-Path $run 'candidate.json'
$current | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $candidatePath -Encoding UTF8
$proofs = @()
$timer.Start()
try {
    Write-Output 'Qualifying native values, managed storage, source input and existing baselines.'
    $shell = (Get-Process -Id $PID).Path
    foreach ($proof in @(@('native-values','std-lib/tools/check-native-type.ps1'),
        @('ordinary-records','std-lib/tools/check-value-record.ps1'),
        @('managed-substrate','std-lib/tools/check-managed-storage.ps1'),
        @('managed-values','std-lib/tools/check-managed-values.ps1'),
        @('utf8-decoder','std-lib/tools/check-utf8.ps1'),
        @('byte-buffer','std-lib/tools/check-byte-buffer.ps1'),
        @('byte-buffer-costs','std-lib/tools/check-byte-buffer-costs.ps1'),
        @('source-references','compiler/UBE_Compiler_v2/tests/source-reference/check.ps1'),
        @('entry-admission','compiler/UBE_Compiler_v2/tests/entry-admission/check.ps1'),
        @('file-bytes','std-lib/tools/check-file-bytes.ps1'),
        @('source-input','compiler/UBE_Compiler_v3/tools/check-source-input.ps1'),
        @('unicode','std-lib/tools/check-unicode.ps1'),
        @('scanner','compiler/UBE_Compiler_v3/tools/check-scanner.ps1'),
        @('reference-storage','compiler/UBE_Compiler_v2/tests/concurrency/check-references.ps1'),
        @('reference-order','compiler/UBE_Compiler_v2/tests/concurrency/check-reference-order.ps1'),
        @('scalar-output','compiler/UBE_Compiler_v2/tests/concurrency/check-scalar-output.ps1'),
        @('thread-statement','compiler/UBE_Compiler_v2/tests/concurrency/check.ps1'),
        @('thread-references','compiler/UBE_Compiler_v2/tests/concurrency/check-thread-references.ps1'),
        @('expression-stack','compiler/UBE_Compiler_v2/tests/concurrency/check-expression-stack.ps1'),
        @('gc-initialization','compiler/UBE_Compiler_v2/tests/concurrency/check-gc-initialization.ps1'))) {
        $proofTimeout = 60
        if ($proof[0] -in @('source-references','source-input','unicode','scanner')) { $proofTimeout = 900 }
        if ($proof[0] -eq 'thread-references') { $proofTimeout = 180 }
        $proofArguments = @('-NoProfile','-File',(Join-Path $root $proof[1]),'-SelectionPath',$candidatePath)
        if ($proof[0] -eq 'thread-statement') { $proofArguments += '-RequireNative' }
        $record = Invoke-Recorded $shell $proofArguments $proofTimeout
        Assert-Success $record $proof[0]
        $reports = [regex]::Matches($record.stdout,'(?m)^Evidence: (.+)$')
        if ($reports.Count -ne 1) { throw "No unique proof report: $($proof[0])" }
        $reportIdentity = Get-ArtifactIdentity $reports[0].Groups[1].Value.Trim()
        $report = Get-Content -LiteralPath $reportIdentity.path -Raw | ConvertFrom-Json
        if (-not $report.success -or $report.checks.Count -eq 0 -or
            $report.acceptedSelection.compiler.sha256 -cne $current.compiler.sha256 -or
            $report.acceptedSelection.manifest.sha256 -cne $current.manifest.sha256) {
            throw "Proof is incomplete or uses another compiler: $($proof[0])"
        }
        if ($proof[0] -eq 'managed-substrate' -and -not $report.sourceBuildCurrent) {
            throw 'Managed substrate proof is not bound to the current source-build inputs'
        }
        foreach ($check in $report.checks) {
            # The existing decoder report records completed assertions as text.
            # Object reports additionally require their explicit passed status.
            if ($check -is [string]) { $assertion = $check }
            else {
                if (-not $check.passed) { throw "Proof assertion failed: $($proof[0])" }
                $assertion = $check.assertion
            }
            $checks.Add([pscustomobject]@{ name = $proof[0]; assertion = $assertion;
                detail = $check; passed = $true })
        }
        $proofs += [pscustomobject]@{ name = $proof[0]; assertions = $report.checks.Count; report = $reportIdentity }
        Write-Output "PASS $($proof[0]): $($report.checks.Count) assertions"
    }
    foreach ($inputIdentity in $inputs) {
        if ((Get-ArtifactIdentity $inputIdentity.path).sha256 -cne $inputIdentity.sha256) { throw "Input changed during proofs: $($inputIdentity.path)" }
    }
} catch {
    $success = $false
    $failure = $_.Exception.Message
} finally {
    $timer.Stop()
    $manifest.success = $success
    $manifest.failure = $failure
    $manifest.elapsedMs = $timer.ElapsedMilliseconds
    $manifest.recordedUtc = [DateTime]::UtcNow.ToString('o')
    $manifest.checks = @($checks.ToArray())
    $manifest.commands = @($commands.ToArray())
    $manifest['sourceBootstrap'] = Get-ArtifactIdentity $sourceManifestPath
    $manifest['proofs'] = $proofs
    $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
}
if (-not $success) { throw $failure }
$current.manifest = Get-ArtifactIdentity $manifestPath
$current | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'out/v2/current.json') -Encoding UTF8
Write-Output "PASS: $($checks.Count) acceptance assertions; usable v2: $stage2"
