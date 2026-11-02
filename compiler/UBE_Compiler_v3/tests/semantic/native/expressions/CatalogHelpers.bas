UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticCatalogFixture"
Intrinsic Function TryResizeCatalogFixtureSources(ByRef Values() As SemanticSource, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeCatalogFixtureSources.UBE_Primitive = "Array.TryResize"
End Function
Function TryMakeCatalogFixtureSource(ByRef Bytes() As Byte, ByVal SourceId As Long, ByVal PackageId As Long, ByRef Result As SemanticSource, ByRef Failure As SemanticFailure) As Boolean
    TryMakeCatalogFixtureSource = False
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
    Work.MaximumTokens = 1048576
    Work.MaximumNodes = 1048576
    Work.MaximumPending = 1048576
    Work.MaximumDepth = 256
    If TryCurrentThreadId(Work.WorkerId) = False Then
        Exit Function
    End If
    Dim Owner As SourceOwner
    Set Owner = New SourceOwner
    If Owner Is Nothing Then
        Exit Function
    End If
    Dim InputState As SourceInput
    Dim InputFailure As SourceFailure
    InputFailure.Kind = 5
    If BeginSourceInput(InputState, 16777216) = False Then
        Exit Function
    End If
    If AppendSourceInput(InputState, Bytes, 0, ByteStorageLength(Bytes), InputFailure) = False Then
        Exit Function
    End If
    If TryFinishSourceInput(InputState, Owner.Document, InputFailure) = False Then
        Exit Function
    End If
    Owner.SourceId = SourceId
    Set Work.Owner = Owner
    If (Work.Owner Is Owner) = False Then
        Exit Function
    End If
    Dim ScanFailure As ScannerFailure
    ScanFailure.Kind = 5
    If TryReadSourceEnvelope(Owner.Document, 1, Pending.Envelope, ScanFailure) = False Then
        Exit Function
    End If
    If TryScanSource(Owner.Document, 0, 1048576, Work.Tokens, ScanFailure) = False Then
        Exit Function
    End If
    Work.Failure.Kind = 5
    If TryParseSyntax(Owner.Document, Work.Tokens, 3, SourceId, 1048576, 1048576, 256, Work.Syntax, Work.Failure, Work.Metrics) = False Then
        Exit Function
    End If
    Work.State = 1
    Set Pending.SyntaxInput = Work
    If (Pending.SyntaxInput Is Work) = False Then
        Exit Function
    End If
    Pending.SourceId = SourceId
    Pending.PackageId = PackageId
    Set Result = Pending
    If Result Is Pending Then
        Failure.Kind = 0
        Failure.Code = 0
        TryMakeCatalogFixtureSource = True
    End If
End Function
Function TryMakeCatalogFixture(ByRef FirstBytes() As Byte, ByRef SecondBytes() As Byte, ByVal SourceCount As Long, ByVal PackageSplit As Long, ByRef Published As SemanticCatalog, ByRef Failure As SemanticFailure) As Boolean
    TryMakeCatalogFixture = False
    Call ResetSemanticFailure(Failure)
    Dim Pending As SemanticCatalog
    Set Pending = New SemanticCatalog
    If Pending Is Nothing Then
        Exit Function
    End If
    Pending.SourceCount = SourceCount
    Pending.PackageCount = 1
    If PackageSplit = 1 Then
        Pending.PackageCount = 2
    End If
    Call DefaultSemanticLimits(Pending.Limits)
    If TryResizeCatalogFixtureSources(Pending.Sources, SourceCount, False) = False Then
        Exit Function
    End If
    If TryMakeCatalogFixtureSource(FirstBytes, 0, 0, Pending.Sources(0), Failure) = False Then
        Exit Function
    End If
    If SourceCount = 2 Then
        Call ResetSemanticFailure(Failure)
        If TryMakeCatalogFixtureSource(SecondBytes, 1, PackageSplit, Pending.Sources(1), Failure) = False Then
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Failure)
    Set Pending.SyntaxInput = New ProjectSyntax
    If Pending.SyntaxInput Is Nothing Then
        Exit Function
    End If
    If TryResizeSourceWorks(Pending.SyntaxInput.Work, SourceCount, False) = False Then
        Exit Function
    End If
    Dim SourceId As Long = 0
    While SourceId < SourceCount
        Call ResetSemanticFailure(Failure)
        If TryRetainSemanticWork(Pending.Sources(SourceId).SyntaxInput, Pending.SyntaxInput.Work(SourceId)) = False Then
            Exit Function
        End If
        SourceId = SourceId + 1
    Wend
    Call ResetSemanticFailure(Failure)
    Set Published = Pending
    If Published Is Pending Then
        Failure.Kind = 0
        Failure.Code = 0
        TryMakeCatalogFixture = True
    End If
End Function
Function TryCatalogFixtureLookup(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal Scope As Long, ByVal NameId As Long, ByVal Assignment As Long, ByRef DeclarationId As Long, ByRef Level As Long, ByRef Failure As SemanticFailure) As Boolean
    TryCatalogFixtureLookup = TryLookupSemanticName(Catalog, SourceId, Scope, NameId, Assignment <> 0, DeclarationId, Level, Failure)
End Function
