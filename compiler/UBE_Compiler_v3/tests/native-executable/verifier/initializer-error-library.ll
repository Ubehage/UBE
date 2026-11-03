; Hand-authored host probe; these are not UBE-generated declarations.
@divisor = global i32 0
@failed = global i32 0
@later = global i32 0
declare i32 @ube_checked_div_i32(i32, i32)
declare i32 @ube_checked_add_i32(i32, i32)
define void @library_init() noinline {
  store volatile i32 0, ptr @divisor
  %d = load volatile i32, ptr @divisor
  %bad = call i32 @ube_checked_div_i32(i32 42, i32 %d)
  store volatile i32 %bad, ptr @failed
  %f = load volatile i32, ptr @failed
  %value = call i32 @ube_checked_add_i32(i32 %f, i32 7)
  store volatile i32 %value, ptr @later
  ret void
}
