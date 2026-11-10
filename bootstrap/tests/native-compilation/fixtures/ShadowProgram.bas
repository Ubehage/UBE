UBE SOURCE 1 MODULE
Attribute UBE_Name = "ShadowProgram"
' Verifies ordinary user declarations can shadow the trusted error-support receiver.
' A user module named Err must retain ordinary call behavior.
Public Function Main() As Long
    Err.Raise 5
    If Err.Marker = 5 Then Main = 0 Else Main = 1
End Function
