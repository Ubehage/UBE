# Executes the guarded UBE publication with independent runtime byte vectors.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$CompilerExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube publication ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $artifacts -Force
$script:processNumber = 0
# Stops at the first independently specified assertion failure.
function Require([bool]$Condition,[string]$Message) { if(-not $Condition){throw $Message} }
# Writes deterministic strict UTF-8 fixtures and LLVM harnesses.
function Write-Text([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,$utf8)}
# Preserves Windows arguments containing whitespace, quotes and trailing slashes.
function Quote-Argument([string]$Value){
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
# Runs a hidden bounded child and retains stdout, stderr and its exact exit code.
function Run([string]$File,[string[]]$Arguments){
 $script:processNumber++
 $prefix=Join-Path $artifacts ('process-'+$script:processNumber)
 $start=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$start.ArgumentList=(($Arguments|ForEach-Object{Quote-Argument $_}) -join ' ')}
 $p=Start-Process @start
 try {
  $handle=$p.Handle
  if(-not $p.WaitForExit(60000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Timeout: $prefix"}
  $p.Refresh()
  Require ($null -ne $p.ExitCode) "Missing exit code for $handle"
  return [pscustomobject]@{ExitCode=$p.ExitCode;Stdout=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Stderr=[IO.File]::ReadAllText($prefix+'.stderr',$utf8);Evidence=$prefix}
 }finally{$p.Dispose()}
}
# Supplies the common native import-library helper's process adapter.
function Invoke-BoundedProcess([string]$File,[string[]]$Arguments){ Run $File $Arguments }
. (Join-Path $PSScriptRoot '../NativeMemory.ps1')
# Compiles native observation code and asserts the executable's AMD64 PE headers.
function Build([string]$Path,[string]$Exe,[string]$Level){
 $link=@(Get-NativeMemoryLinkArguments $Path $Clang $artifacts)
 $r=Run $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$Level),$Path)+$link+@('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608'))
 Require ($r.ExitCode -eq 0) "Build failed $($r.Evidence)"
 $bytes=[IO.File]::ReadAllBytes($Exe)
 Require ($bytes.Length -ge 64 -and $bytes[0] -eq 77 -and $bytes[1] -eq 90) 'Invalid DOS header'
 $offset=[BitConverter]::ToInt32($bytes,60)
 Require ($offset -ge 64 -and $offset -le $bytes.Length-6) 'Invalid PE offset'
 Require ([BitConverter]::ToUInt32($bytes,$offset) -eq 17744 -and [BitConverter]::ToUInt16($bytes,$offset+4) -eq 34404) 'Not AMD64 PE'
}
$nl=[Environment]::NewLine
Write-Output "Artifacts retained: $artifacts"
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$files=@('std-lib/src/portable/InvariantNumbers.bas','std-lib/src/portable/BinaryFloat.bas','std-lib/src/portable/BinaryFloatValues.bas','std-lib/src/portable/BinaryFloatMath.bas','std-lib/src/portable/BinaryFloatPower.bas','std-lib/src/portable/BinaryFloatText.bas','std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/FileBytes.bas','std-lib/src/portable/ByteText.bas','std-lib/src/portable/Utf8.bas','std-lib/src/portable/PathPrimitives.bas','std-lib/src/portable/DirectoryPrimitives.bas','std-lib/src/portable/SystemPrimitives.bas','std-lib/src/win-lib/WindowsPaths.bas','compiler/src/SourceScanner.bas','compiler/src/SyntaxTokens.bas','compiler/src/SourceParser.bas','compiler/src/ConditionalExpressions.bas','compiler/src/ConditionalSource.bas','compiler/src/ConstantValues.bas','compiler/src/ConstantText.bas','compiler/src/ProjectSyntax.bas','compiler/src/ProjectManifest.bas','compiler/src/ProjectLoader.bas','std-lib/src/portable/ThreadPrimitives.bas','std-lib/src/portable/LeasePrimitives.bas','compiler/src/ManagedSourceAssets.bas','compiler/src/OutputPublication.bas','bootstrap/tests/output-publication/LeaseProbe.bas')
$lines=@('UBE-Project 1','Name = "PublicationTests"','Kind = "Library"')
foreach($file in $files){
 $leaf=[IO.Path]::GetFileName($file)
 Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $artifacts $leaf)
 $lines+='Source = "'+$leaf+'"'
}
$manifest=Join-Path $artifacts 'project.UBE'
Write-Text $manifest (($lines -join $nl)+$nl)
$bound=Run $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Binding failed $($bound.Evidence)"
$symbols=@{}
foreach($line in ($bound.Stdout -split '\r?\n')){
 if($line -match '^SYMBOL (\d+)\|function\|([^|]+)\|'){$symbols[$Matches[2]]=$Matches[1]}
}
$ir=Join-Path $artifacts 'production.ll'
$r=Run $BootstrapExe @('--emit-llvm',$manifest,$ir)
Require ($r.ExitCode -eq 0) "Emission failed $($r.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
# Supplies independent native byte descriptors.
function Descriptor([string]$Name,[byte[]]$Bytes){
 $cells=($Bytes|ForEach-Object{'i64 '+$_}) -join ', '
 return "@$Name.data = global [$($Bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Bytes.Length-1),ptr @$Name.data,ptr null}"+$nl
}
$cases=@()
$first=Join-Path $artifacts 'existing.bin'; Write-Text $first 'sentinel'
$other=Join-Path $artifacts 'other.bin'; Write-Text $other 'independent'
$hard=Join-Path $artifacts 'hard.bin'; $null=New-Item -ItemType HardLink -Path $hard -Target $first
$folder=Join-Path $artifacts 'physical'; $null=New-Item -ItemType Directory $folder
$link=Join-Path $artifacts 'linked'; $null=New-Item -ItemType Junction -Path $link -Target $folder
$cases+=,@($first,$first,$true)
$cases+=,@($first,$first.ToUpperInvariant(),$true)
$cases+=,@($first,$hard,$true)
$cases+=,@($first,$other,$false)
$cases+=,@((Join-Path $artifacts 'absent.bin'),(Join-Path $artifacts 'ABSENT.bin'),$true)
$cases+=,@((Join-Path $folder 'absent.bin'),(Join-Path $link 'absent.bin'),$true)
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
for($i=0;$i -lt $cases.Count;$i++){
 $c=$cases[$i]
 $globals+=Descriptor "first$i" ($utf8.GetBytes($c[0]))
 $globals+=Descriptor "second$i" ($utf8.GetBytes($c[1]))
 $overlap=0;if($c[2]){$overlap=-1}
 $code+=@("case$($i):","%p$i=call {i1,i64} @ube.proc.$($symbols['CheckPair'])(ptr @test.context,ptr @first$i,ptr @second$i,i64 $overlap)","%f$i=extractvalue {i1,i64} %p$i,0","%v$i=extractvalue {i1,i64} %p$i,1","%z$i=icmp eq i64 %v$i,0","%g$i=and i1 %f$i,%z$i","br i1 %g$i,label %case$($i+1),label %failed$i","failed$($i):","%error$i=trunc i64 %v$i to i32","%base$i=add i32 %error$i,$(($i+1)*100)","ret i32 %base$i")
}
$code+=@("case$($cases.Count):",'%disposed=call i1 @ube.context.dispose(ptr @test.context)','%exit=select i1 %disposed,i32 0,i32 9999','ret i32 %exit','failed:','ret i32 9998','}')
$path=Join-Path $artifacts 'leases.ll'
Write-Text $path ($production+$nl+$globals+($code -join $nl))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("leases-$level.exe"); Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Reservation assertions failed $level exit $($r.ExitCode) $($r.Evidence)"
 Require ([IO.File]::ReadAllText($first) -ceq 'sentinel') 'Existing target changed'
 Require ([IO.File]::ReadAllText($other) -ceq 'independent') 'Independent target changed'
 Write-Output "PASS $level : six physical target/case/hardlink/junction/independent reservations, cleanup/reacquisition and prior-byte preservation"
}

