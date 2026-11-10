# Verifies integer storage, checked conversions and arithmetic through binding and native execution.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube integer types ' + [guid]::NewGuid())
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

# Reconstructs the ASCII-named symbol and binding records used by these fixtures.
function Read-Bindings([string]$Manifest) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$Manifest)
    Require ($result.ExitCode -eq 0 -and $result.Stderr.Length -eq 0) "Binding failed: $($result.Evidence)"
    $symbols = @{}
    $nodes = @{}
    foreach ($line in $result.Stdout.Replace("`r`n","`n").Split("`n")) {
        if ($line.StartsWith('SYMBOL ')) {
            $f = $line.Substring(7).Split('|')
            Require ($f.Count -eq 24) 'Unexpected symbol framing'
            $symbols[[int]$f[0]] = [pscustomobject]@{ Id=[int]$f[0]; Kind=$f[1]; Name=$f[2]; Type=$f[3]; Module=[int]$f[5]; Declaration=[int]$f[7]; Mode=$f[8]; FirstParameter=[int]$f[10]; Constant=$f[13] }
        } elseif ($line.StartsWith('BOUND ')) {
            $f = $line.Substring(6).Split('|')
            Require ($f.Count -eq 16) 'Unexpected binding framing'
            $nodes[[int]$f[0]] = [pscustomobject]@{ Id=[int]$f[0]; Symbol=[int]$f[1]; Type=$f[2]; Converted=$f[3]; Mode=$f[4]; Writable=$f[5]; Constant=$f[6] }
        }
    }
    return [pscustomobject]@{ Symbols=$symbols; Nodes=$nodes }
}

# Requires one source declaration while excluding its implicit result slot.
function Find-Symbol($Bound, [string]$Name) {
    $found = @($Bound.Symbols.Values | Where-Object { $_.Name -ieq $Name -and $_.Kind -ne 'result' })
    Require ($found.Count -eq 1) "Ambiguous or missing symbol $Name"
    return $found[0]
}

# Requires controlled rejection at a source location with no success publication.
function Assert-Rejected([string]$Name, [string]$Body, [string]$Code) {
    $manifest = New-Fixture $Name @($Body) @('Example') 'Library'
    $result = Invoke-BoundedProcess $BootstrapExe @('--analyze',$manifest)
    Require ($result.ExitCode -eq 1 -and $result.Stderr -match ('(?m)^UBE: ' + [regex]::Escape($Code) + ':') -and $result.Stderr -match 'Example\.bas:\d+:\d+' -and $result.Stdout -notmatch 'ANALYZE OK') "$Name expected $Code with location: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: $Name"
}

