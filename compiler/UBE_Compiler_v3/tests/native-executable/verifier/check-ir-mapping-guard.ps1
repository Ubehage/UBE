param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$valid = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'valid.ll')).Path
$clang = (Resolve-Path -LiteralPath $Clang).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$path = Join-Path $directory 'module.ll'; [IO.File]::Copy($valid, $path)
$expected = (Get-FileHash -LiteralPath $valid).Hash
$stream = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
$mapping = [IO.MemoryMappedFiles.MemoryMappedFile]::CreateFromFile($stream, ('Local\UBE-ir-map-' + [guid]::NewGuid().ToString('N')), 0, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWrite, $null, [IO.HandleInheritability]::None, $true)
$length = $stream.Length
$view = $mapping.CreateViewAccessor($length - 1, 1, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWrite)
$stream.Dispose()
$guard = $null
try {
    $original = $view.ReadByte(0)
    $view.Write(0, [byte]($original -bxor 1)); $view.Flush()
    if ($view.ReadByte(0) -eq $original) { throw 'Mapping did not mutate the test byte' }
    $reader = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try {
        $reader.Seek($length - 1, [IO.SeekOrigin]::Begin) | Out-Null
        if ($reader.ReadByte() -ne ($original -bxor 1)) { throw 'Mapped write was not observed through an independent file handle' }
    } finally { $reader.Dispose() }
    $view.Write(0, $original); $view.Flush()
    try { $guard = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read) } catch [IO.IOException] { }
    if ($guard) {
        $view.Write(0, [byte]($original -bxor 1)); $view.Flush()
        $guard.Seek($length - 1, [IO.SeekOrigin]::Begin) | Out-Null
        if ($guard.ReadByte() -ne ($original -bxor 1)) { throw 'Mapping mutation was not visible through the guard' }
        $view.Write(0, $original); $view.Flush()
        Write-Output 'Adverse result: a verified writable mapping changed the guarded IR.'
    } else { Write-Output 'A verified writable mapping blocked IR guard acquisition.' }
} finally {
    if ($guard) { $guard.Dispose() }
    $view.Dispose(); $mapping.Dispose()
}
$guard = [IO.File]::Open($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    if ((Get-FileHash -LiteralPath $path).Hash -ne $expected) { throw 'Fixture was not restored after mapping control' }
    $object = Join-Path $directory 'valid.o'
    & $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each -c -x ir $path -o $object
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($object)) { throw 'Valid IR failed after mapping release' }
    Write-Output 'After mapping release, the guard was acquired and valid IR compiled.'
} finally { $guard.Dispose() }
