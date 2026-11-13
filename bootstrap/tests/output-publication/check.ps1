# Executes the guarded UBE publication with independent runtime byte vectors.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
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
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/FileBytes.bas','std-lib/src/portable/ByteText.bas','std-lib/src/portable/Utf8.bas','std-lib/src/portable/PathPrimitives.bas','std-lib/src/portable/DirectoryPrimitives.bas','std-lib/src/portable/SystemPrimitives.bas','std-lib/src/win-lib/WindowsPaths.bas','compiler/src/SourceScanner.bas','compiler/src/SyntaxTokens.bas','compiler/src/SourceParser.bas','compiler/src/ProjectSyntax.bas','compiler/src/ProjectManifest.bas','compiler/src/ProjectLoader.bas','compiler/src/OutputPublication.bas','bootstrap/tests/output-publication/PublicationProbe.bas')
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
foreach($name in @('allocate','release','file.open','file.size','file.read','file.write','file.flush','file.close','directory.open','directory.create','directory.remove','file.delete','file.replace','system.clock')){
 $pattern='(?m)^(define[^\r\n@]*?)@ube\.target\.'+[regex]::Escape($name)+'\('
 Require ([regex]::Matches($production,$pattern).Count -eq 1) "Missing $name wrapper"
 $production=[regex]::Replace($production,$pattern,('$'+'{1}@test.real.'+$name+'('))
}
$fileObserver=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/FileObserver.ll'),$utf8)
$allocator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
$observer=@'
@test.create.calls = global i64 0
@test.stages = global i64 0
@test.create.fail = global i64 0
@test.delete.fail = global i64 0
@test.remove.fail = global i64 0
@test.replace.fail = global i64 0
define i64 @ube.target.system.clock() { ret i64 1234 }
define ptr @ube.target.directory.open(ptr %path) {
entry:
 %h=call ptr @test.real.directory.open(ptr %path)
 %good=icmp ne ptr %h,inttoptr(i64 -1 to ptr)
 %delta=zext i1 %good to i64
 %old=load i64,ptr @test.handles
 %next=add i64 %old,%delta
 store i64 %next,ptr @test.handles
 ret ptr %h
}
define i64 @ube.target.directory.create(ptr %path) {
entry:
 %old.calls=load i64,ptr @test.create.calls
 %next.calls=add i64 %old.calls,1
 store i64 %next.calls,ptr @test.create.calls
 %fail=load i64,ptr @test.create.fail
 %forced=icmp ne i64 %fail,0
 br i1 %forced,label %rejected,label %native
rejected:
 ret i64 %fail
native:
 %result=call i64 @test.real.directory.create(ptr %path)
 %good=icmp eq i64 %result,0
 %delta=zext i1 %good to i64
 %old=load i64,ptr @test.stages
 %next=add i64 %old,%delta
 store i64 %next,ptr @test.stages
 ret i64 %result
}
define i64 @ube.target.directory.remove(ptr %path) {
entry:
 %fail=load i64,ptr @test.remove.fail
 %forced=icmp ne i64 %fail,0
 br i1 %forced,label %rejected,label %native
rejected:
 store i64 0,ptr @test.remove.fail
 ret i64 %fail
native:
 %result=call i64 @test.real.directory.remove(ptr %path)
 %good=icmp eq i64 %result,0
 %delta=zext i1 %good to i64
 %old=load i64,ptr @test.stages
 %next=sub i64 %old,%delta
 store i64 %next,ptr @test.stages
 ret i64 %result
}
define i64 @ube.target.file.delete(ptr %path) {
entry:
 %fail=load i64,ptr @test.delete.fail
 %forced=icmp ne i64 %fail,0
 br i1 %forced,label %rejected,label %native
rejected:
 store i64 0,ptr @test.delete.fail
 ret i64 %fail
native:
 %result=call i64 @test.real.file.delete(ptr %path)
 ret i64 %result
}
define i64 @ube.target.file.replace(ptr %source,ptr %destination) {
entry:
 %fail=load i64,ptr @test.replace.fail
 %forced=icmp ne i64 %fail,0
 br i1 %forced,label %rejected,label %native
rejected:
 ret i64 %fail
native:
 %result=call i64 @test.real.file.replace(ptr %source,ptr %destination)
 ret i64 %result
}
'@
$cases=New-Object Collections.Generic.List[object]
# Creates private fixture paths; no production input is used as a mutation target.
function Case([string]$Name,[int]$Mode,[int]$Failure){
 $folder=Join-Path $artifacts $Name
 $null=New-Item -ItemType Directory -Path $folder -Force
 $project=Join-Path $folder 'input.UBE'
 $source=Join-Path $folder 'source.bas'
 $output=Join-Path $folder 'result file.bin'
 Write-Text $project 'manifest input'
 Write-Text $source 'source input'
 Write-Text $output 'previous output'
 $case=@{Name=$Name;Mode=$Mode;Failure=$Failure;Folder=$folder;Manifest=$project;Source=$source;Requested=$output;Output=$output;Expected='previous output';Swap=(Join-Path $folder 'swap.bin');CreateCalls=0;CloseFail=0;CreateFail=0;DeleteFail=0;RemoveFail=0;ReplaceFail=0;Reset=$true;Collisions=0}
 if($Failure -eq 0){$case.CreateCalls=1}
 if($Mode -eq 0 -or $Mode -eq 9){$case.Expected=[byte[]]@(17,42,99,255)}
 $cases.Add($case)
 return $case
}
$null=Case 'publish IR' 0 0
$null=Case 'publish executable' 9 0
$c=Case 'manifest alias' 1 120
$c.Requested=$c.Manifest;$c.Output=$c.Manifest;$c.Expected='manifest input';$c.Reset=$false
$c=Case 'source alias' 1 120
$c.Requested=$c.Source;$c.Output=$c.Source;$c.Expected='source input';$c.Reset=$false
$c=Case 'source hardlink' 1 120
Remove-Item -LiteralPath $c.Output
$null=New-Item -ItemType HardLink -Path $c.Output -Target $c.Source
$c.Expected='source input';$c.Reset=$false
$c=Case 'manifest hardlink' 1 120
Remove-Item -LiteralPath $c.Output
$null=New-Item -ItemType HardLink -Path $c.Output -Target $c.Manifest
$c.Expected='manifest input';$c.Reset=$false
$c=Case 'directory destination' 1 1
$c.Requested=Join-Path $c.Folder 'directory'
$null=New-Item -ItemType Directory -Path $c.Requested
$c=Case 'trailing dot' 1 1;$c.Requested+='.'
$c=Case 'trailing space' 1 1;$c.Requested+=' '
$c=Case 'missing parent' 1 3;$c.Requested=Join-Path $c.Folder 'missing/result.bin'
$c=Case 'junction parent' 0 0
$physical=Join-Path $artifacts 'physical parent'
$null=New-Item -ItemType Directory -Path $physical
$null=New-Item -ItemType Junction -Path (Join-Path $c.Folder 'link') -Target $physical
$c.Requested=Join-Path $c.Folder 'link/result.bin'
$c.Output=Join-Path $physical 'result.bin'
$c=Case 'collision retry' 0 0
$c.CreateCalls=2;$c.Collisions=1
$collision=Join-Path $c.Folder '.ube-1234-0'
$null=New-Item -ItemType Directory -Path $collision
Write-Text (Join-Path $collision 'foreign.bin') 'foreign'
$c=Case 'collision limit' 1 121
$c.CreateCalls=128;$c.Collisions=128
foreach($i in 0..127){$null=New-Item -ItemType Directory -Path (Join-Path $c.Folder ('.ube-1234-'+$i))}
$c=Case 'create refusal' 1 5;$c.CreateCalls=1;$c.CreateFail=5
$c=Case 'failed close' 2 7;$c.CloseFail=1
$null=Case 'incoming owner' 10 1
$null=Case 'missing stage file' 3 0
$c=Case 'commit alias recheck' 4 0;$c.Expected='source input'
$c=Case 'replace refusal' 5 0;$c.ReplaceFail=5
$null=Case 'unknown file cleanup' 6 0
$null=Case 'invalid commit kind' 7 0
$c=Case 'delete retry' 8 0;$c.DeleteFail=5
$c=Case 'directory remove retry' 8 0;$c.RemoveFail=5
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
for($i=0;$i -lt $cases.Count;$i++){
 $c=$cases[$i]
 $globals+=Descriptor "requested$i" ($utf8.GetBytes($c.Requested))
 $globals+=Descriptor "manifest$i" ($utf8.GetBytes($c.Manifest))
 $globals+=Descriptor "source$i" ($utf8.GetBytes($c.Source))
 $globals+=Descriptor "expected$i" ($utf8.GetBytes($c.Output))
 $globals+=Descriptor "swap$i" ($utf8.GetBytes($c.Swap))
 $globals+="@paths$i.data=global [3 x i64] [i64 0,i64 $($utf8.GetByteCount($c.Source)),i64 1]"+$nl+"@paths$i=global {i64,i64,ptr,ptr} {i64 0,i64 0,ptr @paths$i.data,ptr null}"+$nl
 $code+=@("case$($i):",'store i64 0,ptr @test.create.calls',"store i32 $($c.CloseFail),ptr @test.close.failures","store i64 $($c.CreateFail),ptr @test.create.fail","store i64 $($c.DeleteFail),ptr @test.delete.fail","store i64 $($c.RemoveFail),ptr @test.remove.fail","store i64 $($c.ReplaceFail),ptr @test.replace.fail","%p$i=call {i1,i64} @ube.proc.$($symbols['RunCase'])(ptr @test.context,ptr @requested$i,ptr @manifest$i,ptr @source$i,ptr @paths$i,ptr @expected$i,ptr @swap$i,i64 $($c.Failure),i64 $($c.Mode))","%f$i=extractvalue {i1,i64} %p$i,0","%v$i=extractvalue {i1,i64} %p$i,1","%z$i=icmp eq i64 %v$i,0","%g$i=and i1 %f$i,%z$i","%create$i=load i64,ptr @test.create.calls","%exact$i=icmp eq i64 %create$i,$($c.CreateCalls)","%live$i=load i64,ptr @test.live","%clean$i=icmp eq i64 %live$i,0","%handles$i=load i64,ptr @test.handles","%closed$i=icmp eq i64 %handles$i,0","%stages$i=load i64,ptr @test.stages","%removed$i=icmp eq i64 %stages$i,0","%a$i=and i1 %g$i,%exact$i","%b$i=and i1 %clean$i,%closed$i","%c$i=and i1 %a$i,%b$i","%good$i=and i1 %c$i,%removed$i","br i1 %good$i,label %case$($i+1),label %failed$i","failed$($i):","%error$i=trunc i64 %v$i to i32","%base$i=add i32 %error$i,$(($i+1)*100)","ret i32 %base$i")
}
$code+=@("case$($cases.Count):",'%disposed=call i1 @ube.context.dispose(ptr @test.context)','%exit=select i1 %disposed,i32 0,i32 9999','ret i32 %exit','failed:','ret i32 9998','}')
$path=Join-Path $artifacts 'publication.ll'
$combined=$production+$nl+$fileObserver+$nl+$allocator+$nl+$observer+$nl+$globals+($code -join $nl)
Write-Text $path $combined
foreach($level in @('O0','O2')){
 foreach($c in $cases){
  if($c.Reset){if(Test-Path -LiteralPath $c.Output){Remove-Item -LiteralPath $c.Output};Write-Text $c.Output 'previous output'}
  if($c.Mode -eq 4){
   if(Test-Path -LiteralPath $c.Swap){Remove-Item -LiteralPath $c.Swap}
   $null=New-Item -ItemType HardLink -Path $c.Swap -Target $c.Source
  }
 }
 $exe=Join-Path $artifacts ("publication-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 if($r.ExitCode -ge 100 -and $r.ExitCode -lt 9000){$caseIndex=[Math]::Floor($r.ExitCode/100)-1;Write-Output ("Failed case: "+$cases[$caseIndex].Name+" probe="+($r.ExitCode%100))}
 Require ($r.ExitCode -eq 0) "Publication assertions failed $level exit $($r.ExitCode) $($r.Evidence)"
 foreach($c in $cases){
  Require ([IO.File]::ReadAllText($c.Manifest,$utf8) -ceq 'manifest input') "Manifest changed $($c.Name)"
  Require ([IO.File]::ReadAllText($c.Source,$utf8) -ceq 'source input') "Source changed $($c.Name)"
  $expected=$c.Expected;if($expected -is [string]){$expected=$utf8.GetBytes($expected)}
  Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes($c.Output)) -ceq [Convert]::ToBase64String($expected)) "Output bytes differ $($c.Name)"
  $dirs=@(Get-ChildItem -LiteralPath $c.Folder -Directory -Filter '.ube-*')
  Require ($dirs.Count -eq $c.Collisions) "Unexpected remaining stage $($c.Name)"
 }
 Require ([IO.File]::ReadAllText((Join-Path $collision 'foreign.bin'),$utf8) -ceq 'foreign') 'Collision retry modified foreign stage'
 Write-Output "PASS $level : $($cases.Count) exact publication/refusal/cleanup cases; input hardlinks, physical parent, bounded collisions, owner recovery and exact bytes"
}

