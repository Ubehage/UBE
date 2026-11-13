# Verifies counted native file operations and ordinary UBE progress policies.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube file io ' + [guid]::NewGuid())
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

# Renames only named target definitions so injected wrappers retain the real OS implementation.
function Observe-Targets([string]$Text) {
    foreach ($name in @('allocate','release','file.open','file.size','file.read','file.write','file.flush','file.close')) {
        $pattern = '(?m)^(define[^\r\n@]*?)@ube\.target\.' + [regex]::Escape($name) + '\('
        Require ([regex]::Matches($Text,$pattern).Count -eq 1) "Missing unique target definition $name"
        $Text = [regex]::Replace($Text,$pattern,('${1}@test.real.' + $name + '('))
    }
    foreach ($probe in @(
        @{Name='path'; Store='  store volatile i8 %pack.byte, ptr %pack.target'},
        @{Name='pack'; Store='  store volatile i8 %byte, ptr %target'},
        @{Name='unpack'; Store='  store atomic volatile i64 %read.value, ptr %read.target monotonic, align 8'}
    )) {
        Require ([regex]::Matches($Text,[regex]::Escape($probe.Store)).Count -eq 1) "Missing unique movement observation point $($probe.Name)"
        $suffix = $probe.Name
        $instrument = $probe.Store + "`r`n  %test.$suffix.old = load volatile i64, ptr @test.$suffix.cells`r`n  %test.$suffix.next = add i64 %test.$suffix.old, 1`r`n  store volatile i64 %test.$suffix.next, ptr @test.$suffix.cells"
        $Text = $Text.Replace($probe.Store,$instrument)
        $Text += "`r`n@test.$suffix.cells = global i64 0`r`n"
    }
    foreach ($file in @('AllocatorObserver.ll','FileObserver.ll')) { $Text += "`r`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot ('fixtures/' + $file)),$utf8) }
    return $Text
}

# Constructs normal UBE calls that install the exact counted UTF-8 test paths.
function Path-Setup($Procedures, [string]$InputPath, [string]$OutputPath) {
    $inputBytes = $utf8.GetBytes($InputPath)
    $outputBytes = $utf8.GetBytes($OutputPath)
    $lines = @("  %configured = call { i1, i64 } @ube.proc.$($Procedures['Configure'])(ptr %ctx, i64 $($inputBytes.Length), i64 $($outputBytes.Length))",'  %config.ok = extractvalue { i1, i64 } %configured, 0','  %config.value = extractvalue { i1, i64 } %configured, 1','  %config.zero = icmp eq i64 %config.value, 0','  %config.good = and i1 %config.ok, %config.zero')
    $serial = 0
    for ($kind = 0; $kind -lt 2; $kind++) {
        $bytes = $inputBytes
        if ($kind -eq 1) { $bytes = $outputBytes }
        for ($index = 0; $index -lt $bytes.Length; $index++) {
            $lines += "  %path$serial = call { i1, i64 } @ube.proc.$($Procedures['SetPathByte'])(ptr %ctx, i64 $kind, i64 $index, i64 $($bytes[$index]))"
            $serial++
        }
    }
    return $lines
}

$coreDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$manifest = Copy-Fixtures 'file library' @((Join-Path $coreDirectory 'BufferPrimitives.bas'),(Join-Path $coreDirectory 'FilePrimitives.bas'),(Join-Path $coreDirectory 'FileBytes.bas'),(Join-Path $PSScriptRoot 'fixtures/FileProbe.bas')) '0' 'Library'
$procedures = Read-Procedures $manifest
$ir = Join-Path $artifacts 'file-io.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$observed = Observe-Targets ([IO.File]::ReadAllText($ir,$utf8))
$inputPath = Join-Path $artifacts ('source ' + [char]0x9000 + [char]0xD83D + [char]0xDE00 + '.bin')
[IO.File]::WriteAllBytes($inputPath,[byte[]]@(0,127,128,255))
$cases = @(
    @{Name='CheckPrimaryAllocationError'; Seed=1; Read=0; Write=0; Flush=0; Close=1; Size=0; Allocate=2; After=2; Prepare=0; ReadCalls=0; WriteCalls=0; Output='none'},
    @{Name='CheckRegistryCapacity'; Seed=1; Read=0; Write=0; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=0; WriteCalls=0; Output='none'},
    @{Name='CheckSizes'; Seed=0; Read=0; Write=0; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=1; WriteCalls=0; Output='empty'},
    @{Name='CheckSizes'; Seed=4096; Read=0; Write=0; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=2; WriteCalls=1; Output='capacity'},
    @{Name='CheckOpenCloseFailure'; Seed=1; Read=0; Write=0; Flush=0; Close=1; Size=0; Allocate=0; Prepare=0; ReadCalls=0; WriteCalls=0; Output='none'},
    @{Name='CheckReads'; Seed=1; Read=0; Write=0; Flush=0; Close=0; Size=0; Allocate=1; Prepare=0; ReadCalls=2; WriteCalls=0; Output='none'},
    @{Name='CheckReadAtomicity'; Seed=1; Read=1; Write=0; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=1; WriteCalls=0; Output='none'},
    @{Name='CheckInvalidRequests'; Seed=1; Read=0; Write=0; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=0; WriteCalls=0; Output='none'},
    @{Name='CheckRoundTrip'; Seed=1; Read=0; Write=0; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=2; WriteCalls=1; Output='all'},
    @{Name='CheckRoundTrip'; Seed=1; Read=2; Write=2; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=129; WriteCalls=37; Output='all'},
    @{Name='CheckReads'; Seed=1; Read=0; Write=0; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=2; WriteCalls=0; Output='none'},
    @{Name='CheckValidation'; Seed=1; Read=0; Write=0; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=0; WriteCalls=0; Output='none'},
    @{Name='CheckReadFailure'; Seed=5; Read=1; Write=0; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=1; WriteCalls=0; Output='none'},
    @{Name='CheckReadFailure'; Seed=6; Read=0; Write=0; Flush=0; Close=0; Size=1; Allocate=0; Prepare=0; ReadCalls=2; WriteCalls=0; Output='none'},
    @{Name='CheckReadFailure'; Seed=11; Read=0; Write=0; Flush=0; Close=0; Size=-1; Allocate=0; Prepare=0; ReadCalls=2; WriteCalls=0; Output='none'},
    @{Name='CheckReadFailure'; Seed=8; Read=0; Write=0; Flush=0; Close=0; Size=0; Allocate=2; Prepare=0; ReadCalls=0; WriteCalls=0; Output='none'},
    @{Name='CheckCleanupBeforeRaise'; Seed=1; Read=1; Write=0; Flush=0; Close=1; Size=0; Allocate=0; Prepare=0; ReadCalls=1; WriteCalls=0; Output='none'},
    @{Name='CheckCloseRetry'; Seed=1; Read=0; Write=0; Flush=0; Close=1; Size=0; Allocate=0; Prepare=1; ReadCalls=0; WriteCalls=0; Output='none'},
    @{Name='CheckPartialWrite'; Seed=1; Read=0; Write=1; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=0; WriteCalls=1; Output='partial'},
    @{Name='CheckWriteFailure'; Seed=15; Read=0; Write=3; Flush=0; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=0; WriteCalls=1; Output='empty'},
    @{Name='CheckWriteFailure'; Seed=16; Read=0; Write=0; Flush=1; Close=0; Size=0; Allocate=0; Prepare=0; ReadCalls=0; WriteCalls=1; Output='four'}
)
$caseNumber = 0
foreach ($case in $cases) {
    $caseNumber++
    $outputPath = Join-Path $artifacts ("output-$caseNumber.bin")
    $harness = @("@test.input = global i64 $($case.Seed)",'@test.context = private global %ube.context zeroinitializer, align 8','define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0','  call void @ube.context.init(ptr %ctx)','  %init = call i1 @ube.project.init(ptr %ctx)')
    $harness += @(Path-Setup $procedures $inputPath $outputPath)
    $harness += '  store i64 0, ptr @test.alloc.calls'
    if ($case.Prepare) {
        $harness += @("  %prepare = call { i1, i64 } @ube.proc.$($procedures['PrepareOpen'])(ptr %ctx, i64 1)",'  %prepare.ok = extractvalue { i1, i64 } %prepare, 0','  %prepare.value = extractvalue { i1, i64 } %prepare, 1','  %prepare.zero = icmp eq i64 %prepare.value, 0','  %prepare.good = and i1 %prepare.ok, %prepare.zero')
    } else { $harness += '  %prepare.good = and i1 true, true' }
    $flush = 'false'
    if ($case.Flush) { $flush = 'true' }
    $failAfter = 0
    if ($case.ContainsKey('After')) { $failAfter = $case.After }
    $harness += "  store i64 $failAfter, ptr @test.fail.after"
    $packed = 0
    $unpacked = 0
    $pathCells = $utf8.GetByteCount($inputPath)
    if ($case.Name -eq 'CheckRoundTrip') { $packed = 256; $unpacked = 256; $pathCells = 3 * $utf8.GetByteCount($outputPath); if ($case.Write -eq 2) { $packed = 4810 } }
    if ($case.Name -eq 'CheckSizes') { $packed = $case.Seed; $unpacked = $case.Seed; $pathCells = 2 * $utf8.GetByteCount($outputPath) }
    if ($case.Name -eq 'CheckRegistryCapacity') { $pathCells = 65 * $utf8.GetByteCount($inputPath) }
    if ($case.Name -eq 'CheckReads') { $unpacked = 4 }
    if ($case.Name -eq 'CheckReadFailure' -and $case.Size -ne 0) { $unpacked = 4 }
    if ($case.Allocate -eq 2 -and $failAfter -eq 0) { $pathCells = 0 }
    if ($case.Name -eq 'CheckInvalidRequests') { $pathCells = 2 + 2 * $utf8.GetByteCount($inputPath) }
    if ($case.Name -eq 'CheckPartialWrite' -or $case.Name -eq 'CheckWriteFailure') { $packed = 4; $pathCells = $utf8.GetByteCount($outputPath) }
    $harness += @("  store i32 $($case.Read), ptr @test.read.mode", "  store i32 $($case.Write), ptr @test.write.mode", "  store i1 $flush, ptr @test.flush.fail", "  store i32 $($case.Close), ptr @test.close.failures", "  store i64 $($case.Size), ptr @test.size.delta", "  store i64 $($case.Allocate), ptr @test.fail.remaining",'  %seed = load volatile i64, ptr @test.input', "  %result = call { i1, i64 } @ube.proc.$($procedures[$case.Name])(ptr %ctx, i64 %seed)",'  %ok = extractvalue { i1, i64 } %result, 0','  %value = extractvalue { i1, i64 } %result, 1','  %zero = icmp eq i64 %value, 0','  %good = and i1 %ok, %zero','  %reads = load i64, ptr @test.read.calls',"  %reads.good = icmp eq i64 %reads, $($case.ReadCalls)",'  %writes = load i64, ptr @test.write.calls',"  %writes.good = icmp eq i64 %writes, $($case.WriteCalls)",'  %disposed = call i1 @ube.context.dispose(ptr %ctx)','  %live = load i64, ptr @test.live','  %clean = icmp eq i64 %live, 0','  %handles = load i64, ptr @test.handles','  %closed = icmp eq i64 %handles, 0','  %a = and i1 %init, %config.good','  %b = and i1 %prepare.good, %good','  %c = and i1 %reads.good, %writes.good','  %d = and i1 %disposed, %clean','  %e = and i1 %a, %b','  %f = and i1 %c, %d','  %g = and i1 %e, %f','  %all = and i1 %g, %closed','  %exit = select i1 %all, i32 0, i32 1','  ret i32 %exit','}')
    $observations = @('  %packed = load volatile i64, ptr @test.pack.cells',"  %packed.good = icmp eq i64 %packed, $packed",'  %unpacked = load volatile i64, ptr @test.unpack.cells',"  %unpacked.good = icmp eq i64 %unpacked, $unpacked",'  %path.cells = load volatile i64, ptr @test.path.cells',"  %path.good = icmp eq i64 %path.cells, $pathCells",'  %moves = and i1 %packed.good, %unpacked.good','  %movement.good = and i1 %moves, %path.good','  %observed.all = and i1 %all, %movement.good','  %exit = select i1 %observed.all, i32 0, i32 1')
    if ($case.Name -in @('CheckReads','CheckReadAtomicity','CheckValidation','CheckPartialWrite','CheckWriteFailure','CheckCloseRetry')) {
        $expectedAllocations = 1 + $case.Allocate
        $observations = @($observations | ForEach-Object {
            if ($_ -eq '  %exit = select i1 %observed.all, i32 0, i32 1') {
                '  %allocation.calls = load i64, ptr @test.alloc.calls'
                "  %allocation.good = icmp eq i64 %allocation.calls, $expectedAllocations"
                '  %resource.good = and i1 %observed.all, %allocation.good'
                '  %exit = select i1 %resource.good, i32 0, i32 1'
            } else { $_ }
        })
    }
    if ($case.Name -eq 'CheckRegistryCapacity') {
        $observations = @($observations | ForEach-Object {
            if ($_ -eq '  %exit = select i1 %observed.all, i32 0, i32 1') {
                '  %open.calls = load i64, ptr @test.open.calls'
                '  %open.good = icmp eq i64 %open.calls, 65'
                '  %registry.good = and i1 %observed.all, %open.good'
                '  %exit = select i1 %registry.good, i32 0, i32 1'
            } else { $_ }
        })
    }
    $harness = @($harness | ForEach-Object { if ($_ -eq '  %exit = select i1 %all, i32 0, i32 1') { $observations } else { $_ } })
    $combined = Join-Path $artifacts ("case-$caseNumber.ll")
    Write-Text $combined ($observed + "`r`n" + ($harness -join "`r`n") + "`r`n")
    foreach ($level in @('O0','O2')) {
        if (Test-Path -LiteralPath $outputPath) { Remove-Item -LiteralPath $outputPath }
        $exe = Join-Path $artifacts ("case-$caseNumber-$level.exe")
        Build-Harness $combined $exe $level
        $result = Invoke-BoundedProcess $exe @()
        Require ($result.ExitCode -eq 0) "$($case.Name) case$caseNumber $level failed: $($result.Evidence)"
        if ($case.Output -ne 'none') {
            $expected = [byte[]]@()
            if ($case.Output -eq 'all') { $expected = [byte[]](0..255) }
            if ($case.Output -eq 'partial') { $expected = [byte[]]@(1,2) }
            if ($case.Output -eq 'four') { $expected = [byte[]]@(1,2,3,4) }
            if ($case.Output -eq 'capacity') { $expected = [byte[]](@(7) * 4096) }
            Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes($outputPath)) -ceq [Convert]::ToBase64String($expected)) "Independent file bytes differ for case$caseNumber $level"
        } else { Require (-not (Test-Path -LiteralPath $outputPath)) 'Read-only case unexpectedly created output' }
        $script:passed++
        Write-Output "PASS: $($case.Name) case$caseNumber $level; exact calls, balanced owners and independent bytes"
    }
    if ($case.Name -eq 'CheckReads' -and $case.Allocate -eq 0) {
        $control = Join-Path $artifacts 'changed-read-input.ll'
        Write-Text $control ([IO.File]::ReadAllText($combined,$utf8).Replace('@test.input = global i64 1','@test.input = global i64 2'))
        $controlExe = Join-Path $artifacts 'changed-read-input.exe'
        Build-Harness $control $controlExe 'O2'
        $controlRun = Invoke-BoundedProcess $controlExe @()
        Require ($controlRun.ExitCode -eq 1) 'Changed runtime read offset must be rejected by the native observations'
        $script:passed++
        Write-Output 'PASS: changed runtime input invalidates the source read oracle'
    }
}
$lifetime = @('define i1 @test.configure(ptr %ctx) {','entry:') + @(Path-Setup $procedures $inputPath (Join-Path $artifacts 'unused.bin')) + @('  ret i1 %config.good','}', '@test.first = private global %ube.context zeroinitializer, align 8','@test.second = private global %ube.context zeroinitializer, align 8','define i32 @main() {','entry:','  %first = getelementptr %ube.context, ptr @test.first, i32 0','  %second = getelementptr %ube.context, ptr @test.second, i32 0','  call void @ube.context.init(ptr %first)','  call void @ube.context.init(ptr %second)','  %init.one = call i1 @ube.project.init(ptr %first)','  %init.two = call i1 @ube.project.init(ptr %second)','  %path.one = call i1 @test.configure(ptr %first)','  %path.two = call i1 @test.configure(ptr %second)',"  %opened.one = call { i1, i64 } @ube.proc.$($procedures['PrepareOpen'])(ptr %first, i64 1)","  %opened.two = call { i1, i64 } @ube.proc.$($procedures['PrepareOpen'])(ptr %second, i64 1)","  %token.one.pair = call { i1, i64 } @ube.proc.$($procedures['CurrentOwner'])(ptr %first)","  %token.two.pair = call { i1, i64 } @ube.proc.$($procedures['CurrentOwner'])(ptr %second)",'  %token.one = extractvalue { i1, i64 } %token.one.pair, 1','  %token.two = extractvalue { i1, i64 } %token.two.pair, 1','  %different = icmp ne i64 %token.one, %token.two','  %positive = icmp sgt i64 %token.one, 0','  %premature = call i1 @ube.context.dispose(ptr %first)','  %retained = xor i1 %premature, true','  %live.handles = load i64, ptr @test.handles','  %still.two = icmp eq i64 %live.handles, 2',"  %foreign = call { i1, i64 } @ube.proc.$($procedures['CheckForeignOwner'])(ptr %second, i64 %token.one)",'  %foreign.ok = extractvalue { i1, i64 } %foreign, 0','  %foreign.value = extractvalue { i1, i64 } %foreign, 1','  %foreign.zero = icmp eq i64 %foreign.value, 0',"  %closed.one = call { i1, i64 } @ube.proc.$($procedures['CloseOwner'])(ptr %first)","  %closed.two = call { i1, i64 } @ube.proc.$($procedures['CloseOwner'])(ptr %second)",'  %dispose.one = call i1 @ube.context.dispose(ptr %first)','  %dispose.two = call i1 @ube.context.dispose(ptr %second)','  %handles = load i64, ptr @test.handles','  %live = load i64, ptr @test.live','  %no.handles = icmp eq i64 %handles, 0','  %no.live = icmp eq i64 %live, 0','  %a = and i1 %different, %positive','  %b = and i1 %retained, %still.two','  %c = and i1 %foreign.ok, %foreign.zero','  %d = and i1 %dispose.one, %dispose.two','  %e = and i1 %no.handles, %no.live','  %f = and i1 %a, %b','  %g = and i1 %c, %d','  %h = and i1 %f, %g','  %all = and i1 %h, %e','  %exit = select i1 %all, i32 0, i32 1','  ret i32 %exit','}')
$lifetimeIR = Join-Path $artifacts 'context-file-lifetime.ll'
Write-Text $lifetimeIR ($observed + "`r`n" + ($lifetime -join "`r`n") + "`r`n")
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ("context-file-lifetime-$level.exe")
    Build-Harness $lifetimeIR $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Foreign token or live-owner disposal assertion failed: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: unique tokens across contexts and live-owner disposal refusal $level"
}

