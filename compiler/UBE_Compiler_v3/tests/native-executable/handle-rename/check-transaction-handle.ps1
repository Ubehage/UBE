param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($case in @('uncontended','candidate-swap','protected-alias','reader','preexisting-alias')) {
    $directory=Join-Path $root $case; [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate=Join-Path $directory 'candidate.bin'; $moved=Join-Path $directory 'moved.bin'; $destination=Join-Path $directory 'destination.bin'
    [IO.File]::WriteAllText($candidate,'candidate'); [IO.File]::WriteAllText($destination,'old'); [IO.File]::WriteAllText((Join-Path $directory 'protected.bin'),'protected')
    if ($case -eq 'preexisting-alias') { [IO.File]::Delete($destination); New-Item -ItemType HardLink -Path $destination -Target (Join-Path $directory 'protected.bin') | Out-Null }
    if ($case -eq 'candidate-swap') { [IO.File]::Move($candidate,$moved); [IO.File]::Move($moved,$candidate) }
    if ($case -eq 'reader') {
        foreach ($share in @([IO.FileShare]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))) {
            $control=[IO.File]::Open($destination,[IO.FileMode]::Open,[IO.FileAccess]::Read,$share); $control.Dispose()
        }
    }
    if ($case -eq 'protected-alias') {
        [IO.File]::Move($destination,$moved); [IO.File]::Move($moved,$destination)
        $link=Join-Path $directory 'link-control.bin'
        New-Item -ItemType HardLink -Path $link -Target (Join-Path $directory 'protected.bin') | Out-Null
        [IO.File]::Delete($link)
    }
    $id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release') | ForEach-Object { 'Local\UBE-tx-handle-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $process=[Diagnostics.Process]::new()
    $readers=@(); $readerObservations=@()
    try {
        $process.StartInfo.FileName=$probePath; $process.StartInfo.Arguments='"' + $directory + '" ' + ($names -join ' ')
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
        $process.StartInfo.RedirectStandardError=$true; $process.StartInfo.RedirectStandardOutput=$true
        if (-not $process.Start()) { throw 'Probe did not start' }
        if (-not $events[0].WaitOne(5000)) {
            if (-not $process.WaitForExit(5000)) { throw 'Probe did not establish a guard or exit' }
            $errorText=$process.StandardError.ReadToEnd().Trim()
            if ($case -eq 'preexisting-alias') {
                if ($process.ExitCode -eq 0 -or $errorText -notmatch 'protected identity rejected' -or [IO.File]::ReadAllText($destination) -ne 'protected' -or [IO.File]::ReadAllText($candidate) -ne 'candidate') { throw "Preexisting alias not rejected: $errorText" }
                Write-Output 'Preexisting protected alias rejected; candidate preserved.'
            } else { Write-Output "${case}: guard unavailable, exit=$($process.ExitCode), stderr=$errorText" }
            continue
        }
        $events[1].Set() | Out-Null
        if (-not $events[2].WaitOne(5000)) { throw 'Closed-target barrier not reached' }
        $swapped=$false; $actorError=''
        if ($case -eq 'candidate-swap') {
            try { [IO.File]::Move($candidate,$moved); $swapped=$true } catch [IO.IOException] { $actorError=$_.Exception.Message }
            if ($swapped) { [IO.File]::WriteAllText($candidate,'substitute') }
        }
        if ($case -eq 'protected-alias') {
            try { [IO.File]::Move($destination,$moved); $swapped=$true } catch [IO.IOException] { $actorError=$_.Exception.Message }
            if ($swapped) { New-Item -ItemType HardLink -Path $destination -Target (Join-Path $directory 'protected.bin') | Out-Null }
        }
        if ($case -eq 'reader') {
            foreach ($share in @([IO.FileShare]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))) {
                try {
                    $reader=[IO.File]::Open($destination,[IO.FileMode]::Open,[IO.FileAccess]::Read,$share)
                    $buffer=New-Object byte[] 3
                    if ($reader.Read($buffer,0,3) -ne 3 -or [Text.Encoding]::ASCII.GetString($buffer) -ne 'old') { throw 'Reader did not see old bytes' }
                    $reader.Position=0; $readers+=,$reader; $readerObservations+= "share=$share opened-old"
                } catch [IO.IOException] {
                    $code='0x{0:X8}' -f ([uint32]([int64]$_.Exception.HResult -band 0xFFFFFFFFL))
                    $readerObservations+= "share=$share denied=$code"
                }
            }
        }
        $events[3].Set() | Out-Null
        if (-not $process.WaitForExit(10000)) { throw 'Probe timed out' }
        $stdout=$process.StandardOutput.ReadToEnd().Trim(); $stderr=$process.StandardError.ReadToEnd().Trim()
        $final=[IO.File]::ReadAllText($destination)
        if ($process.ExitCode -eq 0 -and $final -ne 'candidate') { throw 'Committed bytes do not match original candidate' }
        if ($process.ExitCode -ne 0 -and (($swapped -and $case -eq 'protected-alias' -and $final -ne 'protected') -or
            (-not ($swapped -and $case -eq 'protected-alias') -and $final -ne 'old'))) { throw 'Failed transaction changed destination' }
        if ($swapped -and $case -eq 'candidate-swap' -and [IO.File]::ReadAllText($candidate) -ne 'substitute') { throw 'Substitute path changed unexpectedly' }
        if ($swapped -and $case -eq 'protected-alias' -and $process.ExitCode -eq 0) { throw 'Transaction replaced a protected alias' }
        if ([IO.File]::ReadAllText((Join-Path $directory 'protected.bin')) -ne 'protected') { throw 'Protected peer bytes changed' }
        foreach ($reader in $readers) {
            $buffer=New-Object byte[] 3
            if ($reader.Read($buffer,0,3) -ne 3 -or [Text.Encoding]::ASCII.GetString($buffer) -ne 'old') { throw 'Held reader did not retain old bytes' }
        }
        Write-Output "${case}: swapped=$swapped actor-error=$actorError status=$($process.ExitCode) destination=$final stdout=$stdout stderr=$stderr"
        if ($case -eq 'reader') { Write-Output ("Reader observations: " + ($readerObservations -join '; ')) }
    } finally {
        $events[1].Set() | Out-Null; $events[3].Set() | Out-Null
        if (-not $process.HasExited -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); foreach ($reader in $readers) { $reader.Dispose() }; foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "Test-owned artifacts: $root"
