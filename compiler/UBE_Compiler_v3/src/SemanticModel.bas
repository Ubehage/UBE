UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticModel"

' Private compiler-domain records. All indexes are context-owned and canonical;
' source spans borrow the retained immutable syntax/source owner graph.
Type SemanticLimits
    MaximumDeclarations As Long
    MaximumFacts As Long
    MaximumPending As Long
    MaximumDepth As Long
End Type
Type SemanticFailure
    Kind As Long
    Code As Long
    SourceId As Long
    FirstByte As Long
    LastByte As Long
    RelatedSourceId As Long
    RelatedFirst As Long
    RelatedLast As Long
End Type
Type SemanticDeclaration
    Kind As Long
    SourceId As Long
    SyntaxId As Long
    NameId As Long
    Scope As Long
    TypeId As Long
    Flags As Long
    FirstParameter As Long
    ParameterCount As Long
    Ordinal As Long
    InitializerSyntaxId As Long
    ValueKnown As Long
    Auxiliary As Long
    BodySyntaxId As Long
    Value As LongLong
End Type
Type SemanticType
    Kind As Long
    Declaration As Long
    Representation As Long
    PackDeclaration As Long
    UnpackDeclaration As Long
    Bits As Long
    Minimum As LongLong
    Maximum As LongLong
End Type
Type SemanticName
    SourceId As Long
    SyntaxId As Long
    FirstByte As Long
    LastByte As Long
    ByteFirst As Long
    ByteCount As Long
End Type
Type SemanticFact
    SourceId As Long
    SyntaxId As Long
    Kind As Long
    TypeId As Long
    Value As LongLong
    Target As Long
    Left As Long
    Right As Long
    Flags As Long
    Auxiliary As Long
    Extra As Long
End Type
Type BoundNode
    SourceId As Long
    SyntaxId As Long
    Kind As Long
    TypeId As Long
    Value As LongLong
    Target As Long
    FirstChild As Long
    NextSibling As Long
    ChildCount As Long
    Flags As Long
    Auxiliary As Long
End Type
Type SemanticExpressionInfo
    SourceId As Long
    SyntaxId As Long
    TypeId As Long
    Flags As Long
    Value As LongLong
    Target As Long
    Node As Long
    IntegerContext As Long
    Selection As Long
    Annotation As Long
    OriginSyntaxId As Long
End Type
Type SemanticMetrics
    SyntaxReads As LongLong
    DeclarationReads As LongLong
    DeclarationWrites As LongLong
    FactWrites As LongLong
    NodeWrites As LongLong
    Transitions As LongLong
    CanonicalScalars As LongLong
    CanonicalBytes As LongLong
    Lookups As LongLong
    MaximumPending As Long
    MaximumDepth As Long
End Type

Sub DefaultSemanticLimits(ByRef Limits As SemanticLimits)
    Limits.MaximumDeclarations = 1048576
    Limits.MaximumFacts = 1048576
    Limits.MaximumPending = 1048576
    Limits.MaximumDepth = 256
End Sub

' Counts executed work at preparation publication, before the catalog freezes.
' The two scalar metric records must be distinct. No input-size formula is used.
Function TryMergeSemanticMetrics(ByRef Destination As SemanticMetrics, ByRef Original As SemanticMetrics) As Boolean
    TryMergeSemanticMetrics = False
    Destination.SyntaxReads = Destination.SyntaxReads + Original.SyntaxReads
    Destination.DeclarationReads = Destination.DeclarationReads + Original.DeclarationReads
    Destination.DeclarationWrites = Destination.DeclarationWrites + Original.DeclarationWrites
    Destination.FactWrites = Destination.FactWrites + Original.FactWrites
    Destination.NodeWrites = Destination.NodeWrites + Original.NodeWrites
    Destination.Transitions = Destination.Transitions + Original.Transitions
    Destination.CanonicalScalars = Destination.CanonicalScalars + Original.CanonicalScalars
    Destination.CanonicalBytes = Destination.CanonicalBytes + Original.CanonicalBytes
    Destination.Lookups = Destination.Lookups + Original.Lookups
    If Original.MaximumPending > Destination.MaximumPending Then
        Destination.MaximumPending = Original.MaximumPending
    End If
    If Original.MaximumDepth > Destination.MaximumDepth Then
        Destination.MaximumDepth = Original.MaximumDepth
    End If
    TryMergeSemanticMetrics = True
End Function
' Failure is rootless, so reset/selection cannot itself lose a source error to
' managed admission. Public callers also seed this before entering managed code.
Sub ResetSemanticFailure(ByRef Failure As SemanticFailure)
    Dim Blank As SemanticFailure
    Failure = Blank
    Failure.Kind = 5
    Failure.Code = 1428
    Failure.SourceId = -1
    Failure.RelatedSourceId = -1
End Sub
' Canonical ordinary/deferred error selection; infrastructure is handled before
' this operation. Class rank follows definition.json rather than numeric codes.
Function SemanticDiagnosticRank(ByVal Code As Long) As Long
    SemanticDiagnosticRank = 100
    If Code >= 1401 And Code <= 1425 Then
        SemanticDiagnosticRank = Code - 1401
    End If
    If Code = 1430 Then
        SemanticDiagnosticRank = 25
    End If
    If Code = 1431 Then
        SemanticDiagnosticRank = 26
    End If
    If Code = 1432 Then
        SemanticDiagnosticRank = 27
    End If
    If Code = 1433 Then
        SemanticDiagnosticRank = 28
    End If
    If Code = 1400 Then
        SemanticDiagnosticRank = 29
    End If
    If Code = 1434 Then
        SemanticDiagnosticRank = 30
    End If
    If Code = 1435 Then
        SemanticDiagnosticRank = 31
    End If
End Function
Sub RecordSemanticDiagnostic(ByRef Failure As SemanticFailure, ByVal Code As Long, ByVal SourceId As Long, ByVal FirstByte As Long, ByVal LastByte As Long, ByVal RelatedSourceId As Long, ByVal RelatedFirst As Long, ByVal RelatedLast As Long)
    Dim Replace As Boolean = Failure.Kind = 0
    If Failure.Kind = 3 Or Failure.Kind = 8 Then
        Replace = SourceId < Failure.SourceId
        If SourceId = Failure.SourceId Then
            Replace = FirstByte < Failure.FirstByte
            If FirstByte = Failure.FirstByte Then
                Replace = SemanticDiagnosticRank(Code) < SemanticDiagnosticRank(Failure.Code)
            End If
        End If
    End If
    If Replace Then
        Failure.Kind = 3
        If Code = 1400 Or (Code >= 1430 And Code <= 1435) Then
            Failure.Kind = 8
        End If
        Failure.Code = Code
        Failure.SourceId = SourceId
        Failure.FirstByte = FirstByte
        Failure.LastByte = LastByte
        Failure.RelatedSourceId = RelatedSourceId
        Failure.RelatedFirst = RelatedFirst
        Failure.RelatedLast = RelatedLast
    End If
End Sub
