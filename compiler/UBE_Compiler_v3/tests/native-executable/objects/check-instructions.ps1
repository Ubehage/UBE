param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$BindingReport,[switch]$WholeCode)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$binding=Get-Content -LiteralPath $BindingReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $binding.success -or $reader.acceptedSelection.compiler.sha256 -cne $binding.acceptedSelection.compiler.sha256){throw 'Passing reader and binding reports from the same bootstrap tools required'}
$run=Join-Path $root ($(if($WholeCode){'bootstrap/out/native-code-instructions/'}else{'bootstrap/out/native-instructions/'})+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$utf8=[Text.UTF8Encoding]::new($false);$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null;$ordinal=0;$empty=0;$totalInstructions=0;$totalBytes=0
foreach($path in @($ReaderReport,$BindingReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
$totalRelocations=0;$relativeFields=0;$sectionFields=0
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[bool]$Rejected=$false,[bool]$Mismatch=$false,[bool]$Relocation=$false){
 $r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r);if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejected){$pattern='instruction failure index=0 first=[0-9]+ count=[0-9]+ code=1506';if($Mismatch){$pattern='instruction mismatch index=0 first=[0-9]+'};if($Relocation){$pattern='instruction relocation failure index=0 code=1506';if($Mismatch){$pattern='instruction relocation mismatch index=0 actual='}};if($r.exit -ne 1 -or $r.stderr -notmatch $pattern){throw ('Unsupported encoding control was not rejected: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
try {
 foreach($input in $reader.inputs){$null=Retain $input}
 $probes=@();foreach($stage in 0..1){$id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($id.Count -ne 1){throw 'Reader executable missing'};$probes+=Retain $id[0]}
 $objdump=Join-Path (Split-Path $reader.acceptedSelection.clang.path -Parent) 'llvm-objdump.exe';$inputs+=Get-ArtifactIdentity $objdump
 $objects=[ordered]@{}
 foreach($command in $binding.commands){if($command.arguments[0] -cne '--bound-extents' -or $command.exit -ne 0){continue};$names=@([regex]::Matches($command.stdout,'(?m)^([^\t\r\n]+)\tno-unwind\r?$')|ForEach-Object {$_.Groups[1].Value});if($WholeCode -or $names.Count){$objects[$command.arguments[1]]=$names}}
 if(($WholeCode -and $objects.Count -ne 144) -or (-not $WholeCode -and $objects.Count -ne 32)){throw 'Retained object matrix is incomplete'};$ordinal=0;$empty=0;$totalInstructions=0;$totalBytes=0
 $mode='--instructions';$label='leaf';if($WholeCode){$mode='--code-instructions';$label='code'}
 $registers=@('rax','rcx','rdx','rbx','rsp','rbp','rsi','rdi','r8','r9','r10','r11','r12','r13','r14','r15')
 foreach($path in $objects.Keys){
  $id=@($binding.inputs|Where-Object path -EQ $path);if($id.Count -lt 1){throw 'Qualified object identity missing'};$object=Retain $id[0];$names=$objects[$path]
  $bytes=[IO.File]::ReadAllBytes($object);$sections=[BitConverter]::ToUInt16($bytes,2);$raw=@();$rawBytes=0;$textSection=-1;$relocationTable=0;$relocationCount=0
  for($s=0;$s -lt $sections;++$s){$at=20+40*$s;if($WholeCode -and ([BitConverter]::ToUInt32($bytes,$at+36) -band 0x20000000) -and [Text.Encoding]::ASCII.GetString($bytes,$at,8).TrimEnd([char]0) -cne '.text'){throw 'Unexpected executable section in frozen matrix'};if([Text.Encoding]::ASCII.GetString($bytes,$at,8).TrimEnd([char]0) -ceq '.text'){$raw+=[BitConverter]::ToUInt32($bytes,$at+20);$rawBytes=[BitConverter]::ToUInt32($bytes,$at+16);$textSection=$s;$relocationTable=[BitConverter]::ToUInt32($bytes,$at+24);$relocationCount=[BitConverter]::ToUInt16($bytes,$at+32)}}
  if($raw.Count -ne 1){throw 'Independent text-section locator is ambiguous'};if($WholeCode -and $rawBytes -eq 0){++$empty;continue}
  $arguments=@('-d',$object);if(-not $WholeCode){$arguments=@('-d',('--disassemble-symbols='+($names -join ',')),$object)}
  $text=Run $objdump $arguments;[IO.File]::WriteAllText((Join-Path $run ($ordinal.ToString()+'-oracle.txt')),$text,$utf8)
  $rows=@();$seen=@();$inText=$false;$nextOffset=-1;if($WholeCode){$nextOffset=0}
  foreach($line in ($text -split '\r?\n')){
   if($line -match '^Disassembly of section (.+):$'){$inText=$Matches[1] -ceq '.text';continue}
   if($line -match '^([0-9A-Fa-f]+) <([^>]+)>:$'){if(-not $inText -or (-not $WholeCode -and $names -cnotcontains $Matches[2])){throw 'Unexpected disassembled function'};$seen+=$Matches[2];if($WholeCode){if([Convert]::ToInt32($Matches[1],16) -ne $nextOffset){throw 'Gap before function label'}}else{$nextOffset=[Convert]::ToInt32($Matches[1],16)};continue}
   $m=[regex]::Match($line,'^\s*([0-9A-Fa-f]+):\s+((?:[0-9A-Fa-f]{2}\s+)+)([a-z][a-z0-9]*)\s*(.*)$');if(-not $m.Success){if($inText -and $line -match '^\s*[0-9A-Fa-f]+:'){throw 'Undecoded instruction in LLVM oracle'};continue};if(-not $inText){throw 'Instruction outside selected text section'}
   $offset=[Convert]::ToInt32($m.Groups[1].Value,16);$encoded=@(($m.Groups[2].Value.Trim() -split '\s+')|ForEach-Object {[Convert]::ToByte($_,16)});$length=$encoded.Count
   if($offset -ne $nextOffset){throw 'Gap in independent instruction sequence'};$nextOffset=$offset+$length
   if($length -lt 1 -or $length -gt 15 -or $offset -gt $rawBytes-$length){throw 'Independent instruction range is invalid'};$first=$raw[0]+$offset;for($i=0;$i -lt $length;++$i){if($bytes[$first+$i] -ne $encoded[$i]){throw 'Disassembly bytes do not match object'}}
   $mnemonic=$m.Groups[3].Value;$flow=0;$relative=[long]0;$targetRegister=-1
   if($mnemonic -notin @('adcq','addl','addq','andb','andl','cmovel','cmoveq','cmovnel','cmovneq','cmpb','cmpl','cmpq','decq','imull','incl','incq','leal','leaq','movb','movl','movq','movsbl','movzbl','nop','nopl','nopw','orb','popq','pushq','seta','setae','setb','setbe','sete','setne','seto','subb','subq','testb','testl','testq','xorb','xorl') -and $mnemonic -notin @('ret','retq','ud2','int3') -and $mnemonic -notmatch '^(j|call)'){throw 'Unclassified instruction mnemonic in oracle'}
   if($mnemonic -in @('ret','retq')){$flow=1}
   if($mnemonic -match '^j' -or $mnemonic -match '^call'){
    $flow=2;if($mnemonic -in @('jmp','jmpq')){$flow=3};if($mnemonic -match '^call'){$flow=4}
    $target=[regex]::Match($m.Groups[4].Value,'^0x([0-9A-Fa-f]+)');if($target.Success){$relative=[Convert]::ToInt64($target.Groups[1].Value,16)-$offset-$length}
    elseif($WholeCode -and $m.Groups[4].Value.StartsWith('*') -and $flow -in @(3,4)){if($flow -eq 3){$flow=6}else{$flow=5}}else{throw 'Unclassified control transfer in oracle'}
   }
   if($flow -in @(5,6) -and $m.Groups[4].Value.Trim() -match '^\*%([a-z0-9]+)$'){$targetRegister=[Array]::IndexOf($registers,$Matches[1]);if($targetRegister -lt 0){throw 'Unknown indirect target register'}}
   if($mnemonic -in @('ud2','int3')){$flow=7}
   if(-not $WholeCode -and $flow -ge 4){throw 'Observed leaf has an unexpected call or trap'}
   $rows+=@([pscustomobject]@{first=[int]$first;length=[int]$length;flow=$flow;relative=$relative;target=$targetRegister;operand=$m.Groups[4].Value})
  }
  if($rows.Count -lt 1 -or ($WholeCode -and $nextOffset -ne $rawBytes) -or (-not $WholeCode -and ($seen.Count -ne $names.Count -or @($names|Where-Object {$seen -cnotcontains $_}).Count))){throw 'Independent instruction disassembly is incomplete'}
  $totalInstructions+=$rows.Count;$totalBytes+=($rows|Measure-Object -Property length -Sum).Sum
  $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$rows.Count);foreach($row in $rows){$writer.Write([int]$row.first);$writer.Write([int]$row.length);$writer.Write([int]$row.flow);$writer.Write([long]$row.relative);$writer.Write([int]$row.target)};$writer.Flush();$expected=Join-Path $run ($ordinal.ToString()+'-expected.bin');[IO.File]::WriteAllBytes($expected,$stream.ToArray());$writer.Dispose();$stream.Dispose()
  foreach($stage in 0..1){$actual=Run $probes[$stage] @($mode,$object,$expected);if($actual -cne ('PASS '+$rows.Count+" independently decoded $label instructions`n")){throw 'Instruction comparison output differs'};$checks+=@([pscustomobject]@{assertion='Production instruction lengths, flow, indirect target registers and signed branch offsets match independent LLVM; leaf mode additionally requires volatile GPR writes';wholeCode=[bool]$WholeCode;readerStage=$stage+1;object=$id[0];functions=$names;instructions=$rows.Count;passed=$true})}
  if($WholeCode){foreach($field in @('flow','relative','target')){
   $wrongOracle=[IO.File]::ReadAllBytes($expected);$at=12;$replacement=[BitConverter]::GetBytes([int]($rows[0].flow -bxor 1));if($field -ceq 'relative'){$at=16;$replacement=[BitConverter]::GetBytes([long]($rows[0].relative+1))};if($field -ceq 'target'){$at=24;$changed=0;if($rows[0].target -ge 0){$changed=$rows[0].target -bxor 1};$replacement=[BitConverter]::GetBytes([int]$changed)};[Array]::Copy($replacement,0,$wrongOracle,$at,$replacement.Length)
   $wrongExpected=Join-Path $run ($ordinal.ToString()+'-wrong-'+$field+'.bin');[IO.File]::WriteAllBytes($wrongExpected,$wrongOracle)
   foreach($stage in 0..1){$null=Run $probes[$stage] @($mode,$object,$wrongExpected) $true $true;$checks+=@([pscustomobject]@{assertion='Changed independent '+$field+' oracle must fail comparison';readerStage=$stage+1;passed=$true})}
  }}
  if($WholeCode){
   if($relocationCount -lt 1 -or $relocationCount -eq 65535 -or $relocationTable -gt $bytes.Length-10*$relocationCount){throw 'Unexpected relocation table in frozen code corpus'}
   $relocationRows=@();$cursor=0;$priorEnd=0
   for($r=0;$r -lt $relocationCount;++$r){
    $tableAt=$relocationTable+10*$r;$site=[BitConverter]::ToUInt32($bytes,$tableAt);$kind=[BitConverter]::ToUInt16($bytes,$tableAt+8)
    if($kind -notin @(4,11) -or $site -lt $priorEnd -or $site -gt $rawBytes-4){throw 'Unexpected or overlapping frozen relocation'};$priorEnd=$site+4
    while($cursor+1 -lt $rows.Count -and $rows[$cursor+1].first -le $raw[0]+$site){++$cursor};$row=$rows[$cursor];$instructionStart=$row.first-$raw[0]
    if($site -lt $instructionStart -or $site+4 -gt $instructionStart+$row.length){throw 'Relocation crosses independent instruction boundary'}
    $addend=[long][BitConverter]::ToInt32($bytes,$raw[0]+$site);$effective=$addend
    if($kind -eq 4){
     if($row.flow -notin @(2,3,4) -and $row.operand -notmatch '\(%rip\)'){throw 'REL32 outside an independent branch or RIP operand'}
     $effective+=$instructionStart+$row.length-$site-4;++$relativeFields
    }else{if($row.flow -ne 0 -or $row.operand -notmatch '\(%[a-z0-9]+\)' -or $row.operand -match '\(%rip\)'){throw 'SECREL outside an independent register-based operand'};++$sectionFields}
    $relocationRows+=@([pscustomobject]@{section=$textSection;index=$r;first=$row.first;length=$row.length;start=[long]$instructionStart;offset=[long]$effective;table=$tableAt;site=$site;kind=$kind})
   }
   $totalRelocations+=$relocationRows.Count
   $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$relocationRows.Count)
   foreach($row in $relocationRows){$writer.Write([int]$row.section);$writer.Write([int]$row.index);$writer.Write([int]$row.first);$writer.Write([int]$row.length);$writer.Write([long]$row.start);$writer.Write([long]$row.offset)}
   $writer.Flush();$relocationExpected=Join-Path $run ($ordinal.ToString()+'-relocations.bin');[IO.File]::WriteAllBytes($relocationExpected,$stream.ToArray());$writer.Dispose();$stream.Dispose()
   foreach($stage in 0..1){$actual=Run $probes[$stage] @('--instruction-relocations',$object,$relocationExpected);if($actual -cne ('PASS '+$relocationRows.Count+' independently paired instruction relocations'+[char]10)){throw 'Instruction relocation comparison output differs'};$checks+=@([pscustomobject]@{assertion='Every code relocation pairs with its decoded field and independent effective addend';readerStage=$stage+1;object=$id[0];relocations=$relocationRows.Count;passed=$true})}
   foreach($defect in @('site','kind','addend','oracle')){
    $wrongBytes=[byte[]]$bytes.Clone();$wrongOracle=[IO.File]::ReadAllBytes($relocationExpected);$firstRelocation=$relocationRows[0];$mismatch=$false
    if($defect -ceq 'site'){[Array]::Copy([BitConverter]::GetBytes([uint32]($firstRelocation.site-1)),0,$wrongBytes,$firstRelocation.table,4)}
    if($defect -ceq 'kind'){$otherKind=11;if($firstRelocation.kind -eq 11){$otherKind=4};[Array]::Copy([BitConverter]::GetBytes([uint16]$otherKind),0,$wrongBytes,$firstRelocation.table+8,2)}
    if($defect -ceq 'addend'){$wrongBytes[$raw[0]+$firstRelocation.site]=$wrongBytes[$raw[0]+$firstRelocation.site] -bxor 1;$mismatch=$true}
    if($defect -ceq 'oracle'){[Array]::Copy([BitConverter]::GetBytes([long]($firstRelocation.offset -bxor 1)),0,$wrongOracle,28,8);$mismatch=$true}
    $wrongObject=Join-Path $run ($ordinal.ToString()+'-relocation-'+$defect+'.o');$wrongExpected=Join-Path $run ($ordinal.ToString()+'-relocation-'+$defect+'.bin');[IO.File]::WriteAllBytes($wrongObject,$wrongBytes);[IO.File]::WriteAllBytes($wrongExpected,$wrongOracle)
    foreach($stage in 0..1){$null=Run $probes[$stage] @('--instruction-relocations',$wrongObject,$wrongExpected) $true $mismatch $true;$checks+=@([pscustomobject]@{assertion='Changed instruction relocation '+$defect+' rejects';readerStage=$stage+1;passed=$true})}
   }
  }
  $bytes[$rows[0].first]=0x62;$wrong=Join-Path $run ($ordinal.ToString()+'-unsupported.o');[IO.File]::WriteAllBytes($wrong,$bytes)
  foreach($stage in 0..1){$null=Run $probes[$stage] @($mode,$wrong,$expected) $true;$checks+=@([pscustomobject]@{assertion='Unsupported instruction in actual object rejects with 1506';readerStage=$stage+1;passed=$true})};++$ordinal
 }
 if($WholeCode -and ($ordinal -ne 112 -or $empty -ne 32 -or $totalInstructions -ne 36192 -or $totalBytes -ne 146088)){throw 'Complete frozen code corpus totals differ'}
 if($WholeCode -and ($totalRelocations -ne 5712 -or $relativeFields -ne 4824 -or $sectionFields -ne 888)){throw 'Frozen relocation totals differ'}
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});wholeCode=[bool]$WholeCode;objects=$ordinal;emptyObjects=$empty;instructions=$totalInstructions;codeBytes=$totalBytes;relocations=$totalRelocations;relativeFields=$relativeFields;sectionFields=$sectionFields;scope='Independent instruction lengths, flow, indirect target registers and signed branch offsets on retained code, including padding. WholeCode also compares every code relocation field and effective addend against independent COFF metadata and LLVM boundaries, and covers all executable bytes in the frozen matrix; default mode covers observed leaf functions and additionally checks volatile GPR writes. Does not establish reachability, operand safety, function membership, termination closure, stack safety or publication.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
