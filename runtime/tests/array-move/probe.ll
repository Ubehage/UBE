@probe.ctx = global %ube.context zeroinitializer, align 8
@probe.a = global [4 x i64] [i64 0, i64 -1, i64 0, i64 0], align 8
@probe.b = global [4 x i64] [i64 0, i64 -1, i64 0, i64 0], align 8
@probe.inline = global [2 x i64] [i64 71, i64 73], align 8

define i1 @probe.shape(ptr %array, i64 %low, i64 %high, ptr %data, ptr %block) {
entry:
  %p1 = getelementptr i64, ptr %array, i64 1
  %p2 = getelementptr i64, ptr %array, i64 2
  %p3 = getelementptr i64, ptr %array, i64 3
  %v0 = load i64, ptr %array
  %v1 = load i64, ptr %p1
  %v2 = load ptr, ptr %p2
  %v3 = load ptr, ptr %p3
  %a = icmp eq i64 %v0, %low
  %b = icmp eq i64 %v1, %high
  %c = icmp eq ptr %v2, %data
  %d = icmp eq ptr %v3, %block
  %ab = and i1 %a, %b
  %cd = and i1 %c, %d
  %ok = and i1 %ab, %cd
  ret i1 %ok
}
define i32 @main() {
entry:
  call void @ube.context.init(ptr @probe.ctx)
  %old = call ptr @ube.memory.new(ptr @probe.ctx, i64 2, i64 1)
  %source = call ptr @ube.memory.new(ptr @probe.ctx, i64 2, i64 1)
  %created.old = icmp ne ptr %old, null
  %created.source = icmp ne ptr %source, null
  %created = and i1 %created.old, %created.source
  br i1 %created, label %setup, label %fail
setup:
  call void @ube.array.install(ptr @probe.ctx, ptr @probe.a, ptr %old, i64 4, i64 5)
  call void @ube.array.install(ptr @probe.ctx, ptr @probe.b, ptr %source, i64 -3, i64 -2)
  %data = getelementptr %ube.block, ptr %source, i64 1
  store i64 101, ptr %data
  %alias = call {i64,i64,ptr,ptr} @ube.array.snapshot(ptr @probe.ctx, ptr @probe.a)
  %retained = extractvalue {i64,i64,ptr,ptr} %alias, 3
  store i64 91, ptr @probe.ctx
  %moved = call i1 @ube.array.move(ptr @probe.ctx, ptr @probe.a, ptr @probe.b)
  %shape = call i1 @probe.shape(ptr @probe.a, i64 -3, i64 -2, ptr %data, ptr %source)
  %empty = call i1 @probe.shape(ptr @probe.b, i64 0, i64 -1, ptr null, ptr null)
  %err = load i64, ptr @probe.ctx
  %sticky = icmp eq i64 %err, 91
  %count.ptr = call ptr @ube.memory.count(ptr @probe.ctx)
  %count = load i64, ptr %count.ptr
  %no.allocate = icmp eq i64 %count, 2
  %refs.ptr = getelementptr %ube.block, ptr %old, i32 0, i32 1
  %refs = load i64, ptr %refs.ptr
  %alias.live = icmp eq i64 %refs, 1
  %a = and i1 %moved, %shape
  %b = and i1 %empty, %sticky
  %c = and i1 %no.allocate, %alias.live
  %ab = and i1 %a, %b
  %first = and i1 %ab, %c
  br i1 %first, label %inline.setup, label %fail
inline.setup:
  %bp1 = getelementptr i64, ptr @probe.b, i64 1
  %bp2 = getelementptr i64, ptr @probe.b, i64 2
  store i64 10, ptr @probe.b
  store i64 11, ptr %bp1
  store ptr @probe.inline, ptr %bp2
  %self = call i1 @ube.array.move(ptr @probe.ctx, ptr @probe.b, ptr @probe.b)
  %self.shape = call i1 @probe.shape(ptr @probe.b, i64 10, i64 11, ptr @probe.inline, ptr null)
  %rejected = call i1 @ube.array.move(ptr @probe.ctx, ptr @probe.a, ptr @probe.b)
  %refused = xor i1 %rejected, true
  %intact.a = call i1 @probe.shape(ptr @probe.a, i64 -3, i64 -2, ptr %data, ptr %source)
  %intact.b = call i1 @probe.shape(ptr @probe.b, i64 10, i64 11, ptr @probe.inline, ptr null)
  %bad.err = load i64, ptr @probe.ctx
  %error5 = icmp eq i64 %bad.err, 5
  %d = and i1 %self, %self.shape
  %e = and i1 %refused, %intact.a
  %f = and i1 %intact.b, %error5
  %de = and i1 %d, %e
  %second = and i1 %de, %f
  br i1 %second, label %fixed.destination, label %fail
fixed.destination:
  %fixed = call i1 @ube.array.move(ptr @probe.ctx, ptr @probe.b, ptr @probe.a)
  %fixed.shape = call i1 @probe.shape(ptr @probe.b, i64 -3, i64 -2, ptr %data, ptr %source)
  %empty.a = call i1 @probe.shape(ptr @probe.a, i64 0, i64 -1, ptr null, ptr null)
  %empty.move = call i1 @ube.array.move(ptr @probe.ctx, ptr @probe.b, ptr @probe.a)
  %empty.b = call i1 @probe.shape(ptr @probe.b, i64 0, i64 -1, ptr null, ptr null)
  %g = and i1 %fixed, %fixed.shape
  %h = and i1 %empty.a, %empty.move
  %gh = and i1 %g, %h
  %third = and i1 %gh, %empty.b
  br i1 %third, label %dispose, label %fail
dispose:
  call void @ube.block.drop(ptr @probe.ctx, ptr %retained)
  %collected = call i1 @ube.memory.collect(ptr @probe.ctx)
  %remaining = load i64, ptr %count.ptr
  %balanced = icmp eq i64 %remaining, 0
  %ok = and i1 %collected, %balanced
  %exit = select i1 %ok, i32 0, i32 1
  ret i32 %exit
fail:
  ret i32 1
}
