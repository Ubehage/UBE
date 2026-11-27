# Independent exact algebraic oracle for binary64 powers with dyadic exponents.
# Compares candidate^degree against base^numerator; no logarithms/exp or host pow.
param([string]$Destination='')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Numerics
function P2([int]$n){return [Numerics.BigInteger]::Pow(2,$n)}
function Decode([Numerics.BigInteger]$bits){
 $unit=P2 52
 $field=[int]($bits/$unit)
 $significand=$bits%$unit
 $exponent=-1074
 if($field -gt 0){$significand+=$unit;$exponent=$field-1075}
 $n=$significand;$d=[Numerics.BigInteger]::One
 if($exponent -ge 0){$n*=P2 $exponent}else{$d=P2 (-$exponent)}
 return @{N=$n;D=$d}
}
function CompareRoot($candidate,$target,[int]$degree){
 $left=[Numerics.BigInteger]::Pow($candidate.N,$degree)*$target.D
 $right=[Numerics.BigInteger]::Pow($candidate.D,$degree)*$target.N
 return [Numerics.BigInteger]::Compare($left,$right)
}
function Midpoint($a,$b){return @{N=$a.N*$b.D+$b.N*$a.D;D=2*$a.D*$b.D}}
function Expected([Numerics.BigInteger]$baseBits,[int]$numerator,[int]$denominatorPower){
 $base=Decode $baseBits
 $degree=1 -shl $denominatorPower
 $p=[Math]::Abs($numerator)
 $target=@{N=[Numerics.BigInteger]::Pow($base.N,$p);D=[Numerics.BigInteger]::Pow($base.D,$p)}
 if($numerator -lt 0){$saved=$target.N;$target.N=$target.D;$target.D=$saved}
 $maximum=[Numerics.BigInteger]::Parse('9218868437227405311')
 $overflow=@{N=(P2 1024)-(P2 970);D=[Numerics.BigInteger]::One}
 if((CompareRoot $overflow $target $degree) -le 0){return @{Error=6;Bits='42'}}
 $low=[Numerics.BigInteger]::Zero;$high=$maximum
 while($low -lt $high){
  $middle=($low+$high+1)/2
  if((CompareRoot (Decode $middle) $target $degree) -le 0){$low=$middle}else{$high=$middle-1}
 }
 if($low -lt $maximum){
  $mid=Midpoint (Decode $low) (Decode ($low+1))
  $order=CompareRoot $mid $target $degree
  if($order -lt 0 -or ($order -eq 0 -and -not $low.IsEven)){$low+=[Numerics.BigInteger]::One}
 }
 return @{Error=0;Bits=$low.ToString()}
}
$fixtures=New-Object 'System.Collections.Generic.List[object]'
$bases=@('1','4503599627370495','4503599627370496','4598175219545276416','4602678819172646912','4607182418800017407','4607182418800017408','4607182418800017409','4611686018427387904','4613937818241073152','4621256167635550208','4625196817309499392','9218868437227405311')
$powers=@(@(1,0),@(2,0),@(3,0),@(-1,0),@(-2,0),@(1,1),@(1,2),@(3,1),@(-1,1),@(1,3),@(5,4))
foreach($base in $bases){foreach($power in $powers){
 $p=[int]$power[0];$q=[int]$power[1]
 $expected=Expected ([Numerics.BigInteger]::Parse($base)) $p $q
 # Each fixture exponent is a small exact dyadic, so this conversion is exact.
 $exponent=[double]$p/[double](1 -shl $q)
 $exponentBits=[BitConverter]::DoubleToInt64Bits($exponent).ToString()
 $fixtures.Add([ordered]@{BaseBits=$base;PowerBits=$exponentBits;Numerator=$p;DenominatorPower=$q;ExpectedBits=$expected.Bits;Error=$expected.Error})
}}
# Sanity checks independent of the candidate search: 2^3=8 and sqrt(9)=3.
if((Expected ([Numerics.BigInteger]::Parse('4611686018427387904')) 3 0).Bits -ne '4620693217682128896'){throw 'Integer-power oracle sanity failed'}
if((Expected ([Numerics.BigInteger]::Parse('4621256167635550208')) 1 1).Bits -ne '4613937818241073152'){throw 'Exact-square-root oracle sanity failed'}
if(-not $Destination){$Destination=Join-Path ([IO.Path]::GetTempPath()) ('ube power oracle '+[guid]::NewGuid()+'.json')}
[IO.File]::WriteAllText([IO.Path]::GetFullPath($Destination),($fixtures|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
Write-Output "PASS exact power oracle sanity; $($fixtures.Count) fixtures written to $Destination"
