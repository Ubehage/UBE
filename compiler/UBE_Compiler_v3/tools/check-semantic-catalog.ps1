param([string]$SelectionPath='',[string]$Stage1Run='',[string]$Stage2Run='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Cannot find repository root'};$root=$parent}
& (Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/native/catalog/qualify.ps1') -SelectionPath $SelectionPath -Stage1Run $Stage1Run -Stage2Run $Stage2Run
