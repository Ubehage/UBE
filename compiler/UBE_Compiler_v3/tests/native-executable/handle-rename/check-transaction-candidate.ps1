param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$candidate=Join-Path $directory 'candidate.bin'; $moved=Join-Path $directory 'checked.bin'; $destination=Join-Path $directory 'destination.bin'
[IO.File]::WriteAllText($candidate,'candidate'); [IO.File]::WriteAllText($destination,'old'); [IO.File]::WriteAllText((Join-Path $directory 'protected.bin'),'protected')
$id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release') | ForEach-Object { 'Local\UBE-tx-candidate-' + $_ + '-' + $id }
$events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
$process=[Diagnostics.Process]::new()
try {
    $process.StartInfo.FileName=$probePath; $process.StartInfo.Arguments='"' + $directory + '" ' + ($names -join ' ')
    $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardOutput=$true; $process.StartInfo.RedirectStandardError=$true
    if (-not $process.Start() -or -not $events[0].WaitOne(5000)) { throw 'Transaction guard was not established' }
    $events[1].Set() | Out-Null
    if (-not $events[2].WaitOne(5000)) { throw 'Closed-handle barrier was not reached' }
    [IO.File]::Move($candidate,$moved); [IO.File]::WriteAllText($candidate,'substitute')
    $events[3].Set() | Out-Null
    if (-not $process.WaitForExit(10000)) { throw 'Transaction probe timed out' }
    $stdout=$process.StandardOutput.ReadToEnd().Trim(); $stderr=$process.StandardError.ReadToEnd().Trim()
    if ($process.ExitCode -ne 0 -or [IO.File]::ReadAllText($destination) -ne 'substitute' -or
        [IO.File]::ReadAllText($moved) -ne 'candidate' -or [IO.File]::Exists($candidate)) { throw "Unexpected candidate-swap outcome: $stdout $stderr" }
    Write-Output "Adverse control: replacement committed substituted candidate; original candidate survived at moved name: $directory"
} finally {
    $events[1].Set() | Out-Null; $events[3].Set() | Out-Null
    if (-not $process.HasExited -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
    $process.Dispose(); foreach ($event in $events) { $event.Dispose() }
}