$types = @('Byte','Integer','Long','LongLong','Boolean')
$matrix = @('UBE SOURCE 1 MODULE','Attribute UBE_Name = "ConversionMatrix"',"' Covers every admitted scalar assignment, argument and result conversion.")
foreach ($source in $types) {
    foreach ($destination in $types) {
        $matrix += @("' Converts a runtime argument at the function-result boundary.","Public Function From${source}To${destination}(ByVal Value As $source) As $destination", "    From${source}To${destination} = Value",'End Function')
    }
}
foreach ($destination in $types) {
    $matrix += @("' Preserves a typed argument to expose its caller conversion.","Public Function Echo${destination}(ByVal Value As $destination) As $destination", "    Echo${destination} = Value",'End Function')
}
$matrix += @("' Observes every conversion pair using mutable runtime source values.",'Public Function CheckMatrix(ByVal Seed As Long) As Long')
foreach ($type in $types) {
    $value = 'Seed'
    if ($type -eq 'Boolean') { $value = 'False' }
    $matrix += @("    Dim Source$type As $type = $value", "    Dim Target$type As $type")
}
$assertion = 0
foreach ($source in $types) {
    foreach ($destination in $types) {
        $expected = '1'
        if ($source -eq 'Boolean') { $expected = '0' }
        if ($destination -eq 'Boolean') { $expected = 'True'; if ($source -eq 'Boolean') { $expected = 'False' } }
        foreach ($expression in @("Source$source", "From${source}To${destination}(Source$source)", "Echo${destination}(Source$source)")) {
            $assertion++
            $matrix += @("    Target$destination = $expression", "    If Target$destination <> $expected Then CheckMatrix = $assertion`: Exit Function")
        }
    }
}
$matrix += '    SourceBoolean = True'
foreach ($destination in @('Integer','Long','LongLong')) {
    $assertion++
    $matrix += @("    Target$destination = FromBooleanTo${destination}(SourceBoolean)", "    If Target$destination <> -1 Then CheckMatrix = $assertion`: Exit Function")
}
$matrix += @('    CheckMatrix = 0','End Function')
$matrixPath = Join-Path $artifacts 'ConversionMatrix.bas'
Write-Text $matrixPath (($matrix -join "`r`n") + "`r`n")
$manifest = Copy-Fixtures 'integer library' @((Join-Path $PSScriptRoot 'fixtures/IntegerProbe.bas'),$matrixPath) '0' 'Library'
$bound = Read-Bindings $manifest
foreach ($constant in @(
    @{ Name='ByteMax'; Type='Byte'; Value='255' }, @{ Name='IntegerMin'; Type='Integer'; Value='-32768' },
    @{ Name='IntegerMax'; Type='Integer'; Value='32767' }, @{ Name='LongMin'; Type='Long'; Value='-2147483648' },
    @{ Name='LongMax'; Type='Long'; Value='2147483647' }, @{ Name='LongLongMin'; Type='LongLong'; Value='-9223372036854775808' },
    @{ Name='LongLongMax'; Type='LongLong'; Value='9223372036854775807' }, @{ Name='ContextWide'; Type='LongLong'; Value='2147483648' },
    @{ Name='NarrowAfterWide'; Type='Integer'; Value='30000' }
)) {
    $symbol = Find-Symbol $bound $constant.Name
    Require ($symbol.Type -eq $constant.Type -and $symbol.Constant -eq $constant.Value) "Typed constant mismatch: $($constant.Name)"
}
foreach ($source in $types) {
    foreach ($destination in $types) {
        $symbol = Find-Symbol $bound "From${source}To${destination}"
        Require ($symbol.Type -eq $destination -and $bound.Symbols[$symbol.FirstParameter].Type -eq $source -and $bound.Symbols[$symbol.FirstParameter].Mode -eq 'ByVal') 'Conversion signature type mismatch'
    }
}
Require (@($bound.Nodes.Values | Where-Object { $_.Mode -eq 'temp' -and $_.Type -eq 'Long' -and $_.Converted -eq 'Byte' }).Count -eq 2) 'Grouped Byte temporary conversion evidence missing'
foreach ($type in @('Byte','Integer','Long','LongLong')) { Require (@($bound.Nodes.Values | Where-Object { $_.Mode -eq 'alias' -and $_.Type -eq $type -and $_.Writable -eq '1' }).Count -ge 1) "Missing exact $type ByRef alias evidence" }
$ast = Invoke-BoundedProcess $BootstrapExe @('--dump-ast',$manifest)
Require ($ast.ExitCode -eq 0) 'Cannot inspect integer expression structure'
$byteOperations = @()
foreach ($line in $ast.Stdout.Replace("`r`n","`n").Split("`n")) {
    if ($line.StartsWith('NODE ')) {
        $f = $line.Substring(5).Split('|')
        if ($f[3] -eq '0' -and $f[1] -eq 'binary' -and $f[2] -eq '+' -and $f[4] -eq '17') { $byteOperations += [int]$f[0] }
    }
}
Require ($byteOperations.Count -eq 1 -and $bound.Nodes[$byteOperations[0]].Type -eq 'Integer') 'Byte+Byte did not retain promoted Integer operation'
$script:passed++
Write-Output 'PASS: integer ranges, contextual constants, typed signatures, promoted Byte arithmetic and ByRef records'

