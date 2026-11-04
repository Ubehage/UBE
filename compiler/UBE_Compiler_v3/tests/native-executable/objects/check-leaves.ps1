param([Parameter(Mandatory=$true)][string]$ReaderReport,[Parameter(Mandatory=$true)][string]$BindingReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$reader=Get-Content -LiteralPath $ReaderReport -Raw|ConvertFrom-Json;$binding=Get-Content -LiteralPath $BindingReport -Raw|ConvertFrom-Json
if(-not $reader.success -or -not $binding.success -or $reader.acceptedSelection.compiler.sha256 -cne $binding.acceptedSelection.compiler.sha256){throw 'Passing reader and binding reports from the same bootstrap tools required'}
$run=Join-Path $root ('bootstrap/out/native-leaves/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$utf8=[Text.UTF8Encoding]::new($false);$inputs=@();$checks=@();$commands=@();$success=$false;$failure=$null
foreach($path in @($ReaderReport,$BindingReport,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
function Retain($Id){$actual=Get-ArtifactIdentity $Id.path;if($actual.sha256 -cne $Id.sha256){throw ('Retained input changed: '+$Id.path)};$script:inputs+=@($actual);return $actual.path}
function Run([string]$File,[string[]]$Arguments,[bool]$Rejected=$false){
 $r=Invoke-BoundedProcess $File $Arguments $run 30;$script:commands+=@($r);if($r.timedOut){throw ($r|ConvertTo-Json -Compress)}
 if($Rejected){if($r.exit -ne 1 -or $r.stderr -notmatch 'leaf failure index=0 first=[0-9]+ code=1506'){throw ('Invalid leaf control was not rejected: '+($r|ConvertTo-Json -Compress))}}
 elseif($r.exit -ne 0 -or $r.stderr -cne ''){throw ($r|ConvertTo-Json -Compress)}
 return $r.stdout
}
try {
 foreach($input in $reader.inputs){$null=Retain $input}
 $probes=@();foreach($stage in 0..1){$id=@($reader.artifacts|Where-Object {(Split-Path $_.path -Leaf) -ceq ('stage'+$stage+'-probe.exe')});if($id.Count -ne 1){throw 'Reader executable missing'};$probes+=Retain $id[0]}
 $objdump=Join-Path (Split-Path $reader.acceptedSelection.clang.path -Parent) 'llvm-objdump.exe';$inputs+=Get-ArtifactIdentity $objdump
 $objects=[ordered]@{}
 foreach($command in $binding.commands){if($command.arguments[0] -cne '--bound-extents' -or $command.exit -ne 0){continue};$names=@([regex]::Matches($command.stdout,'(?m)^([^\t\r\n]+)\tno-unwind\r?$')|ForEach-Object {$_.Groups[1].Value});if($names.Count){$objects[$command.arguments[1]]=$names}}
 if($objects.Count -ne 32){throw 'Expected thirty-two retained objects with observed leaf functions'};$ordinal=0
 foreach($path in $objects.Keys){
  $id=@($binding.inputs|Where-Object path -EQ $path);if($id.Count -lt 1){throw 'Qualified object identity missing'};$object=Retain $id[0];$names=$objects[$path]
  $text=Run $objdump @('-d',('--disassemble-symbols='+($names -join ',')),$object);[IO.File]::WriteAllText((Join-Path $run ($ordinal.ToString()+'-oracle.txt')),$text,$utf8)
  $bytes=[IO.File]::ReadAllBytes($object);$sections=[BitConverter]::ToUInt16($bytes,2);$raw=@();$rawBytes=0
  for($s=0;$s -lt $sections;++$s){$at=20+40*$s;if([Text.Encoding]::ASCII.GetString($bytes,$at,8).TrimEnd([char]0) -ceq '.text'){$raw+=[BitConverter]::ToUInt32($bytes,$at+20);$rawBytes=[BitConverter]::ToUInt32($bytes,$at+16)}}
  if($raw.Count -ne 1){throw 'Independent text-section locator is ambiguous'};$rows=@();$functions=@();$seen=@();$inText=$false;$nextOffset=-1
  foreach($line in ($text -split '\r?\n')){
   if($line -match '^Disassembly of section (.+):$'){$inText=$Matches[1] -ceq '.text';continue}
   if($line -match '^([0-9A-Fa-f]+) <([^>]+)>:$'){if(-not $inText -or $names -cnotcontains $Matches[2]){throw 'Unexpected disassembled function'};$seen+=$Matches[2];$nextOffset=[Convert]::ToInt32($Matches[1],16);$functions+=@([pscustomobject]@{name=$Matches[2];first=[int]($raw[0]+$nextOffset);rows=@()});continue}
   $m=[regex]::Match($line,'^\s*([0-9A-Fa-f]+):\s+((?:[0-9A-Fa-f]{2}\s+)+)([a-z][a-z0-9]*)\s*(.*)$');if(-not $m.Success){if($inText -and $line -match '^\s*[0-9A-Fa-f]+:'){throw 'Undecoded instruction in LLVM oracle'};continue};if(-not $inText){throw 'Instruction outside selected text section'}
   $offset=[Convert]::ToInt32($m.Groups[1].Value,16);$encoded=@(($m.Groups[2].Value.Trim() -split '\s+')|ForEach-Object {[Convert]::ToByte($_,16)});$length=$encoded.Count
   if($offset -ne $nextOffset){throw 'Gap in independent instruction sequence'};$nextOffset=$offset+$length
   if($length -lt 1 -or $length -gt 15 -or $offset -gt $rawBytes-$length){throw 'Independent instruction range is invalid'};$first=$raw[0]+$offset;for($i=0;$i -lt $length;++$i){if($bytes[$first+$i] -ne $encoded[$i]){throw 'Disassembly bytes do not match object'}}
   $mnemonic=$m.Groups[3].Value;$flow=0;$relative=[long]0
   if($mnemonic -in @('ret','retq')){$flow=1}
   if($mnemonic -match '^j'){$flow=2;if($mnemonic -in @('jmp','jmpq')){$flow=3};$target=[regex]::Match($m.Groups[4].Value,'^0x([0-9A-Fa-f]+)');if(-not $target.Success){throw 'Observed leaf has an unsupported indirect branch'};$relative=[Convert]::ToInt64($target.Groups[1].Value,16)-$offset-$length}
   if($mnemonic -match '^call' -or $mnemonic -eq 'ud2'){throw 'Observed leaf has an unexpected call or trap'}
   $row=[pscustomobject]@{first=[int]$first;length=[int]$length;flow=$flow;relative=$relative};$rows+=@($row);$functions[-1].rows+=@($row)
  }
  if($rows.Count -lt 1 -or $seen.Count -ne $names.Count -or @($names|Where-Object {$seen -cnotcontains $_}).Count){throw 'Independent selected-function disassembly is incomplete'}
  # Independent fixed-point reachability over LLVM's complete instruction rows.
  # This oracle does not decode bytes or reuse the production worklist/map logic.
  $stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]$functions.Count);$reachableInstructions=0;$summaries=@()
  foreach($function in $functions){
   if($function.rows.Count -lt 1){throw 'Empty disassembled function'}
   $end=$function.rows[-1].first+$function.rows[-1].length;$fence=$end-$function.first
   $byStart=@{};foreach($row in $function.rows){$byStart[[int]$row.first]=$row}
   $reachable=@{};$reachable[[int]$function.first]=$true;$changed=$true;$passes=0
   while($changed){
    $changed=$false;++$passes;if($passes -gt $function.rows.Count+1){throw 'Independent closure did not converge'}
    foreach($row in $function.rows){if(-not $reachable.ContainsKey([int]$row.first)){continue};$targets=@()
     if($row.flow -eq 0 -or $row.flow -eq 2){$targets+=@([long]($row.first+$row.length))}
     if($row.flow -eq 2 -or $row.flow -eq 3){$targets+=@([long]($row.first+$row.length+$row.relative))}
     foreach($target in $targets){if($target -lt $function.first -or $target -ge $end -or -not $byStart.ContainsKey([int]$target)){throw 'Independent branch escapes or enters operand'};if(-not $reachable.ContainsKey([int]$target)){$reachable[[int]$target]=$true;$changed=$true}}
    }
   }
   $marks=[byte[]]::new($fence);$extent=0
   foreach($row in $function.rows){if(-not $reachable.ContainsKey([int]$row.first)){continue};$offset=$row.first-$function.first;$marks[$offset]=2;for($i=1;$i -lt $row.length;++$i){$marks[$offset+$i]=3};$extent=[Math]::Max($extent,$offset+$row.length)}
   $summaries+=@([pscustomobject]@{name=$function.name;first=$function.first;fence=$fence;codeBytes=$extent;instructions=$reachable.Count});$writer.Write([int]$function.first);$writer.Write([int]$fence);$writer.Write([int]$extent);$writer.Write([int]$reachable.Count);$writer.Write($marks);$reachableInstructions+=$reachable.Count
  }
  $writer.Flush();$expected=Join-Path $run ($ordinal.ToString()+'-expected.bin');[IO.File]::WriteAllBytes($expected,$stream.ToArray());$writer.Dispose();$stream.Dispose()
  foreach($stage in 0..1){$actual=Run $probes[$stage] @('--leaves',$object,$expected);if($actual -cne ('PASS '+$functions.Count+[char]32+'independently traversed leaf functions'+[char]10)){throw 'Leaf comparison output differs'};$checks+=@([pscustomobject]@{assertion='Complete reachable leaf maps and extents match independent LLVM fixed-point closure';readerStage=$stage+1;object=$id[0];functions=$names;leaves=$summaries;instructions=$reachableInstructions;passed=$true})}
  foreach($control in @('unsupported','operand-target','stack-write')){
   $wrongBytes=[IO.File]::ReadAllBytes($object);$first=$functions[0].first
   if($control -eq 'unsupported'){$wrongBytes[$first]=0x62}
   if($control -eq 'operand-target'){$wrongBytes[$first]=0xEB;$wrongBytes[$first+1]=0xFF}
   if($control -eq 'stack-write'){$wrongBytes[$first]=0x53}
   $wrong=Join-Path $run ($ordinal.ToString()+'-'+$control+'.o');[IO.File]::WriteAllBytes($wrong,$wrongBytes)
   foreach($stage in 0..1){$null=Run $probes[$stage] @('--leaves',$wrong,$expected) $true;$checks+=@([pscustomobject]@{assertion=('Actual leaf rejects with 1506: '+$control);readerStage=$stage+1;passed=$true})}
  };++$ordinal
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Input changed during verification: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$reader.acceptedSelection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Reachable native leaf boundaries, maps and bounded traversal on retained objects against independent LLVM fixed-point closure. Fences are test-provided; final definition ownership, relocation binding, memory/stack safety and publication remain unqualified.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
