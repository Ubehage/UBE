param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'reference-check.ps1') -CompilerExe $CompilerExe -Clang $Clang -Locks
