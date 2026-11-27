%ube.block = type { ptr, i64, i64, ptr, i64 }
%ube.rootframe = type { ptr, ptr, ptr, i64 }
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
  %root = icmp eq ptr %control, null
  %initial = select i1 %root, i64 0, i64 2
  call void @ube.managed.thread.register(ptr %ctx, i64 %initial)
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
  %bad.stride.low = icmp sle i64 %stride, 0
  %bad.stride.high = icmp sgt i64 %stride, 128
  %bad.stride = or i1 %bad.stride.low, %bad.stride.high
  %bad = or i1 %negative, %bad.stride
  br i1 %bad, label %failed, label %extent
extent:
  %maximum.count = udiv i64 1152921504606846459, %stride
  %extent.large = icmp ugt i64 %count, %maximum.count
  br i1 %extent.large, label %failed, label %size
size:
  %cells = mul i64 %count, %stride
  %payload.bytes = mul i64 %cells, 8
  %total = add i64 %payload.bytes, 40
  %rounded = add i64 %total, 4095
  %pages = lshr i64 %rounded, 12
  %charge = shl i64 %pages, 12
  %available = sub i64 9223372036854775807, %charge
  %head = call ptr @ube.memory.head(ptr %ctx)
  %bytes.ptr = call ptr @ube.memory.bytes(ptr %ctx)
  %count.ptr = call ptr @ube.memory.count(ptr %ctx)
  br label %attempt
attempt:
  %bytes = load atomic i64, ptr %bytes.ptr monotonic, align 8
  %blocks = load atomic i64, ptr %count.ptr monotonic, align 8
  %over.bytes = icmp ugt i64 %bytes, %available
  %over.blocks = icmp uge i64 %blocks, 9223372036854775807
  %over = or i1 %over.bytes, %over.blocks
  br i1 %over, label %miss, label %allocate
allocate:
  %block = call ptr @ube.target.allocate(i64 %charge)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %allocated, label %miss
miss:
  br label %failed
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
  %layout.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 3
  %repeat.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 4
  store ptr null, ptr %layout.ptr, align 8
  store i64 0, ptr %repeat.ptr, align 8
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
define internal i1 @ube.array.tryresize(ptr %ctx, ptr %array, i64 %count, i64 %preserve, i64 %stride, ptr %layout) {
entry:
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  %negative = icmp slt i64 %count, 0
  %outside.long = icmp ugt i64 %count, 2147483647
  %invalid.count = or i1 %negative, %outside.long
  br i1 %invalid.count, label %argument.fail, label %empty.test
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
  call void @ube.managed.owner.layout(ptr %ctx, ptr %block, ptr %layout, i64 %count)
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
  %managed = icmp ne ptr %layout, null
  br i1 %managed, label %publish.managed, label %install
publish.managed:
  %published.data = getelementptr %ube.block, ptr %block, i64 1
  call void @ube.managed.publish.range(ptr %ctx, ptr %published.data, ptr %layout, i64 %count)
  br label %install
install:
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
define internal i1 @ube.array.trycopy(ptr %ctx, ptr %destination, ptr %source, i64 %stride, ptr %layout) {
entry:
  %root = alloca %ube.rootframe, align 8
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  %snapshot = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %source)
  %lower = extractvalue { i64, i64, ptr, ptr } %snapshot, 0
  %upper = extractvalue { i64, i64, ptr, ptr } %snapshot, 1
  %source.data = extractvalue { i64, i64, ptr, ptr } %snapshot, 2
  %pin = extractvalue { i64, i64, ptr, ptr } %snapshot, 3
  %distance = sub i64 %upper, %lower
  %count = add i64 %distance, 1
  %managed = icmp ne ptr %layout, null
  %root.count = select i1 %managed, i64 %count, i64 0
  call void @ube.managed.root.push(ptr %ctx, ptr %root, ptr %source.data, ptr %layout, i64 %root.count)
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %empty.copy, label %allocate
empty.copy:
  call void @ube.array.clear(ptr %ctx, ptr %destination)
  call void @ube.managed.root.pop(ptr %ctx, ptr %root)
  call void @ube.block.drop(ptr %ctx, ptr %pin)
  %empty.collected = call i1 @ube.memory.collect(ptr %ctx)
  ret i1 true
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 %count, i64 %stride)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %copy, label %memory.fail
copy:
  %destination.data = getelementptr %ube.block, ptr %block, i64 1
  call void @ube.managed.owner.layout(ptr %ctx, ptr %block, ptr %layout, i64 %count)
  %cells = mul i64 %count, %stride
  call void @ube.cells.copy(ptr %source.data, ptr %destination.data, i64 %cells)
  br i1 %managed, label %publish.managed, label %install
publish.managed:
  call void @ube.managed.publish.range(ptr %ctx, ptr %destination.data, ptr %layout, i64 %count)
  br label %install
install:
  call void @ube.array.install(ptr %ctx, ptr %destination, ptr %block, i64 %lower, i64 %upper)
  call void @ube.managed.root.pop(ptr %ctx, ptr %root)
  call void @ube.block.drop(ptr %ctx, ptr %pin)
  %collected = call i1 @ube.memory.collect(ptr %ctx)
  ret i1 true
memory.fail:
  call void @ube.managed.root.pop(ptr %ctx, ptr %root)
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
define internal i1 @ube.array.move(ptr %ctx, ptr %destination, ptr %source) {
entry:
  %same = icmp eq ptr %destination, %source
  br i1 %same, label %success, label %lock
lock:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.program.storage.lock(ptr %program)
  %destination.lock = call ptr @ube.array.lock.address(ptr %program, ptr %destination)
  %source.lock = call ptr @ube.array.lock.address(ptr %program, ptr %source)
  %ordered = icmp ult ptr %destination.lock, %source.lock
  %first = select i1 %ordered, ptr %destination, ptr %source
  %second = select i1 %ordered, ptr %source, ptr %destination
  %collision = icmp eq ptr %destination.lock, %source.lock
  call void @ube.array.lock(ptr %program, ptr %first)
  br i1 %collision, label %inspect, label %lock.second
lock.second:
  call void @ube.array.lock(ptr %program, ptr %second)
  br label %inspect
inspect:
  %source.upper.ptr = getelementptr i64, ptr %source, i64 1
  %source.data.ptr = getelementptr i64, ptr %source, i64 2
  %source.block.ptr = getelementptr i64, ptr %source, i64 3
  %lower = load atomic i64, ptr %source monotonic, align 8
  %upper = load atomic i64, ptr %source.upper.ptr monotonic, align 8
  %data = load ptr, ptr %source.data.ptr
  %block = load ptr, ptr %source.block.ptr
  %nonempty = icmp sge i64 %upper, %lower
  %inline = icmp eq ptr %block, null
  %invalid = and i1 %nonempty, %inline
  br i1 %invalid, label %reject, label %commit
reject:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %unlock
commit:
  %destination.upper.ptr = getelementptr i64, ptr %destination, i64 1
  %destination.data.ptr = getelementptr i64, ptr %destination, i64 2
  %destination.block.ptr = getelementptr i64, ptr %destination, i64 3
  %old = load ptr, ptr %destination.block.ptr
  store atomic i64 %lower, ptr %destination monotonic, align 8
  store atomic i64 %upper, ptr %destination.upper.ptr monotonic, align 8
  store ptr %data, ptr %destination.data.ptr
  store ptr %block, ptr %destination.block.ptr
  store atomic i64 0, ptr %source monotonic, align 8
  store atomic i64 -1, ptr %source.upper.ptr monotonic, align 8
  store ptr null, ptr %source.data.ptr
  store ptr null, ptr %source.block.ptr
  call void @ube.block.drop(ptr %ctx, ptr %old)
  br label %unlock
unlock:
  %result = phi i1 [ false, %reject ], [ true, %commit ]
  br i1 %collision, label %unlock.first, label %unlock.second
unlock.second:
  call void @ube.array.unlock(ptr %program, ptr %second)
  br label %unlock.first
unlock.first:
  call void @ube.array.unlock(ptr %program, ptr %first)
  call void @ube.program.storage.unlock(ptr %program)
  ret i1 %result
success:
  ret i1 true
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
  %allocated = icmp ne ptr %block, null
  br i1 %allocated, label %done, label %recover
recover:
  %collected = call {i1,i64} @ube.managed.collect(ptr %ctx, i64 0)
  call void @ube.program.storage.lock(ptr %program)
  %retry = call ptr @ube.memory.new.locked(ptr %ctx, i64 %count, i64 %stride)
  call void @ube.program.storage.unlock(ptr %program)
  ret ptr %retry
done:
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
  call void @ube.managed.safe(ptr %ctx)
  %wide.length = call i32 @ube.target.file.utf8(ptr %packed, i32 %length32, ptr %wide, i32 4096)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %directory.handle = call ptr @ube.target.directory.open(ptr %wide)
  call void @ube.managed.enter(ptr %ctx)
  br label %opened
open.file:
  call void @ube.managed.safe(ptr %ctx)
  %file.handle = call ptr @ube.target.file.open(ptr %wide, i1 %write)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %kind = call i32 @ube.target.file.type(ptr %handle)
  call void @ube.managed.enter(ptr %ctx)
  %regular = icmp eq i32 %kind, 1
  br i1 %regular, label %mode.check, label %query.fail
mode.check:
  br i1 %directory, label %directory.check, label %file.check
directory.check:
  call void @ube.managed.safe(ptr %ctx)
  %is.directory = call i1 @ube.target.directory.check(ptr %handle)
  call void @ube.managed.enter(ptr %ctx)
  br i1 %is.directory, label %success.create, label %query.fail
file.check:
  br i1 %write, label %success.create, label %query
query:
  store atomic i64 0, ptr %size.out monotonic, align 8
  call void @ube.managed.safe(ptr %ctx)
  %queried = call i1 @ube.target.file.size(ptr %handle, ptr %size.out)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %closed = call i1 @ube.target.file.close(ptr %handle)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %write.ok = call i1 @ube.target.file.write(ptr %handle, ptr %scratch, i32 %count32, ptr %native.progress)
  call void @ube.managed.enter(ptr %ctx)
  br label %observed
read:
  call void @ube.managed.safe(ptr %ctx)
  %read.ok = call i1 @ube.target.file.read(ptr %handle, ptr %scratch, i32 %count32, ptr %native.progress)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %closed = call i1 @ube.target.file.close(ptr %handle)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %ok = call i1 @ube.target.file.flush(ptr %handle)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %wide = call ptr @ube.target.system.commandline()
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %size32 = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr null, i32 0)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %converted = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %scratch, i32 131072)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %native.handle = call ptr @ube.target.system.standard(i32 %which)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %accepted = call i1 @ube.target.file.write(ptr %native.handle, ptr %scratch, i32 %count32, ptr %progress)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %size32 = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr null, i32 0)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %converted = call i32 @ube.target.system.utf8(ptr %wide, i32 %units, ptr %packed, i32 4096)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %physical.length = call i32 @ube.target.path.final(ptr %handle, ptr %wide.output, i32 4097)
  call void @ube.managed.enter(ptr %ctx)
  br label %length
decode:
  %input.length = call i32 @ube.path.decode(ptr %input, ptr %scratch, ptr %wide.input)
  %input.valid = icmp sgt i32 %input.length, 0
  br i1 %input.valid, label %full, label %request.fail
full:
  call void @ube.managed.safe(ptr %ctx)
  %full.length = call i32 @ube.target.path.full(ptr %wide.input, ptr %wide.output, i32 4097)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %comparison = call i32 @ube.target.path.compare(ptr %wide.first, i32 %first.length, ptr %wide.second, i32 %second.length)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %accepted = call i1 @ube.target.file.info(ptr %handle, ptr %information)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %accepted = call i1 @ube.target.file.size(ptr %handle, ptr %size)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %units = call i32 @ube.target.system.executable(ptr %wide, i32 4097)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %ticks = call i64 @ube.target.system.clock()
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %move.error = call i64 @ube.target.file.replace(ptr %wide.first, ptr %wide.second)
  call void @ube.managed.enter(ptr %ctx)
  br label %result
create.check:
  %create = icmp eq i64 %operation, 1
  br i1 %create, label %create.directory, label %remove.check
create.directory:
  call void @ube.managed.safe(ptr %ctx)
  %create.error = call i64 @ube.target.directory.create(ptr %wide.first)
  call void @ube.managed.enter(ptr %ctx)
  br label %result
remove.check:
  %directory = icmp eq i64 %operation, 2
  br i1 %directory, label %remove.directory, label %delete.file
remove.directory:
  call void @ube.managed.safe(ptr %ctx)
  %remove.error = call i64 @ube.target.directory.remove(ptr %wide.first)
  call void @ube.managed.enter(ptr %ctx)
  br label %result
delete.file:
  call void @ube.managed.safe(ptr %ctx)
  %delete.error = call i64 @ube.target.file.delete(ptr %wide.first)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %attributes = call i64 @ube.target.path.attributes(ptr %wide)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %job = call ptr @ube.target.process.job()
  call void @ube.managed.enter(ptr %ctx)
  store ptr %job, ptr %state
  %job.failed = icmp eq ptr %job, null
  br i1 %job.failed, label %io.fail, label %job.limit
job.limit:
  call void @ube.process.zero(ptr %job.information, i64 144)
  %limit.flags = getelementptr i8, ptr %job.information, i64 16
  store i32 8192, ptr %limit.flags
  call void @ube.managed.safe(ptr %ctx)
  %limited = call i1 @ube.target.process.limit(ptr %job, ptr %job.information)
  call void @ube.managed.enter(ptr %ctx)
  br i1 %limited, label %input, label %io.fail
