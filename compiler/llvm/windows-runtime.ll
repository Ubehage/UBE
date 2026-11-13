%ube.block = type { ptr, i64, i64 }
define internal i1 @ube.array.descriptor.overlaps(ptr %array, ptr %output) {
entry:
  %start = ptrtoint ptr %array to i64
  %address = ptrtoint ptr %output to i64
  %distance = sub i64 %address, %start
  %inside = icmp ult i64 %distance, 32
  %before = sub i64 %start, %address
  %crosses = icmp ult i64 %before, 8
  %intersects = or i1 %inside, %crosses
  %exists = icmp ne ptr %array, null
  %overlaps = and i1 %intersects, %exists
  ret i1 %overlaps
}
define internal ptr @ube.thread.program(ptr %ctx) {
entry:
  %address = getelementptr %ube.thread, ptr %ctx, i32 0, i32 2
  %program = load ptr, ptr %address
  ret ptr %program
}
define void @ube.thread.init(ptr %ctx, ptr %program, ptr %control) {
entry:
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  %depth = getelementptr %ube.thread, ptr %ctx, i32 0, i32 1
  %owner = getelementptr %ube.thread, ptr %ctx, i32 0, i32 2
  %state = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3
  store atomic i64 0, ptr %err monotonic, align 8
  store atomic i64 0, ptr %depth monotonic, align 8
  store ptr %program, ptr %owner
  store ptr %control, ptr %state
  ret void
}
define internal ptr @ube.module.state(ptr %ctx, i64 %index) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %address = getelementptr %ube.program, ptr %program, i32 0, i32 0, i64 %index
  ret ptr %address
}

define internal ptr @ube.storage.address(ptr %ctx, i64 %index) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %address = getelementptr %ube.program, ptr %program, i32 0, i32 1, i64 %index
  ret ptr %address
}

define internal ptr @ube.resource.slot(ptr %ctx, i64 %index) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %address = getelementptr %ube.program, ptr %program, i32 0, i32 5, i64 %index
  ret ptr %address
}

define internal ptr @ube.module.owner(ptr %ctx, i64 %index) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %address = getelementptr %ube.program, ptr %program, i32 0, i32 9, i64 %index
  ret ptr %address
}

define internal ptr @ube.memory.head(ptr %ctx) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %address = getelementptr %ube.program, ptr %program, i32 0, i32 2
  ret ptr %address
}

define internal ptr @ube.memory.bytes(ptr %ctx) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %address = getelementptr %ube.program, ptr %program, i32 0, i32 3
  ret ptr %address
}

define internal ptr @ube.memory.count(ptr %ctx) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %address = getelementptr %ube.program, ptr %program, i32 0, i32 4
  ret ptr %address
}
declare dllimport ptr @VirtualAlloc(ptr, i64, i32, i32)
declare dllimport i32 @VirtualFree(ptr, i64, i32)
define ptr @ube.target.allocate(i64 %bytes) {
entry:
  %p = call ptr @VirtualAlloc(ptr null, i64 %bytes, i32 12288, i32 4)
  ret ptr %p
}
define i1 @ube.target.release(ptr %block) {
entry:
  %status = call i32 @VirtualFree(ptr %block, i64 0, i32 32768)
  %ok = icmp ne i32 %status, 0
  ret i1 %ok
}
define internal void @ube.block.retain(ptr %block) {
entry:
  %exists = icmp ne ptr %block, null
  br i1 %exists, label %retain, label %done
retain:
  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1
  %previous = atomicrmw add ptr %refs.ptr, i64 1 monotonic
  br label %done
done:
  ret void
}
define internal void @ube.block.drop(ptr %ctx, ptr %block) {
entry:
  %exists = icmp ne ptr %block, null
  br i1 %exists, label %drop, label %done
drop:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %pending = getelementptr %ube.program, ptr %program, i32 0, i32 12
  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1
  %previous = atomicrmw sub ptr %refs.ptr, i64 1 release
  %last = icmp eq i64 %previous, 1
  br i1 %last, label %retired, label %done
retired:
  %marked = atomicrmw or ptr %pending, i64 1 release
  br label %done
done:
  ret void
}
define internal i1 @ube.memory.collect.locked(ptr %ctx) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %pending = getelementptr %ube.program, ptr %program, i32 0, i32 12
  %acknowledged = atomicrmw xchg ptr %pending, i64 0 acq_rel
  %head = call ptr @ube.memory.head(ptr %ctx)
  %bytes.ptr = call ptr @ube.memory.bytes(ptr %ctx)
  %count.ptr = call ptr @ube.memory.count(ptr %ctx)
  br label %scan
scan:
  %link = phi ptr [ %head, %entry ], [ %block, %keep ], [ %link, %freed ]
  %worked = phi i1 [ false, %entry ], [ %worked, %keep ], [ true, %freed ]
  %block = load ptr, ptr %link
  %exists = icmp ne ptr %block, null
  br i1 %exists, label %inspect, label %done
inspect:
  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1
  %refs = load atomic i64, ptr %refs.ptr acquire, align 8
  %unused = icmp eq i64 %refs, 0
  br i1 %unused, label %release, label %keep
release:
  %next = load ptr, ptr %block
  %charge.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 2
  %charge = load atomic i64, ptr %charge.ptr monotonic, align 8
  %ok = call i1 @ube.target.release(ptr %block)
  br i1 %ok, label %freed, label %refused
refused:
  %remarked = atomicrmw or ptr %pending, i64 1 release
  br label %keep
freed:
  store ptr %next, ptr %link
  %bytes = load atomic i64, ptr %bytes.ptr monotonic, align 8
  %less.bytes = sub i64 %bytes, %charge
  store atomic i64 %less.bytes, ptr %bytes.ptr monotonic, align 8
  %count = load atomic i64, ptr %count.ptr monotonic, align 8
  %less.count = sub i64 %count, 1
  store atomic i64 %less.count, ptr %count.ptr monotonic, align 8
  br label %scan
keep:
  br label %scan
done:
  ret i1 %worked
}
define internal ptr @ube.memory.new.locked(ptr %ctx, i64 %count, i64 %stride) {
entry:
  %negative = icmp sle i64 %count, 0
  %large = icmp sgt i64 %count, 1048576
  %bad.stride.low = icmp sle i64 %stride, 0
  %bad.stride.high = icmp sgt i64 %stride, 128
  %bad.count = or i1 %negative, %large
  %bad.stride = or i1 %bad.stride.low, %bad.stride.high
  %bad = or i1 %bad.count, %bad.stride
  br i1 %bad, label %failed, label %size
size:
  %cells = mul i64 %count, %stride
  %payload.bytes = mul i64 %cells, 8
  %total = add i64 %payload.bytes, 24
  %rounded = add i64 %total, 4095
  %pages = lshr i64 %rounded, 12
  %charge = shl i64 %pages, 12
  %charge.large = icmp ugt i64 %charge, 67108864
  br i1 %charge.large, label %failed, label %quota
quota:
  %available = sub i64 67108864, %charge
  %head = call ptr @ube.memory.head(ptr %ctx)
  %bytes.ptr = call ptr @ube.memory.bytes(ptr %ctx)
  %count.ptr = call ptr @ube.memory.count(ptr %ctx)
  br label %attempt
attempt:
  %retry = phi i1 [ false, %quota ], [ true, %collect ]
  %bytes = load atomic i64, ptr %bytes.ptr monotonic, align 8
  %blocks = load atomic i64, ptr %count.ptr monotonic, align 8
  %over.bytes = icmp ugt i64 %bytes, %available
  %over.blocks = icmp uge i64 %blocks, 4096
  %over = or i1 %over.bytes, %over.blocks
  br i1 %over, label %miss, label %allocate
allocate:
  %block = call ptr @ube.target.allocate(i64 %charge)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %allocated, label %miss
miss:
  br i1 %retry, label %failed, label %collect
collect:
  %collected = call i1 @ube.memory.collect.locked(ptr %ctx)
  br label %attempt
allocated:
  %old.head = load ptr, ptr %head
  store ptr %old.head, ptr %block
  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1
  store atomic i64 1, ptr %refs.ptr monotonic, align 8
  %charge.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 2
  store atomic i64 %charge, ptr %charge.ptr monotonic, align 8
  store ptr %block, ptr %head
  %new.bytes = add i64 %bytes, %charge
  %new.blocks = add i64 %blocks, 1
  store atomic i64 %new.bytes, ptr %bytes.ptr monotonic, align 8
  store atomic i64 %new.blocks, ptr %count.ptr monotonic, align 8
  %data = getelementptr %ube.block, ptr %block, i64 1
  br label %zero
zero:
  %index = phi i64 [ 0, %allocated ], [ %next.index, %zero ]
  %cell = getelementptr i64, ptr %data, i64 %index
  store atomic volatile i64 0, ptr %cell monotonic, align 8
  %next.index = add i64 %index, 1
  %more = icmp ult i64 %next.index, %cells
  br i1 %more, label %zero, label %done
done:
  ret ptr %block
failed:
  ret ptr null
}
define internal void @ube.array.clear(ptr %ctx, ptr %array) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.program.storage.lock(ptr %program)
  call void @ube.array.clear.locked(ptr %ctx, ptr %array)
  call void @ube.program.storage.unlock(ptr %program)
  ret void
}
define internal void @ube.array.clear.locked(ptr %ctx, ptr %array) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.array.lock(ptr %program, ptr %array)
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %block.ptr = getelementptr i64, ptr %array, i64 3
  %old = load ptr, ptr %block.ptr
  store atomic i64 0, ptr %array monotonic, align 8
  store atomic i64 -1, ptr %upper.ptr monotonic, align 8
  store ptr null, ptr %data.ptr
  store ptr null, ptr %block.ptr
  call void @ube.block.drop(ptr %ctx, ptr %old)
  call void @ube.array.unlock(ptr %program, ptr %array)
  ret void
}
define internal void @ube.box.drop(ptr %ctx, ptr %block, i1 %contains.array) {
entry:
  %exists = icmp ne ptr %block, null
  br i1 %exists, label %inspect, label %done
inspect:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.program.storage.lock(ptr %program)
  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1
  %refs = load atomic i64, ptr %refs.ptr acquire, align 8
  %last = icmp eq i64 %refs, 1
  %clear = and i1 %last, %contains.array
  br i1 %clear, label %clear.array, label %drop
clear.array:
  %array = getelementptr %ube.block, ptr %block, i64 1
  call void @ube.array.clear.locked(ptr %ctx, ptr %array)
  br label %drop
drop:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  call void @ube.program.storage.unlock(ptr %program)
  br label %done
done:
  ret void
}
define internal void @ube.array.install(ptr %ctx, ptr %array, ptr %block, i64 %lower, i64 %upper) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.program.storage.lock(ptr %program)
  call void @ube.array.lock(ptr %program, ptr %array)
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %block.ptr = getelementptr i64, ptr %array, i64 3
  %old = load ptr, ptr %block.ptr
  %data = getelementptr %ube.block, ptr %block, i64 1
  store atomic i64 %lower, ptr %array monotonic, align 8
  store atomic i64 %upper, ptr %upper.ptr monotonic, align 8
  store ptr %data, ptr %data.ptr
  store ptr %block, ptr %block.ptr
  call void @ube.block.drop(ptr %ctx, ptr %old)
  call void @ube.array.unlock(ptr %program, ptr %array)
  call void @ube.program.storage.unlock(ptr %program)
  ret void
}
define internal void @ube.cells.copy(ptr %source, ptr %destination, i64 %count) {
entry:
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %done, label %copy
copy:
  %index = phi i64 [ 0, %entry ], [ %next, %copy ]
  %from = getelementptr i64, ptr %source, i64 %index
  %to = getelementptr i64, ptr %destination, i64 %index
  %value = load atomic volatile i64, ptr %from monotonic, align 8
  store atomic volatile i64 %value, ptr %to monotonic, align 8
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %copy, label %done
done:
  ret void
}
define internal i1 @ube.array.tryresize(ptr %ctx, ptr %array, i64 %count, i64 %preserve, i64 %stride) {
entry:
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  %negative = icmp slt i64 %count, 0
  br i1 %negative, label %argument.fail, label %empty.test
empty.test:
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %empty.resize, label %allocate
empty.resize:
  call void @ube.array.clear(ptr %ctx, ptr %array)
  %empty.collected = call i1 @ube.memory.collect(ptr %ctx)
  ret i1 true
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 %count, i64 %stride)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %prepared, label %memory.fail
prepared:
  %upper = sub i64 %count, 1
  %keep = icmp ne i64 %preserve, 0
  br i1 %keep, label %intersection, label %publish
intersection:
  %snapshot = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)
  %old.lower = extractvalue { i64, i64, ptr, ptr } %snapshot, 0
  %old.upper = extractvalue { i64, i64, ptr, ptr } %snapshot, 1
  %old.data = extractvalue { i64, i64, ptr, ptr } %snapshot, 2
  %old.block = extractvalue { i64, i64, ptr, ptr } %snapshot, 3
  %positive.lower = icmp sgt i64 %old.lower, 0
  %first = select i1 %positive.lower, i64 %old.lower, i64 0
  %smaller.upper = icmp slt i64 %old.upper, %upper
  %last = select i1 %smaller.upper, i64 %old.upper, i64 %upper
  %overlap = icmp sle i64 %first, %last
  br i1 %overlap, label %copy, label %publish
copy:
  %data = getelementptr %ube.block, ptr %block, i64 1
  %old.index = sub i64 %first, %old.lower
  %old.offset = mul i64 %old.index, %stride
  %new.offset = mul i64 %first, %stride
  %source = getelementptr i64, ptr %old.data, i64 %old.offset
  %destination = getelementptr i64, ptr %data, i64 %new.offset
  %distance = sub i64 %last, %first
  %elements = add i64 %distance, 1
  %cells = mul i64 %elements, %stride
  call void @ube.cells.copy(ptr %source, ptr %destination, i64 %cells)
  br label %publish
publish:
  %pin = phi ptr [null, %prepared], [%old.block, %intersection], [%old.block, %copy]
  call void @ube.array.install(ptr %ctx, ptr %array, ptr %block, i64 0, i64 %upper)
  call void @ube.block.drop(ptr %ctx, ptr %pin)
  %collected = call i1 @ube.memory.collect(ptr %ctx)
  ret i1 true
argument.fail:
  store atomic i64 5, ptr %err monotonic, align 8
  ret i1 false
memory.fail:
  store atomic i64 7, ptr %err monotonic, align 8
  ret i1 false
}
define internal i1 @ube.array.trycopy(ptr %ctx, ptr %destination, ptr %source, i64 %stride) {
entry:
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  %snapshot = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %source)
  %lower = extractvalue { i64, i64, ptr, ptr } %snapshot, 0
  %upper = extractvalue { i64, i64, ptr, ptr } %snapshot, 1
  %source.data = extractvalue { i64, i64, ptr, ptr } %snapshot, 2
  %pin = extractvalue { i64, i64, ptr, ptr } %snapshot, 3
  %distance = sub i64 %upper, %lower
  %count = add i64 %distance, 1
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %empty.copy, label %allocate
empty.copy:
  call void @ube.array.clear(ptr %ctx, ptr %destination)
  call void @ube.block.drop(ptr %ctx, ptr %pin)
  %empty.collected = call i1 @ube.memory.collect(ptr %ctx)
  ret i1 true
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 %count, i64 %stride)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %copy, label %memory.fail
copy:
  %destination.data = getelementptr %ube.block, ptr %block, i64 1
  %cells = mul i64 %count, %stride
  call void @ube.cells.copy(ptr %source.data, ptr %destination.data, i64 %cells)
  call void @ube.array.install(ptr %ctx, ptr %destination, ptr %block, i64 %lower, i64 %upper)
  call void @ube.block.drop(ptr %ctx, ptr %pin)
  %collected = call i1 @ube.memory.collect(ptr %ctx)
  ret i1 true
memory.fail:
  call void @ube.block.drop(ptr %ctx, ptr %pin)
  store atomic i64 7, ptr %err monotonic, align 8
  ret i1 false
}
define internal void @ube.program.storage.lock(ptr %program) {
entry:
  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 6
  br label %attempt
attempt:
  %pair = cmpxchg ptr %lock, i64 0, i64 1 acquire monotonic
  %won = extractvalue { i64, i1 } %pair, 1
  br i1 %won, label %done, label %attempt
done:
  ret void
}
define internal void @ube.program.storage.unlock(ptr %program) {
entry:
  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 6
  store atomic i64 0, ptr %lock release, align 8
  ret void
}
define internal ptr @ube.array.lock.address(ptr %program, ptr %array) {
entry:
  %address = ptrtoint ptr %array to i64
  %low = lshr i64 %address, 3
  %page = lshr i64 %address, 12
  %stack = lshr i64 %address, 16
  %region = lshr i64 %address, 22
  %high = lshr i64 %address, 32
  %a = xor i64 %low, %page
  %b = xor i64 %a, %stack
  %c = xor i64 %b, %region
  %d = xor i64 %c, %high
  %stripe = and i64 %d, 63
  %index = add i64 %stripe, 1
  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 13, i64 %index, i64 0
  ret ptr %lock
}
define internal void @ube.array.lock(ptr %program, ptr %array) {
entry:
  %lock = call ptr @ube.array.lock.address(ptr %program, ptr %array)
  br label %attempt
attempt:
  %pair = cmpxchg ptr %lock, i64 0, i64 1 acquire monotonic
  %won = extractvalue { i64, i1 } %pair, 1
  br i1 %won, label %done, label %attempt
done:
  ret void
}
define internal void @ube.array.unlock(ptr %program, ptr %array) {
entry:
  %lock = call ptr @ube.array.lock.address(ptr %program, ptr %array)
  store atomic i64 0, ptr %lock release, align 8
  ret void
}
define internal { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array) {
entry:
  %empty = icmp eq ptr %array, null
  br i1 %empty, label %absent, label %capture
absent:
  ret { i64, i64, ptr, ptr } { i64 0, i64 -1, ptr null, ptr null }
capture:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.array.lock(ptr %program, ptr %array)
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %block.ptr = getelementptr i64, ptr %array, i64 3
  %lower = load atomic i64, ptr %array monotonic, align 8
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %data = load ptr, ptr %data.ptr
  %block = load ptr, ptr %block.ptr
  call void @ube.block.retain(ptr %block)
  call void @ube.array.unlock(ptr %program, ptr %array)
  %first = insertvalue { i64, i64, ptr, ptr } poison, i64 %lower, 0
  %second = insertvalue { i64, i64, ptr, ptr } %first, i64 %upper, 1
  %third = insertvalue { i64, i64, ptr, ptr } %second, ptr %data, 2
  %result = insertvalue { i64, i64, ptr, ptr } %third, ptr %block, 3
  ret { i64, i64, ptr, ptr } %result
}
define internal i64 @ube.array.length(ptr %ctx, ptr %array) {
entry:
  %snapshot = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)
  %lower = extractvalue { i64, i64, ptr, ptr } %snapshot, 0
  %upper = extractvalue { i64, i64, ptr, ptr } %snapshot, 1
  %block = extractvalue { i64, i64, ptr, ptr } %snapshot, 3
  %distance = sub i64 %upper, %lower
  %length = add i64 %distance, 1
  call void @ube.block.drop(ptr %ctx, ptr %block)
  ret i64 %length
}
define internal i1 @ube.memory.collect(ptr %ctx) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %pending = getelementptr %ube.program, ptr %program, i32 0, i32 12
  %retired = load atomic i64, ptr %pending acquire, align 8
  %needed = icmp ne i64 %retired, 0
  br i1 %needed, label %collect, label %idle
