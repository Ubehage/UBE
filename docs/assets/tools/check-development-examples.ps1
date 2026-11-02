[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$LocalCliReport,
    [string]$SelectionPath=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){
    $parent=Split-Path $root -Parent
    if(-not $parent -or $parent -ceq $root){throw 'Cannot find repository root'}
    $root=$parent
}
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$LocalCliReport=[IO.Path]::GetFullPath($LocalCliReport)
$local=Get-Content -LiteralPath $LocalCliReport -Raw | ConvertFrom-Json
if($local.schema -cne 'ube-local-cli-1' -or -not $local.success -or
    $local.acceptedSelection.compiler.sha256 -cne $selection.compiler.sha256 -or
    $local.acceptedSelection.manifest.sha256 -cne $selection.manifest.sha256){
    throw 'A successful local CLI replay for the current qualified selection is required'
}
$pins=[Collections.Generic.List[object]]::new()
function Pin($Identity){
    $now=Get-ArtifactIdentity $Identity.path
    if($now.bytes -ne $Identity.bytes -or $now.sha256 -cne $Identity.sha256){throw ('Qualified input changed: '+$Identity.path)}
    $pins.Add($Identity)
}
Pin (Get-ArtifactIdentity $LocalCliReport)
Pin $local.strictReport
$strict=Get-Content -LiteralPath $local.strictReport.path -Raw | ConvertFrom-Json
if(-not $strict.success -or -not $strict.qualified -or $strict.diagnosticOnly -or
    $strict.selection.compiler.sha256 -cne $selection.compiler.sha256 -or
    $strict.selection.manifest.sha256 -cne $selection.manifest.sha256 -or
    @($strict.productionExecutables).Count -ne 2 -or @($strict.checks).Count -eq 0){
    throw 'The exact strict source CLI report and both current source-built stages are required'
}
foreach($check in $strict.checks){if($check.passed -ne $true){throw 'An upstream CLI assertion did not pass'}}
$qualified=$strict.productionExecutables[1]
foreach($identity in @($qualified,$local.qualifiedProgram,$local.program)){
    if($identity.bytes -ne $qualified.bytes -or $identity.sha256 -cne $qualified.sha256){throw 'Installed CLI differs from the qualified stage-two CLI'}
    Pin $identity
}
if([IO.Path]::GetFullPath($local.qualifiedProgram.path) -cne [IO.Path]::GetFullPath($qualified.path)){throw 'Local replay names a different qualified CLI'}
$expectedCases=@($strict.cases | Where-Object stage -EQ 2)
$definitionPath=Join-Path $root 'compiler/UBE_Compiler_v3/tests/parser/cli/cases.json'
$definition=Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$expectedNames=@('missing arguments','unknown option')+@($definition.cases | ForEach-Object name)+@($definition.productionSources | ForEach-Object {'real source '+[IO.Path]::GetFileName($_)})+@('missing source file')
if($expectedCases.Count -ne $expectedNames.Count -or
    (@($expectedCases.case) -join "`n") -cne ($expectedNames -join "`n") -or
    @($local.cases).Count -ne $expectedCases.Count){throw 'The complete ordered local source CLI replay is required'}
