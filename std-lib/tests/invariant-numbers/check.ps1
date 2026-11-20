# Independent BigInteger oracle for ordinary UBE invariant numeric conversion.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Numerics
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube invariant numbers '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $artifacts
Write-Output "Evidence: $artifacts"
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' ')}
 $p=Start-Process @options
 try {$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();$errorText=[IO.File]::ReadAllText($prefix+'.stderr');if($p.ExitCode -ne $Expected -or $errorText){throw "Exit$($p.ExitCode), expected$Expected`: $errorText Evidence$prefix"}} finally {$p.Dispose()}
}
# Exact test oracle: arbitrary precision numerator/denominator and quotient parity.
function Rounded([string]$Text) {
 if($Text -notmatch '^([+-]?)(\d*)(?:\.(\d*))?(?:[Ee]([+-]?\d+))?$'){throw 'Bad oracle fixture'}
 $negative=$Matches[1] -eq '-';$whole=$Matches[2];$fraction='';$exponent=0
 if($Matches.ContainsKey(3)){$fraction=$Matches[3]};if($Matches.ContainsKey(4)){$exponent=[int]$Matches[4]}
 $value=[Numerics.BigInteger]::Parse(($whole+$fraction),[Globalization.CultureInfo]::InvariantCulture)
 $scale=$exponent-$fraction.Length
 if($scale -ge 0){$value*=[Numerics.BigInteger]::Pow(10,$scale)} else {
  $divisor=[Numerics.BigInteger]::Pow(10,-$scale);$remainder=[Numerics.BigInteger]::Zero
  $value=[Numerics.BigInteger]::DivRem($value,$divisor,[ref]$remainder)
  if(2*$remainder -gt $divisor -or (2*$remainder -eq $divisor -and -not $value.IsEven)){$value+=[Numerics.BigInteger]::One}
 }
 if($negative){$value=-$value};return $value
}
$lines=New-Object 'Collections.Generic.List[string]'
$lines.Add('UBE SOURCE 1 MODULE');$lines.Add('Attribute UBE_Name = "Probe"')
$lines.Add(@'
' Keeps each test fixture write in a small ordinary procedure at native O0.
Private Sub PutByte(ByRef Bytes() As Byte, ByVal Index As Long, ByVal Value As Byte)
    Bytes(Index) = Value
End Sub
' Asserts status, exact value, unchanged output on failure, and preserved stale Err on success.
Private Function IntegerCase(ByRef Bytes() As Byte, ByVal Minimum As LongLong, ByVal Maximum As LongLong, ByVal Expected As LongLong, ByVal Failure As Long) As Boolean
    Dim Value As LongLong = 123
    Dim Status As Boolean
    Status = FilePrimitives.SetError(57)
    Status = InvariantNumbers.TryParseInteger(Bytes, 0, BufferPrimitives.ByteStorageLength(Bytes), Minimum, Maximum, Value)
    If Failure <> 0 Then
        IntegerCase = Not Status And Value = 123 And Err.Number = Failure
    Else
        IntegerCase = Status And Value = Expected And Err.Number = 57
    End If
End Function
' Boolean input checks exact mathematical significance, independent of integer representability.
Private Function BooleanCase(ByRef Bytes() As Byte, ByVal Expected As Boolean, ByVal Failure As Long) As Boolean
    Dim Value As Boolean = Not Expected
    Dim Status As Boolean
    Status = FilePrimitives.SetError(57)
    Status = InvariantNumbers.TryParseBoolean(Bytes, 0, BufferPrimitives.ByteStorageLength(Bytes), Value)
    If Failure <> 0 Then
        BooleanCase = Not Status And Value = (Not Expected) And Err.Number = Failure
    Else
        BooleanCase = Status And Value = Expected And Err.Number = 57
    End If
End Function
' Invalid arguments and malformed UTF-8 preserve destinations; counted subspans ignore outside bytes.
Private Function SpanCases() As Boolean
    Dim Bytes(0 To 4) As Byte
    Dim Value As LongLong = 123
    Dim Truth As Boolean = True
    Dim Status As Boolean
    Call PutByte(Bytes, 0, 255)
    Call PutByte(Bytes, 1, 52)
    Call PutByte(Bytes, 2, 50)
    Call PutByte(Bytes, 3, 255)
    Status = FilePrimitives.SetError(57)
    If Not InvariantNumbers.TryParseInteger(Bytes, 1, 2, -100, 100, Value) Then Exit Function
    If Value <> 42 Or Err.Number <> 57 Then Exit Function
    If InvariantNumbers.TryParseInteger(Bytes, -1, 2, -100, 100, Value) Then Exit Function
    If Value <> 42 Or Err.Number <> 5 Then Exit Function
    If InvariantNumbers.TryParseInteger(Bytes, 1, 5, -100, 100, Value) Then Exit Function
    If Value <> 42 Or Err.Number <> 5 Then Exit Function
    If InvariantNumbers.TryParseInteger(Bytes, 1, 2, 100, -100, Value) Then Exit Function
    If Value <> 42 Or Err.Number <> 5 Then Exit Function
    If InvariantNumbers.TryParseInteger(Bytes, 0, 3, -100, 100, Value) Then Exit Function
    If Value <> 42 Or Err.Number <> 13 Then Exit Function
    If InvariantNumbers.TryParseBoolean(Bytes, 0, 3, Truth) Then Exit Function
    If Not Truth Or Err.Number <> 13 Then Exit Function
    SpanCases = True
End Function
'@
)
$script:cases=0
$calls=New-Object 'Collections.Generic.List[string]'
function AddCase([string]$Text,[string]$Minimum,[string]$Maximum,[string]$Expected,[int]$Failure=0,[switch]$Boolean) {
 $script:cases++;$bytes=$utf8.GetBytes($Text)
 $lines.Add("Private Function Check$script:cases() As Boolean")
 $lines.Add('Dim Bytes() As Byte')
 $lines.Add("If Not BufferPrimitives.TryResizeBytes(Bytes, $($bytes.Length), False) Then Exit Function")
 for($i=0;$i -lt $bytes.Length;$i++){$lines.Add("Call PutByte(Bytes, $i, $($bytes[$i]))")}
 if($Boolean){$call="BooleanCase(Bytes, $Expected, $Failure)"}else{$call="IntegerCase(Bytes, $Minimum^, $Maximum^, $Expected^, $Failure)"}
 $lines.Add("Check$script:cases = $call")
 $lines.Add('End Function')
 $calls.Add("If Not Check$script:cases() Then Main = $script:cases`: Exit Function")
}
$minimum='-9223372036854775808';$maximum='9223372036854775807'
$decimal=@('0','-0','+0','1.','.5','-.5','2.5','3.5','-2.5','-3.5','2.50000000000000000000000000000000000000000000001','2.49999999999999999999999999999999999999999999999','00000000000000000000000000000000000000123.5','9223372036854775807','-9223372036854775808','9223372036854775807.49','9223372036854775807.5','-9223372036854775808.5','-9223372036854775808.500000000000000000000000000001','999999999999999999999999999999999999999999999999999999999999999999999999999999999e-70','123456789012345678901234567890123456789e-30','1e100','1e-100','0e100','0e-100','5e-1','15e-1','25e-1','35E-1')
foreach($text in $decimal){$expected=Rounded $text;$failure=0;if($expected -lt [Numerics.BigInteger]::Parse($minimum) -or $expected -gt [Numerics.BigInteger]::Parse($maximum)){$expected=0;$failure=6};AddCase $text $minimum $maximum ([string]$expected) $failure}
$random=New-Object Random(7319)
for($sample=0;$sample -lt 40;$sample++) {
 $digits='';$count=$random.Next(21,81)
 for($index=0;$index -lt $count;$index++){$digits+=[string]$random.Next(0,10)}
 $point=$random.Next(1,$count);$text=$digits.Substring(0,$point)+'.'+$digits.Substring($point)+'e'+[string]($random.Next(-5,25)-$point)
 if($sample % 2){$text='-'+$text}
 $expected=Rounded $text;$failure=0
 if($expected -lt [Numerics.BigInteger]::Parse($minimum) -or $expected -gt [Numerics.BigInteger]::Parse($maximum)){$expected=0;$failure=6}
 AddCase $text $minimum $maximum ([string]$expected) $failure
}
foreach($range in @(@('0','255'),@('-32768','32767'),@('-2147483648','2147483647'))){
 foreach($edge in @($range[0],$range[1])){foreach($tail in @('.4','.5','.6')){$text=$edge+$tail;$expected=Rounded $text;$failure=0;if($expected -lt [Numerics.BigInteger]::Parse($range[0]) -or $expected -gt [Numerics.BigInteger]::Parse($range[1])){$expected=0;$failure=6};AddCase $text $range[0] $range[1] ([string]$expected) $failure}}
}
foreach($case in @(@('&H7FFFFFFFFFFFFFFF',$maximum),@('-&H8000000000000000',$minimum),@('+&hFF','255'),@('&HFFFFFFFF','4294967295'),@('&O777','511'),@('-&o10','-8'),@('&H000000000000000000000000001','1'))){AddCase $case[0] $minimum $maximum $case[1]}
foreach($text in @('&H8000000000000000','&HFFFFFFFFFFFFFFFF','-&H8000000000000001')){AddCase $text $minimum $maximum '0' 6}
foreach($code in @(9,10,11,12,13,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288)) {AddCase ([string][char]$code+'12'+[char]$code) $minimum $maximum '12'}
foreach($text in @('',' ','+','-','.','1e','1e+','1e-','1e1x','1d2','1,5','1 2','1..0','&H','&O','&H-1','&H1&','&O8','NaN','Infinity','-Infinity','True',([string][char]65279+'1'),([string][char]0+'1'))){AddCase $text $minimum $maximum '0' 13}
foreach($text in @('True','tRuE','  TRUE  ','0.1','1e-999999999999999999999999999999999','-1e999999999999999999999999999999999','&HFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF')){AddCase $text '' '' 'True' 0 -Boolean}
foreach($text in @('False','fAlSe','  false  ','-0.000e99999999999999999999999999999','&O000')){AddCase $text '' '' 'False' 0 -Boolean}
foreach($text in @('NaN','Infinity','1e999999x','truex','&H')){AddCase $text '' '' 'False' 13 -Boolean}
$lines.Add('Public Function Main() As Long')
$lines.Add('If Not SpanCases() Then Main = 250: Exit Function')
foreach($call in $calls){$lines.Add($call)}
$lines.Add('End Function')
$source=Join-Path $artifacts 'Probe.bas'
[IO.File]::WriteAllText($source,($lines -join "`r`n")+"`r`n",$utf8)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
foreach($name in @('InvariantNumbers','Utf8','BufferPrimitives','FilePrimitives')){Copy-Item -LiteralPath (Join-Path $repo "std-lib/src/portable/$name.bas") -Destination $artifacts}
foreach($level in @('0','2')) {
 $manifest=Join-Path $artifacts ('Project'+$level+'.UBE')
 $text="UBE-Project 1`r`nName = `"InvariantNumbersTest`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in @('InvariantNumbers','Utf8','BufferPrimitives','FilePrimitives','Probe')){$text+="Source = `"$name.bas`"`r`n"}
 [IO.File]::WriteAllText($manifest,$text,$utf8)
 $exe=Join-Path $artifacts ('Probe'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang)
 Run $exe @()
 Write-Output "PASS O$level $script:cases exact conversions, ranges, whitespace, unchanged failures, stale Err"
 $original=[IO.File]::ReadAllText($source,$utf8)
 $changed=$original.Replace('IntegerCase = Status And Value = Expected And Err.Number = 57','IntegerCase = Status And Value = Expected + 1 And Err.Number = 57')
 if($changed -ceq $original){throw 'Missing changed-oracle marker'}
 [IO.File]::WriteAllText($source,$changed,$utf8)
 $negative=Join-Path $artifacts ('Negative'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$negative,'--clang',$Clang)
 Run $negative @() 1
 [IO.File]::WriteAllText($source,$original,$utf8)
 Write-Output "PASS O$level changed expected numeric observation rejected"
}
