UBE SOURCE 1 MODULE
Attribute UBE_Name = "ScannerProbe"
Private Source() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Count As Long
Private Diagnostic As SourceScanner.ScanDiagnostic
Private Const Control As Long = 0

Private Sub UnexpectedFailure()
    Err.Raise 53
End Sub

Private Function LoadInput() As Long
    Dim Path(0 To 8) As Byte
    Dim Bytes() As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Length As Long
    On Error GoTo Failed
    LoadInput = -1
    Path(0) = 105
    Path(1) = 110
    Path(2) = 112
    Path(3) = 117
    Path(4) = 116
    Path(5) = 46
    Path(6) = 98
    Path(7) = 105
    Path(8) = 110
    If Not FileBytes.TryReadAllBytes(Path, 10000, Bytes, Token, Failure) Then Exit Function
    Length = BufferPrimitives.ByteStorageLength(Bytes)
    If Length < 1 Then Exit Function
    If Not BufferPrimitives.TryResizeBytes(Source, Length - 1, False) Then Exit Function
    If Not BufferPrimitives.CopyByteRange(Bytes, 1, Source, 0, Length - 1) Then Exit Function
    LoadInput = Bytes(0)
    Exit Function
Failed:
    LoadInput = -1
End Function

Private Function AllSelected() As Boolean
    Dim Position As SourceScanner.SourcePosition
    Dim Span As SourceScanner.SourceSpan
    Dim Selected(0 To 9) As SourceScanner.SourceSpan
    Dim Original() As SourceScanner.SourceToken
    Dim OriginalCount As Long
    Dim Used As Long
    Dim Index As Long
    On Error GoTo Failed
    If Not SourceScanner.TryBeginSource(Source, Position, Diagnostic) Then Exit Function
    Do
        If Not SourceScanner.TryReadLogicalLine(Source, Position, Span, Diagnostic) Then Exit Function
        If Span.Kind = SourceScanner.EndSpan Then Exit Do
        Selected(Used) = Span
        Used = Used + 1
    Loop
    If Used <> 6 + Control Then Exit Function
    If Not SourceScanner.TryScan(Source, Original, OriginalCount, Diagnostic) Then Exit Function
    If Not SourceScanner.TryScanSelected(Source, Selected, Used, Tokens, Count, Diagnostic) Then Exit Function
    If Count <> OriginalCount Then Exit Function
    For Index = 0 To Count - 1
        If Tokens(Index).Kind <> Original(Index).Kind Then Exit Function
        If Tokens(Index).ByteStart <> Original(Index).ByteStart Or Tokens(Index).ByteLength <> Original(Index).ByteLength Then Exit Function
        If Tokens(Index).Utf16Start <> Original(Index).Utf16Start Or Tokens(Index).Utf16Length <> Original(Index).Utf16Length Then Exit Function
        If Tokens(Index).Line <> Original(Index).Line Or Tokens(Index).Column <> Original(Index).Column Then Exit Function
    Next
    AllSelected = True
    Exit Function
Failed:
    AllSelected = False
End Function

Private Function OpaqueAndSelected() As Boolean
    Dim Position As SourceScanner.SourcePosition
    Dim Span As SourceScanner.SourceSpan
    Dim Selected(0 To 0) As SourceScanner.SourceSpan
    Dim Index As Long
    Dim Words As Long
    On Error GoTo Failed
    If Not SourceScanner.TryBeginSource(Source, Position, Diagnostic) Then Exit Function
    If Not SourceScanner.TryReadLogicalLine(Source, Position, Span, Diagnostic) Then Exit Function
    If Span.Kind <> SourceScanner.LogicalLineSpan Or Span.Finish.Line <> 2 Then Exit Function
    If Not SourceScanner.TryReadLogicalLine(Source, Position, Span, Diagnostic) Then Exit Function
    If Span.Kind <> SourceScanner.AssemblySpan Or Span.Start.Line <> 2 Or Span.Finish.Line <> 6 Then Exit Function
    If Not SourceScanner.TryReadLogicalLine(Source, Position, Span, Diagnostic) Then Exit Function
    If Span.Kind <> SourceScanner.LogicalLineSpan Or Span.Start.Line <> 6 Then Exit Function
    Selected(0) = Span
    If Not SourceScanner.TryScanSelected(Source, Selected, 1, Tokens, Count, Diagnostic) Then Exit Function
    For Index = 0 To Count - 1
        If Tokens(Index).Kind = SourceScanner.WordToken Then
            Words = Words + 1
            If Tokens(Index).Line <> 6 Or Tokens(Index).Column <> 1 Then Exit Function
            If Tokens(Index).ByteStart <> EXPECT_BYTE Or Tokens(Index).Utf16Start <> EXPECT_UTF16 Then Exit Function
        End If
    Next
    If Words <> 1 + Control Then Exit Function
    OpaqueAndSelected = True
    Exit Function
Failed:
    OpaqueAndSelected = False
End Function

