param([string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/parser-contract/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force|Out-Null
$utf8=New-Object Text.UTF8Encoding($false,$true)
$checks=New-Object 'System.Collections.Generic.List[object]'
$vectors=New-Object 'System.Collections.Generic.List[object]'
$negativeControls=New-Object 'System.Collections.Generic.List[object]'
$baselineRecords=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
$caseNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$grammarRules=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$arities=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
$inputs=@();$baseline=$null;$beforeComplete=$false;$afterComplete=$false;$success=$false;$failure=$null;$recordChecks=$true;$baselineAssertionCount=0
$leafKinds=@('Name','Literal','TypeName','Omitted','Option','Attribute','Field','VariableDecl','ConstantDecl','Parameter','ResultType','EndMarker','Exit','Label','Goto','Return')
$unaryKinds=@('Group','Positive','Negative','Not','AddressOf','New','LeadingMember')
$binaryOperators=@('Add','Subtract','Multiply','Divide','IntegerDivide','Modulo','Power','Concat','Equal','NotEqual','Less','LessEqual','Greater','GreaterEqual','Like','Is','IsNot','And','AndAlso','Or','OrElse','Xor','Eqv','Imp')
$binaryKinds=@('Member','Bang','NamedArgument','TypeOfIs','Assign','LetAssign','SetAssign')+$binaryOperators
foreach($kind in $leafKinds){$arities.Add($kind,@(0,0))}
foreach($kind in $unaryKinds){$arities.Add($kind,@(1,1))}
foreach($kind in $binaryKinds){$arities.Add($kind,@(2,2))}
foreach($kind in @('Call','CallNew','CallStatement','CallKeyword')){$arities.Add($kind,@(1,4096))}
foreach($kind in @('Module','Block','Parameters','StatementList','Print','Header')){$arities.Add($kind,@(0,4096))}
$arities.Add('RecordType',@(2,4096));$arities.Add('NativeType',@(3,3));$arities.Add('Procedure',@(3,4096));$arities.Add('IntrinsicProcedure',@(2,4096))
$arities.Add('IfLine',@(2,3));$arities.Add('IfBlock',@(2,4096));$arities.Add('ElseIf',@(2,2));$arities.Add('Else',@(1,1));$arities.Add('While',@(2,2));$arities.Add('With',@(2,2))
$expressionRoots=@('Name','Literal','Group','Positive','Negative','Not','AddressOf','New','LeadingMember','Member','Bang','TypeOfIs','Call','CallNew')+$binaryOperators
$statementRoots=@('Assign','LetAssign','SetAssign','CallStatement','CallKeyword','IfLine','IfBlock','While','With','Exit','Label','Goto','Return','Print','VariableDecl','ConstantDecl','Block','StatementList')
$diagnosticKinds=@('ExpectedExpression','ExpectedToken','ExpectedIdentifier','UnexpectedToken','InvalidCallSyntax','UnterminatedBlock','UnexpectedTerminator')
$expectedProofNames=@('native-values','ordinary-records','managed-substrate','managed-values','utf8-decoder','byte-buffer','byte-buffer-costs','source-references','entry-admission','file-bytes','source-input','unicode','scanner')

function Assert-Fact([bool]$Condition,[string]$Message){
    if(-not $Condition){throw $Message}
    if($script:recordChecks){$checks.Add([pscustomobject]@{assertion=$Message;passed=$true})}
}
function Has-Property($Object,[string]$Name){return $null -ne $Object.PSObject.Properties[$Name]}
function Assert-Fields($Object,[string[]]$Allowed,[string[]]$Required,[string]$Label){
    Assert-Fact ($null -ne $Object -and $Object -is [Management.Automation.PSCustomObject]) "$Label is an object"
    foreach($property in $Object.PSObject.Properties){Assert-Fact ($Allowed -ccontains $property.Name) "$Label has defined field $($property.Name)"}
    foreach($name in $Required){Assert-Fact (Has-Property $Object $name) "$Label has $name"}
}
function Assert-String($Value,[bool]$Nonempty,[string]$Label){
    Assert-Fact ($Value -is [string]) "$Label is a string"
    if($Nonempty){Assert-Fact ($Value.Length -gt 0) "$Label is nonempty"}
    [void]$utf8.GetBytes($Value)
}
function Is-Integer($Value){return $Value -is [int] -or $Value -is [long]}
function Position-At([string]$Source,[int]$Index){
    if($Index -lt 0 -or $Index -gt $Source.Length){throw 'Coordinate outside source'}
    $byte=$utf8.GetByteCount($Source.Substring(0,$Index));$scalar=0;$line=1;$column=1
    for($i=0;$i -lt $Index;++$i){
        $code=[int]$Source[$i]
        if([char]::IsHighSurrogate($Source[$i])){$code=[char]::ConvertToUtf32($Source,$i);++$i}
        if($code -eq 65279 -and $i -eq 0){continue}
        ++$scalar
        if($code -eq 10){++$line;$column=1}elseif($code -ne 13){++$column}
    }
    return [pscustomobject]@{byte=$byte;scalar=$scalar;line=$line;column=$column}
}
function Resolve-Witness([string]$Source,$Witness,[string]$Label){
    Assert-Fields $Witness @('id','text','occurrence','at','anchor') @('id','text') $Label
    Assert-String $Witness.id $true "$Label id";Assert-String $Witness.text $false "$Label text"
    $at='span';if(Has-Property $Witness 'at'){$at=$Witness.at;Assert-Fact (@('start','end','eof') -ccontains $at) "$Label has defined anchor mode"}
    $occurrence=0
    if(Has-Property $Witness 'occurrence'){
        Assert-Fact ((Is-Integer $Witness.occurrence) -and $Witness.occurrence -ge 0 -and $Witness.occurrence -le 65536) "$Label occurrence is a bounded nonnegative integer"
        $occurrence=[int]$Witness.occurrence
    }
    if($at -ceq 'eof'){
        Assert-Fact ($Witness.text.Length -eq 0 -and -not (Has-Property $Witness 'occurrence')) "$Label EOF uses only empty original text"
        $first=$Source.Length;$last=$first
    }else{
        Assert-Fact ($Witness.text.Length -gt 0) "$Label non-EOF anchor has original text"
        $found=-1
        for($n=0;$n -le $occurrence;++$n){
            $found=$Source.IndexOf([string]$Witness.text,$found+1,[StringComparison]::Ordinal)
            Assert-Fact ($found -ge 0) "$Label occurrence$n exists ordinally"
        }
        $first=$found;$last=$found+$Witness.text.Length
        if($at -ceq 'start'){$last=$first}elseif($at -ceq 'end'){$first=$last}
    }
    $start=Position-At $Source $first;$end=Position-At $Source $last
    if(Has-Property $Witness 'anchor'){
        Assert-Fields $Witness.anchor @('byte','scalar','line','column') @('byte','scalar','line','column') "$Label anchor"
        foreach($field in @('byte','scalar','line','column')){Assert-Fact ((Is-Integer $Witness.anchor.$field) -and $Witness.anchor.$field -eq $start.$field) "$Label independent numeric $field anchor"}
    }
    return [pscustomobject]@{id=$Witness.id;anchorText=$Witness.text;occurrence=$occurrence;mode=$at;first=$start;last=$end}
}
function Assert-Shape($Shape,$Witnesses,[int]$Depth,[string]$Label){
    Assert-Fact ($Depth -le 32) "$Label bounded fixture nesting"
    ++$script:nodeCount;Assert-Fact ($script:nodeCount -le 4096) "$Label bounded fixture node count"
    Assert-Fact ($Shape -is [array] -and $Shape.Count -ge 2) "$Label node is [kind,witness,...children]"
    $kind=$Shape[0];$id=$Shape[1]
    Assert-Fact ($kind -is [string] -and $arities.ContainsKey($kind)) "$Label has defined node kind"
    Assert-Fact ($id -is [string] -and $Witnesses.ContainsKey($id)) "$Label references a defined witness"
    $count=$Shape.Count-2;$arity=$arities[$kind]
    Assert-Fact ($count -ge $arity[0] -and $count -le $arity[1]) "$Label $kind arity"
    $span=$Witnesses[$id];$empty=$span.first.byte -eq $span.last.byte
    if($kind -ceq 'Omitted'){Assert-Fact $empty "$Label Omitted has no source content"}
    elseif(@('Block','StatementList') -cnotcontains $kind){Assert-Fact (-not $empty) "$Label $kind has a full nonempty construct span"}
    $children=New-Object 'System.Collections.Generic.List[object]';$previous=$span.first.byte
    for($i=2;$i -lt $Shape.Count;++$i){
        $child=Assert-Shape $Shape[$i] $Witnesses ($Depth+1) "$Label/$($i-2)"
        if($child.kind -ceq 'Omitted'){Assert-Fact (@('Call','CallNew','CallStatement','CallKeyword') -ccontains $kind -and $i -gt 2) "$Label omitted point is an argument, never a receiver or callee"}
        Assert-Fact ($child.first.byte -ge $span.first.byte -and $child.last.byte -le $span.last.byte) "$Label child$($i-2) contained by original construct"
        Assert-Fact ($child.first.byte -ge $previous) "$Label child$($i-2) ordered without sibling overlap"
        $previous=$child.last.byte;$children.Add($child)
    }
    return [pscustomobject]@{kind=$kind;witness=$id;first=$span.first;last=$span.last;children=$children.ToArray()}
}
function Assert-Case($Case,[string]$File){
    $label="$File/$($Case.name)"
    Assert-Fields $Case @('name','entry','outcome','source','rules','witnesses','shape','diagnostic','deferredReason','notes','semanticChecks') @('name','entry','outcome','source','rules','witnesses') $label
    Assert-String $Case.name $true "$label name";Assert-String $Case.source $false "$label source"
    Assert-Fact (@('expression','statement','unit') -ccontains $Case.entry) "$label defined entry"
    Assert-Fact (@('syntax','reject','deferred') -ccontains $Case.outcome) "$label defined outcome"
    Assert-Fact ($utf8.GetByteCount($Case.source) -le 65536) "$label bounded definition source"
    Assert-Fact ($Case.source -cnotmatch '\r(?!\n)') "$label uses qualified LF or CRLF input"
    Assert-Fact ($Case.rules -is [array] -and $Case.rules.Count -gt 0) "$label has grammar rule references"
    $seenRules=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($rule in $Case.rules){Assert-Fact ($rule -is [string] -and $grammarRules.Contains($rule) -and $seenRules.Add($rule)) "$label refers once to existing EBNF production $rule"}
    if(Has-Property $Case 'notes'){Assert-String $Case.notes $false "$label notes"}
    if(Has-Property $Case 'semanticChecks'){
        Assert-Fact ($Case.outcome -ceq 'syntax' -and $Case.semanticChecks -is [array] -and $Case.semanticChecks.Count -gt 0) "$label semantic obligations are separate from syntax"
        foreach($item in $Case.semanticChecks){Assert-String $item $true "$label semantic obligation"}
    }
    Assert-Fact ($Case.witnesses -is [array] -and $Case.witnesses.Count -gt 0 -and $Case.witnesses.Count -le 256) "$label bounded witness set"
    $witnesses=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach($witness in $Case.witnesses){
        $resolved=Resolve-Witness $Case.source $witness "$label witness"
        Assert-Fact (-not $witnesses.ContainsKey($resolved.id)) "$label unique ordinal witness $($resolved.id)"
        $witnesses.Add($resolved.id,$resolved)
    }
    $shape=$null;$diagnostic=$null;$reason=$null
    switch -CaseSensitive ($Case.outcome){
        'syntax'{
            Assert-Fact ((Has-Property $Case 'shape') -and -not (Has-Property $Case 'diagnostic') -and -not (Has-Property $Case 'deferredReason')) "$label syntax has only an expected shape"
            $script:nodeCount=0;$shape=Assert-Shape $Case.shape $witnesses 0 "$label shape"
            $domain=$expressionRoots;if($Case.entry -ceq 'statement'){$domain=$statementRoots}elseif($Case.entry -ceq 'unit'){$domain=@('Module')}
            Assert-Fact ($domain -ccontains $shape.kind) "$label root kind belongs to entry domain"
        }
        'reject'{
            Assert-Fact ((Has-Property $Case 'diagnostic') -and -not (Has-Property $Case 'shape') -and -not (Has-Property $Case 'deferredReason')) "$label reject has only a diagnostic"
            Assert-Fields $Case.diagnostic @('kind','witness') @('kind','witness') "$label diagnostic"
            Assert-Fact ($diagnosticKinds -ccontains $Case.diagnostic.kind) "$label defined diagnostic classification"
            Assert-Fact ($Case.diagnostic.witness -is [string] -and $witnesses.ContainsKey($Case.diagnostic.witness)) "$label diagnostic has original anchor"
            $diagnostic=[pscustomobject]@{kind=$Case.diagnostic.kind;span=$witnesses[$Case.diagnostic.witness]}
        }
        'deferred'{
            Assert-Fact ((Has-Property $Case 'deferredReason') -and -not (Has-Property $Case 'shape') -and -not (Has-Property $Case 'diagnostic')) "$label deferred does not claim syntax acceptance or rejection"
            Assert-String $Case.deferredReason $true "$label deferred reason";$reason=$Case.deferredReason
        }
    }
    return [pscustomobject]@{file=$File;name=$Case.name;entry=$Case.entry;outcome=$Case.outcome;sourceBytes=$utf8.GetByteCount($Case.source);rules=$Case.rules;witnesses=@($witnesses.Values);shape=$shape;diagnostic=$diagnostic;deferredReason=$reason}
}
function Record-Identity($Identity){
    $path=[IO.Path]::GetFullPath([string]$Identity.path)
    if($baselineRecords.ContainsKey($path)){
        $old=$baselineRecords[$path]
        Assert-Fact ($old.sha256 -ceq $Identity.sha256 -and $old.bytes -eq $Identity.bytes) "Baseline identities agree for $path"
        return
    }
    $actual=Get-ArtifactIdentity $path
    Assert-Fact ($actual.sha256 -ceq $Identity.sha256 -and $actual.bytes -eq $Identity.bytes) "Accepted baseline identity before: $path"
    $baselineRecords.Add($path,$actual)
}
function Read-StrictJson([string]$Path){
    Assert-Fact ((Get-Item -LiteralPath $Path).Length -le 1048576) "Bounded fixture file $Path"
    $text=$utf8.GetString([IO.File]::ReadAllBytes($Path));if($text.Length -gt 0 -and [int]$text[0] -eq 65279){$text=$text.Substring(1)}
    return ($text|ConvertFrom-Json)
}
function Assert-AcceptedBaseline{
    Record-Identity (Get-ArtifactIdentity $SelectionPath)
    $selected=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    Assert-Fact ($selected.schema -ceq 'ube-v2-current-1') 'Existing accepted selection schema is retained'
    foreach($property in $selected.PSObject.Properties){if($property.Name -cne 'schema'){Record-Identity $property.Value}}
    $manifest=Get-Content -LiteralPath $selected.manifest.path -Raw|ConvertFrom-Json
    Assert-Fact ($manifest.success -and $manifest.checks.Count -eq 501) 'Accepted scanner implementation retains 501 passed grouped checks'
    foreach($identity in @($manifest.inputs)+@($manifest.artifacts)){Record-Identity $identity}
    foreach($tool in $manifest.tools){Record-Identity $tool.identity}
    $approved=@($manifest.inputs)+@($manifest.artifacts)+@($manifest.tools|ForEach-Object {$_.identity})
    foreach($name in @('compiler','runtime','unicodeRuntime','seed','clang')){
        $identity=$selected.$name
        $cohortMatches=@($approved|Where-Object {[string]::Equals([IO.Path]::GetFullPath($_.path),[IO.Path]::GetFullPath($identity.path),[StringComparison]::OrdinalIgnoreCase) -and $_.sha256 -ceq $identity.sha256 -and $_.bytes -eq $identity.bytes})
        Assert-Fact ($cohortMatches.Count -gt 0) "Selected $name belongs to the accepted manifest"
    }
    Record-Identity $manifest.sourceBootstrap
    $core=Get-Content -LiteralPath $manifest.sourceBootstrap.path -Raw|ConvertFrom-Json
    Assert-Fact ($core.success -and $core.checks.Count -eq 136) 'Accepted core retains 136 checks'
    foreach($identity in @($core.inputs)+@($core.artifacts)){Record-Identity $identity}
    foreach($check in @($manifest.checks)+@($core.checks)){Assert-Fact ([bool]$check.passed) 'Retained accepted check passed'}
    $children=New-Object 'System.Collections.Generic.List[object]';$sum=136;$proofNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($proof in $manifest.proofs){
        Assert-Fact ($expectedProofNames -ccontains $proof.name -and $proofNames.Add([string]$proof.name)) "Unique defined accepted child proof $($proof.name)"
        Record-Identity $proof.report;$report=Get-Content -LiteralPath $proof.report.path -Raw|ConvertFrom-Json
        Assert-Fact ($report.success -and $report.checks.Count -eq $proof.assertions -and $report.acceptedSelection.compiler.sha256 -ceq $selected.compiler.sha256 -and $report.acceptedSelection.manifest.sha256 -ceq $manifest.sourceBootstrap.sha256) "Retained child cohort $($proof.name)"
        if($proof.name -ceq 'scanner'){Assert-Fact ($report.qualified -and -not $report.diagnosticOnly) 'Retained scanner report is formally qualified'}
        if($proof.name -ceq 'managed-substrate'){Assert-Fact ([bool]$report.sourceBuildCurrent) 'Retained managed substrate was built from current source'}
        foreach($identity in @($report.inputs)+@($report.artifacts)){Record-Identity $identity}
        foreach($check in $report.checks){if(Has-Property $check 'passed'){Assert-Fact ([bool]$check.passed) "Retained child assertion $($proof.name)"}}
        $sum+=$proof.assertions;$children.Add([pscustomobject]@{name=$proof.name;checks=$proof.assertions;report=$proof.report})
    }
    Assert-Fact ($children.Count -eq 13 -and $sum -eq 501) 'All 13 existing child proofs retain the aggregate'
    foreach($name in $expectedProofNames){Assert-Fact ($proofNames.Contains($name)) "Accepted feature proof is retained: $name"}
    $raw=@($manifest.inputs|Where-Object {$_.path -like '*\std-lib\data\unicode\18.0.0\*'})
    Assert-Fact ($raw.Count -eq 5) 'All five versioned Unicode raw/provenance inputs remain pinned'
    return [pscustomobject]@{selection=(Get-ArtifactIdentity $SelectionPath);manifest=$selected.manifest;sourceManifest=$manifest.sourceBootstrap;checks=501;sourceChecks=136;children=$children.ToArray();unicodeRawInputs=5}
}
function Clone-Case($Case){return ($Case|ConvertTo-Json -Depth 90|ConvertFrom-Json)}
function Assert-RejectedMutation([string]$Name,$Case){
    $previous=$script:recordChecks;$script:recordChecks=$false;$rejected=$false;$message=$null
    try{$null=Assert-Case $Case 'negative-control'}catch{$rejected=$true;$message=$_.Exception.Message}finally{$script:recordChecks=$previous}
    Assert-Fact $rejected "Negative control rejected: $Name"
    $negativeControls.Add([pscustomobject]@{name=$Name;rejected=$true;reason=$message})
}
try{
    $baseline=Assert-AcceptedBaseline;$beforeComplete=$true;$baselineAssertionCount=$checks.Count
    $paths=@('compiler/UBE_Compiler_v3/tools/check-parser-contract.ps1','compiler/UBE_Compiler_v3/tests/parser/ORACLES.md','compiler/UBE_Compiler_v3/PARSER-CONTRACT.md','lang-doc/language-spec.md','lang-doc/grammar/ube.ebnf','lang-doc/grammar/conditional-compilation.ebnf','compiler/UBE_Compiler_v3/SCANNER-CONTRACT.md','compiler/UBE_Compiler_v3/SOURCE-INPUT-CONTRACT.md','compiler/UBE_Compiler_v3/tests/scanner/words.json','bootstrap/tools/verification.ps1','compiler/UBE_Compiler_v3/tests/parser/expressions.json','compiler/UBE_Compiler_v3/tests/parser/statements.json','compiler/UBE_Compiler_v3/tests/parser/units.json')|ForEach-Object {Join-Path $root $_}
    $inputs=@($paths|ForEach-Object {Get-ArtifactIdentity $_})
    $grammar=[IO.File]::ReadAllText((Join-Path $root 'lang-doc/grammar/ube.ebnf'),$utf8)
    foreach($match in [regex]::Matches($grammar,'(?m)^([a-z][a-z0-9-]*)\s*=')){[void]$grammarRules.Add($match.Groups[1].Value)}
    Assert-Fact ($grammarRules.Count -gt 0) 'Existing EBNF production names are available'
    $allCases=New-Object 'System.Collections.Generic.List[object]'
    foreach($name in @('expressions','statements','units')){
        $path=Join-Path $root ('compiler/UBE_Compiler_v3/tests/parser/'+$name+'.json');$file=Read-StrictJson $path
        Assert-Fields $file @('schema','cases','comments') @('schema','cases') "$name fixture"
        Assert-Fact ($file.schema -ceq 'ube-parser-cases-1' -and $file.cases -is [array] -and $file.cases.Count -gt 0 -and $file.cases.Count -le 512) "$name bounded parser-definition schema"
        if(Has-Property $file 'comments'){Assert-Fact ($file.comments -is [array]) "$name comments array";foreach($comment in $file.comments){Assert-String $comment $true "$name comment"}}
        foreach($case in $file.cases){
            Assert-Fact ($caseNames.Add([string]$case.name)) "Globally unique parser fixture $($case.name)"
            $vectors.Add((Assert-Case $case ($name+'.json')));$allCases.Add($case)
        }
    }
    $syntactic=@($allCases|Where-Object outcome -CEQ 'syntax');$rejects=@($allCases|Where-Object outcome -CEQ 'reject');$deferred=@($allCases|Where-Object outcome -CEQ 'deferred')
    Assert-Fact ($syntactic.Count -gt 0 -and $rejects.Count -gt 0 -and $deferred.Count -gt 0) 'Fixture set distinguishes syntax, rejection and deferred obligations'
    $seed=Clone-Case $syntactic[0];$seed.rules=@('this-production-does-not-exist');Assert-RejectedMutation 'undefined EBNF production' $seed
    $seed=Clone-Case $syntactic[0];$seed.outcome='passed';Assert-RejectedMutation 'unsupported outcome' $seed
    $seed=Clone-Case $syntactic[0];$seed.witnesses[0].text+='source-text-not-present';Assert-RejectedMutation 'missing exact original witness text' $seed
    $seed=Clone-Case $syntactic[0];$seed.shape[0]='ImaginaryParserNode';Assert-RejectedMutation 'undefined shape kind' $seed
    $seed=Clone-Case $syntactic[0];$seed.shape=@('Add',[string]$seed.shape[1]);Assert-RejectedMutation 'broken expected node arity' $seed
    $seed=Clone-Case $syntactic[0];$seed.shape[1]='absent-witness';Assert-RejectedMutation 'missing shape witness' $seed
    $seed=Clone-Case $rejects[0];$seed.PSObject.Properties.Remove('diagnostic');Assert-RejectedMutation 'missing rejection diagnostic' $seed
    $seed=Clone-Case $rejects[0];$seed.diagnostic.kind='MadeUpDiagnostic';Assert-RejectedMutation 'undefined diagnostic classification' $seed
    $seed=Clone-Case $deferred[0];$seed.outcome='syntax';$seed|Add-Member -NotePropertyName shape -NotePropertyValue @('Name',[string]$seed.witnesses[0].id);Assert-RejectedMutation 'deferred obligation relabeled as syntax' $seed
    $control=[pscustomobject]@{name='coordinate-control';entry='expression';outcome='syntax';source=([char]65279+'a'+"`r`n"+[char]0x03B2);rules=@('expression');witnesses=@([pscustomobject]@{id='all';text=('a'+"`r`n"+[char]0x03B2);anchor=[pscustomobject]@{byte=3;scalar=0;line=1;column=1}},[pscustomobject]@{id='beta';text=([string][char]0x03B2);anchor=[pscustomobject]@{byte=6;scalar=3;line=2;column=1}});shape=@('Name','all')}
    $null=Assert-Case $control 'independent-coordinate-control'
    $seed=Clone-Case $control;$seed.witnesses[1].anchor.byte=5;Assert-RejectedMutation 'wrong independent byte anchor' $seed
    $seed=Clone-Case $control;$seed.witnesses[1].anchor.scalar=2;Assert-RejectedMutation 'wrong CRLF scalar anchor' $seed
    $containment=[pscustomobject]@{name='containment-control';entry='expression';outcome='syntax';source='a+b';rules=@('expression');witnesses=@([pscustomobject]@{id='all';text='a+b'},[pscustomobject]@{id='a';text='a'},[pscustomobject]@{id='b';text='b'});shape=@('Add','all',@('Name','a'),@('Name','b'))}
    $null=Assert-Case $containment 'structural-control'
    $seed=Clone-Case $containment;$seed.shape[1]='a';Assert-RejectedMutation 'child outside its expected parent span' $seed
    $seed=Clone-Case $containment;$seed.shape[2][1]='all';Assert-RejectedMutation 'crossing or overlapping siblings' $seed
    $seed=Clone-Case $containment;$seed.shape[2][0]='Omitted';Assert-RejectedMutation 'omitted argument incorrectly owns source content' $seed
    $seed=Clone-Case $containment;$seed.witnesses[1]|Add-Member -NotePropertyName at -NotePropertyValue 'start';Assert-RejectedMutation 'ordinary Name incorrectly has a zero-width point' $seed
    $seed=Clone-Case $containment;$seed.shape[2][0]='Omitted';$seed.witnesses[1]|Add-Member -NotePropertyName at -NotePropertyValue 'start';Assert-RejectedMutation 'omitted argument used outside a call argument list' $seed
    foreach($identity in $inputs){$actual=Get-ArtifactIdentity $identity.path;Assert-Fact ($actual.sha256 -ceq $identity.sha256 -and $actual.bytes -eq $identity.bytes) "Definition input unchanged: $($identity.path)"}
    $success=$true
}catch{$failure=$_.Exception.Message}
finally{
    if($beforeComplete){
        try{foreach($identity in $baselineRecords.Values){$actual=Get-ArtifactIdentity $identity.path;if($actual.sha256 -cne $identity.sha256 -or $actual.bytes -ne $identity.bytes){throw "Accepted baseline changed during definition check: $($identity.path)"}};$afterComplete=$true}
        catch{$success=$false;if($failure){$failure+='; '+$_.Exception.Message}else{$failure=$_.Exception.Message}}
    }
    [pscustomobject]@{schema='ube-parser-contract-proof-1';success=$success;definitionOnly=$true;parserImplemented=$false;failure=$failure;baseline=$baseline;baselineBeforeComplete=$beforeComplete;baselineAfterComplete=$afterComplete;baselineIdentityCount=$baselineRecords.Count;baselineIdentities=@($baselineRecords.Values);baselineAssertionCount=$baselineAssertionCount;definitionAssertionCount=($checks.Count-$baselineAssertionCount);inputs=$inputs;cases=$vectors.ToArray();caseCount=$vectors.Count;negativeControls=$negativeControls.ToArray();checks=$checks.ToArray();limits='Definition consistency only: hand-authored expected shapes, exact substring/point witnesses, coordinate assertions, known node arity/domain and EBNF reference checks. Source is never parsed and expected grammatical answers are not inferred from an existing compiler. This does not qualify a parser, recovery algorithm, literal conversion, binding, conditional branch selection or full program validity. The existing 501-check source/tool/artifact/13-child cohort is only audited unchanged, never rebuilt or republished.'}|ConvertTo-Json -Depth 90|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if(-not $success){throw $failure}
Write-Output "PASS definition only: $($vectors.Count) parser fixtures, $($negativeControls.Count) negative controls, $($checks.Count-$baselineAssertionCount) definition consistency assertions; accepted 501-check baseline unchanged."
