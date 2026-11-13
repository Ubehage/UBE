# Exercises the production runtime and UBE progress helper with isolated native faults.
$core = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$files = @('BufferPrimitives','FilePrimitives','SystemPrimitives','StandardStreams') | ForEach-Object { Join-Path $core ($_+'.bas') }
$manifest = Copy-Fixtures 'fault-library' $files '0' 'Library'
$library = Join-Path $artifacts 'library.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$library) 'EMIT OK'
$original = [IO.File]::ReadAllText($library,$utf8)
$bound = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) 'Fault library binding failed'
$helper = 0
foreach ($line in ($bound.Stdout -split '\r?\n')) {
    if ($line -match '^SYMBOL ') { $fields=$line.Substring(7).Split('|'); if ($fields[1] -eq 'function' -and $fields[2] -eq 'TryWriteBytes') { $helper=[int]$fields[0] } }
}
Require ($helper -gt 0) 'Missing ordinary StandardStreams helper'

function Replace-Target([string]$Text,[string]$Name,[string]$Definition) {
    $pattern='(?ms)^define [^\r\n]*@'+[regex]::Escape($Name)+'\([^\r\n]*\{\r?\n.*?^\}'
    Require ([regex]::Matches($Text,$pattern).Count -eq 1) "Missing unique target $Name"
    return [regex]::Replace($Text,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $Definition})
}
$cases=@('command-success','command-surrogate','command-null','command-convert-failure','command-allocation','command-quota','command-alias','write-zero','write-short','write-impossible','write-failed-progress','write-null','write-allocation','helper-chunks','helper-short','helper-zero','helper-impossible','helper-failed-progress')
foreach ($mode in $cases) {
    $text=$original
    $command=$mode.StartsWith('command-')
    $isHelper=$mode.StartsWith('helper-')
    $expectedResult='false';$expectedCount=83;$expectedByte=77;$expectedFailure=0;$expectedErr=5;$expectedCalls=0
    $extra=''
    $which='ptr @test.failure'
    $quota=''
    $stub=@'
define ptr @ube.target.system.commandline() {
entry:
  ret ptr @test.wide
}
'@
    $wide='i16 65, i16 0'
    if ($mode -eq 'command-surrogate') {$wide='i16 55296, i16 0'}
    if ($mode -eq 'command-null') {$stub=$stub.Replace('ptr @test.wide','ptr null')}
    $text=Replace-Target $text 'ube.target.system.commandline' $stub
    $extra+="@test.wide = private global [2 x i16] [$wide]`r`n"
    if ($command) {
        $call='  %result = call i1 @ube.system.commandline(ptr @test.ctx, ptr @test.array, ptr @test.count, '+$which+')'
        $expectedFailure=1
        if ($mode -eq 'command-success') {$expectedResult='true';$expectedCount=1;$expectedByte=65;$expectedFailure=0;$expectedErr=777}
        if ($mode -eq 'command-null') {$expectedFailure=5;$expectedErr=57}
        if ($mode -eq 'command-convert-failure') {
            $text=Replace-Target $text 'ube.target.system.utf8' @'
define i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %bytes, i32 %capacity) {
entry:
  %measure = icmp eq ptr %bytes, null
  %value = select i1 %measure, i32 1, i32 0
  ret i32 %value
}
'@
            $expectedFailure=5;$expectedErr=57
        }
        if ($mode -eq 'command-quota') {$quota='  %quota = getelementptr %ube.context, ptr @test.ctx, i32 0, i32 5' + "`r`n  store i64 67108864, ptr %quota";$expectedFailure=3;$expectedErr=7}
        if ($mode -eq 'command-alias') {$call=$call.Replace('ptr @test.failure','ptr @test.count');$expectedFailure=0}
    } else {
        $expectedCount=0;$expectedErr=777
        $call='  %result = call i1 @ube.system.write(ptr @test.ctx, i64 1, ptr @test.array, i64 0, i64 8, ptr @test.count, ptr @test.failure)'
        $expectedResult='true'
        $progress='i32 0';$accepted='true'
        if ($mode -eq 'write-short') {$progress='i32 2';$expectedCount=2}
        if ($mode -eq 'write-impossible') {$progress='i32 9';$expectedResult='false';$expectedFailure=15;$expectedErr=57}
        if ($mode -eq 'write-failed-progress') {$progress='i32 2';$accepted='false';$expectedCount=2;$expectedResult='false';$expectedFailure=15;$expectedErr=57}
        if ($mode -eq 'write-null') {$expectedResult='false';$expectedFailure=15;$expectedErr=57}
        if ($isHelper) {
            $call="  %pair = call { i1, i64 } @ube.proc.$helper(ptr @test.ctx, i64 1, ptr @test.array, i64 0, i64 65537, ptr @test.failure)`r`n  %fresh = extractvalue { i1, i64 } %pair, 0`r`n  %value = extractvalue { i1, i64 } %pair, 1`r`n  %nonzero = icmp ne i64 %value, 0`r`n  %result = and i1 %fresh, %nonzero"
            $expectedCount=83;$expectedCalls=1
            if ($mode -eq 'helper-chunks') {$progress='i32 %count';$expectedCalls=2}
            if ($mode -eq 'helper-short') {$progress='i32 %portion';$expectedCalls=3}
            if ($mode -eq 'helper-zero') {$expectedResult='false';$expectedFailure=15;$expectedErr=57}
            if ($mode -eq 'helper-impossible') {$progress='i32 %excess';$expectedResult='false';$expectedFailure=15;$expectedErr=57}
            if ($mode -eq 'helper-failed-progress') {$progress='i32 2';$accepted='false';$expectedResult='false';$expectedFailure=15;$expectedErr=57}
        } elseif ($mode -ne 'write-null' -and $mode -ne 'write-allocation') {$expectedCalls=1}
        $handle='inttoptr (i64 17 to ptr)';if ($mode -eq 'write-null') {$handle='null'}
        $text=Replace-Target $text 'ube.target.system.standard' "define ptr @ube.target.system.standard(i32 %which) {`r`nentry:`r`n  ret ptr $handle`r`n}"
        $text=Replace-Target $text 'ube.target.file.write' @"
define i1 @ube.target.file.write(ptr %handle, ptr %bytes, i32 %count, ptr %progress) {
entry:
  %old = load volatile i64, ptr @test.calls
  %next = add i64 %old, 1
  store volatile i64 %next, ptr @test.calls
  %small = icmp ult i32 %count, 32768
  %portion = select i1 %small, i32 %count, i32 32768
  %excess = add i32 %count, 1
  store $progress, ptr %progress
  ret i1 $accepted
}
"@
    }
    if ($mode -in @('command-allocation','write-allocation')) {
        $text=Replace-Target $text 'ube.target.allocate' @'
define ptr @ube.target.allocate(i64 %bytes) {
entry:
  %old = load volatile i64, ptr @test.calls
  %next = add i64 %old, 1
  store volatile i64 %next, ptr @test.calls
  ret ptr null
}
'@
        $expectedResult='false';$expectedFailure=3;$expectedErr=7;$expectedCalls=2
    }
    $main=@"
