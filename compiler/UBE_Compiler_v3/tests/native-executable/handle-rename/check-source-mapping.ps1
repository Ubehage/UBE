param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate = Join-Path $directory 'candidate.bin'
$destination = Join-Path $directory 'destination.bin'
[IO.File]::WriteAllText($candidate, 'candidate')
[IO.File]::WriteAllText($destination, 'old')
$stream = [IO.File]::Open($candidate, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
$mappingName = 'Local\UBE-map-' + [guid]::NewGuid().ToString('N')
$mapping = [IO.MemoryMappedFiles.MemoryMappedFile]::CreateFromFile($stream, $mappingName, 0, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWrite, $null, [IO.HandleInheritability]::None, $true)
$view = $mapping.CreateViewAccessor(0, 9, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWrite)
$stream.Dispose()
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-map-ready-' + $id
$releaseName = 'Local\UBE-map-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$process = [Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName = $probePath
    $process.StartInfo.Arguments = '"' + $directory + '" native-sourceguard ' + $readyName + ' ' + $releaseName
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
    if (-not $process.Start()) { throw 'Probe did not start' }
    if (-not $ready.WaitOne(2000)) {
        if (-not $process.WaitForExit(5000) -or $process.ExitCode -ne 5) { throw "Unexpected guard acquisition result: $($process.ExitCode)" }
        if ([IO.File]::ReadAllText($destination) -ne 'old') { throw 'Destination changed' }
        $view.Dispose(); $mapping.Dispose()
        $control = @(& $probePath $directory native-sourceguard 2>&1)
        if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($destination) -ne 'candidate') { throw "Post-disposal control failed: $control" }
        Write-Output 'Guard acquisition failed while writable mapping existed; rename succeeded after disposal.'
    } else {
        $bytes = [Text.Encoding]::ASCII.GetBytes('TAMPERED!')
        $view.WriteArray(0, $bytes, 0, $bytes.Length)
        $view.Flush()
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(5000)) { throw 'Rename did not finish' }
        if ($process.ExitCode -eq 0) {
            if ([IO.File]::ReadAllText($destination) -ne 'TAMPERED!') { throw 'Published bytes differ from mapped write' }
            Write-Output 'Writable mapping changed the guarded candidate and those bytes were published.'
        } else {
            if ([IO.File]::ReadAllText($destination) -ne 'old') { throw 'Failed rename changed destination' }
            Write-Output "Guard acquired but mapped write prevented rename; probe exit $($process.ExitCode)."
        }
    }
} finally {
    $release.Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); $ready.Dispose(); $release.Dispose(); $view.Dispose(); $mapping.Dispose()
}
