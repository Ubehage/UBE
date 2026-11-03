param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Wrapper,
      [Parameter(Mandatory=$true)][string] $Inspector, [Parameter(Mandatory=$true)][string] $Executable,
      [Parameter(Mandatory=$true)][string] $OutputDirectory, [switch] $Absent, [switch] $CheckMetadata,
      [switch] $CorruptMetadata)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($Absent -and $CheckMetadata) { throw 'Metadata checks require an existing output' }
if ($CorruptMetadata -and -not $CheckMetadata) { throw 'Metadata corruption requires metadata checks' }
if ($CheckMetadata) { . (Join-Path $PSScriptRoot '../verifier/preservation-snapshot.ps1') }
$probePath=(Resolve-Path -LiteralPath $Probe).Path; $wrapperPath=(Resolve-Path -LiteralPath $Wrapper).Path
$inspectorPath=(Resolve-Path -LiteralPath $Inspector).Path; $fixture=(Resolve-Path -LiteralPath $Executable).Path
$fixtureHash=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
function Confirm-Absent([string] $path) {
    try {
        $file=[IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $file.Dispose(); return $false
    } catch [IO.FileNotFoundException] { return $true }
}
$cases=@('before-rename-kill','after-rename-kill','rollback','commit')
if ($Absent) { $cases+='actor-create' }
foreach ($case in $cases) {
    $directory=Join-Path $root $case; [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate=Join-Path $directory 'candidate.bin'; $destination=Join-Path $directory 'destination.bin'
    [IO.File]::Copy($fixture,$candidate); if (-not $Absent) { [IO.File]::WriteAllText($destination,'old') }; [IO.File]::WriteAllText((Join-Path $directory 'protected.bin'),'protected')
    if ($CheckMetadata) {
        Set-Content -LiteralPath $destination -Stream 'ube-preservation-test' -Value 'original stream' -NoNewline
        [IO.File]::SetLastWriteTimeUtc($destination, [DateTime]::new(2020, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
        $before = Snapshot $destination
    }
    if ($Absent -and -not (Confirm-Absent $destination)) { throw 'Destination was not initially absent' }
    if ($case -eq 'actor-create') {
        $control=[IO.File]::Open($destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $control.Dispose(); [IO.File]::Delete($destination)
        if (-not (Confirm-Absent $destination)) { throw 'Actor creation control did not restore absence' }
    }
    $id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release','inspect-ready','inspect-release','staged-ready','staged-release') | ForEach-Object { 'Local\UBE-tx-rollback-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $process=[Diagnostics.Process]::new(); $started=$false
    try {
        $mode=if ($case -eq 'rollback') { 'rollback' } else { 'commit' }
        $process.StartInfo.FileName=$probePath
        $process.StartInfo.Arguments='"' + $directory + '" ' + (($names | Select-Object -First 6) -join ' ') + ' "' + $wrapperPath + '" "' + $inspectorPath + '" ' + ($names[6..7] -join ' ') + ' ' + $mode
        if ($Absent) { $process.StartInfo.Arguments+=' allow-absent' }
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
        $process.StartInfo.RedirectStandardError=$true; $process.StartInfo.RedirectStandardOutput=$true
        if (-not $process.Start()) { throw 'Probe did not start' }; $started=$true
        if (-not $events[4].WaitOne(10000)) { throw 'Inspection barrier not reached' }; $events[5].Set() | Out-Null
        if (-not $events[0].WaitOne(5000)) { throw 'Transaction guard was not established' }; $events[1].Set() | Out-Null
        if (-not $events[2].WaitOne(5000)) { throw 'Pre-rename barrier not reached' }
        if ($case -eq 'actor-create') {
            $blocked=$false; $actorError=''
            try {
                $actor=[IO.File]::Open($destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
                $actor.Dispose()
            } catch [IO.IOException] {
                $blocked=$true; $actorError='0x{0:X8}' -f ([uint32]([int64]$_.Exception.HResult -band 0xFFFFFFFFL))
            }
            if (-not $blocked) { throw 'Actor created the reserved output name' }
            Write-Output "actor-create: competing creation blocked=$actorError"
        }
        if ($case -eq 'before-rename-kill') { $process.Kill(); $process.WaitForExit() }
        else {
            $events[3].Set() | Out-Null
            if (-not $events[6].WaitOne(5000)) { throw 'Staged-rename barrier not reached' }
            if ($Absent) {
                if (-not (Confirm-Absent $destination)) { throw 'Staged destination was externally visible before commit' }
            } else {
                $reader=[IO.File]::Open($destination,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
                try {
                    $bytes=New-Object byte[] 4; $count=$reader.Read($bytes,0,$bytes.Length)
                    if ($count -ne 3 -or [Text.Encoding]::ASCII.GetString($bytes,0,$count) -ne 'old') { throw 'Staged transaction was externally visible before commit' }
                } finally { $reader.Dispose() }
            }
            if ($case -eq 'after-rename-kill') { $process.Kill(); $process.WaitForExit() }
            else { $events[7].Set() | Out-Null; if (-not $process.WaitForExit(10000) -or $process.ExitCode -ne 0) { throw 'Commit or rollback failed' } }
        }
        $stdout=$process.StandardOutput.ReadToEnd(); $stderr=$process.StandardError.ReadToEnd()
        if ($stdout -notmatch 'external inspection succeeded' -or $stdout -notmatch 'inspected candidate identity matched') { throw "Inspection evidence missing: $stdout $stderr" }
        if ($case -eq 'rollback' -and $stdout -notmatch 'transaction rollback succeeded') { throw 'Explicit rollback was not confirmed' }
        if ($case -in @('commit','actor-create') -and $stdout -notmatch 'transacted handle rename committed') { throw 'Commit was not confirmed' }
        $deadline=[Diagnostics.Stopwatch]::StartNew(); $observed=$false
        while ($deadline.ElapsedMilliseconds -lt 5000 -and -not $observed) {
            try {
                if ($case -in @('commit','actor-create')) { $observed = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -eq $fixtureHash -and -not [IO.File]::Exists($candidate) }
                elseif ($Absent) { $observed = (Confirm-Absent $destination) -and [IO.File]::Exists($candidate) -and (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -eq $fixtureHash }
                else { $observed = [IO.File]::ReadAllText($destination) -eq 'old' -and [IO.File]::Exists($candidate) -and (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -eq $fixtureHash }
            } catch [IO.IOException] { $observed=$false }
            if (-not $observed) { Start-Sleep -Milliseconds 20 }
        }
        if (-not $observed -or [IO.File]::ReadAllText((Join-Path $directory 'protected.bin')) -ne 'protected') { throw "Unexpected post-$case file state" }
        if ($CheckMetadata -and $case -notin @('commit','actor-create')) {
            if ($CorruptMetadata -and $case -eq 'rollback') {
                [IO.File]::SetLastWriteTimeUtc($destination, [DateTime]::new(2021, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
            }
            if (-not (Same $before (Snapshot $destination))) { throw "Output metadata changed after $case" }
        }
        Write-Output "${case}: expected post-transaction files observed."
    } finally {
        foreach ($n in @(1,3,5,7)) { $events[$n].Set() | Out-Null }
        if ($started -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "Test-owned artifacts: $root"
