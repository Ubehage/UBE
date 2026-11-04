param([string]$SelectionPath='', [switch]$DiagnosticOnly, [string]$ReuseCompilationReport='')
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
$run=Join-Path $root ('bootstrap/out/native-graph/'+[guid]::NewGuid().ToString('N'))
$project=Join-Path $run 'project';$null=[IO.Directory]::CreateDirectory($project)
$utf8=[Text.UTF8Encoding]::new($false);$inputs=@();$commands=@();$checks=@();$success=$false;$failure=$null
$base=Join-Path $root 'compiler/UBE_Compiler_v3';$production=Join-Path $base 'UBE_Compiler_v3.UBE'
$lines=@('UBE-Project 1','Name = "NativeGraphFixture"','Kind = "Exe"','Startup = "Main"');$paths=@()
foreach($line in [IO.File]::ReadAllLines($production)){if($line -match '^Source = "([^"]+)"$'){$paths+=Join-Path $base $Matches[1]}}
foreach($path in $paths) {
    $name=Split-Path $path -Leaf;$text=[IO.File]::ReadAllText($path)
    if($name -ceq 'Main.bas'){$text=[regex]::Replace($text,'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','')}
    [IO.File]::WriteAllText((Join-Path $project $name),$text,$utf8);$lines+='Source = "'+$name+'"';$inputs+=Get-ArtifactIdentity $path
}
$wholeEntry=Join-Path $base 'tests/semantic/native/whole/Entry.bas'
$text=[regex]::Replace([IO.File]::ReadAllText($wholeEntry),'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','')
[IO.File]::WriteAllText((Join-Path $project 'CheckedSourceFixture.bas'),$text,$utf8);$lines+='Source = "CheckedSourceFixture.bas"'
$projectEntry=Join-Path $base 'tests/native-executable/warnings/SourceEntry.bas'
$text=[regex]::Replace([IO.File]::ReadAllText($projectEntry),'(?ms)^Function Main\(\) As Long\r?\n.*?^End Function\r?\n?','')
[IO.File]::WriteAllText((Join-Path $project 'CheckedProjectFixture.bas'),$text,$utf8);$lines+='Source = "CheckedProjectFixture.bas"';$inputs+=Get-ArtifactIdentity $projectEntry
[IO.File]::Copy((Join-Path $PSScriptRoot 'Entry.bas'),(Join-Path $project 'Entry.bas'));$lines+='Source = "Entry.bas"'
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
$inputs+=@($production,$core,$wholeEntry,$PSCommandPath,(Join-Path $PSScriptRoot 'Entry.bas'),(Join-Path $PSScriptRoot 'probe.c')|ForEach-Object {Get-ArtifactIdentity $_})
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'conversion-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'arithmetic-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'bodies.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'body-require.c')
foreach($name in @('guard-bodies.c','guard-observer.c','guards.ps1','guard-project/Guards.UBE','guard-project/A.bas','guard-project/B.bas','guard-project/C.bas','guard-project/GuardsReference.UBE','guard-project/UBECore.UBE','schedule-observer.c','module-bodies.c','modules.ps1','entry-bodies.c','entry-observer.c','entries.ps1','expectations.c','expectations.ps1')){$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot $name)}
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'body-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'native-bodies.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'native-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'call-bodies.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'call-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'initializer-bodies.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'initializer-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'owner-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'owners.ps1')
foreach($path in @('std-lib/tests/file-output/native.c','bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/error_support.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c')){$inputs+=Get-ArtifactIdentity (Join-Path $root $path)}
$nativeNm=Join-Path (Split-Path $selection.clang.path -Parent) 'llvm-nm.exe'
$inputs+=Get-ArtifactIdentity $nativeNm
function Run([string]$File,[string[]]$Arguments,[int]$Timeout=180,[string]$Directory=$root) {
    $r=Invoke-BoundedProcess $File $Arguments $Directory $Timeout;$script:commands+=@($r)
    if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r
}
$reusedCompilations=@();$reuse=$null
if($ReuseCompilationReport) {
    $ReuseCompilationReport=[IO.Path]::GetFullPath($ReuseCompilationReport);$reuse=Get-Content -LiteralPath $ReuseCompilationReport -Raw|ConvertFrom-Json
    if($reuse.acceptedSelection.compiler.sha256 -cne $selection.compiler.sha256 -or $reuse.acceptedSelection.manifest.sha256 -cne $selection.manifest.sha256){throw 'Retained compilation uses another compiler cohort'}
    $oldManifest=Join-Path (Split-Path $ReuseCompilationReport -Parent) 'project/Graph.UBE'
    $oldManifestIdentity=Get-ArtifactIdentity $oldManifest;$expected=@($reuse.artifacts|Where-Object path -EQ $oldManifest)
    if($expected.Count -ne 1 -or $expected[0].sha256 -cne $oldManifestIdentity.sha256 -or (Get-ArtifactIdentity $manifest).sha256 -cne $oldManifestIdentity.sha256){throw 'Retained compiler fixture manifest differs'}
    $oldSources=@(Get-FoundationProjectSources $oldManifest)
    if($oldSources.Count -ne $sources.Count){throw 'Retained compiler source count differs'}
    for($i=0;$i -lt $sources.Count;++$i) {
        $old=Get-ArtifactIdentity $oldSources[$i];$expected=@($reuse.inputs|Where-Object path -EQ $old.path)
        if($expected.Count -ne 1 -or $expected[0].sha256 -cne $old.sha256 -or (Get-ArtifactIdentity $sources[$i]).sha256 -cne $old.sha256){throw ('Retained compiler source differs: '+$old.path)}
        $inputs+=$old
    }
    $inputs+=@((Get-ArtifactIdentity $ReuseCompilationReport),$oldManifestIdentity)
}
try {
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path);$prior=''
    for($stage=0;$stage -lt 2;++$stage) {
        $directory=Join-Path $run ('stage'+$stage);$null=[IO.Directory]::CreateDirectory($directory)
        $raw=Join-Path $directory 'raw.ll';$reused=$false
        if($null -ne $reuse) {
            $oldRaw=Join-Path (Split-Path $ReuseCompilationReport -Parent) ('stage'+$stage+'/raw.ll')
            if([IO.File]::Exists($oldRaw)) {
                $old=Get-ArtifactIdentity $oldRaw;$expected=@($reuse.artifacts|Where-Object path -EQ $old.path)
                $completed=@($reuse.commands|Where-Object {$_.file -eq $stages[$stage] -and -not $_.timedOut -and $_.exit -eq 0 -and $_.arguments.Count -eq 2 -and $_.arguments[0] -eq $oldManifest -and $_.arguments[1] -eq $oldRaw})
                $bootstrap=Get-Content -LiteralPath $selection.manifest.path -Raw|ConvertFrom-Json;$compilerIdentity=Get-ArtifactIdentity $stages[$stage];$compilerExpected=@($bootstrap.artifacts|Where-Object path -EQ $compilerIdentity.path)
                if($expected.Count -ne 1 -or $expected[0].sha256 -cne $old.sha256 -or $completed.Count -ne 1 -or $compilerExpected.Count -ne 1 -or $compilerExpected[0].sha256 -cne $compilerIdentity.sha256){throw 'Retained raw output lacks matching successful compiler provenance'}
                [IO.File]::Copy($oldRaw,$raw);$inputs+=@($old,$compilerIdentity)
                $reusedCompilations+=@([pscustomobject]@{stage=$stage+1;report=(Get-ArtifactIdentity $ReuseCompilationReport);raw=$old;compiler=$compilerIdentity;command=$completed[0]});$reused=$true
            }
        }
        if(-not $reused){$null=Run $stages[$stage] @($manifest,$raw) 900}
        $identity=Get-ArtifactIdentity $raw;if($prior -and $identity.sha256 -cne $prior){throw 'Native graph LLVM differs across stages'};$prior=$identity.sha256
        $ir=[IO.File]::ReadAllText($raw)
        $null=Assert-FoundationRecord $ir $mapping 'NativeGraphPlan' ('ptr, ptr, ptr, '+$types.NativeTraversal+', i32, i32, i32, i32, i32, ptr, i32, i32, i32, ptr, ptr, i32, i32, i32')
        $null=Assert-FoundationRecord $ir $mapping 'NativeTraversal' 'ptr, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeSyntaxLinks' 'i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeNodeLinks' 'i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeArgumentLinks' 'i32, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'BoundNode' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'SemanticFact' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'SemanticResult' 'ptr, ptr, i32'
        $null=Assert-FoundationRecord $ir $mapping 'SemanticModuleResult' ('ptr, i32, ptr, i32, ptr, i32, i32, '+$types.SemanticMetrics)
        $null=Assert-FoundationRecord $ir $mapping 'NativeLLVMWriter' ($types.NativeFailure+', '+$types.NativeLimits+', '+$types.NativeUsage+', '+$types.NativeOutput+', ptr')
        $null=Assert-FoundationRecord $ir $mapping 'NativeOperand' 'i32, i32, i32, i64'
        $null=Assert-FoundationRecord $ir $mapping 'ByteBuffer' 'ptr, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeOutput' ($types.ByteBuffer+', ptr, i32, i32, i32, i32')
        $null=Assert-FoundationRecord $ir $mapping 'NativeFailure' 'i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeLimits' 'i64, i64, i64, i64, i64, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeUsage' 'i64, i64, i64, i64, i64, i64, i64, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeDeclarationTarget' 'i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeDeclarationPlan' 'ptr, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeControlLabels' 'i64, i64, i64, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeBodyState' 'ptr, ptr, i64, i64, i32, i32, i32, i32, i32, i32, i1, i1, i1, i1'
        $null=Assert-FoundationRecord $ir $mapping 'SourceCancellation' 'i1'
        $null=Assert-FoundationRecord $ir $mapping 'NativeExpectedDefinition' ($types.NativeObjectName+', i32, i32, i32, i32, i32, i32, i32, i32')
        $null=Assert-FoundationRecord $ir $mapping 'NativeObjectName' 'i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeExpectedDefinitions' 'ptr, ptr, i32, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeInspection' 'i64, i64, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeInspectionStorage' 'i64, i64, i64'
        $adapter=[Text.StringBuilder]::new()
        Add-FoundationBinding $adapter $ir $mapping 'expected_prepare' 'TryPrepareNativeExpectations' 'i1' 'ptr,ptr,i32,i32,ptr,ptr,ptr,ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'expected_dispose' 'TryDisposeNativeExpectations' 'i1' 'ptr,ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'writer_platform' 'TryEmitNativePlatformSupport' 'i1' 'ptr'
        Add-FoundationBinding $adapter $ir $mapping 'writer_frame_data' 'TryEmitNativeFrameData' 'i1' 'ptr,ptr,i32,i32,i64'
        foreach($default in @(@('expected_inspection_defaults','DefaultNativeInspection'),@('expected_storage_defaults','DefaultNativeInspectionStorage'))) {
            $defaultSymbol=Get-FoundationDefinition $ir $mapping $default[1] 'void' 'ptr'
            $null=$adapter.AppendLine("define void @"+$default[0]+"(ptr %p) {`n call void @"+$defaultSymbol+"(ptr %p)`n ret void`n}")
        }
        foreach($b in @(@('graph_check','CheckNativeGraphSource','ptr,i32,ptr,ptr'),@('graph_plan','PlanNativeGraphModule','ptr,i32,ptr,ptr,ptr,ptr,ptr'),@('graph_dispose','TryDisposeNativeGraph','ptr,ptr,ptr'))) {
            Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] 'i1' $b[2]
        }
        foreach($b in @(@('writer_begin','TryBeginNativeLLVM','ptr'),@('writer_text','TryLLVMText','ptr,ptr'),@('writer_line','TryLLVMLine','ptr,ptr'),@('writer_number','TryLLVMNumber','ptr,i64'),@('writer_identity','TryLLVMIdentity','ptr,ptr'),@('writer_operand','TryLLVMOperand','ptr,ptr'),@('writer_typed','TryLLVMTypedOperand','ptr,ptr'),@('writer_instruction','TryLLVMInstruction','ptr,i32,i32,ptr'),@('writer_snapshot','TrySnapshotNativeLLVM','ptr'),@('writer_dispose','TryDisposeNativeLLVM','ptr'),@('writer_support','TryEmitNativeErrorSupport','ptr'),@('graph_lower','LowerCheckedConversion','ptr,i32,i32,ptr,ptr,ptr,ptr'))) {
            Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] 'i1' $b[2]
        }
        $symbol=Get-FoundationDefinition $ir $mapping 'DefaultNativeLimits' 'void' 'ptr'
        Add-FoundationBinding $adapter $ir $mapping 'graph_operator' 'LowerCheckedOperator' 'i1' 'ptr,i32,i32,ptr,ptr,ptr,ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'writer_overflow' 'TryEmitNativeOverflowDeclarations' 'i1' 'ptr,i32'
        Add-FoundationBinding $adapter $ir $mapping 'graph_declarations' 'PlanCheckedDeclarations' 'i1' 'ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'graph_release_declarations' 'TryDisposeNativeDeclarations' 'i1' 'ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'body_begin' 'TryBeginNativeBodies' 'i1' 'ptr,i32,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'body_dispose' 'TryDisposeNativeBodies' 'i1' 'ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'graph_root' 'TryReadNativeProcedureRoot' 'i1' 'ptr,i32,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'body_initializer' 'EmitCheckedInitializer' 'i1' 'ptr,i32,ptr,ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'body_emit' 'EmitCheckedProcedure' 'i1' 'ptr,i32,i32,ptr,ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'body_module' 'EmitCheckedModule' 'i1' 'ptr,i32,ptr,ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'writer_imports' 'TryEmitNativeImports' 'i1' 'ptr,ptr,i32,i32,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'writer_release' 'TryReleaseNativeSnapshot' 'i1' 'ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'graph_entry' 'EmitCheckedProgramEntry' 'i1' 'ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'writer_process_adapter' 'TryEmitNativeProcessAdapter' 'i1' 'ptr'
        Add-FoundationBinding $adapter $ir $mapping 'graph_schedule' 'EmitCheckedProjectInitialization' 'i1' 'ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'graph_project' 'CheckNativeWarningProject' 'i1' 'ptr,i32,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'writer_initialization' 'TryEmitNativeInitializationSupport' 'i1' 'ptr,i32,i32'
        Add-FoundationBinding $adapter $ir $mapping 'writer_initialization_data' 'TryEmitNativeInitializationData' 'i1' 'ptr,i32'
        Add-FoundationBinding $adapter $ir $mapping 'writer_stack' 'TryEmitNativeStackSupport' 'i1' 'ptr,i32'
        Add-FoundationBinding $adapter $ir $mapping 'writer_storage' 'TryEmitNativeStorage' 'i1' 'ptr,ptr,i32'
        Add-FoundationBinding $adapter $ir $mapping 'body_cancellation' 'TryMakeStatementCancellation' 'i1' 'ptr'
        $null=$adapter.AppendLine("define void @graph_defaults(ptr %p) {`n call void @"+$symbol+"(ptr %p)`n ret void`n}")
        $adapted=Join-Path $directory 'adapter.ll';[IO.File]::WriteAllText($adapted,[regex]::Replace($ir,'(?m)^define i32 @main\(' ,'define i32 @graph_unused_main(')+"`n"+$adapter.ToString(),$utf8)
        $exe=Join-Path $directory 'probe.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-std=c17','-O2','-Wall','-Wextra','-Werror','-I',$root,$adapted,(Join-Path $PSScriptRoot 'probe.c'),$selection.unicodeRuntime.path,'-o',$exe)
        $r=Run $exe @() 180 $directory
        if($r.stderr -cne '' -or $r.stdout -notmatch '^PASS checked native graph [1-9][0-9]* assertions\n$'){throw 'Checked graph oracle did not complete'}
        $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Actual checker graphs, jobs 1/2/4, selected conversions and written versus parameter order';passed=$true;output=$r.stdout;raw=$identity})
        $bodyProbe=Join-Path $directory 'body-probe.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-std=c17','-O2','-Wall','-Wextra','-Werror','-I',$root,$adapted,(Join-Path $PSScriptRoot 'bodies.c'),$selection.unicodeRuntime.path,'-o',$bodyProbe)
        $r=Run $bodyProbe @((Join-Path $PSScriptRoot 'guard-project/Guards.UBE'),(Join-Path $PSScriptRoot 'guard-project/GuardsReference.UBE')) 180 $directory
        if($r.stderr -cne '' -or $r.stdout -notmatch '^PASS checked native bodies [1-9][0-9]* assertions\n$'){throw 'Checked procedure body oracle did not complete'}
        $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Whole checked procedure subtrees, one ordered emission walk, immutable inputs and identical jobs 1/2/4 output';passed=$true;output=$r.stdout})
        foreach($optimization in @('O0','O2')) {
            $native=Join-Path $directory ('checked-conversions-'+$optimization+'.exe')
            $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-x','ir',(Join-Path $directory 'checked-conversions.ll'),'-x','c',(Join-Path $PSScriptRoot 'conversion-observer.c'),'-o',$native)
            $r=Run $native @() 180 $directory
            if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Real checked conversion execution failed'}
            $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Conversions from real checked source emit native code with independent neutral/Err/value observations';optimization=$optimization;passed=$true})
            $native=Join-Path $directory ('checked-arithmetic-'+$optimization+'.exe')
            $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-x','ir',(Join-Path $directory 'checked-arithmetic.ll'),'-x','c',(Join-Path $PSScriptRoot 'arithmetic-observer.c'),'-o',$native)
            $r=Run $native @() 180 $directory
            if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Real checked arithmetic execution failed'}
            $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Actual checked mixed-width operators and operand conversions; independent arithmetic/error/revision observations';optimization=$optimization;passed=$true})
            $native=Join-Path $directory ('bodies-'+$optimization+'.exe')
            $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$directory,'-x','ir',(Join-Path $directory 'bodies.ll'),'-x','c',(Join-Path $PSScriptRoot 'body-observer.c'),'-o',$native)
            $r=Run $native @() 180 $directory
            if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Whole checked procedure execution failed'}
            $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Native whole-procedure values/ByRef effects, While/Exit/ElseIf, nested short circuit and exact Err/revision preservation';optimization=$optimization;passed=$true})
            $native=Join-Path $directory ('native-bodies-'+$optimization+'.exe')
            $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$directory,'-x','ir',(Join-Path $directory 'native-bodies.ll'),'-x','c',(Join-Path $PSScriptRoot 'native-observer.c'),'-o',$native)
            $r=Run $native @() 180 $directory
            if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Checked native representation execution failed'}
            $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Actual checked native Pack/Unpack/equality/ByRef storage and pre-call narrowing; independent ABI/value/Err/revision observer';optimization=$optimization;passed=$true})

            foreach($initializerMode in 0..1) {
                $native=Join-Path $directory ('initializers-'+$optimization+'-'+$initializerMode+'.exe')
                $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror',('-DREFUSE_MODE='+$initializerMode),'-I',$root,'-I',$directory,(Join-Path $directory 'initializer-bodies.ll'),(Join-Path $PSScriptRoot 'initializer-observer.c'),'-o',$native)
                $r=Run $native @() 180 $directory
                if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Checked initializer execution failed'}
                $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Checked initializer written order, neutral reset, fixed ByRef temporaries and recoverable error/call refusal; controlled metadata';optimization=$optimization;mode=$initializerMode;passed=$true})
            }
            foreach($mode in 0..6) {
                $native=Join-Path $directory ('calls-'+$optimization+'-'+$mode+'.exe')
                $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror',('-DREFUSE_MODE='+$mode),'-I',$root,'-I',$directory,'-x','ir',(Join-Path $directory 'call-bodies.ll'),'-x','c',(Join-Path $PSScriptRoot 'call-observer.c'),'-o',$native)
                $r=Invoke-BoundedProcess $native @() $directory 180;$commands+=@($r)
                $expected=0;if($mode -eq 6){$expected=97}
                if($r.timedOut -or $r.exit -ne $expected -or $r.stdout -cne '' -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
                $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Checked ordinary calls: argument order, alias/temporary/default storage, aggregate ABI, neutral refusal and exact Err; controlled metadata only';optimization=$optimization;mode=$mode;passed=$true})
            }
        }
        . (Join-Path $PSScriptRoot 'owners.ps1')
        . (Join-Path $PSScriptRoot 'guards.ps1')
        . (Join-Path $PSScriptRoot 'modules.ps1')
        . (Join-Path $PSScriptRoot 'entries.ps1')
        . (Join-Path $PSScriptRoot 'expectations.ps1')
        $initializerText=[IO.File]::ReadAllText((Join-Path $directory 'initializer-bodies.ll'))
        $initializerHeader=[IO.File]::ReadAllText((Join-Path $directory 'initializer-functions.h'))
        $later=[regex]::Match($initializerHeader,'init_later __asm__\("(ube\.g[0-9]+)"\)')
        if(-not $later.Success){throw 'Initializer reset control target missing'}
        foreach($control in @('reset','default')) {
            $pattern='(?m)^  store i32 0, ptr @'+[regex]::Escape($later.Groups[1].Value)+', align 4\r?\n';$replacement=''
            if($control -eq 'default'){$pattern='(?m)^  store i32 3, ptr (%v[0-9]+), align 8';$replacement='  store i32 4, ptr $1, align 8'}
            if([regex]::Matches($initializerText,$pattern).Count -ne 1){throw 'Initializer control is not unique'}
            $changed=[regex]::Replace($initializerText,$pattern,$replacement)
            $wrong=Join-Path $directory ('wrong-initializer-'+$control+'.ll');[IO.File]::WriteAllText($wrong,$changed,$utf8);$wrongExe=$wrong+'.exe'
            $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-I',$root,'-I',$directory,$wrong,(Join-Path $PSScriptRoot 'initializer-observer.c'),'-o',$wrongExe)
            $r=Invoke-BoundedProcess $wrongExe @() $directory 180;$commands+=@($r)
            if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -notmatch 'initializer oracle'){throw 'Initializer corruption was not rejected'}
            $checks+=@([pscustomobject]@{stage=$stage+1;assertion=('Initializer negative control '+$control);passed=$true})
        }
        $bodyText=[IO.File]::ReadAllText((Join-Path $directory 'bodies.ll'))
        if(-not $bodyText.Contains('phi i1 [ 0,')){throw 'Short-circuit negative control has no target'}
        $wrongIR=Join-Path $directory 'wrong-short-circuit.ll';[IO.File]::WriteAllText($wrongIR,$bodyText.Replace('phi i1 [ 0,','phi i1 [ 1,'),$utf8)
        $wrongExe=Join-Path $directory 'wrong-short-circuit.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-I',$root,'-I',$directory,'-x','ir',$wrongIR,'-x','c',(Join-Path $PSScriptRoot 'body-observer.c'),'-o',$wrongExe)
        $r=Invoke-BoundedProcess $wrongExe @() $directory 180;$commands+=@($r)
        if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -notmatch 'body_short'){throw 'Wrong short-circuit result was not rejected at its native observer'}
        $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Mutated actual short-circuit phi result is rejected by native body observer';passed=$true})
        $nativeText=[IO.File]::ReadAllText((Join-Path $directory 'native-bodies.ll'))
        if(-not $nativeText.Contains('icmp eq i8')){throw 'Native equality negative control has no target'}
        $wrongNativeIR=Join-Path $directory 'wrong-native-equality.ll';[IO.File]::WriteAllText($wrongNativeIR,$nativeText.Replace('icmp eq i8','icmp ne i8'),$utf8)
        $wrongNativeExe=Join-Path $directory 'wrong-native-equality.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-I',$root,'-I',$directory,'-x','ir',$wrongNativeIR,'-x','c',(Join-Path $PSScriptRoot 'native-observer.c'),'-o',$wrongNativeExe)
        $r=Invoke-BoundedProcess $wrongNativeExe @() $directory 180;$commands+=@($r)
        if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -notmatch 'native_equal_byte'){throw 'Wrong native equality was not rejected at its observer'}
        $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Mutated actual native equality predicate is rejected by native representation observer';passed=$true})

        $callText=[IO.File]::ReadAllText((Join-Path $directory 'call-bodies.ll'))
        if(-not $callText.Contains('icmp ule i64 %needed, %remaining')){throw 'Call admission negative control has no target'}
        $wrongCallIR=Join-Path $directory 'wrong-call-admission.ll';[IO.File]::WriteAllText($wrongCallIR,$callText.Replace('icmp ule i64 %needed, %remaining','icmp ugt i64 %needed, %remaining'),$utf8)
        $wrongCallExe=Join-Path $directory 'wrong-call-admission.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-DREFUSE_MODE=1','-I',$root,'-I',$directory,'-x','ir',$wrongCallIR,'-x','c',(Join-Path $PSScriptRoot 'call-observer.c'),'-o',$wrongCallExe)
        $r=Invoke-BoundedProcess $wrongCallExe @() $directory 180;$commands+=@($r)
        if($r.timedOut -or $r.exit -ne 1 -or $r.stdout -cne '' -or $r.stderr -notmatch 'call_ordered'){throw 'Wrong call admission was not rejected at its observer'}
        $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Inverted emitted stack admission predicate rejected by independent call-effects observer';passed=$true})
    }
    foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Graph proof input changed: '+$input.path)}}
    $success=$true
} catch {$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;diagnosticOnly=$DiagnosticOnly.IsPresent;reusedCompilations=$reusedCompilations;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Checked graph preparation, conversion/arithmetic fragments and whole procedure subtrees from actual frontend/checker results; unchanged production lowering, test-only native observers. No complete checked-program, native CLI or publication qualification'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
