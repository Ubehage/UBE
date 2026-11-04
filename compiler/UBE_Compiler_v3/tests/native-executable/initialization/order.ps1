# Standalone schedule emitter with actual shared require/state support; C
# initializers independently observe order, skip-completed and failure cutoff.
foreach($rootCount in 1..3) {
 $order=Join-Path $run ('stage'+$stage+'-order-'+$rootCount+'.ll')
 [IO.File]::Move((Join-Path $run ('initialization-order-'+$rootCount+'.ll')),$order)
 $orderSource=[IO.File]::ReadAllText($order);$schedulePart=$orderSource.Substring(0,$orderSource.IndexOf('@ube.module.initializers'))
 $scheduleIds=[regex]::Matches($schedulePart,'(?m)^define ').Count+[regex]::Matches($schedulePart,'(?m)^\w+:$').Count+[regex]::Matches($schedulePart,'(?m)^  %\w+ =').Count
 if($scheduleIds -ne 9){throw 'Schedule target identity inventory differs from charge'}
 foreach($orderOptimization in @('O0','O2')) {
  $inlined=$order+'-'+$orderOptimization+'-inline.ll'
  $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$orderOptimization),'-S','-emit-llvm',$order,'-o',$inlined)
  if([IO.File]::ReadAllText($inlined) -match '@ube\.(module\.(initialize|require)|stack\.admit)\('){throw 'Schedule/support retained an additional call frame'}
  $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Schedule and admission helpers inline with exact target identity inventory';rootCount=$rootCount;optimization=$orderOptimization;passed=$true})
  foreach($orderMode in 0..3) {
   $orderExe=$order+'-'+$orderOptimization+'-'+$orderMode+'.exe'
   $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$orderOptimization),'-std=c17','-Wall','-Wextra','-Werror',('-DROOT_COUNT='+$rootCount),('-DMODE='+$orderMode),'-I',$root,$order,$data,(Join-Path $PSScriptRoot 'order-observer.c'),'-o',$orderExe)
   $r=Run $orderExe @();if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Schedule native oracle failed'}
   $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Dependency then root manifest order, already/early-completed module skip and failed requirement cutoff';rootCount=$rootCount;optimization=$orderOptimization;mode=$orderMode;passed=$true})
  }
 }
}
$orderText=[IO.File]::ReadAllText((Join-Path $run ('stage'+$stage+'-order-2.ll')))
foreach($orderControl in @('order','failure')) {
 $mode=0
 if($orderControl -eq 'order'){
  $changed=[regex]::Replace($orderText,'@ube\.module\.require\(i32 ([0-2]), i32 -1\)',{param($m) '@ube.module.require(i32 '+(([int]$m.Groups[1].Value+1)%3)+', i32 -1)'})
 }else{$changed=[regex]::Replace($orderText,'br i1 %initialized[0-9]+,','br i1 true,');$mode=2}
 if($changed -ceq $orderText){throw 'Schedule negative-control target missing'}
 $wrong=Join-Path $run ('stage'+$stage+'-wrong-schedule-'+$orderControl+'.ll');[IO.File]::WriteAllText($wrong,$changed,$utf8);$wrongExe=$wrong+'.exe'
 $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-DROOT_COUNT=2',('-DMODE='+$mode),'-I',$root,$wrong,$data,(Join-Path $PSScriptRoot 'order-observer.c'),'-o',$wrongExe)
 $r=Invoke-BoundedProcess $wrongExe @() $run 180;$commands+=@($r)
 if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -notmatch 'schedule oracle'){throw 'Schedule corruption was not rejected'}
 $checks+=@([pscustomobject]@{stage=$stage+1;assertion=('Schedule negative control '+$orderControl);passed=$true;error=$r.stderr})
}
