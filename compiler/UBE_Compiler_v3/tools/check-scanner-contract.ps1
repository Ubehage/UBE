param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/scanner-contract/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false,$true)
$checks = New-Object 'System.Collections.Generic.List[object]'
$vectors = New-Object 'System.Collections.Generic.List[object]'
$inputs = @()
$success = $false
$failure = $null
$lexicalDiagnostics=@('UnexpectedCharacter','UnterminatedString','UnterminatedBracketIdentifier','EmptyBracketIdentifier')
$envelopeDiagnostics=@('MissingSourceHeader','UnsupportedSourceVersion','SourceKindMismatch','MissingSourceIdentity','InvalidSourceIdentity','DuplicateSourceIdentity','UnknownReservedAttribute')
function Assert-Fact([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
    $checks.Add([pscustomobject]@{assertion=$Message;passed=$true})
}
function Same-Text([string]$Left,[string]$Right) {
    return [string]::Equals($Left,$Right,[StringComparison]::Ordinal)
}
function Read-Json([string]$Relative) {
    $path=Join-Path $root $Relative
    if ((Get-Item -LiteralPath $path).Length -gt 1048576) { throw "Oversized fixture: $Relative" }
    $script:inputs += Get-ArtifactIdentity $path
    return ([IO.File]::ReadAllText($path,$utf8) | ConvertFrom-Json)
}
function Position-At([string]$Source,[int]$Index) {
    if ($Index -lt 0 -or $Index -gt $Source.Length) { throw 'Coordinate outside source' }
    $prefix=$Source.Substring(0,$Index)
    $byte=$utf8.GetByteCount($prefix)
    $scalar=0;$line=1;$column=1
    for ($i=0;$i -lt $Index;$i++) {
        $code=[int]$Source[$i]
        if ([char]::IsHighSurrogate($Source[$i])) { $code=[char]::ConvertToUtf32($Source,$i);$i++ }
        if ($code -eq 65279 -and $i -eq 0) { continue }
        $scalar++
        if ($code -eq 10) { $line++;$column=1 }
        elseif ($code -ne 13) { $column++ }
    }
    return [pscustomobject]@{byte=$byte;scalar=$scalar;line=$line;column=$column}
}
function Known-Identifier([string]$Raw) {
    if ($Raw.Length -eq 0) { return $false }
    for ($i=0;$i -lt $Raw.Length;$i++) {
        $c=[int]$Raw[$i]
        $letter=($c -ge 65 -and $c -le 90) -or ($c -ge 97 -and $c -le 122) -or
            $c -in @(229,233,383,945,946,931,963,962,223,7838,8490)
        if (-not ($letter -or $c -eq 95 -or ($i -gt 0 -and $c -ge 48 -and $c -le 57))) { return $false }
    }
    return $true
}
function Known-SimpleFold([string]$Raw) {
    $builder=New-Object Text.StringBuilder
    foreach ($character in $Raw.ToCharArray()) {
        $code=[int]$character
        if ($code -ge 65 -and $code -le 90) { $code+=32 }
        elseif ($code -eq 8490) { $code=107 }
        elseif ($code -eq 931 -or $code -eq 962) { $code=963 }
        elseif ($code -eq 7838) { $code=223 }
        elseif ($code -eq 383) { $code=115 }
        [void]$builder.Append([char]$code)
    }
    return $builder.ToString()
}
function Invariant-Date([string]$Raw) {
    $text=$Raw.Substring(1,$Raw.Length-2)
    if ($text -cnotmatch '^(?:(?<y>[0-9]{4})-(?<m>[0-9]{2})-(?<d>[0-9]{2})(?:(?:T| )(?<h>[0-9]{2}):(?<n>[0-9]{2})(?::(?<s>[0-9]{2})(?:\.[0-9]{1,9})?)?)?|(?<h>[0-9]{2}):(?<n>[0-9]{2})(?::(?<s>[0-9]{2})(?:\.[0-9]{1,9})?)?)$') { return $false }
    $matched=$Matches
    if ($matched.ContainsKey('y')) {
        $year=[int]$matched.y;$month=[int]$matched.m;$day=[int]$matched.d
        if ($year -eq 0 -or $month -lt 1 -or $month -gt 12) { return $false }
        $days=@(31,28,31,30,31,30,31,31,30,31,30,31)
        if (($year%4 -eq 0) -and ($year%100 -ne 0 -or $year%400 -eq 0)) { $days[1]=29 }
        if ($day -lt 1 -or $day -gt $days[$month-1]) { return $false }
    }
    if ($matched.ContainsKey('h')) {
        if ([int]$matched.h -gt 23 -or [int]$matched.n -gt 59) { return $false }
        if ($matched.ContainsKey('s') -and [int]$matched.s -gt 59) { return $false }
    }
    return $true
}
function Assert-TokenCase($Case,$Words) {
    [void]$utf8.GetBytes([string]$Case.source)
    $name=[string]$Case.name;$physical='';$index=0;$eof=0;$synthetic=0;$positions=@();$spans=@();$lastPhysicalKind=''
    for ($n=0;$n -lt $Case.pieces.Count;$n++) {
        $piece=$Case.pieces[$n];$kind=[string]$piece[0];$raw=[string]$piece[1]
        Assert-Fact ($piece.Count -ge 2 -and $piece.Count -le 3) "$name piece$n shape"
        $isSynthetic=$piece.Count -eq 3 -and [bool]$piece[2]
        $start=Position-At $Case.source $index
        $positions+=,$start
        if ($isSynthetic) { $synthetic++;Assert-Fact ($kind -ceq 'Newline' -and $raw.Length -eq 0) "$name synthetic newline zero width" }
        elseif ($kind -ceq 'Eof') { $eof++;Assert-Fact ($raw.Length -eq 0 -and $n -eq $Case.pieces.Count-1) "$name terminal EOF" }
        else {
            Assert-Fact ($raw.Length -gt 0 -and $Case.source.Substring($index).StartsWith($raw,[StringComparison]::Ordinal)) "$name piece$n exact original substring"
            $physical+=$raw;$index+=$raw.Length;$lastPhysicalKind=$kind
        }
        $end=Position-At $Case.source $index
        $spans+=[pscustomobject]@{kind=$kind;raw=$raw;start=$start;end=$end;synthetic=$isSynthetic}
        switch -CaseSensitive ($kind) {
            'Identifier' { Assert-Fact (Known-Identifier $raw) "$name known identifier-shape vector"; $key=Known-SimpleFold $raw;Assert-Fact (-not $Words.ContainsKey($key) -or $Words[$key].role -cne 'reserved') "$name identifier is not a reserved vector" }
            'Keyword' { $key=Known-SimpleFold $raw;Assert-Fact ($Words.ContainsKey($key) -and $Words[$key].role -ceq 'reserved') "$name reserved word catalogue vector" }
            'Integer' { Assert-Fact ($raw -cmatch '^(?:[0-9]+|&[Hh][0-9A-Fa-f]+|&[Oo][0-7]+)[%&^]?$') "$name integer spelling" }
            'Real' { Assert-Fact ($raw -cmatch '^(?:[0-9]+\.[0-9]*(?:[EeDd][+-]?[0-9]+)?|\.[0-9]+(?:[EeDd][+-]?[0-9]+)?|[0-9]+[EeDd][+-]?[0-9]+)[!#@FfRrDd]?$') "$name real-core closure spelling" }
            'String' { Assert-Fact ($raw -cmatch '^"(?:[^"\r\n]|"")*"$') "$name quoted string shape" }
            'BracketIdentifier' { Assert-Fact ($raw -cmatch '^\[(?:[^\]\r\n]|\]\])+\]$') "$name bracket identifier shape" }
            'Symbol' { Assert-Fact ($raw -cin @(':=','<=','>=','<>','+','-','*','/','\','^','&','=','<','>','.', '!',':',',',';','(',')','%','#','@','$')) "$name defined punctuation" }
            'HSpace' { Assert-Fact ($raw -cmatch '^[ \t]+$') "$name HSPACE is space/tab" }
            'Comment' { Assert-Fact ($raw -cmatch "^'[^\r\n]*$") "$name apostrophe comment shield" }
            'RemComment' { Assert-Fact ($raw -match '^Rem(?:[ \t][^\r\n]*)?$' -and $Case.PSObject.Properties['context'] -and $Case.context -ceq 'statement') "$name explicit statement Rem context" }
            'Continuation' { Assert-Fact ($raw -cmatch '^[ \t]_([ \t]*)(?:\x27[^\r\n]*)?\r?\n[ \t]*$') "$name physical continuation shape" }
            'Bom' { Assert-Fact ($n -eq 0 -and $raw -ceq [string][char]65279) "$name initial BOM only" }
            'Newline' { if (-not $isSynthetic) { Assert-Fact ($raw -ceq "`n" -or $raw -ceq "`r`n") "$name physical newline shape" } }
            'DateCandidate' { Assert-Fact ($raw -cmatch '^#[^#\r\n]+#$' -and $Case.context -ceq 'expression') "$name explicit expression date candidate" }
            'Invalid' { Assert-Fact ([bool]$Case.PSObject.Properties['diagnostics']) "$name invalid piece has explicit diagnostic" }
            'Eof' {}
            default { throw "Unknown fixture kind $kind" }
        }
        if ($n+1 -lt $Case.pieces.Count) {
            $next=$Case.pieces[$n+1]
            if ($kind -ceq 'Symbol' -and [string]$next[0] -ceq 'Symbol') { Assert-Fact (($raw+[string]$next[1]) -cnotin @(':=','<=','>=','<>')) "$name longest two-character punctuation" }
            if ($kind -ceq 'Integer' -and [string]$next[0] -ceq 'Symbol' -and $raw -cnotmatch '[%&^]$') { Assert-Fact ([string]$next[1] -cnotin @('%','&','^')) "$name adjacent integer suffix is not split" }
        }
    }
    Assert-Fact ((Same-Text $physical $Case.source) -and $index -eq $Case.source.Length -and $eof -eq 1 -and $synthetic -le 1) "$name exact partition and EOF cardinality"
    $last=$Case.pieces[$Case.pieces.Count-2]
    $requiredSynthetic=1
    if ($lastPhysicalKind -ceq 'Newline') { $requiredSynthetic=0 }
    Assert-Fact ($synthetic -eq $requiredSynthetic) "$name final newline only when its logical terminator is missing"
    Assert-Fact ([string]$last[0] -ceq 'Newline') "$name final logical newline before EOF"
    if ($Case.PSObject.Properties['anchors']) { foreach ($anchor in $Case.anchors) {
        $p=$positions[[int]$anchor.piece]
        Assert-Fact ($p.byte -eq $anchor.byte -and $p.scalar -eq $anchor.scalar -and $p.line -eq $anchor.line -and $p.column -eq $anchor.column) "$name independent original coordinate anchor piece$($anchor.piece)"
    } }
    if ($Case.PSObject.Properties['decoded']) { foreach ($decoded in $Case.decoded) {
        $piece=$Case.pieces[[int]$decoded.piece];$text=[string]$piece[1]
        $value=$text.Substring(1,$text.Length-2)
        if ([string]$piece[0] -ceq 'String') { $value=$value.Replace('""','"') } else { $value=$value.Replace(']]',']') }
        Assert-Fact (Same-Text $value ([string]$decoded.value)) "$name independently specified decoded content"
    } }
    if ($Case.PSObject.Properties['identities']) { foreach ($identity in $Case.identities) {
        $piece=$Case.pieces[[int]$identity.piece];$spelling=[string]$piece[1]
        if ([string]$piece[0] -ceq 'BracketIdentifier') { $spelling=$spelling.Substring(1,$spelling.Length-2).Replace(']]',']') }
        Assert-Fact (Same-Text (Known-SimpleFold $spelling) $identity.folded) "$name explicit known simple-fold vector"
    } }
    if ($Case.PSObject.Properties['dateChecks']) { foreach ($date in $Case.dateChecks) { Assert-Fact ((Invariant-Date ([string]$Case.pieces[[int]$date.piece][1])) -eq [bool]$date.valid) "$name invariant date candidate oracle" } }
    if ($Case.PSObject.Properties['diagnostics']) { foreach ($diagnostic in $Case.diagnostics) {
        Assert-Fact ($diagnostic.kind -cin $lexicalDiagnostics) "$name diagnostic classification is defined"
        Assert-Fact ([string]$Case.pieces[[int]$diagnostic.piece][0] -ceq 'Invalid') "$name diagnostic original offending span"
    } }
    if ($Case.PSObject.Properties['directive']) {
        $logical=New-Object Text.StringBuilder
        foreach ($piece in $Case.pieces) {
            if ([string]$piece[0] -ceq 'Continuation') { [void]$logical.Append(' ') }
            elseif ([string]$piece[0] -cnotin @('Bom','Newline','Eof','Comment','RemComment')) { [void]$logical.Append([string]$piece[1]) }
        }
        $text=$logical.ToString()
        Assert-Fact (Same-Text $text $Case.directive.logical) "$name logical boundary oracle preserves word separation"
        $canonical=Known-SimpleFold $text.TrimStart([char[]]" `t")
        $eligible=$canonical -cmatch '^#(?:const[ \t]+.+|if[ \t]+.+[ \t]+then|elseif[ \t]+.+[ \t]+then|else|end[ \t]+if)$'
        Assert-Fact ($eligible -eq [bool]$Case.directive.eligible) "$name complete logical directive witness"
        if ($eligible) { Assert-Fact ($Case.context -ceq 'logical-directive') "$name directive context explicit" }
    }
    $vectors.Add([pscustomobject]@{name=$name;layer='token-oracle';bytes=$utf8.GetByteCount($Case.source);sourceHex=([BitConverter]::ToString($utf8.GetBytes($Case.source))).Replace('-','');spans=$spans})
}
function Resolve-Span([string]$Source,$Span) {
    if ($Span.PSObject.Properties['eof'] -and $Span.eof) { $i=$Source.Length;$raw='' }
    else {
        $raw=[string]$Span.raw;$i=-1;$from=0
        if ($raw.Length -eq 0 -or [int]$Span.occurrence -lt 1) { throw 'Invalid raw anchor' }
        for ($n=0;$n -lt [int]$Span.occurrence;$n++) {
            $i=$Source.IndexOf($raw,$from,[StringComparison]::Ordinal)
            if ($i -lt 0) { throw 'Declared envelope substring absent' }
            $from=$i+$raw.Length
        }
    }
    return [pscustomobject]@{raw=$raw;start=(Position-At $Source $i);end=(Position-At $Source ($i+$raw.Length))}
}
try {
    foreach ($relative in @('compiler/UBE_Compiler_v3/SCANNER-CONTRACT.md','compiler/UBE_Compiler_v3/tools/check-scanner-contract.ps1','lang-doc/language-spec.md','lang-doc/grammar/ube.ebnf','lang-doc/grammar/conditional-compilation.ebnf','lang-doc/project-files.md','lang-doc/v3-language-definition.md','compiler/UBE_Compiler_v3/SOURCE-INPUT-CONTRACT.md','bootstrap/tools/verification.ps1')) { $inputs+=Get-ArtifactIdentity (Join-Path $root $relative) }
    $catalog=Read-Json 'compiler/UBE_Compiler_v3/tests/scanner/words.json'
    $tokens=Read-Json 'compiler/UBE_Compiler_v3/tests/scanner/tokens.json'
    $envelopes=Read-Json 'compiler/UBE_Compiler_v3/tests/scanner/envelopes.json'
    Assert-Fact ($catalog.schema -ceq 'ube-scanner-word-catalog-1' -and $tokens.schema -ceq 'ube-scanner-token-oracles-1' -and $envelopes.schema -ceq 'ube-scanner-envelope-oracles-1') 'fixture schemas are explicit'
    $words=[Collections.Hashtable]::new([StringComparer]::Ordinal)
    foreach ($word in $catalog.words) {
        Assert-Fact ($word.word -cmatch '^[a-z][a-z_0-9]*$' -and -not $words.ContainsKey($word.word) -and $word.role -cin @('reserved','contextual','attribute')) "catalogue $($word.word) unique canonical spelling/role"
        $words[$word.word]=$word
        if ($word.basis.StartsWith('docs/')) {
            $articlePath=Join-Path $root $word.basis
            $inputs+=Get-ArtifactIdentity $articlePath
            $article=[IO.File]::ReadAllText($articlePath)
            if ($article.Contains('<span class="badge">Contextual word</span>')) { Assert-Fact ($word.role -ceq 'contextual') "catalogue $($word.word) preserves documented contextual role" }
            elseif ($article.Contains('<span class="badge">Reserved word</span>')) { Assert-Fact ($word.role -ceq 'reserved') "catalogue $($word.word) preserves declaration reservedness" }
        }
    }
    $grammar=[IO.File]::ReadAllText((Join-Path $root 'lang-doc/grammar/ube.ebnf'))
    $structural=$grammar.Substring(0,$grammar.IndexOf('(* Literals *)',[StringComparison]::Ordinal))
    $structural=[regex]::Replace($structural,'(?s)\(\*.*?\*\)','')
    $required=@([regex]::Matches($structural,'"([A-Za-z][A-Za-z_0-9]*)"') | ForEach-Object {$_.Groups[1].Value.ToLowerInvariant()})+@('true','false','nothing','null','empty','rem')
    $required=@($required | Sort-Object -Unique)
    Assert-Fact ($required.Count -eq $words.Count -and @($required | Where-Object {-not $words.ContainsKey($_)}).Count -eq 0) 'complete alphabetic structural grammar vocabulary and literal words'
    foreach ($hard in $catalog.requiredHard) { Assert-Fact ($words[$hard.ToLowerInvariant()].role -ceq 'reserved') "explicit hard addition $hard" }
    foreach ($name in $catalog.ordinaryNames) { $key=$name.ToLowerInvariant();Assert-Fact (-not $words.ContainsKey($key) -or $words[$key].ordinaryCallEligible) "ordinary library eligibility $name is not lost" }
    $names=@{}
    foreach ($case in $tokens.cases) { Assert-Fact (-not $names.ContainsKey($case.name)) "unique token case $($case.name)";$names[$case.name]=$true;Assert-TokenCase $case $words }
    $extensions=@{MODULE='.bas';CLASS='.cls';FORM='.frm';CONTROL='.ctl'}
    foreach ($case in $envelopes.cases) {
        Assert-Fact (-not $names.ContainsKey($case.name)) "unique envelope case $($case.name)";$names[$case.name]=$true
        [void]$utf8.GetBytes([string]$case.source)
        foreach ($authority in $case.authority) { Assert-Fact (Test-Path -LiteralPath (Join-Path $root (($authority -split '#')[0]))) "$($case.name) authority exists" }
        $expected=$case.expected;$spans=@()
        Assert-Fact ($expected.format -cin @('native','legacy','reject')) "$($case.name) declared envelope outcome"
        if ($expected.format -ceq 'native') { Assert-Fact ($extensions[$expected.kind] -ieq $case.extension -and [string]$expected.identity -ne '') "$($case.name) identity and extension-kind oracle consistency" }
        if ($expected.format -ceq 'reject') { $anchor=Resolve-Span $case.source $expected.anchor;$spans+=,$anchor;Assert-Fact ($expected.diagnostic -cin $envelopeDiagnostics) "$($case.name) defined explicit diagnostic and original anchor" }
        if ($expected.PSObject.Properties['spans']) { foreach ($span in $expected.spans) {
            $resolved=Resolve-Span $case.source $span;$spans+=,$resolved
            Assert-Fact ($resolved.end.byte -gt $resolved.start.byte) "$($case.name) exact preserved $($span.role) span"
            if ($span.role -ceq 'identity') {
                $quoted=[string]$resolved.raw
                Assert-Fact ($quoted -cmatch '^"(?:[^"\r\n]|"")*"$' -and (Same-Text ($quoted.Substring(1,$quoted.Length-2).Replace('""','"')) $expected.identity)) "$($case.name) identity equals exact quoted source value"
            }
            if ($span.role -ceq 'kind') { Assert-Fact (Same-Text (Known-SimpleFold $resolved.raw) (Known-SimpleFold $expected.kind)) "$($case.name) kind equals original header word" }
            if ($span.role -ceq 'version') { Assert-Fact ($resolved.raw -cmatch '^[0-9]+$' -and (Same-Text $resolved.raw.TrimStart('0') ([string]$expected.canonicalVersion))) "$($case.name) numeric version spelling consistency without host integer overflow" }
        } }
        if ($expected.PSObject.Properties['canonicalIdentity']) { Assert-Fact (Same-Text ($expected.identity.Substring(1,$expected.identity.Length-2).Replace(']]',']')) $expected.canonicalIdentity) "$($case.name) bracket spelling decodes separate canonical identity" }
        $vectors.Add([pscustomobject]@{name=$case.name;layer='envelope-oracle';bytes=$utf8.GetByteCount($case.source);sourceHex=([BitConverter]::ToString($utf8.GetBytes($case.source))).Replace('-','');expected=$expected;spans=$spans})
    }
    # Controls prove the definition gate detects inconsistent data; no checked-in
    # fixture is mutated and no production scanner is substituted by these tests.
    $bad=$tokens.cases[0] | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $bad.source='x';$caught=$false
    try { Assert-TokenCase $bad $words } catch { $caught=Same-Text $_.Exception.Message 'empty exact partition and EOF cardinality' }
    Assert-Fact $caught 'negative control: missing physical lexeme is rejected'
    $bad=$tokens.cases[2] | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $bad.anchors[0].byte=99;$caught=$false
    try { Assert-TokenCase $bad $words } catch { $caught=Same-Text $_.Exception.Message 'unicode-eof independent original coordinate anchor piece1' }
    Assert-Fact $caught 'negative control: incorrect byte coordinate is rejected'
    $caught=$false
    try { [void](Resolve-Span 'source' ([pscustomobject]@{raw='missing';occurrence=1})) } catch { $caught=Same-Text $_.Exception.Message 'Declared envelope substring absent' }
    Assert-Fact $caught 'negative control: absent original metadata span is rejected'
    Assert-Fact (-not (Same-Text "a`0b" 'ab') -and -not (Same-Text 'é' "e$([char]769)") -and -not (Same-Text 'ß' 'ss')) 'ordinal oracle does not ignore NUL, normalize or full-fold'
    $bad=@($tokens.cases | Where-Object name -CEQ 'nul-outside')[0] | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $bad.diagnostics[0].kind='UndefinedLabel';$caught=$false
    try { Assert-TokenCase $bad $words } catch { $caught=Same-Text $_.Exception.Message 'nul-outside diagnostic classification is defined' }
    Assert-Fact $caught 'negative control: undefined diagnostic classification is rejected'
    $bad=@($tokens.cases | Where-Object name -CEQ 'physical-lf')[0] | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $pieces=New-Object Collections.ArrayList
    foreach ($piece in $bad.pieces) { if ([string]$piece[0] -cne 'Eof') { [void]$pieces.Add($piece) } }
    [void]$pieces.Add([object[]]@('Newline','',$true));[void]$pieces.Add([object[]]@('Eof',''))
    $bad.pieces=$pieces.ToArray();$caught=$false
    try { Assert-TokenCase $bad $words } catch { $caught=Same-Text $_.Exception.Message 'physical-lf final newline only when its logical terminator is missing' }
    Assert-Fact $caught 'negative control: redundant synthetic newline is rejected'
    foreach ($identity in $inputs) { if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Input changed: $($identity.path)" } }
    $success=$true
} catch { $failure=$_.Exception.Message }
finally {
    [pscustomobject]@{schema='ube-scanner-contract-proof-1';success=$success;failure=$failure;inputs=$inputs;checks=@($checks.ToArray());vectors=@($vectors.ToArray());
        limits='Definition/data consistency only. No production scanner/parser/preprocessor, keyword-context consumer, Unicode implementation, native failure/concurrency/cost or compiler correctness is qualified. Identifier and folding sanity checks cover explicit known fixture scalars, never host Unicode. Source coordinate oracle uses strict UTF8 and UTF16 scalar decoding; raw expected lexeme partitions are hand authored.'} |
        ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) scanner-contract consistency assertions; $($vectors.Count) independent vectors; $($words.Count) word roles. This checks acceptance data, not production scanner behavior."
