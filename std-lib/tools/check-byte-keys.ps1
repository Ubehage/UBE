param([string]$SelectionPath='')
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
& (Join-Path $root 'std-lib/tests/byte-keys/check.ps1') -SelectionPath $SelectionPath