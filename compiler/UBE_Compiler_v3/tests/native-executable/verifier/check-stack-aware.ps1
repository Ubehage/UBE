param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [switch] $CommitThread)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-guard-aware.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
foreach ($optimization in @('0','2')) {
  foreach ($committed in @($false,$true)) {
    foreach ($mutated in @($false,$true)) {
        $exe = Join-Path $OutputDirectory ("stack-aware-$optimization-$committed-$mutated-$CommitThread.exe")
        $flags = @(if ($mutated) { '-DIGNORE_FRAME_CONTROL' })
        if ($CommitThread) { $flags += '-DTHREAD_COMMIT_CONTROL' }
        $linker = @()
        if ($committed) { $flags += '-DCOMMITTED_STACK_CONTROL'; $linker = @('-Xlinker','--stack','-Xlinker','262144,262144') }
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -fstack-usage -Wall -Wextra -Werror @flags $source @linker -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Frame-aware probe compilation failed' }
        if ($committed -and -not $mutated) {
            $report = [IO.File]::ReadAllText([IO.Path]::ChangeExtension($exe, '.su'))
            foreach ($function in @('can_enter','observe_regions','worker')) {
                $match = [regex]::Match($report, '(?m):' + $function + '\s+(\d+)\s+static\s*$')
                if (-not $match.Success -or [int]$match.Groups[1].Value -gt 2048) { throw "Unexpected $function test frame report" }
                Write-Output "O$optimization committed=True $function frame=$($match.Groups[1].Value)"
            }
        }
        $output = @(& (Resolve-Path -LiteralPath $exe).Path); $status = $LASTEXITCODE
        if ($mutated) {
            if ($status -ne 1 -or $output.Count -ne 0) { throw 'Missing-frame control was not rejected' }
            Write-Output "O$optimization committed=$committed : missing-frame control rejected"
        } else {
            $refusedEarly = $committed -and $output.Count -eq 1 -and $output[0] -match '^committed guard refused before recursion: available=\d+ state=\d+ protect=\d+ reserved=\d+ committed=\d+ guarded=\d+$'
            $match = if ($output.Count -eq 1) { [regex]::Match($output[0], '^frame-aware test refused a larger frame and unwound (\d+) smaller frames$') } else { $null }
            $validRun = $match -and $match.Success -and [int]$match.Groups[1].Value -ge 2 -and [int]$match.Groups[1].Value -lt 192
            if ($status -ne 0 -or $output.Count -ne 1 -or (-not $refusedEarly -and -not $validRun)) { throw "Frame-aware probe failed: $status $output" }
            Write-Output "O$optimization committed=$committed : $($output[0])"
        }
    }
  }
}
