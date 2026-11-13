# Keeps the shipped import definition equal to the reviewed fixed Windows runtime imports.
param([switch]$Write)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$encoding = New-Object Text.UTF8Encoding($false, $true)
$runtime = [IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'), $encoding)
# These OS entry points belong to Kernel32; a new DLL boundary needs an explicit reviewed mapping.
$allowed = @(
 'VirtualAlloc','VirtualFree','CreateFileW','GetFileType','GetFileSizeEx','ReadFile','WriteFile','CloseHandle',
 'FlushFileBuffers','MultiByteToWideChar','GetCommandLineW','GetStdHandle','WideCharToMultiByte',
 'GetFullPathNameW','GetFinalPathNameByHandleW','CompareStringOrdinal','GetFileInformationByHandle',
 'GetModuleFileNameW','GetTickCount64','GetCurrentProcess','DuplicateHandle','CreateProcessW',
 'InitializeProcThreadAttributeList','UpdateProcThreadAttribute','DeleteProcThreadAttributeList',
 'CreateJobObjectW','SetInformationJobObject','AssignProcessToJobObject','ResumeThread',
 'WaitForSingleObject','GetExitCodeProcess','QueryInformationJobObject','TerminateJobObject',
 'TerminateProcess','Sleep','GetLastError','GetFileAttributesW','CreateDirectoryW','RemoveDirectoryW',
 'DeleteFileW','MoveFileExW'
)
$names = New-Object Collections.Generic.List[string]
foreach ($line in ($runtime -split '\r?\n')) {
 if ($line -notmatch '^declare dllimport ') { continue }
 if ($line -notmatch '^declare dllimport (?:ptr|i32|i64|void) @([A-Za-z][A-Za-z0-9]*)\(') { throw "Unreviewed import declaration: $line" }
 $name = $Matches[1]
 if ($allowed -cnotcontains $name) { throw "Unreviewed target DLL mapping: $name" }
 if ($names.Contains($name)) { throw "Duplicate target import: $name" }
 $names.Add($name)
}
if ($names.Count -lt 2) { throw 'Missing target runtime imports' }
$ordered = $names.ToArray()
[Array]::Sort($ordered, [StringComparer]::Ordinal)
$expected = ((@('LIBRARY KERNEL32.dll','EXPORTS') + $ordered) -join "`r`n") + "`r`n"
$path = Join-Path $root 'compiler/llvm/kernel32.def'
if ($Write) { [IO.File]::WriteAllText($path, $expected, $encoding) }
if (-not [IO.File]::Exists($path) -or [IO.File]::ReadAllText($path, $encoding) -cne $expected) {
 throw 'Import definition differs from reviewed runtime declarations; run -Write after review'
}
Write-Output "PASS: $($names.Count) reviewed Kernel32 imports; exact definition parity"
