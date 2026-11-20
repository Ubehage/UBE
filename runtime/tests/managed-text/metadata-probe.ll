@ctx = global %ube.thread zeroinitializer
@program = global %ube.program zeroinitializer
@state = global %ube.managed.state zeroinitializer
@record = global %ube.managed.record zeroinitializer
@candidate = global %ube.managed.record zeroinitializer
@outer = global %ube.rootframe zeroinitializer
@inner = global %ube.rootframe zeroinitializer
@answer = global i64 77
@count = global i64 88
@bad.refs = constant %ube.managed.layout {i64 1,i64 1,ptr null,i64 0,ptr null,i64 0,ptr null}
@bad.arrays = constant %ube.managed.layout {i64 4,i64 0,ptr null,i64 1,ptr null,i64 0,ptr null}
@bad.owners = constant %ube.managed.layout {i64 1,i64 0,ptr null,i64 0,ptr null,i64 1,ptr null}
define i32 @main() {
entry:
 %program.slot = getelementptr %ube.thread, ptr @ctx, i32 0, i32 2
 store ptr @program, ptr %program.slot
 %state.slot = getelementptr %ube.program, ptr @program, i32 0, i32 14
 store ptr @state, ptr %state.slot
 %owner.slot = getelementptr %ube.managed.state, ptr @state, i32 0, i32 2
 store ptr @ctx, ptr %owner.slot
 %phase = getelementptr %ube.managed.state, ptr @state, i32 0, i32 4
 store i64 1, ptr %phase
 store ptr @record, ptr @state
 %identity = getelementptr %ube.managed.record, ptr @record, i32 0, i32 1
 store i64 101, ptr %identity
 %allocation.count = getelementptr %ube.managed.state, ptr @state, i32 0, i32 8
 %root.count = getelementptr %ube.managed.state, ptr @state, i32 0, i32 9
 store i64 1, ptr %allocation.count
 store i64 3, ptr %root.count
 %snapshot = getelementptr %ube.managed.state, ptr @state, i32 0, i32 10, i64 0
 store i64 101, ptr %snapshot
 store i64 91, ptr @ctx
 %counts = call i1 @ube.managed.snapshot.counts(ptr @ctx, ptr @answer, ptr @count)
 %ac = load i64, ptr @answer
 %rc = load i64, ptr @count
 %a = icmp eq i64 %ac, 1
 %b = icmp eq i64 %rc, 3
 %ab = and i1 %a, %b
 %first = and i1 %counts, %ab
 br i1 %first, label %allocation, label %fail
allocation:
 %at = call i1 @ube.managed.allocation.at(ptr @ctx, i64 0, ptr @answer)
 %id = load i64, ptr @answer
 %right = icmp eq i64 %id, 101
 %invalid = call i1 @ube.managed.allocation.at(ptr @ctx, i64 -1, ptr @answer)
 %unchanged = load i64, ptr @answer
 %same = icmp eq i64 %unchanged, 101
 %refused = xor i1 %invalid, true
 %c = and i1 %at, %right
 %d = and i1 %same, %refused
 %second = and i1 %c, %d
 br i1 %second, label %mark, label %fail
mark:
 store i64 91, ptr @ctx
 %marked = call i1 @ube.managed.mark(ptr @ctx, i64 101, ptr @answer)
 %fresh = load i64, ptr @answer
 %yes = icmp eq i64 %fresh, -1
 %again = call i1 @ube.managed.mark(ptr @ctx, i64 101, ptr @answer)
 %repeat = load i64, ptr @answer
 %no = icmp eq i64 %repeat, 0
 %error = load i64, ptr @ctx
 %sticky = icmp eq i64 %error, 91
 %e = and i1 %marked, %yes
 %f = and i1 %again, %no
 %ef = and i1 %e, %f
 %third = and i1 %ef, %sticky
 br i1 %third, label %invalid.mark, label %fail
invalid.mark:
 store i64 77, ptr @answer
 %unknown = call i1 @ube.managed.mark(ptr @ctx, i64 202, ptr @answer)
 %old = load i64, ptr @answer
 %old.ok = icmp eq i64 %old, 77
 %unknown.no = xor i1 %unknown, true
 %bad = load i64, ptr @ctx
 %bad.ok = icmp eq i64 %bad, 5
 %g = and i1 %old.ok, %unknown.no
 %fourth = and i1 %g, %bad.ok
 br i1 %fourth, label %seal, label %fail
seal:
 %sealed = call i1 @ube.managed.seal(ptr @ctx)
 %too.late = call i1 @ube.managed.mark(ptr @ctx, i64 101, ptr @answer)
 %late.no = xor i1 %too.late, true
 %read = call i1 @ube.managed.marked(ptr @ctx, i64 101, ptr @answer)
 %is.marked = load i64, ptr @answer
 %read.ok = icmp eq i64 %is.marked, -1
 %h = and i1 %sealed, %late.no
 %i = and i1 %read, %read.ok
 %fifth = and i1 %h, %i
 br i1 %fifth, label %frames, label %fail
frames:
 call void @ube.managed.root.push(ptr @ctx, ptr @outer, ptr null, ptr null, i64 0)
 call void @ube.managed.root.push(ptr @ctx, ptr @inner, ptr null, ptr null, i64 0)
 %head = getelementptr %ube.thread, ptr @ctx, i32 0, i32 4
 %current = load ptr, ptr %head
 %inner.ok = icmp eq ptr %current, @inner
 %roots = getelementptr %ube.thread, ptr @ctx, i32 0, i32 5
 store ptr @candidate, ptr %roots
 %frame.owner = getelementptr %ube.managed.record, ptr @candidate, i32 0, i32 3
 store ptr @inner, ptr %frame.owner
 call void @ube.managed.root.pop(ptr @ctx, ptr @inner)
 %after = load ptr, ptr %head
 %outer.ok = icmp eq ptr %after, @outer
 %remaining = load ptr, ptr %roots
 %cleared = icmp eq ptr %remaining, null
 %owner = load ptr, ptr %frame.owner
 %abandoned = icmp eq ptr %owner, null
 call void @ube.managed.root.pop(ptr @ctx, ptr @outer)
 %last = load ptr, ptr %head
 %empty = icmp eq ptr %last, null
 %j = and i1 %inner.ok, %outer.ok
 %k = and i1 %cleared, %abandoned
 %jk = and i1 %j, %k
 %sixth = and i1 %jk, %empty
 br i1 %sixth, label %publication, label %fail
publication:
 store i64 101, ptr @answer
 %loaded = call i64 @ube.managed.load(ptr @ctx, ptr @answer, ptr @count)
 %rooted = load i64, ptr @count
 %loaded.ok = icmp eq i64 %loaded, 101
 %rooted.ok = icmp eq i64 %rooted, 101
 call void @ube.managed.return(ptr @ctx, i64 101)
 %taken = call i64 @ube.managed.take(ptr @ctx, ptr @answer)
 %handoff = getelementptr %ube.thread, ptr @ctx, i32 0, i32 8
 %consumed = load i64, ptr %handoff
 %taken.ok = icmp eq i64 %taken, 101
 %consumed.ok = icmp eq i64 %consumed, 0
 call void @ube.managed.return(ptr @ctx, i64 202)
 call void @ube.managed.discard(ptr @ctx)
 %discarded = load i64, ptr %handoff
 %discarded.ok = icmp eq i64 %discarded, 0
 %l = and i1 %loaded.ok, %rooted.ok
 %m = and i1 %taken.ok, %consumed.ok
 %lm = and i1 %l, %m
 %seventh = and i1 %lm, %discarded.ok
 br i1 %seventh, label %registration, label %fail
registration:
 call void @ube.managed.thread.register(ptr @ctx, i64 2)
 %registered.head = getelementptr %ube.program, ptr @program, i32 0, i32 15
 %registered = load ptr, ptr %registered.head
 %registered.ok = icmp eq ptr %registered, @ctx
 %status = getelementptr %ube.thread, ptr @ctx, i32 0, i32 7
 %safe = load i64, ptr %status
 %safe.ok = icmp eq i64 %safe, 2
 call void @ube.managed.enter(ptr @ctx)
 %running = load i64, ptr %status
 %running.ok = icmp eq i64 %running, 0
 call void @ube.managed.thread.unregister(ptr @ctx)
 %unregistered = load ptr, ptr %registered.head
 %unregistered.ok = icmp eq ptr %unregistered, null
 %n = and i1 %registered.ok, %safe.ok
 %o = and i1 %running.ok, %unregistered.ok
 %eighth = and i1 %n, %o
 br i1 %eighth, label %text, label %fail
text:
 %refs.result = call {i1,i64} @ube.managed.layout.visit(ptr @ctx, ptr @answer, ptr @bad.refs, i64 1, i64 -1, i64 0)
 %arrays.result = call {i1,i64} @ube.managed.layout.visit(ptr @ctx, ptr @answer, ptr @bad.arrays, i64 1, i64 -1, i64 0)
 %owners.result = call {i1,i64} @ube.managed.layout.visit(ptr @ctx, ptr @answer, ptr @bad.owners, i64 1, i64 -1, i64 0)
 %refs.count = extractvalue {i1,i64} %refs.result, 1
 %arrays.count = extractvalue {i1,i64} %arrays.result, 1
 %owners.count = extractvalue {i1,i64} %owners.result, 1
 %refs.rejected = icmp eq i64 %refs.count, -1
 %arrays.rejected = icmp eq i64 %arrays.count, -1
 %owners.rejected = icmp eq i64 %owners.count, -1
 %lists.rejected = and i1 %refs.rejected, %arrays.rejected
 %invalid.rejected = and i1 %lists.rejected, %owners.rejected
 br i1 %invalid.rejected, label %text.lifecycle, label %fail
text.lifecycle:
 %text.ok = call i1 @probe.text()
 %exit = select i1 %text.ok, i32 0, i32 1
 ret i32 %exit
fail:
 ret i32 1
}
@text.ctx = global %ube.context zeroinitializer
@text.frame = global %ube.rootframe zeroinitializer
@text.slot = global i64 0
@text.candidate = global i64 77
@text.garbage = global i64 88
@text.byte = global i64 99
@text.work = global i64 0
@text.error = global i64 0
@text.allocations = global i64 0
@text.roots = global i64 0
@text.fresh = global i64 0
@text.offset = constant [1 x i64] [i64 0]
@text.layout = constant %ube.managed.layout {i64 1,i64 1,ptr @text.offset,i64 0,ptr null,i64 0,ptr null}
define {i1,i64} @probe.collector(ptr %ctx, i64 %report) {
entry:
 ret {i1,i64} {i1 true,i64 0}
}
define i1 @probe.text() {
entry:
 call void @ube.context.init(ptr @text.ctx)
 %installed = call i1 @ube.managed.install(ptr @text.ctx, ptr @probe.collector)
 br i1 %installed, label %frame, label %fail
frame:
 call void @ube.managed.globals(ptr @text.ctx, ptr null)
 call void @ube.managed.root.push(ptr @text.ctx, ptr @text.frame, ptr @text.slot, ptr @text.layout, i64 1)
 %created = call i1 @ube.text.create(ptr @text.ctx, i64 3, i64 3, ptr @text.candidate)
 br i1 %created, label %write, label %fail
write:
 %identity = load i64, ptr @text.candidate
 %w0 = call i1 @ube.text.write(ptr @text.ctx, i64 %identity, i64 0, i64 65)
 %w1 = call i1 @ube.text.write(ptr @text.ctx, i64 %identity, i64 1, i64 0)
 %w2 = call i1 @ube.text.write(ptr @text.ctx, i64 %identity, i64 2, i64 66)
 %published = call i1 @ube.text.publish(ptr @text.ctx, ptr @text.slot, i64 %identity)
 %wa = and i1 %w0, %w1
 %wb = and i1 %w2, %published
 %writes = and i1 %wa, %wb
 br i1 %writes, label %observe, label %fail
observe:
 %length = call {i1,i64} @ube.text.length(ptr @text.ctx, ptr @text.slot, i1 false)
 %length.ok = extractvalue {i1,i64} %length, 0
 %bytes = extractvalue {i1,i64} %length, 1
 %bytes.ok = icmp eq i64 %bytes, 3
 %scalars.result = call {i1,i64} @ube.text.length(ptr @text.ctx, ptr @text.slot, i1 true)
 %scalars = extractvalue {i1,i64} %scalars.result, 1
 %scalars.ok = icmp eq i64 %scalars, 3
 %read = call i1 @ube.text.read(ptr @text.ctx, ptr @text.slot, i64 1, ptr @text.byte)
 %byte = load i64, ptr @text.byte
 %zero = icmp eq i64 %byte, 0
 %a = and i1 %length.ok, %bytes.ok
 %b = and i1 %scalars.ok, %read
 %ab = and i1 %a, %b
 %observed = and i1 %ab, %zero
 br i1 %observed, label %invalid, label %fail
invalid:
 store i64 77, ptr @text.byte
 %bad.read = call i1 @ube.text.read(ptr @text.ctx, ptr @text.slot, i64 3, ptr @text.byte)
 %unchanged = load i64, ptr @text.byte
 %unchanged.ok = icmp eq i64 %unchanged, 77
 %read.refused = xor i1 %bad.read, true
 %bad.write = call i1 @ube.text.write(ptr @text.ctx, i64 %identity, i64 0, i64 42)
 %write.refused = xor i1 %bad.write, true
 %bad = and i1 %read.refused, %write.refused
 %refused = and i1 %bad, %unchanged.ok
 br i1 %refused, label %garbage, label %fail
garbage:
 %another = call i1 @ube.text.create(ptr @text.ctx, i64 1, i64 1, ptr @text.garbage)
 %garbage.id = load i64, ptr @text.garbage
 %abandoned = call i1 @ube.text.abandon(ptr @text.ctx, i64 %garbage.id)
 %garbage.ok = and i1 %another, %abandoned
 br i1 %garbage.ok, label %begin, label %fail
begin:
 %owned = call i1 @ube.managed.begin(ptr @text.ctx, ptr @text.work, ptr @text.error)
 %counts = call i1 @ube.managed.snapshot.counts(ptr @text.ctx, ptr @text.allocations, ptr @text.roots)
 %allocations = load i64, ptr @text.allocations
 %roots = load i64, ptr @text.roots
 %allocations.ok = icmp eq i64 %allocations, 2
 %roots.ok = icmp eq i64 %roots, 2
 %c = and i1 %owned, %counts
 %d = and i1 %allocations.ok, %roots.ok
 %snapshot.ok = and i1 %c, %d
 br i1 %snapshot.ok, label %trace, label %fail
trace:
 %root = call i1 @ube.managed.root.at(ptr @text.ctx, i64 1, ptr @text.byte)
 %root.id = load i64, ptr @text.byte
 %root.ok = icmp eq i64 %root.id, %identity
 %marked = call i1 @ube.managed.mark(ptr @text.ctx, i64 %root.id, ptr @text.fresh)
 %fresh = load i64, ptr @text.fresh
 %fresh.ok = icmp eq i64 %fresh, -1
 %edges = call i1 @ube.managed.edge.count(ptr @text.ctx, i64 %root.id, ptr @text.byte)
 %edge.count = load i64, ptr @text.byte
 %edges.zero = icmp eq i64 %edge.count, 0
 %e = and i1 %root, %root.ok
 %f = and i1 %marked, %fresh.ok
 %g = and i1 %edges, %edges.zero
 %ef = and i1 %e, %f
 %trace.ok = and i1 %ef, %g
 br i1 %trace.ok, label %sweep, label %fail
sweep:
 %sealed = call i1 @ube.managed.seal(ptr @text.ctx)
 %marked.release = call i1 @ube.managed.reclaim(ptr @text.ctx, i64 %identity)
 %marked.retained = xor i1 %marked.release, true
 %released = call i1 @ube.managed.reclaim(ptr @text.ctx, i64 %garbage.id)
 %ended = call i1 @ube.managed.end(ptr @text.ctx, i64 1, i64 0)
 %h = and i1 %sealed, %marked.retained
 %i = and i1 %released, %ended
 %swept = and i1 %h, %i
 br i1 %swept, label %survivor, label %fail
survivor:
 %still.read = call i1 @ube.text.read(ptr @text.ctx, ptr @text.slot, i64 2, ptr @text.byte)
 %last.byte = load i64, ptr @text.byte
 %last.ok = icmp eq i64 %last.byte, 66
 %alive = and i1 %still.read, %last.ok
 br i1 %alive, label %final.collect, label %fail
final.collect:
 call void @ube.managed.root.pop(ptr @text.ctx, ptr @text.frame)
 %owned.again = call i1 @ube.managed.begin(ptr @text.ctx, ptr @text.work, ptr @text.error)
 %sealed.again = call i1 @ube.managed.seal(ptr @text.ctx)
 %last.release = call i1 @ube.managed.reclaim(ptr @text.ctx, i64 %identity)
 %ended.again = call i1 @ube.managed.end(ptr @text.ctx, i64 1, i64 0)
 %j = and i1 %owned.again, %sealed.again
 %k = and i1 %last.release, %ended.again
 %last.released = and i1 %j, %k
 br i1 %last.released, label %cleanup, label %fail
cleanup:
 %shutdown = call i1 @ube.managed.shutdown(ptr @text.ctx)
 %again = call i1 @ube.managed.shutdown(ptr @text.ctx)
 %native.released = call i1 @ube.memory.collect(ptr @text.ctx)
 %count.ptr = call ptr @ube.memory.count(ptr @text.ctx)
 %remaining = load i64, ptr %count.ptr
 %empty = icmp eq i64 %remaining, 0
 %retired = and i1 %native.released, %empty
 %shutdown.ok = and i1 %shutdown, %again
 %clean = and i1 %retired, %shutdown.ok
 ret i1 %clean
fail:
 ret i1 false
}
