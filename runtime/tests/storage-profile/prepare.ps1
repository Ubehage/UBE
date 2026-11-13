# Instruments an existing native compiler driver without changing compiler source or emitted runtime assets.
param([Parameter(Mandatory=$true)][string]$InputIR,[Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$InputIR=[IO.Path]::GetFullPath($InputIR)
$Destination=[IO.Path]::GetFullPath($Destination)
if(Test-Path -LiteralPath $Destination){throw 'Use a new profile destination to preserve existing evidence'}
$null=New-Item -ItemType Directory -Path $Destination
$sourceDirectory=[IO.Path]::GetDirectoryName($InputIR)
$ir=[IO.File]::ReadAllText($InputIR,$utf8)
$bindings=[IO.File]::ReadAllText((Join-Path $sourceDirectory 'process-1.stdout'),$utf8)
$identities=@{}
foreach($name in @('ConfigurePath','SetPathByte')){
 $found=[regex]::Matches($bindings,('(?m)^SYMBOL ([0-9]+)\|(?:function|sub)\|'+$name+'\|'))
 if($found.Count -ne 1){throw "Ambiguous probe identity $name"}
 $identities[$name]=$found[0].Groups[1].Value
}
# Redirect only the probe's output paths, retaining its immutable source corpus and worker setting.
foreach($kind in @(2,3)){
 $path=Join-Path $Destination ('output-'+$kind+'.ll');$bytes=$utf8.GetBytes($path)
 $configure='(?m)^  call \{ i1, i64 \} @ube\.proc\.'+$identities.ConfigurePath+'\(ptr @test.context, i64 '+$kind+', i64 [0-9]+\)\r?$'
 $set='(?m)^  call \{ i1, i64 \} @ube\.proc\.'+$identities.SetPathByte+'\(ptr @test.context, i64 '+$kind+', i64 [0-9]+, i64 [0-9]+\)\r?\n'
 if([regex]::Matches($ir,$configure).Count -ne 1){throw "Missing unique output path $kind"}
 $ir=[regex]::Replace($ir,$set,'')
 $replacement='  call { i1, i64 } @ube.proc.'+$identities.ConfigurePath+'(ptr @test.context, i64 '+$kind+', i64 '+$bytes.Length+')'
 for($i=0;$i -lt $bytes.Length;$i++){$replacement+="`r`n"+'  call { i1, i64 } @ube.proc.'+$identities.SetPathByte+'(ptr @test.context, i64 '+$kind+', i64 '+$i+', i64 '+$bytes[$i]+')'}
 $ir=[regex]::Replace($ir,$configure,[Text.RegularExpressions.MatchEvaluator]{param($m)$replacement})
}
# Finds one complete existing runtime definition, never a similarly named source procedure.
function Function-Body([string]$Name){
 $matches=[regex]::Matches($script:ir,('(?ms)^define[^\r\n]*@'+[regex]::Escape($Name)+'\([^\r\n]*\{\r?\n.*?^}\r?\n'))
 if($matches.Count -ne 1){throw "Missing unique runtime function $Name"}
 return $matches[0].Value
}
$operations=@('ube.memory.collect','ube.memory.new','ube.array.snapshot','ube.array.clear','ube.array.install','ube.box.drop','ube.memory.copybytes')
for($op=0;$op -lt $operations.Count;$op++){
 $old=Function-Body $operations[$op]
 if(-not $old.Contains('call void @ube.program.storage.lock(ptr %program)')){throw "Missing storage lock for $($operations[$op])"}
 $new=$old.Replace('call void @ube.program.storage.lock(ptr %program)','call void @profile.storage.lock(ptr %program, i64 '+$op+')')
 $ir=$ir.Replace($old,$new)
}
$old=Function-Body 'ube.program.storage.lock'
$ir=$ir.Replace($old,"define internal void @ube.program.storage.lock(ptr %program) {`r`nentry:`r`n  call void @profile.storage.lock(ptr %program,i64 7)`r`n  ret void`r`n}`r`n")
$old=Function-Body 'ube.memory.collect.locked';$new=$old
$new=$new.Replace('  %block = load ptr, ptr %link',"  %profile.scanned = phi i64 [ 0, %entry ], [ %profile.next, %keep ], [ %profile.next, %freed ]`r`n  %profile.frees = phi i64 [ 0, %entry ], [ %profile.frees, %keep ], [ %profile.more.frees, %freed ]`r`n  %block = load ptr, ptr %link")
$new=$new.Replace("inspect:`r`n","inspect:`r`n  %profile.next = add i64 %profile.scanned, 1`r`n")
$new=$new.Replace("freed:`r`n","freed:`r`n  %profile.more.frees = add i64 %profile.frees, 1`r`n")
$report=@'
done:
  %profile.calls.ptr = getelementptr [72 x i64],ptr @profile.counts,i64 0,i64 64
  %profile.scans.ptr = getelementptr [72 x i64],ptr @profile.counts,i64 0,i64 65
  %profile.frees.ptr = getelementptr [72 x i64],ptr @profile.counts,i64 0,i64 66
  %profile.empty.ptr = getelementptr [72 x i64],ptr @profile.counts,i64 0,i64 67
  %profile.idle.ptr = getelementptr [72 x i64],ptr @profile.counts,i64 0,i64 68
  %profile.max.ptr = getelementptr [72 x i64],ptr @profile.counts,i64 0,i64 69
  %profile.empty = icmp eq i64 %profile.scanned,0
  %profile.idle = icmp eq i64 %profile.frees,0
  %profile.empty.value = zext i1 %profile.empty to i64
  %profile.idle.value = zext i1 %profile.idle to i64
  %profile.old.calls = atomicrmw add ptr %profile.calls.ptr,i64 1 monotonic
  %profile.old.scans = atomicrmw add ptr %profile.scans.ptr,i64 %profile.scanned monotonic
  %profile.old.frees = atomicrmw add ptr %profile.frees.ptr,i64 %profile.frees monotonic
  %profile.old.empty = atomicrmw add ptr %profile.empty.ptr,i64 %profile.empty.value monotonic
  %profile.old.idle = atomicrmw add ptr %profile.idle.ptr,i64 %profile.idle.value monotonic
  %profile.old.max = atomicrmw umax ptr %profile.max.ptr,i64 %profile.scanned monotonic
'@
$new=$new.Replace("done:`r`n",($report -replace '\r?\n',"`r`n")+"`r`n")
$ir=$ir.Replace($old,$new)
$old=Function-Body 'ube.array.snapshot'
$new=$old.Replace("entry:`r`n","entry:`r`n  %profile.snapshots.ptr = getelementptr [72 x i64],ptr @profile.counts,i64 0,i64 70`r`n  %profile.old.snapshots = atomicrmw add ptr %profile.snapshots.ptr,i64 1 monotonic`r`n")
$ir=$ir.Replace($old,$new)
$old=Function-Body 'ube.memory.collect'
$new=$old.Replace("entry:`r`n","entry:`r`n  %profile.requests.ptr = getelementptr [72 x i64],ptr @profile.counts,i64 0,i64 71`r`n  %profile.old.requests = atomicrmw add ptr %profile.requests.ptr,i64 1 monotonic`r`n")
$ir=$ir.Replace($old,$new)
$support=@'
@profile.counts = global [72 x i64] zeroinitializer,align 64
define internal void @profile.storage.lock(ptr %program,i64 %operation) {
entry:
  %lock = getelementptr %ube.program,ptr %program,i32 0,i32 6
  br label %attempt
attempt:
  %retries = phi i64 [0,%entry],[%next,%attempt]
  %pair = cmpxchg ptr %lock,i64 0,i64 1 acquire monotonic
  %won = extractvalue {i64,i1} %pair,1
  %next = add i64 %retries,1
  br i1 %won,label %done,label %attempt
done:
  %offset = mul i64 %operation,8
  %calls.ptr = getelementptr [72 x i64],ptr @profile.counts,i64 0,i64 %offset
  %retries.ptr = getelementptr i64,ptr %calls.ptr,i64 1
  %contended.ptr = getelementptr i64,ptr %calls.ptr,i64 2
  %contended = icmp ne i64 %retries,0
  %value = zext i1 %contended to i64
  %old.calls = atomicrmw add ptr %calls.ptr,i64 1 monotonic
  %old.retries = atomicrmw add ptr %retries.ptr,i64 %retries monotonic
  %old.contended = atomicrmw add ptr %contended.ptr,i64 %value monotonic
  ret void
}
define i32 @main() {
entry:
  %written = alloca i32,align 4
  %status = call i32 @profile.program.entry()
  %handle = call ptr @CreateFileW(ptr @profile.path,i32 1073741824,i32 0,ptr null,i32 2,i32 128,ptr null)
  %valid = icmp ne ptr %handle,inttoptr (i64 -1 to ptr)
  br i1 %valid,label %write,label %failed
write:
  %sent = call i32 @WriteFile(ptr %handle,ptr @profile.counts,i32 576,ptr %written,ptr null)
  %count = load i32,ptr %written,align 4
  %closed = call i32 @CloseHandle(ptr %handle)
  %sent.ok = icmp ne i32 %sent,0
  %close.ok = icmp ne i32 %closed,0
  %count.ok = icmp eq i32 %count,576
  %a = and i1 %sent.ok,%close.ok
  %ok = and i1 %a,%count.ok
  %result = select i1 %ok,i32 %status,i32 99
  ret i32 %result
failed:
  ret i32 99
}
'@
if([regex]::Matches($ir,'(?m)^define i32 @main\(\)').Count -ne 1){throw 'Missing unique native driver entry'}
$ir=$ir.Replace('define i32 @main()','define i32 @profile.program.entry()')
$path=Join-Path $Destination 'counts.bin'
$units=@($path.ToCharArray()|ForEach-Object{'i16 '+[int]$_});$units+='i16 0'
$support+="`r`n"+'@profile.path = private constant ['+$units.Count+' x i16] ['+($units -join ',')+'],align 2'+"`r`n"
$output=Join-Path $Destination 'profile.ll'
[IO.File]::WriteAllText($output,($ir+"`r`n"+$support),$utf8)
Copy-Item -LiteralPath (Join-Path $sourceDirectory 'llvm') -Destination (Join-Path $Destination 'llvm') -Recurse
Copy-Item -LiteralPath (Join-Path $sourceDirectory 'kernel32-files.lib') -Destination (Join-Path $Destination 'kernel32.lib')
Write-Output "Prepared instrumented driver: $output"
Write-Output 'No profile executed. Instrumented elapsed times are not performance acceptance evidence.'
