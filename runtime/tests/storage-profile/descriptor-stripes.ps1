# Applies a test-only descriptor lock partition without changing any data layout.
function Add-DescriptorStripes([string]$IR) {
 foreach($name in @('ube.array.snapshot','ube.array.clear.locked','ube.array.install')) {
  $pattern='(?ms)^define[^\r\n]*@'+[regex]::Escape($name)+'\([^\r\n]*\{\r?\n.*?^}\r?\n'
  $found=[regex]::Matches($IR,$pattern)
  if($found.Count -ne 1){throw "Missing unique descriptor function $name"}
  $old=$found[0].Value;$new=$old
  if($name -eq 'ube.array.snapshot') {
   $new=$new.Replace('  call void @ube.program.storage.lock(ptr %program)','  call void @experiment.descriptor.lock(ptr %array)').Replace('  call void @ube.program.storage.unlock(ptr %program)','  call void @experiment.descriptor.unlock(ptr %array)')
  } elseif($name -eq 'ube.array.clear.locked') {
   $new=$new.Replace("entry:`r`n","entry:`r`n  call void @experiment.descriptor.lock(ptr %array)`r`n").Replace('  ret void',"  call void @experiment.descriptor.unlock(ptr %array)`r`n  ret void")
  } else {
   $new=$new.Replace('  call void @ube.program.storage.lock(ptr %program)',"  call void @ube.program.storage.lock(ptr %program)`r`n  call void @experiment.descriptor.lock(ptr %array)").Replace('  call void @ube.program.storage.unlock(ptr %program)',"  call void @experiment.descriptor.unlock(ptr %array)`r`n  call void @ube.program.storage.unlock(ptr %program)")
  }
  if($old -ceq $new){throw "Descriptor transformation had no effect: $name"}
  $IR=$IR.Replace($old,$new)
 }
 $support=@'
; Each stripe occupies a distinct 64-byte line. Mix stack-base and page bits,
; since independent thread frames often have identical low address offsets.
@experiment.descriptor.stripes = internal global [64 x [8 x i64]] zeroinitializer, align 64
define internal ptr @experiment.descriptor.stripe(ptr %array) {
entry:
  %address = ptrtoint ptr %array to i64
  %low = lshr i64 %address, 3
  %page = lshr i64 %address, 12
  %stack = lshr i64 %address, 16
  %region = lshr i64 %address, 22
  %high = lshr i64 %address, 32
  %a = xor i64 %low, %page
  %b = xor i64 %a, %stack
  %c = xor i64 %b, %region
  %d = xor i64 %c, %high
  %index = and i64 %d, 63
  %lock = getelementptr [64 x [8 x i64]], ptr @experiment.descriptor.stripes, i64 0, i64 %index, i64 0
  ret ptr %lock
}
define internal void @experiment.descriptor.lock(ptr %array) {
entry:
  %lock = call ptr @experiment.descriptor.stripe(ptr %array)
  br label %attempt
attempt:
  %pair = cmpxchg ptr %lock, i64 0, i64 1 acquire monotonic
  %won = extractvalue { i64, i1 } %pair, 1
  br i1 %won, label %done, label %attempt
done:
  ret void
}
define internal void @experiment.descriptor.unlock(ptr %array) {
entry:
  %lock = call ptr @experiment.descriptor.stripe(ptr %array)
  store atomic i64 0, ptr %lock release, align 8
  ret void
}
'@
 return $IR+"`r`n"+($support -replace '\r?\n',"`r`n")
}
