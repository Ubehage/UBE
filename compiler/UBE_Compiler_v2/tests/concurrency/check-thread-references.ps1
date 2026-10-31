param([string]$CandidateDirectory='',[string]$SelectionPath='',[int[]]$Stages=@(1,2))

# Check actual UBE capture/start/wait/stop; C supplies assertions and fault inputs.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$acceptedSelection=$null
if($CandidateDirectory -eq '') {
    if($SelectionPath -eq ''){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
    $selection=Get-VerifiedBootstrapSelection $SelectionPath
    $acceptedSelection=$selection
    $compilerPaths=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    $runtimePath=$selection.runtime.path
} else {
    $selection=Get-Content -LiteralPath (Join-Path $root 'bootstrap/out/v2/current.json') -Raw | ConvertFrom-Json
    $compilerPaths=@((Join-Path $CandidateDirectory 'compiler-stage1.exe'),(Join-Path $CandidateDirectory 'compiler-stage2.exe'))
    $runtimePath=Join-Path $CandidateDirectory 'bootstrap_runtime.o'
}
$run=Join-Path $root ('bootstrap/out/thread-references/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands=@();$cases=@();$rejections=@();$success=$false
$utf8=[Text.UTF8Encoding]::new($false)
try {
    $runtime=Join-Path $run 'bootstrap_runtime.o'
    $runtimeCompile=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-c',(Join-Path $root 'runtime/bootstrap_runtime.c'),'-o',$runtime) $root 60;$commands+=$runtimeCompile
    if($runtimeCompile.timedOut -or $runtimeCompile.exit -ne 0){throw ('Runtime compile: '+$runtimeCompile.stderr)}
    foreach($stage in $Stages) {
        $compiler=$compilerPaths[$stage-1]
        $ir=Join-Path $run ('thread-stage'+$stage+'.ll');$exe=Join-Path $run ('thread-stage'+$stage+'.exe')
        $manifest=Join-Path $PSScriptRoot 'ThreadReferences.UBE'
        $emit=Invoke-BoundedProcess $compiler @($manifest,$ir) $root 60;$commands+=$emit
        if($emit.timedOut -or $emit.exit -ne 0){throw ('Thread source: '+$emit.stdout+$emit.stderr)}
        $llvm=[IO.File]::ReadAllText($ir)
        if($llvm -notmatch 'call i64 @ube_thread_start_checked\(' -or $llvm -notmatch 'call i32 @ube_thread_admit\('){throw 'Missing actual start or checked Sub admission'}
        $link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$ir,'-x','none',$runtime,$selection.unicodeRuntime.path,'-o',$exe) $root 60;$commands+=$link
        if($link.timedOut -or $link.exit -ne 0){throw ('Thread link: '+$link.stderr)}
        $native=Invoke-BoundedProcess $exe @() $root 15;$commands+=$native
        if($native.timedOut -or $native.exit -ne 0 -or $native.stdout.Replace("`r",'') -cne "97`n12`n1012`n81`n45`n5`n" -or $native.stderr -cne ''){throw ('Thread native: '+($native | ConvertTo-Json -Compress))}
        foreach($signature in 'define i64 @ube.p1(ptr %arg.1)','define void @ube.p3(i32 %arg.2, ptr %result.out)','define i32 @ube.p5(ptr %arg.4)','define i64 @ube.p10(ptr %arg.16, double %arg.17)') {
            if(-not $llvm.Contains($signature)){throw ('Fixture ABI changed: '+$signature)}
        }
        $observedIr=Join-Path $run ('observed-stage'+$stage+'.ll');$observedExe=Join-Path $run ('observed-stage'+$stage+'.exe')
        $observedLlvm=$llvm.Replace('define i32 @main(', 'define i32 @ube_observed_program_main(')
        $observedLlvm+=@'

define i64 @probe_start_owner(ptr %owner) {
  %id = call i64 @ube.p1(ptr %owner)
  ret i64 %id
}
define void @probe_make_owner(i32 %length, ptr %output) {
  call void @ube.p3(i32 %length, ptr %output)
  ret void
}
define i32 @probe_copy_owner(ptr %owner) {
  %result = call i32 @ube.p5(ptr %owner)
  ret i32 %result
}
define ptr @probe_reference_layout() {
  ret ptr @ube.value.20000
}
define i64 @probe_start_fraction(ptr %owner, double %fraction) {
  %id = call i64 @ube.p10(ptr %owner, double %fraction)
  ret i64 %id
}
'@
        [IO.File]::WriteAllText($observedIr,$observedLlvm,$utf8)
        $observer=Join-Path $PSScriptRoot 'thread_reference_observer.c'
        $observedLink=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$observedIr,'-x','c',$observer,'-x','none',$selection.unicodeRuntime.path,'-o',$observedExe) $root 60;$commands+=$observedLink
        if($observedLink.timedOut -or $observedLink.exit -ne 0){throw ('Observed link: '+$observedLink.stderr)}
        $observed=Invoke-BoundedProcess $observedExe @() $root 45;$commands+=$observed
        if($observed.timedOut -or $observed.exit -ne 0 -or $observed.stdout -notmatch 'PASS UBE thread failures/TLS/cancellation/root admission;' -or $observed.stderr -cne ''){throw ('Observed native: '+($observed | ConvertTo-Json -Compress))}
        $cases+=[pscustomobject]@{stage=$stage;compiler=(Get-ArtifactIdentity $compiler);ir=(Get-ArtifactIdentity $ir);exe=(Get-ArtifactIdentity $exe);native=$native;observedIr=(Get-ArtifactIdentity $observedIr);observedExe=(Get-ArtifactIdentity $observedExe);observed=$observed}
    }
    if($cases.Count -eq 2 -and $cases[0].ir.sha256 -cne $cases[1].ir.sha256){throw 'Paired-stage thread LLVM differs'}
    $captureCases=@(
        @{name='function-target';declaration="Function Work() As Long`n    Work = 7`nEnd Function";setup='';call='CallNew Work()';code='UBE2240'},
        @{name='byref-capture';declaration="Sub Work(ByRef Value As Long)`nEnd Sub";setup='Dim Value As Long';call='CallNew Work(Value)';code='UBE2240'},
        @{name='implicit-byref';declaration="Sub Work(Value As Long)`nEnd Sub";setup='Dim Value As Long';call='CallNew Work(Value)';code='UBE2240'},
        @{name='array-capture';declaration="Sub Work(ByVal Values() As Byte)`nEnd Sub";setup='Dim Values() As Byte';call='CallNew Work(Values)';code='UBE2240'},
        @{name='record-capture';declaration="Type Packet`n    Value As Long`nEnd Type`nSub Work(ByVal Value As Packet)`nEnd Sub";setup='Dim Value As Packet';call='CallNew Work(Value)';code='UBE2240'},
        @{name='string-capture';declaration="Sub Work(ByVal Value As String)`nEnd Sub";setup='Dim Value As String';call='CallNew Work(Value)';code='UBE2240'},
        @{name='callnew-shape';declaration="Sub Work()`nEnd Sub";setup='';call='CallNew Work';code='UBE2240'}
    )
    foreach($binding in @('Thread.TryCurrentId','Thread.TryIsAlive','Thread.TryRequestStop','Thread.TryStopRequested','Thread.TryWait','Thread.TryYield')) {
        $captureCases+=@{name=($binding.Replace('.','-'));declaration=('Intrinsic Function Wrong() As Long'+"`n"+'Attribute Wrong.UBE_Primitive = "'+$binding+'"'+"`nEnd Function");setup='';call='';code='UBE3232'}
    }
    foreach($case in $captureCases) {
        $source=Join-Path $run ($case.name+'.bas')
        [IO.File]::WriteAllText($source,('UBE SOURCE 1 MODULE'+"`n"+'Attribute UBE_Name = "CaptureRejection"'+"`n"+$case.declaration+"`nFunction Main() As Long`n    "+$case.setup+"`n    "+$case.call+"`n    Main = 0`nEnd Function`n"),$utf8)
        foreach($stage in $Stages) {
            $ir=Join-Path $run ($case.name+'-stage'+$stage+'.ll')
            $rejected=Invoke-BoundedProcess $compilerPaths[$stage-1] @($source,$ir) $root 30;$commands+=$rejected
            if($rejected.timedOut -or $rejected.exit -ne 1 -or $rejected.stdout -notmatch ('error '+$case.code+':') -or $rejected.stderr -cne '' -or [IO.File]::Exists($ir)){throw ('Capture rejection '+$case.name+': '+$rejected.stdout+$rejected.stderr)}
            $rejections+=[pscustomobject]@{name=$case.name;stage=$stage;code=$case.code;result=$rejected;input=(Get-ArtifactIdentity $source);noLlvm=$true}
        }
    }
    if($null -ne $acceptedSelection){$null=Get-VerifiedBootstrapSelection $SelectionPath}
    $success=$true
} catch {$failure=$_.Exception.Message}
$paths=@('ThreadReferences.UBE','ByteOwner.cls','thread-references.bas' | ForEach-Object {Join-Path $PSScriptRoot $_})
$paths+=@('std-lib/UBECore.UBE','std-lib/src/win-lib/thread_primitives.c','runtime/bootstrap_runtime.c','runtime/value_storage.h')
$paths+=@(Get-ChildItem -LiteralPath (Join-Path $root 'std-lib/src/portable') -Filter '*.bas' | ForEach-Object {$_.FullName})
$paths+=@(Join-Path $PSScriptRoot 'thread_reference_observer.c')
$inputs=@($paths | ForEach-Object {Get-ArtifactIdentity $_})
$checks=@()
if($success) {
    foreach($case in $cases){$checks+=[pscustomobject]@{passed=$true;assertion=('native controlled outcomes through source-built stage '+$case.stage)}}
    foreach($case in $rejections){$checks+=[pscustomobject]@{passed=$true;assertion=('controlled '+$case.name+' rejection through stage '+$case.stage)}}
}
$report=[pscustomobject]@{success=$success;acceptedSelection=$acceptedSelection;checks=$checks;qualifiedCompilerConcurrency=$false;scope='Actual UBE identity/scalar capture, fresh wait/stop, growing-input copy observations/positive controls, allocation/TLS/start/wait/root admission failures, lifetime, cleanup and unsupported-signature rejections; full compiler proof and earlier gates remain pending.';inputs=$inputs;runtime=(Get-ArtifactIdentity $runtime);clang=(Get-ArtifactIdentity $selection.clang.path);unicodeRuntime=(Get-ArtifactIdentity $selection.unicodeRuntime.path);cases=$cases;rejections=$rejections;commands=$commands;failure=$(if($success){''}else{$failure})}
$path=Join-Path $run 'report.json';$report | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Output ('Evidence: '+$path)
if(-not $success){throw $failure}
Write-Output ('PASS actual UBE reference capture/start/wait/stop through '+$cases.Count+' stage(s).')
