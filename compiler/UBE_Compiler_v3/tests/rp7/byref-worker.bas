UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Public SubObserved As Long
Public FunctionObserved As Long
Public FunctionResultObserved As Long

Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

Sub SetValue(ByRef Value As Long)
    Value = 41
End Sub

Function IncrementValue(ByRef Value As Long) As Long
    Value = Value + 1
    IncrementValue = Value
End Function

Sub Worker()
    Dim Value As Long
    Value = 1
    Call SetValue(Value)
    SubObserved = Value

    Value = 5
    FunctionResultObserved = IncrementValue(Value)
    FunctionObserved = Value
End Sub

Sub Main()
    Dim Id As LongLong
    Id = CallNew Worker()
    Print RuntimeThreadWait(Id, 5000)
    Print SubObserved
    Print FunctionResultObserved
    Print FunctionObserved
End Sub
