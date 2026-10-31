param([string]$SelectionPath=(Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/unicode/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run | Out-Null
$data=Join-Path $root 'std-lib/data/unicode/18.0.0'
$fixture=Join-Path $root 'std-lib/tests/unicode'
$paths=@('std-lib/tools/check-unicode.ps1','std-lib/tools/generate-unicode.ps1','std-lib/UNICODE-CONTRACT.md','std-lib/src/portable/Unicode.bas','std-lib/src/portable/Utf8Cursor.bas','std-lib/src/portable/Utf8.bas','std-lib/src/portable/ByteBuffer.bas','std-lib/tests/managed-storage/copy-probe.h','std-lib/tests/byte-storage/allocation-probe.h','runtime/bootstrap_runtime.c','bootstrap/tools/verification.ps1','bootstrap/include/ube/unicode_case_folding.hpp','bootstrap/include/ube/unicode_letter_ranges.hpp') | ForEach-Object {Join-Path $root $_}
$paths+=@(Get-ChildItem -LiteralPath $data,$fixture -File | ForEach-Object FullName)
$inputs=@($paths|ForEach-Object {Get-ArtifactIdentity $_})
$checks=@();$commands=@();$measurements=@();$selection=$null;$success=$false;$failure=$null
function Invoke-Recorded([string]$File,[string[]]$Arguments,[int]$Timeout=60) {
    $result=Invoke-BoundedProcess $File $Arguments $root $Timeout
    $script:commands+=$result
    if($result.timedOut -or $result.exit -ne 0){throw "Unicode process failed: $($result|ConvertTo-Json -Depth 5 -Compress)"}
    return $result
}
try {
    $provenance=Get-Content -LiteralPath (Join-Path $data 'provenance.json') -Raw|ConvertFrom-Json
    if($provenance.version -cne '18.0.0'){throw 'Wrong Unicode version'}
    foreach($file in $provenance.files){$actual=Get-ArtifactIdentity (Join-Path $data $file.name);if($actual.sha256 -cne $file.sha256 -or $actual.bytes -ne $file.bytes){throw "Raw Unicode hash/size differs: $($file.name)"}}
    $foldRaw=[IO.File]::ReadAllText((Join-Path $data 'CaseFolding.txt'))
    $categoryRaw=[IO.File]::ReadAllText((Join-Path $data 'DerivedGeneralCategory.txt'))
    if($foldRaw -notmatch '^# CaseFolding-18\.0\.0\.txt' -or $categoryRaw -notmatch '^# DerivedGeneralCategory-18\.0\.0\.txt' -or [IO.File]::ReadAllText((Join-Path $data 'ReadMe.txt')) -notmatch 'final data files for version 18\.0\.0'){throw 'Raw Unicode18 version/status differs'}
    $checks+='official raw Unicode18 version/status, exact recorded bytes/hashes and license present'
    # Independent exhaustive raw-data/header comparison. This does not make the
    # bootstrap headers authoritative: C also reads raw UCD at native test time.
    $expectedFold=[int[]]::new(0x110000);$actualFold=[int[]]::new(0x110000)
    $expectedLetter=[bool[]]::new(0x110000);$actualLetter=[bool[]]::new(0x110000)
    for($cp=0;$cp -lt 0x110000;++$cp){$expectedFold[$cp]=$cp;$actualFold[$cp]=$cp}
    $foldCount=0
    foreach($line in $foldRaw -split "`n") {
        $record=($line -split '#',2)[0] -split ';'
        if($record.Count -ge 3 -and @('C','S') -ccontains $record[1].Trim()) {
            $source=[Convert]::ToInt32($record[0].Trim(),16);$target=[Convert]::ToInt32($record[2].Trim(),16)
            if($expectedFold[$source] -ne $source){throw 'Duplicate raw C/S source'}
            $expectedFold[$source]=$target;++$foldCount
        }
    }
    foreach($line in $categoryRaw -split "`n") {
        $record=($line -split '#',2)[0] -split ';'
        if($record.Count -ge 2 -and @('Lu','Ll','Lt','Lm','Lo') -ccontains $record[1].Trim()) {
            $range=$record[0].Trim() -split '\.\.';$first=[Convert]::ToInt32($range[0],16);$last=if($range.Count -eq 2){[Convert]::ToInt32($range[1],16)}else{$first}
            for($cp=$first;$cp -le $last;++$cp){$expectedLetter[$cp]=$true}
        }
    }
    foreach($match in [regex]::Matches([IO.File]::ReadAllText((Join-Path $root 'bootstrap/include/ube/unicode_case_folding.hpp')),'CaseFoldMapping\{0x([0-9A-F]+), 0x([0-9A-F]+)\}')){$actualFold[[Convert]::ToInt32($match.Groups[1].Value,16)]=[Convert]::ToInt32($match.Groups[2].Value,16)}
    foreach($match in [regex]::Matches([IO.File]::ReadAllText((Join-Path $root 'bootstrap/include/ube/unicode_letter_ranges.hpp')),'CodePointRange\{0x([0-9A-F]+), 0x([0-9A-F]+)\}')){for($cp=[Convert]::ToInt32($match.Groups[1].Value,16);$cp -le [Convert]::ToInt32($match.Groups[2].Value,16);++$cp){$actualLetter[$cp]=$true}}
    for($cp=0;$cp -lt 0x110000;++$cp){if($expectedFold[$cp] -ne $actualFold[$cp] -or $expectedLetter[$cp] -ne $actualLetter[$cp]){throw ('Raw Unicode18 differs from bootstrap headers at U+{0:X}' -f $cp)}}
    if($foldCount -ne 1533){throw 'Unexpected Unicode18 C/S mapping count'}
    $checks+='all 1,114,112 code points: independent raw Unicode18 letter/simple-fold arrays equal bootstrap headers; 1533 C/S mappings'
    $generated=Join-Path $run 'Unicode.regenerated.bas'
    & (Join-Path $root 'std-lib/tools/generate-unicode.ps1') -OutputPath $generated
    if((Get-ArtifactIdentity $generated).sha256 -cne (Get-ArtifactIdentity (Join-Path $root 'std-lib/src/portable/Unicode.bas')).sha256){throw 'Checked-in Unicode source differs from offline regeneration'}
    $checks+='offline deterministic regeneration equals checked-in ordinary UBE source byte-for-byte'
    $inputs+=Get-ArtifactIdentity $SelectionPath
    $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    foreach($property in $selection.PSObject.Properties){if($property.Name -ne 'schema' -and (Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256){throw "Selection changed: $($property.Name)"}}
    $accepted=Get-Content -LiteralPath $selection.manifest.path -Raw|ConvertFrom-Json
    if(-not $accepted.success){throw 'Selected compiler acceptance failed'}
    foreach($identity in $accepted.inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw "Accepted input changed: $($identity.path)"}}
    $runtimeSource=Get-ArtifactIdentity (Join-Path $root 'runtime/bootstrap_runtime.c')
    $acceptedRuntimeSource=@($accepted.inputs|Where-Object path -CEQ $runtimeSource.path)
    if($acceptedRuntimeSource.Count -ne 1 -or $acceptedRuntimeSource[0].sha256 -cne $runtimeSource.sha256){throw 'Instrumented runtime source differs from accepted build input'}
    foreach($identity in @($selection.compiler,$selection.runtime,$selection.unicodeRuntime)){$found=@($accepted.artifacts|Where-Object path -CEQ $identity.path);if($found.Count -ne 1 -or $found[0].sha256 -cne $identity.sha256){throw 'Selected artifact differs from accepted manifest'}}
    $inputs+=@($accepted.inputs)+@($selection.manifest,$selection.compiler,$selection.runtime,$selection.unicodeRuntime,$selection.clang)
    $stageOne=Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
    $stageIdentity=@($accepted.artifacts|Where-Object path -CEQ $stageOne)
    if($stageIdentity.Count -ne 1 -or (Get-ArtifactIdentity $stageOne).sha256 -cne $stageIdentity[0].sha256){throw 'Stage one identity differs'}
    $inputs+=$stageIdentity[0]
    $sources=@((Join-Path $fixture 'Entry.bas'))+@('Utf8','ByteBuffer','Unicode','Utf8Cursor'|ForEach-Object {Join-Path $root ('std-lib/src/portable/'+$_+'.bas')})
    $manifest=Join-Path $run 'UnicodeProof.UBE'
    foreach($path in $sources){$copy=Join-Path $run (Split-Path $path -Leaf);Copy-Item -LiteralPath $path -Destination $copy;if((Get-ArtifactIdentity $copy).sha256 -cne (Get-ArtifactIdentity $path).sha256){throw 'Module copy differs'}}
    $projectLines=@('UBE-Project 1','Name = "UnicodeProof"','Kind = "Exe"','Startup = "Main"')+@($sources|ForEach-Object {'Source = "'+(Split-Path $_ -Leaf)+'"'})
    [IO.File]::WriteAllText($manifest,($projectLines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
    $procedures=@{};$procedureIndex=0
    foreach($path in $sources){foreach($match in [regex]::Matches([IO.File]::ReadAllText($path),'(?m)^(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){if($procedures.ContainsKey($match.Groups[1].Value)){throw 'Duplicate bridge name'};$procedures[$match.Groups[1].Value]='ube.p'+$procedureIndex;++$procedureIndex}}
    $runtime=Join-Path $run 'instrumented-runtime.o'
    $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-c','-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),(Join-Path $root 'runtime/bootstrap_runtime.c'),'-o',$runtime)
    $hashes=@()
    foreach($stage in @($stageOne,$selection.compiler.path)) {
        $index=$hashes.Count+1;$stem=Join-Path $run ('stage'+$index);$ir=$stem+'.ll'
        $null=Invoke-Recorded $stage @($manifest,$ir)
        $raw=[IO.File]::ReadAllText($ir);$hashes+=(Get-ArtifactIdentity $ir).sha256
        $adapter=[IO.File]::ReadAllText((Join-Path $fixture 'adapters.ll'))
        foreach($binding in @(@('LETTER','IsUnicodeLetter','i1','i32'),@('FOLD','SimpleFoldUnicode','i32','i32'),@('CURSOR','TryReadSourceScalar','i1','ptr,i32,ptr,ptr'))) {
            $symbol=$procedures[$binding[1]]
            $definition=[regex]::Matches($raw,'(?m)^define '+$binding[2]+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
            if($definition.Count -ne 1){throw "Missing bridge: $($binding[1])"}
            $types=($definition[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ','
            if($types -cne $binding[3]){throw "Unexpected bridge ABI: $($binding[1])"}
            $adapter=$adapter.Replace('@'+$binding[0]+'@','@'+$symbol)
        }
        $adapted=$raw.Replace('define i32 @main(','define i32 @unicode_unused_entry(')
        $feed=$procedures.FeedUtf8Byte
        $adapted=$adapted.Replace('define i1 @'+$feed+'(','define i1 @unicode_feed_body(')
        $adapter+="`ndeclare void @unicode_feed_called()`ndefine i1 @$feed(ptr %decoder, i8 %byte, ptr %scalar, ptr %complete) {`n  call void @unicode_feed_called()`n  %result = call i1 @unicode_feed_body(ptr %decoder, i8 %byte, ptr %scalar, ptr %complete)`n  ret i1 %result`n}`ndeclare void @unicode_comparison()`n"
        foreach($name in @('IsUnicodeLetter','SimpleFoldUnicode')) {
            $pattern='(?ms)^define [^\r\n]* @'+[regex]::Escape($procedures[$name])+'\([^\r\n]*\) \{.*?^\}'
            $region=[regex]::Matches($adapted,$pattern)
            if($region.Count -ne 1){throw 'Missing lookup instrumentation region'}
            $nonArithmetic=[regex]::Replace($region[0].Value,'(?m)^  %[^\r\n]* = call i32 @ube_checked_(add|sub|mod)_i32\([^\r\n]*\)\r?\n','')
            if($nonArithmetic -match '\bcall\b|\balloca\b.*ptr|\bgetelementptr\b'){throw 'Lookup unexpectedly depends on nonarithmetic calls or managed storage'}
            $observed=[regex]::Replace($region[0].Value,'(?m)^(  %[^\r\n]* = icmp )',"  call void @unicode_comparison()`n"+'$1')
            $adapted=$adapted.Replace($region[0].Value,$observed)
        }
        foreach($mode in @('accepted','instrumented')) {
            $adaptedPath=$stem+'-'+$mode+'.ll';[IO.File]::WriteAllText($adaptedPath,$adapted+"`n"+$adapter,[Text.UTF8Encoding]::new($false))
            $selectedRuntime=if($mode -eq 'accepted'){$selection.runtime.path}else{$runtime}
            $exe=$stem+'-'+$mode+'.exe'
            $null=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror',$adaptedPath,(Join-Path $fixture 'probe.c'),$selectedRuntime,$selection.unicodeRuntime.path,'-o',$exe)
            $result=Invoke-Recorded $exe @((Join-Path $data 'CaseFolding.txt'),(Join-Path $data 'DerivedGeneralCategory.txt'))
            if($result.stderr -cne '' -or $result.stdout -notmatch '^PASS Unicode18 all-codepoint letter/fold; all-scalar UTF8; malformed/bounds/neutral/immutable/Err; four workers; cleanup\nMEASURE comparisons-max:(\d+) feeds:(\d+) allocations:0 copied-bytes:0\n$'){throw "Native oracle output differs: $($result.stdout)$($result.stderr)"}
            $measurements+=[pscustomobject]@{stage=$index;runtime=$mode;maxLookupComparisons=[int]$Matches[1];actualFeedCalls=[long]$Matches[2];measuredAllocations=if($mode -eq 'instrumented'){0}else{$null};measuredPayloadCopiedBytes=if($mode -eq 'instrumented'){0}else{$null};elapsedMs=$result.elapsedMs;sampledPeakWorkingSetBytes=$result.sampledPeakWorkingSetBytes}
            $checks+="stage $index $mode`: native independent raw-UCD/all-scalar/malformed/Err/immutable/cleanup/four-worker oracles; instrumented actual lookup and feed work"
        }
    }
    if($hashes[0] -cne $hashes[1]){throw 'Raw LLVM differs between accepted stages'}
    $checks+='byte-identical raw LLVM through both accepted stages'
    foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw "Proof input changed: $($identity.path)"}}
    $success=$true
} catch {$failure=$_.Exception.Message}
finally {
    [pscustomobject]@{schema='ube-unicode-proof-1';success=$success;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks;measurements=$measurements;commands=$commands;limits='Ordinary Unicode/cursor implementation and exact intact module sources only. No scanner/parser/compiler policy or full Unicode normalization/full-fold behavior is qualified.';artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName})}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if(-not $success){throw $failure}
Write-Output "PASS: $($checks.Count) Unicode/cursor acceptance assertions through both accepted v2 stages."
