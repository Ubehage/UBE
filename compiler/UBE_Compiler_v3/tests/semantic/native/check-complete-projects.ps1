param([Parameter(Mandatory=$true)][string]$ObservationDirectory,[string]$OutputDirectory='')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'complete-project-facts.ps1')
$repo=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $repo 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $repo -Parent;if(-not $parent -or $parent -eq $repo){throw 'Repository root not found'};$repo=$parent}
$oraclePath=Join-Path $PSScriptRoot 'complete/complete.json'
if(-not $OutputDirectory){$OutputDirectory=Join-Path $repo ('bootstrap/out/semantic-complete/'+[guid]::NewGuid().ToString('N'))};[void][IO.Directory]::CreateDirectory($OutputDirectory)
$report=$null;$failure=$null
try{
$oracle=Get-Content $oraclePath -Encoding UTF8 -Raw|ConvertFrom-Json
$controls=@();$results=@();foreach($stage in @('stage1','stage2')){foreach($p in @($oracle.projects|Where-Object id -NE 'scalar-context-and-storage')){
 $path=Join-Path $ObservationDirectory ($stage+'-'+$p.id+'.json');$actual=Get-Content $path -Raw|ConvertFrom-Json;$comparison=Compare-CompleteProject $p $actual
 $results+=@{stage=$stage;project=$p.id;comparison=$comparison;actualHash=(Get-FileHash $path -Algorithm SHA256).Hash}
 if($comparison.errors.Count -eq 0 -and $p.id -eq 'argument-modes-and-control'){
  foreach($control in @('wrong-value','missing-fact','extra-fact','orphan-value','wrong-child','wrong-binding','wrong-parameter-map','wrong-default-origin','wrong-conversion','wrong-expected','wrong-storage-order','wrong-exit-target','wrong-canonical')){
   $changed=Get-Content $path -Raw|ConvertFrom-Json;$expected=$p|ConvertTo-Json -Depth 100|ConvertFrom-Json;$m=$changed.modules[0]
   switch($control){
    'wrong-value' {$f=@($m.facts|Where-Object {$_[2] -eq 1 -and ($_[8]-band 1)})[0];$f[4]=999}
    'missing-fact' {$m.facts=@($m.facts|Select-Object -Skip 1)}
    'extra-fact' {$m.facts+=,@($m.facts[0])}
    'orphan-value' {$m.values+=,@($m.values[0])}
    'wrong-child' {$n=@($m.values|Where-Object {$_[2] -eq 5})[0];$n[6]=-1}
    'wrong-binding' {$f=@($m.facts|Where-Object {$_[2] -eq 2})[0];$f[5]=0}
    'wrong-parameter-map' {$f=@($m.facts|Where-Object {$_[2] -eq 6})[0];$f[9]=99}
    'wrong-default-origin' {$n=@($m.values|Where-Object {$_[2] -eq 1 -and $_[4] -eq 2})[0];$n[1]=0}
    'wrong-conversion' {$f=@($m.facts|Where-Object {$_[2] -eq 3})[0];$f[8]=1}
    'wrong-expected' {$e=@($expected.expressions|Where-Object id -CEQ 'a.one')[0];$e.constant='2'}
    'wrong-storage-order' {$n=@($m.values|Where-Object {$_[2] -eq 103})[0];$n[9]=0}
    'wrong-exit-target' {$n=@($m.values|Where-Object {$_[2] -eq 108 -and $_[9] -eq 3})[0];$n[5]=0}
    'wrong-canonical' {$changed.nameBytesHex='00'+$changed.nameBytesHex.Substring(2)}
   }
   $negative=Compare-CompleteProject $expected $changed;$controls+=@{stage=$stage;name=$control;rejected=$negative.errors.Count -gt 0;errors=$negative.errors}
  }
 }
 if($comparison.errors.Count -eq 0 -and $p.id -eq 'explicit-native-library'){
  foreach($control in @('wrong-representation','wrong-pack-identity','wrong-primitive-declaration','wrong-primitive-metadata','wrong-module-binding','wrong-type-binding','wrong-attribute-binding')){
   $changed=Get-Content $path -Raw|ConvertFrom-Json
   switch($control){
    'wrong-representation' {$changed.types[6][2]=4}
    'wrong-pack-identity' {$changed.types[6][3]=$changed.types[6][4]}
    'wrong-primitive-declaration' {$d=@($changed.declarations|Where-Object {$_[0] -eq 6 -and $_[12] -eq 1})[0];$d[12]=2}
    'wrong-primitive-metadata' {$f=@($changed.catalogFacts|Where-Object {$_[2] -eq 8 -and $_[6] -eq 2})[0];$f[7]=99}
    'wrong-module-binding' {$f=@($changed.catalogFacts|Where-Object {$_[2] -eq 2 -and $_[6] -eq 6})[0];$f[7]=6}
    'wrong-type-binding' {$f=@($changed.catalogFacts|Where-Object {$_[2] -eq 2 -and $_[6] -eq 7})[0];$f[5]=0}
    'wrong-attribute-binding' {$f=@($changed.catalogFacts|Where-Object {$_[2] -eq 2 -and $_[6] -eq 9})[0];$f[5]=0}
   }
   $negative=Compare-CompleteProject $p $changed;$controls+=@{stage=$stage;name=$control;rejected=$negative.errors.Count -gt 0;errors=$negative.errors}
  }
 }
}}
$equal=@();foreach($p in @($oracle.projects|Where-Object id -NE 'scalar-context-and-storage')){$left=Join-Path $ObservationDirectory ('stage1-'+$p.id+'.json');$right=Join-Path $ObservationDirectory ('stage2-'+$p.id+'.json');$equal+=@{project=$p.id;equal=(Get-FileHash $left -Algorithm SHA256).Hash -ceq (Get-FileHash $right -Algorithm SHA256).Hash}}
$report=@{passed=(@($results|Where-Object {$_.comparison.errors.Count}).Count -eq 0 -and @($controls|Where-Object {-not $_.rejected}).Count -eq 0 -and @($equal|Where-Object {-not $_.equal}).Count -eq 0);oracleHash=(Get-FileHash $oraclePath -Algorithm SHA256).Hash;comparatorHash=(Get-FileHash (Join-Path $PSScriptRoot 'complete-project-facts.ps1') -Algorithm SHA256).Hash;results=$results;controls=$controls;stagesEqual=$equal}
}catch{$failure=$_.Exception.Message;$report=@{passed=$false;results=$results;controls=$controls}}
$report.success=$report.passed;$report.failure=$failure
$report|ConvertTo-Json -Depth 20|Set-Content (Join-Path $OutputDirectory 'report.json') -Encoding UTF8
Write-Output "Evidence: $OutputDirectory/report.json"
[pscustomobject]@{passed=$report.passed;results=@($report.results|ForEach-Object {[pscustomobject]@{stage=$_.stage;project=$_.project;assertions=$_.comparison.assertions;errors=$_.comparison.errors}});controls=@($report.controls).Count;controlsRejected=@($report.controls|Where-Object rejected).Count}|ConvertTo-Json -Depth 12
if(-not $report.passed){throw ('Complete project comparison failed. '+$failure)}
