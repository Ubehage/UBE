@test.enum.owners = internal global [16 x ptr] zeroinitializer
@test.enum.count = internal global i64 0
@test.enum.bad = internal global i1 false
@test.enum.box.calls = internal global i64 0

define { i64, i64, ptr, ptr } @test.enum.snapshot(ptr %ctx, ptr %source) {
entry:
 %snapshot = call { i64, i64, ptr, ptr } @ube.array.snapshot(ptr %ctx, ptr %source)
 %owner = extractvalue { i64, i64, ptr, ptr } %snapshot, 3
 %empty = icmp eq ptr %owner, null
 br i1 %empty, label %done, label %find
find:
 %index = phi i64 [ 0, %entry ], [ %next, %occupied ]
 %slot = getelementptr [16 x ptr], ptr @test.enum.owners, i64 0, i64 %index
 %prior = load ptr, ptr %slot
 %free = icmp eq ptr %prior, null
 br i1 %free, label %keep, label %occupied
occupied:
 %next = add i64 %index, 1
 %more = icmp ult i64 %next, 16
 br i1 %more, label %find, label %bad
keep:
 store ptr %owner, ptr %slot
 %count = load i64, ptr @test.enum.count
 %added = add i64 %count, 1
 store i64 %added, ptr @test.enum.count
 br label %done
bad:
 store i1 true, ptr @test.enum.bad
 br label %done
done:
 ret { i64, i64, ptr, ptr } %snapshot
}

define void @test.enum.drop(ptr %ctx, ptr %owner, ptr %descriptor) {
entry:
 %lower = load i64, ptr %descriptor
 %upper.ptr = getelementptr i64, ptr %descriptor, i64 1
 %upper = load i64, ptr %upper.ptr
 %data.ptr = getelementptr i64, ptr %descriptor, i64 2
 %data = load ptr, ptr %data.ptr
 %owner.ptr = getelementptr i64, ptr %descriptor, i64 3
 %stored.owner = load ptr, ptr %owner.ptr
 %index.ptr = getelementptr i64, ptr %descriptor, i64 4
 %index.value = load i64, ptr %index.ptr
 %a = icmp eq i64 %lower, 0
 %b = icmp eq i64 %upper, -1
 %c = icmp eq ptr %data, null
 %d = icmp eq ptr %stored.owner, null
 %e = icmp eq i64 %index.value, 0
 %ab = and i1 %a, %b
 %cd = and i1 %c, %d
 %abcd = and i1 %ab, %cd
 %cleared = and i1 %abcd, %e
 br i1 %cleared, label %check.owner, label %bad.root
bad.root:
 store i1 true, ptr @test.enum.bad
 br label %check.owner
check.owner:
 %empty = icmp eq ptr %owner, null
 br i1 %empty, label %drop, label %find
find:
 %index = phi i64 [ 0, %check.owner ], [ %next, %other ]
 %slot = getelementptr [16 x ptr], ptr @test.enum.owners, i64 0, i64 %index
 %stored = load ptr, ptr %slot
 %matches = icmp eq ptr %stored, %owner
 br i1 %matches, label %remove, label %other
other:
 %next = add i64 %index, 1
 %more = icmp ult i64 %next, 16
 br i1 %more, label %find, label %bad.owner
remove:
 store ptr null, ptr %slot
 %count = load i64, ptr @test.enum.count
 %removed = sub i64 %count, 1
 store i64 %removed, ptr @test.enum.count
 br label %drop
bad.owner:
 store i1 true, ptr @test.enum.bad
 br label %drop
drop:
 call void @ube.block.drop(ptr %ctx, ptr %owner)
 ret void
}

define { i1, i64 } @test.enum.observe(ptr %ctx) {
entry:
 %bad = load i1, ptr @test.enum.bad
 %count = load i64, ptr @test.enum.count
 %observed = select i1 %bad, i64 -1, i64 %count
 %result = insertvalue { i1, i64 } { i1 true, i64 0 }, i64 %observed, 1
 ret { i1, i64 } %result
}

define i1 @test.enum.box(ptr %ctx, i64 %tag, i64 %raw, ptr %layout, ptr %output) {
entry:
 %before = load i64, ptr @test.enum.box.calls
 %count = add i64 %before, 1
 store i64 %count, ptr @test.enum.box.calls
 %fail = icmp eq i64 %count, FAIL_BOX_CALL
 br i1 %fail, label %refuse, label %box
refuse:
 store atomic i64 7, ptr %ctx monotonic, align 8
 ret i1 false
box:
 %result = call i1 @ube.variant.box(ptr %ctx, i64 %tag, i64 %raw, ptr %layout, ptr %output)
 ret i1 %result
}
