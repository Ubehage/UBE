param(
    [string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'),
    [switch]$DiagnosticOnly
)
# Actual production compiler CLI gate. Diagnostic mode pins the accepted tools
# while allowing a deliberately stale source cohort during focused development.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$fixture=Join-Path $root 'compiler/UBE_Compiler_v3/tests/parser/cli'
. (Join-Path $fixture 'diagnostic-oom/check.ps1')
$run=Join-Path $root ('bootstrap/out/parser-cli/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force|Out-Null
$utf8=New-Object Text.UTF8Encoding($false,$true)
$inputs=@();$artifacts=@();$results=@();$commands=@();$checks=@()
$success=$false;$failure=$null;$selection=$null;$hashes=@();$executables=@();$diagnostics=@()
$productionManifest=Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'

# Records one concrete acceptance assertion with supporting evidence.
function Assert-Fact([bool]$Condition,[string]$Message,$Detail=$null) {
    if(-not $Condition){throw $Message}
    $script:checks+=[pscustomobject]@{assertion=$Message;detail=$Detail;passed=$true}
}
# Requires the exact bytes recorded before a run; sizes alone are insufficient.
function Assert-Identity($Identity) {
    $actual=Get-ArtifactIdentity $Identity.path
    if($actual.bytes -ne $Identity.bytes -or $actual.sha256 -cne $Identity.sha256){throw "CLI input/artifact changed: $($Identity.path)"}
}
# Enumerates the real project and explicit source-library closure in source order.
function Get-ProjectInputs([string]$Manifest) {
    $Manifest
    $directory=Split-Path $Manifest -Parent
    foreach($line in [IO.File]::ReadAllLines($Manifest)) {
        if($line -match '^Source = "([^"]+)"$'){[IO.Path]::GetFullPath((Join-Path $directory $Matches[1]))}
    }
    foreach($line in [IO.File]::ReadAllLines($Manifest)) {
        if($line -match '^Reference = "([^"]+)"$'){Get-ProjectInputs ([IO.Path]::GetFullPath((Join-Path $directory $Matches[1])))}
    }
}
# Executes a finite build command, retaining stdout/stderr and process status.
function Invoke-Recorded([string]$File,[string[]]$Arguments=@(),[int]$Timeout=60) {
    $actual=Invoke-BoundedProcess $File $Arguments $root $Timeout
    $script:commands+=$actual
    if($actual.timedOut -or $actual.exit -ne 0){throw "CLI build command failed: $($actual|ConvertTo-Json -Depth 8 -Compress)"}
    return $actual
}
# Compares all observable process outputs, including an empty stderr requirement.
function Compare-CliResult($Actual,[int]$Exit,[string]$Stdout,[string]$Stderr='') {
    return -not $Actual.timedOut -and $Actual.exit -eq $Exit -and $Actual.stdout -ceq $Stdout -and $Actual.stderr -ceq $Stderr
}
# Checks actual checking behavior while proving neither program nor source changed.
function Assert-Cli([int]$Stage,[string]$Executable,[string[]]$Arguments,[int]$Exit,[string]$Stdout,[string]$Label,[string]$Source='') {
    $program=Get-ArtifactIdentity $Executable;$sourceIdentity=$null
    if($Source){$sourceIdentity=Get-ArtifactIdentity $Source}
    $before=@(Get-ChildItem -LiteralPath $run -File -Recurse|Sort-Object FullName|ForEach-Object {Get-ArtifactIdentity $_.FullName})
    $actual=Invoke-BoundedProcess $Executable $Arguments $run 60
    $script:commands+=$actual
    $passed=Compare-CliResult $actual $Exit $Stdout ''
    $script:results+=[pscustomobject]@{stage=$Stage;case=$Label;expected=[pscustomobject]@{exit=$Exit;stdout=$Stdout;stderr=''};actual=$actual;passed=$passed;program=$program;source=$sourceIdentity}
    Assert-Fact $passed "Stage $Stage actual production CLI: $Label" $actual
    Assert-Identity $program
    if($sourceIdentity){Assert-Identity $sourceIdentity}
    $after=@(Get-ChildItem -LiteralPath $run -File -Recurse|Sort-Object FullName|ForEach-Object {Get-ArtifactIdentity $_.FullName})
    Assert-Fact (($before|ConvertTo-Json -Depth 5 -Compress) -ceq ($after|ConvertTo-Json -Depth 5 -Compress)) "Stage $Stage $Label changes no generated file bytes"
    return $actual
}
try {
    $definitionPath=Join-Path $fixture 'cases.json'
    $definition=Get-Content -LiteralPath $definitionPath -Raw -Encoding UTF8|ConvertFrom-Json
    Assert-Fact ($definition.schema -ceq 'ube-parser-cli-cases-1' -and $definition.cases.Count -eq 22 -and $definition.productionSources.Count -eq 16) 'Independent CLI cases and real-source cohort have the expected complete shape'
    $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    Assert-Fact ($selection.schema -ceq 'ube-v2-current-1') 'Selected source-built compiler identity has expected schema'
    foreach($property in $selection.PSObject.Properties){if($property.Name -ne 'schema'){Assert-Identity $property.Value}}
    $accepted=Get-Content -LiteralPath $selection.manifest.path -Raw|ConvertFrom-Json
    Assert-Fact $accepted.success 'Selected bootstrap cohort passed its recorded acceptance gate'
    foreach($identity in @($selection.compiler,$selection.runtime,$selection.unicodeRuntime)) {
        $record=@($accepted.artifacts|Where-Object path -CEQ $identity.path)
        Assert-Fact ($record.Count -eq 1 -and $record[0].sha256 -ceq $identity.sha256 -and $record[0].bytes -eq $identity.bytes) 'Selected executable/runtime matches immutable accepted manifest' $identity
    }
    $stage1=Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
    $stageIdentity=@($accepted.artifacts|Where-Object path -CEQ $stage1)
    Assert-Fact ($stageIdentity.Count -eq 1) 'Stage-one compiler belongs to the same accepted source-built cohort'
    Assert-Identity $stageIdentity[0]
    if(-not $DiagnosticOnly) {
        foreach($identity in $accepted.inputs){Assert-Identity $identity}
        Assert-Fact $true 'Every accepted source-cohort identity matches current bytes before CLI qualification'
    }
    $paths=@($SelectionPath,(Join-Path $PSScriptRoot 'check-parser-cli.ps1'),(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'compiler/UBE_Compiler_v3/PARSER-CONTRACT.md'))
    $paths+=@(Get-ChildItem -LiteralPath $fixture -File -Recurse|ForEach-Object FullName)
    $paths+=@(Get-ProjectInputs $productionManifest)
    $paths+=@($definition.productionSources|ForEach-Object {Join-Path $root $_})
    $inputs=@($paths|Sort-Object -Unique|ForEach-Object {Get-ArtifactIdentity $_})
    foreach($property in $selection.PSObject.Properties){if($property.Name -ne 'schema'){$inputs+=$property.Value}}
    $inputs+=$stageIdentity[0]
    if(-not $DiagnosticOnly){$inputs+=@($accepted.inputs)}
    $cases=@();$names=New-Object 'System.Collections.Generic.HashSet[string]'
    foreach($case in $definition.cases) {
        Assert-Fact ($names.Add([string]$case.name)) 'CLI case names are unique' $case.name
        $path=Join-Path $run ($case.name+$case.extension)
        if($case.PSObject.Properties['bytes']){[IO.File]::WriteAllBytes($path,[byte[]]$case.bytes)}
        else{[IO.File]::WriteAllBytes($path,$utf8.GetBytes([string]$case.source))}
        $cases+=[pscustomobject]@{name=$case.name;path=$path;exit=[int]$case.exit;stdout=[string]$case.stdout;identity=(Get-ArtifactIdentity $path)}
    }
    $sources=@($definition.productionSources|ForEach-Object {Join-Path $root $_})
    foreach($source in $sources){Assert-Fact ([IO.File]::Exists($source)) 'Listed real production source exists' $source}
    $stages=@($stage1,$selection.compiler.path)
    for($stage=0;$stage -lt 2;++$stage) {
        $ir=Join-Path $run ('stage'+($stage+1)+'.ll')
        $exe=Join-Path $run ('stage'+($stage+1)+'.exe')
        $null=Invoke-Recorded $stages[$stage] @($productionManifest,$ir) 300
        $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$ir,'-x','none',$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe) 120
        $hashes+=(Get-ArtifactIdentity $ir);$executables+=(Get-ArtifactIdentity $exe)
        $artifacts+=@((Get-ArtifactIdentity $ir),(Get-ArtifactIdentity $exe))
        $null=Assert-Cli ($stage+1) $exe @() 2 "usage: ube --check <source-file>`n" 'missing arguments'
        $null=Assert-Cli ($stage+1) $exe @('--other','ignored.bas') 2 "usage: ube --check <source-file>`n" 'unknown option'
        foreach($case in $cases) {
            $actual=Assert-Cli ($stage+1) $exe @('--check',$case.path) $case.exit $case.stdout $case.name $case.path
            if($stage -eq 0 -and $case.name -ceq 'valid-module') {
                Assert-Fact (-not (Compare-CliResult $actual 0 $case.stdout '')) 'CLI comparator rejects a deliberately wrong success exit'
                Assert-Fact (-not (Compare-CliResult $actual $case.exit 'different diagnostic' '')) 'CLI comparator rejects a deliberately wrong stdout diagnostic'
                Assert-Fact (-not (Compare-CliResult $actual $case.exit $case.stdout 'unexpected stderr')) 'CLI comparator rejects a deliberately wrong stderr expectation'
            }
        }
        foreach($source in $sources) {
            $null=Assert-Cli ($stage+1) $exe @('--check',$source) ([int]$definition.productionExpected.exit) ([string]$definition.productionExpected.stdout) ('real source '+[IO.Path]::GetFileName($source)) $source
        }
        $missing=Join-Path $run 'absent.bas'
        $null=Assert-Cli ($stage+1) $exe @('--check',$missing) 1 "source(1,1): error UBE1008: cannot open source; check its path and read permissions`n" 'missing source file'
        $diagnostic=Invoke-ParserDiagnosticRegression $ir @(Get-ProjectInputs $productionManifest|Where-Object {[IO.Path]::GetExtension($_) -ieq '.bas'}) $selection (Join-Path $run ('diagnostic-stage'+($stage+1))) $root
        $diagnostics+=$diagnostic
        $inputs+=@($diagnostic.inputs)
        $artifacts+=@($diagnostic.artifacts)+@($diagnostic.report)
        Assert-Fact ($diagnostic.cases -eq 27) "Stage $($stage+1) actual diagnostic helper passes all allocation-denial and real-admission controls" $diagnostic
    }
    Assert-Fact ($hashes.Count -eq 2 -and $hashes[0].sha256 -ceq $hashes[1].sha256 -and $hashes[0].bytes -eq $hashes[1].bytes) 'Both accepted bootstrap stages emit byte-identical raw production LLVM' $hashes
    foreach($identity in $inputs){Assert-Identity $identity}
    foreach($case in $cases){Assert-Identity $case.identity}
    foreach($identity in $artifacts){Assert-Identity $identity}
    Assert-Fact $true 'Every source, fixture, accepted tool and generated program remains byte-identical after both CLI runs'
    $success=$true
} catch {
    $failure=$_.Exception.Message
} finally {
    $report=[pscustomobject]@{
        schema='ube-parser-cli-evidence-1';success=$success;diagnosticOnly=[bool]$DiagnosticOnly;qualified=($success -and -not $DiagnosticOnly);
        failure=$failure;selection=$selection;inputs=$inputs;artifacts=$artifacts;productionLLVM=$hashes;productionExecutables=$executables;
        nativeExecutablesByteIdentical=($executables.Count -eq 2 -and $executables[0].sha256 -ceq $executables[1].sha256);
        checks=$checks;cases=$results;commands=$commands;diagnosticRegressions=$diagnostics;
        limits='Actual production CLI, bounded syntax consumption, and new parser diagnostic allocation-denial/admission controls only. Success still reports semantic checking unavailable. No semantic acceptance, backend, self-hosting, inactive-text recovery, parser cost or general failure-injection qualification follows. DiagnosticOnly bypasses current accepted-source identity audit and cannot qualify final source cohort. Native executable hashes are recorded separately from required raw LLVM identity.'
    }
    $reportPath=Join-Path $run 'report.json'
    [IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 30),$utf8)
    Write-Output "Evidence: $reportPath"
}
if(-not $success){[Console]::Error.WriteLine($failure);exit 1}
Write-Output "PASS production parser CLI: $($results.Count) exact process cases; diagnosticOnly=$([bool]$DiagnosticOnly)"
