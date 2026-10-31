param(
    [string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'),
    [switch]$DiagnosticOnly,
    [switch]$PrepareOnly,
    [switch]$FixtureDiagnostics,
    [ValidateRange(1,4)][int]$RootJobs=4,
    [string]$OnlyCase='',
    [string]$OnlySuite=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($FixtureDiagnostics){$DiagnosticOnly=$true}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$fixture=Join-Path $root 'compiler/UBE_Compiler_v3/tests/parser/native'
. (Join-Path $fixture 'abi.ps1')
. (Join-Path $fixture 'oracles.ps1')
. (Join-Path $fixture 'root-ranges.ps1')
$run=Join-Path $root ('bootstrap/out/parser/'+[Guid]::NewGuid().ToString('N'))
$project=Join-Path $run 'project'
New-Item -ItemType Directory -Path $project -Force|Out-Null
$utf8=New-Object Text.UTF8Encoding($false,$true)
$checks=New-Object 'System.Collections.Generic.List[object]'
$commands=New-Object 'System.Collections.Generic.List[object]'
$measurements=New-Object 'System.Collections.Generic.List[object]'
$fixtureResults=New-Object 'System.Collections.Generic.List[object]'
$rootRanges=New-Object 'System.Collections.Generic.List[object]'
$inputs=@();$selection=$null;$baseline=$null;$oracleCounts=$null;$rootObserver=$null;$success=$false;$failure=$null
$sourceNames=@('SourceInput.bas','ScannerWords.bas','SourceScanner.bas','SourceEnvelope.bas','SyntaxTree.bas','SyntaxExpressions.bas','SyntaxGrammar.bas','SourceSyntax.bas')
function Invoke-Recorded([string]$File,[string[]]$Arguments=@(),[int]$Timeout=60){
    $result=Invoke-BoundedProcess $File $Arguments $root $Timeout
    $commands.Add($result)
    if($result.timedOut -or $result.exit -ne 0){throw "Parser process failed: $($result|ConvertTo-Json -Depth 5 -Compress)"}
    return $result
}
function Assert-Fact([bool]$Condition,[string]$Message,$Detail=$null){
    if(-not $Condition){throw $Message};$checks.Add([pscustomobject]@{assertion=$Message;detail=$Detail;passed=$true})
}
function Assert-Identity($Identity){
    $actual=Get-ArtifactIdentity $Identity.path
    if($actual.sha256 -cne $Identity.sha256 -or $actual.bytes -ne $Identity.bytes){throw "Parser input/artifact changed: $($Identity.path)"}
}
function Get-ProjectSources([string]$Manifest){
    $directory=Split-Path $Manifest -Parent;$lines=[IO.File]::ReadAllLines($Manifest)
    foreach($line in $lines){if($line -match '^Source = "([^"]+)"$'){[IO.Path]::GetFullPath((Join-Path $directory $Matches[1]))}}
    foreach($line in $lines){if($line -match '^Reference = "([^"]+)"$'){Get-ProjectSources ([IO.Path]::GetFullPath((Join-Path $directory $Matches[1])))}}
}
function New-ObservedRuntime{
    $rawPath=Join-Path $run 'runtime-raw.ll';$observedPath=Join-Path $run 'runtime-observed.ll';$object=Join-Path $run 'runtime-observed.o'
    $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),'-S','-emit-llvm',(Join-Path $fixture 'runtime-observed.c'),'-o',$rawPath) 120
    $raw=[IO.File]::ReadAllText($rawPath)
    Assert-Fact ([regex]::Matches($raw,'(?m)^@ube_gc_root_count = [^\r\n]*global i64 0, align 8\r?$').Count -eq 1) 'Exact runtime root counter is present'
    $pattern='(?m)^(?<indent>[ \t]*)store i64 (?<value>[^,\r\n]+), ptr @ube_gc_root_count, align 8(?<suffix>[^\r\n]*)\r?$'
    $stores=[regex]::Matches($raw,$pattern);$all=[regex]::Matches($raw,'(?m)^[ \t]*store[^\r\n]*ptr @ube_gc_root_count[^\r\n]*\r?$')
    Assert-Fact ($stores.Count -ge 3 -and $stores.Count -eq $all.Count) 'Every actual runtime root-count store is observable' $stores.Count
    if($raw.Contains('@parser_root_changed')){throw 'Unexpected prior parser root observer'}
    $observed=[regex]::Replace($raw,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($match)$match.Value+"`n"+$match.Groups['indent'].Value+'call void @parser_root_changed(i64 '+$match.Groups['value'].Value+')'})
    $observed+="`ndeclare void @parser_root_changed(i64)`n"
    Assert-Fact ([regex]::Matches($observed,'call void @parser_root_changed\(i64 ').Count -eq $stores.Count) 'Root observer transform covers every stored count'
    [IO.File]::WriteAllText($observedPath,$observed,$utf8)
    $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-c','-x','ir',$observedPath,'-o',$object) 120
    $script:rootObserver=[pscustomobject]@{raw=(Get-ArtifactIdentity $rawPath);observed=(Get-ArtifactIdentity $observedPath);object=(Get-ArtifactIdentity $object);stores=$stores.Count}
    return $object
}
function Assert-Measurements($Rows){
    $costs=@($Rows|Where-Object {$_.PSObject.Properties['phase']})
    Assert-Fact ($costs.Count -eq 51) 'Complete predefined expression/control/unit/opaque-validation parser cost cohort' $costs.Count
    foreach($row in $costs){
        Assert-Fact ($row.phase -ceq 'parse' -and $row.events.Count -eq 9) 'Measurement identifies direct parser scope and checked event vector'
        Assert-Fact ($row.sourcePayloadCopiedBytes -eq 0) 'Direct parser copies zero source payload bytes'
        Assert-Fact ($row.tokenReads -gt 0 -and $row.tokenReads -eq $row.events[1]) 'Every reported token read equals an executed native record-read event'
        Assert-Fact ($row.transitions -gt 0 -and $row.tokenReads -le 64*([long]$row.tokens+1) -and $row.transitions -le 64*([long]$row.tokens+[long]$row.nodes+1)) 'Executed parser work satisfies predefined linear token/node budgets'
        Assert-Fact ($row.observedPeakRoots -gt 0 -and $row.runtimeArrayHeaderBytes -gt 0 -and $row.runtimeGcHeaderBytes -gt 0) 'Native roots and array/collector header sizes are observed separately'
        Assert-Fact ($row.otherCopiedBytes -eq 0) 'All actual payload copying belongs to growth, exact trim or publication'
        Assert-Fact ($row.workspaceInstances -gt 0 -and $row.workspaceMaximumRequestedSum -ge $row.workspaceMaximumLiveSum -and $row.workspaceBudgetViolations -eq 0 -and $row.expressionFrameBytes -eq 40 -and $row.controlFrameBytes -eq 32) 'Every observed expression/control workspace instance satisfies actual live-request, geometric capacity and copy budgets'
        if($row.status -eq 1){
            $payload=24*[long]$row.nodes;$pendingPayload=24*[long]$row.maximumLiveNodes
            Assert-Fact ($row.nodes -gt 0 -and $row.events[2] -ge $row.nodes -and $row.maximumLiveNodes -ge $row.nodes -and $row.events[2] -ge $row.maximumLiveNodes) 'Successful output and maximum live pending nodes are covered by executed writes'
            if(@('flat','wide','groups','prefix','power','mixed') -ccontains $row.family){Assert-Fact ($row.events[2] -eq $row.nodes -and $row.maximumLiveNodes -eq $row.nodes) 'Pure expression writes and live-node maximum equal final logical nodes'}
            if(@('initializer','default','bound') -ccontains $row.family -and $row.size -ge 64){Assert-Fact ($row.maximumLiveNodes -gt 4*$row.nodes) 'Opaque validation directly measures pending-node storage substantially larger than final output'}
            if($row.nodes -gt 1){Assert-Fact ($row.events[3] -gt 0 -and $row.events[8] -ge $row.nodes-1) 'Node reads and child attachment observations are connected to executed tree construction'}
            Assert-Fact ($row.growthCopiesByRole[2] -le 2*$pendingPayload+8*24) 'Actual node growth copies satisfy predefined maximum-live geometric bound'
            Assert-Fact ($row.trimCopiesByRole[2] -eq $payload) 'Exact trim copies the logical node payload once'
            Assert-Fact ($row.publicationCopiedBytes -eq $payload+12) 'Atomic publication copies the complete node payload and wrapper metadata once'
            Assert-Fact ($row.growthCopiesByRole[2]+$row.trimCopiesByRole[2]+$row.publicationCopiedBytes -le 2*$pendingPayload+2*$payload+64+8*24) 'Total output copies satisfy the predefined live-node and published-payload bound'
        }
    }
}
function Assert-MeasurementControls($Rows){
    foreach($mutation in @('source','reads','work','publication')){
        $clone=$Rows|ConvertTo-Json -Depth 30|ConvertFrom-Json;$row=@($clone|Where-Object {$_.PSObject.Properties['phase'] -and $_.status -eq 1 -and $_.nodes -gt 16})[0]
        switch($mutation){'source'{$row.sourcePayloadCopiedBytes=1;$expected='Direct parser copies zero source payload bytes'};'reads'{$row.tokenReads=0;$expected='Every reported token read equals an executed native record-read event'};'work'{$row.transitions=2147483647;$expected='Executed parser work satisfies predefined linear token/node budgets'};'publication'{$row.publicationCopiedBytes=0;$expected='Atomic publication copies the complete node payload and wrapper metadata once'}}
        $before=$checks.Count;$caught='';try{Assert-Measurements $clone}catch{$caught=$_.Exception.Message}finally{if($checks.Count -gt $before){$checks.RemoveRange($before,$checks.Count-$before)}}
        Assert-Fact ($caught -ceq $expected) "Measured parser budget rejects deliberately wrong $mutation observation"
    }
}
function Read-NativeRows($Actual,[switch]$RootProgress){
    $actual=$Actual
    Assert-Fact ($actual.stdout -match '(?m)^PASS native parser assertions:(\d+) cases:(\d+)\r?$') 'Bounded native parser subprocess completed its explicit assertions' ([pscustomobject]@{arguments=$actual.arguments;elapsedMs=$actual.elapsedMs})
    if($RootProgress){
        $lines=@($actual.stderr -split "`n"|Where-Object {$_.Trim() -ne ''})
        Assert-Fact ($lines.Count -ge 3 -and @($lines|Where-Object {$_ -notmatch '^ROOT(?:-PROGRESS|-COMPLETE)? actor=\d+ (?:required=\d+ first=\d+ last=\d+|available=\d+ required=\d+|attempts=\d+)\r?$'}).Count -eq 0) 'Root subprocess stderr contains only explicit measured-capacity progress'
    }else{Assert-Fact ($actual.stderr -ceq '') 'Native parser subprocess emitted no unexpected stderr'}
    foreach($row in @($actual.stdout -split "`n"|Where-Object {$_.StartsWith('{')}|ForEach-Object {$_|ConvertFrom-Json})){
        $row|Add-Member -NotePropertyName sampledProcessPeakWorkingSetBytes -NotePropertyValue $actual.sampledPeakWorkingSetBytes
        Write-Output $row
    }
}
function Invoke-NativeRows([string]$Exe,[string[]]$Arguments,[int]$Timeout=120,[switch]$RootProgress){
    $actual=Invoke-Recorded $Exe $Arguments $Timeout
    Read-NativeRows $actual -RootProgress:$RootProgress
}
function Invoke-ObservedSuites([string]$Exe,[int]$Stage){
    $rows=New-Object 'System.Collections.Generic.List[object]'
    foreach($suite in @('fixtures','domains','budgets','workers','admission','faults','observer-controls','costs')){
        foreach($row in @(Invoke-NativeRows $Exe @('--suite',$suite) 240)){$rows.Add($row)}
    }
    $requirements=@(Invoke-NativeRows $Exe @('--suite','root-requirements') 30)
    Assert-Fact ($requirements.Count -eq 4 -and @($requirements|Where-Object {$_.suite -cne 'root-requirement' -or -not $_.passed -or $_.required -lt 1}).Count -eq 0) 'Every grammar/source actor has a measured positive actual root-admission requirement'
    Assert-Fact (@($requirements.actor|Sort-Object -Unique).Count -eq 4) 'Measured root-admission actors are unique'
    $attempts=0L;$ranges=New-Object 'System.Collections.Generic.List[object]'
    foreach($requirement in @($requirements|Sort-Object actor)){
        $next=0
        while($next -le $requirement.required){
            $last=[Math]::Min($next+15,[int]$requirement.required)
            $ranges.Add([pscustomobject]@{actor=[int]$requirement.actor;first=$next;last=$last;required=[int]$requirement.required})
            $next=$last+1
        }
    }
    Invoke-ParserRootRanges $Exe $ranges.ToArray() (Join-Path $root 'bootstrap/tools/verification.ps1') $root $RootJobs|ForEach-Object {
        $task=$_.range;$actual=$_.actual;$commands.Add($actual)
        if($actual.timedOut -or $actual.exit -ne 0){throw "Bounded root range failed: $($actual|ConvertTo-Json -Depth 5 -Compress)"}
        $nativeRows=@(Read-NativeRows $actual -RootProgress)
        $range=@($nativeRows|Where-Object suite -CEQ 'root-range')
        Assert-Fact ($range.Count -eq 1 -and $range[0].passed -and $range[0].realBacked -and $range[0].actor -eq $task.actor -and $range[0].required -eq $task.required -and $range[0].first -eq $task.first -and $range[0].last -eq $task.last -and $range[0].attempts -eq $task.last-$task.first+1) 'Exhaustive real-root range covers every requested capacity exactly once' ([pscustomobject]@{stage=$Stage;actor=$task.actor;first=$task.first;last=$task.last;required=$task.required})
        if($task.last -eq $task.required){Assert-Fact ($range[0].successes -gt 0) 'At the measured root requirement the actor succeeds and retains exact results'}
        $attempts+=[long]$range[0].attempts;$rootRanges.Add([pscustomobject]@{stage=$Stage;actual=$range[0]})
        [pscustomobject]@{stage=$Stage;actor=$task.actor;completedFirst=$task.first;completedLast=$task.last;required=$task.required;maximumConcurrentRootProcesses=$RootJobs;completedRanges=$rootRanges.Count;completedAttempts=$attempts}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $run 'root-progress.json') -Encoding UTF8
        Write-Host "Parser roots stage$Stage actor$($task.actor): capacities $($task.first)..$($task.last) / $($task.required) passed"
    }
    foreach($requirement in $requirements){
        $next=0
        foreach($range in @($rootRanges|Where-Object {$_.stage -eq $Stage -and $_.actual.actor -eq $requirement.actor}|ForEach-Object actual|Sort-Object first)){
            Assert-Fact ($range.first -eq $next -and $range.last -ge $next) 'Canonical root-capacity coverage has no gaps, duplicates or overlapping ranges'
            $next=[int]$range.last+1
        }
        Assert-Fact ($next -eq [int]$requirement.required+1) 'Every capacity from zero through the measured requirement was exercised with real backed roots'
    }
    $rows.Add([pscustomobject]@{suite='roots';passed=$true;realBacked=$true;actors=4;attempts=$attempts;scope='Exact union of independently bounded, gap-free capacity ranges over actual one-million-record root pressure.'})
    return $rows.ToArray()
}
try{
    $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    Assert-Fact ($selection.schema -ceq 'ube-v2-current-1') 'Accepted source-built bootstrap selection has the expected schema'
    foreach($property in $selection.PSObject.Properties){if($property.Name -ne 'schema'){Assert-Identity $property.Value}}
    $accepted=Get-Content -LiteralPath $selection.manifest.path -Raw|ConvertFrom-Json
    Assert-Fact $accepted.success 'Selected source-built v2 cohort passed its original gate'
    if(-not $DiagnosticOnly -and -not $PrepareOnly){
        $definition=Invoke-Recorded (Get-Process -Id $PID).Path @('-NoProfile','-File',(Join-Path $PSScriptRoot 'check-parser-contract.ps1'),'-SelectionPath',$SelectionPath) 120
        $paths=[regex]::Matches($definition.stdout,'(?m)^Evidence: (.+)$');Assert-Fact ($paths.Count -eq 1) 'Unique strict parser-definition report'
        $baselineIdentity=Get-ArtifactIdentity $paths[0].Groups[1].Value.Trim();$baseline=Get-Content $baselineIdentity.path -Raw|ConvertFrom-Json
        Assert-Fact ($baseline.success -and $baseline.definitionOnly -and $baseline.caseCount -eq 116 -and $baseline.baselineBeforeComplete -and $baseline.baselineAfterComplete) 'Frozen 116-case definition and complete accepted baseline pass before production acceptance' $baselineIdentity
        foreach($identity in $baseline.baselineIdentities){Assert-Identity $identity}
    }
    $paths=@((Join-Path $PSScriptRoot 'check-parser.ps1'),$SelectionPath,(Join-Path $root 'runtime/bootstrap_runtime.c'),(Join-Path $root 'runtime/value_storage.h'),(Join-Path $root 'std-lib/UBECore.UBE'),(Join-Path $root 'bootstrap/tools/verification.ps1'))
    $paths+=@(Get-ChildItem -LiteralPath $fixture -File|ForEach-Object FullName)
    $paths+=@('expressions.json','statements.json','units.json'|ForEach-Object {Join-Path (Split-Path $fixture -Parent) $_})
    $paths+=@($sourceNames|ForEach-Object {Join-Path $root ('compiler/UBE_Compiler_v3/'+$_)})
    if($baseline){$paths+=@($baseline.inputs|ForEach-Object path)}
    $inputs=@($paths|Sort-Object -Unique|ForEach-Object {Get-ArtifactIdentity $_})
    $oracleCounts=Write-NativeParserOracles (Split-Path $fixture -Parent) (Join-Path $run 'oracles.h')
    Assert-Fact ($oracleCounts.frozenCaseCount -eq 116 -and $oracleCounts.supplementalCaseCount -eq 72) 'All frozen and focused supplemental parser cases retain independently resolved expected source spans and shapes' $oracleCounts
    foreach($name in $sourceNames){[IO.File]::Copy((Join-Path $root ('compiler/UBE_Compiler_v3/'+$name)),(Join-Path $project $name))}
    [IO.File]::Copy((Join-Path $fixture 'Entry.bas'),(Join-Path $project 'Entry.bas'))
    $manifest=Join-Path $project 'ParserAcceptance.UBE';$manifestText="UBE-Project 1`nName = `"ParserAcceptance`"`nKind = `"Exe`"`nStartup = `"Main`"`n"
    foreach($name in $sourceNames+@('Entry.bas')){$manifestText+='Source = "'+$name+"`"`n"}
    $library=Join-Path $root 'std-lib/UBECore.UBE';$reference=[Uri]::UnescapeDataString(([Uri]($project.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$library).ToString());$manifestText+='Reference = "'+$reference+"`"`n"
    [IO.File]::WriteAllText($manifest,$manifestText,$utf8);$ordered=@(Get-ProjectSources $manifest)
    $inputs+=@($ordered|Where-Object {-not $_.StartsWith($project,[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object {Get-ArtifactIdentity $_})
    if($PrepareOnly){$success=$true}
    else{
        $stage1=Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe';$stageIdentity=@($accepted.artifacts|Where-Object path -CEQ $stage1)
        Assert-Fact ($stageIdentity.Count -eq 1) 'Stage one belongs to accepted source-built cohort';Assert-Identity $stageIdentity[0];$inputs+=$stageIdentity[0];$stages=@($stage1,$selection.compiler.path)
        $observedRuntime=New-ObservedRuntime;$hashes=@()
        $stageCount=2;if($FixtureDiagnostics){$stageCount=1}
        for($stage=0;$stage -lt $stageCount;++$stage){
            $stem=Join-Path $run ('stage'+($stage+1));$ir=$stem+'.ll';$adapted=$stem+'-adapted.ll'
            $null=Invoke-Recorded $stages[$stage] @($manifest,$ir) 300
            $abi=Write-NativeParserAbi $ir $adapted $ordered;$abi|ConvertTo-Json -Depth 8|Set-Content -LiteralPath ($stem+'-abi.json') -Encoding UTF8
            foreach($mode in @('exact','observed')){
                if($FixtureDiagnostics -and $mode -ceq 'observed'){continue}
                $runtime=$selection.runtime.path;$defines=@();if($mode -ceq 'observed'){$runtime=$observedRuntime;$defines+=@('-DPARSER_OBSERVED')}
                $exe=$stem+'-'+$mode+'.exe';$arguments=@('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-x','ir',$adapted,'-x','c',(Join-Path $fixture 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$runtime,$selection.unicodeRuntime.path,'-o',$exe)
                $null=Invoke-Recorded $selection.clang.path $arguments 120
                if($FixtureDiagnostics){
                    foreach($case in $oracleCounts.cases){
                        $actual=Invoke-BoundedProcess $exe @('--case',$case.name) $root 30;$commands.Add($actual)
                        $passed=-not $actual.timedOut -and $actual.exit -eq 0 -and $actual.stderr -ceq '' -and $actual.stdout -match 'PASS native parser assertions:\d+ cases:1'
                        $fixtureResults.Add([pscustomobject]@{name=$case.name;entry=$case.entry;outcome=$case.outcome;passed=$passed;actual=$actual})
                    }
                    $failed=@($fixtureResults|Where-Object {-not $_.passed})
                    if($failed.Count){throw "Parser fixture diagnostics: $($failed.Count)/$($oracleCounts.caseCount) failed: $(($failed|ForEach-Object name) -join ', ')"}
                    continue
                }
                $nativeArgs=@();if($OnlyCase){$nativeArgs=@('--case',$OnlyCase)};if($OnlySuite){$nativeArgs=@('--suite',$OnlySuite)}
                if($OnlySuite -and $mode -ceq 'exact'){continue}
                if($mode -ceq 'observed' -and -not $OnlyCase -and -not $OnlySuite){$rows=@(Invoke-ObservedSuites $exe ($stage+1))}
                else{$rows=@(Invoke-NativeRows $exe $nativeArgs 240)}
                if(-not $OnlyCase -and -not $OnlySuite){
                    $required=@('fixtures','domains','budgets','workers','admission');if($mode -ceq 'observed'){$required+=@('faults','roots','observer-controls','costs')}
                    foreach($suite in $required){$found=@($rows|Where-Object {$_.PSObject.Properties['suite'] -and $_.suite -ceq $suite});Assert-Fact ($found.Count -eq 1 -and $found[0].passed) "Stage$($stage+1) $mode complete native suite $suite"}
                    $fixtures=@($rows|Where-Object {$_.PSObject.Properties['suite'] -and $_.suite -ceq 'fixtures'})[0];Assert-Fact ($fixtures.cases -eq $oracleCounts.caseCount) 'Native parser executes every frozen and supplemental syntax/rejection/deferred case'
                    if($mode -ceq 'observed'){Assert-Measurements $rows;Assert-MeasurementControls $rows}
                }
                foreach($row in $rows){$measurements.Add([pscustomobject]@{stage=$stage+1;mode=$mode;actual=$row})}
            }
            if(-not $OnlySuite -and -not $FixtureDiagnostics){
                foreach($negative in @('KIND','SPAN')){
                    $exe=$stem+'-negative-'+$negative.ToLowerInvariant()+'.exe';$null=Invoke-Recorded $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-I',$run,('-DNEGATIVE_PARSER_'+$negative),'-x','ir',$adapted,'-x','c',(Join-Path $fixture 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror','-x','none',$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe)) 120
                    $rejected=Invoke-BoundedProcess $exe @('--case','additive-binds-less-tightly-than-multiplication') $root 30;$commands.Add($rejected)
                    Assert-Fact (-not $rejected.timedOut -and $rejected.exit -eq 1 -and $rejected.stderr.Contains('NEGATIVE_PARSER_'+$negative) -and $rejected.stderr.Contains('parser assertion')) "Stage$($stage+1) native comparator rejects deliberately wrong $negative"
                }
            }
            $hashes+=(Get-ArtifactIdentity $ir).sha256
        }
        if(-not $FixtureDiagnostics){Assert-Fact ($hashes[0] -ceq $hashes[1]) 'Complete intact parser raw LLVM is byte-identical through both accepted source-built stages' $hashes[0]}
        foreach($identity in $inputs){Assert-Identity $identity};if($baseline){foreach($identity in $baseline.baselineIdentities){Assert-Identity $identity}}
        Assert-Fact $true 'All actual parser inputs and accepted baseline identities remain unchanged after native acceptance'
        $success=$true
    }
}catch{$failure=$_.Exception.Message}
finally{
    [pscustomobject]@{schema='ube-parser-native-proof-1';success=$success;qualifiedParser=($success -and -not $DiagnosticOnly -and -not $PrepareOnly -and -not $OnlyCase -and -not $OnlySuite);diagnosticOnly=[bool]$DiagnosticOnly;prepareOnly=[bool]$PrepareOnly;onlyCase=$OnlyCase;onlySuite=$OnlySuite;failure=$failure;fixtureDiagnostics=$fixtureResults.ToArray();acceptedSelection=$selection;definitionBaseline=$baseline;inputs=$inputs;oracleCounts=$oracleCounts;rootObserver=$rootObserver;rootRanges=$rootRanges.ToArray();checks=$checks.ToArray();measurements=$measurements.ToArray();commands=$commands.ToArray();artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Bounded native MODULE grammar and diagnostic fragment contexts only. Exact graph comparison uses the explicit leaf-Header detail projection permitted by logical witnesses; the entire underlying graph is still checked for ownership/order/spans. Conditional preflight only defers pending selection. No semantic checking, literal conversion, inactive-text recovery, code generation or UBE worker scheduler is qualified. Direct parser observations exclude source construction/scanning and C oracle work; requested zero bytes are not physical writes; process samples include test harness/fault fixtures. Root-pressure cost includes real one-million-record registration and absent-root cleanup scans; it is recorded separately from ordinary parser work. Exhaustive capacities are split into bounded gap-free subprocess ranges without reducing coverage.'}|ConvertTo-Json -Depth 70|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if(-not $success){throw $failure}
Write-Output "PASS: $($checks.Count) parser checks; diagnostic=$DiagnosticOnly prepare=$PrepareOnly; accepted selection unchanged."
