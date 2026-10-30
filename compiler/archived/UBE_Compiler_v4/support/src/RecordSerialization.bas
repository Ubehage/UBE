UBE SOURCE 1 MODULE
Attribute UBE_Name = "RecordSerialization"

Function IsRecordKey(ByVal Key As String) As Long
    Dim KeyLength As Long = StringLength(Key)
    If KeyLength = 0 Then
        IsRecordKey = 0
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < KeyLength
        Dim Value As Long = StringByteAt(Key, Index)
        If (Value < 48 Or Value > 57) And (Value < 65 Or Value > 90) And (Value < 97 Or Value > 122) And Value <> 95 And Value <> 45 Then
            IsRecordKey = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    IsRecordKey = 1
End Function

' Appends one canonical key=value line within MaxBytes. Keys are nonempty
' ASCII letters, digits, underscore, or hyphen; values cannot contain CR/LF.
' Returns 0 without changing Buffer when validation or the bound fails.
Public Function AppendRecordField(ByRef Buffer As String, ByVal Key As String, ByVal Value As String, ByVal MaxBytes As Long) As Long
    If IsRecordKey(Key) = 0 Then
        AppendRecordField = 0
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < StringLength(Value)
        Dim CurrentByte As Long = StringByteAt(Value, Index)
        If CurrentByte = 10 Or CurrentByte = 13 Then
            AppendRecordField = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    Dim SerializedLine As String = Key & "=" & Value & StringFromByte(10)
    AppendRecordField = AppendBoundedText(Buffer, SerializedLine, MaxBytes)
End Function
