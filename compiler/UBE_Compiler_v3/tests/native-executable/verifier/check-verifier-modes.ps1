param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
foreach ($optimization in @('0','2')) {
    foreach ($verify in @($false,$true)) {
        foreach ($fixture in @('valid','invalid-dominance')) {
            $inputFile = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "$fixture.ll")).Path
            $outputFile = Join-Path $directory "$optimization-$verify-$fixture.o"
            $process = [Diagnostics.Process]::new()
            $process.StartInfo.FileName = $clangPath
            $process.StartInfo.Arguments = '--target=x86_64-w64-windows-gnu -O' + $optimization + ' -Wno-override-module ' +
                $(if ($verify) { '-Xclang -llvm-verify-each ' } else { '' }) + '-c -x ir "' + $inputFile + '" -o "' + $outputFile + '"'
            $process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
            $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
            if (-not $process.Start()) { throw 'Clang did not start' }
            try {
                $out = $process.StandardOutput.ReadToEndAsync(); $err = $process.StandardError.ReadToEndAsync()
                if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Clang timed out' }
                $errorText = $err.Result; $null = $out.Result
                $hasObject = [IO.File]::Exists($outputFile)
                if ($fixture -eq 'valid' -and ($process.ExitCode -ne 0 -or -not $hasObject)) { throw "Valid fixture failed: $errorText" }
                if ($fixture -eq 'invalid-dominance' -and $verify -and ($process.ExitCode -eq 0 -or $errorText -notmatch 'Instruction does not dominate all uses')) { throw "Verifier control failed: $errorText" }
                Write-Output "O$optimization verify=$verify $fixture : status=$($process.ExitCode) object=$hasObject dominance-diagnostic=$($errorText -match 'Instruction does not dominate all uses')"
            } finally { $process.Dispose() }
        }
    }
}
Write-Output "Observed files: $directory"
