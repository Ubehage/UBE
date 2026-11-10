# Verifies scanner allocation failures without replacing production allocation or publication logic.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube scanner allocation ' + [guid]::NewGuid())
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

# Resolves compiler-owned procedure identifiers from the unchanged bound dump.
function Read-Procedures([string]$Manifest) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$Manifest)
    Require ($result.ExitCode -eq 0) "Binding failed: $($result.Evidence)"
    $procedures = @{}
    foreach ($line in $result.Stdout.Split("`n")) {
        if ($line.StartsWith('SYMBOL ')) {
            $fields = $line.TrimEnd("`r").Substring(7).Split('|')
            Require ($fields.Count -eq 24) 'Unexpected bound symbol framing'
            if ($fields[1] -eq 'function') { $procedures[$fields[2]] = [int]$fields[0] }
        }
    }
    return $procedures
}

# Retains the actual scanner and portable UTF-8 implementation without source rewriting.
$coreDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$scanner = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src/SourceScanner.bas'))
$manifest = Copy-Fixtures 'scanner allocation library' @((Join-Path $coreDirectory 'BufferPrimitives.bas'),(Join-Path $coreDirectory 'Utf8.bas'),$scanner,(Join-Path $PSScriptRoot 'AllocationProbe.bas')) '0' 'Library'
$procedures = Read-Procedures $manifest
$ir = Join-Path $artifacts 'scanner.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$observed = [IO.File]::ReadAllText($ir,$utf8)
foreach ($name in @('allocate','release')) {
    $pattern = '(?m)^(define[^\r\n@]*?)@ube\.target\.' + $name + '\('
    Require ([regex]::Matches($observed,$pattern).Count -eq 1) "Missing allocation wrapper $name"
    $observed = [regex]::Replace($observed,$pattern,('${1}@test.real.' + $name + '('))
}
$observer = @'
@test.calls = global i64 0
@test.fail.at = global i64 0
@test.failed = global i64 0
@test.live = global i64 0
define ptr @ube.target.allocate(i64 %bytes) {
entry:
  %old.calls = load i64, ptr @test.calls
  %calls = add i64 %old.calls, 1
  store i64 %calls, ptr @test.calls
  %at = load i64, ptr @test.fail.at
  %retry = add i64 %at, 1
  %first = icmp eq i64 %calls, %at
  %second = icmp eq i64 %calls, %retry
  %selected = or i1 %first, %second
  %enabled = icmp ne i64 %at, 0
  %fail = and i1 %selected, %enabled
  br i1 %fail, label %failed, label %allocate
failed:
  %old.failed = load i64, ptr @test.failed
  %failed.count = add i64 %old.failed, 1
  store i64 %failed.count, ptr @test.failed
  ret ptr null
allocate:
  %block = call ptr @test.real.allocate(i64 %bytes)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %record, label %done
record:
  %old.live = load i64, ptr @test.live
  %live = add i64 %old.live, 1
  store i64 %live, ptr @test.live
  br label %done
done:
  ret ptr %block
}
define i1 @ube.target.release(ptr %block) {
entry:
  %ok = call i1 @test.real.release(ptr %block)
  br i1 %ok, label %record, label %done
record:
  %old.live = load i64, ptr @test.live
  %live = sub i64 %old.live, 1
  store i64 %live, ptr @test.live
  br label %done
done:
  ret i1 %ok
}
'@
$observed += "`r`n" + $observer
foreach ($stage in 1..4) {
    $harness = @'
@test.context = private global %ube.context zeroinitializer, align 8
define i32 @main() {
entry:
  %ctx = getelementptr %ube.context, ptr @test.context, i32 0
  call void @ube.context.init(ptr %ctx)
  %init = call i1 @ube.project.init(ptr %ctx)
  %setup = call { i1, i64 } @ube.proc.PREPARE(ptr %ctx)
  %setup.ok = extractvalue { i1, i64 } %setup, 0
  %setup.value = extractvalue { i1, i64 } %setup, 1
  %setup.zero = icmp eq i64 %setup.value, 0
  %a = and i1 %setup.ok, %setup.zero
  %ready = and i1 %a, %init
  store i64 0, ptr @test.calls
  store i64 STAGE, ptr @test.fail.at
  %rejected = call { i1, i64 } @ube.proc.REJECT(ptr %ctx)
  %rejected.ok = extractvalue { i1, i64 } %rejected, 0
  %rejected.value = extractvalue { i1, i64 } %rejected, 1
  %rejected.zero = icmp eq i64 %rejected.value, 0
  %rejection = and i1 %rejected.ok, %rejected.zero
  %calls = load i64, ptr @test.calls
  %expected.calls = icmp eq i64 %calls, ATTEMPTS
  %failed = load i64, ptr @test.failed
  %both.failed = icmp eq i64 %failed, 2
  %retained = load i64, ptr @test.live
  %only.owners = icmp eq i64 %retained, 2
  store i64 0, ptr @test.calls
  store i64 0, ptr @test.fail.at
  %retry = call { i1, i64 } @ube.proc.RETRY(ptr %ctx)
  %retry.ok = extractvalue { i1, i64 } %retry, 0
  %retry.value = extractvalue { i1, i64 } %retry, 1
  %retry.zero = icmp eq i64 %retry.value, 0
  %retried = and i1 %retry.ok, %retry.zero
  %retry.calls = load i64, ptr @test.calls
  %four.calls = icmp eq i64 %retry.calls, 4
  %disposed = call i1 @ube.context.dispose(ptr %ctx)
  %live = load i64, ptr @test.live
  %clean = icmp eq i64 %live, 0
  %b = and i1 %ready, %rejection
  %c = and i1 %expected.calls, %both.failed
  %d = and i1 %only.owners, %retried
  %e = and i1 %four.calls, %disposed
  %f = and i1 %b, %c
  %g = and i1 %d, %e
  %h = and i1 %f, %g
  %all = and i1 %h, %clean
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
'@
    $harness = $harness.Replace('ube.proc.PREPARE',('ube.proc.'+$procedures['Prepare'])).Replace('ube.proc.REJECT',('ube.proc.'+$procedures['RejectAllocation'])).Replace('ube.proc.RETRY',('ube.proc.'+$procedures['RetryScan'])).Replace('STAGE',[string]$stage).Replace('ATTEMPTS',[string]($stage+1))
    $combined = Join-Path $artifacts ("allocation-$stage.ll")
    Write-Text $combined ($observed + "`r`n" + $harness)
    foreach ($level in @('O0','O2')) {
        $exe = Join-Path $artifacts ("allocation-$stage-$level.exe")
        Build-Harness $combined $exe $level
        $result = Invoke-BoundedProcess $exe @()
        Require ($result.ExitCode -eq 0) "Allocation stage $stage $level failed: $($result.Evidence)"
        $script:passed++
        Write-Output "PASS: allocation stage $stage $level preserves tokens, retries, and releases all owners"
    }
}

# Exercises helper entry refusal at several depths, including both quoted and ordinary scanning paths.
foreach ($quoted in @(0,-1)) {
    foreach ($depth in 249..256) {
        $harness = @'
@test.context = private global %ube.context zeroinitializer, align 8
define i32 @main() {
entry:
  %ctx = getelementptr %ube.context, ptr @test.context, i32 0
  call void @ube.context.init(ptr %ctx)
  %init = call i1 @ube.project.init(ptr %ctx)
  %setup = call { i1, i64 } @ube.proc.PREPAREDEPTH(ptr %ctx, i64 QUOTED)
  %setup.ok = extractvalue { i1, i64 } %setup, 0
  %setup.value = extractvalue { i1, i64 } %setup, 1
  %setup.zero = icmp eq i64 %setup.value, 0
  %ready = and i1 %setup.ok, %setup.zero
  %depth.ptr = getelementptr %ube.context, ptr %ctx, i32 0, i32 1
  store i64 DEPTH, ptr %depth.ptr
  %attempt = call { i1, i64 } @ube.proc.ATTEMPT(ptr %ctx)
  store i64 0, ptr %depth.ptr
  %fresh = extractvalue { i1, i64 } %attempt, 0
  %value = extractvalue { i1, i64 } %attempt, 1
  %true = icmp ne i64 %value, 0
  %success = and i1 %fresh, %true
  %status = select i1 %success, i64 -1, i64 0
  %checked = call { i1, i64 } @ube.proc.CHECKDEPTH(ptr %ctx, i64 %status, i64 QUOTED)
  %checked.ok = extractvalue { i1, i64 } %checked, 0
  %checked.value = extractvalue { i1, i64 } %checked, 1
  %checked.zero = icmp eq i64 %checked.value, 0
  %contents = and i1 %checked.ok, %checked.zero
  %room = icmp eq i64 DEPTH, 249
  %required.failure = icmp uge i64 DEPTH, 254
  %failed = xor i1 %success, true
  %low.good = select i1 %room, i1 %success, i1 true
  %high.good = select i1 %required.failure, i1 %failed, i1 true
  %disposed = call i1 @ube.context.dispose(ptr %ctx)
  %live = load i64, ptr @test.live
  %clean = icmp eq i64 %live, 0
  %a = and i1 %init, %ready
  %b = and i1 %contents, %disposed
  %c = and i1 %low.good, %high.good
  %d = and i1 %a, %b
  %e = and i1 %c, %clean
  %all = and i1 %d, %e
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
'@
        $harness = $harness.Replace('ube.proc.PREPAREDEPTH',('ube.proc.'+$procedures['PrepareDepth'])).Replace('ube.proc.ATTEMPT',('ube.proc.'+$procedures['DepthAttempt'])).Replace('ube.proc.CHECKDEPTH',('ube.proc.'+$procedures['CheckDepth'])).Replace('QUOTED',[string]$quoted).Replace('DEPTH',[string]$depth)
        $combined = Join-Path $artifacts ("depth-$depth-$quoted.ll")
        Write-Text $combined ($observed + "`r`n" + $harness)
        foreach ($level in @('O0','O2')) {
            $exe = Join-Path $artifacts ("depth-$depth-$quoted-$level.exe")
            Build-Harness $combined $exe $level
            $result = Invoke-BoundedProcess $exe @() 5000
            Require ($result.ExitCode -eq 0) "Depth $depth quoted=$quoted $level failed: $($result.Evidence)"
            $script:passed++
            Write-Output "PASS: depth $depth quoted=$quoted $level terminates with complete or preserved output"
        }
    }
}

# Invalid storage bases must be rejected before allocating or publishing scanner candidates.
$boundsHarness = @'
@test.context = private global %ube.context zeroinitializer, align 8
define i32 @main() {
entry:
  %ctx = getelementptr %ube.context, ptr @test.context, i32 0
  call void @ube.context.init(ptr %ctx)
  %init = call i1 @ube.project.init(ptr %ctx)
  %setup = call { i1, i64 } @ube.proc.PREPARE(ptr %ctx)
  %setup.ok = extractvalue { i1, i64 } %setup, 0
  %setup.value = extractvalue { i1, i64 } %setup, 1
  %setup.zero = icmp eq i64 %setup.value, 0
  %ready = and i1 %setup.ok, %setup.zero
  store i64 0, ptr @test.calls
  %result = call { i1, i64 } @ube.proc.BOUNDS(ptr %ctx)
  %ok = extractvalue { i1, i64 } %result, 0
  %value = extractvalue { i1, i64 } %result, 1
  %zero = icmp eq i64 %value, 0
  %good = and i1 %ok, %zero
  %calls = load i64, ptr @test.calls
  %no.allocations = icmp eq i64 %calls, 0
  %disposed = call i1 @ube.context.dispose(ptr %ctx)
  %live = load i64, ptr @test.live
  %clean = icmp eq i64 %live, 0
  %a = and i1 %init, %ready
  %b = and i1 %good, %no.allocations
  %c = and i1 %disposed, %clean
  %d = and i1 %a, %b
  %all = and i1 %d, %c
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
'@
$boundsHarness = $boundsHarness.Replace('ube.proc.PREPARE',('ube.proc.'+$procedures['Prepare'])).Replace('ube.proc.BOUNDS',('ube.proc.'+$procedures['CheckBounds']))
$boundsIR = Join-Path $artifacts 'invalid-bounds.ll'
Write-Text $boundsIR ($observed + "`r`n" + $boundsHarness)
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ("invalid-bounds-$level.exe")
    Build-Harness $boundsIR $exe $level
    $result = Invoke-BoundedProcess $exe @() 5000
    Require ($result.ExitCode -eq 0) "Nonzero source bounds $level failed: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: nonzero source bounds $level reject before candidate allocation and publication"
}
Write-Output "PASS: $script:passed scanner allocation/depth/bounds checks"
