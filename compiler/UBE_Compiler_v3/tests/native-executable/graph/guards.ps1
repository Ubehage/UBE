# The production helper, data and checked bodies are linked unchanged. Only
# stack metadata, direct startup invocation and the wait-entry observer are C.
foreach($reference in 0..1) {
 $bodyName='guard-bodies.ll';if($reference){$bodyName='guard-reference-bodies.ll'}
 foreach($optimization in @('O0','O2')) {
  foreach($scheduleMode in 0..2) {
   $scheduleExe=Join-Path $directory ('schedule-'+$reference+'-'+$optimization+'-'+$scheduleMode+'.exe')
   $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror',('-DREFERENCE='+$reference),('-DSCHEDULE_MODE='+$scheduleMode),'-I',$root,'-I',$directory,(Join-Path $directory $bodyName),(Join-Path $directory 'guard-data.ll'),(Join-Path $PSScriptRoot 'schedule-observer.c'),'-o',$scheduleExe)
   $r=Run $scheduleExe @() 180 $directory
   if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Checked schedule native oracle failed'}
   $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Checked package metadata, initializer schedule and completed-dependency/failure behavior';reference=$reference;optimization=$optimization;mode=$scheduleMode;passed=$true})
  }
 }
}
foreach($guardOptimization in @('O0','O2')) {
 foreach($guardMode in 0..2) {
  $guardExe=Join-Path $directory ('guards-'+$guardOptimization+'-'+$guardMode+'.exe')
  $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$guardOptimization),'-std=c17','-Wall','-Wextra','-Werror',('-DGUARD_MODE='+$guardMode),'-I',$root,'-I',$directory,(Join-Path $directory 'guard-bodies.ll'),(Join-Path $directory 'guard-data.ll'),(Join-Path $PSScriptRoot 'guard-observer.c'),'-o',$guardExe)
  $r=Invoke-BoundedProcess $guardExe @() $directory 180;$commands+=@($r)
  $expected=0;if($guardMode -eq 2){$expected=97}
  if($r.timedOut -or $r.exit -ne $expected -or $r.stdout -cne '' -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
  $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Checked foreign reads/writes/ordinary and intrinsic calls, ByRef access versus unused forwarding, failure unwind and initializer shared-state integration; controlled metadata/wait entry';optimization=$guardOptimization;mode=$guardMode;passed=$true})
 }
}
$guardOriginal=[IO.File]::ReadAllText((Join-Path $directory 'guard-bodies.ll'))
foreach($guardControl in @('access','unwind','alias')) {
 $pattern='(?m)^(  %v[0-9]+ = )call i1 @ube\.module\.require\([^\r\n]*\)';$mode=0
 if($guardControl -eq 'unwind'){$pattern='(?m)^(  %v[0-9]+ = )call i1 @ube\.module\.require\(i32 -1, i32 [0-9]+\)';$mode=1}
 if($guardControl -eq 'alias'){$pattern='(?m)^(  %v[0-9]+ = )call i1 @ube\.module\.require\(i32 %v[0-9]+, i32 [0-9]+\)'}
 $changed=[regex]::Replace($guardOriginal,$pattern,'${1}icmp eq i32 0, 0')
 if($changed -ceq $guardOriginal){throw 'Guard negative control has no target'}
 $wrong=Join-Path $directory ('wrong-guard-'+$guardControl+'.ll');[IO.File]::WriteAllText($wrong,$changed,$utf8);$wrongExe=$wrong+'.exe'
 $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17',('-DGUARD_MODE='+$mode),'-I',$root,'-I',$directory,$wrong,(Join-Path $directory 'guard-data.ll'),(Join-Path $PSScriptRoot 'guard-observer.c'),'-o',$wrongExe)
 $r=Invoke-BoundedProcess $wrongExe @() $directory 180;$commands+=@($r)
 if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -notmatch 'guard oracle'){throw 'Guard corruption was not rejected'}
 $checks+=@([pscustomobject]@{stage=$stage+1;assertion=('Guard negative control '+$guardControl);passed=$true;error=$r.stderr})
}
