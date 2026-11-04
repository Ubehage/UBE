param([string]$SelectionPath='', [switch]$DiagnosticOnly)
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
$run=Join-Path $root ('bootstrap/out/native-emission/'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run)
$paths=@('compiler/UBE_Compiler_v3/src/SourceCancellation.cls','compiler/UBE_Compiler_v3/src/NativeResources.bas','compiler/UBE_Compiler_v3/src/NativeOutput.bas','compiler/UBE_Compiler_v3/src/SemanticModel.bas','compiler/UBE_Compiler_v3/src/NativeTraversal.bas','compiler/UBE_Compiler_v3/tests/native-executable/emission/Entry.bas')
$paths+='compiler/UBE_Compiler_v3/src/NativeGraph.bas'
$paths+='compiler/UBE_Compiler_v3/src/NativeLLVM.bas'
$paths+='compiler/UBE_Compiler_v3/src/NativeValues.bas'
$paths+='compiler/UBE_Compiler_v3/src/NativeArithmetic.bas'
$paths+='compiler/UBE_Compiler_v3/src/NativeDeclarations.bas'
$paths+='compiler/UBE_Compiler_v3/src/NativeStorage.bas'
$paths+='compiler/UBE_Compiler_v3/src/NativeCalls.bas'
$lines=@('UBE-Project 1','Name = "EmissionFixture"','Kind = "Exe"','Startup = "Main"')
foreach($path in $paths) {
    $relative=Split-Path $path -Leaf
    [IO.File]::Copy((Join-Path $root $path),(Join-Path $run $relative))
    $lines+='Source = "'+$relative+'"'
}
# The component needs existing scalar record borrowers and the target bound. Extract
# their exact production definitions, retaining the complete source identity.
$storageSource=Join-Path $root 'compiler/UBE_Compiler_v3/src/SemanticStorage.bas'
$storageText=[IO.File]::ReadAllText($storageSource)
$borrowers=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "NativeGraphRecordBorrowers"')
foreach($name in @('ReadSemanticFact','ReadBoundNode','ReadSemanticDeclaration')) {
    $match=[regex]::Match($storageText,'(?ms)^Sub '+$name+'\([^\r\n]+\)\r?\n.*?^End Sub')
    if(-not $match.Success){throw 'Production scalar record borrower missing'}
    $borrowers+=$match.Value
}
$boundsSource=Join-Path $root 'compiler/UBE_Compiler_v3/src/SemanticExpressions.bas'
$bound=[regex]::Match([IO.File]::ReadAllText($boundsSource),'(?ms)^Function SemanticLongLongMaximum\(\) As LongLong\r?\n.*?^End Function')
if(-not $bound.Success){throw 'Production LongLong bound missing'}
$borrowers+=$bound.Value
[IO.File]::WriteAllLines((Join-Path $run 'RecordBorrowers.bas'),$borrowers,[Text.UTF8Encoding]::new($false))
$lines+='Source = "RecordBorrowers.bas"'
$relative=[Uri]::UnescapeDataString(([Uri]($run.TrimEnd('\')+'\')).MakeRelativeUri([Uri](Join-Path $root 'std-lib/UBECore.UBE')).ToString())
$lines+='Reference = "'+$relative+'"'
$manifest=Join-Path $run 'Emission.UBE';[IO.File]::WriteAllLines($manifest,$lines,[Text.UTF8Encoding]::new($false))
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
$inputs=@($sources|ForEach-Object {Get-ArtifactIdentity $_})
$inputs+=@($paths|ForEach-Object {Get-ArtifactIdentity (Join-Path $root $_)})
foreach($path in @($PSCommandPath,(Join-Path $PSScriptRoot 'probe.c'),(Join-Path $root 'std-lib/tests/file-output/native.c'),(Join-Path $root 'std-lib/INTEGER-OUTPUT-CONTRACT.md'),(Join-Path $root 'std-lib/BYTE-BUFFER-CONTRACT.md'),(Join-Path $root 'std-lib/UBECore.UBE'))) {$inputs+=Get-ArtifactIdentity $path}
foreach($path in @('bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/error_support.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c')) {$inputs+=Get-ArtifactIdentity (Join-Path $root $path)}
$commands=@();$checks=@();$success=$false;$failure=$null;$prior=''
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'traversal.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'graph.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'llvm.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'llvm-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'conversions.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'conversion-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'arithmetic.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'representation.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'arithmetic-observer.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'storage.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'storage-observer.c')
$inputs+=Get-ArtifactIdentity $storageSource
$inputs+=Get-ArtifactIdentity $boundsSource
function Run([string]$File,[string[]]$Arguments,[string]$Directory=$root,[int]$Expected=0) {
    $r=Invoke-BoundedProcess $File $Arguments $Directory 180
    $script:commands+=@($r)
    if($r.timedOut -or $r.exit -ne $Expected){throw ($r|ConvertTo-Json -Compress)}
    return $r
}
try {
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    for($stage=0;$stage -lt 2;++$stage) {
        $directory=Join-Path $run ('stage'+$stage);$null=[IO.Directory]::CreateDirectory($directory)
        $raw=Join-Path $directory 'raw.ll';$null=Run $stages[$stage] @($manifest,$raw)
        $identity=Get-ArtifactIdentity $raw
        if($prior -and $identity.sha256 -cne $prior){throw 'Raw emission LLVM differs across stages'};$prior=$identity.sha256
        $ir=[IO.File]::ReadAllText($raw)
        $null=Assert-FoundationRecord $ir $mapping 'NativeFailure' 'i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeLimits' 'i64, i64, i64, i64, i64, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeUsage' 'i64, i64, i64, i64, i64, i64, i64, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeOutput' ($types.ByteBuffer+', ptr, i32, i32, i32, i32')
        $null=Assert-FoundationRecord $ir $mapping 'DecimalIntegerEncoder' 'i64, i64, i1'
        $null=Assert-FoundationRecord $ir $mapping 'BoundNode' 'i32, i32, i32, i32, i64, i32, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeTraversal' 'ptr, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeTraversalFrame' 'i32, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeTraversalEvent' 'i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeSyntaxLinks' 'i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeNodeLinks' 'i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeArgumentLinks' 'i32, i32, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'NativeGraphPlan' ('ptr, ptr, ptr, '+$types.NativeTraversal+', i32, i32, i32, i32, i32, ptr, i32, i32, i32, ptr, ptr, i32, i32, i32')
        $null=Assert-FoundationRecord $ir $mapping 'NativeLLVMWriter' ($types.NativeFailure+', '+$types.NativeLimits+', '+$types.NativeUsage+', '+$types.NativeOutput+', ptr')
        $null=Assert-FoundationRecord $ir $mapping 'NativeOperand' 'i32, i32, i32, i64'
        $null=Assert-FoundationRecord $ir $mapping 'SemanticType' 'i32, i32, i32, i32, i32, i32, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeDeclarationTarget' 'i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i64, i64'
        $null=Assert-FoundationRecord $ir $mapping 'NativeDeclarationPlan' 'ptr, i32, i32, i32, i32'
        $null=Assert-FoundationRecord $ir $mapping 'SemanticDeclaration' 'i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i64'
        $adapter=[Text.StringBuilder]::new()
        $cancellationArguments=@{em_begin=1;em_byte=4;em_ascii=4;em_integer=4;em_range=6;em_snapshot=3;em_write=2}
        foreach($b in @(@('em_begin','TryBeginNativeModule','i1','ptr,ptr,ptr'),@('em_byte','TryAppendNativeByte','i1','ptr,ptr,ptr,i8,ptr,ptr'),@('em_ascii','TryAppendNativeAscii','i1','ptr,ptr,ptr,ptr,ptr,ptr'),@('em_integer','TryAppendNativeInteger','i1','ptr,ptr,ptr,i64,ptr,ptr'),@('em_range','TryAppendNativeRange','i1','ptr,ptr,ptr,ptr,i32,i32,ptr,ptr'),@('em_snapshot','TrySnapshotNativeModule','i1','ptr,ptr,ptr,ptr,ptr'),@('em_write','TryWriteNativeModule','i1','ptr,i32,ptr,ptr,ptr'),@('em_release','TryReleaseNativeSnapshot','i1','ptr,ptr,ptr'),@('em_dispose','TryDisposeNativeOutput','i1','ptr,ptr,ptr'),@('em_cancel_make','MakeEmissionCancellation','i1','ptr'),@('integer_next','TryNextDecimalIntegerByte','i1','ptr,ptr,ptr'))) {
            if($cancellationArguments.ContainsKey($b[0])) {
                $symbol=Get-FoundationDefinition $ir $mapping $b[1] $b[2] $b[3]
                $arguments=@();$parts=$b[3] -split ',';for($i=0;$i -lt $parts.Count;++$i){$arguments+=$parts[$i]+' %a'+$i}
                $index=$cancellationArguments[$b[0]];$forward=@($arguments);$forward[$index]='ptr %cancel.owner'
                $null=$adapter.AppendLine('define i32 @'+$b[0]+'('+($arguments -join ', ')+") {`n %cancel.owner = alloca ptr`n store ptr %a$index, ptr %cancel.owner`n %result = call i1 @"+$symbol+'('+($forward -join ', ')+")`n %status = zext i1 %result to i32`n ret i32 %status`n}")
            } else {Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] $b[2] $b[3]}
        }
        foreach($b in @(@('em_defaults','DefaultNativeLimits','ptr'),@('integer_begin','BeginDecimalIntegerEncoding','i64,ptr,ptr'),@('em_cancel','RequestEmissionCancellation','ptr'))) {
            $symbol=Get-FoundationDefinition $ir $mapping $b[1] 'void' $b[2]
            $arguments=@();$parts=$b[2] -split ',';for($i=0;$i -lt $parts.Count;++$i){$arguments+=$parts[$i]+' %a'+$i}
            $null=$adapter.AppendLine('define void @'+$b[0]+'('+($arguments -join ', ')+") {`n call void @"+$symbol+'('+($arguments -join ', ')+")`n ret void`n}")
        }
        foreach($b in @(@('tr_begin','TryBeginNativeTraversal','ptr,ptr,i32,i32,ptr,ptr,ptr,ptr',6),@('tr_next','TryNextNativeTraversal','ptr,ptr,i32,ptr,ptr,ptr,ptr,ptr',5))) {
            $symbol=Get-FoundationDefinition $ir $mapping $b[1] 'i1' $b[2]
            $arguments=@();$parts=$b[2] -split ',';for($i=0;$i -lt $parts.Count;++$i){$arguments+=$parts[$i]+' %a'+$i}
            $index=$b[3];$forward=@($arguments);$forward[$index]='ptr %cancel.owner'
            $null=$adapter.AppendLine('define i32 @'+$b[0]+'('+($arguments -join ', ')+") {`n %cancel.owner = alloca ptr`n store ptr %a$index, ptr %cancel.owner`n %result = call i1 @"+$symbol+'('+($forward -join ', ')+")`n %status = zext i1 %result to i32`n ret i32 %status`n}")
        }
        Add-FoundationBinding $adapter $ir $mapping 'tr_dispose' 'TryDisposeNativeTraversal' 'i1' 'ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'tr_make' 'MakeTraversalNodes' 'i1' 'ptr,i32,i1'
        Add-FoundationBinding $adapter $ir $mapping 'gr_root' 'TryReadNativeProcedureRoot' 'i1' 'ptr,i32,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'tr_skip' 'TrySkipNativeTraversalChild' 'i1' 'ptr'
        Add-FoundationBinding $adapter $ir $mapping 'gr_dispose' 'TryDisposeNativeGraph' 'i1' 'ptr,ptr,ptr'
        Add-FoundationBinding $adapter $ir $mapping 'gr_make' 'MakeGraphFacts' 'i1' 'ptr,i32,i1'
        Add-FoundationBinding $adapter $ir $mapping 'gr_targets' 'MakeGraphTargets' 'i1' 'ptr,i32'
        $symbol=Get-FoundationDefinition $ir $mapping 'TryPrepareNativeGraph' 'i1' 'ptr,ptr,i32,i32,ptr,i32,i32,ptr,ptr,ptr,ptr,ptr'
        $null=$adapter.AppendLine("define i32 @gr_prepare(ptr %p, ptr %v, i32 %vc, i32 %root, ptr %f, i32 %fc, i32 %sc, ptr %d, ptr %l, ptr %u, ptr %c, ptr %error) {`n %cancel = alloca ptr`n store ptr %c, ptr %cancel`n %ok = call i1 @"+$symbol+"(ptr %p, ptr %v, i32 %vc, i32 %root, ptr %f, i32 %fc, i32 %sc, ptr %d, ptr %l, ptr %u, ptr %cancel, ptr %error)`n %result = zext i1 %ok to i32`n ret i32 %result`n}")
        foreach($b in @(@('ll_begin','TryBeginNativeLLVM','ptr'),@('ll_text','TryLLVMText','ptr,ptr'),@('ll_line','TryLLVMLine','ptr,ptr'),@('ll_number','TryLLVMNumber','ptr,i64'),@('ll_type','TryLLVMType','ptr,i32,i1'),@('ll_constant','TryLLVMConstant','ptr,i32,i1,i64'),@('ll_identity','TryLLVMIdentity','ptr,ptr'),@('ll_snapshot','TrySnapshotNativeLLVM','ptr'),@('ll_dispose','TryDisposeNativeLLVM','ptr'))) {
            Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] 'i1' $b[2]
        }
        foreach($b in @(@('ll_operand','TryLLVMOperand','ptr,ptr'),@('ll_typed','TryLLVMTypedOperand','ptr,ptr'),@('ll_instruction','TryLLVMInstruction','ptr,i32,i32,ptr'),@('ll_convert','TryEmitNativeConversion','ptr,ptr,ptr,ptr,ptr,ptr'),@('ll_representation','TryEmitNativeRepresentation','ptr,i32,ptr,i32,ptr,ptr'),@('ll_error_support','TryEmitNativeErrorSupport','ptr'))) {
            Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] 'i1' $b[2]
        }
        foreach($b in @(@('ll_binary','TryEmitNativeBinary','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('ll_unary','TryEmitNativeUnary','ptr,ptr,ptr,ptr,ptr,ptr'),@('ll_overflow_declarations','TryEmitNativeOverflowDeclarations','ptr,i32'))) {
            Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] 'i1' $b[2]
        }
        foreach($b in @(@('st_make_declarations','MakeNativeDeclarations','ptr,i32'),@('st_make_types','MakeNativeTypes','ptr,i32'),@('st_prepare','TryPrepareNativeDeclarations','ptr,ptr,i32,ptr,i32,i32,ptr'),@('st_dispose','TryDisposeNativeDeclarations','ptr,ptr'),@('st_storage','TryEmitNativeStorage','ptr,ptr,i32'),@('st_load','TryEmitNativeLoad','ptr,ptr,i32,ptr'),@('st_store','TryEmitNativeStore','ptr,ptr,i32,ptr'))) {
            Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] 'i1' $b[2]
        }
        foreach($name in @('BeginDecimalIntegerEncoding','TryNextDecimalIntegerByte')) {
            $body=[regex]::Match($ir,'(?ms)^define [^\n]+ @'+[regex]::Escape($names[$name])+'\([^\n]*\) \{.*?^\}').Value
            foreach($call in [regex]::Matches($body,'(?m)^.*\b(?:call|invoke)\b.*$')) {
                if($call.Value -notmatch '@ube_checked_(?:add|sub|mul|div|mod|neg|narrow)_i(?:32|64)\('){throw 'Decimal encoder acquired a non-scalar call'}
            }
        }
        Add-FoundationBinding $adapter $ir $mapping 'st_owner' 'TryReadNativeStorageOwner' 'i1' 'ptr,i32,ptr'
        $adapted=Join-Path $directory 'adapter.ll';[IO.File]::WriteAllText($adapted,$ir.Replace('define i32 @main(','define i32 @emission_unused_main(')+"`n"+$adapter.ToString(),[Text.UTF8Encoding]::new($false))
        $exe=Join-Path $directory 'probe.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-std=c17','-O2','-Wall','-Wextra','-Werror','-I',$root,$adapted,(Join-Path $PSScriptRoot 'probe.c'),$selection.unicodeRuntime.path,'-o',$exe)
        $r=Run $exe @() $directory
        if($r.stderr -cne '' -or $r.stdout -notmatch '^PASS native emission [1-9][0-9]* assertions\n$'){throw 'Emission oracle did not complete'}
        $checks+=@([pscustomobject]@{assertion='Actual bounded emission, independent decimal bytes, resource/failure/cancellation and file read-back oracles';stage=$stage+1;passed=$true;raw=$identity;output=$r.stdout})
        $artifact=Join-Path $directory 'program.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-Werror','-x','ir',(Join-Path $directory 'program.ll'),'-o',$artifact)
        $r=Run $artifact @() $directory 37
        if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Emitted LLVM executable output differed'}
        $checks+=@([pscustomobject]@{assertion='Actual emitted/read-back LLVM validates, links and returns independent native status 37';stage=$stage+1;passed=$true})
        $literals=Join-Path $directory 'literals.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-std=c17','-Wall','-Wextra','-Werror','-x','ir',(Join-Path $directory 'literals.ll'),'-x','c',(Join-Path $PSScriptRoot 'llvm-observer.c'),'-o',$literals)
        $r=Run $literals @() $directory
        if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Typed LLVM constant/aggregate oracle differed'}
        $checks+=@([pscustomobject]@{assertion='Actually emitted scalar/native-aggregate LLVM returns independent boundary values through native observers';stage=$stage+1;passed=$true})
        $conversionIR=[IO.File]::ReadAllText((Join-Path $directory 'conversions.ll'))
        $identities=[regex]::Matches($conversionIR,'(?m)^(?:define|declare) ').Count+[regex]::Matches($conversionIR,'(?m)^\s*%[A-Za-z0-9_.]+ =').Count+[regex]::Matches($conversionIR,'(?m)^[A-Za-z][A-Za-z0-9_.]*:').Count
        foreach($definition in [regex]::Matches($conversionIR,'(?m)^define [^\n]*\(([^)]*)\)')){$identities += [regex]::Matches($definition.Groups[1].Value,'%[A-Za-z0-9_.]+').Count}
        $reported=[long]::Parse([IO.File]::ReadAllText((Join-Path $directory 'conversion-identities.txt')).Trim(),[Globalization.CultureInfo]::InvariantCulture)
        if($identities -ne $reported){throw 'Generated identity charge differs from independently counted LLVM definitions'}
        foreach($optimization in @('O0','O2')) {
            $conversions=Join-Path $directory ('conversions-'+$optimization+'.exe')
            $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-x','ir',(Join-Path $directory 'conversions.ll'),'-x','c',(Join-Path $PSScriptRoot 'conversion-observer.c'),'-o',$conversions)
            $r=Run $conversions @() $directory
            if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Generated conversion observer differed'}
            $checks+=@([pscustomobject]@{assertion='Actual generated conversion matrix, neutral results, exact Err/revision preservation, native thread isolation';stage=$stage+1;optimization=$optimization;passed=$true;identities=$identities})
        }
        $wrongIR=Join-Path $directory 'wrong-conversion-error.ll';[IO.File]::WriteAllText($wrongIR,$conversionIR.Replace(', i32 6)',', i32 11)'),[Text.UTF8Encoding]::new($false))
        $wrongExe=Join-Path $directory 'wrong-conversion-error.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-I',$root,'-x','ir',$wrongIR,'-x','c',(Join-Path $PSScriptRoot 'conversion-observer.c'),'-o',$wrongExe)
        $r=Run $wrongExe @() $directory 1
        if($r.stderr -notmatch 'err=11 expected=6'){throw 'Wrong generated conversion error control was not rejected'}
        $checks+=@([pscustomobject]@{assertion='Changed actual generated Err 6 to Err 11 rejected at independent conversion observation';stage=$stage+1;passed=$true})
        $arithmeticIR=[IO.File]::ReadAllText((Join-Path $directory 'arithmetic.ll'))
        $identities=[regex]::Matches($arithmeticIR,'(?m)^(?:define|declare) ').Count+[regex]::Matches($arithmeticIR,'(?m)^\s*%[A-Za-z0-9_.]+ =').Count+[regex]::Matches($arithmeticIR,'(?m)^[A-Za-z][A-Za-z0-9_.]*:').Count
        foreach($definition in [regex]::Matches($arithmeticIR,'(?m)^define [^\n]*\(([^)]*)\)')){$identities += [regex]::Matches($definition.Groups[1].Value,'%[A-Za-z0-9_.]+').Count}
        $reported=[long]::Parse([IO.File]::ReadAllText((Join-Path $directory 'arithmetic-identities.txt')).Trim(),[Globalization.CultureInfo]::InvariantCulture)
        if($identities -ne $reported){throw 'Arithmetic identity charge differs from independent LLVM definition count'}
        foreach($optimization in @('O0','O2')) {
            $arithmetic=Join-Path $directory ('arithmetic-'+$optimization+'.exe')
            $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-x','ir',(Join-Path $directory 'arithmetic.ll'),'-x','c',(Join-Path $PSScriptRoot 'arithmetic-observer.c'),'-o',$arithmetic)
            $r=Run $arithmetic @() $directory
            if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Generated arithmetic observer differed'}
            $checks+=@([pscustomobject]@{assertion='Generated arithmetic/comparison/bitwise/unary matrix; exact values, Err/revision, defined signed division/remainder boundaries';stage=$stage+1;optimization=$optimization;passed=$true;identities=$identities})
        }
        $wrongIR=Join-Path $directory 'wrong-arithmetic-error.ll';[IO.File]::WriteAllText($wrongIR,$arithmeticIR.Replace(', i32 11)',', i32 6)'),[Text.UTF8Encoding]::new($false))
        $wrongExe=Join-Path $directory 'wrong-arithmetic-error.exe'
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-I',$root,'-x','ir',$wrongIR,'-x','c',(Join-Path $PSScriptRoot 'arithmetic-observer.c'),'-o',$wrongExe)
        $r=Run $wrongExe @() $directory 1
        if($r.stderr -notmatch 'err=6 expected=11'){throw 'Wrong generated division error control was not rejected'}
        $checks+=@([pscustomobject]@{assertion='Actual generated zero-divisor Err 11 changed to 6 is rejected by independent observer';stage=$stage+1;passed=$true})
        $storageIR=[IO.File]::ReadAllText((Join-Path $directory 'storage.ll'))
        $identities=[regex]::Matches($storageIR,'(?m)^(?:define|declare|@ube\.g[0-9]+ =) ').Count+[regex]::Matches($storageIR,'(?m)^\s*%[A-Za-z0-9_.]+ =').Count+[regex]::Matches($storageIR,'(?m)^[A-Za-z][A-Za-z0-9_.]*:').Count
        foreach($definition in [regex]::Matches($storageIR,'(?m)^define [^\n]*\(([^)]*)\)')){$identities += [regex]::Matches($definition.Groups[1].Value,'%[A-Za-z0-9_.]+').Count}
        $reported=[long]::Parse([IO.File]::ReadAllText((Join-Path $directory 'storage-identities.txt')).Trim(),[Globalization.CultureInfo]::InvariantCulture)
        if($identities -ne $reported){throw 'Storage identity charge differs from independent LLVM definition count'}
        foreach($optimization in @('O0','O2')) {
            $storage=Join-Path $directory ('storage-'+$optimization+'.exe')
            $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-std=c17','-Wall','-Wextra','-Werror','-x','ir',(Join-Path $directory 'storage.ll'),'-x','c',(Join-Path $PSScriptRoot 'storage-observer.c'),'-o',$storage)
            $r=Run $storage @() $directory
            if($r.stdout -cne '' -or $r.stderr -cne ''){throw 'Generated storage observer differed'}
            $checks+=@([pscustomobject]@{assertion='Generated scalar/native aggregate global/local/result initialization, ByVal private storage and exact ByRef alias writes';stage=$stage+1;optimization=$optimization;passed=$true;identities=$identities})
        }
        foreach($control in @('OMIT_WRITE_CONTROL','CHANGED_BYTE_CONTROL')) {
            $controlDirectory=Join-Path $directory $control;$null=[IO.Directory]::CreateDirectory($controlDirectory)
            $controlExe=Join-Path $controlDirectory 'probe.exe'
            $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-std=c17','-O2','-Wall','-Wextra','-Werror',('-D'+$control),'-I',$root,$adapted,(Join-Path $PSScriptRoot 'probe.c'),$selection.unicodeRuntime.path,'-o',$controlExe)
            $r=Run $controlExe @() $controlDirectory 1
            if($r.stdout -cne '' -or $r.stderr -notmatch 'contents\(L"program.ll"'){throw 'Write control did not fail exact read-back oracle'}
            $checks+=@([pscustomobject]@{assertion="Actual emitted-file corruption rejected at exact read-back: $control";stage=$stage+1;passed=$true;error=$r.stderr})
        }
    }
    foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw 'Emission proof input changed'}}
    $success=$true
} catch {$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;diagnosticOnly=$DiagnosticOnly.IsPresent;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Bounded byte output, declaration/graph preparation and scalar/native storage plus conversion/arithmetic fragments; synthetic checked records and private file-token producer. No complete checked-program, native CLI, stack/debug or guarded-publication qualification'} | ConvertTo-Json -Depth 18 | Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
