UBE SOURCE 1 MODULE
Attribute UBE_Name = "IrRp7Lowering"

Function LowerComponentStatementToIr(ByVal StatementNode As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal OwnerSymbol As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim TokenIndex As Long = SyntaxNodes(StatementNode).FirstToken
    While TokenIndex <= SyntaxNodes(StatementNode).LastToken And Tokens(TokenIndex).TokenKind >= 9 And Tokens(TokenIndex).TokenKind <= 12
        TokenIndex = TokenIndex + 1
    Wend
    Dim IsLoad As Long = 0
    If TokenIndex <= SyntaxNodes(StatementNode).LastToken Then
        If EqualsFolded(Tokens(TokenIndex).Spelling, "Load") <> 0 Then
            IsLoad = 1
        Else
            If EqualsFolded(Tokens(TokenIndex).Spelling, "Unload") = 0 Then
                LowerComponentStatementToIr = 0
                Exit Function
            End If
        End If
    End If
    Dim TargetToken As Long = TokenIndex + 1
    While TargetToken <= SyntaxNodes(StatementNode).LastToken And Tokens(TargetToken).TokenKind >= 9 And Tokens(TargetToken).TokenKind <= 12
        TargetToken = TargetToken + 1
    Wend
    If TargetToken > SyntaxNodes(StatementNode).LastToken Then
        LowerComponentStatementToIr = 0
        Exit Function
    End If
    Dim TargetSymbol As Long = FindVisibleIrSymbolByName(Tokens(TargetToken).Spelling, OwnerSymbol, FunctionIndex, Symbols, SymbolCount, Storages, Build.StorageCount)
    Dim TargetStorage As Long = FindIrStorageForSymbol(TargetSymbol, FunctionIndex, Storages, Build.StorageCount)
    If TargetSymbol < 0 Or TargetStorage < 0 Then
        Build.FailureDetail = "component lifecycle target"
        LowerComponentStatementToIr = 0
        Exit Function
    End If
    Dim TargetType As Long = Symbols(TargetSymbol).DeclaredType
    If TargetType < 0 Or TargetType >= TypeCount Then
        LowerComponentStatementToIr = 0
        Exit Function
    End If
    Dim ComponentKind As Long = Types(TargetType).TypeKind
    If ComponentKind <> 51 And ComponentKind <> 52 Then
        Build.FailureDetail = "Load/Unload requires a form or control"
        LowerComponentStatementToIr = 0
        Exit Function
    End If
    Dim Opcode As Long = IrOpUnloadComponent()
    If IsLoad <> 0 Then
        Opcode = IrOpLoadComponent()
    End If
    Dim LifecycleInstruction As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, Opcode, -1, -1, -1, -1, FailureBlock, 0, TargetSymbol, 0, "", IrLocationForSyntax(StatementNode, SyntaxNodes, Tokens, Locations, Build))
    If LifecycleInstruction < 0 Or AppendIrInstructionOperand(LifecycleInstruction, IrOperandStorage(), TargetStorage, "", Instructions, Operands, Build) = 0 Or AppendIrInstructionOperand(LifecycleInstruction, IrOperandInteger(), ComponentKind, "", Instructions, Operands, Build) = 0 Then
        LowerComponentStatementToIr = 0
        Exit Function
    End If
    LowerComponentStatementToIr = 1
End Function

