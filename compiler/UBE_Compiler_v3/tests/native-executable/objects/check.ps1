param([string]$SelectionPath='', [switch]$DiagnosticOnly)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))) {$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/project.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
if($DiagnosticOnly){
 $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
 foreach($id in @($selection.compiler,$selection.clang,$selection.runtime,$selection.unicodeRuntime,$selection.manifest)){if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw 'Historical tool artifact changed'}}
}else{$selection=Get-VerifiedBootstrapSelection $SelectionPath}
$run=Join-Path $root ('bootstrap/out/native-objects/'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run);$utf8=[Text.UTF8Encoding]::new($false)
$inputs=@();$commands=@();$checks=@();$success=$false;$failure=$null
$paths=@('compiler/UBE_Compiler_v3/src/SourceCancellation.cls','compiler/UBE_Compiler_v3/src/NativeResources.bas','compiler/UBE_Compiler_v3/src/NativeInspection.bas','compiler/UBE_Compiler_v3/src/NativeObjects.bas','compiler/UBE_Compiler_v3/src/NativeImports.bas','compiler/UBE_Compiler_v3/src/NativeThreadStorage.bas','compiler/UBE_Compiler_v3/src/NativeImageRelocations.bas','compiler/UBE_Compiler_v3/src/NativeSymbols.bas','compiler/UBE_Compiler_v3/src/NativeUnwind.bas','compiler/UBE_Compiler_v3/src/NativeInstructions.bas','compiler/UBE_Compiler_v3/src/NativeLeaves.bas','compiler/UBE_Compiler_v3/src/NativeFunctionIndexes.bas','compiler/UBE_Compiler_v3/src/NativeInventories.bas','compiler/UBE_Compiler_v3/src/NativeBindings.bas','compiler/UBE_Compiler_v3/src/NativeRelocations.bas','compiler/UBE_Compiler_v3/src/NativeConstants.bas','compiler/UBE_Compiler_v3/src/NativeCode.bas','compiler/UBE_Compiler_v3/src/NativeCodeIndexes.bas','compiler/UBE_Compiler_v3/src/NativeExpectations.bas','compiler/UBE_Compiler_v3/src/NativeOutput.bas','compiler/UBE_Compiler_v3/tests/native-executable/objects/Entry.bas')
$lines=@('UBE-Project 1','Name = "NativeObjectFixture"','Kind = "Exe"','Startup = "Main"')
foreach($path in $paths){$name=Split-Path $path -Leaf;[IO.File]::Copy((Join-Path $root $path),(Join-Path $run $name));$lines+='Source = "'+$name+'"';$inputs+=Get-ArtifactIdentity (Join-Path $root $path)}
$scalarSource=Join-Path $root 'compiler/UBE_Compiler_v3/src/SemanticExpressions.bas';$inputs+=Get-ArtifactIdentity $scalarSource
$maximum=[regex]::Match([IO.File]::ReadAllText($scalarSource),'(?ms)^Function SemanticLongLongMaximum\(\) As LongLong\r?\n.*?^End Function')
if(-not $maximum.Success){throw 'Existing compiler scalar maximum helper missing'}
[IO.File]::WriteAllLines((Join-Path $run 'Scalar.bas'),@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "NativeObjectScalars"',$maximum.Value),$utf8);$lines+='Source = "Scalar.bas"'
$targetSource=Join-Path $root 'compiler/UBE_Compiler_v3/src/NativeDeclarations.bas';$inputs+=Get-ArtifactIdentity $targetSource
$targetText=[IO.File]::ReadAllText($targetSource);$targetPieces=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "NativeExpectedTargetFixture"')
foreach($name in @('NativeDeclarationTarget','NativeDeclarationPlan')){$part=[regex]::Match($targetText,'(?ms)^Type '+$name+'\r?\n.*?^End Type');if(-not $part.Success){throw 'Existing target record missing'};$targetPieces+=$part.Value}
$part=[regex]::Match($targetText,'(?ms)^Sub ReadNativeDeclarationTarget\([^\r\n]+\)\r?\n.*?^End Sub');if(-not $part.Success){throw 'Target read helper missing'};$targetPieces+=$part.Value
$graphSource=Join-Path $root 'compiler/UBE_Compiler_v3/src/NativeGraph.bas';$inputs+=Get-ArtifactIdentity $graphSource
$part=[regex]::Match([IO.File]::ReadAllText($graphSource),'(?ms)^Function TryVisitNativeIndex\([^\r\n]+\) As Boolean\r?\n.*?^End Function');if(-not $part.Success){throw 'Native work helper missing'};$targetPieces+=$part.Value
[IO.File]::WriteAllLines((Join-Path $run 'Targets.bas'),$targetPieces,$utf8);$lines+='Source = "Targets.bas"'
$core=Join-Path $root 'std-lib/UBECore.UBE';$relative=[Uri]::UnescapeDataString(([Uri]($run.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$core).ToString());$lines+='Reference = "'+$relative+'"'
$manifest=Join-Path $run 'Objects.UBE';[IO.File]::WriteAllLines($manifest,$lines,$utf8)
$sources=@(Get-FoundationProjectSources $manifest);$names=@{};$types=@{};$classes=@();$ordinal=0
foreach($path in $sources){
 $text=[IO.File]::ReadAllText($path)
 if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=$Matches[1]}
 foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)')){$name=$m.Groups[1].Value;if($names.ContainsKey($name)){throw 'Duplicate procedure name'};$names[$name]='ube.p'+$ordinal;++$ordinal}
}
$ordinal=0;foreach($name in $classes){$types[$name]='%ube.type.'+$ordinal;++$ordinal}
foreach($path in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($path),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)')){$types[$m.Groups[1].Value]='%ube.type.'+$ordinal;++$ordinal}}
$mapping=[pscustomobject]@{procedures=$names;types=$types};$probe=Join-Path $PSScriptRoot 'probe.c'
$inputs+=@($sources|ForEach-Object {Get-ArtifactIdentity $_})
foreach($path in @($probe,$PSCommandPath,$core,(Join-Path $PSScriptRoot 'oracle.c'),(Join-Path $PSScriptRoot 'fixture.c'),(Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-OBJECT-IMPLEMENTATION.md'),(Join-Path $root 'std-lib/BINARY-BYTES-CONTRACT.md'),(Join-Path $root 'std-lib/tests/file-output/native.c'),(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1'),(Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/project.ps1'))){$inputs+=Get-ArtifactIdentity $path}
foreach($path in @('bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/error_support.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c')){$inputs+=Get-ArtifactIdentity (Join-Path $root $path)}
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'relocations.s')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'symbols.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'inventory.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'bindings.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'expectations.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'retention.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'unwind.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'instructions.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'instruction-relocations.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'instruction-targets.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'generated-targets.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'reference-pointers.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'imports.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'image-relocations.c')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-IMAGE-RELOCATION-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'thread-storage.c')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-THREAD-STORAGE-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-IMPORT-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-REFERENCE-POINTER-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-TARGET-OWNERSHIP-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'leaves.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'leaf-binding.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'named-relocations.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'constant-binding.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'fixups.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'code.c')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'code-index.c')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-CODE-OWNERSHIP-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-CODE-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-FIXUP-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-CONSTANT-BINDING-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-RELOCATION-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-LEAF-BINDING-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $PSScriptRoot 'function-index.c')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-FUNCTION-INDEX-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-LEAF-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-INSTRUCTION-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-UNWIND-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-EXPECTATION-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-BINDING-IMPLEMENTATION.md')
$inputs+=Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/NATIVE-INVENTORY-IMPLEMENTATION.md')
$observed=[IO.File]::ReadAllText((Join-Path $root 'std-lib/tests/file-output/native.c'))
foreach($allocation in @('return malloc(n);','return calloc(n,size);','return realloc(p,n);')){
 if(([regex]::Matches($observed,[regex]::Escape($allocation))).Count -ne 1){throw 'Allocation observation seam changed'}
 $observed=$observed.Replace($allocation,'if (!inventory_allow_allocation()) return NULL; '+$allocation)
}
$observed=$observed.Replace('../../../bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/bootstrap_runtime.c')
$observer=@'
#include <stddef.h>
static _Thread_local int inventory_observing;
static _Thread_local size_t inventory_fail_at,inventory_allocation_visits;
static int inventory_allow_allocation(void) {
 if (!inventory_observing) return 1;
 ++inventory_allocation_visits;
 return !inventory_fail_at || inventory_allocation_visits < inventory_fail_at;
}
'@
[IO.File]::WriteAllText((Join-Path $run 'file-output-observed.c'),$observer+"`n"+$observed,$utf8)
$probeText=[IO.File]::ReadAllText($probe).Replace('"std-lib/tests/file-output/native.c"','"file-output-observed.c"')
$probe=Join-Path $run 'probe.c';[IO.File]::WriteAllText($probe,$probeText,$utf8)
function Run([string]$File,[string[]]$Arguments,[int]$Timeout=180){
 $r=Invoke-BoundedProcess $File $Arguments $run $Timeout;$script:commands+=@($r)
 if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r
}
try {
 $oracle=Join-Path $run 'oracle.exe';$null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror',(Join-Path $PSScriptRoot 'oracle.c'),'-o',$oracle)
 $fixtures=@()
 foreach($optimization in @('O0','O2')){foreach($debug in @('Full','None')){
  $flags=@('--target=x86_64-w64-windows-gnu',('-'+$optimization));if($debug -eq 'Full'){$flags+='-gdwarf-4'}else{$flags+='-g0'}
  $object=Join-Path $run ($optimization+'-'+$debug+'.o');$image=Join-Path $run ($optimization+'-'+$debug+'.exe')
  $null=Run $selection.clang.path ($flags+@('-c',(Join-Path $PSScriptRoot 'fixture.c'),'-o',$object))
  $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu',$object,'-o',$image)
  foreach($path in @($object,$image)){$expected=Run $oracle @($path);if($expected.stderr -cne ''){throw 'SDK oracle stderr'};$fixtures+=@([pscustomobject]@{path=$path;expected=$expected.stdout;identity=(Get-ArtifactIdentity $path)})}
 }}
 $overflow=Join-Path $run 'extended-relocations.o';$null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-c',(Join-Path $PSScriptRoot 'relocations.s'),'-o',$overflow)
 $expected=Run $oracle @($overflow)
 if($expected.stderr -cne '' -or $expected.stdout -notmatch '\t65536\t'){throw 'Assembler fixture must contain exactly 65536 effective relocations'}
 $fixtures+=@([pscustomobject]@{path=$overflow;expected=$expected.stdout;identity=(Get-ArtifactIdentity $overflow)})
 $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path);$prior=''
 foreach($path in $stages){$inputs+=Get-ArtifactIdentity $path}
 for($stage=0;$stage -lt 2;++$stage){
  $raw=Join-Path $run ('stage'+$stage+'.ll');$null=Run $stages[$stage] @($manifest,$raw)
  $identity=Get-ArtifactIdentity $raw;if($prior -and $prior -cne $identity.sha256){throw 'Object reader LLVM differs across stages'};$prior=$identity.sha256
  $ir=[IO.File]::ReadAllText($raw);$adapter=[Text.StringBuilder]::new()
  $null=Assert-FoundationRecord $ir $mapping 'NativeInspection' 'i64, i64, i64, i64'
  $null=Assert-FoundationRecord $ir $mapping 'NativeObjectLayout' 'i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i64, i64, i64'
  $null=Assert-FoundationRecord $ir $mapping 'NativeObjectSection' 'i64, i64, i64, i32, i32, i32, i32, i32, i64'
  $null=Assert-FoundationRecord $ir $mapping 'NativeObjectName' 'i32, i32'
  $null=Assert-FoundationRecord $ir $mapping 'NativeObjectSymbol' ($types.NativeObjectName+', i64, i32, i32, i32, i32, i32, i32')
  $null=Assert-FoundationRecord $ir $mapping 'NativeObjectRelocation' 'i64, i64, i32, i32, i32'
  $null=Assert-FoundationRecord $ir $mapping 'NativeSymbolInventory' 'ptr, ptr, ptr, i32, i32, i32, i32, i32, i32'
  $null=Assert-FoundationRecord $ir $mapping 'NativeInspectionStorage' 'i64, i64, i64'
  $null=Assert-FoundationRecord $ir $mapping 'NativeDefinitionRange' 'i32, i32, i32, i32, i32, i32, i64, i64, i64, i64'
  $null=Assert-FoundationRecord $ir $mapping 'NativeExpectedDefinition' ($types.NativeObjectName+', i32, i32, i32, i32, i32, i32, i32, i32')
  $null=Assert-FoundationRecord $ir $mapping 'NativeExpectedDefinitions' 'ptr, ptr, i32, i32, i32, i32, i32, i32'
  $null=Assert-FoundationRecord $ir $mapping 'NativeDeclarationTarget' 'i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i64, i64'
  $null=Assert-FoundationRecord $ir $mapping 'NativeRetainedDefinition' ('i32, '+$types.NativeDefinitionRange+', '+$types.NativeDefinitionRange)
  $null=Assert-FoundationRecord $ir $mapping 'NativeFunctionExtent' 'i32, i32, i32, i32, i32, i64, i64'
  $null=Assert-FoundationRecord $ir $mapping 'NativeImageFunctionTable' 'i32, i32, i32, i32'
  $null=Assert-FoundationRecord $ir $mapping 'NativeInstruction' 'i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i64, i64'
  $null=Assert-FoundationRecord $ir $mapping 'NativeLeaf' 'ptr, ptr, i32, i32, i32, i32, i32, i32'
  $null=Assert-FoundationRecord $ir $mapping 'NativeFunctionIndex' 'ptr, ptr, ptr, i32, i32, i32, i32, i32, i32, i32, i32'
  $null=Assert-FoundationRecord $ir $mapping 'NativeOwnedCode' ('i32, i32, '+$types.NativeRetainedDefinition)
  $null=Assert-FoundationRecord $ir $mapping 'NativeCodeIndex' 'ptr, ptr, ptr, i32, i32, i32, i32, i32, i32'
  foreach($b in @(@('validate_image_relocations','TryValidateNativeImageRelocations','ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('read_thread_storage','TryReadNativeThreadStorage','ptr,ptr,ptr,ptr,ptr,ptr'),@('bind_thread_index','TryBindNativeThreadIndex','ptr,ptr,i64,ptr,ptr,ptr,ptr,ptr'),@('validate_thread_member','TryValidateNativeThreadMember','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('bind_import_target','TryBindNativeImportTarget','ptr,ptr,i64,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('read_image_directory','TryReadNativeImageDirectory','ptr,ptr,i32,ptr,ptr,ptr,ptr,ptr'),@('locate_image_range','TryLocateNativeImageRange','ptr,ptr,i64,i32,ptr,ptr,ptr,ptr'),@('bind_reference_pointer','TryBindNativeReferencePointer','ptr,ptr,i64,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('validate_generated_target','TryValidateNativeGeneratedTarget','ptr,ptr,ptr,i64,ptr,ptr,ptr,ptr,ptr'),@('instruction_relocation_target','TryReadNativeInstructionRelocationTarget','ptr,i64,ptr,ptr,i64,ptr,i32,ptr,ptr,ptr,ptr'),@('instruction_relocation_offset','TryReadNativeInstructionRelocationOffset','ptr,i64,ptr,ptr,ptr,ptr,ptr'),@('code_index_prepare','TryPrepareNativeCodeIndex','ptr,ptr,i32,ptr,ptr,ptr,ptr,ptr,ptr'),@('code_index_dispose','TryDisposeNativeCodeIndex','ptr,ptr,ptr,ptr'),@('validate_code_anchor','TryValidateNativeCodeAnchor','ptr,ptr,ptr,ptr,ptr'),@('validate_code_coverage','TryValidateNativeCodeCoverage','ptr,ptr,ptr,ptr,ptr,ptr'),@('compare_native_bytes','TryCompareNativeByteSpan','ptr,i32,ptr,i32,i32,ptr,ptr,ptr,ptr'),@('validate_code','TryValidateNativeCodeContribution','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('isolate_contribution','TryValidateNativeContributionIsolation','ptr,ptr,ptr,ptr,ptr,ptr'),@('validate_fixup','TryValidateNativeRelocationValue','ptr,ptr,i64,ptr,i32,ptr,i32,ptr,ptr,ptr'),@('bind_constant','TryBindNativeConstantContribution','i32,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('resolve_named_relocation','TryResolveNativeNamedRelocation','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('bind_leaf_extent','TryBindNativeLeafExtent','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('function_index_prepare','TryPrepareNativeFunctionIndex','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('function_index_dispose','TryDisposeNativeFunctionIndex','ptr,ptr,ptr,ptr'),@('function_fence','TryReadNativeFunctionFence','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('inspect_leaf','TryInspectNativeLeaf','ptr,ptr,i32,i32,ptr,ptr,ptr,ptr,ptr,ptr'),@('dispose_leaf','TryDisposeNativeLeaf','ptr,ptr,ptr,ptr'),@('read_instruction','TryReadNativeInstruction','ptr,i32,i32,ptr,ptr,ptr,ptr'),@('prepare_image_function_table','TryPrepareNativeImageFunctionTable','ptr,ptr,ptr,ptr,ptr,ptr'),@('bind_function_extent','TryBindNativeFunctionExtent','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('read_image_function_table','TryReadNativeImageFunctionTable','ptr,ptr,ptr,ptr,ptr,ptr'),@('read_image_function_extent','TryReadNativeImageFunctionExtent','ptr,ptr,ptr,i32,ptr,ptr,ptr,ptr'),@('read_function_extent','TryReadNativeFunctionExtent','ptr,ptr,ptr,ptr,i32,ptr,ptr,ptr,ptr'),@('bind_definition','TryBindNativeDefinition','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('expectations_prepare','TryPrepareNativeExpectations','ptr,ptr,i32,i32,ptr,ptr,ptr,ptr,ptr,ptr'),@('expectations_dispose','TryDisposeNativeExpectations','ptr,ptr,ptr,ptr'),@('locate_definition','TryLocateNativeDefinition','ptr,ptr,ptr,ptr,ptr,i32,ptr,ptr,ptr,ptr'),@('validate_integer_data','TryValidateNativeIntegerData','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('inventory_prepare','TryPrepareNativeSymbolInventory','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('inventory_dispose','TryDisposeNativeSymbolInventory','ptr,ptr,ptr,ptr'),@('inventory_read','TryReadNativeIndexedSymbol','ptr,i32,ptr,ptr,ptr,ptr'),@('inventory_find','TryFindNativeSymbolRange','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('inventory_definition','TryFindNativeDefinition','ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr,ptr'),@('inventory_targets','TryValidateNativeRelocationTargets','ptr,ptr,ptr,ptr,ptr,ptr'),@('read_name','TryReadNativeSectionName','ptr,ptr,ptr,i32,ptr,ptr,ptr'),@('read_symbol','TryReadNativeObjectSymbol','ptr,ptr,ptr,i32,ptr,ptr,ptr'),@('read_relocation','TryReadNativeObjectRelocation','ptr,ptr,ptr,ptr,i32,ptr,ptr,ptr'),@('decode_bytes','TryReadLittleEndianBits','ptr,i32,i32,ptr'),@('read_bits','TryReadNativeBits','ptr,ptr,i32,i32,ptr,ptr,ptr'),@('read_layout','TryReadNativeObjectLayout','ptr,ptr,ptr,ptr,ptr'),@('read_section','TryReadNativeObjectSection','ptr,ptr,ptr,i32,ptr,ptr,ptr'),@('make_cancel','TryMakeInspectionCancellation','ptr'))){Add-FoundationBinding $adapter $ir $mapping $b[0] $b[1] 'i1' $b[2]}
  foreach($binding in @(@('inspection_defaults','DefaultNativeInspection'),@('inventory_storage_defaults','DefaultNativeInspectionStorage'),@('native_limits_defaults','DefaultNativeLimits'))){
   $defaults=Get-FoundationDefinition $ir $mapping $binding[1] 'void' 'ptr'
   $null=$adapter.AppendLine("define void @"+$binding[0]+"(ptr %p) {`n call void @"+$defaults+"(ptr %p)`n ret void`n}")
  }
  $null=$adapter.AppendLine('declare void @binary_byte_event(i32)')
  foreach($binding in @(@('TryReadBinaryByte','binary_read_body'),@('TryReadByteKeyByte','key_read_body'))){
   $visit=Get-FoundationDefinition $ir $mapping $binding[0] 'i1' 'ptr,i32,ptr'
   $ir=$ir.Replace('define i1 @'+$visit+'(','define i1 @'+$binding[1]+'(')
   $null=$adapter.AppendLine("define i1 @"+$visit+"(ptr %b, i32 %i, ptr %v) {`n call void @binary_byte_event(i32 %i)`n %ok = call i1 @"+$binding[1]+"(ptr %b, i32 %i, ptr %v)`n ret i1 %ok`n}")
  }
  $null=$adapter.AppendLine("declare void @inventory_poll()`ndeclare void @inventory_event(i32)")
  $visit=Get-FoundationDefinition $ir $mapping 'TryVisitNativeInspection' 'i1' 'ptr,i32,ptr,ptr'
  $ir=$ir.Replace('define i1 @'+$visit+'(','define i1 @inspection_visit_body(')
  $null=$adapter.AppendLine("define i1 @"+$visit+"(ptr %s, i32 %n, ptr %c, ptr %f) {`n call void @inventory_poll()`n %ok = call i1 @inspection_visit_body(ptr %s, i32 %n, ptr %c, ptr %f)`n br i1 %ok, label %observe, label %done`nobserve:`n call void @inventory_event(i32 %n)`n br label %done`ndone:`n ret i1 %ok`n}")
  $visit=Get-FoundationDefinition $ir $mapping 'TryVisitByteKeyWork' 'i1' 'ptr,ptr,i1,i32,ptr'
  $ir=$ir.Replace('define i1 @'+$visit+'(','define i1 @key_visit_body(')
  $null=$adapter.AppendLine("define i1 @"+$visit+"(ptr %b, ptr %c, i1 %m, i32 %n, ptr %f) {`n br i1 %m, label %poll, label %invoke`npoll:`n call void @inventory_poll()`n br label %invoke`ninvoke:`n %ok = call i1 @key_visit_body(ptr %b, ptr %c, i1 %m, i32 %n, ptr %f)`n %record = and i1 %ok, %m`n br i1 %record, label %observe, label %done`nobserve:`n call void @inventory_event(i32 %n)`n br label %done`ndone:`n ret i1 %ok`n}")
  $adapted=Join-Path $run ('stage'+$stage+'-adapter.ll');[IO.File]::WriteAllText($adapted,[regex]::Replace($ir,'(?m)^define i32 @main\(','define i32 @unused_object_main(')+"`n"+$adapter.ToString(),$utf8)
  $exe=Join-Path $run ('stage'+$stage+'-probe.exe');$arguments=@('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$PSScriptRoot,$adapted,$probe,$selection.unicodeRuntime.path)
  $null=Run $selection.clang.path ($arguments+@('-o',$exe));$r=Run $exe @() 240
  if($r.stderr -cne '' -or $r.stdout -notmatch '^PASS binary/object readers [1-9][0-9]* assertions; inventory [1-9][0-9]* bytes/[1-9][0-9]* events\n$'){throw ($r|ConvertTo-Json -Compress)}
  $checks+=@([pscustomobject]@{assertion='Independent bytes, malformed headers/sections, exact budgets, cancellation, roots and allocation refusal';stage=$stage+1;passed=$true;output=$r.stdout})
  foreach($fixture in $fixtures){$r=Run $exe @($fixture.path);if($r.stderr -cne '' -or $r.stdout -cne $fixture.expected){throw ('SDK structure disagreement: '+$fixture.path+' actual '+$r.stdout+' expected '+$fixture.expected)};$checks+=@([pscustomobject]@{assertion='Actual COFF/PE scalar layout agrees with SDK structure oracle';stage=$stage+1;passed=$true;artifact=$fixture.identity;output=$r.stdout})}
  $negative=Join-Path $run ('stage'+$stage+'-omitted-read.exe');$null=Run $selection.clang.path ($arguments+@('-DOMIT_BINARY_READ_CONTROL','-o',$negative))
  $r=Invoke-BoundedProcess $negative @() $run 10;$commands+=@($r);if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch 'byte_visits==width'){throw 'Omitted byte observations not rejected'}
  $checks+=@([pscustomobject]@{assertion='Omitted physical read observation rejected';stage=$stage+1;passed=$true;error=$r.stderr})
  $negative=Join-Path $run ('stage'+$stage+'-omitted-inventory-event.exe');$null=Run $selection.clang.path ($arguments+@('-DOMIT_INVENTORY_EVENT_CONTROL','-o',$negative))
  $r=Invoke-BoundedProcess $negative @() $run 10;$commands+=@($r);if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch 'inventory_events==required_events'){throw 'Omitted inventory events not rejected'}
  $checks+=@([pscustomobject]@{assertion='Omitted inventory work observations rejected';stage=$stage+1;passed=$true;error=$r.stderr})
  $text=[IO.File]::ReadAllText($adapted);$wrapper=[regex]::Match($text,'(?ms)^define i32 @inventory_targets\([^\r\n]*\) \{.*?^\}')
  if(-not $wrapper.Success){throw 'Target membership control bridge missing'}
  $wrong=Join-Path $run ('stage'+$stage+'-accepted-auxiliary.ll');[IO.File]::WriteAllText($wrong,$text.Replace($wrapper.Value,$wrapper.Value.Replace('ret i32 %status','ret i32 1')),$utf8)
  $wrongExe=$wrong+'.exe';$wrongArguments=@($arguments|ForEach-Object {if($_ -ceq $adapted){$wrong}else{$_}});$null=Run $selection.clang.path ($wrongArguments+@('-o',$wrongExe))
  $r=Invoke-BoundedProcess $wrongExe @() $run 10;$commands+=@($r);if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch [regex]::Escape('ok==(target==0 || target==3)')){throw 'Accepted auxiliary target not rejected'}
  $checks+=@([pscustomobject]@{assertion='Incorrect acceptance of auxiliary relocation targets rejected';stage=$stage+1;passed=$true;error=$r.stderr})
  foreach($control in @(@('image-relocations-range','validate_image_relocations',4,12,'memcmp(&result,&wanted,sizeof result)==0',0),@('thread-storage-range','read_thread_storage',3,68,'storage.status==1 && memcmp(&storage,&wanted,sizeof storage)==0',0),@('thread-storage-status','read_thread_storage',3,228,'storage.status==1 && memcmp(&storage,&wanted,sizeof storage)==0',0),@('thread-index-range','bind_thread_index',5,12,'result.symbol==0 && result.count==4',0),@('import-cell-range','bind_import_target',9,12,'result.symbol==0 && result.first==576',0),@('reference-cell-range','bind_reference_pointer',10,12,'result.symbol==0 && result.section==0 && result.first==512',0),@('signed-target-result','instruction_relocation_target',8,0,'ok==v->valid && (ok?result==v->expected:result==123)',999),@('relocated-instruction-offset','instruction_relocation_offset',4,0,'ok && result==expected',999),@('ownership-status','code_index_prepare',0,44,'e.value.status==1 && e.value.count==n',0),@('ownership-count','code_index_prepare',0,36,'e.value.status==1 && e.value.count==n',999),@('code-length','validate_code',8,20,'result.present==1 && result.object.symbol==-1',0),@('code-placement','validate_code',8,88,'result.image.symbol==-1',0),@('constant-object-length','bind_constant',7,20,'result.present==1',0),@('constant-image-length','bind_constant',7,76,'result.image.symbol==-1',0),@('named-target-address','resolve_named_relocation',8,40,'result.symbol==0',0),@('named-target-section','resolve_named_relocation',8,4,'result.symbol==0',1),@('bound-leaf-object','bind_leaf_extent',6,20,'result.object.count==6',0),@('bound-leaf-image','bind_leaf_extent',6,76,'result.object.count==6',0),@('function-fence','function_fence',6,12,'result.count==expected_count',0),@('function-index-status','function_index_prepare',0,52,'f.value.status==1',0),@('leaf-length','inspect_leaf',0,28,'e.value.code_bytes==v->extent',0),@('leaf-status','inspect_leaf',0,36,'e.value.code_bytes==v->extent',0),@('instruction-target','read_instruction',4,52,'same_instruction(&result,&instruction_vectors[i].expected)',31),@('instruction-length','read_instruction',4,0,'same_instruction(&result,&instruction_vectors[i].expected)'),@('instruction-registers','read_instruction',4,8,'same_instruction(&result,&instruction_vectors[i].expected)',131072),@('extent-binding-length','bind_function_extent',6,8,'result.code_bytes==16'),@('extent-binding-status','prepare_image_function_table',3,12,'table.status==1',0),@('image-unwind-count','read_image_function_table',3,4,'table.count==2'),@('image-unwind-length','read_image_function_extent',5,8,'result.code_bytes==16'),@('unwind-length','read_function_extent',6,8,'result.code_bytes==16'),@('unwind-offset','read_function_extent',6,32,'result.unwind_offset==index*4'),@('retention-object','bind_definition',9,8,'result.object.symbol==0'),@('retention-present','bind_definition',9,0,'result.present==1',0),@('expected-count','expectations_prepare',0,20,'e.value.count==30'),@('expected-work','expectations_prepare',7,48,'e.usage.work==9'),@('symbol-skip','read_symbol',4,36,'symbol.next==3'),@('relocation-width','read_relocation',5,20,'relocation.width==width'))){
   $text=[IO.File]::ReadAllText($adapted);$pattern='(?ms)^define i32 @'+$control[1]+'\([^\r\n]*\) \{.*?^\}'
   $wrapper=[regex]::Match($text,$pattern);if(-not $wrapper.Success){throw 'Control bridge missing'}
   $controlValue=1;if($control.Count -gt 5){$controlValue=$control[5]}
   $mutation=' %control.slot = getelementptr i8, ptr %a'+$control[2]+', i64 '+$control[3]+"`n store i32 $controlValue, ptr %control.slot`n ret i32 %status"
   $changed=$wrapper.Value.Replace(' ret i32 %status',$mutation);if($changed -ceq $wrapper.Value){throw 'Control mutation absent'}
   $wrong=Join-Path $run ('stage'+$stage+'-'+$control[0]+'.ll');[IO.File]::WriteAllText($wrong,$text.Replace($wrapper.Value,$changed),$utf8)
   $wrongExe=$wrong+'.exe';$wrongArguments=@($arguments|ForEach-Object {if($_ -ceq $adapted){$wrong}else{$_}});$null=Run $selection.clang.path ($wrongArguments+@('-o',$wrongExe))
   $controlArguments=@();if($control[0] -like 'image-relocations-*'){$controlArguments=@('--image-relocations')};if($control[0] -like 'import-cell-*'){$controlArguments=@('--imports')}
   if($control[0] -like 'thread-*'){$controlArguments=@('--thread-storage')};if($control[0] -like 'reference-cell-*'){$controlArguments=@('--reference-pointers')};if($control[0] -like 'signed-target-*'){$controlArguments=@('--instruction-targets')};if($control[0] -like 'relocated-instruction-*'){$controlArguments=@('--instruction-relocations')};if($control[0] -like 'ownership-*'){$controlArguments=@('--code-ownership')};if($control[0] -like 'code-*'){$controlArguments=@('--code')};if($control[0] -like 'constant-*'){$controlArguments=@('--constant-binding')};if($control[0] -like 'named-target-*'){$controlArguments=@('--named-relocations')};if($control[0] -like 'bound-leaf-*'){$controlArguments=@('--leaf-binding')};if($control[0] -like 'function-*'){$controlArguments=@('--function-index')};if($control[0] -like 'leaf-*'){$controlArguments=@('--leaves')};if($control[0] -like 'expected-*'){$controlArguments=@('--expectations')};if($control[0] -like 'retention-*'){$controlArguments=@('--retention')};if($control[0] -like 'unwind-*'){$controlArguments=@('--unwind')};if($control[0] -like 'image-unwind-*'){$controlArguments=@('--image-unwind')};if($control[0] -like 'extent-binding-*'){$controlArguments=@('--extent-bindings')};if($control[0] -like 'instruction-*'){$controlArguments=@('--instructions')}
   $r=Invoke-BoundedProcess $wrongExe $controlArguments $run 10;$commands+=@($r)
   if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch [regex]::Escape($control[4])){throw ('Corrupted descriptor not rejected: '+$control[0])}
   $checks+=@([pscustomobject]@{assertion=('Corrupted output rejected: '+$control[0]);stage=$stage+1;passed=$true;error=$r.stderr})
  }
 }
 foreach($stage in 0..1){
  $adapted=Join-Path $run ('stage'+$stage+'-adapter.ll');$text=[IO.File]::ReadAllText($adapted)
  foreach($booleanControl in @(@('validate_image_relocations','--image-relocations'),@('validate_fixup','--fixups'),@('validate_generated_target','--generated-targets'),@('bind_reference_pointer','--reference-pointers'),@('bind_import_target','--imports'),@('read_thread_storage','--thread-storage'),@('bind_thread_index','--thread-storage'),@('validate_thread_member','--thread-storage'))){
  $wrapper=[regex]::Match($text,('(?ms)^define i32 @'+$booleanControl[0]+'\([^\r\n]*\) \{.*?^\}'))
  if(-not $wrapper.Success){throw 'Fixup control bridge missing'}
  foreach($forced in 0..1){
   $changed=$wrapper.Value.Replace('ret i32 %status',('ret i32 '+$forced));if($changed -ceq $wrapper.Value){throw 'Fixup control mutation absent'}
   $wrong=Join-Path $run ('stage'+$stage+'-forced-'+$booleanControl[0]+'-'+$forced+'.ll');[IO.File]::WriteAllText($wrong,$text.Replace($wrapper.Value,$changed),$utf8)
   $wrongExe=$wrong+'.exe';$args=@('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$PSScriptRoot,$wrong,$probe,$selection.unicodeRuntime.path,'-o',$wrongExe)
   $null=Run $selection.clang.path $args;$r=Invoke-BoundedProcess $wrongExe @($booleanControl[1]) $run 10;$commands+=@($r)
   $expected='ok && failure.code==0';if($forced){$expected='!ok && failure.code==1506'}
   if($r.timedOut -or $r.exit -ne 1 -or $r.stderr -notmatch [regex]::Escape($expected)){throw 'Forced fixup result not rejected'}
   $checks+=@([pscustomobject]@{assertion=('Forced Boolean result rejected: '+$booleanControl[0]+' '+$forced);stage=$stage+1;passed=$true;error=$r.stderr})
  }
 }
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Test input changed: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;diagnosticOnly=$DiagnosticOnly.IsPresent;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Bounded production little-endian, COFF/PE headers/sections, names, primary symbols/auxiliary extents and selected relocation descriptions. Includes bounded indexed symbol membership and primary relocation targets. No required auxiliary interpretation, full candidate validation, held-file identity, instruction/stack proof, debug validation or builder/publication qualification.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
