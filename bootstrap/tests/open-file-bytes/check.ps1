# Executes the already-open UBE byte reader with independent runtime byte vectors.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube open file ' + [guid]::NewGuid())
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
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/FileBytes.bas','bootstrap/tests/open-file-bytes/OpenFileProbe.bas')
$lines=@('UBE-Project 1','Name = "OpenFileTests"','Kind = "Library"')
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
# Builds independent counted runtime storage using the private acceptance ABI.
function Descriptor([string]$Name,[byte[]]$Bytes){
 $cells=($Bytes|ForEach-Object{'i64 '+$_}) -join ', '
 return "@$Name.data = global [$($Bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Bytes.Length-1),ptr @$Name.data,ptr null}"+$nl
}
foreach($name in @('allocate','release','file.open','file.size','file.read','file.write','file.flush','file.close')){
 $pattern='(?m)^(define[^\r\n@]*?)@ube\.target\.'+[regex]::Escape($name)+'\('
 Require ([regex]::Matches($production,$pattern).Count -eq 1) "Missing $name wrapper"
 $production=[regex]::Replace($production,$pattern,('$'+'{1}@test.real.'+$name+'('))
}
$observer=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/FileObserver.ll'),$utf8)
$allocator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
$payload=[byte[]](0..9)
$inputPath=Join-Path $artifacts 'input bytes.bin'
[IO.File]::WriteAllBytes($inputPath,$payload)
$emptyPath=Join-Path $artifacts 'empty.bin'
[IO.File]::WriteAllBytes($emptyPath,[byte[]]@())
$cases=@(
 @{Name='exact';Mode=0;Delta=0;Failure=0;Reads=2;Bytes=10;Allocs=3;Path=$inputPath;Expected=$payload},
 @{Name='short progress';Mode=2;Delta=0;Failure=0;Reads=6;Bytes=10;Allocs=3;Path=$inputPath;Expected=$payload},
 @{Name='zero progress';Mode=3;Delta=0;Failure=6;Reads=1;Bytes=0;Allocs=2;Path=$inputPath;Expected=$payload},
 @{Name='failed read';Mode=1;Delta=0;Failure=5;Reads=1;Bytes=2;Allocs=2;Path=$inputPath;Expected=$payload},
 @{Name='premature EOF';Mode=0;Delta=1;Failure=6;Reads=2;Bytes=10;Allocs=2;Path=$inputPath;Expected=$payload},
 @{Name='growth probe';Mode=0;Delta=-1;Failure=11;Reads=2;Bytes=10;Allocs=2;Path=$inputPath;Expected=$payload},
 @{Name='empty';Mode=0;Delta=0;Failure=0;Reads=1;Bytes=0;Allocs=1;Path=$emptyPath;Expected=[byte[]]@()},
 @{Name='negative length';Mode=0;Delta=-11;Failure=1;Reads=0;Bytes=0;Allocs=1;Path=$inputPath;Expected=$payload},
 @{Name='excessive length';Mode=0;Delta=1048567;Failure=1;Reads=0;Bytes=0;Allocs=1;Path=$inputPath;Expected=$payload}
)
$i=0
foreach($c in $cases){
 $globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
 $globals+=Descriptor 'path' ($utf8.GetBytes($c.Path))
 $globals+=Descriptor 'expected' $c.Expected
 $code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)',"store i32 $($c.Mode),ptr @test.read.mode","%p=call {i1,i64} @ube.proc.$($symbols['CheckRead'])(ptr @test.context,ptr @path,ptr @expected,i64 $($c.Delta),i64 $($c.Failure))",'%fresh=extractvalue {i1,i64} %p,0','%value=extractvalue {i1,i64} %p,1','%zero=icmp eq i64 %value,0','%read.calls=load i64,ptr @test.read.calls',"%reads=icmp eq i64 %read.calls,$($c.Reads)",'%read.bytes=load i64,ptr @test.read.bytes',"%bytes=icmp eq i64 %read.bytes,$($c.Bytes)",'%alloc.calls=load i64,ptr @test.alloc.calls',"%allocs=icmp eq i64 %alloc.calls,$($c.Allocs)",'%disposed=call i1 @ube.context.dispose(ptr @test.context)','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%handles=load i64,ptr @test.handles','%closed=icmp eq i64 %handles,0','%a=and i1 %init,%fresh','%b=and i1 %zero,%reads','%c=and i1 %bytes,%allocs','%d=and i1 %disposed,%clean','%e=and i1 %a,%b','%f=and i1 %c,%d','%g=and i1 %e,%f','%good=and i1 %g,%closed','%exit=select i1 %good,i32 0,i32 99','ret i32 %exit','}')
 $path=Join-Path $artifacts ("case-$i.ll")
 Write-Text $path ($production+$nl+$observer+$nl+$allocator+$nl+$globals+($code -join $nl))
 foreach($level in @('O0','O2')){
  $exe=Join-Path $artifacts ("case-$i-$level.exe")
  Build $path $exe $level
  $r=Run $exe @()
  Require ($r.ExitCode -eq 0) "Case $($c.Name) failed $level $($r.Evidence)"
  Write-Output "PASS $($c.Name) $level : exact progress, allocation, bytes and retained owner"
 }
 $i++
}
# Fails each reader allocation and retry; same-context recovery reopens at offset zero.
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$globals+=Descriptor 'path' ($utf8.GetBytes($inputPath))
$globals+=Descriptor 'expected' $payload
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)')
foreach($site in 2..3){
 $code+=@('store i64 0,ptr @test.alloc.calls',"store i64 $site,ptr @test.fail.after",'store i64 2,ptr @test.fail.remaining',"%p$site=call {i1,i64} @ube.proc.$($symbols['CheckRead'])(ptr @test.context,ptr @path,ptr @expected,i64 0,i64 8)","%f$site=extractvalue {i1,i64} %p$site,0","%v$site=extractvalue {i1,i64} %p$site,1","%z$site=icmp eq i64 %v$site,0","%g$site=and i1 %f$site,%z$site","%calls$site=load i64,ptr @test.alloc.calls","%exact$site=icmp eq i64 %calls$site,$($site+1)","%remaining$site=load i64,ptr @test.fail.remaining","%used$site=icmp eq i64 %remaining$site,0","%live$site=load i64,ptr @test.live","%clean$site=icmp eq i64 %live$site,0","%handles$site=load i64,ptr @test.handles","%closed$site=icmp eq i64 %handles$site,0","%a$site=and i1 %g$site,%exact$site","%b$site=and i1 %used$site,%clean$site","%c$site=and i1 %a$site,%b$site","%ok$site=and i1 %c$site,%closed$site",'%reset=add i64 0,0')
 $code=$code|Where-Object{$_ -ne '%reset=add i64 0,0'}
 $code+=@("%r$site=call {i1,i64} @ube.proc.$($symbols['CheckRead'])(ptr @test.context,ptr @path,ptr @expected,i64 0,i64 0)","%rf$site=extractvalue {i1,i64} %r$site,0","%rv$site=extractvalue {i1,i64} %r$site,1","%rz$site=icmp eq i64 %rv$site,0","%rg$site=and i1 %rf$site,%rz$site","%recovery$site=and i1 %ok$site,%rg$site")
 if($site -eq 2){$code+="%all$site=and i1 %init,%recovery$site"}else{$code+="%all$site=and i1 %all$($site-1),%recovery$site"}
}
$code+=@('%disposed=call i1 @ube.context.dispose(ptr @test.context)','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%a=and i1 %all3,%disposed','%good=and i1 %a,%clean','%exit=select i1 %good,i32 0,i32 99','ret i32 %exit','}')
$path=Join-Path $artifacts 'faults.ll'
Write-Text $path ($production+$nl+$observer+$nl+$allocator+$nl+$globals+($code -join $nl))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("faults-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Allocation assertions failed $level $($r.Evidence)"
 Write-Output "PASS $level : both reader allocation sites, failed retries, exact counts, recovery and balanced owners"
}
# Changed bytes must fail the independent expected-output comparison.
$badGlobals=$globals.Replace('@expected.data = global [10 x i64] [i64 0,','@expected.data = global [10 x i64] [i64 99,')
Require ($badGlobals -cne $globals) 'Missing negative-control replacement'
$path=Join-Path $artifacts 'negative.ll'
Write-Text $path ($production+$nl+$observer+$nl+$allocator+$nl+$badGlobals+($code -join $nl))
$exe=Join-Path $artifacts 'negative.exe'
Build $path $exe 'O2'
$r=Run $exe @()
Require ($r.ExitCode -eq 99) 'Changed expected byte must fail exact recovery oracle'
Write-Output 'PASS changed-byte negative control'

