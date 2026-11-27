# Independent rational IEEE arithmetic oracle; no production host FP dependency.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Numerics
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube floating arithmetic '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $artifacts;Write-Output "Evidence: $artifacts"
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' ')}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();$err=[IO.File]::ReadAllText($prefix+'.stderr');if($p.ExitCode -ne $Expected -or $err){throw "Exit $($p.ExitCode), expected $Expected`: $err Evidence $prefix"}}finally{$p.Dispose()}
}
. (Join-Path $PSScriptRoot 'rational-oracle.ps1')
$lines=New-Object 'Collections.Generic.List[string]'
$lines.Add(@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private Function ArithmeticCase(ByVal LeftBits As LongLong, ByVal RightBits As LongLong, ByVal BitWidth As Long, ByVal Operation As Long, ByVal Expected As LongLong, ByVal Failure As Long) As Boolean
    Dim Value As LongLong = 123
    Dim Status As Boolean
    Status = FilePrimitives.SetError(57)
    Status = BinaryFloatMath.TryBinary(LeftBits, RightBits, BitWidth, Operation, Value)
    If Failure <> 0 Then ArithmeticCase = Not Status And Value = 123 And Err.Number = Failure: Exit Function
    If Not Status Then Exit Function
    ArithmeticCase = Value = Expected And Err.Number = 57
End Function
Private Function CompareCase(ByVal LeftBits As LongLong, ByVal RightBits As LongLong, ByVal BitWidth As Long, ByVal Expected As Long, ByVal ExpectedUnordered As Boolean, ByVal Failure As Long) As Boolean
    Dim Order As Long = 123
    Dim Unordered As Boolean
    Dim Status As Boolean
    Status = FilePrimitives.SetError(57)
    Status = BinaryFloatMath.TryCompare(LeftBits, RightBits, BitWidth, Order, Unordered)
    If Failure <> 0 Then CompareCase = Not Status And Order = 123 And Not Unordered And Err.Number = Failure: Exit Function
    If Not Status Then Exit Function
    CompareCase = Order = Expected And Unordered = ExpectedUnordered And Err.Number = 57
End Function
Private Function InvalidCases() As Boolean
    Dim Value As LongLong = 123
    Dim Order As Long = 42
    Dim Unordered As Boolean = True
    If BinaryFloatMath.TryBinary(0, 0, 64, 5, Value) Then Exit Function
    If Value <> 123 Or Err.Number <> 5 Then Exit Function
    If BinaryFloatMath.TryBinary(0, 0, 16, 1, Value) Then Exit Function
    If Value <> 123 Or Err.Number <> 5 Then Exit Function
    If BinaryFloatMath.TryBinary(-1, 0, 32, 1, Value) Then Exit Function
    If Value <> 123 Or Err.Number <> 5 Then Exit Function
    If BinaryFloatMath.TryCompare(0, -1, 32, Order, Unordered) Then Exit Function
    If Order <> 42 Or Not Unordered Or Err.Number <> 5 Then Exit Function
    InvalidCases = True
End Function
'@)
$script:cases=0;$script:pairs=0;$random=New-Object Random(70113)
function Pair([string]$Left,[string]$Right,[int]$W){
 $script:pairs++;$lines.Add("Private Function Pair$script:pairs() As Boolean")
 foreach($op in @(1,2,3,4)){
  $a=Decode $Left $W;$b=Decode $Right $W;$failure=0;$expected='123'
  if($a.Kind -ne 0 -or $b.Kind -ne 0){$failure=6}elseif($op -eq 4 -and $b.N -eq 0){$failure=11}else{
   $expected=Expected $Left $Right $W $op
   if((Decode $expected $W).Kind -ne 0){$failure=6;$expected='123'}
  }
  $script:cases++
  $lines.Add("If Not ArithmeticCase($Left^, $Right^, $W, $op, $expected^, $failure) Then Exit Function")
 }
 $a=Decode $Left $W;$b=Decode $Right $W;$order=0;$unordered=$a.Kind -eq 2 -or $b.Kind -eq 2
 if(-not $unordered){
  if($a.Kind -eq 1 -or $b.Kind -eq 1){
   if($a.Kind -eq 1 -and $b.Kind -eq 1){if($a.Negative -ne $b.Negative){$order=1;if($a.Negative){$order=-1}}}
   elseif($a.Kind -eq 1){$order=1;if($a.Negative){$order=-1}}else{$order=-1;if($b.Negative){$order=1}}
  }else{$an=$a.N;$bn=$b.N;if($a.Negative){$an=-$an};if($b.Negative){$bn=-$bn};$order=[Numerics.BigInteger]::Compare($an*$b.D,$bn*$a.D)}
 }
 $failure=0;if($a.Kind -ne 0 -or $b.Kind -ne 0){$failure=6}
 $lines.Add("If Not CompareCase($Left^, $Right^, $W, $order, $unordered, $failure) Then Exit Function")
 $lines.Add("Pair$script:pairs = True");$lines.Add('End Function')
}
foreach($w in @(32,64)){
 $p=53;$bias=1023;$maxfield=2047;if($w -eq 32){$p=24;$bias=127;$maxfield=255}
 $unit=P2 ($p-1);$one=$bias*$unit;$max=($maxfield-1)*$unit+$unit-1
 $values=@('0',(Encoding 0 $true $w),'1',($unit-1).ToString(),$unit.ToString(),$one.ToString(),(Encoding $one $true $w),($one+1).ToString(),$max.ToString(),(Special 1 $false $w),(Special 1 $true $w),(Special 2 $false $w))
 foreach($a in $values){foreach($b in @('0',$one.ToString(),(Encoding $one $true $w),(Special 1 $false $w))){Pair $a $b $w}}
 Pair $max '1' $w;Pair $max $max $w;Pair '1' '2' $w;Pair ($unit-1).ToString() '1' $w
 Pair ($one+1).ToString() $one.ToString() $w
 $half=($bias-1)*$unit;$halfUlp=($bias-$p)*$unit
 Pair '1' $half.ToString() $w
 Pair '3' $half.ToString() $w
 Pair $one.ToString() $halfUlp.ToString() $w
 Pair ($one+1).ToString() $halfUlp.ToString() $w
 Pair $unit.ToString() (Encoding 1 $true $w) $w
 Pair ($one+1).ToString() (Encoding $one $true $w) $w
 Pair (Encoding 0 $true $w) (Encoding 0 $true $w) $w
 for($i=0;$i -lt 16;$i++){
  $a=$random.Next(0,$maxfield)*$unit+([Numerics.BigInteger]$random.Next(0,1000000)*($unit/1000000))
  $b=$random.Next(0,$maxfield)*$unit+([Numerics.BigInteger]$random.Next(0,1000000)*($unit/1000000))
  Pair (Encoding $a ($i%2 -eq 0) $w) (Encoding $b ($i%3 -eq 0) $w) $w
 }
}
$lines.Add('Public Function Main() As Long')
$lines.Add('If Not InvalidCases() Then Main = 250: Exit Function')
for($i=1;$i -le $script:pairs;$i++){$lines.Add("If Not Pair$i() Then Main = $i`: Exit Function")}
$lines.Add('End Function')
$source=Join-Path $artifacts 'Probe.bas';[IO.File]::WriteAllText($source,($lines -join "`r`n")+"`r`n",$utf8)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'));$modules=@('BinaryFloatMath','BinaryFloatValues','BufferPrimitives','FilePrimitives')
foreach($name in $modules){Copy-Item -LiteralPath (Join-Path $repo "std-lib/src/portable/$name.bas") -Destination $artifacts}
foreach($level in @('0','2')){
 $manifest=Join-Path $artifacts ('Project'+$level+'.UBE');$text="UBE-Project 1`r`nName = `"FloatingMathTest`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in ($modules+@('Probe'))){$text+="Source = `"$name.bas`"`r`n"};[IO.File]::WriteAllText($manifest,$text,$utf8)
 $exe=Join-Path $artifacts ('Probe'+$level+'.exe');Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);Run $exe @()
 Write-Output "PASS O$level $script:cases exact arithmetic cases and $($script:cases/4) comparisons"
 $original=[IO.File]::ReadAllText($source,$utf8);$changed=$original.Replace('Value = Expected And Err.Number = 57','Value = Expected + 1 And Err.Number = 57')
 if($original -ceq $changed){throw 'Missing negative control marker'};[IO.File]::WriteAllText($source,$changed,$utf8)
 $exe=Join-Path $artifacts ('Negative'+$level+'.exe');Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);Run $exe @() 1
 [IO.File]::WriteAllText($source,$original,$utf8);Write-Output "PASS O$level changed-oracle negative control"
}
