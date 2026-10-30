UBE SOURCE 1 MODULE
Attribute UBE_Name = "Strings"

' Returns the number of bytes in Value. UBE text is UTF-8, so callers that
' need characters rather than bytes should use the Unicode APIs.
Public Function StringByteLength(ByVal Value As String) As Long
    StringByteLength = StringLength(Value)
End Function

' Returns 1 when Value has no bytes and 0 otherwise.
Public Function StringIsEmpty(ByVal Value As String) As Long
    If StringLength(Value) = 0 Then
        StringIsEmpty = 1
    Else
        StringIsEmpty = 0
    End If
End Function
