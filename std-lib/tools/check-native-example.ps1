$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/native-example/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands = @()
$checks = @()
$success = $false
$failure = $null
$inputPaths = @((Join-Path $PSScriptRoot 'check-native-example.ps1'),
    (Join-Path $root 'docs/language/words/i/intrinsic.html'),
    (Join-Path $root 'lang-doc/grammar/fixtures/positive/native-values.bas'),
    (Join-Path $root 'bootstrap/tools/verification.ps1'))
$inputs = @($inputPaths | ForEach-Object { Get-ArtifactIdentity $_ })
try {
    $selection = Get-Content (Join-Path $root 'bootstrap/out/v2/current.json') -Raw | ConvertFrom-Json
    foreach ($identity in @($selection.manifest,$selection.compiler,$selection.runtime,$selection.unicodeRuntime,$selection.clang)) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw 'Selected tool changed' }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected compiler is not qualified' }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted input changed: $($identity.path)" }
    }
    $html = [IO.File]::ReadAllText($inputPaths[1])
    $matches = [regex]::Matches($html,'<code id="native-value-example">([\s\S]*?)</code>')
    if ($matches.Count -ne 1) { throw 'Missing or ambiguous public native-value example' }
    $example = [Net.WebUtility]::HtmlDecode($matches[0].Groups[1].Value).Replace("`r`n","`n").TrimEnd()
    if ($example -cne [IO.File]::ReadAllText($inputPaths[2]).Replace("`r`n","`n").TrimEnd()) { throw 'Public example differs from the normative fixture' }
    $checks += 'exact public example / normative fixture identity'
    $lines = $example -split "`n"
    if ($lines[0] -cne 'UBE SOURCE 1 MODULE' -or $lines[1] -cne 'Attribute UBE_Name = "NativeValues"') { throw 'Unexpected native source envelope' }
    $bare = Join-Path $run 'example.bas'
    [IO.File]::WriteAllText($bare,($lines[2..($lines.Count - 1)] -join "`n") + "`n",(New-Object Text.UTF8Encoding($false)))
    $stages = @((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    $stageOneIdentity = @($accepted.artifacts | Where-Object { $_.path -ceq $stages[0] })
    if ($stageOneIdentity.Count -ne 1 -or (Get-ArtifactIdentity $stages[0]).sha256 -cne $stageOneIdentity[0].sha256) { throw 'Stage one differs' }
    $hashes = @()
    for ($index = 0; $index -lt $stages.Count; $index++) {
        $ir = Join-Path $run ("stage$index.ll")
        $exe = Join-Path $run ("stage$index.exe")
        $emission = Invoke-BoundedProcess $stages[$index] @($bare,$ir) $root 15
        $commands += $emission
        if ($emission.exit -ne 0 -or $emission.timedOut) { throw $emission.stdout }
        $link = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',$ir,$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe) $root 30
        $commands += $link
        if ($link.exit -ne 0 -or $link.timedOut) { throw $link.stderr }
        $native = Invoke-BoundedProcess $exe @() $root 15
        $commands += $native
        if ($native.exit -ne 0 -or $native.timedOut -or $native.stdout -cne "255`n" -or $native.stderr -cne '') { throw 'Public example native oracle differs' }
        $checks += "stage $($index + 1): exact native output/exit"
        $hashes += (Get-ArtifactIdentity $ir).sha256
    }
    if ($hashes[0] -cne $hashes[1]) { throw 'Public example stage LLVM differs' }
    $checks += 'byte-identical raw LLVM'
    foreach ($identity in $inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw 'Example input changed' }
    }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ success = $success; failure = $failure; inputs = $inputs; checks = $checks; commands = $commands;
        artifacts = @(Get-ChildItem -LiteralPath $run -File | ForEach-Object { Get-ArtifactIdentity $_.FullName }) } |
        ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output 'PASS: four public-example assertions; only the documented bare bootstrap body was executed.'
