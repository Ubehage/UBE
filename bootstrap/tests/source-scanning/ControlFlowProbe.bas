UBE SOURCE 1 MODULE
Attribute UBE_Name = "ControlFlowProbe"
' Exercises scanning operators, loop boundaries and fresh condition failures.

' Makes both operands observable even when the first Boolean decides the value.
Private Function Touch(ByRef Count As Long, ByVal Value As Boolean) As Boolean
    Count = Count + 1
    Touch = Value
End Function

' Returns a genuinely runtime-dependent failure or a usable Boolean.
Private Function Condition(ByVal Value As Long, ByRef Calls As Long) As Boolean
    Calls = Calls + 1
    If Value = 1 Then Err.Raise 5
    Condition = True
End Function

' Checks precedence, integer width, checked subtraction and eager evaluation.
Private Function Operators(ByVal Seed As Long) As Long
    Dim Failures As Long
    Dim Calls As Long
    Dim Flag As Boolean
    Dim Small As Integer
    Dim Octet As Byte
    Dim Wide As LongLong
    Dim Result As Long
    Dim Maximum As Long
    Result = Seed
    If Not Result = 1 Then Failures = Failures + 1
    Flag = True Or False And False
    If Flag = False Then Failures = Failures + 1
    Flag = Touch(Calls, True) Or Touch(Calls, False)
    If Calls <> 2 Then Failures = Failures + 1
    If Flag = False Then Failures = Failures + 1
    Flag = Not Flag
    If Flag Then Failures = Failures + 1
    Small = 0
    Small = Not Small
    If Small <> -1 Then Failures = Failures + 1
    Octet = 255
    Small = Not Octet
    If Small <> -256 Then Failures = Failures + 1
    Wide = 9223372036854775807^
    Wide = Not Wide
    If Wide <> -9223372036854775808^ Then Failures = Failures + 1
    Result = 5
    Maximum = 2
    Result = Result Or Maximum
    If Result <> 7 Then Failures = Failures + 1
    Result = 20 - 3 - 2
    If Result <> 15 Then Failures = Failures + 1
    Maximum = 2147483647
    Result = Not Maximum
    If Result <> -2147483648& Then Failures = Failures + 1
    Result = 37
    Call Err.Clear()
    Result = Maximum - -Seed
    If Result <> 37 Then Failures = Failures + 1
    If Err.Number <> 6 Then Failures = Failures + 1
    Operators = Failures
End Function

' Checks all Do forms, nearest Exit Do, zero iterations and nested traversal.
Private Function Loops(ByVal Seed As Long) As Long
    Dim Failures As Long
    Dim Count As Long
    Dim Inner As Long
    Dim Total As Long
    Do While Count < 3
        Count = Count + Seed
        If Seed = 0 Then Exit Do
    Loop
    If Count <> 3 Then Failures = Failures + 1
    Do Until Count = 5
        Count = Count + 1
        If Count > 5 Then Exit Do
    Loop
    If Count <> 5 Then Failures = Failures + 1
    Do While False
        Failures = Failures + 1
        Exit Do
    Loop
    Do Until True
        Failures = Failures + 1
        Exit Do
    Loop
    Count = 0
    Do
        Count = Count + 1
    Loop While Count < 3
    If Count <> 3 Then Failures = Failures + 1
    Do
        Count = Count - 1
    Loop Until Count = 0
    If Count <> 0 Then Failures = Failures + 1
    Do
        Count = Count + 1
        Inner = 0
        Do
            Inner = Inner + 1
            Total = Total + 1
            Exit Do
            Total = 100
        Loop
        If Inner <> 1 Then Failures = Failures + 1
        If Count = 3 Then Exit Do
    Loop
    If Total <> 3 Then Failures = Failures + 1
    Loops = Failures
End Function

