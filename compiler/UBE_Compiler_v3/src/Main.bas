UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Intrinsic Function CommandArgumentCount() As Long
End Function
Intrinsic Function LongToString(ByVal Value As Long) As String
End Function

' Keep entry rootless so managed dispatch failure can report a static diagnostic.
Function Main() As Long
    Main = 1
    Dim ExitCode As Long = 1
    If TryRunCompilerCommand(ExitCode) Then
        Main = ExitCode
    Else
        Call PrintProjectStorageFailure()
    End If
End Function
