UBE SOURCE 1 MODULE
Attribute UBE_Name = "ReferenceProbe"
Option Explicit

Private Intrinsic Function CollectGarbage() As Long
Attribute CollectGarbage.UBE_Primitive = "Memory.Collect"
End Function

Private Function Echo(ByVal Value As Gate) As Gate
    On Error GoTo Unexpected
    Set Echo = Value
    Exit Function
Unexpected:
    Err.Raise Err.Number
End Function

Private Sub Clear(ByRef Value As Gate)
    On Error GoTo Unexpected
    Set Value = Nothing
    Exit Sub
Unexpected:
    Err.Raise Err.Number
End Sub

Private Function Recurse(ByVal Value As Gate, ByVal Depth As Long) As Gate
    On Error GoTo Unexpected
    If Depth = 0 Then
        Set Recurse = Value
        Exit Function
    End If
    Set Recurse = Recurse(Value, Depth - 1)
    Exit Function
Unexpected:
    Err.Raise Err.Number
End Function

Private Function FailedValue() As Gate
    Err.Raise 17
End Function

Private Function DefaultFailure(ByVal Original As Gate) As Boolean
    Dim Value As Gate
    Set Value = Original
    Set Value = FailedValue()
    If Value Is Original Then
        If Err.Number = 17 Then DefaultFailure = True
    End If
End Function

Private Function HandlerFailure(ByVal Original As Gate) As Boolean
    On Error GoTo Caught
    Set Original = FailedValue()
    Exit Function
Caught:
    If Original IsNot Nothing Then
        If Err.Number = 17 Then HandlerFailure = True
    End If
End Function

Public Function Main() As Long
    Dim A As Gate
    Dim B As Gate
    Dim C As Gate
    Dim Passed As Boolean
    On Error GoTo Unexpected
    If A IsNot Nothing Then Main = 2: Exit Function
    Set A = New Gate
    Set B = A
    Set C = New Gate
    If A IsNot B Then Main = 1: Exit Function
    If A Is C Then Main = 3: Exit Function
    Set B = Echo(A)
    If A IsNot B Then Main = 4: Exit Function
    Set B = Recurse(A, 4)
    If A IsNot B Then Main = 5: Exit Function
    Clear B
    If B IsNot Nothing Then Main = 6: Exit Function
    If A Is Nothing Then Main = 7: Exit Function
    Call CollectGarbage()
    If A Is Nothing Or C Is Nothing Then Main = 8: Exit Function
    If A Is C Then Main = 9: Exit Function
    Passed = False
    Passed = DefaultFailure(A)
    If Not Passed Then Main = 10: Exit Function
    Passed = False
    Passed = HandlerFailure(A)
    If Not Passed Then Main = 11: Exit Function
    Set A = Nothing
    Set C = Nothing
    Call CollectGarbage()
    Exit Function
Unexpected:
    Main = 90
End Function
