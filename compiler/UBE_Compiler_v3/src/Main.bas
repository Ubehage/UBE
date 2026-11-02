UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Intrinsic Function CommandArgumentCount() As Long
End Function
Intrinsic Function LongToString(ByVal Value As Long) As String
End Function

' No managed local or argument is required to diagnose/close a failed dispatch.
Function Main() As Long
    Main = 1
    Dim ExitCode As Long = 1
    Dim FallbackCode As Long = 1310
    Dim OpenToken As Long = 0
    Dim ReleaseCode As Long = 1321
    If TryRunCompilerCommand(ExitCode, FallbackCode, OpenToken, ReleaseCode) Then
        Main = ExitCode
    Else
        Call PrintCompilerStorageFailure(FallbackCode)
    End If
    ' A reader publishes retained ownership before fallible managed work. Keep
    ' cleanup here so even a failed command/formatter entry cannot lose its token.
    If OpenToken <> 0 Then
        Dim CloseFailure As Long = 0
        If TryCloseByteFile(OpenToken, CloseFailure) = False Then
            If ReleaseCode = 1011 Then
                Print "error UBE1011: could not release source file; operating system cleanup is required"
            Else
                Print "error UBE1321: could not release project input; operating system cleanup is required"
            End If
            Main = 1
        End If
    End If
End Function
