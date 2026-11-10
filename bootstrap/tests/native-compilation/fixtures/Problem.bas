UBE SOURCE 1 MODULE
Attribute UBE_Name = "Problem"
' Supplies failures during another module's initialization without an init cycle.
' Provides a distinct initialized module whose call fails during another initializer.
Public Function RaiseNow() As Long
    Err.Raise 5
End Function
