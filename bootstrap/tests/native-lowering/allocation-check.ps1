# Qualifies allocation, depth, malformed input and staging I/O failures at the UBE lowering boundary.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube lowering failures ' + [guid]::NewGuid())
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

$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
& (Join-Path $root 'bootstrap/tools/runtime-text.ps1')
& (Join-Path $root 'bootstrap/tools/llvm-templates.ps1')
$files=@('BufferPrimitives','FilePrimitives','FileBytes','ByteText','Utf8')|ForEach-Object {Join-Path $root ('std-lib/src/portable/'+$_+'.bas')}
$files+=@('SourceScanner','SyntaxTokens','SourceParser','ProjectSyntax','DeclarationBinder','ConstantValues','ExpressionBinder','AggregateLayout','PrimitiveRoles','NativePlanning','LLVMWriter','LLVMTemplates','LLVMFormat','NativeEmission','NativeValues','NativeStorage','NativeExpressions','NativeControl','NativeFrames','NativeContext','NativeIntrinsics','NativeLowering')|ForEach-Object {Join-Path $root ('compiler/src/'+$_+'.bas')}
$files+=Join-Path $PSScriptRoot 'AllocationProbe.bas'
$manifest=Copy-Fixtures 'emitter' $files '0' 'Library'
$library=Join-Path $artifacts 'emitter.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$library) 'EMIT OK'
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) 'Fault probe binding failed'
$procedures=@{}
foreach($line in ($bound.Stdout -split '\r?\n')) {
    if($line -notmatch '^SYMBOL ') {continue}
    $f=$line.Substring(7).Split('|')
    if($f[5] -eq [string]($files.Count-1) -and $f[1] -in @('function','sub')) {$procedures[$f[2]]=$f[0]}
}
$emitted=[IO.File]::ReadAllText($library,$utf8)
$observed=$emitted.Replace('define ptr @ube.target.allocate(', 'define ptr @test.real.allocate(').Replace('define i1 @ube.target.release(', 'define i1 @test.real.release(').Replace('define i1 @ube.target.file.write(', 'define i1 @test.real.write(').Replace('define i1 @ube.target.file.flush(', 'define i1 @test.real.flush(')
$observer=@'
@test.calls = global i64 0
@test.fail.at = global i64 0
@test.failed = global i64 0
@test.live = global i64 0
@test.io = global i64 0
define ptr @ube.target.allocate(i64 %bytes) {
entry:
  %old = load i64, ptr @test.calls
  %calls = add i64 %old, 1
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
  %previous = load i64, ptr @test.failed
  %count = add i64 %previous, 1
  store i64 %count, ptr @test.failed
  ret ptr null
allocate:
  %block = call ptr @test.real.allocate(i64 %bytes)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %record, label %done
record:
  %live = load i64, ptr @test.live
  %next = add i64 %live, 1
  store i64 %next, ptr @test.live
  br label %done
done:
  ret ptr %block
}
define i1 @ube.target.release(ptr %block) {
entry:
  %ok = call i1 @test.real.release(ptr %block)
  br i1 %ok, label %record, label %done
record:
  %live = load i64, ptr @test.live
  %next = sub i64 %live, 1
  store i64 %next, ptr @test.live
  br label %done
done:
  ret i1 %ok
}
define i1 @ube.target.file.write(ptr %handle, ptr %bytes, i32 %count, ptr %progress) {
entry:
  %mode = load i64, ptr @test.io
  %fail = icmp eq i64 %mode, 1
  br i1 %fail, label %failed, label %write
failed:
  store i32 0, ptr %progress
  ret i1 false
write:
  %ok = call i1 @test.real.write(ptr %handle, ptr %bytes, i32 %count, ptr %progress)
  ret i1 %ok
}
define i1 @ube.target.file.flush(ptr %handle) {
entry:
  %mode = load i64, ptr @test.io
  %fail = icmp eq i64 %mode, 2
  br i1 %fail, label %failed, label %flush
failed:
  ret i1 false
flush:
  %ok = call i1 @test.real.flush(ptr %handle)
  ret i1 %ok
}
'@