' Checks failed conditions skip entire constructs rather than selecting False.
Private Function DefaultFailures(ByVal Seed As Long) As Long
    Dim Failures As Long
    Dim Calls As Long
    Dim Bodies As Long
    Dim Value As Long
    Call Err.Clear()
    If Condition(Seed, Calls) Then
        Failures = Failures + 1
    Else
        Failures = Failures + 1
    End If
    If Calls <> 1 Then Failures = Failures + 1
    If Err.Number <> 5 Then Failures = Failures + 1
    If False Then
        Failures = Failures + 1
    ElseIf Condition(Seed, Calls) Then
        Failures = Failures + 1
    Else
        Failures = Failures + 1
    End If
    If Condition(Seed, Calls) Then Failures = Failures + 1 Else Failures = Failures + 1
    Do While Condition(Seed, Calls)
        Bodies = Bodies + 1
        Exit Do
    Loop
    Do Until Condition(Seed, Calls)
        Bodies = Bodies + 1
        Exit Do
    Loop
    If Bodies <> 0 Then Failures = Failures + 1
    Do
        Bodies = Bodies + 1
        If Bodies > 2 Then Exit Do
    Loop While Condition(Seed, Calls)
    If Bodies <> 1 Then Failures = Failures + 1
    Do
        Bodies = Bodies + 1
        If Bodies > 3 Then Exit Do
    Loop Until Condition(Seed, Calls)
    If Bodies <> 2 Then Failures = Failures + 1
    If Calls <> 7 Then Failures = Failures + 1
    ' A later precondition failure must still use the loop continuation.
    Calls = 0
    Bodies = 0
    Value = 0
    Do While Condition(Value, Calls)
        Bodies = Bodies + 1
        Value = Seed
        If Bodies > 2 Then Exit Do
    Loop
    If Bodies <> 1 Then Failures = Failures + 1
    If Calls <> 2 Then Failures = Failures + 1
    DefaultFailures = Failures
End Function

' A failed body statement continues within the body and retains its destination.
Private Function BodyFailure(ByVal Seed As Long) As Long
    Dim Failures As Long
    Dim Count As Long
    Dim Calls As Long
    Dim Value As Boolean
    Do While Count < 2
        Value = False
        Value = Condition(Seed, Calls)
        If Value Then Failures = Failures + 1
        Count = Count + 1
    Loop
    If Count <> 2 Then Failures = Failures + 1
    If Calls <> 2 Then Failures = Failures + 1
    BodyFailure = Failures
End Function

' An enabled handler receives a failed header and can explicitly continue.
Private Function HandlerNext(ByVal Seed As Long) As Long
    Dim Failures As Long
    Dim Calls As Long
    Dim Handled As Long
    On Error GoTo Failed
    Do Until Condition(Seed, Calls)
        Failures = Failures + 1
        Exit Do
    Loop
AfterLoop:
    If Calls <> 1 Then Failures = Failures + 1
    If Handled <> 1 Then Failures = Failures + 1
    If Err.Number <> 5 Then Failures = Failures + 1
    HandlerNext = Failures: Exit Function
Failed:
    Handled = Handled + 1
    On Error GoTo 0
    GoTo AfterLoop
    HandlerNext = Failures
End Function

' A failed postcondition reaches the handler after exactly one completed body.
Private Function HandlerPost(ByVal Seed As Long) As Long
    Dim Failures As Long
    Dim Calls As Long
    Dim Bodies As Long
    Dim Value As Long
    Dim Handled As Long
    Value = Seed
    On Error GoTo Failed
    Do
        Bodies = Bodies + 1
        If Bodies > 2 Then Exit Do
    Loop Until Condition(Value, Calls)
AfterPost:
    If Bodies <> 1 Then Failures = Failures + 1
    If Calls <> 1 Then Failures = Failures + 1
    If Handled <> 1 Then Failures = Failures + 1
    HandlerPost = Failures: Exit Function
Failed:
    Handled = Handled + 1
    On Error GoTo 0
    GoTo AfterPost
    HandlerPost = Failures
End Function

' Nested failures in an active handler skip constructs without recursive entry.
Private Function ActiveHandler(ByVal Seed As Long) As Long
    Dim Failures As Long
    Dim Calls As Long
    Dim Handled As Long
    Dim Flag As Boolean
    On Error GoTo Failed
    Flag = Condition(Seed, Calls)
AfterHandler:
    If Handled <> 1 Then Failures = Failures + 1
    If Calls <> 3 Then Failures = Failures + 1
    If Err.Number <> 5 Then Failures = Failures + 1
    ActiveHandler = Failures: Exit Function
Failed:
    Handled = Handled + 1
    If Handled > 1 Then Failures = 99: ActiveHandler = Failures: Exit Function
    Do Until Condition(Seed, Calls)
        Failures = Failures + 1
        Exit Do
    Loop
    If Condition(Seed, Calls) Then
        Failures = Failures + 1
    Else
        Failures = Failures + 1
    End If
    GoTo AfterHandler
    ActiveHandler = Failures
End Function

' Aggregates independent observations; Seed zero is the input negative control.
Public Function Run(ByVal Seed As Long) As Long
    Run = Operators(Seed) + Loops(Seed) + DefaultFailures(Seed) + BodyFailure(Seed) + HandlerNext(Seed) + HandlerPost(Seed) + ActiveHandler(Seed)
End Function