idle:
  ret i1 false
collect:
  call void @ube.program.storage.lock(ptr %program)
  %worked = call i1 @ube.memory.collect.locked(ptr %ctx)
  call void @ube.program.storage.unlock(ptr %program)
  ret i1 %worked
}
define internal ptr @ube.memory.new(ptr %ctx, i64 %count, i64 %stride) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.program.storage.lock(ptr %program)
  %block = call ptr @ube.memory.new.locked(ptr %ctx, i64 %count, i64 %stride)
  call void @ube.program.storage.unlock(ptr %program)
  ret ptr %block
}
define internal { i1, i64 } @ube.memory.copybytes(ptr %ctx, ptr %arg.0, i64 %arg.1, ptr %arg.2, i64 %arg.3, i64 %arg.4) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.program.storage.lock(ptr %program)
  %source.lower = load atomic i64, ptr %arg.0 monotonic, align 8
  %source.upper.ptr = getelementptr i64, ptr %arg.0, i64 1
  %source.upper = load atomic i64, ptr %source.upper.ptr monotonic, align 8
  %source.distance = sub i64 %source.upper, %source.lower
  %source.length = add i64 %source.distance, 1
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  %count.invalid = icmp slt i64 %arg.4, 0
  br i1 %count.invalid, label %argument.fail, label %span.starts
span.starts:
  %destination.lower = load atomic i64, ptr %arg.2 monotonic, align 8
  %destination.upper.ptr = getelementptr i64, ptr %arg.2, i64 1
  %destination.upper = load atomic i64, ptr %destination.upper.ptr monotonic, align 8
  %destination.distance = sub i64 %destination.upper, %destination.lower
  %destination.length = add i64 %destination.distance, 1
  %source.negative = icmp slt i64 %arg.1, 0
  %destination.negative = icmp slt i64 %arg.3, 0
  %source.past = icmp sgt i64 %arg.1, %source.length
  %destination.past = icmp sgt i64 %arg.3, %destination.length
  %negative = or i1 %source.negative, %destination.negative
  %past = or i1 %source.past, %destination.past
  %start.invalid = or i1 %negative, %past
  br i1 %start.invalid, label %span.fail, label %span.count
span.count:
  %source.remaining = sub i64 %source.length, %arg.1
  %destination.remaining = sub i64 %destination.length, %arg.3
  %source.short = icmp sgt i64 %arg.4, %source.remaining
  %destination.short = icmp sgt i64 %arg.4, %destination.remaining
  %span.invalid = or i1 %source.short, %destination.short
  br i1 %span.invalid, label %span.fail, label %copy.test
copy.test:
  %empty = icmp eq i64 %arg.4, 0
  br i1 %empty, label %copy.done, label %copy.choose
copy.choose:
  %source.data.ptr = getelementptr i64, ptr %arg.0, i64 2
  %source.data = load ptr, ptr %source.data.ptr
  %destination.data.ptr = getelementptr i64, ptr %arg.2, i64 2
  %destination.data = load ptr, ptr %destination.data.ptr
  %same = icmp eq ptr %arg.0, %arg.2
  %later = icmp sgt i64 %arg.3, %arg.1
  %backward = and i1 %same, %later
  br i1 %backward, label %copy.backward, label %copy.forward
copy.forward:
  %forward.index = phi i64 [ 0, %copy.choose ], [ %forward.next, %copy.forward ]
  %forward.source.index = add i64 %arg.1, %forward.index
  %forward.destination.index = add i64 %arg.3, %forward.index
  %forward.source = getelementptr i64, ptr %source.data, i64 %forward.source.index
  %forward.destination = getelementptr i64, ptr %destination.data, i64 %forward.destination.index
  %forward.value = load atomic volatile i64, ptr %forward.source monotonic, align 8
  store atomic volatile i64 %forward.value, ptr %forward.destination monotonic, align 8
  %forward.next = add i64 %forward.index, 1
  %forward.more = icmp slt i64 %forward.next, %arg.4
  br i1 %forward.more, label %copy.forward, label %copy.done
copy.backward:
  %backward.remaining = phi i64 [ %arg.4, %copy.choose ], [ %backward.index, %copy.backward ]
  %backward.index = sub i64 %backward.remaining, 1
  %backward.source.index = add i64 %arg.1, %backward.index
  %backward.destination.index = add i64 %arg.3, %backward.index
  %backward.source = getelementptr i64, ptr %source.data, i64 %backward.source.index
  %backward.destination = getelementptr i64, ptr %destination.data, i64 %backward.destination.index
  %backward.value = load atomic volatile i64, ptr %backward.source monotonic, align 8
  store atomic volatile i64 %backward.value, ptr %backward.destination monotonic, align 8
  %backward.more = icmp ne i64 %backward.index, 0
  br i1 %backward.more, label %copy.backward, label %copy.done
argument.fail:
  store atomic i64 5, ptr %err monotonic, align 8
  call void @ube.program.storage.unlock(ptr %program)
  ret { i1, i64 } { i1 true, i64 0 }
span.fail:
  store atomic i64 9, ptr %err monotonic, align 8
  call void @ube.program.storage.unlock(ptr %program)
  ret { i1, i64 } { i1 true, i64 0 }
copy.done:
  call void @ube.program.storage.unlock(ptr %program)
  ret { i1, i64 } { i1 true, i64 -1 }
}
@ube.resource.next = internal global i64 1, align 8
declare dllimport ptr @CreateFileW(ptr, i32, i32, ptr, i32, i32, ptr)
declare dllimport i32 @GetFileType(ptr)
declare dllimport i32 @GetFileSizeEx(ptr, ptr)
declare dllimport i32 @ReadFile(ptr, ptr, i32, ptr, ptr)
declare dllimport i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
declare dllimport i32 @CloseHandle(ptr)
declare dllimport i32 @FlushFileBuffers(ptr)
declare dllimport i32 @MultiByteToWideChar(i32, i32, ptr, i32, ptr, i32)
define ptr @ube.target.file.open(ptr %path, i1 %write) {
entry:
  %access = select i1 %write, i32 1073741952, i32 -2147483648
  %creation = select i1 %write, i32 1, i32 3
  %sharing = select i1 %write, i32 0, i32 7
  %handle = call ptr @CreateFileW(ptr %path, i32 %access, i32 %sharing, ptr null, i32 %creation, i32 128, ptr null)
  ret ptr %handle
}
define i32 @ube.target.file.type(ptr %handle) {
entry:
  %kind = call i32 @GetFileType(ptr %handle)
  ret i32 %kind
}
define i1 @ube.target.file.size(ptr %handle, ptr %size) {
entry:
  %status = call i32 @GetFileSizeEx(ptr %handle, ptr %size)
  %ok = icmp ne i32 %status, 0
  ret i1 %ok
}
define i1 @ube.target.file.read(ptr %handle, ptr %bytes, i32 %count, ptr %progress) {
entry:
  %status = call i32 @ReadFile(ptr %handle, ptr %bytes, i32 %count, ptr %progress, ptr null)
  %ok = icmp ne i32 %status, 0
  ret i1 %ok
}
define i1 @ube.target.file.write(ptr %handle, ptr %bytes, i32 %count, ptr %progress) {
entry:
  %status = call i32 @WriteFile(ptr %handle, ptr %bytes, i32 %count, ptr %progress, ptr null)
  %ok = icmp ne i32 %status, 0
  ret i1 %ok
}
define i1 @ube.target.file.close(ptr %handle) {
entry:
  %status = call i32 @CloseHandle(ptr %handle)
  %ok = icmp ne i32 %status, 0
  ret i1 %ok
}
define i1 @ube.target.file.flush(ptr %handle) {
entry:
  %status = call i32 @FlushFileBuffers(ptr %handle)
  %ok = icmp ne i32 %status, 0
  ret i1 %ok
}
define i32 @ube.target.file.utf8(ptr %bytes, i32 %count, ptr %wide, i32 %capacity) {
entry:
  %length = call i32 @MultiByteToWideChar(i32 65001, i32 8, ptr %bytes, i32 %count, ptr %wide, i32 %capacity)
  ret i32 %length
}
define internal i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %code, i64 %number) {
entry:
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  store atomic i64 %number, ptr %err monotonic, align 8
  store atomic i64 %code, ptr %failure monotonic, align 8
  ret i1 false
}
define internal i1 @ube.file.aliasfail(ptr %ctx) {
entry:
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  store atomic i64 5, ptr %err monotonic, align 8
  ret i1 false
}
define internal i64 @ube.resource.token() {
entry:
  br label %attempt
attempt:
  %old = load atomic i64, ptr @ube.resource.next acquire, align 8
  %exhausted = icmp ugt i64 %old, 2147483647
  br i1 %exhausted, label %failed, label %advance
advance:
  %next = add i64 %old, 1
  %pair = cmpxchg ptr @ube.resource.next, i64 %old, i64 %next acq_rel acquire
  %won = extractvalue { i64, i1 } %pair, 1
  br i1 %won, label %done, label %attempt
done:
  ret i64 %old
failed:
  ret i64 0
}
define internal ptr @ube.resource.reserve(ptr %ctx) {
entry:
  br label %scan
scan:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %slot = call ptr @ube.resource.slot(ptr %ctx, i64 %index)
  %token = load atomic i64, ptr %slot acquire, align 8
  %empty = icmp eq i64 %token, 0
  br i1 %empty, label %claim, label %advance
claim:
  %busy = getelementptr %ube.resource, ptr %slot, i32 0, i32 4
  %pair = cmpxchg ptr %busy, i64 0, i64 1 acq_rel acquire
  %won = extractvalue { i64, i1 } %pair, 1
  br i1 %won, label %check, label %advance
check:
  %again = load atomic i64, ptr %slot acquire, align 8
  %still.empty = icmp eq i64 %again, 0
  br i1 %still.empty, label %done, label %unlock
unlock:
  store atomic i64 0, ptr %busy release, align 8
  br label %advance
advance:
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, 64
  br i1 %more, label %scan, label %failed
done:
  ret ptr %slot
failed:
  ret ptr null
}
define internal void @ube.resource.unlock(ptr %slot) {
entry:
  %busy = getelementptr %ube.resource, ptr %slot, i32 0, i32 4
  store atomic i64 0, ptr %busy release, align 8
  ret void
}
define internal i1 @ube.resource.empty(ptr %ctx) {
entry:
  br label %scan
scan:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %slot = call ptr @ube.resource.slot(ptr %ctx, i64 %index)
  %token = load atomic i64, ptr %slot acquire, align 8
  %busy.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 4
  %busy = load atomic i64, ptr %busy.ptr acquire, align 8
  %occupied = or i64 %token, %busy
  %live = icmp ne i64 %occupied, 0
  br i1 %live, label %failed, label %advance
advance:
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, 64
  br i1 %more, label %scan, label %done
done:
  ret i1 true
failed:
  ret i1 false
}
define internal ptr @ube.resource.acquire(ptr %ctx, i64 %wanted, ptr %failure) {
entry:
  %positive = icmp sgt i64 %wanted, 0
  br i1 %positive, label %scan, label %stale
scan:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %slot = call ptr @ube.resource.slot(ptr %ctx, i64 %index)
  %token = load atomic i64, ptr %slot acquire, align 8
  %matches = icmp eq i64 %token, %wanted
  br i1 %matches, label %claim, label %advance
claim:
  %busy.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 4
  %pair = cmpxchg ptr %busy.ptr, i64 0, i64 1 acq_rel acquire
  %won = extractvalue { i64, i1 } %pair, 1
  br i1 %won, label %check, label %busy
check:
  %again = load atomic i64, ptr %slot acquire, align 8
  %same = icmp eq i64 %again, %wanted
  br i1 %same, label %done, label %unlock
unlock:
  call void @ube.resource.unlock(ptr %slot)
  br label %stale
advance:
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, 64
  br i1 %more, label %scan, label %stale
done:
  ret ptr %slot
busy:
  %busy.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 13, i64 5)
  ret ptr null
stale:
  %stale.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret ptr null
}
define internal void @ube.resource.forget(ptr %ctx, ptr %slot) {
entry:
  %block.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2
  %block = load ptr, ptr %block.ptr
  store ptr null, ptr %block.ptr
  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  store ptr null, ptr %handle.ptr
  store atomic i64 0, ptr %slot release, align 8
  call void @ube.block.drop(ptr %ctx, ptr %block)
  call void @ube.resource.unlock(ptr %slot)
  %collected = call i1 @ube.memory.collect(ptr %ctx)
  ret void
}
define internal i1 @ube.file.overlaps(ptr %array, ptr %output) {
entry:
  %address = ptrtoint ptr %output to i64
  %descriptor = ptrtoint ptr %array to i64
  %desc.after = sub i64 %address, %descriptor
  %desc.before = sub i64 %descriptor, %address
  %desc.inside = icmp ult i64 %desc.after, 32
  %desc.cross = icmp ult i64 %desc.before, 8
  %desc.overlap = or i1 %desc.inside, %desc.cross
  %lower = load atomic i64, ptr %array monotonic, align 8
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %distance = sub i64 %upper, %lower
  %length = add i64 %distance, 1
  %bytes = mul i64 %length, 8
  %nonempty = icmp ne i64 %length, 0
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %data = load ptr, ptr %data.ptr
  %payload = ptrtoint ptr %data to i64
  %data.after = sub i64 %address, %payload
  %data.before = sub i64 %payload, %address
  %data.inside = icmp ult i64 %data.after, %bytes
  %data.cross = icmp ult i64 %data.before, 8
  %data.overlap = or i1 %data.inside, %data.cross
  %occupied = and i1 %nonempty, %data.overlap
  %overlap = or i1 %desc.overlap, %occupied
  ret i1 %overlap
}
define internal i1 @ube.file.open.pinned(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i1 %write) {
entry:
  %mode = select i1 %write, i64 2, i64 1
  %result = call i1 @ube.file.open.mode(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i64 %mode)
  ret i1 %result
}
define internal i1 @ube.file.open(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i1 %write) {
entry:
  %descriptor.path = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %token.out)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %length.out)
  %alias.2 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  %aliases.2 = or i1 %aliases.1, %alias.2
  br i1 %aliases.2, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.path = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %path)
  store { i64, i64, ptr, ptr } %snapshot.path, ptr %descriptor.path
  %pin.path = extractvalue { i64, i64, ptr, ptr } %snapshot.path, 3
  %accepted = call i1 @ube.file.open.pinned(ptr %ctx, ptr %descriptor.path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i1 %write)
  call void @ube.block.drop(ptr %ctx, ptr %pin.path)
  ret i1 %accepted
}
define internal i1 @ube.file.open.mode(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i64 %mode) {
entry:
  %write = icmp eq i64 %mode, 2
  %directory = icmp eq i64 %mode, 3
  %size.out = alloca i64, align 8
  %alias.a = icmp eq ptr %token.out, %length.out
  %alias.b = icmp eq ptr %token.out, %failure
  %alias.c = icmp eq ptr %length.out, %failure
  %null.a = icmp eq ptr %token.out, null
  %null.b = icmp eq ptr %length.out, null
  %null.c = icmp eq ptr %failure, null
  %alias.ab = or i1 %alias.a, %alias.b
  %alias.abc = or i1 %alias.ab, %alias.c
  %null.ab = or i1 %null.a, %null.b
  %null.abc = or i1 %null.ab, %null.c
  %overlap.token = call i1 @ube.file.overlaps(ptr %path, ptr %token.out)
  %overlap.length = call i1 @ube.file.overlaps(ptr %path, ptr %length.out)
  %overlap.failure = call i1 @ube.file.overlaps(ptr %path, ptr %failure)
  %overlap.ab = or i1 %overlap.token, %overlap.length
  %overlap = or i1 %overlap.ab, %overlap.failure
  %scalar.alias = or i1 %alias.abc, %null.abc
  %alias = or i1 %scalar.alias, %overlap
  br i1 %alias, label %alias.fail, label %outputs
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
outputs:
  store atomic i64 0, ptr %length.out monotonic, align 8
  store atomic i64 0, ptr %failure monotonic, align 8
  %old.token = load atomic i64, ptr %token.out monotonic, align 8
  %owned = icmp ne i64 %old.token, 0
  %negative = icmp slt i64 %maximum, 0
  %bad.request = or i1 %owned, %negative
  br i1 %bad.request, label %request.fail, label %path.size
request.fail:
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
path.size:
  %lower = load atomic i64, ptr %path monotonic, align 8
  %upper.ptr = getelementptr i64, ptr %path, i64 1
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %distance = sub i64 %upper, %lower
  %length = add i64 %distance, 1
  %empty = icmp sle i64 %length, 0
  %long = icmp sgt i64 %length, 4096
  %bad.path = or i1 %empty, %long
  br i1 %bad.path, label %path.fail, label %path.data
path.data:
  %data.ptr = getelementptr i64, ptr %path, i64 2
  %data = load ptr, ptr %data.ptr
  br label %scan
scan:
  %index = phi i64 [ 0, %path.data ], [ %next, %advance ]
  %cell = getelementptr i64, ptr %data, i64 %index
  %byte = load atomic i64, ptr %cell monotonic, align 8
  %zero = icmp eq i64 %byte, 0
  br i1 %zero, label %path.fail, label %advance
advance:
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, %length
  br i1 %more, label %scan, label %reserve
path.fail:
  %path.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 2, i64 5)
  ret i1 false
