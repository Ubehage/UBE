; Hand-authored host control, not UBE-generated code.
@first = global i32 0
@second = global i32 0
define void @library_init(i1 %reverse) noinline {
entry:
  br i1 %reverse, label %second_first, label %first_first
first_first:
  store volatile i32 3, ptr @first
  br label %initialize_second
second_first:
  br label %initialize_second
initialize_second:
  %old = load volatile i32, ptr @first
  %new = add i32 %old, 4
  store volatile i32 %new, ptr @second
  br i1 %reverse, label %finish_first, label %done
finish_first:
  store volatile i32 3, ptr @first
  br label %done
done:
  ret void
}
