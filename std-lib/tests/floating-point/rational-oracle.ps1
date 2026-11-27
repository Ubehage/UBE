# Exact rational IEEE test oracle shared by helper and native-emitter gates.
Add-Type -AssemblyName System.Numerics
function P2([int]$Exponent){return [Numerics.BigInteger]::Pow(2,$Exponent)}
function Encoding([Numerics.BigInteger]$Magnitude,[bool]$Negative,[int]$W){
 if($Negative){if($W -eq 32){$Magnitude+=P2 31}else{$Magnitude-=P2 63}}
 return $Magnitude.ToString()
}
function Decode([string]$Bits,[int]$W){
 $p=53;$bias=1023;$fieldMax=2047;if($W -eq 32){$p=24;$bias=127;$fieldMax=255}
 $v=[Numerics.BigInteger]::Parse($Bits);$neg=$v -lt 0
 if($W -eq 32){$neg=$v -ge (P2 31);if($neg){$v-=P2 31}}elseif($neg){$v+=P2 63}
 $unit=P2 ($p-1);$field=[int]($v/$unit);$sig=$v%$unit;$kind=0
 if($field -eq $fieldMax){$kind=1;if($sig -ne 0){$kind=2}}
 $e=1-$bias-($p-1);if($field -gt 0){$sig+=$unit;$e=$field-$bias-($p-1)}
 $n=$sig;$d=[Numerics.BigInteger]::One
 if($e -lt 0){$d=P2 (-$e)}else{$n*=P2 $e}
 return @{N=$n;D=$d;Negative=$neg;Kind=$kind}
}
function Special([int]$Kind,[bool]$Negative,[int]$W){
 $p=53;$field=2047;if($W -eq 32){$p=24;$field=255}
 $bits=[Numerics.BigInteger]::Zero
 if($Kind -gt 0){$bits=$field*(P2 ($p-1))};if($Kind -eq 2){$bits+=P2 ($p-2);$Negative=$false}
 return Encoding $bits $Negative $W
}
function RoundRational([Numerics.BigInteger]$N,[Numerics.BigInteger]$D,[bool]$Negative,[int]$W){
 if($N -eq 0){return Special 0 $Negative $W}
 $p=53;$emin=-1022;$emax=1023;$bias=1023;if($W -eq 32){$p=24;$emin=-126;$emax=127;$bias=127}
 $a=$N;$b=$D;$e=0
 if($a -ge $b){while($a -ge 2*$b){$b*=2;$e++}}else{while($a -lt $b){$a*=2;$e--}}
 $quantum=[Math]::Max($e,$emin)-($p-1)
 if($quantum -lt 0){$N*=P2 (-$quantum)}else{$D*=P2 $quantum}
 $rem=[Numerics.BigInteger]::Zero;$q=[Numerics.BigInteger]::DivRem($N,$D,[ref]$rem)
 if(2*$rem -gt $D -or (2*$rem -eq $D -and -not $q.IsEven)){$q+=[Numerics.BigInteger]::One}
 $unit=P2 ($p-1);if($q -ge 2*$unit){$q/=2;$quantum++}
 $e=$quantum+$p-1;if($e -gt $emax){return Special 1 $Negative $W}
 $bits=$q;if($q -ge $unit){$bits=($e+$bias)*$unit+($q-$unit)}
 return Encoding $bits $Negative $W
}
function Expected([string]$Left,[string]$Right,[int]$W,[int]$Operation){
 $a=Decode $Left $W;$b=Decode $Right $W
 if($a.Kind -eq 2 -or $b.Kind -eq 2){return Special 2 $false $W}
 if($Operation -eq 2){$b.Negative=-not $b.Negative}
 $negative=$a.Negative -xor $b.Negative
 if($Operation -le 2){
  if($a.Kind -eq 1 -and $b.Kind -eq 1 -and $a.Negative -ne $b.Negative){return Special 2 $false $W}
  if($a.Kind -eq 1){return Special 1 $a.Negative $W};if($b.Kind -eq 1){return Special 1 $b.Negative $W}
  $an=$a.N;$bn=$b.N;if($a.Negative){$an=-$an};if($b.Negative){$bn=-$bn}
  $n=$an*$b.D+$bn*$a.D;$negative=$n -lt 0
  if($n -eq 0){$negative=$a.Negative -and $b.Negative}
  return RoundRational ([Numerics.BigInteger]::Abs($n)) ($a.D*$b.D) $negative $W
 }
 if($Operation -eq 3){
  if(($a.Kind -eq 1 -and $b.Kind -eq 0 -and $b.N -eq 0) -or ($b.Kind -eq 1 -and $a.Kind -eq 0 -and $a.N -eq 0)){return Special 2 $false $W}
  if($a.Kind -eq 1 -or $b.Kind -eq 1){return Special 1 $negative $W}
  return RoundRational ($a.N*$b.N) ($a.D*$b.D) $negative $W
 }
 if($a.Kind -eq 1 -and $b.Kind -eq 1){return Special 2 $false $W}
 if($a.Kind -eq 1){return Special 1 $negative $W};if($b.Kind -eq 1){return Special 0 $negative $W}
 if($b.N -eq 0){if($a.N -eq 0){return Special 2 $false $W};return Special 1 $negative $W}
 return RoundRational ($a.N*$b.D) ($a.D*$b.N) $negative $W
}
