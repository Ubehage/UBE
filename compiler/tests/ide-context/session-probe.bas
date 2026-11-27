UBE SOURCE 1 MODULE
Attribute UBE_Name = "SessionProbe"
Option Explicit

#If IS_IN_IDE Then
Private Const SelectedBranch As Long = 1
#Else
Private Const SelectedBranch As Long = 0
#End If

Private Initialized As Long = InitializeSource()

Private Intrinsic Function CreateFile(ByRef Path() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute CreateFile.UBE_Primitive = "File.TryCreateNew"
End Function
Private Intrinsic Function WriteFile(ByVal Token As Long, ByRef Bytes() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Progress As Long, ByRef Failure As Long) As Boolean
Attribute WriteFile.UBE_Primitive = "File.TryWrite"
End Function
Private Intrinsic Function CloseFile(ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute CloseFile.UBE_Primitive = "File.TryClose"
End Function
Private Intrinsic Function YieldThread() As Boolean
Attribute YieldThread.UBE_Primitive = "Thread.Yield"
End Function

Private Function InitializeSource() As Long
    Dim Token As Long
    Dim Failure As Long
    Dim Progress As Long
    Dim Bytes(0 To 0) As Byte
    On Error GoTo Failed
    ' SENTINEL PATH
    Bytes(0) = 42
    If Not CreateFile(Path, Token, Failure) Then Err.Raise 5
    If Not WriteFile(Token, Bytes, 0, 1, Progress, Failure) Then Err.Raise 5
    If Progress <> 1 Then Err.Raise 5
    If Not CloseFile(Token, Failure) Then Err.Raise 5
    InitializeSource = 42
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Sub Helper()
    ' HELPER BODY
End Sub

Public Function Main() As Long
    On Error GoTo Failed
    If Initialized <> 42 Then Main = 7: Exit Function
    If IS_IN_IDE <> EXPECTED_CONTEXT Then Main = 8: Exit Function
    If SelectedBranch <> EXPECTED_BRANCH Then Main = 9: Exit Function
    Call Helper()
    ' RUN BODY
    Exit Function
Failed:
    Main = 99
End Function
