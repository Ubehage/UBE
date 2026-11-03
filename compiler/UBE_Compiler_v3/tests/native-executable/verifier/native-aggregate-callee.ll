; Hand-authored LLVM only: these are not UBE-generated bodies.
define { i8 } @echo8({ i8 } %value) noinline { ret { i8 } %value }
define { i16 } @echo16({ i16 } %value) noinline { ret { i16 } %value }
define { i32 } @echo32({ i32 } %value) noinline { ret { i32 } %value }
define { i8 } @copy8({ i8 } %value) noinline {
  %slot = alloca { i8 }
  store { i8 } %value, ptr %slot
  store i8 0, ptr %slot
  %result = load { i8 }, ptr %slot
  ret { i8 } %result
}
define { i16 } @copy16({ i16 } %value) noinline {
  %slot = alloca { i16 }
  store { i16 } %value, ptr %slot
  store i16 12345, ptr %slot
  %result = load { i16 }, ptr %slot
  ret { i16 } %result
}
define { i32 } @copy32({ i32 } %value) noinline {
  %slot = alloca { i32 }
  store { i32 } %value, ptr %slot
  store i32 -2147483648, ptr %slot
  %result = load { i32 }, ptr %slot
  ret { i32 } %result
}
define void @replace8(ptr %value, i8 %new) noinline { store i8 %new, ptr %value ret void }
define void @replace16(ptr %value, i16 %new) noinline { store i16 %new, ptr %value ret void }
define void @replace32(ptr %value, i32 %new) noinline { store i32 %new, ptr %value ret void }
