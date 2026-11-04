param([string]$SelectionPath='', [switch]$DiagnosticOnly)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
& (Join-Path $root 'std-lib/tests/graph-components/check.ps1') -SelectionPath $SelectionPath -DiagnosticOnly:$DiagnosticOnly
