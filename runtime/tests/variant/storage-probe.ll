@variant.ctx = global %ube.context zeroinitializer
@variant.frame = global %ube.rootframe zeroinitializer
@variant.roots = global [4 x i64] zeroinitializer
@variant.offset = constant i64 0
@variant.layout = constant %ube.managed.layout {i64 1,i64 1,ptr @variant.offset,i64 0,ptr null,i64 0,ptr null}
@variant.candidate = global i64 0
@variant.allocate.fail = global i64 0
@variant.allocate.calls = global i64 0
@variant.release.fail = global i64 0
@variant.cleanup.calls = global i64 0
@variant.cleanup.allocated = global i1 false
@variant.array.layout = constant %ube.managed.layout {i64 4,i64 0,ptr null,i64 0,ptr null,i64 0,ptr null}
@variant.object.descriptor = constant i8 0

define i1 @variant.reference.shape(i64 %rank, i64 %cells) {
entry:
 %created = call i1 @ube.variant.create(ptr @variant.ctx, i64 9, i64 101, i64 %rank, i64 %cells, ptr null, ptr null, ptr @variant.candidate)
 br i1 %created, label %extract, label %failed
extract:
 %id = load i64, ptr @variant.candidate
 %reference = call {i1,i64} @ube.variant.reference(ptr @variant.ctx, i64 %id, i64 0)
 %success = extractvalue {i1,i64} %reference, 0
 %value = extractvalue {i1,i64} %reference, 1
 %refused = xor i1 %success, true
 %zero = icmp eq i64 %value, 0
 %error = load i64, ptr @variant.ctx
 %mismatch = icmp eq i64 %error, 13
 %abandoned = call i1 @ube.variant.abandon(ptr @variant.ctx, i64 %id)
 %a = and i1 %refused, %zero
 %b = and i1 %mismatch, %abandoned
 %result = and i1 %a, %b
 ret i1 %result
failed:
 ret i1 false
}

