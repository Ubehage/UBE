# Checks exact source packaging, fixed ordering and preflight rejection without output mutation.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$encoding = New-Object Text.UTF8Encoding($false, $true)
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$runtime = Join-Path $root 'runtime'
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube support package ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $artifacts
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$target = Join-Path $artifacts 'support'
$package = & (Join-Path $runtime 'package-managed-support.ps1') -Destination $target
$entries = @([IO.File]::ReadAllLines((Join-Path $runtime 'managed-support-sources.txt'), $encoding) | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not $_.StartsWith('#') })
$manifest = @([IO.File]::ReadAllLines($package.Manifest, $encoding))
$ledger = @([IO.File]::ReadAllLines($package.Ledger, $encoding))
Require ($package.SourceCount -eq $entries.Count) 'Wrong source count'
Require ($manifest.Count -eq 3 + $entries.Count) 'Unexpected manifest fields'
Require ($manifest[0] -ceq 'UBE-Project 1' -and $manifest[1] -ceq 'Name = "ManagedSupport"' -and $manifest[2] -ceq 'Kind = "Library"') 'Wrong support manifest identity'
Require ($ledger.Count -eq $entries.Count) 'Wrong hash ledger count'
for ($i=0; $i -lt $entries.Count; $i++) {
    $name = [IO.Path]::GetFileName($entries[$i])
    $hash = (Get-FileHash -LiteralPath (Join-Path $root $entries[$i]) -Algorithm SHA256).Hash
    Require ($manifest[$i+3] -ceq ('Source = "' + $name + '"')) 'Source ordering changed'
    Require ((Get-FileHash -LiteralPath (Join-Path $target $name) -Algorithm SHA256).Hash -ceq $hash) "Source bytes changed: $name"
    Require ($ledger[$i] -ceq ($hash + '  ' + $name)) "Incorrect source ledger: $name"
}
$manifestHash = (Get-FileHash -LiteralPath $package.Manifest -Algorithm SHA256).Hash
$rejected = $false
try { & (Join-Path $runtime 'package-managed-support.ps1') -Destination $target | Out-Null } catch { $rejected = $true }
Require $rejected 'Existing destination was accepted'
Require ((Get-FileHash -LiteralPath $package.Manifest -Algorithm SHA256).Hash -ceq $manifestHash) 'Rejected package changed the existing manifest'
# Copy only the packaging tool and ledger: all authoritative production sources are absent.
$fixtureRuntime = Join-Path $artifacts 'missing/runtime'
$null = New-Item -ItemType Directory -Path $fixtureRuntime
Copy-Item -LiteralPath (Join-Path $runtime 'package-managed-support.ps1') -Destination $fixtureRuntime
Copy-Item -LiteralPath (Join-Path $runtime 'managed-support-sources.txt') -Destination $fixtureRuntime
$missingOutput = Join-Path $artifacts 'missing-output'
$rejected = $false
try { & (Join-Path $fixtureRuntime 'package-managed-support.ps1') -Destination $missingOutput | Out-Null } catch { $rejected = $true }
Require $rejected 'Missing authoritative sources were accepted'
Require (-not (Test-Path -LiteralPath $missingOutput)) 'Missing source failure published a partial package'
[IO.File]::WriteAllText((Join-Path $fixtureRuntime 'managed-support-sources.txt'), '../untrusted.bas', $encoding)
$rejected = $false
try { & (Join-Path $fixtureRuntime 'package-managed-support.ps1') -Destination $missingOutput | Out-Null } catch { $rejected = $true }
Require $rejected 'Escaping source ledger entry was accepted'
Require (-not (Test-Path -LiteralPath $missingOutput)) 'Invalid ledger published a partial package'
# Prove the exact-byte oracle detects a changed packaged source.
$first = Join-Path $target ([IO.Path]::GetFileName($entries[0]))
[IO.File]::AppendAllText($first, "`r`n' changed negative control`r`n", $encoding)
Require ((Get-FileHash -LiteralPath $first -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath (Join-Path $root $entries[0]) -Algorithm SHA256).Hash) 'Changed-source negative control was not detected'
Write-Output "PASS: $($entries.Count) exact ordered support sources; existing destination, missing source, invalid path, and changed-byte controls. Evidence: $artifacts"
