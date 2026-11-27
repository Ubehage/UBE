Private Intrinsic Function CollectGarbage() As Long
Attribute CollectGarbage.UBE_Primitive = "Memory.Collect"
End Function

Private Intrinsic Function ResizeValues(ByRef Values() As String, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeValues.UBE_Primitive = "Array.TryResize"
End Function

Private Function Retained(ByVal Depth As Long) As Long
    Dim Index As Long
    Dim ChildResult As Long
    On Error GoTo UnexpectedFailure
    For Index = 1 To 2
        Dim Kept As String
        Dim Values() As String
        Kept = "loop-local"
        If Not ResizeValues(Values, 2, False) Then Retained = 90: Exit Function
        Values(0) = "original"
        Values(1) = "tail"
        While True
            If Depth > 0 Then
                ChildResult = Retained(Depth - 1)
                If ChildResult <> 0 Then Retained = ChildResult: Exit Function
            End If
            Do
                Exit Loop
            Loop
        Wend
        Retained = 92
        Exit Function
    Next Index
    Call CollectGarbage()
    If Kept <> "loop-local" Then Retained = 1: Exit Function
    If Values(0) <> "original" Or Values(1) <> "tail" Then Retained = 2: Exit Function
    Values(0) = "changed"
    If Not ResizeValues(Values, 3, True) Then Retained = 3: Exit Function
    Call CollectGarbage()
    If Values(0) <> "changed" Or Values(1) <> "tail" Or Values(2) <> "" Then Retained = 4: Exit Function
    If Index <> 1 Then Retained = 5: Exit Function
    Exit Function
UnexpectedFailure:
    Retained = 99
End Function

Public Function Main() As Long
    Main = 99
    Main = Retained(3)
End Function
