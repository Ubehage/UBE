# Exact rational oracle for IEEE-to-LongLong conversion, independent of host rounding.
param([Parameter(Mandatory=$true)][string]$CompilerExe)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Numerics
$utf=New-Object Text.UTF8Encoding($false)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube float conversion oracle '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
function P2([int]$n){[Numerics.BigInteger]::Pow(2,$n)}
$cases=New-Object 'System.Collections.Generic.List[string]'
$random=New-Object Random(41127)
foreach($width in @(32,64)){
 $precision=53;$bias=1023;$maximum=2047
 if($width -eq 32){$precision=24;$bias=127;$maximum=255}
 $unit=P2 ($precision-1)
 $magnitudes=New-Object 'System.Collections.Generic.List[System.Numerics.BigInteger]'
 foreach($field in @(0,1,($bias-2),($bias-1),$bias,($bias+1),($bias+30),($bias+31),($bias+62),($bias+63),($maximum-1),$maximum)){
  foreach($fraction in @([Numerics.BigInteger]::Zero,[Numerics.BigInteger]::One,($unit/2),($unit-1))){$magnitudes.Add($field*$unit+$fraction)}
 }
 for($i=0;$i -lt 32;$i++){$magnitudes.Add($random.Next(0,$maximum)*$unit+[Numerics.BigInteger]$random.Next(0,1000000)*($unit/1000000))}
 foreach($magnitude in $magnitudes){foreach($negative in @($false,$true)){
  $bits=$magnitude
  if($negative){if($width -eq 32){$bits+=P2 31}else{$bits-=P2 63}}
  $field=[int]($magnitude/$unit);$significand=$magnitude%$unit
  $exponent=1-$bias-($precision-1)
  if($field -gt 0){$significand+=$unit;$exponent=$field-$bias-($precision-1)}
  $numerator=$significand;$denominator=[Numerics.BigInteger]::One
  if($exponent -ge 0){$numerator*=P2 $exponent}else{$denominator=P2 (-$exponent)}
  $remainder=[Numerics.BigInteger]::Zero
  $value=[Numerics.BigInteger]::DivRem($numerator,$denominator,[ref]$remainder)
  if(2*$remainder -gt $denominator -or (2*$remainder -eq $denominator -and -not $value.IsEven)){$value+=[Numerics.BigInteger]::One}
  if($negative){$value=-$value}
  $valid=$field -ne $maximum -and $value -ge -(P2 63) -and $value -lt (P2 63)
  if(-not $valid){$value=42}
  $cases.Add("If Not Check($bits^, $width, $valid, $value^) Then Exit Function")
 }}
}
$head=@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private Intrinsic Function SetError(ByVal Number As Long) As Boolean
Attribute SetError.UBE_Primitive = "Error.Set"
End Function
Private Function Check(ByVal Bits As LongLong, ByVal BitWidth As Long, ByVal ExpectedSuccess As Boolean, ByVal ExpectedValue As LongLong) As Boolean
    Dim Value As LongLong = 42
    Dim Success As Boolean
    Call SetError(57)
    Success = BinaryFloatValues.TryToInteger(Bits, BitWidth, Value)
    If Success <> ExpectedSuccess Or Value <> ExpectedValue Then Exit Function
    If Success Then
        If Err.Number <> 57 Then Exit Function
    Else
        If Err.Number <> 6 Then Exit Function
    End If
    Check = True
End Function
'@
$lines=New-Object 'System.Collections.Generic.List[string]'
$lines.Add($head)
$groups=[int][Math]::Ceiling($cases.Count/16.0)
for($group=0;$group -lt $groups;$group++){
 $lines.Add("Private Function Group$group() As Boolean")
 for($i=$group*16;$i -lt [Math]::Min(($group+1)*16,$cases.Count);$i++){$lines.Add($cases[$i])}
 $lines.Add("Group$group = True");$lines.Add('End Function')
}
$lines.Add('Public Function Main() As Long')
for($group=0;$group -lt $groups;$group++){$lines.Add("If Not Group$group() Then Main = $($group+1): Exit Function")}
$lines.Add('End Function')
$source=$lines -join "`r`n"
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
Copy-Item -LiteralPath (Join-Path $repo 'std-lib/src/portable/BinaryFloatValues.bas') -Destination $evidence
foreach($level in @('0','2')){foreach($negative in @($false,$true)){
 $candidate=$source
 if($negative){$candidate=$source.Replace('Value <> ExpectedValue','Value <> ExpectedValue + 1')}
 [IO.File]::WriteAllText((Join-Path $evidence 'Probe.bas'),$candidate,$utf)
 $project=Join-Path $evidence 'Probe.UBE'
 $manifest="UBE-Project 1`r`nName = `"ConversionOracle`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`nSource = `"BinaryFloatValues.bas`"`r`nSource = `"Probe.bas`"`r`n"
 [IO.File]::WriteAllText($project,$manifest,$utf)
 $exe=Join-Path $evidence "Probe-$level-$negative.exe"
 & $CompilerExe --build $project $exe
 if($LASTEXITCODE -ne 0){throw 'Build failed'}
 & $exe
 $expected=0;if($negative){$expected=1}
 if($LASTEXITCODE -ne $expected){throw "Oracle failed with $LASTEXITCODE expected $expected"}
}}
Write-Output "PASS $($cases.Count) exact conversions O0/O2 and changed-oracle controls"
