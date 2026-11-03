param([Parameter(Mandatory=$true)][string] $Executable,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$tool = Join-Path $directory 'tool.exe'
[IO.File]::Copy((Resolve-Path -LiteralPath $Executable).Path, $tool)
$stream = [IO.File]::Open($tool, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
$mapping = [IO.MemoryMappedFiles.MemoryMappedFile]::CreateFromFile($stream, ('Local\UBE-tool-map-' + [guid]::NewGuid().ToString('N')), 0, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWrite, $null, [IO.HandleInheritability]::None, $true)
$length = $stream.Length
$view = $mapping.CreateViewAccessor($length - 1, 1, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWrite)
$stream.Dispose()
$guard = $null
try {
    try { $guard = [IO.File]::Open($tool, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read) }
    catch [IO.IOException] { Write-Output 'A writable mapping prevented guard acquisition.' }
    if ($guard) {
        $before = $view.ReadByte(0)
        $view.Write(0, [byte]($before -bxor 1)); $view.Flush()
        $guard.Seek($length - 1, [IO.SeekOrigin]::Begin) | Out-Null
        if ($guard.ReadByte() -ne ($before -bxor 1)) { throw 'Mapped modification was not observed through guard' }
        Write-Output 'A writable mapping changed bytes after guard acquisition.'
    }
} finally {
    if ($guard) { $guard.Dispose() }
    $view.Dispose(); $mapping.Dispose()
}
$control = [IO.File]::Open($tool, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$control.Dispose()
Write-Output 'Guard acquired after mapping disposal.'