$ir = Join-Path $artifacts 'integers.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$checks = @('CheckArithmetic','CheckFailures','CheckByRef','CheckMatrix')
$harness = @('@test.input = global i64 1','@test.context = private global %ube.context zeroinitializer, align 8','define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0')
$prior = '0'
for ($index = 0; $index -lt $checks.Count; $index++) {
    $symbol = Find-Symbol $bound $checks[$index]
    $bit = 1 -shl $index
    $harness += @('  call void @ube.context.init(ptr %ctx)',"  %init$index = call i1 @ube.project.init(ptr %ctx)","  %input$index = load volatile i64, ptr @test.input","  %pair$index = call { i1, i64 } @ube.proc.$($symbol.Id)(ptr %ctx, i64 %input$index)","  %ok$index = extractvalue { i1, i64 } %pair$index, 0","  %value$index = extractvalue { i1, i64 } %pair$index, 1","  %zero$index = icmp eq i64 %value$index, 0","  %good$index = and i1 %ok$index, %zero$index","  %ready$index = and i1 %good$index, %init$index","  %fail$index = select i1 %ready$index, i32 0, i32 $bit","  %mask$index = or i32 $prior, %fail$index")
    $prior = '%mask' + $index
}
$harness += @("  ret i32 $prior",'}')
$combined = Join-Path $artifacts 'integers-with-harness.ll'
Write-Text $combined ([IO.File]::ReadAllText($ir,$utf8) + "`r`n" + ($harness -join "`r`n") + "`r`n")
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ('integers-' + $level + '.exe')
    Build-Harness $combined $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Integer runtime check failed at $level; mask=$($result.ExitCode) (1 arithmetic,2 failures,4 ByRef,8 matrix). Evidence: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: integer actual-source runtime checks $level"
}
$control = Join-Path $artifacts 'integers-input-zero.ll'
Write-Text $control ([IO.File]::ReadAllText($combined,$utf8).Replace('@test.input = global i64 1','@test.input = global i64 0'))
$controlExe = Join-Path $artifacts 'integers-input-zero.exe'
Build-Harness $control $controlExe 'O2'
$controlRun = Invoke-BoundedProcess $controlExe @()
Require ($controlRun.ExitCode -eq 15) "Changed runtime input must fail all four independent checks, got $($controlRun.ExitCode)"
$script:passed++
Write-Output 'PASS: runtime-input negative control detects all four integer oracle failures'

