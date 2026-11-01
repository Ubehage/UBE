$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8 = [Text.UTF8Encoding]::new($false)
$run = Join-Path $root ('bootstrap/out/docs-checks/' + [guid]::NewGuid().ToString('N'))
$inputDirectory = Join-Path $run 'input'
[IO.Directory]::CreateDirectory($inputDirectory) | Out-Null
$tutorial = [IO.File]::ReadAllText((Join-Path $root 'docs/learn/first-program.html'))
$blocks = [regex]::Matches($tutorial, '(?s)<pre><code>(.*?)</code></pre>')
if ($blocks.Count -lt 2) { throw 'Tutorial source/project blocks missing.' }
$source = [Net.WebUtility]::HtmlDecode($blocks[0].Groups[1].Value)
$project = [Net.WebUtility]::HtmlDecode($blocks[1].Groups[1].Value)
$sourcePath = Join-Path $inputDirectory 'Main.bas'
$projectPath = Join-Path $inputDirectory 'Greeting.UBE'
[IO.File]::WriteAllText($sourcePath, $source, $utf8)
[IO.File]::WriteAllText($projectPath, $project, $utf8)
$binary = Join-Path $root 'bootstrap/out/v3/ube.exe'
$binaryHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $binary).Hash
$checks = [Collections.Generic.List[object]]::new()
function Assert-Command([string] $Name, [string] $Arguments, [int] $ExpectedExit, [string] $ExpectedOutput) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $binary
    $info.Arguments = $Arguments
    $info.WorkingDirectory = $root
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($info)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(30000)) { $process.Kill(); $process.Dispose(); throw "Timed out: $Name" }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $exitCode = $process.ExitCode
    $process.Dispose()
    # Match the maintained CLI gate's Windows CRLF-to-LF normalization while
    # retaining raw captured output in the report.
    $normalizedStdout = $stdout.Replace("`r`n", "`n")
    $normalizedStderr = $stderr.Replace("`r`n", "`n")
    $passed = $exitCode -eq $ExpectedExit -and $normalizedStdout -ceq ($ExpectedOutput + "`n") -and $normalizedStderr -ceq ''
    $checks.Add([ordered]@{ Name=$Name; Arguments=$Arguments; ExpectedExit=$ExpectedExit; ExitCode=$exitCode; Stdout=$stdout; Stderr=$stderr; Passed=$passed })
    if (-not $passed) { throw "CLI mismatch: $Name (exit $exitCode, stdout $stdout, stderr $stderr)" }
}
$boundary = 'error UBE1012: source checking is not implemented'
Assert-Command 'native tutorial source' "--check `"$sourcePath`"" 1 $boundary
Assert-Command 'tutorial project default jobs' "--check `"$projectPath`"" 1 $boundary
Assert-Command 'tutorial project four jobs' "--check `"$projectPath`" --jobs 4" 1 $boundary
Assert-Command 'project invalid jobs' "--check `"$projectPath`" --jobs 5" 2 'usage: ube --check <project.UBE> [--jobs N] (N: 1..4)'
Assert-Command 'jobs unavailable for source-only command' "--check `"$sourcePath`" --jobs 1" 2 'usage: ube --check <source-file>'
$files = @(Get-ChildItem -LiteralPath $inputDirectory -File)
if ($files.Count -ne 2 -or @($files | Where-Object Extension -notin '.bas','.UBE').Count -ne 0) { throw 'Checker created an unexpected output file.' }

# Compare all declaration lines on the five new API family pages with intact
# production UBE source, ignoring only whitespace and intrinsic introducers.
$sourceBodies = (Get-ChildItem (Join-Path $root 'std-lib/src/portable') -Filter '*.bas' | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
$sourceBodies = [regex]::Replace($sourceBodies, '\b(?:Public|Private|Intrinsic)\s+', '')
$sourceBodies = [regex]::Replace($sourceBodies, '_\s*\r?\n', ' ')
$normalizedSource = [regex]::Replace($sourceBodies, '\s+', ' ')
$declarations = [Collections.Generic.HashSet[string]]::new()
foreach ($page in @('byte-buffer','utf8','file-paths','thread-status','foundation-utilities')) {
    $html = [IO.File]::ReadAllText((Join-Path $root "docs/library/$page.html"))
    foreach ($block in [regex]::Matches($html, '(?s)<pre><code>(.*?)</code></pre>')) {
        $code = [Net.WebUtility]::HtmlDecode($block.Groups[1].Value)
        foreach ($match in [regex]::Matches($code, '(?m)^(?:Function|Sub) [^\r\n]+')) {
            $signature = [regex]::Replace($match.Value.Trim(), '\s+', ' ')
            if (-not $normalizedSource.Contains($signature)) { throw "Documented declaration missing from source: $signature" }
            $null = $declarations.Add($signature)
        }
    }
}
if ($declarations.Count -ne 35) { throw "Expected 35 distinct API declarations; found $($declarations.Count)." }
$report = [ordered]@{
    Binary=$binary; BinarySha256=$binaryHash; Tutorial='docs/learn/first-program.html'
    ProcessChecks=$checks; NoProgramOutput=$true; SourceMatchedDeclarations=$declarations.Count
    SourceSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash
    ManifestSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $projectPath).Hash
    Scope='Exact CLI output/exit behavior after maintained CRLF-to-LF normalization, and declaration spelling only; not semantic checking, program execution, library qualification or browser interaction.'
}
$reportPath = Join-Path $run 'report.json'
[IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 8), $utf8)
Write-Host "Passed five exact CLI cases, no output program, and $($declarations.Count) source-matched API declarations."
Write-Host "Binary SHA256: $binaryHash"
Write-Host "Report: $reportPath"
