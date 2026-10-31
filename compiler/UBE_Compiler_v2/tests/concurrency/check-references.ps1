param([string]$CandidateDirectory='',[string]$SelectionPath='')

# Exercise intact source-built UBE reference semantics through both stages.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent
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
$run=Join-Path $root ('bootstrap/out/reference-storage/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands=@();$cases=@();$rejections=@();$success=$false
$utf8=[Text.UTF8Encoding]::new($false)
$manifest=Join-Path $PSScriptRoot 'ReferenceBasics.UBE'
$expected="99`n23`n1`n41`n31`n7`n67`n3`n2`n53`n67`n4`n"
$inputs=@('ReferenceBasics.UBE','ByteOwner.cls','reference-basics.bas' | ForEach-Object { Get-ArtifactIdentity (Join-Path $PSScriptRoot $_) })
try {
    foreach($stage in 1,2) {
        $compiler=$compilerPaths[$stage-1]
        $ir=Join-Path $run ('references-stage'+$stage+'.ll');$exe=Join-Path $run ('references-stage'+$stage+'.exe')
        $emit=Invoke-BoundedProcess $compiler @($manifest,$ir) $root 60;$commands+=$emit
        if($emit.timedOut -or $emit.exit -ne 0){throw ('Reference source compile: '+$emit.stdout+$emit.stderr)}
        $link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$ir,'-x','none',$runtimePath,$selection.unicodeRuntime.path,'-o',$exe) $root 60;$commands+=$link
        if($link.timedOut -or $link.exit -ne 0){throw ('Reference link: '+$link.stderr)}
        $native=Invoke-BoundedProcess $exe @() $root 15;$commands+=$native
        if($native.timedOut -or $native.exit -ne 0 -or $native.stdout.Replace("`r",'') -cne $expected -or $native.stderr -cne ''){throw ('Reference native result: '+($native | ConvertTo-Json -Compress))}
        $observedIr=Join-Path $run ('observed-stage'+$stage+'.ll')
        $observedExe=Join-Path $run ('observed-stage'+$stage+'.exe')
        $llvm=[IO.File]::ReadAllText($ir)
        foreach($signature in 'define void @ube.p3(ptr %result.out)','define void @ube.p4(ptr %result.out)','define i32 @ube.p5(ptr %arg.3)') {
            if(-not $llvm.Contains($signature)){throw ('Fixture ABI changed: '+$signature)}
        }
        $llvm=$llvm.Replace('define i32 @main(', 'define i32 @ube_observed_program_main(')
        $llvm+=@'

define void @probe_create(ptr %output) {
  call void @ube.p3(ptr %output)
  ret void
}
define void @probe_allocate(ptr %output) {
  call void @ube.p4(ptr %output)
  ret void
}
define i32 @probe_read_count(ptr %owner) {
  %result = call i32 @ube.p5(ptr %owner)
  ret i32 %result
}
define ptr @probe_reference_layout() {
  ret ptr @ube.value.20000
}
'@
        [IO.File]::WriteAllText($observedIr,$llvm,$utf8)
        $observer=Join-Path $PSScriptRoot 'reference_observer.c'
        $linkObserved=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$observedIr,'-x','c',$observer,'-x','none',$selection.unicodeRuntime.path,'-o',$observedExe) $root 60;$commands+=$linkObserved
        if($linkObserved.timedOut -or $linkObserved.exit -ne 0){throw ('Observer link: '+$linkObserved.stderr)}
        $observed=Invoke-BoundedProcess $observedExe @() $root 30;$commands+=$observed
        if($observed.timedOut -or $observed.exit -ne 0 -or $observed.stdout -notmatch '^PASS reference observer; first successful root capacity=[1-9][0-9]*\r?\n$' -or $observed.stderr -cne ''){throw ('Reference observer: '+($observed | ConvertTo-Json -Compress))}
        $cases+=[pscustomobject]@{stage=$stage;compiler=(Get-ArtifactIdentity $compiler);ir=(Get-ArtifactIdentity $ir);exe=(Get-ArtifactIdentity $exe);native=$native;observedIr=(Get-ArtifactIdentity $observedIr);observedExe=(Get-ArtifactIdentity $observedExe);observed=$observed}
    }
    if($cases[0].ir.sha256 -cne $cases[1].ir.sha256){throw 'Reference LLVM differs between source-built stages'}
    $classText=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ByteOwner.cls'))
    $entryText=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'reference-basics.bas'))
    $negativeCases=@(
        @{name='private-field';owner=$classText.Replace('Public Count As Long','Private Count As Long');entry=$entryText;code='UBE3240'},
        @{name='implicit-field';owner=$classText.Replace('Public Count As Long','Count As Long');entry=$entryText;code='UBE3240'},
        @{name='duplicate-field';owner=$classText+"`nPublic Count As Long`n";entry=$entryText;code='UBE2114'},
        @{name='unknown-field';owner=$classText.Replace('Public Count As Long','Public Count As MissingType');entry=$entryText;code='UBE3215'},
        @{name='method';owner=$classText+"`nPublic Sub Run()`nEnd Sub`n";entry=$entryText;code='UBE2116'},
        @{name='as-new';owner=$classText;entry=$entryText.Replace('Dim Other As ByteOwner','Dim Other As New ByteOwner');code='UBE2207'},
        @{name='new-record';owner=$classText;entry=$entryText.Replace('New ByteOwner','New OwnerPair');code='UBE3241'},
        @{name='reference-without-set';owner=$classText;entry=$entryText.Replace('Set Other = Owner','Other = Owner');code='UBE3242'},
        @{name='set-scalar';owner=$classText;entry=$entryText.Replace('Owner.Count = 99','Set Owner.Count = 99');code='UBE3242'},
        @{name='identity-on-scalar';owner=$classText;entry=$entryText.Replace('Owner Is Other','1 Is 2');code='UBE3243'},
        @{name='print-nothing';owner=$classText;entry=$entryText.Replace('Print Owner.Count','Print Nothing');code='UBE3233'},
        @{name='inline-cycle';owner=$classText;entry=$entryText.Replace('Type OwnerPair','Type OwnerPair'+"`n    Cycle As OwnerPair");code='UBE3221'}
    )
    foreach($case in $negativeCases) {
        $directory=Join-Path $run $case.name;New-Item -ItemType Directory -Path $directory | Out-Null
        [IO.File]::WriteAllText((Join-Path $directory 'ByteOwner.cls'),$case.owner,$utf8)
        [IO.File]::WriteAllText((Join-Path $directory 'reference-basics.bas'),$case.entry,$utf8)
        $caseManifest=Join-Path $directory 'ReferenceBasics.UBE'
        [IO.File]::WriteAllText($caseManifest,[IO.File]::ReadAllText($manifest),$utf8)
        foreach($stage in 1,2) {
            $compiler=$compilerPaths[$stage-1]
            $caseIr=Join-Path $directory ('stage'+$stage+'.ll')
            $rejected=Invoke-BoundedProcess $compiler @($caseManifest,$caseIr) $root 30;$commands+=$rejected
            if($rejected.timedOut -or $rejected.exit -ne 1 -or $rejected.stdout -notmatch ('error '+$case.code+':') -or $rejected.stderr -cne '' -or [IO.File]::Exists($caseIr)){throw ('Unsupported reference construct '+$case.name+': '+$rejected.stdout+$rejected.stderr)}
            $rejections+=[pscustomobject]@{name=$case.name;stage=$stage;code=$case.code;result=$rejected;noLlvm=$true;classInput=(Get-ArtifactIdentity (Join-Path $directory 'ByteOwner.cls'));entryInput=(Get-ArtifactIdentity (Join-Path $directory 'reference-basics.bas'))}
        }
    }
    if($null -ne $acceptedSelection){$null=Get-VerifiedBootstrapSelection $SelectionPath}
    $success=$true
} catch { $failure=$_.Exception.Message }
$checks=@()
if($success) {
    foreach($case in $cases){$checks+=[pscustomobject]@{passed=$true;assertion=('native controlled outcomes through source-built stage '+$case.stage)}}
    foreach($case in $rejections){$checks+=[pscustomobject]@{passed=$true;assertion=('controlled '+$case.name+' rejection, stage '+$case.stage)}}
}
$report=[pscustomobject]@{success=$success;acceptedSelection=$acceptedSelection;checks=$checks;qualifiedConcurrency=$false;scope='Focused identity/value/return, persistent allocation denial, actual root pressure, neutral access, cleanup and unsupported-construct controls; thread captures still require independent gates.';inputs=$inputs;observer=(Get-ArtifactIdentity (Join-Path $PSScriptRoot 'reference_observer.c'));runtimeSource=(Get-ArtifactIdentity (Join-Path $root 'runtime/bootstrap_runtime.c'));cases=$cases;rejections=$rejections;commands=$commands;failure=$(if($success){''}else{$failure})}
$path=Join-Path $run 'report.json';$report | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Output ('Evidence: '+$path)
if(-not $success){throw $failure}
Write-Output 'PASS paired-stage reference identity/value/return, GC/failure/root-pressure/neutral-access/cleanup controls.'
