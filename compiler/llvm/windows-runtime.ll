%ube.block = type { ptr, i64, i64 }
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
  %refs = load i64, ptr %refs.ptr
  %next = add i64 %refs, 1
  store i64 %next, ptr %refs.ptr
  br label %done
done:
  ret void
}
define internal void @ube.block.drop(ptr %block) {
entry:
  %exists = icmp ne ptr %block, null
  br i1 %exists, label %drop, label %done
drop:
  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1
  %refs = load i64, ptr %refs.ptr
  %next = sub i64 %refs, 1
  store i64 %next, ptr %refs.ptr
  br label %done
done:
  ret void
}
define internal i1 @ube.memory.collect(ptr %ctx) {
entry:
  %head = getelementptr %ube.context, ptr %ctx, i32 0, i32 4
  %bytes.ptr = getelementptr %ube.context, ptr %ctx, i32 0, i32 5
  %count.ptr = getelementptr %ube.context, ptr %ctx, i32 0, i32 6
  br label %scan
scan:
  %link = phi ptr [ %head, %entry ], [ %block, %keep ], [ %link, %freed ]
  %worked = phi i1 [ false, %entry ], [ %worked, %keep ], [ true, %freed ]
  %block = load ptr, ptr %link
  %exists = icmp ne ptr %block, null
  br i1 %exists, label %inspect, label %done
inspect:
  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1
  %refs = load i64, ptr %refs.ptr
  %unused = icmp eq i64 %refs, 0
  br i1 %unused, label %release, label %keep
release:
  %next = load ptr, ptr %block
  %charge.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 2
  %charge = load i64, ptr %charge.ptr
  %ok = call i1 @ube.target.release(ptr %block)
  br i1 %ok, label %freed, label %keep
freed:
  store ptr %next, ptr %link
  %bytes = load i64, ptr %bytes.ptr
  %less.bytes = sub i64 %bytes, %charge
  store i64 %less.bytes, ptr %bytes.ptr
  %count = load i64, ptr %count.ptr
  %less.count = sub i64 %count, 1
  store i64 %less.count, ptr %count.ptr
  br label %scan
keep:
  br label %scan
done:
  ret i1 %worked
}
define internal ptr @ube.memory.new(ptr %ctx, i64 %count, i64 %stride) {
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
  %head = getelementptr %ube.context, ptr %ctx, i32 0, i32 4
  %bytes.ptr = getelementptr %ube.context, ptr %ctx, i32 0, i32 5
  %count.ptr = getelementptr %ube.context, ptr %ctx, i32 0, i32 6
  br label %attempt
attempt:
  %retry = phi i1 [ false, %quota ], [ true, %collect ]
  %bytes = load i64, ptr %bytes.ptr
  %blocks = load i64, ptr %count.ptr
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
  %collected = call i1 @ube.memory.collect(ptr %ctx)
  br label %attempt
allocated:
  %old.head = load ptr, ptr %head
  store ptr %old.head, ptr %block
  %refs.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 1
  store i64 1, ptr %refs.ptr
  %charge.ptr = getelementptr %ube.block, ptr %block, i32 0, i32 2
  store i64 %charge, ptr %charge.ptr
  store ptr %block, ptr %head
  %new.bytes = add i64 %bytes, %charge
  %new.blocks = add i64 %blocks, 1
  store i64 %new.bytes, ptr %bytes.ptr
  store i64 %new.blocks, ptr %count.ptr
  %data = getelementptr %ube.block, ptr %block, i64 1
  br label %zero
zero:
  %index = phi i64 [ 0, %allocated ], [ %next.index, %zero ]
  %cell = getelementptr i64, ptr %data, i64 %index
  store volatile i64 0, ptr %cell
  %next.index = add i64 %index, 1
  %more = icmp ult i64 %next.index, %cells
  br i1 %more, label %zero, label %done
done:
  ret ptr %block
failed:
  ret ptr null
}
define internal void @ube.array.clear(ptr %array) {
entry:
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %block.ptr = getelementptr i64, ptr %array, i64 3
  %old = load ptr, ptr %block.ptr
  store i64 0, ptr %array
  store i64 -1, ptr %upper.ptr
  store ptr null, ptr %data.ptr
  store ptr null, ptr %block.ptr
  call void @ube.block.drop(ptr %old)
  ret void
}
define internal void @ube.array.install(ptr %array, ptr %block, i64 %lower, i64 %upper) {
entry:
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %block.ptr = getelementptr i64, ptr %array, i64 3
  %old = load ptr, ptr %block.ptr
  %data = getelementptr %ube.block, ptr %block, i64 1
  store i64 %lower, ptr %array
  store i64 %upper, ptr %upper.ptr
  store ptr %data, ptr %data.ptr
  store ptr %block, ptr %block.ptr
  call void @ube.block.drop(ptr %old)
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
  %value = load volatile i64, ptr %from
  store volatile i64 %value, ptr %to
  %next = add i64 %index, 1
  %more = icmp ult i64 %next, %count
  br i1 %more, label %copy, label %done
done:
  ret void
}
define internal i1 @ube.array.tryresize(ptr %ctx, ptr %array, i64 %count, i64 %preserve, i64 %stride) {
entry:
  %err = getelementptr %ube.context, ptr %ctx, i32 0, i32 0
  %negative = icmp slt i64 %count, 0
  br i1 %negative, label %argument.fail, label %empty.test
empty.test:
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %empty.resize, label %allocate
empty.resize:
  call void @ube.array.clear(ptr %array)
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
  %old.lower = load i64, ptr %array
  %old.upper.ptr = getelementptr i64, ptr %array, i64 1
  %old.upper = load i64, ptr %old.upper.ptr
  %positive.lower = icmp sgt i64 %old.lower, 0
  %first = select i1 %positive.lower, i64 %old.lower, i64 0
  %smaller.upper = icmp slt i64 %old.upper, %upper
  %last = select i1 %smaller.upper, i64 %old.upper, i64 %upper
  %overlap = icmp sle i64 %first, %last
  br i1 %overlap, label %copy, label %publish
copy:
  %old.data.ptr = getelementptr i64, ptr %array, i64 2
  %old.data = load ptr, ptr %old.data.ptr
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
  call void @ube.array.install(ptr %array, ptr %block, i64 0, i64 %upper)
  %collected = call i1 @ube.memory.collect(ptr %ctx)
  ret i1 true
argument.fail:
  store i64 5, ptr %err
  ret i1 false
memory.fail:
  store i64 7, ptr %err
  ret i1 false
}
define internal i1 @ube.array.trycopy(ptr %ctx, ptr %destination, ptr %source, i64 %stride) {
entry:
  %err = getelementptr %ube.context, ptr %ctx, i32 0, i32 0
  %lower = load i64, ptr %source
  %upper.ptr = getelementptr i64, ptr %source, i64 1
  %upper = load i64, ptr %upper.ptr
  %distance = sub i64 %upper, %lower
  %count = add i64 %distance, 1
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %empty.copy, label %allocate
empty.copy:
  call void @ube.array.clear(ptr %destination)
  %empty.collected = call i1 @ube.memory.collect(ptr %ctx)
  ret i1 true
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 %count, i64 %stride)
  %ok = icmp ne ptr %block, null
  br i1 %ok, label %copy, label %memory.fail
