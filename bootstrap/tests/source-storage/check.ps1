# Verifies bounded source-sized storage, counted file transfers, and allocation quota admission.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube source storage ' + [guid]::NewGuid())
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

# Compiles unchanged storage policy and probes through the real source compiler.
$coreDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$manifest = Copy-Fixtures 'storage library' @((Join-Path $coreDirectory 'BufferPrimitives.bas'),(Join-Path $coreDirectory 'FilePrimitives.bas'),(Join-Path $coreDirectory 'FileBytes.bas'),(Join-Path $PSScriptRoot 'StorageProbe.bas')) '0' 'Library'
$procedures = Read-Procedures $manifest
$ir = Join-Path $artifacts 'storage.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$observed = [IO.File]::ReadAllText($ir,$utf8)
foreach ($name in @('allocate','release','file.open','file.size','file.read','file.write','file.flush','file.close')) {
    $pattern = '(?m)^(define[^\r\n@]*?)@ube\.target\.' + [regex]::Escape($name) + '\('
    Require ([regex]::Matches($observed,$pattern).Count -eq 1) "Missing target wrapper $name"
    $observed = [regex]::Replace($observed,$pattern,('${1}@test.real.' + $name + '('))
}
$observed += "`r`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../dynamic-storage/fixtures/AllocatorObserver.ll'),$utf8)
$fileObserver = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/FileObserver.ll'),$utf8)
# Keep real OS calls but select a short-progress boundary that crosses complete 64-KiB chunks.
$fileObserver = $fileObserver.Replace('%count, 2','%count, 32767').Replace('%clip, i32 2,','%clip, i32 32767,').Replace('i32 2, i32 7','i32 2, i32 32767')
$observed += "`r`n" + $fileObserver
$cases = @(
    @{Name='former element ceiling'; Length=4097; Procedure='RoundTrip'; Short=0; Read=2; Write=1},
    @{Name='complete transfer'; Length=65536; Procedure='RoundTrip'; Short=0; Read=2; Write=1},
    @{Name='cross transfer boundary'; Length=65537; Procedure='RoundTrip'; Short=0; Read=3; Write=2},
    @{Name='full source limit'; Length=1048576; Procedure='RoundTrip'; Short=0; Read=17; Write=16},
    @{Name='short chunk progress'; Length=65537; Procedure='RoundTrip'; Short=2; Read=4; Write=3},
    @{Name='native transfer guard'; Length=65536; Procedure='TransferBoundary'; Short=0; Read=1; Write=1},
    @{Name='source byte ceiling'; Length=1048577; Procedure='RejectFileLimit'; Short=0; Read=0; Write=0; NoOutput=$true}
)
foreach ($case in $cases) {
    $input = Join-Path $artifacts ($case.Name + '.input')
    $bytes = New-Object byte[] $case.Length
    for ($i=0;$i -lt $bytes.Length;$i++) { $bytes[$i] = [byte]($i % 256) }
    [IO.File]::WriteAllBytes($input,$bytes)
    $expectedBytes = $case.Length
    if ($case.ContainsKey('NoOutput')) { $expectedBytes = 0 }
    foreach ($level in @('O0','O2')) {
        $output = Join-Path $artifacts ($case.Name + '-' + $level + '.output')
        $inBytes = $utf8.GetBytes($input)
        $outBytes = $utf8.GetBytes($output)
        $h = @('@test.context = private global %ube.context zeroinitializer, align 8',
            'define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0',
            '  call void @ube.context.init(ptr %ctx)','  %init = call i1 @ube.project.init(ptr %ctx)',
            "  %setup = call { i1, i64 } @ube.proc.$($procedures['Configure'])(ptr %ctx, i64 $($inBytes.Length), i64 $($outBytes.Length))",
            '  %setup.ok = extractvalue { i1, i64 } %setup, 0','  %setup.value = extractvalue { i1, i64 } %setup, 1',
            '  %setup.zero = icmp eq i64 %setup.value, 0','  %ready = and i1 %setup.ok, %setup.zero')
        for ($i=0;$i -lt $inBytes.Length;$i++) { $h += "  %input.$i = call { i1, i64 } @ube.proc.$($procedures['SetInput'])(ptr %ctx, i64 $i, i64 $($inBytes[$i]))" }
        for ($i=0;$i -lt $outBytes.Length;$i++) { $h += "  %output.$i = call { i1, i64 } @ube.proc.$($procedures['SetOutput'])(ptr %ctx, i64 $i, i64 $($outBytes[$i]))" }
        $arguments = 'ptr %ctx'
        if ($case.Procedure -eq 'RoundTrip') { $arguments += ", i64 $($case.Length)" }
        $h += @("  store i32 $($case.Short), ptr @test.read.mode","  store i32 $($case.Short), ptr @test.write.mode",
            "  %result = call { i1, i64 } @ube.proc.$($procedures[$case.Procedure])($arguments)",
            '  %ok = extractvalue { i1, i64 } %result, 0','  %value = extractvalue { i1, i64 } %result, 1',
            '  %zero = icmp eq i64 %value, 0','  %good = and i1 %ok, %zero',
            '  %reads = load i64, ptr @test.read.calls','  %writes = load i64, ptr @test.write.calls',
            "  %read.count = icmp eq i64 %reads, $($case.Read)","  %write.count = icmp eq i64 %writes, $($case.Write)",
            '  %read.bytes = load i64, ptr @test.read.bytes','  %write.bytes = load i64, ptr @test.write.bytes',
            "  %read.exact = icmp eq i64 %read.bytes, $expectedBytes","  %write.exact = icmp eq i64 %write.bytes, $expectedBytes",
            '  %disposed = call i1 @ube.context.dispose(ptr %ctx)','  %live = load i64, ptr @test.live',
            '  %handles = load i64, ptr @test.handles','  %no.blocks = icmp eq i64 %live, 0','  %no.handles = icmp eq i64 %handles, 0',
            '  %a = and i1 %ready, %init','  %b = and i1 %good, %disposed','  %c = and i1 %read.count, %write.count',
            '  %d = and i1 %read.exact, %write.exact','  %e = and i1 %no.blocks, %no.handles',
            '  %f = and i1 %a, %b','  %g = and i1 %c, %d','  %j = and i1 %f, %g','  %all = and i1 %j, %e',
            '  %exit = select i1 %all, i32 0, i32 1','  ret i32 %exit','}')
        $combined = Join-Path $artifacts ($case.Name+'-'+$level+'.ll')
        $exe = Join-Path $artifacts ($case.Name+'-'+$level+'.exe')
        Write-Text $combined ($observed + "`r`n" + ($h -join "`r`n"))
        Build-Harness $combined $exe $level
        $result = Invoke-BoundedProcess $exe @()
        Require ($result.ExitCode -eq 0) "$($case.Name) $level failed: $($result.Evidence)"
        if ($case.ContainsKey('NoOutput')) {
            Require (-not (Test-Path -LiteralPath $output)) 'Rejected input created an output file'
        } else {
            Require ((Get-FileHash -LiteralPath $input).Hash -eq (Get-FileHash -LiteralPath $output).Hash) 'Independent file readback differs'
        }
        $script:passed++
        Write-Output "PASS: $($case.Name) $level exact bytes, native counts and owner balance"
    }
}
$quotaHarness = @'
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
  store i64 0, ptr @test.alloc.calls
  %reject = call { i1, i64 } @ube.proc.REJECT(ptr %ctx)
  %reject.ok = extractvalue { i1, i64 } %reject, 0
  %reject.value = extractvalue { i1, i64 } %reject, 1
  %reject.zero = icmp eq i64 %reject.value, 0
  %rejected = and i1 %reject.ok, %reject.zero
  %calls = load i64, ptr @test.alloc.calls
  %no.calls = icmp eq i64 %calls, 0
  %retry = call { i1, i64 } @ube.proc.RETRY(ptr %ctx)
  %retry.ok = extractvalue { i1, i64 } %retry, 0
  %retry.value = extractvalue { i1, i64 } %retry, 1
  %retry.zero = icmp eq i64 %retry.value, 0
  %retried = and i1 %retry.ok, %retry.zero
  %retry.calls = load i64, ptr @test.alloc.calls
  %one.call = icmp eq i64 %retry.calls, 1
  %disposed = call i1 @ube.context.dispose(ptr %ctx)
  %live = load i64, ptr @test.live
  %clean = icmp eq i64 %live, 0
  %a = and i1 %init, %ready
  %b = and i1 %rejected, %no.calls
  %c = and i1 %retried, %one.call
  %d = and i1 %disposed, %clean
  %e = and i1 %a, %b
  %f = and i1 %c, %d
  %all = and i1 %e, %f
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
'@
$quotaHarness = $quotaHarness.Replace('ube.proc.PREPARE',('ube.proc.'+$procedures['PrepareQuota'])).Replace('ube.proc.REJECT',('ube.proc.'+$procedures['RejectQuota'])).Replace('ube.proc.RETRY',('ube.proc.'+$procedures['RetryQuota']))
$quotaIR = Join-Path $artifacts 'quota.ll'
Write-Text $quotaIR ($observed + "`r`n" + $quotaHarness)
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ("quota-$level.exe")
    Build-Harness $quotaIR $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Oversized block quota $level failed: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: oversized block $level rejects before OS allocation, preserves owners and permits retry"
}
Write-Output "PASS: $script:passed source storage checks"

# Retains the actual scanner and portable UTF-8 implementation without source rewriting.
