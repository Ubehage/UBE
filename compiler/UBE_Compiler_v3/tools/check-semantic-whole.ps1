param([string]$SelectionPath='',[switch]$RequireIntegrated=$true,[string]$OutputRoot='')
$ErrorActionPreference='Stop'
$repo=$PSScriptRoot;while(-not [IO.File]::Exists((Join-Path $repo 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $repo -Parent;if(-not $parent -or $parent -eq $repo){throw 'Repository root not found'};$repo=$parent}
& (Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/native/whole/check.ps1') -SelectionPath $SelectionPath -RequireIntegrated:$RequireIntegrated -OutputRoot $OutputRoot
