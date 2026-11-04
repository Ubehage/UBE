param([Parameter(Mandatory=$true)][string]$ReportPath)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
& (Join-Path $root 'std-lib/tests/byte-keys/check-budgeted.ps1') -ReportPath $ReportPath
