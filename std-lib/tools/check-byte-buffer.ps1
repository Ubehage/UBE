param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/byte-buffer/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$fixtureRoot = Join-Path $root 'std-lib/tests/byte-buffer'
$paths = @('std-lib/tools/check-byte-buffer.ps1','std-lib/src/portable/Utf8.bas',
    'std-lib/src/portable/ByteBuffer.bas','std-lib/BYTE-BUFFER-CONTRACT.md',
    'bootstrap/tools/verification.ps1') | ForEach-Object { Join-Path $root $_ }
$paths += @(Get-ChildItem -LiteralPath $fixtureRoot -File | ForEach-Object FullName)
$inputs = @($paths | ForEach-Object { Get-ArtifactIdentity $_ })
$commands = @()
$checks = @()
$selection = $null
$success = $false
$failure = $null
try {
    $inputs += Get-ArtifactIdentity $SelectionPath
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($property in $selection.PSObject.Properties) {
        if ($property.Name -ne 'schema' -and (Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256) {
            throw "Selection changed: $($property.Name)"
        }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected compiler did not pass its acceptance gate' }
    $inputs += @($selection.manifest,$selection.compiler,$selection.runtime,$selection.unicodeRuntime,$selection.clang)
    foreach ($identity in @($selection.compiler,$selection.runtime,$selection.unicodeRuntime)) {
        $artifact = @($accepted.artifacts | Where-Object path -CEQ $identity.path)
        if ($artifact.Count -ne 1 -or $artifact[0].sha256 -cne $identity.sha256) { throw "Selected artifact differs from accepted manifest: $($identity.path)" }
    }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted input changed: $($identity.path)" }
    }
    $inputs += @($accepted.inputs)
    $stages = @((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    $stageOne = @($accepted.artifacts | Where-Object path -CEQ $stages[0])
    if ($stageOne.Count -ne 1 -or (Get-ArtifactIdentity $stages[0]).sha256 -cne $stageOne[0].sha256) { throw 'Stage one identity differs' }
    $body = ''
    foreach ($name in @('Utf8','ByteBuffer')) {
        $module = [IO.File]::ReadAllText((Join-Path $root ('std-lib/src/portable/' + $name + '.bas'))).Replace("`r`n","`n")
        $lines = $module -split "`n"
        if ($lines[0] -cne 'UBE SOURCE 1 MODULE' -or $lines[1] -cne ('Attribute UBE_Name = "' + $name + '"')) { throw "Unexpected source envelope: $name" }
        $body += ($lines[2..($lines.Count - 1)] -join "`n") + "`n"
    }
    $checks += [pscustomobject]@{ assertion = 'exact Utf8 and ByteBuffer library bodies; only their two documented envelope lines removed'; passed = $true }
    $suite = Get-Content -LiteralPath (Join-Path $fixtureRoot 'cases.json') -Raw | ConvertFrom-Json
    foreach ($case in $suite.cases) {
        $source = Join-Path $run ($case.name + '.bas')
        [IO.File]::WriteAllText($source,$body + [IO.File]::ReadAllText((Join-Path $fixtureRoot ($case.name + '.bas'))),(New-Object Text.UTF8Encoding($false)))
        $hashes = @()
        for ($index = 0; $index -lt 2; $index++) {
            $stem = Join-Path $run ('stage' + ($index + 1) + '-' + $case.name)
            $ir = $stem + '.ll'
            $compile = Invoke-BoundedProcess $stages[$index] @($source,$ir) $root 30
            $commands += $compile
            if ($compile.timedOut -or $compile.exit -ne 0 -or -not (Test-Path -LiteralPath $ir)) { throw "Emission failed: $($compile.stdout)$($compile.stderr)" }
            $link = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',$ir,
                $selection.runtime.path,$selection.unicodeRuntime.path,'-o',($stem + '.exe')) $root 30
            $commands += $link
            if ($link.timedOut -or $link.exit -ne 0) { throw "Link failed: $($link.stderr)" }
            $native = Invoke-BoundedProcess ($stem + '.exe') @() $root 30
            $commands += $native
            if ($native.timedOut -or $native.exit -ne $case.exit -or $native.stdout -cne $case.stdout -or $native.stderr -cne $case.stderr) {
                throw "Native oracle failed: $($case.name): $($native | ConvertTo-Json -Compress -Depth 4)"
            }
            $checks += [pscustomobject]@{ assertion = "stage $($index + 1): $($case.name) exact exit/stdout/stderr"; passed = $true }
            $hashes += (Get-ArtifactIdentity $ir).sha256
        }
        if ($hashes[0] -cne $hashes[1]) { throw "Stage raw LLVM differs: $($case.name)" }
        $checks += [pscustomobject]@{ assertion = "$($case.name): byte-identical raw LLVM through both accepted stages"; passed = $true }
    }
    foreach ($identity in $inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Proof input changed: $($identity.path)" }
    }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ schema = 'ube-byte-buffer-functional-proof-1'; success = $success; failure = $failure;
        acceptedSelection = $selection; inputs = $inputs; checks = $checks; commands = $commands;
        limits = 'Functional module-body proof only; allocation failure, Err, cost, concurrent-instance and scope-cleanup instrumentation remain separate pending obligations; full Library manifest unbuilt';
        artifacts = @(Get-ChildItem -LiteralPath $run -File | ForEach-Object { Get-ArtifactIdentity $_.FullName }) } |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) byte-buffer functional assertions through both accepted v2 stages."
