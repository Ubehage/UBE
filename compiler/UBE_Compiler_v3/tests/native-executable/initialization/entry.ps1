$adapterFile=Join-Path $run ('stage'+$stage+'-process-adapter.ll')
[IO.File]::Move((Join-Path $run 'process-adapter.ll'),$adapterFile)
$adapterText=[IO.File]::ReadAllText($adapterFile)
$adapterIds=[regex]::Matches($adapterText,'(?m)^(?:declare|define) ').Count+[regex]::Matches($adapterText,'(?m)^\w+:$').Count+[regex]::Matches($adapterText,'(?m)^  %\w+ =').Count
if($adapterIds -ne 4){throw 'Process adapter identity inventory differs from charge'}
foreach($mainKind in 5..6) {foreach($rootCount in @(1,3)) {
 $entry=Join-Path $run ('stage'+$stage+'-entry-'+$mainKind+'-'+$rootCount+'.ll')
 [IO.File]::Move((Join-Path $run ('entry-'+$mainKind+'-'+$rootCount+'.ll')),$entry)
 if($stage -eq 1){$before=Join-Path $run ('stage0-entry-'+$mainKind+'-'+$rootCount+'.ll');if((Get-ArtifactIdentity $before).sha256 -cne (Get-ArtifactIdentity $entry).sha256){throw 'Program entry differs across stages'}}
 $entryText=[IO.File]::ReadAllText($entry);$programPart=$entryText.Substring(0,$entryText.IndexOf('define internal i1 @ube.module.initialize'))
 # Main's already prepared identity is referenced, not allocated a second time.
 $entryIds=[regex]::Matches($programPart,'(?m)^(?:declare|define) ').Count+[regex]::Matches($programPart,'(?m)^\w+:$').Count+[regex]::Matches($programPart,'(?m)^  %\w+ =').Count-1
 if($entryIds -ne (14+[int]($mainKind -eq 6))){throw 'Program entry identity inventory differs from charge'}
 foreach($optimization in @('O0','O2')) {
  $inlined=$entry+'-'+$optimization+'-inline.ll';$null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-S','-emit-llvm',$entry,'-o',$inlined)
  if([IO.File]::ReadAllText($inlined) -match '@ube\.(module\.(initialize|require)|stack\.admit)\('){throw 'Program startup support retained an additional call frame'}
  foreach($mode in 0..5) {
   $options=@('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror',('-DMAIN_KIND='+$mainKind),('-DROOT_COUNT='+$rootCount),('-DMODE='+$mode),'-I',$root,$entry,$data,(Join-Path $PSScriptRoot 'entry-observer.c'))
   $observed=$entry+'-'+$optimization+'-'+$mode+'-observed.exe';$null=Run $selection.clang.path ($options+@('-o',$observed));$r=Run $observed @()
   $expectedResult=0;if($mainKind -eq 6){$expectedResult=-2147483601};$expectedError=77
   if($mode -in @(1,2,3)){$expectedResult=1};if($mode -eq 4){$expectedResult=0};if($mode -in @(3,4)){$expectedError=28};if($mode -eq 5){$expectedError=11}
   if($r.stderr -cne '' -or $r.stdout -cne ("result`t"+$expectedResult+"`terr`t"+$expectedError+"`n")){throw 'Entry observer tuple differs'}
   $ordinary=$entry+'-'+$optimization+'-'+$mode+'-ordinary.exe';$null=Run $selection.clang.path ($options+@('-DORDINARY_ADAPTER=1',$adapterFile,'-o',$ordinary))
   $r=Invoke-BoundedProcess $ordinary @() $run 180;$commands+=@($r)
   if($r.timedOut -or $r.exit -ne $expectedResult -or $r.stdout -cne '' -or $r.stderr -cne ''){throw ('Ordinary process exit differs: '+($r|ConvertTo-Json -Compress))}
   $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Identical common startup through ordinary/observed adapter; Sub/Long Main, no entry on setup failure, initializer refusal, Main refusal and recoverable initializer Err';mainKind=$mainKind;rootCount=$rootCount;optimization=$optimization;mode=$mode;passed=$true;processResult=$r.exit})
  }
 }
}}
$original=[IO.File]::ReadAllText((Join-Path $run ('stage'+$stage+'-entry-6-1.ll')))
foreach($control in @('setup','initialization','main','skip','error')) {
 $mode=1;$expectedExit=98
 switch($control) {
  'setup' {$changed=$original.Replace('br i1 %ready,','br i1 true,')}
  'initialization' {$changed=$original.Replace('br i1 %initialized,','br i1 true,');$mode=3}
  'main' {$changed=$original.Replace('br i1 %admitted,','br i1 true,');$mode=4;$expectedExit=1}
  'skip' {$changed=$original.Replace('%initialized = call i1 @ube.module.initialize()','%initialized = icmp eq i32 0, 0');$mode=0}
  'error' {$changed=$original.Replace('call void @ube_err_set_stack_exhausted()','; omitted error');$mode=4;$expectedExit=1}
 }
 if($changed -ceq $original){throw 'Entry control target missing'}
 $wrong=Join-Path $run ('stage'+$stage+'-wrong-entry-'+$control+'.ll');[IO.File]::WriteAllText($wrong,$changed,$utf8);$wrongExe=$wrong+'.exe'
 $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17',('-DMODE='+$mode),'-I',$root,$wrong,$data,(Join-Path $PSScriptRoot 'entry-observer.c'),'-o',$wrongExe)
 $r=Invoke-BoundedProcess $wrongExe @() $run 180;$commands+=@($r)
 if($r.timedOut -or $r.exit -ne $expectedExit -or $r.stdout -cne '' -or ($expectedExit -eq 1 -and $r.stderr -notmatch 'entry oracle')){throw 'Entry corruption was not rejected'}
 $checks+=@([pscustomobject]@{stage=$stage+1;assertion=('Entry negative control '+$control);passed=$true;exit=$r.exit;error=$r.stderr})
}
