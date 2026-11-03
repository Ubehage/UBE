param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $OutputDirectory, [ValidateSet('native-relative', 'native-posix')][string] $Mode = 'native-relative')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../verifier/preservation-snapshot.ps1')
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($guarded in @($false, $true)) {
    $directory = Join-Path $root ([string]$guarded)
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate = Join-Path $directory 'candidate.bin'
    $destination = Join-Path $directory 'destination.bin'
    $protected = Join-Path $directory 'protected.bin'
    $editorReplacement = Join-Path $directory 'editor-save.bin'
    $editorBackup = Join-Path $directory 'editor-backup.bin'
    [IO.File]::WriteAllText($candidate, 'candidate')
    [IO.File]::WriteAllText($destination, 'old')
    [IO.File]::WriteAllText($protected, 'protected')
    Set-Content -LiteralPath $protected -Stream 'ube-preservation-test' -Value 'source stream' -NoNewline
    $id = [guid]::NewGuid().ToString('N')
    $readyName = 'Local\UBE-input-ready-' + $id
    $releaseName = 'Local\UBE-input-release-' + $id
    $ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
    $release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
    $process = [Diagnostics.Process]::new()
    $held = $null
    try {
        if ($guarded) {
            $held = [IO.File]::Open($protected, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
            $denied = $false
            try { [IO.File]::Move($protected, (Join-Path $directory 'protected-moved.bin')) } catch [IO.IOException] { $denied = $true }
            if (-not $denied) { throw 'Guard did not block a move of the protected original name' }
        }
        $process.StartInfo.FileName = $probePath
        $process.StartInfo.Arguments = '"' + $directory + '" ' + $Mode + ' ' + $readyName + ' ' + $releaseName
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardError = $true
        if (-not $process.Start() -or -not $ready.WaitOne(10000)) { throw 'Probe did not reach the race point' }
        [IO.File]::Move($destination, (Join-Path $directory 'prior.bin'))
        New-Item -ItemType HardLink -Path $destination -Target $protected | Out-Null
        if ($guarded) {
            $userWriter = [IO.File]::Open($protected, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
            try {
                $userBytes = [Text.Encoding]::UTF8.GetBytes('edited by user')
                $userWriter.SetLength(0)
                $userWriter.Write($userBytes, 0, $userBytes.Length)
                $userWriter.Flush()
            } finally { $userWriter.Dispose() }
            if ([IO.File]::ReadAllText($protected) -cne 'edited by user') { throw 'User edit did not take effect' }
            [IO.File]::WriteAllText($editorReplacement, 'saved by replacement')
            $replaceDenied = $false
            try { [IO.File]::Replace($editorReplacement, $protected, $editorBackup) }
            catch [IO.IOException] { $replaceDenied = $true }
            if (-not $replaceDenied -or [IO.File]::ReadAllText($protected) -cne 'edited by user' -or
                [IO.File]::ReadAllText($editorReplacement) -cne 'saved by replacement') {
                throw 'Guarded editor replacement produced an unexpected result'
            }
        }
        $before = Snapshot $protected
        if ([PreservationIdentity]::Read($destination) -ne $before.Identity) {
            throw 'Substituted destination is not the protected file'
        }
        foreach ($field in @('Hash', 'Creation', 'LastWrite', 'Attributes', 'Security', 'Identity', 'Stream')) {
            $changed = $before.Clone()
            if ($field -in @('Creation', 'LastWrite', 'Attributes')) { $changed[$field] = $changed[$field] + 1 }
            else { $changed[$field] = [string]$changed[$field] + '-changed' }
            if (Same $before $changed) { throw "Snapshot comparator ignored $field" }
        }
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(10000)) { throw 'Probe timed out' }
        $status = $process.ExitCode
        $err = $process.StandardError.ReadToEnd().Trim()
        $after = Snapshot $protected
        if (-not (Same $before $after)) { throw 'Protected input snapshot changed' }
        if ($guarded) {
            if ($status -eq 1 -and [IO.File]::ReadAllText($destination) -eq 'edited by user' -and [IO.File]::ReadAllText($candidate) -eq 'candidate') {
                Write-Output "Guarded hardlink substitution preserved: $err"
            } elseif ($status -eq 0 -and [IO.File]::ReadAllText($destination) -eq 'candidate' -and -not [IO.File]::Exists($candidate)) {
                Write-Output 'Guarded input retained the user edit; its substituted hardlink was replaced.'
            } else { throw "Unexpected guarded outcome: $status $err" }
        } else {
            if ($status -ne 0 -or [IO.File]::ReadAllText($destination) -ne 'candidate' -or [IO.File]::Exists($candidate)) { throw "Unexpected control outcome: $status $err" }
            Write-Output 'Unguarded hardlink substitution was replaced.'
        }
    } finally {
        $release.Set() | Out-Null
        if ($process.Id -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); $ready.Dispose(); $release.Dispose()
        if ($held) { $held.Dispose() }
    }
    if ($guarded) {
        [IO.File]::Replace($editorReplacement, $protected, $editorBackup)
        if ([IO.File]::ReadAllText($protected) -cne 'saved by replacement') { throw 'Editor replacement did not work after guard release' }
        Write-Output 'Editor replacement was blocked during the guard and succeeded after release.'
    }
}
