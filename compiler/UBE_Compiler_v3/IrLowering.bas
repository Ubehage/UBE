UBE SOURCE 1 MODULE
Attribute UBE_Name = "IrLowering"

Function IrLocationForSyntax(ByVal NodeIndex As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef Locations() As IrLocation, ByRef Build As IrBuildState) As Long
    If NodeIndex < 0 Or SyntaxNodes(NodeIndex).FirstToken < 0 Then
        IrLocationForSyntax = AppendIrLocation(Locations, Build.LocationCount, Build.LocationCapacity, 0, 0, 0, 1, 1, NodeIndex, 1)
        Exit Function
    End If
    Dim FirstToken As Long = SyntaxNodes(NodeIndex).FirstToken
    Dim LastToken As Long = SyntaxNodes(NodeIndex).LastToken
    Dim RangeBytes As Long = 0
    If LastToken >= FirstToken Then
        RangeBytes = Tokens(LastToken).StartByte + Tokens(LastToken).ByteLength - Tokens(FirstToken).StartByte
    End If
    IrLocationForSyntax = AppendIrLocation(Locations, Build.LocationCount, Build.LocationCapacity, SyntaxNodes(NodeIndex).SourceId, Tokens(FirstToken).StartByte, RangeBytes, Tokens(FirstToken).LineNumber, Tokens(FirstToken).ColumnNumber, NodeIndex, 0)
End Function

Function IrStructuredRegionOwner(ByVal NodeIndex As Long, ByVal ProcedureNode As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Rules() As GrammarRule) As Long
    Dim CurrentNode As Long = SyntaxNodes(NodeIndex).ParentNode
    While CurrentNode >= 0 And CurrentNode <> ProcedureNode
        If SyntaxRuleIs(CurrentNode, "elseif-part", SyntaxNodes, Rules) <> 0 Or SyntaxRuleIs(CurrentNode, "else-part", SyntaxNodes, Rules) <> 0 Or SyntaxRuleIs(CurrentNode, "block-if", SyntaxNodes, Rules) <> 0 Or SyntaxRuleIs(CurrentNode, "while-statement", SyntaxNodes, Rules) <> 0 Then
            IrStructuredRegionOwner = CurrentNode
            Exit Function
        End If
        CurrentNode = SyntaxNodes(CurrentNode).ParentNode
    Wend
    If CurrentNode = ProcedureNode Then
        IrStructuredRegionOwner = ProcedureNode
    Else
        IrStructuredRegionOwner = -1
    End If
End Function

Function SyntaxNodeIsDescendantOf(ByVal NodeIndex As Long, ByVal AncestorNode As Long, ByRef SyntaxNodes() As SyntaxNode) As Long
    Dim CurrentNode As Long = NodeIndex
    While CurrentNode >= 0
        If CurrentNode = AncestorNode Then
            SyntaxNodeIsDescendantOf = 1
            Exit Function
        End If
        CurrentNode = SyntaxNodes(CurrentNode).ParentNode
    Wend
    SyntaxNodeIsDescendantOf = 0
End Function

Function SyntaxSubtreeLastNode(ByVal RootNode As Long, ByVal SyntaxNodeCount As Long, ByRef SyntaxNodes() As SyntaxNode) As Long
    Dim LastNode As Long = RootNode
    Dim NodeIndex As Long = RootNode + 1
    While NodeIndex < SyntaxNodeCount
        If SyntaxNodeIsDescendantOf(NodeIndex, RootNode, SyntaxNodes) = 0 Then
            Exit While
        End If
        LastNode = NodeIndex
        NodeIndex = NodeIndex + 1
    Wend
    SyntaxSubtreeLastNode = LastNode
End Function

Function FirstExpressionAtOrAfterNode(ByVal FirstNode As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long) As Long
    ' Expressions are appended in syntax-node order. A linear seek keeps this
    ' helper inside the v2 Bootstrap Profile; the subsequent scan remains
    ' bounded to the control statement's syntax subtree.
    Dim ExpressionIndex As Long = 0
    While ExpressionIndex < ExpressionCount
        If Expressions(ExpressionIndex).SyntaxNode >= FirstNode Then
            Exit While
        End If
        ExpressionIndex = ExpressionIndex + 1
    Wend
    FirstExpressionAtOrAfterNode = ExpressionIndex
End Function

Function FindControlConditionExpression(ByVal ControlNode As Long, ByVal StopWord As String, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByVal SyntaxNodeCount As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim FirstToken As Long = SyntaxNodes(ControlNode).FirstToken + 1
    Dim LastToken As Long = SyntaxNodes(ControlNode).LastToken
    If StringLength(StopWord) > 0 Then
        Dim TokenIndex As Long = FirstToken
        While TokenIndex <= LastToken
            If EqualsFolded(Tokens(TokenIndex).Spelling, StopWord) <> 0 Then
                LastToken = TokenIndex - 1
                Exit While
            End If
            TokenIndex = TokenIndex + 1
        Wend
    Else
        Dim HeaderLine As Long = Tokens(SyntaxNodes(ControlNode).FirstToken).LineNumber
        Dim LineToken As Long = FirstToken
        While LineToken <= LastToken
            If Tokens(LineToken).LineNumber <> HeaderLine Then
                LastToken = LineToken - 1
                Exit While
            End If
            LineToken = LineToken + 1
        Wend
    End If
    Dim BestExpression As Long = -1
    Dim BestFirstToken As Long = LastToken + 1
    Dim ExpressionIndex As Long = 0
    While ExpressionIndex < ExpressionCount
        Dim ExpressionNode As Long = Expressions(ExpressionIndex).SyntaxNode
        If SyntaxNodes(ExpressionNode).FirstToken >= FirstToken And SyntaxNodes(ExpressionNode).LastToken <= LastToken Then
            If SyntaxNodes(ExpressionNode).FirstToken < BestFirstToken Then
                BestExpression = ExpressionIndex
                BestFirstToken = SyntaxNodes(ExpressionNode).FirstToken
            Else
                If SyntaxNodes(ExpressionNode).FirstToken = BestFirstToken Then
                    If BestExpression < 0 Or SyntaxNodes(ExpressionNode).LastToken > SyntaxNodes(Expressions(BestExpression).SyntaxNode).LastToken Then
                        BestExpression = ExpressionIndex
                    End If
                End If
            End If
        End If
        ExpressionIndex = ExpressionIndex + 1
    Wend
    FindControlConditionExpression = BestExpression
End Function

Function AppendControlIrBlock(ByVal FunctionIndex As Long, ByVal LocationIndex As Long, ByRef Functions() As IrFunction, ByRef Blocks() As IrBlock, ByRef Build As IrBuildState) As Long
    Dim Result As Long = AppendIrBlock(Blocks, Build.BlockCount, Build.BlockCapacity, FunctionIndex, Functions(FunctionIndex).BlockCount, 0, LocationIndex)
    If Result >= 0 Then
        Functions(FunctionIndex).BlockCount = Functions(FunctionIndex).BlockCount + 1
    End If
    AppendControlIrBlock = Result
End Function

Function FinishIrBranchBlock(ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal TargetBlock As Long, ByVal EdgeKind As Long, ByVal ConditionValue As Long, ByVal LocationIndex As Long, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByRef Edges() As IrEdge, ByRef Build As IrBuildState) As Long
    Dim InstructionIndex As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, IrOpBranch(), -1, -1, TargetBlock, -1, -1, 0, -1, 0, "", LocationIndex)
    If InstructionIndex < 0 Then
        FinishIrBranchBlock = 0
        Exit Function
    End If
    Blocks(BlockIndex).InstructionCount = Build.InstructionCount - Blocks(BlockIndex).FirstInstruction
    If AppendIrEdge(Edges, Build.EdgeCount, Build.EdgeCapacity, FunctionIndex, BlockIndex, TargetBlock, EdgeKind, ConditionValue, 0, 0, LocationIndex) < 0 Then
        FinishIrBranchBlock = 0
    Else
        FinishIrBranchBlock = 1
    End If
End Function

Function FinishIrConditionalBlock(ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal ConditionValue As Long, ByVal TrueBlock As Long, ByVal FalseBlock As Long, ByVal LocationIndex As Long, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Edges() As IrEdge, ByRef Build As IrBuildState) As Long
    Dim InstructionIndex As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, IrOpConditionalBranch(), -1, -1, TrueBlock, FalseBlock, -1, 0, -1, 0, "", LocationIndex)
    If InstructionIndex < 0 Or AppendIrInstructionOperand(InstructionIndex, IrOperandValue(), ConditionValue, "", Instructions, Operands, Build) = 0 Then
        FinishIrConditionalBlock = 0
        Exit Function
    End If
    Blocks(BlockIndex).InstructionCount = Build.InstructionCount - Blocks(BlockIndex).FirstInstruction
    If AppendIrEdge(Edges, Build.EdgeCount, Build.EdgeCapacity, FunctionIndex, BlockIndex, TrueBlock, IrEdgeTrue(), ConditionValue, 0, 0, LocationIndex) < 0 Or AppendIrEdge(Edges, Build.EdgeCount, Build.EdgeCapacity, FunctionIndex, BlockIndex, FalseBlock, IrEdgeFalse(), ConditionValue, 0, 0, LocationIndex) < 0 Then
        FinishIrConditionalBlock = 0
    Else
        FinishIrConditionalBlock = 1
    End If
End Function

Function IrBinaryOperatorPriority(ByVal OperatorText As String) As Long
    If EqualsFolded(OperatorText, "Or") <> 0 Or EqualsFolded(OperatorText, "Xor") <> 0 Then
        IrBinaryOperatorPriority = 1
        Exit Function
    End If
    If EqualsFolded(OperatorText, "And") <> 0 Then
        IrBinaryOperatorPriority = 2
        Exit Function
    End If
    If OperatorText = "=" Or OperatorText = "<>" Or OperatorText = "<" Or OperatorText = "<=" Or OperatorText = ">" Or OperatorText = ">=" Then
        IrBinaryOperatorPriority = 3
        Exit Function
    End If
    If OperatorText = "&" Then
        IrBinaryOperatorPriority = 4
        Exit Function
    End If
    If OperatorText = "+" Or OperatorText = "-" Then
        IrBinaryOperatorPriority = 5
        Exit Function
    End If
    If OperatorText = "*" Or OperatorText = "/" Or OperatorText = "\" Or EqualsFolded(OperatorText, "Mod") <> 0 Then
        IrBinaryOperatorPriority = 6
        Exit Function
    End If
    IrBinaryOperatorPriority = 0
End Function

Function IsIrUnarySign(ByVal TokenIndex As Long, ByVal FirstToken As Long, ByRef Tokens() As LexicalToken) As Long
    If Tokens(TokenIndex).Spelling <> "+" And Tokens(TokenIndex).Spelling <> "-" Then
        IsIrUnarySign = 0
        Exit Function
    End If
    Dim PreviousToken As Long = TokenIndex - 1
    While PreviousToken >= FirstToken And Tokens(PreviousToken).TokenKind >= 9 And Tokens(PreviousToken).TokenKind <= 12
        PreviousToken = PreviousToken - 1
    Wend
    If PreviousToken < FirstToken Then
        IsIrUnarySign = 1
        Exit Function
    End If
    If Tokens(PreviousToken).Spelling = "(" Or Tokens(PreviousToken).Spelling = "," Then
        IsIrUnarySign = 1
        Exit Function
    End If
    If IrBinaryOperatorPriority(Tokens(PreviousToken).Spelling) > 0 Then
        IsIrUnarySign = 1
        Exit Function
    End If
    IsIrUnarySign = 0
End Function

Function SemanticFunctionIndex(ByVal SymbolIndex As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long) As Long
    Dim Index As Long = 0
    While Index < FunctionCount
        If Functions(Index).SymbolIndex = SymbolIndex Then
            SemanticFunctionIndex = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    SemanticFunctionIndex = -1
End Function

Function IsIrProcedureSymbol(ByVal SymbolKind As Long) As Long
    If SymbolKind = SemanticSymbolProcedure() Or SymbolKind = SemanticSymbolProperty() Then
        IsIrProcedureSymbol = 1
    Else
        IsIrProcedureSymbol = 0
    End If
End Function

Function FindExpressionBindingOwner(ByVal SyntaxNodeIndex As Long, ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long) As Long
    If SyntaxNodeIndex >= 0 And SyntaxNodeIndex < BindingCount Then
        If Bindings(SyntaxNodeIndex).SyntaxNode = SyntaxNodeIndex Then
            FindExpressionBindingOwner = Bindings(SyntaxNodeIndex).OwnerSymbol
            Exit Function
        End If
    End If
    Dim Index As Long = 0
    While Index < BindingCount
        If Bindings(Index).SyntaxNode = SyntaxNodeIndex Then
            FindExpressionBindingOwner = Bindings(Index).OwnerSymbol
            Exit Function
        End If
        Index = Index + 1
    Wend
    FindExpressionBindingOwner = -1
End Function

Function FindIrStorageForSymbol(ByVal SymbolIndex As Long, ByVal FunctionIndex As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long) As Long
    Dim Index As Long = 0
    While Index < StorageCount
        If Storages(Index).SymbolIndex = SymbolIndex Then
            If Storages(Index).FunctionIndex = FunctionIndex Or Storages(Index).FunctionIndex = -1 Then
                FindIrStorageForSymbol = Index
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    FindIrStorageForSymbol = -1
End Function

Function FindVisibleIrSymbolByName(ByVal SymbolName As String, ByVal OwnerSymbol As Long, ByVal FunctionIndex As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Storages() As IrStorage, ByVal StorageCount As Long) As Long
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolName = SymbolName Or EqualsFolded(Symbols(SymbolIndex).SymbolName, SymbolName) <> 0 Then
            If Symbols(SymbolIndex).SymbolKind = SemanticSymbolVariable() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() Then
                If Symbols(SymbolIndex).ParentSymbol = OwnerSymbol Then
                    If FindIrStorageForSymbol(SymbolIndex, FunctionIndex, Storages, StorageCount) >= 0 Then
                        FindVisibleIrSymbolByName = SymbolIndex
                        Exit Function
                    End If
                End If
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    SymbolIndex = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolName = SymbolName Or EqualsFolded(Symbols(SymbolIndex).SymbolName, SymbolName) <> 0 Then
            If Symbols(SymbolIndex).SymbolKind = SemanticSymbolVariable() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() Then
                If FindIrStorageForSymbol(SymbolIndex, FunctionIndex, Storages, StorageCount) >= 0 Then
                    FindVisibleIrSymbolByName = SymbolIndex
                    Exit Function
                End If
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    FindVisibleIrSymbolByName = -1
End Function

Function ResolveDirectTypeMember(ByVal BaseType As Long, ByVal MemberName As String, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef MemberOrdinal As Long) As Long
    MemberOrdinal = -1
    If BaseType < 0 Or BaseType >= TypeCount Then
        ResolveDirectTypeMember = -1
        Exit Function
    End If
    Dim TypeSymbol As Long = Types(BaseType).TypeSymbol
    If TypeSymbol < 0 Or TypeSymbol >= SymbolCount Then
        ResolveDirectTypeMember = -1
        Exit Function
    End If
    Dim Ordinal As Long = 0
    Dim SymbolIndex As Long = TypeSymbol + 1
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).ParentSymbol <> TypeSymbol Then
            Exit While
        End If
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolMember() Then
            If Symbols(SymbolIndex).SymbolName = MemberName Or EqualsFolded(Symbols(SymbolIndex).SymbolName, MemberName) <> 0 Then
                MemberOrdinal = Ordinal
                ResolveDirectTypeMember = SymbolIndex
                Exit Function
            End If
            Ordinal = Ordinal + 1
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    ResolveDirectTypeMember = -1
End Function

Function ReadDirectMemberNames(ByVal FirstToken As Long, ByVal LastToken As Long, ByRef Tokens() As LexicalToken, ByRef BaseName As String, ByRef MemberName As String) As Long
    BaseName = ""
    MemberName = ""
    Dim DotToken As Long = -1
    Dim TokenIndex As Long = FirstToken
    While TokenIndex <= LastToken
        If Tokens(TokenIndex).Spelling = "." Then
            DotToken = TokenIndex
            Exit While
        End If
        If Tokens(TokenIndex).TokenKind = 2 Or Tokens(TokenIndex).TokenKind = 3 Then
            BaseName = Tokens(TokenIndex).Spelling
            If Tokens(TokenIndex).TokenKind = 3 Then
                BaseName = Tokens(TokenIndex).Decoded
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    If DotToken < 0 Or StringLength(BaseName) = 0 Then
        ReadDirectMemberNames = 0
        Exit Function
    End If
    TokenIndex = DotToken + 1
    While TokenIndex <= LastToken
        If Tokens(TokenIndex).TokenKind = 2 Or Tokens(TokenIndex).TokenKind = 3 Then
            MemberName = Tokens(TokenIndex).Spelling
            If Tokens(TokenIndex).TokenKind = 3 Then
                MemberName = Tokens(TokenIndex).Decoded
            End If
            Exit While
        End If
        TokenIndex = TokenIndex + 1
    Wend
    If StringLength(MemberName) = 0 Then
        ReadDirectMemberNames = 0
    Else
        ReadDirectMemberNames = 1
    End If
