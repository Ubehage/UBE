UBE SOURCE 1 MODULE
Attribute UBE_Name = "AggregateBinding"

Private Type Measurement
    Value As Double
    Rounded As Single
    Label As String
End Type
Private Type Report
    First As Measurement
    Second As Measurement
End Type
Private Calls As Long

Private Intrinsic Function ResizeValues(ByRef Values() As Single, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeValues.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function MoveValues(ByRef Destination() As Single, ByRef Source() As Single) As Boolean
Attribute MoveValues.UBE_Primitive = "Array.Move"
End Function
Private Intrinsic Function Length(ByRef Values() As Single) As Long
Attribute Length.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function CollectGarbage() As Long
Attribute CollectGarbage.UBE_Primitive = "Memory.Collect"
End Function
Private Function ChangeTemporary(ByRef Value As Single) As Double
    Calls = Calls + 1
    Value = Value + 0.5!
    ChangeTemporary = Value
End Function
Private Function RuntimeValue(ByVal Value As Double) As Double
    RuntimeValue = Value
End Function

Public Function Main() As Long
    Dim Original As Report
    Dim Copy As Report
    Dim Values() As Single
    Dim Other() As Single
    Dim InputValue As Double
    Dim Result As Double
    On Error Resume Next
    Original.First.Value = 0.5#
    Original.First.Rounded = 0.25!
    Original.First.Label = "first"
    Original.Second.Value = -0#
    Original.Second.Rounded = 2.5!
    Original.Second.Label = "second"
    Copy = Original
    If Copy <> Original Then Main = 1: Exit Function
    Copy.Second.Value = 0#
    If Copy <> Original Then Main = 2: Exit Function
    Copy.First.Rounded = 0.5!
    If Copy = Original Then Main = 3: Exit Function
    If Original.First.Rounded <> 0.25! Then Main = 4: Exit Function
    Call CollectGarbage()
    If Original.First.Label <> "first" Or Copy.Second.Label <> "second" Then Main = 5: Exit Function
    If Not ResizeValues(Values, 2, False) Then Main = 6: Exit Function
    Values(0) = 1.5!: Values(1) = -2.5!
    Other = Values
    Other(0) = 3.5!
    If Values(0) <> 1.5! Then Main = 7: Exit Function
    If Not ResizeValues(Values, 4, True) Then Main = 8: Exit Function
    If Values(0) <> 1.5! Or Values(1) <> -2.5! Or Values(3) <> 0! Then Main = 9: Exit Function
    If Not MoveValues(Other, Values) Then Main = 10: Exit Function
    If Length(Values) <> 0 Or Length(Other) <> 4 Or Other(1) <> -2.5! Then Main = 11: Exit Function
    InputValue = RuntimeValue(1.25#)
    Result = ChangeTemporary((InputValue))
    If InputValue <> 1.25# Or Result <> 1.75# Or Calls <> 1 Then Main = 12: Exit Function
    InputValue = RuntimeValue(1E100)
    Result = 42#
    Result = ChangeTemporary((InputValue))
    If Result <> 42# Or Calls <> 1 Or Err.Number <> 6 Then Main = 13: Exit Function
End Function
