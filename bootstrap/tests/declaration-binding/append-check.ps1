# Verifies project append allocation, depth refusal, corrupted arenas, and committed-prefix preservation.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube project append ' + [guid]::NewGuid())
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
$core = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$compiler = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src'))
$manifest = Copy-Fixtures 'append library' @((Join-Path $core 'BufferPrimitives.bas'),(Join-Path $core 'Utf8.bas'),(Join-Path $compiler 'SourceScanner.bas'),(Join-Path $compiler 'SyntaxTokens.bas'),(Join-Path $compiler 'SourceParser.bas'),(Join-Path $compiler 'ProjectSyntax.bas'),(Join-Path $PSScriptRoot 'AppendProbe.bas')) '0' 'Library'
$procedures = Read-Procedures $manifest
$ir = Join-Path $artifacts 'append.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$observed = [IO.File]::ReadAllText($ir,$utf8)
foreach ($name in @('allocate','release')) {
    $pattern = '(?m)^(define[^\r\n@]*?)@ube\.target\.' + $name + '\('
    Require ([regex]::Matches($observed,$pattern).Count -eq 1) "Missing wrapper $name"
    $observed = [regex]::Replace($observed,$pattern,('${1}@test.real.' + $name + '('))
}
$observer = @'
@test.calls = global i64 0
@test.fail.at = global i64 0
@test.failed = global i64 0
@test.live = global i64 0
@test.depth.ptr = global ptr null
@test.inject.at = global i64 0
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
  %inject.at = load i64, ptr @test.inject.at
  %inject = icmp eq i64 %calls, %inject.at
  br i1 %inject, label %inject.depth, label %done
inject.depth:
  %depth.ptr = load ptr, ptr @test.depth.ptr
  store i64 257, ptr %depth.ptr
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