# Generates typed runtime probes for every permitted cell at representable boundaries.
$boundarySource = @('UBE SOURCE 1 MODULE','Attribute UBE_Name = "BoundaryMatrix"',"' Verifies conversion boundaries without compile-time source-value substitution.")
foreach ($source in $types) {
    foreach ($destination in $types) {
        $sentinel = '1'
        if ($destination -eq 'Boolean') { $sentinel = 'True' }
        $boundarySource += @(
            "' Preserves initialized destination storage when checked conversion fails.",
            "Public Function Boundary${source}To${destination}(ByVal RuntimeValue As $source, ByVal Expected As LongLong, ByVal ExpectedError As Long) As Long",
            "    Dim Actual As $destination = $sentinel", '    Dim Observed As LongLong',
            '    Err.Clear','    Actual = RuntimeValue',
            "    If Err.Number <> ExpectedError Then Boundary${source}To${destination} = 1: Exit Function",
            '    Observed = Actual',
            "    If Observed <> Expected Then Boundary${source}To${destination} = 2: Exit Function",
            "    Boundary${source}To${destination} = 0",'End Function'
        )
    }
}
$boundarySourcePath = Join-Path $artifacts 'BoundaryMatrix.bas'
Write-Text $boundarySourcePath (($boundarySource -join "`r`n") + "`r`n")
$boundaryManifest = Copy-Fixtures 'integer boundary library' @($boundarySourcePath) '0' 'Library'
$boundaryBound = Read-Bindings $boundaryManifest
$boundaryIR = Join-Path $artifacts 'integer-boundaries.ll'
$null = Invoke-Compiler @('--emit-llvm',$boundaryManifest,$boundaryIR) 'EMIT OK'
$ranges = @{
    Byte=@([decimal]0,[decimal]255)
    Integer=@([decimal]-32768,[decimal]32767)
    Long=@([decimal]-2147483648,[decimal]2147483647)
    LongLong=@([decimal]::Parse('-9223372036854775808'),[decimal]::Parse('9223372036854775807'))
    Boolean=@([decimal]-1,[decimal]0)
}
$boundaryCases = New-Object 'Collections.Generic.List[object]'
foreach ($source in $types) {
    foreach ($destination in $types) {
        $sourceRange = $ranges[$source]
        $targetRange = $ranges[$destination]
        $candidates = @($sourceRange[0],$sourceRange[1],[decimal]0)
        if ($destination -eq 'Boolean') {
            $candidates += @([decimal]-1,[decimal]1)
        } else {
            $candidates += @(($targetRange[0] - 1),$targetRange[0],($targetRange[0] + 1),($targetRange[1] - 1),$targetRange[1],($targetRange[1] + 1))
        }
        $unique = @{}
        foreach ($candidate in $candidates) {
            if ($candidate -ge $sourceRange[0] -and $candidate -le $sourceRange[1]) {
                $text = $candidate.ToString([Globalization.CultureInfo]::InvariantCulture)
                $unique[$text] = $candidate
            }
        }
        foreach ($inputValue in @($unique.Values | Sort-Object)) {
            $expectedError = 0
            $expected = $inputValue
            if ($destination -eq 'Boolean') {
                $expected = [decimal]0
                if ($inputValue -ne 0) { $expected = [decimal]-1 }
            } elseif ($inputValue -lt $targetRange[0] -or $inputValue -gt $targetRange[1]) {
                $expectedError = 6
                $expected = [decimal]1
            }
            $symbol = Find-Symbol $boundaryBound "Boundary${source}To${destination}"
            $boundaryCases.Add([pscustomobject]@{ Source=$source; Destination=$destination; Input=$inputValue.ToString([Globalization.CultureInfo]::InvariantCulture); Expected=$expected.ToString([Globalization.CultureInfo]::InvariantCulture); ExpectedError=$expectedError; Symbol=$symbol.Id })
        }
    }
}
Write-Text (Join-Path $artifacts 'integer-boundary-cases.json') ($boundaryCases | ConvertTo-Json -Depth 3)
$boundaryHarness = @'
@test.boundary.input = global i64 0
@test.boundary.context = private global %ube.context zeroinitializer, align 8
define i32 @test.boundary.run(ptr %procedure, i64 %input, i64 %expected, i64 %error) {
entry:
  %ctx = getelementptr %ube.context, ptr @test.boundary.context, i32 0
  call void @ube.context.init(ptr %ctx)
  %initialized = call i1 @ube.project.init(ptr %ctx)
  store volatile i64 %input, ptr @test.boundary.input
  %runtime = load volatile i64, ptr @test.boundary.input
  %result = call { i1, i64 } %procedure(ptr %ctx, i64 %runtime, i64 %expected, i64 %error)
  %success = extractvalue { i1, i64 } %result, 0
  %value = extractvalue { i1, i64 } %result, 1
  %zero = icmp eq i64 %value, 0
  %valid = and i1 %success, %zero
  %ready = and i1 %initialized, %valid
  %status = select i1 %ready, i32 0, i32 1
  ret i32 %status
}
define i32 @main() {
entry:
  br label %case0
'@
$boundaryLines = @($boundaryHarness)
for ($index = 0; $index -lt $boundaryCases.Count; $index++) {
    $case = $boundaryCases[$index]
    $next = 'case' + ($index + 1)
    if ($index -eq $boundaryCases.Count - 1) { $next = 'passed' }
    $boundaryLines += @("case${index}:","  %result$index = call i32 @test.boundary.run(ptr @ube.proc.$($case.Symbol), i64 $($case.Input), i64 $($case.Expected), i64 $($case.ExpectedError))","  %ok$index = icmp eq i32 %result$index, 0","  br i1 %ok$index, label %$next, label %failed$index","failed${index}:","  ret i32 $($index + 1)")
}
$boundaryLines += @('passed:','  ret i32 0','}')
$boundaryCombined = Join-Path $artifacts 'integer-boundaries-with-harness.ll'
Write-Text $boundaryCombined ([IO.File]::ReadAllText($boundaryIR,$utf8) + "`r`n" + ($boundaryLines -join "`r`n") + "`r`n")
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ('boundaries-' + $level + '.exe')
    Build-Harness $boundaryCombined $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Boundary case $($result.ExitCode) failed at $level; see integer-boundary-cases.json in $artifacts"
    $script:passed++
    Write-Output "PASS: all 25 conversion cells with $($boundaryCases.Count) runtime boundary cases at $level"
}

