UBE SOURCE 1 MODULE
Attribute UBE_Name = "Conversions"

' Returns the decimal text representation of Value.
Public Function ConvertLongToString(ByVal Value As Long) As String
    ConvertLongToString = LongToString(Value)
End Function

' Converts optional leading whitespace and a signed decimal number to Long.
' Invalid text and overflow return the neutral failure value zero.
Public Function ConvertStringToLong(ByVal Value As String) As Long
    Dim Index As Long = 0
    Dim Length As Long = StringLength(Value)
    Dim Sign As Long = 1
    Dim Result As Long = 0
    Dim DigitCount As Long = 0

    While Index < Length And (StringByteAt(Value, Index) = 32 Or StringByteAt(Value, Index) = 9)
        Index = Index + 1
    Wend
    If Index < Length Then
        If StringByteAt(Value, Index) = 45 Then
            Sign = -1
            Index = Index + 1
        Else
            If StringByteAt(Value, Index) = 43 Then
                Index = Index + 1
            End If
        End If
    End If
    While Index < Length
        Dim Character As Long = StringByteAt(Value, Index)
        If Character < 48 Or Character > 57 Then
            ConvertStringToLong = 0
            Exit Function
        End If
        ' Accumulate negatively so -2147483648 remains representable. The
        ' explicit bounds avoid relying on overflow behavior.
        Dim Digit As Long = Character - 48
        If Result < -214748364 Then
            ConvertStringToLong = 0
            Exit Function
        End If
        If Result = -214748364 Then
            If Sign = 1 And Digit > 7 Then
                ConvertStringToLong = 0
                Exit Function
            End If
            If Sign = -1 And Digit > 8 Then
                ConvertStringToLong = 0
                Exit Function
            End If
        End If
        Result = Result * 10 - Digit
        DigitCount = DigitCount + 1
        Index = Index + 1
    Wend
    If DigitCount = 0 Then
        ConvertStringToLong = 0
        Exit Function
    End If
    If Sign = 1 Then
        Result = -Result
    End If
    ConvertStringToLong = Result
End Function
