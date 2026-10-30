UBE SOURCE 1 MODULE
Attribute UBE_Name = "Memory"

' Runs a complete managed-memory collection. The collector also runs
' automatically; this function is useful for deterministic cleanup points.
' It returns 1 when cleanup work was done and 0 when nothing was ready.
Public Function CollectGarbage() As Long
    CollectGarbage = ManagedCollectGarbage()
End Function
