param([Parameter(Mandatory=$true)][string]$BuildReport)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repository=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $repository 'bootstrap/tools/verification.ps1')
. (Join-Path $PSScriptRoot 'cli-regressions.ps1')
$run=Join-Path $repository ('bootstrap/out/project-cli-regressions/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$inputs=@((Get-ArtifactIdentity $BuildReport),(Get-ArtifactIdentity $PSCommandPath))
$results=@();$success=$false;$failure=$null
function Get-RegressionSources([string]$Manifest){
    $Manifest
    foreach($line in [IO.File]::ReadAllLines($Manifest)){
        if($line -match '^Source = "([^"]+)"$'){[IO.Path]::GetFullPath((Join-Path (Split-Path $Manifest -Parent) $Matches[1]))}
    }
    foreach($line in [IO.File]::ReadAllLines($Manifest)){
        if($line -match '^Reference = "([^"]+)"$'){Get-RegressionSources ([IO.Path]::GetFullPath((Join-Path (Split-Path $Manifest -Parent) $Matches[1])))}
    }
}
try{
    $prior=Get-Content -LiteralPath $BuildReport -Raw | ConvertFrom-Json
    if(-not $prior.success){throw 'Successful production build report required'}
    $selection=$prior.acceptedSelection
    foreach($property in $selection.PSObject.Properties){if($property.Name -cne 'schema'){
        if((Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256){throw 'Accepted tool identity differs'}
        $inputs+=$property.Value
    }}
    $paths=@(Get-RegressionSources (Join-Path $repository 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))
    foreach($path in $paths){
        $identity=Get-ArtifactIdentity $path
        $record=@($prior.inputs | Where-Object path -CEQ $identity.path)
        if($record.Count -lt 1 -or @($record | Where-Object sha256 -CNE $identity.sha256).Count -ne 0){throw ('Production build input differs: '+$path)}
        $inputs+=$identity
    }
    $manifest=Join-Path (Split-Path $BuildReport -Parent) 'fixtures/default/App.UBE'
    for($index=1;$index -le 2;++$index){
        $raw=Join-Path (Split-Path $BuildReport -Parent) ('stage'+$index+'.ll')
        $record=@($prior.artifacts | Where-Object path -CEQ ([IO.Path]::GetFullPath($raw)))
        if($record.Count -ne 1 -or (Get-ArtifactIdentity $raw).sha256 -cne $record[0].sha256){throw 'Production raw LLVM identity differs'}
        $destination=Join-Path $run ('stage'+$index)
        $results+=Invoke-ProjectCliRegressions -RawPath $raw -SourcePaths $paths -Selection $selection -Destination $destination -Repository $repository -ManifestPath $manifest
    }
    foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw ('Pinned source changed: '+$identity.path)}}
    $success=$true
}catch{$failure=$_.Exception.ToString()}
finally{
    $report=Join-Path $run 'report.json'
    [pscustomobject]@{schema='ube-project-cli-regression-evidence-1';success=$success;qualified=$false;
        diagnosticOnly=$true;buildReport=$BuildReport;inputs=$inputs;results=$results;failure=$failure;
        artifacts=@(Get-ChildItem -LiteralPath $run -Recurse -File | ForEach-Object {Get-ArtifactIdentity $_.FullName});
        scope='Actual platform Main root/start/wait/close faults; unchanged UBE diagnostics, all headers and delegated messages; real allocator/root failure, exact fallback, primary preservation, worker/file/root/payload/String cleanup. Diagnostic reuse of accepted raw production images; no refreshed bootstrap qualification or performance claim.'} | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Output ('Evidence: '+$report)
}
if(-not $success){throw $failure}
Write-Output ((@($results | ForEach-Object {$_.checks}).Count).ToString()+' project CLI regression assertions passed.')
