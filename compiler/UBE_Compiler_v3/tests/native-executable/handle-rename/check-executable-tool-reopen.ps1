param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Inspector,
      [Parameter(Mandatory=$true)][string] $Executable, [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [string] $StalledInspector, [string] $DescendantInspector, [string] $LateMarkerInspector, [string] $NulMarkerInspector, [string] $ObjectFile, [string] $DllFile, [string] $JunctionGuard)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../verifier/preservation-snapshot.ps1')
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$clangPath = (Resolve-Path -LiteralPath $Inspector).Path
$fixture = (Resolve-Path -LiteralPath $Executable).Path
$fixtureHash = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$cases = @('normal', 'absent', 'appeared', 'invalid-appeared', 'late-appeared', 'late-alias', 'late-alias-guarded', 'parent-swap', 'input-original', 'input-original-unguarded', 'swap', 'reader', 'invalid', 'invalid-absent', 'locked', 'readonly')
if ($StalledInspector) { $stalledPath = (Resolve-Path -LiteralPath $StalledInspector).Path; $cases += 'timeout' }
if ($DescendantInspector) { $descendantPath = (Resolve-Path -LiteralPath $DescendantInspector).Path; $cases += 'descendant' }
if ($LateMarkerInspector) { $lateMarkerPath = (Resolve-Path -LiteralPath $LateMarkerInspector).Path; $cases += 'late-marker' }
if ($NulMarkerInspector) { $nulMarkerPath = (Resolve-Path -LiteralPath $NulMarkerInspector).Path; $cases += 'nul-marker' }
if ($ObjectFile) { $objectPath = (Resolve-Path -LiteralPath $ObjectFile).Path; $objectHash = (Get-FileHash -LiteralPath $objectPath -Algorithm SHA256).Hash; $cases += 'object' }
if ($DllFile) { $dllPath = (Resolve-Path -LiteralPath $DllFile).Path; $dllHash = (Get-FileHash -LiteralPath $dllPath -Algorithm SHA256).Hash; $cases += 'dll' }
if ($JunctionGuard) { $junctionGuardPath = (Resolve-Path -LiteralPath $JunctionGuard).Path; $cases += 'parent-guarded'; $cases += 'parent-guarded-alias'; $cases += 'parent-guarded-original'; $cases += 'parent-guarded-ancestor' }
foreach ($case in $cases) {
    $swap = $case -eq 'swap'
    $directory = Join-Path $root $case
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $selectedDirectory = $directory
    if ($case -in @('parent-swap', 'parent-guarded', 'parent-guarded-alias', 'parent-guarded-original', 'parent-guarded-ancestor')) {
        $alternate = Join-Path $root "$case-alternate-parent"
        [IO.Directory]::CreateDirectory($alternate) | Out-Null
        [IO.File]::WriteAllText((Join-Path $alternate 'published.exe'), 'alternate output')
        $selectedDirectory = Join-Path $root "$case-selected-parent"
        if ($case -eq 'parent-guarded-ancestor') {
            $ancestor = Join-Path $root "$case-ancestor"
            [IO.Directory]::CreateDirectory($ancestor) | Out-Null
            $selectedDirectory = Join-Path $ancestor 'selected'
        }
        New-Item -ItemType Junction -Path $selectedDirectory -Target $directory | Out-Null
    }
    $candidate = Join-Path $directory 'candidate.exe'
    $old = Join-Path $directory 'published.exe'
    if ($case -in @('late-alias', 'late-alias-guarded', 'parent-guarded-alias')) { $protected = Join-Path $directory 'protected-input.bin'; [IO.File]::WriteAllText($protected, 'protected'); Set-Content -LiteralPath $protected -Stream 'ube-preservation-test' -Value 'source stream' -NoNewline }
    if ($case -notin @('absent', 'invalid-absent', 'appeared', 'invalid-appeared', 'late-appeared', 'late-alias', 'late-alias-guarded')) { [IO.File]::WriteAllText($old, 'old') }
    if ($case -in @('input-original', 'input-original-unguarded', 'parent-guarded-original')) { Set-Content -LiteralPath $old -Stream 'ube-preservation-test' -Value 'source stream' -NoNewline }
    if ($case -in @('invalid', 'invalid-absent', 'invalid-appeared')) { [IO.File]::WriteAllText($candidate, 'not an executable') }
    elseif ($case -eq 'object') { [IO.File]::Copy($objectPath, $candidate) }
    elseif ($case -eq 'dll') { [IO.File]::Copy($dllPath, $candidate) }
    else { [IO.File]::Copy($fixture, $candidate) }
    $id = [guid]::NewGuid().ToString('N')
    $readyName = 'Local\UBE-tool-reopen-ready-' + $id; $releaseName = 'Local\UBE-tool-reopen-release-' + $id
    $ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
    $release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
    $commitReadyName = 'Local\UBE-commit-ready-' + $id; $commitReleaseName = 'Local\UBE-commit-release-' + $id
    $commitReady = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $commitReadyName)
    $commitRelease = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $commitReleaseName)
    $junctionReadyName = 'Local\UBE-parent-ready-' + $id; $junctionReleaseName = 'Local\UBE-parent-release-' + $id
    $junctionReady = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $junctionReadyName)
    $junctionRelease = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $junctionReleaseName)
    $junctionProcess = $null
    $junctionStarted = $false
    $process = [Diagnostics.Process]::new()
    $processStarted = $false
    $guard = $null
    try {
        if ($case -in @('parent-guarded', 'parent-guarded-alias', 'parent-guarded-original', 'parent-guarded-ancestor')) {
            $junctionProcess = [Diagnostics.Process]::new()
            $junctionProcess.StartInfo.FileName = $junctionGuardPath
            $junctionProcess.StartInfo.Arguments = '"' + $selectedDirectory + '" ' + $junctionReadyName + ' ' + $junctionReleaseName
            $junctionProcess.StartInfo.UseShellExecute = $false; $junctionProcess.StartInfo.CreateNoWindow = $true
            $junctionStarted = $junctionProcess.Start()
            if (-not $junctionStarted -or -not $junctionReady.WaitOne(5000)) { throw 'Junction guard did not start' }
        }
        if ($case -eq 'locked') { $guard = [IO.File]::Open($old, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
        if ($case -in @('input-original', 'parent-guarded-original')) { $guard = [IO.File]::Open($old, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite); $protectedBefore = Snapshot $old }
        if ($case -eq 'input-original-unguarded') { $protectedBefore = Snapshot $old }
        if ($case -in @('late-alias-guarded', 'parent-guarded-alias')) { $guard = [IO.File]::Open($protected, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
        if ($case -eq 'reader') { $guard = [IO.File]::Open($old, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)) }
        if ($case -eq 'readonly') { [IO.File]::SetAttributes($old, [IO.FileAttributes]::ReadOnly) }
        $process.StartInfo.FileName = $probePath
        $selectedTool = if ($case -eq 'timeout') { $stalledPath } elseif ($case -eq 'descendant') { $descendantPath } elseif ($case -eq 'late-marker') { $lateMarkerPath } elseif ($case -eq 'nul-marker') { $nulMarkerPath } else { $clangPath }
        $process.StartInfo.Arguments = '"' + $selectedDirectory + '" "' + $selectedTool + '" ' + $readyName + ' ' + $releaseName
        if ($case -in @('late-appeared', 'late-alias', 'late-alias-guarded', 'parent-swap', 'parent-guarded', 'parent-guarded-alias', 'parent-guarded-original', 'parent-guarded-ancestor')) { $process.StartInfo.Arguments += ' ' + $commitReadyName + ' ' + $commitReleaseName }
        $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardError = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $processStarted = $process.Start()
        if (-not $processStarted -or -not $ready.WaitOne(5000)) { throw 'Probe not ready' }
        if ($case -in @('appeared', 'invalid-appeared')) { [IO.File]::WriteAllText($old, 'actor') }
        if ($swap) {
            $moved = Join-Path $directory 'moved.exe'
            [IO.File]::Move($candidate, $moved); [IO.File]::WriteAllText($candidate, 'not an executable')
            $blocked = $false
            try {
                $writer = [IO.File]::Open($moved, [IO.FileMode]::Open, [IO.FileAccess]::Write, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
                $writer.Dispose()
            } catch [IO.IOException] { $blocked = $true }
            if (-not $blocked) { throw 'Guarded source allowed write access' }
        }
        $release.Set() | Out-Null
        if ($case -in @('late-appeared', 'late-alias', 'late-alias-guarded', 'parent-swap', 'parent-guarded', 'parent-guarded-alias', 'parent-guarded-original', 'parent-guarded-ancestor')) {
            if (-not $commitReady.WaitOne(10000)) { throw 'Probe did not reach precommit barrier' }
            if ($case -eq 'late-appeared') { [IO.File]::WriteAllText($old, 'actor') }
            elseif ($case -eq 'parent-swap') {
                [IO.Directory]::Move($selectedDirectory, (Join-Path $root "$case-moved-parent"))
                New-Item -ItemType Junction -Path $selectedDirectory -Target $alternate | Out-Null
            }
            elseif ($case -eq 'parent-guarded-ancestor') {
                $ancestorMoved = $true
                try { [IO.Directory]::Move($ancestor, (Join-Path $root "$case-moved-parent")) } catch [IO.IOException] { $ancestorMoved = $false }
                if ($ancestorMoved) {
                    [IO.Directory]::CreateDirectory($ancestor) | Out-Null
                    New-Item -ItemType Junction -Path $selectedDirectory -Target $alternate | Out-Null
                }
            }
            elseif ($case -in @('parent-guarded', 'parent-guarded-alias', 'parent-guarded-original')) {
                $denied = $false
                try { [IO.Directory]::Move($selectedDirectory, (Join-Path $root "$case-moved-parent")) } catch [IO.IOException] { $denied = $true }
                if (-not $denied) { throw 'Junction guard failed to block the move' }
                if ($case -eq 'parent-guarded-alias') {
                    [IO.File]::Move($old, (Join-Path $directory 'actor-prior.exe'))
                    New-Item -ItemType HardLink -Path $old -Target $protected | Out-Null
                    $protectedBefore = Snapshot $protected
                    if ([PreservationIdentity]::Read($old) -ne $protectedBefore.Identity) { throw 'Substituted output is not the protected input' }
                }
            }
            else {
                New-Item -ItemType HardLink -Path $old -Target $protected | Out-Null
                $protectedBefore = Snapshot $protected
                if ([PreservationIdentity]::Read($old) -ne $protectedBefore.Identity) { throw 'Substituted output is not the protected input' }
            }
            $commitRelease.Set() | Out-Null
        }
        if (-not $process.WaitForExit(15000)) { throw 'Probe timed out' }
        $stderr = $process.StandardError.ReadToEnd()
        $stdout = $process.StandardOutput.ReadToEnd()
        $published = Join-Path $directory 'published.exe'
        if ($case -in @('invalid', 'invalid-absent', 'invalid-appeared')) {
            if ($process.ExitCode -eq 0 -or ($case -eq 'invalid' -and [IO.File]::ReadAllText($published) -ne 'old') -or ($case -eq 'invalid-absent' -and [IO.File]::Exists($published)) -or ($case -eq 'invalid-appeared' -and [IO.File]::ReadAllText($published) -ne 'actor')) {
                throw 'Invalid guarded input was accepted or published'
            }
            continue
        }
        if ($case -eq 'timeout') {
            if ($process.ExitCode -eq 0 -or $stdout -match 'commit attempted' -or $stderr -notmatch 'timed out; child exit observed' -or [IO.File]::ReadAllText($published) -ne 'old' -or (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Timeout did not preserve old output and confirm child exit' }
            Write-Output 'Timeout case: child exit observed; old output and candidate preserved.'
            continue
        }
        if ($case -eq 'descendant') {
            $report = [IO.File]::ReadAllText((Join-Path $directory 'inspection.txt'))
            if ($process.ExitCode -eq 0 -or $stdout -notmatch 'inspector exit code: 0' -or $stdout -match 'commit attempted' -or $report -notmatch 'IMAGE_FILE_EXECUTABLE_IMAGE' -or $stderr -notmatch 'remaining job processes stopped before inspection acceptance' -or [IO.File]::ReadAllText($published) -ne 'old' -or (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Remaining inspector descendant was not stopped before publication' }
            Write-Output 'Inspector descendant stopped; old output and candidate preserved.'
            continue
        }
        if ($case -eq 'late-marker') {
            $report = [IO.File]::ReadAllText((Join-Path $directory 'inspection.txt'))
            $prefix = $report.Substring(0, 4096)
            if ($process.ExitCode -eq 0 -or $stdout -notmatch 'inspector exit code: 0' -or $stdout -match 'commit attempted' -or
                $stderr -notmatch 'candidate header rejected' -or $report.Length -le 4096 -or
                $prefix -notmatch 'Machine: IMAGE_FILE_MACHINE_AMD64' -or $prefix -notmatch 'IMAGE_FILE_EXECUTABLE_IMAGE' -or
                $prefix -notmatch 'ImageOptionalHeader \{' -or $prefix -notmatch 'Magic: 0x20B' -or $prefix -match 'IMAGE_FILE_DLL' -or
                $report -notmatch 'IMAGE_FILE_DLL' -or [IO.File]::ReadAllText($published) -ne 'old' -or
                (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Late disqualifying marker was not rejected before publication' }
            Write-Output 'Late DLL marker appeared beyond 4096 bytes; full report rejected before publication.'
            continue
        }
        if ($case -eq 'nul-marker') {
            $reportBytes = [IO.File]::ReadAllBytes((Join-Path $directory 'inspection.txt'))
            $reportText = [Text.Encoding]::ASCII.GetString($reportBytes)
            if ($process.ExitCode -eq 0 -or $stdout -notmatch 'inspector exit code: 0' -or $stdout -match 'commit attempted' -or
                $stderr -notmatch 'candidate header rejected' -or [Array]::IndexOf($reportBytes, [byte]0) -lt 0 -or
                $reportText -notmatch 'IMAGE_FILE_DLL' -or [IO.File]::ReadAllText($published) -ne 'old' -or
                (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'NUL marker control was not rejected before publication' }
            Write-Output 'Embedded NUL and later DLL marker rejected before publication.'
            continue
        }
        if ($case -eq 'object' -or $case -eq 'dll') {
            $expectedHash = if ($case -eq 'object') { $objectHash } else { $dllHash }
            if ($process.ExitCode -eq 0 -or $stdout -match 'commit attempted' -or $stderr -notmatch 'candidate header rejected' -or [IO.File]::ReadAllText($published) -ne 'old' -or (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $expectedHash) { throw "$case negative control was not rejected safely" }
            Write-Output "$case control rejected before commit; old output and candidate preserved."
            continue
        }
        if ($case -eq 'locked' -or $case -eq 'readonly') {
            if ($process.ExitCode -eq 0 -or $stdout -notmatch 'inspection succeeded' -or $stdout -notmatch 'commit attempted' -or $stderr -notmatch 'rename NTSTATUS:' -or [IO.File]::ReadAllText($published) -ne 'old' -or (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) {
                throw 'Locked destination was modified or candidate was lost'
            }
            Write-Output "${case} case: $($stderr.Trim())"
            continue
        }
        if ($case -in @('input-original', 'parent-guarded-original')) {
            if ($process.ExitCode -eq 0 -or $stdout -notmatch 'inspection succeeded' -or $stdout -notmatch 'commit attempted' -or
                $stderr -notmatch 'rename NTSTATUS:' -or -not (Same $protectedBefore (Snapshot $old)) -or
                (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) {
                throw 'Original input entry or candidate was modified'
            }
            if ($case -eq 'parent-guarded-original') {
                if (-not (Same $protectedBefore (Snapshot (Join-Path $selectedDirectory 'published.exe')))) { throw 'Selected original input changed' }
                $junctionRelease.Set() | Out-Null
                if (-not $junctionProcess.WaitForExit(5000) -or $junctionProcess.ExitCode -ne 0) { throw 'Junction guard did not close' }
                [IO.Directory]::Move($selectedDirectory, (Join-Path $root "$case-moved-parent"))
            }
            Write-Output 'Original input entry and candidate survived denied commit.'
            continue
        }
        if ($process.ExitCode -ne 0) { throw "Probe failed: $stderr" }
        if ((Get-FileHash -LiteralPath (Join-Path $directory 'observed.bin') -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Rewound full-file observation differed from independent fixture hash' }
        if ($case -eq 'normal') {
            if ($stdout -notmatch 'candidate position after inspection: ([0-9]+)') { throw 'Candidate position observation missing' }
            $position = [Int64]$Matches[1]
            if ($position -le 0 -or $stdout -notmatch 'unrewound read returned EOF' -or $stdout -notmatch 'rewound candidate and reread MZ') { throw 'Candidate position observation, EOF control or rewind failed' }
            $empty = Join-Path $directory 'unrewound.bin'
            [IO.File]::WriteAllBytes($empty, [byte[]]@())
            if ((Get-FileHash -LiteralPath $empty -Algorithm SHA256).Hash -eq $fixtureHash) { throw 'EOF negative control unexpectedly matched the full fixture' }
            Write-Output "Inspector left candidate position at $position bytes; unrewound read hit EOF and rewind succeeded."
        }
        if ((Get-FileHash -LiteralPath $published -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Published input differs' }
        if ($case -eq 'parent-swap') {
            if ([IO.File]::ReadAllText((Join-Path $selectedDirectory 'published.exe')) -cne 'alternate output') { throw 'Redirected selected path did not reach the alternate output' }
            Write-Output 'Adverse control: candidate committed in original directory while selected path pointed elsewhere.'
        }
        if ($case -eq 'parent-guarded-ancestor') {
            if ($ancestorMoved) {
                if ([IO.File]::ReadAllText((Join-Path $selectedDirectory 'published.exe')) -cne 'alternate output') { throw 'Redirected ancestor did not expose alternate output' }
                Write-Output 'Adverse control: ancestor move redirected the selected path despite the junction guard.'
            } elseif ((Get-FileHash -LiteralPath (Join-Path $selectedDirectory 'published.exe') -Algorithm SHA256).Hash -ne $fixtureHash) {
                throw 'Selected path lost the candidate despite a blocked ancestor move'
            }
            $junctionRelease.Set() | Out-Null
            if (-not $junctionProcess.WaitForExit(5000) -or $junctionProcess.ExitCode -ne 0) { throw 'Junction guard did not close' }
            if (-not $ancestorMoved) { [IO.Directory]::Move($ancestor, (Join-Path $root "$case-moved-parent")); Write-Output 'Ancestor move was blocked during guard and succeeded after release.' }
        }
        if ($case -in @('parent-guarded', 'parent-guarded-alias')) {
            if ((Get-FileHash -LiteralPath (Join-Path $selectedDirectory 'published.exe') -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Guarded selected path does not show candidate' }
            $junctionRelease.Set() | Out-Null
            if (-not $junctionProcess.WaitForExit(5000) -or $junctionProcess.ExitCode -ne 0) { throw 'Junction guard did not close' }
            [IO.Directory]::Move($selectedDirectory, (Join-Path $root "$case-moved-parent"))
            Write-Output 'Guarded parent move was blocked; selected path received the candidate; move succeeded after release.'
        }
        if ($case -eq 'input-original-unguarded') {
            if ([PreservationIdentity]::Read($published) -eq $protectedBefore.Identity) { throw 'Unguarded original-entry control did not replace the input identity' }
            Write-Output 'Unguarded control: original input entry was replaced.'
        }
        if ($case -in @('late-alias', 'late-alias-guarded', 'parent-guarded-alias')) {
            if (-not (Same $protectedBefore (Snapshot $protected))) { throw 'Protected peer snapshot changed' }
            if ($case -eq 'parent-guarded-alias' -and [IO.File]::ReadAllText((Join-Path $directory 'actor-prior.exe')) -cne 'old') { throw 'Actor-moved prior output changed' }
            Write-Output "$case : precommit hardlink replaced; original input snapshot preserved."
        }
        if ($case -eq 'reader') {
            $bytes = New-Object byte[] 3
            if ($guard.Read($bytes, 0, 3) -ne 3 -or [Text.Encoding]::ASCII.GetString($bytes) -ne 'old') { throw 'Held reader did not retain old bytes' }
        }
        if ($swap -and ([IO.File]::ReadAllText($candidate) -ne 'not an executable' -or [IO.File]::Exists($moved))) { throw 'Path substitution outcome wrong' }
    } finally {
        $release.Set() | Out-Null
        $commitRelease.Set() | Out-Null
        $junctionRelease.Set() | Out-Null
        if ($processStarted -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        if ($junctionStarted -and -not $junctionProcess.WaitForExit(10000)) { $junctionProcess.Kill(); $junctionProcess.WaitForExit() }
        if ($junctionProcess) { $junctionProcess.Dispose() }
        $process.Dispose(); $ready.Dispose(); $release.Dispose(); $commitReady.Dispose(); $commitRelease.Dispose()
        $junctionReady.Dispose(); $junctionRelease.Dispose()
        if ($guard) { $guard.Dispose() }
        if ($case -eq 'readonly' -and [IO.File]::Exists($old)) { [IO.File]::SetAttributes($old, [IO.FileAttributes]::Normal) }
    }
}
Write-Output "Inspected executable published in normal, absent, appeared, swap and reader cases; invalid input preserved old output, absence or actor output; locked and read-only cases preserved old output: $root"
