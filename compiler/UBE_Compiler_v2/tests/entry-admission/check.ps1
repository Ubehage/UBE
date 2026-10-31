param([Parameter(Mandatory=$true)][string]$SelectionPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/entry-admission/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands = @()
$checks = @()
$inputs = @()
$selection = $null
$success = $false
$failure = $null
try {
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    $inputs += Get-ArtifactIdentity $SelectionPath
    foreach ($property in $selection.PSObject.Properties) {
        if ($property.Name -ne 'schema' -and (Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256) { throw "Selection changed: $($property.Name)" }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Source-build manifest unsuccessful' }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted input changed: $($identity.path)" }
    }
    $inputs += @($accepted.inputs)
    $stages = @((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    foreach ($stage in $stages) {
        $identity = @($accepted.artifacts | Where-Object path -CEQ $stage)
        if ($identity.Count -ne 1 -or (Get-ArtifactIdentity $stage).sha256 -cne $identity[0].sha256) { throw 'Stage identity mismatch' }
    }
    $inputs += @(Get-ChildItem -LiteralPath $PSScriptRoot -File | ForEach-Object {Get-ArtifactIdentity $_.FullName})
    $diagnostic = "UBE runtime: cannot enter Main: managed root or argument admission failed; release roots or memory and retry.`n"
    $expectedOutput = "body`nbody`n" + $diagnostic + $diagnostic + "body`nentry admission probe passed`n"
    foreach ($kind in @('function','sub')) {
        $irHashes = @()
        for ($index = 0; $index -lt 2; $index++) {
            $stem = Join-Path $run ($kind + '-stage' + ($index + 1))
            $ir = $stem + '.ll'
            $emission = Invoke-BoundedProcess $stages[$index] @((Join-Path $PSScriptRoot ($kind+'.bas')),$ir) $root 30
            $commands += $emission
            if ($emission.timedOut -or $emission.exit -ne 0 -or $emission.stdout -cne '' -or $emission.stderr -cne '' -or -not (Test-Path $ir)) { throw "Emission failed: ${kind}: $($emission.stdout)$($emission.stderr)" }
            $irHashes += (Get-ArtifactIdentity $ir).sha256
            $text = [IO.File]::ReadAllText($ir)
            $trySymbols = [regex]::Matches($text,'define i1 (@ube\.p[0-9]+)\(ptr %arg\.0\)')
            $callSymbols = [regex]::Matches($text,'define i32 (@ube\.p[0-9]+)\(\)')
            if ($trySymbols.Count -ne 1 -or $callSymbols.Count -ne 1 -or $text -notmatch 'store i1 true, ptr %entry\.admitted' -or $text -notmatch 'ptr null\)' -or $text -notmatch 'ret i32 70') { throw 'Generated entry observer/call ABI assertions failed' }
            $text = $text.Replace($trySymbols[0].Groups[1].Value,'@diagnostic_try').Replace($callSymbols[0].Groups[1].Value,'@diagnostic_call_main').Replace('define i32 @main(','define i32 @diagnostic_entry(')
            $adapted = $stem + '-adapter.ll'
            [IO.File]::WriteAllText($adapted,$text,(New-Object Text.UTF8Encoding($false)))
            $entryResult = 0
            if ($kind -eq 'function') { $entryResult = 42 }
            $exe = $stem + '.exe'
            $link = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',$adapted,(Join-Path $PSScriptRoot 'probe.c'),$selection.runtime.path,$selection.unicodeRuntime.path,('-DEXPECTED_ENTRY='+$entryResult),'-o',$exe) $root 30
            $commands += $link
            if ($link.timedOut -or $link.exit -ne 0) { throw "Link failed: ${kind}: $($link.stderr)" }
            $native = Invoke-BoundedProcess $exe @() $root 30
            $commands += $native
            if ($native.timedOut -or $native.exit -ne 0 -or $native.stdout -cne $expectedOutput -or $native.stderr -cne '') { throw "Native oracle failed: ${kind}: $($native | ConvertTo-Json -Compress)" }
            $checks += [pscustomobject]@{assertion="$kind stage $($index+1): fresh entry observer, exact native output/status/stderr, actual full/partial root exhaustion, ordinary Main calls, stale Err and recovery assertions";passed=$true}
        }
        if ($irHashes[0] -cne $irHashes[1]) { throw "Raw LLVM differs: $kind" }
        $checks += [pscustomobject]@{assertion="${kind}: byte-identical raw LLVM through both source-built stages";passed=$true}
    }
    foreach ($identity in $inputs) { if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Input changed: $($identity.path)" } }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    $path = Join-Path $run 'report.json'
    [pscustomobject]@{schema='ube-entry-admission-proof-1';success=$success;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File | ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Executable Main admission only; ordinary Try procedures retain neutral failure and caller-owned fallback contracts'} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Output "Evidence: $path"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) executable entry-admission assertions."
