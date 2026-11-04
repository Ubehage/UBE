# Compile each complete generated module to an independent object, then link
# the same objects with the independent value/Err/initialization observers.
foreach($reference in 0..1) {
 foreach($optimization in @('O0','O2')) {
  $objects=@()
  foreach($source in 0..3) {
   $input=Join-Path $directory ('module-'+$reference+'-'+$source+'.ll')
   $object=Join-Path $directory ('module-'+$reference+'-'+$source+'-'+$optimization+'.o')
   $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-c',$input,'-o',$object)
   $objects+=$object
  }
  foreach($mode in 0..2) {
   $exe=Join-Path $directory ('modules-'+$reference+'-'+$optimization+'-'+$mode+'.exe')
   $null=Run $selection.clang.path (@('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror',('-DREFERENCE='+$reference),('-DSCHEDULE_MODE='+$mode),'-I',$root,'-I',$directory)+$objects+@((Join-Path $directory 'guard-data.ll'),(Join-Path $PSScriptRoot 'schedule-observer.c'),'-o',$exe))
   $r=Run $exe @() 180 $directory
   if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Separate module initialization oracle failed'}
   $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Production per-module imports/definitions linked as separate objects; normal, completed-dependency and failure schedule';reference=$reference;optimization=$optimization;mode=$mode;passed=$true})
  }
  if($reference -eq 0) {
   foreach($mode in 0..2) {
    $exe=Join-Path $directory ('module-guards-'+$optimization+'-'+$mode+'.exe')
    $null=Run $selection.clang.path (@('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror',('-DGUARD_MODE='+$mode),'-I',$root,'-I',$directory)+$objects+@((Join-Path $directory 'guard-data.ll'),(Join-Path $PSScriptRoot 'guard-observer.c'),'-o',$exe))
    $r=Invoke-BoundedProcess $exe @() $directory 180;$commands+=@($r);$expected=0;if($mode -eq 2){$expected=97}
    if($r.timedOut -or $r.exit -ne $expected -or $r.stdout -cne '' -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
    $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Separate module objects preserve cross-module scalar/native calls, ByRef owner ABI, unused forwarding and failure unwind';optimization=$optimization;mode=$mode;passed=$true})
   }
  }
 }
}
