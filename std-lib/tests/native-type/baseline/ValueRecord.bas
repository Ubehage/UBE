' Existing field-only Type semantics. This is not the proposed opaque type.
Type RecordOctet
    Storage As Byte
End Type

Function MakeRecord(ByVal Storage As Byte) As RecordOctet
    Dim ResultValue As RecordOctet
    ResultValue.Storage = Storage
    MakeRecord = ResultValue
End Function

Sub ChangeCopy(ByVal Value As RecordOctet)
    Value.Storage = 50
End Sub

Sub ChangeStorage(ByRef Value As RecordOctet)
    Value.Storage = 128
End Sub

Function TrySetRecord(ByVal InputValue As Long, ByRef Destination As RecordOctet) As Boolean
    If InputValue < 0 Or InputValue > 255 Then
        TrySetRecord = False
        Exit Function
    End If
    Destination.Storage = InputValue
    TrySetRecord = True
End Function
