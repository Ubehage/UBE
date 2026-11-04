foreach($reference in 0..1) {foreach($optimization in @('O0','O2')) {
 $entry=Join-Path $directory ('project-entry-'+$reference+'.ll');$object=$entry+'-'+$optimization+'.o'
 $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-c',$entry,'-o',$object)
 $objects=@($object);foreach($source in 0..2){$objects+=Join-Path $directory ('module-'+$reference+'-'+$source+'-'+$optimization+'.o')}
 foreach($mode in 0..4) {
  $options=@('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror',('-DREFERENCE='+$reference),('-DMODE='+$mode),'-I',$root,'-I',$directory)+$objects+@((Join-Path $directory 'guard-data.ll'),(Join-Path $PSScriptRoot 'entry-observer.c'))
  $observed=Join-Path $directory ('entry-'+$reference+'-'+$optimization+'-'+$mode+'-observed.exe');$null=Run $selection.clang.path ($options+@('-o',$observed));$r=Run $observed @() 180 $directory
  $expectedResult=129;$expectedError=77;if($mode -in @(1,2,3)){$expectedResult=1};if($mode -eq 4){$expectedResult=0};if($mode -in @(3,4)){$expectedError=28}
  if($r.stderr -cne '' -or $r.stdout -cne ("result`t"+$expectedResult+"`terr`t"+$expectedError+"`n")){throw 'Checked entry observer tuple differs'}
  $ordinary=Join-Path $directory ('entry-'+$reference+'-'+$optimization+'-'+$mode+'-ordinary.exe');$null=Run $selection.clang.path ($options+@('-DORDINARY_ADAPTER=1',(Join-Path $directory 'project-process.ll'),'-o',$ordinary))
  $r=Invoke-BoundedProcess $ordinary @() $directory 180;$commands+=@($r)
  if($r.timedOut -or $r.exit -ne $expectedResult -or $r.stdout -cne '' -or $r.stderr -cne ''){throw ('Checked ordinary entry result differs: '+($r|ConvertTo-Json -Compress))}
  $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Checked Main and dependency order through identical ordinary/observed common entry; startup refusal before user code, initializer failure, Main refusal, exact result/Err/revision';reference=$reference;optimization=$optimization;mode=$mode;passed=$true;processResult=$r.exit})
 }
}}