input:
  call void @ube.managed.safe(ptr %ctx)
  %input.handle = call ptr @ube.target.process.nullinput()
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %duplicated = call i1 @ube.target.process.duplicate(ptr %log.handle, ptr %log.ptr)
  call void @ube.managed.enter(ptr %ctx)
  call void @ube.resource.unlock(ptr %log.slot)
  br i1 %duplicated, label %attribute.measure, label %io.fail
attribute.measure:
  store atomic i64 0, ptr %attribute.size monotonic, align 8
  call void @ube.managed.safe(ptr %ctx)
  %measurement = call i1 @ube.target.process.attributes(ptr null, ptr %attribute.size)
  call void @ube.managed.enter(ptr %ctx)
  %size = load atomic i64, ptr %attribute.size monotonic, align 8
  %positive = icmp ugt i64 %size, 0
  %bounded = icmp ule i64 %size, 4096
  %valid.size = and i1 %positive, %bounded
  %expected.failure = xor i1 %measurement, true
  %measured = and i1 %valid.size, %expected.failure
  br i1 %measured, label %attribute.initialize, label %io.fail
attribute.initialize:
  call void @ube.managed.safe(ptr %ctx)
  %initialized = call i1 @ube.target.process.attributes(ptr %attributes, ptr %attribute.size)
  call void @ube.managed.enter(ptr %ctx)
  br i1 %initialized, label %attribute.values, label %io.fail
attribute.values:
  store i1 true, ptr %attribute.live
  %private.log = load ptr, ptr %log.ptr
  %second.handle = getelementptr ptr, ptr %inherited, i64 1
  store ptr %input.handle, ptr %inherited
  store ptr %private.log, ptr %second.handle
  call void @ube.managed.safe(ptr %ctx)
  %listed = call i1 @ube.target.process.handles(ptr %attributes, ptr %inherited)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %created = call i1 @ube.target.process.create(ptr %wide.app, ptr %wide.command, ptr %wide.directory, ptr %startup, ptr %information)
  call void @ube.managed.enter(ptr %ctx)
  br i1 %created, label %created.owned, label %io.fail
created.owned:
  %native.process = load ptr, ptr %information
  %native.thread.ptr = getelementptr i8, ptr %information, i64 8
  %native.thread = load ptr, ptr %native.thread.ptr
  store ptr %native.process, ptr %process.ptr
  store ptr %native.thread, ptr %thread.ptr
  call void @ube.managed.safe(ptr %ctx)
  %assigned = call i1 @ube.target.process.assign(ptr %job, ptr %native.process)
  call void @ube.managed.enter(ptr %ctx)
  br i1 %assigned, label %contained, label %io.fail
contained:
  store atomic i64 1, ptr %attached.ptr monotonic, align 8
  call void @ube.managed.safe(ptr %ctx)
  %resumed = call i1 @ube.target.process.resume(ptr %native.thread)
  call void @ube.managed.enter(ptr %ctx)
  br i1 %resumed, label %started, label %io.fail
started:
  store atomic i64 1, ptr %started.ptr monotonic, align 8
  call void @ube.managed.safe(ptr %ctx)
  call void @ube.target.process.deleteattributes(ptr %attributes)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  call void @ube.target.process.deleteattributes(ptr %attributes)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %observation = call i32 @ube.process.observe(ptr %state, i32 %timeout)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %observation = call i32 @ube.process.observe(ptr %state, i32 0)
  call void @ube.managed.enter(ptr %ctx)
  %complete = icmp eq i32 %observation, 1
  br i1 %complete, label %success, label %kind
kind:
  %attached.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 8
  %attached = load atomic i64, ptr %attached.ptr monotonic, align 8
  %contained = icmp ne i64 %attached, 0
  br i1 %contained, label %job, label %process
job:
  %job.handle = load ptr, ptr %state
  call void @ube.managed.safe(ptr %ctx)
  %job.stopped = call i1 @ube.target.process.terminatejob(ptr %job.handle)
  call void @ube.managed.enter(ptr %ctx)
  br i1 %job.stopped, label %success, label %io.fail
process:
  %process.ptr = getelementptr %ube.process, ptr %state, i32 0, i32 1
  %process.handle = load ptr, ptr %process.ptr
  %exists = icmp ne ptr %process.handle, null
  br i1 %exists, label %stop, label %success
stop:
  call void @ube.managed.safe(ptr %ctx)
  %stopped = call i1 @ube.target.process.terminate(ptr %process.handle)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %observation = call i32 @ube.process.observe(ptr %state, i32 0)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %closed = call i1 @ube.target.process.close(ptr %handle)
  call void @ube.managed.enter(ptr %ctx)
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
%ube.managed.layout = type { i64, i64, ptr, i64, ptr, i64, ptr }
%ube.managed.array = type { i64, ptr }
%ube.managed.record = type { ptr, i64, i64, ptr, ptr, i64, i64, ptr, i64, ptr, ptr, i64, ptr }
%ube.managed.state = type { ptr, ptr, ptr, i64, i64, i64, i64, i64, i64, i64, ptr, %ube.rootframe, i64, ptr, ptr, ptr, i64, i64 }
@ube.managed.next = internal global i64 1

define internal ptr @ube.managed.state(ptr %ctx) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %slot = getelementptr %ube.program, ptr %program, i32 0, i32 14
  %state = load atomic ptr, ptr %slot acquire, align 8
  ret ptr %state
}

define internal i64 @ube.managed.issue() {
entry:
  br label %attempt
attempt:
  %old = load atomic i64, ptr @ube.managed.next seq_cst, align 8
  %valid = icmp ult i64 %old, 9223372036854775807
  br i1 %valid, label %issue, label %exhausted
issue:
  %next = add i64 %old, 1
  %pair = cmpxchg ptr @ube.managed.next, i64 %old, i64 %next seq_cst seq_cst
  %won = extractvalue {i64,i1} %pair, 1
  br i1 %won, label %done, label %attempt
done:
  ret i64 %old
exhausted:
  ret i64 0
}

; Identity lookup visits allocation metadata, never graph edges.
define internal ptr @ube.managed.find(ptr %state, i64 %identity) {
entry:
  %valid = icmp sgt i64 %identity, 0
  %present = icmp ne ptr %state, null
  %ready = and i1 %valid, %present
  br i1 %ready, label %head, label %absent
head:
  %first = load atomic ptr, ptr %state acquire, align 8
  br label %scan
scan:
  %record = phi ptr [ %first, %head ], [ %next, %advance ]
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %inspect, label %absent
inspect:
  %id.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 1
  %id = load i64, ptr %id.ptr, align 8
  %same = icmp eq i64 %id, %identity
  br i1 %same, label %found, label %advance
advance:
  %next = load ptr, ptr %record, align 8
  br label %scan
found:
  ret ptr %record
absent:
  ret ptr null
}

; A frame only links exact metadata; it neither allocates nor walks managed edges.
define void @ube.managed.root.push(ptr %ctx, ptr %frame, ptr %base, ptr %layout, i64 %count) {
entry:
  %head = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4
  %old = load ptr, ptr %head, align 8
  %base.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 1
  %layout.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 2
  %count.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 3
  store ptr %old, ptr %frame, align 8
  store ptr %base, ptr %base.ptr, align 8
  store ptr %layout, ptr %layout.ptr, align 8
  store i64 %count, ptr %count.ptr, align 8
  store atomic ptr %frame, ptr %head release, align 8
  ret void
}

; Construction candidates are unpublished; dropping their root cannot run user code.
define void @ube.managed.root.pop(ptr %ctx, ptr %frame) {
entry:
  %head = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4
  %candidates = getelementptr %ube.thread, ptr %ctx, i32 0, i32 5
  br label %scan
scan:
  %link = phi ptr [ %candidates, %entry ], [ %link, %abandon ], [ %next.ptr, %keep ]
  %candidate = load ptr, ptr %link, align 8
  %done = icmp eq ptr %candidate, null
  br i1 %done, label %unlink, label %inspect
inspect:
  %next.ptr = getelementptr %ube.managed.record, ptr %candidate, i32 0, i32 4
  %owner.ptr = getelementptr %ube.managed.record, ptr %candidate, i32 0, i32 3
  %owner = load ptr, ptr %owner.ptr, align 8
  %mine = icmp eq ptr %owner, %frame
  br i1 %mine, label %abandon, label %keep
abandon:
  %next = load ptr, ptr %next.ptr, align 8
  store ptr %next, ptr %link, align 8
  store ptr null, ptr %owner.ptr, align 8
  store ptr null, ptr %next.ptr, align 8
  br label %scan
keep:
  br label %scan
unlink:
  %previous = load ptr, ptr %frame, align 8
  store atomic ptr %previous, ptr %head release, align 8
  ret void
}
define void @ube.managed.root.restore(ptr %ctx, ptr %sentinel) {
entry:
  %head = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4
  br label %scan
scan:
  %frame = load ptr, ptr %head, align 8
  %present = icmp ne ptr %frame, null
  br i1 %present, label %pop, label %done
pop:
  %last = icmp eq ptr %frame, %sentinel
  call void @ube.managed.root.pop(ptr %ctx, ptr %frame)
  br i1 %last, label %done, label %scan
done:
  ret void
}
; Snapshot queries are legal only for the elected coordinator.
define internal ptr @ube.managed.owned(ptr %ctx) {
entry:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %exists = icmp ne ptr %state, null
  br i1 %exists, label %inspect, label %bad
inspect:
  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2
  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8
  %mine = icmp eq ptr %owner, %ctx
  br i1 %mine, label %done, label %bad
done:
  ret ptr %state
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret ptr null
}
define i1 @ube.managed.snapshot.counts(ptr %ctx, ptr %allocations, ptr %roots) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ok = icmp ne ptr %state, null
  br i1 %ok, label %read, label %bad
read:
  %allocation.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 8
  %root.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 9
  %allocation.count = load i64, ptr %allocation.ptr, align 8
  %root.count = load i64, ptr %root.ptr, align 8
  %valid = icmp sge i64 %root.count, 0
  br i1 %valid, label %publish, label %snapshot.error
publish:
  store i64 %allocation.count, ptr %allocations, align 8
  store i64 %root.count, ptr %roots, align 8
  ret i1 true
snapshot.error:
  %error.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 6
  %error = load i64, ptr %error.ptr, align 8
  store atomic i64 %error, ptr %ctx monotonic, align 8
  br label %bad
bad:
  ret i1 false
}
define i1 @ube.managed.allocation.at(ptr %ctx, i64 %index, ptr %output) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ok = icmp ne ptr %state, null
  br i1 %ok, label %check, label %failed
check:
  %count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 8
  %count = load i64, ptr %count.ptr, align 8
  %valid = icmp ult i64 %index, %count
  br i1 %valid, label %read, label %bad
read:
  %snapshot.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 10
  %snapshot.data = load ptr, ptr %snapshot.ptr, align 8
  %slot = getelementptr i64, ptr %snapshot.data, i64 %index
  %identity = load i64, ptr %slot, align 8
  store i64 %identity, ptr %output, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
define i1 @ube.managed.mark(ptr %ctx, i64 %identity, ptr %fresh) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ok = icmp ne ptr %state, null
  br i1 %ok, label %phase, label %failed
phase:
  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4
  %phase.value = load i64, ptr %phase.ptr, align 8
  %marking = icmp eq i64 %phase.value, 1
  br i1 %marking, label %empty, label %bad
empty:
  %zero = icmp eq i64 %identity, 0
  br i1 %zero, label %unchanged, label %find
find:
  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %inspect, label %bad
inspect:
  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2
  %mark = load i64, ptr %mark.ptr, align 8
  %first = icmp eq i64 %mark, 0
  br i1 %first, label %publish, label %unchanged
publish:
  store i64 1, ptr %mark.ptr, align 8
  store i64 -1, ptr %fresh, align 8
  ret i1 true
unchanged:
  store i64 0, ptr %fresh, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
define i1 @ube.managed.marked(ptr %ctx, i64 %identity, ptr %output) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ok = icmp ne ptr %state, null
  br i1 %ok, label %empty, label %failed
empty:
  %zero = icmp eq i64 %identity, 0
  br i1 %zero, label %unmarked, label %find
find:
  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %read, label %bad
read:
  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2
  %mark = load i64, ptr %mark.ptr, align 8
  %yes = icmp ne i64 %mark, 0
  %value = select i1 %yes, i64 -1, i64 0
  store i64 %value, ptr %output, align 8
  ret i1 true
unmarked:
  store i64 0, ptr %output, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
define i1 @ube.managed.seal(ptr %ctx) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ok = icmp ne ptr %state, null
  br i1 %ok, label %phase, label %failed
phase:
  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4
  %old = load i64, ptr %phase.ptr, align 8
  %marking = icmp eq i64 %old, 1
  br i1 %marking, label %commit, label %bad
commit:
  store i64 2, ptr %phase.ptr, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
