UBE SOURCE 1 MODULE
Attribute UBE_Name = "InstanceBindingProbe"
Private Const Control As Long = 0
Private Function Check(ByRef Source() As Byte, ByRef Caller() As Byte, ByVal ExpectedCode As Long, ByVal ExpectedReason As Long, ByVal ExpectedMe As Long, ByVal ExpectedFields As Long, ByVal ExpectedReceivers As Long, ByVal ExpectedTemporary As Long) As Boolean
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim ParseError As ProjectSyntax.ProjectDiagnostic
    Dim Package(0 To 0) As Byte
    Dim Facts() As ExpressionBinder.BoundExpression
    Dim FactCount As Long = 77
    Dim Text() As Byte
    Dim Used As Long
    Dim Diagnostic As DeclarationBinder.BindingDiagnostic
    Dim Status As Boolean
    Dim Index As Long
    Dim Current As Long
    Dim Fields As Long
    Dim Receivers As Long
    Dim Temporaries As Long
    On Error GoTo Failed
    Package(0) = 112
    If Not ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, ParseError) Then
        Check = ExpectedCode = ParseError.Code And ExpectedReason = ParseError.Reason
        Exit Function
    End If
    If Not ProjectSyntax.TryAppendModule(Caller, Bytes, Tokens, Nodes, Modules, Counts, ParseError) Then Exit Function
    Status = False
    Status = ExpressionBinder.TryBindExpressions(Bytes, Tokens, Nodes, Modules, Counts, Package, False, Facts, FactCount, Text, Used, Diagnostic)
    If ExpectedCode <> 0 Then
        If Status Or Diagnostic.Code <> ExpectedCode Or Diagnostic.Reason <> ExpectedReason Or FactCount <> 0 Then Exit Function
        If Diagnostic.Line < 1 Or Diagnostic.Column < 1 Then Exit Function
        Check = True
        Exit Function
    End If
    If Not Status Or FactCount <> Counts.NodeCount Then Exit Function
    Do While Index < FactCount
        If Facts(Index).IsCurrentInstance Then
            Current = Current + 1
            If Facts(Index).TypeCode <> SyntaxTokens.KwObject Or Facts(Index).TypeSymbol = 0 Or Facts(Index).Writable Or Facts(Index).ConstantKnown Then Exit Function
        End If
        If Facts(Index).AccessKind = 4 And (Nodes(Index).Kind = SourceParser.NameNode Or Nodes(Index).Kind = SourceParser.MemberNode) Then
            Fields = Fields + 1
            If Not Facts(Index).Writable Then Exit Function
        End If
        If Facts(Index).InstanceReceiver <> 0 Then Receivers = Receivers + 1
        If Facts(Index).ArgumentMode = 3 Then Temporaries = Temporaries + 1
        Index = Index + 1
    Loop
    Check = Current = ExpectedMe + Control And Fields = ExpectedFields And Receivers = ExpectedReceivers And Temporaries = ExpectedTemporary
    Exit Function
Failed:
    Check = False
End Function
Private Function UnexpectedFailure() As Boolean
    Err.Raise 5
End Function
' GENERATED CASES
