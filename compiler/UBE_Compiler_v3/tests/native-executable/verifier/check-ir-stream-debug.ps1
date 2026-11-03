param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $Objdump,
      [Parameter(Mandatory=$true)][string] $OutputDirectory, [switch] $Behavior, [switch] $MutateCalls, [switch] $NoDebug,
      [string] $Linker)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$clangPath = (Resolve-Path -LiteralPath $Clang).Path
$reader = (Resolve-Path -LiteralPath $Objdump).Path
$linkerArguments = @(if ($Linker) { '--ld-path=' + (Resolve-Path -LiteralPath $Linker).Path })
if ($MutateCalls -and -not $Behavior) { throw 'MutateCalls requires Behavior' }
$file = if ($Behavior) { 'behavior.c' } else { 'probe.c' }
$procedure = if ($Behavior) { 'double_observed' } else { 'double_value' }
$procedureLine = if ($MutateCalls) { 6 } elseif ($Behavior) { 8 } else { 3 }
$mainLine = if ($Behavior) { 14 } else { 7 }
$expectedExit = if ($MutateCalls) { 99 } else { 8 }
$source = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../debug-reader/$file")).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$ir = Join-Path $directory 'debug.ll'
$flags = @(if ($MutateCalls) { '-DMUTATE_CALLS' })
$debugFlag = if ($NoDebug) { '-g0' } else { '-g' }
& $clangPath --target=x86_64-w64-windows-gnu -O2 -gdwarf-4 $debugFlag @flags -S -emit-llvm $source -o $ir
if ($LASTEXITCODE -ne 0) { throw 'IR generation failed' }
$text = [IO.File]::ReadAllText($ir)
if ($NoDebug -and $text -match '!DILocation\(') { throw 'No-debug input has locations' }
if (-not $NoDebug -and ($text -notmatch '!DIFile\(' -or $text -notmatch '!DILocation\(' -or $text -notmatch [regex]::Escape($file))) { throw 'Input lacks required debug metadata' }
$pathObject = Join-Path $directory 'path.o'; $streamObject = Join-Path $directory 'stream.o'
& $clangPath --target=x86_64-w64-windows-gnu -O2 -mno-incremental-linker-compatible -Xclang -llvm-verify-each -c -x ir $ir -o $pathObject
if ($LASTEXITCODE -ne 0) { throw 'Path compile failed' }
$process = [Diagnostics.Process]::new()
$process.StartInfo.FileName = $clangPath
$process.StartInfo.Arguments = '--target=x86_64-w64-windows-gnu -O2 -mno-incremental-linker-compatible -Xclang -llvm-verify-each -c -x ir - -o "' + $streamObject + '"'
$process.StartInfo.UseShellExecute = $false; $process.StartInfo.CreateNoWindow = $true
$process.StartInfo.RedirectStandardInput = $true; $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
if (-not $process.Start()) { throw 'Clang did not start' }
$stream = [IO.File]::OpenRead($ir)
try {
    $out = $process.StandardOutput.ReadToEndAsync(); $err = $process.StandardError.ReadToEndAsync()
    $copy = $stream.CopyToAsync($process.StandardInput.BaseStream)
    if (-not $copy.Wait(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Input streaming timed out' }
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Clang timed out' }
    if ($process.ExitCode -ne 0 -or $stream.Position -ne $stream.Length -or -not [IO.File]::Exists($streamObject)) { throw "Stream compile failed: $($err.Result)" }
    $null = $out.Result
} finally {
    if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
    $stream.Dispose(); $process.Dispose()
}
function Matches-Source([string] $info, [string] $file, [string] $procedure, [int] $line) {
    return ($info -match ('DW_AT_name\s*:.*' + [regex]::Escape($file)) -and
        $info -match ('DW_AT_name\s*:.*\b' + [regex]::Escape($procedure) + '\b') -and
        $info -match ('(?m)^' + [regex]::Escape($file) + '\s+' + $line + '\s+(?:0|0x[0-9a-f]+)(?:\s|$)'))
}
function Matches-FunctionLine([string] $info, [string] $disassembly, [string] $procedure, [int] $line) {
    $symbols = [regex]::Matches($disassembly, '(?m)^([0-9a-f]+) <([^>]+)>:\s*$')
    for ($i=0; $i+1 -lt $symbols.Count; $i++) {
        if ($symbols[$i].Groups[2].Value -cne $procedure) { continue }
        $start = [Convert]::ToInt64($symbols[$i].Groups[1].Value,16)
        $end = [Convert]::ToInt64($symbols[$i+1].Groups[1].Value,16)
        if ($end -le $start) { return $false }
        foreach ($row in [regex]::Matches($info, '(?m)^' + [regex]::Escape($file) + '\s+' + $line + '\s+0x([0-9a-f]+)')) {
            $address = [Convert]::ToInt64($row.Groups[1].Value,16)
            if ($address -ge $start -and $address -lt $end) { return $true }
        }
    }
    return $false
}
foreach ($object in @($pathObject,$streamObject)) {
    $output = @(& $reader --dwarf=info,decodedline $object 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Debug reader failed: $output" }
    $info = $output -join "`n"
    if ($NoDebug) {
        if (Matches-Source $info $file $procedure $procedureLine) { throw 'No-debug object has source records' }
    } elseif (-not (Matches-Source $info $file $procedure $procedureLine) -or (Matches-Source $info 'wrong.c' $procedure $procedureLine) -or (Matches-Source $info $file 'wrong_procedure' $procedureLine) -or (Matches-Source $info $file $procedure 999)) { throw 'Debug source comparison or wrong-value control failed' }
    $exe = [IO.Path]::ChangeExtension($object, '.exe')
    & $clangPath --target=x86_64-w64-windows-gnu @linkerArguments $object '-Wl,--no-insert-timestamp' '-Wl,--subsystem,console' -o $exe
    if ($LASTEXITCODE -ne 0) { throw 'Link failed' }
    $child = [Diagnostics.Process]::Start($exe)
    try {
        if (-not $child.WaitForExit(10000)) { $child.Kill(); $child.WaitForExit(); throw 'Linked control timed out' }
        if ($child.ExitCode -ne $expectedExit) { throw "Wrong linked result: $($child.ExitCode)" }
    } finally { $child.Dispose() }
    $linkedInfo = @(& $reader --dwarf=info,decodedline $exe 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Linked debug reader failed' }
    $disassembly = @(& $reader -d $exe 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'Disassembly failed' }
    if ($NoDebug -and (Matches-Source $linkedInfo $file $procedure $procedureLine)) { throw 'No-debug executable has source records' }
    if (-not $NoDebug -and (-not (Matches-Source $linkedInfo $file $procedure $procedureLine) -or
        -not (Matches-FunctionLine $linkedInfo $disassembly $procedure $procedureLine) -or
        -not (Matches-FunctionLine $linkedInfo $disassembly 'main' $mainLine) -or
        (Matches-FunctionLine $linkedInfo $disassembly 'main' $procedureLine) -or
        (Matches-FunctionLine $linkedInfo $disassembly $procedure $mainLine) -or
        (Matches-FunctionLine $linkedInfo $disassembly $procedure 999) -or
        (Matches-FunctionLine $linkedInfo $disassembly 'wrong_procedure' $procedureLine))) { throw 'Linked debug mapping or wrong-value control failed' }
}
$a = (Get-FileHash -LiteralPath $pathObject -Algorithm SHA256).Hash
$b = (Get-FileHash -LiteralPath $streamObject -Algorithm SHA256).Hash
Write-Output "Path and stdin IR builds passed debug=$(-not $NoDebug), behavior=$Behavior, mutation=$MutateCalls; result=$expectedExit; object hashes equal=$($a -eq $b). $directory"
