UBE SOURCE 1 MODULE
Attribute UBE_Name = "CallerRetention"

Type Parcel
    Data() As Byte
    Marker As Long
End Type

Intrinsic Function CollectNow() As Long
Attribute CollectNow.UBE_Primitive = "Memory.Collect"
End Function

Intrinsic Function ResizeBytes(ByRef Values() As Byte, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute ResizeBytes.UBE_Primitive = "Array.TryResize"
End Function

Sub FillArray(ByRef Output() As Byte)
    ReDim Output(2)
    Output(0) = 65
    Output(2) = 90
End Sub

Sub DirectArray(ByRef Output() As Byte)
    Call FillArray(Output)
    Call CollectNow()
End Sub

Sub FillRecord(ByRef Output As Parcel)
    Call ResizeBytes(Output.Data, 2, False)
    Output.Data(0) = 66
    Output.Data(1) = 91
    Output.Marker = 1234
End Sub

Sub DirectRecord(ByRef Output As Parcel)
    Call FillRecord(Output)
    Call CollectNow()
End Sub

Sub ForwardLeaf(ByRef Output() As Byte)
    Call FillArray(Output)
End Sub

Sub ForwardAlias(ByRef First() As Byte, ByRef Second() As Byte)
    Call ForwardLeaf(First)
    Call CollectNow()
    Second(1) = 67
End Sub

Sub ReplaceElement(ByRef Output As Parcel, ByRef Owner() As Parcel)
    ReDim Owner(0)
    Call FillRecord(Output)
    Call CollectNow()
End Sub

Sub ReplaceClassField(ByRef Output() As Byte, ByRef Owner As Carrier)
    Set Owner = Nothing
    Call FillArray(Output)
    Call CollectNow()
End Sub

Function Main() As Long
    Main = 0
End Function