$data = ''
foreach ($item in @(@('first','First'),@('second','Second'))) {
    $source = "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"$($item[1])`"`r`nPublic Sub Work()`r`nDim Value As Long`r`nValue = 7`r`nEnd Sub`r`n"
    $bytes = $utf8.GetBytes($source)
    $data += ('@test.'+$item[0]+'.bytes = private global ['+$bytes.Count+' x i64] ['+(($bytes | ForEach-Object {'i64 '+$_}) -join ', ')+']')+"`r`n"
    $data += ('@test.'+$item[0]+' = private global { i64, i64, ptr, ptr } { i64 0, i64 '+($bytes.Count-1)+', ptr @test.'+$item[0]+'.bytes, ptr null }')+"`r`n"
}
# Each small scan allocates candidate, exact-sized copy, then parser candidate/publication and four arena reserves.
foreach ($stage in 1..9) {
    $h = @'
@test.context = private global %ube.context zeroinitializer
define i32 @main() {
entry:
  %ctx = getelementptr %ube.context, ptr @test.context, i32 0
  call void @ube.context.init(ptr %ctx)
  %init = call i1 @ube.project.init(ptr %ctx)
  %prepare = call {i1,i64} @ube.proc.PREPARE(ptr %ctx, ptr @test.first, ptr @test.second)
  %p0 = extractvalue {i1,i64} %prepare, 0
  %p1 = extractvalue {i1,i64} %prepare, 1
  %p2 = icmp eq i64 %p1, 0
  store i64 0, ptr @test.calls
  store i64 STAGE, ptr @test.fail.at
  %reject = call {i1,i64} @ube.proc.REJECT(ptr %ctx)
  %r0 = extractvalue {i1,i64} %reject, 0
  %r1 = extractvalue {i1,i64} %reject, 1
  %r2 = icmp eq i64 %r1, 0
  %failed = load i64, ptr @test.failed
  %two = icmp eq i64 %failed, 2
  store i64 0, ptr @test.fail.at
  %retry = call {i1,i64} @ube.proc.RETRY(ptr %ctx)
  %t0 = extractvalue {i1,i64} %retry, 0
  %t1 = extractvalue {i1,i64} %retry, 1
  %t2 = icmp eq i64 %t1, 0
  %disposed = call i1 @ube.context.dispose(ptr %ctx)
  %live = load i64, ptr @test.live
  %clean = icmp eq i64 %live, 0
  %a = and i1 %init, %p0
  %b = and i1 %p2, %r0
  %c = and i1 %r2, %two
  %d = and i1 %t0, %t2
  %e = and i1 %disposed, %clean
  %ab = and i1 %a, %b
  %cd = and i1 %c, %d
  %abcd = and i1 %ab, %cd
  %all = and i1 %abcd, %e
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
'@
    $h=$h.Replace('ube.proc.PREPARE','ube.proc.'+$procedures['Prepare']).Replace('ube.proc.REJECT','ube.proc.'+$procedures['RejectAllocation']).Replace('ube.proc.RETRY','ube.proc.'+$procedures['RetryAppend']).Replace('STAGE',[string]$stage)
    $combined=Join-Path $artifacts "append-$stage.ll"
    Write-Text $combined ($observed+"`r`n"+$data+$h)
    foreach($level in @('O0','O2')) {
        $exe=Join-Path $artifacts "append-$stage-$level.exe"
        Build-Harness $combined $exe $level
        $result=Invoke-BoundedProcess $exe @()
        Require ($result.ExitCode -eq 0) "Append stage $stage $level failed: $($result.Evidence)"
        $script:passed++
        Write-Output "PASS: append allocation $stage $level preserves all committed prefixes and retries"
    }
}
# Restores synthetic depth before inspecting retained outputs or disposing the context.
foreach($case in @(0,192,240,248,252,254,255,256,-1)+(1001..1010)) {
    $body = ''
    if($case -lt 1000) {
        $depth=$case
        $tail=0
        if($case -eq -1){$depth=0;$tail=-1}
        $body=@'
  %depth.ptr = getelementptr %ube.context, ptr %ctx, i32 0, i32 1
  store ptr %depth.ptr, ptr @test.depth.ptr
  store i64 DEPTH, ptr %depth.ptr
  store i64 0, ptr @test.calls
  store i64 INJECT, ptr @test.inject.at
  %attempt = call {i1,i64} @ube.proc.ATTEMPT(ptr %ctx)
  %fresh = extractvalue {i1,i64} %attempt, 0
  %value = extractvalue {i1,i64} %attempt, 1
  %returned.true = icmp ne i64 %value, 0
  %success = and i1 %fresh, %returned.true
  %success.value = sext i1 %success to i64
  store i64 0, ptr %depth.ptr
  store i64 0, ptr @test.inject.at
  %check = call {i1,i64} @ube.proc.CHECKDEPTH(ptr %ctx, i64 %success.value, i64 TAIL)
  %check.fresh = extractvalue {i1,i64} %check, 0
  %check.value = extractvalue {i1,i64} %check, 1
  %check.zero = icmp eq i64 %check.value, 0
  %checked = and i1 %check.fresh, %check.zero
  EXPECTED
  %test.ok = and i1 %checked, %expected
'@
        $expected='  %expected = icmp eq i1 %success, false'
        if($case -eq 0 -or $case -eq 192){$expected='  %expected = icmp eq i1 %success, true'}
        if($case -eq 240){$expected='  %expected = icmp eq i1 %fresh, true'}
        $inject=0
        if($case -eq -1){$inject=9}
        $body=$body.Replace('DEPTH',[string]$depth).Replace('INJECT',[string]$inject).Replace('TAIL',[string]$tail).Replace('EXPECTED',$expected).Replace('ube.proc.ATTEMPT','ube.proc.'+$procedures['AttemptAppend']).Replace('ube.proc.CHECK'+[string]$depth,'ube.proc.'+$procedures['CheckDepth'])
    } else {
        $body="  %check = call {i1,i64} @ube.proc.$($procedures['CheckCorruption'])(ptr %ctx, i64 $($case-1000))`r`n"+@'
  %check.fresh = extractvalue {i1,i64} %check, 0
  %check.value = extractvalue {i1,i64} %check, 1
  %check.zero = icmp eq i64 %check.value, 0
  %test.ok = and i1 %check.fresh, %check.zero
'@
    }
    $h=@'
@test.context = private global %ube.context zeroinitializer
define i32 @main() {
entry:
  %ctx = getelementptr %ube.context, ptr @test.context, i32 0
  call void @ube.context.init(ptr %ctx)
  %init = call i1 @ube.project.init(ptr %ctx)
  %prepare = call {i1,i64} @ube.proc.PREPARE(ptr %ctx, ptr @test.first, ptr @test.second)
  %p0 = extractvalue {i1,i64} %prepare, 0
  %p1 = extractvalue {i1,i64} %prepare, 1
  %p2 = icmp eq i64 %p1, 0
BODY
  %disposed = call i1 @ube.context.dispose(ptr %ctx)
  %live = load i64, ptr @test.live
  %clean = icmp eq i64 %live, 0
  %a = and i1 %init, %p0
  %b = and i1 %p2, %test.ok
  %c = and i1 %disposed, %clean
  %ab = and i1 %a, %b
  %all = and i1 %ab, %c
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
'@
    $h=$h.Replace('ube.proc.PREPARE','ube.proc.'+$procedures['Prepare']).Replace('BODY',$body)
    $combined=Join-Path $artifacts "state-$case.ll"
    Write-Text $combined ($observed+"`r`n"+$data+$h)
    foreach($level in @('O0','O2')) {
        $exe=Join-Path $artifacts "state-$case-$level.exe"
        Build-Harness $combined $exe $level
        $result=Invoke-BoundedProcess $exe @()
        Require ($result.ExitCode -eq 0) "Append state $case $level failed: $($result.Evidence)"
        $script:passed++
        Write-Output "PASS: append state $case $level preserves committed prefixes and releases owners"
    }
}
Write-Output "PASS: $script:passed project append groups. Evidence: $artifacts"
