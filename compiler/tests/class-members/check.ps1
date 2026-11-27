param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe',[ValidateSet('All','Execution','GC','Allocation','Diagnostics')][string]$Suite='All')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=[Text.UTF8Encoding]::new($false,$true)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube class members '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$results=New-Object Collections.Generic.List[object]
Write-Output "Evidence: $evidence"
function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $stdout=Join-Path $evidence ($Name+'.stdout');$stderr=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;PassThru=$true;WindowStyle='Hidden';RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(120000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $Name"};$p.Refresh();Require ($null -ne $p.ExitCode) "Missing status: $Name";return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($stdout,$utf);Error=[IO.File]::ReadAllText($stderr,$utf)}}finally{$p.Dispose()}
}
function Project([string]$Name,[string]$Main,[string]$Level,[string]$Class=''){
 $folder=Join-Path $evidence $Name;$null=New-Item -ItemType Directory -Path $folder
 foreach($file in @('Gate.cls','RecordTypes.bas','Helpers.bas')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $folder}
 if($Class -ne ''){
  [IO.File]::WriteAllText((Join-Path $folder 'Gate.cls'),$Class,$utf)
  [IO.File]::WriteAllLines((Join-Path $folder 'Helpers.bas'),@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "Helpers"','Public Sub ClearReference(ByRef Value As Gate)','Set Value = Nothing','End Sub'),$utf)
 }
 [IO.File]::WriteAllText((Join-Path $folder 'Main.bas'),$Main,$utf)
 $manifest=Join-Path $folder 'Probe.UBE'
 [IO.File]::WriteAllLines($manifest,@('UBE-Project 1','Name = "Probe"','Kind = "Exe"','Startup = "Main"',"Optimization = `"$Level`"",'Source = "Gate.cls"','Source = "RecordTypes.bas"','Source = "Helpers.bas"','Source = "Main.bas"'),$utf)
 return $manifest
}
function Record([string]$Name){$results.Add([pscustomobject]@{Name=$Name;Pass=$true});Write-Output "PASS $Name"}
$success=$false
try{
 if($Suite -in @('All','Execution')){
  $main=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'execution-main.bas'),$utf)
  foreach($level in @('0','2')){foreach($control in @('positive','expectation','escaping-failure')){
   $source=$main;$expected=0
   if($control -eq 'expectation'){$source=$source.Replace('If Number <> 42 Then Exit Function','If Number <> 43 Then Exit Function');$expected=1}
   if($control -eq 'escaping-failure'){$source=$source.Replace("' ESCAPING CONTROL",'Helpers.UnexpectedFailure');$expected=99}
   $name="execution-o$level-$control";$manifest=Project $name $source $level;$binary=Join-Path (Split-Path -Parent $manifest) 'probe.exe'
   $run=Run $CompilerExe @('--build',$manifest,$binary,'--clang',$Clang) ($name+'-build')
   Require ($run.Code -eq 0 -and $run.Error -eq '') "Build failed: $name $($run.Out) $($run.Error)"
   $run=Run $binary @() ($name+'-run')
   Require ($run.Code -eq $expected -and $run.Out -eq '' -and $run.Error -eq '') "Expected $expected for $name, got $($run.Code): $($run.Out) $($run.Error)"
   Record $name
  }}
 }
 foreach($graphKind in @('GC','Allocation')){if($Suite -in @('All',$graphKind)){
  $prefix='gc';if($graphKind -eq 'Allocation'){$prefix='allocation'}
  $main=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ($prefix+'-main.bas')),$utf)
  $manifest=Project ('managed-'+$prefix) $main '0';$llvm=Join-Path (Split-Path -Parent $manifest) 'original.ll'
  $run=Run $CompilerExe @('--emit-llvm',$manifest,$llvm) 'managed-graph-emit'
  Require ($run.Code -eq 0 -and $run.Error -eq '') "Graph emission failed: $($run.Out) $($run.Error)"
  $program=[IO.File]::ReadAllText($llvm,$utf)
  foreach($pair in @(@('define i1 @ube.object.create(','define i1 @class.actual.create('),@('define i32 @main()','define i32 @class.source.main()'))){Require ([regex]::Matches($program,[regex]::Escape($pair[0])).Count -eq 1) "Ambiguous graph boundary: $($pair[0])";$program=$program.Replace($pair[0],$pair[1])}
  if($graphKind -eq 'Allocation'){
   $anchor='define ptr @ube.target.allocate('
   Require ([regex]::Matches($program,[regex]::Escape($anchor)).Count -eq 1) 'Ambiguous target allocator'
   $program=$program.Replace($anchor,'define ptr @class.actual.allocate(')
  }
  $observe='call { i1, i64 } @ube.thread.current(ptr %ctx)'
  Require ($program.Contains($observe)) 'Missing source observation hook'
  $replacement='call { i1, i64 } @class.observer.observe(ptr %ctx)'
  if($graphKind -eq 'Allocation'){$replacement='call { i1, i64 } @class.fault.observe(ptr %ctx)'}
  $program=$program.Replace($observe,$replacement)
  $observer=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ($prefix+'-observer.ll')),$utf)
  $library=Join-Path $evidence 'kernel32.lib'
  $run=Run (Join-Path (Split-Path -Parent $Clang) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path $repo 'compiler/llvm/kernel32.def'),'-l',$library) 'imports'
  Require ($run.Code -eq 0 -and $run.Error -eq '') 'Import library failed'
  foreach($level in @('0','2')){foreach($negative in @($false,$true)){
   $oracle=$observer;$expected=0
   if($negative){
    $expected=99
    if($graphKind -eq 'Allocation'){
     $oracle=$oracle.Replace('%p0 = icmp ne ptr %r0, null','%p0 = icmp eq ptr %r0, null')
     # Invert old-destination retention: source must reject its first post-GC mask.
     $oracle=$oracle.Replace('%observed.ok = icmp eq i64 %observed, 2','%observed.ok = icmp eq i64 %observed, 1')
     $expected=4
    }
    else{$oracle=$oracle.Replace('%calls.ok = icmp eq i64 %calls, 7','%calls.ok = icmp eq i64 %calls, 8')}
   }
   $name="$prefix-o$level-negative$negative";$ir=Join-Path $evidence ($name+'.ll');$binary=Join-Path $evidence ($name+'.exe')
   [IO.File]::WriteAllText($ir,$program+"`r`n"+$oracle,$utf)
   $run=Run $Clang @('--target=x86_64-pc-windows-msvc','-Wno-override-module','-fuse-ld=lld','-nostdlib',('-O'+$level),$ir,$library,'-o',$binary,'-Wl,/entry:main,/subsystem:console,/stack:8388608') ($name+'-clang')
   Require ($run.Code -eq 0 -and $run.Error -eq '') "Graph build failed: $($run.Error)"
   $run=Run $binary @() ($name+'-run')
   Require ($run.Code -eq $expected -and $run.Out -eq '' -and $run.Error -eq '') "Graph expected $expected got $($run.Code): $($run.Error)"
   Record $name
  }}
 }}
 if($Suite -in @('All','Diagnostics')){
  $head="UBE SOURCE 1 CLASS`r`nAttribute UBE_Name = `"Gate`"`r`nOption Explicit`r`n"
  $class=$head+"Private Hidden As Long`r`nPublic Function ReadValue() As Long`r`nReadValue = Hidden`r`nEnd Function`r`n"
  $module="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Runner`"`r`nOption Explicit`r`nPublic Function Main() As Long`r`nDim Value As Gate`r`nSet Value = New Gate`r`n' OPERATION`r`nEnd Function`r`n"
  $cases=@(
   @{Name='private';Main=$module.Replace("' OPERATION",'Main = Value.Hidden');Class=$class;File='Main.bas';Line=7;Code='E_COMPILE'},
   @{Name='member-leak';Main=$module.Replace("' OPERATION",'Main = ReadValue()');Class=$class;File='Main.bas';Line=7;Code='E_COMPILE'},
   @{Name='static-instance';Main=$module.Replace("' OPERATION",'Main = Gate.ReadValue()');Class=$class;File='Main.bas';Line=7;Code='E_COMPILE'},
   @{Name='module-me';Main=$module.Replace("' OPERATION",'Set Value = Me');Class=$class;File='Main.bas';Line=7;Code='E_COMPILE'},
   @{Name='callnew-instance';Main=$module.Replace("' OPERATION",'CallNew Value.ReadValue()');Class=$class;File='Main.bas';Line=7;Code='E_COMPILE'},
   @{Name='write-me';Main=$module;Class=($head+"Public Sub Change()`r`nSet Me = Nothing`r`nEnd Sub`r`n");File='Gate.cls';Line=5;Code='E_COMPILE'},
   @{Name='byref-me';Main=$module;Class=($head+"Public Sub Change()`r`nHelpers.ClearReference Me`r`nEnd Sub`r`n");File='Gate.cls';Line=5;Code='E_COMPILE'}
  )
  foreach($unsupported in @(@('array-field','Public Values() As Long','E_COMPILE'),@('field-initializer','Public Value As Long = 1','E_COMPILE'),@('initialize-hook',"Private Sub Class_Initialize()`r`nEnd Sub",'E_COMPILE'),@('terminate-hook',"Private Sub Class_Terminate()`r`nEnd Sub",'E_COMPILE'),@('property',"Public Property Get Value() As Long`r`nEnd Property",'E_LOAD'))){
   $cases+=@{Name=$unsupported[0];Main=$module;Class=($head+$unsupported[1]+"`r`n");File='Gate.cls';Line=4;Code=$unsupported[2]}
  }
  $fieldClass=$head+"Public Value As Long`r`n"
  $worker="Private Sub Worker(ByRef Cell As Long)`r`nCell = 42`r`nEnd Sub`r`n"
  $forward="Private Sub Forward(ByRef Cell As Long)`r`nCallNew Worker(Cell)`r`nEnd Sub`r`n"
  $cases+=@{Name='async-field-alias';Main=($module.Replace("' OPERATION",'CallNew Worker(Value.Value)')+$worker);Class=$fieldClass;File='Main.bas';Line=7;Code='E_COMPILE';Detail='8/55'}
  $cases+=@{Name='forwarded-async-field-alias';Main=($module.Replace("' OPERATION",'Forward Value.Value')+$worker+$forward);Class=$fieldClass;File='Main.bas';Line=7;Code='E_COMPILE';Detail='8/55'}
  foreach($case in $cases){
   $name='reject-'+$case.Name;$manifest=Project $name $case.Main '0' $case.Class;$output=Join-Path (Split-Path -Parent $manifest) 'out.ll'
   [IO.File]::WriteAllText($output,'PRESERVE',$utf)
   $run=Run $CompilerExe @('--emit-llvm',$manifest,$output) $name
   Require ($run.Code -eq 1 -and $run.Out -eq '' -and $run.Error.Contains($case.Code) -and $run.Error.Contains($case.File+':'+$case.Line+':') -and [IO.File]::ReadAllText($output,$utf) -ceq 'PRESERVE') "Located rejection failed: $name $($run.Out) $($run.Error)"
   if($case.ContainsKey('Detail')){Require ($run.Error.Contains('/'+$case.Detail+')')) "Wrong escape diagnostic: $name $($run.Error)"}
   Record $name
  }
 }
 $success=$true
}finally{
 [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),(@{Success=$success;Suite=$Suite;CompilerSHA256=(Get-FileHash -LiteralPath $CompilerExe).Hash;Results=$results.ToArray()}|ConvertTo-Json -Depth 5),$utf)
}
Write-Output "PASS: $($results.Count) class member checks. Evidence: $evidence"
