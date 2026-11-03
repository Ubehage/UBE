param(
    [Parameter(Mandatory=$true)][string] $Readobj,
    [Parameter(Mandatory=$true)][string] $Executable,
    [Parameter(Mandatory=$true)][string] $OutputDirectory
)
$ErrorActionPreference = 'Stop'
$tool = (Resolve-Path -LiteralPath $Readobj).Path
$bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Executable).Path)
if ($bytes.Length -le 1024) { throw 'Fixture is too short to truncate' }
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$truncated = Join-Path $directory 'truncated.exe'
[IO.File]::WriteAllBytes($truncated, [byte[]]$bytes[0..1023])
$ErrorActionPreference = 'Continue'
$lines = @(& $tool --file-headers $truncated 2>&1 | ForEach-Object { "$_" })
$status = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
$headers = $lines -join "`n"
if ($status -eq 0) {
    if ($headers -notmatch 'IMAGE_FILE_EXECUTABLE_IMAGE' -or $headers -notmatch 'Magic: 0x20B') { throw 'Unexpected successful output' }
    Write-Output 'Header inspection accepted a 1024-byte truncation and reported executable-image and PE32+ fields.'
} else {
    Write-Output "Header inspection rejected a 1024-byte truncation with exit $status : $headers"
}
$sections = @(& $tool --sections (Resolve-Path -LiteralPath $Executable).Path 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0 -or $sections -notmatch '(?s)Name: \.text.*?RawDataSize: 12800\s+PointerToRawData: 0x400') { throw 'Fixture code-section layout changed' }
$hadCode = $false
foreach ($byte in $bytes[1024..13823]) { if ($byte -ne 0) { $hadCode = $true; break } }
if (-not $hadCode) { throw 'Code-section control already contains only zero bytes' }
[Array]::Clear($bytes, 1024, 12800)
$damaged = Join-Path $directory 'zero-code.exe'
[IO.File]::WriteAllBytes($damaged, $bytes)
$lines = @(& $tool --file-headers $damaged 2>&1)
if ($LASTEXITCODE -ne 0 -or ($lines -join "`n") -notmatch 'IMAGE_FILE_EXECUTABLE_IMAGE') { throw 'Damaged-code observation unexpectedly failed' }
Write-Output 'Header inspection accepted the same-length image after its complete code section was zeroed.'
