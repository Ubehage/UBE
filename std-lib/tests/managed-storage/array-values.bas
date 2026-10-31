Intrinsic Function CountBytes(ByRef Values() As Byte) As Long
Attribute CountBytes.UBE_Primitive = "Array.Length"
End Function

Sub ChangeCopy(ByVal Values() As Byte)
    Values(0) = 88
    ReDim Preserve Values(4)
    Print Values(0)
    Print Values(4)
End Sub

Sub ChangeCaller(ByRef Values() As Byte)
    Values(1) = 99
End Sub

Function Main() As Long
    Dim Original() As Byte
    Dim Copy() As Byte
    Print CountBytes(Original)
    Copy = Original
    Print CountBytes(Copy)
    ReDim Original(2)
    Print Original(0)
    Print Original(2)
    Original(0) = 65
    Original(1) = 0
    Original(2) = 255
    Copy = Original
    Original(0) = 66
    Copy = Copy
    Call ChangeCopy(Copy)
    Print Copy(0)
    Print CountBytes(Copy)
    Call ChangeCaller(Copy)
    Print Copy(1)
    Print Original(1)
    Print Copy(2)
    ReDim Preserve Original(4)
    Print Original(0)
    Print Original(4)
    Print CountBytes(Copy)
    Main = 0
End Function
