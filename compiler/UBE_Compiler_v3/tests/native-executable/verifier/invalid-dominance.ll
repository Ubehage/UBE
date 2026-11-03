define i32 @sample(i1 %choose) {
entry:
  br i1 %choose, label %left, label %right
left:
  %value = add i32 1, 2
  br label %right
right:
  ret i32 %value
}
