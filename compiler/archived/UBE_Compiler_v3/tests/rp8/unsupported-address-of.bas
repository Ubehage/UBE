UBE SOURCE 1 MODULE
Attribute UBE_Name = "UnsupportedAddressOfMain"

Sub Worker()
End Sub

Function Main() As Long
    Dim Callback As UIntPtr
    Callback = AddressOf Worker
    Main = 0
End Function
