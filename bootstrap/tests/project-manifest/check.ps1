# Executes the bounded UBE manifest parser with independent runtime byte vectors.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube manifest ' + [guid]::NewGuid())
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
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/Utf8.bas','compiler/src/ProjectManifest.bas','bootstrap/tests/project-manifest/ManifestProbe.bas')
$lines=@('UBE-Project 1','Name = "ManifestTests"','Kind = "Library"')
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
# Builds independently specified runtime byte arrays in the admitted private ABI.
function Descriptor([string]$Name,[byte[]]$Bytes){
 $cells=($Bytes|ForEach-Object{'i64 '+$_}) -join ', '
 return "@$Name.data = global [$($Bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Bytes.Length-1),ptr @$Name.data,ptr null}"+$nl
}
$script:cases=New-Object Collections.Generic.List[object]
# Retains source bytes and independent expected metadata for a named case.
function Case([string]$Name,[object]$Text,[int]$Code=0,[int]$Count=1,[bool]$Exe=$true,[int]$Opt=2,[int]$Debug=2,[string]$Project='Test',[string]$First='Main.bas',[string]$Last='Main.bas',[int]$FirstLine=5){
 if($Text -is [string]){$Text=$utf8.GetBytes($Text)}
 $script:cases.Add([pscustomobject]@{Name=$Name;Bytes=[byte[]]$Text;Code=$Code;Count=$Count;Exe=$Exe;Opt=$Opt;Debug=$Debug;Project=$Project;First=$First;Last=$Last;FirstLine=$FirstLine})
}
$valid=@('UBE-Project 1','Name = "Test"','Kind = "Exe"','Startup = "Main"','Source = "Main.bas"') -join $nl
Case 'valid' $valid
Case 'BOM' ([byte[]](@(239,187,191)+$utf8.GetBytes($valid)))
Case 'LF' ($valid.Replace($nl,[string][char]10))
Case 'case and whitespace' ("  uBe-PrOjEcT"+[char]9+" 1"+$nl+"nAmE = "+'"Test"'+$nl+'KIND = "EXE"'+$nl+'STARTUP="MAIN"'+$nl+'SOURCE="Main.bas"')
Case 'library defaults' ($valid.Replace('Kind = "Exe"','Kind = "Library"').Replace('Startup = "Main"'+$nl,'')) 0 1 $false 2 2 'Test' 'Main.bas' 'Main.bas' 4
Case 'ordered paths' ($valid+$nl+'Source = "sub/Other.BAS"') 0 2 $true 2 2 'Test' 'Main.bas' 'sub/Other.BAS'
Case 'unicode path' ($valid.Replace('Main.bas',('f'+[char]0xE6+'.bas'))) 0 1 $true 2 2 'Test' ('f'+[char]0xE6+'.bas') ('f'+[char]0xE6+'.bas')
foreach($opt in @('0','1','2','3','Size')){
 $number=4;if($opt -ne 'Size'){$number=[int]$opt}
 Case ('opt '+$opt) ($valid+$nl+'Optimization = "'+$opt+'"') 0 1 $true $number
}
foreach($debug in @('None','Line','Full')){
 $number=@{None=0;Line=1;Full=2}[$debug]
 Case ('debug '+$debug) ($valid+$nl+'DebugInformation = "'+$debug+'"') 0 1 $true 2 $number
}
Case 'empty' '' 1
Case 'bad header' ($valid.Replace('UBE-Project 1','UBE-Project 2')) 1
Case 'missing header' ($valid.Substring($valid.IndexOf($nl)+$nl.Length)) 1
Case 'missing equals' ($valid.Replace('Name =','Name ')) 2
Case 'unquoted value' ($valid.Replace('"Test"','Test')) 2
Case 'unterminated quote' ($valid.Replace('"Test"','"Test')) 2
Case 'trailing tokens' ($valid.Replace('"Test"','"Test" junk')) 2
Case 'duplicate key' ($valid+$nl+'name = "Again"') 3
Case 'bad identifier' ($valid.Replace('"Test"','"9Test"')) 4
Case 'long identifier' ($valid.Replace('"Test"',('"'+('x'*129)+'"'))) 4
Case 'bad kind' ($valid.Replace('"Exe"','"Dll"')) 5
Case 'bad startup' ($valid.Replace('"Main"','"Other"')) 5
Case 'library startup' ($valid.Replace('"Exe"','"Library"')) 5
Case 'bad opt' ($valid+$nl+'Optimization = "9"') 5
Case 'bad debug' ($valid+$nl+'DebugInformation = "Unknown"') 5
foreach($key in @('Reference','LibraryReference','Resource','StartupForm')){Case ('unsupported '+$key) ($valid+$nl+$key+' = "value"') 6}
Case 'unsupported extension' ($valid.Replace('Main.bas','Main.cls')) 6
Case 'unknown key' ($valid+$nl+'Surprise = "value"') 7
Case 'missing name' ($valid.Replace('Name = "Test"'+$nl,'')) 8
Case 'missing kind' ($valid.Replace('Kind = "Exe"'+$nl,'')) 8
Case 'missing source' ($valid.Replace('Source = "Main.bas"','')) 8
Case 'missing startup' ($valid.Replace('Startup = "Main"'+$nl,'')) 8
Case 'manifest byte limit' ($valid+("'"*65536)) 9
$many=$valid
foreach($i in 1..127){$many+=$nl+'Source = "M'+$i+'.bas"'}
Case '128 source boundary' $many 0 128 $true 2 2 'Test' 'Main.bas' 'M127.bas'
Case '129 source boundary' ($many+$nl+'Source="Last.bas"') 9
Case 'malformed utf8' ([byte[]](@(255)+$utf8.GetBytes($valid))) 10
Case 'embedded nul' ($valid+[char]0) 10
Case 'bare CR' ($valid+[char]13) 10
Case 'DEL' ($valid+[char]127) 10
Case 'empty path' ($valid.Replace('Main.bas','')) 11
Case 'rooted path' ($valid.Replace('Main.bas','/Main.bas')) 11
Case 'drive path' ($valid.Replace('Main.bas','C:\Main.bas')) 11
Case 'quoted path' ($valid.Replace('Main.bas','Ma""in.bas')) 11
Case 'wildcard path' ($valid.Replace('Main.bas','*.bas')) 11
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
for($i=0;$i -lt $cases.Count;$i++){
 $c=$cases[$i]
 $globals+=Descriptor "text$i" $c.Bytes
 $globals+=Descriptor "name$i" ($utf8.GetBytes($c.Project))
 $globals+=Descriptor "first$i" ($utf8.GetBytes($c.First))
 $globals+=Descriptor "last$i" ($utf8.GetBytes($c.Last))
 $ex=0;if($c.Exe){$ex=-1}
 $next='case'+($i+1)
 $code+=@("case$($i):","%p$i=call {i1,i64} @ube.proc.$($symbols['CheckManifest'])(ptr @test.context,ptr @text$i,i64 $($c.Code),i64 $($c.Count),i64 $ex,i64 $($c.Opt),i64 $($c.Debug),ptr @name$i,ptr @first$i,ptr @last$i,i64 $($c.FirstLine))","%fresh$i=extractvalue {i1,i64} %p$i,0","%value$i=extractvalue {i1,i64} %p$i,1","%zero$i=icmp eq i64 %value$i,0","%ok$i=and i1 %fresh$i,%zero$i","br i1 %ok$i,label %$next,label %failed$i","failed$($i):","%dispose$i=call i1 @ube.context.dispose(ptr @test.context)","ret i32 $($i+1)")
}
$code+=@("case$($cases.Count):",'%disposed=call i1 @ube.context.dispose(ptr @test.context)','%exit=select i1 %disposed,i32 0,i32 254','ret i32 %exit','failed:','ret i32 255','}')
$path=Join-Path $artifacts 'manifest.ll'
$combined=$production+$nl+$globals+($code -join $nl)
Write-Text $path $combined
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("manifest-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 if($r.ExitCode -gt 0 -and $r.ExitCode -le $cases.Count){Write-Output ("Failed case: "+$cases[$r.ExitCode-1].Name)}
 Require ($r.ExitCode -eq 0) "Manifest assertions failed $level exit $($r.ExitCode). $($r.Evidence)"
 Write-Output "PASS $level : $($cases.Count) manifest vectors, atomic failure outputs and sticky Err"
}
# A changed valid input must fail the independent expected-name assertion.
$negative=$combined.Replace('@name0.data = global [4 x i64] [i64 84, i64 101, i64 115, i64 116]','@name0.data = global [4 x i64] [i64 88, i64 101, i64 115, i64 116]')
Require ($negative -cne $combined) 'Negative control replacement missing'
$path=Join-Path $artifacts 'negative.ll'
Write-Text $path $negative
$exe=Join-Path $artifacts 'negative.exe'
Build $path $exe 'O2'
$r=Run $exe @()
Require ($r.ExitCode -eq 1) 'Negative expected-name control must fail first case'
Write-Output 'PASS exact changed-input negative control'

