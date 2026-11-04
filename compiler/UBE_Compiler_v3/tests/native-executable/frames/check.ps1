param([Parameter(Mandatory=$true)][string]$GraphReport,[Parameter(Mandatory=$true)][string]$EmissionReport)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$graph=Get-Content -LiteralPath $GraphReport -Raw|ConvertFrom-Json;$emission=Get-Content -LiteralPath $EmissionReport -Raw|ConvertFrom-Json
if(-not $graph.success -or -not $emission.success){throw 'Binding requires successful graph and emission reports'}
if($graph.acceptedSelection.compiler.sha256 -cne $emission.acceptedSelection.compiler.sha256 -or $graph.acceptedSelection.manifest.sha256 -cne $emission.acceptedSelection.manifest.sha256){throw 'Bootstrap identities differ'}
$selection=$emission.acceptedSelection;$clang=$selection.clang.path;$toolDirectory=Split-Path $clang -Parent
if((Get-ArtifactIdentity $clang).sha256 -cne $selection.clang.sha256){throw 'Selected Clang changed'}
$readobj=Join-Path $toolDirectory 'llvm-readobj.exe';$objdump=Join-Path $toolDirectory 'llvm-objdump.exe';$nm=Join-Path $toolDirectory 'llvm-nm.exe'
$run=Join-Path $root ('bootstrap/out/native-frames/'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
$utf8=[Text.UTF8Encoding]::new($false);$inputs=@();$commands=@();$checks=@();$bindings=@();$success=$false;$failure=$null
foreach($path in @($GraphReport,$EmissionReport,$clang,$readobj,$objdump,$nm,$PSCommandPath,(Join-Path $PSScriptRoot 'observer.c'),(Join-Path $root 'bootstrap/runtime/error_support.c'),(Join-Path $root 'bootstrap/tools/verification.ps1'))){$inputs+=Get-ArtifactIdentity $path}
# The graph report can predate the added frame emitter. Verify all production
# source inputs, not an obsolete manifest claim, and pin every consumed output.
foreach($report in @($graph,$emission)){foreach($input in $report.inputs){if($input.path -match '[\\/]src[\\/].*\.(bas|cls)$'){
 if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Generator source changed: '+$input.path)};$inputs+=$input
}}}
function Run([string]$File,[string[]]$Arguments,[int]$Timeout=180){$r=Invoke-BoundedProcess $File $Arguments $run $Timeout;$script:commands+=@($r);if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)};return $r}
function Artifact($Report,[string]$Path){$id=Get-ArtifactIdentity $Path;$expected=@($Report.artifacts|Where-Object path -EQ $id.path);if($expected.Count -ne 1 -or $expected[0].sha256 -cne $id.sha256){throw ('Retained artifact mismatch: '+$Path)};$script:inputs+=$id;return $id.path}
function Read-Frames([string]$Object){
 $usage=[IO.File]::ReadAllLines([IO.Path]::ChangeExtension($Object,'.su'));$frames=@{}
 foreach($line in $usage){if($line -notmatch ':([^:\t]+)\t([0-9]+)\tstatic$'){throw ('Unclassified stack report: '+$line)};$name=$Matches[1];$size=[long]$Matches[2];if($frames.ContainsKey($name) -or $size -gt [long]::MaxValue-8){throw 'Duplicate or overflowing frame'};$frames[$name]=$size}
 if(-not $frames.Count){throw 'Missing frame report'}
 $inventory=(Run $nm @('--defined-only','--format=posix',$Object)).stdout
 $functions=@([regex]::Matches($inventory,'(?m)^(ube\.[^ ]+) [Tt] ')|ForEach-Object {$_.Groups[1].Value})
 $difference=@(Compare-Object ($functions|Sort-Object) (@($frames.Keys)|Sort-Object))
 if($difference.Count){throw 'Frame report differs from object definition inventory'}
 $unwind=(Run $readobj @('--unwind',$Object)).stdout;[IO.File]::WriteAllText($Object+'.unwind.txt',$unwind,$utf8)
 $disassembly=(Run $objdump @('-d','--no-show-raw-insn',$Object)).stdout;[IO.File]::WriteAllText($Object+'.asm.txt',$disassembly,$utf8)
 foreach($name in @($frames.Keys)){
  $blocks=[regex]::Matches($unwind,'(?s)RuntimeFunction \{\s*StartAddress: '+[regex]::Escape($name)+' \([^\n]*\).*?UnwindCodes \[([^\]]*)\]')
  if($frames[$name] -eq 0){
   if($blocks.Count){throw 'Unexpected zero-frame unwind record'}
   $body=[regex]::Matches($disassembly,'(?ms)^[0-9a-f]+ <'+[regex]::Escape($name)+'>:\r?\n(.*?)(?=^[0-9a-f]+ <|\z)')
   if($body.Count -ne 1 -or $body[0].Groups[1].Value -match '\b(?:push|pop|call|enter|leave)[a-z]*\b|%[er]sp\b'){throw 'Missing or unclassified zero-frame leaf evidence'}
  }else{
   if($blocks.Count -ne 1){throw ('Missing or duplicate unwind entry: '+$name)};$sum=[long]0
   foreach($line in ($blocks[0].Groups[1].Value -split '\r?\n')){if(-not $line.Trim()){continue};if($line -match '^\s*0x[0-9A-Fa-f]+: ALLOC_(?:SMALL|LARGE) size=([0-9]+)\s*$'){$sum+=[long]$Matches[1]}elseif($line -match '^\s*0x[0-9A-Fa-f]+: PUSH_NONVOL reg=[A-Z0-9]+\s*$'){$sum+=8}else{throw ('Unclassified unwind operation: '+$line)}}
   if($sum -ne $frames[$name]){throw ('Stack report/unwind mismatch: '+$name)}
  }
 }
 return $frames
}
function Read-Table([string]$Path,[string]$Name,[int]$Count){
 $description=(Run $readobj @('--symbols','--sections',$Path)).stdout
 $symbol=[regex]::Matches($description,'(?m)^\s*Name: '+[regex]::Escape($Name)+'\s*\n\s*Value: ([0-9]+)\s*\n\s*Section: \.rdata \(([0-9]+)\)')
 if($symbol.Count -ne 1){throw ('Missing or duplicate data symbol: '+$Name)}
 $offset=[long]$symbol[0].Groups[1].Value;$number=$symbol[0].Groups[2].Value
 $section=[regex]::Matches($description,'(?m)^\s*Number: '+$number+'\s*\n\s*Name: \.rdata[^\n]*\n\s*VirtualSize:[^\n]*\n\s*VirtualAddress:[^\n]*\n\s*RawDataSize: ([0-9]+)\s*\n\s*PointerToRawData: 0x([0-9A-Fa-f]+)')
 if($section.Count -ne 1 -or $offset -gt [long]$section[0].Groups[1].Value-8*$Count){throw 'Data extent outside section'}
 $position=[Convert]::ToInt64($section[0].Groups[2].Value,16)+$offset;$bytes=[IO.File]::ReadAllBytes($Path)
 if($position -lt 0 -or $position -gt $bytes.Length-8*$Count){throw 'Data extent outside file'}
 $values=@();for($i=0;$i -lt $Count;++$i){$values+=[BitConverter]::ToUInt64($bytes,[int]($position+8*$i))};return ,$values
}
function Assert-Table([string]$Path,[long[]]$Expected){$found=Read-Table $Path 'ube.stack.frames' $Expected.Length;for($i=0;$i -lt $Expected.Length;++$i){if($found[$i] -ne $Expected[$i]){throw ('Bound frame differs at slot '+$i)}};if((Read-Table $Path 'ube.stack.reserve' 1)[0] -ne 256){throw 'Controlled reserve differs'}}
try {
 $graphDirectory=Split-Path ([IO.Path]::GetFullPath($GraphReport)) -Parent;$emissionDirectory=Split-Path ([IO.Path]::GetFullPath($EmissionReport)) -Parent
 for($stage=0;$stage -lt 2;++$stage){
  $sourceDirectory=Join-Path $graphDirectory ('stage'+$stage)
  $header=Artifact $graph (Join-Path $sourceDirectory 'guard-functions.h')
  $ordinary=@([regex]::Matches([IO.File]::ReadAllText($header),'__asm__\("(ube\.f[0-9]+)"\)')|ForEach-Object {$_.Groups[1].Value})
  if($ordinary.Count -ne 14 -or @($ordinary|Select-Object -Unique).Count -ne 14){throw 'Checked frame mapping differs'}
  $frameDriver=Artifact $emission (Join-Path $emissionDirectory ('stage'+$stage+'-frame-data.exe'))
  $platform=Artifact $emission (Join-Path $emissionDirectory ('stage'+$stage+'-platform.ll'))
  $data=Artifact $graph (Join-Path $sourceDirectory 'guard-data.ll')
  foreach($reference in 0..1){foreach($optimization in @('O0','O2')){foreach($debug in @('None','Full')){
   $directory=Join-Path $run ('stage'+$stage+'-'+$reference+'-'+$optimization+'-'+$debug);$null=[IO.Directory]::CreateDirectory($directory)
   $flags=@('--target=x86_64-w64-windows-gnu',('-'+$optimization),'-fno-lto','-fstack-usage');if($debug -eq 'Full'){$flags+=@('-g','-gdwarf-4')}else{$flags+='-g0'}
   $objects=@();$identities=@();$frames=@{}
   foreach($unit in @(('module-'+$reference+'-0'),('module-'+$reference+'-1'),('module-'+$reference+'-2'),('project-entry-'+$reference),'platform')){
    $source=$platform;if($unit -ne 'platform'){$source=Artifact $graph (Join-Path $sourceDirectory ($unit+'.ll'))}
    $object=Join-Path $directory ($unit+'.o');$null=Run $clang ($flags+@('-c',$source,'-o',$object));$objects+=$object;$identities+=Get-ArtifactIdentity $object
    $observed=Read-Frames $object;foreach($name in $observed.Keys){if($frames.ContainsKey($name)){throw 'Repeated object definition'};$frames[$name]=[long]$observed[$name]}
   }
   $names=$ordinary+@('ube.module.init0','ube.module.init1','ube.module.init2','ube.module.wait');$footprints=@()
   foreach($name in $names){if(-not $frames.ContainsKey($name)){throw ('Missing required frame: '+$name)};$footprints+=[long]($frames[$name]+8)}
   $transport=Join-Path $directory 'frames.bin';$stream=[IO.MemoryStream]::new();$writer=[IO.BinaryWriter]::new($stream);$writer.Write([int]14);$writer.Write([int]3);$writer.Write([long]256);foreach($value in $footprints){$writer.Write([long]$value)};$writer.Flush();[IO.File]::WriteAllBytes($transport,$stream.ToArray());$writer.Dispose();$stream.Dispose()
   $table=Join-Path $directory 'frames.ll';$r=Run $frameDriver @($transport,$table);if($r.stdout -cne "PASS frame metadata 18 slots`n" -or $r.stderr -cne ''){throw 'Frame emitter transport mismatch'}
   $tableObject=Join-Path $directory 'frames.o';$null=Run $clang ($flags+@('-c',$table,'-o',$tableObject));Assert-Table $tableObject $footprints
   [IO.File]::WriteAllText((Join-Path $directory 'expected-frames.h'),('static const uint64_t expected_frames[18]={'+($footprints -join ',')+'};'),$utf8)
   $dataObject=Join-Path $directory 'initialization-data.o';$null=Run $clang ($flags+@('-c',$data,'-o',$dataObject))
   $observerObject=Join-Path $directory 'observer.o';$null=Run $clang ($flags+@('-fno-emulated-tls','-std=c17','-Wall','-Wextra','-Werror','-I',$root,'-I',$sourceDirectory,'-I',$directory,'-c',(Join-Path $PSScriptRoot 'observer.c'),'-o',$observerObject))
   $exe=Join-Path $directory 'bound.exe';$null=Run $clang (@('--target=x86_64-w64-windows-gnu','-fno-lto')+$objects+@($dataObject,$tableObject,$observerObject,'-o',$exe))
   Assert-Table $exe $footprints;$r=Run $exe @();if($r.stdout -cne "PASS bound frame metadata and actual checked entry`n" -or $r.stderr -cne ''){throw 'Bound actual entry differs'}
   foreach($identity in $identities){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw 'Measured object changed through link'}}
   if($stage -eq 0 -and $reference -eq 0 -and $optimization -eq 'O0' -and $debug -eq 'None'){
    $originalRows=[IO.File]::ReadAllLines([IO.Path]::ChangeExtension($objects[0],'.su'))
    foreach($control in @('missing','duplicate','dynamic','size')){
     $controlObject=Join-Path $directory ($control+'-report.o');[IO.File]::Copy($objects[0],$controlObject)
     $rows=@($originalRows);switch($control){
      'missing' {$rows=@($rows|Select-Object -Skip 1)}
      'duplicate' {$rows+=@($rows[0])}
      'dynamic' {$rows[0]=$rows[0] -replace 'static$','dynamic'}
      'size' {if($rows[0] -notmatch '\t([0-9]+)\tstatic$'){throw 'Control frame missing'};$value=[long]$Matches[1]+8;$rows[0]=$rows[0] -replace '\t[0-9]+\tstatic$',("`t"+$value+"`tstatic")}
     }
     [IO.File]::WriteAllLines([IO.Path]::ChangeExtension($controlObject,'.su'),$rows,$utf8)
     $rejected=$false;try{$null=Read-Frames $controlObject}catch{if($_.Exception.Message -notmatch 'Frame report differs|Duplicate or overflowing|Unclassified stack report|Stack report/unwind mismatch'){throw};$rejected=$true}
     if(-not $rejected){throw ('Corrupted frame report accepted: '+$control)}
     $checks+=@([pscustomobject]@{assertion=('Frame report negative control '+$control);passed=$true})
    }
   }
   $bindings+=@([pscustomobject]@{stage=$stage+1;reference=$reference;optimization=$optimization;debug=$debug;names=$names;ownFrames=@($names|ForEach-Object {$frames[$_]});footprints=$footprints;objects=$identities;table=(Get-ArtifactIdentity $tableObject);image=(Get-ArtifactIdentity $exe)})
   $checks+=@([pscustomobject]@{assertion='Actual checked modules: static/unwind/leaf agreement, complete slot map, UBE-emitted separate data, retained objects, linked values and real platform entry';stage=$stage+1;reference=$reference;optimization=$optimization;debug=$debug;passed=$true})
   # Deliberately understate one non-leaf slot. The emitter only validates shape;
   # object binding must reject this before execution, in object and image.
   $wrongValues=@($footprints);$slot=0;while($wrongValues[$slot] -le 8){++$slot};$wrongValues[$slot]-=8
   $badText=[IO.File]::ReadAllText($table);$matches=[regex]::Matches($badText,'(?m)^  i64 ([0-9]+)');if($matches.Count -ne 18){throw 'Expected frame constants missing'}
   $match=$matches[$slot];$badText=$badText.Remove($match.Index,$match.Length).Insert($match.Index,('  i64 '+$wrongValues[$slot]));$bad=Join-Path $directory 'understated.ll';[IO.File]::WriteAllText($bad,$badText,$utf8)
   $badObject=Join-Path $directory 'understated.o';$null=Run $clang ($flags+@('-c',$bad,'-o',$badObject));$badExe=Join-Path $directory 'understated.exe';$null=Run $clang (@('--target=x86_64-w64-windows-gnu','-fno-lto')+$objects+@($dataObject,$badObject,$observerObject,'-o',$badExe))
   foreach($candidate in @($badObject,$badExe)){$rejected=$false;try{Assert-Table $candidate $footprints}catch{if($_.Exception.Message -notlike 'Bound frame differs at slot *'){throw};$rejected=$true};if(-not $rejected){throw 'Understated return-address control accepted'}}
   $checks+=@([pscustomobject]@{assertion='Understated call footprint rejected in metadata object and final image before execution';stage=$stage+1;reference=$reference;optimization=$optimization;debug=$debug;passed=$true})
  }}}
 }
 foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw ('Binding input changed: '+$input.path)}}
 $success=$true
}catch{$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks;bindings=$bindings;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Test-owned object/frame binding and exact production UBE metadata emitter with actual checked modules and real Windows entry; controlled reserve 256. Not production binary inspection, call-site/prologue transient proof, derived recovery reserve, complete startup/API safety, debug validation or builder acceptance.'}|ConvertTo-Json -Depth 18|Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
