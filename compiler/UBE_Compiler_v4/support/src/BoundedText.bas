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
