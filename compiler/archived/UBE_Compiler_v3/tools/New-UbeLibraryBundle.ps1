[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$OutputPath,
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$Version,
    [Parameter(Mandatory)] [string]$Target,
    [Parameter(Mandatory)] [ValidateSet('COFF', 'ELF')] [string]$ObjectFormat,
    [Parameter(Mandatory)] [string]$InterfacePath,
    [Parameter(Mandatory)] [string]$ArtifactPath
)

$ErrorActionPreference = 'Stop'
if ($Name -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
    throw 'Bundle Name must be a portable UBE identifier.'
}
if ($Version -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$') {
    throw 'Bundle Version must be a canonical semantic version.'
}

$absoluteOutput = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [IO.Path]::GetDirectoryName($absoluteOutput)
if (-not [IO.Directory]::Exists($outputDirectory)) {
    throw "The output directory does not exist: $outputDirectory"
}
$metadataPath = [IO.Path]::Combine($outputDirectory,
    ".ube-bundle-metadata-$PID-$([Guid]::NewGuid().ToString('N')).txt")

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

try {
    $metadata = @(
        'Format=UBE-LibraryBundle-Metadata-1'
        "Name=$Name"
        "Version=$Version"
        'Language=1.0'
        'IntrinsicABI=ube-intrinsic-abi-1'
        "Target=$Target"
        "ObjectFormat=$ObjectFormat"
        'PointerBits=64'
        "InterfaceSHA256=$(Get-Sha256 $InterfacePath)"
        "ArtifactSHA256=$(Get-Sha256 $ArtifactPath)"
        ''
    ) -join "`n"
    [IO.File]::WriteAllText($metadataPath, $metadata, [Text.UTF8Encoding]::new($false))
    & (Join-Path $PSScriptRoot 'New-UbeResource.ps1') -OutputPath $absoluteOutput `
        -ContainerKind LibraryBundle -Entry @(
            "Artifact=$ArtifactPath",
            "Interface=$InterfacePath",
            "Manifest=$metadataPath"
        )
}
finally {
    if (Test-Path -LiteralPath $metadataPath) {
        Remove-Item -LiteralPath $metadataPath -Force
    }
}
