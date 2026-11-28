; Test-only observation: no graph mutation, publication, or reclamation.
define { i1, i64 } @pressure.observe(ptr %ctx) {
entry:
  %work = alloca i64, align 8
  %error = alloca i64, align 8
  %allocations = alloca i64, align 8
  %roots = alloca i64, align 8
  %owned = call i1 @ube.managed.begin(ptr %ctx, ptr %work, ptr %error)
  br i1 %owned, label %snapshot, label %failed
snapshot:
  %ok = call i1 @ube.managed.snapshot.counts(ptr %ctx, ptr %allocations, ptr %roots)
  %ended = call i1 @ube.managed.end(ptr %ctx, i64 0, i64 0)
  %valid = and i1 %ok, %ended
  br i1 %valid, label %read, label %failed
read:
  %a = load i64, ptr %allocations, align 8
  %r = load i64, ptr %roots, align 8
  %bounded = icmp ult i64 %r, 1000
  br i1 %bounded, label %pack, label %failed
pack:
  %scaled = mul i64 %a, 1000
  %value = add i64 %scaled, %r
  %result = insertvalue { i1, i64 } {i1 true, i64 0}, i64 %value, 1
  ret { i1, i64 } %result
failed:
  store atomic i64 5, ptr %ctx monotonic, align 8
  ret { i1, i64 } zeroinitializer
}
