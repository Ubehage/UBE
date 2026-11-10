UBE SOURCE 1 MODULE
Attribute UBE_Name = "AllocationProbe"
' Checks failure-atomic token publication with faults injected only at native allocation wrappers.
Private Source() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Count As Long
Private Diagnostic As SourceScanner.ScanDiagnostic

' Prepares old output independently of scanner-owned candidate storage.
Private Intrinsic Function ResizeTokens(ByRef Values() As SourceScanner.SourceToken, ByVal Length As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeTokens.UBE_Primitive = "Array.TryResize"
End Function

' Observes actual output storage rather than trusting the published Count.
Private Intrinsic Function TokenLength(ByRef Values() As SourceScanner.SourceToken) As Long
Attribute TokenLength.UBE_Primitive = "Array.Length"
End Function

' Builds forty symbols and a fully distinct sentinel token before allocation observation begins.
Public Function Prepare() As Long
    Dim Status As Boolean
    Dim Index As Long
    On Error GoTo Failed
    Status = BufferPrimitives.TryResizeBytes(Source, 40, False)
    If Status = False Then Prepare = 1: Exit Function
    Do While Index < 40
        Source(Index) = 43
        Index = Index + 1
    Loop
    Status = ResizeTokens(Tokens, 1, False)
    If Status = False Then Prepare = 2: Exit Function
    Tokens(0).Kind = 101
    Tokens(0).ByteStart = 102
    Tokens(0).ByteLength = 103
    Tokens(0).Line = 104
    Tokens(0).Column = 105
    Tokens(0).Utf16Start = 106
    Tokens(0).Utf16Length = 107
    Count = 777
    Call Err.Clear()
    Prepare = 0
    Exit Function
Failed:
    Prepare = 99
End Function

' Requires a recorded allocation failure, no partial count, and every old output field unchanged.
Public Function RejectAllocation() As Long
    Dim Status As Boolean
    Dim Failures As Long
    On Error GoTo Failed
    Status = SourceScanner.TryScan(Source, Tokens, Count, Diagnostic)
    If Status Then Failures = Failures + 1
    If Count <> 0 Then Failures = Failures + 1
    If Diagnostic.Code <> 5 Then Failures = Failures + 1
    If Diagnostic.Reason <> 1 Then Failures = Failures + 1
    If Err.Number <> 7 Then Failures = Failures + 1
    If TokenLength(Tokens) <> 1 Then RejectAllocation = 98: Exit Function
    If Tokens(0).Kind <> 101 Then Failures = Failures + 1
    If Tokens(0).ByteStart <> 102 Then Failures = Failures + 1
    If Tokens(0).ByteLength <> 103 Then Failures = Failures + 1
    If Tokens(0).Line <> 104 Then Failures = Failures + 1
    If Tokens(0).Column <> 105 Then Failures = Failures + 1
    If Tokens(0).Utf16Start <> 106 Then Failures = Failures + 1
    If Tokens(0).Utf16Length <> 107 Then Failures = Failures + 1
    RejectAllocation = Failures
    Exit Function
Failed:
    RejectAllocation = 99
End Function

' Repeats scanning after the fault clears and checks all retained spelling and position spans.
Public Function RetryScan() As Long
    Dim Status As Boolean
    Dim Failures As Long
    Dim Index As Long
    On Error GoTo Failed
    Status = SourceScanner.TryScan(Source, Tokens, Count, Diagnostic)
    If Status = False Then RetryScan = 97: Exit Function
    If Count <> 42 Or TokenLength(Tokens) <> 42 Then RetryScan = 98: Exit Function
    If Diagnostic.Code <> 0 Or Diagnostic.Reason <> 0 Then Failures = Failures + 1
    If Err.Number <> 7 Then Failures = Failures + 1
    Do While Index < 40
        If Tokens(Index).Kind <> SourceScanner.SymbolToken Then Failures = Failures + 1
        If Tokens(Index).ByteStart <> Index Then Failures = Failures + 1
        If Tokens(Index).ByteLength <> 1 Then Failures = Failures + 1
        If Tokens(Index).Line <> 1 Then Failures = Failures + 1
        If Tokens(Index).Column <> Index + 1 Then Failures = Failures + 1
        If Tokens(Index).Utf16Start <> Index + 1 Then Failures = Failures + 1
        If Tokens(Index).Utf16Length <> 1 Then Failures = Failures + 1
        Index = Index + 1
    Loop
    If Tokens(40).Kind <> SourceScanner.NewlineToken Then Failures = Failures + 1
    If Tokens(41).Kind <> SourceScanner.EndToken Then Failures = Failures + 1
    If Tokens(40).ByteStart <> 40 Or Tokens(41).ByteStart <> 40 Then Failures = Failures + 1
    If Tokens(40).ByteLength <> 0 Or Tokens(41).ByteLength <> 0 Then Failures = Failures + 1
    RetryScan = Failures
    Exit Function
Failed:
    RetryScan = 99
End Function

' Prepares either ordinary symbols or a quoted token, leaving failure output count neutral.
Public Function PrepareDepth(ByVal Quoted As Boolean) As Long
    Dim Result As Long
    On Error GoTo Failed
    Result = Prepare()
    If Result <> 0 Then PrepareDepth = Result: Exit Function
    If Quoted Then Source(0) = 34: Source(39) = 34
    Count = 0
    PrepareDepth = 0
    Exit Function
Failed:
    PrepareDepth = 99
End Function

' Gives a runtime depth-limit failure a normal record-only outer boundary when entry itself succeeds.
Public Function DepthAttempt() As Boolean
    On Error GoTo Failed
    DepthAttempt = SourceScanner.TryScan(Source, Tokens, Count, Diagnostic)
    Exit Function
Failed:
    DepthAttempt = False
End Function

' Checks successful depth controls or preserved old output after any propagated helper failure.
Public Function CheckDepth(ByVal Success As Boolean, ByVal Quoted As Boolean) As Long
    Dim Failures As Long
    Dim Index As Long
    On Error GoTo Failed
    If Success Then
        If Diagnostic.Code <> 0 Then Failures = Failures + 1
        If Quoted Then
            If Count <> 3 Or TokenLength(Tokens) <> 3 Then CheckDepth = 98: Exit Function
            If Tokens(0).Kind <> SourceScanner.StringToken Then Failures = Failures + 1
            If Tokens(0).ByteLength <> 40 Or Tokens(0).Utf16Length <> 40 Then Failures = Failures + 1
            Index = 1
        Else
            If Count <> 42 Or TokenLength(Tokens) <> 42 Then CheckDepth = 98: Exit Function
            Do While Index < 40
                If Tokens(Index).Kind <> SourceScanner.SymbolToken Then Failures = Failures + 1
                If Tokens(Index).ByteStart <> Index Then Failures = Failures + 1
                Index = Index + 1
            Loop
        End If
        If Tokens(Index).Kind <> SourceScanner.NewlineToken Then Failures = Failures + 1
        If Tokens(Index + 1).Kind <> SourceScanner.EndToken Then Failures = Failures + 1
    Else
        If Count <> 0 Then Failures = Failures + 1
        If Err.Number <> 28 And Err.Number <> 5 Then Failures = Failures + 1
        If Diagnostic.Code <> 0 Then
            If Diagnostic.Utf16Offset < 1 Or Diagnostic.Line < 1 Or Diagnostic.Column < 1 Then Failures = Failures + 1
            If Diagnostic.ByteOffset < 0 Then Failures = Failures + 1
        End If
        If TokenLength(Tokens) <> 1 Then CheckDepth = 98: Exit Function
        If Tokens(0).Kind <> 101 Or Tokens(0).ByteStart <> 102 Or Tokens(0).ByteLength <> 103 Then Failures = Failures + 1
        If Tokens(0).Line <> 104 Or Tokens(0).Column <> 105 Then Failures = Failures + 1
        If Tokens(0).Utf16Start <> 106 Or Tokens(0).Utf16Length <> 107 Then Failures = Failures + 1
    End If
    CheckDepth = Failures
    Exit Function
Failed:
    CheckDepth = 99
End Function

' Rejects nonzero-based byte storage even when the requested scalar offset names an existing element.
Public Function CheckBounds() As Long
    Dim Positive(1 To 2) As Byte
    Dim Negative(-1 To 0) As Byte
    Dim ByteWidth As Long
    Dim Units As Long
    Dim Status As Boolean
    Dim Failures As Long
    On Error GoTo Failed
    Positive(1) = 65
    Positive(2) = 66
    Negative(-1) = 65
    Negative(0) = 66
    Status = Utf8.TrySequenceWidth(Positive, 1, 2, ByteWidth, Units)
    If Status Or ByteWidth <> 0 Or Units <> 0 Then Failures = Failures + 1
    Status = Utf8.TrySequenceWidth(Negative, 0, 1, ByteWidth, Units)
    If Status Or ByteWidth <> 0 Or Units <> 0 Then Failures = Failures + 1
    Count = 777
    Status = SourceScanner.TryScan(Positive, Tokens, Count, Diagnostic)
    If Status Or Count <> 0 Then Failures = Failures + 1
    Count = 777
    Status = SourceScanner.TryScan(Negative, Tokens, Count, Diagnostic)
    If Status Or Count <> 0 Then Failures = Failures + 1
    If TokenLength(Tokens) <> 1 Then CheckBounds = 98: Exit Function
    If Tokens(0).Kind <> 101 Or Tokens(0).ByteStart <> 102 Or Tokens(0).ByteLength <> 103 Then Failures = Failures + 1
    If Tokens(0).Line <> 104 Or Tokens(0).Column <> 105 Then Failures = Failures + 1
    If Tokens(0).Utf16Start <> 106 Or Tokens(0).Utf16Length <> 107 Then Failures = Failures + 1
    CheckBounds = Failures
    Exit Function
Failed:
    CheckBounds = 99
End Function
