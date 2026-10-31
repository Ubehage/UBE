; Test-only C ABI bridges. The compiler-emitted bodies/types remain intact.
define i64 @test_state_size() {
  %p = getelementptr %ube.type.0, ptr null, i32 1
  %n = ptrtoint ptr %p to i64
  ret i64 %n
}
define i64 @test_state_alignment() {
  %p = getelementptr { i8, %ube.type.0 }, ptr null, i32 0, i32 1
  %n = ptrtoint ptr %p to i64
  ret i64 %n
}
define void @test_reset(ptr %state) {
  call void @ube.p0(ptr %state)
  ret void
}
define i32 @test_feed(ptr %state, i8 %byte, ptr %scalar, ptr %complete) {
  %b = alloca i1
  %ok = call i1 @ube.p1(ptr %state, i8 %byte, ptr %scalar, ptr %b)
  %c = load i1, ptr %b
  %wide = zext i1 %c to i32
  store i32 %wide, ptr %complete
  %result = zext i1 %ok to i32
  ret i32 %result
}
define i32 @test_finish(ptr %state) {
  %ok = call i1 @ube.p2(ptr %state)
  %result = zext i1 %ok to i32
  ret i32 %result
}
define void @test_copy(ptr %destination, ptr %source) {
  call void @ube.p3(ptr %destination, ptr %source)
  ret void
}
define void @test_disturb(ptr %state) {
  %value = load %ube.type.0, ptr %state
  call void @ube.p4(%ube.type.0 %value)
  ret void
}
define void @test_corrupt(ptr %state, i32 %which) {
  call void @ube.p5(ptr %state, i32 %which)
  ret void
}
