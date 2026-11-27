UBE SOURCE 1 MODULE
Attribute UBE_Name = "ContextBindingProbe"
Private Const Control As Long = 0

' Exercises the actual binder with explicit module-owned input, without a launch protocol.
Private Function Check(ByRef Source() As Byte, ByVal Hosted As Boolean, ByVal ExpectedCode As Long, ByVal ExpectedReason As Long, ByVal ExpectedConstants As Long, ByVal ExpectedTemporary As Long, ByVal ContextPackage As Boolean) As Boolean
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim ParseError As ProjectSyntax.ProjectDiagnostic
    Dim Package() As Byte
    Dim Facts() As ExpressionBinder.BoundExpression
    Dim FactCount As Long = 77
    Dim Text() As Byte
    Dim Used As Long
    Dim Diagnostic As DeclarationBinder.BindingDiagnostic
    Dim Status As Boolean
    Dim Index As Long
    Dim Supplied As Long
    Dim Constants As Long
    Dim Temporaries As Long
    Dim Qualified As Long
    Dim Expected As LongLong
    On Error GoTo Failed
    If ContextPackage Then
        If Not BufferPrimitives.TryResizeBytes(Package, 9, False) Then Exit Function
        Package(0) = 105: Package(1) = 115: Package(2) = 95
        Package(3) = 105: Package(4) = 110: Package(5) = 95
        Package(6) = 105: Package(7) = 100: Package(8) = 101
    Else
        If Not BufferPrimitives.TryResizeBytes(Package, 1, False) Then Exit Function
        Package(0) = 112
    End If
    If Hosted Then Expected = -1
    If Not ProjectSyntax.TryAppendModuleWithContext(Source, 0, Hosted, Bytes, Tokens, Nodes, Modules, Counts, ParseError) Then Exit Function
    Status = False
    Status = ExpressionBinder.TryBindExpressions(Bytes, Tokens, Nodes, Modules, Counts, Package, False, Facts, FactCount, Text, Used, Diagnostic)
    If ExpectedCode <> 0 Then
        If Status Or Diagnostic.Code <> ExpectedCode Or Diagnostic.Reason <> ExpectedReason Or FactCount <> 0 Then Exit Function
        If Diagnostic.Line < 1 Or Diagnostic.Column < 1 Then Exit Function
        Check = True
        Exit Function
    End If
    If Not Status Or Diagnostic.Code <> 0 Or FactCount <> Counts.NodeCount Then Exit Function
    Do While Index < FactCount
        If Facts(Index).IsIDEContextConstant Then
            Supplied = Supplied + 1
            If Facts(Index).TypeCode <> SyntaxTokens.KwBoolean Or Not Facts(Index).ConstantKnown Or Facts(Index).Writable Then Exit Function
            If Facts(Index).SymbolIndex <> 0 Or Facts(Index).ConstantValue <> Expected + Control Then Exit Function
        End If
        If Nodes(Index).Kind = SourceParser.ConstantNode Then
            Constants = Constants + 1
            If Not Facts(Index).ConstantKnown Or Facts(Index).ConstantValue <> Expected Then Exit Function
        End If
        If Facts(Index).ArgumentMode = 3 Then Temporaries = Temporaries + 1
        If ContextPackage And Nodes(Index).Kind = SourceParser.MemberNode And Facts(Index).TypeCode = SyntaxTokens.KwBoolean Then
            If Not Facts(Index).ConstantKnown Or Facts(Index).ConstantValue <> Expected Or Facts(Index).SymbolIndex = 0 Then Exit Function
            Qualified = Qualified + 1
        End If
        Index = Index + 1
    Loop
    If ContextPackage And Qualified <> 1 Then Exit Function
    Check = Supplied > 0 And Constants = ExpectedConstants And Temporaries = ExpectedTemporary
    Exit Function
Failed:
    Check = False
End Function

Private Function UnexpectedFailure() As Boolean
    Err.Raise 5
End Function

' GENERATED CASES
