param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$encoding = New-Object Text.UTF8Encoding($false)
foreach ($race in @($false, $true)) {
    $directory = Join-Path $root ([string]$race)
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate = Join-Path $directory 'candidate.bin'
    $destination = Join-Path $directory 'destination.bin'
    [IO.File]::WriteAllText($candidate, 'candidate', $encoding)
    $id = [guid]::NewGuid().ToString('N')
    $readyName = 'Local\UBE-create-ready-' + $id
    $releaseName = 'Local\UBE-create-release-' + $id
    $ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
    $release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
    $process = [Diagnostics.Process]::new()
    try {
        $process.StartInfo.FileName = $probePath
        $process.StartInfo.Arguments = '"' + $directory + '" native-create ' + $readyName + ' ' + $releaseName
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardError = $true
        if (-not $process.Start() -or -not $ready.WaitOne(5000)) { throw 'Probe was not ready' }
        if ($race) { [IO.File]::WriteAllText($destination, 'interloper', $encoding) }
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(5000)) { throw 'Probe did not exit' }
        $stderr = $process.StandardError.ReadToEnd()
        if ($race) {
            if ($process.ExitCode -ne 1 -or $stderr -notmatch 'rename failed: (80|183)' -or
                [IO.File]::ReadAllText($destination) -ne 'interloper' -or [IO.File]::ReadAllText($candidate) -ne 'candidate') {
                throw "Collision case failed: $($process.ExitCode) $stderr"
            }
            Write-Output "Racing destination preserved: $($stderr.Trim())"
        } else {
            if ($process.ExitCode -ne 0 -or [IO.File]::ReadAllText($destination) -ne 'candidate' -or [IO.File]::Exists($candidate)) {
                throw 'Absent destination case failed'
            }
        }
    } finally {
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); $ready.Dispose(); $release.Dispose()
    }
}
Write-Output "Create-only rename succeeded when absent and preserved a racing destination: $root"
