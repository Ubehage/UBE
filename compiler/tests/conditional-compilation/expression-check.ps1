param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube conditional expressions '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $out=Join-Path $evidence ($Name+'.stdout');$err=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;WorkingDirectory=$evidence;RedirectStandardOutput=$out;RedirectStandardError=$err}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(120000)){$p.Kill();throw "Deadline $Name"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing exit $Name"};return [pscustomobject]@{Code=$p.ExitCode;ErrorText=[IO.File]::ReadAllText($err);Log=([IO.File]::ReadAllText($out)+[IO.File]::ReadAllText($err))}}finally{$p.Dispose()}
}
# Expectations are independently authored; numeric payloads use the host IEEE encoder only.
$cases=@(
 @('False',0,153,0,0,0,''), @('True',0,153,-1,0,0,''),
 @('IS_IN_IDE',0,153,0,0,0,''), @('[Is_In_IdE]',-1,153,-1,0,0,''),
 @('IS_IN_IDE',0,153,0,0,0,''), @('n Xor 2%',0,155,5,0,0,''),
 @('8 * 3 \ 2',0,156,12,0,0,''), @('10 * 3 Mod 4',0,156,2,0,0,''),
 @('1 + 2 & "x"',0,163,0,0,0,'3x'), @('"x" & 1 + 2',0,163,0,0,0,'x3'),
 @('8 * 5 Mod 3',0,156,1,0,0,''), @('8 \ 5 * 3',0,156,0,0,0,''),
 @('8 \ 5 Mod 3',0,156,1,0,0,''), @('8 \ 5 / 3',0,157,4,0,0,''),
 @('8 + 5 Mod 3',0,156,10,0,0,''), @('8 - 5 Mod 3',0,156,6,0,0,''),
 @('-2 * 3',0,156,-6,0,0,''), @('8 / 2 * 2',0,159,[BitConverter]::DoubleToInt64Bits(8),0,0,''),
 @('Not 1 = 2 And True',0,153,-1,0,0,''),
 @('False Xor False',0,153,0,0,0,''), @('False Xor True',0,153,-1,0,0,''),
 @('True Xor False',0,153,-1,0,0,''), @('True Xor True',0,153,0,0,0,''),
 @('False Eqv False',0,153,-1,0,0,''), @('False Eqv True',0,153,0,0,0,''),
 @('True Eqv False',0,153,0,0,0,''), @('True Eqv True',0,153,-1,0,0,''),
 @('False Imp False',0,153,-1,0,0,''), @('False Imp True',0,153,-1,0,0,''),
 @('True Imp False',0,153,0,0,0,''), @('True Imp True',0,153,-1,0,0,''),
 @('5 Xor 3',0,156,6,0,0,''), @('5 Eqv 3',0,156,-7,0,0,''), @('5 Imp 3',0,156,-5,0,0,''),
 @('1% Eqv 1&&',0,157,-1,0,0,''), @('False Or True And False',0,153,0,0,0,''),
 @('True Imp False Eqv False',0,153,-1,0,0,''),
 @('False AndAlso (1 \ 0 = 0)',0,153,0,0,0,''),
 @('True OrElse (2147483647 + 1 = 0)',0,153,-1,0,0,''),
 @('False AndAlso Missing',0,0,0,3,1,''), @('True OrElse 1',0,0,0,3,3,''),
 @('False AndAlso (1 + "x" = 0)',0,0,0,3,3,''),
 @('False And (1 \ 0 = 0)',0,0,0,6,4,''), @('1 \ 0',0,0,0,6,4,''),
 @('2147483647 + 1',0,0,0,6,2,''), @('-9223372036854775808&&',0,157,[long]::MinValue,0,0,''),
 @('-(-9223372036854775808&&)',0,0,0,6,2,''),
 @('3 / 2',0,159,[BitConverter]::DoubleToInt64Bits(1.5),0,0,''),
 @('1.5! + 0.5!',0,158,1073741824,0,0,''),
 @('1.5 And 2',0,0,0,3,3,''), @('True + False',0,0,0,3,3,''),
 @('word & "!"',0,163,0,0,0,'AbC!'), @('"a""b"',0,163,0,0,0,'a"b'),
 @('word = "AbC"',0,153,-1,0,0,''), @('"a" < "b"',0,153,-1,0,0,''),
 @('"abc" & True',0,163,0,0,0,'abcTrue'),
 @('"x" & (1 \ 0)',0,0,0,6,4,''),
 @('IS_IN_IDE()',0,0,0,2,6,''), @('IS_IN_IDE.Value',0,0,0,2,6,''),
 @('1 < 2 < 3',0,0,0,2,5,''), @('(1 + 2',0,0,0,2,3,''),
 @('1 + Not True',0,0,0,2,4,''), @('&HFF',0,0,0,6,1,''),
 @((('('*60)+'True'+(')'*60)),0,0,0,4,1,'')
)
$errorColumns=@{
 'False AndAlso Missing'=15; 'True OrElse 1'=6
 'False AndAlso (1 + "x" = 0)'=18; 'False And (1 \ 0 = 0)'=14; '1 \ 0'=3
 '2147483647 + 1'=12; '-(-9223372036854775808&&)'=1; '1.5 And 2'=5; 'True + False'=6
 '"x" & (1 \ 0)'=10; 'IS_IN_IDE()'=10; 'IS_IN_IDE.Value'=10; '1 < 2 < 3'=7
 '(1 + 2'=7; '1 + Not True'=5; '&HFF'=1
}
$errorColumns[(('('*60)+'True'+(')'*60))]=49
$modules=@('BufferPrimitives','FilePrimitives','ByteText','Utf8','InvariantNumbers','BinaryFloat','BinaryFloatValues','BinaryFloatMath','BinaryFloatPower','BinaryFloatText','ThreadPrimitives')
$sources=@()
foreach($name in $modules){$sources+=Join-Path $root ('std-lib/src/portable/'+$name+'.bas')}
foreach($name in @('SourceScanner','SyntaxTokens','SourceParser','ConstantValues','ConstantText','ConditionalExpressions')){$sources+=Join-Path $root ('compiler/src/'+$name+'.bas')}
foreach($path in $sources){Copy-Item -LiteralPath $path -Destination (Join-Path $evidence ([IO.Path]::GetFileName($path)))}
$generated=New-Object Text.StringBuilder
for($i=0;$i -lt $cases.Count;$i++){
 $case=$cases[$i];$bytes=[Text.Encoding]::UTF8.GetBytes($case[0]);$expected=[Text.Encoding]::UTF8.GetBytes($case[6])
 for($part=0;$part -lt $bytes.Length;$part+=24){
  $null=$generated.AppendLine("Private Sub Fill${i}Part$part(ByRef B() As Byte)")
  for($n=$part;$n -lt [Math]::Min($part+24,$bytes.Length);$n++){$null=$generated.AppendLine("B($n) = $($bytes[$n])")}
  $null=$generated.AppendLine('End Sub')
 }
 $null=$generated.AppendLine("Private Function Case$i() As Boolean")
 $null=$generated.AppendLine("Dim B(0 To $($bytes.Length-1)) As Byte")
 if($expected.Length){$null=$generated.AppendLine("Dim E(0 To $($expected.Length-1)) As Byte")}else{$null=$generated.AppendLine('Dim E() As Byte')}
 for($part=0;$part -lt $bytes.Length;$part+=24){$null=$generated.AppendLine("Fill${i}Part$part B")}
 for($n=0;$n -lt $expected.Length;$n++){$null=$generated.AppendLine("E($n) = $($expected[$n])")}
 $column=0;if($case[4] -ne 0){$column=$errorColumns[$case[0]];if($null -eq $column){throw 'Missing expected diagnostic column'}}
 $null=$generated.AppendLine("Case$i = Check(B, $($case[1])&&, $($case[2]), $($case[3])&&, $($case[4]), $($case[5]), $column, E)")
 $null=$generated.AppendLine('End Function')
}
$null=$generated.AppendLine("Public Function Main() As Long`r`nDim Accepted As Boolean`r`nOn Error GoTo Unexpected`r`nMain = 98`r`nAccepted = TextConversions()`r`nIf Not Accepted Then Exit Function`r`nMain = 97`r`nAccepted = False`r`nAccepted = InvalidInputs()`r`nIf Not Accepted Then Exit Function")
for($i=0;$i -lt $cases.Count;$i++){$null=$generated.AppendLine("Main = $($i+1)`r`nAccepted = False`r`nAccepted = Case$i()`r`nIf Not Accepted Then Exit Function")}
$null=$generated.AppendLine("Main = 0`r`nExit Function`r`nUnexpected:`r`nMain = 99`r`nEnd Function")
$body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'expression-probe.bas'),$utf).Replace("' GENERATED CASES",$generated.ToString())
[IO.File]::WriteAllLines((Join-Path $evidence 'cases.txt'),@($cases|ForEach-Object{$_ -join ' | '}),$utf)
foreach($level in @('0','2')){foreach($control in @(0,1)){
 $name="expressions-o$level-control$control"
 [IO.File]::WriteAllText((Join-Path $evidence ($name+'.bas')),$body.Replace('Private Const Control As Long = 0',"Private Const Control As Long = $control"),$utf)
 $lines=@('UBE-Project 1','Name = "ExpressionTests"','Kind = "Exe"','Startup = "Main"',('Optimization = "'+$level+'"'))
 $lines+=@($sources|ForEach-Object{'Source = "'+[IO.Path]::GetFileName($_)+'"'})
 $lines+='Source = "'+$name+'.bas"'
 $project=Join-Path $evidence ($name+'.UBE');[IO.File]::WriteAllText($project,($lines -join "`r`n")+"`r`n",$utf)
 $exe=Join-Path $evidence ($name+'.exe')
 $r=Run $CompilerExe @('--build',$project,$exe,'--clang',$Clang) ($name+'-build')
 if($r.Code -ne 0){throw "Build failed $name $($r.Log)"}
 $r=Run $exe @() ($name+'-run')
 if($r.Code -ne $control -or $r.ErrorText.Length -ne 0){throw "Assertion failed $name expected=$control actual=$($r.Code) $($r.Log)"}
 Write-Output "PASS $name cases=$($cases.Count) exit=$control"
}}