reserve:
  %slot = call ptr @ube.resource.reserve(ptr %ctx)
  %no.slot = icmp eq ptr %slot, null
  br i1 %no.slot, label %allocation.fail, label %identity
identity:
  %token = call i64 @ube.resource.token()
  %exhausted = icmp eq i64 %token, 0
  br i1 %exhausted, label %unreserve, label %allocate
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 8192, i64 1)
  %no.memory = icmp eq ptr %block, null
  br i1 %no.memory, label %unreserve, label %pack.start
unreserve:
  call void @ube.resource.unlock(ptr %slot)
  br label %allocation.fail
allocation.fail:
  %allocation.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 8, i64 7)
  ret i1 false
pack.start:
  %block.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2
  store ptr %block, ptr %block.ptr
  %packed = getelementptr %ube.block, ptr %block, i64 1
  %wide = getelementptr i8, ptr %packed, i64 4096
  br label %pack
pack:
  %pack.index = phi i64 [ 0, %pack.start ], [ %pack.next, %pack ]
  %pack.source = getelementptr i64, ptr %data, i64 %pack.index
  %pack.value = load atomic i64, ptr %pack.source monotonic, align 8
  %pack.byte = trunc i64 %pack.value to i8
  %pack.target = getelementptr i8, ptr %packed, i64 %pack.index
  store volatile i8 %pack.byte, ptr %pack.target
  %pack.next = add i64 %pack.index, 1
  %pack.more = icmp ult i64 %pack.next, %length
  br i1 %pack.more, label %pack, label %convert
convert:
  %length32 = trunc i64 %length to i32
  %wide.length = call i32 @ube.target.file.utf8(ptr %packed, i32 %length32, ptr %wide, i32 4096)
  %wide.bad = icmp sle i32 %wide.length, 0
  %wide.large = icmp sgt i32 %wide.length, 4096
  %wide.invalid = or i1 %wide.bad, %wide.large
  br i1 %wide.invalid, label %conversion.fail, label %open
conversion.fail:
  call void @ube.resource.forget(ptr %ctx, ptr %slot)
  br label %path.fail
open:
  %terminator = getelementptr i16, ptr %wide, i32 %wide.length
  store i16 0, ptr %terminator
  br i1 %directory, label %open.directory, label %open.file
open.directory:
  %directory.handle = call ptr @ube.target.directory.open(ptr %wide)
  br label %opened
open.file:
  %file.handle = call ptr @ube.target.file.open(ptr %wide, i1 %write)
  br label %opened
opened:
  %handle = phi ptr [ %directory.handle, %open.directory ], [ %file.handle, %open.file ]
  %invalid.handle = icmp eq ptr %handle, inttoptr (i64 -1 to ptr)
  %null.handle = icmp eq ptr %handle, null
  %bad.handle = or i1 %invalid.handle, %null.handle
  br i1 %bad.handle, label %open.fail, label %admit
open.fail:
  call void @ube.resource.forget(ptr %ctx, ptr %slot)
  %open.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 57)
  ret i1 false
admit:
  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  store ptr %handle, ptr %handle.ptr
  %mode.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3
  store atomic i64 %mode, ptr %mode.ptr monotonic, align 8
  %kind = call i32 @ube.target.file.type(ptr %handle)
  %regular = icmp eq i32 %kind, 1
  br i1 %regular, label %mode.check, label %query.fail
mode.check:
  br i1 %directory, label %directory.check, label %file.check
directory.check:
  %is.directory = call i1 @ube.target.directory.check(ptr %handle)
  br i1 %is.directory, label %success.create, label %query.fail
file.check:
  br i1 %write, label %success.create, label %query
query:
  store atomic i64 0, ptr %size.out monotonic, align 8
  %queried = call i1 @ube.target.file.size(ptr %handle, ptr %size.out)
  br i1 %queried, label %size.check, label %query.fail
size.check:
  %size = load atomic i64, ptr %size.out monotonic, align 8
  %size.negative = icmp slt i64 %size, 0
  br i1 %size.negative, label %query.fail, label %size.limit
size.limit:
  %too.large = icmp sgt i64 %size, %maximum
  br i1 %too.large, label %limit.fail, label %success.read
query.fail:
  br label %reject
limit.fail:
  br label %reject
reject:
  %failure.code = phi i64 [ 3, %query.fail ], [ 4, %limit.fail ]
  %error.number = phi i64 [ 57, %query.fail ], [ 6, %limit.fail ]
  %closed = call i1 @ube.target.file.close(ptr %handle)
  br i1 %closed, label %rejected, label %retained
rejected:
  call void @ube.resource.forget(ptr %ctx, ptr %slot)
  %reject.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %failure.code, i64 %error.number)
  ret i1 false
retained:
  store atomic i64 %token, ptr %slot release, align 8
  store atomic i64 %token, ptr %token.out monotonic, align 8
  call void @ube.resource.unlock(ptr %slot)
  %close.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 7, i64 57)
  ret i1 false
success.create:
  br label %success
success.read:
  br label %success
success:
  %result.length = phi i64 [ 0, %success.create ], [ %size, %success.read ]
  store atomic i64 %token, ptr %slot release, align 8
  store atomic i64 %token, ptr %token.out monotonic, align 8
  store atomic i64 %result.length, ptr %length.out monotonic, align 8
  call void @ube.resource.unlock(ptr %slot)
  ret i1 true
}
define internal i1 @ube.file.transfer.pinned(ptr %ctx, i64 %token, ptr %array, i64 %start, i64 %count, ptr %progress, ptr %failure, i1 %write) {
entry:
  %native.progress = alloca i32, align 4
  %alias = icmp eq ptr %progress, %failure
  %null.progress = icmp eq ptr %progress, null
  %null.failure = icmp eq ptr %failure, null
  %null.output = or i1 %null.progress, %null.failure
  %overlap.progress = call i1 @ube.file.overlaps(ptr %array, ptr %progress)
  %overlap.failure = call i1 @ube.file.overlaps(ptr %array, ptr %failure)
  %overlap = or i1 %overlap.progress, %overlap.failure
  %bad.scalar = or i1 %alias, %null.output
  %bad.output = or i1 %bad.scalar, %overlap
  br i1 %bad.output, label %alias.fail, label %outputs
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
outputs:
  store atomic i64 0, ptr %progress monotonic, align 8
  store atomic i64 0, ptr %failure monotonic, align 8
  %lower = load atomic i64, ptr %array monotonic, align 8
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %distance = sub i64 %upper, %lower
  %length = add i64 %distance, 1
  %start.negative = icmp slt i64 %start, 0
  %count.negative = icmp slt i64 %count, 0
  %count.large = icmp sgt i64 %count, 65536
  %start.past = icmp sgt i64 %start, %length
  %negative = or i1 %start.negative, %count.negative
  %past = or i1 %count.large, %start.past
  %invalid = or i1 %negative, %past
  br i1 %invalid, label %request.fail, label %range
range:
  %remaining = sub i64 %length, %start
  %past.end = icmp sgt i64 %count, %remaining
  br i1 %past.end, label %request.fail, label %lookup
request.fail:
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
lookup:
  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %mode
mode:
  %mode.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3
  %actual.mode = load atomic i64, ptr %mode.ptr monotonic, align 8
  %wanted.mode = select i1 %write, i64 2, i64 1
  %right.mode = icmp eq i64 %actual.mode, %wanted.mode
  br i1 %right.mode, label %check.empty, label %mode.fail
mode.fail:
  call void @ube.resource.unlock(ptr %slot)
  %mode.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret i1 false
check.empty:
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %empty.success, label %prepare
empty.success:
  call void @ube.resource.unlock(ptr %slot)
  ret i1 true
prepare:
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %data = load ptr, ptr %data.ptr
  %payload = getelementptr i64, ptr %data, i64 %start
  %owner.ptr = getelementptr i64, ptr %array, i64 3
  %owner = load ptr, ptr %owner.ptr
  call void @ube.block.retain(ptr %owner)
  %scratch.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2
  %scratch.block = load ptr, ptr %scratch.ptr
  %scratch = getelementptr %ube.block, ptr %scratch.block, i64 1
  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  %handle = load ptr, ptr %handle.ptr
  %count32 = trunc i64 %count to i32
  store i32 0, ptr %native.progress
  br i1 %write, label %pack, label %read
pack:
  %index = phi i64 [ 0, %prepare ], [ %next, %pack ]
  %source = getelementptr i64, ptr %payload, i64 %index
  %value = load atomic i64, ptr %source monotonic, align 8
  %byte = trunc i64 %value to i8
  %target = getelementptr i8, ptr %scratch, i64 %index
  store volatile i8 %byte, ptr %target
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %pack, label %native.write
native.write:
  %write.ok = call i1 @ube.target.file.write(ptr %handle, ptr %scratch, i32 %count32, ptr %native.progress)
  br label %observed
read:
  %read.ok = call i1 @ube.target.file.read(ptr %handle, ptr %scratch, i32 %count32, ptr %native.progress)
  br label %observed
observed:
  %ok = phi i1 [ %write.ok, %native.write ], [ %read.ok, %read ]
  %done32 = load i32, ptr %native.progress
  %done = zext i32 %done32 to i64
  %bad.progress = icmp ugt i64 %done, %count
  br i1 %bad.progress, label %io.fail, label %publish.mode
publish.mode:
  br i1 %write, label %write.progress, label %read.status
write.progress:
  store atomic i64 %done, ptr %progress monotonic, align 8
  br i1 %ok, label %success, label %io.fail
read.status:
  br i1 %ok, label %read.progress, label %io.fail
read.progress:
  %has.bytes = icmp ne i64 %done, 0
  br i1 %has.bytes, label %unpack, label %read.complete
unpack:
  %read.index = phi i64 [ 0, %read.progress ], [ %read.next, %unpack ]
  %read.source = getelementptr i8, ptr %scratch, i64 %read.index
  %read.byte = load i8, ptr %read.source
  %read.value = zext i8 %read.byte to i64
  %read.target = getelementptr i64, ptr %payload, i64 %read.index
  store atomic volatile i64 %read.value, ptr %read.target monotonic, align 8
  %read.next = add i64 %read.index, 1
  %read.more = icmp ult i64 %read.next, %done
  br i1 %read.more, label %unpack, label %read.complete
read.complete:
  store atomic i64 %done, ptr %progress monotonic, align 8
  br label %success
success:
  call void @ube.block.drop(ptr %ctx, ptr %owner)
  call void @ube.resource.unlock(ptr %slot)
  ret i1 true
io.fail:
  call void @ube.block.drop(ptr %ctx, ptr %owner)
  call void @ube.resource.unlock(ptr %slot)
  %code = select i1 %write, i64 15, i64 5
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %code, i64 57)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.file.transfer(ptr %ctx, i64 %token, ptr %array, i64 %start, i64 %count, ptr %progress, ptr %failure, i1 %write) {
entry:
  %descriptor.array = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %progress)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  br i1 %aliases.1, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.array = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)
  store { i64, i64, ptr, ptr } %snapshot.array, ptr %descriptor.array
  %pin.array = extractvalue { i64, i64, ptr, ptr } %snapshot.array, 3
  %accepted = call i1 @ube.file.transfer.pinned(ptr %ctx, i64 %token, ptr %descriptor.array, i64 %start, i64 %count, ptr %progress, ptr %failure, i1 %write)
  call void @ube.block.drop(ptr %ctx, ptr %pin.array)
  ret i1 %accepted
}
define internal i1 @ube.file.close(ptr %ctx, ptr %token.out, ptr %failure) {
entry:
  %alias = icmp eq ptr %token.out, %failure
  %null.token = icmp eq ptr %token.out, null
  %null.failure = icmp eq ptr %failure, null
  %null.output = or i1 %null.token, %null.failure
  %bad.output = or i1 %alias, %null.output
  br i1 %bad.output, label %alias.fail, label %outputs
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
outputs:
  store atomic i64 0, ptr %failure monotonic, align 8
  %token = load atomic i64, ptr %token.out monotonic, align 8
  %empty = icmp eq i64 %token, 0
  br i1 %empty, label %success, label %lookup
lookup:
  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %kind
kind:
  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3
  %kind.value = load atomic i64, ptr %kind.ptr monotonic, align 8
  %kind.low = icmp sge i64 %kind.value, 1
  %kind.high = icmp sle i64 %kind.value, 3
  %file.kind = and i1 %kind.low, %kind.high
  br i1 %file.kind, label %close, label %kind.fail
kind.fail:
  call void @ube.resource.unlock(ptr %slot)
  %kind.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret i1 false
close:
  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  %handle = load ptr, ptr %handle.ptr
  %closed = call i1 @ube.target.file.close(ptr %handle)
  br i1 %closed, label %released, label %close.fail
released:
  call void @ube.resource.forget(ptr %ctx, ptr %slot)
  store atomic i64 0, ptr %token.out monotonic, align 8
  br label %success
close.fail:
  call void @ube.resource.unlock(ptr %slot)
  %status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 7, i64 57)
  ret i1 false
success:
  ret i1 true
failed:
  ret i1 false
}
define internal i1 @ube.file.flush(ptr %ctx, i64 %token, ptr %failure) {
entry:
  %null.output = icmp eq ptr %failure, null
  br i1 %null.output, label %alias.fail, label %lookup
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
lookup:
  store atomic i64 0, ptr %failure monotonic, align 8
  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %mode
mode:
  %mode.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3
  %actual.mode = load atomic i64, ptr %mode.ptr monotonic, align 8
  %writable = icmp eq i64 %actual.mode, 2
  br i1 %writable, label %flush, label %mode.fail
mode.fail:
  call void @ube.resource.unlock(ptr %slot)
  %mode.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret i1 false
flush:
  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  %handle = load ptr, ptr %handle.ptr
  %ok = call i1 @ube.target.file.flush(ptr %handle)
  call void @ube.resource.unlock(ptr %slot)
  br i1 %ok, label %success, label %flush.fail
flush.fail:
  %flush.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 16, i64 57)
  ret i1 false
success:
  ret i1 true
failed:
  ret i1 false
}
declare dllimport ptr @GetCommandLineW()
declare dllimport ptr @GetStdHandle(i32)
declare dllimport i32 @WideCharToMultiByte(i32, i32, ptr, i32, ptr, i32, ptr, ptr)
define ptr @ube.target.system.commandline() {
entry:
  %result = call ptr @GetCommandLineW()
  ret ptr %result
}
define ptr @ube.target.system.standard(i32 %which) {
entry:
  %result = call ptr @GetStdHandle(i32 %which)
  ret ptr %result
}
define i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %bytes, i32 %capacity) {
entry:
  %result = call i32 @WideCharToMultiByte(i32 65001, i32 128, ptr %wide, i32 %units, ptr %bytes, i32 %capacity, ptr null, ptr null)
  ret i32 %result
}
define internal i1 @ube.system.outputs(ptr %ctx, ptr %array, ptr %count, ptr %failure) {
entry:
  %alias = icmp eq ptr %count, %failure
  %null.count = icmp eq ptr %count, null
  %null.failure = icmp eq ptr %failure, null
  %overlap.count = call i1 @ube.file.overlaps(ptr %array, ptr %count)
  %overlap.failure = call i1 @ube.file.overlaps(ptr %array, ptr %failure)
  %null = or i1 %null.count, %null.failure
  %overlap = or i1 %overlap.count, %overlap.failure
  %bad.scalar = or i1 %alias, %null
  %bad = or i1 %bad.scalar, %overlap
  br i1 %bad, label %failed, label %done
failed:
  %status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
done:
  store atomic i64 0, ptr %failure monotonic, align 8
  ret i1 true
}
define internal i1 @ube.system.commandline.pinned(ptr %ctx, ptr %array, ptr %count, ptr %failure) {
entry:
  %outputs = call i1 @ube.system.outputs(ptr %ctx, ptr %array, ptr %count, ptr %failure)
  br i1 %outputs, label %acquire, label %failed
acquire:
  %wide = call ptr @ube.target.system.commandline()
  %missing = icmp eq ptr %wide, null
  br i1 %missing, label %io.fail, label %scan
scan:
  %index = phi i64 [ 0, %acquire ], [ %next, %advance ]
  %unit.ptr = getelementptr i16, ptr %wide, i64 %index
  %unit = load i16, ptr %unit.ptr
  %end = icmp eq i16 %unit, 0
  br i1 %end, label %length, label %advance
advance:
  %next = add i64 %index, 1
  %bounded = icmp ult i64 %next, 32767
  br i1 %bounded, label %scan, label %request.fail
length:
  %empty = icmp eq i64 %index, 0
  br i1 %empty, label %empty.success, label %measure
empty.success:
  store atomic i64 0, ptr %count monotonic, align 8
  ret i1 true
measure:
  %units = trunc i64 %index to i32
  %size32 = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr null, i32 0)
  %size = sext i32 %size32 to i64
  %lower = load atomic i64, ptr %array monotonic, align 8
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %distance = sub i64 %upper, %lower
  %capacity = add i64 %distance, 1
  %invalid = icmp sle i64 %size, 0
  %large = icmp sgt i64 %size, 131072
  %short = icmp sgt i64 %size, %capacity
  %bad.bound = or i1 %large, %short
  %bad = or i1 %invalid, %bad.bound
  br i1 %bad, label %request.fail, label %allocate
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 16384, i64 1)
  %no.memory = icmp eq ptr %block, null
  br i1 %no.memory, label %memory.fail, label %convert
convert:
  %scratch = getelementptr %ube.block, ptr %block, i64 1
  %converted = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %scratch, i32 131072)
  %complete = icmp eq i32 %converted, %size32
  br i1 %complete, label %prepare, label %conversion.fail
prepare:
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %data = load ptr, ptr %data.ptr
  br label %copy
copy:
  %position = phi i64 [ 0, %prepare ], [ %after, %copy ]
  %source = getelementptr i8, ptr %scratch, i64 %position
  %byte = load i8, ptr %source
  %value = zext i8 %byte to i64
  %destination = getelementptr i64, ptr %data, i64 %position
  store atomic volatile i64 %value, ptr %destination monotonic, align 8
  %after = add i64 %position, 1
  %more = icmp ult i64 %after, %size
  br i1 %more, label %copy, label %success
success:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  store atomic i64 %size, ptr %count monotonic, align 8
  ret i1 true
conversion.fail:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  br label %io.fail
request.fail:
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
memory.fail:
  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)
  ret i1 false
