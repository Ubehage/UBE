param(
    [Parameter(Mandatory=$true)][string] $Probe,
    [Parameter(Mandatory=$true)][string] $UncheckedProbe,
    [Parameter(Mandatory=$true)][string] $WrongCertificateProbe,
    [Parameter(Mandatory=$true)][string] $Executable,
    [Parameter(Mandatory=$true)][string] $OutputDirectory
)
$ErrorActionPreference = 'Stop'
$checked = (Resolve-Path -LiteralPath $Probe).Path
$unchecked = (Resolve-Path -LiteralPath $UncheckedProbe).Path
$wrongCertificate = (Resolve-Path -LiteralPath $WrongCertificateProbe).Path
$original = (Resolve-Path -LiteralPath $Executable).Path
$bytes = [IO.File]::ReadAllBytes($original)
$pe = [BitConverter]::ToUInt32($bytes, 0x3c)
$optional = [int]$pe + 24
$optionalSize = [BitConverter]::ToUInt16($bytes, [int]$pe + 20)
$count = [BitConverter]::ToUInt32($bytes, $optional + 108)
$imageSize = [BitConverter]::ToUInt32($bytes, $optional + 56)
if ($count -lt 5 -or $optionalSize -lt 152 -or $imageSize -ge [uint32]::MaxValue -or $bytes.Length -ge [uint32]::MaxValue) {
    throw 'Fixture lacks the required directory entries or representable bounds'
}
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$offset = [long]([Math]::Ceiling([Math]::Max([double]$imageSize, [double]$bytes.Length) / 8.0) * 8)
if ($offset + 8 -gt 67108864) { throw 'Fixture requires too much test padding' }
$withCertificate = [byte[]]::new([int]($offset + 8))
[Array]::Copy($bytes, $withCertificate, $bytes.Length)
$certificateEntry = $optional + 112 + 8 * 4
[BitConverter]::GetBytes([uint32]$offset).CopyTo($withCertificate, $certificateEntry)
[BitConverter]::GetBytes([uint32]8).CopyTo($withCertificate, $certificateEntry + 4)
$certificatePath = Join-Path $directory 'certificate-in-file.exe'
[IO.File]::WriteAllBytes($certificatePath, $withCertificate)
& $checked $certificatePath
if ($LASTEXITCODE -ne 0) { throw 'File-offset check rejected in-file certificate range' }
& $wrongCertificate $certificatePath
if ($LASTEXITCODE -ne 1) { throw 'Wrong RVA interpretation accepted certificate control' }
Write-Output 'Certificate range: file-offset interpretation accepted and wrong RVA interpretation rejected the bounded control.'
foreach ($probePath in @($checked, $unchecked)) {
    & $probePath $original
    if ($LASTEXITCODE -ne 0) { throw 'Probe rejected original fixture' }
}
foreach ($case in @(@{ Name='import'; Index=1; Address=[uint32]$imageSize; Limit=[uint64]$imageSize },
                     @{ Name='certificate'; Index=4; Address=[uint32]$bytes.Length; Limit=[uint64]$bytes.Length })) {
    $mutated = [byte[]]$bytes.Clone()
    $offset = $optional + 112 + 8 * $case.Index
    [BitConverter]::GetBytes($case.Address).CopyTo($mutated, $offset)
    [BitConverter]::GetBytes([uint32]1).CopyTo($mutated, $offset + 4)
    $address = [BitConverter]::ToUInt32($mutated, $offset)
    $length = [BitConverter]::ToUInt32($mutated, $offset + 4)
    if ([uint64]$address + [uint64]$length -le $case.Limit) { throw 'Mutation did not cross the intended bound' }
    $path = Join-Path $directory ($case.Name + '.exe')
    [IO.File]::WriteAllBytes($path, $mutated)
    & $unchecked $path
    if ($LASTEXITCODE -ne 0) { throw "Unchecked probe rejected $($case.Name) control" }
    & $checked $path
    if ($LASTEXITCODE -ne 1) { throw "Probe accepted out-of-range $($case.Name) directory" }
    Write-Output "$($case.Name): unchecked probe accepted and range check rejected the independently bounded mutation."
}

# Find a range outside every declared section and outside the headers. This
# observes what the experiment accepts; it is not a complete loader model.
$sectionCount = [BitConverter]::ToUInt16($bytes, [int]$pe + 6)
$table = $optional + $optionalSize
$ranges = @()
for ($i = 0; $i -lt $sectionCount; $i++) {
    $section = $table + 40 * $i
    $start = [uint64][BitConverter]::ToUInt32($bytes, $section + 12)
    $virtualSize = [uint64][BitConverter]::ToUInt32($bytes, $section + 8)
    $rawSize = [uint64][BitConverter]::ToUInt32($bytes, $section + 16)
    $ranges += @{ Start=$start; End=$start + [Math]::Max($virtualSize, $rawSize) }
}
$gap = [uint64][BitConverter]::ToUInt32($bytes, $optional + 60)
foreach ($range in ($ranges | Sort-Object Start)) {
    if ($gap + 20 -le $range.Start) { break }
    if ($range.End -gt $gap) { $gap = $range.End }
}
if ($gap + 20 -gt $imageSize) { throw 'Fixture has no suitable in-image section gap' }
foreach ($range in $ranges) {
    if ($gap -lt $range.End -and $gap + 20 -gt $range.Start) { throw 'Chosen gap overlaps a section' }
}
$gapBytes = [byte[]]$bytes.Clone()
$importEntry = $optional + 112 + 8
[BitConverter]::GetBytes([uint32]$gap).CopyTo($gapBytes, $importEntry)
[BitConverter]::GetBytes([uint32]20).CopyTo($gapBytes, $importEntry + 4)
$gapPath = Join-Path $directory 'import-in-gap.exe'
[IO.File]::WriteAllBytes($gapPath, $gapBytes)
& $checked $gapPath
if ($LASTEXITCODE -ne 0) { throw 'Gap control was rejected; update the observed limitation' }
Write-Output "Adverse control: range-only probe accepted import directory in section gap at RVA $gap."