$alias = @('define i1 @test.configure(ptr %ctx) {','entry:') + @(Path-Setup $procedures $inputPath (Join-Path $artifacts 'unused-alias.bin')) + @('  ret i1 %config.good','}')
$aliasMain = @'
@test.context = private global %ube.context zeroinitializer, align 8
@test.payload = global [2 x i64] [i64 55, i64 66]
@test.array = global { i64, i64, ptr, ptr } { i64 0, i64 1, ptr @test.payload, ptr null }
@test.failure = global i64 88
@test.length = global i64 99
define i32 @main() {
entry:
  %ctx = getelementptr %ube.context, ptr @test.context, i32 0
  call void @ube.context.init(ptr %ctx)
  %init = call i1 @ube.project.init(ptr %ctx)
  %configured = call i1 @test.configure(ptr %ctx)
  %prepared = call { i1, i64 } @ube.proc.PREPARE(ptr %ctx, i64 1)
  %owner = call { i1, i64 } @ube.proc.OWNER(ptr %ctx)
  %token = extractvalue { i1, i64 } %owner, 1
  %read = call { i1, i64 } @ube.proc.READ(ptr %ctx, i64 %token, ptr @test.array, i64 0, i64 1, ptr @test.array, ptr @test.failure)
  %write = call { i1, i64 } @ube.proc.WRITE(ptr %ctx, i64 %token, ptr @test.array, i64 0, i64 1, ptr @test.payload, ptr @test.failure)
  %open = call { i1, i64 } @ube.proc.OPEN(ptr %ctx, ptr @test.array, i64 4096, ptr @test.array, ptr @test.length, ptr @test.failure)
  %create = call { i1, i64 } @ube.proc.CREATE(ptr %ctx, ptr @test.array, ptr @test.payload, ptr @test.failure)
  %read.status = extractvalue { i1, i64 } %read, 0
  %read.value = extractvalue { i1, i64 } %read, 1
  %write.status = extractvalue { i1, i64 } %write, 0
  %write.value = extractvalue { i1, i64 } %write, 1
  %open.status = extractvalue { i1, i64 } %open, 0
  %open.value = extractvalue { i1, i64 } %open, 1
  %create.status = extractvalue { i1, i64 } %create, 0
  %create.value = extractvalue { i1, i64 } %create, 1
  %sum.one = or i64 %read.value, %write.value
  %sum.two = or i64 %open.value, %create.value
  %sum = or i64 %sum.one, %sum.two
  %false.values = icmp eq i64 %sum, 0
  %status.one = and i1 %read.status, %write.status
  %status.two = and i1 %open.status, %create.status
  %statuses = and i1 %status.one, %status.two
  %lower = load i64, ptr @test.array
  %byte = load i64, ptr @test.payload
  %failure = load i64, ptr @test.failure
  %length = load i64, ptr @test.length
  %lower.good = icmp eq i64 %lower, 0
  %byte.good = icmp eq i64 %byte, 55
  %failure.good = icmp eq i64 %failure, 88
  %length.good = icmp eq i64 %length, 99
  %error = load i64, ptr %ctx
  %error.good = icmp eq i64 %error, 5
  %reads = load i64, ptr @test.read.calls
  %writes = load i64, ptr @test.write.calls
  %io = or i64 %reads, %writes
  %no.io = icmp eq i64 %io, 0
  %closed = call { i1, i64 } @ube.proc.CLOSE(ptr %ctx)
  %disposed = call i1 @ube.context.dispose(ptr %ctx)
  %live = load i64, ptr @test.live
  %handles = load i64, ptr @test.handles
  %remaining = or i64 %live, %handles
  %clean = icmp eq i64 %remaining, 0
  %a = and i1 %false.values, %statuses
  %b = and i1 %lower.good, %byte.good
  %c = and i1 %failure.good, %length.good
  %d = and i1 %error.good, %no.io
  %e = and i1 %disposed, %clean
  %f = and i1 %a, %b
  %g = and i1 %c, %d
  %h = and i1 %f, %g
  %all = and i1 %h, %e
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
'@
foreach ($entry in @(@('PREPARE','PrepareOpen'),@('OWNER','CurrentOwner'),@('READ','TryRead'),@('WRITE','TryWrite'),@('OPEN','TryOpen'),@('CREATE','TryCreateNew'),@('CLOSE','CloseOwner'))) { $aliasMain = $aliasMain.Replace(('ube.proc.' + $entry[0]),('ube.proc.' + $procedures[$entry[1]])) }
$aliasIR = Join-Path $artifacts 'output-storage-alias.ll'
Write-Text $aliasIR ($observed + "`r`n" + ($alias -join "`r`n") + "`r`n" + $aliasMain)
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ("output-storage-alias-$level.exe")
    Build-Harness $aliasIR $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Output/array alias guard failed: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: output aliases into array descriptors/payload leave storage and owners unchanged $level"
}

