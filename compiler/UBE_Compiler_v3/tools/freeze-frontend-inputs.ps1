param([Parameter(Mandatory=$true)][string]$BaselineReport)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$baseline=Get-Content -LiteralPath $BaselineReport -Raw | ConvertFrom-Json
if(-not $baseline.success -or -not $baseline.frozenBaseline){throw 'A complete baseline is required'}
$run=Split-Path ([IO.Path]::GetFullPath($BaselineReport)) -Parent
$destination=Join-Path $run 'snapshot'
if(Test-Path -LiteralPath $destination){throw 'Snapshot already exists; never overwrite frozen bytes'}
$pins=@($baseline.inputs)+@($baseline.builds.raw)+@($baseline.builds.entry)+@($baseline.builds.exe)
foreach($corpus in $baseline.corpora){$pins+=@($corpus.inputs,$corpus.reference)}
$pins+=Get-ArtifactIdentity $BaselineReport
$pins=@($pins | Sort-Object path -Unique)
# Admit the complete set before creating a snapshot, including original source
# bytes which a later production optimization will intentionally change.
foreach($pin in $pins){
 $full=[IO.Path]::GetFullPath($pin.path)
 if(-not $full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Snapshot input is outside the workspace'}
 $now=Get-ArtifactIdentity $full
 if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Baseline input/artifact changed: '+$pin.path)}
}
$saved=@()
foreach($pin in $pins){
 $relative=[IO.Path]::GetFullPath($pin.path).Substring($root.Length+1)
 $target=Join-Path $destination $relative
 $null=New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
 Copy-Item -LiteralPath $pin.path -Destination $target
 $copy=Get-ArtifactIdentity $target
 if($copy.sha256 -cne $pin.sha256 -or $copy.bytes -ne $pin.bytes){throw 'Snapshot copy identity mismatch'}
 $saved+=[pscustomobject]@{original=$pin;snapshot=$copy}
}
$report=Join-Path $run 'snapshot.json'
[pscustomobject]@{schema='ube-frontend-snapshot-1';success=$true;baseline=(Get-ArtifactIdentity $BaselineReport);tool=(Get-ArtifactIdentity $PSCommandPath);saved=$saved;scope='Exact local source/harness/corpus/reference/native bytes preserved before optimization; no performance acceptance claim.'} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $report -Encoding UTF8
Write-Output ($saved.Count.ToString()+' source/harness/corpus/artifact snapshots copied and SHA-256 compared.')
Write-Output ('Evidence: '+$report)
