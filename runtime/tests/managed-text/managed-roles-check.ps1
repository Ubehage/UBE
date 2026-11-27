# Executes managed primitive role resolution through the actual UBE parser and declaration binder.
param([Parameter(Mandatory=$true)][string]$BootstrapExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube managed primitive roles '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
$script:process=0
function Require([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Write-Text([string]$Path,[string]$Value){[IO.File]::WriteAllText($Path,$Value,$utf8)}
function Quote-Argument([string]$Value){
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
function Invoke-BoundedProcess([string]$File,[string[]]$Arguments){
 $script:process++
 $prefix=Join-Path $artifacts ('process-'+$script:process)
 $start=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$start.ArgumentList=(($Arguments|ForEach-Object{Quote-Argument $_}) -join ' ')}
 $p=Start-Process @start
 try{
  $handle=$p.Handle
  if(-not $p.WaitForExit(60000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Timeout: $prefix"}
  $p.Refresh()
  Require ($null -ne $p.ExitCode) "Missing exit code for $handle"
  return [pscustomobject]@{ExitCode=$p.ExitCode;Stdout=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Stderr=[IO.File]::ReadAllText($prefix+'.stderr',$utf8);Evidence=$prefix}
 }finally{$p.Dispose()}
}
. (Join-Path $root 'bootstrap/tests/NativeMemory.ps1')
function Build([string]$IR,[string]$Exe,[string]$Level){
 $links=@(Get-NativeMemoryLinkArguments $IR $Clang $artifacts)
 $r=Invoke-BoundedProcess $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$Level),$IR)+$links+@('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608'))
 Require ($r.ExitCode -eq 0) "Native build failed: $($r.Evidence)"
}
$nl=[Environment]::NewLine
$files=@('std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/ByteText.bas','std-lib/src/portable/InvariantNumbers.bas','std-lib/src/portable/BinaryFloat.bas','std-lib/src/portable/BinaryFloatValues.bas','std-lib/src/portable/BinaryFloatMath.bas','std-lib/src/portable/BinaryFloatPower.bas','std-lib/src/portable/BinaryFloatText.bas','std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/Utf8.bas','compiler/src/SourceScanner.bas','compiler/src/SyntaxTokens.bas','compiler/src/SourceParser.bas','compiler/src/ConditionalExpressions.bas','compiler/src/ConditionalSource.bas','compiler/src/ConstantValues.bas','compiler/src/ConstantText.bas','compiler/src/ProjectSyntax.bas','compiler/src/DeclarationBinder.bas','compiler/src/PrimitiveRoles.bas','runtime/tests/managed-text/ManagedRolesProbe.bas')
$manifest=@('UBE-Project 1','Name="PrimitiveTests"','Kind="Library"')
foreach($file in $files){$leaf=[IO.Path]::GetFileName($file);Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $artifacts $leaf);$manifest+='Source="'+$leaf+'"'}
$project=Join-Path $artifacts 'project.UBE'
Write-Text $project (($manifest -join $nl)+$nl)
Write-Output "Artifacts retained: $artifacts"
$r=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$project)
Require ($r.ExitCode -eq 0 -and $r.Stdout -match '(?m)^SYMBOL (\d+)\|function\|Check\|') "Binding failed: $($r.Evidence)"
$check=$Matches[1]
$ir=Join-Path $artifacts 'production.ll'
$r=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$project,$ir)
Require ($r.ExitCode -eq 0 -and $r.Stdout -match 'EMIT OK') "Emission failed: $($r.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
$managed=[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/ManagedPrimitives.bas'),$utf8)
$text=[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/TextPrimitives.bas'),$utf8)
$memory=[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/Memory.bas'),$utf8)
$cases=@(@{Name='all authoritative declarations';First=$managed;Second=$text;Expected=@(38..48)+@(57,11)+@(49..55);Code=0;Reason=0})
$roleNames=@('Managed.BeginCollection','Managed.EndCollection','Managed.SnapshotCounts','Managed.AllocationAt','Managed.RootAt','Managed.Mark','Managed.Marked','Managed.EdgeCount','Managed.EdgeAt','Managed.SealCollection','Managed.Reclaim','Text.ByteLength','Text.ScalarLength','Text.ReadByte','Text.Create','Text.WriteByte','Text.Publish','Text.Abandon')
$roleNames+=@('Memory.Collect','Managed.Workspace')
$blocks=@([regex]::Matches($managed+$nl+$text+$nl+$memory,'(?ms)^Public Intrinsic Function ([A-Za-z_][A-Za-z0-9_]*)\([^\r\n]*\).*?^End Function'))
function Module-Source([string]$Body){return (@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "Probe"',$Body,'') -join $nl)}
for($i=0;$i -lt $roleNames.Count;$i++){
 $role=$roleNames[$i]
 $selected=@($blocks|Where-Object{$_.Value.Contains('"'+$role+'"')})
 Require ($selected.Count -eq 1) "Missing independently enumerated role $role"
 $body=$selected[0].Value
 $procedure=$selected[0].Groups[1].Value
 $renamed=$body.Replace('Function '+$procedure+'(', 'Function Renamed(').Replace('Attribute '+$procedure+'.','Attribute Renamed.')
 $cases+=@{Name=($role+' explicit identity');First=(Module-Source $renamed);Second='';Expected=@(38+$i);Code=0;Reason=0}
 if($body -match '\(By(Ref|Val) '){
  $mode='Ref';if($Matches[1] -eq 'Ref'){$mode='Val'}
  $wrong=[regex]::Replace($body,'\(By(Ref|Val) ','(By'+$mode+' ',1)
 }else{$wrong=$body.Replace('()','(ByVal Extra As Long)')}
 $cases+=@{Name=($role+' wrong passing or arity');First=(Module-Source $wrong);Second='';Expected=@();Code=3;Reason=5}
 $wrong=$body.Replace('"'+$role+'"','"'+$role+'.Missing"')
 $cases+=@{Name=($role+' unknown role');First=(Module-Source $wrong);Second='';Expected=@();Code=8;Reason=1}
}
foreach($mutation in @(
 @{Name='String scalar cannot be array';Old='ByRef Value As String';New='ByRef Value() As String'},
 @{Name='text byte result cannot be Long';Old='ByRef Result As Byte';New='ByRef Result As Long'},
 @{Name='candidate cannot be Long';Old='ByRef Candidate As LongLong';New='ByRef Candidate As Long'},
 @{Name='metadata length cannot be Long';Old=') As LongLong';New=') As Long'},
 @{Name='byte value cannot be LongLong';Old='ByVal Value As Byte';New='ByVal Value As LongLong'},
 @{Name='destination cannot be numeric';Old='ByRef Destination As String';New='ByRef Destination As LongLong'}
)){
 $wrong=$text.Replace($mutation.Old,$mutation.New)
 Require ($wrong -cne $text) "Missing mutation $($mutation.Name)"
 $cases+=@{Name=$mutation.Name;First=$managed;Second=$wrong;Expected=@();Code=3;Reason=5}
}
$wrong=$managed.Replace('ByRef Fresh As Boolean','ByRef Fresh As Long')
foreach($mutation in @(
 @{Name='workspace element must be LongLong';Old='ByRef Values() As LongLong';New='ByRef Values() As Long'},
 @{Name='workspace must be array';Old='ByRef Values() As LongLong';New='ByRef Values As LongLong'},
 @{Name='workspace count must be Long';Old='ByVal Count As Long';New='ByVal Count As LongLong'},
 @{Name='workspace preserve must be Boolean';Old='ByVal Preserve As Boolean';New='ByVal Preserve As Long'}
)){
 $cases+=@{Name=$mutation.Name;First=$managed.Replace($mutation.Old,$mutation.New);Second=$text;Expected=@();Code=3;Reason=5}
}
$cases+=@{Name='collection result must be Long';First=$memory.Replace('() As Long','() As Boolean');Second='';Expected=@();Code=3;Reason=5}
$cases+=@{Name='mark output cannot be numeric';First=$wrong;Second=$text;Expected=@();Code=3;Reason=5}
$wrong=$managed.Replace('ByRef PriorError As Long','ByRef PriorError() As Long')
$cases+=@{Name='error output cannot be array';First=$wrong;Second=$text;Expected=@();Code=3;Reason=5}
$wrong=$text.Replace('ByVal Index As LongLong, ','')
$cases+=@{Name='read and write missing argument';First=$managed;Second=$wrong;Expected=@();Code=3;Reason=5}
function Descriptor([string]$Name,[long[]]$Values){
 if($Values.Count -eq 0){return "@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 -1,ptr null,ptr null}"+$nl}
 $cells=($Values|ForEach-Object{'i64 '+$_}) -join ','
 return "@$Name.data = global [$($Values.Count) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Values.Count-1),ptr @$Name.data,ptr null}"+$nl
}
$globals="@test.context = global %ube.context zeroinitializer,align 8"+$nl
$functions=@()
$main=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
for($i=0;$i -lt $cases.Count;$i++){
 $c=$cases[$i]
 $globals+=Descriptor ('first'+$i) ($utf8.GetBytes($c.First))
 $globals+=Descriptor ('second'+$i) ($utf8.GetBytes($c.Second))
 $globals+=Descriptor ('expected'+$i) $c.Expected
 $functions+=@("define i32 @test.case$i(){",'entry:',"%r=call {i1,i64} @ube.proc.$check(ptr @test.context,ptr @first$i,ptr @second$i,ptr @expected$i,i64 $($c.Expected.Count),i64 $($c.Code),i64 $($c.Reason))",'%fresh=extractvalue {i1,i64} %r,0','%value=extractvalue {i1,i64} %r,1','%zero=icmp eq i64 %value,0','%ok=and i1 %fresh,%zero','%reason=mul i64 %value,1000',"%tag=add i64 %reason,$($i+1)",'%result=trunc i64 %tag to i32','%exit=select i1 %ok,i32 0,i32 %result','ret i32 %exit','}')
 $main+=@("case$($i):","%r$i=call i32 @test.case$i()","%ok$i=icmp eq i32 %r$i,0","br i1 %ok$i,label %case$($i+1),label %failed$i","failed$($i):","ret i32 %r$i")
}
$main+=@("case$($cases.Count):",'%dispose=call i1 @ube.context.dispose(ptr @test.context)','%exit=select i1 %dispose,i32 0,i32 254','ret i32 %exit','failed:','ret i32 255','}')
$combined=$production+$nl+$globals+($functions -join $nl)+$nl+($main -join $nl)
$path=Join-Path $artifacts 'roles.ll'
Write-Text $path $combined
Write-Text (Join-Path $artifacts 'cases.txt') ((0..($cases.Count-1)|ForEach-Object{"$($_+1) $($cases[$_].Name)"}) -join $nl)
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("roles-$level.exe")
 Build $path $exe $level
 $r=Invoke-BoundedProcess $exe @()
 Require ($r.ExitCode -eq 0) "Managed primitive assertions failed $level exit $($r.ExitCode): $($r.Evidence); see cases.txt"
 Write-Output "PASS $level : $($cases.Count) managed/text role cases, exact IDs and unchanged failed role maps"
}
$negative=$combined.Replace('@expected0.data = global [20 x i64] [i64 38,','@expected0.data = global [20 x i64] [i64 39,')
Require ($negative -cne $combined) 'Missing role-ID negative-control substitution'
$path=Join-Path $artifacts 'negative.ll'
Write-Text $path $negative
$exe=Join-Path $artifacts 'negative.exe'
Build $path $exe 'O2'
$r=Invoke-BoundedProcess $exe @()
Require ($r.ExitCode -eq 8001) 'Changed expected role ID must fail assertion8/case1'
Write-Output "PASS changed-role-ID oracle negative control. Evidence: $artifacts"
