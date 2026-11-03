param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Objdump, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$probePath = (Resolve-Path -LiteralPath $Probe).Path
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$objdumpPath = (Resolve-Path -LiteralPath $Objdump).Path
$fixture = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../verifier/valid.ll'))
$fixtureHash = (Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
foreach ($case in @('normal', 'swap', 'invalid')) {
    $swap = $case -eq 'swap'
    $directory = Join-Path $root $case
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate = Join-Path $directory 'candidate.ll'
    if ($case -eq 'invalid') { [IO.File]::WriteAllText($candidate, 'not LLVM IR') } else { [IO.File]::Copy($fixture, $candidate) }
    $id = [guid]::NewGuid().ToString('N')
    $readyName = 'Local\UBE-tool-reopen-ready-' + $id; $releaseName = 'Local\UBE-tool-reopen-release-' + $id
    $ready = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $readyName)
    $release = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::ManualReset, $releaseName)
    $process = [Diagnostics.Process]::new()
    try {
        $process.StartInfo.FileName = $probePath
        $process.StartInfo.Arguments = '"' + $directory + '" "' + $clangPath + '" ' + $readyName + ' ' + $releaseName
        $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardError = $true
        if (-not $process.Start() -or -not $ready.WaitOne(5000)) { throw 'Probe not ready' }
        if ($swap) {
            $moved = Join-Path $directory 'moved.ll'
            [IO.File]::Move($candidate, $moved); [IO.File]::WriteAllText($candidate, 'not LLVM IR')
            $blocked = $false
            try {
                $writer = [IO.File]::Open($moved, [IO.FileMode]::Open, [IO.FileAccess]::Write, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
                $writer.Dispose()
            } catch [IO.IOException] { $blocked = $true }
            if (-not $blocked) { throw 'Guarded source allowed write access' }
        }
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(15000)) { throw 'Probe timed out' }
        $stderr = $process.StandardError.ReadToEnd()
        $published = Join-Path $directory 'published.ll'
        if ($case -eq 'invalid') {
            if ($process.ExitCode -eq 0 -or [IO.File]::Exists($published) -or [IO.File]::Exists((Join-Path $directory 'output.o'))) {
                throw 'Invalid guarded input was accepted or published'
            }
            continue
        }
        if ($process.ExitCode -ne 0) { throw "Probe failed: $stderr" }
        if ((Get-FileHash -LiteralPath $published -Algorithm SHA256).Hash -ne $fixtureHash) { throw 'Published input differs' }
        if ($swap -and ([IO.File]::ReadAllText($candidate) -ne 'not LLVM IR' -or [IO.File]::Exists($moved))) { throw 'Path substitution outcome wrong' }
        $object = Join-Path $directory 'output.o'
        $inspection = @(& $objdumpPath -f $object 2>&1)
        if ($LASTEXITCODE -ne 0 -or ($inspection -join ' ') -notmatch 'file format') { throw "Object inspection failed: $inspection" }
    } finally {
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); $ready.Dispose(); $release.Dispose()
    }
}
Write-Output "Held input compiled and renamed in normal and swap cases; invalid input was rejected: $root"
