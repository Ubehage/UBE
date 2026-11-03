param([Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$candidate = Join-Path $root 'candidate.bin'
[IO.File]::WriteAllBytes($candidate, [byte[]]@())
$id = [guid]::NewGuid().ToString('N')
$readyName = 'Local\UBE-candidate-burst-ready-' + $id
$releaseName = 'Local\UBE-candidate-burst-release-' + $id
$ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
$release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
$job = $null
try {
    $job = Start-Job -ArgumentList $candidate,$readyName,$releaseName -ScriptBlock {
        param($path,$readyEvent,$releaseEvent)
        $readyHandle = [Threading.EventWaitHandle]::OpenExisting($readyEvent)
        $releaseHandle = [Threading.EventWaitHandle]::OpenExisting($releaseEvent)
        try {
            $readyHandle.Set() | Out-Null
            if (-not $releaseHandle.WaitOne(10000)) { throw 'Release timed out' }
            $payload = [byte[]]::new(65536)
            for ($i = 0; $i -lt $payload.Length; $i++) { $payload[$i] = [byte]($i % 251) }
            [IO.File]::WriteAllBytes($path, $payload)
        } finally { $readyHandle.Dispose(); $releaseHandle.Dispose() }
    }
    if (-not $ready.WaitOne(10000)) { throw 'Writer did not reach the barrier' }
    $limit = 4096
    $before = (Get-Item -LiteralPath $candidate).Length
    if ($before -gt $limit) { throw 'Initial sample already exceeds the test limit' }
    $release.Set() | Out-Null
    if (-not (Wait-Job -Job $job -Timeout 10) -or $job.State -ne 'Completed') { throw 'Writer did not complete' }
    Receive-Job -Job $job -ErrorAction Stop | Out-Null
    $bytes = [IO.File]::ReadAllBytes($candidate)
    if ($bytes.Length -ne 65536 -or $bytes.Length -le $limit -or $bytes[0] -ne 0 -or $bytes[65535] -ne (65535 % 251)) { throw 'Burst contents or overshoot differ' }
    Write-Output "File-size sample $before was within limit $limit; before the next sample the writer completed $($bytes.Length) bytes."
} finally {
    $release.Set() | Out-Null
    if ($job) { if ($job.State -eq 'Running') { Stop-Job -Job $job }; Remove-Job -Job $job -Force }
    $ready.Dispose(); $release.Dispose()
}
