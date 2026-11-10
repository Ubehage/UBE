# Builds and exercises bounded project parsing with native compiler acceptance assertions.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube native compilation ' + [guid]::NewGuid())
$workingDirectory = Join-Path $artifacts 'unrelated working directory'
$null = New-Item -ItemType Directory -Path $workingDirectory -Force
$script:processNumber = 0
$script:passed = 0

# Quotes one Windows process argument, retaining literal quotes and backslashes.
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

# Runs a hidden child with a retained handle, deadline and persistent evidence.
function Invoke-BoundedProcess([string]$File, [string[]]$Arguments, [int]$TimeoutMilliseconds = 30000) {
    $script:processNumber++
    $prefix = Join-Path $artifacts ('process-' + $script:processNumber)
    $start = @{ FilePath=$File; WorkingDirectory=$workingDirectory; PassThru=$true; WindowStyle='Hidden'; RedirectStandardOutput=($prefix + '.stdout'); RedirectStandardError=($prefix + '.stderr') }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @start
    try {
        $retainedHandle = $process.Handle
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill()
            $null = $process.WaitForExit(5000)
            throw "Process timeout: $File. Evidence: $prefix"
        }
        $process.Refresh()
        if ($null -eq $process.ExitCode) { throw "No exit code for retained handle $retainedHandle" }
        return [pscustomobject]@{ ExitCode=$process.ExitCode; Stdout=[IO.File]::ReadAllText($prefix + '.stdout', $utf8); Stderr=[IO.File]::ReadAllText($prefix + '.stderr', $utf8); Evidence=$prefix }
    } finally { $process.Dispose() }
}

# Writes fixture text as strict UTF-8 independently of the host code page.
function Write-Text([string]$Path, [string]$Text) {
    $null = New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Path)) -Force
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

