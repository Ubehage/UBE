; Native target feasibility fixture for UBE's approved failure-flow contract.
; Hand-authored test IR, not compiler output or a frozen production ABI.
; true means success; only success publishes an ordinary result.
target triple = "x86_64-pc-windows-msvc"

@failure_input = global i32 1
@after_raise = global i32 0
@operand_calls = global i32 0
@cleaned = global i32 0
@cleanup_after = global i32 0

; Returns a valid zero while preserving the caller's previous error record.
define internal i1 @successful_zero(ptr %err, ptr %result) noinline {
  store i32 0, ptr %result
  ret i1 true
}

; Models a runtime-dependent Err.Raise path with no result publication.
define internal i1 @failing_function(ptr %err, ptr %result) noinline {
  %input = load volatile i32, ptr @failure_input
  %fail = icmp ne i32 %input, 0
  br i1 %fail, label %raise, label %normal
raise:
  store i32 5, ptr %err
  ret i1 false ; RAISE_RETURN
normal:
  store volatile i32 1, ptr @after_raise
  store i32 100, ptr %result
  ret i1 true
}

; Records evaluation of the operand following the potentially failing call.
define internal i32 @following_operand() noinline {
  %old = load volatile i32, ptr @operand_calls
  %new = add i32 %old, 1
  store volatile i32 %new, ptr @operand_calls
  ret i32 10
}

; Models user cleanup before Raise; cleanup after Raise is on the normal path.
define internal i1 @cleanup_then_raise(ptr %err) noinline {
  %input = load volatile i32, ptr @failure_input
  %fail = icmp ne i32 %input, 0
  br i1 %fail, label %release_and_raise, label %normal
release_and_raise:
  store volatile i32 1, ptr @cleaned
  store i32 5, ptr %err
  ret i1 false
normal:
  store volatile i32 1, ptr @cleanup_after
  ret i1 true
}

; A completed ByRef mutation is not rolled back when the procedure then raises.
define internal i1 @write_then_raise(ptr %err, ptr %value) noinline {
  store i32 17, ptr %value
  store i32 5, ptr %err
  ret i1 false
}

; Bit 1: successful zero is usable despite a stale nonzero error.
define internal i32 @test_success_zero() {
  %err = alloca i32
  %result = alloca i32
  store i32 5, ptr %err
  store i32 77, ptr %result
  %ok = call i1 @successful_zero(ptr %err, ptr %result)
  %value = load i32, ptr %result
  %number = load i32, ptr %err
  %zero = icmp eq i32 %value, 0
  %sticky = icmp eq i32 %number, 5
  %both = and i1 %zero, %sticky
  %pass = and i1 %ok, %both
  %exit = select i1 %pass, i32 0, i32 1
  ret i32 %exit
}

; Bit 2: Raise returns FAIL, publishes no result and executes no following code.
define internal i32 @test_raise_exit() {
  %err = alloca i32
  %result = alloca i32
  store i32 0, ptr %err
  store i32 88, ptr %result
  store volatile i32 0, ptr @after_raise
  %ok = call i1 @failing_function(ptr %err, ptr %result)
  %failed = xor i1 %ok, true
  %value = load i32, ptr %result
  %number = load i32, ptr %err
  %after = load volatile i32, ptr @after_raise
  %unpublished = icmp eq i32 %value, 88
  %recorded = icmp eq i32 %number, 5
  %stopped = icmp eq i32 %after, 0
  %a = and i1 %failed, %unpublished
  %b = and i1 %recorded, %stopped
  %pass = and i1 %a, %b
  %exit = select i1 %pass, i32 0, i32 2
  ret i32 %exit
}

; Bit 4: default failure skips the remaining operand and assignment, then continues.
define internal i32 @test_default_continuation() {
  %err = alloca i32
  %result = alloca i32
  %destination = alloca i32
  store i32 0, ptr %err
  store i32 99, ptr %result
  store i32 25, ptr %destination
  store volatile i32 0, ptr @operand_calls
  %ok = call i1 @failing_function(ptr %err, ptr %result)
  br i1 %ok, label %commit, label %next_statement ; DEFAULT_BRANCH
commit:
  %left = load i32, ptr %result
  %right = call i32 @following_operand()
  %sum = add i32 %left, %right
  store i32 %sum, ptr %destination
  br label %next_statement
next_statement:
  %value = load i32, ptr %destination
  %calls = load volatile i32, ptr @operand_calls
  %number = load i32, ptr %err
  %unchanged = icmp eq i32 %value, 25
  %skipped = icmp eq i32 %calls, 0
  %recorded = icmp eq i32 %number, 5
  %a = and i1 %unchanged, %skipped
  %pass = and i1 %a, %recorded
  %exit = select i1 %pass, i32 0, i32 4
  ret i32 %exit
}

