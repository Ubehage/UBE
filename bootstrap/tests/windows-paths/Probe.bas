UBE SOURCE 1 MODULE
Attribute UBE_Name = "PathProbe"
' Observes path-policy outputs and atomic publication independently of implementation details.

' Selects the public helper without changing its inputs or expected failure semantics.
Private Function Invoke(ByVal Operation As Long, ByRef First() As Byte, ByRef Second() As Byte, ByRef Result() As Byte, ByRef Value As Boolean, ByRef Failure As Long) As Boolean
    If Operation = 1 Then Invoke = WindowsPaths.TryNormalizePhysical(First, Result, Failure)
    If Operation = 2 Then Invoke = WindowsPaths.TryParent(First, Result, Failure)
    If Operation = 3 Then Invoke = WindowsPaths.TryResolveSource(First, Second, Result, Failure)
    If Operation = 4 Then Invoke = WindowsPaths.TryIsWithin(First, Second, Value, Failure)
    If Operation = 5 Then Invoke = WindowsPaths.TrySamePath(First, Second, Value, Failure)
End Function

' Compares exact bytes, Boolean status and sticky errors, including input/output aliases.
Public Function Check(ByVal Operation As Long, ByRef First() As Byte, ByRef Second() As Byte, ByRef Expected() As Byte, ByVal ExpectedValue As Boolean, ByVal ExpectedFailure As Long, ByVal AliasInput As Long) As Long
    Dim Result(0 To 1) As Byte
    Dim Value As Boolean = True
    Dim Status As Boolean
    Dim Failure As Long = 99
    Dim Index As Long
    Dim Length As Long
    Result(0) = 79
    Result(1) = 75
    If AliasInput = 1 Then
        If Not BufferPrimitives.TryCopyBytes(Result, First) Then Check = 1: Exit Function
    End If
    If AliasInput = 2 Then
        If Not BufferPrimitives.TryCopyBytes(Result, Second) Then Check = 1: Exit Function
    End If
    Status = FilePrimitives.SetError(71)
    If AliasInput = 1 Then
        Status = Invoke(Operation, Result, Second, Result, Value, Failure)
    ElseIf AliasInput = 2 Then
        Status = Invoke(Operation, First, Result, Result, Value, Failure)
    Else
        Status = Invoke(Operation, First, Second, Result, Value, Failure)
    End If
    If Status <> (ExpectedFailure = 0) Or Failure <> ExpectedFailure Then Check = 2: Exit Function
    If ExpectedFailure <> 0 Then
        If Err.Number <> 5 Or Not Value Then Check = 3: Exit Function
    Else
        If Err.Number <> 71 Then Check = 4: Exit Function
        If Operation >= 4 Then
            If Value <> ExpectedValue Then Check = 5: Exit Function
        End If
    End If
    Length = BufferPrimitives.ByteStorageLength(Expected)
    If BufferPrimitives.ByteStorageLength(Result) <> Length Then Check = 6: Exit Function
    Do While Index < Length
        If Result(Index) <> Expected(Index) Then Check = 7: Exit Function
        Index = Index + 1
    Loop
End Function

' Starts with inline storage so every measured allocation belongs to the selected helper.
Public Function CheckAllocation(ByVal Operation As Long, ByRef First() As Byte, ByRef Second() As Byte) As Long
    Dim Result(0 To 1) As Byte
    Dim Value As Boolean = True
    Dim Status As Boolean
    Dim Failure As Long = 99
    Result(0) = 79
    Result(1) = 75
    Status = FilePrimitives.SetError(71)
    Status = Invoke(Operation, First, Second, Result, Value, Failure)
    If Status Or Failure <> 3 Or Err.Number <> 7 Or Not Value Then CheckAllocation = 1: Exit Function
    If BufferPrimitives.ByteStorageLength(Result) <> 2 Then CheckAllocation = 2: Exit Function
    If Result(0) <> 79 Or Result(1) <> 75 Then CheckAllocation = 3: Exit Function
End Function
