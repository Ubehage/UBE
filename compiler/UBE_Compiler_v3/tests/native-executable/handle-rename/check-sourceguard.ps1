param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($mode in @('native-relative', 'native-sourceguard')) {
    $directory = Join-Path $root $mode
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate = Join-Path $directory 'candidate.bin'
    [IO.File]::WriteAllText($candidate, 'candidate')
    $alias = Join-Path $directory 'candidate-alias.bin'
    New-Item -ItemType HardLink -Path $alias -Target $candidate | Out-Null
    [IO.File]::WriteAllText((Join-Path $directory 'destination.bin'), 'old')
    $id = [guid]::NewGuid().ToString('N')
    $readyName = 'Local\UBE-src-ready-' + $id
    $releaseName = 'Local\UBE-src-release-' + $id
    $ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
    $release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
    $process = [Diagnostics.Process]::new()
    try {
        $process.StartInfo.FileName = $probePath
        $process.StartInfo.Arguments = '"' + $directory + '" ' + $mode + ' ' + $readyName + ' ' + $releaseName
        $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
        if (-not $process.Start() -or -not $ready.WaitOne(5000)) { throw 'Probe was not ready' }
        $blocked = $false
        try {
            $stream = [IO.File]::Open($alias, [IO.FileMode]::Open, [IO.FileAccess]::Write, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            try { $bytes = [Text.Encoding]::UTF8.GetBytes('tampered'); $stream.SetLength(0); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
        } catch [IO.IOException] { $blocked = $true }
        if ($blocked -ne ($mode -eq 'native-sourceguard')) { throw "Unexpected write result for $mode" }
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(5000) -or $process.ExitCode -ne 0) { throw 'Rename failed' }
        $expected = if ($blocked) { 'candidate' } else { 'tampered' }
        if ([IO.File]::ReadAllText((Join-Path $directory 'destination.bin')) -ne $expected) { throw 'Wrong published bytes' }
    } finally {
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); $ready.Dispose(); $release.Dispose()
    }
}
Write-Output "Unguarded candidate changed through hard link; guarded candidate retained bytes and renamed: $root"