; Bit 8: an enabled caller handler receives the failure instead of normal continuation.
define internal i32 @test_caller_handler() {
  %err = alloca i32
  %result = alloca i32
  store i32 0, ptr %err
  store i32 99, ptr %result
  %ok = call i1 @failing_function(ptr %err, ptr %result)
  br i1 %ok, label %normal, label %handler
normal:
  ret i32 8
handler:
  %number = load i32, ptr %err
  %value = load i32, ptr %result
  %recorded = icmp eq i32 %number, 5
  %unpublished = icmp eq i32 %value, 99
  %pass = and i1 %recorded, %unpublished
  %exit = select i1 %pass, i32 0, i32 8
  ret i32 %exit
}

; Bit 16: a second failure while the handler is active skips only that statement.
define internal i32 @test_active_handler() {
  %err = alloca i32
  %result = alloca i32
  %entries = alloca i32
  %destination = alloca i32
  store i32 0, ptr %err
  store i32 99, ptr %result
  store i32 0, ptr %entries
  store i32 25, ptr %destination
  %first = call i1 @failing_function(ptr %err, ptr %result)
  br i1 %first, label %unexpected_success, label %handler
handler:
  %old = load i32, ptr %entries
  %new = add i32 %old, 1
  store i32 %new, ptr %entries
  ; The guard turns accidental reentry into a bounded test failure.
  %once = icmp eq i32 %new, 1
  br i1 %once, label %handler_call, label %unexpected_success
handler_call:
  %second = call i1 @failing_function(ptr %err, ptr %result)
  br i1 %second, label %commit, label %handler_next
commit:
  %value = load i32, ptr %result
  store i32 %value, ptr %destination
  br label %handler_next
handler_next:
  %count = load i32, ptr %entries
  %final = load i32, ptr %destination
  %number = load i32, ptr %err
  %single = icmp eq i32 %count, 1
  %unchanged = icmp eq i32 %final, 25
  %recorded = icmp eq i32 %number, 5
  %a = and i1 %single, %unchanged
  %pass = and i1 %a, %recorded
  %exit = select i1 %pass, i32 0, i32 16
  ret i32 %exit
unexpected_success:
  ret i32 16
}

; Bit 32: caller sees explicit cleanup before Raise, never cleanup after it.
define internal i32 @test_cleanup_order() {
  %err = alloca i32
  store i32 0, ptr %err
  store volatile i32 0, ptr @cleaned
  store volatile i32 0, ptr @cleanup_after
  %ok = call i1 @cleanup_then_raise(ptr %err)
  %before = load volatile i32, ptr @cleaned
  %after = load volatile i32, ptr @cleanup_after
  %failed = xor i1 %ok, true
  %released = icmp eq i32 %before, 1
  %stopped = icmp eq i32 %after, 0
  %a = and i1 %failed, %released
  %pass = and i1 %a, %stopped
  %exit = select i1 %pass, i32 0, i32 32
  ret i32 %exit
}

; Bit 64: earlier ByRef side effects survive failure.
define internal i32 @test_byref_preservation() {
  %err = alloca i32
  %value = alloca i32
  store i32 0, ptr %err
  store i32 1, ptr %value
  %ok = call i1 @write_then_raise(ptr %err, ptr %value)
  %final = load i32, ptr %value
  %failed = xor i1 %ok, true
  %retained = icmp eq i32 %final, 17
  %pass = and i1 %failed, %retained
  %exit = select i1 %pass, i32 0, i32 64
  ret i32 %exit
}

; Bit 128: equal consecutive error numbers still represent two fresh failures.
define internal i32 @test_repeated_error() {
  %err = alloca i32
  %result = alloca i32
  store i32 5, ptr %err
  store i32 99, ptr %result
  %first = call i1 @failing_function(ptr %err, ptr %result)
  %number1 = load i32, ptr %err
  %second = call i1 @failing_function(ptr %err, ptr %result)
  %number2 = load i32, ptr %err
  %either_success = or i1 %first, %second
  %both_failed = xor i1 %either_success, true
  %same = icmp eq i32 %number1, %number2
  %five = icmp eq i32 %number2, 5
  %a = and i1 %same, %five
  %pass = and i1 %a, %both_failed
  %exit = select i1 %pass, i32 0, i32 128
  ret i32 %exit
}

; Returns a bit mask of failed behavioral assertions to the bounded runner.
define i32 @main() {
  %a = call i32 @test_success_zero()
  %b = call i32 @test_raise_exit()
  %c = call i32 @test_default_continuation()
  %d = call i32 @test_caller_handler()
  %e = call i32 @test_active_handler()
  %f = call i32 @test_cleanup_order()
  %g = call i32 @test_byref_preservation()
  %h = call i32 @test_repeated_error()
  %ab = or i32 %a, %b
  %cd = or i32 %c, %d
  %ef = or i32 %e, %f
  %gh = or i32 %g, %h
  %abcd = or i32 %ab, %cd
  %efgh = or i32 %ef, %gh
  %all = or i32 %abcd, %efgh
  ret i32 %all
}