for($i=0;$i -lt $expectedCases.Count;++$i){
    $record=$local.cases[$i];$expected=$expectedCases[$i]
    if($record.case -cne $expected.case -or $record.passed -ne $true -or $record.actual.timedOut -or
        $record.actual.exit -ne $expected.expected.exit -or $record.actual.stdout -cne $expected.expected.stdout -or
        $record.actual.stderr -cne $expected.expected.stderr){throw 'The local replay has an incomplete or failed case'}
}
foreach($identity in @($strict.inputs)+@($local.inputs)){Pin $identity}
foreach($path in @($SelectionPath,$PSCommandPath,$definitionPath,(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'docs/learn/first-program.html'))){Pin (Get-ArtifactIdentity $path)}
$binary=$local.program.path
$utf8=[Text.UTF8Encoding]::new($false)
$run=Join-Path $root ('bootstrap/out/docs-checks/'+[guid]::NewGuid().ToString('N'))
$inputDirectory=Join-Path $run 'input'
$null=[IO.Directory]::CreateDirectory($inputDirectory)
$tutorial=[IO.File]::ReadAllText((Join-Path $root 'docs/learn/first-program.html'))
$blocks=[regex]::Matches($tutorial,'(?s)<pre><code>(.*?)</code></pre>')
if($blocks.Count -lt 2){throw 'Tutorial source/project blocks missing'}
$sourcePath=Join-Path $inputDirectory 'Main.bas';$projectPath=Join-Path $inputDirectory 'Greeting.UBE'
[IO.File]::WriteAllText($sourcePath,[Net.WebUtility]::HtmlDecode($blocks[0].Groups[1].Value),$utf8)
[IO.File]::WriteAllText($projectPath,[Net.WebUtility]::HtmlDecode($blocks[1].Groups[1].Value),$utf8)
function InputSnapshot {
    return @((Get-ChildItem -LiteralPath $inputDirectory -Force -Recurse | Sort-Object FullName | ForEach-Object {
        if($_.PSIsContainer){[pscustomobject]@{path=$_.FullName;directory=$true;bytes=0;sha256=''}}
        else{$identity=Get-ArtifactIdentity $_.FullName;[pscustomobject]@{path=$identity.path;directory=$false;bytes=$identity.bytes;sha256=$identity.sha256}}
    })) | ConvertTo-Json -Depth 4 -Compress
}
$before=InputSnapshot
$checks=[Collections.Generic.List[object]]::new()
function Assert-Command([string]$Name,[string[]]$Arguments,[int]$ExpectedExit,[string]$ExpectedOutput){
    $actual=Invoke-BoundedProcess $binary $Arguments $root 60
    $stdout=$actual.stdout.Replace("`r`n","`n");$stderr=$actual.stderr.Replace("`r`n","`n")
    $expected=$ExpectedOutput;if($expected -cne ''){$expected+="`n"}
    $passed=-not $actual.timedOut -and $actual.exit -eq $ExpectedExit -and $stdout -ceq $expected -and $stderr -ceq ''
    $checks.Add([pscustomobject]@{assertion=$Name;arguments=$Arguments;expectedExit=$ExpectedExit;expectedStdout=$expected;actual=$actual;passed=$passed})
    if(-not $passed){throw ('Tutorial CLI mismatch: '+$Name)}
    if((InputSnapshot) -cne $before){throw 'Checking changed tutorial input bytes or created output files/directories'}
}
$success=$false;$failure=$null;$declarations=[Collections.Generic.HashSet[string]]::new()
try{
    Assert-Command 'native tutorial source' @('--check',$sourcePath) 0 ''
    Assert-Command 'tutorial project default jobs' @('--check',$projectPath) 0 ''
    Assert-Command 'tutorial project four jobs' @('--check',$projectPath,'--jobs','4') 0 ''
    Assert-Command 'project invalid jobs' @('--check',$projectPath,'--jobs','5') 2 'usage: ube --check <project.UBE> [--jobs N] (N: 1..4)'
    Assert-Command 'jobs unavailable for source-only command' @('--check',$sourcePath,'--jobs','1') 2 'usage: ube --check <source-file>'
    # Source declaration checks remain independent of tutorial/checker semantics.
    $sourceFiles=@(Get-ChildItem (Join-Path $root 'std-lib/src/portable') -Filter '*.bas')
    foreach($file in $sourceFiles){Pin (Get-ArtifactIdentity $file.FullName)}
    $sourceBodies=($sourceFiles | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
    $sourceBodies=[regex]::Replace($sourceBodies,'\b(?:Public|Private|Intrinsic)\s+','')
    $sourceBodies=[regex]::Replace($sourceBodies,'_\s*\r?\n',' ')
    $normalizedSource=[regex]::Replace($sourceBodies,'\s+',' ')
    foreach($page in @('byte-buffer','utf8','file-paths','thread-status','foundation-utilities')){
        $path=Join-Path $root "docs/library/$page.html";Pin (Get-ArtifactIdentity $path)
        $html=[IO.File]::ReadAllText($path)
        foreach($block in [regex]::Matches($html,'(?s)<pre><code>(.*?)</code></pre>')){
            $code=[Net.WebUtility]::HtmlDecode($block.Groups[1].Value)
            foreach($match in [regex]::Matches($code,'(?m)^(?:Function|Sub) [^\r\n]+')){
                $signature=[regex]::Replace($match.Value.Trim(),'\s+',' ')
                if(-not $normalizedSource.Contains($signature)){throw ('Documented declaration missing from source: '+$signature)}
                $null=$declarations.Add($signature)
            }
        }
    }
    if($declarations.Count -ne 35){throw ('Expected 35 distinct API declarations; found '+$declarations.Count)}
    foreach($identity in $pins){$now=Get-ArtifactIdentity $identity.path;if($now.bytes -ne $identity.bytes -or $now.sha256 -cne $identity.sha256){throw ('Pinned input changed: '+$identity.path)}}
    $null=Get-VerifiedBootstrapSelection $SelectionPath
    $success=$true
}catch{$failure=$_.Exception.Message}finally{
    [pscustomobject]@{schema='ube-docs-development-examples-1';success=$success;acceptedSelection=$selection;localReplay=(Get-ArtifactIdentity $LocalCliReport);strictReport=$local.strictReport;program=$local.program;inputs=$pins.ToArray();checks=$checks.ToArray();sourceMatchedDeclarations=$declarations.Count;inputSnapshotBefore=$before;inputSnapshotAfter=(InputSnapshot);failure=$failure;scope='Five authored tutorial CLI cases on the exact installed qualified stage-two binary and 35 source-matched API declarations. Checking success is bounded semantic acceptance, not code generation, runtime execution, full-language or library qualification.'}|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output ('Evidence: '+(Join-Path $run 'report.json'))
}
if(-not $success){throw $failure}
Write-Output 'PASS: five exact tutorial CLI cases, unchanged inputs/no output, and 35 source-matched API declarations.'