; Root transfer primitives are noninterruptible and never poll or allocate.
define i64 @ube.managed.load(ptr %ctx, ptr %source, ptr %root) {
entry:
  %identity = load atomic i64, ptr %source acquire, align 8
  store atomic i64 %identity, ptr %root release, align 8
  ret i64 %identity
}
define void @ube.managed.store(ptr %ctx, ptr %destination, i64 %identity) {
entry:
  store atomic i64 %identity, ptr %destination release, align 8
  ret void
}
define void @ube.managed.return(ptr %ctx, i64 %identity) {
entry:
  %handoff = getelementptr %ube.thread, ptr %ctx, i32 0, i32 8
  store atomic i64 %identity, ptr %handoff release, align 8
  ret void
}
define i64 @ube.managed.take(ptr %ctx, ptr %root) {
entry:
  %handoff = getelementptr %ube.thread, ptr %ctx, i32 0, i32 8
  %identity = load atomic i64, ptr %handoff acquire, align 8
  store atomic i64 %identity, ptr %root release, align 8
  store atomic i64 0, ptr %handoff release, align 8
  ret i64 %identity
}
define void @ube.managed.discard(ptr %ctx) {
entry:
  %handoff = getelementptr %ube.thread, ptr %ctx, i32 0, i32 8
  store atomic i64 0, ptr %handoff release, align 8
  ret void
}
define void @ube.managed.thread.register(ptr %ctx, i64 %initial) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %roots = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4
  %candidates = getelementptr %ube.thread, ptr %ctx, i32 0, i32 5
  %next = getelementptr %ube.thread, ptr %ctx, i32 0, i32 6
  %status = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7
  %handoff = getelementptr %ube.thread, ptr %ctx, i32 0, i32 8
  store ptr null, ptr %roots, align 8
  store ptr null, ptr %candidates, align 8
  store atomic i64 %initial, ptr %status release, align 8
  store atomic i64 0, ptr %handoff release, align 8
  call void @ube.thread.registry.lock(ptr %program)
  %head = getelementptr %ube.program, ptr %program, i32 0, i32 15
  %old = load ptr, ptr %head, align 8
  store ptr %old, ptr %next, align 8
  store ptr %ctx, ptr %head, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  ret void
}
define void @ube.managed.thread.unregister(ptr %ctx) {
entry:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.thread.registry.lock(ptr %program)
  %head = getelementptr %ube.program, ptr %program, i32 0, i32 15
  br label %scan
scan:
  %link = phi ptr [ %head, %entry ], [ %next, %advance ]
  %thread = load ptr, ptr %link, align 8
  %exists = icmp ne ptr %thread, null
  br i1 %exists, label %inspect, label %done
inspect:
  %next = getelementptr %ube.thread, ptr %thread, i32 0, i32 6
  %same = icmp eq ptr %thread, %ctx
  br i1 %same, label %unlink, label %advance
advance:
  br label %scan
unlink:
  %following = load ptr, ptr %next, align 8
  store ptr %following, ptr %link, align 8
  store ptr null, ptr %next, align 8
  %status = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7
  store atomic i64 4, ptr %status release, align 8
  br label %done
done:
  call void @ube.thread.registry.unlock(ptr %program)
  ret void
}
; Calling threads publish every exact root before invoking this gate.
define void @ube.managed.enter(ptr %ctx) {
entry:
  %status = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7
  %state = call ptr @ube.managed.state(ptr %ctx)
  %present = icmp ne ptr %state, null
  br i1 %present, label %admit, label %plain
plain:
  store atomic i64 0, ptr %status seq_cst, align 8
  ret void
admit:
  store atomic i64 0, ptr %status seq_cst, align 8
  %request.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3
  %request = load atomic i64, ptr %request.ptr seq_cst, align 8
  %requested = icmp ne i64 %request, 0
  br i1 %requested, label %inspect.owner, label %done
inspect.owner:
  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2
  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8
  %mine = icmp eq ptr %owner, %ctx
  br i1 %mine, label %done, label %park
park:
  store atomic i64 1, ptr %status seq_cst, align 8
  br label %wait
wait:
  %active = load atomic i64, ptr %request.ptr seq_cst, align 8
  %finished = icmp eq i64 %active, 0
  br i1 %finished, label %admit, label %yield
yield:
  call void @Sleep(i32 0)
  br label %wait
done:
  ret void
}
define void @ube.managed.safe(ptr %ctx) {
entry:
  %status = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7
  store atomic i64 2, ptr %status seq_cst, align 8
  ret void
}
; Installation occurs before project/module initialization and worker publication.
define i1 @ube.managed.install(ptr %ctx, ptr %callback) {
entry:
  %valid = icmp ne ptr %callback, null
  br i1 %valid, label %existing, label %bad
existing:
  %previous = call ptr @ube.managed.state(ptr %ctx)
  %installed = icmp ne ptr %previous, null
  br i1 %installed, label %compare, label %allocate
compare:
  %old.callback.ptr = getelementptr %ube.managed.state, ptr %previous, i32 0, i32 1
  %old.callback = load ptr, ptr %old.callback.ptr, align 8
  %same = icmp eq ptr %old.callback, %callback
  br i1 %same, label %done, label %bad
allocate:
  %end = getelementptr %ube.managed.state, ptr null, i64 1
  %bytes = ptrtoint ptr %end to i64
  %rounded = add i64 %bytes, 7
  %cells = lshr i64 %rounded, 3
  %block = call ptr @ube.memory.new(ptr %ctx, i64 %cells, i64 1)
  %allocated = icmp ne ptr %block, null
  br i1 %allocated, label %publish, label %memory
publish:
  %state = getelementptr %ube.block, ptr %block, i64 1
  %callback.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 1
  store ptr %callback, ptr %callback.ptr, align 8
  %program = call ptr @ube.thread.program(ptr %ctx)
  %slot = getelementptr %ube.program, ptr %program, i32 0, i32 14
  store atomic ptr %state, ptr %slot release, align 8
  br label %done
done:
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret i1 false
memory:
  store atomic i64 7, ptr %ctx monotonic, align 8
  ret i1 false
}
; The program owns this frame's storage until orderly managed shutdown.
define void @ube.managed.globals(ptr %ctx, ptr %layout) {
entry:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %exists = icmp ne ptr %state, null
  br i1 %exists, label %frame, label %done
frame:
  %root = getelementptr %ube.managed.state, ptr %state, i32 0, i32 11
  %base.ptr = getelementptr %ube.rootframe, ptr %root, i32 0, i32 1
  %old = load ptr, ptr %base.ptr, align 8
  %registered = icmp ne ptr %old, null
  br i1 %registered, label %done, label %register
register:
  %base = call ptr @ube.storage.address(ptr %ctx, i64 0)
  %present = icmp ne ptr %layout, null
  %count = zext i1 %present to i64
  call void @ube.managed.root.push(ptr %ctx, ptr %root, ptr %base, ptr %layout, i64 %count)
  br label %done
done:
  ret void
}
define internal ptr @ube.text.find(ptr %ctx, i64 %identity) {
entry:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %kind, label %bad
kind:
  %kind.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 11
  %value = load i64, ptr %kind.ptr, align 8
  %text = icmp eq i64 %value, 1
  br i1 %text, label %done, label %bad
done:
  ret ptr %record
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret ptr null
}
define internal ptr @ube.managed.candidate(ptr %ctx, i64 %identity) {
entry:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %owner, label %bad
owner:
  %thread.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 10
  %thread = load ptr, ptr %thread.ptr, align 8
  %mine = icmp eq ptr %thread, %ctx
  %frame.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 3
  %frame = load ptr, ptr %frame.ptr, align 8
  %private = icmp ne ptr %frame, null
  %owned = and i1 %mine, %private
  br i1 %owned, label %done, label %bad
done:
  ret ptr %record
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret ptr null
}
define internal ptr @ube.text.candidate(ptr %ctx, i64 %identity) {
entry:
  %record = call ptr @ube.text.find(ptr %ctx, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %candidate, label %failed
candidate:
  %owned = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)
  ret ptr %owned
failed:
  ret ptr null
}
define internal void @ube.managed.unlink(ptr %ctx, ptr %record) {
entry:
  %head = getelementptr %ube.thread, ptr %ctx, i32 0, i32 5
  br label %scan
scan:
  %link = phi ptr [ %head, %entry ], [ %next.ptr, %advance ]
  %item = load ptr, ptr %link, align 8
  %present = icmp ne ptr %item, null
  br i1 %present, label %inspect, label %done
inspect:
  %next.ptr = getelementptr %ube.managed.record, ptr %item, i32 0, i32 4
  %same = icmp eq ptr %item, %record
  br i1 %same, label %unlink, label %advance
advance:
  br label %scan
unlink:
  %next = load ptr, ptr %next.ptr, align 8
  store ptr %next, ptr %link, align 8
  store ptr null, ptr %next.ptr, align 8
  %owner.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 3
  %thread.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 10
  store ptr null, ptr %owner.ptr, align 8
  store ptr null, ptr %thread.ptr, align 8
  br label %done
done:
  ret void
}
define {i1,i64} @ube.text.length(ptr %ctx, ptr %slot, i1 %scalars) {
entry:
  %identity = load atomic i64, ptr %slot acquire, align 8
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %zero, label %find
find:
  %record = call ptr @ube.text.find(ptr %ctx, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %read, label %failed
read:
  %bytes.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5
  %scalars.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 6
  %length.ptr = select i1 %scalars, ptr %scalars.ptr, ptr %bytes.ptr
  %length = load i64, ptr %length.ptr, align 8
  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %length, 1
  ret {i1,i64} %result
zero:
  ret {i1,i64} {i1 true,i64 0}
failed:
  ret {i1,i64} zeroinitializer
}
define i1 @ube.text.read(ptr %ctx, ptr %slot, i64 %index, ptr %output) {
entry:
  %identity = load atomic i64, ptr %slot acquire, align 8
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %bounds, label %find
find:
  %record = call ptr @ube.text.find(ptr %ctx, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %check, label %failed
check:
  %length.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5
  %length = load i64, ptr %length.ptr, align 8
  %valid = icmp ult i64 %index, %length
  br i1 %valid, label %read, label %bounds
read:
  %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %payload = load ptr, ptr %payload.ptr, align 8
  %byte.ptr = getelementptr i8, ptr %payload, i64 %index
  %byte = load i8, ptr %byte.ptr, align 1
  %value = zext i8 %byte to i64
  store i64 %value, ptr %output, align 8
  ret i1 true
bounds:
  store atomic i64 9, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
; Reserves collection metadata before publishing a managed record; collection never grows it.
define internal i1 @ube.managed.register(ptr %ctx, ptr %state, ptr %record) {
entry:
  %retry.used = alloca i1, align 1
  store i1 false, ptr %retry.used, align 1
  %program = call ptr @ube.thread.program(ptr %ctx)
  %request.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3
  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4
  %lease.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 14
  %buffer.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 15
  %capacity.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 16
  %live.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 17
  br label %lock
lock:
  call void @ube.managed.enter(ptr %ctx)
  call void @ube.program.storage.lock(ptr %program)
  %request = load atomic i64, ptr %request.ptr seq_cst, align 8
  %phase = load i64, ptr %phase.ptr, align 8
  %lease = load ptr, ptr %lease.ptr, align 8
  %requested = icmp ne i64 %request, 0
  %phased = icmp ne i64 %phase, 0
  %leased = icmp ne ptr %lease, null
  %active.phase = or i1 %requested, %phased
  %active = or i1 %active.phase, %leased
  br i1 %active, label %park, label %count
park:
  call void @ube.program.storage.unlock(ptr %program)
  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2
  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8
  %mine = icmp eq ptr %owner, %ctx
  br i1 %mine, label %failed, label %lock
count:
  %live = load i64, ptr %live.ptr, align 8
  %count.fits = icmp ult i64 %live, 2147483647
  br i1 %count.fits, label %capacity, label %unlock.failed
capacity:
  %needed = add i64 %live, 1
  %old.capacity = load i64, ptr %capacity.ptr, align 8
  %fits = icmp ule i64 %needed, %old.capacity
  br i1 %fits, label %publish, label %grow
grow:
  %doubled = shl i64 %old.capacity, 1
  %empty = icmp eq i64 %old.capacity, 0
  %initial = select i1 %empty, i64 16, i64 %doubled
  %too.large = icmp ugt i64 %initial, 2147483647
  %new.capacity = select i1 %too.large, i64 2147483647, i64 %initial
  %cells = shl i64 %new.capacity, 1
  %buffer = call ptr @ube.memory.new.locked(ptr %ctx, i64 %cells, i64 1)
  %allocated = icmp ne ptr %buffer, null
  br i1 %allocated, label %replace, label %retry
replace:
  %snapshot = getelementptr %ube.block, ptr %buffer, i64 1
  %queue = getelementptr i64, ptr %snapshot, i64 %new.capacity
  %snapshot.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 10
  %queue.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 13
  %old.buffer = load ptr, ptr %buffer.ptr, align 8
  store ptr %snapshot, ptr %snapshot.ptr, align 8
  store ptr %queue, ptr %queue.ptr, align 8
  store ptr %buffer, ptr %buffer.ptr, align 8
  store i64 %new.capacity, ptr %capacity.ptr, align 8
  call void @ube.block.drop(ptr %ctx, ptr %old.buffer)
  br label %publish
publish:
  %old.head = load atomic ptr, ptr %state acquire, align 8
  store ptr %old.head, ptr %record, align 8
  store atomic ptr %record, ptr %state release, align 8
  store i64 %needed, ptr %live.ptr, align 8
  call void @ube.program.storage.unlock(ptr %program)
  ret i1 true
retry:
  call void @ube.program.storage.unlock(ptr %program)
  %retried = load i1, ptr %retry.used, align 1
  br i1 %retried, label %failed, label %collect
collect:
  store i1 true, ptr %retry.used, align 1
  %collected = call {i1,i64} @ube.managed.collect(ptr %ctx, i64 0)
  br label %lock
unlock.failed:
  call void @ube.program.storage.unlock(ptr %program)
  br label %failed
failed:
  ret i1 false
}
define i1 @ube.text.create(ptr %ctx, i64 %bytes, i64 %scalars, ptr %output) {
entry:
  %negative = icmp slt i64 %bytes, 0
  %negative.scalars = icmp slt i64 %scalars, 0
  %excess.scalars = icmp ugt i64 %scalars, %bytes
  %zero.bytes = icmp eq i64 %bytes, 0
  %zero.scalars = icmp eq i64 %scalars, 0
  %one.zero = xor i1 %zero.bytes, %zero.scalars
  %a = or i1 %negative, %negative.scalars
  %b = or i1 %excess.scalars, %one.zero
  %invalid = or i1 %a, %b
  br i1 %invalid, label %bad, label %empty
empty:
  br i1 %zero.bytes, label %zero, label %owner
zero:
  store i64 0, ptr %output, align 8
  ret i1 true
owner:
  %created = call i1 @ube.managed.create(ptr %ctx, i64 %bytes, i64 %scalars, i64 1, ptr %output)
  ret i1 %created
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret i1 false
}
define internal i1 @ube.managed.create(ptr %ctx, i64 %bytes, i64 %scalars, i64 %kind, ptr %output) {
entry:
  %positive = icmp sgt i64 %bytes, 0
  %kind.valid = icmp sgt i64 %kind, 0
  %valid = and i1 %positive, %kind.valid
  br i1 %valid, label %owner, label %bad
owner:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %ready = icmp ne ptr %state, null
  %frame.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4
  %frame = load ptr, ptr %frame.ptr, align 8
  %framed = icmp ne ptr %frame, null
  %owned = and i1 %ready, %framed
  br i1 %owned, label %size, label %bad
size:
  %header.end = getelementptr %ube.managed.record, ptr null, i64 1
  %header.bytes = ptrtoint ptr %header.end to i64
  %maximum.total = sub i64 9223372036854775807, %header.bytes
  %maximum.bytes = sub i64 %maximum.total, 1023
  %too.large = icmp ugt i64 %bytes, %maximum.bytes
  br i1 %too.large, label %memory, label %allocate
allocate:
  %total = add i64 %bytes, %header.bytes
  %rounded = add i64 %total, 1023
  %chunks = lshr i64 %rounded, 10
  %block = call ptr @ube.memory.new(ptr %ctx, i64 %chunks, i64 128)
  %allocated = icmp ne ptr %block, null
  br i1 %allocated, label %issue, label %memory
issue:
  %identity = call i64 @ube.managed.issue()
  %issued = icmp ne i64 %identity, 0
  br i1 %issued, label %initialize, label %discard
discard:
  call void @ube.block.drop(ptr %ctx, ptr %block)
  br label %memory
initialize:
  %record = getelementptr %ube.block, ptr %block, i64 1
  %payload = getelementptr %ube.managed.record, ptr %record, i64 1
  %id.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 1
  %owner.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 3
  %candidate.next = getelementptr %ube.managed.record, ptr %record, i32 0, i32 4
  %bytes.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5
  %scalars.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 6
  %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %thread.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 10
  %kind.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 11
  store i64 %identity, ptr %id.ptr, align 8
  store ptr %frame, ptr %owner.ptr, align 8
  store i64 %bytes, ptr %bytes.ptr, align 8
  store i64 %scalars, ptr %scalars.ptr, align 8
  store ptr %payload, ptr %payload.ptr, align 8
  store ptr %ctx, ptr %thread.ptr, align 8
  store i64 %kind, ptr %kind.ptr, align 8
  %registered = call i1 @ube.managed.register(ptr %ctx, ptr %state, ptr %record)
  br i1 %registered, label %candidate, label %discard
candidate:
  %candidates = getelementptr %ube.thread, ptr %ctx, i32 0, i32 5
  %old.candidate = load ptr, ptr %candidates, align 8
  store ptr %old.candidate, ptr %candidate.next, align 8
  store ptr %record, ptr %candidates, align 8
  store i64 %identity, ptr %output, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret i1 false
memory:
  store atomic i64 7, ptr %ctx monotonic, align 8
  ret i1 false
}
define i1 @ube.text.write(ptr %ctx, i64 %identity, i64 %index, i64 %value) {
entry:
  %record = call ptr @ube.text.candidate(ptr %ctx, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %bounds, label %failed
bounds:
  %length.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5
  %length = load i64, ptr %length.ptr, align 8
  %valid = icmp ult i64 %index, %length
  br i1 %valid, label %byte, label %range
byte:
  %byte.valid = icmp ule i64 %value, 255
  br i1 %byte.valid, label %write, label %bad
write:
  %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %payload = load ptr, ptr %payload.ptr, align 8
  %address = getelementptr i8, ptr %payload, i64 %index
  %narrow = trunc i64 %value to i8
  store i8 %narrow, ptr %address, align 1
  ret i1 true
range:
  store atomic i64 9, ptr %ctx monotonic, align 8
  br label %failed
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
define i1 @ube.text.publish(ptr %ctx, ptr %destination, i64 %identity) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %zero, label %find
find:
  %record = call ptr @ube.text.candidate(ptr %ctx, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %commit, label %failed
commit:
  call void @ube.managed.store(ptr %ctx, ptr %destination, i64 %identity)
  call void @ube.managed.unlink(ptr %ctx, ptr %record)
  ret i1 true
zero:
  call void @ube.managed.store(ptr %ctx, ptr %destination, i64 0)
  ret i1 true
failed:
  ret i1 false
}
define i1 @ube.text.abandon(ptr %ctx, i64 %identity) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %done, label %find
find:
  %record = call ptr @ube.text.candidate(ptr %ctx, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %unlink, label %failed
unlink:
  call void @ube.managed.unlink(ptr %ctx, ptr %record)
  br label %done
done:
  ret i1 true
failed:
  ret i1 false
}
; Variant payload headers are immutable; exact layout metadata describes only data.
define internal ptr @ube.variant.find(ptr %ctx, i64 %identity) {
entry:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %kind, label %bad
kind:
  %kind.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 11
  %kind.value = load i64, ptr %kind.ptr, align 8
  %variant = icmp eq i64 %kind.value, 2
  br i1 %variant, label %done, label %bad
done:
  ret ptr %record
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret ptr null
}
define ptr @ube.variant.payload(ptr %ctx, i64 %identity) {
entry:
  %record = call ptr @ube.variant.find(ptr %ctx, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %read, label %failed
read:
  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %data = load ptr, ptr %data.ptr, align 8
  ret ptr %data
failed:
  ret ptr null
}
define i1 @ube.variant.create(ptr %ctx, i64 %tag, i64 %nominal, i64 %rank, i64 %cells, ptr %layout, ptr %cleanup, ptr %output) {
entry:
  %positive = icmp sgt i64 %tag, 0
  %tag.bounded = icmp ult i64 %tag, 16384
  %nominal.valid = icmp sge i64 %nominal, 0
  %rank.valid = icmp sge i64 %rank, 0
  %a = and i1 %positive, %tag.bounded
  %b = and i1 %nominal.valid, %rank.valid
  %valid = and i1 %a, %b
  br i1 %valid, label %extent, label %bad
extent:
  %fits = icmp ule i64 %cells, 1152921504606846971
  br i1 %fits, label %allocate, label %memory
allocate:
  %payload.bytes = mul i64 %cells, 8
  %bytes = add i64 %payload.bytes, 32
  %allocated = call i1 @ube.managed.create(ptr %ctx, i64 %bytes, i64 0, i64 2, ptr %output)
  br i1 %allocated, label %initialize, label %failed
initialize:
  %identity = load i64, ptr %output, align 8
  %record = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)
  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %header = load ptr, ptr %data.ptr, align 8
  %nominal.ptr = getelementptr i64, ptr %header, i64 1
  %rank.ptr = getelementptr i64, ptr %header, i64 2
  %cells.ptr = getelementptr i64, ptr %header, i64 3
  %data = getelementptr i64, ptr %header, i64 4
  store i64 %tag, ptr %header, align 8
  store i64 %nominal, ptr %nominal.ptr, align 8
  store i64 %rank, ptr %rank.ptr, align 8
  store i64 %cells, ptr %cells.ptr, align 8
  store ptr %data, ptr %data.ptr, align 8
  %layout.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 7
  %repeat.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 8
  %cleanup.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 12
  store ptr %layout, ptr %layout.ptr, align 8
  %has.layout = icmp ne ptr %layout, null
  %repeat = select i1 %has.layout, i64 1, i64 0
  store i64 %repeat, ptr %repeat.ptr, align 8
  store ptr %cleanup, ptr %cleanup.ptr, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret i1 false
memory:
  store atomic i64 7, ptr %ctx monotonic, align 8
  ret i1 false
failed:
  ret i1 false
}
define i1 @ube.variant.info(ptr %ctx, i64 %identity, ptr %tag.out, ptr %nominal.out, ptr %rank.out, ptr %cells.out) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %zero, label %read
read:
  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)
  %valid = icmp ne ptr %data, null
  br i1 %valid, label %header, label %failed
header:
  %tag.ptr = getelementptr i64, ptr %data, i64 -4
  %nominal.ptr = getelementptr i64, ptr %data, i64 -3
  %rank.ptr = getelementptr i64, ptr %data, i64 -2
  %cells.ptr = getelementptr i64, ptr %data, i64 -1
  %tag.value = load i64, ptr %tag.ptr, align 8
  %nominal.value = load i64, ptr %nominal.ptr, align 8
  %rank.value = load i64, ptr %rank.ptr, align 8
  %cells.value = load i64, ptr %cells.ptr, align 8
  br label %commit
zero:
  br label %commit
commit:
  %tag = phi i64 [0, %zero], [%tag.value, %header]
  %nominal = phi i64 [0, %zero], [%nominal.value, %header]
  %rank = phi i64 [0, %zero], [%rank.value, %header]
  %cells = phi i64 [0, %zero], [%cells.value, %header]
  store i64 %tag, ptr %tag.out, align 8
  store i64 %nominal, ptr %nominal.out, align 8
  store i64 %rank, ptr %rank.out, align 8
  store i64 %cells, ptr %cells.out, align 8
  ret i1 true
failed:
  ret i1 false
}
define {i1,i64} @ube.variant.tag(ptr %ctx, i64 %identity) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %zero, label %read
read:
  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)
  %valid = icmp ne ptr %data, null
  br i1 %valid, label %header, label %failed
header:
  %tag.ptr = getelementptr i64, ptr %data, i64 -4
  %tag = load i64, ptr %tag.ptr, align 8
  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %tag, 1
  ret {i1,i64} %result
zero:
  ret {i1,i64} {i1 true,i64 0}
failed:
  ret {i1,i64} {i1 false,i64 0}
}
define {i1,i64} @ube.variant.scalar(ptr %ctx, i64 %identity) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %zero, label %read
read:
  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)
  %valid = icmp ne ptr %data, null
  br i1 %valid, label %header, label %failed
