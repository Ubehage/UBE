; Test-only C ABI. The runner pins every production type and callee signature.
declare void @source_feed_called()
declare void @source_reserve_enter()
declare void @source_reserve_leave()

define i32 @source_begin(ptr %input, i32 %limit) {
  %ok = call i1 @BEGIN@(ptr %input, i32 %limit)
  %status = zext i1 %ok to i32
  ret i32 %status
}
define i32 @source_append(ptr %input, ptr %bytes, i32 %start, i32 %count, ptr %failure) {
  %ok = call i1 @APPEND@(ptr %input, ptr %bytes, i32 %start, i32 %count, ptr %failure)
  %status = zext i1 %ok to i32
  ret i32 %status
}
define i32 @source_finish(ptr %input, ptr %document, ptr %failure) {
  %ok = call i1 @FINISH@(ptr %input, ptr %document, ptr %failure)
  %status = zext i1 %ok to i32
  ret i32 %status
}
define i32 @source_file(ptr %path, i32 %limit, ptr %document, ptr %failure, ptr %filefailure, ptr %token) {
  %ok = call i1 @FILE@(ptr %path, i32 %limit, ptr %document, ptr %failure, ptr %filefailure, ptr %token)
  %status = zext i1 %ok to i32
  ret i32 %status
}
define i32 @source_scoped(i32 %cancel) {
  %flag = trunc i32 %cancel to i1
  %ok = call i1 @SCOPED@(i1 %flag)
  %status = zext i1 %ok to i32
  ret i32 %status
}
define i32 @source_copy(ptr %destination, ptr %original) {
  %ok = call i1 @COPY@(ptr %destination, ptr %original)
  %status = zext i1 %ok to i32
  ret i32 %status
}
define i1 @FEED@(ptr %decoder, i8 %byte, ptr %scalar, ptr %complete) {
  call void @source_feed_called()
  %ok = call i1 @source_feed_body(ptr %decoder, i8 %byte, ptr %scalar, ptr %complete)
  ret i1 %ok
}
define i1 @RESERVE@(ptr %buffer, i32 %minimum) {
  call void @source_reserve_enter()
  %ok = call i1 @source_reserve_body(ptr %buffer, i32 %minimum)
  call void @source_reserve_leave()
  ret i1 %ok
}
