param(
    [string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'),
    [switch]$DiagnosticOnly,
    [string]$CompiledSnapshot,
    [string]$ReuseRun,
    [string]$CaseSensitiveRoot
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
if($ReuseRun){$ReuseRun=[IO.Path]::GetFullPath($ReuseRun)}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/project-intake/'+[Guid]::NewGuid().ToString('N'))
$project=Join-Path $run 'project'
$null=New-Item -ItemType Directory $project -Force
$utf8=[Text.UTF8Encoding]::new($false)
$names=@('SourceOwner.cls','SourceWork.cls','SourceCancellation.cls','SourceWorkerSlots.bas','SourceParsing.bas','SourceInput.bas','SourceFile.bas','ScannerWords.bas','SourceScanner.bas','SourceEnvelope.bas','SyntaxTree.bas','SyntaxExpressions.bas','SyntaxGrammar.bas','SourceSyntax.bas','ProjectManifest.bas','ProjectPackage.cls','ProjectSource.cls','ProjectInput.cls','ProjectSyntax.cls','ProjectLoading.bas')
$inputs=@();$commands=@();$checks=@();$success=$false;$failure=$null;$selection=$null
$caseSensitiveEvidence=$null;$caseSensitiveFixture=$null
function Run-IntakeProcess([string]$Program,[string[]]$Values,[int]$Timeout=300){
    $record=Invoke-BoundedProcess $Program $Values $root $Timeout
    $script:commands+=$record
    if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne ''){throw ($record | ConvertTo-Json -Depth 5)}
    return $record
}
function Write-IntakeFile([string]$Relative,[string]$Text){
    $path=Join-Path $run ('fixtures/'+$Relative)
    $null=New-Item -ItemType Directory (Split-Path $path -Parent) -Force
    [IO.File]::WriteAllText($path,$Text,$utf8)
    return $path
}
function Project-Text([string]$Name,[string[]]$Sources,[string[]]$References=@(),[string]$Kind='Exe'){
    $lines=@('UBE-Project 1',('Name = "'+$Name+'"'),('Kind = "'+$Kind+'"'))
    if($Kind -ceq 'Exe'){$lines+='Startup = "Main"'}
    $lines+=@($Sources | ForEach-Object {'Source = "'+$_+'"'})
    $lines+=@($References | ForEach-Object {'Reference = "'+$_+'"'})
    return ($lines -join "`n")+"`n"
}
try{
    if($CompiledSnapshot -and -not $DiagnosticOnly){throw 'Compiled snapshots are diagnostic only'}
    if($ReuseRun -and (-not $DiagnosticOnly -or $CompiledSnapshot)){throw 'Build reuse is diagnostic only and excludes a separate snapshot'}
    $reuseReport=$null
    if($ReuseRun){
        $reuseReport=Get-Content (Join-Path $ReuseRun 'report.json') -Raw | ConvertFrom-Json
        $inputs+=Get-ArtifactIdentity (Join-Path $ReuseRun 'report.json')
    }
    if($DiagnosticOnly){$selection=Get-Content $SelectionPath -Raw | ConvertFrom-Json}else{$selection=Get-VerifiedBootstrapSelection $SelectionPath}
    foreach($property in $selection.PSObject.Properties){
        if($property.Name -ne 'schema'){
            if((Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256){throw 'Selected artifact changed'}
            $inputs+=$property.Value
        }
    }
    $accepted=Get-Content $selection.manifest.path -Raw | ConvertFrom-Json
    if(-not $accepted.success){throw 'Unsuccessful selected compiler'}
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    foreach($stage in $stages){
        $identity=@($accepted.artifacts | Where-Object path -CEQ $stage)
        if($identity.Count -ne 1 -or (Get-ArtifactIdentity $stage).sha256 -cne $identity[0].sha256){throw 'Stage identity differs'}
        $inputs+=$identity[0]
    }
    $ordered=@()
    foreach($name in $names){
        $path=Join-Path $root ('compiler/UBE_Compiler_v3/src/'+$name)
        if($CompiledSnapshot){$path=Join-Path $CompiledSnapshot $name}
        if($ReuseRun){
            $cached=Join-Path $ReuseRun ('project/'+$name)
            if((Get-ArtifactIdentity $cached).sha256 -cne (Get-ArtifactIdentity $path).sha256){throw ('Cached UBE input differs: '+$name)}
        }
        Copy-Item $path (Join-Path $project $name)
        $ordered+=$path;$inputs+=Get-ArtifactIdentity $path
    }
    $entry=Join-Path $project 'Entry.bas'
    if($CompiledSnapshot){Copy-Item (Join-Path $CompiledSnapshot 'Entry.bas') $entry}else{
      if($ReuseRun){Copy-Item (Join-Path $ReuseRun 'project/Entry.bas') $entry}else{
        [IO.File]::WriteAllText($entry,"UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""IntakeProof""`nFunction Main() As Long`n    Main = 0`nEnd Function`n",$utf8)
      }
    }
    $ordered+=$entry;$inputs+=Get-ArtifactIdentity $entry
    $manifest=Join-Path $project 'IntakeProof.UBE'
    $lines=@('UBE-Project 1','Name = "IntakeProof"','Kind = "Exe"','Startup = "Main"')+@($names | ForEach-Object {'Source = "'+$_+'"'})+@('Source = "Entry.bas"','Reference = "../../../../../std-lib/UBECore.UBE"')
    [IO.File]::WriteAllText($manifest,($lines -join "`n")+"`n",$utf8)
    $coreManifest=Join-Path $root 'std-lib/UBECore.UBE'
    $inputs+=Get-ArtifactIdentity $coreManifest
    foreach($match in [regex]::Matches([IO.File]::ReadAllText($coreManifest),'(?m)^Source = "([^"]+)"')){
        $path=[IO.Path]::GetFullPath((Join-Path (Split-Path $coreManifest -Parent) $match.Groups[1].Value))
        $ordered+=$path;$inputs+=Get-ArtifactIdentity $path
    }
    if($ReuseRun){
        foreach($identity in @($inputs | Where-Object { $_.path.StartsWith((Join-Path $root 'std-lib'),[StringComparison]::OrdinalIgnoreCase) -or $_.path -in @($stages+$selection.compiler.path+$selection.runtime.path+$selection.unicodeRuntime.path) })){
            $record=@($reuseReport.inputs | Where-Object path -CEQ $identity.path)
            if($record.Count -lt 1 -or @($record | Where-Object sha256 -CNE $identity.sha256).Count -ne 0){throw ('Cached compiler/import identity differs: '+$identity.path)}
        }
    }
    $procedures=@{};$types=@{};$classes=@{};$procedureIndex=0;$typeIndex=0;$classIndex=0
    foreach($path in $ordered){
        $contents=[IO.File]::ReadAllText($path)
        if($contents -match '(?m)^UBE SOURCE 1 CLASS\r?$'){
            $name=[regex]::Match($contents,'Attribute UBE_Name = "([^"]+)"').Groups[1].Value
            $types[$name]='%ube.type.'+$typeIndex;$typeIndex++
            $classes[$name]=$classIndex;$classIndex++
        }
    }
    foreach($path in $ordered){
        $contents=[IO.File]::ReadAllText($path)
        foreach($match in [regex]::Matches($contents,'(?m)^(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){
            $name=$match.Groups[1].Value
            if($procedures.ContainsKey($name)){throw 'Duplicate procedure'}
            $procedures[$name]='ube.p'+$procedureIndex;$procedureIndex++
        }
        foreach($match in [regex]::Matches($contents,'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$match.Groups[1].Value]='%ube.type.'+$typeIndex;$typeIndex++}
    }
    $module="UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""Main""`nFunction Main() As Long`n    Main = 0`nEnd Function`n"
    $null=Write-IntakeFile 'app/src/Main.bas' $module
    $null=Write-IntakeFile 'app/src/Helper.bas' ($module.Replace('"Main"','"Helper"').Replace('Function Main','Function Value').Replace('Main = 0','Value = 7'))
    $null=Write-IntakeFile 'core/Core.bas' ($module.Replace('"Main"','"CoreValue"').Replace('Function Main','Function CoreValue').Replace('Main = 0','CoreValue = 1'))
    $null=Write-IntakeFile 'core/UBECore.UBE' (Project-Text 'UBECore' @('Core.bas') @() 'Library')
    $plain=Write-IntakeFile 'app/plain.UBE' (Project-Text 'App' @('src/Main.bas','src/Helper.bas'))
    $linked=Write-IntakeFile 'app/linked.UBE' (Project-Text 'App' @('src/Main.bas','src/Helper.bas') @('../core/UBECore.UBE'))
    $rows=[Collections.Generic.List[string]]::new()
    function Add-Case([string]$Name,[string]$Path,[int]$Kind,[int]$Code,[int]$Source=-1,[int]$Unit=-1,[int]$Packages=0,[int]$Sources=0,[int]$Option=0,[int]$Oracle=0){
        $escaped=$Path.Replace('\','/').Replace('"','\"')
        $rows.Add(('{"'+$Name+'","'+$escaped+'",'+(@($Kind,$Code,$Source,$Unit,$Packages,$Sources,$Option,$Oracle) -join ',')+'}'))
    }
    if($CaseSensitiveRoot){
        $CaseSensitiveRoot=[IO.Path]::GetFullPath($CaseSensitiveRoot)
        if(-not (Test-Path -LiteralPath $CaseSensitiveRoot -PathType Container)){throw 'Case-sensitive parent must already exist'}
        $nativeFsutil=(Get-Command fsutil.exe -CommandType Application).Source
        $inputs+=Get-ArtifactIdentity $nativeFsutil
        $parentQuery=Run-IntakeProcess $nativeFsutil @('file','queryCaseSensitiveInfo',$CaseSensitiveRoot) 30
        if($parentQuery.stdout -notmatch ' is enabled\.\s*$'){throw 'Requested case-sensitive parent is not enabled; no setting changes are permitted'}
        $caseSensitiveFixture=Join-Path $CaseSensitiveRoot ('project-intake-'+(Split-Path $run -Leaf))
        $null=New-Item -ItemType Directory -Path $caseSensitiveFixture
        $childQuery=Run-IntakeProcess $nativeFsutil @('file','queryCaseSensitiveInfo',$caseSensitiveFixture) 30
        $caseSensitiveEvidence=[pscustomobject]@{parent=$CaseSensitiveRoot;parentQuery=$parentQuery;fixture=$caseSensitiveFixture;fixtureQuery=$childQuery;files=@()}
        if($childQuery.stdout -notmatch ' is enabled\.\s*$'){throw 'Unique fixture did not inherit case sensitivity; no setting changes are permitted'}
        $upper=Join-Path $caseSensitiveFixture 'Main.bas'
        $lower=Join-Path $caseSensitiveFixture 'main.bas'
        [IO.File]::WriteAllText($upper,$module.Replace('"Main"','"UpperValue"'),$utf8)
        [IO.File]::WriteAllText($lower,$module.Replace('"Main"','"LowerValue"'),$utf8)
        $fileIds=@()
        foreach($sensitiveSource in @($upper,$lower)){
            $idQuery=Run-IntakeProcess $nativeFsutil @('file','queryFileID',$sensitiveSource) 30
            $id=[regex]::Match($idQuery.stdout,'0x[0-9a-fA-F]+').Value
            if(-not $id){throw 'Native source file identity query returned no identity'}
            $fileIds+=$id
            $caseSensitiveEvidence.files+=[pscustomobject]@{path=$sensitiveSource;identity=$id;query=$idQuery}
        }
        if($fileIds[0] -ieq $fileIds[1]){throw 'Differently cased source names did not create distinct physical files'}
        $sensitiveManifest=Join-Path $caseSensitiveFixture 'Sensitive.UBE'
        [IO.File]::WriteAllText($sensitiveManifest,(Project-Text 'App' @('Main.bas','main.bas')),$utf8)
        Add-Case 'case-sensitive-physical-sources' $sensitiveManifest 0 0 -1 -1 1 2 0 4
    }
    Add-Case 'ordered-root' $plain 0 0 -1 -1 1 2
    Add-Case 'ordered-direct-core' $linked 0 0 -1 -1 2 3
    Add-Case 'normalized-source' (Write-IntakeFile 'app/normalized.UBE' (Project-Text 'App' @('src/./unused/../Main.bas','src/Helper.bas'))) 0 0 -1 -1 1 2 0 1
    $unicodeDirectory='unicode/'+[char]0x00C5+[char]0x03A9+[char]::ConvertFromUtf32(0x1F642)
    $unicodeRoot=Join-Path $run ('fixtures/'+$unicodeDirectory)
    $null=New-Item -ItemType Directory $unicodeRoot -Force
    Copy-Item (Join-Path $run 'fixtures/app') $unicodeRoot -Recurse
    Copy-Item (Join-Path $run 'fixtures/core') $unicodeRoot -Recurse
    Add-Case 'unicode-parent-direct-core' (Join-Path $unicodeRoot 'app/linked.UBE') 0 0 -1 -1 2 3
    Add-Case 'reverse-declaration-order' (Write-IntakeFile 'app/reversed.UBE' (Project-Text 'App' @('src/Helper.bas','src/Main.bas') @('../core/UBECore.UBE'))) 0 0 -1 -1 2 3 0 3
    $null=Write-IntakeFile 'core/Same.bas' $module
    $null=Write-IntakeFile 'core/SameNames.UBE' (Project-Text 'UBECore' @('Same.bas') @() 'Library')
    Add-Case 'same-name-distinct-packages' (Write-IntakeFile 'app/package-local.UBE' (Project-Text 'App' @('src/Main.bas','src/Helper.bas') @('../core/SameNames.UBE'))) 0 0 -1 -1 2 3 0 2
    foreach($item in @(@('zero-sources',1,2,1309),@('zero-manifest',2,2,1309),@('zero-packages',3,2,1309),@('zero-source-bytes',4,2,1309),@('zero-tokens',5,2,1309),@('zero-total-source',6,2,1309),@('zero-path',7,2,1309),@('zero-metadata',8,2,1309),@('invalid-depth',9,1,1320),@('cancel-before-intake',10,8,1317))){
        $unit=-1
        Add-Case $item[0] $plain $item[2] $item[3] -1 $unit 0 0 $item[1]
    }
    Add-Case 'duplicate-normalized-source' (Write-IntakeFile 'app/duplicate.UBE' (Project-Text 'App' @('src/Main.bas','src/./Main.bas'))) 3 1312
    $null=New-Item -ItemType HardLink -Path (Join-Path $run 'fixtures/app/src/Alias.bas') -Target (Join-Path $run 'fixtures/app/src/Main.bas')
    Add-Case 'source-hard-link' (Write-IntakeFile 'app/hard-link.UBE' (Project-Text 'App' @('src/Main.bas','src/Alias.bas'))) 3 1312 1
    $null=Write-IntakeFile 'app/src/Copy.bas' $module
    Add-Case 'identical-bytes-distinct-file' (Write-IntakeFile 'app/copied.UBE' (Project-Text 'App' @('src/Main.bas','src/Copy.bas'))) 3 1316 1
    Add-Case 'absolute-source' (Write-IntakeFile 'app/absolute.UBE' (Project-Text 'App' @('C:/outside.bas'))) 3 1308
    Add-Case 'source-parent' (Write-IntakeFile 'app/parent.UBE' (Project-Text 'App' @('../outside.bas'))) 4 1307
    Add-Case 'source-missing' (Write-IntakeFile 'app/missing.UBE' (Project-Text 'App' @('src/Missing.bas'))) 6 0 0
    $null=Write-IntakeFile 'app/src/AliasName.bas' ($module.Replace('"Main"','"[mAiN]"'))
    Add-Case 'folded-source-name' (Write-IntakeFile 'app/name.UBE' (Project-Text 'App' @('src/Main.bas','src/AliasName.bas'))) 3 1316 1
    $null=Write-IntakeFile 'app/src/Omega.bas' ($module.Replace('"Main"',('"'+[char]0x03A9+'"')))
    $null=Write-IntakeFile 'app/src/FoldedOmega.bas' ($module.Replace('"Main"',('"'+[char]0x03C9+'"')))
    Add-Case 'unicode-folded-source-name' (Write-IntakeFile 'app/unicode-name.UBE' (Project-Text 'App' @('src/Omega.bas','src/FoldedOmega.bas'))) 3 1316 1
    Add-Case 'self-reference' (Write-IntakeFile 'app/self.UBE' (Project-Text 'App' @('src/Main.bas') @('self.UBE'))) 3 1313
    $selfAlias=Write-IntakeFile 'app/self-link.UBE' (Project-Text 'App' @('src/Main.bas') @('self-alias.UBE'))
    $null=New-Item -ItemType HardLink -Path (Join-Path $run 'fixtures/app/self-alias.UBE') -Target $selfAlias
    Add-Case 'manifest-hard-link-self' $selfAlias 3 1313
    Add-Case 'duplicate-reference' (Write-IntakeFile 'app/repeated.UBE' (Project-Text 'App' @('src/Main.bas') @('../core/UBECore.UBE','../core/./UBECore.UBE'))) 3 1313
    $null=New-Item -ItemType HardLink -Path (Join-Path $run 'fixtures/core/CoreAlias.UBE') -Target (Join-Path $run 'fixtures/core/UBECore.UBE')
    Add-Case 'reference-hard-link' (Write-IntakeFile 'app/reference-link.UBE' (Project-Text 'App' @('src/Main.bas','src/Helper.bas') @('../core/UBECore.UBE','../core/CoreAlias.UBE'))) 3 1313
    $null=Write-IntakeFile 'other/Other.UBE' (Project-Text 'Other' @('Other.bas') @() 'Library')
    Add-Case 'other-library-unavailable' (Write-IntakeFile 'app/other.UBE' (Project-Text 'App' @('src/Main.bas') @('../other/Other.UBE'))) 4 1307
    $null=Write-IntakeFile 'core/Collision.UBE' (Project-Text '[aPP]' @('Core.bas') @() 'Library')
    Add-Case 'package-collision' (Write-IntakeFile 'app/collision.UBE' (Project-Text 'App' @('src/Main.bas') @('../core/Collision.UBE'))) 3 1315
    $null=Write-IntakeFile 'core/Cycle.UBE' (Project-Text 'UBECore' @('Core.bas') @('../app/cycle.UBE') 'Library')
    Add-Case 'ancestor-cycle' (Write-IntakeFile 'app/cycle.UBE' (Project-Text 'App' @('src/Main.bas') @('../core/Cycle.UBE'))) 3 1314
    $null=Write-IntakeFile 'core/Self.UBE' (Project-Text 'UBECore' @('Core.bas') @('Self.UBE') 'Library')
    Add-Case 'library-self' (Write-IntakeFile 'app/core-self.UBE' (Project-Text 'App' @('src/Main.bas') @('../core/Self.UBE'))) 3 1313
    $null=Write-IntakeFile 'core/Transitive.UBE' (Project-Text 'UBECore' @('Core.bas') @('../other/Other.UBE') 'Library')
    Add-Case 'transitive-unavailable' (Write-IntakeFile 'app/transitive.UBE' (Project-Text 'App' @('src/Main.bas') @('../core/Transitive.UBE'))) 4 1307
    $null=Write-IntakeFile 'app/src/Class.cls' ($module.Replace('MODULE','CLASS').Replace('"Main"','"ObjectValue"'))
    Add-Case 'class-deferred' (Write-IntakeFile 'app/class.UBE' (Project-Text 'App' @('src/Class.cls'))) 7 0 0 3
    $null=Write-IntakeFile 'app/src/Bad.bas' ($module.Replace('"Main"','"Bad"')+"~`n")
    Add-Case 'worker-scanner-failure' (Write-IntakeFile 'app/bad.UBE' (Project-Text 'App' @('src/Main.bas','src/Bad.bas'))) 7 0 1 201
    # A distinct fixture leaves the original 35-case/allocation cohort unchanged.
    $contractApp=Join-Path $run 'fixtures/contract/app'
    $contractCore=Join-Path $run 'fixtures/contract/core'
    $richText=[char]65279+"' package metadata`r`nUBE-Project 1`r`nName = ""["+[char]0x00C5+"pp]""`r`nKind = ""Exe""`r`nStartup = ""Main""`r`nSource = ""src/Main.bas""`r`nSource = ""src/Helper.bas""`r`nReference = ""../core/UBECore.UBE""`r`nOptimization = ""3""`r`nDebugInformation = ""Line""`r`n"
    $contractManifest=Write-IntakeFile 'contract/app/Rich.UBE' $richText
    $contractMain=Write-IntakeFile 'contract/app/src/Main.bas' ($module.Replace('Main = 0','Main = (0)'))
    $contractHelper=Write-IntakeFile 'contract/app/src/Helper.bas' ($module.Replace('"Main"','"Helper"').Replace('Function Main','Function Value').Replace('Main = 0','Value = 7'))
    $contractCoreManifest=Write-IntakeFile 'contract/core/UBECore.UBE' (Project-Text 'UBECore' @('Core.bas') @() 'Library')
    $contractCoreSource=Write-IntakeFile 'contract/core/Core.bas' ($module.Replace('"Main"','"CoreValue"').Replace('Function Main','Function CoreValue').Replace('Main = 0','CoreValue = 1'))
    $rejectedProject=Write-IntakeFile 'contract/rejected/Failed.UBE' (Project-Text 'Failed' @('First.bas','Second.bas'))
    $null=Write-IntakeFile 'contract/rejected/First.bas' "UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""Reject""`nType EmptyRecord`nEnd Type`n"
    $null=Write-IntakeFile 'contract/rejected/Second.bas' "UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""RejectLater""`nType AnotherEmpty`nEnd Type`n"
    $contractDefinitions=[Text.StringBuilder]::new()
    foreach($binding in @(@('MANIFEST',$contractManifest),@('APP_DIRECTORY',$contractApp),@('MAIN',$contractMain),@('HELPER',$contractHelper),@('CORE_MANIFEST',$contractCoreManifest),@('CORE_DIRECTORY',$contractCore),@('CORE_SOURCE',$contractCoreSource),@('REJECTED',$rejectedProject))){
        $null=$contractDefinitions.AppendLine('#define INTAKE_CONTRACT_'+$binding[0]+' "'+$binding[1].Replace('\','/')+'"')
    }
    $null=$contractDefinitions.AppendLine('#define INTAKE_WORKING_DIRECTORY "'+$root.Replace('\','\\')+'"')
    $null=$contractDefinitions.AppendLine('static const struct intake_case intake_contract_case={"independent-metadata",INTAKE_CONTRACT_MANIFEST,0,0,-1,-1,2,3,11,0};')
    $header=Join-Path $run 'intake-cases.h'
    $invalid=Write-IntakeFile 'invalid.UBE' ''
    [IO.File]::WriteAllBytes($invalid,[byte[]]@(255))
    [IO.File]::WriteAllText($header,('#define INTAKE_INVALID_MANIFEST "'+$invalid.Replace('\','/')+'"'+"`n"+'static const struct intake_case intake_cases[]={'+($rows -join ",`n")+'};'+"`n"+$contractDefinitions.ToString()),$utf8)
    $fixture=Join-Path $root 'compiler/UBE_Compiler_v3/tests/project-input/intake.c'
    $inputs+=@((Get-ArtifactIdentity $fixture),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity $header),(Get-ArtifactIdentity (Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c')))
    foreach($helper in @('intake-observation.h','intake-contract-proof.h')){$inputs+=Get-ArtifactIdentity (Join-Path $root ('compiler/UBE_Compiler_v3/tests/project-input/'+$helper))}
    foreach($relative in @('bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/thread_primitives.c','compiler/UBE_Compiler_v3/tests/project-input/diagnostic-layout.h','compiler/UBE_Compiler_v3/tests/project-input/CONTEXT-COVERAGE.md','compiler/UBE_Compiler_v3/tests/project-input/ORACLES.md','compiler/UBE_Compiler_v3/PROJECT-INPUT-CONTRACT.md','compiler/UBE_Compiler_v3/PROJECT-METADATA-CONTRACT.md','compiler/UBE_Compiler_v3/PROJECT-DIAGNOSTICS.md')){$inputs+=Get-ArtifactIdentity (Join-Path $root $relative)}
    $inputs+=@(Get-ChildItem (Join-Path $run 'fixtures') -Recurse -File | ForEach-Object {Get-ArtifactIdentity $_.FullName})
    if($caseSensitiveFixture){$inputs+=@(Get-ChildItem -LiteralPath $caseSensitiveFixture -File | ForEach-Object {Get-ArtifactIdentity $_.FullName})}
    $prior=$null
    for($index=0;$index -lt 2;$index++){
        $stem=Join-Path $run ('stage'+$index)
        $cachedRaw=$null
        if($ReuseRun){$candidate=Join-Path $ReuseRun ('stage'+$index+'.ll');if(Test-Path $candidate){$cachedRaw=$candidate}}
        if($CompiledSnapshot){Copy-Item (Join-Path $CompiledSnapshot ('stage'+$index+'.ll')) ($stem+'.ll')}else{
          if($cachedRaw){
            $record=@($reuseReport.inputs | Where-Object path -CEQ $cachedRaw)
            if($record.Count -ne 1 -or (Get-ArtifactIdentity $cachedRaw).sha256 -cne $record[0].sha256){throw 'Cached raw LLVM identity differs'}
            Copy-Item $cachedRaw ($stem+'.ll')
          }else{$null=Run-IntakeProcess $stages[$index] @($manifest,($stem+'.ll'))}
        }
        $raw=[IO.File]::ReadAllText($stem+'.ll');$identity=Get-ArtifactIdentity ($stem+'.ll');$inputs+=$identity
        if($prior -and $prior -cne $identity.sha256){throw 'Source-built stages emitted different raw LLVM'};$prior=$identity.sha256
        $adapter=[Text.StringBuilder]::new()
        foreach($binding in @(@('intake_parse','TryParseProject','i1','ptr,ptr,i32,ptr,ptr,ptr,ptr'),@('intake_limits','DefaultProjectLimits','void','ptr'))){
            $symbol=$procedures[$binding[1]]
            $found=[regex]::Matches($raw,'(?m)^define '+$binding[2]+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
            if($found.Count -ne 1){throw ('Missing ABI '+$binding[1])}
            $actual=@($found[0].Groups[1].Value -split ', ' | ForEach-Object {($_ -split ' ')[0]}) -join ','
            if($actual -cne $binding[3]){throw ('Mismatched ABI '+$binding[1])}
            $args=@();$calls=@();$parts=$binding[3] -split ','
            for($i=0;$i -lt $parts.Count;$i++){$args+=($parts[$i]+' %a'+$i);$calls+=($parts[$i]+' %a'+$i)}
            $ret=$binding[2];if($ret -ceq 'i1'){$ret='i32'}
            $null=$adapter.AppendLine('define '+$ret+' @'+$binding[0]+'('+($args -join ', ')+') {')
            if($ret -ceq 'i32'){
                $null=$adapter.AppendLine(' %ok = call i1 @'+$symbol+'('+($calls -join ', ')+')')
                $null=$adapter.AppendLine(' %value = zext i1 %ok to i32')
                $null=$adapter.AppendLine(' ret i32 %value')
            }else{$null=$adapter.AppendLine(' call void @'+$symbol+'('+($calls -join ', ')+')');$null=$adapter.AppendLine(' ret void')}
            $null=$adapter.AppendLine('}')
        }
        $sizeNames=@('SourceDocument','ProjectManifest','ProjectPath','SourceEnvelope','ProjectPackage','ProjectSource','ProjectInput','ProjectSyntax','ProjectLimits','ProjectFailure','SourceOwner','SourceWork')
        $null=$adapter.AppendLine('define i64 @intake_size(i32 %role) {')
        $null=$adapter.AppendLine(' switch i32 %role, label %invalid [')
        for($i=0;$i -lt $sizeNames.Count;$i++){$null=$adapter.AppendLine(' i32 '+$i+', label %size'+$i)}
        $null=$adapter.AppendLine(' ]');$null=$adapter.AppendLine('invalid:');$null=$adapter.AppendLine(' ret i64 -1')
        for($i=0;$i -lt $sizeNames.Count;$i++){
            $type=$types[$sizeNames[$i]]
            if($raw -notmatch ([regex]::Escape($type)+' = type \{')){throw ('Missing type '+$sizeNames[$i])}
            $null=$adapter.AppendLine('size'+$i+':');$null=$adapter.AppendLine(' ret i64 ptrtoint (ptr getelementptr ('+$type+', ptr null, i32 1) to i64)')
        }
        $null=$adapter.AppendLine('}')
        $null=$adapter.AppendLine("define ptr @intake_class(i32 %role) {`n ret ptr @ube.object."+$classes.SourceCancellation+"`n}")
        $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @intake_unused_main(')+"`n"+$adapter.ToString()
        # Reuse the qualified worker entry/exit observation seam. Bodies stay intact.
        $workSymbol=$procedures.ProcessSourceWork
        $worker=[regex]::Match($adapted,'(?ms)^define void @'+[regex]::Escape($workSymbol)+'\(([^\r\n]*)\) \{.*?^\}')
        if(-not $worker.Success -or [regex]::Matches($worker.Value,'(?m)^thread.body:\r?$').Count -ne 1 -or [regex]::Matches($worker.Value,'(?m)^proc.exit:\r?$').Count -ne 1){throw 'Actual worker observation boundary differs'}
        $workArgument=($worker.Groups[1].Value -split ', ')[0] -replace '^ptr ',''
        $workerBody=[regex]::Replace($worker.Value,'(?m)^thread.body:\r?$','thread.body:'+"`n call void @intake_observe_enter(ptr $workArgument)")
        $workerBody=[regex]::Replace($workerBody,'(?m)^proc.exit:\r?$','proc.exit:'+"`n call void @intake_observe_exit(ptr $workArgument)")
        $adapted=$adapted.Substring(0,$worker.Index)+$workerBody+$adapted.Substring($worker.Index+$worker.Length)+"`n"+'declare void @intake_observe_enter(ptr)'+"`n"+'declare void @intake_observe_exit(ptr)'+"`n"
        [IO.File]::WriteAllText($stem+'-adapted.ll',$adapted,$utf8)
        $null=Run-IntakeProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',$run,'-I',(Join-Path $root 'bootstrap/runtime'),($stem+'-adapted.ll'),$fixture,$selection.unicodeRuntime.path,'-o',($stem+'.exe'))
        $native=Run-IntakeProcess ($stem+'.exe') @()
        if($native.stdout -notmatch ('^PASS project intake cases:'+$rows.Count+' budgets:6 contexts:4 assertions:[0-9]+\r?\n$')){throw 'Unexpected native result'}
        $checks+=[pscustomobject]@{assertion="stage $($index+1): actual UBE project intake and parser at budgets 1/2/4, independent identity/order outcomes, complete graph equality, four simultaneous private contexts, cancellation isolation and cleanup";passed=$true;output=$native.stdout}
        $null=Run-IntakeProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-DUBE_FILE_TESTING','-I',$run,'-I',(Join-Path $root 'bootstrap/runtime'),($stem+'-adapted.ll'),$fixture,$selection.unicodeRuntime.path,'-o',($stem+'-faults.exe'))
        $faults=Run-IntakeProcess ($stem+'-faults.exe') @()
        if($faults.stdout -notmatch ('^PASS project intake cases:'+$rows.Count+' budgets:6 contexts:4 assertions:[0-9]+\r?\n$')){throw 'Unexpected fault-control result'}
        $checks+=[pscustomobject]@{assertion="stage $($index+1): repeated cases plus actual root exhaustion/retry, read/close failures, primary preservation and intake cancellation";passed=$true;output=$faults.stdout}
        $null=Run-IntakeProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-DINTAKE_ALLOCATIONS','-I',$run,'-I',(Join-Path $root 'bootstrap/runtime'),($stem+'-adapted.ll'),$fixture,$selection.unicodeRuntime.path,'-o',($stem+'-allocations.exe'))
        $allocations=Run-IntakeProcess ($stem+'-allocations.exe') @()
        if($allocations.stdout -notmatch ('^\{"allocationPositions":[1-9][0-9]*,"maximumDenialsPerPosition":2,"singleAttemptPositions":[0-9]+,"retriedPositions":[0-9]+\}\r?\nPASS project intake cases:'+$rows.Count+' budgets:6 contexts:4 assertions:[0-9]+\r?\n$')){throw 'Unexpected allocation-control result'}
        $checks+=[pscustomobject]@{assertion="stage $($index+1): deny every executed calloc position and retry through actual UBE project operation, retain old graph and drain";passed=$true;output=$allocations.stdout}
        $null=Run-IntakeProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-DINTAKE_CONTRACT','-I',$run,'-I',(Join-Path $root 'bootstrap/runtime'),($stem+'-adapted.ll'),$fixture,$selection.unicodeRuntime.path,'-o',($stem+'-contract.exe'))
        $contract=Run-IntakeProcess ($stem+'-contract.exe') @()
        if($contract.stdout -notmatch '^PASS project contract metadata:2 failures:11 invalid:26 zero:12 boundaries:9 schedules:12 negative-controls:5 assertions:[0-9]+\r?\n$'){throw 'Unexpected finite contract result'}
        $checks+=[pscustomobject]@{assertion="stage $($index+1): independent complete metadata/path/span/accounting oracles, finite request domains, actual reversed worker completion and canonical full parser failure, rejecting negative controls";passed=$true;output=$contract.stdout}
    }
    foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw ('Input changed during gate: '+$identity.path)}}
    $success=$true
}catch{$failure=$_.Exception.Message}finally{
    $report=Join-Path $run 'report.json'
    $hostRemaining='Case-sensitive physical paths, '
    if($caseSensitiveEvidence -and $caseSensitiveEvidence.files.Count -eq 2){$hostRemaining=''}
    [pscustomobject]@{schema='ube-project-intake-1';success=$success;qualified=($success -and -not $DiagnosticOnly);diagnosticOnly=[bool]$DiagnosticOnly;acceptedSelection=$selection;snapshot=$CompiledSnapshot;reuseRun=$ReuseRun;caseSensitive=$caseSensitiveEvidence;inputs=$inputs;commands=$commands;checks=$checks;artifacts=@(Get-ChildItem $run -File -Recurse | ForEach-Object {Get-ArtifactIdentity $_.FullName});failure=$failure;remaining=($hostRemaining+'refreshed source/retained gates and final performance acceptance.')} | ConvertTo-Json -Depth 12 | Set-Content $report -Encoding UTF8
    Write-Output ('Evidence: '+$report)
}
if(-not $success){throw $failure}
Write-Output ($checks.Count.ToString()+' project intake development groups passed.')
