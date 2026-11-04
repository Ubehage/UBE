$platform=Join-Path $run ('stage'+$stage+'-platform.ll')
[IO.File]::Move((Join-Path $run 'platform.ll'),$platform)
if($stage -eq 1 -and (Get-ArtifactIdentity $platform).sha256 -cne (Get-ArtifactIdentity (Join-Path $run 'stage0-platform.ll')).sha256){throw 'Platform support differs across bootstrap stages'}
$platformText=[IO.File]::ReadAllText($platform)
$platformIds=[regex]::Matches($platformText,'(?m)^@[^ ]+ =').Count+[regex]::Matches($platformText,'(?m)^(?:declare|define) ').Count+[regex]::Matches($platformText,'(?m)^\w+:$').Count+[regex]::Matches($platformText,'(?m)^  %\w+ =').Count+2
if($platformIds -ne 103){throw 'Platform identity inventory differs from charge'}
$synthetic=$platform+'-synthetic.ll'
$syntheticText=$platformText.Replace('declare dllimport i64 @VirtualQuery','declare i64 @platform_query').Replace('call i64 @VirtualQuery','call i64 @platform_query')
if($syntheticText -ceq $platformText -or $syntheticText -match '@VirtualQuery'){throw 'Platform query seam was not isolated'}
[IO.File]::WriteAllText($synthetic,$syntheticText,$utf8)
$controlled=$platform+'-calls.ll';$controlledText=$platformText
foreach($pair in @(@('TerminateProcess','platform_terminate'),@('ExitProcess','platform_exit'),@('Sleep','platform_sleep'))){$controlledText=$controlledText.Replace('@'+$pair[0]+'(','@'+$pair[1]+'(')}
$controlledText=$controlledText.Replace('declare dllimport i32 @platform_terminate','declare i32 @platform_terminate').Replace('declare dllimport void @platform_','declare void @platform_')
[IO.File]::WriteAllText($controlled,$controlledText,$utf8)
$observer=Join-Path $PSScriptRoot 'platform-observer.c'
$nm=Join-Path (Split-Path $selection.clang.path -Parent) 'llvm-nm.exe';$inputs+=Get-ArtifactIdentity $nm
foreach($optimization in @('O0','O2')) {foreach($debugMode in @('None','Full')) {
 $options=@('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-fno-emulated-tls','-std=c17','-Wall','-Wextra','-Werror','-I',$root)
 if($debugMode -eq 'Full'){$options+=@('-g','-gdwarf-4')}else{$options+='-g0'}
 $prefix=$platform+'-'+$optimization+'-'+$debugMode
 $objectOptions=@('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-Werror')
 if($debugMode -eq 'Full'){$objectOptions+=@('-g','-gdwarf-4')}else{$objectOptions+='-g0'}
 $object=$prefix+'.o';$null=Run $selection.clang.path ($objectOptions+@('-fstack-usage','-c',$platform,'-o',$object))
 $symbols=Run $nm @('--undefined-only',$object)
 $undefined=@(($symbols.stdout -split '\r?\n')|Where-Object {$_}|ForEach-Object {($_ -split '\s+')[-1]})
 $expected=@('__imp_ExitProcess','__imp_Sleep','__imp_TerminateProcess','__imp_VirtualQuery','_tls_index','ube.stack.reserve')
 if(@(Compare-Object ($undefined|Sort-Object) ($expected|Sort-Object)).Count){throw ('Unexpected platform object dependencies: '+$symbols.stdout)}
 $stackUsage=[IO.Path]::ChangeExtension($object,'.su');if(-not [IO.File]::Exists($stackUsage)){throw 'Platform stack report missing'}
 $stackRows=@([IO.File]::ReadAllLines($stackUsage));if($stackRows.Count -ne 3 -or @($stackRows|Where-Object {$_ -notmatch '\t[0-9]+\tstatic$'}).Count){throw 'Platform has unknown or dynamic fixed frame usage'}
 $checks+=@([pscustomobject]@{assertion='Platform native TLS/import inventory and fixed compiler frame reports';stage=$stage+1;optimization=$optimization;debugMode=$debugMode;passed=$true;object=(Get-ArtifactIdentity $object);stackUsage=(Get-ArtifactIdentity $stackUsage);rows=$stackRows;limitation='Does not derive the platform API closure or recovery reserve'})
 foreach($reserve in @(0,256,2049)) {
  $exe=$prefix+'-synthetic-'+$reserve+'.exe';$null=Run $selection.clang.path ($options+@('-DSYNTHETIC',('-DRESERVE='+$reserve),$synthetic,$observer,'-o',$exe))
  $r=Run $exe @();if($r.stderr -cne '' -or $r.stdout -notmatch '^PASS platform [1-9][0-9]* assertions\n$'){throw 'Synthetic platform oracle mismatch'}
  $checks+=@([pscustomobject]@{assertion='Synthetic query responses: extent, progress, ownership, page states/protection, capacity and atomic floor publication';stage=$stage+1;optimization=$optimization;debugMode=$debugMode;reserve=$reserve;passed=$true;output=$r.stdout})
 }
 $actual=$prefix+'-actual.exe';$null=Run $selection.clang.path ($options+@($object,$observer,'-o',$actual));$r=Run $actual @()
 if($r.stderr -cne '' -or $r.stdout -notmatch '^PASS platform [1-9][0-9]* assertions\n$'){throw 'Actual Windows memory oracle mismatch'}
 $checks+=@([pscustomobject]@{assertion='Actual stack floor agrees with independent backward page oracle; fragmented allocation, guard preservation, exact/insufficient capacity, inaccessible suffix and Err preservation';stage=$stage+1;optimization=$optimization;debugMode=$debugMode;passed=$true;output=$r.stdout})
 $r=Invoke-BoundedProcess $actual @('fatal') $run 10;$commands+=@($r);if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -cne ''){throw 'Real fatal disposition mismatch'}
 $r=Invoke-BoundedProcess $actual @('wait') $run 1;$commands+=@($r);if(-not $r.timedOut -or $r.stdout -cne "waiting`n" -or $r.stderr -cne ''){throw 'Real non-alertable wait did not remain blocked'}
 $calls=$prefix+'-calls.exe';$null=Run $selection.clang.path ($options+@('-DCONTROL_CALLS',$controlled,$observer,'-o',$calls))
 foreach($mode in @('fatal','wait')){$r=Invoke-BoundedProcess $calls @($mode) $run 10;$commands+=@($r);$exit=91;$stdout='';if($mode -eq 'wait'){$exit=92;$stdout="waiting`n"};if($r.timedOut -or $r.exit -ne $exit -or $r.stdout -cne $stdout -or $r.stderr -cne ''){throw 'Fatal fallback or repeated Sleep contract mismatch'}}
 $checks+=@([pscustomobject]@{assertion='Actual status-1 fatal and indefinite wait; controlled failed termination reaches ExitProcess and returned Sleep repeats with INFINITE';stage=$stage+1;optimization=$optimization;debugMode=$debugMode;passed=$true;limitation='Observed behavior, not an operating-system timing or stack-closure proof'})
 foreach($combination in @(@(6,1),@(5,3))) {foreach($mode in 0..4) {
  $mainKind=$combination[0];$rootCount=$combination[1]
  $entry=Join-Path $run ('stage'+$stage+'-entry-'+$mainKind+'-'+$rootCount+'.ll')
  $entryOptions=$options+@(('-DMAIN_KIND='+$mainKind),('-DROOT_COUNT='+$rootCount),('-DMODE='+$mode),$object,$entry,$data,(Join-Path $PSScriptRoot 'platform-entry-observer.c'))
  $observed=$prefix+'-entry-'+$mainKind+'-'+$mode+'.exe';$null=Run $selection.clang.path ($entryOptions+@('-o',$observed));$r=Run $observed @()
  $expectedResult=0;if($mainKind -eq 6){$expectedResult=-2147483601};if($mode -in @(1,2,3)){$expectedResult=1};if($mode -eq 4){$expectedResult=0};$expectedError=77;if($mode -ge 3){$expectedError=28}
  if($r.stderr -cne '' -or $r.stdout -cne ("result`t"+$expectedResult+"`terr`t"+$expectedError+"`n")){throw 'Actual platform entry observer tuple differs'}
  $ordinary=$observed+'-ordinary.exe';$null=Run $selection.clang.path ($entryOptions+@('-DORDINARY_ADAPTER=1',$adapterFile,'-o',$ordinary))
  $r=Invoke-BoundedProcess $ordinary @() $run 10;$commands+=@($r);if($r.timedOut -or $r.exit -ne $expectedResult -or $r.stdout -cne '' -or $r.stderr -cne ''){throw 'Actual platform ordinary entry result differs'}
  $checks+=@([pscustomobject]@{assertion='Unmodified common/ordinary entry linked to actual Windows setup, fatal and wait: success, setup/initial-capacity failure, later initializer refusal and Main refusal';stage=$stage+1;optimization=$optimization;debugMode=$debugMode;mainKind=$mainKind;rootCount=$rootCount;mode=$mode;passed=$true;limitation='Controlled frame/reserve metadata and C user bodies; no complete stack-safety claim'})
 }}
}}
foreach($control in @('guard','capacity','publication')) {
 $changed=$syntheticText
 switch($control){
  'guard' {$changed=$changed.Replace('%guard = and i32 %protect, 256','%guard = and i32 %protect, 0')}
  'capacity' {$changed=$changed.Replace('br i1 %room, label %publish, label %failed','br i1 true, label %publish, label %failed')}
  'publication' {$changed=$changed.Replace("failed:`n  ret i1 false","failed:`n  store i64 0, ptr @ube.stack.floor, align 8`n  ret i1 false")}
 }
 if($changed -ceq $syntheticText){throw 'Platform negative control target missing'}
 $wrong=$platform+'-'+$control+'.ll';[IO.File]::WriteAllText($wrong,$changed,$utf8);$exe=$wrong+'.exe'
 $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-fno-emulated-tls','-std=c17','-DSYNTHETIC','-I',$root,$wrong,$observer,'-o',$exe)
 $r=Invoke-BoundedProcess $exe @() $run 10;$commands+=@($r);if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch 'platform observer'){throw 'Platform negative control was not rejected'}
 $checks+=@([pscustomobject]@{assertion=('Platform negative control '+$control);stage=$stage+1;passed=$true;error=$r.stderr})
}
