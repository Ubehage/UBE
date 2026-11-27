; Observes real source-created object identities and real monitor outcomes without replacing them.
@oracle.identities = global [6 x i64] zeroinitializer
@oracle.acquires = global [6 x i64] zeroinitializer
@oracle.releases = global [6 x i64] zeroinitializer
@oracle.busy = global [6 x i64] zeroinitializer
@oracle.created = global i64 0
@oracle.main.ctx = global ptr null
@oracle.failed = global i64 0

define i64 @oracle.index(i64 %identity) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %missing, label %scan
scan:
  %index = phi i64 [0, %entry], [%next, %advance]
  %slot = getelementptr [6 x i64], ptr @oracle.identities, i64 0, i64 %index
  %candidate = load atomic i64, ptr %slot acquire, align 8
  %same = icmp eq i64 %candidate, %identity
  br i1 %same, label %found, label %advance
advance:
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, 6
  br i1 %more, label %scan, label %missing
found:
  ret i64 %index
missing:
  ret i64 -1
}

define i1 @ube.object.create(ptr %ctx, ptr %descriptor, ptr %layout, i64 %bytes, ptr %cleanup, ptr %output) {
entry:
  %result = call i1 @oracle.object.create(ptr %ctx, ptr %descriptor, ptr %layout, i64 %bytes, ptr %cleanup, ptr %output)
  br i1 %result, label %record, label %done
record:
  %index = atomicrmw add ptr @oracle.created, i64 1 seq_cst
  %tracked = icmp ult i64 %index, 6
  br i1 %tracked, label %remember, label %done
remember:
  %identity = load i64, ptr %output, align 8
  %slot = getelementptr [6 x i64], ptr @oracle.identities, i64 0, i64 %index
  store atomic i64 %identity, ptr %slot release, align 8
  %first = icmp eq i64 %index, 0
  br i1 %first, label %owner, label %done
owner:
  store atomic ptr %ctx, ptr @oracle.main.ctx release, align 8
  br label %done
done:
  ret i1 %result
}

define {i1,i64} @ube.monitor.tryenter(ptr %ctx, i64 %identity) {
entry:
  %result = call {i1,i64} @oracle.monitor.tryenter(ptr %ctx, i64 %identity)
  %success = extractvalue {i1,i64} %result, 0
  br i1 %success, label %identify, label %done
identify:
  %index = call i64 @oracle.index(i64 %identity)
  %tracked = icmp sge i64 %index, 0
  br i1 %tracked, label %observe, label %done
observe:
  %value = extractvalue {i1,i64} %result, 1
  %acquired = icmp ne i64 %value, 0
  %main.ctx = load atomic ptr, ptr @oracle.main.ctx acquire, align 8
  %main = icmp eq ptr %ctx, %main.ctx
  br i1 %main, label %main.result, label %worker.result
main.result:
  br i1 %acquired, label %count, label %done
count:
  %counter = getelementptr [6 x i64], ptr @oracle.acquires, i64 0, i64 %index
  %prior = atomicrmw add ptr %counter, i64 1 seq_cst
  %shared = icmp eq i64 %index, 4
  %inside.handler = icmp eq i64 %prior, 6
  %failed.headers = icmp eq i64 %prior, 7
  %fresh.waiter = or i1 %inside.handler, %failed.headers
  %reset.waiter = and i1 %shared, %fresh.waiter
  br i1 %reset.waiter, label %reset.busy, label %done
reset.busy:
  %busy.slot = getelementptr [6 x i64], ptr @oracle.busy, i64 0, i64 %index
  store atomic i64 0, ptr %busy.slot release, align 8
  br label %done
worker.result:
  br i1 %acquired, label %done, label %busy
busy:
  %flag = getelementptr [6 x i64], ptr @oracle.busy, i64 0, i64 %index
  store atomic i64 1, ptr %flag release, align 8
  br label %done
done:
  ret {i1,i64} %result
}

