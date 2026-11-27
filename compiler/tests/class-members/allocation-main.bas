UBE SOURCE 1 MODULE
Attribute UBE_Name = "AllocationProbe"
Option Explicit

Private Intrinsic Function Observe() As LongLong
Attribute Observe.UBE_Primitive = "Thread.CurrentId"
End Function

Private Function Handled(ByRef Value As Gate) As Boolean
    On Error GoTo Caught
    Set Value = New Gate
    Exit Function
Caught:
    If Err.Number = 7 Then Handled = True
End Function

Public Function Main() As Long
    Dim Value As Gate
    Dim Original As Gate
    Dim Passed As Boolean
    Set Value = New Gate
    Set Original = Value
    Value.Value = 37
    Call Helpers.RecordError(73)
    Set Value = New Gate
    If Value IsNot Original Or Value.Value <> 37 Or Err.Number <> 7 Then Main = 1: Exit Function
    On Error GoTo Unexpected
    Passed = False
    Passed = Handled(Value)
    If Not Passed Or Value IsNot Original Or Value.Value <> 37 Then Main = 2: Exit Function
    Set Value = New Gate
    If Value Is Original Or Value.Value <> 0 Then Main = 3: Exit Function
    Call Helpers.CollectGarbage()
    If Observe() <> 3 Then Main = 4: Exit Function
    Set Value = Nothing
    Set Original = Nothing
    Call Helpers.CollectGarbage()
    If Observe() <> 0 Then Main = 5: Exit Function
    Exit Function
Unexpected:
    Main = 99
End Function
