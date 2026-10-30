UBE SOURCE 1 MODULE
Attribute UBE_Name = "Utf8Text"

' Decodes one strict UTF-8 scalar. Invalid, truncated, overlong, surrogate, and
' out-of-range sequences return 0 without reading beyond the string.
Function DecodeCompilerUtf8(ByVal InputText As String, ByVal Offset As Long, ByRef CodePoint As Long, ByRef ByteCount As Long) As Long
    CodePoint = 0
    ByteCount = 0
    Dim Length As Long = CompilerTextLength(InputText)
    If Offset < 0 Or Offset >= Length Then DecodeCompilerUtf8 = 0: Exit Function
    Dim First As Long = CompilerTextByteAt(InputText, Offset)
    If First < 128 Then CodePoint = First: ByteCount = 1: DecodeCompilerUtf8 = 1: Exit Function
    Dim Needed As Long = 0
    Dim Minimum As Long = 0
    If First >= 194 And First <= 223 Then Needed = 2: Minimum = 128
    If First >= 224 And First <= 239 Then Needed = 3: Minimum = 2048
    If First >= 240 And First <= 244 Then Needed = 4: Minimum = 65536
    If Needed = 0 Or Offset > Length - Needed Then DecodeCompilerUtf8 = 0: Exit Function
    If Needed = 2 Then CodePoint = First - 192
    If Needed = 3 Then CodePoint = First - 224
    If Needed = 4 Then CodePoint = First - 240
    Dim Index As Long = 1
    While Index < Needed
        Dim NextByte As Long = CompilerTextByteAt(InputText, Offset + Index)
        If NextByte < 128 Or NextByte > 191 Then DecodeCompilerUtf8 = 0: Exit Function
        CodePoint = CodePoint * 64 + NextByte - 128
        Index = Index + 1
    Wend
    If CodePoint < Minimum Or CodePoint > 1114111 Or (CodePoint >= 55296 And CodePoint <= 57343) Then DecodeCompilerUtf8 = 0: Exit Function
    ByteCount = Needed
    DecodeCompilerUtf8 = 1
End Function

' Validates an entire UTF-8 source and returns the first invalid byte offset.
Function ValidateCompilerUtf8(ByVal InputText As String, ByRef InvalidOffset As Long, ByRef ScalarCount As Long) As Long
    InvalidOffset = 0
    ScalarCount = 0
    Dim Offset As Long = 0
    While Offset < CompilerTextLength(InputText)
        Dim CodePoint As Long = 0
        Dim ByteCount As Long = 0
        If DecodeCompilerUtf8(InputText, Offset, CodePoint, ByteCount) = 0 Then InvalidOffset = Offset: ValidateCompilerUtf8 = 0: Exit Function
        If CodePoint = 13 Then
            If Offset + ByteCount >= CompilerTextLength(InputText) Or CompilerTextByteAt(InputText, Offset + ByteCount) <> 10 Then InvalidOffset = Offset: ValidateCompilerUtf8 = 0: Exit Function
        End If
        Offset = Offset + ByteCount
        ScalarCount = ScalarCount + 1
    Wend
    ValidateCompilerUtf8 = 1
End Function

Function CompilerIdentifierStartBytes(ByVal InputText As String, ByVal Offset As Long) As Long
    If CompilerTextByteAt(InputText, Offset) = 95 Then CompilerIdentifierStartBytes = 1: Exit Function
    Dim CodePoint As Long = 0
    Dim ByteCount As Long = 0
    If DecodeCompilerUtf8(InputText, Offset, CodePoint, ByteCount) <> 0 And CompilerCodePointIsLetter(CodePoint) <> 0 Then
        CompilerIdentifierStartBytes = ByteCount
    Else
        CompilerIdentifierStartBytes = 0
    End If
End Function

Function CompilerIdentifierPartBytes(ByVal InputText As String, ByVal Offset As Long) As Long
    Dim Value As Long = CompilerTextByteAt(InputText, Offset)
    If Value >= 48 And Value <= 57 Then
        CompilerIdentifierPartBytes = 1
    Else
        CompilerIdentifierPartBytes = CompilerIdentifierStartBytes(InputText, Offset)
    End If
End Function

' Compares ASCII language words without host locale dependence.
Function CompilerAsciiEqualsFolded(ByVal LeftValue As String, ByVal RightValue As String) As Long
    If CompilerTextLength(LeftValue) <> CompilerTextLength(RightValue) Then CompilerAsciiEqualsFolded = 0: Exit Function
    Dim Index As Long = 0
    While Index < CompilerTextLength(LeftValue)
        Dim LeftByte As Long = CompilerTextByteAt(LeftValue, Index)
        Dim RightByte As Long = CompilerTextByteAt(RightValue, Index)
        If LeftByte >= 65 And LeftByte <= 90 Then LeftByte = LeftByte + 32
        If RightByte >= 65 And RightByte <= 90 Then RightByte = RightByte + 32
        If LeftByte <> RightByte Then CompilerAsciiEqualsFolded = 0: Exit Function
        Index = Index + 1
    Wend
    CompilerAsciiEqualsFolded = 1
End Function
