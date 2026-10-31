; Test-only ABI wrappers; every callee signature is pinned before concatenation.
declare void @metrics_feed_called()
declare void @metrics_finish_called()
define i64 @metrics_buffer_size() {
  ret i64 ptrtoint (ptr getelementptr (%ube.type.1, ptr null, i32 1) to i64)
}
define i64 @metrics_buffer_alignment() {
  ret i64 ptrtoint (ptr getelementptr ({ i8, %ube.type.1 }, ptr null, i32 0, i32 1) to i64)
}
define i64 @metrics_count_offset() {
  ret i64 ptrtoint (ptr getelementptr (%ube.type.1, ptr null, i32 0, i32 1) to i64)
}
define i64 @metrics_decoder_size() {
  ret i64 ptrtoint (ptr getelementptr (%ube.type.0, ptr null, i32 1) to i64)
}
define i1 @ube.p1(ptr %state, i8 %byte, ptr %scalar, ptr %complete) {
  call void @metrics_feed_called()
  %ok = call i1 @metrics_feed_body(ptr %state, i8 %byte, ptr %scalar, ptr %complete)
  ret i1 %ok
}
define i1 @ube.p2(ptr %state) {
  call void @metrics_finish_called()
  %ok = call i1 @metrics_finish_body(ptr %state)
  ret i1 %ok
}
define i32 @metrics_capacity(ptr %buffer) {
  %n = call i32 @ube.p7(ptr %buffer)
  ret i32 %n
}
define i32 @metrics_length(ptr %buffer) {
  %n = call i32 @ube.p8(ptr %buffer)
  ret i32 %n
}
define i32 @metrics_reserve(ptr %buffer, i32 %minimum) {
  %ok = call i1 @ube.p9(ptr %buffer, i32 %minimum)
  %wide = zext i1 %ok to i32
  ret i32 %wide
}
define i32 @metrics_append(ptr %buffer, i8 %byte) {
  %ok = call i1 @ube.p10(ptr %buffer, i8 %byte)
  %wide = zext i1 %ok to i32
  ret i32 %wide
}
define i32 @metrics_append_range(ptr %buffer, ptr %source, i32 %start, i32 %count) {
  %ok = call i1 @ube.p11(ptr %buffer, ptr %source, i32 %start, i32 %count)
  %wide = zext i1 %ok to i32
  ret i32 %wide
}
define i32 @metrics_clear(ptr %buffer) {
  %ok = call i1 @ube.p12(ptr %buffer)
  %wide = zext i1 %ok to i32
  ret i32 %wide
}
define i32 @metrics_snapshot(ptr %buffer, ptr %output) {
  %ok = call i1 @ube.p13(ptr %buffer, ptr %output)
  %wide = zext i1 %ok to i32
  ret i32 %wide
}
define i32 @metrics_count_utf8(ptr %buffer, ptr %count) {
  %ok = call i1 @ube.p14(ptr %buffer, ptr %count)
  %wide = zext i1 %ok to i32
  ret i32 %wide
}
define i32 @metrics_scoped(i8 %marker, i32 %cancel) {
  %flag = trunc i32 %cancel to i1
  %ok = call i1 @ube.p15(i8 %marker, i1 %flag)
  %wide = zext i1 %ok to i32
  ret i32 %wide
}