# A real second process must refuse a live hardlink owner and recover after OS process teardown.
$holdBody=@'
@test.ready = private constant [1 x i8] c"R"
define i32 @main() {
entry:
 call void @ube.context.init(ptr @test.context)
 %init=call i1 @ube.project.init(ptr @test.context)
 %name=alloca i64
 %file=alloca i64
 %written=alloca i32
 store i64 0,ptr %name
 store i64 0,ptr %file
 %p=call {i1,i64} @ube.proc.HOLD(ptr @test.context,ptr @TARGET,ptr %name,ptr %file)
 %worked=extractvalue {i1,i64} %p,0
 %value=extractvalue {i1,i64} %p,1
 %zero=icmp eq i64 %value,0
 %good=and i1 %worked,%zero
 br i1 %good,label %ready,label %failed
ready:
 %stdout=call ptr @GetStdHandle(i32 -11)
 %w=call i32 @WriteFile(ptr %stdout,ptr @test.ready,i32 1,ptr %written,ptr null)
 call void @Sleep(i32 DELAY)
 ret i32 0
failed:
 %code=trunc i64 %value to i32
 ret i32 %code
}
'@
$holdBody=$holdBody.Replace('@ube.proc.HOLD',('@ube.proc.'+$symbols['Hold']))
foreach($item in @(@('holder','first0','30000'),@('contender','second2','0'))){
 $path=Join-Path $artifacts ($item[0]+'.ll')
 Write-Text $path ($production+$nl+$globals+$holdBody.Replace('@TARGET',('@'+$item[1])).Replace('i32 DELAY',('i32 '+$item[2])))
 Build $path (Join-Path $artifacts ($item[0]+'.exe')) 'O0'
}
$ready=Join-Path $artifacts 'holder.stdout'
$holder=Start-Process -FilePath (Join-Path $artifacts 'holder.exe') -WindowStyle Hidden -PassThru -RedirectStandardOutput $ready -RedirectStandardError (Join-Path $artifacts 'holder.stderr')
try{
 $null=$holder.Handle
 $timer=[Diagnostics.Stopwatch]::StartNew()
 do{
  Start-Sleep -Milliseconds 20
  $holder.Refresh()
  Require (-not $holder.HasExited) 'Holder exited before readiness'
  $stream=[IO.File]::Open($ready,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
  try{$reader=New-Object IO.StreamReader($stream);$observed=$reader.ReadToEnd()}finally{$stream.Dispose()}
 }while($observed -ne 'R' -and $timer.ElapsedMilliseconds -lt 5000)
 Require ($observed -ceq 'R') 'Holder readiness deadline'
 $r=Run (Join-Path $artifacts 'contender.exe') @()
 Require ($r.ExitCode -eq 19) "Cross-process hardlink overlap accepted: $($r.ExitCode)"
 foreach($compiler in @($BootstrapExe,$CompilerExe)){
  if($compiler.Length -eq 0){continue}
  $r=Run $compiler @('--emit-llvm',(Join-Path $artifacts 'missing.UBE'),$hard)
  Require ($r.ExitCode -eq 1 -and $r.Stderr.Contains('E_OUTPUT')) "Compiler failed to refuse mixed-process conflict before loading: $compiler $($r.Evidence)"
 }
 $holder.Kill(); Require ($holder.WaitForExit(5000)) 'Holder teardown deadline'
 $r=Run (Join-Path $artifacts 'contender.exe') @()
 Require ($r.ExitCode -eq 0 -and $r.Stdout -ceq 'R') 'Process-exit release did not restore admission'
 Require ([IO.File]::ReadAllText($first) -ceq 'sentinel') 'Cross-process refusal changed output'
 Write-Output 'PASS cross-process and compiler admission hardlink conflict, forced owner teardown, automatic release and unchanged output'
}finally{
 if(-not $holder.HasExited){$holder.Kill();$null=$holder.WaitForExit(5000)}
 $holder.Dispose()
}

# Inject one OS close refusal without changing the lease algorithm or resource registry.
$closing=$production.Replace('define i1 @ube.target.file.close(', 'define i1 @test.real.close(')
Require ($closing -cne $production) 'Missing close boundary'
$closeProbe=@'
@test.close.failure = global i1 false
@test.invalid.bytes = global [1 x i64] [i64 255]
@test.invalid = global {i64,i64,ptr,ptr} {i64 0,i64 0,ptr @test.invalid.bytes,ptr null}
define i1 @ube.target.file.close(ptr %handle) {
 %fail=load i1,ptr @test.close.failure
 store i1 false,ptr @test.close.failure
 br i1 %fail,label %refuse,label %native
refuse:
 ret i1 false
native:
 %result=call i1 @test.real.close(ptr %handle)
 ret i1 %result
}
define i32 @main() {
entry:
 call void @ube.context.init(ptr @test.context)
 %token=alloca i64
 %failure=alloca i64
 store i64 0,ptr %token
 store i64 0,ptr %failure
 %bad=call i1 @ube.lease.acquire(ptr @test.context,ptr @test.invalid,ptr %token,ptr %failure)
 %badcode=load i64,ptr %failure
 %badtoken=load i64,ptr %token
 %invalid=icmp eq i64 %badcode,1
 %empty=icmp eq i64 %badtoken,0
 %refused=xor i1 %bad,true
 %a=and i1 %invalid,%empty
 %b=and i1 %a,%refused
 br i1 %b,label %acquire,label %failed
acquire:
 %accepted=call i1 @ube.lease.acquire(ptr @test.context,ptr @first0,ptr %token,ptr %failure)
 br i1 %accepted,label %wrongkind,label %failed
wrongkind:
 %wrong=call i1 @ube.file.close(ptr @test.context,ptr %token,ptr %failure)
 %wrongcode=load i64,ptr %failure
 %still=load i64,ptr %token
 %kind=icmp eq i64 %wrongcode,9
 %retained=icmp ne i64 %still,0
 %wrongrefused=xor i1 %wrong,true
 %c=and i1 %kind,%retained
 %d=and i1 %c,%wrongrefused
 br i1 %d,label %inject,label %failed
inject:
 store i1 true,ptr @test.close.failure
 store i64 73,ptr %failure
 %first=call {i1,i64} @ube.proc.RELEASE(ptr @test.context,ptr %token,ptr %failure)
 %firstok=extractvalue {i1,i64} %first,0
 %firstvalue=extractvalue {i1,i64} %first,1
 %firstfalse=icmp eq i64 %firstvalue,0
 %firsttoken=load i64,ptr %token
 %firstfailure=load i64,ptr %failure
 %same=icmp eq i64 %firsttoken,%still
 %primary=icmp eq i64 %firstfailure,73
 %e=and i1 %firstok,%firstfalse
 %f=and i1 %same,%primary
 %g=and i1 %e,%f
 br i1 %g,label %retry,label %failed
retry:
 %second=call {i1,i64} @ube.proc.RELEASE(ptr @test.context,ptr %token,ptr %failure)
 %secondok=extractvalue {i1,i64} %second,0
 %secondvalue=extractvalue {i1,i64} %second,1
 %secondtrue=icmp eq i64 %secondvalue,-1
 %lasttoken=load i64,ptr %token
 %lastfailure=load i64,ptr %failure
 %cleared=icmp eq i64 %lasttoken,0
 %preserved=icmp eq i64 %lastfailure,73
 %h=and i1 %secondok,%secondtrue
 %i=and i1 %cleared,%preserved
 %j=and i1 %h,%i
 %disposed=call i1 @ube.context.dispose(ptr @test.context)
 %good=and i1 %j,%disposed
 %exit=select i1 %good,i32 0,i32 98
 ret i32 %exit
failed:
 ret i32 99
}
'@
$path=Join-Path $artifacts 'close.ll'
# Keep the observation driver outside optimization; production callees still receive the selected level.
# Folding several independent runtime boundaries into this synthetic main creates an artificial oversized frame.
$closeProbe=$closeProbe.Replace('define i32 @main() {','define i32 @main() noinline optnone {')
Write-Text $path ($closing+$nl+$globals+$closeProbe.Replace('@ube.proc.RELEASE',('@ube.proc.'+$symbols['TryRelease'])))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("close-$level.exe");Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Lease close/invalid-input assertions failed $level $($r.Evidence)"
 Write-Output "PASS $level : invalid UTF-8 rejection, file/lease token separation, close refusal retains exact owner, retry releases and preserves primary failure"
}

