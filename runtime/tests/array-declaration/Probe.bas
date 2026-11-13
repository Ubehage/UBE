UBE SOURCE 1 MODULE
Attribute UBE_Name = "ArrayDeclarationProbe"
Private Armed As Boolean
Private Ready As Boolean
Private WorkerId As LongLong
Private HookFailure As Long

Private Intrinsic Function Resize(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute Resize.UBE_Primitive = "Array.TryResize"
End Function

Private Intrinsic Function Length(ByRef Values() As Long) As Long
Attribute Length.UBE_Primitive = "Array.Length"
End Function

Private Sub Worker(ByRef Values() As Long)
    Do While Not Ready
        ThreadPrimitives.Yield
    Loop
    If Not Resize(Values, 2, False) Then Err.Raise 7
    Values(0) = 42
    Values(1) = 99
End Sub

' The test-only clear wrapper invokes this after the real descriptor clear unlocks.
Public Function Interleave() As Long
    If Armed Then
        Armed = False
        Ready = True
        If ThreadPrimitives.Wait(WorkerId, 5000) <> 1 Then HookFailure = 1
    End If
    Interleave = 93017
End Function

Public Function Probe() As Long
    Dim Iteration As Long
    Do While Iteration < 2
        Dim Values() As Long
        If Iteration = 0 Then
            WorkerId = CallNew Worker(Values)
            Armed = True
        Else
            If HookFailure <> 0 Then Probe = 1: Exit Function
            If Length(Values) <> 2 Then Probe = 2: Exit Function
            If Values(0) <> 42 Or Values(1) <> 99 Then Probe = 3: Exit Function
            If Not Resize(Values, 0, False) Then Probe = 4: Exit Function
            If Length(Values) <> 0 Then Probe = 5: Exit Function
        End If
        Iteration = Iteration + 1
    Loop
    Probe = 93018
End Function
