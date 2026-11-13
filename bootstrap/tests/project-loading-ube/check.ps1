# Executes the UBE project loader with independent runtime byte vectors.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube project source ' + [guid]::NewGuid())
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
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/FileBytes.bas','std-lib/src/portable/Utf8.bas','std-lib/src/portable/PathPrimitives.bas','std-lib/src/win-lib/WindowsPaths.bas','compiler/src/SourceScanner.bas','compiler/src/SyntaxTokens.bas','compiler/src/SourceParser.bas','compiler/src/ProjectSyntax.bas','compiler/src/ProjectManifest.bas','compiler/src/ProjectLoader.bas','bootstrap/tests/project-loading-ube/LoaderProbe.bas')
$lines=@('UBE-Project 1','Name = "LoaderTests"','Kind = "Library"')
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
# Builds independently supplied runtime paths and expected source payloads.
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
$readNeedle='  %mode = load i32, ptr @test.read.mode'
$readReplacement=@('  %configured.mode = load i32, ptr @test.read.mode','  %fail.at = load i64, ptr @test.read.fail.at','  %fail.this = icmp eq i64 %next, %fail.at','  %mode = select i1 %fail.this, i32 1, i32 %configured.mode') -join $nl
Require ($observer.Contains($readNeedle)) 'Missing unique read mode hook'
$observer=$observer.Replace($readNeedle,$readReplacement)+$nl+'@test.read.fail.at = global i64 0'+$nl
$allocator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
# Creates one isolated manifest retaining its caller-specified source order.
function Fixture([string]$Name,[string[]]$Paths,[string[]]$Bodies){
 $folder=Join-Path $artifacts $Name
 $null=New-Item -ItemType Directory -Path $folder -Force
 $rows=@('UBE-Project 1','Name="LoaderFixture"','Kind="Library"')
 $all=''
 for($i=0;$i -lt $Paths.Count;$i++){
  $rows+='Source="'+$Paths[$i]+'"'
  if($i -lt $Bodies.Count){
   $file=Join-Path $folder $Paths[$i]
   $null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($file)) -Force
   Write-Text $file $Bodies[$i]
   $all+=$Bodies[$i]
  }
 }
 $path=Join-Path $folder 'project.UBE'
 Write-Text $path (($rows -join $nl)+$nl)
 return [pscustomobject]@{Path=$path;Folder=$folder;Bytes=$utf8.GetBytes($all);First=[IO.Path]::GetFullPath((Join-Path $folder $Paths[0]));Last=[IO.Path]::GetFullPath((Join-Path $folder $Paths[-1]));Count=$Paths.Count;ManifestBytes=([IO.File]::ReadAllBytes($path)).Length}
}
$first=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "First"','Public Function Value() As Long','    Value = 42','End Function','') -join $nl
$last=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "Last"','Public Function Other() As Long','    Other = 17','End Function','') -join $nl
$valid=Fixture 'ordered sources' @('z-first.bas','sub/a-last.bas') @($first,$last)
$missing=Fixture 'missing source' @('absent.bas') @()
$syntax=Fixture 'invalid source' @('first.bas','bad.bas') @($first,'NotASource'+$nl)
$duplicate=Fixture 'duplicate source' @('first.bas','first.bas') @($first)
$duplicateModule=Fixture 'duplicate identity' @('first.bas','second.bas') @($first,$first)
$escape=Fixture 'escape project' @('../external.bas') @()
Write-Text (Join-Path $artifacts 'external.bas') $last
$external=Join-Path $artifacts 'external directory'
$null=New-Item -ItemType Directory -Path $external -Force
Write-Text (Join-Path $external 'outside.bas') $last
$junction=Fixture 'junction project' @('redirect/outside.bas') @()
$null=New-Item -ItemType Junction -Path (Join-Path $junction.Folder 'redirect') -Target $external
$alias=Fixture 'junction duplicate' @('inside/first.bas','alias/first.bas') @($first)
$null=New-Item -ItemType Junction -Path (Join-Path $alias.Folder 'alias') -Target (Join-Path $alias.Folder 'inside')
$badManifest=Fixture 'malformed manifest' @('first.bas') @($first)
Write-Text $badManifest.Path 'UBE-Project 9'
# Loads actual production module bytes, including this loader and all frontend passes.
$actualFiles=@(Get-ChildItem -LiteralPath (Join-Path $root 'compiler/src') -Filter '*.bas' | Sort-Object Name)
$actualFiles+=@(Get-ChildItem -LiteralPath (Join-Path $root 'std-lib/src/portable') -Filter '*.bas' | Sort-Object Name)
$actualFiles+=Get-Item -LiteralPath (Join-Path $root 'std-lib/src/win-lib/WindowsPaths.bas')
$actual=Fixture 'actual compiler' @($actualFiles|ForEach-Object{$_.Name}) @($actualFiles|ForEach-Object{[IO.File]::ReadAllText($_.FullName,$utf8)})
$cases=@(
 @{Name='ordered';Fixture=$valid;Stage=0;Code=0;Module=-1;Line=0;Mode=0;ReadBytes=-1},
 @{Name='incoming owner';Fixture=$valid;Stage=1;Code=1;Module=-1;Line=1;Mode=1;ReadBytes=0},
 @{Name='missing source';Fixture=$missing;Stage=6;Code=3;Module=0;Line=4;Mode=0;ReadBytes=$missing.ManifestBytes},
 @{Name='source syntax';Fixture=$syntax;Stage=8;Code=2;Module=1;Line=1;Mode=0;ReadBytes=-1},
 @{Name='duplicate path';Fixture=$duplicate;Stage=6;Code=3;Module=1;Line=5;Mode=0;ReadBytes=($duplicate.ManifestBytes+$utf8.GetByteCount($first))},
 @{Name='duplicate module';Fixture=$duplicateModule;Stage=8;Code=3;Module=1;Line=1;Mode=0;ReadBytes=-1},
 @{Name='lexical escape';Fixture=$escape;Stage=5;Code=1;Module=0;Line=4;Mode=0;ReadBytes=$escape.ManifestBytes},
 @{Name='physical escape';Fixture=$junction;Stage=6;Code=11;Module=0;Line=4;Mode=0;ReadBytes=$junction.ManifestBytes},
 @{Name='physical duplicate';Fixture=$alias;Stage=6;Code=3;Module=1;Line=5;Mode=0;ReadBytes=($alias.ManifestBytes+$utf8.GetByteCount($first))},
 @{Name='manifest syntax';Fixture=$badManifest;Stage=4;Code=1;Module=-1;Line=1;Mode=0;ReadBytes=-1},
 @{Name='failed close';Fixture=$valid;Stage=3;Code=7;Module=-1;Line=1;Mode=2;ReadBytes=$valid.ManifestBytes},
 @{Name='manifest read failure';Fixture=$valid;Stage=3;Code=5;Module=-1;Line=1;Mode=0;ReadBytes=2;ReadMode=1},
 @{Name='primary read and close failure';Fixture=$valid;Stage=3;Code=5;Module=-1;Line=1;Mode=2;ReadBytes=2;ReadMode=1},
 @{Name='source read failure';Fixture=$valid;Stage=7;Code=5;Module=0;Line=4;Mode=0;ReadBytes=($valid.ManifestBytes+2);FailRead=3},
 @{Name='actual compiler';Fixture=$actual;Stage=0;Code=0;Module=-1;Line=0;Mode=0;ReadBytes=-1}
)
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
for($i=0;$i -lt $cases.Count;$i++){
 $c=$cases[$i];$f=$c.Fixture
 $globals+=Descriptor "path$i" ($utf8.GetBytes($f.Path))
 $globals+=Descriptor "bytes$i" $f.Bytes
 $globals+=Descriptor "first$i" ($utf8.GetBytes($f.First))
 $globals+=Descriptor "last$i" ($utf8.GetBytes($f.Last))
 $closeFailures=0;if($c.Mode -eq 2){$closeFailures=1}
 $readMode=0;if($c.ContainsKey('ReadMode')){$readMode=$c.ReadMode}
 $failRead=0;if($c.ContainsKey('FailRead')){$failRead=$c.FailRead}
 $code+=@("case$($i):",'store i64 0,ptr @test.read.calls',"store i64 $failRead,ptr @test.read.fail.at","store i32 $readMode,ptr @test.read.mode")
 $code+=@('store i64 0,ptr @test.read.bytes',"store i32 $closeFailures,ptr @test.close.failures","%p$i=call {i1,i64} @ube.proc.$($symbols['CheckLoad'])(ptr @test.context,ptr @path$i,ptr @bytes$i,ptr @first$i,ptr @last$i,i64 $($f.Count),i64 $($c.Stage),i64 $($c.Code),i64 $($c.Module),i64 $($c.Line),i64 $($c.Mode))","%fresh$i=extractvalue {i1,i64} %p$i,0","%value$i=extractvalue {i1,i64} %p$i,1","%zero$i=icmp eq i64 %value$i,0","%good$i=and i1 %fresh$i,%zero$i","%live$i=load i64,ptr @test.live","%clean$i=icmp eq i64 %live$i,0","%handles$i=load i64,ptr @test.handles","%closed$i=icmp eq i64 %handles$i,0","%a$i=and i1 %good$i,%clean$i","%b$i=and i1 %a$i,%closed$i")
 if($c.ReadBytes -ge 0){$code+=@("%read$i=load i64,ptr @test.read.bytes","%exact$i=icmp eq i64 %read$i,$($c.ReadBytes)","%all$i=and i1 %b$i,%exact$i")}else{$code+="%all$i=and i1 %b$i,true"}
 $code+=@("br i1 %all$i,label %case$($i+1),label %failed$i","failed$($i):","%dispose$i=call i1 @ube.context.dispose(ptr @test.context)","ret i32 $($i+1)")
}
$code+=@("case$($cases.Count):",'%disposed=call i1 @ube.context.dispose(ptr @test.context)','%exit=select i1 %disposed,i32 0,i32 254','ret i32 %exit','failed:','ret i32 255','}')
$path=Join-Path $artifacts 'loader.ll'
$combined=$production+$nl+$observer+$nl+$allocator+$nl+$globals+($code -join $nl)
Write-Text $path $combined
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("loader-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 if($r.ExitCode -gt 0 -and $r.ExitCode -le $cases.Count){Write-Output ("Failed case: "+$cases[$r.ExitCode-1].Name)}
 Require ($r.ExitCode -eq 0) "Loader assertions failed $level exit $($r.ExitCode) $($r.Evidence)"
 Write-Output "PASS $level : $($cases.Count) source-loading cases including physical containment, original source bytes, failed-close owner and actual compiler"
}

