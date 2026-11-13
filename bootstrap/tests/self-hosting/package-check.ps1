# Checks reproducible source packaging only; executable self-hosting has its own acceptance obligation.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$tool = Join-Path $root 'bootstrap/tools/self-host-sources.ps1'
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube self-host sources ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $artifacts
$encoding = New-Object Text.UTF8Encoding($false, $true)
$script:checks = 0

# Records an exact packaging assertion or stops with its failure reason.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}

# Requires preflight refusal and absence of a completed or partial destination.
function Require-Rejection([string]$Destination, [string[]]$Sources, [string]$Pattern) {
    $message = ''
    try { $null = & $tool -Destination $Destination -AdditionalSources $Sources } catch { $message = $_.Exception.Message }
    Require ($message -match $Pattern) "Expected rejection '$Pattern', received '$message'"
    Require (-not (Test-Path -LiteralPath $Destination)) 'Rejected preflight created output'
}

Write-Output "Artifacts retained: $artifacts"
$first = & $tool -Destination (Join-Path $artifacts 'first')
$second = & $tool -Destination (Join-Path $artifacts 'second')
$expected = @('BufferPrimitives','FilePrimitives','FileBytes','ByteText','Utf8','SystemPrimitives','StandardStreams','PathPrimitives','DirectoryPrimitives','ProcessPrimitives','ThreadPrimitives','WindowsArguments','WindowsPaths','WindowsImages','SourceScanner','SyntaxTokens','SourceParser','ProjectSyntax','DeclarationBinder','ConstantValues','ExpressionBinder','AggregateLayout','PrimitiveRoles','LLVMWriter','LLVMTemplates','LLVMFormat','NativeEscapes','NativePlanning','NativeEmission','NativeValues','NativeThreads','NativeOwnership','NativeStorage','NativeExpressions','NativeContext','NativeIntrinsics','NativeFrames','NativeControl','NativeLowering','ProjectManifest','ProjectLoader','CommandOptions','OutputPublication','NativeToolArguments','NativeBackend','CompilerAssets','CompilerMessages','NativeCompilation','CompilationRequest','CompilerCommand')
Require ($first.Sources.Count -eq $expected.Count) 'Unexpected compiler source count'
Require ($first.ManifestSHA256 -ceq $second.ManifestSHA256) 'Manifest differs between destination paths'
Require ((Get-FileHash (Join-Path $first.Destination 'sources.sha256')).Hash -ceq (Get-FileHash (Join-Path $second.Destination 'sources.sha256')).Hash) 'Source ledger differs between packages'
$manifest = [IO.File]::ReadAllText($first.Manifest, $encoding)
$sourceLines = @($manifest -split "`r`n" | Where-Object { $_ -like 'Source = *' })
Require ($sourceLines.Count -eq $expected.Count) 'Manifest source count differs'
for ($i=0; $i -lt $expected.Count; $i++) {
    $leaf = $expected[$i] + '.bas'
    Require ($sourceLines[$i] -ceq ('Source = "' + $leaf + '"')) "Manifest source order differs at $i"
    $record = $first.Sources[$i]
    Require ($record.Index -eq $i -and $record.RelativePath -ceq $leaf) "Returned source identity differs at $i"
    $copy = [IO.Path]::GetFullPath((Join-Path $first.Destination $record.RelativePath))
    Require ([IO.Path]::GetDirectoryName($copy) -ceq $first.Destination) "Copied source escaped package: $leaf"
    Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes($copy)) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($record.OriginalPath))) "Copied bytes differ: $leaf"
    Require ((Get-FileHash -LiteralPath $copy).Hash -ceq $record.SHA256) "Recorded hash differs: $leaf"
}
Require ($manifest -notmatch 'Startup =') 'Library package unexpectedly declares Main'
$driver = Join-Path $artifacts 'CommandDriver.bas'
[IO.File]::WriteAllBytes($driver, $encoding.GetBytes("UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"CommandDriver`"`r`nPublic Function Main() As Long`r`nEnd Function`r`n"))
$executable = & $tool -Destination (Join-Path $artifacts 'executable') -AdditionalSources @($driver) -Kind Exe -Optimization 2
$exeManifest = [IO.File]::ReadAllText($executable.Manifest, $encoding)
Require ($executable.Sources.Count -eq $expected.Count + 1 -and $executable.Sources[$expected.Count].RelativePath -ceq 'CommandDriver.bas') 'Additional driver order differs'
Require ($exeManifest -match 'Kind = "Exe"\r\nOptimization = "2"\r\nStartup = "Main"') 'Executable manifest settings differ'
Require ((Get-FileHash $driver).Hash -ceq (Get-FileHash (Join-Path $executable.Destination 'CommandDriver.bas')).Hash) 'Driver bytes changed'
Require-Rejection (Join-Path $artifacts 'duplicate') @($driver,$driver) 'Duplicate package source filename'
Require-Rejection (Join-Path $artifacts 'core-collision') @('compiler/src/SourceScanner.bas') 'Duplicate package source filename'
Require-Rejection (Join-Path $artifacts 'missing') @('compiler/src/MissingDriver.bas') 'Cannot find path'
$badSource = Join-Path $artifacts 'bad name.bas'
[IO.File]::WriteAllText($badSource, 'unchanged', $encoding)
Require-Rejection (Join-Path $artifacts 'bad-leaf') @($badSource) 'Unsupported package source filename'
$sentinel = Join-Path $first.Destination 'sentinel.txt'
[IO.File]::WriteAllText($sentinel, 'preserve existing output', $encoding)
$message = ''
try { $null = & $tool -Destination $first.Destination } catch { $message = $_.Exception.Message }
Require ($message -match 'already exists') 'Existing package was not refused'
Require ([IO.File]::ReadAllText($sentinel, $encoding) -ceq 'preserve existing output') 'Existing destination changed'
Require ((Get-FileHash $first.Manifest).Hash -ceq $first.ManifestSHA256) 'Refusal changed existing manifest'
# Owns both the link and its target under this fresh evidence directory; neither is deleted.
$redirectTarget = Join-Path $artifacts 'redirect target'
$redirectLink = Join-Path $artifacts 'redirect link'
$null = New-Item -ItemType Directory -Path $redirectTarget
$redirectSentinel = Join-Path $redirectTarget 'sentinel.txt'
[IO.File]::WriteAllText($redirectSentinel, 'preserve redirected target', $encoding)
$redirectHash = (Get-FileHash -LiteralPath $redirectSentinel).Hash
$junctionAvailable = $false
try {
    $null = New-Item -ItemType Junction -Path $redirectLink -Target $redirectTarget -ErrorAction Stop
    $junctionAvailable = $true
} catch {
    Write-Output ('SKIP redirected-ancestor assertion: cannot create test junction: ' + $_.Exception.Message)
}
if ($junctionAvailable) {
    Require (((Get-Item -LiteralPath $redirectLink -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) 'Test junction is not a reparse point'
    Require-Rejection (Join-Path $redirectLink 'package') @() 'redirected ancestor'
    Require (-not (Test-Path -LiteralPath (Join-Path $redirectTarget 'package'))) 'Rejected redirected destination created target output'
    Require ((Get-FileHash -LiteralPath $redirectSentinel).Hash -ceq $redirectHash) 'Rejected redirected destination changed target sentinel'
    Require (@(Get-ChildItem -LiteralPath $redirectTarget -Force).Count -eq 1) 'Rejected redirected destination added target files'
    Write-Output 'PASS: junction ancestor refused; redirected target and sentinel unchanged'
}
Write-Output "PASS: $script:checks source-packaging assertions. No executable self-hosting claim. Evidence: $artifacts"
