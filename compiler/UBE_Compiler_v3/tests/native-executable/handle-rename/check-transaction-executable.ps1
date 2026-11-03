param([Parameter(Mandatory=$true)][string] $Probe, [Parameter(Mandatory=$true)][string] $Wrapper,
      [Parameter(Mandatory=$true)][string] $Inspector, [Parameter(Mandatory=$true)][string] $Executable,
      [Parameter(Mandatory=$true)][string] $ObjectFile, [Parameter(Mandatory=$true)][string] $DllFile,
      [Parameter(Mandatory=$true)][string] $OutputDirectory, [string] $Malformed, [string] $StructuralProbe,
      [string] $MalformedDirectory, [string] $ZeroCode)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$probePath=(Resolve-Path -LiteralPath $Probe).Path; $wrapperPath=(Resolve-Path -LiteralPath $Wrapper).Path
$inspectorPath=(Resolve-Path -LiteralPath $Inspector).Path
if ($StructuralProbe) { $structuralPath=(Resolve-Path -LiteralPath $StructuralProbe).Path }
$fixtures=@{ normal=(Resolve-Path -LiteralPath $Executable).Path; swap=(Resolve-Path -LiteralPath $Executable).Path;
             object=(Resolve-Path -LiteralPath $ObjectFile).Path; dll=(Resolve-Path -LiteralPath $DllFile).Path }
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$cases=@('normal','swap','object','dll')
if ($Malformed) {
    $fixtures.malformed=(Resolve-Path -LiteralPath $Malformed).Path
    $malformedBytes=[IO.File]::ReadAllBytes($fixtures.malformed)
    if ($malformedBytes.Length -lt 64) { throw 'Malformed control lacks DOS header' }
    $peOffset=[long][BitConverter]::ToUInt32($malformedBytes,0x3c)
    if ($peOffset+24 -gt $malformedBytes.Length -or [BitConverter]::ToUInt32($malformedBytes,[int]$peOffset) -ne 0x4550 -or [BitConverter]::ToUInt16($malformedBytes,[int]($peOffset+20)) -ge 112) { throw 'Malformed control does not have the expected short PE32+ optional header' }
    $cases+='malformed'
}
if ($MalformedDirectory) {
    if (-not $StructuralProbe) { throw 'MalformedDirectory requires StructuralProbe' }
    $inputDirectory=(Resolve-Path -LiteralPath $MalformedDirectory).Path
    foreach ($name in @('zero-entry','outside-entry','outside-section','oversized-section','short-dos','offset-outside','section-count-overflow','optional-short','directory-count-overflow')) {
        $key='malformed-' + $name; $fixtures[$key]=(Resolve-Path -LiteralPath (Join-Path $inputDirectory ($name + '.exe'))).Path; $cases+=$key
    }
}
if ($ZeroCode) {
    if (-not $StructuralProbe) { throw 'ZeroCode requires StructuralProbe' }
    $fixtures['zero-code']=(Resolve-Path -LiteralPath $ZeroCode).Path
    $image=[IO.File]::ReadAllBytes($fixtures['zero-code']); $baseline=[IO.File]::ReadAllBytes($fixtures.normal)
    if ($image.Length -ne $baseline.Length) { throw 'Zero-code fixture length differs from valid baseline' }
    $pe=[long][BitConverter]::ToUInt32($image,0x3c)
    if ($pe+24 -gt $image.Length) { throw 'Zero-code fixture has invalid PE offset' }
    $optional=$pe+24; $entry=[long][BitConverter]::ToUInt32($image,[int]($optional+16))
    $table=$optional+[BitConverter]::ToUInt16($image,[int]($pe+20)); $count=[BitConverter]::ToUInt16($image,[int]($pe+6)); $checked=$false
    for ($i=0;$i -lt $count;$i++) {
        $section=$table+40*$i; if ($section+40 -gt $image.Length) { throw 'Zero-code section table exceeds file' }
        $virtual=[long][BitConverter]::ToUInt32($image,[int]($section+12)); $size=[long][BitConverter]::ToUInt32($image,[int]($section+16)); $raw=[long][BitConverter]::ToUInt32($image,[int]($section+20))
        $flags=[BitConverter]::ToUInt32($image,[int]($section+36))
        if (($flags -band 0x20000000) -ne 0 -and $entry -ge $virtual -and $entry-$virtual -lt $size) {
            if ($raw+$size -gt $image.Length) { throw 'Zero-code section exceeds file' }
            $changed=$false
            for ($j=0;$j -lt $image.Length;$j++) {
                if ($j -ge $raw -and $j -lt $raw+$size) { if ($image[$j] -ne 0) { throw 'Entry section is not zeroed' }; if ($baseline[$j] -ne 0) { $changed=$true } }
                elseif ($image[$j] -ne $baseline[$j]) { throw 'Zero-code fixture differs outside the entry section' }
            }
            if (-not $changed) { throw 'Zero-code mutation did not change the valid baseline' }
            $checked=$true; break
        }
    }
    if (-not $checked) { throw 'No zeroed executable entry section found' }
    $cases+='zero-code'
}
foreach ($case in $cases) {
    $directory=Join-Path $root $case; [IO.Directory]::CreateDirectory($directory) | Out-Null
    $candidate=Join-Path $directory 'candidate.bin'; $moved=Join-Path $directory 'inspected.bin'; $destination=Join-Path $directory 'destination.bin'
    [IO.File]::Copy($fixtures[$case],$candidate); $fixtureHash=(Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
    [IO.File]::WriteAllText($destination,'old'); [IO.File]::WriteAllText((Join-Path $directory 'protected.bin'),'protected')
    $id=[guid]::NewGuid().ToString('N'); $names=@('ready','release','closed-ready','closed-release','inspect-ready','inspect-release') | ForEach-Object { 'Local\UBE-tx-executable-' + $_ + '-' + $id }
    $events=@($names | ForEach-Object { [Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::ManualReset,$_) })
    $process=[Diagnostics.Process]::new(); $started=$false
    try {
        $process.StartInfo.FileName=$probePath
        $process.StartInfo.Arguments='"' + $directory + '" ' + ($names -join ' ') + ' "' + $wrapperPath + '" "' + $inspectorPath + '"'
        if ($StructuralProbe) { $process.StartInfo.Arguments+=' "' + $structuralPath + '"' }
        $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
        $process.StartInfo.RedirectStandardError=$true; $process.StartInfo.RedirectStandardOutput=$true
        if (-not $process.Start()) { throw 'Probe did not start' }; $started=$true
        if ($case -in @('object','dll') -or ($case -like 'malformed*' -and $StructuralProbe)) {
            if (-not $process.WaitForExit(10000)) { throw 'Invalid candidate probe timed out' }
            $stderr=$process.StandardError.ReadToEnd(); $stdout=$process.StandardOutput.ReadToEnd()
            $expectedExit=if ($StructuralProbe) { 12 } else { 11 }
            $expectedError=if ($StructuralProbe) { 'structural inspection failed' } else { 'executable inspection failed' }
            if ($process.ExitCode -ne $expectedExit -or $stderr -notmatch $expectedError -or $stdout -match 'external inspection succeeded' -or
                [IO.File]::ReadAllText($destination) -ne 'old' -or (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -ne $fixtureHash) { throw "$case candidate was not rejected safely: $stdout $stderr" }
            Write-Output "${case}: invalid artifact rejected; old output and candidate preserved."
            continue
        }
        if (-not $events[4].WaitOne(10000)) { throw 'Successful inspection barrier not reached' }
        if ($case -eq 'swap') { [IO.File]::Move($candidate,$moved); [IO.File]::WriteAllText($candidate,'substitute') }
        $events[5].Set() | Out-Null
        if ($case -in @('normal','malformed','zero-code')) {
            if (-not $events[0].WaitOne(5000)) { throw 'Transaction handoff did not succeed' }
            $events[1].Set() | Out-Null
            if (-not $events[2].WaitOne(5000)) { throw 'Precommit barrier not reached' }
            $events[3].Set() | Out-Null
        }
        if (-not $process.WaitForExit(10000)) { throw 'Probe timed out' }
        $stdout=$process.StandardOutput.ReadToEnd(); $stderr=$process.StandardError.ReadToEnd()
        if ($StructuralProbe -and $stdout -notmatch 'structural inspection succeeded') { throw 'Structural inspection was not confirmed' }
        if ($case -in @('normal','malformed','zero-code')) {
            if ($process.ExitCode -ne 0 -or $stdout -notmatch 'external inspection succeeded' -or $stdout -notmatch 'inspected candidate identity matched' -or
                (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $fixtureHash) { throw "Normal executable handoff failed: $stdout $stderr" }
        } else {
            if ($process.ExitCode -eq 0 -or $stdout -notmatch 'external inspection succeeded' -or $stderr -notmatch 'candidate identity mismatch' -or
                [IO.File]::ReadAllText($destination) -ne 'old' -or (Get-FileHash -LiteralPath $moved -Algorithm SHA256).Hash -ne $fixtureHash -or
                [IO.File]::ReadAllText($candidate) -ne 'substitute') { throw "Executable swap was not rejected: $stdout $stderr" }
        }
        if ($case -eq 'malformed') { Write-Output 'Adverse control: header-only inspector accepted and published the supplied malformed candidate.' }
        elseif ($case -eq 'zero-code') { Write-Output 'Adverse control: structural and header checks accepted and published a zeroed entry section.' }
        else { Write-Output "${case}: exit=$($process.ExitCode); inspector and identity observations checked." }
    } finally {
        $events[1].Set() | Out-Null; $events[3].Set() | Out-Null; $events[5].Set() | Out-Null
        if ($started -and -not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit() }
        $process.Dispose(); foreach ($event in $events) { $event.Dispose() }
    }
}
Write-Output "Test-owned artifacts: $root"