io.fail:
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.system.commandline(ptr %ctx, ptr %array, ptr %count, ptr %failure) {
entry:
  %descriptor.array = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %count)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  br i1 %aliases.1, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.array = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)
  store { i64, i64, ptr, ptr } %snapshot.array, ptr %descriptor.array
  %pin.array = extractvalue { i64, i64, ptr, ptr } %snapshot.array, 3
  %accepted = call i1 @ube.system.commandline.pinned(ptr %ctx, ptr %descriptor.array, ptr %count, ptr %failure)
  call void @ube.block.drop(ptr %ctx, ptr %pin.array)
  ret i1 %accepted
}
define internal i1 @ube.system.write.pinned(ptr %ctx, i64 %stream, ptr %array, i64 %start, i64 %count, ptr %written, ptr %failure) {
entry:
  %progress = alloca i32, align 4
  %outputs = call i1 @ube.system.outputs(ptr %ctx, ptr %array, ptr %written, ptr %failure)
  br i1 %outputs, label %validate, label %failed
validate:
  store atomic i64 0, ptr %written monotonic, align 8
  %stdout = icmp eq i64 %stream, 1
  %stderr = icmp eq i64 %stream, 2
  %stream.ok = or i1 %stdout, %stderr
  %lower = load atomic i64, ptr %array monotonic, align 8
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %distance = sub i64 %upper, %lower
  %length = add i64 %distance, 1
  %start.bad = icmp ult i64 %length, %start
  %count.bad = icmp ugt i64 %count, 65536
  %bad.range = or i1 %start.bad, %count.bad
  %range.ok = xor i1 %bad.range, true
  %request.ok = and i1 %stream.ok, %range.ok
  br i1 %request.ok, label %range, label %request.fail
range:
  %remaining = sub i64 %length, %start
  %past.end = icmp ugt i64 %count, %remaining
  br i1 %past.end, label %request.fail, label %handle
handle:
  %which = select i1 %stdout, i32 -11, i32 -12
  %native.handle = call ptr @ube.target.system.standard(i32 %which)
  %null = icmp eq ptr %native.handle, null
  %invalid = icmp eq ptr %native.handle, inttoptr (i64 -1 to ptr)
  %bad.handle = or i1 %null, %invalid
  br i1 %bad.handle, label %io.fail, label %empty.check
empty.check:
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %empty.success, label %allocate
empty.success:
  ret i1 true
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 8192, i64 1)
  %no.memory = icmp eq ptr %block, null
  br i1 %no.memory, label %memory.fail, label %prepare
prepare:
  %scratch = getelementptr %ube.block, ptr %block, i64 1
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %data = load ptr, ptr %data.ptr
  %source.base = getelementptr i64, ptr %data, i64 %start
  br label %pack
pack:
  %index = phi i64 [ 0, %prepare ], [ %next, %pack ]
  %source = getelementptr i64, ptr %source.base, i64 %index
  %value = load atomic i64, ptr %source monotonic, align 8
  %byte = trunc i64 %value to i8
  %destination = getelementptr i8, ptr %scratch, i64 %index
  store volatile i8 %byte, ptr %destination
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %pack, label %write
write:
  store i32 0, ptr %progress
  %count32 = trunc i64 %count to i32
  %accepted = call i1 @ube.target.file.write(ptr %native.handle, ptr %scratch, i32 %count32, ptr %progress)
  %done32 = load i32, ptr %progress
  %done = zext i32 %done32 to i64
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %bad.progress = icmp ugt i64 %done, %count
  br i1 %bad.progress, label %io.fail, label %publish
publish:
  store atomic i64 %done, ptr %written monotonic, align 8
  br i1 %accepted, label %success, label %io.fail
success:
  ret i1 true
request.fail:
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
memory.fail:
  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)
  ret i1 false
io.fail:
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 15, i64 57)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.system.write(ptr %ctx, i64 %stream, ptr %array, i64 %start, i64 %count, ptr %written, ptr %failure) {
entry:
  %descriptor.array = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %written)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  br i1 %aliases.1, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.array = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)
  store { i64, i64, ptr, ptr } %snapshot.array, ptr %descriptor.array
  %pin.array = extractvalue { i64, i64, ptr, ptr } %snapshot.array, 3
  %accepted = call i1 @ube.system.write.pinned(ptr %ctx, i64 %stream, ptr %descriptor.array, i64 %start, i64 %count, ptr %written, ptr %failure)
  call void @ube.block.drop(ptr %ctx, ptr %pin.array)
  ret i1 %accepted
}
declare dllimport i32 @GetFullPathNameW(ptr, i32, ptr, ptr)
declare dllimport i32 @GetFinalPathNameByHandleW(ptr, ptr, i32, i32)
declare dllimport i32 @CompareStringOrdinal(ptr, i32, ptr, i32, i32)
define i32 @ube.target.path.full(ptr %input, ptr %output, i32 %capacity) {
entry:
  %result = call i32 @GetFullPathNameW(ptr %input, i32 %capacity, ptr %output, ptr null)
  ret i32 %result
}
define i32 @ube.target.path.final(ptr %handle, ptr %output, i32 %capacity) {
entry:
  %result = call i32 @GetFinalPathNameByHandleW(ptr %handle, ptr %output, i32 %capacity, i32 0)
  ret i32 %result
}
define i32 @ube.target.path.compare(ptr %first, i32 %first.length, ptr %second, i32 %second.length) {
entry:
  %result = call i32 @CompareStringOrdinal(ptr %first, i32 %first.length, ptr %second, i32 %second.length, i32 1)
  ret i32 %result
}
define internal i1 @ube.path.outputs(ptr %ctx, ptr %first, ptr %second, ptr %value, ptr %failure) {
entry:
  %alias = icmp eq ptr %value, %failure
  %null.value = icmp eq ptr %value, null
  %null.failure = icmp eq ptr %failure, null
  %first.value = call i1 @ube.file.overlaps(ptr %first, ptr %value)
  %first.failure = call i1 @ube.file.overlaps(ptr %first, ptr %failure)
  %second.value = call i1 @ube.file.overlaps(ptr %second, ptr %value)
  %second.failure = call i1 @ube.file.overlaps(ptr %second, ptr %failure)
  %null = or i1 %null.value, %null.failure
  %first.overlap = or i1 %first.value, %first.failure
  %second.overlap = or i1 %second.value, %second.failure
  %overlap = or i1 %first.overlap, %second.overlap
  %bad.scalar = or i1 %alias, %null
  %bad = or i1 %bad.scalar, %overlap
  br i1 %bad, label %failed, label %done
failed:
  %status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
done:
  store atomic i64 0, ptr %failure monotonic, align 8
  ret i1 true
}
define internal i32 @ube.path.decode(ptr %array, ptr %packed, ptr %wide) {
entry:
  %lower = load atomic i64, ptr %array monotonic, align 8
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %distance = sub i64 %upper, %lower
  %length = add i64 %distance, 1
  %large = icmp ugt i64 %length, 4096
  br i1 %large, label %failed, label %empty.check
empty.check:
  %empty = icmp eq i64 %length, 0
  br i1 %empty, label %empty.done, label %prepare
empty.done:
  store i16 0, ptr %wide
  ret i32 0
prepare:
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %data = load ptr, ptr %data.ptr
  br label %pack
pack:
  %index = phi i64 [ 0, %prepare ], [ %next, %copy ]
  %source = getelementptr i64, ptr %data, i64 %index
  %value = load atomic i64, ptr %source monotonic, align 8
  %zero = icmp eq i64 %value, 0
  br i1 %zero, label %failed, label %copy
copy:
  %byte = trunc i64 %value to i8
  %destination = getelementptr i8, ptr %packed, i64 %index
  store volatile i8 %byte, ptr %destination
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, %length
  br i1 %more, label %pack, label %convert
convert:
  %bytes = trunc i64 %length to i32
  %units = call i32 @ube.target.file.utf8(ptr %packed, i32 %bytes, ptr %wide, i32 4096)
  %valid = icmp sgt i32 %units, 0
  br i1 %valid, label %done, label %failed
done:
  %units64 = zext i32 %units to i64
  %terminator = getelementptr i16, ptr %wide, i64 %units64
  store i16 0, ptr %terminator
  ret i32 %units
failed:
  ret i32 -1
}
define internal i1 @ube.path.publish(ptr %ctx, ptr %wide, i32 %units, ptr %array, ptr %count, ptr %failure, ptr %packed) {
entry:
  %size32 = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr null, i32 0)
  %size = sext i32 %size32 to i64
  %lower = load atomic i64, ptr %array monotonic, align 8
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %distance = sub i64 %upper, %lower
  %capacity = add i64 %distance, 1
  %invalid = icmp sle i64 %size, 0
  %large = icmp sgt i64 %size, 4096
  %short = icmp sgt i64 %size, %capacity
  %bad.bound = or i1 %large, %short
  %bad = or i1 %invalid, %bad.bound
  br i1 %bad, label %request.fail, label %convert
convert:
  %converted = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %packed, i32 4096)
  %complete = icmp eq i32 %converted, %size32
  br i1 %complete, label %prepare, label %io.fail
prepare:
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %data = load ptr, ptr %data.ptr
  br label %copy
copy:
  %position = phi i64 [ 0, %prepare ], [ %after, %copy ]
  %source = getelementptr i8, ptr %packed, i64 %position
  %byte = load i8, ptr %source
  %value = zext i8 %byte to i64
  %destination = getelementptr i64, ptr %data, i64 %position
  store atomic volatile i64 %value, ptr %destination monotonic, align 8
  %after = add i64 %position, 1
  %more = icmp ult i64 %after, %size
  br i1 %more, label %copy, label %done
done:
  store atomic i64 %size, ptr %count monotonic, align 8
  ret i1 true
request.fail:
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
io.fail:
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
}
define internal void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot) {
entry:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %owned = icmp ne ptr %slot, null
  br i1 %owned, label %unlock, label %done
unlock:
  call void @ube.resource.unlock(ptr %slot)
  br label %done
done:
  ret void
}
define internal i1 @ube.path.resolve.pinned(ptr %ctx, ptr %input, i64 %token, ptr %output, ptr %count, ptr %failure, i1 %final) {
entry:
  %first = select i1 %final, ptr %output, ptr %input
  %outputs = call i1 @ube.path.outputs(ptr %ctx, ptr %first, ptr %output, ptr %count, ptr %failure)
  br i1 %outputs, label %choose, label %failed
choose:
  br i1 %final, label %acquire, label %allocate
acquire:
  %acquired = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %acquired, null
  br i1 %missing, label %failed, label %kind
kind:
  %kind.ptr = getelementptr %ube.resource, ptr %acquired, i32 0, i32 3
  %kind.value = load atomic i64, ptr %kind.ptr monotonic, align 8
  %kind.low = icmp sge i64 %kind.value, 1
  %kind.high = icmp sle i64 %kind.value, 3
  %file.kind = and i1 %kind.low, %kind.high
  br i1 %file.kind, label %allocate, label %kind.fail
kind.fail:
  call void @ube.resource.unlock(ptr %acquired)
  %kind.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret i1 false
allocate:
  %slot = phi ptr [ null, %choose ], [ %acquired, %kind ]
  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)
  %no.memory = icmp eq ptr %block, null
  br i1 %no.memory, label %memory.fail, label %prepare
prepare:
  %scratch = getelementptr %ube.block, ptr %block, i64 1
  %wide.input = getelementptr i8, ptr %scratch, i64 4096
  %wide.output = getelementptr i8, ptr %scratch, i64 20480
  %packed.output = getelementptr i8, ptr %scratch, i64 32768
  br i1 %final, label %physical, label %decode
physical:
  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  %handle = load ptr, ptr %handle.ptr
  %physical.length = call i32 @ube.target.path.final(ptr %handle, ptr %wide.output, i32 4097)
  br label %length
decode:
  %input.length = call i32 @ube.path.decode(ptr %input, ptr %scratch, ptr %wide.input)
  %input.valid = icmp sgt i32 %input.length, 0
  br i1 %input.valid, label %full, label %request.fail
full:
  %full.length = call i32 @ube.target.path.full(ptr %wide.input, ptr %wide.output, i32 4097)
  br label %length
length:
  %units = phi i32 [ %physical.length, %physical ], [ %full.length, %full ]
  %missing.length = icmp eq i32 %units, 0
  br i1 %missing.length, label %io.fail, label %bound
bound:
  %excessive = icmp ugt i32 %units, 4096
  br i1 %excessive, label %request.fail, label %publish
publish:
  %result = call i1 @ube.path.publish(ptr %ctx, ptr %wide.output, i32 %units, ptr %output, ptr %count, ptr %failure, ptr %packed.output)
  call void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot)
  ret i1 %result
memory.fail:
  call void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot)
  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)
  ret i1 false
request.fail:
  call void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot)
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
io.fail:
  call void @ube.path.finish(ptr %ctx, ptr %block, ptr %slot)
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.path.resolve(ptr %ctx, ptr %input, i64 %token, ptr %output, ptr %count, ptr %failure, i1 %final) {
entry:
  %descriptor.input = alloca { i64, i64, ptr, ptr }, align 8
  %descriptor.output = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %input, ptr %count)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %input, ptr %failure)
  %alias.2 = call i1 @ube.array.descriptor.overlaps(ptr %output, ptr %count)
  %alias.3 = call i1 @ube.array.descriptor.overlaps(ptr %output, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  %aliases.2 = or i1 %aliases.1, %alias.2
  %aliases.3 = or i1 %aliases.2, %alias.3
  br i1 %aliases.3, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.input = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %input)
  store { i64, i64, ptr, ptr } %snapshot.input, ptr %descriptor.input
  %pin.input = extractvalue { i64, i64, ptr, ptr } %snapshot.input, 3
  %snapshot.output = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %output)
  store { i64, i64, ptr, ptr } %snapshot.output, ptr %descriptor.output
  %pin.output = extractvalue { i64, i64, ptr, ptr } %snapshot.output, 3
  %same.output.input = icmp eq ptr %output, %input
  %selected.output.input = select i1 %same.output.input, ptr %descriptor.input, ptr %descriptor.output
  %accepted = call i1 @ube.path.resolve.pinned(ptr %ctx, ptr %descriptor.input, i64 %token, ptr %selected.output.input, ptr %count, ptr %failure, i1 %final)
  call void @ube.block.drop(ptr %ctx, ptr %pin.input)
  call void @ube.block.drop(ptr %ctx, ptr %pin.output)
  ret i1 %accepted
}
define internal i1 @ube.path.compare.pinned(ptr %ctx, ptr %first, ptr %second, ptr %ordering, ptr %failure) {
entry:
  %outputs = call i1 @ube.path.outputs(ptr %ctx, ptr %first, ptr %second, ptr %ordering, ptr %failure)
  br i1 %outputs, label %allocate, label %failed
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)
  %no.memory = icmp eq ptr %block, null
  br i1 %no.memory, label %memory.fail, label %prepare
prepare:
  %scratch = getelementptr %ube.block, ptr %block, i64 1
  %wide.first = getelementptr i8, ptr %scratch, i64 4096
  %packed.second = getelementptr i8, ptr %scratch, i64 16384
  %wide.second = getelementptr i8, ptr %scratch, i64 20480
  %first.length = call i32 @ube.path.decode(ptr %first, ptr %scratch, ptr %wide.first)
  %first.invalid = icmp slt i32 %first.length, 0
  br i1 %first.invalid, label %request.fail, label %second.decode
second.decode:
  %second.length = call i32 @ube.path.decode(ptr %second, ptr %packed.second, ptr %wide.second)
  %second.invalid = icmp slt i32 %second.length, 0
  br i1 %second.invalid, label %request.fail, label %empty.check
empty.check:
  %first.empty = icmp eq i32 %first.length, 0
  %second.empty = icmp eq i32 %second.length, 0
  %any.empty = or i1 %first.empty, %second.empty
  br i1 %any.empty, label %empty, label %compare
empty:
  %same = icmp eq i32 %first.length, %second.length
  %different = select i1 %first.empty, i64 -1, i64 1
  %empty.value = select i1 %same, i64 0, i64 %different
  br label %publish
compare:
  %comparison = call i32 @ube.target.path.compare(ptr %wide.first, i32 %first.length, ptr %wide.second, i32 %second.length)
  %too.low = icmp slt i32 %comparison, 1
  %too.high = icmp sgt i32 %comparison, 3
  %invalid = or i1 %too.low, %too.high
  br i1 %invalid, label %io.fail, label %normalize
normalize:
  %normalized = sub i32 %comparison, 2
  %value = sext i32 %normalized to i64
  br label %publish
publish:
  %result = phi i64 [ %empty.value, %empty ], [ %value, %normalize ]
  store atomic i64 %result, ptr %ordering monotonic, align 8
  call void @ube.block.drop(ptr %ctx, ptr %block)
  ret i1 true
memory.fail:
  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)
  ret i1 false
