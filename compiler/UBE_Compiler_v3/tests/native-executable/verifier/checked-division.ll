; Hand-authored target probe, not UBE-generated LLVM.
target triple = "x86_64-w64-windows-gnu"
@numerator = global i32 -2147483648
@negative_one = global i32 -1
@positive_one = global i32 1
@zero = global i32 0
@error_state = global i32 0

define i32 @checked_divide(i32 %left, i32 %right) {
entry:
  %zero_divisor = icmp eq i32 %right, 0
  %minimum = icmp eq i32 %left, -2147483648
  %negative_one = icmp eq i32 %right, -1
  %overflow = and i1 %minimum, %negative_one
  %invalid = or i1 %zero_divisor, %overflow
  br i1 %invalid, label %failure, label %success
failure:
  store i32 1, ptr @error_state
  ret i32 0
success:
  %result = sdiv i32 %left, %right
  ret i32 %result
}

; Test the selected no-error case and a contrasting test-flag case.
define i32 @guarded_remainder(i32 %left, i32 %right, i1 %minimum_error) {
entry:
  %zero_divisor = icmp eq i32 %right, 0
  br i1 %zero_divisor, label %zero_failure, label %check_minimum
zero_failure:
  store i32 1, ptr @error_state
  ret i32 0
check_minimum:
  %minimum = icmp eq i32 %left, -2147483648
  %negative_one = icmp eq i32 %right, -1
  %special = and i1 %minimum, %negative_one
  br i1 %special, label %minimum_case, label %ordinary
minimum_case:
  br i1 %minimum_error, label %record_error, label %neutral_result
record_error:
  store i32 1, ptr @error_state
  br label %neutral_result
neutral_result:
  ret i32 0
ordinary:
  %result = srem i32 %left, %right
  ret i32 %result
}

define i32 @main() {
entry:
  %n = load volatile i32, ptr @numerator
  %minus = load volatile i32, ptr @negative_one
  %plus = load volatile i32, ptr @positive_one
  %z = load volatile i32, ptr @zero
  %failed = call i32 @checked_divide(i32 %n, i32 %minus)
  %valid = call i32 @checked_divide(i32 %n, i32 %plus)
  %prior_error = load i32, ptr @error_state
  store i32 0, ptr @error_state
  %zero_failed = call i32 @checked_divide(i32 %n, i32 %z)
  %zero_error = load i32, ptr @error_state
  store i32 42, ptr @error_state
  %remainder_no_error = call i32 @guarded_remainder(i32 %n, i32 %minus, i1 false)
  %remainder_clear_state = load i32, ptr @error_state
  %remainder_error = call i32 @guarded_remainder(i32 %n, i32 %minus, i1 true)
  %remainder_error_state = load i32, ptr @error_state
  %a = icmp eq i32 %failed, 0
  %b = icmp eq i32 %valid, -2147483648
  %c = icmp eq i32 %prior_error, 1
  %d = icmp eq i32 %zero_failed, 0
  %e = icmp eq i32 %zero_error, 1
  %f = icmp eq i32 %remainder_no_error, 0
  %g = icmp eq i32 %remainder_clear_state, 42
  %h = icmp eq i32 %remainder_error, 0
  %i = icmp eq i32 %remainder_error_state, 1
  %ab = and i1 %a, %b
  %cd = and i1 %c, %d
  %abcd = and i1 %ab, %cd
  %ef = and i1 %e, %f
  %gh = and i1 %g, %h
  %efgh = and i1 %ef, %gh
  %first = and i1 %abcd, %efgh
  %all = and i1 %first, %i
  %exit = select i1 %all, i32 82, i32 99
  ret i32 %exit
}
