param([string]$SelectionPath='', [switch]$DiagnosticOnly)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
if($DiagnosticOnly) {
    $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    foreach($id in @($selection.compiler,$selection.clang,$selection.runtime,$selection.unicodeRuntime,$selection.manifest)) {
        if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw 'Historical tool artifact changed'}
    }
} else {$selection=Get-VerifiedBootstrapSelection $SelectionPath}
$run=Join-Path $root ('bootstrap/out/graph-components/'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run);$utf8=[Text.UTF8Encoding]::new($false)
$inputs=@();$commands=@();$checks=@();$success=$false;$failure=$null
$source=Join-Path $root 'std-lib/src/portable/GraphComponents.bas'
$entry=Join-Path $PSScriptRoot 'Entry.bas';$probe=Join-Path $PSScriptRoot 'probe.c'
$sources=@($source,$entry);$lines=@('UBE-Project 1','Name = "GraphComponentFixture"','Kind = "Exe"','Startup = "Main"')
$names=@{};$types=@{};$ordinal=0;$typeOrdinal=0
foreach($path in $sources) {
    $name=Split-Path $path -Leaf;[IO.File]::Copy($path,(Join-Path $run $name));$lines+='Source = "'+$name+'"'
    $text=[IO.File]::ReadAllText($path)
    foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)')){$names[$m.Groups[1].Value]='ube.p'+$ordinal;++$ordinal}
    foreach($m in [regex]::Matches($text,'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)')){$types[$m.Groups[1].Value]='%ube.type.'+$typeOrdinal;++$typeOrdinal}
}
$mapping=[pscustomobject]@{procedures=$names;types=$types}
$manifest=Join-Path $run 'GraphComponents.UBE';[IO.File]::WriteAllLines($manifest,$lines,$utf8)
foreach($path in @($source,$entry,$probe,$PSCommandPath,(Join-Path $root 'std-lib/GRAPH-COMPONENTS-CONTRACT.md'),(Join-Path $root 'std-lib/tests/file-output/native.c'),(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1'))){$inputs+=Get-ArtifactIdentity $path}
foreach($path in @('bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/error_support.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c')){$inputs+=Get-ArtifactIdentity (Join-Path $root $path)}
function Run([string]$File,[string[]]$Arguments,[int]$Timeout=120) {
    $r=Invoke-BoundedProcess $File $Arguments $run $Timeout;$script:commands+=@($r)
    if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r
}
try {
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path);$prior=''
    for($stage=0;$stage -lt 2;++$stage) {
        $raw=Join-Path $run ('stage'+$stage+'.ll');$null=Run $stages[$stage] @($manifest,$raw)
        $identity=Get-ArtifactIdentity $raw;if($prior -and $prior -cne $identity.sha256){throw 'Graph component LLVM differs across stages'};$prior=$identity.sha256
        $ir=[IO.File]::ReadAllText($raw)
        $null=Assert-FoundationRecord $ir $mapping 'GraphComponentSlot' 'i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'GraphComponents' 'ptr, i32, i32, i32, i32, i32, i32, i32'
        $adapter=[Text.StringBuilder]::new()
        foreach($binding in @(@('components_begin','TryBeginGraphComponents','ptr,ptr,i32,ptr'),@('components_advance','TryAdvanceGraphComponents','ptr,ptr,i32,i32,ptr,ptr,ptr,ptr,ptr'),@('components_read','TryReadGraphComponent','ptr,i32,ptr,ptr'),@('components_dispose','TryDisposeGraphComponents','ptr,ptr'))) {
            Add-FoundationBinding $adapter $ir $mapping $binding[0] $binding[1] 'i1' $binding[2]
        }

        $transition=Get-FoundationDefinition $ir $mapping 'TryGraphComponentTransition' 'i1' 'ptr,ptr,i32,ptr,ptr'
        $body='graph_component_transition_body'
        $ir=$ir.Replace('define i1 @'+$transition+'(', 'define i1 @'+$body+'(')
        $null=$adapter.AppendLine('declare void @graph_transition_event(ptr)')
        $null=$adapter.AppendLine('define i1 @'+$transition+'(ptr %s, ptr %m, i32 %limit, ptr %peak, ptr %f) {')
        $null=$adapter.AppendLine(' call void @graph_transition_event(ptr %s)')
        $null=$adapter.AppendLine(' %ok = call i1 @'+$body+'(ptr %s, ptr %m, i32 %limit, ptr %peak, ptr %f)')
        $null=$adapter.AppendLine(' ret i1 %ok')
        $null=$adapter.AppendLine('}')
        $adapted=Join-Path $run ('stage'+$stage+'-adapter.ll');[IO.File]::WriteAllText($adapted,$ir.Replace('define i32 @main(','define i32 @components_unused_main(')+"`n"+$adapter.ToString(),$utf8)
        foreach($control in @('','WRONG_COMPONENT_CONTROL','OMIT_TRANSITION_CONTROL')) {
            $exe=Join-Path $run ('stage'+$stage+'-'+$control+'.exe');$args=@('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,$adapted,$probe,$selection.unicodeRuntime.path,'-o',$exe)
            if($control){$args+=@('-D'+$control)};$null=Run $selection.clang.path $args
            $r=Invoke-BoundedProcess $exe @() $run 180;$commands+=@($r)
            if($control) {
                $witness='relation\(source,n,labels\[0\]\)';if($control -ceq 'OMIT_TRANSITION_CONTROL'){$witness='transition_events-before_events'}
                if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -notmatch $witness){throw 'Graph component corruption was not rejected at its independent witness'}
            } else {
                if($r.timedOut -or $r.exit -ne 0 -or $r.stderr -cne '' -or $r.stdout -notmatch '^PASS graph components [1-9][0-9]* assertions\n$'){throw ($r|ConvertTo-Json -Compress)}
            }
            $checks+=@([pscustomobject]@{stage=$stage+1;control=$control;assertion=('Directed components, exact work/pending/ownership/failure oracle or negative control: '+$control);passed=$true;raw=$identity;output=$r.stdout;error=$r.stderr})
        }
    }
    foreach($id in $inputs){if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw ('Graph component input changed: '+$id.path)}}
    $success=$true
} catch {$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;diagnosticOnly=$DiagnosticOnly.IsPresent;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Ordinary UBE iterative graph components; independent reachability, actual work/copy/allocation, ownership and failure oracles. No compiler warning extraction or emission qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