header:
  %tag.ptr = getelementptr i64, ptr %data, i64 -4
  %rank.ptr = getelementptr i64, ptr %data, i64 -2
  %cells.ptr = getelementptr i64, ptr %data, i64 -1
  %tag = load i64, ptr %tag.ptr, align 8
  %rank = load i64, ptr %rank.ptr, align 8
  %cells = load i64, ptr %cells.ptr, align 8
  %one = icmp eq i64 %cells, 1
  %not.array = icmp eq i64 %rank, 0
  %simple = icmp ult i64 %tag, 36
  %not.null = icmp ne i64 %tag, 1
  %a = and i1 %one, %not.array
  %b = and i1 %simple, %not.null
  %scalar = and i1 %a, %b
  br i1 %scalar, label %payload, label %mismatch
payload:
  %value = load i64, ptr %data, align 8
  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %value, 1
  ret {i1,i64} %result
zero:
  ret {i1,i64} {i1 true,i64 0}
mismatch:
  store atomic i64 13, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret {i1,i64} {i1 false,i64 0}
}
define i1 @ube.variant.publish(ptr %ctx, ptr %destination, i64 %identity) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %zero, label %find
find:
  %record = call ptr @ube.variant.find(ptr %ctx, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %candidate, label %failed
candidate:
  %owned = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)
  %private = icmp ne ptr %owned, null
  br i1 %private, label %commit, label %failed
commit:
  call void @ube.managed.store(ptr %ctx, ptr %destination, i64 %identity)
  call void @ube.managed.unlink(ptr %ctx, ptr %record)
  ret i1 true
zero:
  call void @ube.managed.store(ptr %ctx, ptr %destination, i64 0)
  ret i1 true
failed:
  ret i1 false
}
define i1 @ube.variant.abandon(ptr %ctx, i64 %identity) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %done, label %find
find:
  %record = call ptr @ube.variant.find(ptr %ctx, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %candidate, label %failed
candidate:
  %owned = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)
  %private = icmp ne ptr %owned, null
  br i1 %private, label %unlink, label %failed
unlink:
  call void @ube.managed.unlink(ptr %ctx, ptr %record)
  br label %done
done:
  ret i1 true
failed:
  ret i1 false
}
; Checked nominal extraction never treats structurally equal payloads as the same type.
define i1 @ube.variant.match(ptr %ctx, i64 %identity, i64 %tag, i64 %nominal, i64 %rank, i64 %cells) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %mismatch, label %find
find:
  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)
  %valid = icmp ne ptr %data, null
  br i1 %valid, label %header, label %failed
header:
  %tag.ptr = getelementptr i64, ptr %data, i64 -4
  %nominal.ptr = getelementptr i64, ptr %data, i64 -3
  %rank.ptr = getelementptr i64, ptr %data, i64 -2
  %cells.ptr = getelementptr i64, ptr %data, i64 -1
  %actual.tag = load i64, ptr %tag.ptr, align 8
  %actual.nominal = load i64, ptr %nominal.ptr, align 8
  %actual.rank = load i64, ptr %rank.ptr, align 8
  %actual.cells = load i64, ptr %cells.ptr, align 8
  %tag.equal = icmp eq i64 %actual.tag, %tag
  %nominal.equal = icmp eq i64 %actual.nominal, %nominal
  %rank.equal = icmp eq i64 %actual.rank, %rank
  %cells.equal = icmp eq i64 %actual.cells, %cells
  %a = and i1 %tag.equal, %nominal.equal
  %b = and i1 %rank.equal, %cells.equal
  %equal = and i1 %a, %b
  br i1 %equal, label %done, label %mismatch
