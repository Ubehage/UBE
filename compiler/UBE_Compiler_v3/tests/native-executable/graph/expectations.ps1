# Test-only LLVM/nm oracle. Production readers consume bounded binary inputs.
function Assert-ExpectedLLVM($Rows,[string]$Text) {
 $definitions=@([regex]::Matches($Text,'(?m)^define [^\r\n@]*@([A-Za-z0-9_.$]+)\(')|ForEach-Object {$_.Groups[1].Value})
 $definitions+=@([regex]::Matches($Text,'(?m)^@([A-Za-z0-9_.$]+) = (?!external\b)[^\r\n]*\b(?:global|constant)\b')|ForEach-Object {$_.Groups[1].Value})
 foreach($name in $definitions){if(@($Rows|Where-Object name -CEQ $name).Count -ne 1){throw ('Unexpected or ambiguous LLVM definition: '+$name)}}
 foreach($row in $Rows) {
  $count=@($definitions|Where-Object {$_ -ceq $row.name}).Count
  $optional=[int]$row.family -in @(4,5,6,23)
  if($count -gt 1 -or (-not $optional -and $count -ne 1)){throw ('Missing or duplicate LLVM definition: '+$row.name)}
 }
}
function Assert-ExpectedObject($Rows,[string]$Text) {
 $symbols=@([regex]::Matches($Text,'(?m)^([^\s]+) ([A-Za-z?])(?: |$)')|ForEach-Object {[pscustomobject]@{name=$_.Groups[1].Value;kind=$_.Groups[2].Value}})
 foreach($row in $Rows) {
  $found=@($symbols|Where-Object name -CEQ $row.name)
  if($found.Count -gt 1 -or ([int]$row.required -eq 1 -and $found.Count -ne 1)){throw ('Missing or duplicate object definition: '+$row.name)}
  if($found.Count -eq 1) {
   $pattern='^[Tt]$';if([int]$row.bytes -gt 0){$pattern='^[BbDdRrSs]$'}
   if($found[0].kind -cnotmatch $pattern){throw ('Wrong object definition kind: '+$row.name)}
  }
 }
}
foreach($reference in 0..1) {
 $table=Join-Path $directory ('expected-definitions-'+$reference+'.tsv')
 $rows=@(Import-Csv -LiteralPath $table -Delimiter "`t")
 if($rows.Count -ne 54){throw 'Expected identity row count differs'}
 if($stage -eq 1) {
  $previous=Join-Path $run ('stage0/expected-definitions-'+$reference+'.tsv')
  if((Get-ArtifactIdentity $table).sha256 -cne (Get-ArtifactIdentity $previous).sha256){throw 'Expected identities differ across compiler stages'}
 }
 $units=@();foreach($source in 0..2){$units+=@([pscustomobject]@{kind=0;source=$source;path=(Join-Path $directory ('module-'+$reference+'-'+$source+'.ll'))})}
 $support=@(('project-entry-'+$reference+'.ll'),'project-process.ll','guard-data.ll','expected-platform.ll','expected-frames.ll')
 for($i=0;$i -lt $support.Count;++$i){$units+=@([pscustomobject]@{kind=$i+1;source=-1;path=(Join-Path $directory $support[$i])})}
 $units+=@([pscustomobject]@{kind=6;source=-1;path=(Join-Path $root 'bootstrap/runtime/error_support.c')})
 foreach($unit in $units) {
  $expected=@($rows|Where-Object {[int]$_.unit -eq $unit.kind -and [int]$_.source -eq $unit.source})
  if($expected.Count -eq 0){throw 'Expected unit has no inventory'}
  if($unit.kind -ne 6){Assert-ExpectedLLVM $expected ([IO.File]::ReadAllText($unit.path))}
  foreach($optimization in @('O0','O2')) {foreach($debug in @('Full','None')) {
   $stem=Join-Path $directory ('expected-'+$reference+'-'+$unit.kind+'-'+$unit.source+'-'+$optimization+'-'+$debug)
   $options=@('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-fno-lto','-fno-emulated-tls')
   if($debug -eq 'Full'){$options+=@('-g','-gdwarf-4')}else{$options+='-g0'}
   if($unit.kind -eq 6){$options+='-std=c17'}
   $null=Run $selection.clang.path ($options+@('-c',$unit.path,'-o',($stem+'.o')))
   $symbols=Run $nativeNm @('--defined-only','--format=posix',($stem+'.o'))
   [IO.File]::WriteAllText(($stem+'.symbols.txt'),$symbols.stdout,$utf8)
   Assert-ExpectedObject $expected $symbols.stdout
   $checks+=@([pscustomobject]@{stage=$stage+1;assertion='Frozen checked-project linkage inventory matches emitted LLVM and required object definitions';reference=$reference;unit=$unit.kind;source=$unit.source;optimization=$optimization;debug=$debug;expected=$expected.Count;passed=$true})
  }}
 }
 # Negative controls independently demonstrate missing, duplicate and wrong-owner rejection.
 $sourceRows=@($rows|Where-Object {[int]$_.unit -eq 0 -and [int]$_.source -eq 0})
 $sourceText=[IO.File]::ReadAllText((Join-Path $directory ('module-'+$reference+'-0.ll')))
 $main=@($sourceRows|Where-Object {[int]$_.family -eq 1 -and [int]$_.required -eq 1})
 if($main.Count -ne 1){throw 'Expected Main control target missing'}
 foreach($control in @('missing','duplicate','owner')) {
  $changed=$sourceRows
  if($control -eq 'missing'){$changed=@($sourceRows|Where-Object name -CNE $main[0].name)}
  if($control -eq 'duplicate'){$changed=$sourceRows+@($main[0])}
  if($control -eq 'owner'){$changed=@($rows|Where-Object {[int]$_.unit -eq 0 -and [int]$_.source -eq 1})}
  $rejected=$false;try{Assert-ExpectedLLVM $changed $sourceText}catch{$rejected=$true}
  if(-not $rejected){throw ('Expected inventory control accepted: '+$control)}
  $checks+=@([pscustomobject]@{stage=$stage+1;assertion=('Expected identity negative control: '+$control);reference=$reference;passed=$true})
 }
}