# Wraps a body in its native module envelope and normalizes physical newlines.
function Module-Text([string]$Name, [string]$Body) {
    return "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"$Name`"`r`n" + $Body.Replace("`r`n", "`n").Replace("`n", "`r`n")
}

# Creates an ordered Library manifest and isolated source modules for one case.
function New-Fixture([string]$Name, [string[]]$Bodies, [string[]]$ModuleNames = @('Example'), [string]$ProjectKind = 'Library') {
    $folder = Join-Path $artifacts $Name
    $lines = @('UBE-Project 1', 'Name = "SemanticFixture"', ('Kind = "' + $ProjectKind + '"'))
    if ($ProjectKind -eq 'Exe') { $lines += 'Startup = "Main"' }
    for ($i = 0; $i -lt $Bodies.Count; $i++) {
        $file = $ModuleNames[$i] + '.bas'
        Write-Text (Join-Path $folder $file) (Module-Text $ModuleNames[$i] $Bodies[$i])
        $lines += 'Source = "' + $file + '"'
    }
    $manifest = Join-Path $folder 'project.UBE'
    Write-Text $manifest (($lines -join "`r`n") + "`r`n")
    return $manifest
}

Write-Output "Artifacts retained: $artifacts"
if (-not $BootstrapExe) {
    $project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../UBE-Bootstrap.vbp'))
    $buildDirectory = Join-Path $artifacts 'build'
    $null = New-Item -ItemType Directory -Path $buildDirectory
    $buildLog = Join-Path $buildDirectory 'vb6-build.log'
    Write-Output "VB6 version: $((Get-Item -LiteralPath $VB6).VersionInfo.FileVersion)"
    $build = Invoke-BoundedProcess $VB6 @('/make', $project, '/out', $buildLog, '/outdir', $buildDirectory)
    if (Test-Path -LiteralPath $buildLog) { Get-Content -LiteralPath $buildLog }
    $BootstrapExe = Join-Path $buildDirectory 'UBE-Bootstrap.exe'
    if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $BootstrapExe)) { throw "VB6 build failed. Evidence: $buildDirectory" }
}
$BootstrapExe = [IO.Path]::GetFullPath($BootstrapExe)
if (-not (Test-Path -LiteralPath $BootstrapExe)) { throw "Bootstrap executable not found: $BootstrapExe" }

# Stops the gate when a native acceptance assertion fails.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Verifies the DOS/PE headers and AMD64 machine field before executing output.
function Assert-X64([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    Require ($bytes.Length -ge 64 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) 'Invalid DOS executable header'
    $offset = [BitConverter]::ToInt32($bytes, 0x3c)
    Require ($offset -ge 64 -and $offset -le $bytes.Length - 6) 'Invalid PE header offset'
    Require ([BitConverter]::ToUInt32($bytes, $offset) -eq 0x4550 -and [BitConverter]::ToUInt16($bytes, $offset + 4) -eq 0x8664) 'Expected x64 PE output'
}

# Requires an emission/build command to publish its stated success marker.
function Invoke-Compiler([string[]]$Arguments, [string]$Marker) {
    $result = Invoke-BoundedProcess $BootstrapExe $Arguments
    Require ($result.ExitCode -eq 0 -and $result.Stderr.Length -eq 0 -and $result.Stdout -match ('(?m)^' + [regex]::Escape($Marker) + '\r?$')) "Compiler failed. Evidence: $($result.Evidence)"
    return $result
}

# Compiles the same generated library+harness IR at a selected optimization level.
function Build-Harness([string]$IR, [string]$Exe, [string]$Level) {
    $result = Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR,'-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
    Require ($result.ExitCode -eq 0) "Native harness build failed. Evidence: $($result.Evidence)"
    Assert-X64 $Exe
}

# Retains original module text while making a manifest for checked-in fixtures.
function Copy-Fixtures([string]$Name, [string[]]$Files, [string]$Level = '2', [string]$Kind = 'Exe') {
    $folder = Join-Path $artifacts $Name
    $lines = @('UBE-Project 1', 'Name = "NativeFixture"', ('Kind = "' + $Kind + '"'), ('Optimization = "' + $Level + '"'))
    if ($Kind -eq 'Exe') { $lines += 'Startup = "Main"' }
    foreach ($file in $Files) {
        $leaf = [IO.Path]::GetFileName($file)
        Write-Text (Join-Path $folder $leaf) ([IO.File]::ReadAllText($file, $utf8))
        $lines += 'Source = "' + $leaf + '"'
    }
    $manifest = Join-Path $folder 'project.UBE'
    Write-Text $manifest (($lines -join "`r`n") + "`r`n")
    return $manifest
}

# Requires controlled failure and verifies an existing valid artifact is unchanged.
function Assert-PreservedFailure([string]$Name, [string[]]$Arguments, [string]$Code, [string]$Artifact, [int]$TimeoutMilliseconds = 30000) {
    $before = (Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash
    $result = Invoke-BoundedProcess $BootstrapExe $Arguments $TimeoutMilliseconds
    Require ($result.ExitCode -eq 1 -and $result.Stderr -match ('(?m)^UBE: ' + [regex]::Escape($Code) + ':') -and $result.Stdout -notmatch '(?m)^(BUILD OK|EMIT OK)\r?$') "$Name failure mismatch. Evidence: $($result.Evidence)"
    Require ((Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash -ceq $before) "$Name changed prior artifact"
    $script:passed++
    Write-Output "PASS: $Name preserves prior artifact"
}

$version = Invoke-BoundedProcess $Clang @('--version')
Require ($version.ExitCode -eq 0) 'Cannot identify LLVM toolchain'
Write-Output $version.Stdout.Trim()
$oracleManifest = Copy-Fixtures 'source oracle' @((Join-Path $PSScriptRoot '../failure-flow/SourceOracle.bas')) '0' 'Library'
$oracleIR = Join-Path $artifacts 'source-oracle.ll'
$null = Invoke-Compiler @('--emit-llvm',$oracleManifest,$oracleIR) 'EMIT OK'
$repeatIR = Join-Path $artifacts 'source-oracle-repeat.ll'
$null = Invoke-Compiler @('--emit-llvm',$oracleManifest,$repeatIR) 'EMIT OK'
Require ([IO.File]::ReadAllText($oracleIR) -ceq [IO.File]::ReadAllText($repeatIR)) 'Repeated compiler LLVM differs'
$dump = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$oracleManifest)
Require ($dump.ExitCode -eq 0 -and $dump.Stderr.Length -eq 0) 'Oracle symbol resolution failed'
$procedures = @{}
foreach ($line in $dump.Stdout.Replace("`r`n", "`n").Split("`n")) {
    if ($line.StartsWith('SYMBOL ')) {
        $fields = $line.Substring(7).Split('|')
        if ($fields[1] -eq 'function' -and $fields[5] -eq '0') { $procedures[$fields[2]] = [int]$fields[0] }
    }
}
$cases = (Get-Content -Raw (Join-Path $PSScriptRoot '../failure-flow/source-oracles.json') | ConvertFrom-Json).cases
Require ($cases.Count -eq 8) 'Expected all eight approved source oracle checks'
$harness = @('@test.runtime.input = global i64 1', '@test.context = private global %ube.context zeroinitializer, align 8', 'define i32 @main() {', 'entry:', '  %ctx = getelementptr %ube.context, ptr @test.context, i32 0')
$previous = '0'
for ($i = 0; $i -lt $cases.Count; $i++) {
    $case = $cases[$i]
    Require ($procedures.ContainsKey($case.procedure)) "Missing emitted oracle symbol $($case.procedure)"
    $symbol = $procedures[$case.procedure]
    $harness += @(
        '  call void @ube.context.init(ptr %ctx)',
        "  %init$i = call i1 @ube.project.init(ptr %ctx)",
        "  %input$i = load volatile i64, ptr @test.runtime.input",
        "  %result$i = call { i1, i64 } @ube.proc.$symbol(ptr %ctx, i64 %input$i)",
        "  %ok$i = extractvalue { i1, i64 } %result$i, 0",
        "  %value$i = extractvalue { i1, i64 } %result$i, 1",
        "  %zero$i = icmp eq i64 %value$i, 0",
        "  %good$i = and i1 %ok$i, %zero$i",
        "  %ready$i = and i1 %init$i, %good$i",
        "  %fail$i = select i1 %ready$i, i32 0, i32 $($case.failureBit)",
        "  %mask$i = or i32 $previous, %fail$i"
    )
    $previous = '%mask' + $i
}
$harness += @("  ret i32 $previous", '}')
$combinedIR = Join-Path $artifacts 'compiled-source-oracle-with-harness.ll'
Write-Text $combinedIR ([IO.File]::ReadAllText($oracleIR, $utf8) + "`r`n" + ($harness -join "`r`n") + "`r`n")
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ('oracle-' + $level + '.exe')
    Build-Harness $combinedIR $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "$level source oracle failed, independent check bit mask=$($result.ExitCode). Evidence: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: actual SourceOracle all eight independent checks at $level, success+zero, runtime volatile input"
}
$controlIR = Join-Path $artifacts 'compiled-source-oracle-input-zero.ll'
$combinedText = [IO.File]::ReadAllText($combinedIR, $utf8)
Require ($combinedText.Contains('@test.runtime.input = global i64 1')) 'Missing harness runtime-input control point'
Write-Text $controlIR ($combinedText.Replace('@test.runtime.input = global i64 1', '@test.runtime.input = global i64 0'))
$controlExe = Join-Path $artifacts 'oracle-input-zero.exe'
Build-Harness $controlIR $controlExe 'O2'
$controlRun = Invoke-BoundedProcess $controlExe @()
Require ($controlRun.ExitCode -eq 255) "All eight source oracle observations must reject input0; received $($controlRun.ExitCode)"
$script:passed++
Write-Output 'PASS: actual SourceOracle negative control detects all eight changed runtime conditions (mask255)'

$fixtureDirectory = Join-Path $PSScriptRoot 'fixtures'
foreach ($level in @('0','2')) {
    foreach ($fixture in @('scalar','shadow')) {
        $files = @((Join-Path $fixtureDirectory 'Program.bas'),(Join-Path $fixtureDirectory 'Helpers.bas'),(Join-Path $fixtureDirectory 'Problem.bas'))
        if ($fixture -eq 'shadow') { $files = @((Join-Path $fixtureDirectory 'ShadowProgram.bas'),(Join-Path $fixtureDirectory 'UserErr.bas')) }
        $manifest = Copy-Fixtures ($fixture + '-O' + $level) $files $level
        $exe = Join-Path $artifacts ($fixture + '-O' + $level + '.exe')
        $null = Invoke-Compiler @('--build',$manifest,$exe,'--clang',$Clang) 'BUILD OK'
        Assert-X64 $exe
        $result = Invoke-BoundedProcess $exe @()
        Require ($result.ExitCode -eq 0) "$fixture O$level native assertion failed, code=$($result.ExitCode). Evidence: $($result.Evidence)"
        $script:passed++
        Write-Output "PASS: native $fixture fixture O$level"
    }
}
$demo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../examples/multi-module/Demo.UBE'))
$preserved = Join-Path $artifacts 'preserved-valid.exe'
$null = Invoke-Compiler @('--build',$demo,$preserved,'--clang',$Clang) 'BUILD OK'
Assert-X64 $preserved
$demoRun = Invoke-BoundedProcess $preserved @()
Require ($demoRun.ExitCode -eq 42) 'Actual Demo executable did not return 42'
$script:passed++
Write-Output 'PASS: checked-in Demo compiles and returns 42'
$subMain = New-Fixture 'Sub Main native entry' @("Sub Main()`nEnd Sub") @('Example') 'Exe'
$subExe = Join-Path $artifacts 'sub-main.exe'
$null = Invoke-Compiler @('--build',$subMain,$subExe,'--clang',$Clang) 'BUILD OK'
Assert-X64 $subExe
$subRun = Invoke-BoundedProcess $subExe @()
Require ($subRun.ExitCode -eq 0) 'Sub Main did not return successful process status zero'
$script:passed++
Write-Output 'PASS: Sub Main native entry returns zero'

$invalid = New-Fixture 'invalid source' @("Function Main() As Long`nMain = Missing`nEnd Function") @('Example') 'Exe'
Assert-PreservedFailure 'frontend diagnostic' @('--build',$invalid,$preserved,'--clang',$Clang) 'E_NAME' $preserved
Assert-PreservedFailure 'missing clang' @('--build',$demo,$preserved,'--clang',(Join-Path $artifacts 'missing-clang.exe')) 'E_BACKEND' $preserved
foreach ($backendExit in @(7,0)) {
    $fakeIR = Join-Path $artifacts ('fake-backend-' + $backendExit + '.ll')
    $fakeExe = Join-Path $artifacts ('fake-backend-' + $backendExit + '.exe')
    Write-Text $fakeIR ("define i32 @main() {`r`nentry:`r`n  ret i32 " + $backendExit + "`r`n}`r`n")
    Build-Harness $fakeIR $fakeExe 'O0'
    $failureName = 'backend nonzero exit'
    if ($backendExit -eq 0) { $failureName = 'backend reports success without native output' }
    Assert-PreservedFailure $failureName @('--build',$demo,$preserved,'--clang',$fakeExe) 'E_BACKEND' $preserved
}
$timeoutIR = Join-Path $artifacts 'timeout-backend.ll'
$timeoutExe = Join-Path $artifacts 'timeout-backend.exe'
Write-Text $timeoutIR "define i32 @main() {`r`nentry:`r`n  br label %spin`r`nspin:`r`n  br label %spin`r`n}`r`n"
Build-Harness $timeoutIR $timeoutExe 'O0'
Assert-PreservedFailure 'backend deadline' @('--build',$demo,$preserved,'--clang',$timeoutExe) 'E_BACKEND' $preserved 45000
$badOutput = Join-Path $artifacts 'missing-parent/result.exe'
$badResult = Invoke-BoundedProcess $BootstrapExe @('--build',$demo,$badOutput,'--clang',$Clang)
Require ($badResult.ExitCode -eq 1 -and $badResult.Stderr -match '(?m)^UBE: E_OUTPUT:' -and -not (Test-Path -LiteralPath $badOutput)) 'Invalid output path was not controlled'
$script:passed++
Write-Output 'PASS: invalid output path rejected without artifact'
$collisionManifest = Copy-Fixtures 'input collision' @((Join-Path $fixtureDirectory 'Program.bas'),(Join-Path $fixtureDirectory 'Helpers.bas'),(Join-Path $fixtureDirectory 'Problem.bas'))
$sourceTarget = Join-Path (Split-Path $collisionManifest) 'Program.bas'
Assert-PreservedFailure 'input-output collision' @('--build',$collisionManifest,$sourceTarget,'--clang',$Clang) 'E_OUTPUT' $sourceTarget
Assert-PreservedFailure 'IR publication frontend diagnostic' @('--emit-llvm',$invalid,$oracleIR) 'E_NAME' $oracleIR
$unsupported = @(
    @{ Name='root explicit Raise boundary'; Bodies=@("Function Main() As Long`nErr.Raise 5`nEnd Function"); Modules=@('Example') },
    @{ Name='module lifecycle hook boundary'; Bodies=@("Private Sub Module_Initialize()`nEnd Sub`nFunction Main() As Long`nEnd Function"); Modules=@('Example') },
    @{ Name='potentially failing If header boundary'; Bodies=@("Function Main() As Long`nIf Check() = 1 Then Main = 0`nEnd Function`nFunction Check() As Long`nCheck = 1`nEnd Function"); Modules=@('Example') },
    @{ Name='potential initialization cycle boundary'; Bodies=@("Public Value As Long = Other.ReadValue()`nFunction Main() As Long`nMain = Value`nEnd Function`nFunction ReadValue() As Long`nReadValue = Value`nEnd Function", "Public Value As Long = Program.ReadValue()`nFunction ReadValue() As Long`nReadValue = Value`nEnd Function"); Modules=@('Program','Other') }
)
foreach ($case in $unsupported) {
    $manifest = New-Fixture $case.Name $case.Bodies $case.Modules 'Exe'
    Assert-PreservedFailure $case.Name @('--emit-llvm',$manifest,$oracleIR) 'E_UNSUPPORTED' $oracleIR
}
$oversizedFrame = "Function Main() As Long`n" + ((1..129 | ForEach-Object { 'Dim V' + $_ + ' As Long' }) -join "`n") + "`nEnd Function"
$manifest = New-Fixture 'native frame bound' @($oversizedFrame) @('Example') 'Exe'
Assert-PreservedFailure 'native frame bound' @('--emit-llvm',$manifest,$oracleIR) 'E_LIMIT' $oracleIR
$parameters = (1..65 | ForEach-Object { 'ByVal P' + $_ + ' As Long' }) -join ', '
$manifest = New-Fixture 'native parameter bound' @("Sub TooMany($parameters)`nEnd Sub`nFunction Main() As Long`nEnd Function") @('Example') 'Exe'
Assert-PreservedFailure 'native parameter bound' @('--emit-llvm',$manifest,$oracleIR) 'E_LIMIT' $oracleIR
$finalDemoRun = Invoke-BoundedProcess $preserved @()
Require ($finalDemoRun.ExitCode -eq 42) 'Preserved executable no longer runs correctly'
Write-Output "PASS: $($script:passed) native compilation groups; actual generated source code executed."