# Exercises public decoding independently, including malformed interiors and bounds.
$decodes=@(
 @('a""b',0,4,'a"b',$true),
 @('prefix"value',6,0,'',$true),
 @('abc',0,3,'abc',$true),
 @('a"b',0,3,'',$false),
 @('abc',-1,2,'',$false),
 @('abc',2,2,'',$false),
 @(("a"+[char]10+"b"),0,3,'',$false)
)
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)')
for($i=0;$i -lt $decodes.Count;$i++){
 $d=$decodes[$i]
 Require ($d.Count -eq 5) "Malformed decoding test vector $i"
 $globals+=Descriptor "decode$i" ($utf8.GetBytes($d[0]))
 $globals+=Descriptor "expected$i" ($utf8.GetBytes($d[3]))
 $validFlag=0;if($d[4]){$validFlag=-1}
 $code+=@("%p$i=call {i1,i64} @ube.proc.$($symbols['CheckDecode'])(ptr @test.context,ptr @decode$i,i64 $($d[1]),i64 $($d[2]),ptr @expected$i,i64 $validFlag)","%f$i=extractvalue {i1,i64} %p$i,0","%v$i=extractvalue {i1,i64} %p$i,1","%z$i=icmp eq i64 %v$i,0","%g$i=and i1 %f$i,%z$i")
 if($i -eq 0){$code+="%all$i=and i1 %init,%g$i"}else{$code+="%all$i=and i1 %all$($i-1),%g$i"}
}
$code+=@('%disposed=call i1 @ube.context.dispose(ptr @test.context)',"%good=and i1 %disposed,%all$($decodes.Count-1)",'%exit=select i1 %good,i32 0,i32 99','ret i32 %exit','}')
$path=Join-Path $artifacts 'decode.ll'
Write-Text $path ($production+$nl+$globals+($code -join $nl))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("decode-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Decode assertions failed $level $($r.Evidence)"
 Write-Output "PASS $level : $($decodes.Count) exact decoding and invalid-span cases"
}
# Fault each of the parser's three allocation sites and its retry, then recover.
$observed=$production.Replace('define ptr @ube.target.allocate(', 'define ptr @test.real.allocate(').Replace('define i1 @ube.target.release(', 'define i1 @test.real.release(')
$observer=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$globals+=Descriptor 'valid' ($utf8.GetBytes($valid))
$globals+=Descriptor 'name' ($utf8.GetBytes('Test'))
$globals+=Descriptor 'path' ($utf8.GetBytes('Main.bas'))
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)')
foreach($site in 2..4){
 $code+=@('store i64 0,ptr @test.alloc.calls',"store i64 $site,ptr @test.fail.after",'store i64 2,ptr @test.fail.remaining',"%p$site=call {i1,i64} @ube.proc.$($symbols['CheckManifest'])(ptr @test.context,ptr @valid,i64 12,i64 1,i64 -1,i64 2,i64 2,ptr @name,ptr @path,ptr @path,i64 5)","%f$site=extractvalue {i1,i64} %p$site,0","%v$site=extractvalue {i1,i64} %p$site,1","%z$site=icmp eq i64 %v$site,0","%g$site=and i1 %f$site,%z$site","%calls$site=load i64,ptr @test.alloc.calls","%exact$site=icmp eq i64 %calls$site,$($site+1)","%remaining$site=load i64,ptr @test.fail.remaining","%used$site=icmp eq i64 %remaining$site,0","%live$site=load i64,ptr @test.live","%clean$site=icmp eq i64 %live$site,0","%a$site=and i1 %g$site,%exact$site","%b$site=and i1 %used$site,%clean$site","%ok$site=and i1 %a$site,%b$site",'store i64 0,ptr @test.alloc.calls',"%r$site=call {i1,i64} @ube.proc.$($symbols['CheckManifest'])(ptr @test.context,ptr @valid,i64 0,i64 1,i64 -1,i64 2,i64 2,ptr @name,ptr @path,ptr @path,i64 5)","%rf$site=extractvalue {i1,i64} %r$site,0","%rv$site=extractvalue {i1,i64} %r$site,1","%rz$site=icmp eq i64 %rv$site,0","%rg$site=and i1 %rf$site,%rz$site","%recovery$site=and i1 %ok$site,%rg$site")
 if($site -eq 2){$code+="%all$site=and i1 %init,%recovery$site"}else{$code+="%all$site=and i1 %all$($site-1),%recovery$site"}
}
$code+=@('%disposed=call i1 @ube.context.dispose(ptr @test.context)','%live=load i64,ptr @test.live','%clean=icmp eq i64 %live,0','%a=and i1 %all4,%disposed','%good=and i1 %a,%clean','%exit=select i1 %good,i32 0,i32 99','ret i32 %exit','}')
$path=Join-Path $artifacts 'faults.ll'
Write-Text $path ($observed+$nl+$observer+$nl+$globals+($code -join $nl))
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("faults-$level.exe")
 Build $path $exe $level
 $r=Run $exe @()
 Require ($r.ExitCode -eq 0) "Allocation assertions failed $level $($r.Evidence)"
 Write-Output "PASS $level : all three parser allocation sites, failed retries, exact call counts, recovery and zero live blocks"
}


