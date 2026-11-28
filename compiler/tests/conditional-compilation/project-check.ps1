param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=[Text.UTF8Encoding]::new($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube conditional projects '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$results=New-Object Collections.Generic.List[object]
Write-Output "Evidence: $evidence"
function Run([string]$File,[string[]]$Arguments,[string]$Name) {
 $stdout=Join-Path $evidence ($Name+'.stdout');$stderr=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(120000)){$p.Kill();throw "Deadline: $Name"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing status: $Name"};return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($stdout,$utf);Error=[IO.File]::ReadAllText($stderr,$utf)}}finally{$p.Dispose()}
}
function WriteProject([string]$Name,[string]$Main,[string]$Other,[string]$Optimization) {
 [IO.File]::WriteAllText((Join-Path $evidence ($Name+'-main.bas')),$Main,$utf)
 [IO.File]::WriteAllText((Join-Path $evidence ($Name+'-other.bas')),$Other,$utf)
 $manifest=Join-Path $evidence ($Name+'.UBE')
 $lines=@('UBE-Project 1','Name = "Probe"','Kind = "Exe"','Startup = "Main"',"Optimization = `"$Optimization`"","Source = `"$Name-main.bas`"","Source = `"$Name-other.bas`"")
 if($Optimization -eq '0'){$lines+='DebugInformation = "Full"'}else{$lines+='DebugInformation = "None"'}
 [IO.File]::WriteAllText($manifest,($lines -join "`r`n")+"`r`n",$utf)
 return $manifest
}
$main=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'project-main.bas'),$utf)
$other=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'project-other.bas'),$utf)
$success=$false
try {
 foreach($optimization in @('0','2')) {foreach($control in @(0,1,2)) {
  $name="project-o$optimization-control$control";$expected=$control;$source=$other
  if($control -eq 1){$source=$source.Replace('ReadValue = 42','ReadValue = 43')}
  if($control -eq 2){$source=$source.Replace('ReadValue = 42','Err.Raise 5');$expected=99}
  $manifest=WriteProject $name $main $source $optimization
  $exe=Join-Path $evidence ($name+'.exe')
  $run=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang) ($name+'-build')
  if($run.Code -ne 0){throw "Build failed: $name $($run.Out) $($run.Error)"}
  $run=Run $exe @() ($name+'-run')
  if($run.Code -ne $expected -or $run.Out.Length -ne 0 -or $run.Error.Length -ne 0){throw "Expected exit $expected for $name, got $($run.Code): $($run.Out) $($run.Error)"}
  $results.Add([pscustomobject]@{Name=$name;Expected=$expected;Actual=$run.Code;Pass=$true})
  Write-Output "PASS $name exit=$expected"
 }}
 # Standalone execution context must agree in directives, initializers and native code.
 $context=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "Probe"','Option Explicit','#If IS_IN_IDE Then','Invalid selected hosted branch !!!','#Else','Private Const Hosted As Boolean = IS_IN_IDE','#End If','Private Sub Change(ByRef Value As Boolean)','Value = True','End Sub','Public Function Main() As Long','On Error GoTo Failed','If IS_IN_IDE Then Main = 7: Exit Function','If Hosted Then Main = 8: Exit Function','Change (IS_IN_IDE)','If IS_IN_IDE Then Main = 9: Exit Function','Exit Function','Failed:','Main = 99','End Function') -join "`r`n"
 foreach($optimization in @('0','2')) {foreach($control in @(0,1,2)) {
  $name="context-o$optimization-control$control";$source=$context;$expected=0
  if($control -eq 1){$source=$source.Replace('If IS_IN_IDE Then Main = 7','If Not IS_IN_IDE Then Main = 7');$expected=7}
  if($control -eq 2){$source=$source.Replace('Value = True','Err.Raise 5');$expected=99}
  $manifest=WriteProject $name $source $other $optimization
  $exe=Join-Path $evidence ($name+'.exe')
  $run=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang) ($name+'-build')
  if($run.Code -ne 0){throw "Context build failed: $name $($run.Out) $($run.Error)"}
  $run=Run $exe @() ($name+'-run')
  if($run.Code -ne $expected -or $run.Out.Length -ne 0 -or $run.Error.Length -ne 0){throw "Context expected $expected, got $($run.Code): $name"}
  $results.Add([pscustomobject]@{Name=$name;Expected=$expected;Actual=$run.Code;Pass=$true})
  Write-Output "PASS $name exit=$expected"
 }}
 # Both selected branches must be valid so rejection tests reach the operation on line16.
 $bothContexts=$context.Replace('Invalid selected hosted branch !!!','Private Const Hosted As Boolean = IS_IN_IDE')
 foreach($mode in @('--emit-llvm','--emit-llvm-ide')) {
  $name='context-valid'+$mode;$manifest=WriteProject $name $bothContexts $other '0';$output=Join-Path $evidence ($name+'.ll')
  $run=Run $CompilerExe @($mode,$manifest,$output) $name
  $warning="UBE: W_DEBUG_UNAVAILABLE: debug information unavailable (operation/code/reason 0/2/0) $manifest`r`n"
  if($run.Code -ne 0 -or $run.Error -cne $warning -or -not (Test-Path -LiteralPath $output)){throw "Valid context admission failed: $name $($run.Out) $($run.Error)"}
  $results.Add([pscustomobject]@{Name=$name;Pass=$true})
  foreach($case in @(@('write','IS_IN_IDE = True','E_COMPILE'),@('reference','Change IS_IN_IDE','E_COMPILE'),@('shadow','Dim IS_IN_IDE As Boolean','E_COMPILE'),@('directive','#Const IS_IN_IDE = True','E_LOAD'))) {
   $source=$bothContexts.Replace('Change (IS_IN_IDE)',$case[1])
   $name='context-reject-'+$case[0]+$mode;$manifest=WriteProject $name $source $other '0';$output=Join-Path $evidence ($name+'.ll')
   [IO.File]::WriteAllText($output,'PRESERVE',$utf)
   $run=Run $CompilerExe @($mode,$manifest,$output) $name
   if($run.Code -ne 1 -or -not $run.Error.Contains($case[2]) -or -not $run.Error.Contains($name+'-main.bas:16:') -or [IO.File]::ReadAllText($output,$utf) -cne 'PRESERVE'){throw "Context rejection failed: $name $($run.Out) $($run.Error)"}
   $results.Add([pscustomobject]@{Name=$name;Pass=$true;Line=16;OutputPreserved=$true})
   Write-Output "PASS $name line16 and prior output preserved"
  }
 }
 # A hosted launch artifact must be executable; ordinary library LLVM remains admitted.
 $library=Join-Path $evidence 'library.UBE';$librarySource=Join-Path $evidence 'library.bas'
 [IO.File]::WriteAllLines($librarySource,@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "LibraryProbe"','Public Function Value() As Long','Value = 42','End Function'),$utf)
 [IO.File]::WriteAllLines($library,@('UBE-Project 1','Name = "LibraryProbe"','Kind = "Library"','DebugInformation = "None"','Source = "library.bas"'),$utf)
 $ordinaryOutput=Join-Path $evidence 'library-ordinary.ll'
 $run=Run $CompilerExe @('--emit-llvm',$library,$ordinaryOutput) 'library-ordinary'
 if($run.Code -ne 0 -or $run.Error -ne '' -or -not (Test-Path -LiteralPath $ordinaryOutput)){throw "Ordinary library emission failed: $($run.Out) $($run.Error)"}
 $results.Add([pscustomobject]@{Name='library-ordinary';Pass=$true});Write-Output 'PASS ordinary library LLVM admission'
 foreach($mode in @('--emit-llvm-ide','--build-ide')) {
  $name='library-reject'+$mode;$output=Join-Path $evidence ($name+'.output')
  [IO.File]::WriteAllText($output,'PRESERVE',$utf)
  $arguments=@($mode,$library,$output);if($mode -eq '--build-ide'){$arguments+=@('--clang',$Clang)}
  $run=Run $CompilerExe $arguments $name
  if($run.Code -ne 1 -or $run.Out -ne '' -or -not $run.Error.Contains('E_BACKEND') -or -not $run.Error.Contains('(operation/code/reason 0/1/1)') -or -not $run.Error.Contains($library) -or [IO.File]::ReadAllText($output,$utf) -cne 'PRESERVE'){throw "Hosted library was not rejected with prior output preserved: $mode $($run.Out) $($run.Error)"}
  $results.Add([pscustomobject]@{Name=$name;Pass=$true;OutputPreserved=$true});Write-Output "PASS $name prior output preserved"
 }
 # Removed Unicode source must not move the later binder diagnostic.
 $bad=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "Probe"','Option Explicit','#If False Then',('"unterminated '+[char]0xE5+' '+[char]::ConvertFromUtf32(0x1F600)),'#End If','Public Function Main() As Long','Main = Missing','End Function') -join "`r`n"
 $manifest=WriteProject 'location' $bad $other '0'
 foreach($mode in @('--emit-llvm','--build')) {
  $output=Join-Path $evidence ('location'+$mode+'.output')
  [IO.File]::WriteAllText($output,'PRESERVE',$utf)
  $arguments=@($mode,$manifest,$output);if($mode -eq '--build'){$arguments+=@('--clang',$Clang)}
  $run=Run $CompilerExe $arguments ('location'+$mode)
  $log=$run.Out+$run.Error
  if($run.Code -ne 1 -or -not $log.Contains('E_COMPILE') -or -not $log.Contains('location-main.bas:8:8') -or [IO.File]::ReadAllText($output,$utf) -cne 'PRESERVE'){throw "Expected located binding rejection and preserved output: $log"}
  $results.Add([pscustomobject]@{Name='location'+$mode;Pass=$true;Location='8:8';OutputPreserved=$true})
 }
 $fixed=WriteProject 'corrected' ($bad.Replace('Main = Missing','Main = 0')) $other '0'
 $before=Join-Path $evidence 'corrected-before.ll'
 $run=Run $CompilerExe @('--emit-llvm',$fixed,$before) 'corrected-before'
 if($run.Code -ne 0){throw "Corrected source failed: $($run.Out) $($run.Error)"}
 $after=Join-Path $evidence 'corrected-after.ll'
 $run=Run $CompilerExe @('--emit-llvm',$fixed,$after) 'corrected-after'
 if($run.Code -ne 0 -or (Get-FileHash -LiteralPath $after).Hash -cne (Get-FileHash -LiteralPath $before).Hash){throw 'Corrected source emission is not deterministic'}
 if(@(Get-ChildItem -LiteralPath $evidence -Force -Filter '*.ube-*').Count){throw 'Leaked publication stage'}
 $results.Add([pscustomobject]@{Name='corrected-recovery';Pass=$true;IdenticalLLVM=$true})
 $success=$true
} finally {
 $report=[pscustomobject]@{Success=$success;Compiler=$CompilerExe;CompilerSha256=(Get-FileHash -LiteralPath $CompilerExe -Algorithm SHA256).Hash;Results=$results.ToArray()}
 [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),($report|ConvertTo-Json -Depth 5),$utf)
}
