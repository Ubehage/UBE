# Directed fixed-point squaring oracle for large integral exponents near one.
# Independent of the production logarithm/exponential evaluation path.
param([string]$Destination='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Numerics
function P2([int]$n){[Numerics.BigInteger]::Pow(2,$n)}
function CeilingDivide([Numerics.BigInteger]$n,[Numerics.BigInteger]$d){($n+$d-1)/$d}
function Decode([Numerics.BigInteger]$bits){
 $unit=P2 52;$field=[int]($bits/$unit);$sig=$bits%$unit;$e=-1074
 if($field -gt 0){$sig+=$unit;$e=$field-1075}
 $n=$sig;$d=[Numerics.BigInteger]::One
 if($e -ge 0){$n*=P2 $e}else{$d=P2 (-$e)}
 @{N=$n;D=$d}
}
function RoundFixed([Numerics.BigInteger]$n,[Numerics.BigInteger]$scale){
 if($n -ge ((P2 1024)-(P2 970))*$scale){return 'overflow'}
 $max=[Numerics.BigInteger]::Parse('9218868437227405311')
 $lo=[Numerics.BigInteger]::Zero;$hi=$max
 while($lo -lt $hi){
  $m=($lo+$hi+1)/2;$v=Decode $m
  if($v.N*$scale -le $n*$v.D){$lo=$m}else{$hi=$m-1}
 }
 if($lo -lt $max){
  $a=Decode $lo;$b=Decode ($lo+1)
  $left=($a.N*$b.D+$b.N*$a.D)*$scale;$right=2*$n*$a.D*$b.D
  if($left -lt $right -or ($left -eq $right -and -not $lo.IsEven)){$lo+=[Numerics.BigInteger]::One}
 }
 $lo.ToString()
}
function Interval([Numerics.BigInteger]$baseBits,[Numerics.BigInteger]$exponent,[int]$precision){
 $scale=P2 $precision;$base=Decode $baseBits
 if($exponent -lt 0){$save=$base.N;$base.N=$base.D;$base.D=$save;$exponent=-$exponent}
 $lo=($base.N*$scale)/$base.D;$hi=CeilingDivide ($base.N*$scale) $base.D
 $resultLo=$scale;$resultHi=$scale
 while($exponent -gt 0){
  if(-not $exponent.IsEven){
   $resultLo=($resultLo*$lo)/$scale
   $resultHi=CeilingDivide ($resultHi*$hi) $scale
  }
  $exponent=$exponent/2
  if($exponent -gt 0){$lo=($lo*$lo)/$scale;$hi=CeilingDivide ($hi*$hi) $scale}
 }
 @{Low=(RoundFixed $resultLo $scale);High=(RoundFixed $resultHi $scale)}
}
$cases=New-Object 'System.Collections.Generic.List[object]'
foreach($base in @('4607182418800017406','4607182418800017407','4607182418800017409','4607182418800017410')){
 foreach($power in @('4503599627370496','9007199254740992','9223372036854775808')){
  foreach($sign in @(1,-1)){
   $p=[Numerics.BigInteger]::Parse($power)*$sign
   $precision=192
   do{
    $result=Interval ([Numerics.BigInteger]::Parse($base)) $p $precision
    if($result.Low -eq $result.High){break}
    $precision*=2
    if($precision -gt 12288){throw 'Oracle could not certify this fixture'}
   }while($true)
   # Check the enclosure again at twice the accepted precision.
   $confirmed=Interval ([Numerics.BigInteger]::Parse($base)) $p ($precision*2)
   if($confirmed.Low -ne $result.Low -or $confirmed.High -ne $result.Low){throw 'Precision convergence check failed'}
   $errorCode=0;$bits=$result.Low
   if($bits -eq 'overflow'){$errorCode=6;$bits='42'}
   $powerBits=[BitConverter]::DoubleToInt64Bits([double]$p).ToString()
   $cases.Add([ordered]@{BaseBits=$base;PowerBits=$powerBits;ExpectedBits=$bits;Error=$errorCode;OraclePrecision=$precision;IntegerExponent=$p.ToString()})
  }
 }
}
if(-not $Destination){$Destination=Join-Path ([IO.Path]::GetTempPath()) ('ube integer power oracle '+[guid]::NewGuid()+'.json')}
[IO.File]::WriteAllText([IO.Path]::GetFullPath($Destination),($cases|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
Write-Output "PASS $($cases.Count) directed-squaring power references with doubled-precision confirmation: $Destination"
