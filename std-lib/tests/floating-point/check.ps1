# Independent exact rational oracle for counted-byte IEEE conversion.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Numerics
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube floating point '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $artifacts
Write-Output "Evidence: $artifacts"
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' ')}
 $p=Start-Process @options
 try {$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();$errorText=[IO.File]::ReadAllText($prefix+'.stderr');if($p.ExitCode -ne $Expected -or $errorText){throw "Exit $($p.ExitCode), expected $Expected`: $errorText Evidence $prefix"}} finally {$p.Dispose()}
}
function Oracle([string]$Text,[int]$BitWidth) {
 if($Text -notmatch '^([+-]?)(\d*)(?:\.(\d*))?(?:[Ee]([+-]?\d+))?$'){throw 'Bad oracle fixture'}
 $negative=$Matches[1] -eq '-';$whole=$Matches[2];$fraction='';$exponent=0
 if($Matches.ContainsKey(3)){$fraction=$Matches[3]};if($Matches.ContainsKey(4)){$exponent=[int]$Matches[4]}
 $n=[Numerics.BigInteger]::Parse(($whole+$fraction),[Globalization.CultureInfo]::InvariantCulture)
 $d=[Numerics.BigInteger]::One;$scale=$exponent-$fraction.Length
 if($scale -ge 0){$n*=[Numerics.BigInteger]::Pow(10,$scale)}else{$d=[Numerics.BigInteger]::Pow(10,-$scale)}
 $precision=53;$minimum=-1022;$maximum=1023;$bias=1023
 if($BitWidth -eq 32){$precision=24;$minimum=-126;$maximum=127;$bias=127}
 $bits=[Numerics.BigInteger]::Zero
 if($n -ne 0){
  $maximumSignificand=[Numerics.BigInteger]::Pow(2,$precision)-1
  $maximumFinite=$maximumSignificand*[Numerics.BigInteger]::Pow(2,$maximum-$precision+1)
  if($n -gt $maximumFinite*$d){return @{Bits='123';Failure=6}}
  $binaryExponent=0;$a=$n;$b=$d
  if($a -ge $b){while($a -ge 2*$b){$b*=2;$binaryExponent++}}else{while($a -lt $b){$a*=2;$binaryExponent--}}
  $quantum=[Math]::Max($binaryExponent,$minimum)-($precision-1)
  if($quantum -lt 0){$n*=[Numerics.BigInteger]::Pow(2,-$quantum)}else{$d*=[Numerics.BigInteger]::Pow(2,$quantum)}
  $remainder=[Numerics.BigInteger]::Zero;$q=[Numerics.BigInteger]::DivRem($n,$d,[ref]$remainder)
  if(2*$remainder -gt $d -or (2*$remainder -eq $d -and -not $q.IsEven)){$q+=[Numerics.BigInteger]::One}
  $unit=[Numerics.BigInteger]::Pow(2,$precision-1)
  if($q -ge 2*$unit){$q/=2;$quantum++}
  $roundedExponent=$quantum+$precision-1
  if($roundedExponent -gt $maximum){return @{Bits='123';Failure=6}}
  if($q -ge $unit){$bits=($roundedExponent+$bias)*$unit+($q-$unit)}else{$bits=$q}
 }
 if($negative){if($BitWidth -eq 64){$bits-=[Numerics.BigInteger]::Pow(2,63)}else{$bits+=[Numerics.BigInteger]::Pow(2,31)}}
 return @{Bits=$bits.ToString();Failure=0}
}
function Dyadic([Numerics.BigInteger]$Mantissa,[int]$Exponent) {
 if($Exponent -ge 0){return ($Mantissa*[Numerics.BigInteger]::Pow(2,$Exponent)).ToString()}
 $digits=($Mantissa*[Numerics.BigInteger]::Pow(5,-$Exponent)).ToString().PadLeft(-$Exponent+1,'0')
 return $digits.Insert($digits.Length+$Exponent,'.')
}
$lines=New-Object 'Collections.Generic.List[string]'
$lines.Add(@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private Sub PutByte(ByRef Bytes() As Byte, ByVal Index As Long, ByVal Value As Byte)
    Bytes(Index) = Value
End Sub
Private Sub PutDigits(ByRef Bytes() As Byte, ByVal Start As Long, ByVal Count As Long, ByVal Value As LongLong)
    Do While Count > 0
        Count = Count - 1
        Bytes(Start + Count) = 48 + Value Mod 10
        Value = Value \ 10
    Loop
End Sub
Private Function CheckValue(ByRef Bytes() As Byte, ByVal BitWidth As Long, ByVal Expected As LongLong, ByVal Failure As Long) As Boolean
    Dim Value As LongLong = 123
    Dim Status As Boolean
    Status = FilePrimitives.SetError(57)
    Status = BinaryFloat.TryParse(Bytes, 0, BufferPrimitives.ByteStorageLength(Bytes), BitWidth, Value)
    If Failure <> 0 Then
        CheckValue = Not Status And Value = 123 And Err.Number = Failure
    Else
        CheckValue = Status And Value = Expected And Err.Number = 57
    End If
End Function
Private Function SpanCases() As Boolean
    Dim Bytes(0 To 3) As Byte
    Dim Value As LongLong = 123
    Dim Status As Boolean
    Bytes(0) = 255
    Bytes(1) = 49
    Bytes(2) = 46
    Bytes(3) = 53
    Status = FilePrimitives.SetError(57)
    If Not BinaryFloat.TryParse(Bytes, 1, 3, 64, Value) Then Exit Function
    If Value <> 4609434218613702656^ Or Err.Number <> 57 Then Exit Function
    If BinaryFloat.TryParse(Bytes, 0, 4, 64, Value) Then Exit Function
    If Value <> 4609434218613702656^ Or Err.Number <> 13 Then Exit Function
    If BinaryFloat.TryParse(Bytes, -1, 4, 64, Value) Then Exit Function
    If Value <> 4609434218613702656^ Or Err.Number <> 5 Then Exit Function
    If BinaryFloat.TryParse(Bytes, 1, 4, 64, Value) Then Exit Function
    If Value <> 4609434218613702656^ Or Err.Number <> 5 Then Exit Function
    If BinaryFloat.TryParse(Bytes, 1, 3, 16, Value) Then Exit Function
    If Value <> 4609434218613702656^ Or Err.Number <> 5 Then Exit Function
    SpanCases = True
End Function
'@)
$script:cases=0;$calls=New-Object 'Collections.Generic.List[string]'
function AddCase([string]$Text,[int]$BitWidth,[string]$Expected='',[int]$Failure=0) {
 if($Expected -eq ''){$result=Oracle $Text $BitWidth;$Expected=$result.Bits;$Failure=$result.Failure}
 $script:cases++;$bytes=$utf8.GetBytes($Text)
 $lines.Add("Private Function Case$script:cases() As Boolean")
 $lines.Add('Dim Bytes() As Byte')
 $lines.Add("If Not BufferPrimitives.TryResizeBytes(Bytes, $($bytes.Length), False) Then Exit Function")
 for($i=0;$i -lt $bytes.Length;){
  if($bytes[$i] -ge 48 -and $bytes[$i] -le 57){
   $count=0;$digits=''
   while($i+$count -lt $bytes.Length -and $count -lt 18 -and $bytes[$i+$count] -ge 48 -and $bytes[$i+$count] -le 57){$digits+=[char]$bytes[$i+$count];$count++}
   $number=[Int64]::Parse($digits,[Globalization.CultureInfo]::InvariantCulture)
   $lines.Add("Call PutDigits(Bytes, $i, $count, $number^)");$i+=$count
  }else{$lines.Add("Call PutByte(Bytes, $i, $($bytes[$i]))");$i++}
 }
 $lines.Add("Case$script:cases = CheckValue(Bytes, $BitWidth, $Expected^, $Failure)")
 $lines.Add('End Function')
 $calls.Add("If Not Case$script:cases() Then Main = $script:cases`: Exit Function")
}
foreach($width in @(32,64)){
 foreach($value in @('0','-0','1','-1','0.1','1e100','1e-400','1e400','16777217','9007199254740993')){AddCase $value $width}
 foreach($value in @('',' ','1e+','1e999999x','1,5','&H1','&O1','+NaN','-NaN','+Infinity')){AddCase $value $width '123' 13}
 AddCase 'NaN' $width '123' 13
 AddCase '-iNfInItY' $width '123' 13
 AddCase ([string][char]160+' 1.5 '+[char]12288) $width $(if($width -eq 32){'1069547520'}else{'4609434218613702656'})
}
foreach($pair in @(@(32,24,-149,127),@(64,53,-1074,1023))){
 $w=$pair[0];$p=$pair[1];$sub=$pair[2];$max=$pair[3]
 foreach($m in @(1,2,3)){AddCase (Dyadic $m ($sub-1)) $w}
 AddCase (Dyadic ([Numerics.BigInteger]::Pow(2,$p)-1) $sub) $w
 AddCase (Dyadic ([Numerics.BigInteger]::Pow(2,$p)-1) ($max-$p+1)) $w
 AddCase ((Dyadic ([Numerics.BigInteger]::Pow(2,$p)-1) ($max-$p+1))+'.1') $w
 AddCase (Dyadic ([Numerics.BigInteger]::Pow(2,$p+1)-1) ($max-$p)) $w
 AddCase ((Dyadic ([Numerics.BigInteger]::Pow(2,$p)+1) (-$p))+'00000000000000000001') $w
}
AddCase ('1.'+('0'*1500)+'1') 64 '4607182418800017408'
AddCase '1e-9999999999999999999999999999999999' 64 '0'
AddCase '1e9999999999999999999999999999999999' 64 '123' 6
$random=New-Object Random(84013)
foreach($w in @(32,64)){
 for($sample=0;$sample -lt 16;$sample++){
  $digits='';for($j=0;$j -lt 40;$j++){$digits+=[string]$random.Next(0,10)}
  $decimal=$digits.Insert(1,'.')+'e'+[string]$random.Next(-350,310)
  if($sample % 2){$decimal='-'+$decimal}
  AddCase $decimal $w
 }
}
$lines.Add('Public Function Main() As Long');$lines.Add('If Not SpanCases() Then Main = 250: Exit Function');foreach($call in $calls){$lines.Add($call)};$lines.Add('End Function')
$source=Join-Path $artifacts 'Probe.bas';[IO.File]::WriteAllText($source,($lines -join "`r`n")+"`r`n",$utf8)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$modules=@('BinaryFloat','InvariantNumbers','Utf8','BufferPrimitives','FilePrimitives')
foreach($name in $modules){Copy-Item -LiteralPath (Join-Path $repo "std-lib/src/portable/$name.bas") -Destination $artifacts}
foreach($level in @('0','2')){
 $manifest=Join-Path $artifacts ('Project'+$level+'.UBE')
 $text="UBE-Project 1`r`nName = `"FloatingPointTest`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in ($modules+@('Probe'))){$text+="Source = `"$name.bas`"`r`n"}
 [IO.File]::WriteAllText($manifest,$text,$utf8)
 $exe=Join-Path $artifacts ('Probe'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);Run $exe @()
 Write-Output "PASS O$level $script:cases exact IEEE conversions, atomic failures, stale Err"
 $original=[IO.File]::ReadAllText($source,$utf8)
 $changed=$original.Replace('Value = Expected And Err.Number = 57','Value = Expected + 1 And Err.Number = 57')
 if($changed -ceq $original){throw 'Missing negative control marker'}
 [IO.File]::WriteAllText($source,$changed,$utf8)
 $negative=Join-Path $artifacts ('Negative'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$negative,'--clang',$Clang);Run $negative @() 1
 [IO.File]::WriteAllText($source,$original,$utf8)
 Write-Output "PASS O$level changed-oracle negative control"
}