copy:
  %source.data.ptr = getelementptr i64, ptr %source, i64 2
  %source.data = load ptr, ptr %source.data.ptr
  %destination.data = getelementptr %ube.block, ptr %block, i64 1
  %cells = mul i64 %count, %stride
  call void @ube.cells.copy(ptr %source.data, ptr %destination.data, i64 %cells)
  call void @ube.array.install(ptr %destination, ptr %block, i64 %lower, i64 %upper)
  %collected = call i1 @ube.memory.collect(ptr %ctx)
  ret i1 true
memory.fail:
  store i64 7, ptr %err
  ret i1 false
}
@ube.file.next = internal global i64 1, align 8
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
  %access = select i1 %write, i32 1073741824, i32 -2147483648
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
  %err = getelementptr %ube.context, ptr %ctx, i32 0, i32 0
  store i64 %number, ptr %err
  store i64 %code, ptr %failure
  ret i1 false
}
define internal i1 @ube.file.aliasfail(ptr %ctx) {
entry:
  %err = getelementptr %ube.context, ptr %ctx, i32 0, i32 0
  store i64 5, ptr %err
  ret i1 false
}
define internal i64 @ube.file.token() {
entry:
  br label %attempt
attempt:
  %old = load atomic i64, ptr @ube.file.next acquire, align 8
  %exhausted = icmp ugt i64 %old, 2147483647
  br i1 %exhausted, label %failed, label %advance
advance:
  %next = add i64 %old, 1
  %pair = cmpxchg ptr @ube.file.next, i64 %old, i64 %next acq_rel acquire
  %won = extractvalue { i64, i1 } %pair, 1
  br i1 %won, label %done, label %attempt
done:
  ret i64 %old
failed:
  ret i64 0
}
define internal ptr @ube.file.reserve(ptr %ctx) {
entry:
  br label %scan
scan:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %slot = getelementptr %ube.context, ptr %ctx, i32 0, i32 7, i64 %index
  %token = load atomic i64, ptr %slot acquire, align 8
  %empty = icmp eq i64 %token, 0
  br i1 %empty, label %claim, label %advance
claim:
  %busy = getelementptr %ube.file, ptr %slot, i32 0, i32 4
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
define internal void @ube.file.unlock(ptr %slot) {
entry:
  %busy = getelementptr %ube.file, ptr %slot, i32 0, i32 4
  store atomic i64 0, ptr %busy release, align 8
  ret void
}
define internal i1 @ube.file.empty(ptr %ctx) {
entry:
  br label %scan
scan:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %slot = getelementptr %ube.context, ptr %ctx, i32 0, i32 7, i64 %index
  %token = load atomic i64, ptr %slot acquire, align 8
  %busy.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 4
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
define internal ptr @ube.file.acquire(ptr %ctx, i64 %wanted, ptr %failure) {
entry:
  %positive = icmp sgt i64 %wanted, 0
  br i1 %positive, label %scan, label %stale
scan:
  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
  %slot = getelementptr %ube.context, ptr %ctx, i32 0, i32 7, i64 %index
  %token = load atomic i64, ptr %slot acquire, align 8
  %matches = icmp eq i64 %token, %wanted
  br i1 %matches, label %claim, label %advance
claim:
  %busy.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 4
  %pair = cmpxchg ptr %busy.ptr, i64 0, i64 1 acq_rel acquire
  %won = extractvalue { i64, i1 } %pair, 1
  br i1 %won, label %check, label %busy
check:
  %again = load atomic i64, ptr %slot acquire, align 8
  %same = icmp eq i64 %again, %wanted
  br i1 %same, label %done, label %unlock
unlock:
  call void @ube.file.unlock(ptr %slot)
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
define internal void @ube.file.forget(ptr %ctx, ptr %slot) {
entry:
  %block.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 2
  %block = load ptr, ptr %block.ptr
  store ptr null, ptr %block.ptr
  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1
  store ptr null, ptr %handle.ptr
  store atomic i64 0, ptr %slot release, align 8
  call void @ube.block.drop(ptr %block)
  call void @ube.file.unlock(ptr %slot)
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
  %lower = load i64, ptr %array
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load i64, ptr %upper.ptr
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
define internal i1 @ube.file.open(ptr %ctx, ptr %path, i64 %maximum, ptr %token.out, ptr %length.out, ptr %failure, i1 %write) {
entry:
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
  store i64 0, ptr %length.out
  store i64 0, ptr %failure
  %old.token = load i64, ptr %token.out
  %owned = icmp ne i64 %old.token, 0
  %negative = icmp slt i64 %maximum, 0
  %bad.request = or i1 %owned, %negative
  br i1 %bad.request, label %request.fail, label %path.size
request.fail:
  %request.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 1, i64 5)
  ret i1 false
path.size:
  %lower = load i64, ptr %path
  %upper.ptr = getelementptr i64, ptr %path, i64 1
  %upper = load i64, ptr %upper.ptr
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
  %byte = load i64, ptr %cell
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
  %slot = call ptr @ube.file.reserve(ptr %ctx)
  %no.slot = icmp eq ptr %slot, null
  br i1 %no.slot, label %allocation.fail, label %identity
identity:
  %token = call i64 @ube.file.token()
  %exhausted = icmp eq i64 %token, 0
  br i1 %exhausted, label %unreserve, label %allocate
allocate:
  %block = call ptr @ube.memory.new(ptr %ctx, i64 8192, i64 1)
  %no.memory = icmp eq ptr %block, null
  br i1 %no.memory, label %unreserve, label %pack.start
unreserve:
  call void @ube.file.unlock(ptr %slot)
  br label %allocation.fail
allocation.fail:
  %allocation.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 8, i64 7)
  ret i1 false
pack.start:
  %block.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 2
  store ptr %block, ptr %block.ptr
  %packed = getelementptr %ube.block, ptr %block, i64 1
  %wide = getelementptr i8, ptr %packed, i64 4096
  br label %pack
pack:
  %pack.index = phi i64 [ 0, %pack.start ], [ %pack.next, %pack ]
  %pack.source = getelementptr i64, ptr %data, i64 %pack.index
  %pack.value = load i64, ptr %pack.source
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
  call void @ube.file.forget(ptr %ctx, ptr %slot)
  br label %path.fail
open:
  %terminator = getelementptr i16, ptr %wide, i32 %wide.length
  store i16 0, ptr %terminator
  %handle = call ptr @ube.target.file.open(ptr %wide, i1 %write)
  %invalid.handle = icmp eq ptr %handle, inttoptr (i64 -1 to ptr)
  %null.handle = icmp eq ptr %handle, null
  %bad.handle = or i1 %invalid.handle, %null.handle
  br i1 %bad.handle, label %open.fail, label %admit
open.fail:
  call void @ube.file.forget(ptr %ctx, ptr %slot)
  %open.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 3, i64 57)
  ret i1 false
admit:
  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1
  store ptr %handle, ptr %handle.ptr
  %mode.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 3
  %mode = select i1 %write, i64 2, i64 1
  store i64 %mode, ptr %mode.ptr
  %kind = call i32 @ube.target.file.type(ptr %handle)
  %regular = icmp eq i32 %kind, 1
  br i1 %regular, label %mode.check, label %query.fail
mode.check:
  br i1 %write, label %success.create, label %query
query:
  store i64 0, ptr %size.out
  %queried = call i1 @ube.target.file.size(ptr %handle, ptr %size.out)
  br i1 %queried, label %size.check, label %query.fail
size.check:
  %size = load i64, ptr %size.out
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
  call void @ube.file.forget(ptr %ctx, ptr %slot)
  %reject.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %failure.code, i64 %error.number)
  ret i1 false
retained:
  store atomic i64 %token, ptr %slot release, align 8
  store i64 %token, ptr %token.out
  call void @ube.file.unlock(ptr %slot)
  %close.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 7, i64 57)
  ret i1 false
