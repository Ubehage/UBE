Type Packet
    Bytes() As Byte
    Count As Long
End Type

Sub FillBytes(ByRef Data() As Byte)
    ReDim Data(0)
    Data(0) = 29
End Sub

Function ReadAddress(ByRef State As Packet) As Long
    ReadAddress = State.Count
End Function

Function ReadValue(ByVal State As Packet) As Long
    Dim Copy As Packet = State
    Copy.Count = 23
    ReadValue = Copy.Count
End Function

Function MakePacket(ByVal Value As Long) As Packet
    Dim Item As Packet
    Item.Count = Value
    Call FillBytes(Item.Bytes)
    MakePacket = Item
End Function

Function Main() As Long
    Dim State As Packet
    Dim Other As Packet
    State.Count = 17
    Call FillBytes(State.Bytes)
    State.Bytes(0) = 65
    Print ReadAddress(State)
    Print ReadValue(State)
    Print State.Count
    Other = MakePacket(31)
    Print ReadAddress(Other)
    Print Other.Bytes(0)
    Main = 0
End Function