Private Function ExpressionRange() As Boolean
    On Error GoTo Failed
    If Not SourceScanner.TryScanRange(Source, 4, BufferPrimitives.ByteStorageLength(Source), Tokens, Count, Diagnostic) Then Exit Function
    If Count <> 6 + Control Then Exit Function
    If Tokens(0).Kind <> SourceScanner.NumberToken Or Tokens(0).ByteStart <> 4 Or Tokens(0).Column <> 5 Then Exit Function
    If Tokens(2).Line <> 2 Or Tokens(2).Column <> 3 Or Tokens(2).ByteStart <> 21 Then Exit Function
    If Tokens(3).Kind <> SourceScanner.WordToken Then Exit Function
    ExpressionRange = True
    Exit Function
Failed:
    ExpressionRange = False
End Function

Private Function RejectionPreserves() As Boolean
    Dim Position As SourceScanner.SourcePosition
    Dim Selected(0 To 1) As SourceScanner.SourceSpan
    Dim Saved As Long
    On Error GoTo Failed
    If Not SourceScanner.TryScan(Source, Tokens, Count, Diagnostic) Then Exit Function
    Saved = Tokens(0).ByteStart
    If Not SourceScanner.TryBeginSource(Source, Position, Diagnostic) Then Exit Function
    If Not SourceScanner.TryReadLogicalLine(Source, Position, Selected(0), Diagnostic) Then Exit Function
    Selected(0).Start.Utf16Offset = 9
    If SourceScanner.TryScanSelected(Source, Selected, 1, Tokens, Count, Diagnostic) Then Exit Function
    If Count <> 0 Or Diagnostic.Code <> 2 + Control Or Tokens(0).ByteStart <> Saved Then Exit Function
    If SourceScanner.TryScanRange(Source, -1, 1, Tokens, Count, Diagnostic) Then Exit Function
    If Count <> 0 Or Tokens(0).ByteStart <> Saved Then Exit Function
    Selected(0).Start.Utf16Offset = 1
    Selected(1) = Selected(0)
    If SourceScanner.TryScanSelected(Source, Selected, 2, Tokens, Count, Diagnostic) Then Exit Function
    If Count <> 0 Or Tokens(0).ByteStart <> Saved Then Exit Function
    If SourceScanner.TryScanSelected(Source, Selected, 3, Tokens, Count, Diagnostic) Then Exit Function
    If Count <> 0 Or Tokens(0).ByteStart <> Saved Then Exit Function
    RejectionPreserves = True
    Exit Function
Failed:
    RejectionPreserves = False
End Function

Private Function ScalarBoundary() As Boolean
    Dim Saved As Long
    On Error GoTo Failed
    If Not SourceScanner.TryScan(Source, Tokens, Count, Diagnostic) Then Exit Function
    Saved = Tokens(0).ByteStart
    If SourceScanner.TryScanRange(Source, 2, BufferPrimitives.ByteStorageLength(Source), Tokens, Count, Diagnostic) Then Exit Function
    If Count <> 0 Or Tokens(0).ByteStart <> Saved + Control Then Exit Function
    If SourceScanner.TryScanRange(Source, 0, 2, Tokens, Count, Diagnostic) Then Exit Function
    If Count <> 0 Or Tokens(0).ByteStart <> Saved Then Exit Function
    ScalarBoundary = True
    Exit Function
Failed:
    ScalarBoundary = False
End Function

Private Function RejectedInput(ByVal Mode As Long) As Boolean
    Dim Position As SourceScanner.SourcePosition
    Dim Span As SourceScanner.SourceSpan
    On Error GoTo Failed
    If Mode = 5 Then
        If SourceScanner.TryBeginSource(Source, Position, Diagnostic) Then Exit Function
        If Diagnostic.Code <> 1 + Control Then Exit Function
    Else
        If Not SourceScanner.TryBeginSource(Source, Position, Diagnostic) Then Exit Function
        If SourceScanner.TryReadLogicalLine(Source, Position, Span, Diagnostic) Then Exit Function
        If Diagnostic.Code <> 2 + Control Or Diagnostic.Reason <> 5 Or Diagnostic.Line <> 1 Then Exit Function
        If Diagnostic.Column <> 3 Or Diagnostic.ByteOffset <> 2 Then Exit Function
        If Position.ByteOffset <> 0 Then Exit Function
    End If
    RejectedInput = True
    Exit Function
Failed:
    RejectedInput = False
End Function

Public Function Main() As Long
    Dim Mode As Long
    Dim Passed As Boolean
    On Error GoTo Failed
    Main = 90
    Mode = LoadInput()
    If Mode = 1 Then Passed = AllSelected()
    If Mode = 2 Then Passed = OpaqueAndSelected()
    If Mode = 3 Then Passed = ExpressionRange()
    If Mode = 4 Then Passed = RejectionPreserves()
    If Mode = 5 Or Mode = 6 Then Passed = RejectedInput(Mode)
    If Mode = 7 Then Passed = ScalarBoundary()
    If Passed Then Main = 0
    Exit Function
Failed:
    Main = 99
End Function
