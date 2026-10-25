param(
    [string]$CompilerPath,
    [string]$ClangPath,
    [string]$RuntimeObject,
    [string]$UnicodeRuntimeObject
)

$ErrorActionPreference = 'Stop'

$sampleRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = (Resolve-Path (Join-Path $sampleRoot '../..')).Path
$projectPath = Join-Path $sampleRoot 'HelloUBE.UBE'

if (-not $CompilerPath) {
    $CompilerPath = Join-Path $repositoryRoot 'compiler/release-previews/ube-v3-rp8-windows-x86_64-x86_64-w64-windows-gnu.exe'
}
if (-not $ClangPath) {
    $clangCommand = Get-Command clang -ErrorAction SilentlyContinue
    $ClangPath = if ($clangCommand) { $clangCommand.Source } else { 'C:\Program Files\LLVM\bin\clang.exe' }
}
if (-not $RuntimeObject) {
    $RuntimeObject = Join-Path $repositoryRoot 'bootstrap/out/bootstrap_runtime.o'
}
if (-not $UnicodeRuntimeObject) {
    $UnicodeRuntimeObject = Join-Path $repositoryRoot 'bootstrap/out/bootstrap_unicode_runtime.o'
}

$requiredFiles = @($CompilerPath, $ClangPath, $RuntimeObject, $UnicodeRuntimeObject, $projectPath)
foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required smoke-test input is unavailable: $requiredFile. Run bootstrap/build.ps1 first."
    }
}

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('UBE hello prøvetest ' + [System.Guid]::NewGuid().ToString('N'))
$executablePath = Join-Path $temporaryRoot 'HelloUBE.exe'
$intermediatePath = Join-Path $temporaryRoot 'HelloUBE.ll'

try {
    New-Item -ItemType Directory -Path $temporaryRoot -ErrorAction Stop | Out-Null

    & $CompilerPath '--build-native' $projectPath 'x86_64-w64-windows-gnu' $ClangPath `
        $RuntimeObject $UnicodeRuntimeObject $executablePath $intermediatePath
    if ($LASTEXITCODE -ne 0) {
        throw "UBE compilation failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        throw 'UBE compilation reported success without producing the executable.'
    }

    $output = & $executablePath
    $programExitCode = $LASTEXITCODE
    if ($programExitCode -ne 0) {
        throw "HelloUBE exited with code $programExitCode."
    }

    $actual = ($output -join "`n") + "`n"
    $expected = "Hello, UBE!`nWelcome to native Basic programming.`n2 + 3 equals:`n5`n"
    if ($actual -cne $expected) {
        throw "HelloUBE output did not match the expected text.`nExpected:`n$expected`nActual:`n$actual"
    }

    Write-Output 'Hello, UBE! smoke test passed.'
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
