param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$reader = (Resolve-Path -LiteralPath $Readobj).Path
$source = Join-Path $PSScriptRoot 'stack-call-footprint.c'
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$rows = @()
foreach ($frameBytes in @(32,8192)) {
    foreach ($debug in @($false,$true)) {
        $stem = Join-Path $root "frame-$frameBytes-$debug"
        $debugFlags = @(if ($debug) { '-g'; '-gdwarf-4' } else { '-g0' })
        & $clangPath --target=x86_64-w64-windows-gnu -O2 @debugFlags -std=c17 -Wall -Wextra -Werror "-DFRAME_BYTES=$frameBytes" -S -emit-llvm $source -o "$stem.ll"
        if ($LASTEXITCODE -ne 0) { throw 'Footprint IR generation failed' }
        & $clangPath --target=x86_64-w64-windows-gnu -O2 -mno-incremental-linker-compatible -Xclang -llvm-verify-each -fstack-usage -c -x ir "$stem.ll" -o "$stem.o"
        if ($LASTEXITCODE -ne 0) { throw 'Footprint object generation failed' }
        $usage = [IO.File]::ReadAllText("$stem.su")
        $matches = [regex]::Matches($usage, '(?m):descend\s+(\d+)\s+static\s*$')
        if ($matches.Count -ne 1) { throw 'Missing or ambiguous static frame report' }
        $ownFrame = [uint64]$matches[0].Groups[1].Value
        if ($ownFrame -lt $frameBytes -or $ownFrame -gt 1048576) { throw 'Unexpected test frame size' }
        $unwind = @(& $reader --unwind "$stem.o") -join "`n"
        if ($LASTEXITCODE -ne 0) { throw 'Unwind reader failed' }
        [IO.File]::WriteAllText("$stem.unwind.txt", $unwind)
        $blocks = [regex]::Matches($unwind, '(?s)RuntimeFunction \{\s*StartAddress: descend \([^\n]*\).*?UnwindCodes \[([^\]]*)\]')
        if ($blocks.Count -ne 1) { throw 'Missing or ambiguous recursive unwind record' }
        $sum = [uint64]0
        foreach ($line in ($blocks[0].Groups[1].Value -split "`n")) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            if ($line -match '^\s*0x[0-9A-Fa-f]+: ALLOC_(?:SMALL|LARGE) size=(\d+)\s*$') { $sum += [uint64]$Matches[1] }
            elseif ($line -match '^\s*0x[0-9A-Fa-f]+: PUSH_NONVOL reg=[A-Z0-9]+\s*$') { $sum += 8 }
            else { throw "Unsupported unwind operation in this fixed-frame fixture: $line" }
        }
        if ($sum -ne $ownFrame) { throw 'Unwind allocation differs from stack-usage report' }
        $objectHash = (Get-FileHash -LiteralPath "$stem.o").Hash
        foreach ($omitReturn in @($false,$true)) {
            $expected = if ($omitReturn) { $ownFrame } else { $ownFrame + 8 }
            $table = "$stem-$omitReturn-table.c"
            [IO.File]::WriteAllText($table, "const unsigned long long required_call_bytes = ${expected}ULL;", [Text.UTF8Encoding]::new($false))
            & $clangPath --target=x86_64-w64-windows-gnu -O2 -c $table -o "$stem-$omitReturn-table.o"
            if ($LASTEXITCODE -ne 0) { throw 'Footprint table compilation failed' }
            $exe = "$stem-$omitReturn.exe"
            & $clangPath --target=x86_64-w64-windows-gnu "$stem.o" "$stem-$omitReturn-table.o" '-Wl,--no-insert-timestamp' -o $exe
            if ($LASTEXITCODE -ne 0) { throw 'Footprint link failed' }
            $process = [Diagnostics.Process]::new()
            $process.StartInfo.FileName = $exe
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.CreateNoWindow = $true
            $process.StartInfo.RedirectStandardOutput = $true
            try {
                if (-not $process.Start()) { throw 'Footprint process did not start' }
                $read = $process.StandardOutput.ReadToEndAsync()
                if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Footprint process timed out' }
                $output = $read.Result.Trim()
                $status = $process.ExitCode
                $wantedStatus = if ($omitReturn) { 1 } else { 0 }
                $actual = $ownFrame + 8
                if ($status -ne $wantedStatus -or $output -cne "call-bytes=$actual expected=$expected entries=2 unwound=2") { throw "Wrong footprint observation: status=$status $output" }
            } finally { $process.Dispose() }
            if ((Get-FileHash -LiteralPath "$stem.o").Hash -ne $objectHash) { throw 'Measured object changed' }
            $rows += [pscustomobject]@{ frameBytes=$frameBytes; debug=$debug; ownFrame=$ownFrame; unwindAllocation=$sum; actualCallBytes=$actual; suppliedCallBytes=$expected; status=$status; objectHash=$objectHash }
            Write-Output "frame=$frameBytes debug=$debug omit-return=$omitReturn : $output; exit=$status"
        }
    }
}
$identities = @($clangPath,$reader,$source,$PSCommandPath) | ForEach-Object { [pscustomobject]@{ path=$_; sha256=(Get-FileHash -LiteralPath $_).Hash } }
[pscustomobject]@{ identities=$identities; rows=$rows } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $root 'report.json') -Encoding UTF8
Write-Output "Test-owned footprint evidence: $root"
