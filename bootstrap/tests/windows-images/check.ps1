# Executes Windows image framing checks against synthetic bytes and controlled file failures.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube windows images ' + [guid]::NewGuid())
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
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/win-lib/WindowsImages.bas','bootstrap/tests/windows-images/ImageProbe.bas')
$lines=@('UBE-Project 1','Name = "ImageTests"','Kind = "Library"')
foreach($file in $files){
 $leaf=[IO.Path]::GetFileName($file)
 Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $artifacts $leaf)
 $lines+='Source = "'+$leaf+'"'
}
$manifest=Join-Path $artifacts 'project.UBE'
Write-Text $manifest (($lines -join $nl)+$nl)
$bound=Run $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Binding failed $($bound.Evidence)"
$symbol=''
foreach($line in ($bound.Stdout -split '\r?\n')){
 if($line -match '^SYMBOL (\d+)\|function\|Check\|'){$symbol=$Matches[1]}
}
Require ($symbol -ne '') 'Missing image probe'
$ir=Join-Path $artifacts 'production.ll'
$r=Run $BootstrapExe @('--emit-llvm',$manifest,$ir)
Require ($r.ExitCode -eq 0) "Emission failed $($r.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
foreach($name in @('allocate','release','file.open','file.size','file.read','file.write','file.flush','file.close')){
 $pattern='(?m)^(define[^\r\n@]*?)@ube\.target\.'+[regex]::Escape($name)+'\('
 Require ([regex]::Matches($production,$pattern).Count -eq 1) "Missing $name wrapper"
 $production=[regex]::Replace($production,$pattern,('$'+'{1}@test.real.'+$name+'('))
}
$observer=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/FileObserver.ll'),$utf8)
$allocator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
# Builds DOS and PE framing directly, independent of the UBE implementation.
function Image-Bytes([int]$Offset){
 $data=New-Object byte[] ($Offset+26)
 $data[0]=77;$data[1]=90
 [BitConverter]::GetBytes($Offset).CopyTo($data,60)
 $data[$Offset]=80;$data[$Offset+1]=69
 $data[$Offset+4]=100;$data[$Offset+5]=134
 $data[$Offset+22]=2;$data[$Offset+24]=11;$data[$Offset+25]=2
 return ,$data
}
$cases=New-Object Collections.Generic.List[object]
$base=Image-Bytes 64
$cases.Add(@{Name='minimal';Bytes=$base;Expected=-1;Failure=0})
$cases.Add(@{Name='large header gap';Bytes=(Image-Bytes 131100);Expected=-1;Failure=0})
$cases.Add(@{Name='maximum too small';Bytes=$base;Expected=0;Failure=1;Maximum=89})
$cases.Add(@{Name='file exceeds maximum';Bytes=(Image-Bytes 65);Expected=0;Failure=4;Maximum=90})
$realIR=Join-Path $artifacts 'real.ll'
$realExe=Join-Path $artifacts 'real.exe'
Write-Text $realIR 'define i32 @main() { ret i32 42 }'
Build $realIR $realExe 'O0'
$cases.Add(@{Name='actual LLVM executable';Bytes=([IO.File]::ReadAllBytes($realExe));Expected=-1;Failure=0})
foreach($entry in @(@('DOS',0,0),@('PE signature',64,0),@('machine',68,0),@('optional magic',88,0),@('not executable',86,0),@('DLL',87,32))){
 $data=[byte[]]$base.Clone();$data[$entry[1]]=$entry[2]
 $cases.Add(@{Name=$entry[0];Bytes=$data;Expected=0;Failure=16})
}
foreach($offset in @([uint32]0,[uint32]63,[uint32]65,[uint32]4294967295)){
 $data=[byte[]]$base.Clone();[BitConverter]::GetBytes($offset).CopyTo($data,60)
 $cases.Add(@{Name="offset $offset";Bytes=$data;Expected=0;Failure=16})
}
$cases.Add(@{Name='truncated';Bytes=([byte[]]$base[0..88]);Expected=0;Failure=16})
$cases.Add(@{Name='short progress';Bytes=$base;Expected=-1;Failure=0;ReadMode=2})
$cases.Add(@{Name='zero progress';Bytes=$base;Expected=0;Failure=6;ReadMode=3})
$cases.Add(@{Name='read failure';Bytes=$base;Expected=0;Failure=5;ReadMode=1})
$cases.Add(@{Name='close failure';Bytes=$base;Expected=0;Failure=7;Close=1})
$cases.Add(@{Name='invalid and failed close';Bytes=([byte[]]$base[0..88]);Expected=0;Failure=16;Close=1})
foreach($allocation in 1..2){$cases.Add(@{Name="allocation $allocation";Bytes=$base;Expected=0;Failure=8;FailAt=$allocation})}
$cases.Add(@{Name='recovery';Bytes=$base;Expected=-1;Failure=0})
# Executes every case in one context; native cleanup and the following success prove recovery.
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
for($i=0;$i -lt $cases.Count;$i++){
 $case=$cases[$i];$path=Join-Path $artifacts ("image-$i.bin")
 [IO.File]::WriteAllBytes($path,$case.Bytes)
 $bytes=$utf8.GetBytes($path);$cells=($bytes|ForEach-Object{'i64 '+$_}) -join ', '
 $globals+="@path$i.data = global [$($bytes.Length) x i64] [$cells]"+$nl+"@path$i = global {i64,i64,ptr,ptr} {i64 0,i64 $($bytes.Length-1),ptr @path$i.data,ptr null}"+$nl
 $mode=0;if($case.ContainsKey('ReadMode')){$mode=$case.ReadMode}
 $close=0;if($case.ContainsKey('Close')){$close=$case.Close}
 $fail=0;if($case.ContainsKey('FailAt')){$fail=$case.FailAt}
 $expectedFailure=$case.Failure
 $maximum=67108864;if($case.ContainsKey('Maximum')){$maximum=$case.Maximum}
 # Acquisition retains transfer scratch at allocation1; the image buffer is2.
 $closeFlag=0;if($close){$closeFlag=-1}
 $failCount=0;if($fail){$failCount=2}
 $code+=@("case${i}:","store i32 $mode,ptr @test.read.mode","store i32 $close,ptr @test.close.failures",'store i64 0,ptr @test.alloc.calls',"store i64 $fail,ptr @test.fail.after","store i64 $failCount,ptr @test.fail.remaining","%pair$i = call {i1,i64} @ube.proc.$symbol(ptr @test.context,ptr @path$i,i64 $maximum,i64 $($case.Expected),i64 $expectedFailure,i64 $closeFlag)","%fresh$i = extractvalue {i1,i64} %pair$i,0","%result$i = extractvalue {i1,i64} %pair$i,1","%zero$i = icmp eq i64 %result$i,0","%ok$i = and i1 %fresh$i,%zero$i","br i1 %ok$i,label %case$($i+1),label %bad$i","bad${i}:","ret i32 $($i+1)")
}
$code+=@("case$($cases.Count):",'%disposed = call i1 @ube.context.dispose(ptr @test.context)','%live = load i64,ptr @test.live','%handles = load i64,ptr @test.handles','%clean = icmp eq i64 %live,0','%closed = icmp eq i64 %handles,0','%owners = and i1 %clean,%closed','%all = and i1 %owners,%disposed','%exit = select i1 %all,i32 0,i32 99','ret i32 %exit','failed:','ret i32 100','}')
$harness=Join-Path $artifacts 'images.ll'
$code=@($code | ForEach-Object {
 if($_ -eq '%ok0 = and i1 %fresh0,%zero0'){
  '%value.ok0 = and i1 %fresh0,%zero0'
  '%observed.allocations = load i64,ptr @test.alloc.calls'
  '%allocation.count.ok = icmp eq i64 %observed.allocations,2'
  '%ok0 = and i1 %value.ok0,%allocation.count.ok'
 }else{$_}
})
Write-Text $harness ($production+$nl+$observer+$nl+$allocator+$nl+$globals+($code -join $nl))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("images-$level.exe")
 Build $harness $exe $level
 $run=Run $exe @()
 Require ($run.ExitCode -eq 0) "Image assertions failed $level exit $($run.ExitCode) $($run.Evidence)"
 Write-Output "PASS $level : $($cases.Count) image and failure cases, zero owners"
}
$changed=[byte[]]$base.Clone();$changed[0]=0
[IO.File]::WriteAllBytes((Join-Path $artifacts 'image-0.bin'),$changed)
$negative=Run (Join-Path $artifacts 'images-O2.exe') @()
Require ($negative.ExitCode -eq 1) 'Changed input must reject the exact first image assertion'
Write-Output 'PASS changed-input image control: exact exit 1'
Write-Output "PASS Windows image framing. Evidence: $artifacts"
