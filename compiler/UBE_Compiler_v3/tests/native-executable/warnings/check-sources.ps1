param([string]$SelectionPath='', [switch]$DiagnosticOnly, [string]$ReuseReport='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))) {$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/project.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
if($DiagnosticOnly) {
    $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    foreach($identity in @($selection.compiler,$selection.clang,$selection.runtime,$selection.unicodeRuntime,$selection.manifest)) {
        if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw 'Historical tool artifact changed'}
    }
} else {$selection=Get-VerifiedBootstrapSelection $SelectionPath}
$run=Join-Path $root ('bootstrap/out/native-warning-sources/'+[guid]::NewGuid().ToString('N'))
$project=Join-Path $run 'project';$null=[IO.Directory]::CreateDirectory($project)
$utf8=[Text.UTF8Encoding]::new($false);$inputs=@();$commands=@();$checks=@();$success=$false;$failure=$null
$base=Join-Path $root 'compiler/UBE_Compiler_v3';$production=Join-Path $base 'UBE_Compiler_v3.UBE'
$lines=@('UBE-Project 1','Name = "NativeWarningSourceFixture"','Kind = "Exe"','Startup = "Main"');$paths=@()
foreach($line in [IO.File]::ReadAllLines($production)){if($line -match '^Source = "([^"]+)"$'){$paths+=Join-Path $base $Matches[1]}}
$dependency=Join-Path $base 'src/NativeDependencies.bas';if($paths -notcontains $dependency){throw 'Production manifest omits NativeDependencies'}
foreach($path in $paths) {
    $name=Split-Path $path -Leaf;$text=[IO.File]::ReadAllText($path)
    if($name -ceq 'Main.bas'){$text=[regex]::Replace($text,'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','')}
    [IO.File]::WriteAllText((Join-Path $project $name),$text,$utf8);$lines+='Source = "'+$name+'"';$inputs+=Get-ArtifactIdentity $path
}
$wholeEntry=Join-Path $base 'tests/semantic/native/whole/Entry.bas'
$text=[regex]::Replace([IO.File]::ReadAllText($wholeEntry),'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','')
[IO.File]::WriteAllText((Join-Path $project 'CheckedSourceFixture.bas'),$text,$utf8);$lines+='Source = "CheckedSourceFixture.bas"'
[IO.File]::Copy((Join-Path $PSScriptRoot 'SourceEntry.bas'),(Join-Path $project 'Entry.bas'));$lines+='Source = "Entry.bas"'
$core=Join-Path $root 'std-lib/UBECore.UBE'
$relative=[Uri]::UnescapeDataString(([Uri]($project.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$core).ToString());$lines+='Reference = "'+$relative+'"'
$manifest=Join-Path $project 'Graph.UBE';[IO.File]::WriteAllLines($manifest,$lines,$utf8)
$sources=@(Get-FoundationProjectSources $manifest);$names=@{};$types=@{};$classes=@();$ordinal=0
foreach($source in $sources) {
    $text=[IO.File]::ReadAllText($source)
    if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=$Matches[1]}
    foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)')) {
        $name=$m.Groups[1].Value;if($names.ContainsKey($name)){throw "Duplicate name $name"};$names[$name]='ube.p'+$ordinal;++$ordinal
    }
}
$ordinal=0;foreach($name in $classes){$types[$name]='%ube.type.'+$ordinal;++$ordinal}
foreach($source in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)')){$types[$m.Groups[1].Value]='%ube.type.'+$ordinal;++$ordinal}}
$mapping=[pscustomobject]@{procedures=$names;types=$types}
$inputs+=@($sources|ForEach-Object {Get-ArtifactIdentity $_})
$inputs+=@($production,$core,$wholeEntry,$PSCommandPath,(Join-Path $PSScriptRoot 'SourceEntry.bas'),(Join-Path $PSScriptRoot 'source-probe.c')|ForEach-Object {Get-ArtifactIdentity $_})
foreach($path in @('std-lib/tests/file-output/native.c','bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/error_support.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c')){$inputs+=Get-ArtifactIdentity (Join-Path $root $path)}
function Run([string]$File,[string[]]$Arguments,[int]$Timeout=180,[string]$Directory=$root) {
    $r=Invoke-BoundedProcess $File $Arguments $Directory $Timeout;$script:commands+=@($r)
    if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r
}