# Verifies additional support-file protection independently of source records.
$protected=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)',"%p=call {i1,i64} @ube.proc.$($symbols['CheckProtected'])(ptr @test.context,ptr @source4,ptr @requested4,i64 0)","%q=call {i1,i64} @ube.proc.$($symbols['CheckProtected'])(ptr @test.context,ptr @source0,ptr @requested0,i64 -1)",'%pf=extractvalue {i1,i64} %p,0','%pv=extractvalue {i1,i64} %p,1','%pz=icmp eq i64 %pv,0','%qf=extractvalue {i1,i64} %q,0','%qv=extractvalue {i1,i64} %q,1','%qz=icmp eq i64 %qv,0','%disposed=call i1 @ube.context.dispose(ptr @test.context)','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%handles=load i64,ptr @test.handles','%closed=icmp eq i64 %handles,0','%a=and i1 %pf,%pz','%b=and i1 %qf,%qz','%c=and i1 %a,%b','%d=and i1 %init,%disposed','%e=and i1 %clean,%closed','%f=and i1 %c,%d','%good=and i1 %f,%e','%exit=select i1 %good,i32 0,i32 99','ret i32 %exit','}')
$path=Join-Path $artifacts 'protected.ll'
Write-Text $path ($production+$nl+$fileObserver+$nl+$allocator+$nl+$observer+$nl+$globals+($protected -join $nl))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("protected-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Protected-input assertions failed $level $($r.Evidence)"
 Write-Output "PASS $level : independent protected-input hardlink refusal and nonalias allowance"
}
# Measures only TryPrepare allocations; cleanup runs after the observation.
$baseline=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)',"%p=call {i1,i64} @ube.proc.$($symbols['CheckPrepare'])(ptr @test.context,ptr @requested0,ptr @manifest0,ptr @source0,ptr @paths0,i64 -1)",'%pf=extractvalue {i1,i64} %p,0','%pv=extractvalue {i1,i64} %p,1','%pz=icmp eq i64 %pv,0','%calls=load i64,ptr @test.alloc.calls',"%q=call {i1,i64} @ube.proc.$($symbols['ClearPrepared'])(ptr @test.context)",'%qf=extractvalue {i1,i64} %q,0','%qv=extractvalue {i1,i64} %q,1','%qz=icmp eq i64 %qv,0','%disposed=call i1 @ube.context.dispose(ptr @test.context)','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%handles=load i64,ptr @test.handles','%closed=icmp eq i64 %handles,0','%stages=load i64,ptr @test.stages','%removed=icmp eq i64 %stages,0','%a=and i1 %pf,%pz','%b=and i1 %qf,%qz','%c=and i1 %a,%b','%d=and i1 %init,%disposed','%e=and i1 %clean,%closed','%f=and i1 %c,%d','%g=and i1 %f,%e','%good=and i1 %g,%removed','%count=trunc i64 %calls to i32','%exit=select i1 %good,i32 %count,i32 -1','ret i32 %exit','}')
$path=Join-Path $artifacts 'baseline.ll'
Write-Text $path ($production+$nl+$fileObserver+$nl+$allocator+$nl+$observer+$nl+$globals+($baseline -join $nl))
$sites=0
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("baseline-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -gt 0 -and $r.ExitCode -lt 4096) "Invalid prepare allocation baseline $level $($r.ExitCode) $($r.Evidence)"
 if($sites -eq 0){$sites=$r.ExitCode}else{Require ($sites -eq $r.ExitCode) 'Prepare allocation sites differ across levels'}
}
$faults=@(
 'define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %loop,label %failed',
 'loop:','%site=phi i64 [1,%entry],[%next,%advance]','store i64 0,ptr @test.alloc.calls','store i64 %site,ptr @test.fail.after','store i64 2,ptr @test.fail.remaining',
 "%p=call {i1,i64} @ube.proc.$($symbols['CheckPrepare'])(ptr @test.context,ptr @requested0,ptr @manifest0,ptr @source0,ptr @paths0,i64 0)",
 '%pf=extractvalue {i1,i64} %p,0','%pv=extractvalue {i1,i64} %p,1','%pz=icmp eq i64 %pv,0','%calls=load i64,ptr @test.alloc.calls','%expected=add i64 %site,1','%exact=icmp eq i64 %calls,%expected','%remaining=load i64,ptr @test.fail.remaining','%used=icmp eq i64 %remaining,0',
 "%q=call {i1,i64} @ube.proc.$($symbols['ClearPrepared'])(ptr @test.context)",
 '%qf=extractvalue {i1,i64} %q,0','%qv=extractvalue {i1,i64} %q,1','%qz=icmp eq i64 %qv,0','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%handles=load i64,ptr @test.handles','%closed=icmp eq i64 %handles,0','%stages=load i64,ptr @test.stages','%removed=icmp eq i64 %stages,0','%a=and i1 %pf,%pz','%b=and i1 %qf,%qz','%c=and i1 %a,%b','%d=and i1 %exact,%used','%e=and i1 %clean,%closed','%f=and i1 %c,%d','%g=and i1 %f,%e','%good=and i1 %g,%removed','br i1 %good,label %recover,label %failed',
 'recover:','store i64 0,ptr @test.alloc.calls',
 "%r=call {i1,i64} @ube.proc.$($symbols['CheckPrepare'])(ptr @test.context,ptr @requested0,ptr @manifest0,ptr @source0,ptr @paths0,i64 -1)",
 '%rf=extractvalue {i1,i64} %r,0','%rv=extractvalue {i1,i64} %r,1','%rz=icmp eq i64 %rv,0','%rc=load i64,ptr @test.alloc.calls',"%re=icmp eq i64 %rc,$sites",
 "%s=call {i1,i64} @ube.proc.$($symbols['ClearPrepared'])(ptr @test.context)",
 '%sf=extractvalue {i1,i64} %s,0','%sv=extractvalue {i1,i64} %s,1','%sz=icmp eq i64 %sv,0','%ra=and i1 %rf,%rz','%rb=and i1 %sf,%sz','%rx=and i1 %ra,%rb','%rg=and i1 %rx,%re','br i1 %rg,label %advance,label %failed',
 'advance:','%next=add i64 %site,1',"%done=icmp ugt i64 %next,$sites",'br i1 %done,label %finished,label %loop',
 'finished:','%disposed=call i1 @ube.context.dispose(ptr @test.context)','%final.live=load i64,ptr @test.live','%final.clean=icmp eq i64 %final.live,0','%final.handles=load i64,ptr @test.handles','%final.closed=icmp eq i64 %final.handles,0','%final.stages=load i64,ptr @test.stages','%final.removed=icmp eq i64 %final.stages,0','%final.a=and i1 %disposed,%final.clean','%final.b=and i1 %final.closed,%final.removed','%final.good=and i1 %final.a,%final.b','%exit=select i1 %final.good,i32 0,i32 98','ret i32 %exit',
 'failed:','ret i32 99','}'
)
$path=Join-Path $artifacts 'faults.ll'
Write-Text $path ($production+$nl+$fileObserver+$nl+$allocator+$nl+$observer+$nl+$globals+($faults -join $nl))
$before=[Convert]::ToBase64String([IO.File]::ReadAllBytes($cases[0].Output))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("faults-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Prepare allocation assertions failed $level $($r.Evidence)"
 Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes($cases[0].Output)) -ceq $before) 'Preparation faults changed prior output bytes'
 Write-Output "PASS $level : all $sites preparation allocation sites/retries, prior-output preservation, recovery and balanced owners/stages"
}
# Changing an expected physical path rejects an otherwise valid request.
$needle='@expected0.data = global ['+$utf8.GetByteCount($cases[0].Output)+' x i64] [i64 67,'
$negative=$combined.Replace($needle,('@expected0.data = global ['+$utf8.GetByteCount($cases[0].Output)+' x i64] [i64 88,'))
Require ($negative -cne $combined) 'Missing physical-path negative control'
$path=Join-Path $artifacts 'negative.ll'
Write-Text $path $negative
$exe=Join-Path $artifacts 'negative.exe'
Build $path $exe 'O2'
$r=Run $exe @()
Require ($r.ExitCode -eq 107) 'Changed physical path must fail exact first-case assertion'
Write-Output 'PASS changed-path negative control'


