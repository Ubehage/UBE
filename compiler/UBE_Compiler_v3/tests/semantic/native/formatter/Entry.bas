UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticFormatterFixture"

Function TryMakeFormatterFixture(ByRef Bytes() As Byte, ByRef Path() As Byte, ByRef Published As ProjectSyntax) As Boolean
    TryMakeFormatterFixture = False
    Dim Failure As SemanticFailure
    Dim Source As SemanticSource
    If TryMakeCatalogFixtureSource(Bytes, 0, 0, Source, Failure) = False Then
        Exit Function
    End If
    Dim Pending As ProjectSyntax
    Set Pending = New ProjectSyntax
    If Pending Is Nothing Then
        Exit Function
    End If
    Set Pending.Project = New ProjectInput
    If Pending.Project Is Nothing Then
        Exit Function
    End If
    If TryResizeSourceWorks(Pending.Work, 1, False) = False Or TryResizeProjectSources(Pending.Project.Sources, 1, False) = False Then
        Exit Function
    End If
    If TryRetainSemanticWork(Source.SyntaxInput, Pending.Work(0)) = False Then
        Exit Function
    End If
    Dim Association As ProjectSource
    Set Association = New ProjectSource
    If Association Is Nothing Then
        Exit Function
    End If
    Set Association.Owner = Source.SyntaxInput.Owner
    If (Association.Owner Is Source.SyntaxInput.Owner) = False Then
        Exit Function
    End If
    If TryCopyByteStorage(Association.Path.Resolved, Path) = False Then
        Exit Function
    End If
    Association.Envelope = Source.Envelope
    Set Pending.Project.Sources(0) = Association
    If (Pending.Project.Sources(0) Is Association) = False Then
        Exit Function
    End If
    Pending.Project.SourceCount = 1
    Pending.Project.Validated = True
    Set Published = Pending
    If Published Is Pending Then
        TryMakeFormatterFixture = True
    End If
End Function
