UBE SOURCE 1 MODULE
Attribute UBE_Name = "PublicationProbe"
' Observes guarded publication with real private fixture files and explicit cleanup.
Private SavedOutput() As Byte
Private SavedStage() As Byte
Private SavedOwned As Boolean
Private SavedToken As Long

' Compares exact canonical path bytes independently of the publication resolver.
Private Function SameBytes(ByRef First() As Byte, ByRef Second() As Byte) As Boolean
    Dim Index As Long
    Dim Length As Long
    Length = BufferPrimitives.ByteStorageLength(First)
    If Length <> BufferPrimitives.ByteStorageLength(Second) Then Exit Function
    Do While Index < Length
        If First(Index) <> Second(Index) Then Exit Function
        Index = Index + 1
    Loop
    SameBytes = True
End Function

' Separates measured preparation from cleanup so every allocation site can be faulted.
Public Function CheckPrepare(ByRef Requested() As Byte, ByRef Manifest() As Byte, ByRef PathBytes() As Byte, ByRef Paths() As ProjectLoader.SourcePath, ByVal Expected As Boolean) As Long
    Dim Failure As Long
    Dim Status As Boolean
    Status = FilePrimitives.SetError(91)
    Status = OutputPublication.TryPrepare(Requested, Manifest, PathBytes, Paths, 1, SavedOutput, SavedStage, SavedOwned, SavedToken, Failure)
    If Status <> Expected Then CheckPrepare = 1: Exit Function
    If SavedToken <> 0 Or SavedOwned <> Expected Then CheckPrepare = 2: Exit Function
    If Expected Then
        If Failure <> 0 Or Err.Number <> 91 Then CheckPrepare = 3
    Else
        If Failure = 0 Then CheckPrepare = 4
    End If
End Function

' Releases any test-owned stage and all retained scratch after the measured call.
Public Function ClearPrepared() As Long
    Dim Failure As Long
    If SavedToken <> 0 Then
        If FileBytes.TryClosePreservingError(SavedToken, Failure) = False Then ClearPrepared = 1: Exit Function
    End If
    If OutputPublication.TryDiscard(SavedStage, SavedOwned, Failure) = False Then ClearPrepared = 2: Exit Function
    If BufferPrimitives.TryResizeBytes(SavedOutput, 0, False) = False Then ClearPrepared = 3: Exit Function
    If BufferPrimitives.TryResizeBytes(SavedStage, 0, False) = False Then ClearPrepared = 4
End Function

