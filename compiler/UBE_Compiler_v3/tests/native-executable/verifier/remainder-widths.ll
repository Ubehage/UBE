; Hand-authored host probe; the error slot simulates, but is not, UBE Err.
define i16 @remainder16(i16 %a, i16 %b, ptr %err) {
entry:
  %zero = icmp eq i16 %b, 0
  br i1 %zero, label %failure, label %check
failure:
  store i32 11, ptr %err
  ret i16 0
check:
  %minimum = icmp eq i16 %a, -32768
  %negative = icmp eq i16 %b, -1
  %exception = and i1 %minimum, %negative
  br i1 %exception, label %special, label %normal
special:
  ret i16 0
normal:
  %value = srem i16 %a, %b
  ret i16 %value
}
define i64 @remainder64(i64 %a, i64 %b, ptr %err) {
entry:
  %zero = icmp eq i64 %b, 0
  br i1 %zero, label %failure, label %check
failure:
  store i32 11, ptr %err
  ret i64 0
check:
  %minimum = icmp eq i64 %a, -9223372036854775808
  %negative = icmp eq i64 %b, -1
  %exception = and i1 %minimum, %negative
  br i1 %exception, label %special, label %normal
special:
  ret i64 0
normal:
  %value = srem i64 %a, %b
  ret i64 %value
}
define i32 @main() {
entry:
  %err = alloca i32
  store i32 73, ptr %err
  %r16 = call i16 @remainder16(i16 -32768, i16 -1, ptr %err)
  %r64 = call i64 @remainder64(i64 -9223372036854775808, i64 -1, ptr %err)
  %preserved = load i32, ptr %err
  %a = icmp eq i16 %r16, 0
  %b = icmp eq i64 %r64, 0
  %c = icmp eq i32 %preserved, 73
  %d = and i1 %a, %b
  %e = and i1 %c, %d
  %normal16 = call i16 @remainder16(i16 -17, i16 5, ptr %err)
  %normal64 = call i64 @remainder64(i64 -17, i64 5, ptr %err)
  %f = icmp eq i16 %normal16, -2
  %g = icmp eq i64 %normal64, -2
  %h = and i1 %f, %g
  %i = and i1 %e, %h
  %bad = call i16 @remainder16(i16 1, i16 0, ptr %err)
  %failed = load i32, ptr %err
  %j = icmp eq i16 %bad, 0
  %k = icmp eq i32 %failed, 11
  %l = and i1 %j, %k
  %pass = and i1 %i, %l
  %result = select i1 %pass, i32 0, i32 1
  ret i32 %result
}
