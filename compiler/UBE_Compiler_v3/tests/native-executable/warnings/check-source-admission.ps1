param([Parameter(Mandatory=$true)][string]$Compiler)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))) {
    $root=Split-Path $root -Parent
    if(-not $root){throw 'Repository root missing'}
}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$compilerIdentity=Get-ArtifactIdentity $Compiler
$casePath=Join-Path $PSScriptRoot 'source-cases.json'
$cases=Get-Content -LiteralPath $casePath -Raw | ConvertFrom-Json
$run=Join-Path $root ('bootstrap/out/native-warning-admission/'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run)
$utf8=[Text.UTF8Encoding]::new($false)
$inputs=@((Get-ArtifactIdentity $casePath),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $root 'bootstrap/tools/verification.ps1')))
$commands=@();$checks=@();$artifacts=@();$success=$false;$failure=$null
try {
    if($cases.schema -cne 'ube-native-warning-source-cases-1'){throw 'Wrong source-case schema'}
    foreach($case in $cases.cases) {
        $dir=Join-Path $run $case.name
        $null=[IO.Directory]::CreateDirectory($dir)
        $lines=@('UBE-Project 1','Name = "WarningSourceFixture"','Kind = "Exe"','Startup = "Main"')
        foreach($source in $case.sources) {
            $name=$source.name+'.bas';$path=Join-Path $dir $name
            [IO.File]::WriteAllText($path,$source.text,$utf8)
            $artifacts+=Get-ArtifactIdentity $path
            $lines+='Source = "'+$name+'"'
        }
        $manifest=Join-Path $dir 'WarningSourceFixture.UBE'
        [IO.File]::WriteAllText($manifest,($lines -join "`n")+"`n",$utf8)
        $artifacts+=Get-ArtifactIdentity $manifest
        foreach($jobs in @(1,4)) {
            $record=Invoke-BoundedProcess $compilerIdentity.path @('--check',$manifest,'--jobs',[string]$jobs) $dir 30
            $commands+=@($record)
            $passed=(-not $record.timedOut -and $record.exit -eq 0 -and $record.stdout -ceq '' -and $record.stderr -ceq '')
            $assertion='Checked source admitted with empty streams'
            if($case.PSObject.Properties['rejection']) {
                $passed=(-not $record.timedOut -and $record.exit -eq 1 -and $record.stderr -ceq '' -and $record.stdout -match ('error UBE'+$case.rejection.code+':'))
                $assertion='Specified checker rejection retained'
            }
            $checks+=@([pscustomobject]@{assertion=$assertion;case=$case.name;jobs=$jobs;passed=$passed})
            if(-not $passed){throw "Admission failed for $($case.name) jobs=$jobs`: $($record.stdout) $($record.stderr)"}
        }
    }
    $success=$true
} catch {$failure=$_.Exception.Message}
$report=Join-Path $run 'report.json'
[pscustomobject]@{success=$success;failure=$failure;compiler=$compilerIdentity;inputs=$inputs;checks=$checks;commands=$commands;artifacts=$artifacts;scope='Source admission only. Expected dependencies and warning spans are independent future extraction assertions, not observed warnings. Runtime execution is not tested.'} | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $report -Encoding UTF8
Write-Output "Evidence: $report"
if(-not $success){throw $failure}
