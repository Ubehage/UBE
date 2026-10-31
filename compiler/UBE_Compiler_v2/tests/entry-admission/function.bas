Function RootedTry(ByRef Failure As Long) As Boolean
    Dim Bytes() As Byte
    Failure = 9
    RootedTry = True
End Function

Function CallMain() As Long
    CallMain = Main()
End Function

Function Main() As Long
    Dim First() As Byte
    Dim Second() As Byte
    Print "body"
    Main = 42
End Function
