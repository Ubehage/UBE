Type ByteBox
    Tag As Byte
    Data() As Byte
    Count As Integer
End Type

Type Envelope
    Item As ByteBox
    Marker As Long
End Type

Sub Fill(ByRef Data() As Byte)
    ReDim Data(1)
    Data(0) = 65
    Data(1) = 255
End Sub

Sub MutateCopy(ByVal Value As Envelope)
    Value.Item.Data(0) = 88
    Value.Item.Tag = 9
    Print Value.Item.Data(0)
End Sub

Sub MutateCaller(ByRef Value As Envelope)
    Value.Item.Data(1) = 99
End Sub

Function Main() As Long
    Dim Original As Envelope
    Dim Copy As Envelope
    Print Original.Item.Tag
    Print Original.Item.Count
    Print Original.Marker
    Call Fill(Original.Item.Data)
    Original.Item.Tag = 7
    Original.Item.Count = 2
    Original.Marker = 12345
    Copy = Original
    Original.Item.Data(0) = 66
    Original.Item.Tag = 8
    Call MutateCopy(Copy)
    Print Copy.Item.Data(0)
    Print Copy.Item.Tag
    Print Copy.Item.Count
    Print Copy.Marker
    Call MutateCaller(Copy)
    Print Copy.Item.Data(1)
    Print Original.Item.Data(1)
    Copy = Copy
    Print Copy.Item.Data(0)
    Main = 0
End Function
