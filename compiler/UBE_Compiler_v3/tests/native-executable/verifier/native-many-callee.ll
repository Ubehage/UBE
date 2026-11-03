define i32 @weighted({ i8 } %a, { i8 } %b, { i8 } %c, { i8 } %d, { i8 } %e) {
  %a8 = extractvalue { i8 } %a, 0
  %b8 = extractvalue { i8 } %b, 0
  %c8 = extractvalue { i8 } %c, 0
  %d8 = extractvalue { i8 } %d, 0
  %e8 = extractvalue { i8 } %e, 0
  %aa = zext i8 %a8 to i32
  %bb = zext i8 %b8 to i32
  %cc = zext i8 %c8 to i32
  %dd = zext i8 %d8 to i32
  %ee = zext i8 %e8 to i32
  %b2 = mul i32 %bb, 2
  %c3 = mul i32 %cc, 3
  %d4 = mul i32 %dd, 4
  %e5 = mul i32 %ee, 5
  %ab = add i32 %aa, %b2
  %abc = add i32 %ab, %c3
  %abcd = add i32 %abc, %d4
  %sum = add i32 %abcd, %e5
  ret i32 %sum
}