done:
  ret i1 true
mismatch:
  store atomic i64 13, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
; Reference extraction preserves object identity; Empty has the neutral reference.
define {i1,i64} @ube.variant.reference(ptr %ctx, i64 %identity, i64 %expected.nominal) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %zero, label %find
find:
  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)
  %valid = icmp ne ptr %data, null
  br i1 %valid, label %header, label %failed
header:
  %nominal.ptr = getelementptr i64, ptr %data, i64 -3
  %nominal = load i64, ptr %nominal.ptr, align 8
  %shape = call i1 @ube.variant.match(ptr %ctx, i64 %identity, i64 9, i64 %nominal, i64 0, i64 1)
  br i1 %shape, label %reference, label %failed
reference:
  %value = load i64, ptr %data, align 8
  %generic = icmp eq i64 %expected.nominal, 0
  %same = icmp eq i64 %expected.nominal, %nominal
  %nothing = icmp eq i64 %value, 0
  %compatible = or i1 %generic, %same
  %accepted = or i1 %compatible, %nothing
  br i1 %accepted, label %done, label %mismatch
done:
  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %value, 1
  ret {i1,i64} %result
zero:
  ret {i1,i64} {i1 true,i64 0}
mismatch:
  store atomic i64 13, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret {i1,i64} {i1 false,i64 0}
}
define i1 @ube.variant.box(ptr %ctx, i64 %tag, i64 %value, ptr %layout, ptr %output) {
entry:
  %candidate = alloca i64, align 8
  %empty = icmp eq i64 %tag, 0
  br i1 %empty, label %zero, label %create
zero:
  call void @ube.managed.store(ptr %ctx, ptr %output, i64 0)
  ret i1 true
create:
  %created = call i1 @ube.variant.create(ptr %ctx, i64 %tag, i64 0, i64 0, i64 1, ptr %layout, ptr null, ptr %candidate)
  br i1 %created, label %initialize, label %failed
initialize:
  %identity = load i64, ptr %candidate, align 8
  %data = call ptr @ube.variant.payload(ptr %ctx, i64 %identity)
  store i64 %value, ptr %data, align 8
  call void @ube.managed.publish.range(ptr %ctx, ptr %data, ptr %layout, i64 1)
  %published = call i1 @ube.variant.publish(ptr %ctx, ptr %output, i64 %identity)
  ret i1 %published
failed:
  ret i1 false
}
; Only fresh private owners receive their immutable precise layout.
define void @ube.managed.owner.layout(ptr %ctx, ptr %block, ptr %layout, i64 %count) {
entry:
  %present = icmp ne ptr %block, null
  br i1 %present, label %attach, label %done
attach:
  %layout.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 3
  %count.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 4
  %managed = icmp ne ptr %layout, null
  %repeat = select i1 %managed, i64 %count, i64 0
  store ptr %layout, ptr %layout.ptr, align 8
  store i64 %repeat, ptr %count.ptr, align 8
  br label %done
done:
  ret void
}
; Retention alone does not root a native block; active leases publish this frame.
define void @ube.managed.owner.root(ptr %ctx, ptr %frame, ptr %block) {
entry:
  %present = icmp ne ptr %block, null
  br i1 %present, label %read, label %empty
read:
  %layout.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 3
  %count.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 4
  %layout = load ptr, ptr %layout.ptr, align 8
  %count = load i64, ptr %count.ptr, align 8
  %base = getelementptr %ube.block, ptr %block, i64 1
  call void @ube.managed.root.push(ptr %ctx, ptr %frame, ptr %base, ptr %layout, i64 %count)
  ret void
empty:
  call void @ube.managed.root.push(ptr %ctx, ptr %frame, ptr null, ptr null, i64 0)
  ret void
}
; Native-owner pointers are accepted only when present in this program's block registry.
define internal i1 @ube.managed.block.valid(ptr %ctx, ptr %wanted) {
entry:
  %head = call ptr @ube.memory.head(ptr %ctx)
  %first = load ptr, ptr %head, align 8
  br label %scan
scan:
  %block = phi ptr [ %first, %entry ], [ %next, %advance ]
  %exists = icmp ne ptr %block, null
  br i1 %exists, label %inspect, label %absent
inspect:
  %same = icmp eq ptr %block, %wanted
  br i1 %same, label %found, label %advance
advance:
  %next = load ptr, ptr %block, align 8
  br label %scan
found:
  ret i1 true
absent:
  ret i1 false
}
; This bounded recursion decodes finite metadata, never follows managed identities.
; Found=True returns one exact identity. Found=False returns the slot count, or -1 on error.
define internal {i1,i64} @ube.managed.layout.visit(ptr %ctx, ptr %base, ptr %layout, i64 %repeat, i64 %index, i64 %depth) {
entry:
  %empty = icmp eq i64 %repeat, 0
  br i1 %empty, label %zero, label %validate
validate:
  %base.present = icmp ne ptr %base, null
  %layout.present = icmp ne ptr %layout, null
  %repeat.valid = icmp ule i64 %repeat, 2147483647
  %depth.valid = icmp ult i64 %depth, 66
  %pointers = and i1 %base.present, %layout.present
  %bounds = and i1 %repeat.valid, %depth.valid
  %valid = and i1 %pointers, %bounds
  br i1 %valid, label %metadata, label %bad
metadata:
  %stride.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 0
  %refs.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 1
  %offsets.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 2
  %arrays.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 3
  %entries.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 4
  %owners.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 5
  %owner.offsets.ptr = getelementptr %ube.managed.layout, ptr %layout, i32 0, i32 6
  %stride = load i64, ptr %stride.ptr, align 8
  %refs = load i64, ptr %refs.ptr, align 8
  %offsets = load ptr, ptr %offsets.ptr, align 8
  %arrays = load i64, ptr %arrays.ptr, align 8
  %entries = load ptr, ptr %entries.ptr, align 8
  %owners = load i64, ptr %owners.ptr, align 8
  %owner.offsets = load ptr, ptr %owner.offsets.ptr, align 8
  %stride.low = icmp sgt i64 %stride, 0
  %stride.high = icmp ule i64 %stride, 2147483647
  %refs.valid = icmp ule i64 %refs, 2147483647
  %arrays.valid = icmp ule i64 %arrays, 2147483647
  %owners.valid = icmp ule i64 %owners, 2147483647
  %s = and i1 %stride.low, %stride.high
  %a = and i1 %refs.valid, %arrays.valid
  %b = and i1 %a, %owners.valid
  %counts.valid = and i1 %s, %b
  %refs.empty = icmp eq i64 %refs, 0
  %refs.present = icmp ne ptr %offsets, null
  %refs.storage = or i1 %refs.empty, %refs.present
  %arrays.empty = icmp eq i64 %arrays, 0
  %arrays.present = icmp ne ptr %entries, null
  %arrays.storage = or i1 %arrays.empty, %arrays.present
  %owners.empty = icmp eq i64 %owners, 0
  %owners.present = icmp ne ptr %owner.offsets, null
  %owners.storage = or i1 %owners.empty, %owners.present
  %lists.first = and i1 %refs.storage, %arrays.storage
  %lists.valid = and i1 %lists.first, %owners.storage
  %shape = and i1 %counts.valid, %lists.valid
  br i1 %shape, label %offset.check, label %bad
offset.check:
  %direct = mul i64 %refs, %repeat
  %direct.valid = icmp ule i64 %direct, 2147483647
  br i1 %direct.valid, label %offset.loop, label %large
offset.loop:
  %offset.index = phi i64 [ 0, %offset.check ], [ %offset.next, %offset.read ]
  %has.offset = icmp ult i64 %offset.index, %refs
  br i1 %has.offset, label %offset.read, label %direct.check
offset.read:
  %offset.ptr = getelementptr i64, ptr %offsets, i64 %offset.index
  %offset = load i64, ptr %offset.ptr, align 8
  %offset.valid = icmp ult i64 %offset, %stride
  %offset.next = add i64 %offset.index, 1
  br i1 %offset.valid, label %offset.loop, label %bad
direct.check:
  %in.direct = icmp ult i64 %index, %direct
  br i1 %in.direct, label %direct.read, label %children
direct.read:
  %element = udiv i64 %index, %refs
  %reference = urem i64 %index, %refs
  %reference.ptr = getelementptr i64, ptr %offsets, i64 %reference
  %reference.offset = load i64, ptr %reference.ptr, align 8
  %element.offset = mul i64 %element, %stride
  %cell.offset = add i64 %element.offset, %reference.offset
  %cell = getelementptr i64, ptr %base, i64 %cell.offset
  %identity = load atomic i64, ptr %cell acquire, align 8
  %direct.result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %identity, 1
  ret {i1,i64} %direct.result
children:
  %child.count = add i64 %arrays, %owners
  %has.children = icmp ne i64 %child.count, 0
  %counting = icmp slt i64 %index, 0
  %remaining.direct = sub i64 %index, %direct
  %initial.index = select i1 %counting, i64 -1, i64 %remaining.direct
  br i1 %has.children, label %child.loop, label %direct.count
child.loop:
  %row = phi i64 [ 0, %children ], [ %next.row, %advance ]
  %child.index = phi i64 [ 0, %children ], [ %next.child, %advance ]
  %remaining = phi i64 [ %initial.index, %children ], [ %next.remaining, %advance ]
  %total = phi i64 [ %direct, %children ], [ %new.total, %advance ]
  %row.offset = mul i64 %row, %stride
  %row.base = getelementptr i64, ptr %base, i64 %row.offset
  %is.array = icmp ult i64 %child.index, %arrays
  br i1 %is.array, label %array, label %owner
array:
  %entry.ptr = getelementptr %ube.managed.array, ptr %entries, i64 %child.index
  %descriptor.offset = load i64, ptr %entry.ptr, align 8
  %array.layout.ptr = getelementptr %ube.managed.array, ptr %entry.ptr, i32 0, i32 1
  %array.layout = load ptr, ptr %array.layout.ptr, align 8
  %descriptor.end = add i64 %descriptor.offset, 4
  %descriptor.in = icmp ule i64 %descriptor.end, %stride
  %descriptor.nonnegative = icmp sge i64 %descriptor.offset, 0
  %descriptor.valid = and i1 %descriptor.in, %descriptor.nonnegative
  br i1 %descriptor.valid, label %array.read, label %bad
array.read:
  %descriptor = getelementptr i64, ptr %row.base, i64 %descriptor.offset
  %upper.ptr = getelementptr i64, ptr %descriptor, i64 1
  %data.ptr = getelementptr i64, ptr %descriptor, i64 2
  %lower = load i64, ptr %descriptor, align 8
  %upper = load i64, ptr %upper.ptr, align 8
  %data = load ptr, ptr %data.ptr, align 8
  %nonempty = icmp sge i64 %upper, %lower
  %difference = sub i64 %upper, %lower
  %length = add i64 %difference, 1
  %array.count = select i1 %nonempty, i64 %length, i64 0
  %array.extent = icmp ule i64 %array.count, 2147483647
  %lower.valid = icmp sge i64 %lower, -2147483648
  %upper.valid = icmp sle i64 %upper, 2147483647
  %bounds.valid = and i1 %lower.valid, %upper.valid
  %array.valid = and i1 %array.extent, %bounds.valid
  br i1 %array.valid, label %visit.array, label %bad
visit.array:
  br label %visit
owner:
  %owner.index = sub i64 %child.index, %arrays
  %owner.offset.ptr = getelementptr i64, ptr %owner.offsets, i64 %owner.index
  %owner.offset = load i64, ptr %owner.offset.ptr, align 8
  %owner.in = icmp ult i64 %owner.offset, %stride
  br i1 %owner.in, label %owner.read, label %bad
owner.read:
  %owner.slot = getelementptr i64, ptr %row.base, i64 %owner.offset
  %block = load ptr, ptr %owner.slot, align 8
  %owner.present = icmp ne ptr %block, null
  br i1 %owner.present, label %owner.validate, label %empty.owner
owner.validate:
  %registered = call i1 @ube.managed.block.valid(ptr %ctx, ptr %block)
  br i1 %registered, label %owner.layout, label %bad
owner.layout:
  %block.layout.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 3
  %block.count.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 4
  %block.layout = load ptr, ptr %block.layout.ptr, align 8
  %block.count = load i64, ptr %block.count.ptr, align 8
  %block.data = getelementptr %ube.block, ptr %block, i64 1
  br label %visit
empty.owner:
  br label %visit
visit:
  %child.base = phi ptr [ %data, %visit.array ], [ %block.data, %owner.layout ], [ null, %empty.owner ]
  %child.layout = phi ptr [ %array.layout, %visit.array ], [ %block.layout, %owner.layout ], [ null, %empty.owner ]
  %child.repeat = phi i64 [ %array.count, %visit.array ], [ %block.count, %owner.layout ], [ 0, %empty.owner ]
  %next.depth = add i64 %depth, 1
  %result = call {i1,i64} @ube.managed.layout.visit(ptr %ctx, ptr %child.base, ptr %child.layout, i64 %child.repeat, i64 %remaining, i64 %next.depth)
  %found = extractvalue {i1,i64} %result, 0
  %value = extractvalue {i1,i64} %result, 1
  br i1 %found, label %return.found, label %count.child
return.found:
  ret {i1,i64} %result
count.child:
  %child.ok = icmp sge i64 %value, 0
  br i1 %child.ok, label %sum, label %error
sum:
  %new.total = add i64 %total, %value
  %total.valid = icmp ule i64 %new.total, 2147483647
  br i1 %total.valid, label %advance, label %large
advance:
  %remaining.child = sub i64 %remaining, %value
  %next.remaining = select i1 %counting, i64 -1, i64 %remaining.child
  %increment.child = add i64 %child.index, 1
  %last.child = icmp eq i64 %increment.child, %child.count
  %next.child = select i1 %last.child, i64 0, i64 %increment.child
  %increment.row = add i64 %row, 1
  %next.row = select i1 %last.child, i64 %increment.row, i64 %row
  %more.rows = icmp ult i64 %next.row, %repeat
  br i1 %more.rows, label %child.loop, label %children.count
children.count:
  %child.result = insertvalue {i1,i64} zeroinitializer, i64 %new.total, 1
  ret {i1,i64} %child.result
direct.count:
  %count.result = insertvalue {i1,i64} zeroinitializer, i64 %direct, 1
  ret {i1,i64} %count.result
zero:
  ret {i1,i64} zeroinitializer
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %error
large:
  store atomic i64 7, ptr %ctx monotonic, align 8
  br label %error
error:
  ret {i1,i64} {i1 false,i64 -1}
}
; Enumerates published typed roots only; integers and native handles are excluded.
define internal {i1,i64} @ube.managed.roots.visit(ptr %ctx, i64 %index) {
entry:
  %remaining.ptr = alloca i64, align 8
  %total.ptr = alloca i64, align 8
  store i64 %index, ptr %remaining.ptr, align 8
  store i64 0, ptr %total.ptr, align 8
  %counting = icmp slt i64 %index, 0
  %program = call ptr @ube.thread.program(ptr %ctx)
  %head = getelementptr %ube.program, ptr %program, i32 0, i32 15
  %first = load ptr, ptr %head, align 8
  br label %threads
threads:
  %thread = phi ptr [ %first, %entry ], [ %next.thread, %advance.thread ]
  %exists = icmp ne ptr %thread, null
  br i1 %exists, label %handoff, label %done
handoff:
  %handoff.slot = getelementptr %ube.thread, ptr %thread, i32 0, i32 8
  %handoff.index = load i64, ptr %remaining.ptr, align 8
  %at.handoff = icmp eq i64 %handoff.index, 0
  br i1 %at.handoff, label %return.handoff, label %count.handoff
return.handoff:
  %handoff.value = load atomic i64, ptr %handoff.slot acquire, align 8
  %handoff.result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %handoff.value, 1
  ret {i1,i64} %handoff.result
count.handoff:
  %handoff.total = load i64, ptr %total.ptr, align 8
  %with.handoff = add i64 %handoff.total, 1
  store i64 %with.handoff, ptr %total.ptr, align 8
  %less.handoff = sub i64 %handoff.index, 1
  %after.handoff = select i1 %counting, i64 -1, i64 %less.handoff
  store i64 %after.handoff, ptr %remaining.ptr, align 8
  %candidates = getelementptr %ube.thread, ptr %thread, i32 0, i32 5
  %first.candidate = load ptr, ptr %candidates, align 8
  br label %candidate.loop
candidate.loop:
  %candidate = phi ptr [ %first.candidate, %count.handoff ], [ %next.candidate, %count.candidate ]
  %candidate.exists = icmp ne ptr %candidate, null
  br i1 %candidate.exists, label %candidate.read, label %frame.start
candidate.read:
  %candidate.index = load i64, ptr %remaining.ptr, align 8
  %at.candidate = icmp eq i64 %candidate.index, 0
  br i1 %at.candidate, label %return.candidate, label %count.candidate
return.candidate:
  %candidate.id.ptr = getelementptr %ube.managed.record, ptr %candidate, i32 0, i32 1
  %candidate.id = load i64, ptr %candidate.id.ptr, align 8
  %candidate.result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %candidate.id, 1
  ret {i1,i64} %candidate.result
count.candidate:
  %candidate.total = load i64, ptr %total.ptr, align 8
  %with.candidate = add i64 %candidate.total, 1
  store i64 %with.candidate, ptr %total.ptr, align 8
  %less.candidate = sub i64 %candidate.index, 1
  %after.candidate = select i1 %counting, i64 -1, i64 %less.candidate
  store i64 %after.candidate, ptr %remaining.ptr, align 8
  %candidate.next.ptr = getelementptr %ube.managed.record, ptr %candidate, i32 0, i32 4
  %next.candidate = load ptr, ptr %candidate.next.ptr, align 8
  br label %candidate.loop
frame.start:
  %frame.head = getelementptr %ube.thread, ptr %thread, i32 0, i32 4
  %first.frame = load atomic ptr, ptr %frame.head acquire, align 8
  br label %frames
frames:
  %frame = phi ptr [ %first.frame, %frame.start ], [ %next.frame, %advance.frame ]
  %frame.exists = icmp ne ptr %frame, null
  br i1 %frame.exists, label %frame.read, label %advance.thread
frame.read:
  %base.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 1
  %layout.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 2
  %repeat.ptr = getelementptr %ube.rootframe, ptr %frame, i32 0, i32 3
  %base = load ptr, ptr %base.ptr, align 8
  %layout = load ptr, ptr %layout.ptr, align 8
  %repeat = load i64, ptr %repeat.ptr, align 8
  %frame.index = load i64, ptr %remaining.ptr, align 8
  %result = call {i1,i64} @ube.managed.layout.visit(ptr %ctx, ptr %base, ptr %layout, i64 %repeat, i64 %frame.index, i64 0)
  %found = extractvalue {i1,i64} %result, 0
  %value = extractvalue {i1,i64} %result, 1
  br i1 %found, label %return.frame, label %count.frame
return.frame:
  ret {i1,i64} %result
count.frame:
  %frame.ok = icmp sge i64 %value, 0
  br i1 %frame.ok, label %sum.frame, label %error
sum.frame:
  %frame.total = load i64, ptr %total.ptr, align 8
  %with.frame = add i64 %frame.total, %value
  %total.valid = icmp ule i64 %with.frame, 2147483647
  br i1 %total.valid, label %advance.frame, label %large
advance.frame:
  store i64 %with.frame, ptr %total.ptr, align 8
  %less.frame = sub i64 %frame.index, %value
  %after.frame = select i1 %counting, i64 -1, i64 %less.frame
  store i64 %after.frame, ptr %remaining.ptr, align 8
  %next.frame = load ptr, ptr %frame, align 8
  br label %frames
advance.thread:
  %next.thread.ptr = getelementptr %ube.thread, ptr %thread, i32 0, i32 6
  %next.thread = load ptr, ptr %next.thread.ptr, align 8
  br label %threads
done:
  %total = load i64, ptr %total.ptr, align 8
  %answer = insertvalue {i1,i64} zeroinitializer, i64 %total, 1
  ret {i1,i64} %answer
large:
  store atomic i64 7, ptr %ctx monotonic, align 8
  br label %error
error:
  ret {i1,i64} {i1 false,i64 -1}
}
define i1 @ube.managed.root.at(ptr %ctx, i64 %index, ptr %output) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ready = icmp ne ptr %state, null
  br i1 %ready, label %bounds, label %failed