request.fail:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
io.fail:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.path.compare(ptr %ctx, ptr %first, ptr %second, ptr %ordering, ptr %failure) {
entry:
  %descriptor.first = alloca { i64, i64, ptr, ptr }, align 8
  %descriptor.second = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %first, ptr %ordering)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %first, ptr %failure)
  %alias.2 = call i1 @ube.array.descriptor.overlaps(ptr %second, ptr %ordering)
  %alias.3 = call i1 @ube.array.descriptor.overlaps(ptr %second, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  %aliases.2 = or i1 %aliases.1, %alias.2
  %aliases.3 = or i1 %aliases.2, %alias.3
  br i1 %aliases.3, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.first = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %first)
  store { i64, i64, ptr, ptr } %snapshot.first, ptr %descriptor.first
  %pin.first = extractvalue { i64, i64, ptr, ptr } %snapshot.first, 3
  %snapshot.second = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %second)
  store { i64, i64, ptr, ptr } %snapshot.second, ptr %descriptor.second
  %pin.second = extractvalue { i64, i64, ptr, ptr } %snapshot.second, 3
  %same.second.first = icmp eq ptr %second, %first
  %selected.second.first = select i1 %same.second.first, ptr %descriptor.first, ptr %descriptor.second
  %accepted = call i1 @ube.path.compare.pinned(ptr %ctx, ptr %descriptor.first, ptr %selected.second.first, ptr %ordering, ptr %failure)
  call void @ube.block.drop(ptr %ctx, ptr %pin.first)
  call void @ube.block.drop(ptr %ctx, ptr %pin.second)
  ret i1 %accepted
}
declare dllimport i32 @GetFileInformationByHandle(ptr, ptr)
define ptr @ube.target.directory.open(ptr %path) {
entry:
  %handle = call ptr @CreateFileW(ptr %path, i32 128, i32 7, ptr null, i32 3, i32 33554432, ptr null)
  ret ptr %handle
}
define i1 @ube.target.file.info(ptr %handle, ptr %information) {
entry:
  %status = call i32 @GetFileInformationByHandle(ptr %handle, ptr %information)
  %ok = icmp ne i32 %status, 0
  ret i1 %ok
}
define internal i1 @ube.target.directory.check(ptr %handle) {
entry:
  %information = alloca [52 x i8], align 4
  %accepted = call i1 @ube.target.file.info(ptr %handle, ptr %information)
  br i1 %accepted, label %inspect, label %failed
inspect:
  %attributes = load i32, ptr %information
  %directory = and i32 %attributes, 16
  %ok = icmp ne i32 %directory, 0
  ret i1 %ok
failed:
  ret i1 false
}
define internal i1 @ube.directory.open.pinned(ptr %ctx, ptr %path, ptr %token, ptr %failure) {
entry:
  %length = alloca i64, align 8
  %result = call i1 @ube.file.open.mode(ptr %ctx, ptr %path, i64 0, ptr %token, ptr %length, ptr %failure, i64 3)
  ret i1 %result
}
define internal i1 @ube.directory.open(ptr %ctx, ptr %path, ptr %token, ptr %failure) {
entry:
  %descriptor.path = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %token)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  br i1 %aliases.1, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.path = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %path)
  store { i64, i64, ptr, ptr } %snapshot.path, ptr %descriptor.path
  %pin.path = extractvalue { i64, i64, ptr, ptr } %snapshot.path, 3
  %accepted = call i1 @ube.directory.open.pinned(ptr %ctx, ptr %descriptor.path, ptr %token, ptr %failure)
  call void @ube.block.drop(ptr %ctx, ptr %pin.path)
  ret i1 %accepted
}
define internal i1 @ube.file.identity.pinned(ptr %ctx, i64 %token, ptr %array, ptr %failure) {
entry:
  %information = alloca [52 x i8], align 4
  %null = icmp eq ptr %failure, null
  %overlap = call i1 @ube.file.overlaps(ptr %array, ptr %failure)
  %bad.output = or i1 %null, %overlap
  br i1 %bad.output, label %alias.fail, label %capacity
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
capacity:
  store atomic i64 0, ptr %failure monotonic, align 8
  %lower = load atomic i64, ptr %array monotonic, align 8
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %distance = sub i64 %upper, %lower
  %length = add i64 %distance, 1
  %short = icmp slt i64 %length, 12
  br i1 %short, label %request.fail, label %acquire
request.fail:
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
acquire:
  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %kind
kind:
  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3
  %kind.value = load atomic i64, ptr %kind.ptr monotonic, align 8
  %kind.low = icmp sge i64 %kind.value, 1
  %kind.high = icmp sle i64 %kind.value, 3
  %right.kind = and i1 %kind.low, %kind.high
  br i1 %right.kind, label %query, label %kind.fail
kind.fail:
  call void @ube.resource.unlock(ptr %slot)
  %kind.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret i1 false
query:
  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  %handle = load ptr, ptr %handle.ptr
  %accepted = call i1 @ube.target.file.info(ptr %handle, ptr %information)
  br i1 %accepted, label %prepare, label %io.fail
prepare:
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %data = load ptr, ptr %data.ptr
  br label %copy
copy:
  %index = phi i64 [ 0, %prepare ], [ %next, %copy ]
  %volume = icmp ult i64 %index, 4
  %base = select i1 %volume, i64 28, i64 40
  %offset = add i64 %base, %index
  %source = getelementptr i8, ptr %information, i64 %offset
  %byte = load i8, ptr %source
  %value = zext i8 %byte to i64
  %destination = getelementptr i64, ptr %data, i64 %index
  store atomic volatile i64 %value, ptr %destination monotonic, align 8
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, 12
  br i1 %more, label %copy, label %done
done:
  call void @ube.resource.unlock(ptr %slot)
  ret i1 true
io.fail:
  call void @ube.resource.unlock(ptr %slot)
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.file.identity(ptr %ctx, i64 %token, ptr %array, ptr %failure) {
entry:
  %descriptor.array = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %array, ptr %failure)
  br i1 %alias.0, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.array = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %array)
  store { i64, i64, ptr, ptr } %snapshot.array, ptr %descriptor.array
  %pin.array = extractvalue { i64, i64, ptr, ptr } %snapshot.array, 3
  %accepted = call i1 @ube.file.identity.pinned(ptr %ctx, i64 %token, ptr %descriptor.array, ptr %failure)
  call void @ube.block.drop(ptr %ctx, ptr %pin.array)
  ret i1 %accepted
}
define internal i1 @ube.file.length(ptr %ctx, i64 %token, ptr %length, ptr %failure) {
entry:
  %size = alloca i64, align 8
  %alias = icmp eq ptr %length, %failure
  %null.length = icmp eq ptr %length, null
  %null.failure = icmp eq ptr %failure, null
  %null = or i1 %null.length, %null.failure
  %bad.output = or i1 %alias, %null
  br i1 %bad.output, label %alias.fail, label %acquire
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
acquire:
  store atomic i64 0, ptr %failure monotonic, align 8
  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %kind
kind:
  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3
  %kind.value = load atomic i64, ptr %kind.ptr monotonic, align 8
  %kind.low = icmp sge i64 %kind.value, 1
  %kind.high = icmp sle i64 %kind.value, 2
  %right.kind = and i1 %kind.low, %kind.high
  br i1 %right.kind, label %query, label %kind.fail
kind.fail:
  call void @ube.resource.unlock(ptr %slot)
  %kind.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret i1 false
query:
  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  %handle = load ptr, ptr %handle.ptr
  store atomic i64 0, ptr %size monotonic, align 8
  %accepted = call i1 @ube.target.file.size(ptr %handle, ptr %size)
  br i1 %accepted, label %range, label %io.fail
range:
  %value = load atomic i64, ptr %size monotonic, align 8
  %invalid = icmp ugt i64 %value, 2147483647
  br i1 %invalid, label %range.fail, label %done
done:
  store atomic i64 %value, ptr %length monotonic, align 8
  call void @ube.resource.unlock(ptr %slot)
  ret i1 true
range.fail:
  call void @ube.resource.unlock(ptr %slot)
  %range.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 4, i64 6)
  ret i1 false
io.fail:
  call void @ube.resource.unlock(ptr %slot)
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
failed:
  ret i1 false
}
declare dllimport i32 @GetModuleFileNameW(ptr, ptr, i32)
declare dllimport i64 @GetTickCount64()
define i32 @ube.target.system.executable(ptr %output, i32 %capacity) {
entry:
  %length = call i32 @GetModuleFileNameW(ptr null, ptr %output, i32 %capacity)
  ret i32 %length
}
define i64 @ube.target.system.clock() {
entry:
  %value = call i64 @GetTickCount64()
  ret i64 %value
}
define internal i1 @ube.system.executable.pinned(ptr %ctx, ptr %output, ptr %count, ptr %failure) {
entry:
  %outputs = call i1 @ube.system.outputs(ptr %ctx, ptr %output, ptr %count, ptr %failure)
  br i1 %outputs, label %allocate, label %failed
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)
  %missing = icmp eq ptr %block, null
  br i1 %missing, label %memory.fail, label %query
query:
  %scratch = getelementptr %ube.block, ptr %block, i64 1
  %wide = getelementptr i8, ptr %scratch, i64 20480
  %packed = getelementptr i8, ptr %scratch, i64 32768
  %units = call i32 @ube.target.system.executable(ptr %wide, i32 4097)
  %empty = icmp eq i32 %units, 0
  br i1 %empty, label %io.fail, label %range
range:
  %large = icmp ugt i32 %units, 4096
  br i1 %large, label %request.fail, label %publish
publish:
  %result = call i1 @ube.path.publish(ptr %ctx, ptr %wide, i32 %units, ptr %output, ptr %count, ptr %failure, ptr %packed)
  call void @ube.block.drop(ptr %ctx, ptr %block)
  ret i1 %result
memory.fail:
  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)
  ret i1 false
io.fail:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
request.fail:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.system.executable(ptr %ctx, ptr %output, ptr %count, ptr %failure) {
entry:
  %descriptor.output = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %output, ptr %count)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %output, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  br i1 %aliases.1, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.output = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %output)
  store { i64, i64, ptr, ptr } %snapshot.output, ptr %descriptor.output
  %pin.output = extractvalue { i64, i64, ptr, ptr } %snapshot.output, 3
  %accepted = call i1 @ube.system.executable.pinned(ptr %ctx, ptr %descriptor.output, ptr %count, ptr %failure)
  call void @ube.block.drop(ptr %ctx, ptr %pin.output)
  ret i1 %accepted
}
define internal i1 @ube.system.clock(ptr %ctx, ptr %value, ptr %failure) {
entry:
  %alias = icmp eq ptr %value, %failure
  %null.value = icmp eq ptr %value, null
  %null.failure = icmp eq ptr %failure, null
  %null = or i1 %null.value, %null.failure
  %bad.output = or i1 %alias, %null
  br i1 %bad.output, label %alias.fail, label %query
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
query:
  %ticks = call i64 @ube.target.system.clock()
  store atomic i64 %ticks, ptr %value monotonic, align 8
  store atomic i64 0, ptr %failure monotonic, align 8
  ret i1 true
}
declare dllimport i32 @GetLastError()
declare dllimport i32 @CreateDirectoryW(ptr, ptr)
declare dllimport i32 @RemoveDirectoryW(ptr)
declare dllimport i32 @DeleteFileW(ptr)
declare dllimport i32 @MoveFileExW(ptr, ptr, i32)
declare dllimport i32 @GetFileAttributesW(ptr)
define internal i64 @ube.target.path.error(i32 %accepted) {
entry:
  %ok = icmp ne i32 %accepted, 0
  br i1 %ok, label %done, label %failed
done:
  ret i64 0
failed:
  %error32 = call i32 @GetLastError()
  %error = zext i32 %error32 to i64
  %empty = icmp eq i64 %error, 0
  %result = select i1 %empty, i64 1, i64 %error
  ret i64 %result
}
define i64 @ube.target.directory.create(ptr %path) {
entry:
  %accepted = call i32 @CreateDirectoryW(ptr %path, ptr null)
  %error = call i64 @ube.target.path.error(i32 %accepted)
  ret i64 %error
}
define i64 @ube.target.directory.remove(ptr %path) {
entry:
  %accepted = call i32 @RemoveDirectoryW(ptr %path)
  %error = call i64 @ube.target.path.error(i32 %accepted)
  ret i64 %error
}
define i64 @ube.target.file.delete(ptr %path) {
entry:
  %accepted = call i32 @DeleteFileW(ptr %path)
  %error = call i64 @ube.target.path.error(i32 %accepted)
  ret i64 %error
}
define i64 @ube.target.file.replace(ptr %source, ptr %destination) {
entry:
  %accepted = call i32 @MoveFileExW(ptr %source, ptr %destination, i32 9)
  %error = call i64 @ube.target.path.error(i32 %accepted)
  ret i64 %error
}
define i64 @ube.target.path.attributes(ptr %path) {
entry:
  %attributes = call i32 @GetFileAttributesW(ptr %path)
  %invalid = icmp eq i32 %attributes, -1
  br i1 %invalid, label %failed, label %done
done:
  %value = zext i32 %attributes to i64
  ret i64 %value
failed:
  %error = call i64 @ube.target.path.error(i32 0)
  %negative = sub i64 0, %error
  ret i64 %negative
}
define internal i1 @ube.path.mutate.pinned(ptr %ctx, ptr %first, ptr %second, ptr %failure, i64 %operation) {
entry:
  %replace = icmp eq i64 %operation, 4
  %other = select i1 %replace, ptr %second, ptr %first
  %null = icmp eq ptr %failure, null
  %first.overlap = call i1 @ube.file.overlaps(ptr %first, ptr %failure)
  %second.overlap = call i1 @ube.file.overlaps(ptr %other, ptr %failure)
  %overlap = or i1 %first.overlap, %second.overlap
  %bad.output = or i1 %null, %overlap
  br i1 %bad.output, label %alias.fail, label %allocate
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
allocate:
  store atomic i64 0, ptr %failure monotonic, align 8
  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)
  %missing = icmp eq ptr %block, null
  br i1 %missing, label %memory.fail, label %prepare
prepare:
  %scratch = getelementptr %ube.block, ptr %block, i64 1
  %wide.first = getelementptr i8, ptr %scratch, i64 4096
  %packed.second = getelementptr i8, ptr %scratch, i64 16384
  %wide.second = getelementptr i8, ptr %scratch, i64 20480
  %first.length = call i32 @ube.path.decode(ptr %first, ptr %scratch, ptr %wide.first)
  %first.valid = icmp sgt i32 %first.length, 0
  br i1 %first.valid, label %select, label %request.fail
select:
  br i1 %replace, label %second.decode, label %create.check
second.decode:
  %second.length = call i32 @ube.path.decode(ptr %second, ptr %packed.second, ptr %wide.second)
  %second.valid = icmp sgt i32 %second.length, 0
  br i1 %second.valid, label %move, label %request.fail
move:
  %move.error = call i64 @ube.target.file.replace(ptr %wide.first, ptr %wide.second)
  br label %result
create.check:
  %create = icmp eq i64 %operation, 1
  br i1 %create, label %create.directory, label %remove.check
create.directory:
  %create.error = call i64 @ube.target.directory.create(ptr %wide.first)
  br label %result
remove.check:
  %directory = icmp eq i64 %operation, 2
  br i1 %directory, label %remove.directory, label %delete.file
remove.directory:
  %remove.error = call i64 @ube.target.directory.remove(ptr %wide.first)
  br label %result
delete.file:
  %delete.error = call i64 @ube.target.file.delete(ptr %wide.first)
  br label %result
result:
  %error = phi i64 [ %move.error, %move ], [ %create.error, %create.directory ], [ %remove.error, %remove.directory ], [ %delete.error, %delete.file ]
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %success = icmp eq i64 %error, 0
  br i1 %success, label %done, label %classify
classify:
  %file.exists = icmp eq i64 %error, 80
  %directory.exists = icmp eq i64 %error, 183
  %exists = or i1 %file.exists, %directory.exists
  %creating = icmp eq i64 %operation, 1
  %collision = and i1 %exists, %creating
  %file.missing = icmp eq i64 %error, 2
  %path.missing = icmp eq i64 %error, 3
  %absent = or i1 %file.missing, %path.missing
  %code.absence = select i1 %absent, i64 18, i64 5
  %number.absence = select i1 %absent, i64 53, i64 57
  %code = select i1 %collision, i64 17, i64 %code.absence
  %number = select i1 %collision, i64 58, i64 %number.absence
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %code, i64 %number)
  ret i1 false
done:
  ret i1 true
memory.fail:
  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)
  ret i1 false
request.fail:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
}
define internal i1 @ube.path.mutate(ptr %ctx, ptr %first, ptr %second, ptr %failure, i64 %operation) {
entry:
  %descriptor.first = alloca { i64, i64, ptr, ptr }, align 8
  %descriptor.second = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %first, ptr %failure)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %second, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  br i1 %aliases.1, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.first = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %first)
  store { i64, i64, ptr, ptr } %snapshot.first, ptr %descriptor.first
  %pin.first = extractvalue { i64, i64, ptr, ptr } %snapshot.first, 3
  %snapshot.second = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %second)
  store { i64, i64, ptr, ptr } %snapshot.second, ptr %descriptor.second
  %pin.second = extractvalue { i64, i64, ptr, ptr } %snapshot.second, 3
  %same.second.first = icmp eq ptr %second, %first
  %selected.second.first = select i1 %same.second.first, ptr %descriptor.first, ptr %descriptor.second
  %accepted = call i1 @ube.path.mutate.pinned(ptr %ctx, ptr %descriptor.first, ptr %selected.second.first, ptr %failure, i64 %operation)
  call void @ube.block.drop(ptr %ctx, ptr %pin.first)
  call void @ube.block.drop(ptr %ctx, ptr %pin.second)
  ret i1 %accepted
}
define internal i1 @ube.directory.create(ptr %ctx, ptr %path, ptr %failure) {
entry:
  %result = call i1 @ube.path.mutate(ptr %ctx, ptr %path, ptr null, ptr %failure, i64 1)
  ret i1 %result
}
define internal i1 @ube.directory.remove(ptr %ctx, ptr %path, ptr %failure) {
entry:
  %result = call i1 @ube.path.mutate(ptr %ctx, ptr %path, ptr null, ptr %failure, i64 2)
  ret i1 %result
}
define internal i1 @ube.file.delete(ptr %ctx, ptr %path, ptr %failure) {
entry:
  %result = call i1 @ube.path.mutate(ptr %ctx, ptr %path, ptr null, ptr %failure, i64 3)
  ret i1 %result
}
define internal i1 @ube.file.replace(ptr %ctx, ptr %source, ptr %destination, ptr %failure) {
entry:
  %result = call i1 @ube.path.mutate(ptr %ctx, ptr %source, ptr %destination, ptr %failure, i64 4)
  ret i1 %result
}
define internal i1 @ube.path.kind.pinned(ptr %ctx, ptr %path, ptr %kind, ptr %failure) {
entry:
  %outputs = call i1 @ube.system.outputs(ptr %ctx, ptr %path, ptr %kind, ptr %failure)
  br i1 %outputs, label %allocate, label %failed
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 4608, i64 1)
  %missing = icmp eq ptr %block, null
  br i1 %missing, label %memory.fail, label %prepare
prepare:
  %scratch = getelementptr %ube.block, ptr %block, i64 1
  %wide = getelementptr i8, ptr %scratch, i64 4096
  %length = call i32 @ube.path.decode(ptr %path, ptr %scratch, ptr %wide)
  %valid = icmp sgt i32 %length, 0
  br i1 %valid, label %query, label %request.fail
query:
  %attributes = call i64 @ube.target.path.attributes(ptr %wide)
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %negative = icmp slt i64 %attributes, 0
  br i1 %negative, label %classify, label %present
classify:
  %file.missing = icmp eq i64 %attributes, -2
  %path.missing = icmp eq i64 %attributes, -3
  %absent = or i1 %file.missing, %path.missing
  br i1 %absent, label %missing.path, label %io.fail
missing.path:
  store atomic i64 0, ptr %kind monotonic, align 8
  ret i1 true
