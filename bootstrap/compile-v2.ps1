param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Output
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'tools/verification.ps1')
try {
    $currentPath = Join-Path $PSScriptRoot 'out/v2/current.json'
    if (-not (Test-Path -LiteralPath $currentPath)) { throw 'No accepted source-built v2. Run bootstrap/build-v2.ps1 first.' }
    $current = Get-Content -LiteralPath $currentPath -Raw | ConvertFrom-Json
    if ($current.schema -cne 'ube-v2-current-1') { throw 'Unsupported v2 selection manifest.' }
    foreach ($identity in @($current.manifest,$current.compiler,$current.runtime,$current.unicodeRuntime,$current.clang)) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) {
            throw "Selected v2 artifact changed: $($identity.path). Rebuild v2."
        }
    }
    $manifest = Get-Content -LiteralPath $current.manifest.path -Raw | ConvertFrom-Json
    if (-not $manifest.success) { throw 'Selected v2 did not pass its acceptance gate.' }
    # The gate inventories code, headers, fixtures and explicit semantic contracts;
    # ordinary later prose is absent from that inventory and remains editable.
    foreach ($identity in $manifest.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) {
            throw "Source changed since the v2 gate: $($identity.path). Rebuild v2."
        }
    }
    $sourcePath = [IO.Path]::GetFullPath($Source)
    $outputPath = [IO.Path]::GetFullPath($Output)
    if ([IO.Path]::GetExtension($outputPath) -ine '.exe') { throw 'Output must name an .exe file.' }
    $run = Join-Path $PSScriptRoot ('out/v2/compilations/' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $run -Force | Out-Null
    $ir = Join-Path $run 'program.ll'
    $exe = Join-Path $run 'program.exe'
    # Generated Unicode and word tables make the current bootstrap consumer
    # slower to compile than the small foundation probes. Keep a finite bound.
    $emit = Invoke-BoundedProcess $current.compiler.path @($sourcePath,$ir) $root 300
    if ($emit.timedOut -or $emit.exit -ne 0 -or -not (Test-Path -LiteralPath $ir)) {
        throw "v2 compilation failed (exit $($emit.exit), timeout $($emit.timedOut)): $($emit.stdout)$($emit.stderr)"
    }
    $link = Invoke-BoundedProcess $current.clang.path @('--target=x86_64-w64-windows-gnu','-O2',
        '-x','ir',$ir,'-x','none',$current.runtime.path,$current.unicodeRuntime.path,'-o',$exe) $root 30
    if ($link.timedOut -or $link.exit -ne 0 -or -not (Test-Path -LiteralPath $exe)) {
        throw "Native link failed (exit $($link.exit), timeout $($link.timedOut)): $($link.stdout)$($link.stderr)"
    }
    $parent = Split-Path -Parent $outputPath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if ([IO.File]::Exists($outputPath)) { [IO.File]::Replace($exe,$outputPath,[NullString]::Value) }
    else { [IO.File]::Move($exe,$outputPath) }
    [pscustomobject]@{ output = (Get-ArtifactIdentity $outputPath); compiler = $current.compiler;
        source = (Get-ArtifactIdentity $sourcePath); emit = $emit; link = $link } |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $run 'compile.json') -Encoding UTF8
    Write-Output "Built $outputPath"
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
