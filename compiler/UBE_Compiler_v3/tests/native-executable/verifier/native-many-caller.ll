@a = global i8 1
@b = global i8 2
@c = global i8 3
@d = global i8 4
@e = global i8 5
declare i32 @weighted({ i8 }, { i8 }, { i8 }, { i8 }, { i8 })
define i32 @main() {
  %a0 = load volatile i8, ptr @a
  %b0 = load volatile i8, ptr @b
  %c0 = load volatile i8, ptr @c
  %d0 = load volatile i8, ptr @d
  %e0 = load volatile i8, ptr @e
  %a1 = insertvalue { i8 } poison, i8 %a0, 0
  %b1 = insertvalue { i8 } poison, i8 %b0, 0
  %c1 = insertvalue { i8 } poison, i8 %c0, 0
  %d1 = insertvalue { i8 } poison, i8 %d0, 0
  %e1 = insertvalue { i8 } poison, i8 %e0, 0
  %sum = call i32 @weighted({ i8 } %a1, { i8 } %b1, { i8 } %c1, { i8 } %d1, { i8 } %e1)
  %ok = icmp eq i32 %sum, 55
  %exit = select i1 %ok, i32 0, i32 1
  ret i32 %exit
}
