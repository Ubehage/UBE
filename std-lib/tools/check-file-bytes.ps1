param(
    [string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'),
    [switch]$NativeOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/file-bytes/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$names = @('runtime/bootstrap_runtime.c','runtime/value_storage.h',
    'std-lib/src/win-lib/file_primitives.c','std-lib/src/portable/FileBytes.bas',
    'std-lib/FILE-BYTES-CONTRACT.md','std-lib/tests/file-bytes/ORACLES.md',
    'std-lib/tests/file-bytes/native.c','std-lib/tests/file-bytes/primitives.bas',
    'std-lib/tools/check-file-bytes.ps1','bootstrap/tools/verification.ps1')
$inputs = @($names | ForEach-Object { Get-ArtifactIdentity (Join-Path $root $_) })
$commands = @(); $checks = @(); $failure = $null; $success = $false
try {
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($name in @('compiler','runtime','unicodeRuntime','clang')) {
        $identity = $selection.$name
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Selected artifact changed: $name" }
    }
    $inputs += $selection.clang
    $runtime = Join-Path $run 'runtime-test.o'
    $compile = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-std=c17','-Wall','-Wextra','-Wpedantic','-Werror',
        '-DUBE_FILE_TESTING','-c',(Join-Path $root 'runtime/bootstrap_runtime.c'),'-o',$runtime) $root 60
    $commands += $compile
    if ($compile.timedOut -or $compile.exit -ne 0) { throw "Instrumented runtime failed: $($compile.stderr)" }
    $native = Join-Path $run 'native.exe'
    $link = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',
        '-Wall','-Wextra','-Werror','-I',(Join-Path $root 'runtime'),
        (Join-Path $root 'std-lib/tests/file-bytes/native.c'),$runtime,$selection.unicodeRuntime.path,'-o',$native) $root 30
    $commands += $link
    if ($link.timedOut -or $link.exit -ne 0) { throw "Native oracle failed to build: $($link.stderr)" }
    $unicode = [string][char]0x00e9 + [char]::ConvertFromUtf32(0x1f642)
    $fixture = Join-Path $run ($unicode + '.bin')
    $payload = New-Object byte[] 257
    for ($index=0; $index -lt 257; $index++) { $payload[$index] = $index % 256 }
    [IO.File]::WriteAllBytes($fixture,$payload)
    $execute = Invoke-BoundedProcess $native @($fixture,$unicode) $root 30
    $commands += $execute
    if ($execute.timedOut -or $execute.exit -ne 0 -or $execute.stderr -cne '' -or $execute.stdout -notmatch '^PASS file primitives [0-9]+ assertions\r?\n$') {
        throw "Native file oracle failed: $($execute | ConvertTo-Json -Compress -Depth 4)"
    }
    $checks += [pscustomobject]@{ assertion = 'native independent bytes/status/Err/failure atomicity/resource tokens/Unicode arguments/cleanup/four workers'; passed=$true; output=$execute.stdout }
    if (-not $NativeOnly) {
        $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
        if (-not $accepted.success) { throw 'Selected source gate did not succeed' }
        $inputs += @($selection.manifest,$selection.compiler,$selection.runtime,$selection.unicodeRuntime,$selection.clang)
        $stages = @((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
        foreach ($stage in $stages) {
            $artifact = @($accepted.artifacts | Where-Object path -CEQ $stage)
            if ($artifact.Count -ne 1 -or (Get-ArtifactIdentity $stage).sha256 -cne $artifact[0].sha256) { throw "Stage artifact differs from accepted source gate: $stage" }
        }
        $body = ''
        foreach ($name in @('Utf8','ByteBuffer','FileBytes')) {
            $source = Join-Path $root ('std-lib/src/portable/' + $name + '.bas')
            $inputs += Get-ArtifactIdentity $source
            $lines = [IO.File]::ReadAllText($source).Replace("`r`n","`n") -split "`n"
            if ($lines[0] -cne 'UBE SOURCE 1 MODULE' -or $lines[1] -cne ('Attribute UBE_Name = "' + $name + '"')) { throw "Unexpected envelope: $name" }
            $body += ($lines[2..($lines.Count-1)] -join "`n") + "`n"
        }
        $source = Join-Path $run 'primitives.bas'
        [IO.File]::WriteAllText($source,$body + [IO.File]::ReadAllText((Join-Path $root 'std-lib/tests/file-bytes/primitives.bas')),(New-Object Text.UTF8Encoding($false)))
        $hashes = @()
        for ($index=0; $index -lt 2; $index++) {
            $stem = Join-Path $run ('stage' + ($index+1))
            $compile = Invoke-BoundedProcess $stages[$index] @($source,($stem+'.ll')) $root 30
            $commands += $compile
            if ($compile.timedOut -or $compile.exit -ne 0) { throw "UBE role compilation failed: $($compile.stdout)$($compile.stderr)" }
            $link = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',($stem+'.ll'),$selection.runtime.path,$selection.unicodeRuntime.path,'-o',($stem+'.exe')) $root 30
            $commands += $link
            if ($link.timedOut -or $link.exit -ne 0) { throw "UBE link failed: $($link.stderr)" }
            $execute = Invoke-BoundedProcess ($stem+'.exe') @($fixture) $root 30
            $commands += $execute
            if ($execute.timedOut -or $execute.exit -ne 0 -or $execute.stderr -cne '' -or $execute.stdout.Replace("`r`n","`n") -cne "file primitives`n") { throw "UBE byte oracle failed: $($execute | ConvertTo-Json -Compress -Depth 4)" }
            $checks += [pscustomobject]@{ assertion="stage $($index+1): counted Unicode path and all byte values through exact declarations"; passed=$true }
            $hashes += (Get-ArtifactIdentity ($stem+'.ll')).sha256
        }
        if ($hashes[0] -cne $hashes[1]) { throw 'Raw UBE LLVM differs between stages' }
        $checks += [pscustomobject]@{ assertion='both stages emit byte-identical raw LLVM'; passed=$true }
    }
    foreach ($identity in $inputs) { if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Proof input changed: $($identity.path)" } }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ schema='ube-file-bytes-proof-1'; success=$success; failure=$failure; nativeOnly=[bool]$NativeOnly;
        acceptedSelection=$selection; inputs=$inputs; checks=$checks; commands=$commands;
        artifacts=@(Get-ChildItem -LiteralPath $run -File | ForEach-Object { Get-ArtifactIdentity $_.FullName });
        limits='Bounded Windows adapter; no general cancellation scheduler, complete Library envelope, atomic filesystem snapshot, or fault-proof OS close guarantee.' } |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) byte-file report assertions."
