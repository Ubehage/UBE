UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceParsingEntry"

' Native development entry using actual file intake and UBE source workers.
Intrinsic Function CommandArgumentCount() As Long
End Function

Function MakeSourceCancellation() As SourceCancellation
    Set MakeSourceCancellation = New SourceCancellation
End Function

' Qualifies fixture bytes through the intact source-input pipeline.
Function TryMakeSourceOwner(ByRef Bytes() As Byte, ByVal SourceId As Long, ByRef Published As SourceOwner) As Boolean
    TryMakeSourceOwner = False
    Dim Pending As SourceOwner
    Set Pending = New SourceOwner
    If Pending Is Nothing Then
        Exit Function
    End If
    Dim Input As SourceInput
    Dim Failure As SourceFailure
    Failure.Kind = 5
    If BeginSourceInput(Input, ByteStorageLength(Bytes)) = False Then
        Exit Function
    End If
    If AppendSourceInput(Input, Bytes, 0, ByteStorageLength(Bytes), Failure) = False Then
        Exit Function
    End If
    If TryFinishSourceInput(Input, Pending.Document, Failure) = False Then
        Exit Function
    End If
    Pending.SourceId = SourceId
    Set Published = Pending
    TryMakeSourceOwner = True
End Function

' Allocates a private result while retaining the same immutable token owner.
Function MakeSharedSyntaxWork(ByVal Owner As SourceWork) As SharedSyntaxWork
    Dim Work As SharedSyntaxWork
    Set Work = New SharedSyntaxWork
    Set Work.Owner = Owner
    Work.Failure.Kind = 5
    Set MakeSharedSyntaxWork = Work
End Function

' Actual UBE parser worker borrows one shared document/token array.
Sub ProcessSharedSyntax(ByVal Work As SharedSyntaxWork)
    If TryCurrentThreadId(Work.WorkerId) = False Then
        Exit Sub
    End If
    Work.Failure.Kind = 5
    If TryParseSyntax(Work.Owner.Owner.Document, Work.Owner.Tokens, 3, Work.Owner.Owner.SourceId, 1048576, 1048576, 256, Work.Syntax, Work.Failure, Work.Metrics) = False Then
        Work.State = 2
        Exit Sub
    End If
    Work.State = 1
End Sub

' Starts the real parser Sub without a C worker replacement.
Function StartSharedSyntax(ByVal Work As SharedSyntaxWork) As LongLong
    StartSharedSyntax = CallNew ProcessSharedSyntax(Work)
End Function

' Creates only a reference vector; individual source owners stay immutable.
Intrinsic Function TryResizeSourceOwners(ByRef Values() As SourceOwner, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSourceOwners.UBE_Primitive = "Array.TryResize"
End Function

' Reads ordered source paths, qualifies documents, then invokes one worker budget.
Function Main() As Long
    Main = 1
    Dim Owners() As SourceOwner
    Dim Count As Long = CommandArgumentCount()
    If TryResizeSourceOwners(Owners, Count, False) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    Dim Owner As SourceOwner
    While Index < Count
        Set Owner = New SourceOwner
        If Owner Is Nothing Then
            Exit Function
        End If
        Owner.SourceId = Index
        Dim PathUtf8() As Byte
        Dim ArgumentFailure As Long = 0
        If TryCommandArgument(Index, PathUtf8, ArgumentFailure) = False Then
            Exit Function
        End If
        Dim InputFailure As SourceFailure
        InputFailure.Kind = 5
        Dim FileFailure As Long = 0
        Dim OpenToken As Long = 0
        If TryReadSourceFile(PathUtf8, 16777216, Owner.Document, InputFailure, FileFailure, OpenToken) = False Then
            If OpenToken <> 0 Then
                Call TryCloseByteFile(OpenToken, FileFailure)
            End If
            Print InputFailure.Kind
            Exit Function
        End If
        Set Owners(Index) = Owner
        Index = Index + 1
    Wend
    Dim Cancellation As SourceCancellation
    Set Cancellation = New SourceCancellation
    If Cancellation Is Nothing Then
        Exit Function
    End If
    Dim Published() As SourceWork
    Dim Failure As SourceSetFailure
    Failure.Kind = 5
    Failure.SourceId = -1
    If TryParseSources(Owners, 2, 1048576, 1048576, 1048576, 256, Cancellation, Published, Failure) = False Then
        Print Failure.Kind
        Print Failure.SourceId
        Print Failure.UnitFailure.Kind
        Exit Function
    End If
    Index = 0
    While Index < Count
        Dim Work As SourceWork
        Set Work = Published(Index)
        Print Work.Owner.SourceId
        Print Work.Syntax(0).NodeCount
        Print Work.WorkerId
        Index = Index + 1
    Wend
    Main = 0
End Function