present:
  %directory.bit = and i64 %attributes, 16
  %directory = icmp ne i64 %directory.bit, 0
  %value = select i1 %directory, i64 2, i64 1
  store atomic i64 %value, ptr %kind monotonic, align 8
  ret i1 true
memory.fail:
  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)
  ret i1 false
request.fail:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
io.fail:
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.path.kind(ptr %ctx, ptr %path, ptr %kind, ptr %failure) {
entry:
  %descriptor.path = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %kind)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %path, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  br i1 %aliases.1, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.path = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %path)
  store { i64, i64, ptr, ptr } %snapshot.path, ptr %descriptor.path
  %pin.path = extractvalue { i64, i64, ptr, ptr } %snapshot.path, 3
  %accepted = call i1 @ube.path.kind.pinned(ptr %ctx, ptr %descriptor.path, ptr %kind, ptr %failure)
  call void @ube.block.drop(ptr %ctx, ptr %pin.path)
  ret i1 %accepted
}
%ube.process = type { ptr, ptr, ptr, ptr, ptr, i64, i64, i64, i64 }
@ube.process.nullname = private constant [4 x i16] [i16 78, i16 85, i16 76, i16 0]
declare dllimport ptr @GetCurrentProcess()
declare dllimport i32 @DuplicateHandle(ptr, ptr, ptr, ptr, i32, i32, i32)
declare dllimport i32 @CreateProcessW(ptr, ptr, ptr, ptr, i32, i32, ptr, ptr, ptr, ptr)
declare dllimport i32 @InitializeProcThreadAttributeList(ptr, i32, i32, ptr)
declare dllimport i32 @UpdateProcThreadAttribute(ptr, i32, i64, ptr, i64, ptr, ptr)
declare dllimport void @DeleteProcThreadAttributeList(ptr)
declare dllimport ptr @CreateJobObjectW(ptr, ptr)
declare dllimport i32 @SetInformationJobObject(ptr, i32, ptr, i32)
declare dllimport i32 @AssignProcessToJobObject(ptr, ptr)
declare dllimport i32 @ResumeThread(ptr)
declare dllimport i32 @WaitForSingleObject(ptr, i32)
declare dllimport i32 @GetExitCodeProcess(ptr, ptr)
declare dllimport i32 @QueryInformationJobObject(ptr, i32, ptr, i32, ptr)
declare dllimport i32 @TerminateJobObject(ptr, i32)
declare dllimport i32 @TerminateProcess(ptr, i32)
declare dllimport void @Sleep(i32)
define i1 @ube.target.process.duplicate(ptr %source, ptr %output) {
entry:
  %self = call ptr @GetCurrentProcess()
  %result = call i32 @DuplicateHandle(ptr %self, ptr %source, ptr %self, ptr %output, i32 0, i32 1, i32 2)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define ptr @ube.target.process.nullinput() {
entry:
  %security = alloca { i32, ptr, i32 }, align 8
  %descriptor = getelementptr { i32, ptr, i32 }, ptr %security, i32 0, i32 1
  %inherit = getelementptr { i32, ptr, i32 }, ptr %security, i32 0, i32 2
  store i32 24, ptr %security
  store ptr null, ptr %descriptor
  store i32 1, ptr %inherit
  %result = call ptr @CreateFileW(ptr @ube.process.nullname, i32 -2147483648, i32 3, ptr %security, i32 3, i32 128, ptr null)
  ret ptr %result
}
define ptr @ube.target.process.job() {
entry:
  %result = call ptr @CreateJobObjectW(ptr null, ptr null)
  ret ptr %result
}
define i1 @ube.target.process.limit(ptr %job, ptr %information) {
entry:
  %result = call i32 @SetInformationJobObject(ptr %job, i32 9, ptr %information, i32 144)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define i1 @ube.target.process.attributes(ptr %list, ptr %size) {
entry:
  %result = call i32 @InitializeProcThreadAttributeList(ptr %list, i32 1, i32 0, ptr %size)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define i1 @ube.target.process.handles(ptr %list, ptr %handles) {
entry:
  %result = call i32 @UpdateProcThreadAttribute(ptr %list, i32 0, i64 131074, ptr %handles, i64 16, ptr null, ptr null)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define void @ube.target.process.deleteattributes(ptr %list) {
entry:
  call void @DeleteProcThreadAttributeList(ptr %list)
  ret void
}
define i1 @ube.target.process.create(ptr %app, ptr %command, ptr %directory, ptr %startup, ptr %information) {
entry:
  %result = call i32 @CreateProcessW(ptr %app, ptr %command, ptr null, ptr null, i32 1, i32 134742020, ptr null, ptr %directory, ptr %startup, ptr %information)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define i1 @ube.target.process.assign(ptr %job, ptr %process) {
entry:
  %result = call i32 @AssignProcessToJobObject(ptr %job, ptr %process)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define i1 @ube.target.process.resume(ptr %thread) {
entry:
  %result = call i32 @ResumeThread(ptr %thread)
  %ok = icmp ne i32 %result, -1
  ret i1 %ok
}
define i32 @ube.target.process.wait(ptr %process, i32 %milliseconds) {
entry:
  %result = call i32 @WaitForSingleObject(ptr %process, i32 %milliseconds)
  ret i32 %result
}
define i1 @ube.target.process.exit(ptr %process, ptr %code) {
entry:
  %result = call i32 @GetExitCodeProcess(ptr %process, ptr %code)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define i1 @ube.target.process.accounting(ptr %job, ptr %information) {
entry:
  %result = call i32 @QueryInformationJobObject(ptr %job, i32 1, ptr %information, i32 48, ptr null)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define i1 @ube.target.process.terminatejob(ptr %job) {
entry:
  %result = call i32 @TerminateJobObject(ptr %job, i32 1)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define i1 @ube.target.process.terminate(ptr %process) {
entry:
  %result = call i32 @TerminateProcess(ptr %process, i32 1)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define i1 @ube.target.process.close(ptr %handle) {
entry:
  %result = call i32 @CloseHandle(ptr %handle)
  %ok = icmp ne i32 %result, 0
  ret i1 %ok
}
define void @ube.target.process.sleep(i32 %milliseconds) {
entry:
  call void @Sleep(i32 %milliseconds)
  ret void
}
define internal void @ube.process.zero(ptr %storage, i64 %length) {
entry:
  br label %clear
clear:
  %index = phi i64 [0, %entry], [%next, %clear]
  %cell = getelementptr i8, ptr %storage, i64 %index
  store volatile i8 0, ptr %cell
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, %length
  br i1 %more, label %clear, label %done
done:
  ret void
}
define internal ptr @ube.process.acquire(ptr %ctx, i64 %token, ptr %failure) {
entry:
  %slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %kind
kind:
  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3
  %actual = load atomic i64, ptr %kind.ptr monotonic, align 8
  %correct = icmp eq i64 %actual, 4
  br i1 %correct, label %done, label %wrong
wrong:
  call void @ube.resource.unlock(ptr %slot)
  %status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret ptr null
done:
  ret ptr %slot
failed:
  ret ptr null
}
define internal ptr @ube.process.state(ptr %slot) {
entry:
  %scratch.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2
  %block = load ptr, ptr %scratch.ptr
  %state = getelementptr %ube.block, ptr %block, i64 1
  ret ptr %state
}
define internal i32 @ube.process.command(ptr %array, ptr %packed, ptr %wide) {
entry:
  %lower = load atomic i64, ptr %array monotonic, align 8
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load atomic i64, ptr %upper.ptr monotonic, align 8
  %distance = sub i64 %upper, %lower
  %length = add i64 %distance, 1
  %empty = icmp eq i64 %length, 0
  %large = icmp ugt i64 %length, 131072
  %invalid = or i1 %empty, %large
  br i1 %invalid, label %failed, label %prepare
prepare:
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %data = load ptr, ptr %data.ptr
  br label %copy
copy:
  %index = phi i64 [0, %prepare], [%next, %more]
  %source = getelementptr i64, ptr %data, i64 %index
  %value = load atomic i64, ptr %source monotonic, align 8
  %nul = icmp eq i64 %value, 0
  br i1 %nul, label %failed, label %pack
pack:
  %byte = trunc i64 %value to i8
  %destination = getelementptr i8, ptr %packed, i64 %index
  store volatile i8 %byte, ptr %destination
  br label %more
more:
  %next = add i64 %index, 1
  %remaining = icmp ult i64 %next, %length
  br i1 %remaining, label %copy, label %convert
convert:
  %bytes = trunc i64 %length to i32
  %units = call i32 @ube.target.file.utf8(ptr %packed, i32 %bytes, ptr %wide, i32 32766)
  %valid = icmp sgt i32 %units, 0
  br i1 %valid, label %finish, label %failed
finish:
  %units64 = zext i32 %units to i64
  %end = getelementptr i16, ptr %wide, i64 %units64
  store i16 0, ptr %end
  ret i32 %units
failed:
  ret i32 -1
}
define internal i64 @ube.process.active(ptr %state) {
entry:
  %information = alloca [48 x i8], align 8
  %attached.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 8
  %attached = load atomic i64, ptr %attached.ptr monotonic, align 8
  %contained = icmp ne i64 %attached, 0
  br i1 %contained, label %query, label %unattached
query:
  %job = load ptr, ptr %state
  %ok = call i1 @ube.target.process.accounting(ptr %job, ptr %information)
  br i1 %ok, label %count, label %failed
count:
  %active.ptr = getelementptr i8, ptr %information, i64 40
  %active32 = load i32, ptr %active.ptr
  %active = zext i32 %active32 to i64
  ret i64 %active
unattached:
  %process.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 1
  %process = load ptr, ptr %process.ptr
  %exists = icmp ne ptr %process, null
  %exited.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 6
  %exited = load atomic i64, ptr %exited.ptr monotonic, align 8
  %live = icmp eq i64 %exited, 0
  %running = and i1 %exists, %live
  %result = zext i1 %running to i64
  ret i64 %result
failed:
  ret i64 -1
}
define internal i32 @ube.process.observe(ptr %state, i32 %milliseconds) {
entry:
  %native.exit = alloca i32, align 4
  %exit.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 5
  %exited.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 6
  %exited = load atomic i64, ptr %exited.ptr monotonic, align 8
  %cached = icmp ne i64 %exited, 0
  br i1 %cached, label %query, label %process
process:
  %process.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 1
  %handle = load ptr, ptr %process.ptr
  %missing = icmp eq ptr %handle, null
  br i1 %missing, label %not.created, label %wait
not.created:
  store atomic i64 1, ptr %exit.ptr monotonic, align 8
  store atomic i64 1, ptr %exited.ptr monotonic, align 8
  br label %query
wait:
  %result = call i32 @ube.target.process.wait(ptr %handle, i32 %milliseconds)
  %done = icmp eq i32 %result, 0
  br i1 %done, label %read.exit, label %timeout
timeout:
  %pending = icmp eq i32 %result, 258
  br i1 %pending, label %query, label %failed
read.exit:
  %read = call i1 @ube.target.process.exit(ptr %handle, ptr %native.exit)
  br i1 %read, label %cache, label %failed
cache:
  %code32 = load i32, ptr %native.exit
  %code = sext i32 %code32 to i64
  store atomic i64 %code, ptr %exit.ptr monotonic, align 8
  store atomic i64 1, ptr %exited.ptr monotonic, align 8
  br label %query
query:
  %active = call i64 @ube.process.active(ptr %state)
  %bad.query = icmp slt i64 %active, 0
  br i1 %bad.query, label %failed, label %pause.check
pause.check:
  %nonempty = icmp ne i64 %active, 0
  %positive.wait = icmp ugt i32 %milliseconds, 0
  %wait.descendants = and i1 %cached, %nonempty
  %pause = and i1 %wait.descendants, %positive.wait
  br i1 %pause, label %sleep, label %finish
sleep:
  call void @ube.target.process.sleep(i32 %milliseconds)
  %after = call i64 @ube.process.active(ptr %state)
  %bad.after = icmp slt i64 %after, 0
  br i1 %bad.after, label %failed, label %finish
finish:
  %current = phi i64 [%active, %pause.check], [%after, %sleep]
  %root.state = load atomic i64, ptr %exited.ptr monotonic, align 8
  %root.done = icmp ne i64 %root.state, 0
  %empty = icmp eq i64 %current, 0
  %complete = and i1 %root.done, %empty
  %value = zext i1 %complete to i32
  ret i32 %value
failed:
  ret i32 -1
}
define internal i1 @ube.process.start.pinned(ptr %ctx, ptr %app, ptr %command, ptr %directory, i64 %log.token, ptr %token.out, ptr %failure) {
entry:
  %attribute.size = alloca i64, align 8
  %attribute.live = alloca i1, align 1
  %inherited = alloca [2 x ptr], align 8
  store i1 false, ptr %attribute.live
  %same = icmp eq ptr %token.out, %failure
  %null.token = icmp eq ptr %token.out, null
  %null.failure = icmp eq ptr %failure, null
  %a = call i1 @ube.file.overlaps(ptr %app, ptr %token.out)
  %b = call i1 @ube.file.overlaps(ptr %app, ptr %failure)
  %c = call i1 @ube.file.overlaps(ptr %command, ptr %token.out)
  %d = call i1 @ube.file.overlaps(ptr %command, ptr %failure)
  %e = call i1 @ube.file.overlaps(ptr %directory, ptr %token.out)
  %f = call i1 @ube.file.overlaps(ptr %directory, ptr %failure)
  %ab = or i1 %a, %b
  %cd = or i1 %c, %d
  %ef = or i1 %e, %f
  %abcd = or i1 %ab, %cd
  %overlap = or i1 %abcd, %ef
  %nulls = or i1 %null.token, %null.failure
  %bad.scalar = or i1 %same, %nulls
  %bad = or i1 %bad.scalar, %overlap
  br i1 %bad, label %alias.fail, label %validate
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
validate:
  store atomic i64 0, ptr %failure monotonic, align 8
  %old = load atomic i64, ptr %token.out monotonic, align 8
  %available = icmp eq i64 %old, 0
  br i1 %available, label %reserve, label %request.fail
reserve:
  %slot = call ptr @ube.resource.reserve(ptr %ctx)
  %no.slot = icmp eq ptr %slot, null
  br i1 %no.slot, label %memory.fail, label %allocate
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 27280, i64 1)
  %no.block = icmp eq ptr %block, null
  br i1 %no.block, label %empty.release, label %prepare
empty.release:
  call void @ube.resource.forget(ptr %ctx, ptr %slot)
  br label %memory.fail
prepare:
  %scratch.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 2
  store ptr %block, ptr %scratch.ptr
  %state = getelementptr %ube.block, ptr %block, i64 1
  call void @ube.process.zero(ptr %state, i64 72)
  %wide.app = getelementptr i8, ptr %state, i64 128
  %wide.directory = getelementptr i8, ptr %state, i64 8448
  %wide.command = getelementptr i8, ptr %state, i64 16896
  %packed = getelementptr i8, ptr %state, i64 82688
  %startup = getelementptr i8, ptr %state, i64 213760
  %information = getelementptr i8, ptr %state, i64 213872
  %job.information = getelementptr i8, ptr %state, i64 213896
  %attributes = getelementptr i8, ptr %state, i64 214144
  %app.length = call i32 @ube.path.decode(ptr %app, ptr %packed, ptr %wide.app)
  %app.valid = icmp sgt i32 %app.length, 0
  br i1 %app.valid, label %directory.decode, label %invalid.private
directory.decode:
  %directory.length = call i32 @ube.path.decode(ptr %directory, ptr %packed, ptr %wide.directory)
  %directory.valid = icmp sgt i32 %directory.length, 0
  br i1 %directory.valid, label %command.decode, label %invalid.private
command.decode:
  %command.length = call i32 @ube.process.command(ptr %command, ptr %packed, ptr %wide.command)
  %command.valid = icmp sgt i32 %command.length, 0
  br i1 %command.valid, label %identity, label %invalid.private
identity:
  %token = call i64 @ube.resource.token()
  %valid.token = icmp ne i64 %token, 0
  br i1 %valid.token, label %publish, label %exhausted.private
publish:
  %kind.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 3
  %handle.ptr = getelementptr %ube.resource, ptr %slot, i32 0, i32 1
  store ptr null, ptr %handle.ptr
  store atomic i64 4, ptr %kind.ptr monotonic, align 8
  store atomic i64 %token, ptr %slot release, align 8
  store atomic i64 %token, ptr %token.out monotonic, align 8
  %process.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 1
  %thread.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 2
  %input.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 3
  %log.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 4
  %started.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 7
  %attached.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 8
  %job = call ptr @ube.target.process.job()
  store ptr %job, ptr %state
  %job.failed = icmp eq ptr %job, null
  br i1 %job.failed, label %io.fail, label %job.limit
job.limit:
  call void @ube.process.zero(ptr %job.information, i64 144)
  %limit.flags = getelementptr i8, ptr %job.information, i64 16
  store i32 8192, ptr %limit.flags
  %limited = call i1 @ube.target.process.limit(ptr %job, ptr %job.information)
  br i1 %limited, label %input, label %io.fail
input:
  %input.handle = call ptr @ube.target.process.nullinput()
  %invalid.input = icmp eq ptr %input.handle, inttoptr (i64 -1 to ptr)
  %null.input = icmp eq ptr %input.handle, null
  %bad.input = or i1 %invalid.input, %null.input
  br i1 %bad.input, label %io.fail, label %input.owned
input.owned:
  store ptr %input.handle, ptr %input.ptr
  %log.slot = call ptr @ube.resource.acquire(ptr %ctx, i64 %log.token, ptr %failure)
  %no.log = icmp eq ptr %log.slot, null
  br i1 %no.log, label %retain.failure, label %log.kind
log.kind:
  %log.kind.ptr = getelementptr %ube.resource, ptr %log.slot, i32 0, i32 3
  %log.mode = load atomic i64, ptr %log.kind.ptr monotonic, align 8
  %writable = icmp eq i64 %log.mode, 2
  br i1 %writable, label %duplicate, label %wrong.log
wrong.log:
  call void @ube.resource.unlock(ptr %log.slot)
  %wrong.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  br label %retain.failure
duplicate:
  %log.handle.ptr = getelementptr %ube.resource, ptr %log.slot, i32 0, i32 1
  %log.handle = load ptr, ptr %log.handle.ptr
  %duplicated = call i1 @ube.target.process.duplicate(ptr %log.handle, ptr %log.ptr)
  call void @ube.resource.unlock(ptr %log.slot)
  br i1 %duplicated, label %attribute.measure, label %io.fail
attribute.measure:
  store atomic i64 0, ptr %attribute.size monotonic, align 8
  %measurement = call i1 @ube.target.process.attributes(ptr null, ptr %attribute.size)
  %size = load atomic i64, ptr %attribute.size monotonic, align 8
  %positive = icmp ugt i64 %size, 0
  %bounded = icmp ule i64 %size, 4096
  %valid.size = and i1 %positive, %bounded
  %expected.failure = xor i1 %measurement, true
  %measured = and i1 %valid.size, %expected.failure
  br i1 %measured, label %attribute.initialize, label %io.fail
attribute.initialize:
  %initialized = call i1 @ube.target.process.attributes(ptr %attributes, ptr %attribute.size)
  br i1 %initialized, label %attribute.values, label %io.fail
attribute.values:
  store i1 true, ptr %attribute.live
  %private.log = load ptr, ptr %log.ptr
  %second.handle = getelementptr ptr, ptr %inherited, i64 1
  store ptr %input.handle, ptr %inherited
  store ptr %private.log, ptr %second.handle
  %listed = call i1 @ube.target.process.handles(ptr %attributes, ptr %inherited)
  br i1 %listed, label %startup.prepare, label %io.fail
startup.prepare:
  call void @ube.process.zero(ptr %startup, i64 112)
  call void @ube.process.zero(ptr %information, i64 24)
  store i32 112, ptr %startup
  %flags = getelementptr i8, ptr %startup, i64 60
  %stdin = getelementptr i8, ptr %startup, i64 80
  %stdout = getelementptr i8, ptr %startup, i64 88
  %stderr = getelementptr i8, ptr %startup, i64 96
  %list = getelementptr i8, ptr %startup, i64 104
  store i32 257, ptr %flags
  store ptr %input.handle, ptr %stdin
  store ptr %private.log, ptr %stdout
  store ptr %private.log, ptr %stderr
  store ptr %attributes, ptr %list
  %created = call i1 @ube.target.process.create(ptr %wide.app, ptr %wide.command, ptr %wide.directory, ptr %startup, ptr %information)
  br i1 %created, label %created.owned, label %io.fail
created.owned:
  %native.process = load ptr, ptr %information
  %native.thread.ptr = getelementptr i8, ptr %information, i64 8
  %native.thread = load ptr, ptr %native.thread.ptr
  store ptr %native.process, ptr %process.ptr
  store ptr %native.thread, ptr %thread.ptr
  %assigned = call i1 @ube.target.process.assign(ptr %job, ptr %native.process)
  br i1 %assigned, label %contained, label %io.fail
contained:
  store atomic i64 1, ptr %attached.ptr monotonic, align 8
  %resumed = call i1 @ube.target.process.resume(ptr %native.thread)
  br i1 %resumed, label %started, label %io.fail
started:
  store atomic i64 1, ptr %started.ptr monotonic, align 8
  call void @ube.target.process.deleteattributes(ptr %attributes)
  store i1 false, ptr %attribute.live
  call void @ube.resource.unlock(ptr %slot)
  ret i1 true
io.fail:
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  br label %retain.failure
retain.failure:
  %live = load i1, ptr %attribute.live
  br i1 %live, label %delete.attributes, label %unlock
delete.attributes:
  call void @ube.target.process.deleteattributes(ptr %attributes)
  br label %unlock
unlock:
  call void @ube.resource.unlock(ptr %slot)
  ret i1 false
invalid.private:
  call void @ube.resource.forget(ptr %ctx, ptr %slot)
  br label %request.fail
exhausted.private:
  call void @ube.resource.forget(ptr %ctx, ptr %slot)
  br label %memory.fail
request.fail:
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
memory.fail:
  %memory.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 7)
  ret i1 false
}
define internal i1 @ube.process.start(ptr %ctx, ptr %app, ptr %command, ptr %directory, i64 %log.token, ptr %token.out, ptr %failure) {
entry:
  %descriptor.app = alloca { i64, i64, ptr, ptr }, align 8
  %descriptor.command = alloca { i64, i64, ptr, ptr }, align 8
  %descriptor.directory = alloca { i64, i64, ptr, ptr }, align 8
  %alias.0 = call i1 @ube.array.descriptor.overlaps(ptr %app, ptr %token.out)
  %alias.1 = call i1 @ube.array.descriptor.overlaps(ptr %app, ptr %failure)
  %alias.2 = call i1 @ube.array.descriptor.overlaps(ptr %command, ptr %token.out)
  %alias.3 = call i1 @ube.array.descriptor.overlaps(ptr %command, ptr %failure)
  %alias.4 = call i1 @ube.array.descriptor.overlaps(ptr %directory, ptr %token.out)
  %alias.5 = call i1 @ube.array.descriptor.overlaps(ptr %directory, ptr %failure)
  %aliases.1 = or i1 %alias.0, %alias.1
  %aliases.2 = or i1 %aliases.1, %alias.2
  %aliases.3 = or i1 %aliases.2, %alias.3
  %aliases.4 = or i1 %aliases.3, %alias.4
  %aliases.5 = or i1 %aliases.4, %alias.5
  br i1 %aliases.5, label %alias.fail, label %pin
alias.fail:
  %rejected = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
pin:
  %snapshot.app = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %app)
  store { i64, i64, ptr, ptr } %snapshot.app, ptr %descriptor.app
  %pin.app = extractvalue { i64, i64, ptr, ptr } %snapshot.app, 3
  %snapshot.command = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %command)
  store { i64, i64, ptr, ptr } %snapshot.command, ptr %descriptor.command
  %pin.command = extractvalue { i64, i64, ptr, ptr } %snapshot.command, 3
  %same.command.app = icmp eq ptr %command, %app
  %selected.command.app = select i1 %same.command.app, ptr %descriptor.app, ptr %descriptor.command
  %snapshot.directory = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %directory)
  store { i64, i64, ptr, ptr } %snapshot.directory, ptr %descriptor.directory
  %pin.directory = extractvalue { i64, i64, ptr, ptr } %snapshot.directory, 3
  %same.directory.app = icmp eq ptr %directory, %app
  %selected.directory.app = select i1 %same.directory.app, ptr %descriptor.app, ptr %descriptor.directory
  %same.directory.command = icmp eq ptr %directory, %command
  %selected.directory.command = select i1 %same.directory.command, ptr %selected.command.app, ptr %selected.directory.app
  %accepted = call i1 @ube.process.start.pinned(ptr %ctx, ptr %descriptor.app, ptr %selected.command.app, ptr %selected.directory.command, i64 %log.token, ptr %token.out, ptr %failure)
  call void @ube.block.drop(ptr %ctx, ptr %pin.app)
  call void @ube.block.drop(ptr %ctx, ptr %pin.command)
  call void @ube.block.drop(ptr %ctx, ptr %pin.directory)
  ret i1 %accepted
}
define internal i1 @ube.process.wait(ptr %ctx, i64 %token, i64 %milliseconds, ptr %state.out, ptr %exit.out, ptr %failure) {
entry:
  %same.a = icmp eq ptr %state.out, %exit.out
  %same.b = icmp eq ptr %state.out, %failure
  %same.c = icmp eq ptr %exit.out, %failure
  %null.a = icmp eq ptr %state.out, null
  %null.b = icmp eq ptr %exit.out, null
  %null.c = icmp eq ptr %failure, null
  %same.ab = or i1 %same.a, %same.b
  %same = or i1 %same.ab, %same.c
  %null.ab = or i1 %null.a, %null.b
  %nulls = or i1 %null.ab, %null.c
  %bad = or i1 %same, %nulls
  br i1 %bad, label %alias.fail, label %validate
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
validate:
  store atomic i64 0, ptr %failure monotonic, align 8
  %excessive = icmp ugt i64 %milliseconds, 5000
  br i1 %excessive, label %request.fail, label %lookup
lookup:
  %slot = call ptr @ube.process.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %observe
observe:
  %state = call ptr @ube.process.state(ptr %slot)
  %timeout = trunc i64 %milliseconds to i32
  %observation = call i32 @ube.process.observe(ptr %state, i32 %timeout)
  %bad.observation = icmp slt i32 %observation, 0
  br i1 %bad.observation, label %io.fail, label %publish
publish:
  %value = zext i32 %observation to i64
  store atomic i64 %value, ptr %state.out monotonic, align 8
  %finished = icmp eq i32 %observation, 1
  br i1 %finished, label %publish.exit, label %success
publish.exit:
  %exit.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 5
  %code = load atomic i64, ptr %exit.ptr monotonic, align 8
  store atomic i64 %code, ptr %exit.out monotonic, align 8
  br label %success
success:
  call void @ube.resource.unlock(ptr %slot)
  ret i1 true
io.fail:
  call void @ube.resource.unlock(ptr %slot)
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
request.fail:
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.process.terminate(ptr %ctx, i64 %token, ptr %failure) {
entry:
  %null = icmp eq ptr %failure, null
  br i1 %null, label %alias.fail, label %lookup
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
lookup:
  store atomic i64 0, ptr %failure monotonic, align 8
  %slot = call ptr @ube.process.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %inspect
inspect:
  %state = call ptr @ube.process.state(ptr %slot)
  %observation = call i32 @ube.process.observe(ptr %state, i32 0)
  %complete = icmp eq i32 %observation, 1
  br i1 %complete, label %success, label %kind
kind:
  %attached.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 8
  %attached = load atomic i64, ptr %attached.ptr monotonic, align 8
  %contained = icmp ne i64 %attached, 0
  br i1 %contained, label %job, label %process
job:
  %job.handle = load ptr, ptr %state
  %job.stopped = call i1 @ube.target.process.terminatejob(ptr %job.handle)
  br i1 %job.stopped, label %success, label %io.fail
process:
  %process.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 1
  %process.handle = load ptr, ptr %process.ptr
  %exists = icmp ne ptr %process.handle, null
  br i1 %exists, label %stop, label %success
stop:
  %stopped = call i1 @ube.target.process.terminate(ptr %process.handle)
  br i1 %stopped, label %success, label %io.fail
success:
  call void @ube.resource.unlock(ptr %slot)
  ret i1 true
io.fail:
  call void @ube.resource.unlock(ptr %slot)
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
failed:
  ret i1 false
}
define internal i1 @ube.process.close(ptr %ctx, ptr %token.out, ptr %failure) {
entry:
  %same = icmp eq ptr %token.out, %failure
  %null.token = icmp eq ptr %token.out, null
  %null.failure = icmp eq ptr %failure, null
  %nulls = or i1 %null.token, %null.failure
  %bad = or i1 %same, %nulls
  br i1 %bad, label %alias.fail, label %lookup
alias.fail:
  %alias.status = call i1 @ube.file.aliasfail(ptr %ctx)
  ret i1 false
lookup:
  store atomic i64 0, ptr %failure monotonic, align 8
  %token = load atomic i64, ptr %token.out monotonic, align 8
  %empty = icmp eq i64 %token, 0
  br i1 %empty, label %success, label %acquire
acquire:
  %slot = call ptr @ube.process.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %observe
observe:
  %state = call ptr @ube.process.state(ptr %slot)
  %observation = call i32 @ube.process.observe(ptr %state, i32 0)
  %bad.observation = icmp slt i32 %observation, 0
  br i1 %bad.observation, label %io.fail, label %ready
ready:
  %complete = icmp eq i32 %observation, 1
  br i1 %complete, label %release, label %busy
release:
  br label %handles
handles:
  %index = phi i64 [0, %release], [%next, %advance]
  %all = phi i1 [true, %release], [%accepted, %advance]
  %handle.ptr = getelementptr ptr, ptr %state, i64 %index
  %handle = load ptr, ptr %handle.ptr
  %present = icmp ne ptr %handle, null
  br i1 %present, label %close, label %advance
close:
  %closed = call i1 @ube.target.process.close(ptr %handle)
  br i1 %closed, label %clear, label %advance
clear:
  store ptr null, ptr %handle.ptr
  %is.job = icmp eq i64 %index, 0
  br i1 %is.job, label %detach, label %advance
detach:
  %attached.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 8
  store atomic i64 0, ptr %attached.ptr monotonic, align 8
  br label %advance
advance:
  %current = phi i1 [true, %handles], [false, %close], [true, %clear], [true, %detach]
  %accepted = and i1 %all, %current
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, 5
  br i1 %more, label %handles, label %finish
finish:
  br i1 %accepted, label %forget, label %close.fail
forget:
  call void @ube.resource.forget(ptr %ctx, ptr %slot)
  store atomic i64 0, ptr %token.out monotonic, align 8
  br label %success
busy:
  call void @ube.resource.unlock(ptr %slot)
  %busy.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 12, i64 5)
  ret i1 false
io.fail:
  call void @ube.resource.unlock(ptr %slot)
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 5, i64 57)
  ret i1 false
close.fail:
  call void @ube.resource.unlock(ptr %slot)
  %close.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 7, i64 57)
  ret i1 false
success:
  ret i1 true
failed:
  ret i1 false
}
; Native thread mechanics. Generated source entry thunks own typed capture cleanup.
%ube.worker = type { ptr, i64, ptr, i64, i64, i64, ptr, ptr, %ube.thread, i64, i64, i64 }
@ube.thread.next = internal global i64 1
declare dllimport ptr @CreateThread(ptr, i64, ptr, ptr, i32, ptr)
define ptr @ube.target.thread.start(ptr %procedure, ptr %argument) {
entry:
  %handle = call ptr @CreateThread(ptr null, i64 8388608, ptr %procedure, ptr %argument, i32 65536, ptr null)
  ret ptr %handle
}
define i32 @ube.target.thread.wait(ptr %handle, i32 %milliseconds) {
entry:
  %result = call i32 @WaitForSingleObject(ptr %handle, i32 %milliseconds)
  ret i32 %result
}
define i1 @ube.target.thread.close(ptr %handle) {
entry:
  %status = call i32 @CloseHandle(ptr %handle)
  %ok = icmp ne i32 %status, 0
  ret i1 %ok
}
define internal { i1, i64 } @ube.thread.failure(ptr %ctx, i64 %number) {
entry:
  store i64 %number, ptr %ctx, align 8
  ret { i1, i64 } zeroinitializer
}
define internal { i1, i64 } @ube.thread.value(i64 %value) {
entry:
  %pair = insertvalue { i1, i64 } { i1 true, i64 0 }, i64 %value, 1
  ret { i1, i64 } %pair
}
define internal void @ube.thread.registry.lock(ptr %program) {
entry:
  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 11
  br label %acquire
acquire:
  %attempt = cmpxchg ptr %lock, i64 0, i64 1 acquire monotonic
  %ok = extractvalue { i64, i1 } %attempt, 1
  br i1 %ok, label %done, label %yield
yield:
  call void @Sleep(i32 0)
  br label %acquire
done:
  ret void
}
define internal void @ube.thread.registry.unlock(ptr %program) {
entry:
  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 11
  store atomic i64 0, ptr %lock release, align 8
  ret void
}
define internal i64 @ube.thread.issue() {
entry:
  br label %retry
retry:
  %old = load atomic i64, ptr @ube.thread.next seq_cst, align 8
  %exhausted = icmp eq i64 %old, 0
  br i1 %exhausted, label %failed, label %issue
issue:
  %last = icmp eq i64 %old, 9223372036854775807
  %increment = add i64 %old, 1
  %next = select i1 %last, i64 0, i64 %increment
  %pair = cmpxchg ptr @ube.thread.next, i64 %old, i64 %next seq_cst seq_cst
  %ok = extractvalue { i64, i1 } %pair, 1
  br i1 %ok, label %done, label %retry
done:
  ret i64 %old
failed:
  ret i64 0
}
define internal ptr @ube.thread.record.new(ptr %ctx) {
entry:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 16, i64 1)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %done, label %failed
done:
  %data = getelementptr %ube.block, ptr %block, i64 1
  ret ptr %data
failed:
  ret ptr null
}
define internal void @ube.thread.record.drop(ptr %ctx, ptr %record) {
entry:
  %block = getelementptr %ube.block, ptr %record, i64 -1
  call void @ube.block.drop(ptr %ctx, ptr %block)
  ret void
}
define internal void @ube.thread.record.link(ptr %program, ptr %record) {
entry:
  %head = getelementptr %ube.program, ptr %program, i32 0, i32 10
  %old = load atomic ptr, ptr %head acquire, align 8
  store ptr %old, ptr %record, align 8
  store atomic ptr %record, ptr %head release, align 8
  ret void
}
define internal ptr @ube.thread.record.find(ptr %ctx, i64 %id) {
entry:
  %valid = icmp sgt i64 %id, 0
  br i1 %valid, label %head, label %failed
head:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %address = getelementptr %ube.program, ptr %program, i32 0, i32 10
  %first = load atomic ptr, ptr %address acquire, align 8
  br label %scan
scan:
  %record = phi ptr [ %first, %head ], [ %next, %advance ]
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %inspect, label %failed
inspect:
  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1
  %candidate = load i64, ptr %id.ptr, align 8
  %same = icmp eq i64 %candidate, %id
  br i1 %same, label %done, label %advance
advance:
  %next = load ptr, ptr %record, align 8
  br label %scan
done:
  ret ptr %record
failed:
  ret ptr null
}

define internal ptr @ube.thread.current.record(ptr %ctx) {
entry:
  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3
  %existing = load ptr, ptr %control, align 8
  %ready = icmp ne ptr %existing, null
  br i1 %ready, label %known, label %allocate
known:
  ret ptr %existing
allocate:
  %record = call ptr @ube.thread.record.new(ptr %ctx)
  %allocated = icmp ne ptr %record, null
  br i1 %allocated, label %identity, label %failed
identity:
  %id = call i64 @ube.thread.issue()
  %issued = icmp ne i64 %id, 0
  br i1 %issued, label %publish, label %discard
publish:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1
  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3
  store i64 %id, ptr %id.ptr, align 8
  store atomic i64 1, ptr %state release, align 8
  call void @ube.thread.registry.lock(ptr %program)
  call void @ube.thread.record.link(ptr %program, ptr %record)
  call void @ube.thread.registry.unlock(ptr %program)
  store ptr %record, ptr %control, align 8
  ret ptr %record
discard:
  call void @ube.thread.record.drop(ptr %ctx, ptr %record)
  br label %failed
failed:
  ret ptr null
}
define { i1, i64 } @ube.thread.current(ptr %ctx) {
entry:
  %record = call ptr @ube.thread.current.record(ptr %ctx)
  %ok = icmp ne ptr %record, null
  br i1 %ok, label %done, label %failed
done:
  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1
  %id = load i64, ptr %id.ptr, align 8
  %result = call { i1, i64 } @ube.thread.value(i64 %id)
  ret { i1, i64 } %result
failed:
  %failure = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 7)
  ret { i1, i64 } %failure
}
define i1 @ube.thread.stop.requested(ptr %ctx) {
entry:
  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3
  %record = load ptr, ptr %control, align 8
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %inspect, label %none
inspect:
  %flag = getelementptr %ube.worker, ptr %record, i32 0, i32 5
  %stop = load atomic i64, ptr %flag seq_cst, align 8
  %requested = icmp ne i64 %stop, 0
  ret i1 %requested
none:
  ret i1 false
}

define internal i32 @ube.thread.entry(ptr %record) {
entry:
  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3
  br label %gate
gate:
  %value = load atomic i64, ptr %state acquire, align 8
  %started = icmp ne i64 %value, 0
  br i1 %started, label %run, label %yield
yield:
  call void @Sleep(i32 0)
  br label %gate
run:
  %ctx = getelementptr %ube.worker, ptr %record, i32 0, i32 8
  %entry.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 7
  %capture.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 6
  %procedure = load ptr, ptr %entry.ptr, align 8
  %capture = load ptr, ptr %capture.ptr, align 8
  %payload = getelementptr %ube.block, ptr %capture, i64 1
  %success = call i1 %procedure(ptr %ctx, ptr %payload)
  %error = load i64, ptr %ctx, align 8
  %saved = select i1 %success, i64 0, i64 %error
  %error.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 4
  store i64 %saved, ptr %error.ptr, align 8
  call void @ube.block.drop(ptr %ctx, ptr %capture)
  store ptr null, ptr %capture.ptr, align 8
  store i64 0, ptr %ctx, align 8
  %program = call ptr @ube.thread.program(ptr %ctx)
  %active = getelementptr %ube.program, ptr %program, i32 0, i32 7
  %completion = select i1 %success, i64 2, i64 3
  store atomic i64 %completion, ptr %state release, align 8
  %previous = atomicrmw sub ptr %active, i64 1 acq_rel
  ret i32 0
}
define { i1, i64 } @ube.thread.start(ptr %ctx, ptr %procedure, ptr %capture) {
entry:
  %null.procedure = icmp eq ptr %procedure, null
  %null.capture = icmp eq ptr %capture, null
  %invalid = or i1 %null.procedure, %null.capture
  br i1 %invalid, label %bad, label %current
current:
  %parent = call ptr @ube.thread.current.record(ptr %ctx)
  %parent.ok = icmp ne ptr %parent, null
  br i1 %parent.ok, label %allocate, label %memory
allocate:
  %record = call ptr @ube.thread.record.new(ptr %ctx)
  %allocated = icmp ne ptr %record, null
  br i1 %allocated, label %reserve, label %memory
reserve:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %active.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 7
  %closed.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 8
  call void @ube.thread.registry.lock(ptr %program)
  %active = load atomic i64, ptr %active.ptr acquire, align 8
  %closed = load atomic i64, ptr %closed.ptr acquire, align 8
  %full = icmp uge i64 %active, 64
  %closing = icmp ne i64 %closed, 0
  %refused = or i1 %full, %closing
  br i1 %refused, label %unlock.discard, label %identity
identity:
  %id = call i64 @ube.thread.issue()
  %issued = icmp ne i64 %id, 0
  br i1 %issued, label %admitted, label %unlock.discard
admitted:
  %prior = atomicrmw add ptr %active.ptr, i64 1 acq_rel
  call void @ube.thread.registry.unlock(ptr %program)
  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1
  %capture.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 6
  %entry.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 7
  %thread = getelementptr %ube.worker, ptr %record, i32 0, i32 8
  store i64 %id, ptr %id.ptr, align 8
  store ptr %capture, ptr %capture.ptr, align 8
  store ptr %procedure, ptr %entry.ptr, align 8
  call void @ube.thread.init(ptr %thread, ptr %program, ptr %record)
  %handle = call ptr @ube.target.thread.start(ptr @ube.thread.entry, ptr %record)
  %created = icmp ne ptr %handle, null
  br i1 %created, label %publish, label %unreserve
publish:
  %handle.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 2
  %state.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 3
  store ptr %handle, ptr %handle.ptr, align 8
  call void @ube.thread.registry.lock(ptr %program)
  call void @ube.thread.record.link(ptr %program, ptr %record)
  call void @ube.thread.registry.unlock(ptr %program)
  store atomic i64 1, ptr %state.ptr release, align 8
  %result = call { i1, i64 } @ube.thread.value(i64 %id)
  ret { i1, i64 } %result
unreserve:
  %previous = atomicrmw sub ptr %active.ptr, i64 1 acq_rel
  call void @ube.thread.record.drop(ptr %ctx, ptr %record)
  %failure = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 57)
  ret { i1, i64 } %failure
unlock.discard:
  call void @ube.thread.registry.unlock(ptr %program)
  call void @ube.thread.record.drop(ptr %ctx, ptr %record)
  br label %memory
memory:
  %oom = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 7)
  ret { i1, i64 } %oom
