UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceInput"

' Compiler-owned source policy. See SOURCE-INPUT-CONTRACT.md.
' Fields are reserved state; one mutable owner; outputs must not alias inputs.
Type SourcePosition
    ByteOffset As Long
    ScalarOffset As Long
    LineNumber As Long
    Column As Long
End Type

Type SourceFailure
    Kind As Long
    Position As SourcePosition
End Type

Type SourceDocument
    Bytes() As Byte
    ContentStart As Long
    ScalarCount As Long
    LineCount As Long
End Type

Type SourceInput
    Buffer As ByteBuffer
    Decoder As Utf8Decoder
    Cursor As SourcePosition
    SequenceStart As SourcePosition
    CarriageReturn As SourcePosition
    ContentStart As Long
    MaximumBytes As Long
    PendingCarriageReturn As Boolean
    Ready As Boolean
End Type

' Resets the logical source, retaining buffer capacity; no allocation or Err change.
Function BeginSourceInput(ByRef State As SourceInput, ByVal MaximumBytes As Long) As Boolean
    BeginSourceInput = False
    If MaximumBytes < 0 Or MaximumBytes > 2147483646 Then
        Exit Function
    End If
    If ClearByteBuffer(State.Buffer) = False Then
        Exit Function
    End If
    Call ResetUtf8Decoder(State.Decoder)
    State.Cursor.ByteOffset = 0
    State.Cursor.ScalarOffset = 0
    State.Cursor.LineNumber = 1
    State.Cursor.Column = 1
    State.SequenceStart = State.Cursor
    State.CarriageReturn = State.Cursor
    State.ContentStart = 0
    State.MaximumBytes = MaximumBytes
    State.PendingCarriageReturn = False
    State.Ready = True
    BeginSourceInput = True
End Function

' Borrows a zero-based array byte range; validates private state before storage.
' Returns fresh failure data. Success and domain failures preserve Err.
Function AppendSourceInput(ByRef State As SourceInput, ByRef Bytes() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Failure As SourceFailure) As Boolean
    AppendSourceInput = False
    Failure.Kind = 1
    Failure.Position = State.Cursor
    Dim Length As Long = ByteStorageLength(Bytes)
    If State.Ready = False Or Start < 0 Or Count < 0 Or Start > Length Then
        Exit Function
    End If
    If Count > Length - Start Then
        Exit Function
    End If
    If State.Cursor.ByteOffset > State.MaximumBytes Or Count > State.MaximumBytes - State.Cursor.ByteOffset Then
        Failure.Kind = 2
        Exit Function
    End If
    Dim Decoder As Utf8Decoder = State.Decoder
    Dim Cursor As SourcePosition = State.Cursor
    Dim SequenceStart As SourcePosition = State.SequenceStart
    Dim CarriageReturn As SourcePosition = State.CarriageReturn
    Dim PendingCarriageReturn As Boolean = State.PendingCarriageReturn
    Dim ContentStart As Long = State.ContentStart
    Dim Index As Long = 0
    While Index < Count
        If PendingCarriageReturn And Bytes(Start + Index) <> 10 Then
            Failure.Kind = 4
            Failure.Position = CarriageReturn
            Exit Function
        End If
        If Decoder.Remaining = 0 Then
            SequenceStart = Cursor
        End If
        Dim Scalar As Long = 0
        Dim Complete As Boolean = False
        If FeedUtf8Byte(Decoder, Bytes(Start + Index), Scalar, Complete) = False Then
            Failure.Kind = 3
            Failure.Position = SequenceStart
            Exit Function
        End If
        Cursor.ByteOffset = Cursor.ByteOffset + 1
        If Complete Then
            If PendingCarriageReturn And Scalar <> 10 Then
                Failure.Kind = 4
                Failure.Position = CarriageReturn
                Exit Function
            End If
            If SequenceStart.ByteOffset = 0 And Scalar = 65279 Then
                ContentStart = 3
            Else
                If Scalar = 13 Then
                    CarriageReturn = SequenceStart
                    PendingCarriageReturn = True
                Else
                    If Scalar = 10 Then
                        Cursor.LineNumber = Cursor.LineNumber + 1
                        Cursor.Column = 1
                        PendingCarriageReturn = False
                    Else
                        Cursor.Column = Cursor.Column + 1
                    End If
                End If
                Cursor.ScalarOffset = Cursor.ScalarOffset + 1
            End If
        End If
        Index = Index + 1
    Wend
    If TryAppendBytes(State.Buffer, Bytes, Start, Count) = False Then
        Failure.Kind = 5
        Exit Function
    End If
    State.Decoder = Decoder
    State.Cursor = Cursor
    State.SequenceStart = SequenceStart
    State.CarriageReturn = CarriageReturn
    State.PendingCarriageReturn = PendingCarriageReturn
    State.ContentStart = ContentStart
    Failure.Kind = 0
    Failure.Position = Cursor
    AppendSourceInput = True
End Function

' Publishes only after valid EOF; failure preserves the old complete Document.
' The independent byte snapshot may subsequently be shared as immutable State.
Function TryFinishSourceInput(ByRef State As SourceInput, ByRef Document As SourceDocument, ByRef Failure As SourceFailure) As Boolean
    TryFinishSourceInput = False
    Failure.Kind = 1
    Failure.Position = State.Cursor
    If State.Ready = False Then
        Exit Function
    End If
    Dim Decoder As Utf8Decoder = State.Decoder
    If FinishUtf8Decoder(Decoder) = False Then
        Failure.Kind = 3
        Failure.Position = State.SequenceStart
        Exit Function
    End If
    If State.PendingCarriageReturn Then
        Failure.Kind = 4
        Failure.Position = State.CarriageReturn
        Exit Function
    End If
    If TrySnapshotByteBuffer(State.Buffer, Document.Bytes) = False Then
        Failure.Kind = 5
        Exit Function
    End If
    Document.ContentStart = State.ContentStart
    Document.ScalarCount = State.Cursor.ScalarOffset
    Document.LineCount = State.Cursor.LineNumber
    Failure.Kind = 0
    TryFinishSourceInput = True
End Function
