; Test-only ABI adapters. Production definitions and layouts are pinned first.
declare void @scanner_feed_called()
declare void @scanner_read_called()
declare void @scanner_grow_enter()
declare void @scanner_grow_leave()
declare void @scanner_record_copied()
declare i32 @scanner_runtime_resize(ptr, i32, ptr, i32)

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
define i32 @scanner_scan(ptr %document, i32 %context, i32 %maximum, ptr %tokens, ptr %failure) {
  %ok = call i1 @SCAN@(ptr %document, i32 %context, i32 %maximum, ptr %tokens, ptr %failure)
  %status = zext i1 %ok to i32
  ret i32 %status
}
define i32 @scanner_envelope(ptr %document, i32 %extension, ptr %metadata, ptr %failure) {
  %ok = call i1 @ENVELOPE@(ptr %document, i32 %extension, ptr %metadata, ptr %failure)
  %status = zext i1 %ok to i32
  ret i32 %status
}
define i1 @FEED@(ptr %decoder, i8 %byte, ptr %scalar, ptr %complete) {
  call void @scanner_feed_called()
  %ok = call i1 @scanner_feed_body(ptr %decoder, i8 %byte, ptr %scalar, ptr %complete)
  ret i1 %ok
}
define i1 @BYTE@(ptr %bytes, i32 %count, i32 %offset, ptr %value) {
  %ok = call i1 @scanner_byte_body(ptr %bytes, i32 %count, i32 %offset, ptr %value)
  br i1 %ok, label %read, label %done
read:
  %loaded = load i32, ptr %value, align 4
  %valid = icmp sge i32 %loaded, 0
  br i1 %valid, label %observed, label %done
observed:
  call void @scanner_read_called()
  br label %done
done:
  ret i1 %ok
}
define void @RECORDCOPY@(ptr %destination, ptr %original) {
  call void @scanner_record_copy_body(ptr %destination, ptr %original)
  call void @scanner_record_copied()
  ret void
}