bad:
  %bad.result = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 5)
  ret { i1, i64 } %bad.result
}

; A native handle is closed only after every admitted waiter has stopped using it.
define internal i1 @ube.thread.wait.release(ptr %ctx, ptr %record, i1 %joined) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %waiters = getelementptr %ube.worker, ptr %record, i32 0, i32 9
  %closing = getelementptr %ube.worker, ptr %record, i32 0, i32 10
  %finished = getelementptr %ube.worker, ptr %record, i32 0, i32 11
  %handle.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 2
  call void @ube.thread.registry.lock(ptr %program)
  %count = load i64, ptr %waiters, align 8
  %less = sub i64 %count, 1
  store i64 %less, ptr %waiters, align 8
  %old.done = load i64, ptr %finished, align 8
  %done = select i1 %joined, i64 1, i64 %old.done
  store i64 %done, ptr %finished, align 8
  %busy = load i64, ptr %closing, align 8
  %handle = load ptr, ptr %handle.ptr, align 8
  %last = icmp eq i64 %less, 0
  %native.done = icmp eq i64 %done, 1
  %idle = icmp eq i64 %busy, 0
  %exists = icmp ne ptr %handle, null
  %safe = and i1 %last, %native.done
  %owned = and i1 %idle, %exists
  %release = and i1 %safe, %owned
  br i1 %release, label %claim, label %keep
