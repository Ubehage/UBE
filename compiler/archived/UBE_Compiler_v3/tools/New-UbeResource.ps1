[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OutputPath,

    [Parameter(Mandatory)]
    [string[]]$Entry,

    [ValidateSet('Resource', 'LibraryBundle')]
    [string]$ContainerKind = 'Resource'
)

$ErrorActionPreference = 'Stop'
$maximumContainerBytes = 64MB
$maximumEntries = 1024

function Get-Sha256TextBytes([byte[]]$Payload) {
    $provider = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = $provider.ComputeHash($Payload)
    }
    finally {
        $provider.Dispose()
    }
    return ,([Text.Encoding]::ASCII.GetBytes(([BitConverter]::ToString($digest).Replace('-', ''))))
}

if ($Entry.Count -eq 0 -or $Entry.Count -gt $maximumEntries) {
    throw "A UBE-Resource 1 container requires 1 to $maximumEntries entries."
}

$records = foreach ($item in $Entry) {
    $separator = $item.IndexOf('=')
    if ($separator -le 0 -or $separator -eq $item.Length - 1) {
        throw "Resource entries use Name=Path: $item"
    }
    $name = $item.Substring(0, $separator)
    if ($name.Length -gt 255 -or $name -cnotmatch '^[A-Za-z0-9_.-]+$') {
        throw "Resource names are 1-255 portable ASCII name characters: $name"
    }
    $inputPath = [IO.Path]::GetFullPath($item.Substring($separator + 1))
    $payload = [IO.File]::ReadAllBytes($inputPath)
    [pscustomobject]@{
        Name = $name
        NameBytes = [Text.Encoding]::ASCII.GetBytes($name)
        Payload = $payload
        Hash = Get-Sha256TextBytes $payload
    }
}

$records = @($records | Sort-Object -Property Name -CaseSensitive)
for ($index = 1; $index -lt $records.Count; $index++) {
    if ([StringComparer]::Ordinal.Compare($records[$index - 1].Name, $records[$index].Name) -eq 0) {
        throw "Duplicate resource name: $($records[$index].Name)"
    }
}
if ($ContainerKind -eq 'LibraryBundle') {
    $actualNames = @($records | ForEach-Object Name)
    if ($actualNames.Count -ne 3 -or
        $actualNames[0] -cne 'Artifact' -or
        $actualNames[1] -cne 'Interface' -or
        $actualNames[2] -cne 'Manifest') {
        throw 'A library bundle contains exactly Artifact, Interface, and Manifest entries.'
    }
}

$directorySize = [uint64]0
$payloadSize = [uint64]0
foreach ($record in $records) {
    $directorySize += 84 + $record.NameBytes.Length
    $payloadSize += $record.Payload.Length
}
if (16 + $directorySize + $payloadSize -gt $maximumContainerBytes) {
    throw 'The UBE-Resource 1 container exceeds the 64 MiB limit.'
}

$absoluteOutput = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [IO.Path]::GetDirectoryName($absoluteOutput)
if (-not [IO.Directory]::Exists($outputDirectory)) {
    throw "The output directory does not exist: $outputDirectory"
}
$temporaryPath = "$absoluteOutput.ube-tmp-$PID-$([Guid]::NewGuid().ToString('N'))"

try {
    $stream = [IO.File]::Open($temporaryPath, [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $writer = [IO.BinaryWriter]::new($stream, [Text.Encoding]::ASCII, $true)
        try {
            $magic = if ($ContainerKind -eq 'LibraryBundle') { "UBEUBL1`n" } else { "UBEUBR1`n" }
            $writer.Write([Text.Encoding]::ASCII.GetBytes($magic))
            $writer.Write([uint32]$records.Count)
            $writer.Write([uint32]$directorySize)
            $payloadOffset = [uint64](16 + $directorySize)
            foreach ($record in $records) {
                $writer.Write([uint16]$record.NameBytes.Length)
                $writer.Write([uint16]0)
                $writer.Write($payloadOffset)
                $writer.Write([uint64]$record.Payload.Length)
                $writer.Write($record.Hash)
                $writer.Write($record.NameBytes)
                $payloadOffset += $record.Payload.Length
            }
            foreach ($record in $records) {
                $writer.Write($record.Payload)
            }
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
    Move-Item -LiteralPath $temporaryPath -Destination $absoluteOutput -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
}
