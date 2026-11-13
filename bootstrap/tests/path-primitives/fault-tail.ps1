# Qualifies bounded path publication, same-handle ownership and independent recovery.
$core=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$files=@('FilePrimitives','PathPrimitives') | ForEach-Object {Join-Path $core ($_+'.bas')}
$manifest=Copy-Fixtures 'fault-library' $files '0' 'Library'
$library=Join-Path $artifacts 'library.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$library) 'EMIT OK'
$original=[IO.File]::ReadAllText($library,$utf8)
function Replace-Target([string]$Text,[string]$Name,[string]$Definition) {
    $pattern='(?ms)^define [^\r\n]*@'+[regex]::Escape($Name)+'\([^\r\n]*\{\r?\n.*?^\}'
    Require ([regex]::Matches($Text,$pattern).Count -eq 1) "Missing unique target $Name"
    return [regex]::Replace($Text,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $Definition})
}
$cases=@('full-output-bound','full-utf8-expansion', 'full-success','full-input-bound','full-input-excess','full-invalid-utf8','full-nul','full-capacity','full-zero-capacity','full-output-alias','full-input-alias','full-scalar-alias','full-os-failure','full-result-excess','full-surrogate','full-conversion-failure','full-allocation','full-quota','final-success','final-os-failure','final-allocation','final-stale','final-busy','compare-success','compare-invalid-utf8','compare-os-failure','compare-result-excess','compare-allocation','compare-alias')
foreach($mode in $cases) {
    $text=$original
    $final=$mode.StartsWith('final-');$compare=$mode.StartsWith('compare-')
    $expectedResult='false';$expectedCount=83;$expectedByte=77;$expectedFailure=1;$expectedErr=5;$expectedAllocations=1;$expectedBusy=0
    $inputCount=1;$inputByte=97;$capacity=4096;$wanted=17;$countPointer='@test.count';$failurePointer='@test.failure';$quota='';$fill=''
    $returnUnits=4;$firstUnit=67
    if($mode.EndsWith('-success') -or $mode -eq 'full-input-bound' -or $mode -eq 'full-output-bound') {$expectedResult='true';$expectedCount=4;$expectedByte=67;$expectedFailure=0;$expectedErr=777}
    if($compare -and $mode.EndsWith('-success')) {$expectedCount=0;$expectedByte=77}
    if($mode -eq 'full-input-bound') {$inputCount=4096;$fill="  br label %fill`r`nfill:`r`n  %i = phi i64 [ 0, %entry ], [ %next, %fill ]`r`n  %cell = getelementptr i64, ptr @test.input, i64 %i`r`n  store i64 97, ptr %cell`r`n  %next = add i64 %i, 1`r`n  %more = icmp ult i64 %next, 4096`r`n  br i1 %more, label %fill, label %call`r`ncall:"}
    if($mode -eq 'full-input-excess') {$inputCount=4097}
    if($mode -in @('full-invalid-utf8','compare-invalid-utf8')) {$inputByte=255}
    if($mode -eq 'full-nul') {$inputByte=0}
    if($mode -eq 'full-capacity') {$capacity=3}
    if($mode -eq 'full-zero-capacity') {$capacity=0}
    if($mode -eq 'full-output-alias') {$countPointer='@test.output';$expectedFailure=0;$expectedAllocations=0}
    if($mode -eq 'full-input-alias') {$countPointer='@test.input';$expectedFailure=0;$expectedAllocations=0}
    if($mode -in @('full-scalar-alias','compare-alias')) {$failurePointer='@test.count';$expectedFailure=0;$expectedAllocations=0}
    if($mode.EndsWith('-os-failure') -or $mode -eq 'full-conversion-failure' -or $mode -eq 'compare-result-excess') {$expectedFailure=5;$expectedErr=57}
    if($mode -eq 'full-output-bound') {$returnUnits=4096;$expectedCount=4096}
    if($mode -eq 'full-utf8-expansion') {$returnUnits=4096}
    if($mode -eq 'full-result-excess') {$returnUnits=4097}
    if($mode -eq 'full-surrogate') {$returnUnits=1;$firstUnit=55296}
    if($mode -eq 'final-stale') {$wanted=99;$expectedFailure=9;$expectedAllocations=0}
    if($mode -eq 'final-busy') {$expectedBusy=1;$expectedFailure=13;$expectedAllocations=0}
    if($mode.EndsWith('-allocation')) {$expectedFailure=3;$expectedErr=7;$expectedAllocations=2}
    if($mode -eq 'full-quota') {$expectedFailure=3;$expectedErr=7;$expectedAllocations=0;$quota="  store i64 67108864, ptr %charge"}
    $allocationFail='false';if($mode.EndsWith('-allocation')) {$allocationFail='%inject'}
    $text=$text.Replace('define ptr @ube.target.allocate(', 'define ptr @test.real.allocate(')
    $text+=@"

define ptr @ube.target.allocate(i64 %bytes) {
entry:
  %old = load volatile i64, ptr @test.allocations
  %next = add i64 %old, 1
  store volatile i64 %next, ptr @test.allocations
  %inject = load volatile i1, ptr @test.inject
  br i1 $allocationFail, label %failed, label %allocate
allocate:
  %block = call ptr @test.real.allocate(i64 %bytes)
  ret ptr %block
failed:
  ret ptr null
}
"@
    $osFail='false';if($mode.EndsWith('-os-failure')) {$osFail='%inject'}
    $pathBody=@"
entry:
  %inject = load volatile i1, ptr @test.inject
  br i1 $osFail, label %failed, label %write
write:
  %first = select i1 %inject, i16 $firstUnit, i16 67
  store i16 %first, ptr %output
  %a = getelementptr i16, ptr %output, i64 1
  store i16 58, ptr %a
  %b = getelementptr i16, ptr %output, i64 2
  store i16 92, ptr %b
  %c = getelementptr i16, ptr %output, i64 3
  store i16 97, ptr %c
  %length = select i1 %inject, i32 $returnUnits, i32 4
  ret i32 %length
failed:
  ret i32 0
}
"@
    if($mode -in @('full-output-bound','full-utf8-expansion')) {
        $unit=97;if($mode -eq 'full-utf8-expansion'){$unit=230}
        $pathBody=$pathBody.Replace('  %length = select',("  br label %fillwide"+"`r`nfillwide:`r`n  %wi = phi i64 [ 4, %write ], [ %wnext, %fillwide ]`r`n  %wcell = getelementptr i16, ptr %output, i64 %wi`r`n  store i16 $unit, ptr %wcell`r`n  %wnext = add i64 %wi, 1`r`n  %wmore = icmp ult i64 %wnext, 4096`r`n  br i1 %wmore, label %fillwide, label %wide.done`r`nwide.done:`r`n  %length = select"))
    }
    $text=Replace-Target $text 'ube.target.path.full' ("define i32 @ube.target.path.full(ptr %input, ptr %output, i32 %capacity) {`r`n"+$pathBody)
    $finalBody=$pathBody.Replace('entry:',"entry:`r`n  %right = icmp eq ptr %handle, inttoptr (i64 17 to ptr)`r`n  store i1 %right, ptr @test.same.handle")
    $text=Replace-Target $text 'ube.target.path.final' ("define i32 @ube.target.path.final(ptr %handle, ptr %output, i32 %capacity) {`r`n"+$finalBody)
    if($mode -eq 'full-conversion-failure') {
        $text=$text.Replace('define i32 @ube.target.system.utf8(', 'define i32 @test.real.utf8(')
        $text+=@'

define i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %bytes, i32 %capacity) {
entry:
  %inject = load volatile i1, ptr @test.inject
  %writing = icmp ne ptr %bytes, null
  %fail = and i1 %inject, %writing
  br i1 %fail, label %failed, label %convert
failed:
  ret i32 0
convert:
  %result = call i32 @test.real.utf8(ptr %wide, i32 %units, ptr %bytes, i32 %capacity)
  ret i32 %result
}
'@
    }
    if($mode -in @('compare-os-failure','compare-result-excess')) {
        $text=$text.Replace('define i32 @ube.target.path.compare(', 'define i32 @test.real.compare(')
        $bad=0;if($mode -eq 'compare-result-excess'){$bad=4}
        $text+=@"

define i32 @ube.target.path.compare(ptr %first, i32 %first.length, ptr %second, i32 %second.length) {
entry:
  %inject = load volatile i1, ptr @test.inject
  br i1 %inject, label %failed, label %compare
failed:
  ret i32 $bad
compare:
  %result = call i32 @test.real.compare(ptr %first, i32 %first.length, ptr %second, i32 %second.length)
  ret i32 %result
}
"@
    }
    $text=Replace-Target $text 'ube.target.file.close' "define i1 @ube.target.file.close(ptr %handle) {`r`nentry:`r`n  ret i1 true`r`n}"
    $setup='';$cleanup='';$ownerChecks='true';$recoveryExpected=4
    if($compare) {$call="@ube.path.compare(ptr @test.ctx, ptr @test.first, ptr @test.second, ptr $countPointer, ptr $failurePointer)";$recovery='@ube.path.compare(ptr @test.ctx, ptr @test.first, ptr @test.second, ptr @test.count, ptr @test.failure)';$recoveryExpected=0}
    elseif($final) {
        $call="@ube.path.resolve(ptr @test.ctx, ptr null, i64 $wanted, ptr @test.destination, ptr $countPointer, ptr $failurePointer, i1 true)"
        $recovery='@ube.path.resolve(ptr @test.ctx, ptr null, i64 17, ptr @test.destination, ptr @test.count, ptr @test.failure, i1 true)'
        $setup=@"
  store atomic i64 17, ptr %slot release, align 8
  store ptr inttoptr (i64 17 to ptr), ptr %handle
  %kind = getelementptr %ube.resource, ptr %slot, i32 0, i32 3
  store i64 1, ptr %kind
  store atomic i64 $expectedBusy, ptr %busy release, align 8
"@
        $cleanup="  %closed = call i1 @ube.file.close(ptr @test.ctx, ptr @test.token, ptr @test.failure)"
        $ownerChecks='%owner.ok'
    }else {$call="@ube.path.resolve(ptr @test.ctx, ptr @test.first, i64 0, ptr @test.destination, ptr $countPointer, ptr $failurePointer, i1 false)";$recovery='@ube.path.resolve(ptr @test.ctx, ptr @test.first, i64 0, ptr @test.destination, ptr @test.count, ptr @test.failure, i1 false)'}
    $inputUpper=$inputCount+4;$outputUpper=$capacity+4
    $main=@"
