param([string]$SelectionPath='', [switch]$DiagnosticOnly)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))) {$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/project.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
if($DiagnosticOnly) {
    $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    foreach($id in @($selection.compiler,$selection.clang,$selection.runtime,$selection.unicodeRuntime,$selection.manifest)) {
        if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw 'Historical tool artifact changed'}
    }
} else {$selection=Get-VerifiedBootstrapSelection $SelectionPath}
$run=Join-Path $root ('bootstrap/out/native-initialization/'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run);$utf8=[Text.UTF8Encoding]::new($false)
$inputs=@();$commands=@();$checks=@();$success=$false;$failure=$null
$paths=@('compiler/UBE_Compiler_v3/src/SourceCancellation.cls','compiler/UBE_Compiler_v3/src/NativeResources.bas','compiler/UBE_Compiler_v3/src/NativeOutput.bas','compiler/UBE_Compiler_v3/src/NativeLLVM.bas','compiler/UBE_Compiler_v3/src/NativeInitialization.bas','compiler/UBE_Compiler_v3/src/NativeEntry.bas','compiler/UBE_Compiler_v3/src/NativePlatform.bas','compiler/UBE_Compiler_v3/src/NativeFrames.bas','compiler/UBE_Compiler_v3/tests/native-executable/initialization/Entry.bas')
$lines=@('UBE-Project 1','Name = "NativeInitializationFixture"','Kind = "Exe"','Startup = "Main"')
foreach($path in $paths){
 $name=Split-Path $path -Leaf;$text=[IO.File]::ReadAllText((Join-Path $root $path))
 # This component borrows only the exact scalar emitters. The catalog adapter
 # is exercised in the whole checked-source gate, without mock catalog types.
 if($name -ceq 'NativeInitialization.bas'){$pattern='(?ms)^Function (?:TryEmitNativeProjectInitialization|TryReadNativeInitializationBoundary)\([^\r\n]+\) As Boolean\r?\n.*?^End Function\r?\n';if([regex]::Matches($text,$pattern).Count -ne 2){throw 'Checked initialization adapters missing'};$text=[regex]::Replace($text,$pattern,'')}
 if($name -ceq 'NativeEntry.bas'){$pattern='(?ms)^Function TryEmitNativeProgramEntry\([^\r\n]+\) As Boolean\r?\n.*?^End Function\r?\n';if([regex]::Matches($text,$pattern).Count -ne 1){throw 'Checked entry adapter missing'};$text=[regex]::Replace($text,$pattern,'')}
 [IO.File]::WriteAllText((Join-Path $run $name),$text,$utf8);$lines+='Source = "'+$name+'"';$inputs+=Get-ArtifactIdentity (Join-Path $root $path)
}
# Retain the existing exact scalar visit helper, without a second implementation.
$graphSource=Join-Path $root 'compiler/UBE_Compiler_v3/src/NativeGraph.bas';$inputs+=Get-ArtifactIdentity $graphSource
$visit=[regex]::Match([IO.File]::ReadAllText($graphSource),'(?ms)^Function TryVisitNativeIndex\([^\r\n]+\) As Boolean\r?\n.*?^End Function')
if(-not $visit.Success){throw 'Native visit helper missing'}
$callSource=Join-Path $root 'compiler/UBE_Compiler_v3/src/NativeCalls.bas';$inputs+=Get-ArtifactIdentity $callSource
$stack=[regex]::Match([IO.File]::ReadAllText($callSource),'(?ms)^Function TryEmitNativeStackSupport\([^\r\n]+\) As Boolean\r?\n.*?^End Function')
if(-not $stack.Success){throw 'Production stack support missing'}
$frame=[regex]::Match([IO.File]::ReadAllText($callSource),'(?ms)^Function TryLLVMFrameReference\([^\r\n]+\) As Boolean\r?\n.*?^End Function');if(-not $frame.Success){throw 'Frame reference emitter missing'}
$visitLines=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "NativeInitializationVisitFixture"',$visit.Value,$stack.Value,$frame.Value)
[IO.File]::WriteAllLines((Join-Path $run 'Visit.bas'),$visitLines,$utf8);$lines+='Source = "Visit.bas"'
$core=Join-Path $root 'std-lib/UBECore.UBE';$relative=[Uri]::UnescapeDataString(([Uri]($run.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$core).ToString());$lines+='Reference = "'+$relative+'"'
$manifest=Join-Path $run 'Initialization.UBE';[IO.File]::WriteAllLines($manifest,$lines,$utf8)
$sources=@(Get-FoundationProjectSources $manifest);$names=@{};$types=@{};$classes=@();$ordinal=0
foreach($path in $sources) {
 $text=[IO.File]::ReadAllText($path)
 if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=$Matches[1]}
 foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)')){$name=$m.Groups[1].Value;if($names.ContainsKey($name)){throw 'Duplicate procedure name'};$names[$name]='ube.p'+$ordinal;++$ordinal}
}
$ordinal=0;foreach($name in $classes){$types[$name]='%ube.type.'+$ordinal;++$ordinal}
foreach($path in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($path),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)')){$types[$m.Groups[1].Value]='%ube.type.'+$ordinal;++$ordinal}}
$mapping=[pscustomobject]@{procedures=$names;types=$types};$probe=Join-Path $PSScriptRoot 'probe.c'
$inputs+=@($sources|ForEach-Object {Get-ArtifactIdentity $_})
foreach($path in @($probe,$PSCommandPath,$core,(Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-INITIALIZATION-IMPLEMENTATION.md'),(Join-Path $PSScriptRoot 'observer.c'),(Join-Path $PSScriptRoot 'order-observer.c'),(Join-Path $PSScriptRoot 'order.ps1'),(Join-Path $PSScriptRoot 'entry-probe.c'),(Join-Path $PSScriptRoot 'entry-observer.c'),(Join-Path $PSScriptRoot 'entry.ps1'),(Join-Path $PSScriptRoot 'platform-probe.c'),(Join-Path $PSScriptRoot 'frame-probe.c'),(Join-Path $PSScriptRoot 'frame-data-driver.c'),(Join-Path $PSScriptRoot 'platform-observer.c'),(Join-Path $PSScriptRoot 'platform-entry-observer.c'),(Join-Path $PSScriptRoot 'platform.ps1'),(Join-Path $root 'std-lib/tests/file-output/native.c'),(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1'))){$inputs+=Get-ArtifactIdentity $path}
foreach($path in @('bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/error_support.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c')){$inputs+=Get-ArtifactIdentity (Join-Path $root $path)}
function Run([string]$File,[string[]]$Arguments,[int]$Timeout=180) {
    $r=Invoke-BoundedProcess $File $Arguments $run $Timeout;$script:commands+=@($r)
    if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r
}
try {
 $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path);$prior='';$programPrior=''
 for($stage=0;$stage -lt 2;++$stage) {
  $raw=Join-Path $run ('stage'+$stage+'.ll');$null=Run $stages[$stage] @($manifest,$raw)
  $identity=Get-ArtifactIdentity $raw;if($prior -and $prior -cne $identity.sha256){throw 'Initialization support LLVM differs across stages'};$prior=$identity.sha256
  $ir=[IO.File]::ReadAllText($raw);$adapter=[Text.StringBuilder]::new()
  $null=Assert-FoundationRecord $ir $mapping 'NativeLLVMWriter' ($types.NativeFailure+', '+$types.NativeLimits+', '+$types.NativeUsage+', '+$types.NativeOutput+', ptr')
  foreach($b in @(@('begin','TryBeginNativeLLVM','ptr'),@('dispose','TryDisposeNativeLLVM','ptr'),@('snapshot','TrySnapshotNativeLLVM','ptr'),@('line','TryLLVMLine','ptr,ptr'),@('support','TryEmitNativeInitializationSupport','ptr,i32,i32'),@('data_support','TryEmitNativeInitializationData','ptr,i32'),@('order_support','TryEmitNativeInitializationOrder','ptr,i32,i32'),@('stack_support','TryEmitNativeStackSupport','ptr,i32'),@('entry_support','TryEmitNativeEntry','ptr,i32,i64,i32,i32,i32,i32'),@('process_adapter','TryEmitNativeProcessAdapter','ptr'),@('platform_support','TryEmitNativePlatformSupport','ptr'),@('frame_data','TryEmitNativeFrameData','ptr,ptr,i32,i32,i64'),@('make_cancel','TryMakeInitializationCancellation','ptr'))){Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] 'i1' $b[2]}
  $defaultSymbol=Get-FoundationDefinition $ir $mapping 'DefaultNativeLimits' 'void' 'ptr'
  $null=$adapter.AppendLine("define void @defaults(ptr %p) {`n call void @"+$defaultSymbol+"(ptr %p)`n ret void`n}")
  $visitSymbol=Get-FoundationDefinition $ir $mapping 'TryVisitNativeIndex' 'i1' 'ptr,ptr,ptr,ptr'
  $ir=$ir.Replace('define i1 @'+$visitSymbol+'(','define i1 @initialization_visit_body(')
  $null=$adapter.AppendLine('declare void @visit_event()')
  $null=$adapter.AppendLine('define i1 @'+$visitSymbol+'(ptr %l, ptr %u, ptr %c, ptr %f) {')
  $null=$adapter.AppendLine(' call void @visit_event()')
  $null=$adapter.AppendLine(' %ok = call i1 @initialization_visit_body(ptr %l, ptr %u, ptr %c, ptr %f)')
  $null=$adapter.AppendLine(' ret i1 %ok')
  $null=$adapter.AppendLine('}')
  $adapted=Join-Path $run ('stage'+$stage+'-adapter.ll');[IO.File]::WriteAllText($adapted,[regex]::Replace($ir,'(?m)^define i32 @main\(' ,'define i32 @unused_initialization_main(')+"`n"+$adapter.ToString(),$utf8)
  $exe=Join-Path $run ('stage'+$stage+'-probe.exe');$null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,$adapted,$probe,$selection.unicodeRuntime.path,'-o',$exe)
  $frameDriver=Join-Path $run ('stage'+$stage+'-frame-data.exe');$null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,$adapted,(Join-Path $PSScriptRoot 'frame-data-driver.c'),$selection.unicodeRuntime.path,'-o',$frameDriver)
  $r=Run $exe @();if($r.stderr -cne '' -or $r.stdout -notmatch '^PASS initialization emission [1-9][0-9]* assertions\n$'){throw ($r|ConvertTo-Json -Compress)}
  $checks+=@([pscustomobject]@{assertion='Support emitter resources, failures and cleanup';stage=$stage+1;passed=$true;output=$r.stdout})
  $generated=Join-Path $run ('stage'+$stage+'-initialization.ll');[IO.File]::Move((Join-Path $run 'initialization.ll'),$generated)
  $data=Join-Path $run ('stage'+$stage+'-initialization-data.ll');[IO.File]::Move((Join-Path $run 'initialization-data.ll'),$data)
  $dataIdentity=Get-ArtifactIdentity $data;if($stage -eq 0){$dataPrior=$dataIdentity.sha256}elseif($dataIdentity.sha256 -cne $dataPrior){throw 'Shared data differs across stages'}
  $program=Get-ArtifactIdentity $generated;if($programPrior -and $programPrior -cne $program.sha256){throw 'Emitted initialization program differs across stages'};$programPrior=$program.sha256
  $programText=[IO.File]::ReadAllText($generated);$supportText=$programText.Substring(0,$programText.IndexOf('@ube.stack.floor'))
  $identities=[regex]::Matches($supportText,'(?m)^@[^ ]+ =').Count+[regex]::Matches($supportText,'(?m)^(?:define|declare) ').Count+[regex]::Matches($supportText,'(?m)^\w+:$').Count+[regex]::Matches($supportText,'(?m)^  %\w+ =').Count+2
  if($identities -ne 41){throw 'Support emitted identity inventory disagrees with charge'}
  $other=Join-Path $run ('stage'+$stage+'-other-module.ll');$otherText=$programText.Replace('@initialization_require(', '@initialization_require_other(').Replace('@initialization_state(', '@initialization_state_other(').Replace('@initialization_failed(', '@initialization_failed_other(');[IO.File]::WriteAllText($other,$otherText,$utf8)
  $dataText=[IO.File]::ReadAllText($data);if(([regex]::Matches($dataText,'(?m)^@[^ ]+ =').Count+[regex]::Matches($dataText,'(?m)^declare ').Count) -ne 6){throw 'Shared data identity inventory disagrees with charge'}
  foreach($optimization in @('O0','O2')) {
   $optimized=Join-Path $run ('stage'+$stage+'-inline-'+$optimization+'.ll')
   $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-S','-emit-llvm',$generated,'-o',$optimized)
   if([IO.File]::ReadAllText($optimized) -match '@ube\.(module\.require|stack\.admit)\('){throw 'Required inline helper retained a function/call boundary'}
   $checks+=@([pscustomobject]@{assertion='Initialization and stack-admission helpers are inlined';stage=$stage+1;optimization=$optimization;passed=$true;artifact=(Get-ArtifactIdentity $optimized)})
   foreach($mode in 0..9) {
    $native=Join-Path $run ('stage'+$stage+'-'+$optimization+'-'+$mode+'.exe')
    $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror',('-DMODE='+$mode),'-I',$root,$generated,$other,$data,(Join-Path $PSScriptRoot 'observer.c'),'-o',$native)
    $timeout=10;if($mode -eq 6){$timeout=1};$r=Invoke-BoundedProcess $native @() $run $timeout;$commands+=@($r)
    if($mode -eq 6){if(-not $r.timedOut -or $r.stdout -cne "waiting:A`n" -or $r.stderr -cne ''){throw 'Busy module did not enter the observed bounded wait'}}
    elseif($mode -eq 7 -or $mode -eq 8){if($r.timedOut -or $r.exit -ne 97 -or $r.stdout -cne '' -or $r.stderr -cne ''){throw 'Controlled fatal path mismatch'}}
    elseif($r.timedOut -or $r.exit -ne 0 -or $r.stdout -cne "PASS initialization runtime`n" -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
    $checks+=@([pscustomobject]@{assertion=('Native initialization effects/state/error/wait mode '+$mode);stage=$stage+1;optimization=$optimization;passed=$true;program=$program})
   }
  }
  . (Join-Path $PSScriptRoot 'order.ps1')
  . (Join-Path $PSScriptRoot 'entry.ps1')
  . (Join-Path $PSScriptRoot 'platform.ps1')
  foreach($control in @('repeat','admit','private-state')) {
   $changed=$programText;$changedOther=$otherText;$mode=0
   if($control -eq 'repeat'){$changed=$changed.Replace('store i8 2, ptr %slot','store i8 0, ptr %slot')}
   elseif($control -eq 'admit'){$changed=$changed.Replace('br i1 %room, label %admitted, label %refused','br i1 true, label %admitted, label %refused');$mode=3}
   else{$changedOther=$changedOther.Replace('@ube.module.states = external global [3 x i8]','@ube.module.states = internal global [3 x i8] zeroinitializer')}
   if($changed -ceq $programText -and $changedOther -ceq $otherText){throw 'Control mutation missing'}
   $wrong=Join-Path $run ('stage'+$stage+'-'+$control+'.ll');[IO.File]::WriteAllText($wrong,$changed,$utf8);$native=$wrong+'.exe'
   $wrongOther=Join-Path $run ('stage'+$stage+'-'+$control+'-other.ll');[IO.File]::WriteAllText($wrongOther,$changedOther,$utf8)
   $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17',('-DMODE='+$mode),'-I',$root,$wrong,$wrongOther,$data,(Join-Path $PSScriptRoot 'observer.c'),'-o',$native)
   $r=Invoke-BoundedProcess $native @() $run 10;$commands+=@($r);if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch 'initialization observer'){throw 'State/admission corruption not rejected'}
   $checks+=@([pscustomobject]@{assertion=('Initialization negative control '+$control);stage=$stage+1;passed=$true;error=$r.stderr})
  }
  $omitted=Join-Path $run ('stage'+$stage+'-omitted-visit.exe')
  $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-DOMIT_INITIALIZATION_VISIT_CONTROL','-I',$root,$adapted,$probe,$selection.unicodeRuntime.path,'-o',$omitted)
  $r=Invoke-BoundedProcess $omitted @() $run 10;$commands+=@($r)
  if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch 'visits==w.usage.work'){throw 'Omitted observed work not rejected'}
  $checks+=@([pscustomobject]@{assertion='Initialization observed-work negative control';stage=$stage+1;passed=$true;error=$r.stderr})
 }
 $success=$true
} catch {$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;diagnosticOnly=$DiagnosticOnly.IsPresent;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Production initialization, common/process entry and Windows platform support; synthetic and real query oracles, actual fatal/wait behavior, O0/O2 Full/None platform integration with controlled C user bodies and stack metadata. No checked-source body/ByRef integration, derived recovery reserve, complete API stack closure, native builder or production debug validation qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