claim:
  store i64 1, ptr %closing, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  %ok = call i1 @ube.target.thread.close(ptr %handle)
  call void @ube.thread.registry.lock(ptr %program)
  %retained = select i1 %ok, ptr null, ptr %handle
  store ptr %retained, ptr %handle.ptr, align 8
  store i64 0, ptr %closing, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  ret i1 %ok
keep:
  call void @ube.thread.registry.unlock(ptr %program)
  ret i1 true
}
; Reads the release-published outcome independently of the persistent Err number.
define internal { i1, i64 } @ube.thread.completion(ptr %ctx, ptr %record) {
entry:
  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3
  %value = load atomic i64, ptr %state acquire, align 8
  %failed = icmp eq i64 %value, 3
  br i1 %failed, label %failure, label %success
failure:
  %error.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 4
  %error = load i64, ptr %error.ptr, align 8
  %bad = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 %error)
  ret { i1, i64 } %bad
success:
  ret { i1, i64 } { i1 true, i64 1 }
}

define internal { i1, i64 } @ube.thread.wait.core(ptr %ctx, i64 %id, i64 %timeout, i1 %observe.stop) {
entry:
  %invalid.timeout = icmp slt i64 %timeout, -1
  br i1 %invalid.timeout, label %invalid, label %lookup
lookup:
  %record = call ptr @ube.thread.record.find(ptr %ctx, i64 %id)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %self, label %invalid
self:
  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3
  %current = load ptr, ptr %control, align 8
  %same = icmp eq ptr %current, %record
  br i1 %same, label %invalid, label %acquire
acquire:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %handle.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 2
  %waiters = getelementptr %ube.worker, ptr %record, i32 0, i32 9
  %finished = getelementptr %ube.worker, ptr %record, i32 0, i32 11
  %closing.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 10
  %state.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 3
  call void @ube.thread.registry.lock(ptr %program)
  %done = load i64, ptr %finished, align 8
  %handle = load ptr, ptr %handle.ptr, align 8
  %closing = load i64, ptr %closing.ptr, align 8
  %already = icmp eq i64 %done, 1
  %native = icmp ne ptr %handle, null
  %idle = icmp eq i64 %closing, 0
  %borrow = and i1 %native, %idle
  br i1 %borrow, label %retain, label %unlocked
retain:
  %count = load i64, ptr %waiters, align 8
  %more = add i64 %count, 1
  store i64 %more, ptr %waiters, align 8
  br label %unlocked
unlocked:
  call void @ube.thread.registry.unlock(ptr %program)
  br i1 %already, label %already.complete, label %clock
already.complete:
  br i1 %borrow, label %release.joined, label %completed
clock:
  %started = call i64 @GetTickCount64()
  %forever = icmp eq i64 %timeout, -1
  br label %poll
poll:
  br i1 %borrow, label %native.poll, label %root.poll
native.poll:
  %status = call i32 @ube.target.thread.wait(ptr %handle, i32 0)
  %joined = icmp eq i32 %status, 0
  br i1 %joined, label %release.joined, label %native.status
native.status:
  %waiting = icmp eq i32 %status, 258
  br i1 %waiting, label %pending, label %release.failed
root.poll:
  %state = load atomic i64, ptr %state.ptr acquire, align 8
  %complete = icmp uge i64 %state, 2
  br i1 %complete, label %completed, label %pending
pending:
  %requested = call i1 @ube.thread.stop.requested(ptr %ctx)
  %stop = and i1 %requested, %observe.stop
  %now = call i64 @GetTickCount64()
  %elapsed = sub i64 %now, %started
  %deadline = icmp uge i64 %elapsed, %timeout
  %bounded = xor i1 %forever, true
  %expired = and i1 %bounded, %deadline
  %interrupted = or i1 %stop, %expired
  br i1 %interrupted, label %interrupted.wait, label %pause
pause:
  call void @Sleep(i32 1)
  br label %poll
interrupted.wait:
  br i1 %borrow, label %release.timeout, label %zero
release.timeout:
  %timeout.closed = call i1 @ube.thread.wait.release(ptr %ctx, ptr %record, i1 false)
  br i1 %timeout.closed, label %zero, label %native.failed
release.failed:
  %failed.closed = call i1 @ube.thread.wait.release(ptr %ctx, ptr %record, i1 false)
  br label %native.failed
release.joined:
  %closed = call i1 @ube.thread.wait.release(ptr %ctx, ptr %record, i1 true)
  br i1 %closed, label %completed, label %joined.cleanup.failed
joined.cleanup.failed:
  %joined.state = load atomic i64, ptr %state.ptr acquire, align 8
  %worker.failed = icmp eq i64 %joined.state, 3
  br i1 %worker.failed, label %completed, label %native.failed
completed:
  %result = call { i1, i64 } @ube.thread.completion(ptr %ctx, ptr %record)
  ret { i1, i64 } %result
zero:
  ret { i1, i64 } { i1 true, i64 0 }
invalid:
  %bad = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 5)
  ret { i1, i64 } %bad
native.failed:
  %os = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 57)
  ret { i1, i64 } %os
}

define { i1, i64 } @ube.thread.wait(ptr %ctx, i64 %id, i64 %timeout) {
entry:
  %result = call { i1, i64 } @ube.thread.wait.core(ptr %ctx, i64 %id, i64 %timeout, i1 true)
  ret { i1, i64 } %result
}
define { i1, i64 } @ube.thread.alive(ptr %ctx, i64 %id) {
entry:
  %record = call ptr @ube.thread.record.find(ptr %ctx, i64 %id)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %inspect, label %invalid
inspect:
  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3
  %value = load atomic i64, ptr %state acquire, align 8
  %running = icmp ult i64 %value, 2
  %answer = select i1 %running, i64 -1, i64 0
  %result = call { i1, i64 } @ube.thread.value(i64 %answer)
  ret { i1, i64 } %result
invalid:
  %bad = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 5)
  ret { i1, i64 } %bad
}
define { i1, i64 } @ube.thread.request.stop(ptr %ctx, i64 %id) {
entry:
  %record = call ptr @ube.thread.record.find(ptr %ctx, i64 %id)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %inspect, label %invalid
inspect:
  %state = getelementptr %ube.worker, ptr %record, i32 0, i32 3
  %value = load atomic i64, ptr %state acquire, align 8
  %running = icmp ult i64 %value, 2
  br i1 %running, label %request, label %done
request:
  %flag = getelementptr %ube.worker, ptr %record, i32 0, i32 5
  store atomic i64 1, ptr %flag seq_cst, align 8
  ret { i1, i64 } { i1 true, i64 1 }
done:
  ret { i1, i64 } { i1 true, i64 0 }
invalid:
  %bad = call { i1, i64 } @ube.thread.failure(ptr %ctx, i64 5)
  ret { i1, i64 } %bad
}

; The generated process entry publishes Main's fresh outcome before waiting for workers.
define void @ube.thread.root.complete(ptr %ctx, i1 %success) {
entry:
  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3
  %record = load ptr, ptr %control, align 8
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %publish, label %done
publish:
  %error.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 4
  %state.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 3
  %number = load i64, ptr %ctx, align 8
  %saved = select i1 %success, i64 0, i64 %number
  %state = select i1 %success, i64 2, i64 3
  store i64 %saved, ptr %error.ptr, align 8
  store atomic i64 %state, ptr %state.ptr release, align 8
  ret void
done:
  ret void
}
; Main's return closes no live worker prematurely, including workers with ignored IDs.
define i1 @ube.thread.drain(ptr %ctx) {
entry:
  %saved.error = load i64, ptr %ctx, align 8
  %program = call ptr @ube.thread.program(ptr %ctx)
  %head = getelementptr %ube.program, ptr %program, i32 0, i32 10
  %active.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 7
  %closed.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 8
  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3
  %self = load ptr, ptr %control, align 8
  br label %round
round:
  %first = load atomic ptr, ptr %head acquire, align 8
  br label %scan
scan:
  %record = phi ptr [ %first, %round ], [ %next, %advance ]
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %inspect, label %quiescent
inspect:
  %same = icmp eq ptr %record, %self
  br i1 %same, label %advance, label %join
join:
  %id.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 1
  %id = load i64, ptr %id.ptr, align 8
  %result = call { i1, i64 } @ube.thread.wait.core(ptr %ctx, i64 %id, i64 -1, i1 false)
  %handle.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 2
  call void @ube.thread.registry.lock(ptr %program)
  %handle = load ptr, ptr %handle.ptr, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  %released = icmp eq ptr %handle, null
  br i1 %released, label %advance, label %retained
advance:
  %next = load ptr, ptr %record, align 8
  br label %scan
quiescent:
  call void @ube.thread.registry.lock(ptr %program)
  %active = load atomic i64, ptr %active.ptr acquire, align 8
  %empty = icmp eq i64 %active, 0
  br i1 %empty, label %close, label %again
close:
  store atomic i64 1, ptr %closed.ptr release, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  store i64 %saved.error, ptr %ctx, align 8
  ret i1 true
again:
  call void @ube.thread.registry.unlock(ptr %program)
  call void @Sleep(i32 1)
  br label %round
retained:
  %remaining = load atomic i64, ptr %active.ptr acquire, align 8
  %workers.live = icmp ne i64 %remaining, 0
  br i1 %workers.live, label %retry.observation, label %failed
retry.observation:
  call void @Sleep(i32 1)
  br label %round
failed:
  store i64 %saved.error, ptr %ctx, align 8
  ret i1 false
}
; Disposes completion records only after no worker or waiter can access them.
define i1 @ube.thread.program.dispose(ptr %ctx) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %active.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 7
  %closed.ptr = getelementptr %ube.program, ptr %program, i32 0, i32 8
  %head = getelementptr %ube.program, ptr %program, i32 0, i32 10
  call void @ube.thread.registry.lock(ptr %program)
  %active = load atomic i64, ptr %active.ptr acquire, align 8
  %empty = icmp eq i64 %active, 0
  br i1 %empty, label %inspect.head, label %busy
inspect.head:
  %first = load atomic ptr, ptr %head acquire, align 8
  br label %inspect
inspect:
  %record = phi ptr [ %first, %inspect.head ], [ %next, %advance ]
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %ownership, label %close.admission
ownership:
  %waiters.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 9
  %closing.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 10
  %waiters = load i64, ptr %waiters.ptr, align 8
  %closing = load i64, ptr %closing.ptr, align 8
  %waiting = icmp ne i64 %waiters, 0
  %releasing = icmp ne i64 %closing, 0
  %owned = or i1 %waiting, %releasing
  br i1 %owned, label %busy, label %advance
advance:
  %next = load ptr, ptr %record, align 8
  br label %inspect
close.admission:
  store atomic i64 1, ptr %closed.ptr release, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  br label %release
release:
  %candidate = phi ptr [ %first, %close.admission ], [ %following, %released ]
  %present = icmp ne ptr %candidate, null
  br i1 %present, label %handle, label %discard.head
handle:
  %handle.ptr = getelementptr %ube.worker, ptr %candidate, i32 0, i32 2
  %native = load ptr, ptr %handle.ptr, align 8
  %has.handle = icmp ne ptr %native, null
  br i1 %has.handle, label %close.handle, label %released
close.handle:
  %closed = call i1 @ube.target.thread.close(ptr %native)
  br i1 %closed, label %clear, label %failed
clear:
  store ptr null, ptr %handle.ptr, align 8
  br label %released
released:
  %following = load ptr, ptr %candidate, align 8
  br label %release
discard.head:
  store atomic ptr null, ptr %head release, align 8
  %control = getelementptr %ube.thread, ptr %ctx, i32 0, i32 3
  store ptr null, ptr %control, align 8
  br label %discard
discard:
  %item = phi ptr [ %first, %discard.head ], [ %after, %drop ]
  %remains = icmp ne ptr %item, null
  br i1 %remains, label %drop, label %done
drop:
  %after = load ptr, ptr %item, align 8
  call void @ube.thread.record.drop(ptr %ctx, ptr %item)
  br label %discard
done:
  ret i1 true
busy:
  call void @ube.thread.registry.unlock(ptr %program)
  ret i1 false
failed:
  ret i1 false
}
