UBE SOURCE 1 MODULE
Attribute UBE_Name = "ImageProbe"
' Observes executable validation independently from native backend invocation.

' Checks exact success/failure and verifies that the image reader released its owner.
Public Function Check(ByRef Path() As Byte, ByVal Maximum As Long, ByVal Expected As Boolean, ByVal ExpectedFailure As Long, ByVal CloseFails As Boolean) As Long
    Dim Token As Long
    Dim Failure As Long
    Dim SavedError As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = FilePrimitives.SetError(71)
    Status = WindowsImages.TryCheckAMD64Executable(Path, Maximum, Token, Failure)
    SavedError = Err.Number
    If Status <> Expected Then Check = 1: GoTo Cleanup
    If Failure <> ExpectedFailure Then Check = 2: GoTo Cleanup
    If Expected Then
        If SavedError <> 71 Then Check = 3: GoTo Cleanup
    Else
        If SavedError = 0 Or SavedError = 71 Then Check = 4: GoTo Cleanup
    End If
    If CloseFails Then
        If Token = 0 Then Check = 5: GoTo Cleanup
    Else
        If Token <> 0 Then Check = 6: GoTo Cleanup
    End If
Cleanup:
    If Not FilePrimitives.TryClose(Token, Failure) Then Check = 7
    Exit Function
Failed:
    Check = 8
    GoTo Cleanup
End Function
