param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$readobj = (Resolve-Path -LiteralPath $Readobj).Path
$dir = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($dir) | Out-Null
$source = Join-Path $PSScriptRoot 'debug-version-reference.c'
$ir = Join-Path $dir 'valid.ll'
& $clang --target=x86_64-w64-windows-gnu -O2 -g -S -emit-llvm $source -o $ir
if ($LASTEXITCODE -ne 0) { throw 'Debug IR generation failed' }
$text = [IO.File]::ReadAllText($ir)
$changed = $text.Replace('!"Debug Info Version", i32 3', '!"Debug Info Version", i32 1')
if ($changed -ceq $text) { throw 'Expected debug metadata version not found' }
$bad = Join-Path $dir 'old-debug-version.ll'
[IO.File]::WriteAllText($bad, $changed)
foreach ($case in @(@($ir, 'valid'), @($bad, 'invalid-debug'))) {
    $output = Join-Path $dir ($case[1] + '.o')
    $process = [Diagnostics.Process]::new()
    try {
        $process.StartInfo.FileName = $clang
        $process.StartInfo.Arguments = "--target=x86_64-w64-windows-gnu -O2 -g -Xclang -llvm-verify-each -c -x ir `"$($case[0])`" -o `"$output`""
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.RedirectStandardError = $true
        if (-not $process.Start()) { throw 'Clang start failed' }
        $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Clang timed out' }
        $null = $stdout.Result; $diagnostic = $stderr.Result
        if ($process.ExitCode -ne 0 -or -not [IO.File]::Exists($output)) { throw "Compile failed: $diagnostic" }
        if ($case[1] -eq 'invalid-debug' -and $diagnostic -notmatch 'ignoring debug info') { throw "Missing debug-discard diagnostic: $diagnostic" }
        if ($case[1] -eq 'valid' -and $diagnostic -match 'ignoring debug info') { throw "Valid debug info discarded: $diagnostic" }
        Write-Output "$($case[1]): exit=$($process.ExitCode) diagnostic=$($diagnostic.Trim())"
    } finally { $process.Dispose() }
    $sections = @(& $readobj --sections $output) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Section inspection failed' }
    $hasInfo = $sections -match '(?m)^\s*Name: \.debug_info\b'
    $hasLine = $sections -match '(?m)^\s*Name: \.debug_line\b'
    if ($case[1] -eq 'valid' -and (-not $hasInfo -or -not $hasLine)) { throw 'Valid object lacks the expected debug sections' }
    if ($case[1] -eq 'invalid-debug' -and ($hasInfo -or $hasLine)) { throw 'Invalid-debug object unexpectedly contains inspected debug sections' }
    Write-Output "$($case[1]): debug_info=$hasInfo debug_line=$hasLine"
}
foreach ($strip in @($false, $true)) {
    $executable = Join-Path $dir ("linked-$strip.exe")
    $linkArgs = @('--target=x86_64-w64-windows-gnu', (Join-Path $dir 'valid.o'), '-o', $executable)
    if ($strip) { $linkArgs += '-Wl,--strip-debug' }
    & $clang @linkArgs
    if ($LASTEXITCODE -ne 0) { throw 'Link failed' }
    $sections = @(& $readobj --sections $executable) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Linked section inspection failed' }
    $hasInfo = $sections -match '(?m)^\s*Name: \.debug_info\b'
    $hasLine = $sections -match '(?m)^\s*Name: \.debug_line\b'
    if (-not $strip -and (-not $hasInfo -or -not $hasLine)) { throw 'Linked control lacks debug sections' }
    if ($strip -and ($hasInfo -or $hasLine)) { throw 'Stripped control retained debug sections' }
    & $executable
    if ($LASTEXITCODE -ne 7) { throw "Unexpected executable result: $LASTEXITCODE" }
    Write-Output "linked strip=$strip : exit=7 debug_info=$hasInfo debug_line=$hasLine"
}
Write-Output "Artifacts: $dir"
