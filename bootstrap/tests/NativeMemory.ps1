# Links the compiler's Windows memory imports using the already installed LLVM tools.
# The invoking gate supplies bounded process execution, assertions and UTF-8 writing.
function Get-NativeMemoryLinkArguments([string]$IR, [string]$Clang, [string]$Directory) {
    $text = [IO.File]::ReadAllText($IR)
    if (-not $text.Contains('@VirtualAlloc')) { return }
    $library = Join-Path $Directory 'kernel32-memory.lib'
    if (-not (Test-Path -LiteralPath $library)) {
        $definition = Join-Path $Directory 'kernel32-memory.def'
        Write-Text $definition "LIBRARY KERNEL32.dll`r`nEXPORTS`r`nVirtualAlloc`r`nVirtualFree`r`n"
        $tool = Join-Path ([IO.Path]::GetDirectoryName($Clang)) 'llvm-dlltool.exe'
        Require (Test-Path -LiteralPath $tool) "Required installed LLVM import tool missing: $tool"
        $result = Invoke-BoundedProcess $tool @('-m','i386:x86-64','-d',$definition,'-l',$library)
        Require ($result.ExitCode -eq 0 -and (Test-Path -LiteralPath $library)) "Memory import library generation failed. Evidence: $($result.Evidence)"
    }
    $bytes = [IO.File]::ReadAllBytes($library)
    Require ($bytes.Length -ge 8 -and $bytes.Length -le 65536 -and [Text.Encoding]::ASCII.GetString($bytes,0,8) -eq "!<arch>`n") 'Invalid bounded memory import library'
    return $library
}