End Function

Function LowerDirectMemberAddress(ByVal FirstToken As Long, ByVal LastToken As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal OwnerSymbol As Long, ByVal LocationIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Build As IrBuildState, ByRef Tokens() As LexicalToken, ByRef MemberSymbol As Long) As Long
    Dim BaseName As String = ""
    Dim MemberName As String = ""
    If ReadDirectMemberNames(FirstToken, LastToken, Tokens, BaseName, MemberName) = 0 Then
        LowerDirectMemberAddress = -1
        Exit Function
    End If
    Dim BaseSymbol As Long = FindVisibleIrSymbolByName(BaseName, OwnerSymbol, FunctionIndex, Symbols, SymbolCount, Storages, Build.StorageCount)
    If BaseSymbol < 0 Then
        LowerDirectMemberAddress = -1
        Exit Function
    End If
    Dim BaseStorage As Long = FindIrStorageForSymbol(BaseSymbol, FunctionIndex, Storages, Build.StorageCount)
    Dim MemberOrdinal As Long = -1
    MemberSymbol = ResolveDirectTypeMember(Symbols(BaseSymbol).DeclaredType, MemberName, Types, TypeCount, Symbols, SymbolCount, MemberOrdinal)
    If BaseStorage < 0 Or MemberSymbol < 0 Or MemberOrdinal < 0 Then
        LowerDirectMemberAddress = -1
        Exit Function
    End If
    ' Address values carry the type of the storage they identify. LLVM still
    ' lowers them as opaque pointers, while the target-independent verifier
    ' can prove exact ByRef identity and load/store compatibility.
    Dim AddressType As Long = Symbols(MemberSymbol).DeclaredType
    If AddressType < 0 Then
        LowerDirectMemberAddress = -1
        Exit Function
    End If
    Dim AddressInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpFieldAddress(), AddressType, -1, MemberSymbol, 0, "", LocationIndex, Instructions, Values, Build)
    If AddressInstruction < 0 Then
        LowerDirectMemberAddress = -1
        Exit Function
    End If
    If AppendIrInstructionOperand(AddressInstruction, IrOperandStorage(), BaseStorage, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(AddressInstruction, IrOperandType(), Symbols(BaseSymbol).DeclaredType, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(AddressInstruction, IrOperandInteger(), MemberOrdinal, "", Instructions, Operands, Build) = 0 Then
        LowerDirectMemberAddress = -1
        Exit Function
    End If
    LowerDirectMemberAddress = Instructions(AddressInstruction).ResultValue
End Function

Function FindExpressionInsideTokenRange(ByVal FirstToken As Long, ByVal LastToken As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef SyntaxNodes() As SyntaxNode) As Long
    Dim BestExpression As Long = -1
    Dim ExpressionIndex As Long = 0
    While ExpressionIndex < ExpressionCount
        Dim ExpressionNode As Long = Expressions(ExpressionIndex).SyntaxNode
        If SyntaxNodes(ExpressionNode).FirstToken >= FirstToken And SyntaxNodes(ExpressionNode).LastToken <= LastToken Then
            If BestExpression < 0 Then
                BestExpression = ExpressionIndex
            Else
                Dim BestNode As Long = Expressions(BestExpression).SyntaxNode
                Dim CurrentWidth As Long = SyntaxNodes(ExpressionNode).LastToken - SyntaxNodes(ExpressionNode).FirstToken
                Dim BestWidth As Long = SyntaxNodes(BestNode).LastToken - SyntaxNodes(BestNode).FirstToken
                If CurrentWidth > BestWidth Then
                    BestExpression = ExpressionIndex
                End If
            End If
        End If
        ExpressionIndex = ExpressionIndex + 1
    Wend
    FindExpressionInsideTokenRange = BestExpression
End Function

Function FindCalledParameterSymbol(ByVal ProcedureSymbol As Long, ByVal Ordinal As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long) As Long
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).ParentSymbol = ProcedureSymbol And Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() Then
            If Symbols(SymbolIndex).ParameterOrdinal = Ordinal Then
                FindCalledParameterSymbol = SymbolIndex
                Exit Function
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    FindCalledParameterSymbol = -1
End Function

Function CountCalledParameters(ByVal ProcedureSymbol As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long) As Long
    Dim Count As Long = 0
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).ParentSymbol = ProcedureSymbol And Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() Then
            Count = Count + 1
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    CountCalledParameters = Count
End Function

