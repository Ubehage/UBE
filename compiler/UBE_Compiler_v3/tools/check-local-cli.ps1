param(
    [Parameter(Mandatory=$true)][string]$CliReport,
    [string]$SelectionPath=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$CliReport=[IO.Path]::GetFullPath($CliReport)
$strict=Get-Content -LiteralPath $CliReport -Raw | ConvertFrom-Json
if(-not $strict.success -or -not $strict.qualified -or $strict.diagnosticOnly -or
    $strict.selection.manifest.sha256 -cne $selection.manifest.sha256){
    throw 'A strict CLI report for the current qualified selection is required'
}
$program=$strict.productionExecutables[1]
$cases=@($strict.cases | Where-Object stage -EQ 2)
$definition=Get-Content -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/tests/parser/cli/cases.json') -Raw | ConvertFrom-Json
$expectedNames=@('missing arguments','unknown option')+@($definition.cases | ForEach-Object name)+@($definition.productionSources | ForEach-Object {'real source '+[IO.Path]::GetFileName($_)})+@('missing source file')
if($cases.Count -ne $expectedNames.Count -or (@($cases.case) -join "`n") -cne ($expectedNames -join "`n")){
    throw 'The complete ordered independent source CLI process oracle set is required'
}
$pins=@($strict.inputs)+@((Get-ArtifactIdentity $CliReport),$program,(Get-ArtifactIdentity $PSCommandPath))
foreach($pin in $pins){
    $now=Get-ArtifactIdentity $pin.path
    if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Qualified CLI input changed: '+$pin.path)}
}
$run=Join-Path $root ('bootstrap/out/local-cli/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$target=Join-Path $root 'bootstrap/out/v3/ube.exe'
$results=@();$success=$false;$failure=$null
try{
    $null=New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
    Copy-Item -LiteralPath $program.path -Destination $target -Force
    if((Get-ArtifactIdentity $target).sha256 -cne $program.sha256){throw 'Local executable differs from the qualified stage-two CLI'}
    foreach($case in $cases){
        $actual=Invoke-BoundedProcess $target @($case.actual.arguments) (Split-Path $CliReport -Parent) 60
        $passed=-not $actual.timedOut -and $actual.exit -eq $case.expected.exit -and
            $actual.stdout -ceq $case.expected.stdout -and $actual.stderr -ceq $case.expected.stderr
        $results+=[pscustomobject]@{case=$case.case;expected=$case.expected;actual=$actual;passed=$passed}
        if(-not $passed){throw ('Local CLI oracle failed: '+$case.case)}
    }
    foreach($pin in $pins){
        $now=Get-ArtifactIdentity $pin.path
        if($now.sha256 -cne $pin.sha256 -or $now.bytes -ne $pin.bytes){throw ('Qualified CLI input changed during replay: '+$pin.path)}
    }
    $null=Get-VerifiedBootstrapSelection $SelectionPath
    $success=$true
}catch{$failure=$_.Exception.Message;throw}finally{
    $report=Join-Path $run 'report.json'
    [pscustomobject]@{schema='ube-local-cli-1';success=$success;acceptedSelection=$selection;
        strictReport=(Get-ArtifactIdentity $CliReport);inputs=$pins;program=(Get-ArtifactIdentity $target);
        qualifiedProgram=$program;cases=$results;failure=$failure} |
        ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $report -Encoding UTF8
    Write-Output ('Evidence: '+$report)
}
Write-Output ('PASS local CLI: byte-identical qualified stage-two executable and all '+$cases.Count+' process oracles.')