; This bounded handshake requires an observed busy result from the actual worker.
; Sleep merely gives the worker CPU; elapsed time never establishes ownership.
define i1 @oracle.await.busy(ptr %ctx, i64 %index) {
entry:
  %slot = getelementptr [6 x i64], ptr @oracle.busy, i64 0, i64 %index
  br label %check
check:
  %remaining = phi i64 [5000, %entry], [%next, %wait]
  %busy = load atomic i64, ptr %slot acquire, align 8
  %observed = icmp eq i64 %busy, 1
  br i1 %observed, label %done, label %timeout
timeout:
  %expired = icmp eq i64 %remaining, 0
  br i1 %expired, label %failed, label %wait
wait:
  %yielded = call i1 @ube.monitor.yield(ptr %ctx)
  %next = sub i64 %remaining, 1
  br label %check
done:
  ret i1 true
failed:
  ret i1 false
}

define i1 @oracle.retire.valid(ptr %ctx, i64 %identity, i64 %index, i64 %ordinal) {
entry:
  %initial = icmp eq i64 %ordinal, 0
  %outer = icmp eq i64 %index, 0
  %inner = icmp eq i64 %index, 1
  %reentrant = icmp eq i64 %index, 3
  %shared = icmp eq i64 %index, 4
  %recursive = icmp eq i64 %index, 5
  %handler.ordinal = icmp eq i64 %ordinal, 6
  %handler = and i1 %shared, %handler.ordinal
  %header.ordinal = icmp eq i64 %ordinal, 7
  %header = and i1 %shared, %header.ordinal
  %shared.wait = or i1 %handler, %header
  %loop.monitor = or i1 %outer, %inner
  %nested.monitor = or i1 %reentrant, %recursive
  %wait.monitor = or i1 %loop.monitor, %nested.monitor
  %first.wait = and i1 %initial, %wait.monitor
  %needs.wait = or i1 %first.wait, %shared.wait
  br i1 %needs.wait, label %wait, label %inspect
wait:
  %busy = call i1 @oracle.await.busy(ptr %ctx, i64 %index)
  br i1 %busy, label %inspect, label %failed
inspect:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %present = icmp ne ptr %record, null
  br i1 %present, label %depth, label %failed
depth:
  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %fields = load ptr, ptr %data.ptr, align 8
  %depth.ptr = getelementptr i8, ptr %fields, i64 -8
  %actual.depth = load i64, ptr %depth.ptr, align 8
  %nested = and i1 %reentrant, %initial
  %ordinary.depth = select i1 %nested, i64 2, i64 1
  %previous.ordinal = sub i64 %ordinal, 1
  %completed.frames = udiv i64 %previous.ordinal, 2
  %frame.depth = sub i64 4, %completed.frames
  %initial.depth = select i1 %initial, i64 5, i64 %frame.depth
  %last.recursive = icmp eq i64 %ordinal, 6
  %recursive.depth = select i1 %last.recursive, i64 1, i64 %initial.depth
  %expected.depth = select i1 %recursive, i64 %recursive.depth, i64 %ordinary.depth
  %depth.ok = icmp eq i64 %actual.depth, %expected.depth
  br i1 %depth.ok, label %placement, label %failed
placement:
  br i1 %outer, label %outer.placement, label %markers
outer.placement:
  %inner.acquires.ptr = getelementptr [6 x i64], ptr @oracle.acquires, i64 0, i64 1
  %inner.releases.ptr = getelementptr [6 x i64], ptr @oracle.releases, i64 0, i64 1
  %inner.acquires = load atomic i64, ptr %inner.acquires.ptr acquire, align 8
  %inner.releases = load atomic i64, ptr %inner.releases.ptr acquire, align 8
  %acquires.ok = icmp eq i64 %inner.acquires, 2
  %releases.ok = icmp eq i64 %inner.releases, 2
  %placement.ok = and i1 %acquires.ok, %releases.ok
  br i1 %placement.ok, label %markers, label %failed
markers:
  %second = icmp eq i64 %ordinal, 1
  %reentrant.outer = and i1 %reentrant, %second
  %recursive.outer = and i1 %recursive, %last.recursive
  %ordinary.marked = or i1 %reentrant.outer, %shared.wait
  %marked = or i1 %ordinary.marked, %recursive.outer
  br i1 %marked, label %check.marker, label %done
check.marker:
  %ordinary.error = select i1 %handler, i64 74, i64 73
  %shared.error = select i1 %header, i64 76, i64 %ordinary.error
  %expected.error = select i1 %recursive.outer, i64 75, i64 %shared.error
  %actual.error = load atomic i64, ptr %ctx monotonic, align 8
  %marker.ok = icmp eq i64 %actual.error, %expected.error
  br i1 %marker.ok, label %done, label %failed
done:
  ret i1 true
failed:
  ret i1 false
}