Function LowerIndexedMemberAddress(ByVal FirstToken As Long, ByVal LastToken As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal OwnerSymbol As Long, ByVal LocationIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef MemberSymbol As Long) As Long
    Dim BaseName As String = ""
    Dim MemberName As String = ""
    Dim OpenToken As Long = -1
    Dim CloseToken As Long = -1
    Dim DotToken As Long = -1
    Dim ParenthesisDepth As Long = 0
    Dim TokenIndex As Long = FirstToken
    While TokenIndex <= LastToken
        If OpenToken < 0 Then
            If Tokens(TokenIndex).Spelling = "(" Then
                OpenToken = TokenIndex
                ParenthesisDepth = 1
            Else
                If Tokens(TokenIndex).TokenKind = 2 Or Tokens(TokenIndex).TokenKind = 3 Then
                    If StringLength(BaseName) = 0 Then
                        BaseName = Tokens(TokenIndex).Spelling
                        If Tokens(TokenIndex).TokenKind = 3 Then
                            BaseName = Tokens(TokenIndex).Decoded
                        End If
                    End If
                End If
            End If
        Else
            If CloseToken < 0 And Tokens(TokenIndex).Spelling = "(" Then
                ParenthesisDepth = ParenthesisDepth + 1
            Else
                If CloseToken < 0 And Tokens(TokenIndex).Spelling = ")" Then
                    ParenthesisDepth = ParenthesisDepth - 1
                    If ParenthesisDepth = 0 Then
                        CloseToken = TokenIndex
                    End If
                Else
                    If CloseToken >= 0 And Tokens(TokenIndex).Spelling = "." Then
                        DotToken = TokenIndex
                        Exit While
                    End If
                End If
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    If OpenToken < 0 Or CloseToken <= OpenToken Or DotToken <= CloseToken Or StringLength(BaseName) = 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    TokenIndex = DotToken + 1
    While TokenIndex <= LastToken
        If Tokens(TokenIndex).TokenKind = 2 Or Tokens(TokenIndex).TokenKind = 3 Then
            MemberName = Tokens(TokenIndex).Spelling
            If Tokens(TokenIndex).TokenKind = 3 Then
                MemberName = Tokens(TokenIndex).Decoded
            End If
            Exit While
        End If
        TokenIndex = TokenIndex + 1
    Wend
    If StringLength(MemberName) = 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    Dim BaseSymbol As Long = FindVisibleIrSymbolByName(BaseName, OwnerSymbol, FunctionIndex, Symbols, SymbolCount, Storages, Build.StorageCount)
    If BaseSymbol < 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    Dim ArrayType As Long = Symbols(BaseSymbol).DeclaredType
    If ArrayType < 0 Or ArrayType >= TypeCount Or Types(ArrayType).TypeKind <> 41 Or Types(ArrayType).ElementType < 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    Dim ElementType As Long = Types(ArrayType).ElementType
    Dim MemberOrdinal As Long = -1
    MemberSymbol = ResolveDirectTypeMember(ElementType, MemberName, Types, TypeCount, Symbols, SymbolCount, MemberOrdinal)
    If MemberSymbol < 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    Dim IndexExpression As Long = FindExpressionInsideTokenRange(OpenToken + 1, CloseToken - 1, Expressions, ExpressionCount, SyntaxNodes)
    If IndexExpression < 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    Dim IndexValue As Long = LowerSemanticExpressionValue(IndexExpression, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    If IndexValue < 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    Dim LongType As Long = FindSemanticType("Long", Types, TypeCount)
    If Values(IndexValue).TypeIndex <> LongType Then
        Dim IndexConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), LongType, FailureBlock, BaseSymbol, 0, "", LocationIndex, Instructions, Values, Build)
        If IndexConvert < 0 Or AppendIrInstructionOperand(IndexConvert, IrOperandValue(), IndexValue, "", Instructions, Operands, Build) = 0 Then
            LowerIndexedMemberAddress = -1
            Exit Function
        End If
        IndexValue = Instructions(IndexConvert).ResultValue
    End If
    Dim BaseStorage As Long = FindIrStorageForSymbol(BaseSymbol, FunctionIndex, Storages, Build.StorageCount)
    Dim AddressType As Long = ElementType
    Dim ArrayAddressInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpArrayAddress(), AddressType, FailureBlock, BaseSymbol, 0, "", LocationIndex, Instructions, Values, Build)
    If ArrayAddressInstruction < 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    If AppendIrInstructionOperand(ArrayAddressInstruction, IrOperandStorage(), BaseStorage, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(ArrayAddressInstruction, IrOperandValue(), IndexValue, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(ArrayAddressInstruction, IrOperandType(), ElementType, "", Instructions, Operands, Build) = 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    Dim ArrayAddressValue As Long = Instructions(ArrayAddressInstruction).ResultValue
    Dim FieldInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpFieldAddress(), Symbols(MemberSymbol).DeclaredType, -1, MemberSymbol, 0, "", LocationIndex, Instructions, Values, Build)
    If FieldInstruction < 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    If AppendIrInstructionOperand(FieldInstruction, IrOperandValue(), ArrayAddressValue, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(FieldInstruction, IrOperandType(), ElementType, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(FieldInstruction, IrOperandInteger(), MemberOrdinal, "", Instructions, Operands, Build) = 0 Then
        LowerIndexedMemberAddress = -1
        Exit Function
    End If
    LowerIndexedMemberAddress = Instructions(FieldInstruction).ResultValue
End Function

Function LowerIndexedElementAddress(ByVal FirstToken As Long, ByVal LastToken As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal OwnerSymbol As Long, ByVal LocationIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken, ByRef BaseSymbol As Long, ByRef ElementType As Long) As Long
    Dim BaseName As String = ""
    Dim OpenToken As Long = -1
    Dim CloseToken As Long = -1
    Dim ParenthesisDepth As Long = 0
    Dim TokenIndex As Long = FirstToken
    While TokenIndex <= LastToken
        If OpenToken < 0 Then
            If Tokens(TokenIndex).Spelling = "(" Then
                OpenToken = TokenIndex
                ParenthesisDepth = 1
            Else
                If Tokens(TokenIndex).TokenKind = 2 Or Tokens(TokenIndex).TokenKind = 3 Then
                    If StringLength(BaseName) = 0 Then
                        BaseName = Tokens(TokenIndex).Spelling
                        If Tokens(TokenIndex).TokenKind = 3 Then
                            BaseName = Tokens(TokenIndex).Decoded
                        End If
                    End If
                End If
            End If
        Else
            If Tokens(TokenIndex).Spelling = "(" Then
                ParenthesisDepth = ParenthesisDepth + 1
            Else
                If Tokens(TokenIndex).Spelling = ")" Then
                    ParenthesisDepth = ParenthesisDepth - 1
                    If ParenthesisDepth = 0 Then
                        CloseToken = TokenIndex
                        Exit While
                    End If
                End If
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    Dim HasTrailingSyntax As Long = 0
    If CloseToken >= 0 Then
        TokenIndex = CloseToken + 1
        While TokenIndex <= LastToken
            If Tokens(TokenIndex).TokenKind <> 11 Then
                HasTrailingSyntax = 1
            End If
            TokenIndex = TokenIndex + 1
        Wend
    End If
    If OpenToken < 0 Or CloseToken <= OpenToken Or HasTrailingSyntax <> 0 Or StringLength(BaseName) = 0 Then
        LowerIndexedElementAddress = -1
        Exit Function
    End If
    BaseSymbol = FindVisibleIrSymbolByName(BaseName, OwnerSymbol, FunctionIndex, Symbols, SymbolCount, Storages, Build.StorageCount)
    If BaseSymbol < 0 Then
        LowerIndexedElementAddress = -1
        Exit Function
    End If
    Dim ArrayType As Long = Symbols(BaseSymbol).DeclaredType
    If ArrayType < 0 Or ArrayType >= TypeCount Then
        LowerIndexedElementAddress = -1
        Exit Function
    End If
    If Types(ArrayType).TypeKind <> 41 Or Types(ArrayType).ElementType < 0 Then
        LowerIndexedElementAddress = -1
        Exit Function
    End If
    ElementType = Types(ArrayType).ElementType
    Dim IndexExpression As Long = FindExpressionInsideTokenRange(OpenToken + 1, CloseToken - 1, Expressions, ExpressionCount, SyntaxNodes)
    If IndexExpression < 0 Then
        LowerIndexedElementAddress = -1
        Exit Function
    End If
    Dim IndexValue As Long = LowerSemanticExpressionValue(IndexExpression, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    If IndexValue < 0 Then
        LowerIndexedElementAddress = -1
        Exit Function
    End If
    Dim LongType As Long = FindSemanticType("Long", Types, TypeCount)
    If Values(IndexValue).TypeIndex <> LongType Then
        Dim IndexConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), LongType, FailureBlock, BaseSymbol, 0, "", LocationIndex, Instructions, Values, Build)
        If IndexConvert < 0 Or AppendIrInstructionOperand(IndexConvert, IrOperandValue(), IndexValue, "", Instructions, Operands, Build) = 0 Then
            LowerIndexedElementAddress = -1
            Exit Function
        End If
        IndexValue = Instructions(IndexConvert).ResultValue
    End If
    Dim BaseStorage As Long = FindIrStorageForSymbol(BaseSymbol, FunctionIndex, Storages, Build.StorageCount)
    If BaseStorage < 0 Then
        LowerIndexedElementAddress = -1
        Exit Function
    End If
    Dim AddressType As Long = ElementType
    Dim AddressInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpArrayAddress(), AddressType, FailureBlock, BaseSymbol, 0, "", LocationIndex, Instructions, Values, Build)
    If AddressInstruction < 0 Then
        LowerIndexedElementAddress = -1
        Exit Function
    End If
    If AppendIrInstructionOperand(AddressInstruction, IrOperandStorage(), BaseStorage, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(AddressInstruction, IrOperandValue(), IndexValue, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(AddressInstruction, IrOperandType(), ElementType, "", Instructions, Operands, Build) = 0 Then
        LowerIndexedElementAddress = -1
        Exit Function
    End If
    LowerIndexedElementAddress = Instructions(AddressInstruction).ResultValue
End Function

Function FindSemanticExpressionForNode(ByVal NodeIndex As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef SyntaxNodes() As SyntaxNode) As Long
    Dim ExpressionIndex As Long = 0
    While ExpressionIndex < ExpressionCount
        Dim CurrentNode As Long = Expressions(ExpressionIndex).SyntaxNode
        While CurrentNode >= 0
            If CurrentNode = NodeIndex Then
                FindSemanticExpressionForNode = ExpressionIndex
                Exit Function
            End If
            CurrentNode = SyntaxNodes(CurrentNode).ParentNode
        Wend
        ExpressionIndex = ExpressionIndex + 1
    Wend
    FindSemanticExpressionForNode = -1
End Function

Function FindAssignmentExpression(ByVal AssignmentNode As Long, ByVal WantRightHandSide As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim EqualsToken As Long = SyntaxNodes(AssignmentNode).FirstToken
    While EqualsToken <= SyntaxNodes(AssignmentNode).LastToken
        If Tokens(EqualsToken).Spelling = "=" Then
            Exit While
        End If
        EqualsToken = EqualsToken + 1
    Wend
    Dim BestExpression As Long = -1
    Dim ExpressionIndex As Long = 0
    While ExpressionIndex < ExpressionCount
        Dim ExpressionNode As Long = Expressions(ExpressionIndex).SyntaxNode
        Dim CurrentNode As Long = ExpressionNode
        Dim IsDescendant As Long = 0
        While CurrentNode >= 0
            If CurrentNode = AssignmentNode Then
                IsDescendant = 1
                Exit While
            End If
            CurrentNode = SyntaxNodes(CurrentNode).ParentNode
        Wend
        If IsDescendant <> 0 Then
            Dim OnRight As Long = 0
            If SyntaxNodes(ExpressionNode).FirstToken > EqualsToken Then
                OnRight = 1
            End If
            If OnRight = WantRightHandSide Then
                If BestExpression < 0 Then
                    BestExpression = ExpressionIndex
                Else
                    If WantRightHandSide <> 0 Then
                        If SyntaxNodes(ExpressionNode).FirstToken < SyntaxNodes(Expressions(BestExpression).SyntaxNode).FirstToken Then
                            BestExpression = ExpressionIndex
                        Else
                            If SyntaxNodes(ExpressionNode).FirstToken = SyntaxNodes(Expressions(BestExpression).SyntaxNode).FirstToken And SyntaxNodes(ExpressionNode).LastToken > SyntaxNodes(Expressions(BestExpression).SyntaxNode).LastToken Then
                                BestExpression = ExpressionIndex
                            End If
                        End If
                    Else
                        If SyntaxNodes(ExpressionNode).FirstToken <= SyntaxNodes(Expressions(BestExpression).SyntaxNode).FirstToken And SyntaxNodes(ExpressionNode).LastToken >= SyntaxNodes(Expressions(BestExpression).SyntaxNode).LastToken Then
                            BestExpression = ExpressionIndex
                        End If
                    End If
                End If
            End If
        End If
        ExpressionIndex = ExpressionIndex + 1
    Wend
    FindAssignmentExpression = BestExpression
End Function

Function SyntaxNodeIsInsideStructuredControl(ByVal NodeIndex As Long, ByVal ProcedureNode As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Rules() As GrammarRule) As Long
    Dim CurrentNode As Long = SyntaxNodes(NodeIndex).ParentNode
    While CurrentNode >= 0 And CurrentNode <> ProcedureNode
        If SyntaxRuleIs(CurrentNode, "if-statement", SyntaxNodes, Rules) <> 0 Or SyntaxRuleIs(CurrentNode, "select-statement", SyntaxNodes, Rules) <> 0 Or SyntaxRuleIs(CurrentNode, "for-statement", SyntaxNodes, Rules) <> 0 Or SyntaxRuleIs(CurrentNode, "do-statement", SyntaxNodes, Rules) <> 0 Or SyntaxRuleIs(CurrentNode, "while-statement", SyntaxNodes, Rules) <> 0 Or SyntaxRuleIs(CurrentNode, "with-statement", SyntaxNodes, Rules) <> 0 Or SyntaxRuleIs(CurrentNode, "sync-lock-statement", SyntaxNodes, Rules) <> 0 Then
            SyntaxNodeIsInsideStructuredControl = 1
            Exit Function
        End If
        CurrentNode = SyntaxNodes(CurrentNode).ParentNode
    Wend
    SyntaxNodeIsInsideStructuredControl = 0
End Function

Function ResolveAssignmentTargetSymbol(ByVal AssignmentNode As Long, ByVal OwnerSymbol As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim TokenIndex As Long = SyntaxNodes(AssignmentNode).FirstToken
    Dim TargetName As String = ""
    While TokenIndex <= SyntaxNodes(AssignmentNode).LastToken
        If Tokens(TokenIndex).Spelling = "=" Then
            Exit While
        End If
        If Tokens(TokenIndex).TokenKind = 2 Or Tokens(TokenIndex).TokenKind = 3 Then
            TargetName = Tokens(TokenIndex).Spelling
            If Tokens(TokenIndex).TokenKind = 3 Then
                TargetName = Tokens(TokenIndex).Decoded
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    If StringLength(TargetName) = 0 Then
        ResolveAssignmentTargetSymbol = -1
        Exit Function
    End If
    If Symbols(OwnerSymbol).SymbolName = TargetName Or EqualsFolded(Symbols(OwnerSymbol).SymbolName, TargetName) <> 0 Then
        ResolveAssignmentTargetSymbol = OwnerSymbol
        Exit Function
    End If
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).ParentSymbol = OwnerSymbol Then
            If Symbols(SymbolIndex).SymbolName = TargetName Or EqualsFolded(Symbols(SymbolIndex).SymbolName, TargetName) <> 0 Then
                If Symbols(SymbolIndex).SymbolKind = SemanticSymbolVariable() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() Then
                    ResolveAssignmentTargetSymbol = SymbolIndex
                    Exit Function
                End If
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    Dim MatchIndex As Long = -1
    Dim MatchCount As Long = 0
    SymbolIndex = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolName = TargetName Or EqualsFolded(Symbols(SymbolIndex).SymbolName, TargetName) <> 0 Then
            If Symbols(SymbolIndex).SymbolKind = SemanticSymbolVariable() Then
                MatchIndex = SymbolIndex
                MatchCount = MatchCount + 1
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    If MatchCount = 1 Then
        ResolveAssignmentTargetSymbol = MatchIndex
    Else
        ResolveAssignmentTargetSymbol = -1
    End If
End Function

Function AppendIrInstructionOperand(ByVal InstructionIndex As Long, ByVal OperandKind As Long, ByVal ReferencedIndex As Long, ByVal ImmediateText As String, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Build As IrBuildState) As Long
    Dim Ordinal As Long = Instructions(InstructionIndex).OperandCount
    Dim OperandIndex As Long = AppendIrOperand(Operands, Build.OperandCount, Build.OperandCapacity, InstructionIndex, Ordinal, OperandKind, ReferencedIndex, ImmediateText)
    If OperandIndex < 0 Then
        AppendIrInstructionOperand = 0
        Exit Function
    End If
    If Instructions(InstructionIndex).FirstOperand < 0 Then
        Instructions(InstructionIndex).FirstOperand = OperandIndex
    End If
    Instructions(InstructionIndex).OperandCount = Instructions(InstructionIndex).OperandCount + 1
    AppendIrInstructionOperand = 1
End Function

Function AppendTypedIrValueInstruction(ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal Opcode As Long, ByVal TypeIndex As Long, ByVal FailureTarget As Long, ByVal SymbolIndex As Long, ByVal Flags As Long, ByVal ImmediateText As String, ByVal LocationIndex As Long, ByRef Instructions() As IrInstruction, ByRef Values() As IrValue, ByRef Build As IrBuildState) As Long
    ' Only failures represented as recoverable RP5 IR control flow retain a
    ' failure target. Allocation, array, string, and callee failures still use
    ' the bootstrap support ABI's controlled terminal-failure contract; giving
    ' those operations an edge would falsely claim the backend can resume.
    If Opcode <> IrOpCheckedAdd() And Opcode <> IrOpCheckedSubtract() And Opcode <> IrOpCheckedMultiply() And Opcode <> IrOpCheckedNegate() And Opcode <> IrOpCheckedDivide() And Opcode <> IrOpCheckedRemainder() And Opcode <> IrOpConvert() Then
        FailureTarget = -1
    End If
    Dim InstructionIndex As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, Opcode, -1, TypeIndex, -1, -1, FailureTarget, 0, SymbolIndex, Flags, ImmediateText, LocationIndex)
    If InstructionIndex < 0 Then
        AppendTypedIrValueInstruction = -1
        Exit Function
    End If
    Dim ValueIndex As Long = AppendIrValue(Values, Build.ValueCount, Build.ValueCapacity, FunctionIndex, TypeIndex, InstructionIndex, IrValueInstruction(), Flags, LocationIndex)
    If ValueIndex < 0 Then
        AppendTypedIrValueInstruction = -1
        Exit Function
    End If
    Instructions(InstructionIndex).ResultValue = ValueIndex
    AppendTypedIrValueInstruction = InstructionIndex
End Function

Function LowerSimpleTokenValue(ByVal FirstToken As Long, ByVal LastToken As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal OwnerSymbol As Long, ByVal LocationIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Build As IrBuildState, ByRef Tokens() As LexicalToken) As Long
    While FirstToken < LastToken And Tokens(FirstToken).TokenKind >= 9 And Tokens(FirstToken).TokenKind <= 12
        FirstToken = FirstToken + 1
    Wend
    While LastToken > FirstToken And Tokens(LastToken).TokenKind >= 9 And Tokens(LastToken).TokenKind <= 12
        LastToken = LastToken - 1
    Wend
    While FirstToken < LastToken And Tokens(FirstToken).Spelling = "(" And Tokens(LastToken).Spelling = ")"
        FirstToken = FirstToken + 1
        LastToken = LastToken - 1
    Wend
    If FirstToken <> LastToken Then
        Build.FailureDetail = "simple range " & Tokens(FirstToken).Spelling & ".." & Tokens(LastToken).Spelling
        LowerSimpleTokenValue = -1
        Exit Function
    End If
    Dim TokenKind As Long = Tokens(FirstToken).TokenKind
    Dim TypeIndex As Long = -1
    Dim Opcode As Long = IrOpConstant()
    Dim SymbolIndex As Long = -1
    Dim StorageIndex As Long = -1
    Dim TextValue As String = Tokens(FirstToken).Decoded
    If TokenKind <> 6 And StringLength(TextValue) = 0 Then
        TextValue = Tokens(FirstToken).Spelling
    End If
    If TokenKind = 4 Then
        TypeIndex = FindSemanticType("Long", Types, TypeCount)
    Else
        If TokenKind = 6 Then
            TypeIndex = FindSemanticType("String", Types, TypeCount)
        Else
            SymbolIndex = FindVisibleIrSymbolByName(Tokens(FirstToken).Spelling, OwnerSymbol, FunctionIndex, Symbols, SymbolCount, Storages, Build.StorageCount)
            If SymbolIndex >= 0 Then
                TypeIndex = Symbols(SymbolIndex).DeclaredType
                StorageIndex = FindIrStorageForSymbol(SymbolIndex, FunctionIndex, Storages, Build.StorageCount)
                If StorageIndex >= 0 Then
                    Opcode = IrOpLoad()
                Else
                    TextValue = Symbols(SymbolIndex).ConstantText
                End If
            End If
        End If
    End If
    If TypeIndex < 0 Then
        Build.FailureDetail = "simple unresolved " & Tokens(FirstToken).Spelling & " symbol " & LongToString(SymbolIndex)
        LowerSimpleTokenValue = -1
        Exit Function
    End If
    Dim InstructionIndex As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, Opcode, TypeIndex, -1, SymbolIndex, 0, TextValue, LocationIndex, Instructions, Values, Build)
    If InstructionIndex < 0 Then
        LowerSimpleTokenValue = -1
        Exit Function
    End If
    If Opcode = IrOpLoad() Then
        If AppendIrInstructionOperand(InstructionIndex, IrOperandStorage(), StorageIndex, "", Instructions, Operands, Build) = 0 Then
            LowerSimpleTokenValue = -1
            Exit Function
        End If
    End If
    LowerSimpleTokenValue = Instructions(InstructionIndex).ResultValue
End Function

Function IrIntegerTypeRank(ByVal TypeIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long) As Long
    If TypeIndex < 0 Or TypeIndex >= TypeCount Then
        IrIntegerTypeRank = 0
        Exit Function
    End If
    Dim TypeName As String = Types(TypeIndex).TypeName
    If EqualsFolded(TypeName, "Boolean") <> 0 Then
        IrIntegerTypeRank = 1
        Exit Function
    End If
    If EqualsFolded(TypeName, "Byte") <> 0 Then
        IrIntegerTypeRank = 2
        Exit Function
    End If
    If EqualsFolded(TypeName, "Integer") <> 0 Then
        IrIntegerTypeRank = 3
        Exit Function
    End If
    If EqualsFolded(TypeName, "Long") <> 0 Then
        IrIntegerTypeRank = 4
        Exit Function
    End If
    If EqualsFolded(TypeName, "LongLong") <> 0 Or EqualsFolded(TypeName, "Currency") <> 0 Or EqualsFolded(TypeName, "IntPtr") <> 0 Or EqualsFolded(TypeName, "UIntPtr") <> 0 Then
        IrIntegerTypeRank = 5
        Exit Function
    End If
    IrIntegerTypeRank = 0
End Function

Function PromoteIrIntegerValues(ByRef LeftValue As Long, ByRef RightValue As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal LocationIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Build As IrBuildState) As Long
    Dim LeftType As Long = Values(LeftValue).TypeIndex
    Dim RightType As Long = Values(RightValue).TypeIndex
    If LeftType = RightType Then
        PromoteIrIntegerValues = LeftType
        Exit Function
    End If
    Dim LeftRank As Long = IrIntegerTypeRank(LeftType, Types, TypeCount)
    Dim RightRank As Long = IrIntegerTypeRank(RightType, Types, TypeCount)
    If LeftRank = 0 Or RightRank = 0 Then
        PromoteIrIntegerValues = -1
        Exit Function
    End If
    Dim CommonType As Long = LeftType
    If RightRank > LeftRank Then
        CommonType = RightType
    End If
    If LeftType <> CommonType Then
        Dim LeftConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), CommonType, FailureBlock, -1, 0, "", LocationIndex, Instructions, Values, Build)
        If LeftConvert < 0 Or AppendIrInstructionOperand(LeftConvert, IrOperandValue(), LeftValue, "", Instructions, Operands, Build) = 0 Then
            PromoteIrIntegerValues = -2
            Exit Function
        End If
        LeftValue = Instructions(LeftConvert).ResultValue
    End If
    If RightType <> CommonType Then
        Dim RightConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), CommonType, FailureBlock, -1, 0, "", LocationIndex, Instructions, Values, Build)
        If RightConvert < 0 Or AppendIrInstructionOperand(RightConvert, IrOperandValue(), RightValue, "", Instructions, Operands, Build) = 0 Then
            PromoteIrIntegerValues = -2
            Exit Function
        End If
        RightValue = Instructions(RightConvert).ResultValue
    End If
    PromoteIrIntegerValues = CommonType
End Function