bounds:
  %count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 9
  %count = load i64, ptr %count.ptr, align 8
  %valid = icmp ult i64 %index, %count
  br i1 %valid, label %read, label %bad
read:
  %result = call {i1,i64} @ube.managed.roots.visit(ptr %ctx, i64 %index)
  %found = extractvalue {i1,i64} %result, 0
  %value = extractvalue {i1,i64} %result, 1
  br i1 %found, label %publish, label %failed
publish:
  store i64 %value, ptr %output, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
define internal {i1,i64} @ube.managed.edges.visit(ptr %ctx, i64 %identity, i64 %index) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ready = icmp ne ptr %state, null
  br i1 %ready, label %empty, label %failed
empty:
  %zero = icmp eq i64 %identity, 0
  br i1 %zero, label %none, label %find
find:
  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %read, label %bad
read:
  %layout.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 7
  %repeat.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 8
  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %layout = load ptr, ptr %layout.ptr, align 8
  %repeat = load i64, ptr %repeat.ptr, align 8
  %data = load ptr, ptr %data.ptr, align 8
  %result = call {i1,i64} @ube.managed.layout.visit(ptr %ctx, ptr %data, ptr %layout, i64 %repeat, i64 %index, i64 0)
  ret {i1,i64} %result
none:
  ret {i1,i64} zeroinitializer
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret {i1,i64} {i1 false,i64 -1}
}
define i1 @ube.managed.edge.count(ptr %ctx, i64 %identity, ptr %output) {
entry:
  %result = call {i1,i64} @ube.managed.edges.visit(ptr %ctx, i64 %identity, i64 -1)
  %count = extractvalue {i1,i64} %result, 1
  %valid = icmp sge i64 %count, 0
  br i1 %valid, label %publish, label %failed
publish:
  store i64 %count, ptr %output, align 8
  ret i1 true
failed:
  ret i1 false
}
define i1 @ube.managed.edge.at(ptr %ctx, i64 %identity, i64 %index, ptr %output) {
entry:
  %valid = icmp sge i64 %index, 0
  br i1 %valid, label %read, label %bad
read:
  %result = call {i1,i64} @ube.managed.edges.visit(ptr %ctx, i64 %identity, i64 %index)
  %found = extractvalue {i1,i64} %result, 0
  %value = extractvalue {i1,i64} %result, 1
  br i1 %found, label %publish, label %not.found
not.found:
  %error = icmp slt i64 %value, 0
  br i1 %error, label %failed, label %bad
publish:
  store i64 %value, ptr %output, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
; Begin owns or joins one synchronous round; completed results remain until joiners consume them.
define i1 @ube.managed.begin(ptr %ctx, ptr %prior.work, ptr %prior.error) {
entry:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %exists = icmp ne ptr %state, null
  br i1 %exists, label %setup, label %invalid
setup:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2
  %request.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3
  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4
  %work.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 5
  %error.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 6
  %allocation.count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 8
  %root.count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 9
  %joiners.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 12
  %status.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 7
  br label %elect
elect:
  call void @ube.thread.registry.lock(ptr %program)
  %request = load atomic i64, ptr %request.ptr seq_cst, align 8
  %active = icmp ne i64 %request, 0
  br i1 %active, label %join.check, label %admit
join.check:
  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8
  %recursive = icmp eq ptr %owner, %ctx
  br i1 %recursive, label %recursive.error, label %join
recursive.error:
  call void @ube.thread.registry.unlock(ptr %program)
  br label %invalid
join:
  %joiners = load i64, ptr %joiners.ptr, align 8
  %more.joiners = add i64 %joiners, 1
  store i64 %more.joiners, ptr %joiners.ptr, align 8
  store atomic i64 1, ptr %status.ptr seq_cst, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  br label %join.wait
join.wait:
  %joining = load atomic i64, ptr %request.ptr seq_cst, align 8
  %joined = icmp eq i64 %joining, 0
  br i1 %joined, label %join.result, label %join.yield
join.yield:
  call void @Sleep(i32 0)
  br label %join.wait
join.result:
  call void @ube.thread.registry.lock(ptr %program)
  %joined.work = load i64, ptr %work.ptr, align 8
  %joined.error = load i64, ptr %error.ptr, align 8
  store i64 %joined.work, ptr %prior.work, align 8
  store i64 %joined.error, ptr %prior.error, align 8
  %remaining.joiners = load i64, ptr %joiners.ptr, align 8
  %less.joiners = sub i64 %remaining.joiners, 1
  store i64 %less.joiners, ptr %joiners.ptr, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  call void @ube.managed.enter(ptr %ctx)
  ret i1 false
admit:
  %waiting.joiners = load i64, ptr %joiners.ptr, align 8
  %readers.done = icmp eq i64 %waiting.joiners, 0
  br i1 %readers.done, label %own, label %admit.wait
admit.wait:
  store atomic i64 2, ptr %status.ptr seq_cst, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  call void @Sleep(i32 0)
  br label %elect
own:
  store atomic i64 0, ptr %status.ptr seq_cst, align 8
  store atomic ptr %ctx, ptr %owner.ptr release, align 8
  store i64 0, ptr %phase.ptr, align 8
  store i64 0, ptr %work.ptr, align 8
  store i64 0, ptr %error.ptr, align 8
  store atomic i64 1, ptr %request.ptr seq_cst, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  br label %rendezvous
rendezvous:
  call void @ube.thread.registry.lock(ptr %program)
  %thread.head = getelementptr %ube.program, ptr %program, i32 0, i32 15
  %first.thread = load ptr, ptr %thread.head, align 8
  br label %threads
threads:
  %thread = phi ptr [ %first.thread, %rendezvous ], [ %next.thread, %advance ]
  %thread.exists = icmp ne ptr %thread, null
  br i1 %thread.exists, label %inspect, label %stopped
inspect:
  %mine = icmp eq ptr %thread, %ctx
  br i1 %mine, label %advance, label %inspect.status
inspect.status:
  %thread.status.ptr = getelementptr %ube.thread, ptr %thread, i32 0, i32 7
  %thread.status = load atomic i64, ptr %thread.status.ptr seq_cst, align 8
  %running = icmp eq i64 %thread.status, 0
  br i1 %running, label %wait, label %advance
advance:
  %next.ptr = getelementptr %ube.thread, ptr %thread, i32 0, i32 6
  %next.thread = load ptr, ptr %next.ptr, align 8
  br label %threads
wait:
  call void @ube.thread.registry.unlock(ptr %program)
  call void @Sleep(i32 0)
  br label %rendezvous
stopped:
  call void @ube.thread.registry.unlock(ptr %program)
  call void @ube.program.storage.lock(ptr %program)
  %retired = call i1 @ube.memory.collect.locked(ptr %ctx)
  call void @ube.program.storage.unlock(ptr %program)
  store i64 0, ptr %prior.work, align 8
  store i64 0, ptr %prior.error, align 8
  %first.record = load atomic ptr, ptr %state acquire, align 8
  br label %snapshot
snapshot:
  %record = phi ptr [ %first.record, %stopped ], [ %next.record, %record.read ]
  %allocation.count = phi i64 [ 0, %stopped ], [ %next.count, %record.read ]
  %record.exists = icmp ne ptr %record, null
  br i1 %record.exists, label %capacity, label %roots
capacity:
  %capacity.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 16
  %capacity.value = load i64, ptr %capacity.ptr, align 8
  %room = icmp ult i64 %allocation.count, %capacity.value
  br i1 %room, label %record.read, label %metadata.error
record.read:
  %identity.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 1
  %identity = load i64, ptr %identity.ptr, align 8
  %snapshot.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 10
  %snapshot.data = load ptr, ptr %snapshot.ptr, align 8
  %slot = getelementptr i64, ptr %snapshot.data, i64 %allocation.count
  store i64 %identity, ptr %slot, align 8
  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2
  store i64 0, ptr %mark.ptr, align 8
  %next.record = load ptr, ptr %record, align 8
  %next.count = add i64 %allocation.count, 1
  br label %snapshot
roots:
  %live.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 17
  %live = load i64, ptr %live.ptr, align 8
  %consistent = icmp eq i64 %allocation.count, %live
  br i1 %consistent, label %counts, label %metadata.error
counts:
  store i64 %allocation.count, ptr %allocation.count.ptr, align 8
  %root.result = call {i1,i64} @ube.managed.roots.visit(ptr %ctx, i64 -1)
  %root.count = extractvalue {i1,i64} %root.result, 1
  %roots.valid = icmp sge i64 %root.count, 0
  br i1 %roots.valid, label %ready, label %root.error
ready:
  store i64 %root.count, ptr %root.count.ptr, align 8
  store i64 1, ptr %phase.ptr, align 8
  ret i1 true
metadata.error:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %root.error
root.error:
  %failure = load atomic i64, ptr %ctx monotonic, align 8
  store i64 %failure, ptr %prior.error, align 8
  store i64 %failure, ptr %error.ptr, align 8
  store i64 -1, ptr %root.count.ptr, align 8
  ret i1 true
invalid:
  store i64 0, ptr %prior.work, align 8
  store i64 5, ptr %prior.error, align 8
  ret i1 false
}
define i1 @ube.managed.end(ptr %ctx, i64 %work, i64 %error) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ready = icmp ne ptr %state, null
  br i1 %ready, label %start, label %failed
start:
  %first = load atomic ptr, ptr %state acquire, align 8
  br label %scan
scan:
  %record = phi ptr [ %first, %start ], [ %next, %clear ]
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %clear, label %publish
clear:
  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2
  store i64 0, ptr %mark.ptr, align 8
  %next = load ptr, ptr %record, align 8
  br label %scan
publish:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.thread.registry.lock(ptr %program)
  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2
  %request.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 3
  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4
  %work.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 5
  %error.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 6
  %epoch.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 7
  %epoch = load i64, ptr %epoch.ptr, align 8
  %next.epoch = add i64 %epoch, 1
  store i64 %next.epoch, ptr %epoch.ptr, align 8
  store i64 %work, ptr %work.ptr, align 8
  store i64 %error, ptr %error.ptr, align 8
  store i64 0, ptr %phase.ptr, align 8
  store atomic ptr null, ptr %owner.ptr release, align 8
  %lease.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 14
  store ptr null, ptr %lease.ptr, align 8
  store atomic i64 0, ptr %request.ptr seq_cst, align 8
  call void @ube.thread.registry.unlock(ptr %program)
  ret i1 true
failed:
  ret i1 false
}
; The ordinary UBE collector has already selected this unmarked identity after sealing.
define i1 @ube.managed.reclaim(ptr %ctx, i64 %identity) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ready = icmp ne ptr %state, null
  br i1 %ready, label %phase, label %failed