# Represents input bytes as ordinary descriptor-backed runtime input, not pre-bound facts.
function Byte-Global([string]$Name,[byte[]]$Bytes) {
    $cells=($Bytes|ForEach-Object {'i64 '+$_}) -join ', '
    return '@'+$Name+'.data = private global ['+$Bytes.Length+' x i64] ['+$cells+"]`r`n"+'@'+$Name+' = global { i64, i64, ptr, ptr } { i64 0, i64 '+($Bytes.Length-1)+', ptr @'+$Name+".data, ptr null }`r`n"
}
$source=@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Example"
Public Type Pair
    First As Long
    Second As Long
End Type
Private Function ReadValue(ByRef InputValue As Long) As Long
    ReadValue = InputValue
End Function
Public Function Run(ByVal Seed As Long) As Long
    Dim A As Pair
    Dim B As Pair
    Dim Equal As Boolean
    A.First = Seed
    B = A
    Equal = A = B
    Run = ReadValue((Seed)) + 1
End Function
'@
$inputs=(Byte-Global 'test.source' $utf8.GetBytes($source))+(Byte-Global 'test.catalog' ([IO.File]::ReadAllBytes((Join-Path $root 'compiler/llvm/templates.bin'))))+(Byte-Global 'test.runtime' ([IO.File]::ReadAllBytes((Join-Path $root 'compiler/llvm/windows-runtime.ll'))))
$observedIR=Join-Path $artifacts 'observed.ll'
Write-Text $observedIR ($observed+$observer+$inputs)
$types=([regex]::Matches($emitted,'(?m)^%ube\.(?:resource|context) = type .*')|ForEach-Object {$_.Value}) -join "`r`n"
$externals=@'
@test.calls = external global i64
@test.fail.at = external global i64
@test.failed = external global i64
@test.live = external global i64
@test.io = external global i64
@test.source = external global { i64, i64, ptr, ptr }
@test.catalog = external global { i64, i64, ptr, ptr }
@test.runtime = external global { i64, i64, ptr, ptr }
declare void @ube.context.init(ptr)
declare i1 @ube.project.init(ptr)
declare i1 @ube.context.dispose(ptr)
'@
foreach($name in $procedures.Keys) {
    $args='ptr'
    if($name -eq 'Prepare') {$args+=', ptr, ptr, ptr'}
    if($name -eq 'OpenStage') {$args+=', ptr'}
    if($name -in @('Field','Corrupt','CheckRejected')) {$args+=', i64'}
    $externals+="`r`ndeclare { i1, i64 } @ube.proc."+$procedures[$name]+'('+$args+')'
}
$objects=@{}
$links=@(Get-NativeMemoryLinkArguments $observedIR $Clang $artifacts)
foreach($level in @('O0','O2')) {
    $obj=Join-Path $artifacts ('observed-'+$level+'.obj')
    $build=Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc',('-'+$level),'-c',$observedIR,'-o',$obj) 120000
    Require ($build.ExitCode -eq 0) "Observed production object failed: $($build.Evidence)"
    $objects[$level]=$obj
}

# Emits one call while preserving its fresh status for independent assertions.
function Call-Probe([string]$Name,[string]$Arguments='') {
    $script:number++
    $id=$script:number
    $script:body+='  %r'+$id+' = call { i1, i64 } @ube.proc.'+$procedures[$Name]+'(ptr @ctx'+$Arguments+")`r`n"
    return '%r'+$id
}

# Uses exact native exits to identify the first failed acceptance predicate.
function Assert-Condition([string]$Condition) {
    $script:checks++
    $n=$script:checks
    $script:body+="  br i1 $Condition, label %continue$n, label %failed$n`r`nfailed${n}:`r`n  ret i32 "+(1000+$n)+"`r`ncontinue${n}:`r`n"
}

