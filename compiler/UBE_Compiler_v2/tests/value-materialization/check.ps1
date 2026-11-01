param([Parameter(Mandatory=$true)][string]$SelectionPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $PSScriptRoot 'ir-use.ps1')
$run=Join-Path $root ('bootstrap/out/value-materialization/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$checks=@();$commands=@();$inputs=@();$outputs=@();$witnesses=@();$acceptedSelection=$null;$success=$false;$failure=$null
$utf8=[Text.UTF8Encoding]::new($false)
function Run-Checked([string]$File,[string[]]$Arguments,[int]$Timeout=60){
 $record=Invoke-BoundedProcess $File $Arguments $root $Timeout;$script:commands+=$record
 if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne ''){throw ($record|ConvertTo-Json -Depth 5 -Compress)}
 return $record
}
function Check([string]$Message){$script:checks+=[pscustomobject]@{assertion=$Message;passed=$true}}
function Read-UniquePart([string]$Text,[string]$Kind,[string]$Name){
 $matches=[regex]::Matches($Text,'(?ms)^'+$Kind+' '+$Name+'(?:\([^\r\n]*|)\r?\n.*?^End '+$Kind+'\r?\n')
 if($matches.Count -ne 1){throw ('Expected unique actual compiler declaration: '+$Name)}
 return $matches[0].Value
}
try{
 $acceptedSelection=Get-VerifiedBootstrapSelection $SelectionPath
 $selection=$acceptedSelection;$manifest=Get-Content -LiteralPath $selection.manifest.path -Raw|ConvertFrom-Json
 $inputs+=Get-ArtifactIdentity $SelectionPath;$inputs+=@($manifest.inputs)
 $inputs+=@(Get-ChildItem -LiteralPath $PSScriptRoot -File|ForEach-Object {Get-ArtifactIdentity $_.FullName})
 $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
 $compilerSource=Join-Path $root 'compiler/UBE_Compiler_v2/Main.bas';$text=[IO.File]::ReadAllText($compilerSource)
 $parts=@($text.Substring(0,$text.IndexOf('Type Token')))
 foreach($name in @('SyntaxNode','LocalDeclarationSyntax','StatementSyntax','Token','ProcedureDeclarationSyntax','ParameterSyntax')){$parts+=Read-UniquePart $text 'Type' $name}
 foreach($name in @('ExpressionDepthLimit','IsReferenceType','IsUtf8Continuation','Utf8SequenceLength','DecodeUtf8CodePoint','EqualsIdentifier','FindProcedureByToken','HasKnownValueAddress','NoteValueSlotUse','PrepareCallArgumentUses','PrepareValueSlotUses','NeedsValueSlot')){$parts+=Read-UniquePart $text 'Function' $name}
 $parts+="Function Main() As Long`n    Main = 0`nEnd Function`n"
 $classifier=Join-Path $run 'Classifier.bas';[IO.File]::WriteAllText($classifier,($parts -join "`n"),$utf8)
 $procedures=@{};$index=0
 foreach($m in [regex]::Matches([IO.File]::ReadAllText($classifier),'(?m)^(?:Intrinsic )?(?:Function|Sub) ([A-Za-z_][A-Za-z_0-9]*)\b')){$procedures[$m.Groups[1].Value]='ube.p'+$index;++$index}
 $classifierHashes=@()
 for($stage=0;$stage -lt 2;++$stage){
  $stem=Join-Path $run ('classifier-stage'+($stage+1));$null=Run-Checked $stages[$stage] @($classifier,($stem+'.ll'))
  $raw=[IO.File]::ReadAllText($stem+'.ll');$classifierHashes+=(Get-ArtifactIdentity ($stem+'.ll')).sha256
  if($raw -notmatch '(?m)^%ube.type.0 = type \{ i32, i32, i32, i32, i32, i32, i32, i32 \}\r?$'){throw 'Private SyntaxNode32-byte shape differs'}
  $argumentTypes=@('i32, i32, i32, ptr, ptr',(('i32,'*13)+'i32').Replace(',',', '),('i32, i32, i32, i32, i32'))
  for($i=0;$i -lt $argumentTypes.Count;++$i){
   if($raw -notmatch ('(?m)^%ube.type.'+($i+3)+' = type \{ '+[regex]::Escape($argumentTypes[$i])+' \}\r?$')){throw 'Private Token/Procedure/Parameter argument ABI differs'}
  }
  $adapter=[Text.StringBuilder]::new()
  if($raw -notmatch '(?m)^declare i32 @ube_gc_root_enter\('){$null=$adapter.AppendLine('declare i32 @ube_gc_root_enter(ptr, ptr)')}
  $prepareSymbol=$procedures.PrepareValueSlotUses
  if([regex]::Matches($raw,'(?m)^define i32 @'+[regex]::Escape($prepareSymbol)+'\(').Count -ne 1){throw 'Classifier preparation return ABI differs'}
  # The old six-argument oracle stays unchanged. Its three extra empty arrays
  # share one new native ByRef location, admitted before calling actual UBE.
  $null=$adapter.AppendLine(@"
define i32 @q_prepare(ptr %a0, i32 %a1, ptr %a2, i32 %a3, ptr %a4, i32 %a5) {
entry:
 %empty = alloca ptr
 store ptr null, ptr %empty
 %root = alloca [32 x i8], align 8
 store [32 x i8] zeroinitializer, ptr %root, align 8
 %admitted = call i32 @ube_gc_root_enter(ptr %root, ptr %empty)
 %ok = icmp ne i32 %admitted, 0
 br i1 %ok, label %ready, label %failed
failed:
 %error = call i32 @ube_error_set_number(i32 7)
 ret i32 0
ready:
 %answer = call i32 @$prepareSymbol(ptr %a0, i32 %a1, ptr %a2, i32 %a3, ptr %a4, i32 %a5, ptr %empty, i32 0, ptr %empty, i32 0, ptr %empty, i32 0)
 %left = call i32 @ube_gc_root_leave(ptr %root)
 ret i32 %answer
}
"@)
  $arguments='ptr %a0, i32 %a1, ptr %a2, i32 %a3, ptr %a4, i32 %a5, ptr %a6, i32 %a7, ptr %a8, i32 %a9, ptr %a10, i32 %a11'
  $null=$adapter.AppendLine("define i32 @q_prepare_ex($arguments) {`n %answer = call i32 @$prepareSymbol($arguments)`n ret i32 %answer`n}")
  foreach($binding in @(@('q_needs','NeedsValueSlot','ptr %a0, i32 %a1'),@('q_address','HasKnownValueAddress','ptr %a0, i32 %a1'))){
   $symbol=$procedures[$binding[1]]
   if([regex]::Matches($raw,'(?m)^define i32 @'+[regex]::Escape($symbol)+'\(').Count -ne 1){throw 'Classifier helper return ABI differs'}
   $null=$adapter.AppendLine('define i32 @'+$binding[0]+'('+$binding[2]+') {')
   $null=$adapter.AppendLine(' %r = call i32 @'+$symbol+'('+$binding[2]+')');$null=$adapter.AppendLine(' ret i32 %r');$null=$adapter.AppendLine('}')
  }
  $null=$adapter.AppendLine('define i64 @q_size(i32 %role) {');$null=$adapter.AppendLine(' switch i32 %role, label %bad [ i32 0, label %a i32 1, label %b i32 2, label %c ]');$null=$adapter.AppendLine('bad:');$null=$adapter.AppendLine(' ret i64 -1')
  for($i=0;$i -lt 3;++$i){$null=$adapter.AppendLine(@('a:','b:','c:')[$i]);$null=$adapter.AppendLine(' ret i64 ptrtoint (ptr getelementptr (%ube.type.'+$i+', ptr null, i32 1) to i64)')};$null=$adapter.AppendLine('}')
  $body=[regex]::Match($raw,'(?ms)^define i32 @'+[regex]::Escape($procedures.NeedsValueSlot)+'\([^\r\n]*\r?\n.*?^\}').Value
  if([regex]::Matches($body,'call i32 @ube_value_root_enter\(').Count -ne 2 -or [regex]::Matches($body,'call i32 @ube_value_root_enter\(ptr %root.borrow.').Count -ne 2){throw 'NeedsValueSlot must retain exactly its two borrow-owner admissions and no duplicate argument/private-value root'}
  $adapted=$stem+'-adapter.ll';[IO.File]::WriteAllText($adapted,([regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @q_unused_main(')+"`n"+$adapter),$utf8)
  $null=Run-Checked $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',(Join-Path $root 'bootstrap/runtime'),'-DEXPECTED_NEED_ROOTS=2',$adapted,(Join-Path $PSScriptRoot 'classifier.c'),$selection.unicodeRuntime.path,'-o',($stem+'.exe'))
  $native=Run-Checked ($stem+'.exe') @()
  if($native.stdout -cne "PASS classifier native assertions:2097226 required-roots:2`nPASS ByRef argument controls cumulative assertions:2097260`n"){throw ('Classifier native assertions differ: '+$native.stdout)}
  $outputs+=[pscustomobject]@{stage=$stage;raw=(Get-ArtifactIdentity ($stem+'.ll'));native=$native}
  Check ('stage'+($stage+1)+': all original2097226 independent mask/layout/full-capacity/Err/GC assertions plus34 exact formal-binding/unknown/shared/mixed/alias/owner/failure-recovery controls; zero roots/payload')
 }
 if($classifierHashes[0] -cne $classifierHashes[1]){throw 'Classifier raw LLVM differs between source-built stages'}
 Check 'Actual extracted classifier helpers emit byte-identical LLVM through both source-built stages'

 # The comparator changes one test compiler decision, never the production compiler.
 $rawPath=Join-Path (Split-Path $selection.compiler.path -Parent) 'v2-stage2.ll'
 $rawIdentity=@($manifest.artifacts|Where-Object path -CEQ $rawPath)
 if($rawIdentity.Count -ne 1 -or (Get-ArtifactIdentity $rawPath).sha256 -cne $rawIdentity[0].sha256){throw 'Same-cohort compiler LLVM is not manifest-pinned'}
 $inputs+=$rawIdentity[0];$compilerRaw=[IO.File]::ReadAllText($rawPath)
 $names=@([regex]::Matches($text,'(?m)^(?:Intrinsic )?(?:Function|Sub) ([A-Za-z_][A-Za-z_0-9]*)\b')|ForEach-Object {$_.Groups[1].Value})
 $needsIndex=[Array]::IndexOf($names,'NeedsValueSlot');if($needsIndex -lt 0){throw 'Missing materialization decision'}
 $pattern='(?ms)^define i32 @ube.p'+$needsIndex+'\(ptr %arg.\d+, i32 %arg.\d+\) \{\r?\n.*?^\}'
 if([regex]::Matches($compilerRaw,$pattern).Count -ne 1 -or $compilerRaw -notmatch '(?m)^%ube.type.4 = type \{ i32, i32, i32, i32, i32, i32, i32, i32 \}\r?$'){throw 'Eager decision adapter ABI/layout differs'}
 $eagerBody="define i32 @ube.p$needsIndex(ptr %arg.0, i32 %arg.1) {`nentry:`n  %array = load ptr, ptr %arg.0`n  %node = call ptr @ube_array_element(ptr %array, i32 %arg.1)`n  %type.address = getelementptr i8, ptr %node, i64 20`n  %type = load i32, ptr %type.address`n  %needed = icmp sge i32 %type, 1000`n  %answer = zext i1 %needed to i32`n  ret i32 %answer`n}"
 $eagerPath=Join-Path $run 'eager-compiler.ll';[IO.File]::WriteAllText($eagerPath,[regex]::Replace($compilerRaw,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($m) $eagerBody}),$utf8)
 $eager=Join-Path $run 'eager-compiler.exe'
 $null=Run-Checked $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',$eagerPath,$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$eager)
 $cases=@(
  [pscustomobject]@{name='byref-address';source=(Join-Path $PSScriptRoot 'byref-address.bas');stdout="17`n"},
  [pscustomobject]@{name='record-address';source=(Join-Path $PSScriptRoot 'record-address.bas');stdout="17`n23`n17`n31`n29`n"},
  [pscustomobject]@{name='borrowed-array';source=(Join-Path $root 'std-lib/tests/managed-storage/borrowed-element.bas');stdout="65`n88`n99`n99`n"},
  [pscustomobject]@{name='reference-results';source=(Join-Path $root 'compiler/UBE_Compiler_v2/tests/concurrency/ReferenceBasics.UBE');stdout="99`n23`n1`n41`n31`n7`n67`n3`n2`n53`n67`n4`n"}
 )
 foreach($case in $cases){
  $inputs+=Get-ArtifactIdentity $case.source
  $old=Join-Path $run ($case.name+'-eager.ll');$null=Run-Checked $eager @($case.source,$old)
  $raws=@()
  for($stage=0;$stage -lt 2;++$stage){
   $stem=Join-Path $run ($case.name+'-stage'+($stage+1));$null=Run-Checked $stages[$stage] @($case.source,($stem+'.ll'));$raws+=Get-ArtifactIdentity ($stem+'.ll')
   $adapted=$stem+'-adapter.ll';[IO.File]::WriteAllText($adapted,[regex]::Replace([IO.File]::ReadAllText($stem+'.ll'),'(?m)^define i32 @main\(','define i32 @fixture_main('),$utf8)
   $null=Run-Checked $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',(Join-Path $root 'bootstrap/runtime'),$adapted,(Join-Path $PSScriptRoot 'lifetime.c'),$selection.unicodeRuntime.path,'-o',($stem+'.exe'))
   $native=Run-Checked ($stem+'.exe') @()
   if($native.stdout -cne $case.stdout){throw ('Independent fixture stdout differs: '+$case.name)}
   $outputs+=[pscustomobject]@{name=$case.name;stage=$stage;raw=$raws[-1];native=$native}
   Check ($case.name+' stage'+($stage+1)+': exact independent output under forced GC, native zero-root and zero-payload drain')
  }
  if($raws[0].sha256 -cne $raws[1].sha256){throw 'Fixture source-stage LLVM differs'}
  Check ($case.name+': both source-built stages emit byte-identical raw LLVM')
  $witness=Compare-ValueSlotFootprint ([IO.File]::ReadAllText($old)) ([IO.File]::ReadAllText($raws[0].path))
  if($witness.omittedValueSlots -lt 1){throw 'Fixture does not witness any omitted value slot'}
  if($case.name -ceq 'byref-address'){
   $fixtureProcedures=@([regex]::Matches([IO.File]::ReadAllText($case.source),'(?m)^(?:Intrinsic )?(?:Function|Sub) ([A-Za-z_][A-Za-z_0-9]*)\b')|ForEach-Object {$_.Groups[1].Value})
   $forwardIndex=[Array]::IndexOf($fixtureProcedures,'Forward');if($forwardIndex -lt 0){throw 'Missing Forward witness procedure'}
   $forward=@($witness.details|Where-Object {$_.header -match ('^define i32 @ube\.p'+$forwardIndex+'\(')})
   $mainIndex=[Array]::IndexOf($fixtureProcedures,'Main');if($mainIndex -lt 0){throw 'Missing Main witness procedure'}
   $main=@($witness.details|Where-Object {$_.header -match ('^define i32 @ube\.p'+$mainIndex+'\(')})
   # This comparator forces every managed slot, including the already omitted
   # Document base (13) of Document.Bytes. The four Forward ByRef actuals are
   # 1/5/9/14; Main forwards its three managed locals through 22/24/26.
   if($witness.omittedValueSlots -ne 8 -or $forward.Count -ne 1 -or ($forward[0].omittedNodes -join ',') -cne '1,5,9,13,14' -or $main.Count -ne 1 -or ($main[0].omittedNodes -join ',') -cne '22,24,26'){throw 'Complete ByRef eager comparator must omit exactly four Forward actuals, its existing member base, and three Main actuals'}
  }
  $witnesses+=[pscustomobject]@{name=$case.name;eager=(Get-ArtifactIdentity $old);current=$raws[0];footprint=$witness}
  Check ($case.name+': every omitted slot has only neutral/root bookkeeping uses; all genuine materializations, ByVal, borrow, result, cleanup and native ABI instructions match eager oracle exactly')
 }
 $negative=Join-Path $PSScriptRoot 'byref-rvalue.bas'
 $expected=$negative+"(4,12): error UBE3202: ByRef argument must be an addressable variable`n"
 for($stage=0;$stage -lt 2;++$stage){
  $path=Join-Path $run ('byref-rvalue-stage'+($stage+1)+'.ll')
  $record=Invoke-BoundedProcess $stages[$stage] @($negative,$path) $root 30;$commands+=$record
  if($record.timedOut -or $record.exit -ne 1 -or $record.stdout -cne $expected -or $record.stderr -cne '' -or (Test-Path $path)){throw ('ByRef literal rejection differs: '+($record|ConvertTo-Json -Depth 5 -Compress))}
  $outputs+=[pscustomobject]@{name='byref-rvalue';stage=$stage;native=$record}
  Check ('ByRef literal stage'+($stage+1)+': exact independent UBE3202 diagnostic and no LLVM publication')
 }
 $oldFixture="define i32 @probe() {`nentry:`n  %value.1 = alloca ptr`n  %scratch.1 = alloca ptr`n  store ptr zeroinitializer, ptr %value.1`n  store ptr zeroinitializer, ptr %scratch.1`n  ret i32 0`n}"
 $newFixture="define i32 @probe() {`nentry:`n  ret i32 0`n}"
 $null=Compare-ValueSlotFootprint $oldFixture $newFixture
 foreach($control in @(
  @('real slot use',$oldFixture.Replace('  ret i32 0',"  %read = load ptr, ptr %value.1`n  ret i32 0"),$newFixture),
  @('genuine instruction',$oldFixture,$newFixture.Replace('ret i32 0','ret i32 1')),
  @('native ABI',$oldFixture,$newFixture.Replace('define i32','define i64')),
  @('partial scratch omission',$oldFixture,$newFixture.Replace('  ret i32 0',"  %scratch.1 = alloca ptr`n  ret i32 0"))
 )){
  $rejected=$false;try{$null=Compare-ValueSlotFootprint $control[1] $control[2]}catch{$rejected=$true}
  if(-not $rejected){throw ('Emitted-use oracle accepted corruption: '+$control[0])}
  Check ('Emitted-use negative control rejects '+$control[0])
 }
 foreach($pin in $inputs){$now=Get-ArtifactIdentity $pin.path;if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Proof input changed: '+$pin.path)}}
 $null=Get-VerifiedBootstrapSelection $SelectionPath
 if($checks.Count -ne 25){throw ('Materialization proof assertion accounting differs: '+$checks.Count)}
 $success=$true
}catch{$failure=$_.Exception.Message}finally{
 $path=Join-Path $run 'report.json'
 [pscustomobject]@{schema='ube-value-materialization-proof-1';success=$success;failure=$failure;acceptedSelection=$acceptedSelection;inputs=$inputs;checks=$checks;outputs=$outputs;witnesses=$witnesses;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Independent classifier and actual slot-use/lifetime regression; same-cohort test-only eager decision. Existing managed/root/entry/reference/thread gates remain required. No timing or performance-acceptance claim.'}|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $path -Encoding UTF8
 Write-Output ('Evidence: '+$path)
}
if(-not $success){throw $failure}
Write-Output ('PASS: '+$checks.Count+' value-materialization assertions.')
