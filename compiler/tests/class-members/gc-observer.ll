; Raw identities here are deliberately not registered as managed roots.
@class.observer.ids = private global [5 x i64] zeroinitializer
@class.observer.created = private global i64 0
@class.observer.calls = private global i64 0
@class.observer.bad = private global i1 false

define i1 @ube.object.create(ptr %ctx, ptr %descriptor, ptr %layout, i64 %bytes, ptr %cleanup, ptr %output) {
entry:
  %result = call i1 @class.actual.create(ptr %ctx, ptr %descriptor, ptr %layout, i64 %bytes, ptr %cleanup, ptr %output)
  br i1 %result, label %remember, label %done
remember:
  %count = load i64, ptr @class.observer.created
  %bounded = icmp ult i64 %count, 5
  br i1 %bounded, label %keep, label %bad
keep:
  %id = load i64, ptr %output
  %slot = getelementptr [5 x i64], ptr @class.observer.ids, i64 0, i64 %count
  store i64 %id, ptr %slot
  %next = add i64 %count, 1
  store i64 %next, ptr @class.observer.created
  br label %done
bad:
  store i1 true, ptr @class.observer.bad
  br label %done
done:
  ret i1 %result
}

define i64 @class.observer.present(ptr %ctx, i64 %index) {
entry:
  %slot = getelementptr [5 x i64], ptr @class.observer.ids, i64 0, i64 %index
  %id = load i64, ptr %slot
  %state = call ptr @ube.managed.state(ptr %ctx)
  %record = call ptr @ube.managed.find(ptr %state, i64 %id)
  %found = icmp ne ptr %record, null
  %value = zext i1 %found to i64
  ret i64 %value
}

define { i1, i64 } @class.observer.observe(ptr %ctx) {
entry:
  %phase = load i64, ptr @class.observer.calls
  %next = add i64 %phase, 1
  store i64 %next, ptr @class.observer.calls
  switch i64 %phase, label %bad [i64 0, label %cycle i64 1, label %cycle i64 2, label %identity i64 3, label %numeric i64 4, label %numeric i64 5, label %held i64 6, label %held]
cycle:
  %first = call i64 @class.observer.present(ptr %ctx, i64 0)
  %second = call i64 @class.observer.present(ptr %ctx, i64 1)
  %high = mul i64 %second, 2
  %mask = or i64 %first, %high
  br label %done
identity:
  %raw.slot = getelementptr [5 x i64], ptr @class.observer.ids, i64 0, i64 3
  %raw = load i64, ptr %raw.slot
  br label %done
numeric:
  %owner = call i64 @class.observer.present(ptr %ctx, i64 2)
  %victim = call i64 @class.observer.present(ptr %ctx, i64 3)
  %victim.bit = mul i64 %victim, 2
  %numeric.mask = or i64 %owner, %victim.bit
  br label %done
held:
  %held.alive = call i64 @class.observer.present(ptr %ctx, i64 4)
  br label %done
bad:
  store i1 true, ptr @class.observer.bad
  br label %done
done:
  %value = phi i64 [%mask, %cycle], [%raw, %identity], [%numeric.mask, %numeric], [%held.alive, %held], [-1, %bad]
  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %value, 1
  ret {i1,i64} %result
}

define i32 @main() {
entry:
  %source = call i32 @class.source.main()
  %source.ok = icmp eq i32 %source, 0
  %bad = load i1, ptr @class.observer.bad
  %good = xor i1 %bad, true
  %calls = load i64, ptr @class.observer.calls
  %calls.ok = icmp eq i64 %calls, 7
  %created = load i64, ptr @class.observer.created
  %created.ok = icmp eq i64 %created, 5
  %a = and i1 %source.ok, %good
  %b = and i1 %calls.ok, %created.ok
  %ok = and i1 %a, %b
  %status = select i1 %ok, i32 0, i32 99
  ret i32 %status
}
