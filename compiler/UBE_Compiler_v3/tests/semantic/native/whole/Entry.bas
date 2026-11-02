UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticStatementFixture"
Function TryMakeStatementSource(ByRef Bytes() As Byte, ByVal SourceId As Long, ByVal PackageId As Long, ByRef Result As SemanticSource, ByRef Failure As SemanticFailure) As Boolean
    TryMakeStatementSource = False
    Call ResetSemanticFailure(Failure)
    Dim Pending As SemanticSource
    Set Pending = New SemanticSource
    If Pending Is Nothing Then
        Exit Function
    End If
    Dim Work As SourceWork
    Set Work = New SourceWork
    If Work Is Nothing Then
        Exit Function
    End If
    Dim Owner As SourceOwner
    Set Owner = New SourceOwner
    If Owner Is Nothing Then
        Exit Function
    End If
    Dim Qualified As SourceInput
    Dim InputFailure As SourceFailure
    InputFailure.Kind = 5
    Failure.FirstByte = -1
    If BeginSourceInput(Qualified, ByteStorageLength(Bytes)) = False Then
        Exit Function
    End If
    Failure.FirstByte = -2
    If AppendSourceInput(Qualified, Bytes, 0, ByteStorageLength(Bytes), InputFailure) = False Then
        Exit Function
    End If
    Failure.FirstByte = -3
    If TryFinishSourceInput(Qualified, Owner.Document, InputFailure) = False Then
        Exit Function
    End If
    Owner.SourceId = SourceId
    Set Work.Owner = Owner
    Dim ScanFailure As ScannerFailure
    ScanFailure.Kind = 5
    Failure.FirstByte = -4
    If TryReadSourceEnvelope(Owner.Document, 1, Pending.Envelope, ScanFailure) = False Then
        Exit Function
    End If
    Failure.FirstByte = -5
    If TryScanSource(Owner.Document, 0, 1048576, Work.Tokens, ScanFailure) = False Then
        Exit Function
    End If
    Work.Failure.Kind = 5
    Failure.FirstByte = -6
    If TryParseSyntax(Owner.Document, Work.Tokens, 3, SourceId, 1048576, 1048576, 256, Work.Syntax, Work.Failure, Work.Metrics) = False Then
        Exit Function
    End If
    Work.State = 1
    Set Pending.SyntaxInput = Work
    Pending.SourceId = SourceId
    Pending.PackageId = PackageId
    Set Result = Pending
    Failure.Kind = 0
    Failure.Code = 0
    TryMakeStatementSource = True
End Function

Function TryMakeStatementCancellation(ByRef Published As SourceCancellation) As Boolean
    TryMakeStatementCancellation = False
    Dim Pending As SourceCancellation
    Set Pending = New SourceCancellation
    If Pending Is Nothing Then
        Exit Function
    End If
    Set Published = Pending
    TryMakeStatementCancellation = Published Is Pending
End Function
Function TryCheckStatementSource(ByVal SyntaxInput As SemanticSource, ByVal Jobs As Long, ByRef Limits As SemanticLimits, ByVal Cancellation As SourceCancellation, ByRef Published As SemanticResult, ByRef Failure As SemanticFailure) As Boolean
    TryCheckStatementSource = False
    Call ResetSemanticFailure(Failure)
    If SyntaxInput Is Nothing Then
        TryCheckStatementSource = FailSemanticDomain(Failure)
        Exit Function
    End If
    TryCheckStatementSource = TryCheckSourceSemantics(SyntaxInput.SyntaxInput, SyntaxInput.Envelope, Jobs, Limits, Cancellation, Published, Failure)
End Function
Function TryMakeStatementProject(ByRef PathUtf8() As Byte, ByVal Jobs As Long, ByVal Cancellation As SourceCancellation, ByRef Published As ProjectSyntax, ByRef Failure As SemanticFailure) As Boolean
    TryMakeStatementProject = False
    Call ResetSemanticFailure(Failure)
    Dim Limits As ProjectLimits
    Call DefaultProjectLimits(Limits)
    Dim SetupFailure As ProjectFailure
    Call PrepareProjectFailure(SetupFailure)
    Dim Pending As ProjectSyntax
    Dim OpenToken As Long = 0
    Dim Accepted As Boolean = TryParseProject(PathUtf8, Limits, Jobs, Cancellation, Pending, SetupFailure, OpenToken)
    If OpenToken <> 0 Then
        Dim CloseFailure As Long = 5
        If TryCloseByteFile(OpenToken, CloseFailure) = False Then
            Exit Function
        End If
    End If
    If Accepted = False Then
        Failure.Kind = SetupFailure.Kind
        Failure.Code = SetupFailure.Code
        Failure.SourceId = SetupFailure.SourceId
        Failure.FirstByte = SetupFailure.FirstByte
        Failure.LastByte = SetupFailure.LastByte
        Exit Function
    End If
    Set Published = Pending
    If (Published Is Pending) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TryMakeStatementProject = True
End Function
Function TryCheckStatementProject(ByVal SyntaxInput As ProjectSyntax, ByVal Jobs As Long, ByRef Limits As SemanticLimits, ByVal Cancellation As SourceCancellation, ByRef Published As SemanticResult, ByRef Failure As SemanticFailure) As Boolean
    Call ResetSemanticFailure(Failure)
    TryCheckStatementProject = TryCheckProjectSemantics(SyntaxInput, Jobs, Limits, Cancellation, Published, Failure)
End Function
Function Main() As Long
    Main = 0
End Function
