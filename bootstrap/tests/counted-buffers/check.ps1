# Verifies counted-buffer primitives and ordinary UBECore publication behavior.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube counted buffers ' + [guid]::NewGuid())
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

. (Join-Path $PSScriptRoot '../NativeMemory.ps1')
# Compiles the same generated library+harness IR at a selected optimization level.
function Build-Harness([string]$IR, [string]$Exe, [string]$Level) {
    $linkArguments = @(Get-NativeMemoryLinkArguments $IR $Clang $artifacts)
    $arguments = @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR) + $linkArguments + @('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
    $result = Invoke-BoundedProcess $Clang $arguments
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

# Reads the existing symbol/binding prefix for ASCII-named primitive fixtures.
function Read-Bindings([string]$Manifest) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$Manifest)
    Require ($result.ExitCode -eq 0 -and $result.Stderr.Length -eq 0) "Binding failed: $($result.Evidence)"
    $symbols = @{}
    $nodes = @{}
    foreach ($line in $result.Stdout.Replace("`r`n","`n").Split("`n")) {
        if ($line.StartsWith('SYMBOL ')) {
            $f = $line.Substring(7).Split('|')
            Require ($f.Count -eq 24) 'Unexpected symbol framing'
            $symbols[[int]$f[0]] = [pscustomobject]@{ Id=[int]$f[0]; Kind=$f[1]; Name=$f[2]; Type=$f[3]; Module=[int]$f[5]; Mode=$f[8]; Role=$f[9]; FirstParameter=[int]$f[10]; Rank=[int]$f[15] }
        } elseif ($line.StartsWith('BOUND ')) {
            $f = $line.Substring(6).Split('|')
            Require ($f.Count -eq 16) 'Unexpected binding framing'
            $nodes[[int]$f[0]] = [pscustomobject]@{ Id=[int]$f[0]; Symbol=[int]$f[1]; Type=$f[2]; Converted=$f[3]; Mode=$f[4] }
        }
    }
    return [pscustomobject]@{ Symbols=$symbols; Nodes=$nodes }
}

# Resolves a unique source procedure identity in the ordered module list.
function Find-Procedure($Bound, [string]$Name, [int]$Module = -1) {
    $found = @($Bound.Symbols.Values | Where-Object { $_.Kind -eq 'function' -and $_.Name -ieq $Name -and ($Module -lt 0 -or $_.Module -eq $Module) })
    Require ($found.Count -eq 1) "Expected one function $Name"
    return $found[0]
}

# Requires declaration validation failure with a source location and no success marker.
function Assert-Rejected([string]$Name, [string]$Body, [string]$Code, [string]$Kind = 'Library') {
    $manifest = New-Fixture $Name @($Body) @('Example') $Kind
    $result = Invoke-BoundedProcess $BootstrapExe @('--analyze',$manifest)
    Require ($result.ExitCode -eq 1 -and $result.Stderr -match ('(?m)^UBE: ' + [regex]::Escape($Code) + ':') -and $result.Stderr -match 'Example\.bas:\d+:\d+' -and $result.Stdout -notmatch 'ANALYZE OK') "$Name expected $Code with location. Evidence: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: $Name"
}

