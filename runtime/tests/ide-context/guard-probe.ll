; Target API doubles exercise the actual extracted guard, not a replacement guard.
@case = global i32 0
@opens = global i32 0
@closes = global i32 0
@reports = global i32 0
@contract = global i1 true
@control = global i1 false
@name = private constant [47 x i16] [i16 76, i16 111, i16 99, i16 97, i16 108, i16 92, i16 85, i16 66, i16 69, i16 46, i16 73, i16 68, i16 69, i16 46, i16 48, i16 49, i16 50, i16 51, i16 52, i16 53, i16 54, i16 55, i16 56, i16 57, i16 97, i16 98, i16 99, i16 100, i16 101, i16 102, i16 48, i16 49, i16 50, i16 51, i16 52, i16 53, i16 54, i16 55, i16 56, i16 57, i16 97, i16 98, i16 99, i16 100, i16 101, i16 102, i16 0]
@message = private constant [112 x i8] c"UBE: E_IDE_CONTEXT: this IDE-run executable requires a live UBE IDE session; rebuild for standalone execution.\0D\0A"

define void @check(i1 %condition) {
  %old = load i1, ptr @contract
  %value = and i1 %old, %condition
  store i1 %value, ptr @contract
  ret void
}
define i32 @GetEnvironmentVariableW(ptr %variable, ptr %buffer, i32 %capacity) {
entry:
  %cap = icmp eq i32 %capacity, 47
  call void @check(i1 %cap)
  %mode = load i32, ptr @case
  %missing = icmp eq i32 %mode, 1
  %write.failure = icmp eq i32 %mode, 15
  %empty = or i1 %missing, %write.failure
  br i1 %empty, label %absent, label %copy
absent:
  ret i32 0
copy:
  %i = phi i64 [ 0, %entry ], [ %next, %copy ]
  %source = getelementptr i16, ptr @name, i64 %i
  %raw = load i16, ptr %source
  %upper.mode = icmp eq i32 %mode, 14
  %suffix = icmp uge i64 %i, 14
  %upper.suffix = and i1 %upper.mode, %suffix
  %is.lower = icmp uge i16 %raw, 97
  %to.upper = and i1 %upper.suffix, %is.lower
  %upper = sub i16 %raw, 32
  %character = select i1 %to.upper, i16 %upper, i16 %raw
  %target = getelementptr i16, ptr %buffer, i64 %i
  store i16 %character, ptr %target
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, 47
  br i1 %more, label %copy, label %alter
alter:
  %prefix = icmp eq i32 %mode, 4
  br i1 %prefix, label %bad.prefix, label %hex
bad.prefix:
  store i16 88, ptr %buffer
  br label %length
hex:
  %bad = icmp eq i32 %mode, 5
  br i1 %bad, label %bad.hex, label %length
bad.hex:
  %last = getelementptr i16, ptr %buffer, i64 45
  store i16 103, ptr %last
  br label %length
length:
  %short = icmp eq i32 %mode, 2
  %long = icmp eq i32 %mode, 3
  %length.1 = select i1 %short, i32 45, i32 46
  %length.2 = select i1 %long, i32 48, i32 %length.1
  ret i32 %length.2
}
define ptr @OpenJobObjectW(i32 %access, i32 %inherit, ptr %name) {
  %count = load i32, ptr @opens
  %next = add i32 %count, 1
  store i32 %next, ptr @opens
  %query = icmp eq i32 %access, 4
  %private = icmp eq i32 %inherit, 0
  %correct = and i1 %query, %private
  call void @check(i1 %correct)
  %mode = load i32, ptr @case
  %fail = icmp eq i32 %mode, 6
  %result = select i1 %fail, ptr null, ptr inttoptr (i64 42 to ptr)
  ret ptr %result
}
define ptr @GetCurrentProcess() {
  ret ptr inttoptr (i64 43 to ptr)
}
define i32 @IsProcessInJob(ptr %process, ptr %job, ptr %member) {
  %p = icmp eq ptr %process, inttoptr (i64 43 to ptr)
  %j = icmp eq ptr %job, inttoptr (i64 42 to ptr)
  %correct = and i1 %p, %j
  call void @check(i1 %correct)
  %mode = load i32, ptr @case
  %not.member = icmp eq i32 %mode, 8
  %value = select i1 %not.member, i32 0, i32 1
  store i32 %value, ptr %member
  %fail = icmp eq i32 %mode, 7
  %result = select i1 %fail, i32 0, i32 1
  ret i32 %result
}
define i32 @QueryInformationJobObject(ptr %job, i32 %class, ptr %buffer, i32 %size, ptr %returned) {
  %j = icmp eq ptr %job, inttoptr (i64 42 to ptr)
  %c = icmp eq i32 %class, 9
  %s = icmp eq i32 %size, 144
  %jc = and i1 %j, %c
  %correct = and i1 %jc, %s
  call void @check(i1 %correct)
  %mode = load i32, ptr @case
  %no.kill = icmp eq i32 %mode, 10
  %breakaway = icmp eq i32 %mode, 11
  %silent = icmp eq i32 %mode, 12
  %flags.1 = select i1 %no.kill, i32 0, i32 8192
  %flags.2 = select i1 %breakaway, i32 10240, i32 %flags.1
  %flags.3 = select i1 %silent, i32 12288, i32 %flags.2
  %address = getelementptr i8, ptr %buffer, i64 16
  store i32 %flags.3, ptr %address
  %fail = icmp eq i32 %mode, 9
  %result = select i1 %fail, i32 0, i32 1
  ret i32 %result
}
define i32 @CloseHandle(ptr %job) {
  %j = icmp eq ptr %job, inttoptr (i64 42 to ptr)
  call void @check(i1 %j)
  %count = load i32, ptr @closes
  %next = add i32 %count, 1
  store i32 %next, ptr @closes
  %mode = load i32, ptr @case
  %fail = icmp eq i32 %mode, 13
  %result = select i1 %fail, i32 0, i32 1
  ret i32 %result
}
define ptr @GetStdHandle(i32 %stream) {
  %correct = icmp eq i32 %stream, -12
  call void @check(i1 %correct)
  ret ptr inttoptr (i64 44 to ptr)
}
define i32 @WriteFile(ptr %handle, ptr %bytes, i32 %count, ptr %written, ptr %overlapped) {
entry:
  %h = icmp eq ptr %handle, inttoptr (i64 44 to ptr)
  %c = icmp eq i32 %count, 112
  %valid = and i1 %h, %c
  call void @check(i1 %valid)
  %old = load i32, ptr @reports
  %next.report = add i32 %old, 1
  store i32 %next.report, ptr @reports
  br i1 %c, label %compare, label %done
compare:
  %i = phi i64 [ 0, %entry ], [ %next, %compare ]
  %a = getelementptr i8, ptr %bytes, i64 %i
  %b = getelementptr i8, ptr @message, i64 %i
  %actual = load i8, ptr %a
  %expected = load i8, ptr %b
  %same = icmp eq i8 %actual, %expected
  call void @check(i1 %same)
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, 112
  br i1 %more, label %compare, label %done
done:
  store i32 112, ptr %written
  %mode = load i32, ptr @case
  %fail = icmp eq i32 %mode, 15
  %result = select i1 %fail, i32 0, i32 1
  ret i32 %result
}
define i32 @main() {
entry:
  br label %test
test:
  %mode = phi i32 [ 0, %entry ], [ %next, %continue ]
  store i32 %mode, ptr @case
  store i32 0, ptr @opens
  store i32 0, ptr @closes
  store i32 0, ptr @reports
  store i1 true, ptr @contract
  %answer = call i1 @ube.ide.session.check()
  %lower = icmp eq i32 %mode, 0
  %upper = icmp eq i32 %mode, 14
  %valid = or i1 %lower, %upper
  %control = load i1, ptr @control
  %expected = xor i1 %valid, %control
  %result.ok = icmp eq i1 %answer, %expected
  %first = icmp uge i32 %mode, 6
  %last = icmp ult i32 %mode, 15
  %later = and i1 %first, %last
  %opened = or i1 %lower, %later
  %expected.opens = zext i1 %opened to i32
  %open.failed = icmp eq i32 %mode, 6
  %not.failed = xor i1 %open.failed, true
  %closed = and i1 %opened, %not.failed
  %expected.closes = zext i1 %closed to i32
  %invalid = xor i1 %valid, true
  %expected.reports = zext i1 %invalid to i32
  %opens = load i32, ptr @opens
  %closes = load i32, ptr @closes
  %reports = load i32, ptr @reports
  %open.ok = icmp eq i32 %opens, %expected.opens
  %close.ok = icmp eq i32 %closes, %expected.closes
  %report.ok = icmp eq i32 %reports, %expected.reports
  %contract = load i1, ptr @contract
  %a = and i1 %result.ok, %open.ok
  %b = and i1 %close.ok, %report.ok
  %c = and i1 %a, %b
  %ok = and i1 %c, %contract
  br i1 %ok, label %continue, label %failed
continue:
  %next = add i32 %mode, 1
  %more = icmp ult i32 %next, 16
  br i1 %more, label %test, label %success
failed:
  %exit = add i32 %mode, 1
  ret i32 %exit
success:
  ret i32 0
}
