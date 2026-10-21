UBE SOURCE 1 MODULE
Attribute UBE_Name = "ObjectDispatchMain"

Intrinsic Function ManagedCollectGarbage() As Long
End Function

Sub Main()
    Dim First As New Worker
    Dim Second As New Worker
    Dim AliasValue As Worker
    Set AliasValue = First
    First.Current = 20
    Call AliasValue.Increment()
    Call Second.Increment()
    Print First.Current
    Print Second.Current
    Set First = Nothing
    Print AliasValue.Current
    Set AliasValue = Nothing
    Set Second = Nothing
    Print ManagedCollectGarbage()
End Sub