$coreProject = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/UBECore.UBE'))
$core = Read-Bindings $coreProject
Require ((Find-Procedure $core 'ByteStorageLength').Role -eq 'array.length' -and (Find-Procedure $core 'CopyByteRange').Role -eq 'memory.copybytes' -and (Find-Procedure $core 'AppendBytes').Role -eq '') 'UBECore source roles or ordinary append identity mismatch'
$script:passed++
Write-Output 'PASS: actual UBECore project binds only explicit primitive declarations'
$coreDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$manifest = Copy-Fixtures 'counted buffer library' @((Join-Path $coreDirectory 'BufferPrimitives.bas'),(Join-Path $coreDirectory 'ByteBuffers.bas'),(Join-Path $PSScriptRoot 'fixtures/BufferProbe.bas')) '0' 'Library'
$bound = Read-Bindings $manifest
foreach ($binding in @(
    @{ Name='ByteStorageLength'; Module=0; Role='array.length' },
    @{ Name='CopyByteRange'; Module=0; Role='memory.copybytes' },
    @{ Name='CountEntries'; Module=2; Role='array.length' },
    @{ Name='MovePayload'; Module=2; Role='memory.copybytes' }
)) {
    $symbol = Find-Procedure $bound $binding.Name $binding.Module
    Require ($symbol.Role -eq $binding.Role -and @($bound.Nodes.Values | Where-Object { $_.Symbol -eq $symbol.Id }).Count -gt 0) "Primitive role identity not referenced: $($binding.Name)"
}
$ordinary = Find-Procedure $bound 'CopyByteRange' 2
$append = Find-Procedure $bound 'AppendBytes' 1
Require ($ordinary.Role -eq '' -and $append.Role -eq '') 'Ordinary source declaration acquired primitive meaning by spelling'
$script:passed++
Write-Output 'PASS: renamed and casefolded primitive bindings retain identity; ordinary declarations remain source code'
$ir = Join-Path $artifacts 'counted-buffers.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$checks = @('CheckCopies','CheckStatus','CheckAppend','CheckAppendValidation','CheckConversion')
$harness = @('@test.input = global i64 1','@test.context = private global %ube.context zeroinitializer, align 8','define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0')
$prior = '0'
for ($index = 0; $index -lt $checks.Count; $index++) {
    $symbol = Find-Procedure $bound $checks[$index] 2
    $bit = 1 -shl $index
    $harness += @('  call void @ube.context.init(ptr %ctx)',"  %init$index = call i1 @ube.project.init(ptr %ctx)","  %input$index = load volatile i64, ptr @test.input","  %pair$index = call { i1, i64 } @ube.proc.$($symbol.Id)(ptr %ctx, i64 %input$index)","  %ok$index = extractvalue { i1, i64 } %pair$index, 0","  %value$index = extractvalue { i1, i64 } %pair$index, 1","  %zero$index = icmp eq i64 %value$index, 0","  %good$index = and i1 %ok$index, %zero$index","  %disposed$index = call i1 @ube.context.dispose(ptr %ctx)","  %available$index = and i1 %init$index, %disposed$index","  %ready$index = and i1 %good$index, %available$index","  %fail$index = select i1 %ready$index, i32 0, i32 $bit","  %mask$index = or i32 $prior, %fail$index")
    $prior = '%mask' + $index
}
$harness += @("  ret i32 $prior",'}')
$combined = Join-Path $artifacts 'counted-buffers-with-harness.ll'
Write-Text $combined ([IO.File]::ReadAllText($ir,$utf8) + "`r`n" + ($harness -join "`r`n") + "`r`n")
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ('counted-buffers-' + $level + '.exe')
    Build-Harness $combined $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Counted buffer checks failed at $level; mask=$($result.ExitCode) (1 copy,2 status,4 append,8 validation,16 conversion). Evidence: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: actual UBECore plus payload/status/append checks $level"
}
$control = Join-Path $artifacts 'counted-buffers-input-two.ll'
Write-Text $control ([IO.File]::ReadAllText($combined,$utf8).Replace('@test.input = global i64 1','@test.input = global i64 2'))
$controlExe = Join-Path $artifacts 'counted-buffers-input-two.exe'
Build-Harness $control $controlExe 'O2'
$controlRun = Invoke-BoundedProcess $controlExe @()
Require ($controlRun.ExitCode -eq 5) "Changed runtime input must fail copy and append observations only; received $($controlRun.ExitCode)"
$script:passed++
Write-Output 'PASS: changed runtime input triggers the independent copy and append observations'

