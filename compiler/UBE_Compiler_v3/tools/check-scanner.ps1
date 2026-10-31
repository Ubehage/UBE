param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'),[switch]$DiagnosticOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$fixture=Join-Path $root 'compiler/UBE_Compiler_v3/tests/scanner/native'
. (Join-Path $fixture 'oracles.ps1')
$run=Join-Path $root ('bootstrap/out/scanner/'+[Guid]::NewGuid().ToString('N'))
$project=Join-Path $run 'project'
New-Item -ItemType Directory -Path $project -Force | Out-Null
$utf8=New-Object Text.UTF8Encoding($false,$true)
$sourceNames=@('SourceInput.bas','SourceFile.bas','ScannerWords.bas','SourceScanner.bas','SourceEnvelope.bas')
$paths=@('compiler/UBE_Compiler_v3/tools/check-scanner.ps1','compiler/UBE_Compiler_v3/SCANNER-CONTRACT.md','std-lib/UBECore.UBE','runtime/bootstrap_runtime.c','runtime/value_storage.h','std-lib/tests/managed-storage/copy-probe.h','std-lib/tests/byte-storage/allocation-probe.h','bootstrap/tools/verification.ps1')|ForEach-Object {Join-Path $root $_}
$paths+=@($sourceNames|ForEach-Object {Join-Path $root ('compiler/UBE_Compiler_v3/'+$_)})
$paths+=@(Get-ChildItem -LiteralPath $fixture -File|ForEach-Object FullName)
$paths+=@('tokens.json','envelopes.json','words.json'|ForEach-Object {Join-Path (Split-Path $fixture -Parent) $_})
$inputs=@();$checks=@();$commands=@();$measurements=@();$success=$false;$failure=$null;$selection=$null;$fixtureCounts=$null
function Invoke-Recorded([string]$File,[string[]]$Arguments=@(),[int]$Timeout=60) {
    $result=Invoke-BoundedProcess $File $Arguments $root $Timeout
    $script:commands+=$result
    if($result.timedOut -or $result.exit -ne 0){throw "Scanner process failed: $($result|ConvertTo-Json -Compress -Depth 5)"}
    return $result
}
function Get-ProjectSources([string]$Manifest){
    $directory=Split-Path $Manifest -Parent;$lines=[IO.File]::ReadAllLines($Manifest)
    foreach($line in $lines){if($line -match '^Source = "([^"]+)"$'){[IO.Path]::GetFullPath((Join-Path $directory $Matches[1]))}}
    foreach($line in $lines){if($line -match '^Reference = "([^"]+)"$'){Get-ProjectSources ([IO.Path]::GetFullPath((Join-Path $directory $Matches[1])))}}
}
try {
    $inputs=@($paths|ForEach-Object {Get-ArtifactIdentity $_})
    $fixtureCounts=[pscustomobject]@{tokenVectors=@((Get-Content (Join-Path (Split-Path $fixture -Parent) 'tokens.json') -Raw -Encoding UTF8|ConvertFrom-Json).cases).Count;envelopeVectors=@((Get-Content (Join-Path (Split-Path $fixture -Parent) 'envelopes.json') -Raw -Encoding UTF8|ConvertFrom-Json).cases).Count;wordRoles=@((Get-Content (Join-Path (Split-Path $fixture -Parent) 'words.json') -Raw -Encoding UTF8|ConvertFrom-Json).words).Count;envelopeRegressions=@((Get-Content (Join-Path $fixture 'regressions.json') -Raw -Encoding UTF8|ConvertFrom-Json).cases).Count}
    if($fixtureCounts.tokenVectors -ne 62 -or $fixtureCounts.envelopeVectors -ne 40 -or $fixtureCounts.wordRoles -ne 174){throw 'Original scanner acceptance cohort count changed'}
    $fixtureCounts|Add-Member -NotePropertyName tokenRegressions -NotePropertyValue @((Get-Content (Join-Path $fixture 'regressions.json') -Raw -Encoding UTF8|ConvertFrom-Json).tokenCases).Count
    $inputs+=Get-ArtifactIdentity $SelectionPath
    $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    if($selection.schema -cne 'ube-v2-current-1'){throw 'Unexpected selection schema'}
    foreach($property in $selection.PSObject.Properties){if($property.Name -ne 'schema'){
        if((Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256){throw "Selected artifact changed: $($property.Name)"};$inputs+=$property.Value
    }}
    $accepted=Get-Content -LiteralPath $selection.manifest.path -Raw|ConvertFrom-Json
    if(-not $accepted.success){throw 'Selected compiler acceptance is not successful'}
    foreach($identity in @($selection.compiler,$selection.runtime,$selection.unicodeRuntime)){
        $found=@($accepted.artifacts|Where-Object path -CEQ $identity.path)
        if($found.Count -ne 1 -or $found[0].sha256 -cne $identity.sha256){throw 'Selected artifact differs from accepted manifest'}
    }
    if(-not $DiagnosticOnly){
        foreach($identity in $accepted.inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw "Accepted cohort input changed: $($identity.path)"}}
        $inputs+=@($accepted.inputs)
    }
    $stage1=Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
    $stageIdentity=@($accepted.artifacts|Where-Object path -CEQ $stage1)
    if($stageIdentity.Count -ne 1 -or (Get-ArtifactIdentity $stage1).sha256 -cne $stageIdentity[0].sha256){throw 'Stage-one identity differs'}
    $inputs+=$stageIdentity[0];$stages=@($stage1,$selection.compiler.path)
    foreach($name in $sourceNames){Copy-Item -LiteralPath (Join-Path $root ('compiler/UBE_Compiler_v3/'+$name)) -Destination (Join-Path $project $name)}
    Copy-Item -LiteralPath (Join-Path $fixture 'Entry.bas') -Destination (Join-Path $project 'Entry.bas')
    $manifest=Join-Path $project 'ScannerProof.UBE'
    $manifestText="UBE-Project 1`nName = `"ScannerProof`"`nKind = `"Exe`"`nStartup = `"Main`"`n"
    foreach($name in $sourceNames+@('Entry.bas')){$manifestText+='Source = "'+$name+"`"`n"}
    $manifestText+="Reference = `"../../../../../std-lib/UBECore.UBE`"`n"
    [IO.File]::WriteAllText($manifest,$manifestText,$utf8)
    $ordered=@(Get-ProjectSources $manifest)
    $inputs+=@($ordered|Where-Object {-not $_.StartsWith($project,[StringComparison]::OrdinalIgnoreCase)}|ForEach-Object {Get-ArtifactIdentity $_})
    Write-NativeScannerOracles (Split-Path $fixture -Parent) (Join-Path $run 'oracles.h')
    $procedures=@{};$types=@{};$procedureIndex=0;$typeIndex=0
    foreach($source in $ordered){
        $text=[IO.File]::ReadAllText($source)
        foreach($match in [regex]::Matches($text,'(?m)^(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){
            if($procedures.ContainsKey($match.Groups[1].Value)){throw 'Duplicate test bridge procedure'}
            $procedures[$match.Groups[1].Value]='ube.p'+$procedureIndex;++$procedureIndex
        }
        foreach($match in [regex]::Matches($text,'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$match.Groups[1].Value]='%ube.type.'+$typeIndex;++$typeIndex}
    }
    $bindings=@{BEGIN=@('BeginSourceInput','i1','ptr,i32');APPEND=@('AppendSourceInput','i1','ptr,ptr,i32,i32,ptr');FINISH=@('TryFinishSourceInput','i1','ptr,ptr,ptr');SCAN=@('TryScanSource','i1','ptr,i32,i32,ptr,ptr');ENVELOPE=@('TryReadSourceEnvelope','i1','ptr,i32,ptr,ptr');FEED=@('FeedUtf8Byte','i1','ptr,i8,ptr,ptr');BYTE=@('TryScannerByte','i1','ptr,i32,i32,ptr');RECORDCOPY=@('CopyScannerToken','void','ptr,ptr')}
    $observedRuntime=Join-Path $run 'observed-runtime.o'
    $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),'-c',(Join-Path $fixture 'runtime-observed.c'),'-o',$observedRuntime)
    $hashes=@()
    for($index=0;$index -lt 2;++$index){
        $stem=Join-Path $run ('stage'+($index+1));$ir=$stem+'.ll'
        $null=Invoke-Recorded $stages[$index] @($manifest,$ir) 300
        $raw=[IO.File]::ReadAllText($ir);$adapter=[IO.File]::ReadAllText((Join-Path $fixture 'adapters.ll'))
        foreach($key in $bindings.Keys){
            $binding=$bindings[$key];$symbol=$procedures[$binding[0]]
            $definitions=[regex]::Matches($raw,'(?m)^define '+$binding[1]+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
            if($definitions.Count -ne 1){throw "Missing exact bridge: $($binding[0])"}
            $actualTypes=@($definitions[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ','
            if($actualTypes -cne $binding[2]){throw "Unexpected bridge signature: $($binding[0]) = $actualTypes"}
            $adapter=$adapter.Replace('@'+$key+'@','@'+$symbol)
        }
        $expectedTypes=@{SourcePosition='i32, i32, i32, i32';SourceFailure=('i32, '+$types.SourcePosition);SourceDocument='ptr, i32, i32, i32';SourceToken=('i32, '+$types.SourcePosition+', '+$types.SourcePosition);ScannerFailure=('i32, '+$types.SourcePosition+', '+$types.SourcePosition);SourceEnvelope='i32, i32, i32, i32, i1'}
        foreach($name in $expectedTypes.Keys){if([regex]::Matches($raw,'(?m)^'+[regex]::Escape($types[$name]+' = type { '+$expectedTypes[$name]+' }')+'\r?$').Count -ne 1){throw "Unexpected production record: $name"}}
        if([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Unexpected entry wrapper'}
        $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @scanner_unused_entry(')
        $adapted=[regex]::Replace($adapted,'(?m)^define i1 @'+[regex]::Escape($procedures.FeedUtf8Byte)+'\(','define i1 @scanner_feed_body(')
        $adapted=[regex]::Replace($adapted,'(?m)^define i1 @'+[regex]::Escape($procedures.TryScannerByte)+'\(','define i1 @scanner_byte_body(')
        $adapted=[regex]::Replace($adapted,'(?m)^define void @'+[regex]::Escape($procedures.CopyScannerToken)+'\(','define void @scanner_record_copy_body(')
        if([regex]::Matches($raw,'(?m)^declare i32 @ube_value_try_resize\(ptr, i32, ptr, i32\)\r?$').Count -ne 1){throw 'Unexpected typed array resize ABI'}
        $adapted=$adapted.Replace('call i32 @ube_value_try_resize(','call i32 @scanner_runtime_resize(')
        $layout="`ndefine i64 @scanner_layout(i32 %index) {`n switch i32 %index, label %invalid [`n"
        $layoutTypes=@('SourceInput','SourceDocument','SourceToken','SourcePosition','SourceEnvelope')
        for($i=0;$i -lt $layoutTypes.Count;++$i){$layout+=" i32 $i, label %case$i`n"};$layout+=" ]`ninvalid:`n ret i64 -1`n"
        for($i=0;$i -lt $layoutTypes.Count;++$i){$layout+="case${i}:`n ret i64 ptrtoint (ptr getelementptr ("+$types[$layoutTypes[$i]]+", ptr null, i32 1) to i64)`n"};$layout+="}`n"
        $adaptedIr=$stem+'-adapted.ll';[IO.File]::WriteAllText($adaptedIr,$adapted+"`n"+$adapter+$layout,$utf8)
        foreach($instrumented in @($false,$true)){
            $mode='exact';$runtime=$selection.runtime.path;$defines=@()
            if($instrumented){$mode='observed';$runtime=$observedRuntime;$defines=@('-DOBSERVE_SCANNER')}
            $exe=$stem+'-'+$mode+'.exe'
            $null=Invoke-Recorded $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-x','ir',$adaptedIr,'-x','c',(Join-Path $fixture 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$runtime,$selection.unicodeRuntime.path,'-o',$exe)) 120
            $native=Invoke-Recorded $exe @() 120
            if($native.stderr -cne '' -or $native.stdout -notmatch '(?m)^PASS scanner assertions:(\d+)\r?$'){throw 'Unexpected native scanner result'}
            $checks+=[pscustomobject]@{stage=$index+1;mode=$mode;assertion='independent exact token/span/failure/word/split/worker/cleanup comparisons';assertions=[long]$Matches[1];passed=$true}
            if($instrumented){
                $rows=@($native.stdout -split "`n"|Where-Object {$_.StartsWith('{')}|ForEach-Object {$_|ConvertFrom-Json})
                if($rows.Count -ne 20){throw 'Wrong independent scanner cost sample count'}
                foreach($row in $rows){
                    $t=[long]$row.tokens;$r=[long]$row.stride
                    if($r -ne 36 -or $t -lt 2 -or $row.capacity -lt $t -or ($t -gt 8 -and $row.capacity -ge 2*$t) -or ($t -le 8 -and $row.capacity -ne 8)){throw 'Pinned geometric token capacity budget failed'}
                    $publication=[long]$row.copiedBytes-[long]$row.growthCopiedBytes+[long]$row.recordPublicationCopiedBytes
                    if($row.growthCopiedBytes -ge 2*$r*$t -or $publication -gt 2*$r*$t -or ($row.copiedBytes+$row.recordPublicationCopiedBytes) -ge 4*$r*$t){throw 'Pinned executed token copy budget failed'}
                    if($row.feedCalls -gt 2*$row.n){throw 'Pinned decoding traversal budget failed'}
                    if($row.sourcePayloadCopiedBytes -ne 0){throw 'Borrowed source payload was copied during scan'}
                }
                $measurements+=@($rows|ForEach-Object {[pscustomobject]@{stage=$index+1;actual=$_;sampledProcessPeakWorkingSetBytes=$native.sampledPeakWorkingSetBytes}})
            }
        }
        foreach($negative in @('TOKEN_KIND','TOKEN_POSITION')){
            $exe=$stem+'-negative-'+$negative.ToLowerInvariant()+'.exe'
            $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-I',$run,'-x','ir',$adaptedIr,'-x','c',(Join-Path $fixture 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror',('-DNEGATIVE_'+$negative),'-x','none',$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe) 120
            $rejected=Invoke-BoundedProcess $exe @() $root 30;$commands+=$rejected
            if($rejected.timedOut -or $rejected.exit -ne 1 -or $rejected.stderr -notmatch 'empty token 0 actual kind='){throw 'Native comparator did not reject mutated token observation'}
            $checks+=[pscustomobject]@{stage=$index+1;assertion=('native comparator rejects mutated '+$negative.ToLowerInvariant());passed=$true}
        }
        $hashes+=(Get-ArtifactIdentity $ir).sha256
    }
    if($hashes[0] -cne $hashes[1]){throw 'Complete production source raw LLVM differs between stages'}
    $checks+=[pscustomobject]@{assertion='byte-identical raw LLVM through both selected accepted stages';passed=$true}
    foreach($name in $sourceNames){if((Get-ArtifactIdentity (Join-Path $project $name)).sha256 -cne (Get-ArtifactIdentity (Join-Path $root ('compiler/UBE_Compiler_v3/'+$name))).sha256){throw 'Complete production copy changed'}}
    foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw "Proof input changed: $($identity.path)"}}
    $success=$true
}catch{$failure=$_.Exception.Message}
finally{
    [pscustomobject]@{schema='ube-scanner-native-proof-1';success=$success;qualified=($success -and -not $DiagnosticOnly);diagnosticOnly=[bool]$DiagnosticOnly;failure=$failure;fixtureCounts=$fixtureCounts;acceptedSelection=$selection;inputs=$inputs;checks=$checks;measurements=$measurements;commands=$commands;limits='Raw scanning/source-envelope recognition only. DiagnosticOnly explicitly skips accepted source cohort equality and never qualifies a scanner. Date candidates do not validate dates; no parser, conditional branch evaluation, binding or code generation is qualified. Native C workers qualify private outputs/shared immutable inputs, not UBE scheduling. calloc counters report requested zero initialization, not physical writes. Complete production UBE sources and declared UBECore reference are unchanged; only test ABI/observation wrappers are generated.';artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName})}|ConvertTo-Json -Depth 14|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if(-not $success){throw $failure}
if($DiagnosticOnly){Write-Output "PASS diagnostic only: $($checks.Count) checks; scanner remains unqualified."}else{Write-Output "PASS: $($checks.Count) native scanner acceptance checks through both accepted stages."}
