UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProcessProbe"
' Observes child ownership and fresh process outcomes while the native harness injects target failures.
Private LogToken As Long
Private ChildToken As Long
Private LastState As Long
Private LastExit As Long
Private LastFailure As Long
Private LastError As Long

' Acquires the test's private log before process fault injection begins.
Public Function PrepareLog(ByRef Path() As Byte) As Long
    Dim Failure As Long
    If Not FilePrimitives.TryCreateNew(Path, LogToken, Failure) Then PrepareLog = 100 + Failure
End Function

' Starts one child and reports its explicit status while retaining any failed-start cleanup owner.
Public Function StartAttempt(ByRef Application() As Byte, ByRef CommandLine() As Byte, ByRef Directory() As Byte) As Long
    Dim Status As Boolean
    LastFailure = 99
    Status = FilePrimitives.SetError(71)
    Status = ProcessPrimitives.TryStart(Application, CommandLine, Directory, LogToken, ChildToken, LastFailure)
    LastError = Err.Number
    If Status Then
        If LastFailure <> 0 Or LastError <> 71 Or ChildToken <= 0 Then StartAttempt = 100: Exit Function
    Else
        StartAttempt = LastFailure
        If LastFailure = 0 Then StartAttempt = 101
    End If
End Function

' Observes wait publication with poisoned output fields and an older error.
Public Function WaitOnce(ByVal Milliseconds As Long) As Long
    Dim Status As Boolean
    LastState = 77
    LastExit = 88
    LastFailure = 99
    Status = FilePrimitives.SetError(71)
    Status = ProcessPrimitives.TryWait(ChildToken, Milliseconds, LastState, LastExit, LastFailure)
    LastError = Err.Number
    If Not Status Then WaitOnce = LastFailure
End Function

' Requests tree termination without clearing its owner token.
Public Function StopOnce() As Long
    Dim Status As Boolean
    Status = FilePrimitives.SetError(71)
    Status = ProcessPrimitives.TryTerminate(ChildToken, LastFailure)
    LastError = Err.Number
    If Not Status Then StopOnce = LastFailure
End Function

' Drains normal completion while allowing asynchronous job accounting to catch up with root exit.
Public Function WaitComplete() As Long
    Dim Attempts As Long
    Dim Result As Long
    Do While Attempts < 200
        Result = WaitOnce(25)
        If Result <> 0 Then WaitComplete = Result: Exit Function
        If LastState = 1 Then Exit Function
        Attempts = Attempts + 1
    Loop
    WaitComplete = 100
End Function

' Rejects overlapping wait outputs without publishing either value or consuming the child owner.
Public Function CheckAliases() As Long
    Dim Value As Long = 93
    Dim Failure As Long = 94
    If ProcessPrimitives.TryWait(ChildToken, 0, Value, Value, Failure) Then CheckAliases = 1: Exit Function
    If Value <> 93 Or Failure <> 94 Then CheckAliases = 2: Exit Function
    If ProcessPrimitives.TryWait(ChildToken, 0, Value, Failure, Failure) Then CheckAliases = 3: Exit Function
    If Value <> 93 Or Failure <> 94 Then CheckAliases = 4: Exit Function
End Function

' Attempts release and exposes a preserved token when any native close fails.
Public Function CloseOnce() As Long
    Dim Status As Boolean
    Status = FilePrimitives.SetError(71)
    Status = ProcessPrimitives.TryClose(ChildToken, LastFailure)
    LastError = Err.Number
    If Not Status Then CloseOnce = LastFailure
End Function

' Prevents file and process operations from accepting each other's owner tokens.
Public Function CheckKinds() As Long
    Dim Saved As Long
    Dim Failure As Long
    Dim Count As Long = 91
    Dim Buffer(0 To 1) As Byte
    Saved = LogToken
    If ProcessPrimitives.TryClose(LogToken, Failure) Or Failure <> 9 Or LogToken <> Saved Then CheckKinds = 1: Exit Function
    Saved = ChildToken
    If FilePrimitives.TryClose(ChildToken, Failure) Or Failure <> 9 Or ChildToken <> Saved Then CheckKinds = 2: Exit Function
    If FilePrimitives.TryFlush(ChildToken, Failure) Or Failure <> 9 Then CheckKinds = 3: Exit Function
    If FilePrimitives.TryFinalPath(ChildToken, Buffer, Count, Failure) Or Failure <> 9 Or Count <> 91 Then CheckKinds = 4: Exit Function
End Function

' Reads captured fields without conflating sticky Err with the last operation's Boolean status.
Public Function Field(ByVal Index As Long) As Long
    If Index = 0 Then Field = ChildToken
    If Index = 1 Then Field = LastState
    If Index = 2 Then Field = LastExit
    If Index = 3 Then Field = LastFailure
    If Index = 4 Then Field = LastError
    If Index = 5 Then Field = LogToken
End Function

' Terminates and drains retained children under a bounded test deadline, then explicitly closes the owner.
Public Function CleanupChild() As Long
    Dim Failure As Long
    Dim State As Long
    Dim ExitCode As Long
    Dim Attempts As Long
    If ChildToken = 0 Then Exit Function
    If Not ProcessPrimitives.TryTerminate(ChildToken, Failure) Then CleanupChild = 1: Exit Function
    Do While Attempts < 200
        If Not ProcessPrimitives.TryWait(ChildToken, 25, State, ExitCode, Failure) Then CleanupChild = 2: Exit Function
        If State = 1 Then Exit Do
        Attempts = Attempts + 1
    Loop
    If State <> 1 Then CleanupChild = 3: Exit Function
    If Not ProcessPrimitives.TryClose(ChildToken, Failure) Then CleanupChild = 4: Exit Function
    If ChildToken <> 0 Then CleanupChild = 5
End Function

' Closes the independent caller-owned log only after every child owner has been released.
Public Function CloseLog() As Long
    Dim Failure As Long
    If ChildToken <> 0 Then CloseLog = 1: Exit Function
    If Not FilePrimitives.TryClose(LogToken, Failure) Then CloseLog = 2
End Function
