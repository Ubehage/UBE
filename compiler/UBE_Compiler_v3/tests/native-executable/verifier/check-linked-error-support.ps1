param([Parameter(Mandatory=$true)][string] $SourceReport,
      [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [switch] $RequireMinimal)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$sourceReportPath=(Resolve-Path -LiteralPath $SourceReport).Path
$source=Get-Content -LiteralPath $sourceReportPath -Raw | ConvertFrom-Json
function Tool([string] $name) {
    $found=@($source.identities | Where-Object { [IO.Path]::GetFileName($_.path) -ieq $name })
    if ($found.Count -ne 1 -or (Get-FileHash -LiteralPath $found[0].path -Algorithm SHA256).Hash -cne $found[0].sha256) { throw "Tool identity mismatch: $name" }
    return $found[0].path
}
$clang=Tool 'clang.exe'; $linker=Tool 'ld.lld.exe'; $readobj=Tool 'llvm-readobj.exe'
$nm=Join-Path ([IO.Path]::GetDirectoryName($clang)) 'llvm-nm.exe'
$objdump=Join-Path ([IO.Path]::GetDirectoryName($clang)) 'llvm-objdump.exe'
foreach ($item in @($nm,$objdump)) { if (-not [IO.File]::Exists($item)) { throw "Missing inspector: $item" } }
foreach ($item in @($source.inputs)) {
    if ((Get-FileHash -LiteralPath $item.path -Algorithm SHA256).Hash -cne $item.sha256) { throw "Input identity mismatch: $($item.path)" }
}
if (@($source.inputs).Count -ne 14) { throw 'Unexpected source-report input count (13 support inputs plus original object)' }
$support=@($source.arguments | Where-Object { $candidate=$_; @($source.inputs | Where-Object { $_.path -eq $candidate -and [IO.Path]::GetFileName($_.path) -ne 'verified.o' }).Count -eq 1 })
if ($support.Count -ne 20 -or [IO.Path]::GetFileName($support[0]) -ne 'crt2.o' -or [IO.Path]::GetFileName($support[1]) -ne 'crtbegin.o' -or [IO.Path]::GetFileName($support[-1]) -ne 'crtend.o') { throw "Unexpected explicit support sequence: $($support.Count)" }
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$runtime=(Resolve-Path -LiteralPath 'bootstrap/runtime/bootstrap_runtime.c').Path
$driver=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'linked-error-support.c')).Path
$ir=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'runtime-error-bridge.ll')).Path
$sourceHashes=@($runtime,$driver,$ir | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash} })
$windows=[Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$environment=@{SystemRoot=$windows;WINDIR=$windows;TEMP=$root;TMP=$root;PATH=(([IO.Path]::GetDirectoryName($clang)),([IO.Path]::GetDirectoryName($linker)),(Join-Path $windows 'System32') -join ';')}
$commands=[Collections.Generic.List[object]]::new()
function Invoke-Tool([string] $Program,[string[]] $Items,[int] $Timeout=20000) {
    foreach ($item in $Items) { if ($item.Contains('"') -or $item.EndsWith('\')) { throw 'Unsupported test argument spelling' } }
    $p=[Diagnostics.Process]::new(); $p.StartInfo.FileName=$Program
    $p.StartInfo.Arguments=(@($Items | ForEach-Object { '"'+$_+'"' }) -join ' ')
    $p.StartInfo.UseShellExecute=$false; $p.StartInfo.CreateNoWindow=$true; $p.StartInfo.WorkingDirectory=$root
    $p.StartInfo.RedirectStandardOutput=$true; $p.StartInfo.RedirectStandardError=$true
    $p.StartInfo.EnvironmentVariables.Clear(); foreach ($key in $environment.Keys) { $p.StartInfo.EnvironmentVariables[$key]=$environment[$key] }
    try {
        if (-not $p.Start()) { throw "Process did not start: $Program" }
        $out=$p.StandardOutput.ReadToEndAsync(); $err=$p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($Timeout)) { $p.Kill(); $p.WaitForExit(); throw "Process timed out: $Program" }
        $result=@{program=$Program;arguments=$Items;exit=$p.ExitCode;stdout=$out.Result;stderr=$err.Result}
        $commands.Add($result)
        return $result
    } finally { $p.Dispose() }
}
function Require-Ok($result,[string] $label) { if ($result.exit -ne 0) { throw "$label failed: $($result.stderr)" } }
$common=@('--no-default-config','--target=x86_64-w64-windows-gnu','-O2','-mno-incremental-linker-compatible')
$include=Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($support[0]))) 'include'
if (-not [IO.Directory]::Exists($include)) { throw 'Missing explicit MinGW include directory' }
$runtimeObject=Join-Path $root 'runtime.o'; $irObject=Join-Path $root 'bridge.o'
Require-Ok (Invoke-Tool $clang ($common+@('-isystem',$include,'-std=c17','-ffunction-sections','-fdata-sections','-c',$runtime,'-o',$runtimeObject))) 'runtime compile'
Require-Ok (Invoke-Tool $clang ($common+@('-Xclang','-llvm-verify-each','-c','-x','ir',$ir,'-o',$irObject))) 'bridge compile'
$wrongIr=Join-Path $root 'bridge-wrong-error.ll'; $wrongIrObject=Join-Path $root 'bridge-wrong-error.o'
$irText=[IO.File]::ReadAllText($ir)
$needle='call void @ube_err_set(i32 11, ptr null, ptr null)'
if ([regex]::Matches($irText,[regex]::Escape($needle)).Count -ne 3) { throw 'Expected three error calls for independent mutation' }
[IO.File]::WriteAllText($wrongIr,$irText.Replace($needle,'call void @ube_err_set(i32 12, ptr null, ptr null)'),[Text.UTF8Encoding]::new($false))
Require-Ok (Invoke-Tool $clang ($common+@('-Xclang','-llvm-verify-each','-c','-x','ir',$wrongIr,'-o',$wrongIrObject))) 'wrong-error bridge compile'
$results=@()
foreach ($variant in @('good','WRONG_ERROR_CONTROL','WRONG_THREAD_CONTROL')) {
    $driverObject=Join-Path $root "driver-$variant.o"
    $flags=@(if ($variant -ne 'good') { "-D$variant" })
    Require-Ok (Invoke-Tool $clang ($common+@('-isystem',$include,'-std=c17','-Wall','-Wextra','-Werror','-c')+$flags+@($driver,'-o',$driverObject))) 'driver compile'
    foreach ($gc in @(if ($variant -eq 'good') { 'gc','no-gc' } else { 'gc' })) {
        $exe=Join-Path $root "$variant-$gc.exe"; $map=Join-Path $root "$variant-$gc.map"
        $selectedIrObject=if ($variant -eq 'WRONG_ERROR_CONTROL') {$wrongIrObject} else {$irObject}
        $objects=@($driverObject,$selectedIrObject,$runtimeObject)
        $args=@('--no-default-config','--target=x86_64-w64-windows-gnu','-nostdlib',"--ld-path=$linker")+@($support[0..1])+$objects+@($support[2..($support.Count-1)])+@('-Wl,--no-insert-timestamp','-Wl,--subsystem,console','-Wl,--threads=1','-Wl,--Xlink=/nodefaultlib',"-Wl,-Map=$map",$(if ($gc -eq 'gc') {'-Wl,--gc-sections'} else {'-Wl,--no-gc-sections'}),'-o',$exe)
        $link=Invoke-Tool $clang $args
        if ($link.exit -ne 0) {
            if ($gc -eq 'gc') { throw "GC link failed: $($link.stderr)" }
            $results += [pscustomobject]@{variant=$variant;gc=$gc;linkExit=$link.exit;linkError=$link.stderr}
            continue
        }
        $symbols=Invoke-Tool $nm @('--defined-only',$exe)
        $imports=Invoke-Tool $readobj @('--coff-imports','--coff-exports',$exe)
        $disassembly=Invoke-Tool $objdump @('-d',$exe)
        Require-Ok $symbols 'symbol inventory'; Require-Ok $imports 'imports/exports'; Require-Ok $disassembly 'disassembly'
        [IO.File]::WriteAllText((Join-Path $root "$variant-$gc.symbols.txt"),$symbols.stdout)
        [IO.File]::WriteAllText((Join-Path $root "$variant-$gc.imports-exports.txt"),$imports.stdout)
        [IO.File]::WriteAllText((Join-Path $root "$variant-$gc.disassembly.txt"),$disassembly.stdout)
        $ubeNames=@([regex]::Matches($symbols.stdout,'(?m)^\S+\s+\S\s+(ube_[A-Za-z0-9_]+)\s*$') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $allowed=@('ube_err_set','ube_err_number','ube_err_clear','ube_thread_error','ube_error_copy_text','ube_current_error_state')
        foreach ($required in @('ube_err_set','ube_err_number','ube_err_clear','ube_thread_error')) {
            if ($required -notin $ubeNames) { throw "Required retained symbol not observed: $required" }
        }
        $unexpected=@($ubeNames | Where-Object { $_ -notin $allowed })
        if ($gc -eq 'no-gc' -and $unexpected.Count -eq 0) { throw 'No-GC control unexpectedly satisfied the minimal-support comparator' }
        $execution=$null
        if ($gc -eq 'gc') {
            $execution=Invoke-Tool $exe @() 30000
            if ($variant -eq 'good') {
                if ($execution.exit -ne 0 -or $execution.stdout.Trim() -ne 'three-width remainder and overlapping thread-local Err passed in both launch orders') { throw "Good runtime failed: $($execution.exit) $($execution.stderr)" }
            } elseif ($execution.exit -ne 1) { throw "Runtime mutation not rejected: $variant exit=$($execution.exit)" }
        }
        $results += [pscustomobject]@{variant=$variant;gc=$gc;linkExit=0;executable=$exe;sha256=(Get-FileHash -LiteralPath $exe).Hash;ubeSymbols=$ubeNames;unexpected=$unexpected;minimal=($unexpected.Count -eq 0);execution=$execution;map=$map}
        Write-Output "$variant $gc : UBE symbols=$($ubeNames.Count), unexpected=$($unexpected.Count), execution=$(if ($execution) {$execution.exit} else {'not-run'})"
    }
}
foreach ($item in @($source.inputs)+@($source.identities[0..2])) {
    if ((Get-FileHash -LiteralPath $item.path -Algorithm SHA256).Hash -cne $item.sha256) { throw "Input changed during test: $($item.path)" }
}
foreach ($item in $sourceHashes) {
    if ((Get-FileHash -LiteralPath $item.path -Algorithm SHA256).Hash -cne $item.sha256) { throw "Source changed during test: $($item.path)" }
}
$identities=@($sourceReportPath,$PSCommandPath,$runtime,$driver,$ir,$nm,$objdump | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash} })
$artifacts=@($runtimeObject,$irObject,$wrongIr,$wrongIrObject,(Join-Path $root 'driver-good.o'),(Join-Path $root 'driver-WRONG_ERROR_CONTROL.o'),(Join-Path $root 'driver-WRONG_THREAD_CONTROL.o') | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash} })
$baseline=@($results | Where-Object { $_.variant -eq 'good' -and $_.gc -eq 'gc' })
if ($baseline.Count -ne 1) { throw 'Expected exactly one good GC result' }
[pscustomobject]@{sourceReport=$sourceReportPath;requireMinimal=$RequireMinimal.IsPresent;minimalityAccepted=$baseline[0].minimal;environment=$environment;identities=$identities;artifacts=$artifacts;sourceToolIdentities=@($source.identities[0..2]);supportInputs=@($source.inputs);supportSequence=$support;commands=$commands.ToArray();results=$results} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $root 'report.json') -Encoding UTF8
Write-Output "Evidence: $root"
if ($RequireMinimal -and -not $baseline[0].minimal) { throw 'GC-linked runtime retained UBE symbols outside the error-support allowlist' }