@test.ctx = private global %ube.context zeroinitializer, align 8
@test.data = private global [131072 x i64] zeroinitializer, align 8
@test.array = private global {i64, i64, ptr, ptr} {i64 5, i64 131076, ptr @test.data, ptr null}, align 8
@test.count = private global i64 83, align 8
@test.failure = private global i64 0, align 8
@test.calls = private global i64 0, align 8
$extra
define i32 @main() {
entry:
  call void @ube.context.init(ptr @test.ctx)
  store i64 777, ptr @test.ctx
  store i64 77, ptr @test.data
$quota
$call
  %result.ok = icmp eq i1 %result, $expectedResult
  %count = load i64, ptr @test.count
  %count.ok = icmp eq i64 %count, $expectedCount
  %byte = load i64, ptr @test.data
  %byte.ok = icmp eq i64 %byte, $expectedByte
  %failure = load i64, ptr @test.failure
  %failure.ok = icmp eq i64 %failure, $expectedFailure
  %err = load i64, ptr @test.ctx
  %err.ok = icmp eq i64 %err, $expectedErr
  %calls = load volatile i64, ptr @test.calls
  %calls.ok = icmp eq i64 %calls, $expectedCalls
  %disposed = call i1 @ube.context.dispose(ptr @test.ctx)
  %live.ptr = getelementptr %ube.context, ptr @test.ctx, i32 0, i32 6
  %live = load i64, ptr %live.ptr
  %clean = icmp eq i64 %live, 0
  %a = and i1 %result.ok, %count.ok
  %b = and i1 %byte.ok, %failure.ok
  %c = and i1 %err.ok, %calls.ok
  %d = and i1 %disposed, %clean
  %e = and i1 %a, %b
  %f = and i1 %c, %d
  %all = and i1 %e, %f
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
"@
    $path=Join-Path $artifacts ($mode+'.ll')
    Write-Text $path ($text+"`r`n"+$main)
    foreach ($level in @('O0','O2')) {
        $exe=Join-Path $artifacts ($mode+'-'+$level+'.exe')
        Build-Harness $path $exe $level
        $run=Invoke-BoundedProcess $exe @()
        Require ($run.ExitCode -eq 0) "Fault $mode $level failed: $($run.Evidence)"
        Write-Output "PASS: $mode $level"
    }
}
Write-Output "PASS: 36 system fault/ownership/progress cases; evidence $artifacts"
