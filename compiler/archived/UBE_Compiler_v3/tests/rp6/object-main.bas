UBE SOURCE 1 MODULE
Attribute UBE_Name = "ObjectMain"

Intrinsic Function ManagedCollectGarbage() As Long
End Function

Sub Main()
    Dim Current As Counter
    Set Current = New Counter
    Print Current.Value
    Set Current = Nothing
    Print ManagedCollectGarbage()
    Dim LazyValue As New Counter
    Print LazyValue.Value
End Sub
