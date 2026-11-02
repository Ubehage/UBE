param([Parameter(Mandatory=$true)][string]$Executable,[int[]]$Jobs=@(1,2,4))
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$repo=$PSScriptRoot;while(-not [IO.File]::Exists((Join-Path $repo 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $repo -Parent;if(-not $parent -or $parent -eq $repo){throw 'Repository root not found'};$repo=$parent};. (Join-Path $repo 'bootstrap/tools/verification.ps1')
$casesPath=Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/cases.json';$definitionPath=Join-Path $repo 'compiler/UBE_Compiler_v3/tests/semantic/definition.json'
$cases=([IO.File]::ReadAllText($casesPath)|ConvertFrom-Json).cases;$definition=[IO.File]::ReadAllText($definitionPath)|ConvertFrom-Json
$codes=@{};for($i=0;$i -lt $definition.diagnostics.Count;$i++){$codes[$definition.diagnostics[$i]]=1401+$i};$codes.DeferredFeature=1400;$codes.DeferredLiteral=1430;$codes.DeferredLocalLifetime=1431;$codes.DeferredOperator=1432;$codes.DeferredType=1433;$codes.DeferredRepresentation=1434;$codes.DeferredPrimitive=1435
$output=Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Executable))) ('projects-'+[Guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($output);$utf8=New-Object Text.UTF8Encoding($false)
Copy-Item -LiteralPath $PSCommandPath -Destination $output;Copy-Item -LiteralPath $casesPath -Destination $output;Copy-Item -LiteralPath $definitionPath -Destination $output
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'targeted-facts.ps1') -Destination $output;. (Join-Path $output 'targeted-facts.ps1')
$callHelper=Join-Path $PSScriptRoot '../targeted-calls.ps1';Copy-Item -LiteralPath $callHelper -Destination $output;. (Join-Path $output 'targeted-calls.ps1')
function Resolve-ProjectWitness($case,$id){
 $w=@($case.witnesses|Where-Object id -CEQ $id);if($w.Count -ne 1){throw "Witness identity $id"};$w=$w[0];$sourceId=-1;for($i=0;$i -lt $case.sources.Count;$i++){if($case.sources[$i].id -ceq $w.source){$sourceId=$i;break}};if($sourceId -lt 0){throw 'Witness source missing'};$text=[string]$case.sources[$sourceId].source;$base=0;$limit=$text.Length;$props=@($w.PSObject.Properties.Name)
 if($props -contains 'mode' -and $w.mode -eq 'eof'){return @($sourceId,[Text.Encoding]::UTF8.GetByteCount($text),[Text.Encoding]::UTF8.GetByteCount($text))}
 if($props -contains 'within'){$base=$text.IndexOf([string]$w.within,[StringComparison]::Ordinal);if($base -lt 0 -or $text.IndexOf([string]$w.within,$base+1,[StringComparison]::Ordinal) -ge 0){throw "Context $id"};$limit=$base+$w.within.Length}
 $start=$base-1;for($i=0;$i -le $w.occurrence;$i++){$start=$text.IndexOf([string]$w.text,$start+1,[StringComparison]::Ordinal);if($start -lt $base -or $start+$w.text.Length -gt $limit){throw "Anchor $id"}}
 $first=[Text.Encoding]::UTF8.GetByteCount($text.Substring(0,$start));$last=$first+[Text.Encoding]::UTF8.GetByteCount([string]$w.text)
 if($props -contains 'mode'){if($w.mode -eq 'start'){$last=$first};if($w.mode -eq 'end'){$first=$last}}
 return @($sourceId,$first,$last)
}
function Resolve-Witness($case,$id){return Resolve-ProjectWitness $case $id}
$records=New-Object Collections.Generic.List[object]
foreach($case in $cases){
 if(@($case.sources).Count -le 1){continue};$directory=Join-Path $output $case.id;[void][IO.Directory]::CreateDirectory($directory)
 $rootLines=@('UBE-Project 1','Name = "SemanticProjectFixture"','Kind = "Exe"','Startup = "Main"');$libraryLines=@('UBE-Project 1','Name = "UBECore"','Kind = "Library"');$reference=$false
 foreach($source in $case.sources){$name=$source.id+'.bas';[IO.File]::WriteAllText((Join-Path $directory $name),$source.source,$utf8);if($source.package -eq 'app'){$rootLines+='Source = "'+$name+'"'}else{$reference=$true;$libraryLines+='Source = "'+$name+'"'}}
 if($reference){$rootLines+='Reference = "UBECore.UBE"';[IO.File]::WriteAllText((Join-Path $directory 'UBECore.UBE'),($libraryLines -join "`n")+"`n",$utf8)}
 $project=Join-Path $directory 'App.UBE';[IO.File]::WriteAllText($project,($rootLines -join "`n")+"`n",$utf8)
 $firstObservation=$null
 foreach($job in $Jobs){
  $run=Invoke-BoundedProcess ([IO.Path]::GetFullPath($Executable)) @('--project',[IO.Path]::GetFullPath($project),[string]$job) $repo 60;$errors=New-Object Collections.Generic.List[string];$actual=$null;$factResult=$null
  if($run.timedOut -or $run.exit -ne 0){$errors.Add('native transport failed')}else{try{$actual=$run.stdout|ConvertFrom-Json}catch{$errors.Add('invalid observation JSON')}}
  if($null -ne $actual){if(-not $actual.setup){$errors.Add("qualified project setup failed $($actual.failure -join ',')")}elseif($case.expected.outcome -eq 'checked'){if(-not $actual.ok){$errors.Add("expected checked; code $($actual.failure[1])")}else{$factResult=Compare-TargetedFacts $case $actual;foreach($itemError in $factResult.errors){$errors.Add($itemError)}}}else{if($actual.ok){$errors.Add('expected diagnostic; published success')}else{$expected=$case.expected.diagnostic;$span=Resolve-ProjectWitness $case $expected.at;if($actual.failure[1] -ne $codes[$expected.kind]){$errors.Add("code $($actual.failure[1]); expected $($codes[$expected.kind]) $($expected.kind)")};if(($actual.failure[2..4] -join ',') -ne ($span -join ',')){$errors.Add("primary $($actual.failure[2..4] -join ','); expected $($span -join ',')")};if(@($expected.related).Count -gt 0){$related=Resolve-ProjectWitness $case $expected.related[0];if(($actual.failure[5..7] -join ',') -ne ($related -join ',')){$errors.Add("related $($actual.failure[5..7] -join ','); expected $($related -join ',')")}}}}}
  if($null -eq $firstObservation){$firstObservation=$run.stdout}elseif($firstObservation -cne $run.stdout){$errors.Add('canonical scalar observation stream differs across jobs')}
  $observation=Join-Path $directory ('jobs'+$job+'.json');[IO.File]::WriteAllText($observation,$run.stdout,$utf8);$records.Add([pscustomobject]@{id=$case.id;jobs=$job;passed=($errors.Count -eq 0);errors=$errors.ToArray();facts=$factResult;observation=(Get-ArtifactIdentity $observation);run=$run})
 }
}
$failed=@($records|Where-Object {-not $_.passed});$report=[pscustomobject]@{success=($failed.Count -eq 0);qualified=$false;diagnosticOnly=$true;limits='Actual filesystem project admission and multi-source semantic outcomes/exact diagnostic spans, reported selected facts/graphs and complete scalar stream equality at jobs1/2/4. Unsupported selected fact kinds are explicitly listed per record. Actual overlap and full failure/resource controls remain separate obligations.';executable=(Get-ArtifactIdentity ([IO.Path]::GetFullPath($Executable)));records=$records.ToArray();passed=($records.Count-$failed.Count);failed=$failed.Count;inputs=@(Get-ChildItem -LiteralPath $output -Recurse -File|ForEach-Object {Get-ArtifactIdentity $_.FullName})}
$report|ConvertTo-Json -Depth 16|Set-Content -LiteralPath (Join-Path $output 'report.json') -Encoding UTF8;$failed|Select-Object id,jobs,errors|ConvertTo-Json -Depth 8;Write-Output "Evidence: $output/report.json"