define i1 @variant.references() {
entry:
 %root1 = getelementptr [4 x i64], ptr @variant.roots, i64 0, i64 1
 %root2 = getelementptr [4 x i64], ptr @variant.roots, i64 0, i64 2
 %root3 = getelementptr [4 x i64], ptr @variant.roots, i64 0, i64 3
 store atomic i64 42, ptr @variant.ctx monotonic, align 8
 %empty = call {i1,i64} @ube.variant.reference(ptr @variant.ctx, i64 0, i64 101)
 %empty.ok = extractvalue {i1,i64} %empty, 0
 %empty.value = extractvalue {i1,i64} %empty, 1
 %empty.zero = icmp eq i64 %empty.value, 0
 %empty.error = load i64, ptr @variant.ctx
 %empty.sticky = icmp eq i64 %empty.error, 42
 %null.id = load i64, ptr %root1
 %null = call {i1,i64} @ube.variant.reference(ptr @variant.ctx, i64 %null.id, i64 0)
 %null.ok = extractvalue {i1,i64} %null, 0
 %null.value = extractvalue {i1,i64} %null, 1
 %null.failed = xor i1 %null.ok, true
 %null.zero = icmp eq i64 %null.value, 0
 %null.error = load i64, ptr @variant.ctx
 %null.mismatch = icmp eq i64 %null.error, 13
 %a = and i1 %empty.ok, %empty.zero
 %b = and i1 %empty.sticky, %null.failed
 %c = and i1 %null.zero, %null.mismatch
 %d = and i1 %a, %b
 %neutral = and i1 %d, %c
 br i1 %neutral, label %object, label %fail
object:
 %object.created = call i1 @ube.object.create(ptr @variant.ctx, ptr @variant.object.descriptor, ptr null, i64 0, ptr null, ptr %root1)
 br i1 %object.created, label %box, label %fail
box:
 %object.id = load i64, ptr %root1
 %object.record = call ptr @ube.managed.candidate(ptr @variant.ctx, i64 %object.id)
 call void @ube.managed.store(ptr @variant.ctx, ptr %root1, i64 %object.id)
 call void @ube.managed.unlink(ptr @variant.ctx, ptr %object.record)
 %box.created = call i1 @ube.variant.create(ptr @variant.ctx, i64 9, i64 101, i64 0, i64 1, ptr @variant.layout, ptr null, ptr @variant.candidate)
 br i1 %box.created, label %publish, label %fail
publish:
 %box.id = load i64, ptr @variant.candidate
 %box.data = call ptr @ube.variant.payload(ptr @variant.ctx, i64 %box.id)
 call void @ube.managed.store(ptr @variant.ctx, ptr %box.data, i64 %object.id)
 %box.published = call i1 @ube.variant.publish(ptr @variant.ctx, ptr %root2, i64 %box.id)
 call void @ube.managed.store(ptr @variant.ctx, ptr %root1, i64 0)
 %round = call {i1,i64} @ube.managed.collect(ptr @variant.ctx, i64 -1)
 %collected = extractvalue {i1,i64} %round, 0
 store atomic i64 42, ptr @variant.ctx monotonic, align 8
 %reference = call {i1,i64} @ube.variant.reference(ptr @variant.ctx, i64 %box.id, i64 101)
 %reference.ok = extractvalue {i1,i64} %reference, 0
 %reference.value = extractvalue {i1,i64} %reference, 1
 %reference.expected = icmp eq i64 %reference.value, %object.id
 %generic = call {i1,i64} @ube.variant.reference(ptr @variant.ctx, i64 %box.id, i64 0)
 %generic.ok = extractvalue {i1,i64} %generic, 0
 %generic.value = extractvalue {i1,i64} %generic, 1
 %generic.expected = icmp eq i64 %generic.value, %object.id
 %success.error = load i64, ptr @variant.ctx
 %success.sticky = icmp eq i64 %success.error, 42
 %address = call ptr @ube.object.address(ptr @variant.ctx, i64 %reference.value, ptr @variant.object.descriptor)
 %object.alive = icmp ne ptr %address, null
 %wrong.class = call {i1,i64} @ube.variant.reference(ptr @variant.ctx, i64 %box.id, i64 202)
 %wrong.ok = extractvalue {i1,i64} %wrong.class, 0
 %wrong.value = extractvalue {i1,i64} %wrong.class, 1
 %wrong.failed = xor i1 %wrong.ok, true
 %wrong.zero = icmp eq i64 %wrong.value, 0
 %wrong.error = load i64, ptr @variant.ctx
 %wrong.mismatch = icmp eq i64 %wrong.error, 13
 %e = and i1 %box.published, %collected
 %f = and i1 %reference.ok, %reference.expected
 %g = and i1 %generic.ok, %generic.expected
 %h = and i1 %success.sticky, %object.alive
 %i = and i1 %wrong.failed, %wrong.zero
 %j = and i1 %i, %wrong.mismatch
 %k = and i1 %e, %f
 %l = and i1 %g, %h
 %m = and i1 %k, %l
 %references = and i1 %m, %j
 br i1 %references, label %nothing, label %fail
nothing:
 %nothing.boxed = call i1 @ube.variant.box(ptr @variant.ctx, i64 9, i64 0, ptr @variant.layout, ptr %root3)
 %nothing.id = load i64, ptr %root3
 %nothing.result = call {i1,i64} @ube.variant.reference(ptr @variant.ctx, i64 %nothing.id, i64 202)
 %nothing.ok = extractvalue {i1,i64} %nothing.result, 0
 %nothing.value = extractvalue {i1,i64} %nothing.result, 1
 %nothing.zero = icmp eq i64 %nothing.value, 0
 %nothing.tag = call {i1,i64} @ube.variant.tag(ptr @variant.ctx, i64 %nothing.id)
 %nothing.tag.value = extractvalue {i1,i64} %nothing.tag, 1
 %nothing.distinct = icmp eq i64 %nothing.tag.value, 9
 %numeric.id = load i64, ptr @variant.roots
 %numeric = call {i1,i64} @ube.variant.reference(ptr @variant.ctx, i64 %numeric.id, i64 0)
 %numeric.ok = extractvalue {i1,i64} %numeric, 0
 %numeric.value = extractvalue {i1,i64} %numeric, 1
 %numeric.failed = xor i1 %numeric.ok, true
 %numeric.zero = icmp eq i64 %numeric.value, 0
 %n = and i1 %nothing.boxed, %nothing.ok
 %o = and i1 %nothing.zero, %nothing.distinct
 %p = and i1 %numeric.failed, %numeric.zero
 %q = and i1 %n, %o
 %rank.rejected = call i1 @variant.reference.shape(i64 1, i64 1)
 %cells.rejected = call i1 @variant.reference.shape(i64 0, i64 2)
 %shape = and i1 %rank.rejected, %cells.rejected
 %r = and i1 %q, %p
 %result = and i1 %r, %shape
 ret i1 %result
fail:
 ret i1 false
}

