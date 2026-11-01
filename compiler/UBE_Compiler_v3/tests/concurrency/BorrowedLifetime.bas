UBE SOURCE 1 MODULE
Attribute UBE_Name = "BorrowedLifetime"

Intrinsic Function CollectNow() As Long
Attribute CollectNow.UBE_Primitive = "Memory.Collect"
End Function

Intrinsic Function StorageLength(ByRef Values() As Byte) As Long
Attribute StorageLength.UBE_Primitive = "Array.Length"
End Function

Intrinsic Function TryResizeStorage(ByRef Values() As Byte, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeStorage.UBE_Primitive = "Array.TryResize"
End Function

Sub DropOwnerWithElement(ByRef Value As Byte, ByRef Owner As BorrowedStorage)
    Set Owner = Nothing
    Call CollectNow()
    Print Value
    Value = 88
    Call CollectNow()
    Print Value
End Sub

Sub DropOwnerWithArray(ByRef Values() As Byte, ByRef Owner As BorrowedStorage)
    Set Owner = Nothing
    ReDim Values(1)
    Values(0) = 72
    Call CollectNow()
    Print Values(0)
    Print StorageLength(Values)
End Sub

Function Main() As Long
    Dim First As BorrowedStorage
    Set First = New BorrowedStorage
    Call TryResizeStorage(First.Bytes, 1, False)
    First.Bytes(0) = 65
    Call DropOwnerWithElement(First.Bytes(0), First)
    If First Is Nothing Then
        Print 7
    Else
        Print 0
    End If
    Dim Second As BorrowedStorage
    Set Second = New BorrowedStorage
    Call TryResizeStorage(Second.Bytes, 1, False)
    Second.Bytes(0) = 66
    Call DropOwnerWithArray(Second.Bytes, Second)
    If Second Is Nothing Then
        Print 9
    Else
        Print 0
    End If
    Call CollectNow()
    Main = 0
End Function
