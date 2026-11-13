# Executes the native tool argument builder with independent runtime byte vectors.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube native arguments ' + [guid]::NewGuid())
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
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/FileBytes.bas','std-lib/src/portable/ByteText.bas','std-lib/src/portable/Utf8.bas','std-lib/src/portable/PathPrimitives.bas','std-lib/src/portable/DirectoryPrimitives.bas','std-lib/src/portable/SystemPrimitives.bas','std-lib/src/win-lib/WindowsPaths.bas','std-lib/src/win-lib/WindowsArguments.bas','compiler/src/SourceScanner.bas','compiler/src/SyntaxTokens.bas','compiler/src/SourceParser.bas','compiler/src/ProjectSyntax.bas','compiler/src/ProjectManifest.bas','compiler/src/ProjectLoader.bas','compiler/src/OutputPublication.bas','compiler/src/NativeToolArguments.bas','bootstrap/tests/native-tool-arguments/ToolArgumentProbe.bas')
$lines=@('UBE-Project 1','Name = "ToolArgumentTests"','Kind = "Library"')
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
# Provides static input descriptors independent of construction/allocation code.
function Descriptor([string]$Name,[byte[]]$Bytes){
 $cells=($Bytes|ForEach-Object{'i64 '+$_}) -join ', '
 return "@$Name.data = global [$($Bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Bytes.Length-1),ptr @$Name.data,ptr null}"+$nl
}
foreach($name in @('allocate','release')){
 $pattern='(?m)^(define[^\r\n@]*?)@ube\.target\.'+$name+'\('
 Require ([regex]::Matches($production,$pattern).Count -eq 1) "Missing $name wrapper"
 $production=[regex]::Replace($production,$pattern,('$'+'{1}@test.real.'+$name+'('))
}
$allocator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
# Specifies the intended argv independently of production numeric byte tables.
function ExpectedArguments([string]$Application,[string]$Stage,[int]$Optimization,[bool]$Import){
 if($Import){return @($Application,'-m','i386:x86-64','-d',($Stage+'\kernel32-memory.def'),'-l',($Stage+'\kernel32-memory.lib'))}
 $level='-O'+$Optimization
 if($Optimization -eq 4){$level='-Os'}
 return @($Application,'--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',$level,'-x','ir',($Stage+'\input.ll'),'-x','none',($Stage+'\kernel32-memory.lib'),'-o',($Stage+'\output.exe'),'-Wl,/entry:main,/subsystem:console,/stack:8388608')
}
$application='C:\LLVM tools\bin\clang.exe'
$stage='C:\private stage & name (1)'
$vectors=New-Object Collections.Generic.List[object]
foreach($optimization in 0..4){$vectors.Add(@{Application=$application;Stage=$stage;Optimization=$optimization;Import=$false;Alias=0})}
$vectors.Add(@{Application='C:\LLVM tools\bin\llvm-dlltool.exe';Stage=$stage;Optimization=0;Import=$true;Alias=0})
foreach($alias in 1..2){
 $vectors.Add(@{Application=$application;Stage=$stage;Optimization=2;Import=$false;Alias=$alias})
 $vectors.Add(@{Application='C:\LLVM tools\bin\llvm-dlltool.exe';Stage=$stage;Optimization=0;Import=$true;Alias=$alias})
}
$vectors.Add(@{Application=('C:\'+[char]0xE6+'\clang.exe');Stage=('C:\'+[char]0x03A9+' stage');Optimization=3;Import=$false;Alias=0})
$vectors.Add(@{Application='\\server\share\LLVM\clang.exe';Stage='\\server\share\private stage';Optimization=1;Import=$false;Alias=0})
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
$outputs=@()
$expectedSets=@()
for($i=0;$i -lt $vectors.Count;$i++){
 $v=$vectors[$i]
 $expected=@(ExpectedArguments $v.Application $v.Stage $v.Optimization $v.Import)
 $command=($expected|ForEach-Object{'"'+$_+'"'}) -join ' '
 $expectedSets+=,@($expected)
 $output=Join-Path $artifacts ("command-$i.bin");$outputs+=$output
 $globals+=Descriptor "app$i" ($utf8.GetBytes($v.Application))
 $globals+=Descriptor "stage$i" ($utf8.GetBytes($v.Stage))
 $globals+=Descriptor "expected$i" ($utf8.GetBytes($command))
 $globals+=Descriptor "output$i" ($utf8.GetBytes($output))
 $importFlag=0;if($v.Import){$importFlag=-1}
 $code+=@("case$($i):","%p$i=call {i1,i64} @ube.proc.$($symbols['WriteCase'])(ptr @test.context,ptr @app$i,ptr @stage$i,i64 $($v.Optimization),i64 $importFlag,ptr @expected$i,ptr @output$i,i64 $($v.Alias))","%f$i=extractvalue {i1,i64} %p$i,0","%v$i=extractvalue {i1,i64} %p$i,1","%z$i=icmp eq i64 %v$i,0","%g$i=and i1 %f$i,%z$i","br i1 %g$i,label %case$($i+1),label %failed$i","failed$($i):","ret i32 $($i+1)")
}
$code+=@("case$($vectors.Count):",'%disposed=call i1 @ube.context.dispose(ptr @test.context)','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%good=and i1 %disposed,%clean','%exit=select i1 %good,i32 0,i32 254','ret i32 %exit','failed:','ret i32 255','}')
$path=Join-Path $artifacts 'commands.ll'
$combined=$production+$nl+$allocator+$nl+$globals+($code -join $nl)
Write-Text $path $combined
# Uses the independent operating-system command-line parser on actual produced bytes.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NativeToolArgumentOracle {
    [DllImport("shell32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr CommandLineToArgvW(string commandLine, out int count);
    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr value);
    public static string[] Parse(string commandLine) {
        int count;
        IntPtr pointer = CommandLineToArgvW(commandLine, out count);
        if(pointer == IntPtr.Zero) throw new InvalidOperationException("CommandLineToArgvW failed");
        try {
            string[] result = new string[count];
            for(int i=0;i<count;i++) result[i]=Marshal.PtrToStringUni(Marshal.ReadIntPtr(pointer,i*IntPtr.Size));
            return result;
        } finally { LocalFree(pointer); }
    }
}
'@
foreach($level in @('O0','O2')){
 foreach($output in $outputs){if(Test-Path -LiteralPath $output){Remove-Item -LiteralPath $output}}
 $exe=Join-Path $artifacts ("commands-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Command assertions failed $level exit $($r.ExitCode) $($r.Evidence)"
 for($i=0;$i -lt $vectors.Count;$i++){
  $actual=[NativeToolArgumentOracle]::Parse([IO.File]::ReadAllText($outputs[$i],$utf8))
  $expected=$expectedSets[$i]
  Require ($actual.Count -eq $expected.Count) "argv count differs $i $level"
  for($j=0;$j -lt $expected.Count;$j++){Require ($actual[$j] -ceq $expected[$j]) "argv differs $i/$j $level"}
 }
 Write-Output "PASS $level : $($vectors.Count) exact commands and independent Windows argv, optimization flags, input/output aliases"
}
$invalid=@(
 @{Application=$application;Stage=$stage;Optimization=-1;Import=$false},
 @{Application=$application;Stage=$stage;Optimization=5;Import=$false},
 @{Application='C:\bad"app.exe';Stage=$stage;Optimization=0;Import=$false},
 @{Application=$application;Stage='C:\bad"stage';Optimization=0;Import=$false},
 @{Application='clang.exe';Stage=$stage;Optimization=0;Import=$false},
 @{Application=$application;Stage='relative';Optimization=0;Import=$true},
 @{Application='';Stage=$stage;Optimization=0;Import=$true},
 @{Application=$application;Stage='';Optimization=0;Import=$false},
 @{Application='C:\';Stage=$stage;Optimization=0;Import=$false},
 @{Application=([byte[]]@(255));Stage=$stage;Optimization=0;Import=$true},
 @{Application=$application;Stage=('C:\'+('a'*4094));Optimization=0;Import=$false}
)
$badGlobals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl+(Descriptor 'empty' ([byte[]]@()))
$bad=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)')
for($i=0;$i -lt $invalid.Count;$i++){
 $v=$invalid[$i];$app=$v.Application;if($app -is [string]){$app=$utf8.GetBytes($app)}
 $badGlobals+=Descriptor "app$i" $app
 $badGlobals+=Descriptor "stage$i" ($utf8.GetBytes($v.Stage))
 $importFlag=0;if($v.Import){$importFlag=-1}
 $bad+=@("%p$i=call {i1,i64} @ube.proc.$($symbols['CheckBuild'])(ptr @test.context,ptr @app$i,ptr @stage$i,i64 $($v.Optimization),i64 $importFlag,ptr @empty,i64 0)","%f$i=extractvalue {i1,i64} %p$i,0","%v$i=extractvalue {i1,i64} %p$i,1","%z$i=icmp eq i64 %v$i,0","%g$i=and i1 %f$i,%z$i")
 if($i -eq 0){$bad+="%all$i=and i1 %init,%g$i"}else{$bad+="%all$i=and i1 %all$($i-1),%g$i"}
}
$bad+=@('%disposed=call i1 @ube.context.dispose(ptr @test.context)','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0',"%a=and i1 %all$($invalid.Count-1),%disposed",'%good=and i1 %a,%clean','%exit=select i1 %good,i32 0,i32 99','ret i32 %exit','}')
$path=Join-Path $artifacts 'invalid.ll'
Write-Text $path ($production+$nl+$allocator+$nl+$badGlobals+($bad -join $nl))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("invalid-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Invalid-input assertions failed $level $($r.Evidence)"
 Write-Output "PASS $level : $($invalid.Count) invalid inputs preserve prior output"
}

# Measures and faults every allocation in both public builders, then checks exact recovery.
foreach($kind in @('clang','import')){
 $import=$kind -eq 'import';$importFlag=0;if($import){$importFlag=-1}
 $app=$application
 if($import){$app='C:\LLVM tools\bin\llvm-dlltool.exe'}
 $argv=@(ExpectedArguments $app $stage 2 $import)
 $expected=($argv|ForEach-Object{'"'+$_+'"'}) -join ' '
 $faultGlobals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
 $faultGlobals+=Descriptor 'app' ($utf8.GetBytes($app))
 $faultGlobals+=Descriptor 'stage' ($utf8.GetBytes($stage))
 $faultGlobals+=Descriptor 'expected' ($utf8.GetBytes($expected))
 $baseline=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)',"%p=call {i1,i64} @ube.proc.$($symbols['CheckBuild'])(ptr @test.context,ptr @app,ptr @stage,i64 2,i64 $importFlag,ptr @expected,i64 -1)",'%f=extractvalue {i1,i64} %p,0','%v=extractvalue {i1,i64} %p,1','%z=icmp eq i64 %v,0','%calls=load i64,ptr @test.alloc.calls','%disposed=call i1 @ube.context.dispose(ptr @test.context)','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%a=and i1 %init,%f','%b=and i1 %z,%disposed','%c=and i1 %a,%b','%good=and i1 %c,%clean','%count=trunc i64 %calls to i32','%exit=select i1 %good,i32 %count,i32 -1','ret i32 %exit','}')
 $path=Join-Path $artifacts ("baseline-$kind.ll")
 Write-Text $path ($production+$nl+$allocator+$nl+$faultGlobals+($baseline -join $nl))
 $sites=0
 foreach($level in @('O0','O2')){
  $exe=Join-Path $artifacts ("baseline-$kind-$level.exe")
  Build $path $exe $level
  $r=Run $exe @()
  Require ($r.ExitCode -gt 0 -and $r.ExitCode -lt 4096) "Invalid allocation baseline $kind $level $($r.Evidence)"
  if($sites -eq 0){$sites=$r.ExitCode}else{Require ($sites -eq $r.ExitCode) 'Allocation count differs across levels'}
 }
 $faults=@(
  'define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %loop,label %failed',
  'loop:','%site=phi i64 [1,%entry],[%next,%advance]','store i64 0,ptr @test.alloc.calls','store i64 %site,ptr @test.fail.after','store i64 2,ptr @test.fail.remaining',
  "%p=call {i1,i64} @ube.proc.$($symbols['CheckBuild'])(ptr @test.context,ptr @app,ptr @stage,i64 2,i64 $importFlag,ptr @expected,i64 0)",
  '%f=extractvalue {i1,i64} %p,0','%v=extractvalue {i1,i64} %p,1','%z=icmp eq i64 %v,0','%calls=load i64,ptr @test.alloc.calls','%expected.calls=add i64 %site,1','%exact=icmp eq i64 %calls,%expected.calls','%remaining=load i64,ptr @test.fail.remaining','%used=icmp eq i64 %remaining,0','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%a=and i1 %f,%z','%b=and i1 %exact,%used','%c=and i1 %a,%b','%good=and i1 %c,%clean','br i1 %good,label %recover,label %failed',
  'recover:','store i64 0,ptr @test.alloc.calls',
  "%r=call {i1,i64} @ube.proc.$($symbols['CheckBuild'])(ptr @test.context,ptr @app,ptr @stage,i64 2,i64 $importFlag,ptr @expected,i64 -1)",
  '%rf=extractvalue {i1,i64} %r,0','%rv=extractvalue {i1,i64} %r,1','%rz=icmp eq i64 %rv,0','%rc=load i64,ptr @test.alloc.calls',"%re=icmp eq i64 %rc,$sites",'%ra=and i1 %rf,%rz','%rg=and i1 %ra,%re','br i1 %rg,label %advance,label %failed',
  'advance:','%next=add i64 %site,1',"%done=icmp ugt i64 %next,$sites",'br i1 %done,label %finished,label %loop',
  'finished:','%disposed=call i1 @ube.context.dispose(ptr @test.context)','%final.live=load i64,ptr @test.live','%final.clean=icmp eq i64 %final.live,0','%final.good=and i1 %disposed,%final.clean','%exit=select i1 %final.good,i32 0,i32 98','ret i32 %exit',
  'failed:','ret i32 99','}'
 )
 $path=Join-Path $artifacts ("faults-$kind.ll")
 $faultText=$production+$nl+$allocator+$nl+$faultGlobals+($faults -join $nl)
 Write-Text $path $faultText
 foreach($level in @('O0','O2')){
  $exe=Join-Path $artifacts ("faults-$kind-$level.exe")
  Build $path $exe $level
  $r=Run $exe @()
  Require ($r.ExitCode -eq 0) "Fault assertions failed $kind $level $($r.Evidence)"
  Write-Output "PASS $kind $level : all $sites allocation sites and retries, preserved destination, exact recovery, zero native blocks"
 }
 # A changed expected command byte must make the recovery assertion fail.
 $needle='@expected.data = global ['+$utf8.GetByteCount($expected)+' x i64] [i64 34,'
 $negative=$faultText.Replace($needle,('@expected.data = global ['+$utf8.GetByteCount($expected)+' x i64] [i64 33,'))
 Require ($negative -cne $faultText) 'Missing expected-command negative-control substitution'
 $path=Join-Path $artifacts ("negative-$kind.ll")
 Write-Text $path $negative
 $exe=Join-Path $artifacts ("negative-$kind.exe")
 Build $path $exe 'O2'
 $r=Run $exe @()
 Require ($r.ExitCode -eq 99) "Changed-command negative control failed $kind"
 Write-Output "PASS $kind changed-command negative control"
}


