# Verifies ordinary catalog packaging without selecting compiler-specific dependencies.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$tool=Join-Path $root 'std-lib/tools/package-library.ps1'
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube library packaging '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $evidence
$utf8=New-Object Text.UTF8Encoding($false,$true)
function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Refused([scriptblock]$Action,[string]$Expected){
 try{$null=& $Action;throw 'Expected refusal was not raised'}catch{Require ($_.Exception.Message.Contains($Expected)) ('Unexpected refusal: '+$_)}
}
$target=Join-Path $evidence 'installed'
$result=& $tool -Destination $target
$manifest=[IO.File]::ReadAllText($result.Manifest,$utf8)
Require ($manifest.Contains('Name = "UBECore"')) 'Installed package identity changed'
Require ($manifest.Contains('Source = "src/win-lib/WindowsPaths.bas"')) 'Target modules absent'
Require ($manifest.Contains('Source = "src/portable/ThreadPrimitives.bas"')) 'Public thread module absent'
foreach($record in $result.Sources){
 Require ((Get-FileHash -LiteralPath (Join-Path $target $record.RelativePath) -Algorithm SHA256).Hash -ceq $record.SHA256) ('Changed copied source: '+$record.RelativePath)
 Require ($manifest.Contains('Source = "'+$record.RelativePath+'"')) 'Copied source absent from catalog'
}
Require (@([IO.File]::ReadAllLines((Join-Path $target 'sources.sha256'))).Count -eq $result.SourceCount) 'Incomplete source ledger'
Refused {& $tool -Destination $target} 'already exists'

# A private source-root fixture proves catalog validation and preflight-before-write behavior.
$source=Join-Path $evidence 'source'
$null=New-Item -ItemType Directory (Join-Path $source 'src/portable') -Force
[IO.File]::WriteAllText((Join-Path $source 'src/portable/One.bas'),"UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"One`"`r`n",$utf8)
[IO.File]::WriteAllText((Join-Path $source 'src/portable/Two.bas'),"UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"One`"`r`n",$utf8)
$header="UBE-Project 1`r`nName = `"UBECore`"`r`nKind = `"Library`"`r`n"
$core=Join-Path $source 'UBECore.UBE';$platform=Join-Path $source 'UBECore.Windows.UBE'
[IO.File]::WriteAllText($core,$header+"Source = `"src/portable/One.bas`"`r`n",$utf8)
[IO.File]::WriteAllText($platform,$header+"Source = `"src/portable/Two.bas`"`r`n",$utf8)
$duplicate=Join-Path $evidence 'duplicate'
Refused {& $tool -Destination $duplicate -LibraryRoot $source} 'duplicate library module identity'
Require (-not (Test-Path -LiteralPath $duplicate)) 'Failed preflight created package'
[IO.File]::WriteAllText($platform,$header+"Source = `"src/portable/One.bas`"`r`n",$utf8)
Refused {& $tool -Destination $duplicate -LibraryRoot $source} 'Repeated library source'
[IO.File]::WriteAllText($platform,$header+"Source = `"src/../outside.bas`"`r`n",$utf8)
Refused {& $tool -Destination $duplicate -LibraryRoot $source} 'Noncanonical library path'
$junction=Join-Path $evidence 'redirected';$null=New-Item -ItemType Junction -Path $junction -Target $target
Refused {& $tool -Destination (Join-Path $junction 'nested')} 'Redirected library path'
Require (-not (Test-Path -LiteralPath (Join-Path $target 'nested'))) 'Redirected destination was written'
Write-Output "PASS $($result.SourceCount) exact library copies, generic merged manifest/ledger, no overwrite, duplicate module/source and traversal/redirect refusal; evidence: $evidence"
