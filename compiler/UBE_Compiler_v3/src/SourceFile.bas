UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceFile"

' Reads one source through counted raw bytes. The caller owns OpenToken, initially
' zero; a genuine close failure leaves it available for explicit cleanup/retry.
' Result publication happens only after close. File failure details are fresh.
Function TryReadSourceFile(ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByRef Document As SourceDocument, ByRef Failure As SourceFailure, ByRef FileFailure As Long, ByRef OpenToken As Long) As Boolean
    TryReadSourceFile = False
    Call ResetSourceFileFailure(Failure)
    FileFailure = 0
    Dim State As SourceInput
    Dim UnusedIdentity() As Byte
    If TryReadSourceFileInput(PathUtf8, MaximumBytes, False, State, UnusedIdentity, Failure, FileFailure, OpenToken) = False Then
        Exit Function
    End If
    Failure.Kind = 5
    TryReadSourceFile = TryFinishSourceInput(State, Document, Failure)
End Function

' Private construction entry: Identity may be prepared before a later failure.
' Only pending compiler metadata may use these paired outputs. The enclosing
' project reference provides atomic publication; Document still finishes only
' after successful close. No additional document copy, handle or retained reference.
' Caller seeds Failure.Kind=5 before entry and owns any returned OpenToken.
Function TryReadSourceFileIdentity(ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByRef Document As SourceDocument, ByRef Identity() As Byte, ByRef Failure As SourceFailure, ByRef FileFailure As Long, ByRef OpenToken As Long) As Boolean
    TryReadSourceFileIdentity = False
    Call ResetSourceFileFailure(Failure)
    FileFailure = 0
    Dim State As SourceInput
    If TryReadSourceFileInput(PathUtf8, MaximumBytes, True, State, Identity, Failure, FileFailure, OpenToken) = False Then
        Exit Function
    End If
    Failure.Kind = 5
    TryReadSourceFileIdentity = TryFinishSourceInput(State, Document, Failure)
End Function

' Shared bounded intake body. State/Identity are private, caller-owned scratch;
' failure may leave them partially prepared. Neither is a published result.
' Independent callers share no mutable state. All I/O uses the same token.
Function TryReadSourceFileInput(ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByVal ReadIdentity As Boolean, ByRef State As SourceInput, ByRef Identity() As Byte, ByRef Failure As SourceFailure, ByRef FileFailure As Long, ByRef OpenToken As Long) As Boolean
    TryReadSourceFileInput = False
    FileFailure = 0
    Failure.Kind = 1
    Failure.Position.ByteOffset = 0
    Failure.Position.ScalarOffset = 0
    Failure.Position.LineNumber = 1
    Failure.Position.Column = 1
    If OpenToken <> 0 Or MaximumBytes < 0 Or MaximumBytes > 2147483646 Then
        Exit Function
    End If
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
    Dim Accepted As Boolean = True
    If ReadIdentity Then
        FileFailure = 8
        If TryReadByteFileIdentity(OpenToken, Identity, FileFailure) = False Then
            Failure.Kind = 6
            Accepted = False
        End If
    End If
    If Accepted Then
        Accepted = TryResizeByteStorage(Chunk, ChunkSize, False)
        If Accepted = False Then
            Failure.Kind = 5
        End If
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
    TryReadSourceFileInput = True
End Function

' Rootless scalar status initialization also precedes shared-body admission.
Sub ResetSourceFileFailure(ByRef Failure As SourceFailure)
    Failure.Kind = 5
    Failure.Position.ByteOffset = 0
    Failure.Position.ScalarOffset = 0
    Failure.Position.LineNumber = 1
    Failure.Position.Column = 1
End Sub