# Checks fresh success and payload together, independently of visible Err.
function Assert-Pair([string]$Pair,[long]$Expected) {
    $script:number++;$n=$script:number
    $script:body+="  %f$n = extractvalue { i1, i64 } $Pair, 0`r`n  %v$n = extractvalue { i1, i64 } $Pair, 1`r`n  %eq$n = icmp eq i64 %v$n, $Expected`r`n  %ok$n = and i1 %f$n, %eq$n`r`n"
    Assert-Condition "%ok$n"
}

# Runs one independently initialized failure/recovery case against cached production objects.
function Run-Case([string]$Mode,[int]$Argument,[string]$Level) {
    $tag=$Mode+'-'+$Argument+'-'+$Level
    $path=Join-Path $artifacts ($tag+'.stage.ll')
    $retryPath=Join-Path $artifacts ($tag+'.retry.ll')
    $globals=(Byte-Global 'path.first' $utf8.GetBytes($path))+(Byte-Global 'path.retry' $utf8.GetBytes($retryPath))
    $script:body="@ctx = private global %ube.context zeroinitializer, align 8`r`ndefine i32 @main() {`r`nentry:`r`n  call void @ube.context.init(ptr @ctx)`r`n  %initialized = call i1 @ube.project.init(ptr @ctx)`r`n"
    $script:number=0;$script:checks=0
    Assert-Condition '%initialized'
    Assert-Pair (Call-Probe 'Prepare' ', ptr @test.source, ptr @test.catalog, ptr @test.runtime') 0
    Assert-Pair (Call-Probe 'OpenStage' ', ptr @path.first') -1
    $script:body+="  %owners = load i64, ptr @test.live`r`n  store i64 0, ptr @test.calls`r`n"
    if($Mode -eq 'allocation') {$script:body+="  store i64 $Argument, ptr @test.fail.at`r`n"}
    if($Mode -eq 'corrupt') {$null=Call-Probe 'Corrupt' (', i64 '+$Argument)}
    if($Mode -eq 'io') {$script:body+="  store i64 $Argument, ptr @test.io`r`n"}
    if($Mode -eq 'depth') {$script:body+="  %depth.ptr = getelementptr %ube.context, ptr @ctx, i32 0, i32 1`r`n  store i64 $Argument, ptr %depth.ptr`r`n"}
    $attempt=Call-Probe 'Attempt'
    if($Mode -eq 'depth') {$script:body+="  store i64 0, ptr %depth.ptr`r`n"}
    $script:body+="  %calls = load i64, ptr @test.calls`r`n  store i64 0, ptr @test.fail.at`r`n  store i64 0, ptr @test.io`r`n"
    if($Mode -eq 'baseline') {Assert-Pair $attempt -1}
    elseif($Mode -eq 'depth') {
        $script:body+="  %attempt.fresh = extractvalue { i1, i64 } $attempt, 0`r`n  %attempt.value = extractvalue { i1, i64 } $attempt, 1`r`n  %attempt.true = icmp ne i64 %attempt.value, 0`r`n  %success = and i1 %attempt.fresh, %attempt.true`r`n"
        if($Argument -eq 0) {Assert-Condition '%success'}
        elseif($Argument -eq 256) {$script:body+="  %refused = xor i1 %success, true`r`n";Assert-Condition '%refused'}
        $script:body+="  br i1 %success, label %depth.done, label %depth.failed`r`ndepth.failed:`r`n"
        $entered=Call-Probe 'Field' ', i64 5'
        $script:body+="  %work = extractvalue { i1, i64 } $entered, 1`r`n  %entered = icmp ne i64 %work, 777`r`n  br i1 %entered, label %depth.check, label %depth.done`r`ndepth.check:`r`n"
        Assert-Pair (Call-Probe 'CheckRejected' ', i64 0') 0
        $script:body+="  br label %depth.done`r`ndepth.done:`r`n"
    } else {
        Assert-Pair $attempt 0
        $expected=7;if($Mode -eq 'corrupt' -and $Argument -in @(1,2,5)) {$expected=9}
        Assert-Pair (Call-Probe 'CheckRejected' (', i64 '+$expected)) 0
        if($Mode -eq 'allocation') {
            $script:body+="  %failed = load i64, ptr @test.failed`r`n  %two = icmp eq i64 %failed, 2`r`n";Assert-Condition '%two'
        }
        if($Mode -eq 'io') {
            $failure=15;if($Argument -eq 2){$failure=16}
            Assert-Pair (Call-Probe 'Field' ', i64 2') $failure
            Assert-Pair (Call-Probe 'Field' ', i64 3') 57
        }
    }
    $script:body+="  %retained = load i64, ptr @test.live`r`n  %owners.only = icmp eq i64 %retained, %owners`r`n";Assert-Condition '%owners.only'
    Assert-Pair (Call-Probe 'CloseStage') -1
    if($Mode -in @('allocation','io')) {
        Assert-Pair (Call-Probe 'OpenStage' ', ptr @path.retry') -1
        Assert-Pair (Call-Probe 'Attempt') -1
        Assert-Pair (Call-Probe 'CloseStage') -1
    }
    $script:body+="  %disposed = call i1 @ube.context.dispose(ptr @ctx)`r`n";Assert-Condition '%disposed'
    $script:body+="  %live = load i64, ptr @test.live`r`n  %clean = icmp eq i64 %live, 0`r`n";Assert-Condition '%clean'
    if($Mode -eq 'baseline') {$script:body+="  %count = trunc i64 %calls to i32`r`n  ret i32 %count`r`n}`r`n"} else {$script:body+="  ret i32 0`r`n}`r`n"}
    $ir=Join-Path $artifacts ($tag+'.ll');$exe=Join-Path $artifacts ($tag+'.exe')
    Write-Text $ir ($types+"`r`n"+$externals+"`r`n"+$globals+$script:body)
    $build=Invoke-BoundedProcess $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$Level),$ir,$objects[$Level])+$links+@('-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')) 60000
    Require ($build.ExitCode -eq 0) "Fault harness build failed: $($build.Evidence)"
    $run=Invoke-BoundedProcess $exe @() 60000
    if($Mode -eq 'baseline') {Require ($run.ExitCode -gt 0 -and $run.ExitCode -lt 1000) "Baseline failed $($run.ExitCode): $($run.Evidence)";return $run.ExitCode}
    Require ($run.ExitCode -eq 0) "$tag failed assertion $($run.ExitCode): $($run.Evidence)"
    if($Mode -in @('allocation','io')) {
        Require ((Get-FileHash -LiteralPath $retryPath -Algorithm SHA256).Hash -ceq $script:baselineHash) "$tag recovery output differs from successful emission"
    }
    Write-Output "PASS: $tag controlled outcome and ownership checks"
}
$count=0
$script:baselineHash=''
foreach($level in @('O0','O2')) {
    $measured=Run-Case 'baseline' 0 $level
    if($count -ne 0){Require ($measured -eq $count) 'Optimization changed allocation count'}
    $count=$measured
    $stage=Join-Path $artifacts ('baseline-0-'+$level+'.stage.ll')
    $hash=(Get-FileHash -LiteralPath $stage -Algorithm SHA256).Hash
    if($script:baselineHash -ne '') {Require ($hash -ceq $script:baselineHash) 'Optimization changed complete generated LLVM'}
    $script:baselineHash=$hash
    $verified=Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc',('-'+$level),'-c',$stage,'-o',($stage+'.obj')) 60000
    Require ($verified.ExitCode -eq 0) "Generated baseline LLVM rejected: $($verified.Evidence)"
    Write-Output "PASS: $level baseline uses $count allocations with complete cleanup"
}
foreach($level in @('O0','O2')) {
    foreach($stage in 1..$count) {Run-Case 'allocation' $stage $level}
    foreach($mode in 1..5) {Run-Case 'corrupt' $mode $level}
    foreach($mode in 1..2) {Run-Case 'io' $mode $level}
    foreach($depth in @(0,192,224,240,248,252,254,255,256)) {Run-Case 'depth' $depth $level}
}
Write-Output "PASS: every $count measured allocation site plus malformed input, I/O and depth boundaries at O0/O2"
