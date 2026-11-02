param(
    [Parameter(Mandatory=$true)][string]$DefinitionReport,
    [Parameter(Mandatory=$true)][string]$CliReport,
    [string]$SelectionPath=''
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Repository root missing'};$root=$parent}
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$utf8=[Text.UTF8Encoding]::new($false,$true)
$run=Join-Path $root ('bootstrap/out/semantic-inputs/'+[Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Force -Path $run
$results=[Collections.Generic.List[object]]::new();$pins=[Collections.Generic.List[object]]::new();$proofs=[Collections.Generic.List[object]]::new()
$success=$false;$failure=$null;$selection=$null;$frontend=@();$semanticCount=0;$definitionIdentity=$null;$cliIdentity=$null
function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Has($Value,[string]$Name){return $null -ne $Value -and $null -ne $Value.PSObject.Properties[$Name]}
function True-Flag($Value,[string]$Name){return (Has $Value $Name) -and $Value.$Name -is [bool] -and $Value.$Name}
function Pin($Identity){$now=Get-ArtifactIdentity $Identity.path;Require ($now.bytes -eq $Identity.bytes -and $now.sha256 -ceq $Identity.sha256) 'Accepted report/input/executable identity changed';$pins.Add($now)}
function Read-Report([string]$Path){Require ((Get-Item -LiteralPath $Path).Length -le 67108864) 'Report exceeds64MiB audit bound';return ([IO.File]::ReadAllText($Path,$utf8)|ConvertFrom-Json)}
function Accepted-Compiler($Report,$Selected){
    Require ((Has $Report 'acceptedSelection') -and (Has $Report.acceptedSelection 'compiler')) 'Accepted compiler identity is required'
    $compiler=$Report.acceptedSelection.compiler
    Require ($compiler.sha256 -ceq $Selected.compiler.sha256 -and $compiler.bytes -eq $Selected.compiler.bytes -and [string]::Equals([IO.Path]::GetFullPath($compiler.path),[IO.Path]::GetFullPath($Selected.compiler.path),[StringComparison]::OrdinalIgnoreCase)) 'Report must use the current accepted compiler'
    Pin $compiler
    # Child/provisional source-bootstrap manifest hashes may differ from the
    # final parent; the accepted compiler and exact report/input pins bind this.
}
function Passed-Checks($Report,[string]$Label){
    Require ((Has $Report 'checks') -and $Report.checks -is [array] -and $Report.checks.Count -gt 0 -and $Report.checks.Count -le 1048576) "$Label requires nonempty bounded checks"
    foreach($check in $Report.checks){Require ((Has $check 'passed') -and $check.passed -is [bool] -and $check.passed) "$Label assertion must explicitly pass"}
}
function Snapshot([string]$Folder){
    $items=@(Get-ChildItem -LiteralPath $Folder -Recurse -Force|Sort-Object FullName)
    return @($items|ForEach-Object {if($_.PSIsContainer){[pscustomobject]@{path=$_.FullName;directory=$true}}else{[pscustomobject]@{path=$_.FullName;directory=$false;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}}})
}
function Frontend-Expected([string]$Kind,$Witness){
    switch -CaseSensitive ($Kind){
        'ExpectedExpression'{return "error UBE1201: expected expression (next lines: line, column, byte)`n$($Witness.first.line)`n$($Witness.first.column)`n$($Witness.first.byte)`n"}
        'FrontendDeferred'{return "error UBE1200: source syntax family is not implemented (next lines: line, column, byte)`n$($Witness.first.line)`n$($Witness.first.column)`n$($Witness.first.byte)`n"}
        'UnknownReservedAttribute'{return "source($($Witness.first.line),$($Witness.first.column)): error UBE1100: unknown reserved source attribute at byte $($Witness.first.byte)`n"}
        default{throw 'Undefined retained frontend prediction; do not infer an answer from CLI output'}
    }
}
try{
    $selection=Get-VerifiedBootstrapSelection $SelectionPath
    $definitionIdentity=Get-ArtifactIdentity $DefinitionReport;$cliIdentity=Get-ArtifactIdentity $CliReport
    $definition=Read-Report $DefinitionReport;$cli=Read-Report $CliReport
    Require ($definition.schema -ceq 'ube-semantic-contract-proof-1' -and (True-Flag $definition 'success') -and (True-Flag $definition 'definitionOnly') -and $definition.semanticImplemented -is [bool] -and -not $definition.semanticImplemented) 'A successful independent definition report is required'
    Accepted-Compiler $definition $selection;Passed-Checks $definition 'Definition report'
    Require ($definition.assertionCount -eq $definition.checks.Count) 'Definition assertion inventory must match its checks'
    Require ($cli.schema -ceq 'ube-semantic-cli-1' -and (True-Flag $cli 'success') -and (True-Flag $cli 'qualified') -and (True-Flag $cli 'sourceBuildCurrent')) 'A qualified final semantic CLI report is required'
    Accepted-Compiler $cli $selection;Passed-Checks $cli 'Semantic CLI report'
    $casePath=Join-Path $root 'compiler/UBE_Compiler_v3/tests/semantic/cases.json';$caseIdentity=Get-ArtifactIdentity $casePath
    $casePins=@($definition.identities|Where-Object {[string]::Equals($_.path,$caseIdentity.path,[StringComparison]::OrdinalIgnoreCase)})
    Require ($casePins.Count -eq 1 -and $casePins[0].sha256 -ceq $caseIdentity.sha256 -and $casePins[0].bytes -eq $caseIdentity.bytes) 'Definition must cover these exact independent cases'
    $cases=([IO.File]::ReadAllText($casePath,$utf8)|ConvertFrom-Json).cases
    $frontend=@($cases|Where-Object {$_.expected.outcome -ceq 'frontend'});$semanticCount=@($cases|Where-Object {$_.expected.outcome -cne 'frontend'}).Count
    Require ($frontend.Count -eq 3) 'All three explicit retained frontend cases are required'
    $kinds=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($case in $frontend){Require ($case.sources.Count -eq 1 -and $kinds.Add([string]$case.expected.diagnostic.kind)) 'Retained frontend cases must have unique classes and one original source'}
    Require ($kinds.SetEquals([string[]]@('ExpectedExpression','FrontendDeferred','UnknownReservedAttribute'))) 'Only the three fixed frontend predictions are admitted'
    foreach($path in @($PSCommandPath,$DefinitionReport,$CliReport,$SelectionPath,$selection.manifest.path,(Join-Path $root 'bootstrap/tools/verification.ps1'))){Pin (Get-ArtifactIdentity $path)}
    Pin $caseIdentity
    Require ($cli.productionExecutables -is [array] -and $cli.productionExecutables.Count -eq 2) 'Both qualified source-built final CLI stages are required'
    $programPaths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($program in $cli.productionExecutables){Require ($programPaths.Add([IO.Path]::GetFullPath($program.path))) 'Final CLI stage executable paths must be distinct';Pin $program}
    $proofNames=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);$proofPaths=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    Require ($cli.proofs -is [array] -and $cli.proofs.Count -eq 6) 'Both final CLI stages need their three complete child proofs'
    foreach($proof in $cli.proofs){
        Require (($proof.stage -eq 1 -or $proof.stage -eq 2) -and @('check-process.ps1','check-project-process.ps1','check-faults.ps1') -ccontains $proof.gate -and $proofNames.Add(([string]$proof.stage)+'/'+$proof.gate)) 'Final CLI child stage/gate identities must be complete and unique'
        Require ($proofPaths.Add([IO.Path]::GetFullPath($proof.report.path))) 'Final CLI child report paths must be unique';Pin $proof.report
        $child=Read-Report $proof.report.path;Require ($child.success -is [bool] -and $child.success) 'Final CLI child report must succeed';Passed-Checks $child 'Final CLI child proof';Require ($proof.checks -eq $child.checks.Count) 'Final CLI child assertion count must match its report';$proofs.Add($proof)
    }
    $stage=0
    foreach($program in $cli.productionExecutables){
        ++$stage;$index=0
        foreach($case in $frontend){
            $source=$case.sources[0];$folder=Join-Path $run ('stage'+$stage+'/frontend'+$index);$null=New-Item -ItemType Directory -Force -Path $folder
            $path=Join-Path $folder 'input.bas';[IO.File]::WriteAllText($path,[string]$source.source,$utf8)
            $resolved=@($definition.cases|Where-Object id -CEQ $case.id);Require ($resolved.Count -eq 1 -and $resolved[0].outcome -ceq 'frontend') 'Retained frontend case must have one independent definition result'
            $witness=@($resolved[0].witnesses|Where-Object id -CEQ $case.expected.diagnostic.at);Require ($witness.Count -eq 1 -and $witness[0].source -ceq $source.id) 'Retained frontend diagnostic must use its exact original source witness'
            $expected=Frontend-Expected $case.expected.diagnostic.kind $witness[0]
            $before=Snapshot $folder;$input=Get-ArtifactIdentity $path
            $actual=Invoke-BoundedProcess $program.path @('--check',$path) $folder 30
            $after=Snapshot $folder;$unchanged=($before|ConvertTo-Json -Depth 5 -Compress) -ceq ($after|ConvertTo-Json -Depth 5 -Compress)
            $passed=-not $actual.timedOut -and $actual.exit -eq 1 -and $actual.stdout -ceq $expected -and $actual.stderr -ceq '' -and $unchanged
            $results.Add([pscustomobject]@{assertion="Stage$stage retained frontend $($case.id): exact diagnostic/status and original input/no artifacts";case=$case.id;source=$source.id;stage=$stage;input=$input;before=$before;after=$after;expected=[pscustomobject]@{exit=1;stdout=$expected;stderr=''};actual=$actual;passed=$passed})
            Require $passed "Retained frontend case differs:$($case.id),stage$stage";++$index
        }
    }
    Require ($results.Count -eq 6) 'All three retained frontend cases executed through both final CLI stages'
    foreach($pin in $pins){$now=Get-ArtifactIdentity $pin.path;Require ($now.sha256 -ceq $pin.sha256 -and $now.bytes -eq $pin.bytes) 'Accepted report/input/executable changed during frontend gate'}
    $null=Get-VerifiedBootstrapSelection $SelectionPath;$success=$true
}catch{$failure=$_.Exception.Message}
finally{
    [pscustomobject]@{schema='ube-semantic-input-proof-1';success=$success;qualified=$success;frontendOnly=$true;semanticImplemented=$false;sourceBuildCurrent=$success;failure=$failure;selection=$selection;acceptedSelection=$selection;definitionReport=$definitionIdentity;cliReport=$cliIdentity;inputs=$pins.ToArray();cliProofs=$proofs.ToArray();caseCount=$frontend.Count;semanticCasesDelegated=$semanticCount;processCount=$results.Count;checks=$results.ToArray();results=$results.ToArray();limits='Exactly three independently specified earlier frontend diagnostics through both qualified final CLI stages. Semantic CLI/native gates own all semantic cases; this gate predicts no semantic outcome. Exact original source bytes and complete file/directory inventories stay unchanged.'}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if(-not $success){throw $failure}
Write-Output 'PASS retained frontend only: three cases, six exact outcomes through both qualified final CLI stages.'
