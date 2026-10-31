Type Parcel
    Bytes() As Byte
    Stamp As Long
End Type

Intrinsic Function CollectNow() As Long
Attribute CollectNow.UBE_Primitive = "Memory.Collect"
End Function

Function MakeBytes(ByVal Value As Byte) As Byte()
    Dim Data() As Byte
    ReDim Data(1)
    Data(0) = Value
    Data(1) = 255
    MakeBytes = Data
End Function

Function PassBytes(ByVal Data() As Byte) As Byte()
    PassBytes = Data
    Data(0) = 88
End Function

Function MakeParcel(ByVal Value As Byte) As Parcel
    Dim Result As Parcel
    Result.Bytes = MakeBytes(Value)
    Result.Stamp = 1234
    MakeParcel = Result
    Result.Bytes(0) = 99
End Function

Function Main() As Long
    Dim First() As Byte = PassBytes(MakeBytes(65))
    Dim Second() As Byte = First
    First(0) = 66
    Print Second(0)
    Print First(0)
    Dim Box As Parcel = MakeParcel(70)
    Dim Copy As Parcel = Box
    Box.Bytes(0) = 71
    Call CollectNow()
    Print Copy.Bytes(0)
    Print Box.Bytes(0)
    Print Box.Bytes(1)
    Print Copy.Stamp
    Main = 0
End Function
