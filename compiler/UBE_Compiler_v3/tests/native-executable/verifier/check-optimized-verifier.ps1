param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
foreach ($debug in @($false, $true)) {
    foreach ($valid in @($true, $false)) {
        $inputFile = if ($valid) { 'valid.ll' } else { 'invalid-dominance.ll' }
        $inputPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot $inputFile)).Path
        $outputPath = Join-Path $root ("output-$debug-$valid.o")
        $process = [Diagnostics.Process]::new()
        try {
            $process.StartInfo.FileName = $clangPath
            $debugArg = if ($debug) { ' -g' } else { '' }
            $process.StartInfo.Arguments = "--target=x86_64-w64-windows-gnu -O2$debugArg -mno-incremental-linker-compatible -Xclang -llvm-verify-each -c -x ir `"$inputPath`" -o `"$outputPath`""
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.CreateNoWindow = $true
            $process.StartInfo.RedirectStandardOutput = $true
            $process.StartInfo.RedirectStandardError = $true
            if (-not $process.Start()) { throw 'Clang did not start' }
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Clang timed out' }
            $status = $process.ExitCode
            $null = $stdout.Result
            $diagnostics = $stderr.Result
            if ($valid) {
                if ($status -ne 0 -or -not [IO.File]::Exists($outputPath) -or (Get-Item -LiteralPath $outputPath).Length -eq 0) { throw "Valid IR failed: $diagnostics" }
            } else {
                if ($status -eq 0 -or $diagnostics -notmatch 'Instruction does not dominate all uses') { throw "Dominance control was not diagnosed: $diagnostics" }
            }
            Write-Output "O2 debug=$debug valid=$valid exit=$status"
        } finally { $process.Dispose() }
    }
}
