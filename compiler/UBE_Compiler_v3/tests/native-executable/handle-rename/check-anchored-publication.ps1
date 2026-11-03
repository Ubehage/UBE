param([Parameter(Mandatory=$true)][string] $Probe,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
function Assert-Owned([string] $Path) {
    $absolute=[IO.Path]::GetFullPath($Path)
    if (-not $absolute.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Test operation escaped its owned root' }
}
function Text-Is([string] $Path,[string] $Expected) {
    if (-not [IO.File]::Exists($Path) -or [IO.File]::ReadAllText($Path) -cne $Expected) { throw "Unexpected file contents: $Path" }
}
$results=@()
foreach ($case in @('success','absent','cancel','locked-output','late-ordinary','late-hardlink','source-edit','source-save','source-moved-to-output','initial-source-entry','initial-hardlink','ancestor-move','candidate-move','candidate-write','invalid-candidate','reparse-parent')) {
    $base=Join-Path $root $case; $ancestor=Join-Path $base 'ancestor'; $directory=Join-Path $ancestor 'parent'
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $source=Join-Path $directory 'protected.bin'; $candidate=Join-Path $directory 'candidate.bin'; $destination=Join-Path $directory 'destination.bin'
    $prior=Join-Path $directory 'prior.bin'
    $candidateText=if ($case -eq 'invalid-candidate') { 'bad bytes' } else { 'candidate' }
    [IO.File]::WriteAllText($source,'source'); [IO.File]::WriteAllText($candidate,$candidateText)
    if ($case -ne 'absent') { [IO.File]::WriteAllText($destination,'old') }
    $sourceLeaf='protected.bin'; $selected=$directory; $expectedExit=0
    if ($case -eq 'invalid-candidate') { $expectedExit=22 }
    if ($case -eq 'initial-source-entry') { $sourceLeaf='destination.bin'; $expectedExit=20 }
    if ($case -eq 'initial-hardlink') {
        [IO.File]::Delete($destination)
        New-Item -ItemType HardLink -Path $destination -Target $source | Out-Null
        $expectedExit=20
    }
    if ($case -eq 'reparse-parent') {
        $selected=Join-Path $base 'junction'
        New-Item -ItemType Junction -Path $selected -Target $directory | Out-Null
        $expectedExit=21
    }
    $id=[guid]::NewGuid().ToString('N'); $readyName='Local\UBE-publish-ready-'+$id; $releaseName='Local\UBE-publish-release-'+$id
    $ready=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$readyName)
    $release=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$releaseName)
    $process=[Diagnostics.Process]::new(); $started=$false; $lock=$null
    $mode=if ($case -eq 'cancel') { 'cancel' } else { 'commit' }
    if ($case -eq 'cancel') { $expectedExit=10 }
    if ($case -eq 'locked-output') { $expectedExit=1 }
    try {
        $process.StartInfo.FileName=$probePath
        $process.StartInfo.Arguments='"'+$selected+'" '+$sourceLeaf+' '+$readyName+' '+$releaseName+' '+$mode
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
        $process.StartInfo.RedirectStandardOutput=$true; $process.StartInfo.RedirectStandardError=$true
        if (-not $process.Start()) { throw 'Probe did not start' }; $started=$true
        $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
        $timer=[Diagnostics.Stopwatch]::StartNew(); $observedReady=$false
        while ($timer.ElapsedMilliseconds -lt 5000) {
            if ($ready.WaitOne(25)) { $observedReady=$true; break }
            if ($process.HasExited) { break }
        }
        if ($expectedExit -in @(20,21,22)) {
            if ($observedReady) { throw 'Rejected input reached publication barrier' }
        } else {
            if (-not $observedReady) {
                $detail=if ($process.HasExited) { "exit=$($process.ExitCode): $($stderr.Result)" } else { 'process still running' }
                throw "Publication barrier missing: $case ($detail)"
            }
            switch ($case) {
                'locked-output' { $lock=[IO.File]::Open($destination,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None) }
                'late-ordinary' { [IO.File]::Move($destination,$prior); [IO.File]::WriteAllText($destination,'interloper'); Text-Is $destination 'interloper' }
                'late-hardlink' { [IO.File]::Delete($destination); New-Item -ItemType HardLink -Path $destination -Target $source | Out-Null; Text-Is $destination 'source' }
                'source-edit' { [IO.File]::WriteAllText($source,'edited'); Text-Is $source 'edited' }
                'source-save' { [IO.File]::Move($source,$prior); [IO.File]::WriteAllText($source,'edited'); Text-Is $prior 'source'; Text-Is $source 'edited' }
                'source-moved-to-output' { [IO.File]::Delete($destination); [IO.File]::Move($source,$destination); Text-Is $destination 'source' }
                'ancestor-move' {
                    $moved=Join-Path $base 'moved'; Assert-Owned $ancestor; Assert-Owned $moved
                    $denied=$false
                    try { [IO.Directory]::Move($ancestor,$moved) } catch [IO.IOException] { $denied=$true }
                    if (-not $denied -or -not [IO.Directory]::Exists($ancestor)) { throw 'Held ancestor moved' }
                }
                'candidate-move' {
                    $denied=$false
                    try { [IO.File]::Move($candidate,$prior) } catch [IO.IOException] { $denied=$true }
                    if (-not $denied) { throw 'Inspected candidate name moved' }
                }
                'candidate-write' {
                    $denied=$false
                    try { [IO.File]::WriteAllText($candidate,'tampered!') } catch [IO.IOException] { $denied=$true }
                    if (-not $denied) { throw 'Inspected candidate bytes changed' }
                }
            }
        }
        $release.Set() | Out-Null
        if (-not $process.WaitForExit(10000)) { throw 'Publication probe timed out' }
        $out=$stdout.Result; $err=$stderr.Result
        if ($process.ExitCode -ne $expectedExit) { throw "${case}: expected $expectedExit, got $($process.ExitCode): $out $err" }
        if ($lock) { $lock.Dispose(); $lock=$null }
        if ($expectedExit -eq 0) {
            Text-Is $destination 'candidate'
            if ([IO.File]::Exists($candidate)) { throw 'Successful rename left candidate name' }
        } else {
            Text-Is $candidate $candidateText
            Text-Is $destination $(if ($case -eq 'initial-hardlink') { 'source' } else { 'old' })
        }
        if ($case -eq 'source-moved-to-output') {
            if ([IO.File]::Exists($source)) { throw 'Actor-relocated source entry unexpectedly restored' }
        } else { Text-Is $source $(if ($case -in @('source-edit','source-save')) { 'edited' } else { 'source' }) }
        if ($case -eq 'source-save') { Text-Is $prior 'source' }
        if ($case -eq 'late-ordinary') { Text-Is $prior 'old' }
        if ($case -eq 'ancestor-move') {
            Assert-Owned $ancestor; Assert-Owned $moved
            [IO.Directory]::Move($ancestor,$moved)
            Text-Is (Join-Path $moved 'parent/destination.bin') 'candidate'
        }
        $results+=[pscustomobject]@{name=$case;exit=$process.ExitCode;ready=$observedReady;stdout=$out;stderr=$err}
        Write-Output "${case}: exit=$expectedExit; output, candidate and source effects matched."
    } finally {
        $release.Set() | Out-Null
        if ($lock) { $lock.Dispose() }
        if ($started -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); $ready.Dispose(); $release.Dispose()
    }
}
$identities=@($probePath,$PSCommandPath,(Join-Path $PSScriptRoot 'anchored-publish.c')) | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash} }
[pscustomobject]@{identities=$identities;cases=$results} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'report.json') -Encoding UTF8
Write-Output "Publication evidence: $root"
