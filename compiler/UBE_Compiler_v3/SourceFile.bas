UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceFile"

' Reads one source through counted raw bytes. The caller owns OpenToken, initially
' zero; a genuine close failure leaves it available for explicit cleanup/retry.
' Result publication happens only after close. File failure details are fresh.
Function TryReadSourceFile(ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByRef Document As SourceDocument, ByRef Failure As SourceFailure, ByRef FileFailure As Long, ByRef OpenToken As Long) As Boolean
    TryReadSourceFile = False
    FileFailure = 0
    Failure.Kind = 1
    Failure.Position.ByteOffset = 0
    Failure.Position.ScalarOffset = 0
    Failure.Position.LineNumber = 1
    Failure.Position.Column = 1
    If OpenToken <> 0 Or MaximumBytes < 0 Or MaximumBytes > 2147483646 Then
        Exit Function
    End If
    Dim State As SourceInput
    Failure.Kind = 5
    If BeginSourceInput(State, MaximumBytes) = False Then
        Exit Function
    End If
    Dim Length As Long = 0
    If TryOpenByteFile(PathUtf8, MaximumBytes, OpenToken, Length, FileFailure) = False Then
        Failure.Kind = 6
        If FileFailure = 4 Then
            Failure.Kind = 2
        End If
        Exit Function
    End If
    Dim Chunk() As Byte
    Dim ChunkSize As Long = 4096
    If Length < ChunkSize Then
        ChunkSize = Length + 1
    End If
    Dim Accepted As Boolean = TryResizeByteStorage(Chunk, ChunkSize, False)
    If Accepted = False Then
        Failure.Kind = 5
    End If
    Dim Offset As Long = 0
    While Accepted And Offset < Length
        Dim Requested As Long = Length - Offset
        If Requested > ChunkSize Then
            Requested = ChunkSize
        End If
        Dim ReadCount As Long = 0
        If TryReadByteFile(OpenToken, Chunk, 0, Requested, ReadCount, FileFailure) = False Then
            Failure.Kind = 6
            Accepted = False
        Else
            If ReadCount = 0 Then
                Failure.Kind = 6
                FileFailure = 6
                Accepted = False
                Call RecordErrorNumber(57)
            Else
                Failure.Kind = 5
                If AppendSourceInput(State, Chunk, 0, ReadCount, Failure) = False Then
                    Accepted = False
                Else
                    Offset = Offset + ReadCount
                End If
            End If
        End If
    Wend
    If Accepted Then
        Dim Extra As Long = 0
        If TryReadByteFile(OpenToken, Chunk, 0, 1, Extra, FileFailure) = False Then
            Failure.Kind = 6
            Accepted = False
        Else
            If Extra <> 0 Then
                Failure.Kind = 6
                FileFailure = 11
                Accepted = False
                Call RecordErrorNumber(57)
            End If
        End If
    End If
    Dim CloseFailure As Long = 0
    If TryCloseByteFile(OpenToken, CloseFailure) = False Then
        If Accepted Then
            Failure.Kind = 6
            FileFailure = CloseFailure
        End If
        Accepted = False
    End If
    If Accepted = False Then
        Exit Function
    End If
    Failure.Kind = 5
    TryReadSourceFile = TryFinishSourceInput(State, Document, Failure)
End Function
