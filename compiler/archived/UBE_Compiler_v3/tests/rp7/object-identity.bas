UBE SOURCE 1 MODULE
Attribute UBE_Name = "RP7ObjectIdentityMain"

Sub Main()
    Dim First As New EventSource
    Dim Second As EventSource
    Set Second = First
    Print First Is Second
    Set Second = Nothing
    Print Second Is Nothing
End Sub
