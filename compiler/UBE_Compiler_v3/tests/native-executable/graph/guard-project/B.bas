UBE SOURCE 1 MODULE
Attribute UBE_Name = "B"
Public Value As Long = 12
Public Initializations As Long = Initializations + 1
Public Dependency As Long = C.Value
Public Calls As Long = 0
Public Function ReadValue() As Long
 Calls = Calls + 1
 ReadValue = Value
End Function
Public Function Accept(ByVal X As Long) As Long
 Calls = Calls + 1
 Accept = X + Value
End Function
Public Type Wide As Long
End Type
Public Intrinsic Function Pack(ByVal Bits As Long) As Wide
Attribute Pack.UBE_Primitive = "Value.Pack"
End Function
Public Intrinsic Function Unpack(ByVal Item As Wide) As Long
Attribute Unpack.UBE_Primitive = "Value.Unpack"
End Function