$casePath=Join-Path $PSScriptRoot 'source-cases.json';$inputs+=Get-ArtifactIdentity $casePath
$caseData=Get-Content -LiteralPath $casePath -Raw|ConvertFrom-Json
$header=[Text.StringBuilder]::new();$null=$header.AppendLine('static const struct source_case source_cases[] = {')
foreach($case in $caseData.cases) {
    $dir=Join-Path $run $case.name;$null=[IO.Directory]::CreateDirectory($dir)
    $sourceLines=@('UBE-Project 1','Name = "WarningSourceFixture"','Kind = "Exe"','Startup = "Main"')
    foreach($source in $case.sources) {$name=$source.name+'.bas';[IO.File]::WriteAllText((Join-Path $dir $name),$source.text,$utf8);$sourceLines+='Source = "'+$name+'"'}
    $path=Join-Path $dir 'WarningSourceFixture.UBE';[IO.File]::WriteAllText($path,($sourceLines -join "`n")+"`n",$utf8)
    $edgeText=@($case.dependencies|ForEach-Object {'{'+($_.from,$_.to,$_.source,$_.first,$_.last -join ',')+'}'}) -join ','
    $warningText=@($case.warnings|ForEach-Object {'{'+($_.code,$_.source,$_.first,$_.last,$_.smallestModule -join ',')+'}'}) -join ','
    if(-not $edgeText){$edgeText='{0}'};if(-not $warningText){$warningText='{0}'}
    $cPath='"'+$path.Replace('\','/').Replace('"','\"')+'"'
    $scale=0;if($case.PSObject.Properties['scale']){$scale=$case.scale}
    $rejection='0,0,0,0';if($case.PSObject.Properties['rejection']){$rejection=$case.rejection.code,$case.rejection.source,$case.rejection.first,$case.rejection.last -join ','}
    $null=$header.AppendLine('{'+$cPath+','+$case.sources.Count+','+$case.dependencies.Count+','+$case.warnings.Count+',{'+$edgeText+'},{'+$warningText+'},'+$scale+','+$rejection+'},')
}
$null=$header.AppendLine('};');[IO.File]::WriteAllText((Join-Path $run 'source-cases.h'),$header.ToString(),$utf8)
try {
    $reuse=$null;$reuseIdentity=$null
    if($ReuseReport) {
        if(-not $DiagnosticOnly){throw 'Retained compilation reuse is diagnostic-only'}
        $reuseIdentity=Get-ArtifactIdentity $ReuseReport;$inputs+=$reuseIdentity
        $reuse=Get-Content -LiteralPath $reuseIdentity.path -Raw|ConvertFrom-Json
        if(-not $reuse.success -or $reuse.acceptedSelection.compiler.sha256 -cne $selection.compiler.sha256 -or $reuse.acceptedSelection.manifest.sha256 -cne $selection.manifest.sha256){throw 'Retained compilation uses a different or unsuccessful tool cohort'}
        $oldManifest=Join-Path (Split-Path $reuseIdentity.path -Parent) 'project/Graph.UBE'
        $oldManifestIdentity=Get-ArtifactIdentity $oldManifest
        $recordedManifest=@($reuse.artifacts|Where-Object path -CEQ $oldManifestIdentity.path)
        if($recordedManifest.Count -ne 1 -or $recordedManifest[0].sha256 -cne $oldManifestIdentity.sha256 -or (Get-ArtifactIdentity $manifest).sha256 -cne $oldManifestIdentity.sha256){throw 'Retained compilation manifest differs'}
        $oldSources=@(Get-FoundationProjectSources $oldManifest)
        if($oldSources.Count -ne $sources.Count){throw 'Retained compilation has a different source list'}
        for($i=0;$i -lt $sources.Count;++$i) {
            $old=Get-ArtifactIdentity $oldSources[$i];$new=Get-ArtifactIdentity $sources[$i]
            $recorded=@($reuse.inputs|Where-Object path -CEQ $old.path)
            if($recorded.Count -eq 0 -or @($recorded|Where-Object sha256 -CNE $old.sha256).Count -ne 0 -or $old.sha256 -cne $new.sha256){throw ('Retained compiled source differs: '+$sources[$i])}
        }
    }
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path);$prior=''
    for($stage=0;$stage -lt 2;++$stage) {
        $raw=Join-Path $run ('stage'+$stage+'.ll')
        if($reuse) {
            $oldRaw=@($reuse.checks|Where-Object stage -EQ ($stage+1))[0].raw
            if((Get-ArtifactIdentity $oldRaw.path).sha256 -cne $oldRaw.sha256){throw 'Retained LLVM artifact changed'}
            [IO.File]::Copy($oldRaw.path,$raw)
        } else {$null=Run $stages[$stage] @($manifest,$raw) 900}
        $identity=Get-ArtifactIdentity $raw;if($prior -and $prior -cne $identity.sha256){throw 'Source-warning LLVM differs across stages'};$prior=$identity.sha256
        $ir=[IO.File]::ReadAllText($raw)
        $null=Assert-FoundationRecord $ir $mapping 'NativeDependencies' ('ptr, ptr, ptr, ptr, '+$types.NativeTraversal+', i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32')
        $null=Assert-FoundationRecord $ir $mapping 'NativeDependencyProcedure' 'i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeDependencyFormal' 'i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeDependencyEdge' 'i32, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeWarningGraph' ('ptr, ptr, ptr, ptr, '+$types.GraphComponents+', i32, i32, i32, i32, i32, i32, i32, i32, i32')
        $adapter=[Text.StringBuilder]::new()
        foreach($b in @(@('source_check','CheckNativeWarningProject','ptr,i32,ptr,ptr'),@('source_declarations','PrepareWarningDeclarations','ptr,ptr,ptr'),@('source_release_declarations','TryDisposeNativeDeclarations','ptr,ptr'),@('source_discover','TryDiscoverNativeWarnings','ptr,ptr,ptr,ptr,ptr'),@('source_dispose','TryDisposeNativeDependencies','ptr,ptr'),@('warning_begin','TryBeginNativeWarnings','ptr,i32,ptr,ptr,ptr,ptr'),@('warning_finish','TryFinishNativeWarnings','ptr,ptr,ptr,ptr,ptr'),@('warning_dispose','TryDisposeNativeWarnings','ptr,ptr,ptr'),@('source_cancel','TryMakeStatementCancellation','ptr'))) {
            Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] 'i1' $b[2]
        }
        $defaults=Get-FoundationDefinition $ir $mapping 'DefaultNativeLimits' 'void' 'ptr'
        $null=$adapter.AppendLine("define void @source_defaults(ptr %p) {`n call void @"+$defaults+"(ptr %p)`n ret void`n}")
        $visit=Get-FoundationDefinition $ir $mapping 'TryVisitNativeIndex' 'i1' 'ptr,ptr,ptr,ptr'
        $ir=$ir.Replace('define i1 @'+$visit+'(', 'define i1 @source_visit_body(')
        $null=$adapter.AppendLine("declare void @source_visit_event()`ndefine i1 @"+$visit+"(ptr %l, ptr %u, ptr %c, ptr %f) {`n call void @source_visit_event()`n %ok = call i1 @source_visit_body(ptr %l, ptr %u, ptr %c, ptr %f)`n ret i1 %ok`n}")
        $component=Get-FoundationDefinition $ir $mapping 'TryGraphComponentTransition' 'i1' 'ptr,ptr,i32,ptr,ptr'
        $ir=$ir.Replace('define i1 @'+$component+'(', 'define i1 @source_component_body(')
        $null=$adapter.AppendLine("declare void @source_component_event(ptr)`ndefine i1 @"+$component+"(ptr %s, ptr %m, i32 %n, ptr %p, ptr %f) {`n call void @source_component_event(ptr %s)`n %ok = call i1 @source_component_body(ptr %s, ptr %m, i32 %n, ptr %p, ptr %f)`n ret i1 %ok`n}")
        $cursor=Get-FoundationDefinition $ir $mapping 'TryNextNativeTraversal' 'i1' 'ptr,ptr,i32,ptr,ptr,ptr,ptr,ptr'
        $ir=$ir.Replace('define i1 @'+$cursor+'(', 'define i1 @source_cursor_body(')
        $null=$adapter.AppendLine("declare void @source_cursor_event(ptr, i32)`ndefine i1 @"+$cursor+"(ptr %s, ptr %v, i32 %n, ptr %l, ptr %u, ptr %c, ptr %e, ptr %f) {`n %ok = call i1 @source_cursor_body(ptr %s, ptr %v, i32 %n, ptr %l, ptr %u, ptr %c, ptr %e, ptr %f)`n %wide = zext i1 %ok to i32`n call void @source_cursor_event(ptr %e, i32 %wide)`n ret i1 %ok`n}")
        $null=$adapter.AppendLine('declare void @source_dependency_event(ptr)')
        foreach($b in @(@('TryDependencySeed','ptr,i32,ptr','ptr %s, i32 %n, ptr %w'),@('TryDependencyProcedure','ptr,ptr,i32,ptr','ptr %s, ptr %t, i32 %n, ptr %w'))) {
            $symbol=Get-FoundationDefinition $ir $mapping $b[0] 'i1' $b[1];$body='source_'+$b[0]+'_body'
            $ir=$ir.Replace('define i1 @'+$symbol+'(', 'define i1 @'+$body+'(')
            $null=$adapter.AppendLine('define i1 @'+$symbol+'('+$b[2]+") {`n %ok = call i1 @"+$body+'('+$b[2]+")`n call void @source_dependency_event(ptr %s)`n ret i1 %ok`n}")
        }
        $adapted=Join-Path $run ('stage'+$stage+'-adapter.ll');[IO.File]::WriteAllText($adapted,[regex]::Replace($ir,'(?m)^define i32 @main\(' ,'define i32 @source_unused_main(')+"`n"+$adapter.ToString(),$utf8)
        $object=Join-Path $run ('stage'+$stage+'.o');$null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-c',$adapted,'-o',$object) 300
        foreach($control in @('','WRONG_SOURCE_WITNESS_CONTROL','OMIT_SOURCE_VISIT_CONTROL')) {
            $exe=Join-Path $run ('stage'+$stage+'-'+$control+'.exe');$args=@('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$run,$object,(Join-Path $PSScriptRoot 'source-probe.c'),$selection.unicodeRuntime.path,'-o',$exe)
            if($control){$args+=@('-D'+$control)};$null=Run $selection.clang.path $args 300
            $r=Invoke-BoundedProcess $exe @() $run 180;$commands+=@($r)
            if($control){$witness='expected';if($control -ceq 'OMIT_SOURCE_VISIT_CONTROL'){$witness='observed'};if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch $witness){throw 'Source-warning negative control not rejected'}}
            else {if($r.timedOut -or $r.exit -ne 0 -or $r.stderr -cne '' -or $r.stdout -notmatch '^(?:METRIC source-scale n=(?:2|4|8) work=[0-9]+ payload=[0-9]+\n)*PASS checked warning sources [1-9][0-9]* assertions\n$'){throw ($r|ConvertTo-Json -Compress)}}
            $checks+=@([pscustomobject]@{assertion=('Checked-source dependencies/witnesses/resources or negative control: '+$control);stage=$stage+1;passed=$true;raw=$identity;output=$r.stdout;error=$r.stderr})
        }
    }
    foreach($id in $inputs){if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw ('Warning-source input changed: '+$id.path)}}
    $success=$true
} catch {$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;diagnosticOnly=$DiagnosticOnly.IsPresent;reusedCompilation=$reuseIdentity;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Checked-source discovery and conservative ByRef propagation. Diagnostic reuse validates the complete ordered compiled-source vector and raw artifact identities. No CLI/IDE delivery or runtime initialization qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}