phase:
  %phase.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 4
  %phase.value = load i64, ptr %phase.ptr, align 8
  %sealed = icmp eq i64 %phase.value, 2
  br i1 %sealed, label %find, label %bad
find:
  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %inspect, label %bad
inspect:
  %mark.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 2
  %owner.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 3
  %mark = load i64, ptr %mark.ptr, align 8
  %owner = load ptr, ptr %owner.ptr, align 8
  %unmarked = icmp eq i64 %mark, 0
  %published = icmp eq ptr %owner, null
  %eligible = and i1 %unmarked, %published
  br i1 %eligible, label %cleanup, label %bad
cleanup:
  %cleanup.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 12
  %cleanup.function = load ptr, ptr %cleanup.ptr, align 8
  %has.cleanup = icmp ne ptr %cleanup.function, null
  br i1 %has.cleanup, label %retire.payload, label %lock
retire.payload:
; Retire native owners once, before taking storage locks; failed OS release may retry.
  %payload.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %payload = load ptr, ptr %payload.ptr, align 8
  call void %cleanup.function(ptr %ctx, ptr %payload)
  store ptr null, ptr %cleanup.ptr, align 8
  br label %lock
lock:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.program.storage.lock(ptr %program)
  %block = getelementptr %ube.block, ptr %record, i64 -1
  %native.head = call ptr @ube.memory.head(ptr %ctx)
  br label %native.scan
native.scan:
  %native.link = phi ptr [ %native.head, %lock ], [ %native.item, %native.advance ]
  %native.item = load ptr, ptr %native.link, align 8
  %native.exists = icmp ne ptr %native.item, null
  br i1 %native.exists, label %native.inspect, label %locked.bad
native.inspect:
  %native.same = icmp eq ptr %native.item, %block
  br i1 %native.same, label %managed.start, label %native.advance
native.advance:
  br label %native.scan
managed.start:
  br label %managed.scan
managed.scan:
  %managed.link = phi ptr [ %state, %managed.start ], [ %managed.item, %managed.advance ]
  %managed.item = load ptr, ptr %managed.link, align 8
  %managed.exists = icmp ne ptr %managed.item, null
  br i1 %managed.exists, label %managed.inspect, label %locked.bad
managed.inspect:
  %managed.same = icmp eq ptr %managed.item, %record
  br i1 %managed.same, label %release, label %managed.advance
managed.advance:
  br label %managed.scan
release:
  %next.native = load ptr, ptr %block, align 8
  %next.managed = load ptr, ptr %record, align 8
  %charge.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 2
  %charge = load atomic i64, ptr %charge.ptr monotonic, align 8
  %released = call i1 @ube.target.release(ptr %block)
  br i1 %released, label %unlink, label %retained
unlink:
  store ptr %next.native, ptr %native.link, align 8
  store atomic ptr %next.managed, ptr %managed.link release, align 8
  %live.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 17
  %live = load i64, ptr %live.ptr, align 8
  %less.live = sub i64 %live, 1
  store i64 %less.live, ptr %live.ptr, align 8
  %bytes.ptr = call ptr @ube.memory.bytes(ptr %ctx)
  %blocks.ptr = call ptr @ube.memory.count(ptr %ctx)
  %bytes = load atomic i64, ptr %bytes.ptr monotonic, align 8
  %blocks = load atomic i64, ptr %blocks.ptr monotonic, align 8
  %less.bytes = sub i64 %bytes, %charge
  %less.blocks = sub i64 %blocks, 1
  store atomic i64 %less.bytes, ptr %bytes.ptr monotonic, align 8
  store atomic i64 %less.blocks, ptr %blocks.ptr monotonic, align 8
  call void @ube.program.storage.unlock(ptr %program)
  %count.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 8
  %count = load i64, ptr %count.ptr, align 8
  br label %snapshot
snapshot:
  %index = phi i64 [ 0, %unlink ], [ %next.index, %slot ]
  %more = icmp ult i64 %index, %count
  br i1 %more, label %slot, label %done
slot:
  %snapshot.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 10
  %snapshot.data = load ptr, ptr %snapshot.ptr, align 8
  %slot.ptr = getelementptr i64, ptr %snapshot.data, i64 %index
  %slot.value = load i64, ptr %slot.ptr, align 8
  %same = icmp eq i64 %slot.value, %identity
  %new.value = select i1 %same, i64 0, i64 %slot.value
  store i64 %new.value, ptr %slot.ptr, align 8
  %next.index = add i64 %index, 1
  br label %snapshot
retained:
  call void @ube.program.storage.unlock(ptr %program)
  store atomic i64 57, ptr %ctx monotonic, align 8
  br label %failed
locked.bad:
  call void @ube.program.storage.unlock(ptr %program)
  br label %bad
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
done:
  ret i1 true
