Type OwnedResult
    Data() As Byte
    Marker As Long
End Type

Sub Initialize(ByRef Source() As Byte)
    ReDim Source(1)
    Source(0) = 65
    Source(1) = 255
End Sub

Function InspectCopy(ByVal Source() As Byte) As Long
    Source(0) = 88
    InspectCopy = 123
End Function

Function ArrayResult(ByRef Source() As Byte) As Byte()
    ArrayResult = Source
End Function

Function RecordCopy(ByRef Source As OwnedResult) As OwnedResult
    RecordCopy = Source
End Function

Function FirstByte(ByRef Source() As Byte) As Long
    FirstByte = Source(0)
End Function

Sub MutateSource(ByRef Source() As Byte)
    Source(0) = 66
End Sub

Sub InitializeRecord(ByRef Source As OwnedResult)
    Call Initialize(Source.Data)
    Source.Marker = 123
End Sub

Function Main() As Long
    Main = 0
End Function
