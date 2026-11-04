param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$GraphReport,[Parameter(Mandatory=$true)][string]$SupportReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json
$graph=Get-Content -LiteralPath $GraphReport -Raw|ConvertFrom-Json
$support=Get-Content -LiteralPath $SupportReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $graph.success -or $reader.acceptedSelection.compiler.sha256 -cne $graph.acceptedSelection.compiler.sha256){throw 'Passing reader/graph reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-retention/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$utf8=[Text.UTF8Encoding]::new($false);$inputs=@();$commands=@();$checks=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$GraphReport,$SupportReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Identity){$actual=Get-ArtifactIdentity $Identity.path;if($actual.sha256 -cne $Identity.sha256){throw ('Retained input changed: '+$Identity.path)};$script:inputs+=@($actual);return $actual.path}
function Artifact($Report,[string]$Path){$expected=@($Report.artifacts|Where-Object path -EQ $Path);if($expected.Count -ne 1){throw ('Missing retained artifact: '+$Path)};return Retain $expected[0]}
function Run([string]$File,[string[]]$Arguments,[bool]$Rejected=$false){
 $r=Invoke-BoundedProcess $File $Arguments $run 60;$script:commands+=@($r)
 if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejected){if($r.exit -ne 1 -or $r.stderr -notmatch 'retention failure row=[0-9]+ code=1506 resource=0'){throw ('Retention mutation was not rejected: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
function Write-Expected([string]$Path,$Rows){
 $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$names=[Text.StringBuilder]::new()
 foreach($row in $Rows){$null=$names.Append($row.name)}
 $writer.Write([int]$Rows.Count);$writer.Write([int]$names.Length);$first=0
 foreach($row in $Rows){$writer.Write([int]$first);$writer.Write([int]$row.name.Length);foreach($field in @('unit','source','declaration','family','required','bytes','type','representation')){$writer.Write([int]$row.$field)};$first+=$row.name.Length}
 $writer.Write([Text.Encoding]::ASCII.GetBytes($names.ToString()));$writer.Flush();[IO.File]::WriteAllBytes($Path,$stream.ToArray());$writer.Dispose();$stream.Dispose()
}
# Independent test-only PE/COFF mutation locator; expected names come from the frozen table.
function Symbol-Offset([byte[]]$Bytes,[string]$Name){
 $pe=[BitConverter]::ToInt32($Bytes,60);$table=[BitConverter]::ToInt32($Bytes,$pe+12);$count=[BitConverter]::ToInt32($Bytes,$pe+16);$strings=$table+18*$count;$found=@()
 for($index=0;$index -lt $count;){$at=$table+18*$index
  if([BitConverter]::ToInt32($Bytes,$at) -eq 0){$first=$strings+[BitConverter]::ToInt32($Bytes,$at+4);$end=$first;while($Bytes[$end] -ne 0){++$end};$candidate=[Text.Encoding]::ASCII.GetString($Bytes,$first,$end-$first)}else{$length=0;while($length -lt 8 -and $Bytes[$at+$length] -ne 0){++$length};$candidate=[Text.Encoding]::ASCII.GetString($Bytes,$at,$length)}
  if($candidate -ceq $Name -and [BitConverter]::ToInt16($Bytes,$at+12) -gt 0){$found+=$at};$index+=1+$Bytes[$at+17]
 }
 if($found.Count -ne 1){throw ('Mutation target is not unique: '+$Name)};return $found[0]
}
try {
 foreach($input in $reader.inputs){$null=Retain $input}
 $readerRoot=Split-Path ([IO.Path]::GetFullPath($ReaderReport)) -Parent;$graphRoot=Split-Path ([IO.Path]::GetFullPath($GraphReport)) -Parent
 $probes=@();foreach($stage in 0..1){$probes+=Artifact $reader (Join-Path $readerRoot ('stage'+$stage+'-probe.exe'))}
 $clang=Retain $reader.acceptedSelection.clang;$linker=$null
 foreach($identity in $support.identities){if((Split-Path $identity.path -Leaf) -ceq 'ld.lld.exe'){$linker=Retain $identity};if((Split-Path $identity.path -Leaf) -ceq 'clang.exe' -and $identity.sha256 -cne $reader.acceptedSelection.clang.sha256){throw 'Explicit linker profile uses another Clang'}}
 if(-not $linker){throw 'Pinned explicit linker missing'}
 $nm=Join-Path (Split-Path $clang -Parent) 'llvm-nm.exe';$inputs+=Get-ArtifactIdentity $nm
 $supportPaths=@();foreach($argument in $support.arguments){$id=@($support.inputs|Where-Object path -EQ $argument);if($id.Count -eq 1 -and (Split-Path $argument -Leaf) -cne 'verified.o'){$supportPaths+=Retain $id[0]}}
 if($supportPaths.Count -ne 20 -or (Split-Path $supportPaths[0] -Leaf) -cne 'crt2.o' -or (Split-Path $supportPaths[-1] -Leaf) -cne 'crtend.o'){throw 'Reviewed explicit support order missing'}
 foreach($generator in 0..1){foreach($reference in 0..1){
  $directory=Join-Path $graphRoot ('stage'+$generator);$table=Artifact $graph (Join-Path $directory ('expected-definitions-'+$reference+'.tsv'));$rows=@(Import-Csv -LiteralPath $table -Delimiter "`t");if($rows.Count -ne 54){throw 'Complete expected table missing'}
  foreach($optimization in @('O0','O2')){foreach($debug in @('Full','None')){
   $stem='stage'+$generator+'-'+$reference+'-'+$optimization+'-'+$debug;$units=@();$objects=@()
   foreach($kind in 0..6){$sources=@(-1);if($kind -eq 0){$sources=0..2};foreach($source in $sources){
    $object=Artifact $graph (Join-Path $directory ('expected-'+$reference+'-'+$kind+'-'+$source+'-'+$optimization+'-'+$debug+'.o'));$objects+=$object
    $selected=@($rows|Where-Object {[int]$_.unit -eq $kind -and [int]$_.source -eq $source});$expected=Join-Path $run ($stem+'-'+$kind+'-'+$source+'.bin');Write-Expected $expected $selected
    $symbols=Run $nm @('--defined-only','--format=posix',$object);$names=@([regex]::Matches($symbols,'(?m)^([^\s]+) [A-Za-z?](?: |$)')|ForEach-Object {$_.Groups[1].Value});$output=''
    foreach($row in $selected){$present=@($names|Where-Object {$_ -ceq $row.name}).Count;if($present -gt 1 -or ([int]$row.required -eq 1 -and $present -ne 1)){throw 'Independent object inventory disagrees with required identity'};$output+=$row.name+"`t"+$present+"`n"}
    $units+=@([pscustomobject]@{kind=$kind;source=$source;object=$object;expected=$expected;output=$output;rows=$selected})
   }}
   $image=Join-Path $run ($stem+'.exe')
   $arguments=@('--no-default-config','--target=x86_64-w64-windows-gnu','-nostdlib',('--ld-path='+$linker))+@($supportPaths[0..1])+$objects+@($supportPaths[2..19])+@('-Wl,--no-insert-timestamp','-Wl,--subsystem,console','-Wl,--threads=1','-Wl,--Xlink=/nodefaultlib','-o',$image)
   $null=Run $clang $arguments
   foreach($unit in $units){foreach($readerStage in 0..1){$output=Run $probes[$readerStage] @('--retained',$unit.object,$image,$unit.expected);if($output -cne $unit.output){throw 'Production retention presence differs from independent object inventory'}
    $checks+=@([pscustomobject]@{assertion='Every frozen object definition survives explicit unstripped linking with matching type, permissions and requested storage span';readerStage=$readerStage+1;generatorStage=$generator+1;reference=$reference;optimization=$optimization;debug=$debug;unit=$unit.kind;source=$unit.source;rows=$unit.rows.Count;passed=$true})
   }}
   $main=@($rows|Where-Object {[int]$_.family -eq 1 -and [int]$_.required -eq 1});if($main.Count -ne 1){throw 'Main expectation missing'}
   $unit=@($units|Where-Object {$_.kind -eq 0 -and $_.source -eq [int]$main[0].source})[0]
   $other=@($unit.rows|Where-Object {[int]$_.family -eq 1 -and [int]$_.required -eq 0})[0]
   foreach($control in @('missing-main','missing-ordinary','wrong-type','outside-section')){
    $bytes=[IO.File]::ReadAllBytes($image);$name=$main[0].name;if($control -eq 'missing-ordinary'){$name=$other.name};$at=Symbol-Offset $bytes $name
    if($control -like 'missing-*'){$bytes[$at]=120;$bytes[$at+1]=0;$bytes[$at+2]=0;$bytes[$at+3]=0;$bytes[$at+4]=0;$bytes[$at+5]=0;$bytes[$at+6]=0;$bytes[$at+7]=0}
    if($control -eq 'wrong-type'){$bytes[$at+14]=0;$bytes[$at+15]=0}
    if($control -eq 'outside-section'){[Array]::Copy([BitConverter]::GetBytes([uint32]::MaxValue),0,$bytes,$at+8,4)}
    $wrong=Join-Path $run ($stem+'-'+$control+'.exe');[IO.File]::WriteAllBytes($wrong,$bytes)
    foreach($readerStage in 0..1){$null=Run $probes[$readerStage] @('--retained',$unit.object,$wrong,$unit.expected) $true;$checks+=@([pscustomobject]@{assertion=('Linked retention rejects '+$control);readerStage=$readerStage+1;generatorStage=$generator+1;reference=$reference;optimization=$optimization;debug=$debug;passed=$true})}
   }
  }}
 }}
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Current production retention binding over frozen expected identities and retained checked-project objects, freshly linked with reviewed explicit support. Function anchors and expected data spans, not code extents, instruction/fixup equality, full debug/stack validation or publication. Controlled frame/reserve images are not executed.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
