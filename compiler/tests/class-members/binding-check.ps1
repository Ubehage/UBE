param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube instance binding '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $out=Join-Path $evidence ($Name+'.stdout');$err=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;WorkingDirectory=$evidence;RedirectStandardOutput=$out;RedirectStandardError=$err}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(180000)){$p.Kill();throw "Deadline $Name"};$p.Refresh();return [pscustomobject]@{Code=$p.ExitCode;Log=([IO.File]::ReadAllText($out)+[IO.File]::ReadAllText($err))}}finally{$p.Dispose()}
}
$cases=@(
 @('implicit',"Public Value As Long`nSub Run()`nValue = 4`nEnd Sub",'',0,0,0,1,0,0),
 @('explicit-me',"Public Value As Long`nSub Run()`nMe.Value = 4`nEnd Sub",'',0,0,1,1,1,0),
 @('method',"Function Read() As Long`nRead = 6`nEnd Function", "Sub Run()`nDim Item As Gate`nDim Value As Long = Item.Read()`nEnd Sub",0,0,0,0,2,0),
 @('implicit-method',"Function Read() As Long`nRead = 6`nEnd Function`nSub Run()`nDim Value As Long = Read()`nEnd Sub",'',0,0,0,0,0,0),
 @('me-result',"Function Self() As Gate`nSet Self = Me`nEnd Function",'',0,0,1,0,0,0),
 @('grouped-me',"Sub Take(ByRef Item As Gate)`nEnd Sub`nSub Run()`nTake (Me)`nEnd Sub",'',0,0,2,0,0,1),
 @('me-direct-ref',"Sub Take(ByRef Item As Gate)`nEnd Sub`nSub Run()`nTake Me`nEnd Sub",'',10,12,0,0,0,0),
 @('me-write',"Sub Run()`nSet Me = Nothing`nEnd Sub",'',3,21,0,0,0,0),
 @('private',"Private Value As Long", "Sub Run()`nDim Item As Gate`nItem.Value = 4`nEnd Sub",2,12,0,0,0,0),
 @('default-private',"Dim Value As Long", "Sub Run()`nDim Item As Gate`nItem.Value = 4`nEnd Sub",2,12,0,0,0,0),
 @('global-leak',"Public Value As Long", "Sub Run()`nValue = 4`nEnd Sub",2,10,0,0,0,0),
 @('static-class',"Public Value As Long", "Sub Run()`nGate.Value = 4`nEnd Sub",3,11,0,0,0,0),
 @('me-module','',"Sub Run()`nDim Item As Gate`nSet Item = Me`nEnd Sub",3,18,0,0,0,0),
 @('array',"Public Values() As Long",'',8,11,0,0,0,0),
 @('initializer',"Public Value As Long = 1",'',8,11,0,0,0,0),
 @('initialize',"Private Sub Class_Initialize()`nEnd Sub",'',8,50,0,0,0,0),
 @('terminate',"Private Sub [CLASS_TERMINATE]()`nEnd Sub",'',8,50,0,0,0,0),
 @('intrinsic',"Public Intrinsic Sub Run()`nEnd Sub",'',3,42,0,0,0,0),
 @('thread',"Sub Run()`nEnd Sub", "Sub Start()`nDim Item As Gate`nCallNew Item.Run()`nEnd Sub",3,17,0,0,0,0),
 @('me-initializer',"Public Value As Long`nSub Run()`nDim X As Long = Me.Value`nEnd Sub",'',3,18,0,0,0,0)
)
$dependencies=@()
foreach($name in @('BufferPrimitives','FilePrimitives','ByteText','Utf8','InvariantNumbers','BinaryFloat','BinaryFloatValues','BinaryFloatMath','BinaryFloatPower','BinaryFloatText')){$dependencies+=Join-Path $root ('std-lib/src/portable/'+$name+'.bas')}
foreach($name in @('SourceScanner','SyntaxTokens','SourceParser','ProjectSyntax','DeclarationBinder','ConstantValues','ConstantText','ConditionalExpressions','ConditionalSource','ExpressionBinder','ManagedLayouts','AggregateLayout')){$dependencies+=Join-Path $root ('compiler/src/'+$name+'.bas')}
foreach($path in $dependencies){Copy-Item -LiteralPath $path -Destination $evidence}
$generated=New-Object Text.StringBuilder
for($i=0;$i -lt $cases.Count;$i++){
 $case=$cases[$i]
 $source="UBE SOURCE 1 CLASS`nAttribute UBE_Name = `"Gate`"`n"+$case[1]+"`n"
 $caller="UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Caller`"`n"+$case[2]+"`n"
 $arrays=@([Text.Encoding]::UTF8.GetBytes($source),[Text.Encoding]::UTF8.GetBytes($caller))
 for($v=0;$v -lt 2;$v++){
  $bytes=$arrays[$v]
  for($part=0;$part -lt $bytes.Length;$part+=24){
   $null=$generated.AppendLine("Private Sub Fill${i}Array${v}Part$part(ByRef B() As Byte)")
   for($n=$part;$n -lt [Math]::Min($part+24,$bytes.Length);$n++){$null=$generated.AppendLine("B($n) = $($bytes[$n])")}
   $null=$generated.AppendLine('End Sub')
  }
 }
 $null=$generated.AppendLine("Private Function Case$i() As Boolean`r`nDim B(0 To $($arrays[0].Length-1)) As Byte`r`nDim C(0 To $($arrays[1].Length-1)) As Byte")
 for($v=0;$v -lt 2;$v++){$var='B';if($v){$var='C'};for($part=0;$part -lt $arrays[$v].Length;$part+=24){$null=$generated.AppendLine("Fill${i}Array${v}Part$part $var")}}
 $null=$generated.AppendLine("Case$i = Check(B, C, $($case[3]), $($case[4]), $($case[5]), $($case[6]), $($case[7]), $($case[8]))`r`nEnd Function")
}
$null=$generated.AppendLine("Public Function Main() As Long`r`nDim Passed As Boolean`r`nOn Error GoTo Unexpected")
for($i=0;$i -lt $cases.Count;$i++){$null=$generated.AppendLine("Main = $($i+1)`r`nPassed = False`r`nPassed = Case$i()`r`nIf Not Passed Then Exit Function")}
$null=$generated.AppendLine("Main = 0`r`nExit Function`r`nUnexpected:`r`nMain = 99`r`nEnd Function")
$body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'binding-probe.bas'),$utf).Replace("' GENERATED CASES",$generated.ToString())
foreach($level in @('0','2')){foreach($control in @(0,1,2)){
 $name="binding-o$level-control$control";$expected=0;$candidate=$body
 if($control -eq 1){$candidate=$candidate.Replace('Private Const Control As Long = 0','Private Const Control As Long = 1');$expected=1}
 if($control -eq 2){$candidate=$candidate.Replace('Passed = Case0()','Passed = UnexpectedFailure()');$expected=99}
 [IO.File]::WriteAllText((Join-Path $evidence ($name+'.bas')),$candidate,$utf)
 $lines=@('UBE-Project 1','Name = "ContextTests"','Kind = "Exe"','Startup = "Main"',('Optimization = "'+$level+'"'))
 $lines+=@($dependencies|ForEach-Object{'Source = "'+[IO.Path]::GetFileName($_)+'"'});$lines+='Source = "'+$name+'.bas"'
 $project=Join-Path $evidence ($name+'.UBE');[IO.File]::WriteAllText($project,($lines -join "`r`n")+"`r`n",$utf)
 $exe=Join-Path $evidence ($name+'.exe');$r=Run $CompilerExe @('--build',$project,$exe,'--clang',$Clang) ($name+'-build')
 if($r.Code -ne 0){throw "Build failed $name $($r.Log)"}
 $r=Run $exe @() ($name+'-run');if($r.Code -ne $expected -or $r.Log.Length -ne 0){throw "Assertion failed $name expected=$expected actual=$($r.Code) $($r.Log)"}
 Write-Output "PASS $name cases=$($cases.Count)  exit=$expected"
}}