define i1 @ube.monitor.retire(ptr %ctx, ptr %identity.slot, ptr %acquired.slot) {
entry:
  %held.value = load atomic i64, ptr %acquired.slot acquire, align 8
  %held = icmp eq i64 %held.value, 1
  %main.ctx = load atomic ptr, ptr @oracle.main.ctx acquire, align 8
  %main = icmp eq ptr %ctx, %main.ctx
  %observe = and i1 %held, %main
  br i1 %observe, label %identify, label %plain
identify:
  %identity = load atomic i64, ptr %identity.slot acquire, align 8
  %index = call i64 @oracle.index(i64 %identity)
  %tracked = icmp sge i64 %index, 0
  br i1 %tracked, label %check, label %plain
check:
  %counter = getelementptr [6 x i64], ptr @oracle.releases, i64 0, i64 %index
  %ordinal = load atomic i64, ptr %counter acquire, align 8
  %valid = call i1 @oracle.retire.valid(ptr %ctx, i64 %identity, i64 %index, i64 %ordinal)
  br i1 %valid, label %release, label %record.failure
record.failure:
  store atomic i64 1, ptr @oracle.failed release, align 8
  br label %release
release:
  %result = call i1 @oracle.monitor.retire(ptr %ctx, ptr %identity.slot, ptr %acquired.slot)
  br i1 %result, label %count, label %return
count:
  %prior = atomicrmw add ptr %counter, i64 1 seq_cst
  br label %return
return:
  ret i1 %result
plain:
  %plain.result = call i1 @oracle.monitor.retire(ptr %ctx, ptr %identity.slot, ptr %acquired.slot)
  ret i1 %plain.result
}

define i32 @main() {
entry:
  %source = call i32 @oracle.source.main()
  %failure = load atomic i64, ptr @oracle.failed acquire, align 8
  %source.ok = icmp eq i32 %source, 0
  %observations.ok = icmp eq i64 %failure, 0
  %outer.ptr = getelementptr [6 x i64], ptr @oracle.releases, i64 0, i64 0
  %inner.ptr = getelementptr [6 x i64], ptr @oracle.releases, i64 0, i64 1
  %reentrant.ptr = getelementptr [6 x i64], ptr @oracle.releases, i64 0, i64 3
  %shared.ptr = getelementptr [6 x i64], ptr @oracle.releases, i64 0, i64 4
  %recursive.ptr = getelementptr [6 x i64], ptr @oracle.releases, i64 0, i64 5
  %outer = load atomic i64, ptr %outer.ptr acquire, align 8
  %inner = load atomic i64, ptr %inner.ptr acquire, align 8
  %reentrant = load atomic i64, ptr %reentrant.ptr acquire, align 8
  %shared = load atomic i64, ptr %shared.ptr acquire, align 8
  %recursive = load atomic i64, ptr %recursive.ptr acquire, align 8
  %outer.ok = icmp eq i64 %outer, 1
  %inner.ok = icmp eq i64 %inner, 2
  %reentrant.ok = icmp eq i64 %reentrant, 2
  %shared.ok = icmp eq i64 %shared, 9
  %recursive.ok = icmp eq i64 %recursive, 7
  %a = and i1 %source.ok, %observations.ok
  %b = and i1 %outer.ok, %inner.ok
  %c = and i1 %reentrant.ok, %shared.ok
  %d = and i1 %a, %b
  %ordinary.ok = and i1 %c, %d
  %ok = and i1 %ordinary.ok, %recursive.ok
  %exit = select i1 %ok, i32 0, i32 99
  ret i32 %exit
}
