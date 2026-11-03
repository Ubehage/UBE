param([Parameter(Mandatory=$true)][string] $Full,
      [Parameter(Mandatory=$true)][string] $None,
      [Parameter(Mandatory=$true)][string] $ExpectedSource,
      [Parameter(Mandatory=$true)][string] $ExpectedProducer,
      [Parameter(Mandatory=$true)][string] $ExpectedDirectory,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$fullPath=(Resolve-Path -LiteralPath $Full).Path; $nonePath=(Resolve-Path -LiteralPath $None).Path
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$utf8=[Text.UTF8Encoding]::new($false,$true)
function Range([byte[]]$b,[long]$p,[long]$n,[long]$end) {
    if ($p -lt 0 -or $n -lt 0 -or $end -gt $b.Length -or $p -gt $end -or $n -gt $end-$p) { throw 'bounded read rejected' }
}
function U16([byte[]]$b,[long]$p,[long]$end) { Range $b $p 2 $end; return [BitConverter]::ToUInt16($b,[int]$p) }
function U32([byte[]]$b,[long]$p,[long]$end) { Range $b $p 4 $end; return [BitConverter]::ToUInt32($b,[int]$p) }
function Str([byte[]]$b,[long]$p,[long]$end) {
    Range $b $p 1 $end; $start=$p
    while ($p -lt $end -and $b[$p] -ne 0) { $p++ }
    if ($p -eq $end) { throw 'unterminated string' }
    return $utf8.GetString($b,[int]$start,[int]($p-$start))
}
function Uleb([byte[]]$b,[ref]$position,[long]$end) {
    [uint64]$value=0; $shift=0
    for ($i=0;$i -lt 5;$i++) {
        Range $b $position.Value 1 $end
        $part=$b[$position.Value]; $position.Value++
        $value=$value -bor ([uint64]($part -band 127) -shl $shift)
        if (($part -band 128) -eq 0) { if ($value -gt [uint32]::MaxValue) { throw 'ULEB overflow' }; return [uint32]$value }
        $shift+=7
    }
    throw 'ULEB too long'
}
function Inspect([byte[]]$b) {
    $end=[long]$b.Length
    if ((U16 $b 0 $end) -ne 0x5a4d) { throw 'not MZ' }
    $pe=[long](U32 $b 60 $end)
    if ((U32 $b $pe $end) -ne 0x4550) { throw 'not PE' }
    $count=[long](U16 $b ($pe+6) $end); $symbols=[long](U32 $b ($pe+12) $end); $symbolCount=[long](U32 $b ($pe+16) $end)
    $optional=[long](U16 $b ($pe+20) $end); $table=$pe+24+$optional
    if ($count -eq 0 -or $count -gt 96) { throw 'section count' }
    Range $b $table (40*$count) $end
    $strings=$symbols+18*$symbolCount
    $stringLength=[long](U32 $b $strings $end)
    if ($stringLength -lt 4) { throw 'COFF string size' }
    Range $b $strings $stringLength $end
    $sections=@{}; $sectionFields=@{}
    for ($i=0;$i -lt $count;$i++) {
        $field=$table+40*$i; Range $b $field 8 $end
        $rawName=[Text.Encoding]::ASCII.GetString($b,[int]$field,8).TrimEnd([char]0)
        if ($rawName.StartsWith('/')) {
            if ($rawName -notmatch '^/(\d+)$') { throw 'bad long section name' }
            $offset=[long]::Parse($Matches[1]); if ($offset -lt 4 -or $offset -ge $stringLength) { throw 'long name outside string table' }
            $name=Str $b ($strings+$offset) ($strings+$stringLength)
        } else { $name=$rawName }
        $size=[long](U32 $b ($field+8) $end); $rawSize=[long](U32 $b ($field+16) $end); $raw=[long](U32 $b ($field+20) $end)
        if ($size -gt $rawSize) { if ($name -like '.debug_*') { throw 'debug virtual size exceeds raw' } }
        if ($name -like '.debug_*') {
            Range $b $raw $size $end
            if ($sections.ContainsKey($name)) { throw 'duplicate debug section' }
            $sections[$name]=@{start=$raw;end=$raw+$size}; $sectionFields[$name]=$field
        }
    }
    foreach ($name in @('.debug_info','.debug_abbrev','.debug_str','.debug_line')) { if (-not $sections.ContainsKey($name)) { throw "missing $name" } }
    $info=$sections['.debug_info']; $abbrev=$sections['.debug_abbrev']; $str=$sections['.debug_str']; $line=$sections['.debug_line']
    $position=[long]$info.start; $matching=0; $unknown=0; $program=$null; $units=0; $versions=@()
    while ($position -lt $info.end) {
        $unitStart=$position; $length=[long](U32 $b $position $info.end); $position+=4
        if ($length -eq 0 -or $length -eq [uint32]::MaxValue) { throw 'unsupported or empty unit' }
        Range $b $position $length $info.end; $unitEnd=$position+$length
        $version=[int](U16 $b $position $unitEnd); $units++; $versions+= $version
        if ($version -ne 4) { $unknown++; $position=$unitEnd; continue }
        $position+=2; $abbrevOffset=[long](U32 $b $position $unitEnd); $position+=4
        Range $b $position 1 $unitEnd; if ($b[$position] -ne 8) { throw 'unexpected address size' }; $position++
        $code=Uleb $b ([ref]$position) $unitEnd
        if ($code -eq 0 -or $abbrevOffset -ge ($abbrev.end-$abbrev.start)) { throw 'bad abbreviation reference' }
        $ap=[long]($abbrev.start+$abbrevOffset); $fields=$null
        while ($ap -lt $abbrev.end) {
            $candidate=Uleb $b ([ref]$ap) $abbrev.end
            if ($candidate -eq 0) { break }
            $tag=Uleb $b ([ref]$ap) $abbrev.end; Range $b $ap 1 $abbrev.end; $ap++
            $items=@()
            while ($true) {
                $attribute=Uleb $b ([ref]$ap) $abbrev.end; $form=Uleb $b ([ref]$ap) $abbrev.end
                if ($attribute -eq 0 -and $form -eq 0) { break }
                if ($attribute -eq 0 -or $form -eq 0) { throw 'bad abbreviation pair' }
                $items+=,@($attribute,$form)
            }
            if ($candidate -eq $code) { if ($tag -ne 0x11) { throw 'root is not compile unit' }; $fields=$items; break }
        }
        if ($null -eq $fields) { throw 'missing root abbreviation' }
        $values=@{}; $locations=@{}
        foreach ($item in $fields) {
            $attribute=[int]$item[0]; $form=[int]$item[1]; $locations[$attribute]=$position
            switch ($form) {
                1 { Range $b $position 8 $unitEnd; $values[$attribute]=[BitConverter]::ToUInt64($b,[int]$position); $position+=8 }
                5 { $values[$attribute]=U16 $b $position $unitEnd; $position+=2 }
                6 { $values[$attribute]=U32 $b $position $unitEnd; $position+=4 }
                14 { $offset=[long](U32 $b $position $unitEnd); $position+=4; if ($offset -ge ($str.end-$str.start)) { throw 'string offset outside debug_str' }; $values[$attribute]=Str $b ($str.start+$offset) $str.end }
                23 { $values[$attribute]=U32 $b $position $unitEnd; $position+=4 }
                default { throw "unsupported root form $form" }
            }
        }
        foreach ($key in @(3,16,19,27,37)) { if (-not $values.ContainsKey($key)) { throw "required root attribute missing: $key" } }
        $lineOffset=[long]$values[16]; if ($lineOffset -ge ($line.end-$line.start)) { throw 'stmt_list outside debug_line' }
        if ($values[3] -ceq $ExpectedSource -and $values[37] -ceq $ExpectedProducer -and $values[27] -ceq $ExpectedDirectory -and $values[19] -eq 29) {
            $matching++; $program=@{unit=$unitStart;length=$length;nameField=$locations[3];nameString=$str.start+[long](U32 $b $locations[3] $unitEnd);producerString=$str.start+[long](U32 $b $locations[37] $unitEnd);stmtField=$locations[16];abbrevField=$unitStart+6;versionField=$unitStart+4}
        }
        $position=$unitEnd
    }
    return @{matching=$matching;unknown=$unknown;units=$units;versions=$versions;program=$program;sections=$sections;sectionFields=$sectionFields}
}
function Set32([byte[]]$bytes,[long]$offset,[uint32]$value) { [BitConverter]::GetBytes($value).CopyTo($bytes,[int]$offset) }
$fullBytes=[IO.File]::ReadAllBytes($fullPath); $noneBytes=[IO.File]::ReadAllBytes($nonePath)
$good=Inspect $fullBytes; $noneResult=Inspect $noneBytes
if ($good.matching -ne 1 -or @($good.versions | Where-Object { $_ -eq 5 }).Count -lt 1 -or $noneResult.matching -ne 0 -or @($noneResult.versions | Where-Object { $_ -eq 5 }).Count -lt 1) { throw 'Full/None identity or unrelated-unit control failed' }
$cases=@('long-name','identity','producer','version','unit-length','short-unit','string-offset','abbrev-offset','line-offset')
$controls=@()
foreach ($case in $cases) {
    $mutated=[byte[]]$fullBytes.Clone(); $program=$good.program
    switch ($case) {
        'long-name' { [Text.Encoding]::ASCII.GetBytes('/999999').CopyTo($mutated,[int]$good.sectionFields['.debug_info']) }
        'identity' { $mutated[$program.nameString]=$mutated[$program.nameString] -bxor 1 }
        'producer' { $mutated[$program.producerString]=$mutated[$program.producerString] -bxor 1 }
        'version' { [BitConverter]::GetBytes([uint16]3).CopyTo($mutated,[int]$program.versionField) }
        'unit-length' { Set32 $mutated $program.unit ([uint32]4294967280) }
        'short-unit' { Set32 $mutated $program.unit ([uint32]7) }
        'string-offset' { Set32 $mutated $program.nameField ([uint32]::MaxValue) }
        'abbrev-offset' { Set32 $mutated $program.abbrevField ([uint32]::MaxValue) }
        'line-offset' { Set32 $mutated $program.stmtField ([uint32]::MaxValue) }
    }
    $supportStart=$program.unit+4+$program.length
    for ($i=$supportStart;$i -lt $good.sections['.debug_info'].end;$i++) {
        if ($mutated[$i] -ne $fullBytes[$i]) { throw "Mutation changed support-unit bytes: $case" }
    }
    $path=Join-Path $root "$case.exe"; [IO.File]::WriteAllBytes($path,$mutated)
    $rejected=$false; $reason=''
    try { $observed=Inspect $mutated; $rejected=$observed.matching -ne 1 }
    catch { $rejected=$true; $reason=$_.Exception.Message }
    if ($reason -eq '' -and $observed.unknown -lt 1) { throw "Support-unit framing not observed: $case" }
    if (-not $rejected) { throw "Mutation not rejected: $case" }
    $controls += [pscustomobject]@{name=$case;path=$path;sha256=(Get-FileHash -LiteralPath $path).Hash;reason=$reason}
    Write-Output "$case : rejected"
}
$report=[pscustomobject]@{command=@('powershell','-NoProfile','-File',$PSCommandPath,'-Full',$fullPath,'-None',$nonePath,'-ExpectedSource',$ExpectedSource,'-ExpectedProducer',$ExpectedProducer,'-ExpectedDirectory',$ExpectedDirectory,'-OutputDirectory',[IO.Path]::GetFullPath($OutputDirectory));full=$fullPath;fullHash=(Get-FileHash -LiteralPath $fullPath).Hash;none=$nonePath;noneHash=(Get-FileHash -LiteralPath $nonePath).Hash;scriptHash=(Get-FileHash -LiteralPath $PSCommandPath).Hash;expectedSource=$ExpectedSource;expectedSourceHash=(Get-FileHash -LiteralPath $ExpectedSource).Hash;expectedProducer=$ExpectedProducer;expectedDirectory=$ExpectedDirectory;fullUnits=$good.units;fullVersions=$good.versions;fullOtherVersionUnits=$good.unknown;noneUnits=$noneResult.units;noneVersions=$noneResult.versions;noneOtherVersionUnits=$noneResult.unknown;controls=$controls;limits='DWARF4 root forms only; other versions framed and skipped; no line program, code or full semantic validation'}
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $root 'report.json') -Encoding UTF8
Write-Output "Full matched; None had no matching DWARF4 unit; unsupported versions skipped. Evidence: $root"