@test.ctx = private global %ube.context zeroinitializer, align 8
@test.input = private global [4097 x i64] zeroinitializer, align 8
@test.other = private global [1 x i64] [i64 65], align 8
@test.output = private global [4096 x i64] zeroinitializer, align 8
@test.first = private global {i64, i64, ptr, ptr} {i64 5, i64 $inputUpper, ptr @test.input, ptr null}, align 8
@test.second = private global {i64, i64, ptr, ptr} {i64 3, i64 3, ptr @test.other, ptr null}, align 8
@test.destination = private global {i64, i64, ptr, ptr} {i64 5, i64 $outputUpper, ptr @test.output, ptr null}, align 8
@test.count = private global i64 83, align 8
@test.failure = private global i64 0, align 8
@test.token = private global i64 17, align 8
@test.allocations = private global i64 0, align 8
@test.inject = private global i1 true
@test.same.handle = private global i1 true
define i32 @main() {
entry:
  call void @ube.context.init(ptr @test.ctx)
  store i64 777, ptr @test.ctx
  store i64 $inputByte, ptr @test.input
  store i64 77, ptr @test.output
  %charge = getelementptr %ube.context, ptr @test.ctx, i32 0, i32 5
  %slot = getelementptr %ube.context, ptr @test.ctx, i32 0, i32 7, i64 0
  %handle = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  %busy = getelementptr %ube.resource, ptr %slot, i32 0, i32 4
$setup
$quota
$fill
  %result = call i1 $call
  %result.ok = icmp eq i1 %result, $expectedResult
  %count = load i64, ptr @test.count
  %count.ok = icmp eq i64 %count, $expectedCount
  %byte = load i64, ptr @test.output
  %byte.ok = icmp eq i64 %byte, $expectedByte
  %input.value = load i64, ptr @test.input
  %input.ok = icmp eq i64 %input.value, $inputByte
  %failure = load i64, ptr @test.failure
  %failure.ok = icmp eq i64 %failure, $expectedFailure
  %err = load i64, ptr @test.ctx
  %err.ok = icmp eq i64 %err, $expectedErr
  %allocations = load volatile i64, ptr @test.allocations
  %allocations.ok = icmp eq i64 %allocations, $expectedAllocations
  %owner = load atomic i64, ptr %slot acquire, align 8
  %owner.same = icmp eq i64 %owner, 17
  %busy.now = load atomic i64, ptr %busy acquire, align 8
  %busy.same = icmp eq i64 %busy.now, $expectedBusy
  %same.handle = load i1, ptr @test.same.handle
  %same.owner = and i1 %owner.same, %same.handle
  %owner.ok = and i1 %same.owner, %busy.same
  %a = and i1 %result.ok, %count.ok
  %b = and i1 %byte.ok, %failure.ok
  %c = and i1 %err.ok, %allocations.ok
  %d = and i1 %a, %b
  %e = and i1 %c, $ownerChecks
  %prior = and i1 %d, %e
  %initial = and i1 %prior, %input.ok
  store i1 false, ptr @test.inject
  store atomic i64 0, ptr %busy release, align 8
  store i64 97, ptr @test.input
  %first.upper = getelementptr i64, ptr @test.first, i64 1
  store i64 5, ptr %first.upper
  %output.upper = getelementptr i64, ptr @test.destination, i64 1
  store i64 4100, ptr %output.upper
  %charged = load i64, ptr %charge
  %quota.injected = icmp eq i64 %charged, 67108864
  %restored = select i1 %quota.injected, i64 0, i64 %charged
  store i64 %restored, ptr %charge
  %recovery = call i1 $recovery
  %recovered.count = load i64, ptr @test.count
  %recovered.count.ok = icmp eq i64 %recovered.count, $recoveryExpected
  %recovered.err = load i64, ptr @test.ctx
  %recovered.err.ok = icmp eq i64 %recovered.err, $expectedErr
  %recovered.failure = load i64, ptr @test.failure
  %recovered.failure.ok = icmp eq i64 %recovered.failure, 0
  %f = and i1 %recovery, %recovered.count.ok
  %g = and i1 %recovered.err.ok, %recovered.failure.ok
  %recovered = and i1 %f, %g
$cleanup
  %disposed = call i1 @ube.context.dispose(ptr @test.ctx)
  %live.ptr = getelementptr %ube.context, ptr @test.ctx, i32 0, i32 6
  %live = load i64, ptr %live.ptr
  %clean = icmp eq i64 %live, 0
  %released = and i1 %disposed, %clean
  %correct = and i1 %initial, %recovered
  %all = and i1 %correct, %released
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
"@
    $path=Join-Path $artifacts ($mode+'.ll');Write-Text $path ($text+"`r`n"+$main)
    foreach($level in @('O0','O2')) {
        $exe=Join-Path $artifacts ($mode+'-'+$level+'.exe');Build-Harness $path $exe $level
        $run=Invoke-BoundedProcess $exe @()
        Require ($run.ExitCode -eq 0) "Path fault $mode $level failed: $($run.Evidence)"
        Write-Output "PASS: $mode $level"
    }
}
Write-Output "PASS: 58 path boundary/failure/ownership/recovery cases; evidence $artifacts"
