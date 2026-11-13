# Uses named OS boundaries to assert failure preservation, typed ownership and recovery.
$core=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$files=@('FilePrimitives','SystemPrimitives','PathPrimitives','DirectoryPrimitives') | ForEach-Object {Join-Path $core ($_+'.bas')}
$manifest=Copy-Fixtures 'fault-library' $files '0' 'Library'
$library=Join-Path $artifacts 'library.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$library) 'EMIT OK'
$original=[IO.File]::ReadAllText($library,$utf8)
function Replace-Target([string]$Text,[string]$Name,[string]$Definition) {
    $pattern='(?ms)^define [^\r\n]*@'+[regex]::Escape($Name)+'\([^\r\n]*\{\r?\n.*?^\}'
    Require ([regex]::Matches($Text,$pattern).Count -eq 1) "Missing unique target $Name"
    return [regex]::Replace($Text,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $Definition})
}
$cases=@('id.ok','id.query','id.short','id.alias','id.process','len.ok','len.query','len.large','len.negative','len.directory','len.process','len.alias','exe.ok','exe.os','exe.short','exe.allocate','exe.alias','clock.ok','clock.alias','create.ok','create.existsfile','create.existsdir','create.denied','create.allocate','create.invalid','create.alias','remove.missing','remove.denied','delete.missing','delete.pathmissing','delete.denied','replace.crossvolume','replace.missing','replace.denied','replace.ok','kind.file','kind.directory','kind.missing','kind.pathmissing','kind.denied','kind.invalidname','kind.allocate','kind.invalid','kind.alias')
foreach($mode in $cases) {
    $pieces=$mode.Split('.');$operation=$pieces[0];$variant=$pieces[1]
    $text=$original;$owner=$operation -in @('id','len')
    $expectedResult='true';$expectedCount=83;$expectedFailure=0;$expectedErr=777;$expectedByte=77
    $expectedCalls=1;$expectedAllocations=0;$capacity=4096;$inputByte=97;$kind=1
    $scalar='@test.count';$failure='@test.failure';$nativeError=0;$attributes=0;$size=5
    $queryOk='true';$executableLength=4
    if($operation -eq 'id'){$expectedByte=4}
    if($operation -eq 'len'){$expectedCount=5}
    if($operation -eq 'exe'){$expectedCount=4;$expectedByte=67;$expectedAllocations=1}
    if($operation -eq 'clock'){$expectedCount=4294967297}
    if($operation -in @('create','remove','delete','replace','kind')){$expectedAllocations=1}
    if($operation -eq 'kind'){$expectedCount=1}
    if($variant -notin @('ok','file','directory','missing','pathmissing') -or ($variant -eq 'directory' -and $operation -eq 'len')) {
        $expectedResult='false';$expectedCount=83;$expectedByte=77;$expectedFailure=5;$expectedErr=57
    }
    if($variant -eq 'query'){$queryOk='false'}
    if($variant -eq 'short'){$capacity=1;$expectedFailure=1;$expectedErr=5;if($operation -eq 'id'){$expectedCalls=0}}
    if($variant -eq 'alias'){
        $expectedFailure=0;$expectedErr=5;$expectedCalls=0;$expectedAllocations=0
        if($operation -eq 'id'){$failure='@test.output'}elseif($operation -in @('create','remove','delete','replace')){$failure='@test.input'}else{$failure='@test.count'}
    }
    if($variant -eq 'process'){$kind=4;$expectedFailure=9;$expectedErr=5;$expectedCalls=0}
    if($variant -eq 'directory' -and $operation -eq 'len'){$kind=3;$expectedFailure=9;$expectedErr=5;$expectedCalls=0}
    if($variant -eq 'large'){$size=2147483648;$expectedFailure=4;$expectedErr=6}
    if($variant -eq 'negative'){$size=-1;$expectedFailure=4;$expectedErr=6}
    if($variant -eq 'os'){$executableLength=0}
    if($variant -eq 'allocate'){$expectedFailure=3;$expectedErr=7;$expectedCalls=0;$expectedAllocations=2}
    if($variant -eq 'invalid'){$inputByte=255;$expectedFailure=1;$expectedErr=5;$expectedCalls=0}
    if($variant -eq 'existsfile'){$nativeError=80;$expectedFailure=17;$expectedErr=58}
    if($variant -eq 'existsdir'){$nativeError=183;$expectedFailure=17;$expectedErr=58}
    if($variant -eq 'denied'){$nativeError=5;$attributes=-5}
    if($variant -eq 'crossvolume'){$nativeError=17}
    if($variant -in @('missing','pathmissing')) {
        $nativeError=2;if($variant -eq 'pathmissing'){$nativeError=3}
        if($operation -eq 'kind'){$attributes=-$nativeError;$expectedCount=0}
        else {$expectedResult='false';$expectedCount=83;$expectedFailure=18;$expectedErr=53}
    }
    if($variant -eq 'directory' -and $operation -eq 'kind'){$attributes=16;$expectedCount=2}
    if($variant -eq 'invalidname'){$attributes=-123}
    $increment="  %old = load volatile i64, ptr @test.calls`r`n  %next = add i64 %old, 1`r`n  store volatile i64 %next, ptr @test.calls"
    $text=Replace-Target $text 'ube.target.file.info' @"
define i1 @ube.target.file.info(ptr %handle, ptr %info) {
entry:
$increment
  %inject = load volatile i1, ptr @test.inject
  %ok = select i1 %inject, i1 $queryOk, i1 true
  %volume = getelementptr i8, ptr %info, i64 28
  %high = getelementptr i8, ptr %info, i64 44
  %low = getelementptr i8, ptr %info, i64 48
  store i32 16909060, ptr %volume
  store i32 84281096, ptr %high
  store i32 151653132, ptr %low
  ret i1 %ok
}
"@
    $text=Replace-Target $text 'ube.target.file.size' @"
define i1 @ube.target.file.size(ptr %handle, ptr %size) {
entry:
$increment
  %inject = load volatile i1, ptr @test.inject
  %ok = select i1 %inject, i1 $queryOk, i1 true
  %value = select i1 %inject, i64 $size, i64 5
  store i64 %value, ptr %size
  ret i1 %ok
}
"@
    $text=Replace-Target $text 'ube.target.system.executable' @"
define i32 @ube.target.system.executable(ptr %output, i32 %capacity) {
entry:
$increment
  store i16 67, ptr %output
  %a = getelementptr i16, ptr %output, i64 1
  store i16 58, ptr %a
  %b = getelementptr i16, ptr %output, i64 2
  store i16 92, ptr %b
  %c = getelementptr i16, ptr %output, i64 3
  store i16 97, ptr %c
  %inject = load volatile i1, ptr @test.inject
  %length = select i1 %inject, i32 $executableLength, i32 4
  ret i32 %length
}
"@
    $text=Replace-Target $text 'ube.target.system.clock' "define i64 @ube.target.system.clock() {`r`nentry:`r`n$increment`r`n  ret i64 4294967297`r`n}"
    foreach($name in @('directory.create','directory.remove','file.delete','file.replace','path.attributes')){
        $signature='ptr %path';if($name -eq 'file.replace'){$signature='ptr %source, ptr %destination'}
        $value=$nativeError;if($name -eq 'path.attributes'){$value=$attributes}
        $text=Replace-Target $text ('ube.target.'+$name) "define i64 @ube.target.$name($signature) {`r`nentry:`r`n$increment`r`n  %inject = load volatile i1, ptr @test.inject`r`n  %result = select i1 %inject, i64 $value, i64 0`r`n  ret i64 %result`r`n}"
    }
    $text=$text.Replace('define ptr @ube.target.allocate(','define ptr @test.real.allocate(')
    $allocationFail='false';if($variant -eq 'allocate'){$allocationFail='%inject'}
    $text+=@"

define ptr @ube.target.allocate(i64 %bytes) {
entry:
  %old = load volatile i64, ptr @test.allocations
  %next = add i64 %old, 1
  store volatile i64 %next, ptr @test.allocations
  %inject = load volatile i1, ptr @test.inject
  br i1 $allocationFail, label %failed, label %allocate
allocate:
  %result = call ptr @test.real.allocate(i64 %bytes)
  ret ptr %result
failed:
  ret ptr null
}
"@
    $text=Replace-Target $text 'ube.target.file.close' "define i1 @ube.target.file.close(ptr %handle) {`r`nentry:`r`n  ret i1 true`r`n}"
    $recoveryCount=83;$ownerSetup='';$ownerCleanup=''
    switch($operation){
        'id' {$call="@ube.file.identity(ptr @test.ctx, i64 17, ptr @test.destination, ptr $failure)"}
        'len' {$call="@ube.file.length(ptr @test.ctx, i64 17, ptr $scalar, ptr $failure)";$recoveryCount=5}
        'exe' {$call="@ube.system.executable(ptr @test.ctx, ptr @test.destination, ptr $scalar, ptr $failure)";$recoveryCount=4}
        'clock' {$call="@ube.system.clock(ptr @test.ctx, ptr $scalar, ptr $failure)";$recoveryCount=4294967297}
        'kind' {$call="@ube.path.kind(ptr @test.ctx, ptr @test.first, ptr $scalar, ptr $failure)";$recoveryCount=1}
        'create' {$call="@ube.directory.create(ptr @test.ctx, ptr @test.first, ptr $failure)"}
        'remove' {$call="@ube.directory.remove(ptr @test.ctx, ptr @test.first, ptr $failure)"}
        'delete' {$call="@ube.file.delete(ptr @test.ctx, ptr @test.first, ptr $failure)"}
        'replace' {$call="@ube.file.replace(ptr @test.ctx, ptr @test.first, ptr @test.first, ptr $failure)"}
    }
    $recovery=$call.Replace(('ptr '+$failure+')'),'ptr @test.failure)')
    if($owner){
        $ownerSetup="  store atomic i64 17, ptr %slot release, align 8`r`n  store ptr inttoptr (i64 17 to ptr), ptr %handle`r`n  store i64 $kind, ptr %kind.ptr"
        $ownerCleanup='  %closed = call i1 @ube.file.close(ptr @test.ctx, ptr @test.token, ptr @test.failure)'
    }
    $expectedIdentity=@(4,3,2,1,8,7,6,5,12,11,10,9)
    $byteChecks='';$identityOk='true'
    for($i=0;$i -lt 12;$i++){
        $expected=77
        if($operation -eq 'id' -and $expectedResult -eq 'true'){$expected=$expectedIdentity[$i]}
        elseif($operation -eq 'exe' -and $expectedResult -eq 'true' -and $i -lt 4){$expected=@(67,58,92,97)[$i]}
        $byteChecks+="  %cell$i = getelementptr i64, ptr @test.output, i64 $i`r`n  %byte$i = load i64, ptr %cell$i`r`n  %byte.ok$i = icmp eq i64 %byte$i, $expected`r`n  %bytes.ok$i = and i1 $identityOk, %byte.ok$i`r`n"
        $identityOk="%bytes.ok$i"
    }
    $upper=$capacity+4
    $main=@"
@test.ctx = private global %ube.context zeroinitializer, align 8
@test.input = private global i64 $inputByte, align 8
@test.output = private global [4096 x i64] zeroinitializer, align 8
@test.first = private global {i64, i64, ptr, ptr} {i64 5, i64 5, ptr @test.input, ptr null}, align 8
@test.destination = private global {i64, i64, ptr, ptr} {i64 5, i64 $upper, ptr @test.output, ptr null}, align 8
@test.count = private global i64 83, align 8
@test.failure = private global i64 0, align 8
@test.token = private global i64 17, align 8
@test.calls = private global i64 0, align 8
@test.allocations = private global i64 0, align 8
@test.inject = private global i1 true
define i32 @main() {
entry:
  call void @ube.context.init(ptr @test.ctx)
  store i64 777, ptr @test.ctx
  %slot = getelementptr %ube.resource, ptr null, i64 0
  %unused = ptrtoint ptr %slot to i64
  %real.slot = getelementptr %ube.context, ptr @test.ctx, i32 0, i32 7, i64 0
  %handle = getelementptr %ube.resource, ptr %real.slot, i32 0, i32 1
  %kind.ptr = getelementptr %ube.resource, ptr %real.slot, i32 0, i32 3
$ownerSetup
  br label %fill
fill:
  %i = phi i64 [ 0, %entry ], [ %next, %fill ]
  %cell = getelementptr i64, ptr @test.output, i64 %i
  store i64 77, ptr %cell
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, 12
  br i1 %more, label %fill, label %run
run:
  %result = call i1 $call
  %result.ok = icmp eq i1 %result, $expectedResult
  %count = load i64, ptr @test.count
  %count.ok = icmp eq i64 %count, $expectedCount
  %failure = load i64, ptr @test.failure
  %failure.ok = icmp eq i64 %failure, $expectedFailure
  %err = load i64, ptr @test.ctx
  %err.ok = icmp eq i64 %err, $expectedErr
  %input = load i64, ptr @test.input
  %input.ok = icmp eq i64 %input, $inputByte
  %calls = load volatile i64, ptr @test.calls
  %calls.ok = icmp eq i64 %calls, $expectedCalls
  %allocations = load volatile i64, ptr @test.allocations
  %allocations.ok = icmp eq i64 %allocations, $expectedAllocations
$byteChecks
  %a = and i1 %result.ok, %count.ok
  %b = and i1 %failure.ok, %err.ok
  %c = and i1 %calls.ok, %allocations.ok
  %d = and i1 %input.ok, $identityOk
  %e = and i1 %a, %b
  %f = and i1 %c, %d
  %initial = and i1 %e, %f
  store i1 false, ptr @test.inject
  store i64 97, ptr @test.input
  store i64 1, ptr %kind.ptr
  %upper = getelementptr i64, ptr @test.destination, i64 1
  store i64 4100, ptr %upper
  %recovered = call i1 $recovery
  %recovery.count = load i64, ptr @test.count
  %recovery.count.ok = icmp eq i64 %recovery.count, $recoveryCount
  %recovery.err = load i64, ptr @test.ctx
  %recovery.err.ok = icmp eq i64 %recovery.err, $expectedErr
  %recovery.failure = load i64, ptr @test.failure
  %recovery.failure.ok = icmp eq i64 %recovery.failure, 0
  %g = and i1 %recovered, %recovery.count.ok
  %h = and i1 %recovery.err.ok, %recovery.failure.ok
  %recovery.ok = and i1 %g, %h
$ownerCleanup
  %disposed = call i1 @ube.context.dispose(ptr @test.ctx)
  %live.ptr = getelementptr %ube.context, ptr @test.ctx, i32 0, i32 6
  %live = load i64, ptr %live.ptr
  %clean = icmp eq i64 %live, 0
  %released = and i1 %disposed, %clean
  %correct = and i1 %initial, %recovery.ok
  %all = and i1 %correct, %released
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
"@
    $main=$main.Replace('  %slot = getelementptr %ube.resource, ptr null, i64 0' + "`r`n" + '  %unused = ptrtoint ptr %slot to i64' + "`r`n",'').Replace('ptr %slot release','ptr %real.slot release')
    $path=Join-Path $artifacts ($mode+'.ll');Write-Text $path ($text+"`r`n"+$main)
    foreach($level in @('O0','O2')){
        $exe=Join-Path $artifacts ($mode+'-'+$level+'.exe');Build-Harness $path $exe $level
        $run=Invoke-BoundedProcess $exe @()
        Require ($run.ExitCode -eq 0) "Metadata/namespace fault $mode $level failed: $($run.Evidence)"
        Write-Output "PASS: $mode $level"
    }
}
Write-Output "PASS: $($cases.Count*2) metadata/namespace failure and recovery cases; evidence $artifacts"