# Measures successful allocation sites, then faults each site and its retry.
$faultGlobals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$faultGlobals+=Descriptor 'path' ($utf8.GetBytes($valid.Path))
$faultGlobals+=Descriptor 'bytes' $valid.Bytes
$faultGlobals+=Descriptor 'first' ($utf8.GetBytes($valid.First))
$faultGlobals+=Descriptor 'last' ($utf8.GetBytes($valid.Last))
$callSuccess="%p=call {i1,i64} @ube.proc.$($symbols['CheckLoad'])(ptr @test.context,ptr @path,ptr @bytes,ptr @first,ptr @last,i64 2,i64 0,i64 0,i64 -1,i64 0,i64 0)"
$baseline=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)',$callSuccess,'%fresh=extractvalue {i1,i64} %p,0','%value=extractvalue {i1,i64} %p,1','%zero=icmp eq i64 %value,0','%a=and i1 %init,%fresh','%b=and i1 %a,%zero','%calls=load i64,ptr @test.alloc.calls','%disposed=call i1 @ube.context.dispose(ptr @test.context)','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%handles=load i64,ptr @test.handles','%closed=icmp eq i64 %handles,0','%c=and i1 %b,%disposed','%d=and i1 %clean,%closed','%good=and i1 %c,%d','%count=trunc i64 %calls to i32','%exit=select i1 %good,i32 %count,i32 -1','ret i32 %exit','}')
$baselinePath=Join-Path $artifacts 'baseline.ll'
Write-Text $baselinePath ($production+$nl+$observer+$nl+$allocator+$nl+$faultGlobals+($baseline -join $nl))
$allocationSites=0
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("baseline-$level.exe")
 Build $baselinePath $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -gt 0 -and $r.ExitCode -lt 4096) "Invalid allocation baseline $level $($r.ExitCode) $($r.Evidence)"
 if($allocationSites -eq 0){$allocationSites=$r.ExitCode}else{Require ($allocationSites -eq $r.ExitCode) 'Allocation sites differ across optimization levels'}
 Write-Output "PASS $level : observed $allocationSites complete-loader allocations"
}
$faults=@(
 'define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %loop,label %failed',
 'loop:','%site=phi i64 [1,%entry],[%next,%advance]','store i64 0,ptr @test.alloc.calls','store i64 %site,ptr @test.fail.after','store i64 2,ptr @test.fail.remaining',
 "%p=call {i1,i64} @ube.proc.$($symbols['CheckLoad'])(ptr @test.context,ptr @path,ptr @bytes,ptr @first,ptr @last,i64 2,i64 0,i64 0,i64 -1,i64 0,i64 3)",
 '%fresh=extractvalue {i1,i64} %p,0','%value=extractvalue {i1,i64} %p,1','%zero=icmp eq i64 %value,0','%calls=load i64,ptr @test.alloc.calls','%expected=add i64 %site,1','%exact=icmp eq i64 %calls,%expected','%remaining=load i64,ptr @test.fail.remaining','%used=icmp eq i64 %remaining,0','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%handles=load i64,ptr @test.handles','%closed=icmp eq i64 %handles,0','%a=and i1 %fresh,%zero','%b=and i1 %exact,%used','%c=and i1 %clean,%closed','%d=and i1 %a,%b','%good=and i1 %d,%c','br i1 %good,label %recover,label %failed',
 'recover:','store i64 0,ptr @test.alloc.calls',
 "%r=call {i1,i64} @ube.proc.$($symbols['CheckLoad'])(ptr @test.context,ptr @path,ptr @bytes,ptr @first,ptr @last,i64 2,i64 0,i64 0,i64 -1,i64 0,i64 0)",
 '%rf=extractvalue {i1,i64} %r,0','%rv=extractvalue {i1,i64} %r,1','%rz=icmp eq i64 %rv,0','%rc=load i64,ptr @test.alloc.calls',"%re=icmp eq i64 %rc,$allocationSites",'%ra=and i1 %rf,%rz','%rg=and i1 %ra,%re','br i1 %rg,label %advance,label %failed',
 'advance:','%next=add i64 %site,1',"%done=icmp ugt i64 %next,$allocationSites",'br i1 %done,label %finished,label %loop',
 'finished:','%disposed=call i1 @ube.context.dispose(ptr @test.context)','%final.live=load i64,ptr @test.live','%final.clean=icmp eq i64 %final.live,0','%final.handles=load i64,ptr @test.handles','%final.closed=icmp eq i64 %final.handles,0','%final.a=and i1 %disposed,%final.clean','%final.good=and i1 %final.a,%final.closed','%exit=select i1 %final.good,i32 0,i32 98','ret i32 %exit',
 'failed:','ret i32 99','}'
)
$path=Join-Path $artifacts 'faults.ll'
Write-Text $path ($production+$nl+$observer+$nl+$allocator+$nl+$faultGlobals+($faults -join $nl))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("faults-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Loader fault assertions failed $level exit $($r.ExitCode) $($r.Evidence)"
 Write-Output "PASS $level : all $allocationSites allocation sites/retries, invalid partial results, exact recovery and balanced owners"
}
# Altering expected retained source bytes must reject the first otherwise-valid case.
$needle='@bytes0.data = global ['+$valid.Bytes.Length+' x i64] [i64 85,'
$replacement='@bytes0.data = global ['+$valid.Bytes.Length+' x i64] [i64 88,'
$negative=$combined.Replace($needle,$replacement)
Require ($negative -cne $combined) 'Missing source negative-control substitution'
$path=Join-Path $artifacts 'negative.ll'
Write-Text $path $negative
$exe=Join-Path $artifacts 'negative.exe'
Build $path $exe 'O2'
$r=Run $exe @()
Require ($r.ExitCode -eq 1) 'Changed expected source must fail first exact case'
Write-Output 'PASS exact changed-source negative control'