success.create:
  br label %success
success.read:
  br label %success
success:
  %result.length = phi i64 [ 0, %success.create ], [ %size, %success.read ]
  store atomic i64 %token, ptr %slot release, align 8
  store i64 %token, ptr %token.out
  store i64 %result.length, ptr %length.out
  call void @ube.file.unlock(ptr %slot)
  ret i1 true
}
define internal i1 @ube.file.transfer(ptr %ctx, i64 %token, ptr %array, i64 %start, i64 %count, ptr %progress, ptr %failure, i1 %write) {
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
  store i64 0, ptr %progress
  store i64 0, ptr %failure
  %lower = load i64, ptr %array
  %upper.ptr = getelementptr i64, ptr %array, i64 1
  %upper = load i64, ptr %upper.ptr
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
  %slot = call ptr @ube.file.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %mode
mode:
  %mode.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 3
  %actual.mode = load i64, ptr %mode.ptr
  %wanted.mode = select i1 %write, i64 2, i64 1
  %right.mode = icmp eq i64 %actual.mode, %wanted.mode
  br i1 %right.mode, label %check.empty, label %mode.fail
mode.fail:
  call void @ube.file.unlock(ptr %slot)
  %mode.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret i1 false
check.empty:
  %empty = icmp eq i64 %count, 0
  br i1 %empty, label %empty.success, label %prepare
empty.success:
  call void @ube.file.unlock(ptr %slot)
  ret i1 true
prepare:
  %data.ptr = getelementptr i64, ptr %array, i64 2
  %data = load ptr, ptr %data.ptr
  %payload = getelementptr i64, ptr %data, i64 %start
  %owner.ptr = getelementptr i64, ptr %array, i64 3
  %owner = load ptr, ptr %owner.ptr
  call void @ube.block.retain(ptr %owner)
  %scratch.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 2
  %scratch.block = load ptr, ptr %scratch.ptr
  %scratch = getelementptr %ube.block, ptr %scratch.block, i64 1
  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1
  %handle = load ptr, ptr %handle.ptr
  %count32 = trunc i64 %count to i32
  store i32 0, ptr %native.progress
  br i1 %write, label %pack, label %read
pack:
  %index = phi i64 [ 0, %prepare ], [ %next, %pack ]
  %source = getelementptr i64, ptr %payload, i64 %index
  %value = load i64, ptr %source
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
  store i64 %done, ptr %progress
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
  store volatile i64 %read.value, ptr %read.target
  %read.next = add i64 %read.index, 1
  %read.more = icmp ult i64 %read.next, %done
  br i1 %read.more, label %unpack, label %read.complete
read.complete:
  store i64 %done, ptr %progress
  br label %success
success:
  call void @ube.block.drop(ptr %owner)
  call void @ube.file.unlock(ptr %slot)
  ret i1 true
io.fail:
  call void @ube.block.drop(ptr %owner)
  call void @ube.file.unlock(ptr %slot)
  %code = select i1 %write, i64 15, i64 5
  %io.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 %code, i64 57)
  ret i1 false