define ptr @ube.target.allocate(i64 %bytes) {
entry:
 %called = atomicrmw add ptr @variant.allocate.calls, i64 1 seq_cst
 %left = load i64, ptr @variant.allocate.fail
 %fail = icmp ne i64 %left, 0
 br i1 %fail, label %refuse, label %allocate
refuse:
 %less = sub i64 %left, 1
 store i64 %less, ptr @variant.allocate.fail
 ret ptr null
allocate:
 %block = call ptr @variant.target.allocate(i64 %bytes)
 ret ptr %block
}
define i1 @ube.target.release(ptr %block) {
entry:
 %left = load i64, ptr @variant.release.fail
 %fail = icmp ne i64 %left, 0
 br i1 %fail, label %refuse, label %release
refuse:
 store i64 0, ptr @variant.release.fail
 ret i1 false
release:
 %released = call i1 @variant.target.release(ptr %block)
 ret i1 %released
}
; Compiler-generated cleanup has no user callback, allocation or collection.
define void @variant.cleanup(ptr %ctx, ptr %payload) {
entry:
 %called = atomicrmw add ptr @variant.cleanup.calls, i64 1 seq_cst
 %before = load i64, ptr @variant.allocate.calls
 call void @ube.array.clear(ptr %ctx, ptr %payload)
 %after = load i64, ptr @variant.allocate.calls
 %allocated = icmp ne i64 %before, %after
 store i1 %allocated, ptr @variant.cleanup.allocated
 ret void
}
define i1 @variant.scalar.check(i64 %tag, i64 %raw) {
entry:
 %root = getelementptr [4 x i64], ptr @variant.roots, i64 0, i64 3
 %boxed = call i1 @ube.variant.box(ptr @variant.ctx, i64 %tag, i64 %raw, ptr null, ptr %root)
 %id = load i64, ptr %root
 %tag.result = call {i1,i64} @ube.variant.tag(ptr @variant.ctx, i64 %id)
 %tag.ok = extractvalue {i1,i64} %tag.result, 0
 %tag.value = extractvalue {i1,i64} %tag.result, 1
 %scalar = call {i1,i64} @ube.variant.scalar(ptr @variant.ctx, i64 %id)
 %scalar.ok = extractvalue {i1,i64} %scalar, 0
 %value = extractvalue {i1,i64} %scalar, 1
 %exact.tag = icmp eq i64 %tag.value, %tag
 %exact.value = icmp eq i64 %value, %raw
 %a = and i1 %boxed, %tag.ok
 %b = and i1 %scalar.ok, %exact.tag
 %c = and i1 %a, %b
 %ok = and i1 %c, %exact.value
 ret i1 %ok
}
define i32 @variantmain() {
entry:
 %tag.out = alloca i64
 %nominal.out = alloca i64
 %rank.out = alloca i64
 %cells.out = alloca i64
 call void @ube.context.init(ptr @variant.ctx)
 %started = call i1 @ube.project.init(ptr @variant.ctx)
 br i1 %started, label %root, label %fail
root:
 call void @ube.managed.root.push(ptr @variant.ctx, ptr @variant.frame, ptr @variant.roots, ptr @variant.layout, i64 4)
 %root1 = getelementptr [4 x i64], ptr @variant.roots, i64 0, i64 1
 %root2 = getelementptr [4 x i64], ptr @variant.roots, i64 0, i64 2
 %root3 = getelementptr [4 x i64], ptr @variant.roots, i64 0, i64 3
 %empty = call {i1,i64} @ube.variant.tag(ptr @variant.ctx, i64 0)
 %empty.ok = extractvalue {i1,i64} %empty, 0
 %empty.tag = extractvalue {i1,i64} %empty, 1
 %zero = icmp eq i64 %empty.tag, 0
 %a = and i1 %empty.ok, %zero
 br i1 %a, label %scalars, label %fail
scalars:
 %integer = call i1 @variant.scalar.check(i64 2, i64 -32768)
 %long = call i1 @variant.scalar.check(i64 3, i64 -2147483648)
 %single = call i1 @variant.scalar.check(i64 4, i64 1069547520)
 %double = call i1 @variant.scalar.check(i64 5, i64 4609434218613702656)
 %boolean = call i1 @variant.scalar.check(i64 11, i64 -1)
 %byte = call i1 @variant.scalar.check(i64 17, i64 255)
 %longlong = call i1 @variant.scalar.check(i64 20, i64 -9223372036854775808)
 %b = and i1 %integer, %long
 %c = and i1 %single, %double
 %d = and i1 %boolean, %byte
 %e = and i1 %b, %c
 %f = and i1 %d, %longlong
 %g = and i1 %e, %f
 br i1 %g, label %scalar, label %fail
scalar:
 store atomic i64 42, ptr @variant.ctx monotonic, align 8
 %boxed = call i1 @ube.variant.box(ptr @variant.ctx, i64 3, i64 -123, ptr null, ptr @variant.roots)
 %identity = load i64, ptr @variant.roots
 %scalar.result = call {i1,i64} @ube.variant.scalar(ptr @variant.ctx, i64 %identity)
 %scalar.ok = extractvalue {i1,i64} %scalar.result, 0
 %scalar.value = extractvalue {i1,i64} %scalar.result, 1
 %expected.scalar = icmp eq i64 %scalar.value, -123
 %error = load i64, ptr @variant.ctx
 %sticky = icmp eq i64 %error, 42
 %h = and i1 %boxed, %scalar.ok
 %i = and i1 %expected.scalar, %sticky
 %j = and i1 %h, %i
 br i1 %j, label %invalid, label %fail
invalid:
 store i64 99, ptr %tag.out
 store i64 98, ptr %nominal.out
 store i64 97, ptr %rank.out
 store i64 96, ptr %cells.out
 %invalid.result = call i1 @ube.variant.info(ptr @variant.ctx, i64 -1, ptr %tag.out, ptr %nominal.out, ptr %rank.out, ptr %cells.out)
 %invalid.failed = xor i1 %invalid.result, true
 %kept.tag = load i64, ptr %tag.out
 %kept.nominal = load i64, ptr %nominal.out
 %kept.rank = load i64, ptr %rank.out
 %kept.cells = load i64, ptr %cells.out
 %tag.kept = icmp eq i64 %kept.tag, 99
 %nominal.kept = icmp eq i64 %kept.nominal, 98
 %rank.kept = icmp eq i64 %kept.rank, 97
 %cells.kept = icmp eq i64 %kept.cells, 96
 %k = and i1 %tag.kept, %nominal.kept
 %l = and i1 %rank.kept, %cells.kept
 %m = and i1 %k, %l
 %n = and i1 %m, %invalid.failed
 br i1 %n, label %null, label %fail
null:
 %null.boxed = call i1 @ube.variant.box(ptr @variant.ctx, i64 1, i64 0, ptr null, ptr %root1)
 %null.id = load i64, ptr %root1
 %null.scalar = call {i1,i64} @ube.variant.scalar(ptr @variant.ctx, i64 %null.id)
 %null.success = extractvalue {i1,i64} %null.scalar, 0
 %null.failed = xor i1 %null.success, true
 %null.error = load i64, ptr @variant.ctx
 %mismatch = icmp eq i64 %null.error, 13
 %o = and i1 %null.boxed, %null.failed
 %p = and i1 %o, %mismatch
 br i1 %p, label %references, label %fail
references:
 %references.ok = call i1 @variant.references()
 br i1 %references.ok, label %text, label %fail
text:
 %text.created = call i1 @ube.text.create(ptr @variant.ctx, i64 1, i64 1, ptr @variant.candidate)
 %text.id = load i64, ptr @variant.candidate
 %text.written = call i1 @ube.text.write(ptr @variant.ctx, i64 %text.id, i64 0, i64 65)
 %text.published = call i1 @ube.text.publish(ptr @variant.ctx, ptr %root1, i64 %text.id)
 %text.boxed = call i1 @ube.variant.box(ptr @variant.ctx, i64 8, i64 %text.id, ptr @variant.layout, ptr %root2)
 call void @ube.managed.store(ptr @variant.ctx, ptr %root1, i64 0)
 %collected = call {i1,i64} @ube.managed.collect(ptr @variant.ctx, i64 -1)
 %collected.ok = extractvalue {i1,i64} %collected, 0
 %box.id = load i64, ptr %root2
 %text.scalar = call {i1,i64} @ube.variant.scalar(ptr @variant.ctx, i64 %box.id)
 %text.scalar.ok = extractvalue {i1,i64} %text.scalar, 0
 %text.value = extractvalue {i1,i64} %text.scalar, 1
 %same.text = icmp eq i64 %text.value, %text.id
 call void @ube.managed.store(ptr @variant.ctx, ptr %root1, i64 %text.value)
 %read = call i1 @ube.text.read(ptr @variant.ctx, ptr %root1, i64 0, ptr %tag.out)
 %letter = load i64, ptr %tag.out
 %letter.ok = icmp eq i64 %letter, 65
 %q = and i1 %text.created, %text.written
 %r = and i1 %text.published, %text.boxed
 %s = and i1 %text.scalar.ok, %same.text
 %t = and i1 %read, %letter.ok
 %u = and i1 %q, %r
 %v = and i1 %s, %t
 %w = and i1 %u, %v
 %text.all = and i1 %w, %collected.ok
 br i1 %text.all, label %numeric.edge, label %fail
numeric.edge:
 %other.created = call i1 @ube.text.create(ptr @variant.ctx, i64 1, i64 1, ptr @variant.candidate)
 %other.id = load i64, ptr @variant.candidate
 %other.written = call i1 @ube.text.write(ptr @variant.ctx, i64 %other.id, i64 0, i64 66)
 %other.published = call i1 @ube.text.publish(ptr @variant.ctx, ptr %root1, i64 %other.id)
 %numeric.boxed = call i1 @ube.variant.box(ptr @variant.ctx, i64 20, i64 %other.id, ptr null, ptr %root3)
 call void @ube.managed.store(ptr @variant.ctx, ptr %root1, i64 0)
 %numeric.round = call {i1,i64} @ube.managed.collect(ptr @variant.ctx, i64 -1)
 %numeric.collected = extractvalue {i1,i64} %numeric.round, 0
 %other.record = call ptr @ube.text.find(ptr @variant.ctx, i64 %other.id)
 %not.root = icmp eq ptr %other.record, null
 %na = and i1 %other.created, %other.written
 %nb = and i1 %other.published, %numeric.boxed
 %nc = and i1 %numeric.collected, %not.root
 %nd = and i1 %na, %nb
 %ne = and i1 %nd, %nc
 br i1 %ne, label %allocation, label %fail
allocation:
 store i64 2, ptr @variant.allocate.fail
 store i64 0, ptr @variant.allocate.calls
 %refused = call i1 @ube.variant.box(ptr @variant.ctx, i64 3, i64 456, ptr null, ptr @variant.roots)
 %refused.correct = xor i1 %refused, true
 %preserved.id = load i64, ptr @variant.roots
 %preserved = icmp eq i64 %preserved.id, %identity
 %attempts = load i64, ptr @variant.allocate.calls
 %twice = icmp eq i64 %attempts, 2
 %allocation.error = load i64, ptr @variant.ctx
 %out.of.memory = icmp eq i64 %allocation.error, 7
 %x = and i1 %refused.correct, %preserved
 %y = and i1 %twice, %out.of.memory
 %z = and i1 %x, %y
 br i1 %z, label %aggregate, label %fail
aggregate:
 %array.created = call i1 @ube.variant.create(ptr @variant.ctx, i64 8195, i64 0, i64 1, i64 4, ptr @variant.array.layout, ptr @variant.cleanup, ptr @variant.candidate)
 %array.id = load i64, ptr @variant.candidate
 %array.data = call ptr @ube.variant.payload(ptr @variant.ctx, i64 %array.id)
 %array.allocated = call i1 @ube.array.tryresize(ptr @variant.ctx, ptr %array.data, i64 3, i64 0, i64 1, ptr null)
 %candidate.round = call {i1,i64} @ube.managed.collect(ptr @variant.ctx, i64 -1)
 %candidate.kept = extractvalue {i1,i64} %candidate.round, 0
 %array.published = call i1 @ube.variant.publish(ptr @variant.ctx, ptr %root3, i64 %array.id)
 %array.info = call i1 @ube.variant.info(ptr @variant.ctx, i64 %array.id, ptr %tag.out, ptr %nominal.out, ptr %rank.out, ptr %cells.out)
 %array.rank = load i64, ptr %rank.out
 %array.rank.ok = icmp eq i64 %array.rank, 1
 %array.tag = load i64, ptr %tag.out
 %array.nominal = load i64, ptr %nominal.out
 %array.cells = load i64, ptr %cells.out
 %array.tag.ok = icmp eq i64 %array.tag, 8195
 %array.nominal.ok = icmp eq i64 %array.nominal, 0
 %array.cells.ok = icmp eq i64 %array.cells, 4
 %shape.a = and i1 %array.tag.ok, %array.nominal.ok
 %shape.b = and i1 %array.rank.ok, %array.cells.ok
 %shape = and i1 %shape.a, %shape.b
 store atomic i64 42, ptr @variant.ctx monotonic, align 8
 %shape.matched = call i1 @ube.variant.match(ptr @variant.ctx, i64 %array.id, i64 8195, i64 0, i64 1, i64 4)
 %shape.error = load i64, ptr @variant.ctx
 %shape.sticky = icmp eq i64 %shape.error, 42
 %wrong.tag = call i1 @ube.variant.match(ptr @variant.ctx, i64 %array.id, i64 8194, i64 0, i64 1, i64 4)
 %wrong.nominal = call i1 @ube.variant.match(ptr @variant.ctx, i64 %array.id, i64 8195, i64 7, i64 1, i64 4)
 %wrong.rank = call i1 @ube.variant.match(ptr @variant.ctx, i64 %array.id, i64 8195, i64 0, i64 2, i64 4)
 %wrong.cells = call i1 @ube.variant.match(ptr @variant.ctx, i64 %array.id, i64 8195, i64 0, i64 1, i64 3)
 %empty.match = call i1 @ube.variant.match(ptr @variant.ctx, i64 0, i64 8195, i64 0, i64 1, i64 4)
 %match.error = load i64, ptr @variant.ctx
 %match.error.ok = icmp eq i64 %match.error, 13
 %wrong.a = or i1 %wrong.tag, %wrong.nominal
 %wrong.b = or i1 %wrong.rank, %wrong.cells
 %wrong.c = or i1 %wrong.a, %wrong.b
 %wrong.any = or i1 %wrong.c, %empty.match
 %wrong.none = xor i1 %wrong.any, true
 %match.a = and i1 %shape.matched, %shape.sticky
 %match.b = and i1 %wrong.none, %match.error.ok
 %match.all = and i1 %match.a, %match.b
 %aa = and i1 %array.created, %array.allocated
 %ab = and i1 %array.published, %array.info
 %ac = and i1 %aa, %ab
 %ad = and i1 %ac, %shape
 %ae = and i1 %ad, %candidate.kept
 %af = and i1 %ae, %match.all
 br i1 %af, label %cleanup, label %fail
cleanup:
 call void @ube.managed.store(ptr @variant.ctx, ptr %root3, i64 0)
 store i64 1, ptr @variant.release.fail
 %release.round = call {i1,i64} @ube.managed.collect(ptr @variant.ctx, i64 -1)
 %retry.round = call {i1,i64} @ube.managed.collect(ptr @variant.ctx, i64 -1)
 %cleanup.calls = load i64, ptr @variant.cleanup.calls
 %once = icmp eq i64 %cleanup.calls, 1
 %cleanup.allocated = load i1, ptr @variant.cleanup.allocated
 %allocation.free = xor i1 %cleanup.allocated, true
 %cleanup.correct = and i1 %once, %allocation.free
 br i1 %cleanup.correct, label %partial, label %fail
partial:
 %partial.created = call i1 @ube.variant.create(ptr @variant.ctx, i64 8195, i64 0, i64 1, i64 4, ptr @variant.array.layout, ptr @variant.cleanup, ptr @variant.candidate)
 %partial.id = load i64, ptr @variant.candidate
 %partial.data = call ptr @ube.variant.payload(ptr @variant.ctx, i64 %partial.id)
 store i64 2, ptr @variant.allocate.fail
 %partial.allocation = call i1 @ube.array.tryresize(ptr @variant.ctx, ptr %partial.data, i64 3, i64 0, i64 1, ptr null)
 %partial.refused = xor i1 %partial.allocation, true
 %partial.abandoned = call i1 @ube.variant.abandon(ptr @variant.ctx, i64 %partial.id)
 %partial.round = call {i1,i64} @ube.managed.collect(ptr @variant.ctx, i64 -1)
 %partial.collected = extractvalue {i1,i64} %partial.round, 0
 %partial.calls = load i64, ptr @variant.cleanup.calls
 %partial.cleaned = icmp eq i64 %partial.calls, 2
 %pa = and i1 %partial.created, %partial.refused
 %pb = and i1 %partial.abandoned, %partial.collected
 %pc = and i1 %pa, %pb
 %pd = and i1 %pc, %partial.cleaned
 br i1 %pd, label %unpublished, label %fail
unpublished:
 %unpublished.created = call i1 @ube.variant.create(ptr @variant.ctx, i64 8195, i64 0, i64 1, i64 4, ptr @variant.array.layout, ptr @variant.cleanup, ptr @variant.candidate)
 %unpublished.id = load i64, ptr @variant.candidate
 %unpublished.data = call ptr @ube.variant.payload(ptr @variant.ctx, i64 %unpublished.id)
 %unpublished.allocated = call i1 @ube.array.tryresize(ptr @variant.ctx, ptr %unpublished.data, i64 3, i64 0, i64 1, ptr null)
 %ua = and i1 %unpublished.created, %unpublished.allocated
 br i1 %ua, label %dispose, label %fail
dispose:
 call void @ube.managed.root.pop(ptr @variant.ctx, ptr @variant.frame)
 %disposed = call i1 @ube.context.dispose(ptr @variant.ctx)
 %count.ptr = call ptr @ube.memory.count(ptr @variant.ctx)
 %count = load i64, ptr %count.ptr
 %no.blocks = icmp eq i64 %count, 0
 %final.calls = load i64, ptr @variant.cleanup.calls
 %scope.cleaned = icmp eq i64 %final.calls, 3
 %disposed.clean = and i1 %disposed, %no.blocks
 %clean = and i1 %disposed.clean, %scope.cleaned
 br i1 %clean, label %done, label %fail
done:
 ret i32 0
fail:
 %failure = phi i32 [2, %entry], [3, %root], [4, %scalars], [1, %scalar], [5, %invalid], [6, %null], [15, %references], [7, %text], [14, %numeric.edge], [8, %allocation], [9, %aggregate], [10, %cleanup], [12, %partial], [13, %unpublished], [11, %dispose]
 ret i32 %failure
}
