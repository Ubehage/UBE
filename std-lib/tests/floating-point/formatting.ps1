# Independent exact rounding-interval oracle for shortest coefficient formatting.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Numerics
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube floating formatting '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $artifacts;Write-Output "Evidence: $artifacts"
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' ')}
 $timer=[Diagnostics.Stopwatch]::StartNew();$p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(120000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();$err=[IO.File]::ReadAllText($prefix+'.stderr');if($p.ExitCode -ne $Expected -or $err){throw "Exit $($p.ExitCode), expected $Expected`: $err Evidence $prefix"}}finally{$p.Dispose()}
 $timer.Stop();return $timer.Elapsed.TotalSeconds
}
function P2([int]$E){return [Numerics.BigInteger]::Pow(2,$E)}
function P10([int]$E){return [Numerics.BigInteger]::Pow(10,$E)}
function Rational([Numerics.BigInteger]$Bits,[int]$W){
 $p=53;$bias=1023;if($W -eq 32){$p=24;$bias=127}
 $unit=P2 ($p-1);$field=[int]($Bits/$unit);$m=$Bits%$unit;$e=1-$bias-($p-1)
 if($field -ne 0){$m+=$unit;$e=$field-$bias-($p-1)}
 $n=$m;$d=[Numerics.BigInteger]::One;if($e -ge 0){$n*=P2 $e}else{$d=P2 (-$e)}
 return @{N=$n;D=$d}
}
function Render([Numerics.BigInteger]$C,[int]$E,[bool]$Negative){
 while($C%10 -eq 0 -and $C -ne 0){$C/=10;$E++}
 $digits=$C.ToString();$position=$digits.Length+$E
 if($E -ge 0){$fixed=$digits+('0'*$E)}elseif($position -gt 0){$fixed=$digits.Insert($position,'.')}else{$fixed='0.'+('0'*(-$position))+$digits}
 $scientific=$digits.Substring(0,1);if($digits.Length -gt 1){$scientific+='.'+$digits.Substring(1)}
 $power=$E+$digits.Length-1;if($power -ne 0){$scientific+='E'+$power.ToString([Globalization.CultureInfo]::InvariantCulture)}
 $text=$scientific;if($fixed.Length -le $scientific.Length){$text=$fixed};if($Negative){$text='-'+$text};return $text
}
function Expected([string]$Bits,[int]$W){
 $v=[Numerics.BigInteger]::Parse($Bits);$negative=$v -lt 0
 if($W -eq 32){$negative=$v -ge (P2 31);if($negative){$v-=P2 31}}elseif($negative){$v+=P2 63}
 $p=53;$limit=17;$maxfield=2047;if($W -eq 32){$p=24;$limit=9;$maxfield=255}
 $unit=P2 ($p-1);$infinity=$maxfield*$unit
 if($v -gt $infinity){return 'NaN'}
 if($v -eq $infinity){if($negative){return '-Infinity'};return 'Infinity'}
 if($v -eq 0){if($negative){return '-0'};return '0'}
 $x=Rational $v $W;$previous=Rational ($v-1) $W
 $loN=$x.N*$previous.D+$previous.N*$x.D;$loD=2*$x.D*$previous.D
 $closed=$v.IsEven
 if($v -eq $infinity-1){$hiN=$x.N;$hiD=$x.D;$hiClosed=$true}else{
  $next=Rational ($v+1) $W;$hiN=$x.N*$next.D+$next.N*$x.D;$hiD=2*$x.D*$next.D;$hiClosed=$closed
 }
 $order=$x.N.ToString().Length-$x.D.ToString().Length
 if($order -ge 0){if($x.N -lt $x.D*(P10 $order)){$order--}}else{if($x.N*(P10 (-$order)) -lt $x.D){$order--}}
 for($digits=1;$digits -le $limit;$digits++){
  $e=$order-$digits+1;$ln=$loN;$ld=$loD;$hn=$hiN;$hd=$hiD;$xn=$x.N;$xd=$x.D
  if($e -ge 0){$factor=P10 $e;$ld*=$factor;$hd*=$factor;$xd*=$factor}else{$factor=P10 (-$e);$ln*=$factor;$hn*=$factor;$xn*=$factor}
  $rem=[Numerics.BigInteger]::Zero;$minimum=[Numerics.BigInteger]::DivRem($ln,$ld,[ref]$rem)
  if($rem -ne 0 -or -not $closed){$minimum+=[Numerics.BigInteger]::One}
  $maximum=[Numerics.BigInteger]::DivRem($hn,$hd,[ref]$rem)
  if($rem -eq 0 -and -not $hiClosed){$maximum-=[Numerics.BigInteger]::One}
  if($minimum -gt $maximum){continue}
  $candidate=[Numerics.BigInteger]::DivRem($xn,$xd,[ref]$rem)
  if(2*$rem -gt $xd -or (2*$rem -eq $xd -and -not $candidate.IsEven)){$candidate+=[Numerics.BigInteger]::One}
  if($candidate -lt $minimum){$candidate=$minimum};if($candidate -gt $maximum){$candidate=$maximum}
  return Render $candidate $e $negative
 }
 throw "No shortest representation: $Bits/$W"
}
$lines=New-Object 'Collections.Generic.List[string]'
$lines.Add(@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private Function FailureCases() As Boolean
    Dim Bytes(0 To 2) As Byte
    Dim Used As Long = 1
    Dim Status As Boolean
    Bytes(0) = 42: Bytes(1) = 43: Bytes(2) = 44
    If BinaryFloatText.TryAppend(Bytes, Used, 9218868437227405311^, 64) Then Exit Function
    If Used <> 1 Or Bytes(0) <> 42 Or Bytes(1) <> 43 Or Bytes(2) <> 44 Or Err.Number <> 9 Then Exit Function
    If BinaryFloatText.TryAppend(Bytes, Used, -1, 32) Then Exit Function
    If Used <> 1 Or Bytes(0) <> 42 Or Bytes(1) <> 43 Or Bytes(2) <> 44 Or Err.Number <> 5 Then Exit Function
    If BinaryFloatText.TryAppend(Bytes, Used, 0, 16) Then Exit Function
    If Used <> 1 Or Bytes(0) <> 42 Or Bytes(1) <> 43 Or Bytes(2) <> 44 Or Err.Number <> 5 Then Exit Function
    Used = -1
    If BinaryFloatText.TryAppend(Bytes, Used, 0, 64) Then Exit Function
    If Used <> -1 Or Bytes(0) <> 42 Or Bytes(1) <> 43 Or Bytes(2) <> 44 Or Err.Number <> 5 Then Exit Function
    Used = 4
    If BinaryFloatText.TryAppend(Bytes, Used, 0, 64) Then Exit Function
    If Used <> 4 Or Bytes(0) <> 42 Or Bytes(1) <> 43 Or Bytes(2) <> 44 Or Err.Number <> 9 Then Exit Function
    FailureCases = True
End Function
Private Function StorageCases() As Boolean
    Dim Bytes(1 To 3) As Byte
    Dim Used As Long = 1
    Bytes(1) = 42: Bytes(2) = 43: Bytes(3) = 44
    If BinaryFloatText.TryAppend(Bytes, Used, 0, 64) Then Exit Function
    If Used <> 1 Or Bytes(1) <> 42 Or Bytes(2) <> 43 Or Bytes(3) <> 44 Or Err.Number <> 9 Then Exit Function
    StorageCases = True
End Function
'@)
$script:cases=0;$script:fixtures=New-Object 'Collections.Generic.List[object]'
function Add([string]$Bits,[int]$W){
 $text=Expected $Bits $W;$script:cases++;$script:fixtures.Add(@{Bits=$Bits;Width=$W;Text=$text})
 $lines.Add("Private Function Check$script:cases() As Boolean")
 $lines.Add('Dim Bytes(0 To 47) As Byte');$lines.Add('Dim Used As Long = 1');$lines.Add('Dim Status As Boolean');$lines.Add('Dim Parsed As LongLong')
 $lines.Add('Bytes(0) = 42');$lines.Add('Status = FilePrimitives.SetError(57)')
 if($text -in @('NaN','Infinity','-Infinity')){
  $lines.Add("If BinaryFloatText.TryAppend(Bytes, Used, $Bits^, $W) Then Exit Function")
  $lines.Add('If Used <> 1 Or Bytes(0) <> 42 Or Bytes(1) <> 0 Or Err.Number <> 6 Then Exit Function')
  $lines.Add("Check$script:cases = True");$lines.Add('End Function');return
 }
 $lines.Add("If Not BinaryFloatText.TryAppend(Bytes, Used, $Bits^, $W) Then Exit Function")
 $lines.Add("If Used <> $($text.Length+1) Or Bytes(0) <> 42 Or Err.Number <> 57 Then Exit Function")
 for($i=0;$i -lt $text.Length;$i++){$lines.Add("If Bytes($($i+1)) <> $([int][char]$text[$i]) Then Exit Function")}
 if($text -ne 'NaN'){
  $lines.Add("If Not BinaryFloat.TryParse(Bytes, 1, Used - 1, $W, Parsed) Then Exit Function")
  $lines.Add("If Parsed <> $Bits^ Or Err.Number <> 57 Then Exit Function")
 }
 $lines.Add("Check$script:cases = True");$lines.Add('End Function')
}
$random=New-Object Random(61351)
foreach($w in @(32,64)){
 $p=53;$bias=1023;$maxfield=2047;if($w -eq 32){$p=24;$bias=127;$maxfield=255}
 $unit=P2 ($p-1);$inf=$maxfield*$unit
 $values=@([Numerics.BigInteger]::Zero,[Numerics.BigInteger]::One,[Numerics.BigInteger]2,[Numerics.BigInteger]3,($unit-1),$unit,($unit+1),($bias*$unit-1),($bias*$unit),($bias*$unit+1),($inf-2),($inf-1),$inf,($inf+1),($inf+$unit/2))
 foreach($v in $values){Add $v.ToString() $w}
 foreach($v in @([Numerics.BigInteger]::Zero,[Numerics.BigInteger]::One,($bias*$unit),($inf-1),$inf)){if($w -eq 32){$v+=P2 31}else{$v-=P2 63};Add $v.ToString() $w}
 for($i=0;$i -lt 20;$i++){
  $v=$random.Next(0,$maxfield)*$unit+[Numerics.BigInteger]$random.Next(0,1000000)*($unit/1000000)
  Add $v.ToString() $w
 }
}
# Familiar decimal values and notation transitions, encoded independently by exact rational cases.
foreach($bits in @('4591870180066957722','4602678819172646912','4698018361873203200','4667987612595716096','4576918229304087675','4562254508917369340')){Add $bits 64}
$lines.Add('Public Function Main() As Long');$lines.Add('If Not FailureCases() Then Main = 250: Exit Function')
$lines.Add('If Not StorageCases() Then Main = 251: Exit Function')
for($i=1;$i -le $script:cases;$i++){$lines.Add("If Not Check$i() Then Main = $i`: Exit Function")};$lines.Add('End Function')
$source=Join-Path $artifacts 'Probe.bas';[IO.File]::WriteAllText($source,($lines -join "`r`n")+"`r`n",$utf8)
$script:fixtures | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $artifacts 'oracle.json') -Encoding UTF8
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'));$modules=@('BinaryFloatText','BinaryFloatValues','BinaryFloat','InvariantNumbers','ByteText','Utf8','BufferPrimitives','FilePrimitives')
foreach($name in $modules){Copy-Item -LiteralPath (Join-Path $repo "std-lib/src/portable/$name.bas") -Destination $artifacts}
foreach($level in @('0','2')){
 $manifest=Join-Path $artifacts ('Project'+$level+'.UBE');$text="UBE-Project 1`r`nName = `"FloatingFormatTest`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in ($modules+@('Probe'))){$text+="Source = `"$name.bas`"`r`n"};[IO.File]::WriteAllText($manifest,$text,$utf8)
 $exe=Join-Path $artifacts ('Probe'+$level+'.exe');$build=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);$run=Run $exe @()
 Write-Output "PASS O$level $script:cases exact shortest-coefficient texts and roundtrips, atomic failures; build $build sec; execution $run sec"
 $original=[IO.File]::ReadAllText($source,$utf8)
 $formatOnly=[regex]::Replace($original,'(?m)^If Not BinaryFloat\.TryParse[^\r\n]*\r?\n|^If Parsed <>[^\r\n]*\r?\n','')
 [IO.File]::WriteAllText($source,$formatOnly,$utf8)
 $exe=Join-Path $artifacts ('FormatOnly'+$level+'.exe');$null=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);$formatTime=Run $exe @()
 Write-Output "PASS O$level independent exact text assertions without parser; formatting execution $formatTime sec"
 $changed=$original.Replace('If Bytes(1) <> 48 Then','If Bytes(1) <> 49 Then')
 if($original -ceq $changed){throw 'Missing negative control marker'};[IO.File]::WriteAllText($source,$changed,$utf8)
 $exe=Join-Path $artifacts ('Negative'+$level+'.exe');$null=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);$null=Run $exe @() 1
 [IO.File]::WriteAllText($source,$original,$utf8);Write-Output "PASS O$level changed-text negative control"
}
