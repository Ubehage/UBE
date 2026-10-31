Type Segment
    Bytes() As Byte
    Code As Long
End Type

Type Document
    Parts() As Segment
End Type

Intrinsic Function CollectNow() As Long
Attribute CollectNow.UBE_Primitive = "Memory.Collect"
End Function

Sub Fill(ByRef Data() As Byte, ByVal Value As Byte)
    ReDim Data(2)
    Data(0) = Value
    Data(2) = 255
End Sub

Sub Build(ByRef Parts() As Segment)
    ReDim Parts(1)
    Call Fill(Parts(0).Bytes, 65)
    Call Fill(Parts(1).Bytes, 70)
    Parts(0).Code = 111
    Parts(1).Code = 222
End Sub

Sub Churn()
    Dim Index As Long
    Index = 0
    While Index < 32
        Dim Scratch() As Byte
        ReDim Scratch(1023)
        Scratch(0) = 9
        Call CollectNow()
        Index = Index + 1
    Wend
End Sub

Function Main() As Long
    Dim Original As Document
    Dim Copy As Document
    Call Build(Original.Parts)
    Copy = Original
    Original.Parts(0).Bytes(0) = 66
    Call Churn()
    Call CollectNow()
    Print Original.Parts(0).Bytes(0)
    Print Copy.Parts(0).Bytes(0)
    Print Copy.Parts(1).Bytes(0)
    Print Copy.Parts(1).Bytes(2)
    Print Copy.Parts(0).Code
    Print Copy.Parts(1).Code
    Main = 0
End Function
