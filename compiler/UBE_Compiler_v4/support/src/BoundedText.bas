UBE SOURCE 1 MODULE
Attribute UBE_Name = "BoundedText"

' Appends Fragment only when the resulting byte length is within MaxBytes.
' Returns 1 on success and 0 without changing Buffer on invalid input or limit
' exhaustion. Each Buffer must have one mutation owner at a time.
Public Function AppendBoundedText(ByRef Buffer As String, ByVal Fragment As String, ByVal MaxBytes As Long) As Long
    If MaxBytes < 0 Then
        AppendBoundedText = 0
        Exit Function
    End If
    Dim BufferBytes As Long = StringLength(Buffer)
    Dim FragmentBytes As Long = StringLength(Fragment)
    If BufferBytes > MaxBytes Or FragmentBytes > MaxBytes - BufferBytes Then
        AppendBoundedText = 0
        Exit Function
    End If
    Buffer = Buffer & Fragment
    AppendBoundedText = 1
End Function

' Returns the byte at Index, or -1 when Index is outside Value. This bounded
' compiler-support view keeps bootstrap string intrinsics private.
Public Function CompilerTextByteAt(ByVal Value As String, ByVal Index As Long) As Long
    If Index < 0 Or Index >= StringLength(Value) Then
        CompilerTextByteAt = -1
    Else
        CompilerTextByteAt = StringByteAt(Value, Index)
    End If
End Function

' Copies a byte slice into Result. Invalid ranges return 0 and clear Result.
Public Function CompilerTextSlice(ByVal Value As String, ByVal StartIndex As Long, ByVal Length As Long, ByRef Result As String) As Long
    Result = ""
    If StartIndex < 0 Or Length < 0 Then
        CompilerTextSlice = 0
        Exit Function
    End If
    Dim ValueLength As Long = StringLength(Value)
    If StartIndex > ValueLength Or Length > ValueLength - StartIndex Then
        CompilerTextSlice = 0
        Exit Function
    End If
    Result = StringSlice(Value, StartIndex, Length)
    CompilerTextSlice = 1
End Function

' Returns one byte as a string for compiler-owned serialization. Values
' outside the byte range return an empty string.
Public Function CompilerTextFromByte(ByVal Value As Long) As String
    If Value < 0 Or Value > 255 Then
        CompilerTextFromByte = ""
    Else
        CompilerTextFromByte = StringFromByte(Value)
    End If
End Function

' Returns the UTF-8 byte length used by compiler phase bounds.
Public Function CompilerTextLength(ByVal Value As String) As Long
    CompilerTextLength = StringLength(Value)
End Function

' Formats a nonnegative Long without exposing a conversion intrinsic. Negative
' input is outside the phase-counter contract and returns an empty string.
Public Function CompilerLongToText(ByVal Value As Long) As String
    If Value < 0 Then
        CompilerLongToText = ""
        Exit Function
    End If
    If Value = 0 Then
        CompilerLongToText = "0"
        Exit Function
    End If
    Dim Result As String = ""
    While Value > 0
        Dim Digit As Long = Value Mod 10
        Result = StringFromByte(48 + Digit) & Result
        Value = Value \ 10
    Wend
    CompilerLongToText = Result
End Function
