; argc 1 = agreed order, argc 2 = reverse library declarations,
; argc 3 = executable initializes before library. Test-only controls.
@second = external global i32
@result = global i32 0
declare void @library_init(i1)
define void @app_init() noinline {
  %value = load volatile i32, ptr @second
  %new = add i32 %value, 1
  store volatile i32 %new, ptr @result
  ret void
}
define i32 @main(i32 %argc, ptr %argv) {
  %rootfirst = icmp eq i32 %argc, 3
  br i1 %rootfirst, label %wrong_root_order, label %library_first
wrong_root_order:
  call void @app_init()
  call void @library_init(i1 false)
  br label %done
library_first:
  %reverse = icmp eq i32 %argc, 2
  call void @library_init(i1 %reverse)
  call void @app_init()
  br label %done
done:
  %exit = load volatile i32, ptr @result
  ret i32 %exit
}
