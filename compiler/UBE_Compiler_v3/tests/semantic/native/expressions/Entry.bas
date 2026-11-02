UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticExpressionFixture"

' Test admission copies source once through the existing catalog fixture helper.
' Production binding still borrows its immutable parsed owner graph.
Private Function TryCheckExpressionFixtureCore(ByRef Bytes() As Byte, ByRef SecondBytes() As Byte, ByVal SourceCount As Long, ByVal PackageSplit As Long, ByVal FirstByte As Long, ByVal LastByte As Long, ByVal Kind As Long, ByVal Context As Long, ByVal Destination As Long, ByVal Discard As Boolean, ByRef Published As SemanticModuleWork, ByRef Info As SemanticExpressionInfo, ByRef Failure As SemanticFailure) As Boolean
    TryCheckExpressionFixtureCore = False
    Call ResetSemanticFailure(Failure)
    Dim Catalog As SemanticCatalog
    If TryMakeCatalogFixture(Bytes, SecondBytes, SourceCount, PackageSplit, Catalog, Failure) = False Then
        Exit Function
    End If
    Dim Cancellation As SourceCancellation
    Set Cancellation = New SourceCancellation
    If Cancellation Is Nothing Then
        Call ResetSemanticFailure(Failure)
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If TryBuildSemanticDeclarations(Catalog, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If TryPrepareSemanticConstants(Catalog, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    Dim Work As SemanticModuleWork
    Set Work = New SemanticModuleWork
    If Work Is Nothing Then
        Exit Function
    End If
    Set Work.Catalog = Catalog
    Set Work.Source = Catalog.Sources(0)
    Set Work.Cancellation = Cancellation
    Call DefaultSemanticLimits(Work.Limits)
    Work.MaximumFacts = Work.Limits.MaximumFacts
    Work.MaximumPending = Work.Limits.MaximumPending
    Work.Root = -1
    Work.Scope = 0
    Dim SyntaxId As Long = -1
    Dim Index As Long = 0
    While Index < Work.Source.SyntaxInput.Syntax(0).NodeCount
        Dim Node As SyntaxNode
        Call ReadSyntaxNode(Node, Work.Source.SyntaxInput.Syntax(0).Nodes(Index))
        If Node.FirstByte = FirstByte And Node.LastByte = LastByte And Node.Kind = Kind Then
            If SyntaxId >= 0 Then
                TryCheckExpressionFixtureCore = FailSemanticDomain(Failure)
                Exit Function
            End If
            SyntaxId = Index
        End If
        Index = Index + 1
    Wend
    If SyntaxId < 0 Then
        TryCheckExpressionFixtureCore = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Target As Long = -1
    Index = 0
    While Index < Catalog.DeclarationCount
        Dim Declaration As SemanticDeclaration
        Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(Index))
        If Declaration.SourceId = 0 Then
            If Declaration.Kind = 5 Or Declaration.Kind = 6 Then
                If Declaration.BodySyntaxId >= 0 Then
                    Call ReadSyntaxNode(Node, Work.Source.SyntaxInput.Syntax(0).Nodes(Declaration.BodySyntaxId))
                    If Node.FirstByte <= FirstByte And LastByte <= Node.LastByte Then
                        Work.Scope = Index
                    End If
                End If
            End If
            If Declaration.InitializerSyntaxId = SyntaxId Then
                Target = Index
            End If
        End If
        Index = Index + 1
    Wend
    Set Published = Work
    Call ResetSemanticFailure(Work.Failure)
    If TryBindSemanticExpression(Work, SyntaxId, Context, False, False, Discard, Info) = False Then
        Failure = Work.Failure
        Exit Function
    End If
    If Destination > 0 Then
        Dim Conversion As Long = -1
        Call ResetSemanticFailure(Work.Failure)
        If TryConvertSemanticExpression(Work, Info, Destination, 4, Target, -1, Conversion) = False Then
            Failure = Work.Failure
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Work.Failure)
    If TryMaterializeSemanticExpression(Work, Info) = False Then
        Failure = Work.Failure
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TryCheckExpressionFixtureCore = True
End Function
Function TryCheckExpressionFixture(ByRef Bytes() As Byte, ByVal FirstByte As Long, ByVal LastByte As Long, ByVal Kind As Long, ByVal Context As Long, ByVal Destination As Long, ByVal Discard As Boolean, ByRef Published As SemanticModuleWork, ByRef Info As SemanticExpressionInfo, ByRef Failure As SemanticFailure) As Boolean
    Dim SecondBytes() As Byte
    Call ResetSemanticFailure(Failure)
    TryCheckExpressionFixture = TryCheckExpressionFixtureCore(Bytes, SecondBytes, 1, 0, FirstByte, LastByte, Kind, Context, Destination, Discard, Published, Info, Failure)
End Function
Function TryCheckExpressionFixturePair(ByRef Bytes() As Byte, ByRef SecondBytes() As Byte, ByVal FirstByte As Long, ByVal LastByte As Long, ByVal Kind As Long, ByVal Context As Long, ByVal Destination As Long, ByVal Discard As Boolean, ByRef Published As SemanticModuleWork, ByRef Info As SemanticExpressionInfo, ByRef Failure As SemanticFailure) As Boolean
    Call ResetSemanticFailure(Failure)
    TryCheckExpressionFixturePair = TryCheckExpressionFixtureCore(Bytes, SecondBytes, 2, 1, FirstByte, LastByte, Kind, Context, Destination, Discard, Published, Info, Failure)
End Function
Function TryReadExpressionFixtureOrigin(ByVal Work As SemanticModuleWork, ByVal SourceId As Long, ByVal SyntaxId As Long, ByRef Node As SyntaxNode) As Boolean
    Call ResetSemanticFailure(Work.Failure)
    TryReadExpressionFixtureOrigin = TryReadCatalogSyntax(Work.Catalog, SourceId, SyntaxId, Node, Work.Failure)
    Call ResetSemanticFailure(Work.Failure)
End Function

Function Main() As Long
    Main = 0
End Function
