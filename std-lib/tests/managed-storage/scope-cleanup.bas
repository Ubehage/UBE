Type ByteOwner
    Data() As Byte
End Type

Intrinsic Function CollectNow() As Long
Attribute CollectNow.UBE_Primitive = "Memory.Collect"
End Function

Sub AllocateBytes(ByRef Data() As Byte)
    ReDim Data(15)
End Sub

Sub MakeLocal(ByVal Early As Boolean)
    Dim Local As ByteOwner
    Call AllocateBytes(Local.Data)
    Local.Data(0) = 65
    If Early Then
        Exit Sub
    End If
    Dim Copy As ByteOwner = Local
    Copy.Data(0) = 66
End Sub

Function Main() As Long
    Dim Index As Long
    Index = 0
    While Index < 1000
        Call MakeLocal(True)
        Call MakeLocal(False)
        Call CollectNow()
        Index = Index + 1
    Wend
    Main = 0
End Function