$lengthHeader = 'Public Intrinsic Function Measure(ByRef Values() As Byte) As Long'
$lengthAttribute = 'Attribute Measure.UBE_Primitive = "Array.Length"'
$copyHeader = 'Public Intrinsic Function Transfer(ByRef Source() As Byte, ByVal SourceStart As Long, ByRef Destination() As Byte, ByVal DestinationStart As Long, ByVal Count As Long) As Boolean'
$copyAttribute = 'Attribute Transfer.UBE_Primitive = "Memory.CopyBytes"'
$cases = @(
    @{ Name='missing binding'; Body="$lengthHeader`nEnd Function"; Code='E_TYPE' },
    @{ Name='duplicate binding'; Body="$lengthHeader`n$lengthAttribute`n$lengthAttribute`nEnd Function"; Code='E_TYPE' },
    @{ Name='conflicting binding'; Body="$lengthHeader`n$lengthAttribute`nAttribute Measure.UBE_Primitive = `"Memory.CopyBytes`"`nEnd Function"; Code='E_TYPE' },
    @{ Name='wrong target'; Body="$lengthHeader`nAttribute Other.UBE_Primitive = `"Array.Length`"`nEnd Function"; Code='E_TYPE' },
    @{ Name='ordinary declaration binding'; Body="Function Measure(ByRef Values() As Byte) As Long`n$lengthAttribute`nEnd Function"; Code='E_TYPE' },
    @{ Name='unknown role'; Body="$lengthHeader`nAttribute Measure.UBE_Primitive = `"Array.Unknown`"`nEnd Function"; Code='E_UNSUPPORTED' },
    @{ Name='deferred collection role'; Body="$lengthHeader`nAttribute Measure.UBE_Primitive = `"Memory.Collect`"`nEnd Function"; Code='E_UNSUPPORTED' },
    @{ Name='role whitespace not trimmed'; Body="$lengthHeader`nAttribute Measure.UBE_Primitive = `" Array.Length `"`nEnd Function"; Code='E_UNSUPPORTED' },
    @{ Name='intrinsic body forbidden'; Body="$lengthHeader`n$lengthAttribute`nMeasure = 1`nEnd Function"; Code='E_PARSE' },
    @{ Name='nonstring binding'; Body="$lengthHeader`nAttribute Measure.UBE_Primitive = 1`nEnd Function"; Code='E_PARSE' },
    @{ Name='wrong attribute member'; Body="$lengthHeader`nAttribute Measure.Other = `"Array.Length`"`nEnd Function"; Code='E_UNSUPPORTED' },
    @{ Name='length result signature'; Body="Public Intrinsic Function Measure(ByRef Values() As Byte) As LongLong`n$lengthAttribute`nEnd Function"; Code='E_TYPE' },
    @{ Name='length scalar signature'; Body="Public Intrinsic Function Measure(ByRef Values As Byte) As Long`n$lengthAttribute`nEnd Function"; Code='E_TYPE' },
    @{ Name='copy element signature'; Body=($copyHeader.Replace('Source() As Byte','Source() As Integer') + "`n$copyAttribute`nEnd Function"); Code='E_TYPE' },
    @{ Name='copy offset width'; Body=($copyHeader.Replace('SourceStart As Long','SourceStart As LongLong') + "`n$copyAttribute`nEnd Function"); Code='E_TYPE' },
    @{ Name='copy count mode'; Body=($copyHeader.Replace('ByVal Count','ByRef Count') + "`n$copyAttribute`nEnd Function"); Code='E_TYPE' },
    @{ Name='copy result signature'; Body=($copyHeader.Replace('As Boolean','As Long') + "`n$copyAttribute`nEnd Function"); Code='E_TYPE' }
)
foreach ($case in $cases) { Assert-Rejected $case.Name $case.Body $case.Code }
$mainBody = "Public Intrinsic Function Main(ByRef Values() As Byte) As Long`nAttribute Main.UBE_Primitive = `"Array.Length`"`nEnd Function"
Assert-Rejected 'Intrinsic executable Main' $mainBody 'E_TYPE' 'Exe'
$libraryMain = New-Fixture 'Library Main intrinsic' @($mainBody) @('Example') 'Library'
$libraryMainBound = Read-Bindings $libraryMain
Require ((Find-Procedure $libraryMainBound 'Main').Role -eq 'array.length') 'Library procedure Main incorrectly treated as executable entry'
$script:passed++
Write-Output 'PASS: Library Main is an ordinary arbitrary intrinsic declaration name'
$invalid = New-Fixture 'invalid binding publication' @("$lengthHeader`nEnd Function") @('Example') 'Library'
Assert-PreservedFailure 'invalid primitive binding' @('--emit-llvm',$invalid,$ir) 'E_TYPE' $ir
Write-Output "PASS: $($script:passed) counted-buffer groups; actual portable UBECore source executed."