failed:
  ret i1 false
}
; The linked UBE callback runs with independent bounded support call depth.
define {i1,i64} @ube.managed.collect(ptr %ctx, i64 %report) {
entry:
  %incoming.error = load atomic i64, ptr %ctx monotonic, align 8
  %depth.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 1
  %incoming.depth = load atomic i64, ptr %depth.ptr monotonic, align 8
  %state = call ptr @ube.managed.state(ptr %ctx)
  %present = icmp ne ptr %state, null
  br i1 %present, label %owner, label %native
native:
  %program = call ptr @ube.thread.program(ptr %ctx)
  call void @ube.program.storage.lock(ptr %program)
  %retired = call i1 @ube.memory.collect.locked(ptr %ctx)
  call void @ube.program.storage.unlock(ptr %program)
  ret {i1,i64} {i1 true,i64 0}
owner:
  %owner.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 2
  %coordinator = load atomic ptr, ptr %owner.ptr acquire, align 8
  %recursive = icmp eq ptr %coordinator, %ctx
  br i1 %recursive, label %suppressed, label %callback
callback:
  %callback.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 1
  %procedure = load ptr, ptr %callback.ptr, align 8
  store atomic i64 0, ptr %depth.ptr monotonic, align 8
  %result = call {i1,i64} %procedure(ptr %ctx, i64 %report)
  %success = extractvalue {i1,i64} %result, 0
  %still.owner = load atomic ptr, ptr %owner.ptr acquire, align 8
  %unfinished = icmp eq ptr %still.owner, %ctx
  br i1 %unfinished, label %abort, label %restore
abort:
  %failure = load atomic i64, ptr %ctx monotonic, align 8
  %finished = call i1 @ube.managed.end(ptr %ctx, i64 0, i64 %failure)
  br label %restore
restore:
  store atomic i64 %incoming.depth, ptr %depth.ptr monotonic, align 8
  %reporting = icmp ne i64 %report, 0
  br i1 %reporting, label %done, label %preserve
preserve:
  store atomic i64 %incoming.error, ptr %ctx monotonic, align 8
  br label %done
done:
  ret {i1,i64} %result
suppressed:
  ret {i1,i64} {i1 true,i64 0}
}
; The bounded heap's numeric traversal queue is reserved within the same program quota.
define i1 @ube.managed.workspace(ptr %ctx, ptr %array, i64 %count, i64 %preserve) {
entry:
  %state = call ptr @ube.managed.owned(ptr %ctx)
  %ready = icmp ne ptr %state, null
  br i1 %ready, label %validate, label %failed
validate:
  %not.preserve = icmp eq i64 %preserve, 0
  %nonnegative = icmp sge i64 %count, 0
  %arguments = and i1 %not.preserve, %nonnegative
  br i1 %arguments, label %capacity, label %bad
capacity:
  %capacity.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 16
  %capacity.value = load i64, ptr %capacity.ptr, align 8
  %fits = icmp ule i64 %count, %capacity.value
  br i1 %fits, label %descriptor, label %memory
descriptor:
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %block.ptr = getelementptr i64, ptr %array, i64 3
  %lower = load i64, ptr %array, align 8
  %upper = load i64, ptr %upper.ptr, align 8
  %data = load ptr, ptr %data.ptr, align 8
  %block = load ptr, ptr %block.ptr, align 8
  %lease.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 14
  %lease = load ptr, ptr %lease.ptr, align 8
  %unowned = icmp eq ptr %block, null
  %empty = icmp slt i64 %upper, %lower
  %unleased = icmp eq ptr %lease, null
  %mine = icmp eq ptr %lease, %array
  %zero = icmp eq i64 %count, 0
  br i1 %zero, label %release.check, label %acquire.check
release.check:
  %empty.unleased = and i1 %empty, %unleased
  %releasable = or i1 %mine, %empty.unleased
  %release.valid = and i1 %releasable, %unowned
  br i1 %release.valid, label %release, label %bad
release:
  store i64 0, ptr %array, align 8
  store i64 -1, ptr %upper.ptr, align 8
  store ptr null, ptr %data.ptr, align 8
  store ptr null, ptr %lease.ptr, align 8
  ret i1 true
acquire.check:
  %empty.unowned = and i1 %empty, %unowned
  %available = and i1 %empty.unowned, %unleased
  br i1 %available, label %acquire, label %bad
acquire:
  %workspace.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 13
  %workspace = load ptr, ptr %workspace.ptr, align 8
  br label %clear
clear:
  %index = phi i64 [ 0, %acquire ], [ %next, %clear ]
  %cell = getelementptr i64, ptr %workspace, i64 %index
  store volatile i64 0, ptr %cell, align 8
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %clear, label %publish
publish:
  %last = sub i64 %count, 1
  store i64 0, ptr %array, align 8
  store i64 %last, ptr %upper.ptr, align 8
  store ptr %workspace, ptr %data.ptr, align 8
  store ptr %array, ptr %lease.ptr, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
memory:
  store atomic i64 7, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
; Exact typed payload publication boundary; layout/count are compiler metadata.
define void @ube.managed.publish.range(ptr %ctx, ptr %destination, ptr %layout, i64 %count) {
entry:
  fence release
  ret void
}
define i1 @ube.managed.shutdown(ptr %ctx) {
entry:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %present = icmp ne ptr %state, null
  br i1 %present, label %roots, label %done
roots:
  %global = getelementptr %ube.managed.state, ptr %state, i32 0, i32 11
  %roots.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 4
  %root = load ptr, ptr %roots.ptr, align 8
  %is.global = icmp eq ptr %root, %global
  %no.roots = icmp eq ptr %root, null
  %ready = or i1 %is.global, %no.roots
  br i1 %ready, label %retire, label %busy
retire:
  br i1 %is.global, label %pop, label %collect
pop:
  call void @ube.managed.root.pop(ptr %ctx, ptr %global)
  br label %collect
collect:
  call void @ube.managed.discard(ptr %ctx)
  %result = call { i1, i64 } @ube.managed.collect(ptr %ctx, i64 -1)
  %success = extractvalue { i1, i64 } %result, 0
  %head = load ptr, ptr %state, align 8
  %empty = icmp eq ptr %head, null
  %clean = and i1 %success, %empty
  br i1 %clean, label %detach, label %busy
detach:
  %program = call ptr @ube.thread.program(ptr %ctx)
  %slot = getelementptr %ube.program, ptr %program, i32 0, i32 14
  store atomic ptr null, ptr %slot release, align 8
  %metadata.ptr = getelementptr %ube.managed.state, ptr %state, i32 0, i32 15
  %metadata = load ptr, ptr %metadata.ptr, align 8
  store ptr null, ptr %metadata.ptr, align 8
  call void @ube.block.drop(ptr %ctx, ptr %metadata)
  %block = getelementptr %ube.block, ptr %state, i64 -1
  call void @ube.block.drop(ptr %ctx, ptr %block)
  br label %done
busy:
  ret i1 false
done:
  ret i1 true
}
; Native thread mechanics. Generated source entry thunks own typed capture cleanup.
%ube.worker = type { ptr, i64, ptr, i64, i64, i64, ptr, ptr, %ube.thread, i64, i64, i64, %ube.rootframe }
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
  %block = call ptr @ube.memory.new(ptr %ctx, i64 25, i64 1)
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
  call void @ube.managed.enter(ptr %ctx)
  %success = call i1 %procedure(ptr %ctx, ptr %payload)
  %error = load i64, ptr %ctx, align 8
  %saved = select i1 %success, i64 0, i64 %error
  %error.ptr = getelementptr %ube.worker, ptr %record, i32 0, i32 4
  store i64 %saved, ptr %error.ptr, align 8
  %capture.root = getelementptr %ube.worker, ptr %record, i32 0, i32 12
  call void @ube.managed.root.restore(ptr %ctx, ptr %capture.root)
  call void @ube.block.drop(ptr %ctx, ptr %capture)
  store ptr null, ptr %capture.ptr, align 8
  call void @ube.managed.discard(ptr %ctx)
  call void @ube.managed.thread.unregister(ptr %ctx)
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
  %capture.root = getelementptr %ube.worker, ptr %record, i32 0, i32 12
  call void @ube.managed.owner.root(ptr %thread, ptr %capture.root, ptr %capture)
  call void @ube.managed.safe(ptr %ctx)
  %handle = call ptr @ube.target.thread.start(ptr @ube.thread.entry, ptr %record)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.root.restore(ptr %thread, ptr %capture.root)
  call void @ube.managed.thread.unregister(ptr %thread)
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
  call void @ube.managed.safe(ptr %ctx)
  %ok = call i1 @ube.target.thread.close(ptr %handle)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %status = call i32 @ube.target.thread.wait(ptr %handle, i32 0)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  call void @Sleep(i32 1)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  call void @Sleep(i32 1)
  call void @ube.managed.enter(ptr %ctx)
  br label %round
retained:
  %remaining = load atomic i64, ptr %active.ptr acquire, align 8
  %workers.live = icmp ne i64 %remaining, 0
  br i1 %workers.live, label %retry.observation, label %failed
retry.observation:
  call void @ube.managed.safe(ptr %ctx)
  call void @Sleep(i32 1)
  call void @ube.managed.enter(ptr %ctx)
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
  call void @ube.managed.safe(ptr %ctx)
  %closed = call i1 @ube.target.thread.close(ptr %native)
  call void @ube.managed.enter(ptr %ctx)
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
; Genuine class identities share precise managed allocation metadata, never value-record identities.
define internal ptr @ube.object.find(ptr %ctx, i64 %identity) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %nothing, label %read.state
read.state:
  %state = call ptr @ube.managed.state(ptr %ctx)
  %installed = icmp ne ptr %state, null
  br i1 %installed, label %find, label %bad
find:
  %record = call ptr @ube.managed.find(ptr %state, i64 %identity)
  %exists = icmp ne ptr %record, null
  br i1 %exists, label %read.kind, label %bad
read.kind:
  %kind.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 11
  %kind = load i64, ptr %kind.ptr, align 8
  %object = icmp eq i64 %kind, 3
  br i1 %object, label %size, label %bad
size:
  %bytes.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 5
  %bytes = load i64, ptr %bytes.ptr, align 8
  %valid = icmp uge i64 %bytes, 24
  br i1 %valid, label %done, label %bad
done:
  ret ptr %record
nothing:
  store atomic i64 91, ptr %ctx monotonic, align 8
  ret ptr null
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret ptr null
}
; Header: immutable class descriptor, atomic owning thread context, owner-only recursion.
define i1 @ube.object.create(ptr %ctx, ptr %descriptor, ptr %layout, i64 %bytes, ptr %cleanup, ptr %output) {
entry:
  %identity.slot = alloca i64, align 8
  %descriptor.valid = icmp ne ptr %descriptor, null
  %output.valid = icmp ne ptr %output, null
  %size.valid = icmp ule i64 %bytes, 9223372036854775783
  %pointers.valid = and i1 %descriptor.valid, %output.valid
  %valid = and i1 %pointers.valid, %size.valid
  br i1 %valid, label %allocate, label %bad
allocate:
  %total = add i64 %bytes, 24
  %allocated = call i1 @ube.managed.create(ptr %ctx, i64 %total, i64 0, i64 3, ptr %identity.slot)
  br i1 %allocated, label %initialize, label %failed
initialize:
  %identity = load i64, ptr %identity.slot, align 8
  ; A rejected candidate stays frame-owned for ordinary cleanup; output is untouched.
  %record = call ptr @ube.managed.candidate(ptr %ctx, i64 %identity)
  %present = icmp ne ptr %record, null
  br i1 %present, label %metadata, label %failed
metadata:
  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %header = load ptr, ptr %data.ptr, align 8
  %fields = getelementptr i8, ptr %header, i64 24
  store ptr %descriptor, ptr %header, align 8
  store ptr %fields, ptr %data.ptr, align 8
  %layout.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 7
  %count.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 8
  %cleanup.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 12
  %has.layout = icmp ne ptr %layout, null
  %count = zext i1 %has.layout to i64
  store ptr %layout, ptr %layout.ptr, align 8
  store i64 %count, ptr %count.ptr, align 8
  store ptr %cleanup, ptr %cleanup.ptr, align 8
  store i64 %identity, ptr %output, align 8
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
; The caller keeps an exact identity root alive while using the returned field address.
define ptr @ube.object.address(ptr %ctx, i64 %identity, ptr %descriptor) {
entry:
  %record = call ptr @ube.object.find(ptr %ctx, i64 %identity)
  %present = icmp ne ptr %record, null
  br i1 %present, label %type, label %failed
type:
  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %fields = load ptr, ptr %data.ptr, align 8
  %header = getelementptr i8, ptr %fields, i64 -24
  %actual = load ptr, ptr %header, align 8
  %same = icmp eq ptr %actual, %descriptor
  br i1 %same, label %done, label %bad
done:
  ret ptr %fields
bad:
  store atomic i64 13, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret ptr null
}
; Source Object may hide its static class, but each instance retains its exact nominal identity.
define {i1,i64} @ube.object.nominal(ptr %ctx, i64 %identity) {
entry:
  %empty = icmp eq i64 %identity, 0
  br i1 %empty, label %nothing, label %find
find:
  %record = call ptr @ube.object.find(ptr %ctx, i64 %identity)
  %present = icmp ne ptr %record, null
  br i1 %present, label %descriptor, label %failed
descriptor:
  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %fields = load ptr, ptr %data.ptr, align 8
  %header = getelementptr i8, ptr %fields, i64 -24
  %description = load ptr, ptr %header, align 8
  %described = icmp ne ptr %description, null
  br i1 %described, label %read.nominal, label %bad
read.nominal:
  %nominal = load i64, ptr %description, align 8
  %valid = icmp sgt i64 %nominal, 0
  br i1 %valid, label %done, label %bad
done:
  %result = insertvalue {i1,i64} {i1 true,i64 0}, i64 %nominal, 1
  ret {i1,i64} %result
nothing:
  ret {i1,i64} {i1 true,i64 0}
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret {i1,i64} zeroinitializer
}
; Rooted callers remain registered UBE threads for the entire acquired/waiting interval.
define {i1,i64} @ube.monitor.tryenter(ptr %ctx, i64 %identity) {
entry:
  %record = call ptr @ube.object.find(ptr %ctx, i64 %identity)
  %present = icmp ne ptr %record, null
  br i1 %present, label %inspect, label %failed
inspect:
  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %fields = load ptr, ptr %data.ptr, align 8
  %owner.ptr = getelementptr i8, ptr %fields, i64 -16
  %depth.ptr = getelementptr i8, ptr %fields, i64 -8
  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8
  %mine = icmp eq ptr %owner, %ctx
  br i1 %mine, label %reenter, label %acquire
reenter:
  %depth = load i64, ptr %depth.ptr, align 8
  %positive = icmp ugt i64 %depth, 0
  %room = icmp ult i64 %depth, 9223372036854775807
  %valid = and i1 %positive, %room
  br i1 %valid, label %increment, label %overflow
increment:
  %next = add i64 %depth, 1
  store i64 %next, ptr %depth.ptr, align 8
  br label %acquired
acquire:
  %pair = cmpxchg ptr %owner.ptr, ptr null, ptr %ctx acquire monotonic
  %won = extractvalue {ptr,i1} %pair, 1
  br i1 %won, label %initialize, label %busy
initialize:
  store i64 1, ptr %depth.ptr, align 8
  br label %acquired
acquired:
  ret {i1,i64} {i1 true,i64 1}
busy:
  ret {i1,i64} {i1 true,i64 0}
overflow:
  store atomic i64 6, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret {i1,i64} zeroinitializer
}
; Valid compiler-owned release is allocation-free, cannot fail, and preserves Err.
define i1 @ube.monitor.leave(ptr %ctx, i64 %identity) {
entry:
  %record = call ptr @ube.object.find(ptr %ctx, i64 %identity)
  %present = icmp ne ptr %record, null
  br i1 %present, label %inspect, label %failed
inspect:
  %data.ptr = getelementptr %ube.managed.record, ptr %record, i32 0, i32 9
  %fields = load ptr, ptr %data.ptr, align 8
  %owner.ptr = getelementptr i8, ptr %fields, i64 -16
  %depth.ptr = getelementptr i8, ptr %fields, i64 -8
  %owner = load atomic ptr, ptr %owner.ptr acquire, align 8
  %mine = icmp eq ptr %owner, %ctx
  br i1 %mine, label %read.depth, label %bad
read.depth:
  %depth = load i64, ptr %depth.ptr, align 8
  %valid = icmp ugt i64 %depth, 0
  br i1 %valid, label %decrement, label %bad
decrement:
  %next = sub i64 %depth, 1
  store i64 %next, ptr %depth.ptr, align 8
  %last = icmp eq i64 %next, 0
  br i1 %last, label %release, label %done
release:
  store atomic ptr null, ptr %owner.ptr release, align 8
  br label %done
done:
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
; Scheduling backoff only: correctness depends on atomics and roots, never the sleep duration.
define i1 @ube.monitor.yield(ptr %ctx) {
entry:
  call void @ube.managed.safe(ptr %ctx)
  call void @Sleep(i32 1)
  call void @ube.managed.enter(ptr %ctx)
  ret i1 true
}
; Structured cleanup retains both slots on an invalid acquired-state release.
define i1 @ube.monitor.retire(ptr %ctx, ptr %identity.slot, ptr %acquired.slot) {
entry:
  %identity.valid = icmp ne ptr %identity.slot, null
  %acquired.valid = icmp ne ptr %acquired.slot, null
  %valid = and i1 %identity.valid, %acquired.valid
  br i1 %valid, label %inspect, label %bad
inspect:
  %acquired = load atomic i64, ptr %acquired.slot acquire, align 8
  %empty = icmp eq i64 %acquired, 0
  br i1 %empty, label %clear, label %owned
owned:
  %held = icmp eq i64 %acquired, 1
  br i1 %held, label %release, label %bad
release:
  %identity = load atomic i64, ptr %identity.slot acquire, align 8
  %released = call i1 @ube.monitor.leave(ptr %ctx, i64 %identity)
  br i1 %released, label %clear, label %failed
clear:
  store atomic i64 0, ptr %acquired.slot release, align 8
  call void @ube.managed.store(ptr %ctx, ptr %identity.slot, i64 0)
  ret i1 true
bad:
  store atomic i64 5, ptr %ctx monotonic, align 8
  br label %failed
failed:
  ret i1 false
}
