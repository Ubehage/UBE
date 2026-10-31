# Test-only translation of hand-authored partitions into C constants. This does
# not recognize token boundaries: pieces and diagnostic anchors supply them.
function Write-NativeScannerOracles([string]$Directory,[string]$Destination) {
    $utf8 = New-Object Text.UTF8Encoding($false,$true)
    function CBytes([string]$s) { $b=$utf8.GetBytes($s); if ($b.Length -eq 0) { return '0' }; return ($b | ForEach-Object { $_.ToString() }) -join ',' }
    function CPosition([string]$s,[int]$offset) {
        $prefix=$s.Substring(0,$offset); $byte=$utf8.GetByteCount($prefix); $scalar=0; $line=1; $column=1
        for ($j=0;$j -lt $offset;++$j) {
            $c=[int]$s[$j]
            if ($j -eq 0 -and $c -eq 65279) { continue }
            if ([char]::IsHighSurrogate($s[$j])) { ++$j }
            ++$scalar
            if ($c -eq 10) { ++$line; $column=1 } elseif ($c -ne 13) { ++$column }
        }
        return "{$byte,$scalar,$line,$column}"
    }
    $kinds=@{Identifier=1;Keyword=2;Integer=3;Real=4;String=5;BracketIdentifier=6;Symbol=7;HSpace=8;Comment=9;RemComment=10;Continuation=11;Bom=12;Newline=13;DateCandidate=14;Eof=15;Invalid=0}
    $failures=@{UnexpectedCharacter=1;UnterminatedString=2;UnterminatedBracketIdentifier=3;EmptyBracketIdentifier=4}
    $text=New-Object Text.StringBuilder
    [void]$text.AppendLine('/* Derived only from hand-authored fixture pieces and prefix coordinates. */')
    $cases=@((Get-Content -LiteralPath (Join-Path $Directory 'tokens.json') -Encoding UTF8 -Raw | ConvertFrom-Json).cases)
    $cases+=@((Get-Content -LiteralPath (Join-Path $Directory 'native/regressions.json') -Encoding UTF8 -Raw|ConvertFrom-Json).tokenCases)
    [void]$text.AppendLine('static const size_t token_fixture_count = '+$cases.Count+';')
    $wordCases=@((Get-Content -LiteralPath (Join-Path $Directory 'words.json') -Encoding UTF8 -Raw | ConvertFrom-Json).words)
    foreach ($word in $wordCases) {
        $kind='Identifier'; if ($word.role -ceq 'reserved') { $kind='Keyword' }
        $cases+= [pscustomobject]@{name=('word-'+$word.word);source=('x.'+$word.word);pieces=@(@('Identifier','x'),@('Symbol','.'),@($kind,$word.word),@('Newline','',$true),@('Eof',''))}
    }
    $index=0; $rows=@()
    foreach ($case in $cases) {
        $source=[string]$case.source; $offset=0; $records=@(); $failure='{0,{0,0,0,0},{0,0,0,0}}'
        foreach ($piece in $case.pieces) {
            $start=CPosition $source $offset; $offset+=([string]$piece[1]).Length; $end=CPosition $source $offset
            $records+=('{'+$kinds[[string]$piece[0]]+','+$start+','+$end+'}')
        }
        $diagnostics=$case.PSObject.Properties['diagnostics']
        if ($null -ne $diagnostics) {
            $diag=$case.diagnostics[0]; $record=$records[[int]$diag.piece]
            $failure=$record -replace '^\{0,',('{'+$failures[[string]$diag.kind]+',')
        }
        $context=0; if ($case.PSObject.Properties['context']) { switch ($case.context) { expression {$context=1}; 'file-number' {$context=2}; statement {$context=3} } }
        [void]$text.AppendLine("static const uint8_t token_source_$index[] = {$(CBytes $source)};")
        [void]$text.AppendLine("static const struct token token_expected_$index[] = {$($records -join ',')};")
        $rows+=('{"'+$case.name+'",token_source_'+$index+','+$utf8.GetByteCount($source)+','+$context+',token_expected_'+$index+','+$records.Count+','+$failure+'}')
        ++$index
    }
    [void]$text.AppendLine('static const struct token_case token_cases[] = {'+($rows -join ",`n")+'};')
    function Find-Anchor([string]$source,$anchor) {
        if($anchor.PSObject.Properties['eof']){return @($source.Length,$source.Length)}
        $at=-1;for($occ=0;$occ -lt [int]$anchor.occurrence;++$occ){$at=$source.IndexOf([string]$anchor.raw,$at+1,[StringComparison]::Ordinal);if($at -lt 0){throw 'Absent hand-authored envelope anchor'}}
        return @($at,($at+([string]$anchor.raw).Length))
    }
    $envelopes=@((Get-Content -LiteralPath (Join-Path $Directory 'envelopes.json') -Encoding UTF8 -Raw|ConvertFrom-Json).cases)
    $envelopes+=@((Get-Content -LiteralPath (Join-Path $Directory 'native/regressions.json') -Encoding UTF8 -Raw|ConvertFrom-Json).cases)
    $diagnostics=@{MissingSourceHeader=101;UnsupportedSourceVersion=102;SourceKindMismatch=103;MissingSourceIdentity=104;InvalidSourceIdentity=105;DuplicateSourceIdentity=106;UnknownReservedAttribute=107}
    $extensions=@{'.bas'=1;'.cls'=2;'.frm'=3;'.ctl'=4};$containerKinds=@{MODULE=1;CLASS=2;FORM=3;CONTROL=4}
    $rows=@();$index=0
    foreach($case in $envelopes){
        $source=[string]$case.source;$expected=$case.expected;$format=0;$kind=0;$has=0;$first=0;$last=0;$failure='{0,{0,0,0,0},{0,0,0,0}}'
        if($expected.format -ceq 'reject'){
            $anchor=Find-Anchor $source $expected.anchor
            $failure='{'+$diagnostics[[string]$expected.diagnostic]+','+(CPosition $source $anchor[0])+','+(CPosition $source $anchor[1])+'}'
        }else{
            $format=2;if($expected.format -ceq 'native'){$format=1;$kind=$containerKinds[[string]$expected.kind]}
            if($expected.PSObject.Properties['identity']){
                $span=@($expected.spans|Where-Object role -CEQ 'identity')[0];$anchor=Find-Anchor $source $span
                $first=$utf8.GetByteCount($source.Substring(0,$anchor[0]));$last=$utf8.GetByteCount($source.Substring(0,$anchor[1]));$has=1
            }
        }
        $spans=@();if($expected.PSObject.Properties['spans']){foreach($span in $expected.spans){$anchor=Find-Anchor $source $span;$b=$utf8.GetByteCount($source.Substring(0,$anchor[0]));$n=$utf8.GetByteCount([string]$span.raw);$spans+=('{'+$b+','+$n+',envelope_span_'+$index+'_'+$spans.Count+'}');[void]$text.AppendLine('static const uint8_t envelope_span_'+$index+'_'+($spans.Count-1)+'[] = {'+(CBytes ([string]$span.raw))+'};')}}
        if($spans.Count -eq 0){$spans=@('{0,0,NULL}')}
        [void]$text.AppendLine('static const struct raw_span envelope_spans_'+$index+'[] = {'+($spans -join ',')+'};')
        [void]$text.AppendLine("static const uint8_t envelope_source_$index[] = {$(CBytes $source)};")
        $rows+=('{"'+$case.name+'",envelope_source_'+$index+','+$utf8.GetByteCount($source)+','+$extensions[[string]$case.extension]+','+$format+','+$kind+','+$first+','+$last+','+$has+','+$failure+',envelope_spans_'+$index+','+$(if($expected.PSObject.Properties['spans']){$expected.spans.Count}else{0})+'}')
        ++$index
    }
    [void]$text.AppendLine('static const struct envelope_case envelope_cases[] = {'+($rows -join ",`n")+'};')
    [IO.File]::WriteAllText($Destination,$text.ToString(),$utf8)
}
