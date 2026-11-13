# Compares only the storage-lock acquisition loop in frozen native compiler drivers.
param([Parameter(Mandatory=$true)][string]$BaselineDirectory,[switch]$DescriptorStripes)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
. (Join-Path $PSScriptRoot 'descriptor-stripes.ps1')
$candidate='ttas';if($DescriptorStripes){$candidate='stripes'}
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube storage lock experiment '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
Copy-Item -LiteralPath (Join-Path $BaselineDirectory 'llvm') -Destination (Join-Path $artifacts 'llvm') -Recurse
$lib=Join-Path $artifacts 'kernel32.lib'
Copy-Item -LiteralPath (Join-Path $BaselineDirectory 'kernel32-files.lib') -Destination $lib
$bindings=[IO.File]::ReadAllText((Join-Path $BaselineDirectory 'process-1.stdout'),$utf8)
$identities=@{}
foreach($name in @('ConfigurePath','SetPathByte')){
 $found=[regex]::Matches($bindings,('(?m)^SYMBOL ([0-9]+)\|(?:function|sub)\|'+$name+'\|'))
 if($found.Count -ne 1){throw "Ambiguous identity $name"}
 $identities[$name]=$found[0].Groups[1].Value
}
$ttas=@'
define internal void @ube.program.storage.lock(ptr %program) {
entry:
  %lock = getelementptr %ube.program, ptr %program, i32 0, i32 6
  br label %poll
poll:
  %held = load atomic i64, ptr %lock monotonic, align 8
  %free = icmp eq i64 %held, 0
  br i1 %free, label %attempt, label %poll
attempt:
  %pair = cmpxchg ptr %lock, i64 0, i64 1 acquire monotonic
  %won = extractvalue { i64, i1 } %pair, 1
  br i1 %won, label %done, label %poll
done:
  ret void
}
'@
$script:sequence=0
# Runs bounded hidden tools, preserving diagnostics and exact native exit status.
function Run([string]$File,[string[]]$Arguments) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $watch=[Diagnostics.Stopwatch]::StartNew();$p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(120000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();if($p.ExitCode -ne 0){throw "Exit $($p.ExitCode): $prefix"}}finally{$p.Dispose()}
 $watch.Stop();return $watch.Elapsed.TotalMilliseconds
}
foreach($workers in @(1,2)) {
 $input=Join-Path $BaselineDirectory ('compiler sources trial '+$workers+'.ll')
 $ir=[IO.File]::ReadAllText($input,$utf8)
 foreach($kind in @(2,3)) {
  $bytes=$utf8.GetBytes((Join-Path $artifacts ('output-'+$kind+'.ll')))
  $configure='(?m)^  call \{ i1, i64 \} @ube\.proc\.'+$identities.ConfigurePath+'\(ptr @test.context, i64 '+$kind+', i64 [0-9]+\)\r?$'
  $set='(?m)^  call \{ i1, i64 \} @ube\.proc\.'+$identities.SetPathByte+'\(ptr @test.context, i64 '+$kind+', i64 [0-9]+, i64 [0-9]+\)\r?\n'
  if([regex]::Matches($ir,$configure).Count -ne 1){throw "Missing path $kind"}
  $ir=[regex]::Replace($ir,$set,'')
  $replacement='  call { i1, i64 } @ube.proc.'+$identities.ConfigurePath+'(ptr @test.context, i64 '+$kind+', i64 '+$bytes.Length+')'
  for($i=0;$i -lt $bytes.Length;$i++){$replacement+="`r`n"+'  call { i1, i64 } @ube.proc.'+$identities.SetPathByte+'(ptr @test.context, i64 '+$kind+', i64 '+$i+', i64 '+$bytes[$i]+')'}
  $ir=[regex]::Replace($ir,$configure,[Text.RegularExpressions.MatchEvaluator]{param($m)$replacement})
 }
 foreach($variant in @('baseline',$candidate)) {
  $text=$ir
  if($variant -eq 'ttas') {
   $pattern='(?ms)^define internal void @ube\.program\.storage\.lock\(ptr %program\) \{\r?\n.*?^}\r?\n'
   if([regex]::Matches($text,$pattern).Count -ne 1){throw 'Missing unique lock'}
   $text=[regex]::Replace($text,$pattern,($ttas -replace '\r?\n',"`r`n")+"`r`n")
  }
  if($variant -eq 'stripes'){$text=Add-DescriptorStripes $text}
  $stem=Join-Path $artifacts ($variant+'-'+$workers)
  [IO.File]::WriteAllText(($stem+'.ll'),$text,$utf8)
  $null=Run 'C:\Program Files\LLVM\bin\clang.exe' @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib','-O2',($stem+'.ll'),$lib,'-o',($stem+'.exe'),'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 }
}
$expected=(Get-FileHash -LiteralPath (Join-Path $BaselineDirectory 'compiler-trial-1.ll') -Algorithm SHA256).Hash
$rows=New-Object Collections.Generic.List[object]
# Two reversed blocks balance variant and worker ordering without concurrent benchmark jobs.
$order=@('baseline-1',($candidate+'-1'),'baseline-2',($candidate+'-2'),($candidate+'-2'),'baseline-2',($candidate+'-1'),'baseline-1')
foreach($round in @(1,2)) {
 foreach($case in $order) {
  $elapsed=Run (Join-Path $artifacts ($case+'.exe')) @()
  $hash=(Get-FileHash -LiteralPath (Join-Path $artifacts 'output-2.ll') -Algorithm SHA256).Hash
  if($hash -cne $expected){throw "Changed output: $case"}
  $row=[pscustomobject]@{Round=$round;Case=$case;Milliseconds=$elapsed;OutputHash=$hash}
  $rows.Add($row);$rows|Export-Csv -LiteralPath (Join-Path $artifacts 'measurements.csv') -NoTypeInformation
  Write-Output ("PASS {0} {1} {2:N2} ms exact hash" -f $round,$case,$elapsed)
 }
}
$rows|Group-Object Case|ForEach-Object{[pscustomobject]@{Case=$_.Name;MeanMilliseconds=($_.Group|Measure-Object Milliseconds -Average).Average;Trials=$_.Count}}|Format-Table -AutoSize
