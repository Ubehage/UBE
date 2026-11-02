UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticExpressions"

' Compiler type selection and source observations. Numeric decoding/evaluation
' remains ordinary UBECore code; these helpers impose the language's types.
Sub ClearSemanticExpression(ByRef Info As SemanticExpressionInfo, ByVal SourceId As Long, ByVal SyntaxId As Long)
    Dim Blank As SemanticExpressionInfo
    Info = Blank
    Info.SourceId = SourceId
    Info.SyntaxId = SyntaxId
    Info.OriginSyntaxId = SyntaxId
    Info.Target = -1
    Info.Node = -1
    Info.Annotation = -1
End Sub

' Shared cooperative checkpoint for private semantic work. Native sticky stop
' also drains workers after an admission/storage/wait failure closes the pool.
Function TryContinueSemanticWork(ByVal Work As SemanticModuleWork) As Boolean
    TryContinueSemanticWork = False
    Call ResetSemanticFailure(Work.Failure)
    Dim Requested As Boolean = False
    If TryThreadStopRequested(Requested) = False Then
        Exit Function
    End If
    If Work.Cancellation Is Nothing Then
        Exit Function
    End If
    If Requested Or Work.Cancellation.Requested Then
        Work.Failure.Kind = 4
        Work.Failure.Code = 1429
        Exit Function
    End If
    TryContinueSemanticWork = True
End Function

Function TryReadSemanticSyntax(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByRef Node As SyntaxNode) As Boolean
    TryReadSemanticSyntax = False
    Call ResetSemanticFailure(Work.Failure)
    If SyntaxId < 0 Or SyntaxId >= Work.Source.SyntaxInput.Syntax(0).NodeCount Then
        TryReadSemanticSyntax = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Call ReadSyntaxNode(Node, Work.Source.SyntaxInput.Syntax(0).Nodes(SyntaxId))
    Work.Metrics.SyntaxReads = Work.Metrics.SyntaxReads + 1
    TryReadSemanticSyntax = True
End Function

' Recover the already-qualified lexical family/coordinates, never a second
' lexer. With at most1048576 tokens, search performs at most21 record reads.
' Failure1 is invalid/missing token;5 is managed admission;0 is success.
Function TryFindSemanticSourceToken(ByRef Tokens() As SourceToken, ByVal ByteOffset As Long, ByRef Published As SourceToken, ByRef Failure As Long) As Boolean
    TryFindSemanticSourceToken = False
    Failure = 5
    Dim Count As Long = ScannerTokenLength(Tokens)
    If ByteOffset < 0 Or Count < 1 Or Count > 1048576 Then
        Failure = 1
        Exit Function
    End If
    Dim Low As Long = 0
    Dim High As Long = Count
    Dim Token As SourceToken
    While Low < High
        Dim Middle As Long = Low + (High - Low) \ 2
        Token.Kind = -1
        Call CopyScannerToken(Token, Tokens(Middle))
        If Token.Kind = -1 Then
            Exit Function
        End If
        If Token.First.ByteOffset = ByteOffset Then
            Published = Token
            Failure = 0
            TryFindSemanticSourceToken = True
            Exit Function
        End If
        If Token.First.ByteOffset < ByteOffset Then
            Low = Middle + 1
        Else
            High = Middle
        End If
    Wend
    Failure = 1
End Function

