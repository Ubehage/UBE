param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-guard-aware.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
  $normalOutputs = @{}
  foreach ($debug in @($false,$true)) {
    $stem = Join-Path $OutputDirectory ("linked-guard-$optimization-$debug")
    $debugFlags = @(if ($debug) { '-g' })
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" @debugFlags -Wall -Wextra -Werror -DUSE_LINKED_FRAME -S -emit-llvm $source -o "$stem.ll"
    if ($LASTEXITCODE -ne 0) { throw 'Guard IR generation failed' }
    & $Clang --target=x86_64-w64-windows-gnu "-O$optimization" @debugFlags -fno-lto -fstack-usage -c -x ir "$stem.ll" -o "$stem.o"
    if ($LASTEXITCODE -ne 0) { throw 'Guard object generation failed' }
    $report = [IO.File]::ReadAllText("$stem.su")
    $entry = [regex]::Match($report, '(?m):descend\s+(\d+)\s+static\s*$')
    if (-not $entry.Success) { throw 'Recursive frame report missing' }
    $ownFrame = [long]$entry.Groups[1].Value
    if ($ownFrame -lt 8192 -or $ownFrame -gt 1048576) { throw 'Recursive frame outside test bounds' }
    # This target's static report excludes the call's eight-byte return address.
    $frame = $ownFrame + 8
    $hash = (Get-FileHash -LiteralPath "$stem.o" -Algorithm SHA256).Hash
    foreach ($wrong in @($false,$true)) {
        $value = if ($wrong) { 1 } else { $frame }
        $table = "$stem-table-$wrong.c"; $tableObject = "$stem-table-$wrong.o"; $exe = "$stem-$wrong.exe"
        Set-Content -LiteralPath $table -Encoding Ascii -Value "const unsigned long long required_frame = ${value}ULL;"
        & $Clang --target=x86_64-w64-windows-gnu "-O$optimization" -fno-lto -c $table -o $tableObject
        if ($LASTEXITCODE -ne 0) { throw 'Metadata object generation failed' }
        $description = (& $Readobj --symbols --sections $tableObject) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Metadata object inspection failed' }
        $symbol = [regex]::Matches($description, '(?m)^\s*Name: required_frame\s*\n\s*Value: 0\s*\n\s*Section: \.rdata \((\d+)\)')
        if ($symbol.Count -ne 1) { throw 'Expected unique metadata symbol missing' }
        $sectionNumber = $symbol[0].Groups[1].Value
        $sectionPattern = '(?m)^\s*Number: ' + $sectionNumber + '\s*\n\s*Name: \.rdata[^\n]*\n\s*VirtualSize:[^\n]*\n\s*VirtualAddress:[^\n]*\n\s*RawDataSize: (\d+)\s*\n\s*PointerToRawData: 0x([0-9A-Fa-f]+)'
        $section = [regex]::Matches($description, $sectionPattern)
        if ($section.Count -ne 1 -or [long]$section[0].Groups[1].Value -ne 8) { throw 'Unexpected metadata section' }
        $offset = [Convert]::ToInt64($section[0].Groups[2].Value, 16)
        $bytes = [IO.File]::ReadAllBytes($tableObject)
        if ($offset -lt 0 -or $offset -gt $bytes.Length - 8) { throw 'Metadata section is outside object' }
        $actualValue = [BitConverter]::ToUInt64($bytes, [int]$offset)
        $accepted = $actualValue -eq [uint64]$frame
        if ($accepted -eq $wrong) { throw 'Metadata comparison did not distinguish correct and understated values' }
        & $Clang --target=x86_64-w64-windows-gnu "-O$optimization" -fno-lto "$stem.o" $tableObject -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Guard test link failed' }
        $linkedDescription = (& $Readobj --symbols --sections $exe) -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Linked image inspection failed' }
        if ($debug -and $linkedDescription -notmatch '(?m)^\s*Name: \.debug_info\s') { throw 'Debug information section missing from linked image' }
        $linkedSymbols = [regex]::Matches($linkedDescription, '(?m)^\s*Name: required_frame\s*\n\s*Value: (\d+)\s*\n\s*Section: \.rdata \((\d+)\)')
        if ($linkedSymbols.Count -ne 1) { throw 'Linked metadata symbol missing or ambiguous' }
        $symbolOffset = [long]$linkedSymbols[0].Groups[1].Value
        $linkedSectionNumber = $linkedSymbols[0].Groups[2].Value
        $linkedSectionPattern = '(?m)^\s*Number: ' + $linkedSectionNumber + '\s*\n\s*Name: \.rdata[^\n]*\n\s*VirtualSize:[^\n]*\n\s*VirtualAddress:[^\n]*\n\s*RawDataSize: (\d+)\s*\n\s*PointerToRawData: 0x([0-9A-Fa-f]+)'
        $linkedSection = [regex]::Matches($linkedDescription, $linkedSectionPattern)
        if ($linkedSection.Count -ne 1 -or $symbolOffset -gt [long]$linkedSection[0].Groups[1].Value - 8) { throw 'Linked metadata is outside its section' }
        $imageOffset = [Convert]::ToInt64($linkedSection[0].Groups[2].Value, 16) + $symbolOffset
        $image = [IO.File]::ReadAllBytes($exe)
        if ($imageOffset -lt 0 -or $imageOffset -gt $image.Length - 8) { throw 'Linked metadata is outside image' }
        $linkedValue = [BitConverter]::ToUInt64($image, [int]$imageOffset)
        if ($linkedValue -ne $actualValue -or (($linkedValue -eq [uint64]$frame) -eq $wrong)) { throw 'Linked metadata comparison failed' }
        $output = @(& (Resolve-Path -LiteralPath $exe).Path)
        if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1 -or $output[0] -notmatch '^frame-aware test refused a larger frame and unwound ([2-9]|[1-5][0-9]|6[0-3]) smaller frames$') { throw 'Guard test did not unwind' }
        if ($debug) {
            if ($output[0] -ne $normalOutputs[$wrong]) { throw 'Debug and non-debug observations differ' }
        } else { $normalOutputs[$wrong] = $output[0] }
        if ((Get-FileHash -LiteralPath "$stem.o" -Algorithm SHA256).Hash -ne $hash) { throw 'Measured object changed' }
        Write-Output "O$optimization debug=$debug own-frame=$ownFrame call-bytes=$frame metadata=$value object-and-image-accepted=$accepted : $($output[0])"
    }
  }
}
