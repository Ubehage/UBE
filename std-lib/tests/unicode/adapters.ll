define i32 @test_letter(i32 %scalar) {
  %answer = call i1 @LETTER@(i32 %scalar)
  %result = zext i1 %answer to i32
  ret i32 %result
}
define i32 @test_fold(i32 %scalar) {
  %result = call i32 @FOLD@(i32 %scalar)
  ret i32 %result
}
define i32 @test_cursor(ptr %bytes, i32 %offset, ptr %scalar, ptr %width) {
  %answer = call i1 @CURSOR@(ptr %bytes, i32 %offset, ptr %scalar, ptr %width)
  %result = zext i1 %answer to i32
  ret i32 %result
}
