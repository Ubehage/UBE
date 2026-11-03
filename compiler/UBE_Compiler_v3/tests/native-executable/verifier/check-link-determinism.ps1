param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [Parameter(Mandatory=$true)][string] $Readobj)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$readobjPath = (Resolve-Path -LiteralPath $Readobj).Path
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'link-determinism.c')).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$target = Join-Path $directory 'candidate.exe'
foreach ($mode in @('default','no-timestamp','debug-default','debug-no-timestamp')) {
    $saved = @()
    foreach ($iteration in @(1,2)) {
        $flags = @(
            if ($mode -like '*no-timestamp') { '-Wl,--no-insert-timestamp' }
            if ($mode -like 'debug-*') { '-g' }
        )
        & $clangPath --target=x86_64-w64-windows-gnu -std=c17 -O2 @flags $source -o $target
        if ($LASTEXITCODE -ne 0) { throw "Build failed: $mode $iteration" }
        $process = [Diagnostics.Process]::Start($target)
        if (-not $process.WaitForExit(5000)) { $process.Kill(); $process.WaitForExit(); throw 'Control timed out' }
        if ($process.ExitCode -ne 7) { throw 'Executable control returned the wrong value' }
        $process.Dispose()
        $copy = Join-Path $directory "$mode-$iteration.exe"
        [IO.File]::Copy($target, $copy)
        if ($mode -like 'debug-*') {
            $sections = @(& $readobjPath --sections $copy 2>&1)
            if ($LASTEXITCODE -ne 0 -or ($sections -join "`n") -notmatch 'Name: \.debug_info' -or ($sections -join "`n") -notmatch 'Name: \.debug_line') { throw 'Expected debug sections missing' }
        }
        $bytes = [IO.File]::ReadAllBytes($copy)
        $offset = [BitConverter]::ToUInt32($bytes, 0x3c)
        if ($offset + 12 -gt $bytes.Length -or [BitConverter]::ToUInt32($bytes, [int]$offset) -ne 0x4550) { throw 'Bad PE header' }
        $saved += ,@{ path=$copy; hash=(Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash; timestamp=[BitConverter]::ToUInt32($bytes, [int]$offset+8); bytes=$bytes }
        if ($iteration -eq 1) { Start-Sleep -Seconds 2 }
    }
    if ($saved[0].bytes.Length -ne $saved[1].bytes.Length) { $difference = -1 }
    else {
        $difference = 0
        for ($i=0; $i -lt $saved[0].bytes.Length; $i++) { if ($saved[0].bytes[$i] -ne $saved[1].bytes[$i]) { $difference++ } }
    }
    if ($mode -like '*no-timestamp' -and ($saved[0].timestamp -ne 0 -or $saved[1].timestamp -ne 0)) { throw 'Requested timestamp suppression did not produce zero timestamps' }
    Write-Output "$mode : timestamps=$($saved[0].timestamp),$($saved[1].timestamp); equal=$($saved[0].hash -eq $saved[1].hash); differing-bytes=$difference; hashes=$($saved[0].hash),$($saved[1].hash)"
}
Write-Output "Test-owned artifacts: $directory"
