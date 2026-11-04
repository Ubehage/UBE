# Dot-sourced by check.ps1 after its real checked call fixture is emitted.
# Add three scalar observations at callee entry; preserve every production byte
# after removing those calls and the one observer declaration.
$ownerOriginal=[IO.File]::ReadAllText((Join-Path $directory 'call-bodies.ll'))
$ownerHeader=[IO.File]::ReadAllText((Join-Path $directory 'call-functions.h'))
$ownerObserved=$ownerOriginal
foreach($site in @(@('call_step',0,1),@('call_alter',3,2))) {
 $symbolMatch=[regex]::Match($ownerHeader,'(?m)^extern [^\r\n]*\b'+$site[0]+'\([^\r\n]*__asm__\("([^"]+)"\)')
 if(-not $symbolMatch.Success){throw 'Owner observer callee symbol missing'}
 $functionPattern='(?m)^define [^\r\n]+ @'+[regex]::Escape($symbolMatch.Groups[1].Value)+'\(([^\r\n]*)\) \{\r?\n[^:\r\n]+:\r?\n'
 $functionMatch=[regex]::Match($ownerObserved,$functionPattern)
 if(-not $functionMatch.Success){throw 'Owner observer entry missing'}
 $arguments=$functionMatch.Groups[1].Value -split ', ';$insertion=''
 for($parameter=0;$parameter -lt $site[2];++$parameter) {
  $offset=2*$parameter
  if($arguments[$offset] -notmatch '^ptr %v[0-9]+$' -or $arguments[$offset+1] -notmatch '^i32 %v[0-9]+$'){throw 'Pointer/owner private ABI differs'}
  $insertion+='  call void @observe_owner(i32 '+$site[1]+', i32 '+$parameter+', '+$arguments[$offset+1]+")`n"
 }
 $ownerObserved=$ownerObserved.Insert($functionMatch.Index+$functionMatch.Length,$insertion)
}
$ownerDeclaration="`ndeclare void @observe_owner(i32, i32, i32)`n"
$ownerObserved+=$ownerDeclaration
$ownerRestored=[regex]::Replace($ownerObserved,'(?m)^  call void @observe_owner\([^\r\n]*\)\r?\n','')
$ownerRestored=$ownerRestored.Substring(0,$ownerRestored.Length-$ownerDeclaration.Length)
if($ownerRestored -cne $ownerOriginal){throw 'Owner instrumentation changed production instructions'}
$ownerIR=Join-Path $directory 'observed-owners.ll';[IO.File]::WriteAllText($ownerIR,$ownerObserved,$utf8)
foreach($ownerOptimization in @('O0','O2')) {
 $ownerExe=Join-Path $directory ('owners-'+$ownerOptimization+'.exe')
 $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$ownerOptimization),'-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$directory,$ownerIR,(Join-Path $PSScriptRoot 'owner-observer.c'),'-o',$ownerExe)
 $r=Run $ownerExe @() 180 $directory
 if($r.stdout -cne "PASS ByRef module owners`n" -or $r.stderr -cne ''){throw 'ByRef owner native observer failed'}
 $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Actual global/local/temporary/named/recursive ByRef companion transport';optimization=$ownerOptimization;passed=$true})
}
foreach($ownerControl in @('global','forward','temporary')) {
 $ownerPattern='(ptr @ube\.g[0-9]+), i32 0';$ownerReplacement='$1, i32 -1'
 if($ownerControl -eq 'forward'){$ownerPattern='(ptr %v[0-9]+), i32 %v[0-9]+'}
 if($ownerControl -eq 'temporary'){$ownerPattern='(ptr %v[0-9]+), i32 -1';$ownerReplacement='$1, i32 0'}
 $ownerWrong=[regex]::Replace($ownerObserved,'(?m)^  (?:%v[0-9]+ = )?call [^\r\n]+$',{param($match) [regex]::Replace($match.Value,$ownerPattern,$ownerReplacement)})
 if($ownerWrong -ceq $ownerObserved){throw 'ByRef owner corruption target missing'}
 $ownerWrongIR=Join-Path $directory ('wrong-owner-'+$ownerControl+'.ll');[IO.File]::WriteAllText($ownerWrongIR,$ownerWrong,$utf8);$ownerWrongExe=$ownerWrongIR+'.exe'
 $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-I',$root,'-I',$directory,$ownerWrongIR,(Join-Path $PSScriptRoot 'owner-observer.c'),'-o',$ownerWrongExe)
 $r=Invoke-BoundedProcess $ownerWrongExe @() $directory 180;$commands+=@($r)
 if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -notmatch 'owner oracle'){throw 'ByRef owner corruption was not rejected'}
 $checks+=@([pscustomobject]@{stage=$stage+1;assertion=('ByRef owner negative control '+$ownerControl);passed=$true;error=$r.stderr})
}
