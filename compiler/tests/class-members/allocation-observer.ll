; Fault only target allocations during the second and third object constructions.
; Real managed construction, retry, collection, publication and retirement remain intact.
@class.fault.active = private global i1 false
@class.fault.calls = private global i64 0
@class.fault.misses = private global i64 0
@class.fault.bad = private global i1 false
@class.fault.ids = private global [2 x i64] zeroinitializer
@class.fault.created = private global i64 0
@class.fault.observed = private global i64 0

define ptr @ube.target.allocate(i64 %bytes) {
entry:
  %active = load i1, ptr @class.fault.active
  br i1 %active, label %fail, label %ordinary
fail:
  %old = load i64, ptr @class.fault.misses
  %next = add i64 %old, 1
  store i64 %next, ptr @class.fault.misses
  ret ptr null
ordinary:
  %result = call ptr @class.actual.allocate(i64 %bytes)
  ret ptr %result
}

define i1 @ube.object.create(ptr %ctx, ptr %descriptor, ptr %layout, i64 %bytes, ptr %cleanup, ptr %output) {
entry:
  %index = load i64, ptr @class.fault.calls
  %next = add i64 %index, 1
  store i64 %next, ptr @class.fault.calls
  %second = icmp eq i64 %index, 1
  %third = icmp eq i64 %index, 2
  %fault = or i1 %second, %third
  %candidate.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 5
  %before = load ptr, ptr %candidate.ptr
  %old.output = load i64, ptr %output
  %old.misses = load i64, ptr @class.fault.misses
  store i1 %fault, ptr @class.fault.active
  %result = call i1 @class.actual.create(ptr %ctx, ptr %descriptor, ptr %layout, i64 %bytes, ptr %cleanup, ptr %output)
  store i1 false, ptr @class.fault.active
  br i1 %fault, label %check.failure, label %check.success
check.failure:
  %after = load ptr, ptr %candidate.ptr
  %candidate.ok = icmp eq ptr %before, %after
  %new.output = load i64, ptr %output
  %output.ok = icmp eq i64 %old.output, %new.output
  %error = load atomic i64, ptr %ctx monotonic, align 8
  %error.ok = icmp eq i64 %error, 7
  %failed = xor i1 %result, true
  %misses = load i64, ptr @class.fault.misses
  %difference = sub i64 %misses, %old.misses
  %retried = icmp uge i64 %difference, 2
  %nonempty = icmp ugt i64 %bytes, 0
  %a = and i1 %candidate.ok, %output.ok
  %b = and i1 %error.ok, %failed
  %c = and i1 %retried, %nonempty
  %d = and i1 %a, %b
  %ok = and i1 %d, %c
  br i1 %ok, label %done, label %bad
check.success:
  %count = load i64, ptr @class.fault.created
  %bounded = icmp ult i64 %count, 2
  %valid = and i1 %result, %bounded
  br i1 %valid, label %remember, label %bad
remember:
  %id = load i64, ptr %output
  %slot = getelementptr [2 x i64], ptr @class.fault.ids, i64 0, i64 %count
  store i64 %id, ptr %slot
  %created = add i64 %count, 1
  store i64 %created, ptr @class.fault.created
  br label %done
bad:
  store i1 true, ptr @class.fault.bad
  br label %done
done:
  ret i1 %result
}

define {i1,i64} @class.fault.observe(ptr %ctx) {
entry:
  %old = load i64, ptr @class.fault.observed
  %next = add i64 %old, 1
  store i64 %next, ptr @class.fault.observed
  %id0 = load i64, ptr @class.fault.ids
  %slot1 = getelementptr [2 x i64], ptr @class.fault.ids, i64 0, i64 1
  %id1 = load i64, ptr %slot1
  %state = call ptr @ube.managed.state(ptr %ctx)
  %r0 = call ptr @ube.managed.find(ptr %state, i64 %id0)
  %r1 = call ptr @ube.managed.find(ptr %state, i64 %id1)
  %p0 = icmp ne ptr %r0, null
  %p1 = icmp ne ptr %r1, null
  %low = zext i1 %p0 to i64
  %high = select i1 %p1, i64 2, i64 0
  %mask = or i64 %low, %high
  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %mask, 1
  ret {i1,i64} %result
}

define i32 @main() {
entry:
  %source = call i32 @class.source.main()
  %calls = load i64, ptr @class.fault.calls
  %calls.ok = icmp eq i64 %calls, 4
  %created = load i64, ptr @class.fault.created
  %created.ok = icmp eq i64 %created, 2
  %observed = load i64, ptr @class.fault.observed
  %observed.ok = icmp eq i64 %observed, 2
  %bad = load i1, ptr @class.fault.bad
  %good = xor i1 %bad, true
  %a = and i1 %calls.ok, %created.ok
  %b = and i1 %observed.ok, %good
  %ok = and i1 %a, %b
  %result = select i1 %ok, i32 %source, i32 99
  ret i32 %result
}
