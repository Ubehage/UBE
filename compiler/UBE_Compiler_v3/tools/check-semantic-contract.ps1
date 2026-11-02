param([string]$SelectionPath='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Repository root missing'};$root=$parent}
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$compiler=Join-Path $root 'compiler/UBE_Compiler_v3'
$fixtureRoot=Join-Path $compiler 'tests/semantic'
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$utf8=[Text.UTF8Encoding]::new($false,$true)
$run=Join-Path $root ('bootstrap/out/semantic-contract/'+[Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Force -Path $run)
$checks=[Collections.Generic.List[object]]::new()
$controls=[Collections.Generic.List[object]]::new()
$resolvedCases=[Collections.Generic.List[object]]::new()
$inventoryEvidence=[Collections.Generic.List[object]]::new()
$identities=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
$recordChecks=$true;$success=$false;$failure=$null;$definition=$null;$baseline=$null;$selected=$null;$proofAudit=$null
function Read-DefinitionJson([string]$Path){
    if((Get-Item -LiteralPath $Path).Length -gt 2097152){throw "Definition/report exceeds bounded JSON size: $Path"}
    $content=[IO.File]::ReadAllText($Path,$utf8)
    return ($content|ConvertFrom-Json)
}
function Assert-Fact([bool]$Condition,[string]$Message){
    if(-not $Condition){throw $Message}
    if($script:recordChecks){$checks.Add([pscustomobject]@{assertion=$Message;passed=$true})}
}
function Has($Object,[string]$Name){return $null -ne $Object.PSObject.Properties[$Name]}
function Fields($Object,[string[]]$Required,[string[]]$Allowed,[string]$Label){
    Assert-Fact ($null -ne $Object -and $Object -is [pscustomobject]) "$Label object"
    foreach($p in $Object.PSObject.Properties){Assert-Fact ($Allowed -ccontains $p.Name) "$Label defined field $($p.Name)"}
    foreach($p in $Required){Assert-Fact (Has $Object $p) "$Label required field $p"}
}
function String($Value,[string]$Label,[bool]$Empty=$false){
    Assert-Fact ($Value -is [string]) "$Label string"
    Assert-Fact ($Empty -or $Value.Length -gt 0) "$Label nonempty"
    [void]$utf8.GetBytes($Value)
}
function Integer($Value){return $Value -is [int] -or $Value -is [long]}
function List($Value,[string]$Label,[int]$Min=0,[int]$Max=4096){Assert-Fact ($Value -is [array] -and $Value.Count -ge $Min -and $Value.Count -le $Max) "$Label bounded array"}
function Position([string]$Source,[int]$Index){
    Assert-Fact ($Index -ge 0 -and $Index -le $Source.Length) 'Position inside original source'
    $scalar=0;$line=1;$column=1
    for($i=0;$i -lt $Index;++$i){
        $code=[int]$Source[$i]
        if([char]::IsHighSurrogate($Source[$i])){
            Assert-Fact ($i+1 -lt $Index -and [char]::IsLowSurrogate($Source[$i+1])) 'Position does not split a Unicode scalar'
            $code=[char]::ConvertToUtf32($Source,$i);++$i
        }
        if($code -eq 65279 -and $i -eq 0){continue}
        ++$scalar
        if($code -eq 10){++$line;$column=1}elseif($code -ne 13){++$column}
    }
    return [pscustomobject]@{byte=$utf8.GetByteCount($Source.Substring(0,$Index));scalar=$scalar;line=$line;column=$column}
}
function Witness($W,$Sources){
    Fields $W @('id','source','text') @('id','source','text','occurrence','mode','within','anchor') 'Witness'
    String $W.id 'Witness ID';String $W.source 'Witness source';String $W.text 'Witness text' $true
    Assert-Fact ($Sources.ContainsKey($W.source)) 'Witness source exists'
    $source=[string]$Sources[$W.source].source
    $mode='span';if(Has $W 'mode'){$mode=$W.mode}
    Assert-Fact (@('span','start','end','eof') -ccontains $mode) 'Witness mode defined'
    $n=0;if(Has $W 'occurrence'){$n=$W.occurrence;Assert-Fact ((Integer $n) -and $n -ge 0 -and $n -le 65536) 'Witness occurrence bounded'}
    if($mode -ceq 'eof'){
        Assert-Fact ($W.text.Length -eq 0 -and -not (Has $W 'occurrence') -and -not (Has $W 'within')) 'EOF uses only original empty boundary'
        $first=$source.Length;$last=$first
    }else{
        Assert-Fact ($W.text.Length -gt 0) 'Non-EOF witness has original text'
        $offset=0;$search=$source
        if(Has $W 'within'){
            String $W.within 'Witness context'
            $offset=$source.IndexOf([string]$W.within,[StringComparison]::Ordinal)
            Assert-Fact ($offset -ge 0) 'Witness context exists'
            Assert-Fact ($source.IndexOf([string]$W.within,$offset+1,[StringComparison]::Ordinal) -lt 0) 'Witness context is unique'
            $search=[string]$W.within
        }
        $found=-1
        for($i=0;$i -le $n;++$i){$found=$search.IndexOf([string]$W.text,$found+1,[StringComparison]::Ordinal);Assert-Fact ($found -ge 0) 'Witness exact occurrence exists'}
        $first=$offset+$found;$last=$first+$W.text.Length
        if($mode -ceq 'start'){$last=$first}elseif($mode -ceq 'end'){$first=$last}
    }
    $a=Position $source $first;$b=Position $source $last
    if(Has $W 'anchor'){
        Fields $W.anchor @('byte','scalar','line','column') @('byte','scalar','line','column') 'Numeric anchor'
        foreach($name in @('byte','scalar','line','column')){Assert-Fact ((Integer $W.anchor.$name) -and $W.anchor.$name -eq $a.$name) "Independent numeric $name anchor"}
    }
    return [pscustomobject]@{id=$W.id;source=$W.source;first=$a;last=$b;text=$W.text;mode=$mode}
}
function Rule-List($Rules){
    List $Rules 'Rule references' 1 20
    $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($r in $Rules){Assert-Fact ($definition.rules -ccontains $r -and $seen.Add([string]$r)) 'Rule reference is defined and unique'}
}
function Type-Name($Value){Assert-Fact ($definition.types -ccontains $Value) 'Expected type is defined'}
function Constant-Value($Fact){
    Type-Name $Fact.type;String $Fact.value 'Expected constant'
    if($Fact.type -ceq 'Boolean'){Assert-Fact (@('True','False') -ccontains $Fact.value) 'Expected Boolean spelling';return}
    Assert-Fact (@('Byte','Integer','Long','LongLong') -ccontains $Fact.type) 'Expected integer constant type'
    Assert-Fact ($Fact.value -cmatch '^-?(0|[1-9][0-9]*)$') 'Expected integer canonical decimal spelling'
    $bounds=@{Byte=@('0','255');Integer=@('-32768','32767');Long=@('-2147483648','2147483647');LongLong=@('-9223372036854775808','9223372036854775807')}
    $value=[decimal]::Parse($Fact.value,[Globalization.CultureInfo]::InvariantCulture)
    $min=[decimal]::Parse($bounds[$Fact.type][0],[Globalization.CultureInfo]::InvariantCulture)
    $max=[decimal]::Parse($bounds[$Fact.type][1],[Globalization.CultureInfo]::InvariantCulture)
    Assert-Fact ($value -ge $min -and $value -le $max) 'Expected constant fits its type'
}
function Validate-Case($Case){
    Fields $Case @('id','rules','sources','witnesses','declarations','expected') @('id','rules','sources','witnesses','declarations','expected') 'Case'
    String $Case.id 'Case ID';Rule-List $Case.rules;List $Case.sources 'Sources' 1 256;List $Case.witnesses 'Witnesses' 1 256;List $Case.declarations 'Declarations' 0 256
    $sources=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $librarySeen=$false;$rootCount=0
    foreach($s in $Case.sources){
        Fields $s @('id','package','module','source') @('id','package','module','source') 'Source'
        foreach($p in @('id','package','module','source')){String $s.$p "Source $p"}
        Assert-Fact (-not $sources.ContainsKey($s.id)) 'Source ID unique'
        Assert-Fact (@('app','ubecore') -ccontains $s.package) 'Bounded explicit package identity'
        if($s.package -ceq 'ubecore'){$librarySeen=$true}else{Assert-Fact (-not $librarySeen) 'Root sources precede explicit library';++$rootCount}
        Assert-Fact ($utf8.GetByteCount($s.source) -le 65536 -and $s.source -cnotmatch '\r(?!\n)') 'Definition source bounded and valid newline domain'
        $body=$s.source.TrimStart([char]65279)
        Assert-Fact ($body.StartsWith('UBE SOURCE 1 MODULE',[StringComparison]::Ordinal)) 'Fixture domain native MODULE header'
        $sources.Add($s.id,$s)
    }
    Assert-Fact ($rootCount -gt 0) 'Fixture has root source'
    $witnesses=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach($w in $Case.witnesses){$resolved=Witness $w $sources;Assert-Fact (-not $witnesses.ContainsKey($w.id)) 'Witness ID unique';$witnesses.Add($w.id,$resolved)}
    $decls=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach($d in $Case.declarations){
        Fields $d @('id','at','type','kind') @('id','at','type','kind','parameters') 'Declaration'
        String $d.id 'Declaration ID';Type-Name $d.type
        Assert-Fact (@('variable','constant','procedure','result','native') -ccontains $d.kind) 'Declaration kind defined'
        Assert-Fact ($witnesses.ContainsKey($d.at)) 'Declaration witness exists'
        $where=$witnesses[$d.at];Assert-Fact ($where.first.byte -lt $where.last.byte) 'Declaration name is nonempty'
        Assert-Fact (-not $decls.ContainsKey($d.id)) 'Declaration ID unique'
        if(Has $d 'parameters'){List $d.parameters 'Declared parameter types';foreach($t in $d.parameters){Type-Name $t}}
        $decls.Add($d.id,$d)
    }
    Fields $Case.expected @('outcome','facts') @('outcome','facts','diagnostic') 'Expected'
    $expected=$Case.expected
    Assert-Fact (@('checked','error','deferred','frontend') -ccontains $expected.outcome) 'Expected outcome defined'
    List $expected.facts 'Facts'
    if($expected.outcome -ceq 'checked'){
        Assert-Fact (-not (Has $expected 'diagnostic') -and $expected.facts.Count -gt 0) 'Checked case has facts and no diagnostic'
    }else{
        Assert-Fact ((Has $expected 'diagnostic') -and $expected.facts.Count -eq 0) 'Failure/deferred has one diagnostic and no partial facts'
        $d=$expected.diagnostic;Fields $d @('kind','at','related') @('kind','at','related') 'Diagnostic'
        $known=$definition.diagnostics;if($expected.outcome -ceq 'deferred'){$known=$definition.deferred}elseif($expected.outcome -ceq 'frontend'){$known=$definition.frontend}
        Assert-Fact ($known -ccontains $d.kind) 'Diagnostic matches outcome domain'
        Assert-Fact ($witnesses.ContainsKey($d.at)) 'Diagnostic witness exists';List $d.related 'Related spans'
        foreach($r in $d.related){Assert-Fact ($witnesses.ContainsKey($r)) 'Related witness exists'}
    }
    foreach($f in $expected.facts){
        Fields $f @('kind','at') @('kind','at','type','value','target','arguments') 'Fact'
        Assert-Fact ($witnesses.ContainsKey($f.at)) 'Fact witness exists'
        if(@('type','constant','representation','conversion','argument','result') -ccontains $f.kind){Assert-Fact (Has $f 'type') 'Typed fact has type';Type-Name $f.type}
        switch -CaseSensitive ($f.kind){
            'type'{Fields $f @('kind','at','type') @('kind','at','type') 'Type fact'}
            'representation'{Fields $f @('kind','at','type') @('kind','at','type') 'Representation fact';Assert-Fact (@('Byte','Integer','Long') -ccontains $f.type) 'Qualified native representation'}
            'constant'{Fields $f @('kind','at','type','value') @('kind','at','type','value') 'Constant fact';Constant-Value $f}
            'binding'{Fields $f @('kind','at','target') @('kind','at','target') 'Binding fact';Assert-Fact ($decls.ContainsKey($f.target)) 'Binding declaration exists'}
            'call'{
                Fields $f @('kind','at','target','arguments') @('kind','at','target','arguments') 'Call fact'
                Assert-Fact ($decls.ContainsKey($f.target) -and $decls[$f.target].kind -ceq 'procedure') 'Call target is a procedure'
                Assert-Fact (Has $decls[$f.target] 'parameters') 'Call target has independent parameter types'
                List $f.arguments 'Expected call slots'
                $where=$witnesses[$f.at];$last=$where.first.byte;$used=[Collections.Generic.HashSet[int]]::new()
                foreach($arg in $f.arguments){
                    Fields $arg @('at','parameter','mode') @('at','parameter','mode') 'Call slot'
                    Assert-Fact ($witnesses.ContainsKey($arg.at)) 'Call slot witness exists'
                    Assert-Fact ((Integer $arg.parameter) -and $arg.parameter -ge 0 -and $arg.parameter -lt $decls[$f.target].parameters.Count -and $used.Add([int]$arg.parameter)) 'Call slot parameter unique and in range'
                    Assert-Fact (@('alias','temporary','value','default') -ccontains $arg.mode) 'Call slot mode defined'
                    $argSpan=$witnesses[$arg.at]
                    Assert-Fact ($argSpan.source -ceq $where.source -and $argSpan.first.byte -ge $last -and $argSpan.last.byte -le $where.last.byte) 'Call slots preserve source order and containment'
                    $last=$argSpan.last.byte
                }
            }
            default{
                Assert-Fact (Has $definition.factValues $f.kind) 'Fact kind defined'
                Assert-Fact (Has $f 'value') 'Mode fact has value'
                Assert-Fact ($definition.factValues.($f.kind) -ccontains $f.value) 'Fact mode defined'
                $required=@('kind','at','value');if(@('conversion','argument','result') -ccontains $f.kind){$required+=@('type')}
                Fields $f $required $required 'Mode fact'
            }
        }
    }
    return [pscustomobject]@{id=$Case.id;outcome=$expected.outcome;sourceCount=$sources.Count;facts=$expected.facts.Count;rules=$Case.rules;witnesses=@($witnesses.Values)}
}
function Validate-Inventory($Entry){
    Fields $Entry @('id','path','owner','end','state','evidence','need') @('id','path','owner','end','state','evidence','need') 'Inventory'
    foreach($p in @('id','path','owner','end','state','need')){String $Entry.$p "Inventory $p"}
    Assert-Fact (@('opaque','retained','borrowed') -ccontains $Entry.state) 'Inventory retention domain'
    Assert-Fact ($Entry.path -cmatch '^src/[A-Za-z]+\.(bas|cls)$') 'Inventory bounded production path'
    List $Entry.evidence 'Inventory evidence' 1 20
    $path=Join-Path $compiler $Entry.path;$content=[IO.File]::ReadAllText($path,$utf8)
    $start=$content.IndexOf([string]$Entry.owner,[StringComparison]::Ordinal)
    Assert-Fact ($start -ge 0) 'Inventory owner exists'
    $end=$content.IndexOf([string]$Entry.end,$start,[StringComparison]::Ordinal)
    Assert-Fact ($end -ge 0) 'Inventory owner end exists'
    $section=$content.Substring($start,$end-$start+$Entry.end.Length)
    $found=[Collections.Generic.List[object]]::new()
    foreach($snippet in $Entry.evidence){
        String $snippet 'Inventory snippet';$index=$section.IndexOf([string]$snippet,[StringComparison]::Ordinal)
        Assert-Fact ($index -ge 0) 'Inventory snippet exists inside owner'
        $line=1+([regex]::Matches($content.Substring(0,$start+$index),"`n")).Count
        $found.Add([pscustomobject]@{snippet=$snippet;line=$line})
    }
    return [pscustomobject]@{id=$Entry.id;state=$Entry.state;source=(Get-ArtifactIdentity $path);owner=$Entry.owner;matches=$found.ToArray();need=$Entry.need}
}
function Validate-Obligation($O){
    Fields $O @('id','rules','stimulus','oracle','measurement') @('id','rules','stimulus','oracle','measurement') 'Obligation'
    foreach($p in @('id','stimulus','oracle','measurement')){String $O.$p "Obligation $p"};Rule-List $O.rules
}
function Record-Identity($Identity){
    $actual=Get-ArtifactIdentity $Identity.path
    Assert-Fact ($actual.bytes -eq $Identity.bytes -and $actual.sha256 -ceq $Identity.sha256) "Accepted/input identity unchanged: $($Identity.path)"
    $identities[$actual.path]=$actual
}
function Read-ProofJson([string]$Path){
    Assert-Fact ((Get-Item -LiteralPath $Path).Length -le 67108864) 'Child proof report stays within64MiB audit bound'
    return ([IO.File]::ReadAllText($Path,$utf8)|ConvertFrom-Json)
}
function Audit-ChildProof($Proof,$Child,$Selected,$ParentChecks){
    Assert-Fact ((Has $Child 'success') -and $Child.success -is [bool] -and $Child.success) 'Child proof succeeded'
    Assert-Fact ((Has $Child 'checks') -and $Child.checks -is [array] -and $Child.checks.Count -gt 0 -and $Child.checks.Count -le 1048576) 'Child proof has nonempty bounded assertion array'
    Assert-Fact ((Integer $Proof.assertions) -and $Proof.assertions -eq $Child.checks.Count) 'Child proof recorded assertion count matches actual checks'
    Assert-Fact ((Has $Child 'acceptedSelection') -and (Has $Child.acceptedSelection 'compiler')) 'Child proof records accepted compiler identity'
    $compiler=$Child.acceptedSelection.compiler
    Assert-Fact ($compiler.sha256 -ceq $Selected.compiler.sha256 -and $compiler.bytes -eq $Selected.compiler.bytes -and [string]::Equals([IO.Path]::GetFullPath($compiler.path),[IO.Path]::GetFullPath($Selected.compiler.path),[StringComparison]::OrdinalIgnoreCase)) 'Child proof uses current accepted compiler identity'
    Record-Identity $compiler
    # Child reports are emitted against the immutable source-bootstrap manifest.
    # Its hash need not equal the completed parent manifest that adopts them.
    $recorded=@($ParentChecks|Where-Object {$_.name -ceq $Proof.name})
    Assert-Fact ($recorded.Count -eq $Child.checks.Count) 'Parent proof assertion count matches child checks'
    for($i=0;$i -lt $Child.checks.Count;++$i){
        $check=$Child.checks[$i]
        if($check -is [string]){String $check 'Child textual assertion';$assertion=$check}
        else{
            Assert-Fact ((Has $check 'passed') -and $check.passed -is [bool] -and $check.passed) 'Child object assertion explicitly passed'
            Assert-Fact (Has $check 'assertion') 'Child object assertion has text'
            String $check.assertion 'Child assertion';$assertion=$check.assertion
        }
        Assert-Fact ($recorded[$i].assertion -ceq $assertion) 'Parent proof assertion text/order matches hashed child'
    }
    return [pscustomobject]@{name=$Proof.name;assertions=$Child.checks.Count;report=$Proof.report;acceptedCompiler=$compiler;parentManifestHashRequired=$false}
}
function Audit-ManifestProofs($Manifest,$Selected){
    Assert-Fact ((Has $Manifest 'checks') -and $Manifest.checks -is [array] -and $Manifest.checks.Count -gt 0 -and $Manifest.checks.Count -le 1048576) 'Current source manifest has nonempty bounded assertions'
    foreach($check in $Manifest.checks){Assert-Fact ((Has $check 'passed') -and $check.passed -is [bool] -and $check.passed) 'Recorded source assertion explicitly passed'}
    Assert-Fact ((Has $Manifest 'proofs') -and $Manifest.proofs -is [array] -and $Manifest.proofs.Count -gt 0 -and $Manifest.proofs.Count -le 1024) 'Current source manifest has bounded child proof records'
    $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $paths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $digests=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $audited=[Collections.Generic.List[object]]::new();$total=0L
    foreach($proof in $Manifest.proofs){
        Fields $proof @('name','assertions','report') @('name','assertions','report') 'Manifest child proof'
        String $proof.name 'Child proof name'
        Assert-Fact ($names.Add([string]$proof.name)) 'Child proof names unique'
        Fields $proof.report @('path','bytes','sha256') @('path','bytes','sha256') 'Child report identity'
        String $proof.report.path 'Child report path'
        Assert-Fact ($paths.Add([IO.Path]::GetFullPath($proof.report.path))) 'Child report paths unique'
        Assert-Fact ($digests.Add(([string]$proof.report.bytes)+':'+$proof.report.sha256)) 'Child report content identities unique'
        Record-Identity $proof.report
        $child=Read-ProofJson $proof.report.path
        $audited.Add((Audit-ChildProof $proof $child $Selected $Manifest.checks))
        $total+=$proof.assertions
    }
    Assert-Fact ($total -le $Manifest.checks.Count) 'Child proof assertion totals do not exceed parent assertions'
    return [pscustomobject]@{proofCount=$audited.Count;assertions=$total;parentAssertions=$Manifest.checks.Count;localAssertions=$Manifest.checks.Count-$total;proofs=$audited.ToArray()}
}

function Negative([string]$Name,$Value,[scriptblock]$Validate,[string]$Reason){
    $saved=$script:recordChecks;$script:recordChecks=$false;$errorText=$null
    try{& $Validate $Value|Out-Null}catch{$errorText=$_.Exception.Message}finally{$script:recordChecks=$saved}
    Assert-Fact ($null -ne $errorText -and $errorText.Contains($Reason)) "Negative control rejects intended defect: $Name"
    $controls.Add([pscustomobject]@{name=$Name;reason=$errorText;rejected=$true})
}
function Clone($Value){return ($Value|ConvertTo-Json -Depth 60|ConvertFrom-Json)}
try{
    $definition=Read-DefinitionJson (Join-Path $fixtureRoot 'definition.json')
    Fields $definition @('schema','status','rules','types','diagnostics','deferred','frontend','factValues','minimumCases') @('schema','status','rules','types','diagnostics','deferred','frontend','factValues','minimumCases') 'Definition'
    Assert-Fact ($definition.schema -ceq 'ube-semantic-definition-1' -and $definition.status -ceq 'approved-definition-only') 'Definition schema and approved implementation scope'
    Assert-Fact ((Integer $definition.minimumCases) -and $definition.minimumCases -ge 190 -and $definition.minimumCases -le 512) 'Definition minimum case count is bounded'
    foreach($domain in @('rules','types','diagnostics','deferred','frontend')){
        List $definition.$domain "Definition $domain" 1 64
        $unique=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach($item in $definition.$domain){String $item "Definition $domain entry";Assert-Fact ($unique.Add([string]$item)) "Definition $domain entries unique"}
    }
    $contract=[IO.File]::ReadAllText((Join-Path $compiler 'SEMANTIC-CONTRACT.md'),$utf8)
    foreach($rule in $definition.rules){Assert-Fact ($contract -cmatch ('(?m)^## '+[regex]::Escape($rule)+'\r?$')) 'Rule has exact contract section'}
    $selected=Get-VerifiedBootstrapSelection $SelectionPath
    Assert-Fact ($selected.schema -ceq 'ube-v2-current-1') 'Existing accepted selection schema'
    Record-Identity (Get-ArtifactIdentity $SelectionPath)
    foreach($p in $selected.PSObject.Properties){if($p.Name -cne 'schema'){Record-Identity $p.Value}}
    $manifest=Read-ProofJson $selected.manifest.path
    Assert-Fact ($manifest.success -is [bool] -and $manifest.success) 'Current source-built manifest succeeded'
    $proofAudit=Audit-ManifestProofs $manifest $selected
    foreach($id in @($manifest.inputs)+@($manifest.artifacts)){Record-Identity $id}
    foreach($t in $manifest.tools){Record-Identity $t.identity}
    $baseline=[pscustomobject]@{selection=(Get-ArtifactIdentity $SelectionPath);compiler=$selected.compiler;manifest=$selected.manifest;recordedAssertions=$manifest.checks.Count;proofCount=$proofAudit.proofCount;proofAssertions=$proofAudit.assertions;rerun=$false}
    Record-Identity (Get-ArtifactIdentity $PSCommandPath)
    $paths=@('SEMANTIC-CONTRACT.md','SEMANTIC-SYNTAX-INVENTORY.md','tools/check-semantic-contract.ps1','tools/check-semantic-inputs.ps1','tests/semantic/definition.json','tests/semantic/cases.json','tests/semantic/inventory.json','tests/semantic/obligations.json','tests/semantic/ORACLES.md')
    foreach($p in $paths){Record-Identity (Get-ArtifactIdentity (Join-Path $compiler $p))}
    foreach($p in @('lang-doc/language-spec.md','lang-doc/conversion-table.md','lang-doc/grammar/ube.ebnf','lang-doc/managed-memory.md','lang-doc/threading.md','docs/language/topics/types.html','bootstrap/tools/verification.ps1')){Record-Identity (Get-ArtifactIdentity (Join-Path $root $p))}
    $file=Read-DefinitionJson (Join-Path $fixtureRoot 'cases.json')
    Assert-Fact ($file.schema -ceq 'ube-semantic-cases-1') 'Cases schema';String $file.authorship 'Independent authorship statement'
    List $file.cases 'Complete case set' $definition.minimumCases 512
    $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $coverage=[Collections.Generic.Dictionary[string,int]]::new([StringComparer]::Ordinal)
    foreach($rule in $definition.rules){$coverage.Add($rule,0)}
    foreach($case in $file.cases){
        Assert-Fact ($names.Add([string]$case.id)) 'Case ID globally unique'
        try{$resolvedCases.Add((Validate-Case $case))}catch{throw "Case $($case.id): $($_.Exception.Message)"}
        foreach($rule in $case.rules){++$coverage[$rule]}
    }
    foreach($outcome in @('checked','error','deferred','frontend')){Assert-Fact (@($file.cases|Where-Object {$_.expected.outcome -ceq $outcome}).Count -gt 0) 'Each expected outcome represented'}
    foreach($domain in @('diagnostics','deferred','frontend')){
        foreach($kind in $definition.$domain){Assert-Fact (@($file.cases|Where-Object {(Has $_.expected 'diagnostic') -and $_.expected.diagnostic.kind -ceq $kind}).Count -gt 0) "Expected diagnostic/deferred class has an independent case: $kind"}
    }
    $inventory=Read-DefinitionJson (Join-Path $fixtureRoot 'inventory.json')
    Assert-Fact ($inventory.schema -ceq 'ube-semantic-inventory-1') 'Inventory schema';List $inventory.entries 'Inventory entries' 16 32
    $ids=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($entry in $inventory.entries){Assert-Fact ($ids.Add([string]$entry.id)) 'Inventory ID unique';$inventoryEvidence.Add((Validate-Inventory $entry))}
    $obligationsPath=Join-Path $fixtureRoot 'obligations.json'
    Record-Identity (Get-ArtifactIdentity $obligationsPath)
    $obligations=Read-DefinitionJson $obligationsPath
    Assert-Fact ($obligations.schema -ceq 'ube-semantic-obligations-1' -and $obligations.status -ceq 'native-gates-required') 'Native obligations state requirements, not results';List $obligations.obligations 'Obligations' 12 32
    $ids=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($o in $obligations.obligations){Assert-Fact ($ids.Add([string]$o.id)) 'Obligation ID unique';Validate-Obligation $o;foreach($rule in $o.rules){++$coverage[$rule]}}
    foreach($r in $coverage.Keys){Assert-Fact ($coverage[$r] -gt 0) "Contract rule has cases or future obligations: $r"}
    $checked=@($file.cases|Where-Object {$_.expected.outcome -ceq 'checked'})[0]
    $errorCase=@($file.cases|Where-Object {$_.expected.outcome -ceq 'error'})[0]
    $binding=@($file.cases|Where-Object id -CEQ 'unicode-simple-fold')[0]
    $call=@($file.cases|Where-Object id -CEQ 'named-source-order-not-parameter-order')[0]
    $coordinates=@($file.cases|Where-Object id -CEQ 'unicode-bom-crlf-tab-position')[0]
    $constant=@($file.cases|Where-Object id -CEQ 'integer-literal-max')[0]
    $v=Clone $checked;$v.rules=@('invented-rule');Negative 'undefined rule' $v {param($x) Validate-Case $x} 'Rule reference'
    $v=Clone $checked;$v.witnesses[0].text='absent witness';Negative 'absent original span' $v {param($x) Validate-Case $x} 'Witness exact occurrence'
    $v=Clone $checked;$v.witnesses[0].source='absent';Negative 'unknown source owner' $v {param($x) Validate-Case $x} 'Witness source exists'
    $v=Clone $checked;$v.expected.facts[0].type='Int128';Negative 'undefined type' $v {param($x) Validate-Case $x} 'Expected type'
    $v=Clone $binding;$v.expected.facts[0].target='missing';Negative 'missing binding declaration' $v {param($x) Validate-Case $x} 'Binding declaration'
    $v=Clone $call;$v.expected.facts[0].arguments[0].parameter=2;Negative 'call parameter outside signature' $v {param($x) Validate-Case $x} 'Call slot parameter'
    $v=Clone $call;$v.expected.facts[0].arguments=@($v.expected.facts[0].arguments[1],$v.expected.facts[0].arguments[0]);Negative 'parameter order substituted for evaluation order' $v {param($x) Validate-Case $x} 'Call slots preserve source order'
    $v=Clone $call;$v.expected.facts[0].arguments[0].mode='borrow-forever';Negative 'invalid alias mode' $v {param($x) Validate-Case $x} 'Call slot mode'
    $v=Clone $coordinates;$v.witnesses[0].anchor.byte=71;Negative 'wrong independent byte coordinate' $v {param($x) Validate-Case $x} 'Independent numeric byte'
    $v=Clone $coordinates;$v.witnesses[0].anchor.scalar=67;Negative 'wrong supplementary/CRLF scalar coordinate' $v {param($x) Validate-Case $x} 'Independent numeric scalar'
    $v=Clone $checked;$v.sources+=@($v.sources[0]);Negative 'duplicate source identity' $v {param($x) Validate-Case $x} 'Source ID unique'
    $v=Clone $binding;$v.declarations+=@($v.declarations[0]);Negative 'duplicate declaration identity' $v {param($x) Validate-Case $x} 'Declaration ID unique'
    $v=Clone $checked;$v.expected.outcome='compiled';Negative 'unsupported result category' $v {param($x) Validate-Case $x} 'Expected outcome'
    $v=Clone $errorCase;$v.expected.outcome='checked';Negative 'error relabeled as checked' $v {param($x) Validate-Case $x} 'Checked case has facts'
    $v=Clone $errorCase;$v.expected.PSObject.Properties.Remove('diagnostic');Negative 'missing required diagnostic' $v {param($x) Validate-Case $x} 'Failure/deferred has one diagnostic'
    $v=Clone $binding;$v.witnesses[0]|Add-Member -NotePropertyName mode -NotePropertyValue start;Negative 'empty declaration span' $v {param($x) Validate-Case $x} 'Declaration name is nonempty'
    $v=Clone $constant;$v.expected.facts[0].value='32768';Negative 'constant outside expected type' $v {param($x) Validate-Case $x} 'Expected constant fits'
    $v=Clone $checked;$v.PSObject.Properties.Remove('rules');Negative 'missing case requirement list' $v {param($x) Validate-Case $x} 'required field rules'
    $v=Clone $inventory.entries[0];$v.evidence[0]='fabricated retention field';Negative 'stale inventory source evidence' $v {param($x) Validate-Inventory $x} 'Inventory snippet exists'
    $v=Clone $obligations.obligations[0];$v.rules=@('invented-rule');Negative 'undefined future obligation rule' $v {param($x) Validate-Obligation $x} 'Rule reference'
    $v=Clone $manifest;$v.checks=@();Negative 'empty accepted assertion set' $v {param($x) Audit-ManifestProofs $x $selected} 'nonempty bounded assertions'
    $v=Clone $manifest;$v.checks[0].passed=$false;Negative 'failed accepted assertion' $v {param($x) Audit-ManifestProofs $x $selected} 'explicitly passed'
    $v=Clone $manifest;$v.proofs+=@(Clone $v.proofs[0]);Negative 'duplicate proof family' $v {param($x) Audit-ManifestProofs $x $selected} 'names unique'
    $v=Clone $manifest;$duplicate=Clone $v.proofs[0];$duplicate.name='duplicate-report-control';$v.proofs+=@($duplicate);Negative 'reused proof report identity' $v {param($x) Audit-ManifestProofs $x $selected} 'report paths unique'
    $v=Clone $manifest;$v.proofs[0].assertions=$v.proofs[0].assertions+1;Negative 'incorrect declared proof count' $v {param($x) Audit-ManifestProofs $x $selected} 'recorded assertion count matches'
    $v=Clone $manifest;$v.proofs[0].report.sha256=('0'*64);Negative 'changed child report hash' $v {param($x) Audit-ManifestProofs $x $selected} 'identity unchanged'
    $auditProof=$manifest.proofs[0];$auditChild=Read-ProofJson $auditProof.report.path
    $v=Clone $auditChild;$v.success=$false;Negative 'unsuccessful child report' $v {param($x) Audit-ChildProof $auditProof $x $selected $manifest.checks} 'Child proof succeeded'
    $v=Clone $auditChild;$v.checks=@();Negative 'empty child checks' $v {param($x) Audit-ChildProof $auditProof $x $selected $manifest.checks} 'nonempty bounded assertion array'
    $v=Clone $auditChild;$v.acceptedSelection.compiler.sha256=('0'*64);Negative 'another accepted compiler' $v {param($x) Audit-ChildProof $auditProof $x $selected $manifest.checks} 'current accepted compiler identity'
    $v=Clone $auditChild
    if($v.checks[0] -is [string]){$v.checks[0]=''}else{$v.checks[0].passed=$false}
    Negative 'failed or empty child assertion' $v {param($x) Audit-ChildProof $auditProof $x $selected $manifest.checks} $(if($auditChild.checks[0] -is [string]){'nonempty'}else{'explicitly passed'})
    $v=Clone $manifest
    foreach($check in $v.checks){if($check.name -ceq $auditProof.name){$check.assertion='substituted child assertion';break}}
    Negative 'parent assertion text detached from child' $v {param($x) Audit-ChildProof $auditProof $auditChild $selected $x.checks} 'text/order matches hashed child'
    $v=Clone $auditChild;$v.acceptedSelection.manifest.sha256=('0'*64)
    $allowed=Audit-ChildProof $auditProof $v $selected $manifest.checks
    Assert-Fact ($allowed.assertions -eq $auditProof.assertions) 'Provisional child manifest hash may differ from final parent'

    foreach($id in @($identities.Values)){Record-Identity $id}
    $null=Get-VerifiedBootstrapSelection $SelectionPath
    $success=$true
}catch{$failure=$_.Exception.Message}
finally{
    $report=[ordered]@{schema='ube-semantic-contract-proof-1';success=$success;definitionOnly=$true;semanticImplemented=$false;sourceBuildCurrent=$success;acceptedSelection=$selected;failure=$failure;baseline=$baseline;proofAudit=$proofAudit;identityCount=$identities.Count;identities=@($identities.Values);caseCount=$resolvedCases.Count;cases=$resolvedCases.ToArray();inventory=$inventoryEvidence.ToArray();negativeControls=$controls.ToArray();assertionCount=$checks.Count;checks=$checks.ToArray();limits='Definition consistency and current selected input/artifact identity audit only. No UBE parsing, semantic evaluation, native checker, fault/concurrency/performance execution or frontend rebuild is performed. Inventory snippets are source evidence, not proof of future published detail. Native obligations remain unexecuted.'}
    $report|ConvertTo-Json -Depth 60|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if(-not $success){throw $failure}
Write-Output "PASS definition only: $($resolvedCases.Count) cases, $($inventoryEvidence.Count) inventory entries, $($controls.Count) negative controls, $($checks.Count) assertions; $($identities.Count) identities unchanged."
