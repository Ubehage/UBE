# Executes managed support role resolution through the actual UBE parser and declaration binder.
param([Parameter(Mandatory=$true)][string]$BootstrapExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube managed support roles '+[guid]::NewGuid())
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
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/ByteText.bas','std-lib/src/portable/Utf8.bas','std-lib/src/portable/InvariantNumbers.bas','compiler/src/SourceScanner.bas','compiler/src/SyntaxTokens.bas','compiler/src/SourceParser.bas','compiler/src/ProjectSyntax.bas','compiler/src/DeclarationBinder.bas','compiler/src/ConstantValues.bas','compiler/src/ConstantText.bas','compiler/src/ExpressionBinder.bas','compiler/src/ManagedSupport.bas','runtime/tests/managed-text/SupportProbe.bas')
$files+='compiler/src/ManagedSourceAssets.bas'
$manifest=@('UBE-Project 1','Name="SupportTests"','Kind="Library"')
foreach($file in $files){$leaf=[IO.Path]::GetFileName($file);Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $artifacts $leaf);$manifest+='Source="'+$leaf+'"'}
$project=Join-Path $artifacts 'project.UBE'
Write-Text $project (($manifest -join "`r`n")+"`r`n")
Write-Output "Artifacts retained: $artifacts"
$r=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$project)
Require ($r.ExitCode -eq 0 -and $r.Stdout -match '(?m)^SYMBOL (\d+)\|function\|Check\|') "Binding failed: $($r.Evidence)"
$check=$Matches[1]
Require ($r.Stdout -match '(?m)^SYMBOL (\d+)\|function\|CheckNeed\|') 'Missing syntax selection probe'
$checkNeed=$Matches[1]
Require ($r.Stdout -match '(?m)^SYMBOL (\d+)\|function\|CheckAsset\|') 'Missing asset identity probe'
$checkAsset=$Matches[1]
Require ($r.Stdout -match '(?m)^SYMBOL (\d+)\|function\|CheckProjectAssets\|') 'Missing private source span probe'
$checkProjectAssets=$Matches[1]
$ir=Join-Path $artifacts 'production.ll'
$r=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$project,$ir)
Require ($r.ExitCode -eq 0 -and $r.Stdout -match 'EMIT OK') "Emission failed: $($r.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
$text=@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Text"
Public Function Concat(ByVal Left As String, ByVal Right As String) As String
Concat = Left
End Function
Public Function CompareBinary(ByVal Left As String, ByVal Right As String) As Long
CompareBinary = 0
End Function
Public Function FromInteger(ByVal Value As LongLong) As String
Exit Function
End Function
Public Function FromBoolean(ByVal Value As Boolean) As String
Exit Function
End Function
Public Function ToInteger(ByVal Value As String, ByVal Minimum As LongLong, ByVal Maximum As LongLong) As LongLong
ToInteger = 0
End Function
Public Function ToBoolean(ByVal Value As String) As Boolean
ToBoolean = False
End Function
Public Function FromUtf8(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long) As String
Exit Function
End Function
'@
$collector=@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedMemory"
Public Function Collect(ByVal ReportFailure As Boolean) As Long
Collect = 0
End Function
'@
$numeric=@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "User"
Public Sub Work()
Exit Sub
End Sub
'@
$cases=@(
 @{Name='exact private roles ignore public collisions';Public=$text;Text=$text;Collector=$collector;Domain=1;Reason=0;Expected=@(11..18)},
 @{Name='case folded role identities';Public=$text;Text=$text.Replace('"Text"','"tExT"').Replace('Concat','cOnCaT');Collector=$collector;Domain=1;Reason=0;Expected=@(11..18)},
 @{Name='numeric needs no roles';Public=$numeric;Text='';Collector='';Domain=1;Reason=0;Expected=@(0,0,0,0,0,0,0,0)},
 @{Name='public names never grant roles';Public=$numeric;Text=$text;Collector=$collector;Domain=0;Reason=81},
 @{Name='missing private collector';Public=$text;Text=$text;Collector='';Domain=1;Reason=81},
 @{Name='wrong support module';Public=$text;Text=$text.Replace('"Text"','"Other"');Collector=$collector;Domain=1;Reason=81},
 @{Name='wrong parameter passing';Public=$text;Text=$text.Replace('ByVal Left As String','ByRef Left As String');Collector=$collector;Domain=1;Reason=82},
 @{Name='wrong result type';Public=$text;Text=$text.Replace('CompareBinary(ByVal Left As String, ByVal Right As String) As Long','CompareBinary(ByVal Left As String, ByVal Right As String) As LongLong');Collector=$collector;Domain=1;Reason=82},
 @{Name='wrong byte rank';Public=$text;Text=$text.Replace('ByRef Bytes() As Byte','ByRef Bytes As Byte');Collector=$collector;Domain=1;Reason=82},
 @{Name='private callable role';Public=$text;Text=$text.Replace('Public Function FromBoolean','Private Function FromBoolean');Collector=$collector;Domain=1;Reason=82},
 @{Name='empty role body';Public=$text;Text=$text.Replace('Concat = Left','');Collector=$collector;Domain=1;Reason=82},
 @{Name='wrong collector signature';Public=$text;Text=$text;Collector=$collector.Replace('ReportFailure As Boolean','ReportFailure As Long');Domain=1;Reason=82},
 @{Name='private support initializer refused';Public=$text;Text=$text.Replace('Public Function Concat',"Private State As Long = 1`r`nPublic Function Concat");Collector=$collector;Domain=1;Reason=83}
)
$cases+=@{Name='authoritative Text and collector declarations';Public=$numeric;Text=[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/Text.bas'),$utf8);Collector=[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/ManagedMemory.bas'),$utf8);Domain=1;Reason=0;Expected=@(8,9,10,11,12,13,6,15)}
function Descriptor([string]$Name,[long[]]$Values){
 if($Values.Count -eq 0){return "@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 -1,ptr null,ptr null}`r`n"}
 $cells=($Values|ForEach-Object{'i64 '+$_}) -join ','
 return "@$Name.data = global [$($Values.Count) x i64] [$cells]`r`n@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Values.Count-1),ptr @$Name.data,ptr null}`r`n"
}
$globals="@test.context = global %ube.context zeroinitializer,align 8`r`n"
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init=call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
for($i=0;$i -lt $cases.Count;$i++){
 $c=$cases[$i]
 foreach($name in @('Public','Text','Collector')){$globals+=Descriptor ($name+$i) ($utf8.GetBytes($c[$name]))}
 $expected=@(0,0,0,0,0,0,0,0);if($c.ContainsKey('Expected')){$expected=$c.Expected}
 $globals+=Descriptor ('expected'+$i) $expected
 $code+=@("case$($i):","%r$i=call {i1,i64} @ube.proc.$check(ptr @test.context,ptr @Public$i,ptr @Text$i,ptr @Collector$i,ptr @expected$i,i64 $($c.Domain),i64 $($c.Reason))","%fresh$i=extractvalue {i1,i64} %r$i,0","%value$i=extractvalue {i1,i64} %r$i,1","%zero$i=icmp eq i64 %value$i,0","%ok$i=and i1 %fresh$i,%zero$i","br i1 %ok$i,label %case$($i+1),label %failed$i","failed$($i):","%reason$i=mul i64 %value$i,100","%tag$i=add i64 %reason$i,$($i+1)","%exit$i=trunc i64 %tag$i to i32","ret i32 %exit$i")
}
$nl=[Environment]::NewLine
$needs=@(
 @{Body='Public Intrinsic Function CollectGarbage() As Long'+$nl+'Attribute CollectGarbage.UBE_Primitive = "Memory.Collect"'+$nl+'End Function';Expected=-1},
 @{Body='Public Intrinsic Function CollectGarbage() As Long'+$nl+'Attribute CollectGarbage.UBE_Primitive = "Memory.CollectMore"'+$nl+'End Function';Expected=0},
 @{Body='Public Value As Long';Expected=0},
 @{Body='Public Value As String';Expected=-1},
 @{Body='Public Value$';Expected=-1},
 @{Body="Public Sub Work()`r`nDim Value As Long`r`nValue = 1 & 2`r`nEnd Sub";Expected=-1},
 @{Body="Public Sub Work()`r`nDim Value As Long`r`nValue = `"`"`r`nEnd Sub";Expected=-1},
 @{Body="Public Type Record`r`nValue As String`r`nEnd Type";Expected=-1},
 @{Body="Public Intrinsic Function Begin(ByRef Work As Long, ByRef Number As Long) As Boolean`r`nAttribute Begin.UBE_Primitive = `"Managed.BeginCollection`"`r`nEnd Function";Expected=-1},
 @{Body="Public Intrinsic Function Record(ByVal Number As Long) As Boolean`r`nAttribute Record.UBE_Primitive = `"Error.Set`"`r`nEnd Function";Expected=0}
)
for($i=0;$i -lt $needs.Count;$i++){
 $ordinal=$cases.Count+$i
 $source="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"String`"`r`n"+$needs[$i].Body+"`r`n"
 $globals+=Descriptor ('need'+$i) ($utf8.GetBytes($source))
 $code+=@("case$($ordinal):","%need$i=call {i1,i64} @ube.proc.$checkNeed(ptr @test.context,ptr @need$i,i64 $($needs[$i].Expected))","%need.fresh$i=extractvalue {i1,i64} %need$i,0","%need.value$i=extractvalue {i1,i64} %need$i,1","%need.zero$i=icmp eq i64 %need.value$i,0","%need.ok$i=and i1 %need.fresh$i,%need.zero$i","br i1 %need.ok$i,label %case$($ordinal+1),label %need.failed$i","need.failed$($i):","ret i32 $($ordinal+1)")
}
$assetEntries=@([IO.File]::ReadAllLines((Join-Path $root 'runtime/managed-support-sources.txt'),$utf8)|ForEach-Object{$_.Trim()}|Where-Object{$_ -and -not $_.StartsWith('#')})
$assetCases=@()
for($i=0;$i -lt $assetEntries.Count;$i++){$assetCases+=@{Bytes=[IO.File]::ReadAllBytes((Join-Path $root $assetEntries[$i]));Identity=$i;Expected=-1}}
$changed=[byte[]]$assetCases[0].Bytes.Clone();$changed[0]=86
$assetCases+=@{Bytes=$changed;Identity=0;Expected=0}
$swapped=[byte[]]$assetCases[0].Bytes.Clone();$swap=$swapped[0];$swapped[0]=$swapped[1];$swapped[1]=$swap
$assetCases+=@{Bytes=$swapped;Identity=0;Expected=0}
$normalized=$utf8.GetString($assetCases[0].Bytes).Replace("`r`n","`n")
$assetCases+=@{Bytes=$utf8.GetBytes($normalized);Identity=0;Expected=-1}
$assetCases+=@{Bytes=$utf8.GetBytes($normalized.Replace("`n","`r`n"));Identity=0;Expected=-1}
$assetCases+=@{Bytes=$assetCases[0].Bytes;Identity=-1;Expected=0}
for($i=0;$i -lt $assetCases.Count;$i++){
 $ordinal=$cases.Count+$needs.Count+$i
 $globals+=Descriptor ('asset'+$i) $assetCases[$i].Bytes
 $code+=@("case$($ordinal):","%asset$i=call {i1,i64} @ube.proc.$checkAsset(ptr @test.context,ptr @asset$i,i64 $($assetCases[$i].Identity),i64 $($assetCases[$i].Expected))","%asset.fresh$i=extractvalue {i1,i64} %asset$i,0","%asset.value$i=extractvalue {i1,i64} %asset$i,1","%asset.zero$i=icmp eq i64 %asset.value$i,0","%asset.ok$i=and i1 %asset.fresh$i,%asset.zero$i","br i1 %asset.ok$i,label %case$($ordinal+1),label %asset.failed$i","asset.failed$($i):","ret i32 $($ordinal+1)")
}
$projectBytes=New-Object Collections.Generic.List[byte]
$starts=@();$sizes=@()
for($i=0;$i -lt $assetEntries.Count;$i++){$starts+=$projectBytes.Count;$sizes+=$assetCases[$i].Bytes.Length;$projectBytes.AddRange([byte[]]$assetCases[$i].Bytes)}
$globals+=Descriptor 'projectBytes' $projectBytes.ToArray()
$globals+=Descriptor 'projectStarts' $starts
$globals+=Descriptor 'projectSizes' $sizes
for($i=0;$i -lt 12;$i++){
 $ordinal=$cases.Count+$needs.Count+$assetCases.Count+$i
 $expected=0;if($i -eq 0 -or $i -eq 9){$expected=-1}
 $code+=@("case$($ordinal):","%project$i=call {i1,i64} @ube.proc.$checkProjectAssets(ptr @test.context,ptr @projectBytes,ptr @projectStarts,ptr @projectSizes,i64 $i,i64 $expected)","%project.fresh$i=extractvalue {i1,i64} %project$i,0","%project.value$i=extractvalue {i1,i64} %project$i,1","%project.zero$i=icmp eq i64 %project.value$i,0","%project.ok$i=and i1 %project.fresh$i,%project.zero$i","br i1 %project.ok$i,label %case$($ordinal+1),label %project.failed$i","project.failed$($i):","ret i32 $($ordinal+1)")
}
$code+=@("case$($cases.Count+$needs.Count+$assetCases.Count+12):",'%dispose=call i1 @ube.context.dispose(ptr @test.context)','%exit=select i1 %dispose,i32 0,i32 254','ret i32 %exit','failed:','ret i32 255','}')
$combined=$production+"`r`n"+$globals+($code -join "`r`n")
$path=Join-Path $artifacts 'roles.ll'
Write-Text $path $combined
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts ("roles-$level.exe")
 Build $path $exe $level
 $r=Invoke-BoundedProcess $exe @()
 Require ($r.ExitCode -eq 0) "Role assertions failed $level exit $($r.ExitCode): $($r.Evidence)"
 Write-Output "PASS $level : $($cases.Count) role identity/signature/isolation/publication, $($needs.Count) syntax selection, $($assetCases.Count) source identities and 12 project span cases"
}
# Wrong independent expected identity must fail the first exact role check.
$negative=$combined.Replace('@expected0.data = global [8 x i64] [i64 11,','@expected0.data = global [8 x i64] [i64 12,')
Require ($negative -cne $combined) 'Missing negative-control substitution'
$path=Join-Path $artifacts 'negative.ll'
Write-Text $path $negative
$exe=Join-Path $artifacts 'negative.exe'
Build $path $exe 'O2'
$r=Invoke-BoundedProcess $exe @()
Require ($r.ExitCode -eq 801) 'Changed expected role identity must fail assertion8/case1'
Write-Output "PASS changed-role oracle negative control. Evidence: $artifacts"