failed:
  ret i1 false
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
  store i64 0, ptr %failure
  %token = load i64, ptr %token.out
  %empty = icmp eq i64 %token, 0
  br i1 %empty, label %success, label %lookup
lookup:
  %slot = call ptr @ube.file.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %close
close:
  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1
  %handle = load ptr, ptr %handle.ptr
  %closed = call i1 @ube.target.file.close(ptr %handle)
  br i1 %closed, label %released, label %close.fail
released:
  call void @ube.file.forget(ptr %ctx, ptr %slot)
  store i64 0, ptr %token.out
  br label %success
close.fail:
  call void @ube.file.unlock(ptr %slot)
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
  store i64 0, ptr %failure
  %slot = call ptr @ube.file.acquire(ptr %ctx, i64 %token, ptr %failure)
  %missing = icmp eq ptr %slot, null
  br i1 %missing, label %failed, label %mode
mode:
  %mode.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 3
  %actual.mode = load i64, ptr %mode.ptr
  %writable = icmp eq i64 %actual.mode, 2
  br i1 %writable, label %flush, label %mode.fail
mode.fail:
  call void @ube.file.unlock(ptr %slot)
  %mode.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 9, i64 5)
  ret i1 false
flush:
  %handle.ptr = getelementptr %ube.file, ptr %slot, i32 0, i32 1
  %handle = load ptr, ptr %handle.ptr
  %ok = call i1 @ube.target.file.flush(ptr %handle)
  call void @ube.file.unlock(ptr %slot)
  br i1 %ok, label %success, label %flush.fail
flush.fail:
  %flush.status = call i1 @ube.file.fail(ptr %ctx, ptr %failure, i64 16, i64 57)
  ret i1 false
success:
  ret i1 true
failed:
  ret i1 false
}
