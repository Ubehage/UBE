UBE SOURCE 1 MODULE
Attribute UBE_Name = "Err"
' Provides an ordinary user module whose spelling matches the support receiver.
Public Marker As Long
' This user declaration has no trusted runtime-error role.
Public Sub Raise(ByVal Value As Long)
    Marker = Value
End Sub