' Writes a small independent payload and closes it before any commit is attempted.
Private Function WritePayload(ByRef Path() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Payload(0 To 3) As Byte
    Dim Status As Boolean
    Payload(0) = 17
    Payload(1) = 42
    Payload(2) = 99
    Payload(3) = 255
    If FilePrimitives.TryCreateNew(Path, Token, Failure) = False Then Exit Function
    Status = FileBytes.TryWriteAllBytes(Token, Payload, Failure)
    If FileBytes.TryClosePreservingError(Token, Failure) = False Then Exit Function
    WritePayload = Status
End Function

' Creates an unreviewed test leaf to prove discard never recursively removes unknown content.
Private Function UnknownPath(ByRef Stage() As Byte, ByRef Path() As Byte, ByRef Failure As Long) As Boolean
    Dim Leaf(0 To 10) As Byte
    Leaf(0) = 117
    Leaf(1) = 110
    Leaf(2) = 107
    Leaf(3) = 110
    Leaf(4) = 111
    Leaf(5) = 119
    Leaf(6) = 110
    Leaf(7) = 46
    Leaf(8) = 98
    Leaf(9) = 105
    Leaf(10) = 110
    UnknownPath = WindowsPaths.TryResolveSource(Stage, Leaf, Path, Failure)
End Function

' Exercises failed cleanup while retaining the primary error and owned stage for recovery.
Private Function CheckDiscard(ByRef Stage() As Byte, ByRef Owned As Boolean, ByVal Unknown As Boolean, ByRef Token As Long, ByRef Failure As Long) As Long
    Dim Path() As Byte
    Dim Status As Boolean
    If Unknown Then
        If UnknownPath(Stage, Path, Failure) = False Then CheckDiscard = 1: Exit Function
        If WritePayload(Path, Token, Failure) = False Then CheckDiscard = 2: Exit Function
    End If
    Failure = 77
    Status = FilePrimitives.SetError(91)
    Status = OutputPublication.TryDiscard(Stage, Owned, Failure)
    If Status Or Owned = False Or Failure <> 77 Or Err.Number <> 91 Then CheckDiscard = 3: Exit Function
    If Unknown Then
        If FilePrimitives.TryDelete(Path, Failure) = False Then CheckDiscard = 4: Exit Function
    End If
    Failure = 0
    If OutputPublication.TryDiscard(Stage, Owned, Failure) = False Then CheckDiscard = 5: Exit Function
    If Owned Or Failure <> 0 Or Err.Number <> 91 Then CheckDiscard = 6
End Function

' Checks prepare/refusal, closed-file commit, revalidation and bounded stage cleanup.
Public Function RunCase(ByRef Requested() As Byte, ByRef Manifest() As Byte, ByRef PathBytes() As Byte, ByRef Paths() As ProjectLoader.SourcePath, ByRef Expected() As Byte, ByRef SwapPath() As Byte, ByVal ExpectedFailure As Long, ByVal Mode As Long) As Long
    Dim Output() As Byte
    Dim Stage() As Byte
    Dim FilePath() As Byte
    Dim Parent() As Byte
    Dim ExpectedParent() As Byte
    Dim Owned As Boolean
    Dim Token As Long
    Dim Length As Long
    Dim Failure As Long
    Dim Kind As Long = 1
    Dim Status As Boolean
    Dim Result As Long
    On Error GoTo Failed
    If Mode = 10 Then
        If FilePrimitives.TryOpen(Manifest, 65536, Token, Length, Failure) = False Then RunCase = 1: GoTo Cleanup
    End If
    Status = FilePrimitives.SetError(91)
    Status = OutputPublication.TryPrepare(Requested, Manifest, PathBytes, Paths, 1, Output, Stage, Owned, Token, Failure)
    If ExpectedFailure <> 0 Then
        If Status Or Failure <> ExpectedFailure Or Owned Then RunCase = 2: GoTo Cleanup
        If Mode = 2 Or Mode = 10 Then
            If Token <= 0 Then RunCase = 3: GoTo Cleanup
        Else
            If Token <> 0 Then RunCase = 4: GoTo Cleanup
        End If
        GoTo Cleanup
    End If
    If Status = False Or Owned = False Or Token <> 0 Or Failure <> 0 Then RunCase = 5: GoTo Cleanup
    If Err.Number <> 91 Then RunCase = 6: GoTo Cleanup
    If SameBytes(Output, Expected) = False Then RunCase = 7: GoTo Cleanup
    If WindowsPaths.TryParent(Output, ExpectedParent, Failure) = False Then RunCase = 8: GoTo Cleanup
    If WindowsPaths.TryParent(Stage, Parent, Failure) = False Then RunCase = 9: GoTo Cleanup
    If SameBytes(Parent, ExpectedParent) = False Then RunCase = 10: GoTo Cleanup
    If Mode = 9 Then Kind = OutputPublication.Executable
    If Mode <> 3 Then
        If OutputPublication.TryStagePath(Stage, Kind, FilePath, Failure) = False Then RunCase = 11: GoTo Cleanup
        If WritePayload(FilePath, Token, Failure) = False Then RunCase = 12: GoTo Cleanup
    End If
    If Mode = 6 Or Mode = 8 Then
        Result = CheckDiscard(Stage, Owned, Mode = 6, Token, Failure)
        If Result <> 0 Then RunCase = 20 + Result
        GoTo Cleanup
    End If
    If Mode = 4 Then
        If FilePrimitives.TryReplace(SwapPath, Output, Failure) = False Then RunCase = 13: GoTo Cleanup
    End If
    If Mode = 7 Then Kind = OutputPublication.ImportLibrary
    Status = OutputPublication.TryCommit(Manifest, PathBytes, Paths, 1, Output, Stage, Owned, Kind, Token, Failure)
    If Mode = 3 Then
        If Status Or Failure <> 18 Then RunCase = 14: GoTo Cleanup
    ElseIf Mode = 4 Then
        If Status Or Failure <> 120 Then RunCase = 15: GoTo Cleanup
    ElseIf Mode = 5 Then
        If Status Or Failure <> 5 Then RunCase = 16: GoTo Cleanup
    ElseIf Mode = 7 Then
        If Status Or Failure <> 1 Then RunCase = 17: GoTo Cleanup
    Else
        If Status = False Or Failure <> 0 Then RunCase = 18: GoTo Cleanup
    End If
Cleanup:
    If Token <> 0 Then
        If FileBytes.TryClosePreservingError(Token, Failure) = False Then RunCase = 90
    End If
    If Owned Then
        If OutputPublication.TryDiscard(Stage, Owned, Failure) = False Then RunCase = 91
    End If
    If Token <> 0 Or Owned Then RunCase = 92
    Exit Function
Failed:
    RunCase = 99
    GoTo Cleanup
End Function

' Checks independent support-file protection, including a hardlink destination.
Public Function CheckProtected(ByRef InputPath() As Byte, ByRef Output() As Byte, ByVal Expected As Boolean) As Long
    Dim Token As Long
    Dim Failure As Long
    Dim Status As Boolean
    Status = FilePrimitives.SetError(91)
    Status = OutputPublication.TryProtectPath(InputPath, Output, Token, Failure)
    If Status <> Expected Then CheckProtected = 1
    If Expected Then
        If Failure <> 0 Or Err.Number <> 91 Then CheckProtected = 2
    Else
        If Failure <> 120 Then CheckProtected = 3
    End If
    If Token <> 0 Then
        CheckProtected = 4
        Status = FileBytes.TryClosePreservingError(Token, Failure)
    End If
End Function

