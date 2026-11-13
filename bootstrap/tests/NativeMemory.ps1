# Links the compiler's Windows memory imports using the already installed LLVM tools.
# The invoking gate supplies bounded process execution, assertions and UTF-8 writing.
function Get-NativeMemoryLinkArguments([string]$IR, [string]$Clang, [string]$Directory) {
    $text = [IO.File]::ReadAllText($IR)
    $fileImports = $text.Contains('@CreateFileW')
    if (-not $text.Contains('@VirtualAlloc') -and -not $fileImports) { return }
    $stem = 'kernel32-memory'
    if ($fileImports) { $stem = 'kernel32-files' }
    $library = Join-Path $Directory ($stem + '.lib')
    if (-not (Test-Path -LiteralPath $library)) {
        $definition = Join-Path $Directory ($stem + '.def')
        $exports = "LIBRARY KERNEL32.dll`r`nEXPORTS`r`nVirtualAlloc`r`nVirtualFree`r`n"
        if ($fileImports) { $exports += "CreateFileW`r`nReadFile`r`nWriteFile`r`nCloseHandle`r`nGetFileSizeEx`r`nGetFileType`r`nFlushFileBuffers`r`nMultiByteToWideChar`r`nGetCommandLineW`r`nGetStdHandle`r`nWideCharToMultiByte`r`nGetFullPathNameW`r`nGetFinalPathNameByHandleW`r`nCompareStringOrdinal`r`nGetFileInformationByHandle`r`nGetModuleFileNameW`r`nGetTickCount64`r`nGetCurrentProcess`r`nDuplicateHandle`r`nCreateProcessW`r`nInitializeProcThreadAttributeList`r`nUpdateProcThreadAttribute`r`nDeleteProcThreadAttributeList`r`nCreateJobObjectW`r`nSetInformationJobObject`r`nAssignProcessToJobObject`r`nResumeThread`r`nWaitForSingleObject`r`nGetExitCodeProcess`r`nQueryInformationJobObject`r`nTerminateJobObject`r`nTerminateProcess`r`nSleep`r`nGetLastError`r`nCreateDirectoryW`r`nRemoveDirectoryW`r`nDeleteFileW`r`nMoveFileExW`r`nGetFileAttributesW`r`n" }
        if ($text.Contains('@CreateThread')) { $exports += "CreateThread`r`n" }
        Write-Text $definition $exports
        $tool = Join-Path ([IO.Path]::GetDirectoryName($Clang)) 'llvm-dlltool.exe'
        Require (Test-Path -LiteralPath $tool) "Required installed LLVM import tool missing: $tool"
        $result = Invoke-BoundedProcess $tool @('-m','i386:x86-64','-d',$definition,'-l',$library)
        Require ($result.ExitCode -eq 0 -and (Test-Path -LiteralPath $library)) "Memory import library generation failed. Evidence: $($result.Evidence)"
    }
    $bytes = [IO.File]::ReadAllBytes($library)
    Require ($bytes.Length -ge 8 -and $bytes.Length -le 65536 -and [Text.Encoding]::ASCII.GetString($bytes,0,8) -eq "!<arch>`n") 'Invalid bounded memory import library'
    return $library
}
