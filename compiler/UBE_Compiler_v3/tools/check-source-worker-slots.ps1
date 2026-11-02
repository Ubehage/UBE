param([string]$SelectionPath='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Repository root missing'};$root=$parent}
& (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/source-worker-slots/check.ps1') -SelectionPath $SelectionPath