Function LowerTokenRangeValue(ByVal FirstToken As Long, ByVal LastToken As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal OwnerSymbol As Long, ByVal LocationIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    While FirstToken < LastToken And Tokens(FirstToken).TokenKind >= 9 And Tokens(FirstToken).TokenKind <= 12
        FirstToken = FirstToken + 1
    Wend
    While LastToken > FirstToken And Tokens(LastToken).TokenKind >= 9 And Tokens(LastToken).TokenKind <= 12
        LastToken = LastToken - 1
    Wend
    If Tokens(FirstToken).Spelling = "(" And Tokens(LastToken).Spelling = ")" Then
        Dim OuterDepth As Long = 0
        Dim OuterScan As Long = FirstToken
        Dim OuterClosesAtEnd As Long = 0
        While OuterScan <= LastToken
            If Tokens(OuterScan).Spelling = "(" Then
                OuterDepth = OuterDepth + 1
            Else
                If Tokens(OuterScan).Spelling = ")" Then
                    OuterDepth = OuterDepth - 1
                    If OuterDepth = 0 Then
                        If OuterScan = LastToken Then
                            OuterClosesAtEnd = 1
                        End If
                        Exit While
                    End If
                End If
            End If
            OuterScan = OuterScan + 1
        Wend
        If OuterClosesAtEnd <> 0 Then
            LowerTokenRangeValue = LowerTokenRangeValue(FirstToken + 1, LastToken - 1, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
            Exit Function
        End If
    End If
    Dim OperatorToken As Long = -1
    Dim OperatorPriority As Long = 100
    Dim Depth As Long = 0
    Dim ScanToken As Long = FirstToken
    While ScanToken <= LastToken
        If Tokens(ScanToken).Spelling = "(" Then
            Depth = Depth + 1
        Else
            If Tokens(ScanToken).Spelling = ")" Then
                Depth = Depth - 1
            Else
                If Depth = 0 Then
                    Dim Priority As Long = IrBinaryOperatorPriority(Tokens(ScanToken).Spelling)
                    If IsIrUnarySign(ScanToken, FirstToken, Tokens) <> 0 Then
                        Priority = 0
                    End If
                    If Priority > 0 And Priority <= OperatorPriority And ScanToken > FirstToken And ScanToken < LastToken Then
                        OperatorToken = ScanToken
                        OperatorPriority = Priority
                    End If
                End If
            End If
        End If
        ScanToken = ScanToken + 1
    Wend
    If OperatorToken < 0 Then
        If Tokens(FirstToken).Spelling = "-" Or EqualsFolded(Tokens(FirstToken).Spelling, "Not") <> 0 Then
            Dim UnaryValue As Long = LowerTokenRangeValue(FirstToken + 1, LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
            If UnaryValue < 0 Then
                LowerTokenRangeValue = UnaryValue
                Exit Function
            End If
            Dim UnaryOpcode As Long = IrOpCheckedNegate()
            Dim UnaryType As Long = Values(UnaryValue).TypeIndex
            Dim UnaryFailure As Long = FailureBlock
            Dim UnaryText As String = "-2147483648"
            If EqualsFolded(Tokens(FirstToken).Spelling, "Not") <> 0 Then
                UnaryOpcode = IrOpBoolean()
                UnaryFailure = -1
                UnaryText = "Not"
            End If
            Dim UnaryInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, UnaryOpcode, UnaryType, UnaryFailure, -1, 0, UnaryText, LocationIndex, Instructions, Values, Build)
            If UnaryInstruction < 0 Or AppendIrInstructionOperand(UnaryInstruction, IrOperandValue(), UnaryValue, "", Instructions, Operands, Build) = 0 Then
                LowerTokenRangeValue = -22
                Exit Function
            End If
            LowerTokenRangeValue = Instructions(UnaryInstruction).ResultValue
            Exit Function
        End If
        Dim DirectOpenToken As Long = FirstToken + 1
        While DirectOpenToken < LastToken And Tokens(DirectOpenToken).TokenKind >= 9 And Tokens(DirectOpenToken).TokenKind <= 12
            DirectOpenToken = DirectOpenToken + 1
        Wend
        If DirectOpenToken < LastToken And Tokens(DirectOpenToken).Spelling = "(" And Tokens(LastToken).Spelling = ")" Then
            Dim DirectProcedureSymbol As Long = 0
            Dim DirectCalledFunction As Long = -1
            While DirectProcedureSymbol < SymbolCount
                If EqualsFolded(Symbols(DirectProcedureSymbol).SymbolName, Tokens(FirstToken).Spelling) <> 0 Then
                    If Symbols(DirectProcedureSymbol).SymbolKind = SemanticSymbolProcedure() Or Symbols(DirectProcedureSymbol).SymbolKind = SemanticSymbolProperty() Then
                        DirectCalledFunction = SemanticFunctionIndex(DirectProcedureSymbol, Functions, FunctionCount)
                        If DirectCalledFunction >= 0 Then
                            Exit While
                        End If
                    End If
                End If
                DirectProcedureSymbol = DirectProcedureSymbol + 1
            Wend
            If DirectCalledFunction >= 0 Then
                Dim DirectArgumentKinds() As Long
                Dim DirectArgumentValues() As Long
                Dim DirectExpected As Long = CountCalledParameters(DirectProcedureSymbol, Symbols, SymbolCount)
                If DirectExpected > 0 Then
                    ReDim DirectArgumentKinds(DirectExpected - 1)
                    ReDim DirectArgumentValues(DirectExpected - 1)
                End If
                Dim DirectArgumentCount As Long = 0
                Dim DirectArgumentFirst As Long = DirectOpenToken + 1
                Dim DirectScan As Long = DirectArgumentFirst
                Dim DirectDepth As Long = 0
                While DirectScan <= LastToken
                    Dim DirectEndsArgument As Long = 0
                    If DirectScan = LastToken Then
                        If DirectArgumentFirst < LastToken Then
                            DirectEndsArgument = 1
                        End If
                    Else
                        If Tokens(DirectScan).Spelling = "(" Then
                            DirectDepth = DirectDepth + 1
                        Else
                            If Tokens(DirectScan).Spelling = ")" Then
                                DirectDepth = DirectDepth - 1
                            Else
                                If Tokens(DirectScan).Spelling = "," And DirectDepth = 0 Then
                                    DirectEndsArgument = 1
                                End If
                            End If
                        End If
                    End If
                    If DirectEndsArgument <> 0 Then
                        If DirectArgumentCount >= DirectExpected Then
                            LowerTokenRangeValue = -23
                            Exit Function
                        End If
                        Dim DirectParameter As Long = FindCalledParameterSymbol(DirectProcedureSymbol, DirectArgumentCount, Symbols, SymbolCount)
                        Dim DirectArgumentLast As Long = DirectScan - 1
                        Dim DirectTrimFirst As Long = DirectArgumentFirst
                        Dim DirectTrimLast As Long = DirectArgumentLast
                        While DirectTrimFirst < DirectTrimLast And Tokens(DirectTrimFirst).TokenKind >= 9 And Tokens(DirectTrimFirst).TokenKind <= 12
                            DirectTrimFirst = DirectTrimFirst + 1
                        Wend
                        While DirectTrimLast > DirectTrimFirst And Tokens(DirectTrimLast).TokenKind >= 9 And Tokens(DirectTrimLast).TokenKind <= 12
                            DirectTrimLast = DirectTrimLast - 1
                        Wend
                        Dim DirectArgumentKind As Long = IrOperandValue()
                        Dim DirectArgumentValue As Long = -1
                        If DirectParameter >= 0 Then
                            If Symbols(DirectParameter).Flags And 2 Then
                                DirectArgumentValue = LowerTokenRangeValue(DirectTrimFirst, DirectTrimLast, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
                            Else
                                Dim DirectMemberSymbol As Long = -1
                                DirectArgumentValue = LowerIndexedMemberAddress(DirectTrimFirst, DirectTrimLast, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, DirectMemberSymbol)
                                If DirectArgumentValue < 0 Then
                                    Dim DirectElementSymbol As Long = -1
                                    Dim DirectElementType As Long = -1
                                    DirectArgumentValue = LowerIndexedElementAddress(DirectTrimFirst, DirectTrimLast, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, DirectElementSymbol, DirectElementType)
                                End If
                                If DirectArgumentValue < 0 Then
                                    DirectArgumentValue = LowerDirectMemberAddress(DirectTrimFirst, DirectTrimLast, FunctionIndex, BlockIndex, OwnerSymbol, LocationIndex, Types, TypeCount, Symbols, SymbolCount, Storages, Instructions, Operands, Values, Build, Tokens, DirectMemberSymbol)
                                End If
                                If DirectArgumentValue < 0 Then
                                    Dim DirectArgumentName As String = Tokens(DirectTrimFirst).Spelling
                                    Dim DirectArgumentSymbol As Long = FindVisibleIrSymbolByName(DirectArgumentName, OwnerSymbol, FunctionIndex, Symbols, SymbolCount, Storages, Build.StorageCount)
                                    DirectArgumentValue = FindIrStorageForSymbol(DirectArgumentSymbol, FunctionIndex, Storages, Build.StorageCount)
                                    DirectArgumentKind = IrOperandStorage()
                                End If
                            End If
                        End If
                        If DirectParameter < 0 Or DirectArgumentValue < 0 Then
                            LowerTokenRangeValue = -23
                            Exit Function
                        End If
                        If Symbols(DirectParameter).Flags And 2 Then
                            If DirectArgumentKind = IrOperandValue() Then
                                If Values(DirectArgumentValue).TypeIndex <> Symbols(DirectParameter).DeclaredType Then
                                    Dim DirectConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), Symbols(DirectParameter).DeclaredType, FailureBlock, DirectParameter, 0, "", LocationIndex, Instructions, Values, Build)
                                    If DirectConvert < 0 Or AppendIrInstructionOperand(DirectConvert, IrOperandValue(), DirectArgumentValue, "", Instructions, Operands, Build) = 0 Then
                                        LowerTokenRangeValue = -23
                                        Exit Function
                                    End If
                                    DirectArgumentValue = Instructions(DirectConvert).ResultValue
                                End If
                            End If
                        End If
                        DirectArgumentKinds(DirectArgumentCount) = DirectArgumentKind
                        DirectArgumentValues(DirectArgumentCount) = DirectArgumentValue
                        DirectArgumentCount = DirectArgumentCount + 1
                        DirectArgumentFirst = DirectScan + 1
                    End If
                    DirectScan = DirectScan + 1
                Wend
                If DirectArgumentCount = DirectExpected Then
                    Dim DirectCallInstruction As Long = -1
                    If Symbols(DirectProcedureSymbol).DeclaredType >= 0 Then
                        DirectCallInstruction = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpCall(), Symbols(DirectProcedureSymbol).DeclaredType, FailureBlock, DirectProcedureSymbol, 0, "", LocationIndex, Instructions, Values, Build)
                    Else
                        DirectCallInstruction = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, IrOpCall(), -1, -1, -1, -1, -1, 0, DirectProcedureSymbol, 0, "", LocationIndex)
                    End If
                    If DirectCallInstruction >= 0 Then
                        If AppendIrInstructionOperand(DirectCallInstruction, IrOperandFunction(), DirectCalledFunction, "", Instructions, Operands, Build) <> 0 Then
                            Dim DirectAppend As Long = 0
                            While DirectAppend < DirectArgumentCount
                                If AppendIrInstructionOperand(DirectCallInstruction, DirectArgumentKinds(DirectAppend), DirectArgumentValues(DirectAppend), "", Instructions, Operands, Build) = 0 Then
                                    LowerTokenRangeValue = -23
                                    Exit Function
                                End If
                                DirectAppend = DirectAppend + 1
                            Wend
                            If Symbols(DirectProcedureSymbol).DeclaredType >= 0 Then
                                LowerTokenRangeValue = Instructions(DirectCallInstruction).ResultValue
                            Else
                                Dim IgnoredCallValue As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpDefaultValue(), FindSemanticType("Long", Types, TypeCount), -1, -1, 0, "", LocationIndex, Instructions, Values, Build)
                                If IgnoredCallValue < 0 Then
                                    LowerTokenRangeValue = -23
                                    Exit Function
                                End If
                                LowerTokenRangeValue = Instructions(IgnoredCallValue).ResultValue
                            End If
                            Exit Function
                        End If
                    End If
                End If
            End If
        End If
        Dim RangeMemberSymbol As Long = -1
        Dim RangeMemberAddress As Long = LowerIndexedMemberAddress(FirstToken, LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, RangeMemberSymbol)
        If RangeMemberAddress < 0 Then
            RangeMemberAddress = LowerDirectMemberAddress(FirstToken, LastToken, FunctionIndex, BlockIndex, OwnerSymbol, LocationIndex, Types, TypeCount, Symbols, SymbolCount, Storages, Instructions, Operands, Values, Build, Tokens, RangeMemberSymbol)
        End If
        If RangeMemberAddress >= 0 Then
            Dim RangeMemberLoad As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpLoad(), Symbols(RangeMemberSymbol).DeclaredType, -1, RangeMemberSymbol, 0, "", LocationIndex, Instructions, Values, Build)
            If RangeMemberLoad >= 0 Then
                If AppendIrInstructionOperand(RangeMemberLoad, IrOperandValue(), RangeMemberAddress, "", Instructions, Operands, Build) <> 0 Then
                    LowerTokenRangeValue = Instructions(RangeMemberLoad).ResultValue
                    Exit Function
                End If
            End If
            LowerTokenRangeValue = -20
            Exit Function
        End If
        Dim RangeElementSymbol As Long = -1
        Dim RangeElementType As Long = -1
        Dim RangeElementAddress As Long = LowerIndexedElementAddress(FirstToken, LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, RangeElementSymbol, RangeElementType)
        If RangeElementAddress >= 0 Then
            Dim RangeElementLoad As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpLoad(), RangeElementType, -1, RangeElementSymbol, 0, "", LocationIndex, Instructions, Values, Build)
            If RangeElementLoad >= 0 Then
                If AppendIrInstructionOperand(RangeElementLoad, IrOperandValue(), RangeElementAddress, "", Instructions, Operands, Build) <> 0 Then
                    LowerTokenRangeValue = Instructions(RangeElementLoad).ResultValue
                    Exit Function
                End If
            End If
            LowerTokenRangeValue = -20
            Exit Function
        End If
        Dim SimpleValue As Long = LowerSimpleTokenValue(FirstToken, LastToken, FunctionIndex, BlockIndex, OwnerSymbol, LocationIndex, Types, TypeCount, Symbols, SymbolCount, Storages, Instructions, Operands, Values, Build, Tokens)
        If SimpleValue >= 0 Then
            LowerTokenRangeValue = SimpleValue
            Exit Function
        End If
        If Tokens(LastToken).Spelling = ")" Then
            Dim OpenCallToken As Long = FirstToken + 1
            While OpenCallToken < LastToken And Tokens(OpenCallToken).TokenKind >= 9 And Tokens(OpenCallToken).TokenKind <= 12
                OpenCallToken = OpenCallToken + 1
            Wend
            If Tokens(OpenCallToken).Spelling = "(" Then
                Dim AfterOpenToken As Long = OpenCallToken + 1
                While AfterOpenToken < LastToken And Tokens(AfterOpenToken).TokenKind >= 9 And Tokens(AfterOpenToken).TokenKind <= 12
                    AfterOpenToken = AfterOpenToken + 1
                Wend
                If AfterOpenToken = LastToken Then
                    Dim ProcedureSymbol As Long = 0
                    While ProcedureSymbol < SymbolCount
                        If EqualsFolded(Symbols(ProcedureSymbol).SymbolName, Tokens(FirstToken).Spelling) <> 0 Then
                            If Symbols(ProcedureSymbol).SymbolKind = SemanticSymbolProcedure() Or Symbols(ProcedureSymbol).SymbolKind = SemanticSymbolProperty() Then
                                Dim CalledFunction As Long = SemanticFunctionIndex(ProcedureSymbol, Functions, FunctionCount)
                                If CalledFunction >= 0 And CountCalledParameters(ProcedureSymbol, Symbols, SymbolCount) = 0 Then
                                    Dim CallInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpCall(), Symbols(ProcedureSymbol).DeclaredType, FailureBlock, ProcedureSymbol, 0, "", LocationIndex, Instructions, Values, Build)
                                    If CallInstruction >= 0 Then
                                        If AppendIrInstructionOperand(CallInstruction, IrOperandFunction(), CalledFunction, "", Instructions, Operands, Build) <> 0 Then
                                            LowerTokenRangeValue = Instructions(CallInstruction).ResultValue
                                            Exit Function
                                        End If
                                    End If
                                End If
                            End If
                        End If
                        ProcedureSymbol = ProcedureSymbol + 1
                    Wend
                End If
            End If
        End If
        Dim RangeExpression As Long = FindExpressionInsideTokenRange(FirstToken, LastToken, Expressions, ExpressionCount, SyntaxNodes)
        If RangeExpression >= 0 Then
            LowerTokenRangeValue = LowerSemanticExpressionValue(RangeExpression, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
        Else
            LowerTokenRangeValue = -20
        End If
        Exit Function
    End If
    Dim LeftValue As Long = LowerTokenRangeValue(FirstToken, OperatorToken - 1, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    If LeftValue < 0 Then
        LowerTokenRangeValue = LeftValue
        Exit Function
    End If
    Dim RightValue As Long = LowerTokenRangeValue(OperatorToken + 1, LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    If RightValue < 0 Then
        LowerTokenRangeValue = RightValue
        Exit Function
    End If
    Dim OperatorText As String = Tokens(OperatorToken).Spelling
    Dim Opcode As Long = IrOpCompare()
    Dim ResultType As Long = FindSemanticType("Boolean", Types, TypeCount)
    Dim FailureTarget As Long = -1
    If OperatorPriority = 1 Or OperatorPriority = 2 Then
        Opcode = IrOpBoolean()
        ResultType = Values(LeftValue).TypeIndex
    Else
        If OperatorPriority = 4 Then
            Opcode = IrOpConcatenate()
            ResultType = FindSemanticType("String", Types, TypeCount)
            FailureTarget = FailureBlock
        Else
            If OperatorPriority >= 5 Then
                ResultType = Values(LeftValue).TypeIndex
                FailureTarget = FailureBlock
                If OperatorText = "+" Then
                    Opcode = IrOpCheckedAdd()
                End If
                If OperatorText = "-" Then
                    Opcode = IrOpCheckedSubtract()
                End If
                If OperatorText = "*" Then
                    Opcode = IrOpCheckedMultiply()
                End If
                If OperatorText = "/" Or OperatorText = "\" Then
                    Opcode = IrOpCheckedDivide()
                End If
                If EqualsFolded(OperatorText, "Mod") <> 0 Then
                    Opcode = IrOpCheckedRemainder()
                End If
            End If
        End If
    End If
    If OperatorPriority <> 4 Then
        Dim PromotedType As Long = PromoteIrIntegerValues(LeftValue, RightValue, FunctionIndex, BlockIndex, FailureBlock, LocationIndex, Types, TypeCount, Instructions, Operands, Values, Build)
        If PromotedType >= 0 Then
            If Opcode <> IrOpCompare() Then
                ResultType = PromotedType
            End If
        Else
            If Values(LeftValue).TypeIndex <> Values(RightValue).TypeIndex Then
                LowerTokenRangeValue = -24
                Exit Function
            End If
        End If
    End If
    Dim InstructionIndex As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, Opcode, ResultType, FailureTarget, -1, 0, OperatorText, LocationIndex, Instructions, Values, Build)
    If InstructionIndex < 0 Or AppendIrInstructionOperand(InstructionIndex, IrOperandValue(), LeftValue, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(InstructionIndex, IrOperandValue(), RightValue, "", Instructions, Operands, Build) = 0 Then
        LowerTokenRangeValue = -21
        Exit Function
    End If
    LowerTokenRangeValue = Instructions(InstructionIndex).ResultValue
End Function

Function LowerSemanticExpressionValue(ByVal ExpressionIndex As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal OwnerSymbol As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim ExpressionLocation As Long = IrLocationForSyntax(Expressions(ExpressionIndex).SyntaxNode, SyntaxNodes, Tokens, Locations, Build)
    If ExpressionLocation < 0 Then
        LowerSemanticExpressionValue = -1
        Exit Function
    End If

    Dim Opcode As Long = IrOpDefaultValue()
    Dim FailureTarget As Long = -1
    Dim OperandKind As Long = 0
    Dim OperandIndex As Long = -1
    Dim ImmediateText As String = Expressions(ExpressionIndex).ConstantText
    Dim ResolvedSymbol As Long = Expressions(ExpressionIndex).ResolvedSymbol

    Dim ExpressionNode As Long = Expressions(ExpressionIndex).SyntaxNode
    Dim BinaryToken As Long = -1
    Dim BinaryPriority As Long = 100
    Dim BinaryDepth As Long = 0
    Dim BinaryScan As Long = SyntaxNodes(ExpressionNode).FirstToken
    While BinaryScan <= SyntaxNodes(ExpressionNode).LastToken
        If Tokens(BinaryScan).Spelling = "(" Then
            BinaryDepth = BinaryDepth + 1
        Else
            If Tokens(BinaryScan).Spelling = ")" Then
                BinaryDepth = BinaryDepth - 1
            Else
                If BinaryDepth = 0 Then
                    Dim CandidatePriority As Long = IrBinaryOperatorPriority(Tokens(BinaryScan).Spelling)
                    If CandidatePriority > 0 And CandidatePriority <= BinaryPriority And BinaryScan > SyntaxNodes(ExpressionNode).FirstToken And BinaryScan < SyntaxNodes(ExpressionNode).LastToken Then
                        BinaryToken = BinaryScan
                        BinaryPriority = CandidatePriority
                    End If
                End If
            End If
        End If
        BinaryScan = BinaryScan + 1
    Wend
    If BinaryToken >= 0 Then
        Dim LeftExpression As Long = FindExpressionInsideTokenRange(SyntaxNodes(ExpressionNode).FirstToken, BinaryToken - 1, Expressions, ExpressionCount, SyntaxNodes)
        Dim RightExpression As Long = FindExpressionInsideTokenRange(BinaryToken + 1, SyntaxNodes(ExpressionNode).LastToken, Expressions, ExpressionCount, SyntaxNodes)
        Dim LeftValue As Long = LowerTokenRangeValue(SyntaxNodes(ExpressionNode).FirstToken, BinaryToken - 1, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, ExpressionLocation, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
        If LeftValue < 0 Then
            If StringLength(Build.FailureDetail) = 0 Then
                Build.FailureDetail = "left " & Tokens(SyntaxNodes(ExpressionNode).FirstToken).Spelling & ".." & Tokens(BinaryToken - 1).Spelling
            End If
            LowerSemanticExpressionValue = -20
            Exit Function
        End If
        Dim RightValue As Long = LowerTokenRangeValue(BinaryToken + 1, SyntaxNodes(ExpressionNode).LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, ExpressionLocation, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
        If RightValue < 0 Then
            If StringLength(Build.FailureDetail) = 0 Then
                Build.FailureDetail = "right " & Tokens(BinaryToken + 1).Spelling & ".." & Tokens(SyntaxNodes(ExpressionNode).LastToken).Spelling
            End If
            LowerSemanticExpressionValue = -20
            Exit Function
        End If
        Dim OperatorText As String = Tokens(BinaryToken).Spelling
        Dim BinaryOpcode As Long = IrOpCompare()
        Dim BinaryType As Long = FindSemanticType("Boolean", Types, TypeCount)
        Dim BinaryFailure As Long = -1
        If BinaryPriority = 1 Or BinaryPriority = 2 Then
            BinaryOpcode = IrOpBoolean()
            BinaryType = Values(LeftValue).TypeIndex
        Else
            If BinaryPriority = 4 Then
                BinaryOpcode = IrOpConcatenate()
                BinaryType = FindSemanticType("String", Types, TypeCount)
                BinaryFailure = FailureBlock
            Else
                If BinaryPriority >= 5 Then
                    BinaryType = Values(LeftValue).TypeIndex
                    BinaryFailure = FailureBlock
                    If OperatorText = "+" Then
                        BinaryOpcode = IrOpCheckedAdd()
                    End If
                    If OperatorText = "-" Then
                        BinaryOpcode = IrOpCheckedSubtract()
                    End If
                    If OperatorText = "*" Then
                        BinaryOpcode = IrOpCheckedMultiply()
                    End If
                    If OperatorText = "/" Or OperatorText = "\" Then
                        BinaryOpcode = IrOpCheckedDivide()
                    End If
                    If EqualsFolded(OperatorText, "Mod") <> 0 Then
                        BinaryOpcode = IrOpCheckedRemainder()
                    End If
                End If
            End If
        End If
        If BinaryPriority <> 4 Then
            Dim BinaryPromotedType As Long = PromoteIrIntegerValues(LeftValue, RightValue, FunctionIndex, BlockIndex, FailureBlock, ExpressionLocation, Types, TypeCount, Instructions, Operands, Values, Build)
            If BinaryPromotedType >= 0 Then
                If BinaryOpcode <> IrOpCompare() Then
                    BinaryType = BinaryPromotedType
                End If
            Else
                If Values(LeftValue).TypeIndex <> Values(RightValue).TypeIndex Then
                    LowerSemanticExpressionValue = -24
                    Exit Function
                End If
            End If
        End If
        Dim BinaryInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, BinaryOpcode, BinaryType, BinaryFailure, -1, 0, OperatorText, ExpressionLocation, Instructions, Values, Build)
        If BinaryInstruction < 0 Then
            LowerSemanticExpressionValue = -21
            Exit Function
        End If
        If AppendIrInstructionOperand(BinaryInstruction, IrOperandValue(), LeftValue, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(BinaryInstruction, IrOperandValue(), RightValue, "", Instructions, Operands, Build) = 0 Then
            LowerSemanticExpressionValue = -21
            Exit Function
        End If
        LowerSemanticExpressionValue = Instructions(BinaryInstruction).ResultValue
        Exit Function
    End If
    Dim MemberSymbol As Long = -1
    Dim MemberAddress As Long = LowerIndexedMemberAddress(SyntaxNodes(ExpressionNode).FirstToken, SyntaxNodes(ExpressionNode).LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, ExpressionLocation, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, MemberSymbol)
    If MemberAddress < 0 Then
        MemberAddress = LowerDirectMemberAddress(SyntaxNodes(ExpressionNode).FirstToken, SyntaxNodes(ExpressionNode).LastToken, FunctionIndex, BlockIndex, OwnerSymbol, ExpressionLocation, Types, TypeCount, Symbols, SymbolCount, Storages, Instructions, Operands, Values, Build, Tokens, MemberSymbol)
    End If
    If MemberAddress >= 0 Then
        Dim MemberLoad As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpLoad(), Symbols(MemberSymbol).DeclaredType, -1, MemberSymbol, 0, "", ExpressionLocation, Instructions, Values, Build)
        If MemberLoad < 0 Or AppendIrInstructionOperand(MemberLoad, IrOperandValue(), MemberAddress, "", Instructions, Operands, Build) = 0 Then
            LowerSemanticExpressionValue = -1
            Exit Function
        End If
        LowerSemanticExpressionValue = Instructions(MemberLoad).ResultValue
        Exit Function
    End If
    Dim ElementBaseSymbol As Long = -1
    Dim ElementType As Long = -1
    Dim ElementAddress As Long = LowerIndexedElementAddress(SyntaxNodes(ExpressionNode).FirstToken, SyntaxNodes(ExpressionNode).LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, ExpressionLocation, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, ElementBaseSymbol, ElementType)
    If ElementAddress >= 0 Then
        Dim ElementLoad As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpLoad(), ElementType, -1, ElementBaseSymbol, 0, "", ExpressionLocation, Instructions, Values, Build)
        If ElementLoad < 0 Or AppendIrInstructionOperand(ElementLoad, IrOperandValue(), ElementAddress, "", Instructions, Operands, Build) = 0 Then
            LowerSemanticExpressionValue = -1
            Exit Function
        End If
        LowerSemanticExpressionValue = Instructions(ElementLoad).ResultValue
        Exit Function
    End If

    If Expressions(ExpressionIndex).ConstantKind <> 0 Then
        Opcode = IrOpConstant()
    Else
        If ResolvedSymbol >= 0 And ResolvedSymbol < SymbolCount Then
            If ResolvedSymbol = OwnerSymbol Then
                OperandIndex = FindIrStorageForSymbol(ResolvedSymbol, FunctionIndex, Storages, Build.StorageCount)
                If OperandIndex >= 0 Then
                    Opcode = IrOpLoad()
                    OperandKind = IrOperandStorage()
                End If
            Else
            If Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolVariable() Or Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolParameter() Then
                OperandIndex = FindIrStorageForSymbol(ResolvedSymbol, FunctionIndex, Storages, Build.StorageCount)
                If OperandIndex >= 0 Then
                    Opcode = IrOpLoad()
                    OperandKind = IrOperandStorage()
                End If
            Else
                If Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolConstant() Or Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolMember() Then
                    Opcode = IrOpConstant()
                    ImmediateText = Symbols(ResolvedSymbol).ConstantText
                Else
                    If Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolProcedure() Or Symbols(ResolvedSymbol).SymbolKind = SemanticSymbolProperty() Then
                        OperandIndex = SemanticFunctionIndex(ResolvedSymbol, Functions, FunctionCount)
                        If OperandIndex >= 0 Then
                            Opcode = IrOpCall()
                            OperandKind = IrOperandFunction()
                            FailureTarget = FailureBlock
                        End If
                    End If
                End If
            End If
            End If
        End If
    End If

    Dim CallArgumentKinds() As Long
    Dim CallArgumentIndexes() As Long
    Dim CallArgumentCount As Long = 0
    Dim ExpectedCallArgumentCount As Long = 0
    If Opcode = IrOpCall() Then
        ExpectedCallArgumentCount = CountCalledParameters(ResolvedSymbol, Symbols, SymbolCount)
        If ExpectedCallArgumentCount > 0 Then
            ReDim CallArgumentKinds(ExpectedCallArgumentCount - 1)
            ReDim CallArgumentIndexes(ExpectedCallArgumentCount - 1)
        End If
    End If
    If Opcode = IrOpCall() Then
        Dim OpenToken As Long = -1
        Dim CloseToken As Long = -1
        Dim ScanToken As Long = SyntaxNodes(ExpressionNode).FirstToken
        Dim ParenthesisDepth As Long = 0
        While ScanToken <= SyntaxNodes(ExpressionNode).LastToken
            If Tokens(ScanToken).Spelling = "(" Then
                If OpenToken < 0 Then
                    OpenToken = ScanToken
                End If
                ParenthesisDepth = ParenthesisDepth + 1
            Else
                If Tokens(ScanToken).Spelling = ")" Then
                    ParenthesisDepth = ParenthesisDepth - 1
                    If OpenToken >= 0 And ParenthesisDepth = 0 Then
                        CloseToken = ScanToken
                    End If
                End If
            End If
            ScanToken = ScanToken + 1
        Wend
        Dim ArgumentOrdinal As Long = 0
        If OpenToken >= 0 And CloseToken > OpenToken + 1 Then
            Dim ArgumentFirst As Long = OpenToken + 1
            ScanToken = ArgumentFirst
            ParenthesisDepth = 0
            While ScanToken <= CloseToken
                Dim EndsArgument As Long = 0
                If ScanToken = CloseToken Then
                    EndsArgument = 1
                Else
                    If Tokens(ScanToken).Spelling = "(" Then
                        ParenthesisDepth = ParenthesisDepth + 1
                    Else
                        If Tokens(ScanToken).Spelling = ")" Then
                            ParenthesisDepth = ParenthesisDepth - 1
                        Else
                            If Tokens(ScanToken).Spelling = "," And ParenthesisDepth = 0 Then
                                EndsArgument = 1
                            End If
                        End If
                    End If
                End If
                If EndsArgument <> 0 Then
                    Dim ArgumentLast As Long = ScanToken - 1
                    Dim ArgumentExpression As Long = FindExpressionInsideTokenRange(ArgumentFirst, ArgumentLast, Expressions, ExpressionCount, SyntaxNodes)
                    Dim ParameterSymbol As Long = FindCalledParameterSymbol(ResolvedSymbol, ArgumentOrdinal, Symbols, SymbolCount)
                    If ArgumentExpression < 0 Or ParameterSymbol < 0 Then
                        LowerSemanticExpressionValue = -11
                        Exit Function
                    End If
                    Dim ArgumentOperandKind As Long = IrOperandValue()
                    Dim ArgumentReferencedIndex As Long = -1
                    If Symbols(ParameterSymbol).Flags And 2 Then
                        ArgumentReferencedIndex = LowerSemanticExpressionValue(ArgumentExpression, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
                        If ArgumentReferencedIndex >= 0 Then
                            If Values(ArgumentReferencedIndex).TypeIndex <> Symbols(ParameterSymbol).DeclaredType Then
                                Dim ArgumentConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), Symbols(ParameterSymbol).DeclaredType, FailureBlock, ParameterSymbol, 0, "", ExpressionLocation, Instructions, Values, Build)
                                If ArgumentConvert < 0 Or AppendIrInstructionOperand(ArgumentConvert, IrOperandValue(), ArgumentReferencedIndex, "", Instructions, Operands, Build) = 0 Then
                                    LowerSemanticExpressionValue = -13
                                    Exit Function
                                End If
                                ArgumentReferencedIndex = Instructions(ArgumentConvert).ResultValue
                            End If
                        End If
                    Else
                        Dim ArgumentNode As Long = Expressions(ArgumentExpression).SyntaxNode
                        Dim ArgumentMemberSymbol As Long = -1
                        ArgumentReferencedIndex = LowerIndexedMemberAddress(SyntaxNodes(ArgumentNode).FirstToken, SyntaxNodes(ArgumentNode).LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, ExpressionLocation, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, ArgumentMemberSymbol)
                        If ArgumentReferencedIndex < 0 Then
                            Dim ArgumentElementSymbol As Long = -1
                            Dim ArgumentElementType As Long = -1
                            ArgumentReferencedIndex = LowerIndexedElementAddress(SyntaxNodes(ArgumentNode).FirstToken, SyntaxNodes(ArgumentNode).LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, ExpressionLocation, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, ArgumentElementSymbol, ArgumentElementType)
                        End If
                        If ArgumentReferencedIndex < 0 Then
                            ArgumentReferencedIndex = LowerDirectMemberAddress(SyntaxNodes(ArgumentNode).FirstToken, SyntaxNodes(ArgumentNode).LastToken, FunctionIndex, BlockIndex, OwnerSymbol, ExpressionLocation, Types, TypeCount, Symbols, SymbolCount, Storages, Instructions, Operands, Values, Build, Tokens, ArgumentMemberSymbol)
                        End If
                        If ArgumentReferencedIndex >= 0 Then
                            ArgumentOperandKind = IrOperandValue()
                        Else
                            Dim ArgumentSymbol As Long = Expressions(ArgumentExpression).ResolvedSymbol
                            ArgumentReferencedIndex = FindIrStorageForSymbol(ArgumentSymbol, FunctionIndex, Storages, Build.StorageCount)
                            ArgumentOperandKind = IrOperandStorage()
                        End If
                    End If
                    If ArgumentReferencedIndex < 0 Then
                        LowerSemanticExpressionValue = -12
                        Exit Function
                    End If
                    If CallArgumentCount >= ExpectedCallArgumentCount Then
                        LowerSemanticExpressionValue = -14
                        Exit Function
                    End If
                    CallArgumentKinds(CallArgumentCount) = ArgumentOperandKind
                    CallArgumentIndexes(CallArgumentCount) = ArgumentReferencedIndex
                    CallArgumentCount = CallArgumentCount + 1
                    ArgumentOrdinal = ArgumentOrdinal + 1
                    ArgumentFirst = ScanToken + 1
                End If
                ScanToken = ScanToken + 1
            Wend
        End If
    End If
    Dim InstructionIndex As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, Opcode, Expressions(ExpressionIndex).TypeIndex, FailureTarget, ResolvedSymbol, Expressions(ExpressionIndex).Flags, ImmediateText, ExpressionLocation, Instructions, Values, Build)
    If InstructionIndex < 0 Then
        LowerSemanticExpressionValue = -1
        Exit Function
    End If
    If OperandKind <> 0 Then
        If AppendIrInstructionOperand(InstructionIndex, OperandKind, OperandIndex, "", Instructions, Operands, Build) = 0 Then
            LowerSemanticExpressionValue = -1
            Exit Function
        End If
    End If
    Dim CallArgumentIndex As Long = 0
    While CallArgumentIndex < CallArgumentCount
        If AppendIrInstructionOperand(InstructionIndex, CallArgumentKinds(CallArgumentIndex), CallArgumentIndexes(CallArgumentIndex), "", Instructions, Operands, Build) = 0 Then
            LowerSemanticExpressionValue = -1
            Exit Function
        End If
        CallArgumentIndex = CallArgumentIndex + 1
    Wend
    LowerSemanticExpressionValue = Instructions(InstructionIndex).ResultValue
End Function

Function LowerAssignmentToIr(ByVal AssignmentNode As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal ResultStorage As Long, ByVal OwnerSymbol As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim RightExpression As Long = FindAssignmentExpression(AssignmentNode, 1, Expressions, ExpressionCount, SyntaxNodes, Tokens)
    If RightExpression < 0 Then
        LowerAssignmentToIr = -1
        Exit Function
    End If
    Dim AssignmentLocation As Long = IrLocationForSyntax(AssignmentNode, SyntaxNodes, Tokens, Locations, Build)
    Dim EqualsToken As Long = SyntaxNodes(AssignmentNode).FirstToken
    While EqualsToken <= SyntaxNodes(AssignmentNode).LastToken And Tokens(EqualsToken).Spelling <> "="
        EqualsToken = EqualsToken + 1
    Wend
    Dim LeftMemberSymbol As Long = -1
    Dim LeftMemberAddress As Long = LowerIndexedMemberAddress(SyntaxNodes(AssignmentNode).FirstToken, EqualsToken - 1, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, AssignmentLocation, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, LeftMemberSymbol)
    If LeftMemberAddress < 0 Then
        LeftMemberAddress = LowerDirectMemberAddress(SyntaxNodes(AssignmentNode).FirstToken, EqualsToken - 1, FunctionIndex, BlockIndex, OwnerSymbol, AssignmentLocation, Types, TypeCount, Symbols, SymbolCount, Storages, Instructions, Operands, Values, Build, Tokens, LeftMemberSymbol)
    End If
    Dim LeftElementType As Long = -1
    If LeftMemberAddress < 0 Then
        LeftMemberAddress = LowerIndexedElementAddress(SyntaxNodes(AssignmentNode).FirstToken, EqualsToken - 1, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, AssignmentLocation, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens, LeftMemberSymbol, LeftElementType)
    End If
    Dim LeftSymbol As Long = LeftMemberSymbol
    If LeftMemberAddress < 0 Then
        LeftSymbol = ResolveAssignmentTargetSymbol(AssignmentNode, OwnerSymbol, Symbols, SymbolCount, SyntaxNodes, Tokens)
    End If
    Dim TargetStorage As Long = -1
    If LeftMemberAddress >= 0 Then
        TargetStorage = -1
    Else
    If LeftSymbol = OwnerSymbol Then
        TargetStorage = ResultStorage
    Else
        TargetStorage = FindIrStorageForSymbol(LeftSymbol, FunctionIndex, Storages, Build.StorageCount)
    End If
    End If
    If TargetStorage < 0 And LeftMemberAddress < 0 Then
        LowerAssignmentToIr = -2
        Exit Function
    End If
    Dim RightValue As Long = LowerTokenRangeValue(EqualsToken + 1, SyntaxNodes(AssignmentNode).LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, AssignmentLocation, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    If RightValue < 0 Then
        LowerAssignmentToIr = RightValue
        Exit Function
    End If
    Dim TargetType As Long = -1
    If LeftMemberAddress >= 0 Then
        If LeftElementType >= 0 Then
            TargetType = LeftElementType
        Else
            TargetType = Symbols(LeftMemberSymbol).DeclaredType
        End If
    Else
        TargetType = Storages(TargetStorage).TypeIndex
    End If
    If Values(RightValue).TypeIndex <> TargetType Then
        Dim ConvertInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), TargetType, FailureBlock, LeftSymbol, 0, "", AssignmentLocation, Instructions, Values, Build)
        If ConvertInstruction < 0 Or AppendIrInstructionOperand(ConvertInstruction, IrOperandValue(), RightValue, "", Instructions, Operands, Build) = 0 Then
            LowerAssignmentToIr = -4
            Exit Function
        End If
        RightValue = Instructions(ConvertInstruction).ResultValue
    End If
    Dim StoreInstruction As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, IrOpStore(), -1, -1, -1, -1, -1, 0, LeftSymbol, 0, "", AssignmentLocation)
    If StoreInstruction < 0 Then
        LowerAssignmentToIr = -5
        Exit Function
    End If
    Dim TargetOperandKind As Long = IrOperandStorage()
    Dim TargetOperandIndex As Long = TargetStorage
    If LeftMemberAddress >= 0 Then
        TargetOperandKind = IrOperandValue()
        TargetOperandIndex = LeftMemberAddress
    End If
    If AppendIrInstructionOperand(StoreInstruction, TargetOperandKind, TargetOperandIndex, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(StoreInstruction, IrOperandValue(), RightValue, "", Instructions, Operands, Build) = 0 Then
        LowerAssignmentToIr = -6
        Exit Function
    End If
    LowerAssignmentToIr = 1
End Function

Function LowerVariableInitializerToIr(ByVal VariableNode As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal OwnerSymbol As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim VariableSymbol As Long = -1
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SyntaxNode = VariableNode And Symbols(SymbolIndex).ParentSymbol = OwnerSymbol And Symbols(SymbolIndex).SymbolKind = SemanticSymbolVariable() Then
            VariableSymbol = SymbolIndex
            Exit While
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    If VariableSymbol < 0 Then
        LowerVariableInitializerToIr = 0
        Exit Function
    End If
    Dim EqualsToken As Long = -1
    Dim Depth As Long = 0
    Dim TokenIndex As Long = SyntaxNodes(VariableNode).FirstToken
    While TokenIndex <= SyntaxNodes(VariableNode).LastToken
        If Tokens(TokenIndex).Spelling = "(" Then
            Depth = Depth + 1
        Else
            If Tokens(TokenIndex).Spelling = ")" Then
                Depth = Depth - 1
            Else
                If Depth = 0 And Tokens(TokenIndex).Spelling = "=" Then
                    EqualsToken = TokenIndex
                    Exit While
                End If
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    If EqualsToken < 0 Then
        LowerVariableInitializerToIr = 1
        Exit Function
    End If
    Dim LocationIndex As Long = IrLocationForSyntax(VariableNode, SyntaxNodes, Tokens, Locations, Build)
    Dim InitialValue As Long = LowerTokenRangeValue(EqualsToken + 1, SyntaxNodes(VariableNode).LastToken, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    If InitialValue < 0 Then
        LowerVariableInitializerToIr = 0
        Exit Function
    End If
    Dim VariableType As Long = Symbols(VariableSymbol).DeclaredType
    If Values(InitialValue).TypeIndex <> VariableType Then
        Dim ConvertInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), VariableType, FailureBlock, VariableSymbol, 0, "", LocationIndex, Instructions, Values, Build)
        If ConvertInstruction < 0 Or AppendIrInstructionOperand(ConvertInstruction, IrOperandValue(), InitialValue, "", Instructions, Operands, Build) = 0 Then
            LowerVariableInitializerToIr = 0
            Exit Function
        End If
        InitialValue = Instructions(ConvertInstruction).ResultValue
    End If
    Dim VariableStorage As Long = FindIrStorageForSymbol(VariableSymbol, FunctionIndex, Storages, Build.StorageCount)
    Dim StoreInstruction As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, IrOpStore(), -1, -1, -1, -1, -1, 0, VariableSymbol, 0, "", LocationIndex)
    If VariableStorage < 0 Or StoreInstruction < 0 Or AppendIrInstructionOperand(StoreInstruction, IrOperandStorage(), VariableStorage, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(StoreInstruction, IrOperandValue(), InitialValue, "", Instructions, Operands, Build) = 0 Then
        LowerVariableInitializerToIr = 0
        Exit Function
    End If
    LowerVariableInitializerToIr = 1
End Function

Function LowerReDimStatementToIr(ByVal StatementNode As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal OwnerSymbol As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim TokenIndex As Long = SyntaxNodes(StatementNode).FirstToken
    Dim PreserveValue As Long = 0
    Dim ArrayName As String = ""
    Dim OpenToken As Long = -1
    Dim CloseToken As Long = -1
    Dim Depth As Long = 0
    While TokenIndex <= SyntaxNodes(StatementNode).LastToken
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Preserve") <> 0 Then
            PreserveValue = 1
        End If
        If StringLength(ArrayName) = 0 And (Tokens(TokenIndex).TokenKind = 2 Or Tokens(TokenIndex).TokenKind = 3) Then
            If EqualsFolded(Tokens(TokenIndex).Spelling, "ReDim") = 0 And EqualsFolded(Tokens(TokenIndex).Spelling, "Preserve") = 0 Then
                ArrayName = Tokens(TokenIndex).Spelling
                If Tokens(TokenIndex).TokenKind = 3 Then
                    ArrayName = Tokens(TokenIndex).Decoded
                End If
            End If
        End If
        If Tokens(TokenIndex).Spelling = "(" Then
            If OpenToken < 0 Then
                OpenToken = TokenIndex
            End If
            Depth = Depth + 1
        Else
            If Tokens(TokenIndex).Spelling = ")" Then
                Depth = Depth - 1
                If Depth = 0 Then
                    CloseToken = TokenIndex
                    Exit While
                End If
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    Dim ArraySymbol As Long = FindVisibleIrSymbolByName(ArrayName, OwnerSymbol, FunctionIndex, Symbols, SymbolCount, Storages, Build.StorageCount)
    If ArraySymbol < 0 Or OpenToken < 0 Or CloseToken <= OpenToken Then
        LowerReDimStatementToIr = 0
        Exit Function
    End If
    Dim ArrayType As Long = Symbols(ArraySymbol).DeclaredType
    If ArrayType < 0 Or ArrayType >= TypeCount Or Types(ArrayType).TypeKind <> 41 Then
        LowerReDimStatementToIr = 0
        Exit Function
    End If
    Dim LocationIndex As Long = IrLocationForSyntax(StatementNode, SyntaxNodes, Tokens, Locations, Build)
    Dim ToToken As Long = -1
    Depth = 0
    TokenIndex = OpenToken + 1
    While TokenIndex < CloseToken
        If Tokens(TokenIndex).Spelling = "(" Then
            Depth = Depth + 1
        Else
            If Tokens(TokenIndex).Spelling = ")" Then
                Depth = Depth - 1
            Else
                If Depth = 0 And EqualsFolded(Tokens(TokenIndex).Spelling, "To") <> 0 Then
                    ToToken = TokenIndex
                    Exit While
                End If
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
    Dim UpperFirst As Long = OpenToken + 1
    If ToToken >= 0 Then
        UpperFirst = ToToken + 1
    End If
    Dim UpperValue As Long = LowerTokenRangeValue(UpperFirst, CloseToken - 1, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    If UpperValue < 0 Then
        LowerReDimStatementToIr = 0
        Exit Function
    End If
    Dim LongType As Long = FindSemanticType("Long", Types, TypeCount)
    Dim LowerValue As Long = -1
    If ToToken >= 0 Then
        LowerValue = LowerTokenRangeValue(OpenToken + 1, ToToken - 1, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    Else
        Dim LowerInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConstant(), LongType, -1, -1, 0, "0", LocationIndex, Instructions, Values, Build)
        If LowerInstruction >= 0 Then
            LowerValue = Instructions(LowerInstruction).ResultValue
        End If
    End If
    If LowerValue < 0 Then
        LowerReDimStatementToIr = 0
        Exit Function
    End If
    If Values(LowerValue).TypeIndex <> LongType Then
        Dim LowerConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), LongType, FailureBlock, ArraySymbol, 0, "", LocationIndex, Instructions, Values, Build)
        If LowerConvert < 0 Or AppendIrInstructionOperand(LowerConvert, IrOperandValue(), LowerValue, "", Instructions, Operands, Build) = 0 Then
            LowerReDimStatementToIr = 0
            Exit Function
        End If
        LowerValue = Instructions(LowerConvert).ResultValue
    End If
    If Values(UpperValue).TypeIndex <> LongType Then
        Dim UpperConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), LongType, FailureBlock, ArraySymbol, 0, "", LocationIndex, Instructions, Values, Build)
        If UpperConvert < 0 Or AppendIrInstructionOperand(UpperConvert, IrOperandValue(), UpperValue, "", Instructions, Operands, Build) = 0 Then
            LowerReDimStatementToIr = 0
            Exit Function
        End If
        UpperValue = Instructions(UpperConvert).ResultValue
    End If
    Dim ResizeInstruction As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, IrOpArrayResize(), -1, -1, -1, -1, -1, 0, ArraySymbol, 0, "", LocationIndex)
    Dim ArrayStorage As Long = FindIrStorageForSymbol(ArraySymbol, FunctionIndex, Storages, Build.StorageCount)
    If ResizeInstruction < 0 Or ArrayStorage < 0 Then
        LowerReDimStatementToIr = 0
        Exit Function
    End If
    If AppendIrInstructionOperand(ResizeInstruction, IrOperandStorage(), ArrayStorage, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(ResizeInstruction, IrOperandValue(), LowerValue, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(ResizeInstruction, IrOperandValue(), UpperValue, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(ResizeInstruction, IrOperandType(), Types(ArrayType).ElementType, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(ResizeInstruction, IrOperandInteger(), PreserveValue, "", Instructions, Operands, Build) = 0 Then
        LowerReDimStatementToIr = 0
        Exit Function
    End If
    LowerReDimStatementToIr = 1
End Function

Function LowerIrStructuredRegion(ByVal RegionNode As Long, ByVal ProcedureNode As Long, ByVal FunctionIndex As Long, ByRef CurrentBlock As Long, ByVal FailureBlock As Long, ByVal LoopExitBlock As Long, ByVal ResultStorage As Long, ByVal OwnerSymbol As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long, ByRef Rules() As GrammarRule, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Edges() As IrEdge, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim LastToken As Long = -1
    Dim RegionFirstToken As Long = SyntaxNodes(RegionNode).FirstToken
    Dim RegionLastToken As Long = SyntaxNodes(RegionNode).LastToken
    Dim SearchNode As Long = RegionNode + 1
    Dim RegionLastNode As Long = SyntaxSubtreeLastNode(RegionNode, BindingCount, SyntaxNodes)
    While SearchNode <= RegionLastNode
        If SyntaxNodes(SearchNode).FirstToken >= RegionFirstToken And SyntaxNodes(SearchNode).LastToken <= RegionLastToken And SyntaxNodes(SearchNode).FirstToken > LastToken Then
        If IrStructuredRegionOwner(SearchNode, ProcedureNode, SyntaxNodes, Rules) = RegionNode Then
            Dim IsAssignment As Long = SyntaxRuleIs(SearchNode, "assignment-statement", SyntaxNodes, Rules)
            Dim IsBlockIf As Long = SyntaxRuleIs(SearchNode, "block-if", SyntaxNodes, Rules)
            Dim IsWhile As Long = SyntaxRuleIs(SearchNode, "while-statement", SyntaxNodes, Rules)
            Dim IsCallStatement As Long = SyntaxRuleIs(SearchNode, "call-statement", SyntaxNodes, Rules)
            Dim IsPrintStatement As Long = SyntaxRuleIs(SearchNode, "print-statement", SyntaxNodes, Rules)
            Dim IsExitStatement As Long = SyntaxRuleIs(SearchNode, "exit-statement", SyntaxNodes, Rules)
            Dim IsVariableItem As Long = SyntaxRuleIs(SearchNode, "variable-item", SyntaxNodes, Rules)
            Dim IsReDimStatement As Long = 0
            If SyntaxRuleIs(SearchNode, "dynamic-statement", SyntaxNodes, Rules) <> 0 Then
                Dim DynamicFirstToken As Long = SyntaxNodes(SearchNode).FirstToken
                While DynamicFirstToken <= SyntaxNodes(SearchNode).LastToken And Tokens(DynamicFirstToken).TokenKind >= 9 And Tokens(DynamicFirstToken).TokenKind <= 12
                    DynamicFirstToken = DynamicFirstToken + 1
                Wend
                If DynamicFirstToken >= 0 Then
                    If EqualsFolded(Tokens(DynamicFirstToken).Spelling, "ReDim") <> 0 Then
                        IsReDimStatement = 1
                    End If
                End If
            End If
            If IsAssignment <> 0 Or IsBlockIf <> 0 Or IsWhile <> 0 Or IsCallStatement <> 0 Or IsReDimStatement <> 0 Or IsPrintStatement <> 0 Or IsExitStatement <> 0 Or IsVariableItem <> 0 Then
                If IsVariableItem <> 0 Then
                    If LowerVariableInitializerToIr(SearchNode, FunctionIndex, CurrentBlock, FailureBlock, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens) = 0 Then
                        Build.FailureSyntaxNode = SearchNode
                        Build.FailureStage = -700
                        Build.FailureDetail = "variable initializer"
                        LowerIrStructuredRegion = 0
                        Exit Function
                    End If
                Else
                If IsAssignment <> 0 Then
                    Dim AssignmentResult As Long = LowerAssignmentToIr(SearchNode, FunctionIndex, CurrentBlock, FailureBlock, ResultStorage, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
                    If AssignmentResult <= 0 Then
                        If Build.FailureSyntaxNode < 0 Then
                            Build.FailureSyntaxNode = SearchNode
                            Build.FailureStage = AssignmentResult
                        End If
                        LowerIrStructuredRegion = 0
                        Exit Function
                    End If
                Else
                    If IsExitStatement <> 0 Then
                        Dim ExitKindToken As Long = SyntaxNodes(SearchNode).FirstToken + 1
                        While ExitKindToken <= SyntaxNodes(SearchNode).LastToken And Tokens(ExitKindToken).TokenKind >= 9 And Tokens(ExitKindToken).TokenKind <= 12
                            ExitKindToken = ExitKindToken + 1
                        Wend
                        Dim ExitTargetBlock As Long = Functions(FunctionIndex).ReturnBlock
                        If ExitKindToken <= SyntaxNodes(SearchNode).LastToken Then
                            If EqualsFolded(Tokens(ExitKindToken).Spelling, "While") <> 0 Then
                                ExitTargetBlock = LoopExitBlock
                            End If
                        End If
                        If ExitKindToken > SyntaxNodes(SearchNode).LastToken Or ExitTargetBlock < 0 Or (EqualsFolded(Tokens(ExitKindToken).Spelling, "Sub") = 0 And EqualsFolded(Tokens(ExitKindToken).Spelling, "Function") = 0 And EqualsFolded(Tokens(ExitKindToken).Spelling, "Property") = 0 And EqualsFolded(Tokens(ExitKindToken).Spelling, "While") = 0) Then
                            Build.FailureSyntaxNode = SearchNode
                            Build.FailureStage = -600
                            Build.FailureDetail = "unsupported Exit target"
                            LowerIrStructuredRegion = 0
                            Exit Function
                        End If
                        Dim ExitLocation As Long = IrLocationForSyntax(SearchNode, SyntaxNodes, Tokens, Locations, Build)
                        If FinishIrBranchBlock(FunctionIndex, CurrentBlock, ExitTargetBlock, IrEdgeFallthrough(), -1, ExitLocation, Blocks, Instructions, Edges, Build) = 0 Then
                            LowerIrStructuredRegion = 0
                            Exit Function
                        End If
                        CurrentBlock = AppendControlIrBlock(FunctionIndex, ExitLocation, Functions, Blocks, Build)
                        If CurrentBlock < 0 Then
                            LowerIrStructuredRegion = 0
                            Exit Function
                        End If
                        Blocks(CurrentBlock).FirstInstruction = Build.InstructionCount
                    Else
                    If IsPrintStatement <> 0 Then
                        Dim PrintFirstToken As Long = SyntaxNodes(SearchNode).FirstToken + 1
                        Dim PrintValue As Long = LowerTokenRangeValue(PrintFirstToken, SyntaxNodes(SearchNode).LastToken, FunctionIndex, CurrentBlock, FailureBlock, OwnerSymbol, IrLocationForSyntax(SearchNode, SyntaxNodes, Tokens, Locations, Build), Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
                        Dim PrintInstruction As Long = -1
                        If PrintValue >= 0 Then
                            PrintInstruction = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, CurrentBlock, IrOpPrint(), -1, -1, -1, -1, -1, 0, -1, 0, "newline", IrLocationForSyntax(SearchNode, SyntaxNodes, Tokens, Locations, Build))
                        End If
                        If PrintInstruction < 0 Or AppendIrInstructionOperand(PrintInstruction, IrOperandValue(), PrintValue, "", Instructions, Operands, Build) = 0 Then
                            If Build.FailureSyntaxNode < 0 Then
                                Build.FailureSyntaxNode = SearchNode
                                Build.FailureStage = -500
                            End If
                            LowerIrStructuredRegion = 0
                            Exit Function
                        End If
                    Else
                    If IsReDimStatement <> 0 Then
                        Dim ReDimResult As Long = LowerReDimStatementToIr(SearchNode, FunctionIndex, CurrentBlock, FailureBlock, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
                        If ReDimResult <= 0 Then
                            If Build.FailureSyntaxNode < 0 Then
                                Build.FailureSyntaxNode = SearchNode
                                Build.FailureStage = -400
                            End If
                            LowerIrStructuredRegion = 0
                            Exit Function
                        End If
                    Else
                    If IsCallStatement <> 0 Then
                        Dim CallFirstToken As Long = SyntaxNodes(SearchNode).FirstToken + 1
                        Dim IgnoredCallResult As Long = LowerTokenRangeValue(CallFirstToken, SyntaxNodes(SearchNode).LastToken, FunctionIndex, CurrentBlock, FailureBlock, OwnerSymbol, IrLocationForSyntax(SearchNode, SyntaxNodes, Tokens, Locations, Build), Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
                        If IgnoredCallResult < 0 Then
                            If Build.FailureSyntaxNode < 0 Then
                                Build.FailureSyntaxNode = SearchNode
                                Build.FailureStage = IgnoredCallResult
                            End If
                            LowerIrStructuredRegion = 0
                            Exit Function
                        End If
                    Else
                    If IsBlockIf <> 0 Then
                        If LowerIrBlockIf(SearchNode, ProcedureNode, FunctionIndex, CurrentBlock, FailureBlock, LoopExitBlock, ResultStorage, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Bindings, BindingCount, Rules, Functions, Storages, Blocks, Instructions, Operands, Values, Edges, Locations, Build, SyntaxNodes, Tokens) = 0 Then
                            If Build.FailureSyntaxNode < 0 Then
                                Build.FailureSyntaxNode = SearchNode
                                Build.FailureStage = -200
                            End If
                            LowerIrStructuredRegion = 0
                            Exit Function
                        End If
                    Else
                        If LowerIrWhile(SearchNode, ProcedureNode, FunctionIndex, CurrentBlock, FailureBlock, ResultStorage, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Bindings, BindingCount, Rules, Functions, Storages, Blocks, Instructions, Operands, Values, Edges, Locations, Build, SyntaxNodes, Tokens) = 0 Then
                            If Build.FailureSyntaxNode < 0 Then
                                Build.FailureSyntaxNode = SearchNode
                                Build.FailureStage = -300
                            End If
                            LowerIrStructuredRegion = 0
                            Exit Function
                        End If
                    End If
                    End If
                    End If
                    End If
                    End If
                End If
                End If
                LastToken = SyntaxNodes(SearchNode).LastToken
            End If
        End If
        End If
        SearchNode = SearchNode + 1
    Wend
    LowerIrStructuredRegion = 1
End Function

Function LowerIrWhile(ByVal WhileNode As Long, ByVal ProcedureNode As Long, ByVal FunctionIndex As Long, ByRef CurrentBlock As Long, ByVal FailureBlock As Long, ByVal ResultStorage As Long, ByVal OwnerSymbol As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long, ByRef Rules() As GrammarRule, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Edges() As IrEdge, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim LocationIndex As Long = IrLocationForSyntax(WhileNode, SyntaxNodes, Tokens, Locations, Build)
    Dim ConditionBlock As Long = AppendControlIrBlock(FunctionIndex, LocationIndex, Functions, Blocks, Build)
    Dim BodyBlock As Long = AppendControlIrBlock(FunctionIndex, LocationIndex, Functions, Blocks, Build)
    Dim AfterBlock As Long = AppendControlIrBlock(FunctionIndex, LocationIndex, Functions, Blocks, Build)
    If ConditionBlock < 0 Or BodyBlock < 0 Or AfterBlock < 0 Then
        LowerIrWhile = 0
        Exit Function
    End If
    If FinishIrBranchBlock(FunctionIndex, CurrentBlock, ConditionBlock, IrEdgeFallthrough(), -1, LocationIndex, Blocks, Instructions, Edges, Build) = 0 Then
        LowerIrWhile = 0
        Exit Function
    End If
    CurrentBlock = ConditionBlock
    Blocks(CurrentBlock).FirstInstruction = Build.InstructionCount
    Dim ConditionExpression As Long = FindControlConditionExpression(WhileNode, "", Expressions, ExpressionCount, BindingCount, SyntaxNodes, Tokens)
    If ConditionExpression < 0 Then
        Build.FailureSyntaxNode = WhileNode
        Build.FailureStage = -301
        LowerIrWhile = 0
        Exit Function
    End If
    Dim ConditionValue As Long = LowerSemanticExpressionValue(ConditionExpression, FunctionIndex, CurrentBlock, FailureBlock, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    Dim BooleanType As Long = FindSemanticType("Boolean", Types, TypeCount)
    If ConditionValue < 0 Then
        Build.FailureSyntaxNode = WhileNode
        Build.FailureStage = ConditionValue
        LowerIrWhile = 0
        Exit Function
    End If
    If Values(ConditionValue).TypeIndex <> BooleanType Then
        Dim ConditionConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, CurrentBlock, IrOpConvert(), BooleanType, FailureBlock, -1, 0, "", LocationIndex, Instructions, Values, Build)
        If ConditionConvert < 0 Or AppendIrInstructionOperand(ConditionConvert, IrOperandValue(), ConditionValue, "", Instructions, Operands, Build) = 0 Then
            LowerIrWhile = 0
            Exit Function
        End If
        ConditionValue = Instructions(ConditionConvert).ResultValue
    End If
    If FinishIrConditionalBlock(FunctionIndex, CurrentBlock, ConditionValue, BodyBlock, AfterBlock, LocationIndex, Blocks, Instructions, Operands, Edges, Build) = 0 Then
        LowerIrWhile = 0
        Exit Function
    End If
    CurrentBlock = BodyBlock
    Blocks(CurrentBlock).FirstInstruction = Build.InstructionCount
    If LowerIrStructuredRegion(WhileNode, ProcedureNode, FunctionIndex, CurrentBlock, FailureBlock, AfterBlock, ResultStorage, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Bindings, BindingCount, Rules, Functions, Storages, Blocks, Instructions, Operands, Values, Edges, Locations, Build, SyntaxNodes, Tokens) = 0 Then
        LowerIrWhile = 0
        Exit Function
    End If
    If FinishIrBranchBlock(FunctionIndex, CurrentBlock, ConditionBlock, IrEdgeFallthrough(), -1, LocationIndex, Blocks, Instructions, Edges, Build) = 0 Then
        LowerIrWhile = 0
        Exit Function
    End If
    CurrentBlock = AfterBlock
    Blocks(CurrentBlock).FirstInstruction = Build.InstructionCount
    LowerIrWhile = 1
End Function

Function LowerIrBlockIf(ByVal IfNode As Long, ByVal ProcedureNode As Long, ByVal FunctionIndex As Long, ByRef CurrentBlock As Long, ByVal FailureBlock As Long, ByVal LoopExitBlock As Long, ByVal ResultStorage As Long, ByVal OwnerSymbol As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long, ByRef Rules() As GrammarRule, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Edges() As IrEdge, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim LocationIndex As Long = IrLocationForSyntax(IfNode, SyntaxNodes, Tokens, Locations, Build)
    Dim ThenBlock As Long = AppendControlIrBlock(FunctionIndex, LocationIndex, Functions, Blocks, Build)
    Dim FalseBlock As Long = AppendControlIrBlock(FunctionIndex, LocationIndex, Functions, Blocks, Build)
    Dim MergeBlock As Long = AppendControlIrBlock(FunctionIndex, LocationIndex, Functions, Blocks, Build)
    If ThenBlock < 0 Or FalseBlock < 0 Or MergeBlock < 0 Then
        LowerIrBlockIf = 0
        Exit Function
    End If
    Dim ConditionExpression As Long = FindControlConditionExpression(IfNode, "Then", Expressions, ExpressionCount, BindingCount, SyntaxNodes, Tokens)
    If ConditionExpression < 0 Then
        LowerIrBlockIf = 0
        Exit Function
    End If
    Dim ConditionValue As Long = LowerSemanticExpressionValue(ConditionExpression, FunctionIndex, CurrentBlock, FailureBlock, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
    Dim BooleanType As Long = FindSemanticType("Boolean", Types, TypeCount)
    If ConditionValue < 0 Then
        LowerIrBlockIf = 0
        Exit Function
    End If
    If Values(ConditionValue).TypeIndex <> BooleanType Then
        Dim ConditionConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, CurrentBlock, IrOpConvert(), BooleanType, FailureBlock, -1, 0, "", LocationIndex, Instructions, Values, Build)
        If ConditionConvert < 0 Or AppendIrInstructionOperand(ConditionConvert, IrOperandValue(), ConditionValue, "", Instructions, Operands, Build) = 0 Then
            LowerIrBlockIf = 0
            Exit Function
        End If
        ConditionValue = Instructions(ConditionConvert).ResultValue
    End If
    If FinishIrConditionalBlock(FunctionIndex, CurrentBlock, ConditionValue, ThenBlock, FalseBlock, LocationIndex, Blocks, Instructions, Operands, Edges, Build) = 0 Then
        LowerIrBlockIf = 0
        Exit Function
    End If
    CurrentBlock = ThenBlock
    Blocks(CurrentBlock).FirstInstruction = Build.InstructionCount
    If LowerIrStructuredRegion(IfNode, ProcedureNode, FunctionIndex, CurrentBlock, FailureBlock, LoopExitBlock, ResultStorage, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Bindings, BindingCount, Rules, Functions, Storages, Blocks, Instructions, Operands, Values, Edges, Locations, Build, SyntaxNodes, Tokens) = 0 Or FinishIrBranchBlock(FunctionIndex, CurrentBlock, MergeBlock, IrEdgeFallthrough(), -1, LocationIndex, Blocks, Instructions, Edges, Build) = 0 Then
        LowerIrBlockIf = 0
        Exit Function
    End If
    CurrentBlock = FalseBlock
    Blocks(CurrentBlock).FirstInstruction = Build.InstructionCount
    Dim PartNode As Long = IfNode + 1
    Dim IfLastNode As Long = SyntaxSubtreeLastNode(IfNode, BindingCount, SyntaxNodes)
    While PartNode <= IfLastNode
        If SyntaxRuleIs(PartNode, "elseif-part", SyntaxNodes, Rules) <> 0 And IrStructuredRegionOwner(PartNode, ProcedureNode, SyntaxNodes, Rules) = IfNode Then
            Dim ElseIfBody As Long = AppendControlIrBlock(FunctionIndex, IrLocationForSyntax(PartNode, SyntaxNodes, Tokens, Locations, Build), Functions, Blocks, Build)
            Dim NextFalse As Long = AppendControlIrBlock(FunctionIndex, IrLocationForSyntax(PartNode, SyntaxNodes, Tokens, Locations, Build), Functions, Blocks, Build)
            Dim ElseIfExpression As Long = FindControlConditionExpression(PartNode, "Then", Expressions, ExpressionCount, BindingCount, SyntaxNodes, Tokens)
            If ElseIfBody < 0 Or NextFalse < 0 Or ElseIfExpression < 0 Then
                LowerIrBlockIf = 0
                Exit Function
            End If
            Dim ElseIfValue As Long = LowerSemanticExpressionValue(ElseIfExpression, FunctionIndex, CurrentBlock, FailureBlock, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
            If ElseIfValue < 0 Then
                LowerIrBlockIf = 0
                Exit Function
            End If
            If Values(ElseIfValue).TypeIndex <> BooleanType Then
                Dim ElseIfConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, CurrentBlock, IrOpConvert(), BooleanType, FailureBlock, -1, 0, "", LocationIndex, Instructions, Values, Build)
                If ElseIfConvert < 0 Or AppendIrInstructionOperand(ElseIfConvert, IrOperandValue(), ElseIfValue, "", Instructions, Operands, Build) = 0 Then
                    LowerIrBlockIf = 0
                    Exit Function
                End If
                ElseIfValue = Instructions(ElseIfConvert).ResultValue
            End If
            If FinishIrConditionalBlock(FunctionIndex, CurrentBlock, ElseIfValue, ElseIfBody, NextFalse, LocationIndex, Blocks, Instructions, Operands, Edges, Build) = 0 Then
                LowerIrBlockIf = 0
                Exit Function
            End If
            CurrentBlock = ElseIfBody
            Blocks(CurrentBlock).FirstInstruction = Build.InstructionCount
            If LowerIrStructuredRegion(PartNode, ProcedureNode, FunctionIndex, CurrentBlock, FailureBlock, LoopExitBlock, ResultStorage, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Bindings, BindingCount, Rules, Functions, Storages, Blocks, Instructions, Operands, Values, Edges, Locations, Build, SyntaxNodes, Tokens) = 0 Or FinishIrBranchBlock(FunctionIndex, CurrentBlock, MergeBlock, IrEdgeFallthrough(), -1, LocationIndex, Blocks, Instructions, Edges, Build) = 0 Then
                LowerIrBlockIf = 0
                Exit Function
            End If
            CurrentBlock = NextFalse
            Blocks(CurrentBlock).FirstInstruction = Build.InstructionCount
        End If
        PartNode = PartNode + 1
    Wend
    PartNode = IfNode + 1
    While PartNode <= IfLastNode
        If SyntaxRuleIs(PartNode, "else-part", SyntaxNodes, Rules) <> 0 And IrStructuredRegionOwner(PartNode, ProcedureNode, SyntaxNodes, Rules) = IfNode Then
            If LowerIrStructuredRegion(PartNode, ProcedureNode, FunctionIndex, CurrentBlock, FailureBlock, LoopExitBlock, ResultStorage, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Bindings, BindingCount, Rules, Functions, Storages, Blocks, Instructions, Operands, Values, Edges, Locations, Build, SyntaxNodes, Tokens) = 0 Then
                LowerIrBlockIf = 0
                Exit Function
            End If
            Exit While
        End If
        PartNode = PartNode + 1
    Wend
    If FinishIrBranchBlock(FunctionIndex, CurrentBlock, MergeBlock, IrEdgeFallthrough(), -1, LocationIndex, Blocks, Instructions, Edges, Build) = 0 Then
        LowerIrBlockIf = 0
        Exit Function
    End If
    CurrentBlock = MergeBlock
    Blocks(CurrentBlock).FirstInstruction = Build.InstructionCount
    LowerIrBlockIf = 1
End Function

Function LowerSemanticProgramToIr(ByRef SemanticStateValue As SemanticState, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Bindings() As SemanticNodeBinding, ByVal BindingCount As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken, ByRef Program As IrProgram, ByRef Globals() As IrGlobal, ByRef Functions() As IrFunction, ByRef Parameters() As IrParameter, ByRef Storages() As IrStorage, ByRef Blocks() As IrBlock, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Edges() As IrEdge, ByRef Cleanups() As IrCleanup, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Program.FormatVersion = 1
    Program.EntryFunction = -1
    Program.HasErrors = 0
    Build.FailureSyntaxNode = -1
    Build.FailureStage = 0
    Build.FailureDetail = ""

    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If IsIrProcedureSymbol(Symbols(SymbolIndex).SymbolKind) <> 0 Then
            Dim LocationIndex As Long = IrLocationForSyntax(Symbols(SymbolIndex).SyntaxNode, SyntaxNodes, Tokens, Locations, Build)
            Dim AddedFunction As Long = AppendIrFunction(Functions, Build.FunctionCount, Build.FunctionCapacity, SymbolIndex, Symbols(SymbolIndex).SymbolName, Symbols(SymbolIndex).DeclaredType, Symbols(SymbolIndex).Flags, LocationIndex)
            If AddedFunction < 0 Or LocationIndex < 0 Then
                Call AddIrDiagnostic("UBE5000", "IR function or location limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                LowerSemanticProgramToIr = 0
                Exit Function
            End If
            If SymbolIndex = SemanticStateValue.EntrySymbol Then
                Program.EntryFunction = AddedFunction
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend

    ' Register module storage before lowering bodies so every procedure can
    ' resolve a visible module variable to the same target-independent slot.
    SymbolIndex = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolVariable() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolConstant() Then
            If Symbols(SymbolIndex).ParentSymbol >= 0 Then
                If Symbols(SymbolIndex).ParentSymbol < SymbolCount Then
                    If IsIrProcedureSymbol(Symbols(Symbols(SymbolIndex).ParentSymbol).SymbolKind) = 0 Then
                        Dim GlobalLocation As Long = IrLocationForSyntax(Symbols(SymbolIndex).SyntaxNode, SyntaxNodes, Tokens, Locations, Build)
                        Dim GlobalStorage As Long = AppendIrStorage(Storages, Build.StorageCount, Build.StorageCapacity, -1, SymbolIndex, Symbols(SymbolIndex).DeclaredType, IrStorageGlobal(), Symbols(SymbolIndex).Flags, GlobalLocation)
                        If GlobalStorage < 0 Or AppendIrGlobal(Globals, Build.GlobalCount, Build.GlobalCapacity, SymbolIndex, Symbols(SymbolIndex).DeclaredType, GlobalStorage, -1, Symbols(SymbolIndex).Flags, GlobalLocation) < 0 Then
                            Call AddIrDiagnostic("UBE5000", "IR global storage limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            LowerSemanticProgramToIr = 0
                            Exit Function
                        End If
                    End If
                End If
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend

    Dim FunctionIndex As Long = 0
    While FunctionIndex < Build.FunctionCount
        Dim OwnerSymbol As Long = Functions(FunctionIndex).SymbolIndex
        Functions(FunctionIndex).FirstParameter = Build.ParameterCount
        Functions(FunctionIndex).FirstStorage = Build.StorageCount
        Dim ResultStorage As Long = -1
        If Functions(FunctionIndex).ResultType >= 0 Then
            ResultStorage = AppendIrStorage(Storages, Build.StorageCount, Build.StorageCapacity, FunctionIndex, OwnerSymbol, Functions(FunctionIndex).ResultType, IrStorageResult(), 0, Functions(FunctionIndex).LocationIndex)
            If ResultStorage < 0 Then
                Call AddIrDiagnostic("UBE5000", "IR result storage limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                LowerSemanticProgramToIr = 0
                Exit Function
            End If
        End If
        SymbolIndex = 0
        While SymbolIndex < SymbolCount
            If Symbols(SymbolIndex).ParentSymbol = OwnerSymbol Then
                If Symbols(SymbolIndex).SymbolKind = SemanticSymbolParameter() Then
                    Dim ParameterLocation As Long = IrLocationForSyntax(Symbols(SymbolIndex).SyntaxNode, SyntaxNodes, Tokens, Locations, Build)
                    Dim PassingMode As Long = IrPassingByRef()
                    If Symbols(SymbolIndex).Flags And 2 Then
                        PassingMode = IrPassingByVal()
                    End If
                    Dim ParameterStorage As Long = AppendIrStorage(Storages, Build.StorageCount, Build.StorageCapacity, FunctionIndex, SymbolIndex, Symbols(SymbolIndex).DeclaredType, IrStorageParameter(), Symbols(SymbolIndex).Flags, ParameterLocation)
                    If AppendIrParameter(Parameters, Build.ParameterCount, Build.ParameterCapacity, FunctionIndex, SymbolIndex, Symbols(SymbolIndex).DeclaredType, ParameterStorage, Symbols(SymbolIndex).ParameterOrdinal, PassingMode, Symbols(SymbolIndex).Flags, ParameterLocation) < 0 Then
                        Call AddIrDiagnostic("UBE5000", "IR parameter limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                        LowerSemanticProgramToIr = 0
                        Exit Function
                    End If
                Else
                    If Symbols(SymbolIndex).SymbolKind = SemanticSymbolVariable() Or Symbols(SymbolIndex).SymbolKind = SemanticSymbolConstant() Then
                        Dim LocalLocation As Long = IrLocationForSyntax(Symbols(SymbolIndex).SyntaxNode, SyntaxNodes, Tokens, Locations, Build)
                        If AppendIrStorage(Storages, Build.StorageCount, Build.StorageCapacity, FunctionIndex, SymbolIndex, Symbols(SymbolIndex).DeclaredType, IrStorageLocal(), Symbols(SymbolIndex).Flags, LocalLocation) < 0 Then
                            Call AddIrDiagnostic("UBE5000", "IR local storage limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                            LowerSemanticProgramToIr = 0
                            Exit Function
                        End If
                    End If
                End If
            End If
            SymbolIndex = SymbolIndex + 1
        Wend
        Functions(FunctionIndex).ParameterCount = Build.ParameterCount - Functions(FunctionIndex).FirstParameter
        Functions(FunctionIndex).StorageCount = Build.StorageCount - Functions(FunctionIndex).FirstStorage
        Functions(FunctionIndex).FirstBlock = Build.BlockCount
        Dim FunctionLocation As Long = Functions(FunctionIndex).LocationIndex
        Dim EntryBlock As Long = AppendIrBlock(Blocks, Build.BlockCount, Build.BlockCapacity, FunctionIndex, 0, 0, FunctionLocation)
        Dim ReturnBlock As Long = AppendIrBlock(Blocks, Build.BlockCount, Build.BlockCapacity, FunctionIndex, 1, 0, FunctionLocation)
        Dim FailureBlock As Long = AppendIrBlock(Blocks, Build.BlockCount, Build.BlockCapacity, FunctionIndex, 2, 1, FunctionLocation)
        If EntryBlock < 0 Or ReturnBlock < 0 Or FailureBlock < 0 Then
            Call AddIrDiagnostic("UBE5000", "IR block limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            LowerSemanticProgramToIr = 0
            Exit Function
        End If
        Functions(FunctionIndex).EntryBlock = EntryBlock
        Functions(FunctionIndex).ReturnBlock = ReturnBlock
        Functions(FunctionIndex).BlockCount = 3
        Blocks(EntryBlock).FirstInstruction = Build.InstructionCount

        Dim CurrentBlock As Long = EntryBlock
        Dim InitializeStorage As Long = Functions(FunctionIndex).FirstStorage
        While InitializeStorage < Functions(FunctionIndex).FirstStorage + Functions(FunctionIndex).StorageCount
            If Storages(InitializeStorage).StorageKind <> IrStorageParameter() Then
                Dim DefaultInstruction As Long = AppendTypedIrValueInstruction(FunctionIndex, CurrentBlock, IrOpDefaultValue(), Storages(InitializeStorage).TypeIndex, -1, Storages(InitializeStorage).SymbolIndex, 0, "", Storages(InitializeStorage).LocationIndex, Instructions, Values, Build)
                Dim DefaultStore As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, CurrentBlock, IrOpStore(), -1, -1, -1, -1, -1, 0, Storages(InitializeStorage).SymbolIndex, 0, "", Storages(InitializeStorage).LocationIndex)
                If DefaultInstruction < 0 Or DefaultStore < 0 Or AppendIrInstructionOperand(DefaultStore, IrOperandStorage(), InitializeStorage, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(DefaultStore, IrOperandValue(), Instructions(DefaultInstruction).ResultValue, "", Instructions, Operands, Build) = 0 Then
                    Call AddIrDiagnostic("UBE5000", "IR local initialization limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    LowerSemanticProgramToIr = 0
                    Exit Function
                End If
                If Storages(InitializeStorage).StorageKind = IrStorageLocal() Then
                    If Storages(InitializeStorage).TypeIndex >= 0 And Storages(InitializeStorage).TypeIndex < TypeCount Then
                        If Types(Storages(InitializeStorage).TypeIndex).TypeKind = 41 Then
                            ' Flags bit 0 with DeactivationInstruction = -1 means
                            ' the initialized owned array remains active until
                            ' every function exit (ordinary or failure). A
                            ' backend must emit that same cleanup on both exits.
                            If AppendIrCleanup(Cleanups, Build.CleanupCount, Build.CleanupCapacity, FunctionIndex, 0, InitializeStorage, IrCleanupArrayStorage(), DefaultStore, -1, 1, Storages(InitializeStorage).LocationIndex) < 0 Then
                                Call AddIrDiagnostic("UBE5000", "IR cleanup record limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                                LowerSemanticProgramToIr = 0
                                Exit Function
                            End If
                        End If
                    End If
                End If
            End If
            InitializeStorage = InitializeStorage + 1
        Wend
        If LowerIrStructuredRegion(Symbols(OwnerSymbol).SyntaxNode, Symbols(OwnerSymbol).SyntaxNode, FunctionIndex, CurrentBlock, FailureBlock, -1, ResultStorage, OwnerSymbol, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Bindings, BindingCount, Rules, Functions, Storages, Blocks, Instructions, Operands, Values, Edges, Locations, Build, SyntaxNodes, Tokens) = 0 Then
            Dim FailureLine As Long = 0
            If Build.FailureSyntaxNode >= 0 Then
                FailureLine = Tokens(SyntaxNodes(Build.FailureSyntaxNode).FirstToken).LineNumber
            End If
            Call AddIrDiagnostic("UBE5010", "procedure body could not be represented in typed control-flow IR: " & Symbols(OwnerSymbol).SymbolName & " at line " & LongToString(FailureLine) & " stage " & LongToString(Build.FailureStage) & " " & Build.FailureDetail, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            LowerSemanticProgramToIr = 0
            Exit Function
        End If
        If FinishIrBranchBlock(FunctionIndex, CurrentBlock, ReturnBlock, IrEdgeFallthrough(), -1, FunctionLocation, Blocks, Instructions, Edges, Build) = 0 Then
            Call AddIrDiagnostic("UBE5000", "IR final branch limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            LowerSemanticProgramToIr = 0
            Exit Function
        End If

        Blocks(ReturnBlock).FirstInstruction = Build.InstructionCount
        Dim ReturnValue As Long = -1
        If ResultStorage >= 0 Then
            Dim ReturnLoad As Long = AppendTypedIrValueInstruction(FunctionIndex, ReturnBlock, IrOpLoad(), Functions(FunctionIndex).ResultType, -1, OwnerSymbol, 0, "", FunctionLocation, Instructions, Values, Build)
            If ReturnLoad < 0 Or AppendIrInstructionOperand(ReturnLoad, IrOperandStorage(), ResultStorage, "", Instructions, Operands, Build) = 0 Then
                Call AddIrDiagnostic("UBE5000", "IR return value limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                LowerSemanticProgramToIr = 0
                Exit Function
            End If
            ReturnValue = Instructions(ReturnLoad).ResultValue
        End If
        Dim ReturnInstruction As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, ReturnBlock, IrOpReturn(), -1, Functions(FunctionIndex).ResultType, -1, -1, -1, 0, -1, 0, "", FunctionLocation)
        If ReturnValue >= 0 Then
            Call AppendIrInstructionOperand(ReturnInstruction, IrOperandValue(), ReturnValue, "", Instructions, Operands, Build)
        End If
        Blocks(ReturnBlock).InstructionCount = Build.InstructionCount - Blocks(ReturnBlock).FirstInstruction

        Blocks(FailureBlock).FirstInstruction = Build.InstructionCount
        Call AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, FailureBlock, IrOpReturn(), -1, Functions(FunctionIndex).ResultType, -1, -1, -1, 0, -1, 1, "", FunctionLocation)
        Blocks(FailureBlock).InstructionCount = Build.InstructionCount - Blocks(FailureBlock).FirstInstruction
        FunctionIndex = FunctionIndex + 1
    Wend

    ' A fallible instruction has two observable successors even though its
    ' successful continuation remains in the current linear IR block during
    ' RP5. Record the exceptional successor explicitly so verification and
    ' later cleanup lowering never have to infer it from an opcode.
    Dim FailureInstruction As Long = 0
    While FailureInstruction < Build.InstructionCount
        If Instructions(FailureInstruction).FailureTarget >= 0 Then
            If AppendIrEdge(Edges, Build.EdgeCount, Build.EdgeCapacity, Instructions(FailureInstruction).FunctionIndex, Instructions(FailureInstruction).BlockIndex, Instructions(FailureInstruction).FailureTarget, IrEdgeError(), -1, Instructions(FailureInstruction).CleanupDepth, 0, Instructions(FailureInstruction).LocationIndex) < 0 Then
                Call AddIrDiagnostic("UBE5000", "IR failure-edge limit exceeded", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                LowerSemanticProgramToIr = 0
                Exit Function
            End If
        End If
        FailureInstruction = FailureInstruction + 1
    Wend

    If DiagnosticCount <> 0 Then
        Program.HasErrors = 1
        LowerSemanticProgramToIr = 0
    Else
        LowerSemanticProgramToIr = 1
    End If
End Function