# Replacement changes inode identity; old and new aliases must both remain refused until cleanup.
$stage=Join-Path $artifacts 'stage';$null=New-Item -ItemType Directory $stage
Write-Text (Join-Path $stage 'input.ll') 'published candidate'
$newAlias=Join-Path $artifacts 'published-alias.bin'
$publicationGlobals=$globals+(Descriptor 'stage' ($utf8.GetBytes($stage)))+(Descriptor 'newalias' ($utf8.GetBytes($newAlias)))
$publication=$holdBody.Replace('@TARGET','@first0').Replace('i32 DELAY','i32 30000')
$publication=$publication.Replace('%written=alloca i32','%candidate=alloca i64'+$nl+' store i64 0,ptr %candidate'+$nl+' %written=alloca i32')
$publication=$publication.Replace(('@ube.proc.'+$symbols['Hold']+'(ptr @test.context,ptr @first0,ptr %name,ptr %file)'),('@ube.proc.'+$symbols['PublishHold']+'(ptr @test.context,ptr @first0,ptr @stage,ptr %name,ptr %file,ptr %candidate)'))
$path=Join-Path $artifacts 'publisher.ll';Write-Text $path ($production+$nl+$publicationGlobals+$publication)
Build $path (Join-Path $artifacts 'publisher.exe') 'O0'
$path=Join-Path $artifacts 'newalias.ll';Write-Text $path ($production+$nl+$publicationGlobals+$holdBody.Replace('@TARGET','@newalias').Replace('i32 DELAY','i32 0'))
Build $path (Join-Path $artifacts 'newalias.exe') 'O0'
$ready=Join-Path $artifacts 'publisher.stdout'
$publisher=Start-Process -FilePath (Join-Path $artifacts 'publisher.exe') -WindowStyle Hidden -PassThru -RedirectStandardOutput $ready -RedirectStandardError (Join-Path $artifacts 'publisher.stderr')
try{
 $null=$publisher.Handle;$timer=[Diagnostics.Stopwatch]::StartNew()
 do{
  Start-Sleep -Milliseconds 20;$publisher.Refresh()
  Require (-not $publisher.HasExited) 'Publisher exited before retained-owner observation'
  $stream=[IO.File]::Open($ready,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
  try{$reader=New-Object IO.StreamReader($stream);$observed=$reader.ReadToEnd()}finally{$stream.Dispose()}
 }while($observed -ne 'R' -and $timer.ElapsedMilliseconds -lt 5000)
 Require ($observed -ceq 'R') 'Publisher readiness deadline'
 Require ([IO.File]::ReadAllText($first) -ceq 'published candidate') 'Atomic publication bytes differ'
 Require ([IO.File]::ReadAllText($hard) -ceq 'sentinel') 'Old inode changed during replacement'
 $null=New-Item -ItemType HardLink -Path $newAlias -Target $first
 $r=Run (Join-Path $artifacts 'contender.exe') @();Require ($r.ExitCode -eq 19) 'Old inode lease lost after replacement'
 $r=Run (Join-Path $artifacts 'newalias.exe') @();Require ($r.ExitCode -eq 19) 'Published inode lease absent after replacement'
 $publisher.Kill();Require ($publisher.WaitForExit(5000)) 'Publisher teardown deadline'
 $r=Run (Join-Path $artifacts 'newalias.exe') @();Require ($r.ExitCode -eq 0) 'Published inode lease not released after exit'
 Write-Output 'PASS real replacement rejects changed snapshot and retains old/new hardlink identities until owner teardown'
}finally{
 if(-not $publisher.HasExited){$publisher.Kill();$null=$publisher.WaitForExit(5000)}
 $publisher.Dispose()
}
