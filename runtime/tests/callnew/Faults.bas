UBE SOURCE 1 MODULE
Attribute UBE_Name = "CaptureFaults"
' Exercises every allocation involved in boxes, snapshots, grouped captures and native worker startup.
Private Ready As Boolean
Private Observed As Long
Private Type Pair
    Value As Long
End Type

' Allocates ordinary array storage before capture preparation.
Private Intrinsic Function Resize(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute Resize.UBE_Primitive = "Array.TryResize"
End Function

' Uses every captured owner before publishing an independently calculated observation.
Private Sub Worker(ByRef Scalar As Long, ByRef Record As Pair, ByRef Values() As Long, ByVal RecordCopy As Pair, ByVal ArrayCopy() As Long, ByRef Temporary As Long)
    Do While Not Ready
        ThreadPrimitives.Yield
    Loop
    Observed = Scalar + Record.Value + Values(0) + RecordCopy.Value + ArrayCopy(0) + Temporary
    Scalar = 99
    Record.Value = 98
    Values(0) = 97
    Temporary = 96
End Sub

' Propagates a fresh startup failure after enabling any successfully admitted worker to finish.
Public Function Exercise() As Long
    Dim Scalar As Long = 1
    Dim Record As Pair
    Dim Values() As Long
    Dim Id As LongLong
    Dim Primary As Long
    On Error GoTo Failed
    Ready = False
    Observed = 0
    Record.Value = 2
    If Resize(Values, 2, False) = False Then Err.Raise 7
    Values(0) = 3
    Id = CallNew Worker(Scalar, Record, Values, Record, Values, (Scalar))
    Ready = True
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Then Exercise = 1: Exit Function
    If Observed <> 12 Then Exercise = 2: Exit Function
    If Scalar <> 99 Or Record.Value <> 98 Or Values(0) <> 97 Then Exercise = 3
    Exit Function
Failed:
    Primary = Err.Number
    Ready = True
    Err.Raise Primary
End Function