$invalidConstants = @(
    @{ Name='Byte negative'; Body='Const X As Byte = -1' },
    @{ Name='Byte above max'; Body='Const X As Byte = 256' },
    @{ Name='Integer below min'; Body='Const X As Integer = -32769' },
    @{ Name='Integer above max'; Body='Const X As Integer = 32768' },
    @{ Name='Long below min'; Body='Const X As Long = -2147483649' },
    @{ Name='Long above max'; Body='Const X As Long = 2147483648' },
    @{ Name='LongLong below min'; Body='Const X As LongLong = -9223372036854775809' },
    @{ Name='LongLong above max'; Body='Const X As LongLong = 9223372036854775808' },
    @{ Name='Boolean True into Byte'; Body='Const X As Byte = True' },
    @{ Name='Integer suffixed intermediate overflow'; Body='Const X As LongLong = 32767% + 1%' },
    @{ Name='Long suffixed intermediate overflow'; Body='Const X As LongLong = 2147483647& + 1&' },
    @{ Name='LongLong suffixed intermediate overflow'; Body='Const X As LongLong = 9223372036854775807^ + 1^' },
    @{ Name='Integer invalid suffixed magnitude'; Body='Const X As LongLong = 32768%' },
    @{ Name='grouped Integer magnitude not signed literal'; Body='Const X As Integer = -(32768%)' },
    @{ Name='grouped LongLong magnitude not signed literal'; Body='Const X As LongLong = -(9223372036854775808^)' }
)
foreach ($case in $invalidConstants) { Assert-Rejected $case.Name $case.Body 'E_CONSTANT' }
Assert-Rejected 'conflicting declaration suffix' 'Dim Value% As Long' 'E_PARSE'
Assert-Rejected 'mismatched variable use suffix' "Sub Run()`nDim Value As Integer`nValue& = 1`nEnd Sub" 'E_TYPE'
Assert-Rejected 'mismatched function use suffix' "Function Value^()`nValue^ = 1`nEnd Function`nSub Run()`nDim X As LongLong = Value%()`nEnd Sub" 'E_TYPE'
Assert-Rejected 'suffix does not create new identity' "Dim Value%`nDim [value] As Integer" 'E_DUPLICATE'
foreach ($source in $types) {
    foreach ($destination in $types) {
        if ($source -ne $destination) {
            Assert-Rejected ("ByRef $source to $destination") ("Sub Take(ByRef Value As $destination)`nEnd Sub`nSub Run()`nDim Value As $source`nTake Value`nEnd Sub") 'E_ARGUMENT'
        }
    }
}
$invalid = New-Fixture 'invalid unchanged artifact' @('Const X As Byte = 256') @('Example') 'Library'
Assert-PreservedFailure 'integer frontend failure' @('--emit-llvm',$invalid,$ir) 'E_CONSTANT' $ir
Write-Output "PASS: $($script:passed) integer type groups; source-generated native checks and scoped semantic diagnostics."
