param(
    [Parameter(Mandatory=$true)][string] $Probe,
    [Parameter(Mandatory=$true)][string] $Library,
    [Parameter(Mandatory=$true)][string] $OutputDirectory
)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$libraryPath = (Resolve-Path -LiteralPath $Library).Path
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$label = 'unicode-' + [char]0x00E6 + [char]0x00F8 + [char]0x00E5 + [char]::ConvertFromUtf32(0x10400) + '-' + [Guid]::NewGuid().ToString('N')
$directory = Join-Path $outputRoot $label
[IO.Directory]::CreateDirectory($directory) | Out-Null
foreach ($case in @(@('valid.ll', 0, 'valid module'), @('invalid-dominance.ll', 1, 'invalid module'))) {
    $path = Join-Path $directory $case[0]
    [IO.File]::Copy((Join-Path $PSScriptRoot $case[0]), $path)
    $output = @(& $probePath $libraryPath $path 2>&1)
    if ($LASTEXITCODE -ne $case[1] -or $output.Count -ne 1 -or $output[0] -ne $case[2]) {
        throw "Unicode input failed for $($case[0]): exit $LASTEXITCODE, output $output"
    }
}
Write-Output "Passed verifier API Unicode-path valid and invalid controls: $directory"
