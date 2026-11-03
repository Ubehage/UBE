param([Parameter(Mandatory=$true)][string] $SourceReport,
      [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$sourceReport = (Resolve-Path -LiteralPath $SourceReport).Path
$source = Get-Content -LiteralPath $sourceReport -Raw | ConvertFrom-Json
$readobj = (Resolve-Path -LiteralPath $Readobj).Path
$auditRoot = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($auditRoot)
$expectedCounts=@{'crt2.o'=1;'crtbegin.o'=1;'libmingw32.a'=31;'libgcc.a'=285;'libgcc_eh.a'=4;'libmoldname.a'=1;'libmingwex.a'=316;'libmsvcrt.a'=2658;'libadvapi32.a'=881;'libshell32.a'=389;'libuser32.a'=983;'libkernel32.a'=1759;'crtend.o'=1}
$inputs = @($source.inputs | Where-Object { $expectedCounts.ContainsKey([IO.Path]::GetFileName($_.path)) })
if ($inputs.Count -ne 13) { throw 'Expected thirteen support inputs' }
if (@($inputs | ForEach-Object { [IO.Path]::GetFileName($_.path) } | Select-Object -Unique).Count -ne 13) { throw 'Duplicate support basename' }
$rows = @()
foreach ($inputFile in $inputs) {
    $path = $inputFile.path
    $name = [IO.Path]::GetFileName($path)
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($hash -cne $inputFile.sha256) { throw "Input identity mismatch: $path" }
    $bytes = [IO.File]::ReadAllBytes($path)
    $members = @()
    $metadata = 0
    $archive = [Text.Encoding]::ASCII.GetString($bytes,0,[Math]::Min(8,$bytes.Length))
    if ($archive -eq "!<thin>`n") { throw "Thin archive: $path" }
    if ($archive -eq "!<arch>`n") {
        $offset = 8L
        while ($offset -lt $bytes.LongLength) {
            if ($bytes.LongLength-$offset -lt 60) { throw 'Truncated archive header' }
            $memberName = [Text.Encoding]::ASCII.GetString($bytes,[int]$offset,16).Trim()
            $sizeText = [Text.Encoding]::ASCII.GetString($bytes,[int]$offset+48,10).Trim()
            $size = 0L
            if (-not [long]::TryParse($sizeText,[ref]$size) -or $size -lt 0) { throw 'Invalid archive member length' }
            if ($bytes[$offset+58] -ne 96 -or $bytes[$offset+59] -ne 10) { throw 'Invalid archive header terminator' }
            $start = $offset+60
            if ($size -gt $bytes.LongLength-$start) { throw 'Archive member outside file' }
            if ($memberName -in @('/','//','/SYM64/')) { $metadata++ }
            else { $members += @{name=$memberName;start=$start;size=$size} }
            $offset = $start+$size+($size%2)
        }
        if ($offset -ne $bytes.LongLength) { throw 'Archive alignment past file end' }
    } else { $members = @(@{name=$name;start=0L;size=$bytes.LongLength}) }
    $formats = @{}
    $rawDirectives = @()
    $sections = 0
    foreach ($member in $members) {
        $start = [int]$member.start
        if ($member.size -lt 20) { throw 'Member too short for COFF or import header' }
        $machine = [BitConverter]::ToUInt16($bytes,$start)
        if ($machine -eq 0x8664) { $kind='AMD64-COFF' }
        elseif ($machine -eq 0 -and [BitConverter]::ToUInt16($bytes,$start+2) -eq 0xffff -and [BitConverter]::ToUInt16($bytes,$start+6) -eq 0x8664) {
            $version = [BitConverter]::ToUInt16($bytes,$start+4)
            if ($version -eq 0) { $kind='AMD64-short-import' }
            elseif ($version -eq 2 -and $member.size -ge 56) { $kind='AMD64-bigobj' }
            else { throw "Unclassified anonymous COFF version $version" }
        } else { throw "Non-AMD64/unknown member in ${name}: $($member.name)" }
        if (-not $formats.ContainsKey($kind)) { $formats[$kind]=0 }
        $formats[$kind]++
        if ($kind -ne 'AMD64-COFF') { throw 'Section cross-check requires ordinary COFF for this fixed cohort' }
        $sectionCount = [BitConverter]::ToUInt16($bytes,$start+2)
        $optionalSize = [BitConverter]::ToUInt16($bytes,$start+16)
        $table = 20L+$optionalSize
        if ($table+40L*$sectionCount -gt $member.size) { throw 'Section table exceeds member' }
        $symbolOffset = [BitConverter]::ToUInt32($bytes,$start+8)
        $symbolCount = [BitConverter]::ToUInt32($bytes,$start+12)
        for ($section=0;$section -lt $sectionCount;$section++) {
            $header = [int]($start+$table+40L*$section)
            $sectionName = [Text.Encoding]::ASCII.GetString($bytes,$header,8).TrimEnd([char]0)
            if ($sectionName.StartsWith('/')) {
                $stringOffset=0L
                if (-not [long]::TryParse($sectionName.Substring(1),[ref]$stringOffset)) { throw 'Invalid long section name' }
                $strings = [long]$symbolOffset+18L*$symbolCount
                if ($strings+4 -gt $member.size) { throw 'COFF string table missing' }
                $stringLength = [BitConverter]::ToUInt32($bytes,[int]($start+$strings))
                if ($stringOffset -lt 4 -or $strings+$stringLength -gt $member.size -or $stringOffset -ge $stringLength) { throw 'COFF string name outside member' }
                $nameStart = [int]($start+$strings+$stringOffset)
                $nameEnd = $nameStart
                while ($nameEnd -lt $start+$strings+$stringLength -and $bytes[$nameEnd] -ne 0) { $nameEnd++ }
                if ($nameEnd -eq $start+$strings+$stringLength) { throw 'Unterminated section name' }
                $sectionName=[Text.Encoding]::ASCII.GetString($bytes,$nameStart,$nameEnd-$nameStart)
            }
            if ($sectionName -in @('.llvmbc','.llvm.lto') -or $sectionName.StartsWith('.gnu.lto')) { throw "Embedded LTO section: $name $sectionName" }
            $sections++
            if ($sectionName -eq '.drectve') {
                $rawSize=[BitConverter]::ToUInt32($bytes,$header+16)
                $rawOffset=[BitConverter]::ToUInt32($bytes,$header+20)
                if ([long]$rawOffset+$rawSize -gt $member.size) { throw 'Directive bytes outside member' }
                $raw=[Text.Encoding]::ASCII.GetString($bytes,[int]($start+$rawOffset),[int]$rawSize)
                if ($raw -notmatch '^\s*(?:-aligncomm:"[^"]+",[0-9]+\s*)+\x00*$') { throw "Unexpected raw directive contents in $name" }
                $rawDirectives+=@{archiveMember=$member.name;bytes=$rawSize;text=$raw}
            }
        }
    }
    $outPath = Join-Path $auditRoot ($name+'.readobj.txt')
    $errPath = Join-Path $auditRoot ($name+'.stderr.txt')
    & $readobj --file-headers --coff-directives $path 1> $outPath 2> $errPath
    $status = $LASTEXITCODE
    $output = Get-Content -LiteralPath $outPath -Raw
    $stderr = Get-Content -LiteralPath $errPath -Raw
    if ($status -ne 0 -or $stderr) { throw "Readobj failure for ${name}: $stderr" }
    $parsed = [regex]::Matches($output,'(?m)^File: ').Count
    $formatLines = @([regex]::Matches($output,'(?m)^Format: (.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
    if ($parsed -ne $members.Count -or $formatLines.Count -ne $members.Count) { throw "Parsed member count differs: $name" }
    if ($parsed -ne $expectedCounts[$name]) { throw "Member count differs from recorded cohort: $name" }
    if (@($formatLines | Where-Object { $_ -notin @('COFF-x86-64','COFF-import-file') }).Count) { throw "Unexpected readobj format in $name" }
    $directives = @([regex]::Matches($output,'(?m)^Directive\(s\): (.*)$') | ForEach-Object { $_.Groups[1].Value.Trim() })
    if ($rawDirectives.Count -ne $directives.Count) { throw 'Raw and reported directive section counts differ' }
    for ($i=0;$i -lt $directives.Count;$i++) { if ($rawDirectives[$i].text.Trim() -cne $directives[$i]) { throw 'Raw and reported directive contents differ' } }
    $rows += [pscustomobject]@{path=$path;sha256=$hash;bytes=$bytes.Length;archive=($archive -eq "!<arch>`n");archiveMetadataMembers=$metadata;members=$members.Count;memberFormats=$formats;sections=$sections;embeddedLtoSections=0;rawDirectives=$rawDirectives;readobjParsedMembers=$parsed;readobjFormats=@($formatLines | Group-Object | ForEach-Object { @{format=$_.Name;count=$_.Count} });directives=$directives;exit=$status;stdout=$outPath;stdoutSha256=(Get-FileHash -LiteralPath $outPath -Algorithm SHA256).Hash;stderr=$errPath}
    Write-Output "$name members=$($members.Count) directives=$($directives.Count)"
}
$report = @{sourceReport=$sourceReport;sourceReportSha256=(Get-FileHash -LiteralPath $sourceReport -Algorithm SHA256).Hash;readobj=$readobj;readobjSha256=(Get-FileHash -LiteralPath $readobj -Algorithm SHA256).Hash;script=$PSCommandPath;scriptSha256=(Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash;arguments=@('--file-headers','--coff-directives');inputs=$rows}
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $auditRoot 'report.json') -Encoding UTF8
Write-Output "Report: $auditRoot\report.json"