Function LowerRaiseEventToIr(ByVal StatementNode As Long, ByVal FunctionIndex As Long, ByVal BlockIndex As Long, ByVal FailureBlock As Long, ByVal OwnerSymbol As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Expressions() As SemanticExpression, ByVal ExpressionCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByRef Storages() As IrStorage, ByRef Instructions() As IrInstruction, ByRef Operands() As IrOperand, ByRef Values() As IrValue, ByRef Locations() As IrLocation, ByRef Build As IrBuildState, ByRef SyntaxNodes() As SyntaxNode, ByRef Tokens() As LexicalToken) As Long
    Dim LocationIndex As Long = IrLocationForSyntax(StatementNode, SyntaxNodes, Tokens, Locations, Build)
    Dim TokenIndex As Long = SyntaxNodes(StatementNode).FirstToken
    While TokenIndex <= SyntaxNodes(StatementNode).LastToken And Tokens(TokenIndex).TokenKind >= 9 And Tokens(TokenIndex).TokenKind <= 12
        TokenIndex = TokenIndex + 1
    Wend
    If TokenIndex > SyntaxNodes(StatementNode).LastToken Or EqualsFolded(Tokens(TokenIndex).Spelling, "RaiseEvent") = 0 Then
        LowerRaiseEventToIr = 0
        Exit Function
    End If
    Dim EventNameToken As Long = TokenIndex + 1
    While EventNameToken <= SyntaxNodes(StatementNode).LastToken And Tokens(EventNameToken).TokenKind >= 9 And Tokens(EventNameToken).TokenKind <= 12
        EventNameToken = EventNameToken + 1
    Wend
    Dim EventOwner As Long = -1
    If OwnerSymbol >= 0 And OwnerSymbol < SymbolCount Then
        EventOwner = Symbols(OwnerSymbol).ParentSymbol
    End If
    Dim EventSymbol As Long = -1
    Dim SymbolIndex As Long = 0
    While SymbolIndex < SymbolCount
        If Symbols(SymbolIndex).SymbolKind = SemanticSymbolEvent() And Symbols(SymbolIndex).ParentSymbol = EventOwner Then
            If EqualsFolded(Symbols(SymbolIndex).SymbolName, Tokens(EventNameToken).Spelling) <> 0 Then
                EventSymbol = SymbolIndex
                Exit While
            End If
        End If
        SymbolIndex = SymbolIndex + 1
    Wend
    If EventSymbol < 0 Then
        Build.FailureDetail = "RaiseEvent target"
        LowerRaiseEventToIr = 0
        Exit Function
    End If
    Dim ExpectedArguments As Long = CountCalledParameters(EventSymbol, Symbols, SymbolCount)
    Dim ArgumentKinds() As Long
    Dim ArgumentValues() As Long
    If ExpectedArguments > 0 Then
        ReDim ArgumentKinds(ExpectedArguments - 1)
        ReDim ArgumentValues(ExpectedArguments - 1)
    End If
    Dim OpenToken As Long = EventNameToken + 1
    While OpenToken <= SyntaxNodes(StatementNode).LastToken And Tokens(OpenToken).TokenKind >= 9 And Tokens(OpenToken).TokenKind <= 12
        OpenToken = OpenToken + 1
    Wend
    Dim CloseToken As Long = SyntaxNodes(StatementNode).LastToken
    While CloseToken > OpenToken And Tokens(CloseToken).TokenKind >= 9 And Tokens(CloseToken).TokenKind <= 12
        CloseToken = CloseToken - 1
    Wend
    Dim ArgumentCount As Long = 0
    If OpenToken <= CloseToken And Tokens(OpenToken).Spelling = "(" And Tokens(CloseToken).Spelling = ")" Then
        Dim ArgumentFirst As Long = OpenToken + 1
        Dim ScanToken As Long = ArgumentFirst
        Dim Depth As Long = 0
        While ScanToken <= CloseToken
            Dim EndsArgument As Long = 0
            If ScanToken = CloseToken Then
                If ArgumentFirst < CloseToken Then
                    EndsArgument = 1
                End If
            Else
                If Tokens(ScanToken).Spelling = "(" Then
                    Depth = Depth + 1
                Else
                    If Tokens(ScanToken).Spelling = ")" Then
                        Depth = Depth - 1
                    Else
                        If Tokens(ScanToken).Spelling = "," And Depth = 0 Then
                            EndsArgument = 1
                        End If
                    End If
                End If
            End If
            If EndsArgument <> 0 Then
                If ArgumentCount >= ExpectedArguments Then
                    LowerRaiseEventToIr = 0
                    Exit Function
                End If
                Dim ArgumentLast As Long = ScanToken - 1
                Dim TrimFirst As Long = ArgumentFirst
                Dim TrimLast As Long = ArgumentLast
                While TrimFirst < TrimLast And Tokens(TrimFirst).TokenKind >= 9 And Tokens(TrimFirst).TokenKind <= 12
                    TrimFirst = TrimFirst + 1
                Wend
                While TrimLast > TrimFirst And Tokens(TrimLast).TokenKind >= 9 And Tokens(TrimLast).TokenKind <= 12
                    TrimLast = TrimLast - 1
                Wend
                Dim EventParameter As Long = FindCalledParameterSymbol(EventSymbol, ArgumentCount, Symbols, SymbolCount)
                Dim ArgumentKind As Long = IrOperandValue()
                Dim ArgumentValue As Long = -1
                If EventParameter >= 0 Then
                    If (Symbols(EventParameter).Flags And 2) <> 0 Then
                        ArgumentValue = LowerTokenRangeValue(TrimFirst, TrimLast, FunctionIndex, BlockIndex, FailureBlock, OwnerSymbol, LocationIndex, Types, TypeCount, Expressions, ExpressionCount, Symbols, SymbolCount, Functions, Build.FunctionCount, Storages, Instructions, Operands, Values, Locations, Build, SyntaxNodes, Tokens)
                        If ArgumentValue >= 0 Then
                            If Values(ArgumentValue).TypeIndex <> Symbols(EventParameter).DeclaredType Then
                                Dim ArgumentConvert As Long = AppendTypedIrValueInstruction(FunctionIndex, BlockIndex, IrOpConvert(), Symbols(EventParameter).DeclaredType, FailureBlock, EventParameter, 0, "", LocationIndex, Instructions, Values, Build)
                                If ArgumentConvert >= 0 Then
                                    If AppendIrInstructionOperand(ArgumentConvert, IrOperandValue(), ArgumentValue, "", Instructions, Operands, Build) <> 0 Then
                                        ArgumentValue = Instructions(ArgumentConvert).ResultValue
                                    Else
                                        ArgumentValue = -1
                                    End If
                                End If
                            End If
                        End If
                    Else
                        Dim ArgumentName As String = Tokens(TrimFirst).Spelling
                        Dim ArgumentSymbol As Long = FindVisibleIrSymbolByName(ArgumentName, OwnerSymbol, FunctionIndex, Symbols, SymbolCount, Storages, Build.StorageCount)
                        ArgumentValue = FindIrStorageForSymbol(ArgumentSymbol, FunctionIndex, Storages, Build.StorageCount)
                        ArgumentKind = IrOperandStorage()
                    End If
                End If
                If EventParameter < 0 Or ArgumentValue < 0 Then
                    LowerRaiseEventToIr = 0
                    Exit Function
                End If
                ArgumentKinds(ArgumentCount) = ArgumentKind
                ArgumentValues(ArgumentCount) = ArgumentValue
                ArgumentCount = ArgumentCount + 1
                ArgumentFirst = ScanToken + 1
            End If
            ScanToken = ScanToken + 1
        Wend
    End If
    If ArgumentCount <> ExpectedArguments Then
        Build.FailureDetail = "RaiseEvent argument count"
        LowerRaiseEventToIr = 0
        Exit Function
    End If
    Dim RaiseInstruction As Long = AppendIrInstruction(Instructions, Build.InstructionCount, Build.InstructionCapacity, FunctionIndex, BlockIndex, IrOpRaiseEvent(), -1, -1, -1, -1, FailureBlock, 0, EventSymbol, 0, Symbols(EventSymbol).SymbolName, LocationIndex)
    If RaiseInstruction < 0 Or AppendIrInstructionOperand(RaiseInstruction, IrOperandInteger(), EventSymbol, "", Instructions, Operands, Build) = 0 Then
        LowerRaiseEventToIr = 0
        Exit Function
    End If
    Dim AppendArgument As Long = 0
    While AppendArgument < ArgumentCount
        If AppendIrInstructionOperand(RaiseInstruction, ArgumentKinds(AppendArgument), ArgumentValues(AppendArgument), "", Instructions, Operands, Build) = 0 Then
            LowerRaiseEventToIr = 0
            Exit Function
        End If
        AppendArgument = AppendArgument + 1
    Wend
    LowerRaiseEventToIr = 1
End Function
