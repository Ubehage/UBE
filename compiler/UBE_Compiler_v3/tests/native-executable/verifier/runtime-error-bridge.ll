; Hand-authored host probe: uses the bootstrap error store, not UBE-generated IR.
declare void @ube_err_set(i32, ptr, ptr)
define i16 @probe_remainder_i16(i16 %left, i16 %right) noinline {
entry:
  %zero = icmp eq i16 %right, 0
  br i1 %zero, label %failure, label %check
failure:
  call void @ube_err_set(i32 11, ptr null, ptr null)
  ret i16 0
check:
  %minimum = icmp eq i16 %left, -32768
  %negative = icmp eq i16 %right, -1
  %exception = and i1 %minimum, %negative
  br i1 %exception, label %special, label %ordinary
special:
  ret i16 0
ordinary:
  %result = srem i16 %left, %right
  ret i16 %result
}
define i32 @probe_remainder_i32(i32 %left, i32 %right) noinline {
entry:
  %zero = icmp eq i32 %right, 0
  br i1 %zero, label %failure, label %check
failure:
  call void @ube_err_set(i32 11, ptr null, ptr null)
  ret i32 0
check:
  %minimum = icmp eq i32 %left, -2147483648
  %negative = icmp eq i32 %right, -1
  %exception = and i1 %minimum, %negative
  br i1 %exception, label %special, label %ordinary
special:
  ret i32 0
ordinary:
  %result = srem i32 %left, %right
  ret i32 %result
}
define i64 @probe_remainder_i64(i64 %left, i64 %right) noinline {
entry:
  %zero = icmp eq i64 %right, 0
  br i1 %zero, label %failure, label %check
failure:
  call void @ube_err_set(i32 11, ptr null, ptr null)
  ret i64 0
check:
  %minimum = icmp eq i64 %left, -9223372036854775808
  %negative = icmp eq i64 %right, -1
  %exception = and i1 %minimum, %negative
  br i1 %exception, label %special, label %ordinary
special:
  ret i64 0
ordinary:
  %result = srem i64 %left, %right
  ret i64 %result
}
