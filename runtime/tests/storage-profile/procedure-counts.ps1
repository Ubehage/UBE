# Counts executed snapshot calls per generated procedure and runtime helper; not a timing benchmark.
param([Parameter(Mandatory=$true)][string]$BaselineDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube snapshot procedures '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
Copy-Item -LiteralPath (Join-Path $BaselineDirectory 'llvm') -Destination (Join-Path $artifacts 'llvm') -Recurse
$bindings=[IO.File]::ReadAllText((Join-Path $BaselineDirectory 'process-1.stdout'),$utf8)
$symbols=@{};$modules=@{};$identities=@{}
foreach($line in ($bindings -split '\r?\n')) {
 if($line.StartsWith('SYMBOL ')) {
  $fields=$line.Substring(7).Split('|');$symbols[$fields[0]]=$fields
  if($fields[1] -eq 'module'){$modules[$fields[5]]=$fields[2]}
  if($fields[1] -in @('function','sub') -and $fields[2] -in @('ConfigurePath','SetPathByte','TryAppendInteger')){$identities[$fields[2]]=$fields[0]}
 }
}
$ir=[IO.File]::ReadAllText((Join-Path $BaselineDirectory 'compiler sources trial 1.ll'),$utf8)
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
$rows=New-Object Collections.Generic.List[object]
$definitions=[regex]::Matches($ir,'(?ms)^define[^\r\n]*@([^ (]+)\([^\r\n]*\{\r?\n.*?^}\r?\n')
$ordinal=0
foreach($definition in $definitions) {
 $name=$definition.Groups[1].Value
 $old=$definition.Value
 if(-not $old.Contains('@ube.array.snapshot(') -and -not $name.StartsWith('ube.proc.')){continue}
 $label=$name;$category='runtime'
 if($name -match '^ube\.proc\.([0-9]+)$') {
  $fields=$symbols[$Matches[1]]
  $label=$modules[$fields[5]]+'.'+$fields[2];$category='source'
 }
 $entryIndex=$ordinal*3;$snapshotIndex=$entryIndex+1;$appendIndex=$entryIndex+2
 $new=$old.Replace("entry:`r`n","entry:`r`n  call void @profile.hit(i64 $entryIndex)`r`n")
 $new=[regex]::Replace($new,'(?m)^(  .* = call .*@ube\.array\.snapshot\([^\r\n]*\r?$)',("  call void @profile.hit(i64 $snapshotIndex)`r`n"+'$1'))
 if($label -eq 'LLVMFormat.TryFormat') {
  $call='(?m)^(  .* = call .*@ube\.proc\.'+$identities.TryAppendInteger+'\([^\r\n]*\r?$)'
  $new=[regex]::Replace($new,$call,("  call void @profile.hit(i64 $appendIndex)`r`n"+'$1'))
 }
 $rows.Add([pscustomobject]@{Index=$ordinal;Category=$category;Symbol=$name;Name=$label;Entries=0;Snapshots=0;IntegerAppends=0})
 $ir=$ir.Replace($old,$new);$ordinal++
}
$cells=$ordinal*3;$size=$cells*8
$ir=$ir.Replace('define i32 @main()','define i32 @profile.program.entry()')
$support=@'
@profile.counts = internal global [CELLS x i64] zeroinitializer, align 64
define internal void @profile.hit(i64 %index) {
entry:
 %pointer = getelementptr [CELLS x i64], ptr @profile.counts, i64 0, i64 %index
 %prior = atomicrmw add ptr %pointer, i64 1 monotonic
 ret void
}
define i32 @main() {
entry:
 %written = alloca i32, align 4
 %status = call i32 @profile.program.entry()
 %handle = call ptr @CreateFileW(ptr @profile.path, i32 1073741824, i32 0, ptr null, i32 2, i32 128, ptr null)
 %valid = icmp ne ptr %handle, inttoptr (i64 -1 to ptr)
 br i1 %valid, label %write, label %failed
write:
 %sent = call i32 @WriteFile(ptr %handle, ptr @profile.counts, i32 BYTES, ptr %written, ptr null)
 %count = load i32, ptr %written, align 4
 %closed = call i32 @CloseHandle(ptr %handle)
 %sent.ok = icmp ne i32 %sent, 0
 %close.ok = icmp ne i32 %closed, 0
 %count.ok = icmp eq i32 %count, BYTES
 %a = and i1 %sent.ok, %close.ok
 %ok = and i1 %a, %count.ok
 %result = select i1 %ok, i32 %status, i32 99
 ret i32 %result
failed:
 ret i32 99
}
'@
$support=$support.Replace('CELLS',[string]$cells).Replace('BYTES',[string]$size)
$path=Join-Path $artifacts 'counts.bin';$units=@($path.ToCharArray()|ForEach-Object{'i16 '+[int]$_});$units+='i16 0'
$support+="`r`n"+'@profile.path = private constant ['+$units.Count+' x i16] ['+($units -join ',')+'],align 2'+"`r`n"
$stem=Join-Path $artifacts 'profile'
[IO.File]::WriteAllText(($stem+'.ll'),($ir+"`r`n"+$support),$utf8)
$script:sequence=0
# Executes direct tools with bounded deadlines and retained diagnostics.
function Run([string]$File,[string[]]$Arguments) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(180000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();if($p.ExitCode -ne 0){throw "Exit $($p.ExitCode): $prefix"}}finally{$p.Dispose()}
}
Run 'C:\Program Files\LLVM\bin\clang.exe' @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib','-O2',($stem+'.ll'),(Join-Path $BaselineDirectory 'kernel32-files.lib'),'-o',($stem+'.exe'),'-Wl,/entry:main,/subsystem:console,/stack:8388608')
Run ($stem+'.exe') @()
$expected=(Get-FileHash -LiteralPath (Join-Path $BaselineDirectory 'compiler-trial-1.ll') -Algorithm SHA256).Hash
$actual=(Get-FileHash -LiteralPath (Join-Path $artifacts 'output-2.ll') -Algorithm SHA256).Hash
if($expected -cne $actual){throw 'Profile changed emitted output'}
$data=[IO.File]::ReadAllBytes($path)
if($data.Length -ne $size){throw 'Counter payload length mismatch'}
foreach($row in $rows) {
 $row.Entries=[BitConverter]::ToInt64($data,$row.Index*24)
 $row.Snapshots=[BitConverter]::ToInt64($data,$row.Index*24+8)
 $row.IntegerAppends=[BitConverter]::ToInt64($data,$row.Index*24+16)
}
$rows|Export-Csv -LiteralPath (Join-Path $artifacts 'counts.csv') -NoTypeInformation
$rows|Sort-Object Snapshots -Descending|Select-Object -First 25 Name,Entries,Snapshots,IntegerAppends|Format-Table -AutoSize
Write-Output "PASS exact output hash $actual; execution counts only, no timing claim"