$nativeOutputPath = Join-Path $artifacts 'native-created.bin'
$inputBytes = $utf8.GetBytes($inputPath)
$outputBytes = $utf8.GetBytes($nativeOutputPath)
$body = @("' Drives real portable file operations through the production native entry point.",'Function Main() As Long',' Dim Status As Long'," Status = FileProbe.Configure($($inputBytes.Length), $($outputBytes.Length))",' If Status <> 0 Then Main = 99: Exit Function')
for ($kind = 0; $kind -lt 2; $kind++) {
    $bytes = $inputBytes
    if ($kind -eq 1) { $bytes = $outputBytes }
    for ($index = 0; $index -lt $bytes.Length; $index++) { $body += " Status = FileProbe.SetPathByte($kind, $index, $($bytes[$index]))" }
}
$body += @(' Main = FileProbe.CheckRoundTrip(1)','End Function')
$mainSource = Join-Path $artifacts 'MainProgram.bas'
Write-Text $mainSource (Module-Text 'MainProgram' ($body -join "`r`n"))
$nativeManifest = Copy-Fixtures 'native file project' @((Join-Path $coreDirectory 'BufferPrimitives.bas'),(Join-Path $coreDirectory 'FilePrimitives.bas'),(Join-Path $coreDirectory 'FileBytes.bas'),(Join-Path $PSScriptRoot 'fixtures/FileProbe.bas'),$mainSource) '2' 'Exe'
$nativeExe = Join-Path $artifacts 'native-file-project.exe'
$null = Invoke-Compiler @('--build',$nativeManifest,$nativeExe,'--clang',$Clang) 'BUILD OK'
Assert-X64 $nativeExe
$nativeRun = Invoke-BoundedProcess $nativeExe @()
Require ($nativeRun.ExitCode -eq 0) "Production native file build failed at runtime: $($nativeRun.Evidence)"
Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes($nativeOutputPath)) -ceq [Convert]::ToBase64String([byte[]](0..255))) 'Production file bytes differ'
$before = (Get-FileHash -LiteralPath $nativeOutputPath).Hash
$again = Invoke-BoundedProcess $nativeExe @()
Require ($again.ExitCode -eq 1 -and (Get-FileHash -LiteralPath $nativeOutputPath).Hash -ceq $before) 'Repeated exclusive native creation must fail without changing existing bytes'
$script:passed++
Write-Output 'PASS: production --build file imports, entry, disposal and exclusive creation'
# Requires a located exact-signature diagnostic before any successful semantic publication.
function Assert-Rejected([string]$Name, [string]$Parameters, [string]$Role, [string]$Code = 'E_TYPE', [string]$ResultType = 'Boolean') {
    $body = "Public Intrinsic Function Probe($Parameters) As $ResultType`nAttribute Probe.UBE_Primitive = `"$Role`"`nEnd Function"
    $project = New-Fixture $Name @($body)
    $result = Invoke-BoundedProcess $BootstrapExe @('--analyze',$project)
    Require ($result.ExitCode -eq 1 -and $result.Stderr -match ('^UBE: ' + $Code + ':') -and $result.Stderr -match 'Example\.bas:\d+:\d+' -and $result.Stdout -notmatch 'ANALYZE OK') "${Name} expected ${Code}: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: $Name"
}
Assert-Rejected 'open wrong limit width' 'ByRef Path() As Byte, ByVal Limit As LongLong, ByRef Token As Long, ByRef Length As Long, ByRef Failure As Long' 'File.TryOpen'
Assert-Rejected 'create token must be ByRef' 'ByRef Path() As Byte, ByVal Token As Long, ByRef Failure As Long' 'File.TryCreateNew'
Assert-Rejected 'read offset must be ByVal' 'ByVal Token As Long, ByRef Data() As Byte, ByRef Start As Long, ByVal Count As Long, ByRef Progress As Long, ByRef Failure As Long' 'File.TryRead'
Assert-Rejected 'write source must be Byte' 'ByVal Token As Long, ByRef Data() As Integer, ByVal Start As Long, ByVal Count As Long, ByRef Progress As Long, ByRef Failure As Long' 'File.TryWrite'
Assert-Rejected 'flush result must be Boolean' 'ByVal Token As Long, ByRef Failure As Long' 'File.TryFlush' 'E_TYPE' 'Long'
Assert-Rejected 'close failure must be ByRef' 'ByRef Token As Long, ByVal Failure As Long' 'File.TryClose'
Assert-Rejected 'Error.Set requires Long' 'ByVal Number As Boolean' 'Error.Set'
Assert-Rejected 'Process argument remains deferred' 'ByVal Index As Long, ByRef Result() As Byte, ByRef Failure As Long' 'Process.TryArgument' 'E_UNSUPPORTED'
Write-Output "PASS: $($script:passed) file-I/O groups. Evidence: $artifacts"
