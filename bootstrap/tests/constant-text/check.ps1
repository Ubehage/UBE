# Exercises the actual UBE constant arena independently of managed String lowering.
param([Parameter(Mandatory=$true)][string]$CompilerExe, [string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube constant text '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$script:sequence=0
function Quote-Argument([string]$Value) {
 if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object {Quote-Argument $_}) -join ' ')}
 $p=Start-Process @options
 try {$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();$errorText=[IO.File]::ReadAllText($prefix+'.stderr');if($p.ExitCode -ne $Expected -or $errorText){throw "Exit $($p.ExitCode), expected $Expected`: $errorText Evidence $prefix"}} finally {$p.Dispose()}
}
$lines=New-Object 'Collections.Generic.List[string]'
$lines.Add('UBE SOURCE 1 MODULE')
$lines.Add('Attribute UBE_Name = "Probe"')
$lines.Add(@'
Private Intrinsic Function SetError(ByVal Number As Long) As Boolean
Attribute SetError.UBE_Primitive = "Error.Set"
End Function
Private Sub PutByte(ByRef Bytes() As Byte, ByVal Index As Long, ByVal Value As Byte)
    Bytes(Index) = Value
End Sub
' Every invalid operation preserves the prefix, logical size and output variables.
Private Function InvalidSpans() As Boolean
    Dim Source(0 To 2) As Byte
    Dim Arena() As Byte
    Dim Used As Long = 1
    Dim Start As Long = 123
    Dim Length As Long = 456
    Dim Order As Long = 789
    If Not BufferPrimitives.TryResizeBytes(Arena, 1, False) Then Exit Function
    Call PutByte(Arena, 0, 71)
    Call PutByte(Source, 0, 34)
    Call PutByte(Source, 1, 65)
    Call PutByte(Source, 2, 34)
    If ConstantText.TryAppendLiteral(Source, -1, 3, Arena, Used, Start, Length) Then Exit Function
    If ConstantText.TryAppendLiteral(Source, 0, 4, Arena, Used, Start, Length) Then Exit Function
    If ConstantText.TryAppendLiteral(Source, 2147483647, 3, Arena, Used, Start, Length) Then Exit Function
    If ConstantText.TryConcatenate(Arena, Used, 0, 2, 0, 1, Start, Length) Then Exit Function
    If ConstantText.TryConcatenate(Arena, Used, -1, 1, 0, 1, Start, Length) Then Exit Function
    If ConstantText.TryCompare(Arena, Used, 0, 1, 0, 2, Order) Then Exit Function
    If Used <> 1 Or Start <> 123 Or Length <> 456 Or Order <> 789 Or Arena(0) <> 71 Then Exit Function
    If Not ConstantText.TryAppendLiteral(Source, 0, 3, Arena, Used, Start, Length) Then Exit Function
    InvalidSpans = Used = 2 And Start = 1 And Length = 1 And Arena(0) = 71 And Arena(1) = 65
End Function
' Repeated growth retains prior immutable spans; copies include embedded NULs and exact case.
Private Function Concatenation() As Boolean
    Dim Source(0 To 4) As Byte
    Dim Arena() As Byte
    Dim Used As Long
    Dim Start As Long
    Dim Length As Long
    Dim NextStart As Long
    Dim NextLength As Long
    Dim Index As Long
    Dim Order As Long
    Call PutByte(Source, 0, 34)
    Call PutByte(Source, 1, 90)
    Call PutByte(Source, 2, 0)
    Call PutByte(Source, 3, 97)
    Call PutByte(Source, 4, 34)
    If Not ConstantText.TryAppendLiteral(Source, 0, 5, Arena, Used, Start, Length) Then Exit Function
    Do While Index < 8
        If Not ConstantText.TryConcatenate(Arena, Used, Start, Length, Start, Length, NextStart, NextLength) Then Exit Function
        If NextStart <> Used - NextLength Or NextLength <> Length * 2 Then Exit Function
        If Not ConstantText.TryCompare(Arena, Used, Start, Length, NextStart, Length, Order) Then Exit Function
        If Order <> 0 Then Exit Function
        If Not ConstantText.TryCompare(Arena, Used, Start, Length, NextStart, NextLength, Order) Then Exit Function
        If Order <> -1 Then Exit Function
        Start = NextStart
        Length = NextLength
        Index = Index + 1
    Loop
    If Not ConstantText.TryCompare(Arena, Used, 0, 1, 2, 1, Order) Then Exit Function
    If Order <> -1 Then Exit Function
    If Not ConstantText.TryCompare(Arena, Used, 2, 1, 0, 1, Order) Then Exit Function
    If Order <> 1 Then Exit Function
    If Not ConstantText.TryConcatenate(Arena, Used, 0, 0, 0, 0, NextStart, NextLength) Then Exit Function
    Concatenation = NextStart = Used And NextLength = 0 And Arena(0) = 90 And Arena(1) = 0 And Arena(2) = 97
End Function
'@
)
$script:cases=0
$calls=New-Object 'Collections.Generic.List[string]'
function Add-Literal([byte[]]$Bytes,[byte[]]$Expected,[bool]$Valid=$true) {
 $script:cases++
 $lines.Add("Private Function Check$script:cases() As Boolean")
 $lines.Add('Dim Source() As Byte')
 $lines.Add('Dim Arena() As Byte')
 $lines.Add('Dim Used As Long = 1')
 $lines.Add('Dim Start As Long = 123')
 $lines.Add('Dim Length As Long = 456')
 $lines.Add('Dim Status As Boolean')
 $lines.Add("If Not BufferPrimitives.TryResizeBytes(Source, $($Bytes.Length), False) Then Exit Function")
 $lines.Add('If Not BufferPrimitives.TryResizeBytes(Arena, 1, False) Then Exit Function')
 $lines.Add('Call PutByte(Arena, 0, 71)')
 for($i=0;$i -lt $Bytes.Length;$i++){$lines.Add("Call PutByte(Source, $i, $($Bytes[$i]))")}
 $lines.Add('Status = SetError(57)')
 $lines.Add("Status = ConstantText.TryAppendLiteral(Source, 0, $($Bytes.Length), Arena, Used, Start, Length)")
 if($Valid){
  $lines.Add("If Not Status Or Used <> $($Expected.Length+1) Or Start <> 1 Or Length <> $($Expected.Length) Then Exit Function")
  for($i=0;$i -lt $Expected.Length;$i++){$lines.Add("If Arena($($i+1)) <> $($Expected[$i]) Then Exit Function")}
 }else{$lines.Add('If Status Or Used <> 1 Or Start <> 123 Or Length <> 456 Then Exit Function')}
 $lines.Add("Check$script:cases = Arena(0) = 71 And Err.Number = 57")
 $lines.Add('End Function')
 $calls.Add("If Not Check$script:cases() Then Main = $script:cases`: Exit Function")
}
foreach($text in @('', 'AZaz', '"', 'a""Z', "N$([char]0)UL", ([char]0xE9).ToString(), ([char]0xFEFF).ToString(), [char]::ConvertFromUtf32(0x1F642))) {
 $literal='"'+$text.Replace('"','""')+'"'
 Add-Literal $utf8.GetBytes($literal) $utf8.GetBytes($text)
}
foreach($bytes in @(@(),@(34),@(34,65),@(65,34),@(34,34,34),@(34,10,34),@(34,13,34),@(34,192,128,34),@(34,237,160,128,34),@(34,244,144,128,128,34),@(34,226,130,34))) {Add-Literal ([byte[]]$bytes) ([byte[]]@()) $false}
$lines.Add('Public Function Main() As Long')
$lines.Add('On Error GoTo Unexpected')
foreach($call in $calls){$lines.Add($call)}
$lines.Add('If Not InvalidSpans() Then Main = 100: Exit Function')
$lines.Add('If Not Concatenation() Then Main = 101: Exit Function')
$lines.Add('Exit Function')
$lines.Add('Unexpected:')
$lines.Add('Main = 102')
$lines.Add('End Function')
$source=Join-Path $artifacts 'Probe.bas'
$original=($lines -join "`r`n")+"`r`n"
[IO.File]::WriteAllText($source,$original,$utf8)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$compilerModules=@('ConstantText','ConstantValues','SourceScanner','SyntaxTokens')
$coreModules=@('Utf8','BufferPrimitives','FilePrimitives','ByteText','InvariantNumbers','BinaryFloat','BinaryFloatValues','BinaryFloatMath','BinaryFloatPower','BinaryFloatText','ThreadPrimitives')
foreach($name in $compilerModules){Copy-Item -LiteralPath (Join-Path $repo ('compiler/src/'+$name+'.bas')) -Destination $artifacts}
foreach($name in $coreModules){Copy-Item -LiteralPath (Join-Path $repo ('std-lib/src/portable/'+$name+'.bas')) -Destination $artifacts}
foreach($level in @('0','2')) {
 $manifest=Join-Path $artifacts ('Project'+$level+'.UBE')
 $text="UBE-Project 1`r`nName = `"ConstantTextTest`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in ($compilerModules+$coreModules+@('Probe'))){$text+="Source = `"$name.bas`"`r`n"}
 [IO.File]::WriteAllText($manifest,$text,$utf8)
 $exe=Join-Path $artifacts ('Probe'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang)
 Run $exe @()
 Write-Output "PASS O$level $script:cases literals plus invalid spans, growth, concatenation and binary order"
 $changed=$original.Replace('Check2 = Arena(0) = 71 And Err.Number = 57','Check2 = Arena(0) = 72 And Err.Number = 57')
 if($changed -ceq $original){throw 'Missing changed-oracle marker'}
 [IO.File]::WriteAllText($source,$changed,$utf8)
 $negative=Join-Path $artifacts ('Negative'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$negative,'--clang',$Clang)
 Run $negative @() 2
 [IO.File]::WriteAllText($source,$original,$utf8)
 Write-Output "PASS O$level changed observation rejected"
}
