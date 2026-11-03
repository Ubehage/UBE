param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Objdump,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'stack-frame-probe.c'
$driver = Join-Path $PSScriptRoot 'stack-frame-driver.c'
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
function Check-Order([string] $dump) {
    $probe = $dump.IndexOf('___chkstk_ms', [StringComparison]::Ordinal)
    $guard = $dump.IndexOf('recursion_guard', [StringComparison]::Ordinal)
    $body = $dump.IndexOf('observe_frame', [StringComparison]::Ordinal)
    return $probe -ge 0 -and $guard -gt $probe -and $body -gt $guard
}
function Check-Caller([string] $dump) {
    $guard = $dump.IndexOf('recursion_guard', [StringComparison]::Ordinal)
    $callee = $dump.IndexOf('IMAGE_REL_AMD64_REL32' + "`t" + 'guarded_callee', [StringComparison]::Ordinal)
    return $guard -ge 0 -and $callee -gt $guard
}
foreach ($optimization in @('0','2')) {
    $object = Join-Path $OutputDirectory ("stack-frame-O$optimization.o")
    & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror -c $source -o $object
    if ($LASTEXITCODE -ne 0) { throw 'Stack probe compilation failed' }
    $dump = (& $Objdump -d -r $object) -join "`n"
    if ($LASTEXITCODE -ne 0 -or -not (Check-Order $dump)) { throw "Unexpected call order at O$optimization" }
    $changed = $dump.Replace('___chkstk_ms','TEMP_STACK_MARKER').Replace('recursion_guard','___chkstk_ms').Replace('TEMP_STACK_MARKER','recursion_guard')
    if (Check-Order $changed) { throw 'Comparator accepted altered call order' }
    $callerStart = $dump.IndexOf('<guarded_caller>:', [StringComparison]::Ordinal)
    if ($callerStart -lt 0) { throw 'Caller disassembly missing' }
    $caller = $dump.Substring($callerStart)
    if (-not (Check-Caller $caller)) { throw "Caller does not guard before call at O$optimization" }
    $changedCaller = $caller.Replace('recursion_guard','TEMP_GUARD_MARKER').Replace('guarded_callee','recursion_guard').Replace('TEMP_GUARD_MARKER','guarded_callee')
    if (Check-Caller $changedCaller) { throw 'Comparator accepted altered caller order' }
    foreach ($mutated in @($false, $true)) {
        $exe = Join-Path $OutputDirectory ("stack-frame-O$optimization-$mutated.exe")
        $flags = @(if ($mutated) { '-DALWAYS_ALLOW_CONTROL' })
        & $Clang --target=x86_64-w64-windows-gnu -std=c17 "-O$optimization" -Wall -Wextra -Werror @flags $source $driver -o $exe
        if ($LASTEXITCODE -ne 0) { throw 'Stack driver compilation failed' }
        & (Resolve-Path -LiteralPath $exe).Path
        $expected = if ($mutated) { 1 } else { 0 }
        if ($LASTEXITCODE -ne $expected) { throw "Unexpected guard behavior at O$optimization mutated=$mutated" }
    }
}
Write-Output 'Stack and call order checked; guard behavior passed at O0 and O2; ordering and always-allow controls rejected.'
