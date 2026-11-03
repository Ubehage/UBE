param([Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $Executable,
      [Parameter(Mandatory=$true)][string] $OutputDirectory, [string] $StructuralProbe)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$tool = (Resolve-Path -LiteralPath $Readobj).Path
if ($StructuralProbe) { $probePath=(Resolve-Path -LiteralPath $StructuralProbe).Path }
$bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Executable).Path)
function U16([byte[]] $b, [long] $p) {
    if ($p -lt 0 -or $p + 2 -gt $b.Length) { throw 'Outside file' }
    return [BitConverter]::ToUInt16($b, [int]$p)
}
function U32([byte[]] $b, [long] $p) {
    if ($p -lt 0 -or $p + 4 -gt $b.Length) { throw 'Outside file' }
    return [BitConverter]::ToUInt32($b, [int]$p)
}
function Structure([byte[]] $b) {
    try {
        if ((U16 $b 0) -ne 0x5a4d) { return $false }
        $pe = [long](U32 $b 0x3c)
        if ((U32 $b $pe) -ne 0x4550 -or (U16 $b ($pe+4)) -ne 0x8664) { return $false }
        $count = [long](U16 $b ($pe+6)); $optionalSize = [long](U16 $b ($pe+20))
        $flags = U16 $b ($pe+22); $opt = $pe+24
        if ($count -eq 0 -or $optionalSize -lt 112 -or ($flags -band 2) -eq 0 -or ($flags -band 0x2000) -ne 0 -or (U16 $b $opt) -ne 0x20b) { return $false }
        if ((U32 $b ($opt+108)) -gt [Math]::Floor(($optionalSize-112)/8)) { return $false }
        $entry = [long](U32 $b ($opt+16)); $imageSize = [long](U32 $b ($opt+56))
        $table = $opt+$optionalSize
        if ($entry -eq 0 -or $entry -ge $imageSize -or $table + 40*$count -gt $b.Length) { return $false }
        $entryBacked = $false
        for ($i=0; $i -lt $count; $i++) {
            $section = $table + 40*$i
            $virtual = [long](U32 $b ($section+12)); $rawSize = [long](U32 $b ($section+16))
            $raw = [long](U32 $b ($section+20)); $characteristics = U32 $b ($section+36)
            if ($rawSize -gt 0 -and ($raw -gt $b.Length -or $rawSize -gt $b.Length-$raw)) { return $false }
            if (($characteristics -band 0x20000000) -ne 0 -and $entry -ge $virtual -and $entry-$virtual -lt $rawSize) { $entryBacked = $true }
        }
        return $entryBacked
    } catch { return $false }
}
function Set-U32([byte[]] $b, [long] $offset, [uint32] $value) {
    [BitConverter]::GetBytes($value).CopyTo($b, [int]$offset)
}
function Run-Readobj([string] $path) {
    $p = [Diagnostics.Process]::new()
    $p.StartInfo.FileName = $tool; $p.StartInfo.Arguments = '--file-headers --sections "' + $path + '"'
    $p.StartInfo.UseShellExecute = $false; $p.StartInfo.CreateNoWindow = $true
    $p.StartInfo.RedirectStandardOutput = $true; $p.StartInfo.RedirectStandardError = $true
    if (-not $p.Start()) { throw 'Cannot start readobj' }
    try {
        $out = $p.StandardOutput.ReadToEndAsync(); $err = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit(10000)) { $p.Kill(); $p.WaitForExit(); throw 'readobj timed out' }
        return @{ status = $p.ExitCode; stdout = $out.Result; stderr = $err.Result }
    } finally { $p.Dispose() }
}
$pe = [long](U32 $bytes 0x3c); $opt = $pe+24; $table = $opt + (U16 $bytes ($pe+20))
if (-not (Structure $bytes)) { throw 'Fixture failed independent structural checks' }
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
foreach ($case in @('original', 'zero-code', 'wrong-machine', 'dll', 'zero-entry', 'outside-entry', 'outside-section', 'oversized-section', 'short-dos', 'offset-outside', 'section-count-overflow', 'optional-short', 'directory-count-overflow')) {
    $b = [byte[]]$bytes.Clone()
    if ($case -eq 'wrong-machine') { [BitConverter]::GetBytes([uint16]0x14c).CopyTo($b,[int]($pe+4)) }
    if ($case -eq 'dll') { [BitConverter]::GetBytes([uint16]((U16 $b ($pe+22)) -bor 0x2000)).CopyTo($b,[int]($pe+22)) }
    if ($case -eq 'zero-entry') { Set-U32 $b ($opt+16) 0 }
    if ($case -eq 'outside-entry') { Set-U32 $b ($opt+16) ([uint32](U32 $b ($opt+56))) }
    if ($case -eq 'outside-section') { Set-U32 $b ($table+20) ([uint32]($b.Length+4096)) }
    if ($case -eq 'oversized-section') { Set-U32 $b ($table+16) ([uint32]::MaxValue) }
    if ($case -eq 'short-dos') { $b = [byte[]]$b[0..63] }
    if ($case -eq 'offset-outside') { Set-U32 $b 0x3c ([uint32]::MaxValue) }
    if ($case -eq 'section-count-overflow') { [BitConverter]::GetBytes([uint16]::MaxValue).CopyTo($b,[int]($pe+6)) }
    if ($case -eq 'optional-short') { [BitConverter]::GetBytes([uint16]16).CopyTo($b,[int]($pe+20)) }
    if ($case -eq 'directory-count-overflow') { Set-U32 $b ($opt+108) ([uint32]([Math]::Floor(((U16 $b ($pe+20))-112)/8)+1)) }
    if ($case -eq 'zero-code') {
        $entry = [long](U32 $b ($opt+16)); $found = $false
        for ($i=0; $i -lt (U16 $b ($pe+6)); $i++) {
            $section = $table + 40*$i; $virtual = [long](U32 $b ($section+12))
            $size = [long](U32 $b ($section+16)); $raw = [long](U32 $b ($section+20))
            if (((U32 $b ($section+36)) -band 0x20000000) -ne 0 -and $entry -ge $virtual -and $entry-$virtual -lt $size) {
                [Array]::Clear($b, [int]$raw, [int]$size); $found = $true; break
            }
        }
        if (-not $found) { throw 'No entry section to corrupt' }
    }
    $accepted = Structure $b
    if (($case -in @('original', 'zero-code')) -ne $accepted) { throw "Unexpected structural comparison for $case" }
    $path = Join-Path $directory ($case + '.exe'); [IO.File]::WriteAllBytes($path, $b)
    if ($StructuralProbe) {
        $process=[Diagnostics.Process]::new(); $process.StartInfo.FileName=$probePath; $process.StartInfo.Arguments='"' + $path + '"'
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true; $process.StartInfo.RedirectStandardOutput=$true; $process.StartInfo.RedirectStandardError=$true
        if (-not $process.Start()) { throw 'Structural probe did not start' }
        try {
            if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Structural probe timed out' }
            $probeOutput=$process.StandardOutput.ReadToEnd().Trim(); $probeError=$process.StandardError.ReadToEnd().Trim()
            $expectedStatus=if ($accepted) { 0 } else { 1 }; $expectedOutput=if ($accepted) { 'structure accepted' } else { 'structure rejected' }
            if ($process.ExitCode -ne $expectedStatus -or $probeOutput -ne $expectedOutput) { throw "Structural probe differed for $case : $probeOutput $probeError" }
        } finally { $process.Dispose() }
    }
    $result = Run-Readobj $path
    $markers = $result.status -eq 0 -and $result.stdout -match 'Machine: IMAGE_FILE_MACHINE_AMD64' -and
        $result.stdout -match 'IMAGE_FILE_EXECUTABLE_IMAGE' -and $result.stdout -match 'ImageOptionalHeader \{' -and
        $result.stdout -match 'Magic: 0x20B' -and $result.stdout -notmatch '(?m)^\s*IMAGE_FILE_DLL \('
    if ($case -in @('original', 'zero-code', 'zero-entry', 'outside-entry', 'outside-section', 'oversized-section') -and
        ($result.status -ne 0 -or $result.stdout -notmatch 'Machine: IMAGE_FILE_MACHINE_AMD64' -or
        $result.stdout -notmatch 'IMAGE_FILE_EXECUTABLE_IMAGE' -or $result.stdout -notmatch 'ImageOptionalHeader \{' -or
        $result.stdout -notmatch 'Magic: 0x20B' -or $result.stdout -match '(?m)^\s*IMAGE_FILE_DLL \(')) { throw "readobj marker comparison differed for $case" }
    Write-Output "$case : structural=$accepted readobj-exit=$($result.status) header-markers=$markers"
}
Write-Output "Fixtures: $directory"
