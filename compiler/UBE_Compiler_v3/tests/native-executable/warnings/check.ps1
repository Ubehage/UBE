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
$run=Join-Path $root ('bootstrap/out/native-warnings/'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run);$utf8=[Text.UTF8Encoding]::new($false)
$inputs=@();$commands=@();$checks=@();$success=$false;$failure=$null
$paths=@('compiler/UBE_Compiler_v3/src/SourceCancellation.cls','compiler/UBE_Compiler_v3/src/NativeResources.bas','compiler/UBE_Compiler_v3/src/NativeOutput.bas','compiler/UBE_Compiler_v3/src/NativeWarnings.bas','compiler/UBE_Compiler_v3/tests/native-executable/warnings/Entry.bas')
$lines=@('UBE-Project 1','Name = "NativeWarningFixture"','Kind = "Exe"','Startup = "Main"')
foreach($path in $paths){$name=Split-Path $path -Leaf;[IO.File]::Copy((Join-Path $root $path),(Join-Path $run $name));$lines+='Source = "'+$name+'"';$inputs+=Get-ArtifactIdentity (Join-Path $root $path)}
# Retain the existing exact scalar visit helper, without a second implementation.
$graphSource=Join-Path $root 'compiler/UBE_Compiler_v3/src/NativeGraph.bas';$inputs+=Get-ArtifactIdentity $graphSource
$visit=[regex]::Match([IO.File]::ReadAllText($graphSource),'(?ms)^Function TryVisitNativeIndex\([^\r\n]+\) As Boolean\r?\n.*?^End Function')
if(-not $visit.Success){throw 'Native visit helper missing'}
$visitLines=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "NativeWarningVisitFixture"',$visit.Value)
[IO.File]::WriteAllLines((Join-Path $run 'Visit.bas'),$visitLines,$utf8);$lines+='Source = "Visit.bas"'
$core=Join-Path $root 'std-lib/UBECore.UBE';$relative=[Uri]::UnescapeDataString(([Uri]($run.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$core).ToString());$lines+='Reference = "'+$relative+'"'
$manifest=Join-Path $run 'Warnings.UBE';[IO.File]::WriteAllLines($manifest,$lines,$utf8)
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
foreach($path in @($probe,$PSCommandPath,$core,(Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-WARNING-IMPLEMENTATION.md'),(Join-Path $root 'std-lib/GRAPH-COMPONENTS-CONTRACT.md'),(Join-Path $root 'std-lib/tests/file-output/native.c'),(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1'))){$inputs+=Get-ArtifactIdentity $path}
foreach($path in @('bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/error_support.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c')){$inputs+=Get-ArtifactIdentity (Join-Path $root $path)}
function Run([string]$File,[string[]]$Arguments,[int]$Timeout=180) {
    $r=Invoke-BoundedProcess $File $Arguments $run $Timeout;$script:commands+=@($r)
    if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r
}
try {
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path);$prior=''
    for($stage=0;$stage -lt 2;++$stage) {
        $raw=Join-Path $run ('stage'+$stage+'.ll');$null=Run $stages[$stage] @($manifest,$raw)
        $identity=Get-ArtifactIdentity $raw;if($prior -and $prior -cne $identity.sha256){throw 'Native warning LLVM differs across stages'};$prior=$identity.sha256
        $ir=[IO.File]::ReadAllText($raw)
        $null=Assert-FoundationRecord $ir $mapping 'GraphComponents' 'ptr, i32, i32, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeWarningSpan' 'i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeInitializationWarning' 'i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeWarningGraph' ('ptr, ptr, ptr, ptr, '+$types.GraphComponents+', i32, i32, i32, i32, i32, i32, i32, i32, i32')
        $null=Assert-FoundationRecord $ir $mapping 'NativeLimits' 'i64, i64, i64, i64, i64, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeUsage' 'i64, i64, i64, i64, i64, i64, i64, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'SourceCancellation' 'i1'
        $adapter=[Text.StringBuilder]::new()
        foreach($binding in @(@('warning_begin','TryBeginNativeWarnings','ptr,i32,ptr,ptr,ptr,ptr'),@('warning_add','TryAddNativeWarningDependency','ptr,i32,i32,i32,i32,i32,ptr,ptr,ptr,ptr'),@('warning_finish','TryFinishNativeWarnings','ptr,ptr,ptr,ptr,ptr'),@('warning_read','TryReadNativeInitializationWarning','ptr,i32,ptr,ptr'),@('warning_dispose','TryDisposeNativeWarnings','ptr,ptr,ptr'),@('warning_cancel','TryMakeWarningCancellation','ptr'))) {
            Add-FoundationBinding $adapter $ir $mapping $binding[0] $binding[1] 'i1' $binding[2]
        }
        $defaults=Get-FoundationDefinition $ir $mapping 'DefaultNativeLimits' 'void' 'ptr'
        $null=$adapter.AppendLine("define void @warning_defaults(ptr %p) {`n call void @"+$defaults+"(ptr %p)`n ret void`n}")
        $transition=Get-FoundationDefinition $ir $mapping 'TryGraphComponentTransition' 'i1' 'ptr,ptr,i32,ptr,ptr'
        $ir=$ir.Replace('define i1 @'+$transition+'(', 'define i1 @warning_component_transition_body(')
        $null=$adapter.AppendLine('declare void @warning_component_event(ptr)')
        $null=$adapter.AppendLine('define i1 @'+$transition+'(ptr %s, ptr %m, i32 %limit, ptr %peak, ptr %f) {')
        $null=$adapter.AppendLine(' call void @warning_component_event(ptr %s)')
        $null=$adapter.AppendLine(' %ok = call i1 @warning_component_transition_body(ptr %s, ptr %m, i32 %limit, ptr %peak, ptr %f)')
        $null=$adapter.AppendLine(' ret i1 %ok')
        $null=$adapter.AppendLine('}')
        $visitSymbol=Get-FoundationDefinition $ir $mapping 'TryVisitNativeIndex' 'i1' 'ptr,ptr,ptr,ptr'
        $ir=$ir.Replace('define i1 @'+$visitSymbol+'(', 'define i1 @warning_index_visit_body(')
        $null=$adapter.AppendLine('declare void @warning_visit_event()')
        $null=$adapter.AppendLine('define i1 @'+$visitSymbol+'(ptr %l, ptr %u, ptr %c, ptr %f) {')
        $null=$adapter.AppendLine(' call void @warning_visit_event()')
        $null=$adapter.AppendLine(' %ok = call i1 @warning_index_visit_body(ptr %l, ptr %u, ptr %c, ptr %f)')
        $null=$adapter.AppendLine(' ret i1 %ok')
        $null=$adapter.AppendLine('}')
        $adapted=Join-Path $run ('stage'+$stage+'-adapter.ll');[IO.File]::WriteAllText($adapted,$ir.Replace('define i32 @main(','define i32 @warning_unused_main(')+"`n"+$adapter.ToString(),$utf8)
        foreach($control in @('','WRONG_WITNESS_CONTROL','OMIT_VISIT_CONTROL')) {
            $exe=Join-Path $run ('stage'+$stage+'-'+$control+'.exe');$args=@('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,$adapted,$probe,$selection.unicodeRuntime.path,'-o',$exe)
            if($control){$args+=@('-D'+$control)};$null=Run $selection.clang.path $args
            $r=Invoke-BoundedProcess $exe @() $run 180;$commands+=@($r)
            if($control) {
                $witness='expected';if($control -ceq 'OMIT_VISIT_CONTROL'){$witness='visit_events'}
                if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -notmatch $witness){throw 'Warning corruption was not rejected at its independent witness'}
            } else {
                if($r.timedOut -or $r.exit -ne 0 -or $r.stderr -cne '' -or $r.stdout -notmatch '^PASS native warnings [1-9][0-9]* assertions\n$'){throw ($r|ConvertTo-Json -Compress)}
            }
            $checks+=@([pscustomobject]@{stage=$stage+1;control=$control;assertion=('Warning matrix/witness/resource/failure oracle or negative control: '+$control);passed=$true;raw=$identity;output=$r.stdout;error=$r.stderr})
        }
    }
    foreach($id in $inputs){if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw ('Native warning input changed: '+$id.path)}}
    $success=$true
} catch {$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;diagnosticOnly=$DiagnosticOnly.IsPresent;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Compiler dependency matrix, component witnesses and canonical warning records under actual shared budgets. No checked-source dependency extraction, CLI delivery or runtime initialization qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
