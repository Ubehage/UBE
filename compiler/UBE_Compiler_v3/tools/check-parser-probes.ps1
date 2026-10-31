param([string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$fixture=Join-Path $root 'compiler/UBE_Compiler_v3/tests/parser/probes'
. (Join-Path $fixture 'abi.ps1')
. (Join-Path $fixture 'oracles.ps1')
. (Join-Path $fixture 'stack-safety.ps1')
$run=Join-Path $root ('bootstrap/out/parser-probes/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force|Out-Null
$utf8=New-Object Text.UTF8Encoding($false,$true)
$checks=New-Object 'System.Collections.Generic.List[object]'
$commands=New-Object 'System.Collections.Generic.List[object]'
$measurements=New-Object 'System.Collections.Generic.List[object]'
$stackSafety=New-Object 'System.Collections.Generic.List[object]'
$inputs=@();$baseline=$null;$selection=$null;$oracleCounts=$null;$rootObserver=$null;$success=$false;$failure=$null

function Invoke-Recorded([string]$File,[string[]]$Arguments=@(),[int]$Timeout=60){
    $result=Invoke-BoundedProcess $File $Arguments $root $Timeout
    $commands.Add($result)
    if($result.timedOut -or $result.exit -ne 0){throw "Parser probe process failed: $($result|ConvertTo-Json -Depth 5 -Compress)"}
    return $result
}
function Assert-Fact([bool]$Condition,[string]$Message,$Detail=$null){
    if(-not $Condition){throw $Message}
    $checks.Add([pscustomobject]@{assertion=$Message;detail=$Detail;passed=$true})
}
function Assert-Identity($Identity){
    $actual=Get-ArtifactIdentity $Identity.path
    if($actual.sha256 -cne $Identity.sha256 -or $actual.bytes -ne $Identity.bytes){throw "Identity changed: $($Identity.path)"}
}
function Get-ProjectSources([string]$Manifest){
    $directory=Split-Path $Manifest -Parent;$lines=[IO.File]::ReadAllLines($Manifest)
    foreach($line in $lines){if($line -match '^Source = "([^"]+)"$'){[IO.Path]::GetFullPath((Join-Path $directory $Matches[1]))}}
    foreach($line in $lines){if($line -match '^Reference = "([^"]+)"$'){Get-ProjectSources ([IO.Path]::GetFullPath((Join-Path $directory $Matches[1])))}}
}
function New-ProbeProject([string]$Mode){
    $directory=Join-Path $run ($Mode+'/project');New-Item -ItemType Directory -Path $directory -Force|Out-Null
    $sourceNames=@('SourceInput.bas')
    if($Mode -ceq 'traversal'){$sourceNames+=@('ScannerWords.bas','SourceScanner.bas','SourceEnvelope.bas')}
    $sources=@()
    foreach($name in $sourceNames){$sources+=Join-Path $root ('compiler/UBE_Compiler_v3/'+$name)}
    $sources+=Join-Path $fixture 'SyntaxStorage.bas'
    if($Mode -ceq 'traversal'){$sources+=Join-Path $fixture 'ExpressionTraversal.bas'}
    $sources+=Join-Path $fixture 'Entry.bas'
    $manifest=Join-Path $directory 'ParserProbe.UBE'
    $text="UBE-Project 1`nName = `"ParserProbe`"`nKind = `"Exe`"`nStartup = `"Main`"`n"
    foreach($source in $sources){
        $destination=Join-Path $directory ([IO.Path]::GetFileName($source))
        [IO.File]::Copy($source,$destination)
        if((Get-ArtifactIdentity $source).sha256 -cne (Get-ArtifactIdentity $destination).sha256){throw 'Probe source copy differs'}
        $text+='Source = "'+[IO.Path]::GetFileName($source)+"`"`n"
    }
    $library=Join-Path $root 'std-lib/UBECore.UBE'
    $reference=[Uri]::UnescapeDataString(([Uri]($directory.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$library).ToString())
    $text+='Reference = "'+$reference+"`"`n"
    [IO.File]::WriteAllText($manifest,$text,$utf8)
    return [pscustomobject]@{directory=$directory;manifest=$manifest;originals=$sources;ordered=@(Get-ProjectSources $manifest)}
}
function New-ObservedRuntime{
    $rawPath=Join-Path $run 'runtime-observed-raw.ll';$observedPath=Join-Path $run 'runtime-observed.ll'
    $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),'-S','-emit-llvm',(Join-Path $fixture 'runtime-observed.c'),'-o',$rawPath) 120
    $raw=[IO.File]::ReadAllText($rawPath)
    Assert-Fact ([regex]::Matches($raw,'(?m)^@ube_gc_root_count = [^\r\n]*global i64 0, align 8\r?$').Count -eq 1) 'Exact i64 runtime root counter is present'
    $pattern='(?m)^(?<indent>[ \t]*)store i64 (?<value>[^,\r\n]+), ptr @ube_gc_root_count, align 8(?<suffix>[^\r\n]*)\r?$'
    $stores=[regex]::Matches($raw,$pattern)
    Assert-Fact ($stores.Count -ge 3) 'All ordinary runtime root-count store sites are observable' $stores.Count
    $allStores=[regex]::Matches($raw,'(?m)^[ \t]*store[^\r\n]*ptr @ube_gc_root_count[^\r\n]*\r?$')
    Assert-Fact ($allStores.Count -eq $stores.Count) 'No runtime root-count store escapes the exact observation signature'
    if($raw -match '@parser_probe_root_count_changed'){throw 'Unexpected pre-existing root observer'}
    $observed=[regex]::Replace($raw,$pattern,[Text.RegularExpressions.MatchEvaluator]{param($match)
        $match.Value+"`n"+$match.Groups['indent'].Value+'call void @parser_probe_root_count_changed(i64 '+$match.Groups['value'].Value+')'
    })
    $observed+="`ndeclare void @parser_probe_root_count_changed(i64)`n"
    if([regex]::Matches($observed,'call void @parser_probe_root_count_changed\(i64 ').Count -ne $stores.Count){throw 'Root observation transform incomplete'}
    [IO.File]::WriteAllText($observedPath,$observed,$utf8)
    $object=Join-Path $run 'runtime-observed.o'
    $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-c','-x','ir',$observedPath,'-o',$object) 120
    $script:rootObserver=[pscustomobject]@{raw=(Get-ArtifactIdentity $rawPath);observed=(Get-ArtifactIdentity $observedPath);object=(Get-ArtifactIdentity $object);transformedRootCountStores=$stores.Count;scope='Callbacks receive every actual stored global root count under the original runtime lock; no production runtime source is changed.'}
    return $object
}
function Assert-Measurements($Rows,[string]$Mode){
    $costRows=@($Rows|Where-Object {$_.PSObject.Properties['phase']})
    $expectedCount=48;if($Mode -ceq 'traversal'){$expectedCount=36}
    Assert-Fact ($costRows.Count -eq $expectedCount) "$Mode complete predefined executed cost sample set" $costRows.Count
    $strides=@{1=4;2=16;3=24;4=20;5=32;6=16;7=8;12=4}
    foreach($row in $costRows){
        Assert-Fact (@('construct','project','traverse') -ccontains $row.phase) 'Observed row identifies a probe phase'
        Assert-Fact ($row.sourcePayloadCopiedBytes -eq 0) 'Executed source payload copies are zero'
        Assert-Fact ($row.runtimeArrayHeaderBytes -gt 0 -and $row.runtimeGcHeaderBytes -gt 0) 'Measured native array and collector header sizes are separate from logical payload'
        Assert-Fact ($row.events.Count -eq 24 -and $row.growthCopiesByRole.Count -eq 13 -and $row.capacityByRole.Count -eq 13 -and $row.requiredByRole.Count -eq 13) 'Observed event/role vectors match checked ABI'
        Assert-Fact ($row.observedPeakRootRecords -gt 0 -and $row.observedPeakRootStorageBytes -eq 32*$row.observedPeakRootRecords) 'Observed root storage includes actual generated/runtime roots'
        foreach($role in $strides.Keys){
            $capacity=[long]$row.capacityByRole[$role];$required=[long]$row.requiredByRole[$role];$growth=[long]$row.growthCopiesByRole[$role];$stride=[long]$strides[$role]
            if($row.phase -ceq 'construct' -and (($role -eq 3 -and $row.candidate -eq 0) -or ($role -eq 4 -and $row.candidate -eq 1))){$required=[long]$row.nodes}
            if($row.phase -ceq 'construct' -and $role -eq 12 -and $row.candidate -eq 1){$required=[long]$row.edges}
            if($required -gt 0){Assert-Fact ($capacity -ge $required -and $capacity -le [Math]::Max(8,2*$required)) "Role $role capacity grows geometrically"}
            $allowance=8*$stride
            Assert-Fact ($growth -le 2*$stride*$required+$allowance) "Role $role observed growth copy satisfies predefined live-length bound"
        }
        $payload=16*[long]$row.nodes
        if($row.phase -ceq 'construct'){
            if($row.candidate -eq 0){$payload=24*[long]$row.nodes}else{$payload=20*[long]$row.nodes+4*[long]$row.edges}
        }
        $expectedPublication=0L
        if($row.status -eq 1){
            $expectedPublication=$payload
            if($row.phase -ceq 'construct'){$expectedPublication+=$(if($row.candidate -eq 0){12}else{16})}
        }
        Assert-Fact ([long]$row.publicationCopiedBytesIncludingWrapper -eq $expectedPublication) 'Actual publication copies every expected scalar payload leaf'
        Assert-Fact ([long]$row.otherCopiedBytes -eq 0) 'Every observed payload copy belongs to an accounted growth, trim or publication operation'
        $trim=0L
        if($row.phase -ceq 'construct'){
            if($row.candidate -eq 0){$trim=[long]$row.trimCopiesByRole[3]}else{$trim=[long]$row.trimCopiesByRole[4]+[long]$row.trimCopiesByRole[12]}
        }else{$trim=[long]$row.trimCopiesByRole[2]}
        Assert-Fact ($row.status -ne 1 -or $trim -eq $payload) 'Successful exact trimming observes the complete logical output payload'
        Assert-Fact ($trim+[long]$row.publicationCopiedBytesIncludingWrapper -le 2*$payload+64) 'Exact trim/publication satisfies predefined payload and wrapper bound'
        $outputGrowth=[long]$row.growthCopiesByRole[2];$small=8*16
        if($row.phase -ceq 'construct'){
            if($row.candidate -eq 0){$outputGrowth=[long]$row.growthCopiesByRole[3];$small=8*24}else{$outputGrowth=[long]$row.growthCopiesByRole[4]+[long]$row.growthCopiesByRole[12];$small=8*(20+4)}
        }
        Assert-Fact ($row.status -ne 1 -or $row.nodes -le 8 -or $outputGrowth -gt 0) 'Nonempty growing output exercises the actual growth-copy observer'
        Assert-Fact ($outputGrowth+$trim+[long]$row.publicationCopiedBytesIncludingWrapper -le 4*$payload+64+$small) 'Combined output copying satisfies predefined logical-payload bound'
        if($row.phase -ceq 'construct'){
            Assert-Fact ($row.events[1] -le 2*[long]$row.nodes -and $row.events[7] -le [long]$row.edges -and $row.events[15] -le [long]$row.nodes -and $row.events[16] -le [long]$row.nodes) 'Executed construction validation and sibling-link actions satisfy predefined node/edge bounds'
        }
        if($row.phase -ceq 'project'){
            $reads=[long]$row.events[3]+[long]$row.events[5]+[long]$row.events[15]+[long]$row.events[16]
            $edges=[long]$row.events[9]+[long]$row.events[10]
            Assert-Fact ($reads -le 2*[long]$row.nodes -and $edges -le 2*[long]$row.edges) 'Executed projection read and validation actions satisfy predefined node/edge bounds'
        }
        if($row.phase -ceq 'traverse'){
            Assert-Fact ($row.tokenReads -gt 0 -and $row.actions -gt 0 -and ($row.status -ne 1 -or $row.events[2] -eq [long]$row.nodes)) 'Expression counters observe actual token work and every successfully emitted command'
            Assert-Fact ($row.tokenReads -le 64*([long]$row.tokens+1) -and $row.actions -le 64*([long]$row.tokens+[long]$row.events[2]+1)) 'Actual expression work satisfies predefined linear token/emitted-action bounds'
        }
    }
}
function Assert-MeasurementControls($Rows,[string]$Mode){
    $mutations=@('publication','unclassified')
    if($Mode -ceq 'storage'){$mutations+=@('validation','siblings')}
    foreach($mutation in $mutations){
        $clone=ConvertFrom-Json -InputObject ($Rows|ConvertTo-Json -Depth 20)
        $selected=@($clone|Where-Object {$_.PSObject.Properties['phase'] -and $_.status -eq 1 -and $_.nodes -gt 8 -and $_.candidate -eq 0 -and $_.phase -ceq $(if($Mode -ceq 'storage'){'construct'}else{'traverse'})})[0]
        $expected=''
        switch($mutation){
            'publication'{$selected.publicationCopiedBytesIncludingWrapper=0;$expected='Actual publication copies every expected scalar payload leaf'}
            'unclassified'{$selected.otherCopiedBytes=1;$expected='Every observed payload copy belongs to an accounted growth, trim or publication operation'}
            'validation'{$selected.events[15]=[long]$selected.nodes+1;$expected='Executed construction validation and sibling-link actions satisfy predefined node/edge bounds'}
            'siblings'{$selected.events[7]=[long]$selected.edges+1;$expected='Executed construction validation and sibling-link actions satisfy predefined node/edge bounds'}
        }
        $before=$checks.Count;$caught=''
        try{Assert-Measurements $clone $Mode}catch{$caught=$_.Exception.Message}
        finally{if($checks.Count -gt $before){$checks.RemoveRange($before,$checks.Count-$before)}}
        Assert-Fact ($caught -ceq $expected) "Measured $Mode budgets reject deliberately wrong $mutation observation"
    }
}
function Assert-Suites($Rows,[string]$RuntimeMode){
    $required=@('fixtures','domains','workers');if($RuntimeMode -ceq 'observed'){$required+=@('costs','faults','roots')}
    $suites=@($Rows|Where-Object {$_.PSObject.Properties['suite']})
    foreach($name in $required){
        $found=@($suites|Where-Object suite -CEQ $name)
        Assert-Fact ($found.Count -eq 1 -and $found[0].passed) "Native $RuntimeMode suite completed: $name" $(if($found.Count){$found[0]}else{$null})
        if($name -ceq 'roots'){Assert-Fact ($found[0].realBacked -and $found[0].attempts -gt 0) 'Root pressure uses actual backed root nodes and observed attempts'}
        if($name -ceq 'faults'){Assert-Fact ($found[0].boundaries -gt 0) 'Fault suite exercised actual allocation boundaries'}
    }
}

try{
    $shell=(Get-Process -Id $PID).Path
    $definition=Invoke-Recorded $shell @('-NoProfile','-File',(Join-Path $PSScriptRoot 'check-parser-contract.ps1'),'-SelectionPath',$SelectionPath) 120
    $paths=[regex]::Matches($definition.stdout,'(?m)^Evidence: (.+)$')
    Assert-Fact ($paths.Count -eq 1) 'Unique strict parser-definition baseline report'
    $baselineIdentity=Get-ArtifactIdentity $paths[0].Groups[1].Value.Trim()
    $baseline=Get-Content $baselineIdentity.path -Raw|ConvertFrom-Json
    Assert-Fact ($baseline.success -and $baseline.definitionOnly -and -not $baseline.parserImplemented -and $baseline.caseCount -eq 116 -and $baseline.baselineBeforeComplete -and $baseline.baselineAfterComplete) 'Frozen 116-case definition and accepted native cohort pass before probes' $baselineIdentity
    $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    foreach($identity in $baseline.baselineIdentities){Assert-Identity $identity}
    $inputPaths=@((Join-Path $PSScriptRoot 'check-parser-probes.ps1'),(Join-Path $root 'compiler/UBE_Compiler_v3/PARSER-PROBES.md'),$SelectionPath,$baselineIdentity.path)
    $inputPaths+=@((Get-ChildItem -LiteralPath $fixture -File).FullName)
    $inputPaths+=@($baseline.inputs|ForEach-Object path)
    $inputPaths+=@('SourceInput.bas','ScannerWords.bas','SourceScanner.bas','SourceEnvelope.bas'|ForEach-Object {Join-Path $root ('compiler/UBE_Compiler_v3/'+$_)})
    $inputPaths+=@((Join-Path $root 'std-lib/UBECore.UBE'),(Join-Path $root 'runtime/bootstrap_runtime.c'),(Join-Path $root 'runtime/value_storage.h'),(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),(Join-Path $root 'std-lib/tests/byte-storage/allocation-probe.h'),(Join-Path $root 'bootstrap/tools/verification.ps1'))
    $inputs=@($inputPaths|Sort-Object -Unique|ForEach-Object {Get-ArtifactIdentity $_})
    $oracleCounts=Write-ParserProbeOracles (Split-Path $fixture -Parent) (Join-Path $run 'oracles.h')
    Assert-Fact ($oracleCounts.syntaxTrees -eq 77) 'All 77 frozen syntax shapes have independent postorder/storage oracles' $oracleCounts
    $accepted=Get-Content $selection.manifest.path -Raw|ConvertFrom-Json
    $stage1=Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
    $stageOneIdentity=@($accepted.artifacts|Where-Object path -CEQ $stage1)
    Assert-Fact ($stageOneIdentity.Count -eq 1) 'Source-built stage one belongs to accepted cohort'
    Assert-Identity $stageOneIdentity[0]
    $stages=@($stage1,$selection.compiler.path)
    $observedRuntime=New-ObservedRuntime
    foreach($mode in @('storage','traversal')){
        $project=New-ProbeProject $mode
        $hashes=@()
        for($index=0;$index -lt 2;++$index){
            $stem=Join-Path (Split-Path $project.directory -Parent) ('stage'+($index+1));$ir=$stem+'.ll';$adapted=$stem+'-adapted.ll';$assembly=$stem+'-adapted.s'
            $null=Invoke-Recorded $stages[$index] @($project.manifest,$ir) 300
            $abi=Write-ParserProbeAbi $ir $adapted $project.ordered $mode
            $abi|ConvertTo-Json -Depth 8|Set-Content -LiteralPath ($stem+'-abi.json') -Encoding UTF8
            $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-S','-x','ir',$adapted,'-o',$assembly) 120
            foreach($runtimeMode in @('exact','observed')){
                $runtime=$selection.runtime.path;$defines=@();if($runtimeMode -ceq 'observed'){$runtime=$observedRuntime;$defines+=@('-DOBSERVE_PROBES')}
                if($mode -ceq 'storage'){$defines+='-DPROBE_STORAGE'}else{$defines+='-DPROBE_TRAVERSAL'}
                $exe=$stem+'-'+$runtimeMode+'.exe'
                $link=@('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-x','ir',$adapted,'-x','c',(Join-Path $fixture 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$runtime,$selection.unicodeRuntime.path,'-o',$exe)
                $null=Invoke-Recorded $selection.clang.path $link 120
                if($mode -ceq 'traversal'){
                    $safety=Get-ParserProbeStackSafety $ir $assembly $exe $abi
                    $stackSafety.Add([pscustomobject]@{stage=$index+1;runtime=$runtimeMode;facts=$safety})
                    Assert-Fact $safety.safeForGuardedDepth 'Compiled recursive candidate has guarded static-frame headroom before deep execution' $safety
                }
                $native=Invoke-Recorded $exe @() 240
                Assert-Fact ($native.stderr -ceq '' -and $native.stdout -match '(?m)^PASS parser probes assertions:(\d+) cases:(\d+)\r?$') "$mode stage$($index+1) $runtimeMode native comparisons, failures and cleanup passed"
                $nativeAssertions=[long]$Matches[1];$nativeCases=[long]$Matches[2]
                Assert-Fact ($nativeAssertions -gt 0 -and $nativeCases -ge $(if($mode -ceq 'storage'){77}else{$oracleCounts.expressionCases})) 'Native suite exercised the independent fixture cohort' ([pscustomobject]@{mode=$mode;stage=$index+1;runtime=$runtimeMode;assertions=$nativeAssertions;cases=$nativeCases})
                $rows=@($native.stdout -split "`n"|Where-Object {$_.StartsWith('{')}|ForEach-Object {$_|ConvertFrom-Json})
                Assert-Suites $rows $runtimeMode
                if($runtimeMode -ceq 'observed'){
                    Assert-Measurements $rows $mode
                    Assert-MeasurementControls $rows $mode
                    foreach($row in $rows){$measurements.Add([pscustomobject]@{mode=$mode;stage=$index+1;actual=$row;sampledProcessPeakWorkingSetBytes=$native.sampledPeakWorkingSetBytes})}
                }
            }
            foreach($negative in @('KIND','SPAN')){
                $exe=$stem+'-negative-'+$negative.ToLowerInvariant()+'.exe'
                $defines=@('-DNEGATIVE_PROBE_'+$negative);if($mode -ceq 'storage'){$defines+='-DPROBE_STORAGE'}else{$defines+='-DPROBE_TRAVERSAL'}
                $null=Invoke-Recorded $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-x','ir',$adapted,'-x','c',(Join-Path $fixture 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe)) 120
                $rejected=Invoke-BoundedProcess $exe @() $root 30;$commands.Add($rejected)
                Assert-Fact (-not $rejected.timedOut -and $rejected.exit -eq 1 -and $rejected.stderr.Contains('NEGATIVE_PROBE_'+$negative) -and $rejected.stderr.Contains('parser probe assertion')) "Native $mode comparator rejects deliberately wrong $negative through stage$($index+1)"
            }
            $hashes+=(Get-ArtifactIdentity $ir).sha256
        }
        Assert-Fact ($hashes[0] -ceq $hashes[1]) "$mode complete raw UBE LLVM is byte-identical through both accepted stages" $hashes[0]
        foreach($original in $project.originals){if((Get-ArtifactIdentity $original).sha256 -cne (Get-ArtifactIdentity (Join-Path $project.directory ([IO.Path]::GetFileName($original)))).sha256){throw 'Probe project copy changed'}}
    }
    foreach($identity in $inputs){Assert-Identity $identity}
    foreach($identity in $baseline.baselineIdentities){Assert-Identity $identity}
    Assert-Fact $true 'Probe/authority inputs and complete accepted baseline remain unchanged after native execution'
    $success=$true
}catch{$failure=$_.Exception.Message}
finally{
    [pscustomobject]@{schema='ube-parser-probes-proof-1';success=$success;qualifiedProbe=$success;productionParserImplemented=$false;failure=$failure;
        acceptedSelection=$selection;definitionBaseline=$baseline;inputs=$inputs;oracleCounts=$oracleCounts;rootObserver=$rootObserver;
        stackSafety=$stackSafety.ToArray();checks=$checks.ToArray();measurements=$measurements.ToArray();commands=$commands.ToArray();
        artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName});
        limits='Test-only storage and narrow expression traversal probes, not a production parser or complete grammar acceptance. Frozen 116-case definition and accepted source-built native cohort are audited unchanged, not republished. Source setup/scanning and C comparator work are separate from probe counters. Observed runtime counts executed operations/requests and every stored global root count; requested zero initialization is not physical writes. Static recursive frame accounting excludes other helper/CRT/native driver stack. Native private workers do not qualify a UBE scheduler. Recursive native-frame guard limitations must remain explicit in the candidate decision.'}|
        ConvertTo-Json -Depth 60|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if(-not $success){throw $failure}
Write-Output "PASS: $($checks.Count) parser-probe checks through both accepted source-built stages; production selection unchanged."
