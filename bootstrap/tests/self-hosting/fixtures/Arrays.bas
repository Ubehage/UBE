UBE SOURCE 1 MODULE
Attribute UBE_Name = "Entry"
' Exercises independently owned dynamic byte storage, preservation and checked spans.
Public Function Main() As Long
    Dim Values() As Byte
    Dim Copy() As Byte
    If Not BufferPrimitives.TryResizeBytes(Values, 3, False) Then Main = 1: Exit Function
    Values(0) = 10
    Values(1) = 20
    Values(2) = 12
    If Not BufferPrimitives.TryResizeBytes(Values, 8, True) Then Main = 2: Exit Function
    If Not BufferPrimitives.TryCopyBytes(Copy, Values) Then Main = 3: Exit Function
    Values(0) = 99
    If Copy(0) <> 10 Or Copy(1) <> 20 Or Copy(2) <> 12 Or Copy(7) <> 0 Then Main = 4: Exit Function
    Main = Copy(0) + Copy(1) + Copy(2)
End Function
