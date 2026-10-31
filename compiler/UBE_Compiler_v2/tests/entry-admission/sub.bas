Function RootedTry(ByRef Failure As Long) As Boolean
    Dim Bytes() As Byte
    Failure = 9
    RootedTry = True
End Function

Function CallMain() As Long
    Call Main()
    CallMain = 42
End Function

Sub Main()
    Dim First() As Byte
    Dim Second() As Byte
    Print "body"
End Sub