Function SemanticWorkError(ByVal Work As SemanticModuleWork, ByVal Code As Long, ByVal SyntaxId As Long) As Boolean
    SemanticWorkError = False
    Dim Node As SyntaxNode
    If TryReadSemanticSyntax(Work, SyntaxId, Node) = False Then
        Exit Function
    End If
    Call RecordSemanticDiagnostic(Work.Diagnostic, Code, Work.Source.SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
    Work.Failure = Work.Diagnostic
End Function

Function TryReadSemanticDeclaration(ByVal Work As SemanticModuleWork, ByVal DeclarationId As Long, ByRef Declaration As SemanticDeclaration) As Boolean
    TryReadSemanticDeclaration = False
    Call ResetSemanticFailure(Work.Failure)
    If DeclarationId < 0 Or DeclarationId >= Work.Catalog.DeclarationCount Then
        TryReadSemanticDeclaration = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Call ReadSemanticDeclaration(Declaration, Work.Catalog.Declarations(DeclarationId))
    Work.Metrics.DeclarationReads = Work.Metrics.DeclarationReads + 1
    TryReadSemanticDeclaration = True
End Function

Function IsSemanticInteger(ByVal TypeId As Long) As Boolean
    IsSemanticInteger = TypeId >= 2 And TypeId <= 5
End Function

Function SemanticPromotedInteger(ByVal TypeId As Long) As Long
    SemanticPromotedInteger = TypeId
    If TypeId = 2 Then
        SemanticPromotedInteger = 3
    End If
End Function

Function SemanticCommonInteger(ByVal LeftType As Long, ByVal RightType As Long) As Long
    Dim Left As Long = SemanticPromotedInteger(LeftType)
    Dim Right As Long = SemanticPromotedInteger(RightType)
    SemanticCommonInteger = Left
    If Right > Left Then
        SemanticCommonInteger = Right
    End If
End Function

' Build the final target limits from representable bootstrap literals. This
' does not let the bootstrap's narrower literal parser choose UBE source types.
Function SemanticLongLongMaximum() As LongLong
    Dim Half As LongLong = 2147483648
    Dim Value As LongLong = Half * Half
    SemanticLongLongMaximum = (Value - 1) * 2 + 1
End Function
Function SemanticLongLongMinimum() As LongLong
    Dim Maximum As LongLong = SemanticLongLongMaximum()
    SemanticLongLongMinimum = -Maximum - 1
End Function

' These scalar ranges do not borrow managed storage and preserve Err.
Function TrySemanticIntegerBounds(ByVal TypeId As Long, ByRef Minimum As LongLong, ByRef Maximum As LongLong) As Boolean
    TrySemanticIntegerBounds = True
    If TypeId = 2 Then
        Minimum = 0
        Maximum = 255
    Else
        If TypeId = 3 Then
        Minimum = -32767 - 1
        Maximum = 32767
    Else
        If TypeId = 4 Then
        Minimum = -2147483647 - 1
        Maximum = 2147483647
    Else
        If TypeId = 5 Then
        Minimum = SemanticLongLongMinimum()
        Maximum = SemanticLongLongMaximum()
    Else
        TrySemanticIntegerBounds = False
    End If
    End If
    End If
    End If
End Function

Function SemanticIntegerHolds(ByVal TypeId As Long, ByVal Value As LongLong) As Boolean
    Dim Minimum As LongLong = 0
    Dim Maximum As LongLong = 0
    SemanticIntegerHolds = False
    If TrySemanticIntegerBounds(TypeId, Minimum, Maximum) Then
        SemanticIntegerHolds = Value >= Minimum And Value <= Maximum
    End If
End Function

' Literal selection is total only after signed-64 decoding. Selection is retained
' independently of the later operator promotions and destination conversion.
Sub SelectSemanticIntegerLiteral(ByVal Context As Long, ByVal Value As LongLong, ByRef TypeId As Long, ByRef Selection As Long)
    TypeId = 4
    Selection = 3
    If IsSemanticInteger(Context) Then
        TypeId = Context
        Selection = 1
        If SemanticIntegerHolds(TypeId, Value) = False Then
            Selection = 2
            While TypeId < 5 And SemanticIntegerHolds(TypeId, Value) = False
                TypeId = TypeId + 1
            Wend
        End If
    Else
        If SemanticIntegerHolds(4, Value) = False Then
        TypeId = 5
    End If
    End If
End Sub

Function SemanticNumericOperation(ByVal SyntaxKind As Long) As Long
    SemanticNumericOperation = 0
    If SyntaxKind = 12 Then
        SemanticNumericOperation = 1
    Else
        If SyntaxKind = 13 Then
        SemanticNumericOperation = 2
    Else
        If SyntaxKind = 8 Then
        SemanticNumericOperation = 3
    Else
        If SyntaxKind = 10 Then
        SemanticNumericOperation = 4
    Else
        If SyntaxKind = 11 Then
        SemanticNumericOperation = 5
    Else
        If SyntaxKind = 5 Then
        SemanticNumericOperation = 6
    Else
        If SyntaxKind = 4 Then
        SemanticNumericOperation = 7
    Else
        If SyntaxKind = 6 Then
        SemanticNumericOperation = 8
    Else
        If SyntaxKind = 24 Then
        SemanticNumericOperation = 9
    Else
        If SyntaxKind = 26 Then
        SemanticNumericOperation = 10
    Else
        If SyntaxKind = 28 Then
        SemanticNumericOperation = 11
    Else
        If SyntaxKind = 29 Then
        SemanticNumericOperation = 12
    Else
        If SyntaxKind = 30 Then
        SemanticNumericOperation = 13
    End If
    End If
    End If
    End If
    End If
    End If
    End If
    End If
    End If
    End If
    End If
    End If
    End If
End Function

Function SemanticPropagatesIntegerContext(ByVal SyntaxKind As Long) As Boolean
    SemanticPropagatesIntegerContext = SyntaxKind = 3 Or SyntaxKind = 4 Or SyntaxKind = 5 Or SyntaxKind = 8 Or SyntaxKind = 10 Or SyntaxKind = 11 Or SyntaxKind = 12 Or SyntaxKind = 13
End Function

Function TryAppendSemanticBinding(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal DeclarationId As Long, ByVal Role As Long, ByVal Level As Long, ByRef FactId As Long) As Boolean
    TryAppendSemanticBinding = False
    Dim Declaration As SemanticDeclaration
    If TryReadSemanticDeclaration(Work, DeclarationId, Declaration) = False Then
        Exit Function
    End If
    Dim Fact As SemanticFact
    Fact.SourceId = Work.Source.SourceId
    Fact.SyntaxId = SyntaxId
    Fact.Kind = 2
    Fact.TypeId = Declaration.TypeId
    Fact.Target = DeclarationId
    Fact.Left = Role
    Fact.Right = Level
    Fact.Auxiliary = -1
    Fact.Extra = -1
    TryAppendSemanticBinding = TryAppendSemanticFact(Work, Fact, FactId)
End Function

Function TryAnnotateSemanticExpression(ByVal Work As SemanticModuleWork, ByRef Info As SemanticExpressionInfo) As Boolean
    TryAnnotateSemanticExpression = False
    Dim Fact As SemanticFact
    Fact.SourceId = Info.SourceId
    Fact.SyntaxId = Info.SyntaxId
    Fact.Kind = 1
    Fact.TypeId = Info.TypeId
    Fact.Value = Info.Value
    Fact.Target = Info.Target
    Fact.Left = Info.IntegerContext
    Fact.Right = Info.Selection
    Fact.Flags = Info.Flags
    Fact.Auxiliary = Info.Node
    Fact.Extra = Info.OriginSyntaxId
    TryAnnotateSemanticExpression = TryAppendSemanticFact(Work, Fact, Info.Annotation)
End Function

' No conversion changes the source expression type. The fact is an edge or a
' destination operation; a known folded value node retains its arithmetic type.
Function TryConvertSemanticExpression(ByVal Work As SemanticModuleWork, ByRef Info As SemanticExpressionInfo, ByVal Destination As Long, ByVal Placement As Long, ByVal Target As Long, ByVal Ordinal As Long, ByRef ConversionId As Long) As Boolean
    TryConvertSemanticExpression = False
    ConversionId = -1
    Dim Fact As SemanticFact
    Fact.SourceId = Info.SourceId
    Fact.SyntaxId = Info.SyntaxId
    Fact.Kind = 3
    Fact.TypeId = Destination
    Fact.Left = Info.TypeId
    Fact.Right = Placement
    Fact.Target = Target
    Fact.Auxiliary = Ordinal
    Fact.Extra = -1
    Fact.Value = Info.Value
    Dim Known As Boolean = (Info.Flags And 1) <> 0
    If Info.TypeId <> Destination Then
        If Info.TypeId >= 6 Or Destination >= 6 Or Info.TypeId = 0 Or Destination = 0 Then
            TryConvertSemanticExpression = SemanticWorkError(Work, 1416, Info.SyntaxId)
            Exit Function
        End If
        Fact.Flags = 1
        If Known Then
            If Destination = 1 Then
                Fact.Value = 0
                If Info.Value <> 0 Then
                    Fact.Value = 1
                End If
            Else
                Dim Converted As LongLong = Info.Value
                If Info.TypeId = 1 And Info.Value <> 0 Then
                    Converted = -1
                End If
                If SemanticIntegerHolds(Destination, Converted) = False Then
                    If (Info.Flags And 64) <> 0 Then
                        Known = False
                        Fact.Value = 0
                    Else
                        TryConvertSemanticExpression = SemanticWorkError(Work, 1410, Info.SyntaxId)
                        Exit Function
                    End If
                End If
                If Known Then
                    Fact.Value = Converted
                End If
            End If
        End If
    End If
    If Known Then
        Fact.Flags = Fact.Flags Or 2
    End If
    TryConvertSemanticExpression = TryAppendSemanticFact(Work, Fact, ConversionId)
End Function

' Known values are allocated only when a surviving parent/destination uses them.
' Their source facts already retain all discarded arithmetic operand/type detail.
Function TryMaterializeSemanticExpression(ByVal Work As SemanticModuleWork, ByRef Info As SemanticExpressionInfo) As Boolean
    TryMaterializeSemanticExpression = False
    If (Info.Flags And 64) <> 0 Then
        TryMaterializeSemanticExpression = True
        Exit Function
    End If
    If Info.Node >= 0 Then
        TryMaterializeSemanticExpression = True
        Exit Function
    End If
    If (Info.Flags And 1) = 0 Then
        TryMaterializeSemanticExpression = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Node As BoundNode
    Node.SourceId = Info.SourceId
    Node.SyntaxId = Info.OriginSyntaxId
    Node.Kind = 1
    If Info.TypeId = 1 Then
        Node.Kind = 2
    End If
    Node.TypeId = Info.TypeId
    Node.Value = Info.Value
    Node.Target = Info.Target
    Node.FirstChild = -1
    Node.NextSibling = -1
    Node.Auxiliary = -1
    If TryAppendBoundNode(Work, Node, Info.Node) = False Then
        Exit Function
    End If
    If Info.Annotation >= 0 Then
        Call ResetSemanticFailure(Work.Failure)
        Dim Fact As SemanticFact
        Call ReadSemanticFact(Fact, Work.Facts(Info.Annotation))
        Fact.Auxiliary = Info.Node
        Call WriteSemanticFact(Work.Facts(Info.Annotation), Fact)
        Work.Metrics.FactWrites = Work.Metrics.FactWrites + 1
    End If
    TryMaterializeSemanticExpression = True
End Function

' Type selection is separate from evaluation. Mixed Boolean/integer eager
' operations retain their explicit deferred status; native types are nominal.
Function TrySelectSemanticOperator(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal Kind As Long, ByVal LeftType As Long, ByVal RightType As Long, ByVal Unary As Boolean, ByRef OperandType As Long, ByRef ResultType As Long) As Boolean
    TrySelectSemanticOperator = False
    OperandType = LeftType
    ResultType = LeftType
    If Unary Then
        If IsSemanticInteger(LeftType) Then
            OperandType = SemanticPromotedInteger(LeftType)
            ResultType = OperandType
        Else
            If LeftType = 1 And Kind = 6 Then
            ResultType = 1
        Else
            TrySelectSemanticOperator = SemanticWorkError(Work, 1412, SyntaxId)
            Exit Function
        End If
        End If
    Else
        If Kind = 25 Or Kind = 27 Then
        If LeftType <> 1 Or RightType <> 1 Then
            TrySelectSemanticOperator = SemanticWorkError(Work, 1412, SyntaxId)
            Exit Function
        End If
        ResultType = 1
        OperandType = 1
    Else
        If LeftType >= 6 Or RightType >= 6 Then
        If LeftType <> RightType Or (Kind <> 15 And Kind <> 16) Then
            TrySelectSemanticOperator = SemanticWorkError(Work, 1412, SyntaxId)
            Exit Function
        End If
        ResultType = 1
    Else
        If LeftType = 1 Or RightType = 1 Then
        If LeftType <> RightType Or (Kind >= 17 And Kind <= 20) Then
            TrySelectSemanticOperator = SemanticWorkError(Work, 1432, SyntaxId)
            Exit Function
        End If
        If Kind <> 15 And Kind <> 16 And Kind <> 24 And Kind <> 26 And Kind <> 28 And Kind <> 29 And Kind <> 30 Then
            TrySelectSemanticOperator = SemanticWorkError(Work, 1412, SyntaxId)
            Exit Function
        End If
        ResultType = 1
        OperandType = 1
    Else
        If IsSemanticInteger(LeftType) And IsSemanticInteger(RightType) Then
        OperandType = SemanticCommonInteger(LeftType, RightType)
        ResultType = OperandType
        If Kind >= 15 And Kind <= 20 Then
            ResultType = 1
        End If
    Else
        TrySelectSemanticOperator = SemanticWorkError(Work, 1412, SyntaxId)
        Exit Function
    End If
    End If
    End If
    End If
    End If
    If Unary = False And Kind <> 8 And Kind <> 10 And Kind <> 11 And Kind <> 12 And Kind <> 13 And (Kind < 15 Or Kind > 20) And (Kind < 24 Or Kind > 30) Then
        TrySelectSemanticOperator = SemanticWorkError(Work, 1432, SyntaxId)
        Exit Function
    End If
    TrySelectSemanticOperator = True
End Function

' Boolean values are logical 0/1 here; no runtime Boolean ABI is selected.
Function EvaluateSemanticBoolean(ByVal Kind As Long, ByVal Left As LongLong, ByVal Right As LongLong) As LongLong
    Dim L As Boolean = Left <> 0
    Dim R As Boolean = Right <> 0
    Dim Value As Boolean = False
    If Kind = 6 Then
        Value = Not L
    Else
        If Kind = 15 Then
        Value = L = R
    Else
        If Kind = 16 Then
        Value = L <> R
    Else
        If Kind = 24 Or Kind = 25 Then
        Value = L And R
    Else
        If Kind = 26 Or Kind = 27 Then
        Value = L Or R
    Else
        If Kind = 28 Then
        Value = L <> R
    Else
        If Kind = 29 Then
        Value = L = R
    Else
        If Kind = 30 Then
        Value = (Not L) Or R
    End If
    End If
    End If
    End If
    End If
    End If
    End If
    End If
    EvaluateSemanticBoolean = 0
    If Value Then
        EvaluateSemanticBoolean = 1
    End If
End Function

Function EvaluateSemanticComparison(ByVal Kind As Long, ByVal Left As LongLong, ByVal Right As LongLong) As LongLong
    Dim Order As Long = CompareIntegers(Left, Right)
    Dim Value As Boolean = False
    If Kind = 15 Then
        Value = Order = 0
    Else
        If Kind = 16 Then
        Value = Order <> 0
    Else
        If Kind = 17 Then
        Value = Order < 0
    Else
        If Kind = 18 Then
        Value = Order <= 0
    Else
        If Kind = 19 Then
        Value = Order > 0
    Else
        If Kind = 20 Then
        Value = Order >= 0
    End If
    End If
    End If
    End If
    End If
    End If
    EvaluateSemanticComparison = 0
    If Value Then
        EvaluateSemanticComparison = 1
    End If
End Function

' The scanner/parser already selected a complete literal token. This inspects
' its supported lexical family and delegates only its exact ASCII digit span.
Function TryReadSemanticLiteral(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal Context As Long, ByVal Negative As Boolean, ByRef Info As SemanticExpressionInfo) As Boolean
    TryReadSemanticLiteral = False
    Call ClearSemanticExpression(Info, Work.Source.SourceId, SyntaxId)
    Info.IntegerContext = Context
    Dim Node As SyntaxNode
    If TryReadSemanticSyntax(Work, SyntaxId, Node) = False Then
        Exit Function
    End If
    If Node.Kind <> 2 Or Node.LastByte <= Node.FirstByte Then
        TryReadSemanticLiteral = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Matches As Boolean = False
    If TrySemanticWord(Work.Catalog, Work.Source.SourceId, Node, "true", Matches, Work.Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Matches Then
        Info.TypeId = 1
        Info.Value = 1
        Info.Flags = 9
        TryReadSemanticLiteral = True
        Exit Function
    End If
    If TrySemanticWord(Work.Catalog, Work.Source.SourceId, Node, "false", Matches, Work.Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Matches Then
        Info.TypeId = 1
        Info.Value = 0
        Info.Flags = 9
        TryReadSemanticLiteral = True
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim LiteralToken As SourceToken
    Dim TokenFailure As Long = 5
    If TryFindSemanticSourceToken(Work.Source.SyntaxInput.Tokens, Node.FirstByte, LiteralToken, TokenFailure) = False Then
        If TokenFailure = 1 Then
            TryReadSemanticLiteral = FailSemanticDomain(Work.Failure)
        End If
        Exit Function
    End If
    If LiteralToken.Kind <> 3 Then
        TryReadSemanticLiteral = SemanticWorkError(Work, 1430, SyntaxId)
        Exit Function
    End If
    Dim First As Long = Node.FirstByte
    Dim Count As Long = Node.LastByte - First
    Dim FirstCharacter As Long = Work.Source.SyntaxInput.Owner.Document.Bytes(First)
    Dim LastCharacter As Long = Work.Source.SyntaxInput.Owner.Document.Bytes(Node.LastByte - 1)
    If FirstCharacter < 48 Or FirstCharacter > 57 Then
        TryReadSemanticLiteral = SemanticWorkError(Work, 1430, SyntaxId)
        Exit Function
    End If
    Dim SuffixType As Long = -1
    If LastCharacter = 37 Then
        SuffixType = 3
    Else
        If LastCharacter = 38 Then
        SuffixType = 4
    Else
        If LastCharacter = 94 Then
        SuffixType = 5
    End If
    End If
    End If
    If SuffixType >= 0 Then
        Count = Count - 1
    End If
    Dim Minimum As LongLong = SemanticLongLongMinimum()
    Dim Maximum As LongLong = SemanticLongLongMaximum()
    If SuffixType >= 0 Then
        If TrySemanticIntegerBounds(SuffixType, Minimum, Maximum) = False Then
            Exit Function
        End If
    End If
    Dim Value As LongLong = 0
    Dim Failure As Long = 5
    ' Suffixed tokens first require their positive spelling to be representable.
    ' Explicit signed-minimum spellings remain a distinct deferred boundary.
    Dim DecodeNegative As Boolean = Negative And SuffixType < 0
    If TryDecodeDecimalInteger(Work.Source.SyntaxInput.Owner.Document.Bytes, First, Count, DecodeNegative, Minimum, Maximum, Value, Failure) = False Then
        If Failure = 5 Then
            Call ResetSemanticFailure(Work.Failure)
        Else
            If Failure = 3 Then
            Dim Code As Long = 1410
            If Negative And SuffixType >= 0 Then
                Dim Signed As LongLong = 0
                Dim SignedFailure As Long = 5
                If TryDecodeDecimalInteger(Work.Source.SyntaxInput.Owner.Document.Bytes, First, Count, True, SemanticLongLongMinimum(), SemanticLongLongMaximum(), Signed, SignedFailure) Then
                    If Signed = Minimum Then
                        Code = 1430
                    End If
                Else
                    If SignedFailure = 5 Then
                        Call ResetSemanticFailure(Work.Failure)
                        Exit Function
                    End If
                End If
            End If
            TryReadSemanticLiteral = SemanticWorkError(Work, Code, SyntaxId)
        Else
            TryReadSemanticLiteral = SemanticWorkError(Work, 1430, SyntaxId)
        End If
        End If
        Exit Function
    End If
    If SuffixType >= 0 Then
        Info.TypeId = SuffixType
        Info.Selection = 4
        If Negative Then
            Failure = 5
            If TryEvaluateInteger(6, Value, 0, Minimum, Maximum, Value, Failure) = False Then
                TryReadSemanticLiteral = SemanticWorkError(Work, 1410, SyntaxId)
                Exit Function
            End If
        End If
    Else
        Call SelectSemanticIntegerLiteral(Context, Value, Info.TypeId, Info.Selection)
    End If
    Info.Value = Value
    Info.Flags = 9
    TryReadSemanticLiteral = True
End Function

' Resolve a name once at the prescribed levels. Member syntax is Module.Member,
' never a payload field or an invitation to search another callable signature.
Function TryResolveSemanticExpressionName(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal AssignmentTarget As Boolean, ByRef DeclarationId As Long, ByRef LookupLevel As Long) As Boolean
    TryResolveSemanticExpressionName = TryLookupSemanticExpressionName(Work, SyntaxId, AssignmentTarget, True, DeclarationId, LookupLevel)
End Function

Function TryLookupSemanticExpressionName(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal AssignmentTarget As Boolean, ByVal ObserveQualifier As Boolean, ByRef DeclarationId As Long, ByRef LookupLevel As Long) As Boolean
    TryLookupSemanticExpressionName = False
    DeclarationId = -1
    LookupLevel = 0
    Dim Node As SyntaxNode
    If TryReadSemanticSyntax(Work, SyntaxId, Node) = False Then
        Exit Function
    End If
    Dim NameId As Long = -1
    If Node.Kind = 1 Then
        If TryGetSemanticName(Work.Catalog, Work.Source.SourceId, SyntaxId, NameId, Work.Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        Work.Metrics.Lookups = Work.Metrics.Lookups + 1
        If TryLookupSemanticName(Work.Catalog, Work.Source.SourceId, Work.Scope, NameId, AssignmentTarget, DeclarationId, LookupLevel, Work.Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If DeclarationId < 0 Then
            TryLookupSemanticExpressionName = SemanticWorkError(Work, 1406, SyntaxId)
            Exit Function
        End If
    Else
        If Node.Kind = 34 Then
        Dim ModuleSyntax As Long = Node.FirstChild
        Dim ModuleNode As SyntaxNode
        If TryReadSemanticSyntax(Work, ModuleSyntax, ModuleNode) = False Then
            Exit Function
        End If
        If ModuleNode.Kind <> 1 Then
            Dim Code As Long = 1412
            If ModuleNode.Kind = 34 Then
                Code = 1400
            End If
            TryLookupSemanticExpressionName = SemanticWorkError(Work, Code, SyntaxId)
            Exit Function
        End If
        If ModuleNode.FirstChild >= 0 Then
            Dim ModuleSuffix As SyntaxNode
            If TryReadSemanticSyntax(Work, ModuleNode.FirstChild, ModuleSuffix) = False Then
                Exit Function
            End If
            If ModuleSuffix.Kind = 83 Then
                TryLookupSemanticExpressionName = SemanticWorkError(Work, 1403, ModuleSyntax)
                Exit Function
            End If
        End If
        Dim MemberSyntax As Long = ModuleNode.NextSibling
        Dim MemberName As Long = -1
        If TryGetSemanticName(Work.Catalog, Work.Source.SourceId, ModuleSyntax, NameId, Work.Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Work.Failure)
        If TryGetSemanticName(Work.Catalog, Work.Source.SourceId, MemberSyntax, MemberName, Work.Failure) = False Then
            Exit Function
        End If
        Dim ModuleDecl As Long = -1
        Call ResetSemanticFailure(Work.Failure)
        Work.Metrics.Lookups = Work.Metrics.Lookups + 1
        If TryLookupSemanticQualified(Work.Catalog, Work.Source.SourceId, NameId, MemberName, DeclarationId, ModuleDecl, Work.Failure) = False Then
            Exit Function
        End If
        LookupLevel = 6
        Call ResetSemanticFailure(Work.Failure)
        Dim Binding As Long = -1
        If ObserveQualifier Then
            Dim ModuleLevel As Long = 5
            If ModuleDecl = Work.Source.SourceId Then
                ModuleLevel = 3
            Else
                If Work.Catalog.Sources(ModuleDecl).PackageId = Work.Source.PackageId Then
                    ModuleLevel = 4
                End If
            End If
            If TryAppendSemanticBinding(Work, ModuleSyntax, ModuleDecl, 6, ModuleLevel, Binding) = False Then
                Exit Function
            End If
        End If
    Else
        TryLookupSemanticExpressionName = SemanticWorkError(Work, 1414, SyntaxId)
        Exit Function
    End If
    End If
    Call ResetSemanticFailure(Work.Failure)
    Dim Declaration As SemanticDeclaration
    If TryReadSemanticDeclaration(Work, DeclarationId, Declaration) = False Then
        Exit Function
    End If
    ' Reads before a written local declaration are explicitly outside this slice;
    ' the declaration itself remains visible for its own initializer.
    If Declaration.SourceId = Work.Source.SourceId And Declaration.Scope = Work.Scope And Declaration.Kind = 2 And Work.Scope >= Work.Catalog.SourceCount Then
        Dim DeclNode As SyntaxNode
        If TryReadSemanticSyntax(Work, Declaration.SyntaxId, DeclNode) = False Then
            Exit Function
        End If
        If Node.FirstByte < DeclNode.FirstByte Then
            TryLookupSemanticExpressionName = SemanticWorkError(Work, 1431, SyntaxId)
            Exit Function
        End If
    End If
    Dim SelectedName As SyntaxNode
    Dim SelectedSyntax As Long = SyntaxId
    SelectedName = Node
    If Node.Kind = 34 Then
        Dim LeftNode As SyntaxNode
        If TryReadSemanticSyntax(Work, Node.FirstChild, LeftNode) = False Then
            Exit Function
        End If
        If TryReadSemanticSyntax(Work, LeftNode.NextSibling, SelectedName) = False Then
            Exit Function
        End If
        SelectedSyntax = LeftNode.NextSibling
    End If
    If SelectedName.FirstChild >= 0 Then
        Dim Suffix As SyntaxNode
        If TryReadSemanticSyntax(Work, SelectedName.FirstChild, Suffix) = False Then
            Exit Function
        End If
        If Suffix.Kind = 83 Then
            Call ResetSemanticFailure(Work.Failure)
            Dim Character As Long = Work.Source.SyntaxInput.Owner.Document.Bytes(Suffix.FirstByte)
            Dim SuffixType As Long = -1
            If Character = 37 Then
                SuffixType = 3
            Else
                If Character = 38 Then
                SuffixType = 4
            Else
                If Character = 94 Then
                SuffixType = 5
            End If
            End If
            End If
            If SuffixType <> Declaration.TypeId Then
                Dim SuffixCode As Long = 1403
                TryLookupSemanticExpressionName = SemanticWorkError(Work, SuffixCode, SelectedSyntax)
                Exit Function
            End If
        End If
    End If
    TryLookupSemanticExpressionName = True
End Function

Function TryReadSemanticStorage(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal DeclarationId As Long, ByVal LookupLevel As Long, ByVal RequiredConstant As Boolean, ByVal Skipped As Boolean, ByVal ArgumentStorage As Boolean, ByRef Info As SemanticExpressionInfo) As Boolean
    TryReadSemanticStorage = False
    Call ClearSemanticExpression(Info, Work.Source.SourceId, SyntaxId)
    Dim Declaration As SemanticDeclaration
    If TryReadSemanticDeclaration(Work, DeclarationId, Declaration) = False Then
        Exit Function
    End If
    Info.TypeId = Declaration.TypeId
    Info.Target = DeclarationId
    Dim Role As Long = 1
    If ArgumentStorage Then
        Role = 10
    End If
    If Declaration.Kind = 3 Then
        Role = 2
        If Declaration.SourceId = Work.Source.SourceId And Declaration.Scope = Work.Scope And Work.Scope >= Work.Catalog.SourceCount Then
            Dim ReadAt As SyntaxNode
            Dim DeclaredAt As SyntaxNode
            If TryReadSemanticSyntax(Work, SyntaxId, ReadAt) = False Then
                Exit Function
            End If
            If TryReadSemanticSyntax(Work, Declaration.SyntaxId, DeclaredAt) = False Then
                Exit Function
            End If
            If ReadAt.FirstByte < DeclaredAt.FirstByte Then
                Dim VisibilityCode As Long = 1431
                If RequiredConstant Then
                    VisibilityCode = 1413
                End If
                TryReadSemanticStorage = SemanticWorkError(Work, VisibilityCode, SyntaxId)
                Exit Function
            End If
        End If
        If Declaration.ValueKnown = 0 Then
            TryReadSemanticStorage = SemanticWorkError(Work, 1413, SyntaxId)
            Exit Function
        End If
        Info.Flags = 1
        Info.Value = Declaration.Value
    Else
        If Declaration.Kind = 2 Or Declaration.Kind = 4 Then
        If RequiredConstant Then
            TryReadSemanticStorage = SemanticWorkError(Work, 1413, SyntaxId)
            Exit Function
        End If
        Info.Flags = 2
        Dim Node As BoundNode
        Node.SourceId = Info.SourceId
        Node.SyntaxId = SyntaxId
        Node.Kind = 3
        Node.TypeId = Info.TypeId
        Node.Target = DeclarationId
        Node.FirstChild = -1
        Node.NextSibling = -1
        Node.Auxiliary = -1
        If Skipped = False Then
            If TryAppendBoundNode(Work, Node, Info.Node) = False Then
                Exit Function
            End If
        End If
    Else
        TryReadSemanticStorage = SemanticWorkError(Work, 1412, SyntaxId)
        Exit Function
    End If
    End If
    If Skipped Then
        Info.Flags = Info.Flags Or 64
    End If
    Dim Binding As Long = -1
    Dim BindingSyntax As Long = SyntaxId
    Dim Written As SyntaxNode
    If TryReadSemanticSyntax(Work, SyntaxId, Written) = False Then
        Exit Function
    End If
    If Written.Kind = 34 Then
        Dim Qualifier As SyntaxNode
        If TryReadSemanticSyntax(Work, Written.FirstChild, Qualifier) = False Then
            Exit Function
        End If
        BindingSyntax = Qualifier.NextSibling
    End If
    TryReadSemanticStorage = TryAppendSemanticBinding(Work, BindingSyntax, DeclarationId, Role, LookupLevel, Binding)
End Function

Function TryFinishSemanticOperator(ByVal Work As SemanticModuleWork, ByVal SyntaxId As Long, ByVal Kind As Long, ByRef Left As SemanticExpressionInfo, ByRef Right As SemanticExpressionInfo, ByVal Unary As Boolean, ByVal Skipped As Boolean, ByRef Info As SemanticExpressionInfo) As Boolean
    TryFinishSemanticOperator = False
    Call ClearSemanticExpression(Info, Work.Source.SourceId, SyntaxId)
    Dim OperandType As Long = 0
    If TrySelectSemanticOperator(Work, SyntaxId, Kind, Left.TypeId, Right.TypeId, Unary, OperandType, Info.TypeId) = False Then
        Exit Function
    End If
    Dim ConversionId As Long = -1
    If TryConvertSemanticExpression(Work, Left, OperandType, 1, SyntaxId, 0, ConversionId) = False Then
        Exit Function
    End If
    If Unary = False Then
        If TryConvertSemanticExpression(Work, Right, OperandType, 2, SyntaxId, 1, ConversionId) = False Then
            Exit Function
        End If
    End If
    Dim KnownLeft As Boolean = (Left.Flags And 1) <> 0
    Dim KnownRight As Boolean = (Right.Flags And 1) <> 0
    If Skipped = False And KnownRight And (Kind = 10 Or Kind = 11) And Right.Value = 0 Then
        TryFinishSemanticOperator = SemanticWorkError(Work, 1411, SyntaxId)
        Exit Function
    End If
    Dim Known As Boolean = KnownLeft And (Unary Or KnownRight)
    If KnownLeft And ((Kind = 25 And Left.Value = 0) Or (Kind = 27 And Left.Value <> 0)) Then
        Known = True
        Info.Value = Left.Value
    Else
        If Known And Skipped = False Then
        If OperandType = 1 Then
            Info.Value = EvaluateSemanticBoolean(Kind, Left.Value, Right.Value)
        Else
            If Kind >= 15 And Kind <= 20 Then
            Info.Value = EvaluateSemanticComparison(Kind, Left.Value, Right.Value)
        Else
            Dim Minimum As LongLong = 0
            Dim Maximum As LongLong = 0
            If TrySemanticIntegerBounds(OperandType, Minimum, Maximum) = False Then
                TryFinishSemanticOperator = FailSemanticDomain(Work.Failure)
                Exit Function
            End If
            Dim Failure As Long = 5
            If TryEvaluateInteger(SemanticNumericOperation(Kind), Left.Value, Right.Value, Minimum, Maximum, Info.Value, Failure) = False Then
                Dim Code As Long = 1410
                If Failure = 4 Then
                    Code = 1411
                End If
                TryFinishSemanticOperator = SemanticWorkError(Work, Code, SyntaxId)
                Exit Function
            End If
        End If
        End If
    Else
        Known = False
    End If
    End If
    If Known Then
        Info.Flags = 1
        If (Left.Flags And 8) <> 0 And (Unary Or (Right.Flags And 8) <> 0) And IsSemanticInteger(Info.TypeId) Then
            Info.Flags = Info.Flags Or 8 Or 16
        End If
    Else
        If Skipped = False Then
        If TryMaterializeSemanticExpression(Work, Left) = False Then
            Exit Function
        End If
        If Unary = False Then
            If TryMaterializeSemanticExpression(Work, Right) = False Then
                Exit Function
            End If
        End If
        Dim Node As BoundNode
        Node.SourceId = Info.SourceId
        Node.SyntaxId = SyntaxId
        Node.Kind = 5
        If Unary Then
            Node.Kind = 4
        End If
        Node.TypeId = Info.TypeId
        Node.Target = -1
        Node.FirstChild = -1
        Node.NextSibling = -1
        Node.Auxiliary = Kind
        If IsSemanticInteger(Info.TypeId) And SemanticNumericOperation(Kind) >= 1 And SemanticNumericOperation(Kind) <= 6 Then
            Node.Flags = 1
            Info.Flags = 128
        End If
        If Kind = 25 Or Kind = 27 Then
            Node.Flags = Node.Flags Or 2
            Info.Flags = Info.Flags Or 32
        End If
        If TryAppendBoundNode(Work, Node, Info.Node) = False Then
            Exit Function
        End If
        Dim Tail As Long = -1
        If TryLinkBoundChild(Work, Info.Node, Left.Node, Tail) = False Then
            Exit Function
        End If
        If Unary = False Then
            If TryLinkBoundChild(Work, Info.Node, Right.Node, Tail) = False Then
                Exit Function
            End If
        End If
    End If
    End If
    If Skipped Then
        Info.Flags = Info.Flags Or 64
    End If
    TryFinishSemanticOperator = True
End Function
