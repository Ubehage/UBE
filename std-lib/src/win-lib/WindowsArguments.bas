UBE SOURCE 1 MODULE
Attribute UBE_Name = "WindowsArguments"
' Encodes counted arguments for Windows child-process command lines without shell interpretation.

' Appends one quoted argument atomically; the caller supplies any separating space.
Public Function TryAppendQuotedArgument(ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Destination() As Byte, ByRef Used As Long) As Boolean
    Dim Scratch() As Byte
    Dim Capacity As Long
    Dim Needed As Long
    Dim Index As Long
    Dim Slashes As Long
    Dim Copies As Long
    Dim Position As Long
    Dim Value As Byte
    On Error GoTo Failed
    Capacity = BufferPrimitives.ByteStorageLength(Source)
    If Start < 0 Or Count < 0 Or Used < 0 Then TryAppendQuotedArgument = FilePrimitives.SetError(5): Exit Function
    If Start > Capacity Then TryAppendQuotedArgument = FilePrimitives.SetError(9): Exit Function
    If Count > Capacity - Start Then TryAppendQuotedArgument = FilePrimitives.SetError(9): Exit Function
    Capacity = BufferPrimitives.ByteStorageLength(Destination)
    If Used > Capacity Then TryAppendQuotedArgument = FilePrimitives.SetError(9): Exit Function
    Needed = 2
    Do While Index < Count
        Value = Source(Start + Index)
        If Value = 0 Then TryAppendQuotedArgument = FilePrimitives.SetError(5): Exit Function
        If Value = 92 Then
            Slashes = Slashes + 1
        Else
            Needed = Needed + Slashes + 1
            If Value = 34 Then Needed = Needed + Slashes + 1
            Slashes = 0
        End If
        Index = Index + 1
    Loop
    Needed = Needed + Slashes + Slashes
    If Needed > 131072 Or Needed > Capacity - Used Then TryAppendQuotedArgument = FilePrimitives.SetError(9): Exit Function
    If Not BufferPrimitives.TryResizeBytes(Scratch, Needed, False) Then Exit Function
    Scratch(0) = 34
    Position = 1
    Index = 0
    Slashes = 0
    Do While Index < Count
        Value = Source(Start + Index)
        If Value = 92 Then
            Slashes = Slashes + 1
        Else
            Copies = Slashes
            If Value = 34 Then Copies = Slashes + Slashes + 1
            Do While Copies > 0
                Scratch(Position) = 92
                Position = Position + 1
                Copies = Copies - 1
            Loop
            Scratch(Position) = Value
            Position = Position + 1
            Slashes = 0
        End If
        Index = Index + 1
    Loop
    Copies = Slashes + Slashes
    Do While Copies > 0
        Scratch(Position) = 92
        Position = Position + 1
        Copies = Copies - 1
    Loop
    Scratch(Position) = 34
    If Not BufferPrimitives.CopyByteRange(Scratch, 0, Destination, Used, Needed) Then Exit Function
    Used = Used + Needed
    TryAppendQuotedArgument = True
    Exit Function
Failed:
    TryAppendQuotedArgument = False
End Function

' Reads one zero-based argument from a nonempty raw Windows command line, preserving output on failure.
Public Function TryReadArgument(ByRef CommandLine() As Byte, ByVal Requested As Long, ByRef Destination() As Byte, ByRef Found As Boolean) As Boolean
    Dim Scratch() As Byte
    Dim Result() As Byte
    Dim Length As Long
    Dim Index As Long
    Dim Argument As Long
    Dim Used As Long
    Dim Quotes As Long
    Dim Slashes As Long
    Dim Pairs As Long
    Dim SequenceWidth As Long
    Dim Units As Long
    Dim Value As Byte
    On Error GoTo Failed
    Length = BufferPrimitives.ByteStorageLength(CommandLine)
    If Requested < 0 Or Length < 1 Or Length > 131072 Then TryReadArgument = FilePrimitives.SetError(5): Exit Function
    Do While Index < Length
        If CommandLine(Index) = 0 Then TryReadArgument = FilePrimitives.SetError(5): Exit Function
        If Not Utf8.TrySequenceWidth(CommandLine, Index, Length, SequenceWidth, Units) Then TryReadArgument = FilePrimitives.SetError(5): Exit Function
        Index = Index + SequenceWidth
    Loop
    If Not BufferPrimitives.TryResizeBytes(Scratch, Length, False) Then Exit Function
    Index = 0
    ' Windows treats the executable spelling separately: backslashes are literal here.
    If CommandLine(0) = 34 Then
        Index = 1
        Do While Index < Length
            Value = CommandLine(Index)
            Index = Index + 1
            If Value = 34 Then Exit Do
            Scratch(Used) = Value
            Used = Used + 1
        Loop
    Else
        Do While Index < Length
            Value = CommandLine(Index)
            If Value = 32 Or Value = 9 Then Exit Do
            Scratch(Used) = Value
            Used = Used + 1
            Index = Index + 1
        Loop
    End If
    If Requested = 0 Then GoTo Publish
    Do
        Do While Index < Length
            Value = CommandLine(Index)
            If Value <> 32 And Value <> 9 Then Exit Do
            Index = Index + 1
        Loop
        If Index = Length Then Found = False: TryReadArgument = True: Exit Function
        Argument = Argument + 1
        Used = 0
        Quotes = 0
        Slashes = 0
        Do While Index < Length
            Value = CommandLine(Index)
            If Quotes = 0 Then
                If Value = 32 Or Value = 9 Then Exit Do
            End If
            If Value = 92 Then
                Scratch(Used) = Value
                Used = Used + 1
                Slashes = Slashes + 1
                Index = Index + 1
            ElseIf Value = 34 Then
                Pairs = 0
                Do While Slashes >= 2
                    Pairs = Pairs + 1
                    Slashes = Slashes - 2
                Loop
                Used = Used - Pairs
                If Slashes = 0 Then
                    Quotes = Quotes + 1
                Else
                    Scratch(Used - 1) = 34
                End If
                Index = Index + 1
                Slashes = 0
                Do While Index < Length
                    If CommandLine(Index) <> 34 Then Exit Do
                    Quotes = Quotes + 1
                    If Quotes = 3 Then
                        Scratch(Used) = 34
                        Used = Used + 1
                        Quotes = 0
                    End If
                    Index = Index + 1
                Loop
                If Quotes = 2 Then Quotes = 0
            Else
                Scratch(Used) = Value
                Used = Used + 1
                Slashes = 0
                Index = Index + 1
            End If
        Loop
        If Argument = Requested Then GoTo Publish
    Loop
Publish:
    If Not BufferPrimitives.TryResizeBytes(Result, Used, False) Then Exit Function
    If Not BufferPrimitives.CopyByteRange(Scratch, 0, Result, 0, Used) Then Exit Function
    If Not BufferPrimitives.TryCopyBytes(Destination, Result) Then Exit Function
    Found = True
    TryReadArgument = True
    Exit Function
Failed:
    TryReadArgument = False
End Function
