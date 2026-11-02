param([Parameter(Mandatory=$true)][string]$Executable,[string]$ObservationDirectory='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$repo=$PSScriptRoot;while(-not [IO.File]::Exists((Join-Path $repo 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $repo -Parent;if(-not $parent -or $parent -eq $repo){throw 'Repository root not found'};$repo=$parent};. (Join-Path $repo 'bootstrap/tools/verification.ps1')
$casesPath=Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/cases.json';$definitionPath=Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/definition.json'
$cases=([IO.File]::ReadAllText($casesPath)|ConvertFrom-Json).cases;$definition=[IO.File]::ReadAllText($definitionPath)|ConvertFrom-Json
$codes=@{};for($i=0;$i -lt $definition.diagnostics.Count;$i++){$codes[$definition.diagnostics[$i]]=1401+$i};$codes.DeferredFeature=1400;$codes.DeferredLiteral=1430;$codes.DeferredLocalLifetime=1431;$codes.DeferredOperator=1432;$codes.DeferredType=1433;$codes.DeferredRepresentation=1434;$codes.DeferredPrimitive=1435
$output=Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Executable))) ('cases-'+[Guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($output)
foreach($file in @('targeted-check.ps1','targeted-facts.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $output}
Copy-Item -LiteralPath $casesPath -Destination (Join-Path $output 'cases.json');Copy-Item -LiteralPath $definitionPath -Destination (Join-Path $output 'definition.json')
. (Join-Path $output 'targeted-facts.ps1')
$callHelper=Join-Path $PSScriptRoot '../targeted-calls.ps1';Copy-Item -LiteralPath $callHelper -Destination $output;. (Join-Path $output 'targeted-calls.ps1')
function Resolve-Witness($case,$id){
 $w=@($case.witnesses|Where-Object id -CEQ $id);if($w.Count -ne 1){throw "Witness identity $id"};$w=$w[0];$source=@($case.sources|Where-Object id -CEQ $w.source)[0];$text=[string]$source.source;$base=0;$limit=$text.Length;$props=@($w.PSObject.Properties.Name)
 if($props -contains 'mode' -and $w.mode -eq 'eof'){return @(0,[Text.Encoding]::UTF8.GetByteCount($text),[Text.Encoding]::UTF8.GetByteCount($text))}
 if($props -contains 'within'){$base=$text.IndexOf([string]$w.within,[StringComparison]::Ordinal);if($base -lt 0 -or $text.IndexOf([string]$w.within,$base+1,[StringComparison]::Ordinal) -ge 0){throw "Context $id"};$limit=$base+$w.within.Length}
 $start=$base-1;for($i=0;$i -le $w.occurrence;$i++){$start=$text.IndexOf([string]$w.text,$start+1,[StringComparison]::Ordinal);if($start -lt $base -or $start+$w.text.Length -gt $limit){throw "Anchor $id"}}
 $first=[Text.Encoding]::UTF8.GetByteCount($text.Substring(0,$start));$last=$first+[Text.Encoding]::UTF8.GetByteCount([string]$w.text)
 if($props -contains 'mode'){if($w.mode -eq 'start'){$last=$first};if($w.mode -eq 'end'){$first=$last}}
 return @(0,$first,$last)
}
$records=New-Object Collections.Generic.List[object];$skips=New-Object Collections.Generic.List[object];$controls=New-Object Collections.Generic.List[object]
foreach($case in $cases){
 if(@($case.sources).Count -ne 1 -or $case.expected.outcome -eq 'frontend'){$skips.Add([pscustomobject]@{id=$case.id;reason= $(if(@($case.sources).Count -ne 1){'project fixture required'}else{'retained frontend fixture'})});continue}
 $sourcePath=Join-Path $output ('input'+$records.Count+'.bas');[IO.File]::WriteAllText($sourcePath,[string]$case.sources[0].source,(New-Object Text.UTF8Encoding($false)))
 if($ObservationDirectory -ne ''){$run=[pscustomobject]@{timedOut=$false;exit=0;stdout=[IO.File]::ReadAllText((Join-Path $ObservationDirectory ($case.id+'.json')));stderr='';reusedObservation=(Get-ArtifactIdentity (Join-Path $ObservationDirectory ($case.id+'.json')))}}else{$run=Invoke-BoundedProcess ([IO.Path]::GetFullPath($Executable)) @($sourcePath) $repo 30};$errors=New-Object Collections.Generic.List[string];$actual=$null;$factResult=$null
 if($run.timedOut -or $run.exit -ne 0){$errors.Add('native transport failed')}else{try{$actual=$run.stdout|ConvertFrom-Json}catch{$errors.Add('invalid observation JSON')}}
 if($null -ne $actual){
  if(-not $actual.setup){$errors.Add('qualified frontend setup failed')}
  elseif($case.expected.outcome -eq 'checked'){if(-not $actual.ok){$errors.Add("expected checked; code $($actual.failure[1])")}else{$factResult=Compare-TargetedFacts $case $actual;foreach($itemError in $factResult.errors){$errors.Add($itemError)}
   if($case.id -eq 'initializer-wide-literals-small-result'){
    $syntax=@(Get-TargetedSyntaxAt $actual (Resolve-Witness $case 'expr'))[0]
    foreach($mutation in @('wrong-value','missing-expression','duplicate-expression','orphan-node','wrong-expectation')){
     $copy=$actual|ConvertTo-Json -Depth 30|ConvertFrom-Json;$expectedCopy=$case|ConvertTo-Json -Depth 30|ConvertFrom-Json
     $expression=@($copy.facts|Where-Object {$_[1] -eq $syntax -and $_[2] -eq 1})[0]
     switch($mutation){
      'wrong-value' {$expression[4]=30001}
      'missing-expression' {$copy.facts=@($copy.facts|Where-Object {-not ($_[1] -eq $syntax -and $_[2] -eq 1)})}
      'duplicate-expression' {$copy.facts=@($copy.facts)+@(,$expression)}
      'orphan-node' {$copy.values=@($copy.values)+@(,$copy.values[-1])}
      'wrong-expectation' {@($expectedCopy.expected.facts|Where-Object kind -EQ 'constant')[0].value='30001'}
     }
     if(@($copy.PSObject.Properties.Name) -contains 'modules'){$copy.modules[0].facts=$copy.facts;$copy.modules[0].values=$copy.values}
     $control=Compare-TargetedFacts $expectedCopy $copy;$rejected=$control.errors.Count -gt 0;$controls.Add([pscustomobject]@{mutation=$mutation;rejected=$rejected;errors=$control.errors});if(-not $rejected){$errors.Add("negative control accepted $mutation")}
    }
   }
  }}
  else{
   if($actual.ok){$errors.Add('expected diagnostic; published success')}else{
    $expected=$case.expected.diagnostic;$span=Resolve-Witness $case $expected.at
    if($actual.failure[1] -ne $codes[$expected.kind]){$errors.Add("code $($actual.failure[1]); expected $($codes[$expected.kind]) $($expected.kind)")}
    if(($actual.failure[2..4] -join ',') -ne ($span -join ',')){$errors.Add("primary $($actual.failure[2..4] -join ','); expected $($span -join ',')")}
    if(@($expected.related).Count -gt 0){$related=Resolve-Witness $case $expected.related[0];if(($actual.failure[5..7] -join ',') -ne ($related -join ',')){$errors.Add("related $($actual.failure[5..7] -join ','); expected $($related -join ',')")}}
   }
  }
 }
 $observationPath=Join-Path $output ($case.id+'.json');[IO.File]::WriteAllText($observationPath,$run.stdout,(New-Object Text.UTF8Encoding($false)))
 $records.Add([pscustomobject]@{id=$case.id;passed=($errors.Count -eq 0);errors=@($errors);facts=$factResult;source=(Get-ArtifactIdentity $sourcePath);observation=(Get-ArtifactIdentity $observationPath);run=$run})
}
$failed=@($records|Where-Object {-not $_.passed});$report=[pscustomobject]@{success=($failed.Count -eq 0);qualified=$false;diagnosticOnly=$true;limits='Single-source outcome/exact diagnostic spans, selected kinds reported per record and scalar graph ownership/record consistency. Any unsupported fact kinds are explicitly listed per record and do not count as compared. Multi-source/reference cases and retained frontend cases excluded; whole resource/failure qualification remains.';executable=(Get-ArtifactIdentity ([IO.Path]::GetFullPath($Executable)));cases=(Get-ArtifactIdentity (Join-Path $output 'cases.json'));definition=(Get-ArtifactIdentity (Join-Path $output 'definition.json'));comparator=@('targeted-check.ps1','targeted-facts.ps1','targeted-calls.ps1'|ForEach-Object {Get-ArtifactIdentity (Join-Path $output $_)});controls=$controls.ToArray();records=$records.ToArray();skipped=$skips.ToArray();passed=($records.Count-$failed.Count);failed=$failed.Count}
$report|ConvertTo-Json -Depth 15|Set-Content -LiteralPath (Join-Path $output 'report.json') -Encoding UTF8
$failed|Select-Object id,errors|ConvertTo-Json -Depth 8;Write-Output "Evidence: $output/report.json"
