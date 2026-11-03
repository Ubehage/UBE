param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [switch] $CompareRegions)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-error-live.c'
$runtime = 'bootstrap/runtime/bootstrap_runtime.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
  foreach ($debug in @($false,$true)) {
    foreach ($variant in @('good','WRONG_STACK_ERROR_CONTROL','WRONG_STACK_RESULT_CONTROL','OVERSIZED_STACK_FRAME_CONTROL')) {
        $stem = Join-Path $OutputDirectory "committed-error-$optimization-$debug-$variant"
        $flags = @('-DCOMMITTED_PAGE_GUARD','-DLINKED_STACK_FRAME')
        if ($CompareRegions) { $flags += @('-DSTACK_REGION_SCAN','-DCOMPARE_REGION_GUARD') }
        if ($debug) { $flags += '-g' }
        if ($variant -ne 'good') { $flags += "-D$variant" }
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -fno-lto -fstack-usage -Wall -Wextra -Werror @flags -c $source -o "$stem.o"
        if ($LASTEXITCODE -ne 0) { throw 'Guard object compilation failed' }
        $report = [IO.File]::ReadAllText("$stem.su")
        $entry = [regex]::Match($report, '(?m):descend\s+(\d+)\s+static\s*$')
        if (-not $entry.Success -or [long]$entry.Groups[1].Value -lt 8192 -or [long]$entry.Groups[1].Value -gt 1048576) { throw 'Static recursive-frame report missing or outside test bounds' }
        $ownFrame = [uint64]$entry.Groups[1].Value
        # Include the return address pushed by CALL, absent from this .su entry.
        $frame = $ownFrame + 8
        $metadata = if ($variant -eq 'OVERSIZED_STACK_FRAME_CONTROL') { [uint64]16777216 } else { $frame }
        if ($variant -eq 'OVERSIZED_STACK_FRAME_CONTROL' -and $metadata -le $frame) { throw 'Oversized frame control is not oversized' }
        $knownGuardFrames = 0
        foreach ($function in @('checked_call','has_space')) {
            $guardEntry = [regex]::Match($report, '(?m):' + $function + '\s+(\d+)\s+static\s*$')
            if (-not $guardEntry.Success) { throw "Static $function frame report missing" }
            $knownGuardFrames += [int]$guardEntry.Groups[1].Value + 8
        }
        $walkEntry = [regex]::Match($report, '(?m):stack_writable_floor\s+(\d+)\s+static\s*$')
        if ($walkEntry.Success) { $knownGuardFrames += [int]$walkEntry.Groups[1].Value + 8 }
        $regionEntry = [regex]::Match($report, '(?m):stack_writable_floor_regions\s+(\d+)\s+static\s*$')
        if ($regionEntry.Success) { $knownGuardFrames += [int]$regionEntry.Groups[1].Value + 8 }
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -fno-lto -fstack-usage -ffunction-sections -fdata-sections -c $runtime -o "$stem-runtime.o"
        if ($LASTEXITCODE -ne 0) { throw 'Runtime object compilation failed' }
        $runtimeReport = [IO.File]::ReadAllText("$stem-runtime.su")
        $errorEntry = [regex]::Match($runtimeReport, '(?m):ube_err_set\s+(\d+)\s+static\s*$')
        if (-not $errorEntry.Success) { throw 'Static error-setter frame report missing' }
        $knownGuardFrames += [int]$errorEntry.Groups[1].Value + 8
        $copyEntry = [regex]::Match($runtimeReport, '(?m):ube_error_copy_text\s+(\d+)\s+static\s*$')
        if ($copyEntry.Success) { $knownGuardFrames += [int]$copyEntry.Groups[1].Value + 8 }
        if ($knownGuardFrames -ge 65536) { throw 'Known reported helper frames exhaust the experimental reserve' }
        $objectHash = (Get-FileHash -LiteralPath "$stem.o").Hash
        $runtimeHash = (Get-FileHash -LiteralPath "$stem-runtime.o").Hash
        Set-Content -LiteralPath "$stem-frame.c" -Encoding Ascii -Value "const unsigned long long required_frame = ${metadata}ULL;"
        & $Clang --target=x86_64-w64-windows-gnu -fno-lto -c "$stem-frame.c" -o "$stem-frame.o"
        if ($LASTEXITCODE -ne 0) { throw 'Frame metadata compilation failed' }
        $description = (& $Readobj --symbols --sections "$stem-frame.o") -join "`n"
        $symbol = [regex]::Matches($description, '(?m)^\s*Name: required_frame\s*\n\s*Value: 0\s*\n\s*Section: \.rdata \((\d+)\)')
        if ($LASTEXITCODE -ne 0 -or $symbol.Count -ne 1) { throw 'Frame metadata symbol missing' }
        $sectionNumber = $symbol[0].Groups[1].Value
        $pattern = '(?m)^\s*Number: ' + $sectionNumber + '\s*\n\s*Name: \.rdata[^\n]*\n\s*VirtualSize:[^\n]*\n\s*VirtualAddress:[^\n]*\n\s*RawDataSize: (\d+)\s*\n\s*PointerToRawData: 0x([0-9A-Fa-f]+)'
        $section = [regex]::Matches($description, $pattern)
        if ($section.Count -ne 1 -or [int]$section[0].Groups[1].Value -ne 8) { throw 'Unexpected frame metadata section' }
        $offset = [Convert]::ToInt64($section[0].Groups[2].Value, 16)
        $bytes = [IO.File]::ReadAllBytes("$stem-frame.o")
        if ($offset -lt 0 -or $offset -gt $bytes.Length - 8 -or [BitConverter]::ToUInt64($bytes, [int]$offset) -ne $metadata -or [uint64]1 -eq $frame) { throw 'Frame metadata comparison failed' }
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -ffunction-sections -fdata-sections "$stem.o" "$stem-frame.o" "$stem-runtime.o" '-Wl,--gc-sections' -Xlinker --stack -Xlinker 262144,262144 -o "$stem.exe"
        if ($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath "$stem.o").Hash -ne $objectHash -or (Get-FileHash -LiteralPath "$stem-runtime.o").Hash -ne $runtimeHash) { throw 'Link failed or measured object changed' }
        $linked = (& $Readobj --symbols --sections "$stem.exe") -join "`n"
        $linkedSymbol = [regex]::Matches($linked, '(?m)^\s*Name: required_frame\s*\n\s*Value: (\d+)\s*\n\s*Section: \.rdata \((\d+)\)')
        if ($LASTEXITCODE -ne 0 -or $linkedSymbol.Count -ne 1) { throw 'Linked frame symbol missing or ambiguous' }
        $symbolOffset = [long]$linkedSymbol[0].Groups[1].Value
        $linkedNumber = $linkedSymbol[0].Groups[2].Value
        $linkedPattern = '(?m)^\s*Number: ' + $linkedNumber + '\s*\n\s*Name: \.rdata[^\n]*\n\s*VirtualSize:[^\n]*\n\s*VirtualAddress:[^\n]*\n\s*RawDataSize: (\d+)\s*\n\s*PointerToRawData: 0x([0-9A-Fa-f]+)'
        $linkedSection = [regex]::Matches($linked, $linkedPattern)
        if ($linkedSection.Count -ne 1 -or $symbolOffset -gt [long]$linkedSection[0].Groups[1].Value - 8) { throw 'Linked frame metadata is outside its section' }
        $imageOffset = [Convert]::ToInt64($linkedSection[0].Groups[2].Value, 16) + $symbolOffset
        $image = [IO.File]::ReadAllBytes("$stem.exe")
        if ($imageOffset -lt 0 -or $imageOffset -gt $image.Length - 8 -or [BitConverter]::ToUInt64($image, [int]$imageOffset) -ne $metadata) { throw 'Linked frame metadata differs from intended value' }
        $output = @(& (Resolve-Path -LiteralPath "$stem.exe").Path); $status = $LASTEXITCODE
        if ($variant -eq 'good') {
            if ($status -ne 0 -or $output.Count -ne 1 -or $output[0] -ne 'guarded recursion, argument effects and thread-local error passed') { throw "Guarded error run failed: $status $output" }
            if ($debug) {
                $sections = (& $Readobj --sections "$stem.exe") -join "`n"
                if ($LASTEXITCODE -ne 0 -or $sections -notmatch '(?m)^\s*Name: \.debug_info\s') { throw 'Debug section missing' }
            }
        } elseif ($variant -eq 'OVERSIZED_STACK_FRAME_CONTROL') {
            if ($status -ne 0 -or $output.Count -ne 1 -or $output[0] -ne 'oversized linked frame refused before entering callee') { throw "Oversized-frame control failed: $status $output" }
        } elseif ($status -ne 1) { throw "Error/result mutation was not rejected: $variant status=$status" }
        Write-Output "O$optimization debug=$debug variant=$variant own-frame=$ownFrame call-bytes=$frame metadata=$metadata known-helper-call-total=$knownGuardFrames status=$status"
    }
  }
}
