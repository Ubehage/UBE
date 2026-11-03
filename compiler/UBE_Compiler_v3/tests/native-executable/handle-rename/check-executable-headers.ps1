param(
    [Parameter(Mandatory=$true)][string] $Readobj,
    [Parameter(Mandatory=$true)][string] $Executable,
    [Parameter(Mandatory=$true)][string] $ObjectFile,
    [Parameter(Mandatory=$true)][string] $Dll
)
$ErrorActionPreference = 'Stop'
$tool = (Resolve-Path -LiteralPath $Readobj).Path
function Read-Headers([string] $path) {
    $resolved = (Resolve-Path -LiteralPath $path).Path
    $lines = @(& $tool --file-headers $resolved 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Header tool failed for $resolved : $lines" }
    return ($lines -join "`n")
}
function Is-ObservedExe([string] $headers) {
    return ($headers -match 'Machine: IMAGE_FILE_MACHINE_AMD64' -and
        $headers -match 'IMAGE_FILE_EXECUTABLE_IMAGE' -and
        $headers -match 'ImageOptionalHeader \{' -and
        $headers -match 'Magic: 0x20B' -and
        $headers -notmatch '(?m)^\s*IMAGE_FILE_DLL \(')
}
$exeHeaders = Read-Headers $Executable
$objectHeaders = Read-Headers $ObjectFile
$dllHeaders = Read-Headers $Dll
if (-not (Is-ObservedExe $exeHeaders)) { throw 'Executable control did not match' }
if (Is-ObservedExe $objectHeaders) { throw 'Object control incorrectly matched' }
if (Is-ObservedExe $dllHeaders) { throw 'DLL control incorrectly matched' }
if ($objectHeaders -notmatch 'Machine: IMAGE_FILE_MACHINE_AMD64' -or
    $dllHeaders -notmatch 'IMAGE_FILE_EXECUTABLE_IMAGE' -or
    $dllHeaders -notmatch '(?m)^\s*IMAGE_FILE_DLL \(') { throw 'Negative controls did not exercise expected ambiguity' }
Write-Output 'Header comparator distinguished this executable from the object and DLL controls.'
