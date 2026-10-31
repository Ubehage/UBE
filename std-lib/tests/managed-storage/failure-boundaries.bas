Sub Initialize(ByRef Source() As Byte, ByRef Destination() As Byte)
    ReDim Source(1)
    Source(0) = 65
    Source(1) = 255
    ReDim Destination(0)
    Destination(0) = 9
End Sub

Sub CopyValue(ByRef Source() As Byte, ByRef Destination() As Byte)
    Destination = Source
End Sub

Function GrowValue(ByRef Destination() As Byte) As Boolean
    GrowValue = ResizeBytes(Destination, 4, True)
End Function

Sub Observe(ByRef Source() As Byte, ByRef Destination() As Byte)
    Print Source(0)
    Print Destination(0)
    Print CountBytes(Destination)
End Sub

Sub MutateSource(ByRef Source() As Byte)
    Source(0) = 66
End Sub

Sub ObserveGrowth(ByRef Destination() As Byte)
    Print Destination(0)
    Print Destination(1)
    Print Destination(2)
    Print Destination(3)
End Sub

Intrinsic Function CountBytes(ByRef Values() As Byte) As Long
Attribute CountBytes.UBE_Primitive = "Array.Length"
End Function

Intrinsic Function ResizeBytes(ByRef Values() As Byte, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeBytes.UBE_Primitive = "Array.TryResize"
End Function

Function Main() As Long
    Main = 0
End Function
