# Verifies bounded LLVM byte streaming through real caller-owned files.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube llvm writing ' + [guid]::NewGuid())
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

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$files = @('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/FileBytes.bas','std-lib/src/portable/ByteText.bas','compiler/src/LLVMWriter.bas','bootstrap/tests/llvm-writing/Probe.bas') | ForEach-Object { Join-Path $root $_ }
$manifest = Copy-Fixtures 'writer' $files '0' 'Library'
$library = Join-Path $artifacts 'writer.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$library) 'EMIT OK'
$bound = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Binding failed: $($bound.Evidence)"
$symbols = @{}
foreach ($line in ($bound.Stdout -split '\r?\n')) {
    if ($line -notmatch '^SYMBOL ') { continue }
    $fields = $line.Substring(7).Split('|')
    if ($fields[5] -eq '5' -and $fields[1] -in @('function','sub')) { $symbols[$fields[2]] = $fields[0] }
}
foreach ($name in @('ConfigurePath','SetPathByte','Run')) { Require ($symbols.ContainsKey($name)) "Missing $name symbol" }
$emitted = [IO.File]::ReadAllText($library,$utf8)

# Builds a minimal driver that supplies paths and volatile input to real UBE procedures.
function Make-Driver([string]$Path,[int]$Mode,[int]$Seed,[bool]$FailFlush) {
    $ir = $emitted
    if ($FailFlush) {
        $pattern = '(?ms)^define i1 @ube\.target\.file\.flush\(ptr %handle\) \{.*?^\}'
        Require ([regex]::Matches($ir,$pattern).Count -eq 1) 'Missing unique flush injection boundary'
        $ir = [regex]::Replace($ir,$pattern,"define i1 @ube.target.file.flush(ptr %handle) {`r`n  ret i1 false`r`n}")
    }
    if ($Mode -eq 6) {
        $pattern = '(?ms)^define i1 @ube\.target\.file\.write\(ptr %handle, ptr %bytes, i32 %count, ptr %progress\) \{.*?^\}'
        Require ([regex]::Matches($ir,$pattern).Count -eq 1) 'Missing unique write injection boundary'
        $ir = [regex]::Replace($ir,$pattern,"define i1 @ube.target.file.write(ptr %handle, ptr %bytes, i32 %count, ptr %progress) {`r`n  store i32 0, ptr %progress`r`n  ret i1 false`r`n}")
    }
    $bytes = $utf8.GetBytes($Path)
    $lines = @('@writer.test.context = private global %ube.context zeroinitializer, align 8',('@writer.seed = private global i64 '+$Seed),'define i32 @main() {','entry:','  call void @ube.context.init(ptr @writer.test.context)','  %initialized = call i1 @ube.project.init(ptr @writer.test.context)',('  %configured = call { i1, i64 } @ube.proc.'+$symbols['ConfigurePath']+'(ptr @writer.test.context, i64 '+$bytes.Length+')'))
    for ($i=0;$i -lt $bytes.Length;$i++) { $lines += '  %path'+$i+' = call { i1, i64 } @ube.proc.'+$symbols['SetPathByte']+'(ptr @writer.test.context, i64 '+$i+', i64 '+$bytes[$i]+')' }
    $lines += @('  %seed = load volatile i64, ptr @writer.seed',('  %result = call { i1, i64 } @ube.proc.'+$symbols['Run']+'(ptr @writer.test.context, i64 '+$Mode+', i64 %seed)'),'  %fresh = extractvalue { i1, i64 } %result, 0','  %value = extractvalue { i1, i64 } %result, 1','  %disposed = call i1 @ube.context.dispose(ptr @writer.test.context)','  %valid = and i1 %fresh, %disposed','  %status = trunc i64 %value to i32','  %exit = select i1 %valid, i32 %status, i32 100','  ret i32 %exit','}')
    return $ir + ($lines -join "`r`n") + "`r`n"
}

# Constructs intended file bytes independently of generated instructions.
function Expected-Bytes([int]$Mode) {
    if ($Mode -eq 0) { return $utf8.GetBytes(('A' * 65534) + "-9223372036854775808`r`n92233720368547758070-1") }
    if ($Mode -eq 1) { return $utf8.GetBytes('A' * 16777216) }
    if ($Mode -eq 2) { return $utf8.GetBytes("`n" * 500000) }
    if ($Mode -eq 5) { return $utf8.GetBytes('AAA') }
    return [byte[]]@()
}

foreach ($level in @('O0','O2')) {
    foreach ($mode in 0..6) {
        $path = Join-Path $artifacts ("stage-$level-$mode.bin")
        $ir = Join-Path $artifacts ("driver-$level-$mode.ll")
        $exe = Join-Path $artifacts ("driver-$level-$mode.exe")
        Write-Text $ir (Make-Driver $path $mode 1 ($mode -eq 5))
        Build-Harness $ir $exe $level
        $run = Invoke-BoundedProcess $exe @() 60000
        Require ($run.ExitCode -eq 0) "Writer $level mode $mode assertion $($run.ExitCode): $($run.Evidence)"
        $actual = [IO.File]::ReadAllBytes($path)
        $expected = [byte[]]@(Expected-Bytes $mode)
        Require ($actual.Length -eq $expected.Length) "Writer $level mode $mode length mismatch"
        $sha = [Security.Cryptography.SHA256]::Create()
        try { Require ([Convert]::ToBase64String($sha.ComputeHash($actual)) -ceq [Convert]::ToBase64String($sha.ComputeHash($expected))) "Writer $level mode $mode byte mismatch" } finally { $sha.Dispose() }
        $script:passed++
        Write-Output "PASS: $level mode $mode exact bytes and source state assertions"
    }
}
$controlPath = Join-Path $artifacts 'changed-payload.bin'
$controlIR = Join-Path $artifacts 'changed-payload.ll'
$controlExe = Join-Path $artifacts 'changed-payload.exe'
Write-Text $controlIR (Make-Driver $controlPath 0 2 $false)
Build-Harness $controlIR $controlExe 'O2'
$control = Invoke-BoundedProcess $controlExe @()
Require ($control.ExitCode -eq 0) 'Changed-payload control failed for an unrelated source-state reason'
$changed = [IO.File]::ReadAllBytes($controlPath)
Require ($changed.Length -eq 65578 -and $changed[0] -eq 66) 'Changed-payload control did not reach output'
Require ($changed[0] -ne (Expected-Bytes 0)[0]) 'Unchanged byte oracle accepted altered runtime payload'
Write-Output "PASS: $passed native writer scenarios plus exact changed-payload negative control"
