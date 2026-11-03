@later = external global i32
@result = global i32 0
declare i32 @ube_checked_add_i32(i32, i32)
define void @app_init() noinline {
  %value = load volatile i32, ptr @later
  %new = call i32 @ube_checked_add_i32(i32 %value, i32 1)
  store volatile i32 %new, ptr @result
  ret void
}
define i32 @app_result() noinline {
  %value = load volatile i32, ptr @result
  ret i32 %value
}
