@input8 = global i8 -1
@input16 = global i16 -32768
@input32 = global i32 2147483647
@size8 = global i64 ptrtoint (ptr getelementptr ({ i8 }, ptr null, i32 1) to i64)
@size16 = global i64 ptrtoint (ptr getelementptr ({ i16 }, ptr null, i32 1) to i64)
@size32 = global i64 ptrtoint (ptr getelementptr ({ i32 }, ptr null, i32 1) to i64)
@align8 = global i64 ptrtoint (ptr getelementptr ({ i8, { i8 } }, ptr null, i32 0, i32 1) to i64)
@align16 = global i64 ptrtoint (ptr getelementptr ({ i8, { i16 } }, ptr null, i32 0, i32 1) to i64)
@align32 = global i64 ptrtoint (ptr getelementptr ({ i8, { i32 } }, ptr null, i32 0, i32 1) to i64)
declare { i8 } @echo8({ i8 })
declare { i16 } @echo16({ i16 })
declare { i32 } @echo32({ i32 })
declare { i8 } @copy8({ i8 })
declare { i16 } @copy16({ i16 })
declare { i32 } @copy32({ i32 })
declare void @replace8(ptr, i8)
declare void @replace16(ptr, i16)
declare void @replace32(ptr, i32)
define i32 @main() {
  %p8 = alloca { i8 }
  %p16 = alloca { i16 }
  %p32 = alloca { i32 }
  %x8 = load volatile i8, ptr @input8
  %x16 = load volatile i16, ptr @input16
  %x32 = load volatile i32, ptr @input32
  store i8 %x8, ptr %p8
  store i16 %x16, ptr %p16
  store i32 %x32, ptr %p32
  %v8 = insertvalue { i8 } poison, i8 %x8, 0
  %v16 = insertvalue { i16 } poison, i16 %x16, 0
  %v32 = insertvalue { i32 } poison, i32 %x32, 0
  %r8 = call { i8 } @echo8({ i8 } %v8)
  %r16 = call { i16 } @echo16({ i16 } %v16)
  %r32 = call { i32 } @echo32({ i32 } %v32)
  %o8 = extractvalue { i8 } %r8, 0
  %o16 = extractvalue { i16 } %r16, 0
  %o32 = extractvalue { i32 } %r32, 0
  %cv8 = call { i8 } @copy8({ i8 } %v8)
  %cv16 = call { i16 } @copy16({ i16 } %v16)
  %cv32 = call { i32 } @copy32({ i32 } %v32)
  %co8 = extractvalue { i8 } %cv8, 0
  %co16 = extractvalue { i16 } %cv16, 0
  %co32 = extractvalue { i32 } %cv32, 0
  %before8 = load volatile i8, ptr %p8
  %before16 = load volatile i16, ptr %p16
  %before32 = load volatile i32, ptr %p32
  call void @replace8(ptr %p8, i8 0)
  call void @replace16(ptr %p16, i16 12345)
  call void @replace32(ptr %p32, i32 -2147483648)
  %n8 = load i8, ptr %p8
  %n16 = load i16, ptr %p16
  %n32 = load i32, ptr %p32
  %a = icmp eq i8 %o8, -1
  %b = icmp eq i16 %o16, -32768
  %c = icmp eq i32 %o32, 2147483647
  %d = icmp eq i8 %n8, 0
  %e = icmp eq i16 %n16, 12345
  %f = icmp eq i32 %n32, -2147483648
  %ab = and i1 %a, %b
  %cd = and i1 %c, %d
  %ef = and i1 %e, %f
  %abcd = and i1 %ab, %cd
  %all = and i1 %abcd, %ef
  %ca = icmp eq i8 %co8, 0
  %cb = icmp eq i16 %co16, 12345
  %cc = icmp eq i32 %co32, -2147483648
  %cd8 = icmp eq i8 %before8, -1
  %cd16 = icmp eq i16 %before16, -32768
  %cd32 = icmp eq i32 %before32, 2147483647
  %copyab = and i1 %ca, %cb
  %copycd = and i1 %cc, %cd8
  %copyef = and i1 %cd16, %cd32
  %copyabcd = and i1 %copyab, %copycd
  %copyall = and i1 %copyabcd, %copyef
  %s8 = load volatile i64, ptr @size8
  %s16 = load volatile i64, ptr @size16
  %s32 = load volatile i64, ptr @size32
  %a8 = load volatile i64, ptr @align8
  %a16 = load volatile i64, ptr @align16
  %a32 = load volatile i64, ptr @align32
  %ls8 = icmp eq i64 %s8, 1
  %ls16 = icmp eq i64 %s16, 2
  %ls32 = icmp eq i64 %s32, 4
  %la8 = icmp eq i64 %a8, 1
  %la16 = icmp eq i64 %a16, 2
  %la32 = icmp eq i64 %a32, 4
  %sizes1 = and i1 %ls8, %ls16
  %sizes2 = and i1 %ls32, %la8
  %sizes3 = and i1 %la16, %la32
  %sizes4 = and i1 %sizes1, %sizes2
  %layout = and i1 %sizes4, %sizes3
  %withcopy = and i1 %all, %copyall
  %passed = and i1 %withcopy, %layout
  %result = select i1 %passed, i32 0, i32 1
  ret i32 %result
}
