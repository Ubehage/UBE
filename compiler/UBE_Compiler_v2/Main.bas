Intrinsic Function StringLength(ByVal Value As String) As Long
End Function
Intrinsic Function StringByteAt(ByVal Value As String, ByVal Index As Long) As Long
End Function
Intrinsic Function StringSlice(ByVal Value As String, ByVal Start As Long, ByVal Length As Long) As String
End Function
Intrinsic Function StringIndexOf(ByVal Value As String, ByVal Needle As String, ByVal Start As Long) As Long
End Function
Intrinsic Function StringFromByte(ByVal Value As Long) As String
End Function
Intrinsic Function LongToString(ByVal Value As Long) As String
End Function
Intrinsic Function CommandArgumentCount() As Long
End Function
Intrinsic Function CommandArgument(ByVal Index As Long) As String
End Function
Intrinsic Function ReadAllText(ByVal Path As String) As String
End Function
Intrinsic Function WriteAllText(ByVal Path As String, ByVal Contents As String) As Long
End Function

Intrinsic Function CompilerDeleteFile(ByVal Path As String) As Long
End Function

Intrinsic Function CompilerValidateResource(ByVal Path As String) As Long
End Function

Intrinsic Function CompilerResourceLlvmEscape(ByVal Path As String) As String
End Function

Intrinsic Function CompilerValidateLibraryBundle(ByVal Path As String, ByVal TargetTriple As String, ByVal RequiredVersion As String, ByVal RequiredInterface As String) As Long
End Function
Intrinsic Function StringArrayJoin(ByRef Values() As String, ByVal Count As Long) As String
End Function
Intrinsic Function UnicodeIsLetter(ByVal CodePoint As Long) As Long
End Function
Intrinsic Function UnicodeSimpleFoldCodePoint(ByVal CodePoint As Long) As Long
End Function

Type Token
    TokenKind As Long
    StartByte As Long
    ByteLength As Long
    Spelling As String
    Decoded As String
End Type

Type SourceFile
    SourceId As Long
    FilePath As String
    Contents As String
    CombinedStart As Long
    ByteLength As Long
End Type

Type Diagnostic
    DiagnosticCode As String
    StartByte As Long
    ByteLength As Long
    DiagnosticMessage As String
End Type

Type ProcedureSyntax
    ProcedureKind As Long
    HeaderToken As Long
    EndToken As Long
    PrintExpressionNode As Long
    ResultExpressionNode As Long
End Type

Type SyntaxNode
    NodeKind As Long
    SourceToken As Long
    LeftNode As Long
    RightNode As Long
    OperatorToken As Long
    ResolvedType As Long
End Type

Type ProcedureDeclarationSyntax
    ProcedureKind As Long
    NameToken As Long
    HeaderToken As Long
    EndToken As Long
    IsIntrinsic As Long
    FirstParameter As Long
    ParameterCount As Long
    ReturnTypeToken As Long
End Type

Type ParameterSyntax
    OwnerProcedure As Long
    NameToken As Long
    TypeToken As Long
    PassingMode As Long
    IsDynamicArray As Long
End Type

Type LocalDeclarationSyntax
    OwnerProcedure As Long
    NameToken As Long
    TypeToken As Long
    IsDynamicArray As Long
    InitializerFirstToken As Long
    InitializerTokenCount As Long
    InitializerNode As Long
End Type

Type StatementSyntax
    OwnerProcedure As Long
    StatementKind As Long
    FirstToken As Long
    LastToken As Long
    OperatorToken As Long
    ValueNode As Long
    TargetNode As Long
    Flags As Long
End Type

Type IrInstruction
    Opcode As Long
    OwnerProcedure As Long
    ResultType As Long
    OperandA As Long
    OperandB As Long
    SourceToken As Long
    Flags As Long
End Type

Type IrProcedure
    SourceProcedure As Long
    FirstInstruction As Long
    InstructionCount As Long
End Type

Type LlvmEmitterState
    NextRegister As Long
    NextLabel As Long
    NextString As Long
    Failed As Long
    CurrentTerminated As Long
End Type

Sub LlvmTypeName(ByVal TypeId As Long, ByRef Result As String)
    If TypeId >= 100000 Then
        Result = "ptr"
        Exit Sub
    End If
    If TypeId = 1 Then
        Result = "i1"
    Else
        If TypeId = 2 Or TypeId = 4 Then
            Result = "i32"
        Else
            If TypeId = 3 Then
                Result = "ptr"
            Else
                If TypeId = 5 Then
                    Result = "i64"
                Else
                    If TypeId = 6 Then
                        Result = "double"
                    Else
                        If TypeId >= 1000 Then
                            Result = "%ube.type." & LongToString(TypeId - 1000)
                        Else
                            Result = "void"
                        End If
                    End If
                End If
            End If
        End If
    End If
End Sub

Sub EmitSimpleStatement(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementIndex As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String)
    Dim Kind As Long = Statements(StatementIndex).StatementKind
    If Kind = 7 Then
        Dim DeclarationLocal As Long = -1
        Dim LocalIndex As Long = 0
        While LocalIndex < LocalCount
            If Locals(LocalIndex).OwnerProcedure = Owner Then
                If EqualsIdentifier(Tokens(Locals(LocalIndex).NameToken).Spelling, Tokens(Statements(StatementIndex).OperatorToken).Spelling) <> 0 Then
                    DeclarationLocal = LocalIndex
                    Exit While
                End If
            End If
            LocalIndex = LocalIndex + 1
        Wend
        If DeclarationLocal < 0 Then
            State.Failed = 1
            Exit Sub
        End If
        If Locals(DeclarationLocal).InitializerNode >= 0 Then
            Dim InitializerOperand As String = ""
            Dim InitializerTypeId As Long = 0
            Call EmitExpression(Tokens, Nodes, Locals(DeclarationLocal).InitializerNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, InitializerOperand, InitializerTypeId)
            If State.Failed <> 0 Then
                Exit Sub
            End If
            Dim InitializerLlvmType As String = ""
            Call LlvmTypeName(InitializerTypeId, InitializerLlvmType)
            Call AppendText(Body, BodyCount, BodyCapacity, "  store " & InitializerLlvmType & " " & InitializerOperand & ", ptr %local." & LongToString(DeclarationLocal) & NewLine)
        End If
        Exit Sub
    End If
    If Kind = 1 Then
        Dim AssignmentAddress As String = ""
        Dim AssignmentTypeId As Long = 0
        Call EmitLvalueAddress(Tokens, Nodes, Statements(StatementIndex).TargetNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, AssignmentAddress, AssignmentTypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Dim AssignmentOperand As String = ""
        Dim AssignmentValueType As Long = 0
        Call EmitExpression(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, AssignmentOperand, AssignmentValueType)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Dim AssignmentLlvmType As String = ""
        Call LlvmTypeName(AssignmentTypeId, AssignmentLlvmType)
        Call AppendText(Body, BodyCount, BodyCapacity, "  store " & AssignmentLlvmType & " " & AssignmentOperand & ", ptr " & AssignmentAddress & NewLine)
        Exit Sub
    End If
    If Kind = 2 Then
        Dim DiscardedOperand As String = ""
        Dim DiscardedType As Long = 0
        Call EmitExpression(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, DiscardedOperand, DiscardedType)
        Exit Sub
    End If
    If Kind = 3 Then
        Dim PrintOperand As String = ""
        Dim PrintTypeId As Long = 0
        Call EmitExpression(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, PrintOperand, PrintTypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        If PrintTypeId = 3 Then
            Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_string(ptr " & PrintOperand & ")" & NewLine)
        Else
            Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_i32(i32 " & PrintOperand & ")" & NewLine)
        End If
        Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_newline()" & NewLine)
        Exit Sub
    End If
    If Kind = 4 Then
        Dim ArrayAddress As String = ""
        Dim ArrayTypeId As Long = 0
        Call EmitLvalueAddress(Tokens, Nodes, Statements(StatementIndex).TargetNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, ArrayAddress, ArrayTypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Dim UpperOperand As String = ""
        Dim UpperTypeId As Long = 0
        Call EmitExpression(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, UpperOperand, UpperTypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Dim OldHandle As String = ""
        Call NextLlvmRegister(State, OldHandle)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & OldHandle & " = load ptr, ptr " & ArrayAddress & NewLine)
        Dim ElementTypeId As Long = ArrayTypeId - 100000
        Dim ElementSize As String = "4"
        If ElementTypeId = 3 Or ElementTypeId = 5 Or ElementTypeId >= 100000 Then
            ElementSize = "8"
        Else
            If ElementTypeId >= 1000 Then
                ElementSize = "ptrtoint (ptr getelementptr (%ube.type." & LongToString(ElementTypeId - 1000) & ", ptr null, i32 1) to i64)"
            End If
        End If
        Dim PreserveFlag As String = "false"
        If Statements(StatementIndex).Flags <> 0 Then
            PreserveFlag = "true"
        End If
        Dim NewHandle As String = ""
        Call NextLlvmRegister(State, NewHandle)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & NewHandle & " = call ptr @ube_array_redim(ptr " & OldHandle & ", i32 0, i32 " & UpperOperand & ", i64 " & ElementSize & ", i1 " & PreserveFlag & ")" & NewLine)
        Call AppendText(Body, BodyCount, BodyCapacity, "  store ptr " & NewHandle & ", ptr " & ArrayAddress & NewLine)
        Exit Sub
    End If
    State.Failed = 1
End Sub

Sub NextLlvmRegister(ByRef State As LlvmEmitterState, ByRef Result As String)
    Result = "%r" & LongToString(State.NextRegister)
    State.NextRegister = State.NextRegister + 1
End Sub

Sub ProcedureLlvmSymbol(ByVal ProcedureIndex As Long, ByRef Result As String)
    Result = "@ube.p" & LongToString(ProcedureIndex)
End Sub

Sub IntrinsicLlvmSymbol(ByVal IntrinsicName As String, ByRef Result As String)
    If EqualsIdentifier(IntrinsicName, "StringLength") <> 0 Then
        Result = "@ube_string_length"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringByteAt") <> 0 Then
        Result = "@ube_string_byte_at"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringSlice") <> 0 Then
        Result = "@ube_string_slice"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringIndexOf") <> 0 Then
        Result = "@ube_string_index_of"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringFromByte") <> 0 Then
        Result = "@ube_string_from_byte"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "LongToString") <> 0 Then
        Result = "@ube_long_to_string"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CommandArgumentCount") <> 0 Then
        Result = "@ube_command_argument_count"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CommandArgument") <> 0 Then
        Result = "@ube_command_argument"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "ReadAllText") <> 0 Then
        Result = "@ube_read_all_text"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "WriteAllText") <> 0 Then
        Result = "@ube_write_all_text"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringArrayJoin") <> 0 Then
        Result = "@ube_string_array_join"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerRunTool") <> 0 Then
        Result = "@ube_compiler_run_tool"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerDeleteFile") <> 0 Then
        Result = "@ube_compiler_delete_file"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerValidateResource") <> 0 Then
        Result = "@ube_compiler_validate_resource"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerResourceLlvmEscape") <> 0 Then
        Result = "@ube_compiler_resource_llvm_escape"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerValidateLibraryBundle") <> 0 Then
        Result = "@ube_compiler_validate_library_bundle"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "UnicodeIsLetter") <> 0 Then
        Result = "@ube_unicode_is_letter"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "UnicodeSimpleFoldCodePoint") <> 0 Then
        Result = "@ube_unicode_simple_fold_code_point"
        Exit Sub
    End If
    Result = ""
End Sub

Function AppendIrInstruction(ByRef Instructions() As IrInstruction, ByRef Count As Long, ByRef Capacity As Long, ByVal Opcode As Long, ByVal OwnerProcedure As Long, ByVal ResultType As Long, ByVal OperandA As Long, ByVal OperandB As Long, ByVal SourceToken As Long, ByVal Flags As Long) As Long
    If Count >= 1000000 Then
        AppendIrInstruction = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 1024
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > 1000000 Then
            NewCapacity = 1000000
        End If
        If Capacity = 0 Then
            ReDim Instructions(NewCapacity - 1)
        Else
            ReDim Preserve Instructions(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Instructions(Count).Opcode = Opcode
    Instructions(Count).OwnerProcedure = OwnerProcedure
    Instructions(Count).ResultType = ResultType
    Instructions(Count).OperandA = OperandA
    Instructions(Count).OperandB = OperandB
    Instructions(Count).SourceToken = SourceToken
    Instructions(Count).Flags = Flags
    AppendIrInstruction = Count
    Count = Count + 1
End Function

Function AppendStatement(ByRef Statements() As StatementSyntax, ByRef Count As Long, ByRef Capacity As Long, ByVal OwnerProcedure As Long, ByVal StatementKind As Long, ByVal FirstToken As Long, ByVal LastToken As Long, ByVal OperatorToken As Long) As Long
    If Count >= 500000 Then
        AppendStatement = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 512
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > 500000 Then
            NewCapacity = 500000
        End If
        If Capacity = 0 Then
            ReDim Statements(NewCapacity - 1)
        Else
            ReDim Preserve Statements(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Statements(Count).OwnerProcedure = OwnerProcedure
    Statements(Count).StatementKind = StatementKind
    Statements(Count).FirstToken = FirstToken
    Statements(Count).LastToken = LastToken
    Statements(Count).OperatorToken = OperatorToken
    Statements(Count).ValueNode = -1
    Statements(Count).TargetNode = -1
    Statements(Count).Flags = 0
    AppendStatement = Count
    Count = Count + 1
End Function

Function AppendLocalDeclaration(ByRef Locals() As LocalDeclarationSyntax, ByRef Count As Long, ByRef Capacity As Long, ByVal OwnerProcedure As Long, ByVal NameToken As Long, ByVal TypeToken As Long, ByVal IsDynamicArray As Long, ByVal InitializerFirstToken As Long, ByVal InitializerTokenCount As Long) As Long
    If Count >= 200000 Then
        AppendLocalDeclaration = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 256
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > 200000 Then
            NewCapacity = 200000
        End If
        If Capacity = 0 Then
            ReDim Locals(NewCapacity - 1)
        Else
            ReDim Preserve Locals(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Locals(Count).OwnerProcedure = OwnerProcedure
    Locals(Count).NameToken = NameToken
    Locals(Count).TypeToken = TypeToken
    Locals(Count).IsDynamicArray = IsDynamicArray
    Locals(Count).InitializerFirstToken = InitializerFirstToken
    Locals(Count).InitializerTokenCount = InitializerTokenCount
    Locals(Count).InitializerNode = -1
    AppendLocalDeclaration = Count
    Count = Count + 1
End Function

Function AppendParameter(ByRef Parameters() As ParameterSyntax, ByRef Count As Long, ByRef Capacity As Long, ByVal OwnerProcedure As Long, ByVal NameToken As Long, ByVal TypeToken As Long, ByVal PassingMode As Long, ByVal IsDynamicArray As Long) As Long
    If Count >= 100000 Then
        AppendParameter = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 128
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > 100000 Then
            NewCapacity = 100000
        End If
        If Capacity = 0 Then
            ReDim Parameters(NewCapacity - 1)
        Else
            ReDim Preserve Parameters(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Parameters(Count).OwnerProcedure = OwnerProcedure
    Parameters(Count).NameToken = NameToken
    Parameters(Count).TypeToken = TypeToken
    Parameters(Count).PassingMode = PassingMode
    Parameters(Count).IsDynamicArray = IsDynamicArray
    AppendParameter = Count
    Count = Count + 1
End Function

Type TypeDeclarationSyntax
    NameToken As Long
    HeaderToken As Long
    EndToken As Long
    FirstField As Long
    FieldCount As Long
End Type

Type FieldDeclarationSyntax
    OwnerType As Long
    NameToken As Long
    TypeToken As Long
    IsDynamicArray As Long
End Type

Function AppendFieldDeclaration(ByRef Fields() As FieldDeclarationSyntax, ByRef Count As Long, ByRef Capacity As Long, ByVal OwnerType As Long, ByVal NameToken As Long, ByVal TypeToken As Long, ByVal IsDynamicArray As Long) As Long
    If Count >= 100000 Then
        AppendFieldDeclaration = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 128
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > 100000 Then
            NewCapacity = 100000
        End If
        If Capacity = 0 Then
            ReDim Fields(NewCapacity - 1)
        Else
            ReDim Preserve Fields(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Fields(Count).OwnerType = OwnerType
    Fields(Count).NameToken = NameToken
    Fields(Count).TypeToken = TypeToken
    Fields(Count).IsDynamicArray = IsDynamicArray
    AppendFieldDeclaration = Count
    Count = Count + 1
End Function

Function AppendTypeDeclaration(ByRef Declarations() As TypeDeclarationSyntax, ByRef Count As Long, ByRef Capacity As Long, ByVal NameToken As Long, ByVal HeaderToken As Long, ByVal EndToken As Long) As Long
    If Count >= 10000 Then
        AppendTypeDeclaration = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 32
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > 10000 Then
            NewCapacity = 10000
        End If
        If Capacity = 0 Then
            ReDim Declarations(NewCapacity - 1)
        Else
            ReDim Preserve Declarations(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Declarations(Count).NameToken = NameToken
    Declarations(Count).HeaderToken = HeaderToken
    Declarations(Count).EndToken = EndToken
    Declarations(Count).FirstField = -1
    Declarations(Count).FieldCount = 0
    AppendTypeDeclaration = Count
    Count = Count + 1
End Function

Function AppendProcedureDeclaration(ByRef Procedures() As ProcedureDeclarationSyntax, ByRef Count As Long, ByRef Capacity As Long, ByVal ProcedureKind As Long, ByVal NameToken As Long, ByVal HeaderToken As Long, ByVal EndToken As Long, ByVal IsIntrinsic As Long) As Long
    If Count >= 10000 Then
        AppendProcedureDeclaration = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 64
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > 10000 Then
            NewCapacity = 10000
        End If
        If Capacity = 0 Then
            ReDim Procedures(NewCapacity - 1)
        Else
            ReDim Preserve Procedures(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Procedures(Count).ProcedureKind = ProcedureKind
    Procedures(Count).NameToken = NameToken
    Procedures(Count).HeaderToken = HeaderToken
    Procedures(Count).EndToken = EndToken
    Procedures(Count).IsIntrinsic = IsIntrinsic
    Procedures(Count).FirstParameter = -1
    Procedures(Count).ParameterCount = 0
    Procedures(Count).ReturnTypeToken = -1
    AppendProcedureDeclaration = Count
    Count = Count + 1
End Function

Function AppendSyntaxNode(ByRef Nodes() As SyntaxNode, ByRef Count As Long, ByRef Capacity As Long, ByVal NodeKind As Long, ByVal SourceToken As Long, ByVal LeftNode As Long, ByVal RightNode As Long, ByVal OperatorToken As Long) As Long
    If Count >= 200000 Then
        AppendSyntaxNode = -1
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 256
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > 200000 Then
            NewCapacity = 200000
        End If
        If Capacity = 0 Then
            ReDim Nodes(NewCapacity - 1)
        Else
            ReDim Preserve Nodes(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Nodes(Count).NodeKind = NodeKind
    Nodes(Count).SourceToken = SourceToken
    Nodes(Count).LeftNode = LeftNode
    Nodes(Count).RightNode = RightNode
    Nodes(Count).OperatorToken = OperatorToken
    Nodes(Count).ResolvedType = 0
    AppendSyntaxNode = Count
    Count = Count + 1
End Function

Sub AppendDiagnostic(ByRef Diagnostics() As Diagnostic, ByRef Count As Long, ByVal DiagnosticCode As String, ByVal StartByte As Long, ByVal ByteLength As Long, ByVal DiagnosticMessage As String)
    If Count >= 100 Then
        Exit Sub
    End If
    If Count = 0 Then
        ReDim Diagnostics(0)
    Else
        ReDim Preserve Diagnostics(Count)
    End If
    Diagnostics(Count).DiagnosticCode = DiagnosticCode
    Diagnostics(Count).StartByte = StartByte
    Diagnostics(Count).ByteLength = ByteLength
    Diagnostics(Count).DiagnosticMessage = DiagnosticMessage
    Count = Count + 1
End Sub

Function IsUtf8Continuation(ByVal Value As Long) As Long
    IsUtf8Continuation = 0
    If Value >= 128 And Value <= 191 Then
        IsUtf8Continuation = 1
    End If
End Function

Function Utf8SequenceLength(ByVal Contents As String, ByVal StartByte As Long, ByVal TotalLength As Long) As Long
    Dim FirstByte As Long = StringByteAt(Contents, StartByte)
    If FirstByte < 128 Then
        Utf8SequenceLength = 1
        Exit Function
    End If
    If FirstByte >= 194 And FirstByte <= 223 Then
        If StartByte + 1 >= TotalLength Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        If IsUtf8Continuation(StringByteAt(Contents, StartByte + 1)) = 0 Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        Utf8SequenceLength = 2
        Exit Function
    End If
    If FirstByte >= 224 And FirstByte <= 239 Then
        If StartByte + 2 >= TotalLength Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        Dim SecondByte As Long = StringByteAt(Contents, StartByte + 1)
        Dim ThirdByte As Long = StringByteAt(Contents, StartByte + 2)
        If IsUtf8Continuation(ThirdByte) = 0 Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        If FirstByte = 224 Then
            If SecondByte < 160 Or SecondByte > 191 Then
                Utf8SequenceLength = 0
                Exit Function
            End If
        Else
            If FirstByte = 237 Then
                If SecondByte < 128 Or SecondByte > 159 Then
                    Utf8SequenceLength = 0
                    Exit Function
                End If
            Else
                If IsUtf8Continuation(SecondByte) = 0 Then
                    Utf8SequenceLength = 0
                    Exit Function
                End If
            End If
        End If
        Utf8SequenceLength = 3
        Exit Function
    End If
    If FirstByte >= 240 And FirstByte <= 244 Then
        If StartByte + 3 >= TotalLength Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        Dim FourSecond As Long = StringByteAt(Contents, StartByte + 1)
        If FirstByte = 240 Then
            If FourSecond < 144 Or FourSecond > 191 Then
                Utf8SequenceLength = 0
                Exit Function
            End If
        Else
            If FirstByte = 244 Then
                If FourSecond < 128 Or FourSecond > 143 Then
                    Utf8SequenceLength = 0
                    Exit Function
                End If
            Else
                If IsUtf8Continuation(FourSecond) = 0 Then
                    Utf8SequenceLength = 0
                    Exit Function
                End If
            End If
        End If
        If IsUtf8Continuation(StringByteAt(Contents, StartByte + 2)) = 0 Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        If IsUtf8Continuation(StringByteAt(Contents, StartByte + 3)) = 0 Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        Utf8SequenceLength = 4
        Exit Function
    End If
    Utf8SequenceLength = 0
End Function

Function ValidateUtf8(ByVal Contents As String, ByRef InvalidByte As Long) As Long
    Dim TotalLength As Long = StringLength(Contents)
    Dim Index As Long = 0
    While Index < TotalLength
        Dim SequenceLength As Long = Utf8SequenceLength(Contents, Index, TotalLength)
        If SequenceLength = 0 Then
            InvalidByte = Index
            ValidateUtf8 = 0
            Exit Function
        End If
        Index = Index + SequenceLength
    Wend
    InvalidByte = -1
    ValidateUtf8 = 1
End Function

Sub FindLineAndColumn(ByVal Contents As String, ByVal TargetByte As Long, ByRef LineNumber As Long, ByRef ColumnNumber As Long)
    LineNumber = 1
    ColumnNumber = 1
    Dim Index As Long = 0
    While Index < TargetByte
        Dim Current As Long = StringByteAt(Contents, Index)
        If Current = 10 Then
            LineNumber = LineNumber + 1
            ColumnNumber = 1
        Else
            If Current <> 13 Then
                ColumnNumber = ColumnNumber + 1
            End If
        End If
        Dim CharacterBytes As Long = 1
        If Current >= 128 Then
            CharacterBytes = Utf8SequenceLength(Contents, Index, TargetByte)
            If CharacterBytes = 0 Then
                CharacterBytes = 1
            End If
        End If
        Index = Index + CharacterBytes
    Wend
End Sub

Sub ReportDiagnostics(ByRef Source As SourceFile, ByRef Diagnostics() As Diagnostic, ByVal Count As Long)
    Dim Index As Long = 0
    While Index < Count
        Dim LineNumber As Long = 1
        Dim ColumnNumber As Long = 1
        Call FindLineAndColumn(Source.Contents, Diagnostics(Index).StartByte, LineNumber, ColumnNumber)
        Print Source.FilePath & "(" & LongToString(LineNumber) & "," & LongToString(ColumnNumber) & "): error " & Diagnostics(Index).DiagnosticCode & ": " & Diagnostics(Index).DiagnosticMessage
        Index = Index + 1
    Wend
End Sub

Sub ReportProjectDiagnostics(ByRef Sources() As SourceFile, ByVal SourceCount As Long, ByRef Diagnostics() As Diagnostic, ByVal Count As Long)
    Dim Index As Long = 0
    While Index < Count
        Dim SourceIndex As Long = 0
        Dim MatchIndex As Long = -1
        While SourceIndex < SourceCount
            Dim RangeEnd As Long = Sources(SourceIndex).CombinedStart + Sources(SourceIndex).ByteLength
            If Diagnostics(Index).StartByte >= Sources(SourceIndex).CombinedStart Then
                If Diagnostics(Index).StartByte <= RangeEnd Then
                    MatchIndex = SourceIndex
                    Exit While
                End If
            End If
            SourceIndex = SourceIndex + 1
        Wend
        If MatchIndex < 0 Then
            MatchIndex = SourceCount - 1
        End If
        Dim LocalByte As Long = Diagnostics(Index).StartByte - Sources(MatchIndex).CombinedStart
        If LocalByte < 0 Then
            LocalByte = 0
        End If
        If LocalByte > Sources(MatchIndex).ByteLength Then
            LocalByte = Sources(MatchIndex).ByteLength
        End If
        Dim LineNumber As Long = 1
        Dim ColumnNumber As Long = 1
        Call FindLineAndColumn(Sources(MatchIndex).Contents, LocalByte, LineNumber, ColumnNumber)
        Print Sources(MatchIndex).FilePath & "(" & LongToString(LineNumber) & "," & LongToString(ColumnNumber) & "): error " & Diagnostics(Index).DiagnosticCode & ": " & Diagnostics(Index).DiagnosticMessage
        Index = Index + 1
    Wend
End Sub

Sub AppendToken(ByRef Tokens() As Token, ByRef Count As Long, ByRef Capacity As Long, ByVal Kind As Long, ByVal StartByte As Long, ByVal ByteLength As Long, ByVal Spelling As String, ByVal Decoded As String)
    If Count = Capacity Then
        Dim NewCapacity As Long = 256
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > 250000 Then
            NewCapacity = 250000
        End If
        If Capacity = 0 Then
            ReDim Tokens(NewCapacity - 1)
        Else
            ReDim Preserve Tokens(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Tokens(Count).TokenKind = Kind
    Tokens(Count).StartByte = StartByte
    Tokens(Count).ByteLength = ByteLength
    Tokens(Count).Spelling = Spelling
    Tokens(Count).Decoded = Decoded
    Count = Count + 1
End Sub

Sub AppendText(ByRef Chunks() As String, ByRef Count As Long, ByRef Capacity As Long, ByVal Value As String)
    If Count = Capacity Then
        Dim NewCapacity As Long = 32
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If Capacity = 0 Then
            ReDim Chunks(NewCapacity - 1)
        Else
            ReDim Preserve Chunks(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Chunks(Count) = Value
    Count = Count + 1
End Sub

Sub EscapeLlvmString(ByVal Value As String, ByRef Result As String)
    Dim Chunks() As String
    Dim ChunkCount As Long = 0
    Dim ChunkCapacity As Long = 0
    Dim Index As Long = 0
    Dim Length As Long = StringLength(Value)
    While Index < Length
        Dim Current As Long = StringByteAt(Value, Index)
        If Current >= 32 And Current <= 126 And Current <> 34 And Current <> 92 Then
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, StringFromByte(Current))
        Else
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "\" & StringSlice("0123456789ABCDEF", Current \ 16, 1) & StringSlice("0123456789ABCDEF", Current Mod 16, 1))
        End If
        Index = Index + 1
    Wend
    Result = StringArrayJoin(Chunks, ChunkCount)
End Sub

Function IsIdentifierStart(ByVal Value As Long) As Long
    IsIdentifierStart = 0
    If Value = 95 Or Value >= 65 And Value <= 90 Or Value >= 97 And Value <= 122 Then
        IsIdentifierStart = 1
    End If
End Function

Function IsIdentifierPart(ByVal Value As Long) As Long
    IsIdentifierPart = IsIdentifierStart(Value)
    If Value >= 48 And Value <= 57 Then
        IsIdentifierPart = 1
    End If
End Function

Function DecodeUtf8CodePoint(ByVal Contents As String, ByVal StartByte As Long, ByVal SequenceLength As Long) As Long
    Dim FirstByte As Long = StringByteAt(Contents, StartByte)
    If SequenceLength = 1 Then
        DecodeUtf8CodePoint = FirstByte
        Exit Function
    End If
    Dim SecondByte As Long = StringByteAt(Contents, StartByte + 1)
    If SequenceLength = 2 Then
        DecodeUtf8CodePoint = (FirstByte - 192) * 64 + SecondByte - 128
        Exit Function
    End If
    Dim ThirdByte As Long = StringByteAt(Contents, StartByte + 2)
    If SequenceLength = 3 Then
        DecodeUtf8CodePoint = (FirstByte - 224) * 4096 + (SecondByte - 128) * 64 + ThirdByte - 128
        Exit Function
    End If
    Dim FourthByte As Long = StringByteAt(Contents, StartByte + 3)
    DecodeUtf8CodePoint = (FirstByte - 240) * 262144 + (SecondByte - 128) * 4096 + (ThirdByte - 128) * 64 + FourthByte - 128
End Function

Function IdentifierStartLength(ByVal Contents As String, ByVal StartByte As Long, ByVal TotalLength As Long) As Long
    Dim FirstByte As Long = StringByteAt(Contents, StartByte)
    If FirstByte < 128 Then
        IdentifierStartLength = IsIdentifierStart(FirstByte)
        Exit Function
    End If
    Dim SequenceLength As Long = Utf8SequenceLength(Contents, StartByte, TotalLength)
    If SequenceLength = 0 Then
        IdentifierStartLength = 0
        Exit Function
    End If
    Dim CodePoint As Long = DecodeUtf8CodePoint(Contents, StartByte, SequenceLength)
    If UnicodeIsLetter(CodePoint) <> 0 Then
        IdentifierStartLength = SequenceLength
    Else
        IdentifierStartLength = 0
    End If
End Function

Function IdentifierPartLength(ByVal Contents As String, ByVal StartByte As Long, ByVal TotalLength As Long) As Long
    Dim FirstByte As Long = StringByteAt(Contents, StartByte)
    If FirstByte < 128 Then
        IdentifierPartLength = IsIdentifierPart(FirstByte)
        Exit Function
    End If
    IdentifierPartLength = IdentifierStartLength(Contents, StartByte, TotalLength)
End Function

Function ContinuationEnd(ByVal Contents As String, ByVal UnderscoreByte As Long, ByVal TotalLength As Long) As Long
    Dim Cursor As Long = UnderscoreByte + 1
    While Cursor < TotalLength
        Dim Current As Long = StringByteAt(Contents, Cursor)
        If Current = 32 Or Current = 9 Then
            Cursor = Cursor + 1
        Else
            Exit While
        End If
    Wend
    If Cursor < TotalLength Then
        If StringByteAt(Contents, Cursor) = 39 Then
            Cursor = Cursor + 1
            While Cursor < TotalLength
                Dim CommentByte As Long = StringByteAt(Contents, Cursor)
                If CommentByte = 10 Or CommentByte = 13 Then
                    Exit While
                End If
                Cursor = Cursor + 1
            Wend
        End If
    End If
    If Cursor >= TotalLength Then
        ContinuationEnd = -1
        Exit Function
    End If
    Dim NewlineByte As Long = StringByteAt(Contents, Cursor)
    If NewlineByte = 10 Then
        ContinuationEnd = Cursor + 1
        Exit Function
    End If
    If NewlineByte = 13 Then
        If Cursor + 1 < TotalLength Then
            If StringByteAt(Contents, Cursor + 1) = 10 Then
                ContinuationEnd = Cursor + 2
                Exit Function
            End If
        End If
        ContinuationEnd = -2
        Exit Function
    End If
    ContinuationEnd = -1
End Function

Function FoldAsciiByte(ByVal Value As Long) As Long
    FoldAsciiByte = Value
    If Value >= 65 And Value <= 90 Then
        FoldAsciiByte = Value + 32
    End If
End Function

Function EqualsKeyword(ByVal Value As String, ByVal Keyword As String) As Long
    EqualsKeyword = EqualsIdentifier(Value, Keyword)
End Function

Function EqualsIdentifier(ByVal LeftValue As String, ByVal RightValue As String) As Long
    Dim LeftLength As Long = StringLength(LeftValue)
    Dim RightLength As Long = StringLength(RightValue)
    Dim LeftIndex As Long = 0
    Dim RightIndex As Long = 0
    While LeftIndex < LeftLength And RightIndex < RightLength
        Dim LeftBytes As Long = Utf8SequenceLength(LeftValue, LeftIndex, LeftLength)
        Dim RightBytes As Long = Utf8SequenceLength(RightValue, RightIndex, RightLength)
        If LeftBytes = 0 Or RightBytes = 0 Then
            EqualsIdentifier = 0
            Exit Function
        End If
        Dim LeftCodePoint As Long = DecodeUtf8CodePoint(LeftValue, LeftIndex, LeftBytes)
        Dim RightCodePoint As Long = DecodeUtf8CodePoint(RightValue, RightIndex, RightBytes)
        If UnicodeSimpleFoldCodePoint(LeftCodePoint) <> UnicodeSimpleFoldCodePoint(RightCodePoint) Then
            EqualsIdentifier = 0
            Exit Function
        End If
        LeftIndex = LeftIndex + LeftBytes
        RightIndex = RightIndex + RightBytes
    Wend
    If LeftIndex = LeftLength And RightIndex = RightLength Then
        EqualsIdentifier = 1
    Else
        EqualsIdentifier = 0
    End If
End Function

Function LexSource(ByVal SourceText As String, ByRef Tokens() As Token, ByRef Count As Long, ByRef Capacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim Length As Long = StringLength(SourceText)
    Dim Index As Long = 0
    Dim PreviousWasHorizontalSpace As Long = 0
    While Index < Length
        ' Keep one slot for the end-of-file token. This bounded ceiling matches
        ' the v3 bootstrap profile and is large enough for the RP5 compiler.
        If Count >= 249999 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE1003", Index, 0, "token limit exceeded")
            LexSource = 1
            Exit Function
        End If
        Dim Current As Long = StringByteAt(SourceText, Index)
        Dim ContinuedAt As Long = -1
        If PreviousWasHorizontalSpace <> 0 And Current = 95 Then
            ContinuedAt = ContinuationEnd(SourceText, Index, Length)
        End If
        If ContinuedAt = -2 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE1002", Index, 1, "lone carriage return is not a valid line ending")
            LexSource = 1
            Exit Function
        End If
        If ContinuedAt >= 0 Then
            Index = ContinuedAt
            PreviousWasHorizontalSpace = 1
        Else
        If Current = 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE1001", Index, 1, "source contains a NUL byte")
            LexSource = 1
            Exit Function
        End If
        If Current = 32 Or Current = 9 Then
            Index = Index + 1
            PreviousWasHorizontalSpace = 1
        Else
            PreviousWasHorizontalSpace = 0
            If Current = 39 Then
                Dim ApostropheCommentStart As Long = Index
                Index = Index + 1
                While Index < Length
                    Dim ApostropheCommentByte As Long = StringByteAt(SourceText, Index)
                    If ApostropheCommentByte = 10 Or ApostropheCommentByte = 13 Then
                        Exit While
                    End If
                    Index = Index + 1
                Wend
                Call AppendToken(Tokens, Count, Capacity, 9, ApostropheCommentStart, Index - ApostropheCommentStart, StringSlice(SourceText, ApostropheCommentStart, Index - ApostropheCommentStart), StringSlice(SourceText, ApostropheCommentStart + 1, Index - ApostropheCommentStart - 1))
            Else
            If Current = 10 Or Current = 13 Then
                Dim NewlineStart As Long = Index
                If Current = 13 Then
                    Index = Index + 1
                    If Index < Length Then
                        If StringByteAt(SourceText, Index) = 10 Then
                            Index = Index + 1
                        Else
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE1002", NewlineStart, 1, "lone carriage return is not a valid line ending")
                            LexSource = 1
                            Exit Function
                        End If
                    Else
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE1002", NewlineStart, 1, "lone carriage return is not a valid line ending")
                        LexSource = 1
                        Exit Function
                    End If
                Else
                    Index = Index + 1
                End If
                Call AppendToken(Tokens, Count, Capacity, 4, NewlineStart, Index - NewlineStart, StringSlice(SourceText, NewlineStart, Index - NewlineStart), "")
            Else
                Dim IdentifierFirstBytes As Long = IdentifierStartLength(SourceText, Index, Length)
                If IdentifierFirstBytes <> 0 Then
                    Dim IdentifierStart As Long = Index
                    Index = Index + IdentifierFirstBytes
                    While Index < Length
                        Dim IdentifierPartBytes As Long = IdentifierPartLength(SourceText, Index, Length)
                        If IdentifierPartBytes <> 0 Then
                            Index = Index + IdentifierPartBytes
                        Else
                            Exit While
                        End If
                    Wend
                    Dim IdentifierText As String = StringSlice(SourceText, IdentifierStart, Index - IdentifierStart)
                    If EqualsKeyword(IdentifierText, "Rem") <> 0 Then
                        While Index < Length
                            Dim RemCommentByte As Long = StringByteAt(SourceText, Index)
                            If RemCommentByte = 10 Or RemCommentByte = 13 Then
                                Exit While
                            End If
                            Index = Index + 1
                        Wend
                        Call AppendToken(Tokens, Count, Capacity, 9, IdentifierStart, Index - IdentifierStart, StringSlice(SourceText, IdentifierStart, Index - IdentifierStart), StringSlice(SourceText, IdentifierStart + 3, Index - IdentifierStart - 3))
                    Else
                        Call AppendToken(Tokens, Count, Capacity, 1, IdentifierStart, Index - IdentifierStart, IdentifierText, IdentifierText)
                    End If
                Else
                    If Current >= 48 And Current <= 57 Then
                        Dim IntegerStart As Long = Index
                        Index = Index + 1
                        While Index < Length
                            Dim Digit As Long = StringByteAt(SourceText, Index)
                            If Digit >= 48 And Digit <= 57 Then
                                Index = Index + 1
                            Else
                                Exit While
                            End If
                        Wend
                        Dim IntegerText As String = StringSlice(SourceText, IntegerStart, Index - IntegerStart)
                        Call AppendToken(Tokens, Count, Capacity, 2, IntegerStart, Index - IntegerStart, IntegerText, IntegerText)
                    Else
                        If Current = 34 Then
                            Dim StringStart As Long = Index
                            Index = Index + 1
                            Dim StringSegmentStart As Long = Index
                            Dim DecodedString As String = ""
                            Dim StringClosed As Long = 0
                            While Index < Length
                                Dim StringCurrent As Long = StringByteAt(SourceText, Index)
                                If StringCurrent = 10 Or StringCurrent = 13 Then
                                    Exit While
                                End If
                                If StringCurrent = 34 Then
                                    If Index + 1 < Length Then
                                        If StringByteAt(SourceText, Index + 1) = 34 Then
                                            DecodedString = DecodedString & StringSlice(SourceText, StringSegmentStart, Index - StringSegmentStart) & StringFromByte(34)
                                            Index = Index + 2
                                            StringSegmentStart = Index
                                        Else
                                            DecodedString = DecodedString & StringSlice(SourceText, StringSegmentStart, Index - StringSegmentStart)
                                            StringClosed = 1
                                            Exit While
                                        End If
                                    Else
                                        DecodedString = DecodedString & StringSlice(SourceText, StringSegmentStart, Index - StringSegmentStart)
                                        StringClosed = 1
                                        Exit While
                                    End If
                                Else
                                    Index = Index + 1
                                End If
                            Wend
                            If StringClosed = 0 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE1004", StringStart, Index - StringStart, "unterminated string literal")
                                LexSource = 1
                                Exit Function
                            End If
                            Call AppendToken(Tokens, Count, Capacity, 3, StringStart, Index - StringStart + 1, StringSlice(SourceText, StringStart, Index - StringStart + 1), DecodedString)
                            Index = Index + 1
                        Else
                            If Current < 32 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE1006", Index, 1, "invalid control character")
                                LexSource = 1
                                Exit Function
                            End If
                            Dim PunctuationKind As Long = 8
                            Dim PunctuationLength As Long = 1
                            If Current = 40 Then
                                PunctuationKind = 5
                            Else
                                If Current = 41 Then
                                    PunctuationKind = 6
                                Else
                                    If Current = 61 Then
                                        PunctuationKind = 7
                                    Else
                                        If Current = 60 And Index + 1 < Length Then
                                            Dim LessNext As Long = StringByteAt(SourceText, Index + 1)
                                            If LessNext = 61 Or LessNext = 62 Then
                                                PunctuationLength = 2
                                            End If
                                        Else
                                            If Current = 62 And Index + 1 < Length Then
                                                If StringByteAt(SourceText, Index + 1) = 61 Then
                                                    PunctuationLength = 2
                                                End If
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                            Dim PunctuationText As String = StringSlice(SourceText, Index, PunctuationLength)
                            Call AppendToken(Tokens, Count, Capacity, PunctuationKind, Index, PunctuationLength, PunctuationText, PunctuationText)
                            Index = Index + PunctuationLength
                        End If
                    End If
                End If
            End If
            End If
        End If
        End If
    Wend
    Call AppendToken(Tokens, Count, Capacity, 0, Length, 0, "", "")
    LexSource = 0
End Function

Function ParseStringPrimary(ByRef Tokens() As Token, ByVal TokenCount As Long, ByRef Cursor As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    If Cursor >= TokenCount Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2010", 0, 0, "expected string expression")
        ParseStringPrimary = -1
        Exit Function
    End If
    If Tokens(Cursor).TokenKind = 3 Then
        ParseStringPrimary = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 1, Cursor, -1, -1, -1)
        Cursor = Cursor + 1
        Exit Function
    End If
    If Tokens(Cursor).TokenKind = 5 Then
        Dim OpenToken As Long = Cursor
        Cursor = Cursor + 1
        Dim InnerNode As Long = ParseStringExpression(Tokens, TokenCount, Cursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
        If InnerNode < 0 Then
            ParseStringPrimary = -1
            Exit Function
        End If
        If Cursor >= TokenCount Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2011", Tokens(OpenToken).StartByte, Tokens(OpenToken).ByteLength, "expected ')' after expression")
            ParseStringPrimary = -1
            Exit Function
        End If
        If Tokens(Cursor).TokenKind <> 6 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2011", Tokens(Cursor).StartByte, Tokens(Cursor).ByteLength, "expected ')' after expression")
            ParseStringPrimary = -1
            Exit Function
        End If
        Cursor = Cursor + 1
        ParseStringPrimary = InnerNode
        Exit Function
    End If
    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2010", Tokens(Cursor).StartByte, Tokens(Cursor).ByteLength, "expected string expression")
    ParseStringPrimary = -1
End Function

Function ParseStringExpression(ByRef Tokens() As Token, ByVal TokenCount As Long, ByRef Cursor As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim LeftNode As Long = ParseStringPrimary(Tokens, TokenCount, Cursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
    If LeftNode < 0 Then
        ParseStringExpression = -1
        Exit Function
    End If
    While Cursor < TokenCount
        If Tokens(Cursor).Spelling <> "&" Then
            Exit While
        End If
        Dim OperatorToken As Long = Cursor
        Cursor = Cursor + 1
        Dim RightNode As Long = ParseStringPrimary(Tokens, TokenCount, Cursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
        If RightNode < 0 Then
            ParseStringExpression = -1
            Exit Function
        End If
        LeftNode = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 2, OperatorToken, LeftNode, RightNode, OperatorToken)
        If LeftNode < 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2005", Tokens(OperatorToken).StartByte, Tokens(OperatorToken).ByteLength, "syntax node limit exceeded")
            ParseStringExpression = -1
            Exit Function
        End If
    Wend
    ParseStringExpression = LeftNode
End Function

Sub EvaluateStringExpression(ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Tokens() As Token, ByRef Result As String)
    If Nodes(NodeIndex).NodeKind = 1 Then
        Result = Tokens(Nodes(NodeIndex).SourceToken).Decoded
        Exit Sub
    End If
    Dim LeftValue As String = ""
    Dim RightValue As String = ""
    Call EvaluateStringExpression(Nodes, Nodes(NodeIndex).LeftNode, Tokens, LeftValue)
    Call EvaluateStringExpression(Nodes, Nodes(NodeIndex).RightNode, Tokens, RightValue)
    Result = LeftValue & RightValue
End Sub

Function ParseIntegerPrimary(ByRef Tokens() As Token, ByVal TokenCount As Long, ByRef Cursor As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    If Cursor >= TokenCount Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2012", 0, 0, "expected integer expression")
        ParseIntegerPrimary = -1
        Exit Function
    End If
    If Tokens(Cursor).TokenKind = 2 Then
        ParseIntegerPrimary = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 3, Cursor, -1, -1, -1)
        Cursor = Cursor + 1
        Exit Function
    End If
    If Tokens(Cursor).TokenKind = 5 Then
        Dim IntegerOpenToken As Long = Cursor
        Cursor = Cursor + 1
        Dim InnerIntegerNode As Long = ParseIntegerPrimary(Tokens, TokenCount, Cursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
        If InnerIntegerNode < 0 Then
            ParseIntegerPrimary = -1
            Exit Function
        End If
        If Cursor >= TokenCount Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2011", Tokens(IntegerOpenToken).StartByte, Tokens(IntegerOpenToken).ByteLength, "expected ')' after expression")
            ParseIntegerPrimary = -1
            Exit Function
        End If
        If Tokens(Cursor).TokenKind <> 6 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2011", Tokens(Cursor).StartByte, Tokens(Cursor).ByteLength, "expected ')' after expression")
            ParseIntegerPrimary = -1
            Exit Function
        End If
        Cursor = Cursor + 1
        ParseIntegerPrimary = InnerIntegerNode
        Exit Function
    End If
    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2012", Tokens(Cursor).StartByte, Tokens(Cursor).ByteLength, "expected integer expression")
    ParseIntegerPrimary = -1
End Function

Function ExpressionOperatorPrecedence(ByRef Tokens() As Token, ByVal TokenIndex As Long) As Long
    Dim OperatorText As String = Tokens(TokenIndex).Spelling
    If OperatorText = "*" Or OperatorText = "/" Or OperatorText = "\" Or EqualsKeyword(OperatorText, "Mod") <> 0 Then
        ExpressionOperatorPrecedence = 70
        Exit Function
    End If
    If OperatorText = "+" Or OperatorText = "-" Then
        ExpressionOperatorPrecedence = 60
        Exit Function
    End If
    If OperatorText = "&" Then
        ExpressionOperatorPrecedence = 50
        Exit Function
    End If
    If OperatorText = "=" Or OperatorText = "<" Or OperatorText = ">" Or OperatorText = "<>" Or OperatorText = "<=" Or OperatorText = ">=" Then
        ExpressionOperatorPrecedence = 40
        Exit Function
    End If
    If EqualsKeyword(OperatorText, "And") <> 0 Then
        ExpressionOperatorPrecedence = 30
        Exit Function
    End If
    If EqualsKeyword(OperatorText, "Or") <> 0 Then
        ExpressionOperatorPrecedence = 20
        Exit Function
    End If
    ExpressionOperatorPrecedence = 0
End Function

Function ParseGeneralPrimary(ByRef Tokens() As Token, ByVal EndExclusive As Long, ByRef Cursor As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    If Cursor >= EndExclusive Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2220", 0, 0, "expected expression")
        ParseGeneralPrimary = -1
        Exit Function
    End If
    Dim ResultNode As Long = -1
    If Tokens(Cursor).TokenKind = 2 Then
        ResultNode = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 10, Cursor, -1, -1, -1)
        Cursor = Cursor + 1
    Else
        If Tokens(Cursor).TokenKind = 3 Then
            ResultNode = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 11, Cursor, -1, -1, -1)
            Cursor = Cursor + 1
        Else
            If Tokens(Cursor).TokenKind = 1 Then
                ResultNode = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 12, Cursor, -1, -1, -1)
                Cursor = Cursor + 1
            Else
                If Tokens(Cursor).TokenKind = 5 Then
                    Dim GeneralOpenToken As Long = Cursor
                    Cursor = Cursor + 1
                    ResultNode = ParseGeneralExpression(Tokens, EndExclusive, Cursor, 1, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
                    If ResultNode < 0 Then
                        ParseGeneralPrimary = -1
                        Exit Function
                    End If
                    If Cursor >= EndExclusive Or Tokens(Cursor).TokenKind <> 6 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2221", Tokens(GeneralOpenToken).StartByte, Tokens(GeneralOpenToken).ByteLength, "expected ')' after expression")
                        ParseGeneralPrimary = -1
                        Exit Function
                    End If
                    Cursor = Cursor + 1
                Else
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2220", Tokens(Cursor).StartByte, Tokens(Cursor).ByteLength, "expected expression")
                    ParseGeneralPrimary = -1
                    Exit Function
                End If
            End If
        End If
    End If
    If ResultNode < 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2005", Tokens(Cursor - 1).StartByte, Tokens(Cursor - 1).ByteLength, "syntax node limit exceeded")
        ParseGeneralPrimary = -1
        Exit Function
    End If
    While Cursor < EndExclusive
        If Tokens(Cursor).Spelling = "." Then
            Dim MemberOperator As Long = Cursor
            Cursor = Cursor + 1
            If Cursor >= EndExclusive Or Tokens(Cursor).TokenKind <> 1 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2222", Tokens(MemberOperator).StartByte, Tokens(MemberOperator).ByteLength, "expected member name after '.'")
                ParseGeneralPrimary = -1
                Exit Function
            End If
            ResultNode = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 14, Cursor, ResultNode, -1, MemberOperator)
            Cursor = Cursor + 1
        Else
            If Tokens(Cursor).TokenKind = 5 Then
                Dim CallOpenToken As Long = Cursor
                Cursor = Cursor + 1
                Dim FirstArgumentLink As Long = -1
                Dim LastArgumentLink As Long = -1
                While Cursor < EndExclusive And Tokens(Cursor).TokenKind <> 6
                    Dim ArgumentNode As Long = ParseGeneralExpression(Tokens, EndExclusive, Cursor, 1, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
                    If ArgumentNode < 0 Then
                        ParseGeneralPrimary = -1
                        Exit Function
                    End If
                    Dim ArgumentLink As Long = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 17, Tokens(Cursor - 1).StartByte, ArgumentNode, -1, -1)
                    If ArgumentLink < 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2005", Tokens(CallOpenToken).StartByte, Tokens(CallOpenToken).ByteLength, "syntax node limit exceeded")
                        ParseGeneralPrimary = -1
                        Exit Function
                    End If
                    If FirstArgumentLink < 0 Then
                        FirstArgumentLink = ArgumentLink
                    Else
                        Nodes(LastArgumentLink).RightNode = ArgumentLink
                    End If
                    LastArgumentLink = ArgumentLink
                    If Cursor < EndExclusive And Tokens(Cursor).Spelling = "," Then
                        Cursor = Cursor + 1
                        If Cursor >= EndExclusive Or Tokens(Cursor).TokenKind = 6 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2220", Tokens(CallOpenToken).StartByte, Tokens(CallOpenToken).ByteLength, "expected expression")
                            ParseGeneralPrimary = -1
                            Exit Function
                        End If
                    Else
                        Exit While
                    End If
                Wend
                If Cursor >= EndExclusive Or Tokens(Cursor).TokenKind <> 6 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2223", Tokens(CallOpenToken).StartByte, Tokens(CallOpenToken).ByteLength, "expected ')' after arguments")
                    ParseGeneralPrimary = -1
                    Exit Function
                End If
                Cursor = Cursor + 1
                ResultNode = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 13, CallOpenToken, ResultNode, FirstArgumentLink, -1)
            Else
                Exit While
            End If
        End If
    Wend
    ParseGeneralPrimary = ResultNode
End Function

Function ParseGeneralUnary(ByRef Tokens() As Token, ByVal EndExclusive As Long, ByRef Cursor As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    If Cursor < EndExclusive Then
        If Tokens(Cursor).Spelling = "+" Or Tokens(Cursor).Spelling = "-" Or EqualsKeyword(Tokens(Cursor).Spelling, "Not") <> 0 Then
            Dim UnaryOperator As Long = Cursor
            Cursor = Cursor + 1
            Dim UnaryOperand As Long = ParseGeneralUnary(Tokens, EndExclusive, Cursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
            If UnaryOperand < 0 Then
                ParseGeneralUnary = -1
                Exit Function
            End If
            ParseGeneralUnary = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 16, UnaryOperator, UnaryOperand, -1, UnaryOperator)
            Exit Function
        End If
    End If
    ParseGeneralUnary = ParseGeneralPrimary(Tokens, EndExclusive, Cursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
End Function

Function ParseGeneralExpression(ByRef Tokens() As Token, ByVal EndExclusive As Long, ByRef Cursor As Long, ByVal MinimumPrecedence As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim LeftExpression As Long = ParseGeneralUnary(Tokens, EndExclusive, Cursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
    If LeftExpression < 0 Then
        ParseGeneralExpression = -1
        Exit Function
    End If
    While Cursor < EndExclusive
        Dim Precedence As Long = ExpressionOperatorPrecedence(Tokens, Cursor)
        If Precedence < MinimumPrecedence Then
            Exit While
        End If
        Dim BinaryOperator As Long = Cursor
        Cursor = Cursor + 1
        Dim RightExpression As Long = ParseGeneralExpression(Tokens, EndExclusive, Cursor, Precedence + 1, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
        If RightExpression < 0 Then
            ParseGeneralExpression = -1
            Exit Function
        End If
        LeftExpression = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 15, BinaryOperator, LeftExpression, RightExpression, BinaryOperator)
        If LeftExpression < 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2005", Tokens(BinaryOperator).StartByte, Tokens(BinaryOperator).ByteLength, "syntax node limit exceeded")
            ParseGeneralExpression = -1
            Exit Function
        End If
    Wend
    ParseGeneralExpression = LeftExpression
End Function

Function ParseProcedureDeclarations(ByRef Tokens() As Token, ByVal TokenCount As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByRef ProcedureCount As Long, ByRef ProcedureCapacity As Long, ByRef Parameters() As ParameterSyntax, ByRef ParameterCount As Long, ByRef ParameterCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim Index As Long = 0
    While Index + 1 < TokenCount
        Dim DeclarationKind As Long = 0
        If Tokens(Index).TokenKind = 1 Then
            If EqualsKeyword(Tokens(Index).Spelling, "Sub") <> 0 Then
                DeclarationKind = 1
            Else
                If EqualsKeyword(Tokens(Index).Spelling, "Function") <> 0 Then
                    DeclarationKind = 2
                End If
            End If
        End If
        If DeclarationKind <> 0 And Tokens(Index + 1).TokenKind = 1 Then
            Dim DeclarationEnd As Long = -1
            Dim SearchIndex As Long = Index + 2
            While SearchIndex + 1 < TokenCount
                If Tokens(SearchIndex).TokenKind = 1 And EqualsKeyword(Tokens(SearchIndex).Spelling, "End") <> 0 Then
                    If Tokens(SearchIndex + 1).TokenKind = 1 Then
                        If DeclarationKind = 1 And EqualsKeyword(Tokens(SearchIndex + 1).Spelling, "Sub") <> 0 Then
                            DeclarationEnd = SearchIndex + 1
                            Exit While
                        End If
                        If DeclarationKind = 2 And EqualsKeyword(Tokens(SearchIndex + 1).Spelling, "Function") <> 0 Then
                            DeclarationEnd = SearchIndex + 1
                            Exit While
                        End If
                    End If
                End If
                SearchIndex = SearchIndex + 1
            Wend
            If DeclarationEnd < 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2101", Tokens(Index).StartByte, Tokens(Index).ByteLength, "unterminated procedure declaration")
                ParseProcedureDeclarations = 0
                Exit Function
            End If
            Dim ExistingIndex As Long = 0
            While ExistingIndex < ProcedureCount
                If EqualsIdentifier(Tokens(Procedures(ExistingIndex).NameToken).Spelling, Tokens(Index + 1).Spelling) <> 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2100", Tokens(Index + 1).StartByte, Tokens(Index + 1).ByteLength, "duplicate procedure name: " & Tokens(Index + 1).Spelling)
                    ParseProcedureDeclarations = 0
                    Exit Function
                End If
                ExistingIndex = ExistingIndex + 1
            Wend
            Dim IntrinsicFlag As Long = 0
            If Index > 0 Then
                If Tokens(Index - 1).TokenKind = 1 And EqualsKeyword(Tokens(Index - 1).Spelling, "Intrinsic") <> 0 Then
                    IntrinsicFlag = 1
                End If
            End If
            Dim DeclarationIndex As Long = AppendProcedureDeclaration(Procedures, ProcedureCount, ProcedureCapacity, DeclarationKind, Index + 1, Index, DeclarationEnd, IntrinsicFlag)
            If DeclarationIndex < 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2102", Tokens(Index).StartByte, Tokens(Index).ByteLength, "procedure declaration limit exceeded")
                ParseProcedureDeclarations = 0
                Exit Function
            End If
            Procedures(DeclarationIndex).FirstParameter = ParameterCount
            Dim HeaderCursor As Long = Index + 2
            If HeaderCursor < DeclarationEnd Then
                If Tokens(HeaderCursor).TokenKind = 5 Then
                    HeaderCursor = HeaderCursor + 1
                    While HeaderCursor < DeclarationEnd And Tokens(HeaderCursor).TokenKind <> 6
                        Dim ParameterMode As Long = 1
                        If Tokens(HeaderCursor).TokenKind = 1 Then
                            If EqualsKeyword(Tokens(HeaderCursor).Spelling, "ByVal") <> 0 Then
                                ParameterMode = 2
                                HeaderCursor = HeaderCursor + 1
                            Else
                                If EqualsKeyword(Tokens(HeaderCursor).Spelling, "ByRef") <> 0 Then
                                    ParameterMode = 3
                                    HeaderCursor = HeaderCursor + 1
                                Else
                                    If EqualsKeyword(Tokens(HeaderCursor).Spelling, "ParamArray") <> 0 Then
                                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2128", Tokens(HeaderCursor).StartByte, Tokens(HeaderCursor).ByteLength, "ParamArray is not supported by this compiler generation")
                                        ParseProcedureDeclarations = 0
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                        If HeaderCursor >= DeclarationEnd Or Tokens(HeaderCursor).TokenKind <> 1 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2120", Tokens(Index).StartByte, Tokens(Index).ByteLength, "expected parameter name")
                            ParseProcedureDeclarations = 0
                            Exit Function
                        End If
                        Dim ParameterNameToken As Long = HeaderCursor
                        Dim ExistingParameter As Long = Procedures(DeclarationIndex).FirstParameter
                        While ExistingParameter < ParameterCount
                            If EqualsIdentifier(Tokens(Parameters(ExistingParameter).NameToken).Spelling, Tokens(ParameterNameToken).Spelling) <> 0 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2121", Tokens(ParameterNameToken).StartByte, Tokens(ParameterNameToken).ByteLength, "duplicate parameter name: " & Tokens(ParameterNameToken).Spelling)
                                ParseProcedureDeclarations = 0
                                Exit Function
                            End If
                            ExistingParameter = ExistingParameter + 1
                        Wend
                        HeaderCursor = HeaderCursor + 1
                        Dim ParameterIsArray As Long = 0
                        If HeaderCursor < DeclarationEnd And Tokens(HeaderCursor).TokenKind = 5 Then
                            ParameterIsArray = 1
                            HeaderCursor = HeaderCursor + 1
                            If HeaderCursor >= DeclarationEnd Or Tokens(HeaderCursor).TokenKind <> 6 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2122", Tokens(ParameterNameToken).StartByte, Tokens(ParameterNameToken).ByteLength, "dynamic array parameter requires empty parentheses")
                                ParseProcedureDeclarations = 0
                                Exit Function
                            End If
                            HeaderCursor = HeaderCursor + 1
                        End If
                        If HeaderCursor >= DeclarationEnd Or Tokens(HeaderCursor).TokenKind <> 1 Or EqualsKeyword(Tokens(HeaderCursor).Spelling, "As") = 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2123", Tokens(ParameterNameToken).StartByte, Tokens(ParameterNameToken).ByteLength, "parameter requires an explicit As type")
                            ParseProcedureDeclarations = 0
                            Exit Function
                        End If
                        HeaderCursor = HeaderCursor + 1
                        If HeaderCursor >= DeclarationEnd Or Tokens(HeaderCursor).TokenKind <> 1 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2124", Tokens(ParameterNameToken).StartByte, Tokens(ParameterNameToken).ByteLength, "expected parameter type")
                            ParseProcedureDeclarations = 0
                            Exit Function
                        End If
                        Dim NewParameter As Long = AppendParameter(Parameters, ParameterCount, ParameterCapacity, DeclarationIndex, ParameterNameToken, HeaderCursor, ParameterMode, ParameterIsArray)
                        If NewParameter < 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2125", Tokens(ParameterNameToken).StartByte, Tokens(ParameterNameToken).ByteLength, "parameter limit exceeded")
                            ParseProcedureDeclarations = 0
                            Exit Function
                        End If
                        Procedures(DeclarationIndex).ParameterCount = Procedures(DeclarationIndex).ParameterCount + 1
                        HeaderCursor = HeaderCursor + 1
                        If HeaderCursor < DeclarationEnd And Tokens(HeaderCursor).Spelling = "," Then
                            HeaderCursor = HeaderCursor + 1
                        Else
                            Exit While
                        End If
                    Wend
                    If HeaderCursor >= DeclarationEnd Or Tokens(HeaderCursor).TokenKind <> 6 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2126", Tokens(Index).StartByte, Tokens(Index).ByteLength, "expected ')' after parameters")
                        ParseProcedureDeclarations = 0
                        Exit Function
                    End If
                    HeaderCursor = HeaderCursor + 1
                End If
            End If
            If DeclarationKind = 2 Then
                If HeaderCursor >= DeclarationEnd Or Tokens(HeaderCursor).TokenKind <> 1 Or EqualsKeyword(Tokens(HeaderCursor).Spelling, "As") = 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2127", Tokens(Index + 1).StartByte, Tokens(Index + 1).ByteLength, "Function requires an explicit result type")
                    ParseProcedureDeclarations = 0
                    Exit Function
                End If
                HeaderCursor = HeaderCursor + 1
                If HeaderCursor >= DeclarationEnd Or Tokens(HeaderCursor).TokenKind <> 1 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2128", Tokens(Index + 1).StartByte, Tokens(Index + 1).ByteLength, "expected Function result type")
                    ParseProcedureDeclarations = 0
                    Exit Function
                End If
                Procedures(DeclarationIndex).ReturnTypeToken = HeaderCursor
                HeaderCursor = HeaderCursor + 1
            End If
            If HeaderCursor < DeclarationEnd And Tokens(HeaderCursor).TokenKind = 9 Then
                HeaderCursor = HeaderCursor + 1
            End If
            If HeaderCursor >= DeclarationEnd Or Tokens(HeaderCursor).TokenKind <> 4 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2129", Tokens(Index).StartByte, Tokens(Index).ByteLength, "unexpected token in procedure header")
                ParseProcedureDeclarations = 0
                Exit Function
            End If
            Index = DeclarationEnd
        End If
        Index = Index + 1
    Wend
    ParseProcedureDeclarations = 1
End Function

Function ParseTypeDeclarations(ByRef Tokens() As Token, ByVal TokenCount As Long, ByRef Declarations() As TypeDeclarationSyntax, ByRef DeclarationCount As Long, ByRef DeclarationCapacity As Long, ByRef Fields() As FieldDeclarationSyntax, ByRef FieldCount As Long, ByRef FieldCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim Index As Long = 0
    While Index + 1 < TokenCount
        If Tokens(Index).TokenKind = 1 And EqualsKeyword(Tokens(Index).Spelling, "Type") <> 0 And Tokens(Index + 1).TokenKind = 1 Then
            Dim DeclarationEnd As Long = -1
            Dim SearchIndex As Long = Index + 2
            While SearchIndex + 1 < TokenCount
                If Tokens(SearchIndex).TokenKind = 1 And EqualsKeyword(Tokens(SearchIndex).Spelling, "End") <> 0 Then
                    If Tokens(SearchIndex + 1).TokenKind = 1 And EqualsKeyword(Tokens(SearchIndex + 1).Spelling, "Type") <> 0 Then
                        DeclarationEnd = SearchIndex + 1
                        Exit While
                    End If
                End If
                SearchIndex = SearchIndex + 1
            Wend
            If DeclarationEnd < 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2111", Tokens(Index).StartByte, Tokens(Index).ByteLength, "unterminated Type declaration")
                ParseTypeDeclarations = 0
                Exit Function
            End If
            Dim ExistingIndex As Long = 0
            While ExistingIndex < DeclarationCount
                If EqualsIdentifier(Tokens(Declarations(ExistingIndex).NameToken).Spelling, Tokens(Index + 1).Spelling) <> 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2110", Tokens(Index + 1).StartByte, Tokens(Index + 1).ByteLength, "duplicate Type name: " & Tokens(Index + 1).Spelling)
                    ParseTypeDeclarations = 0
                    Exit Function
                End If
                ExistingIndex = ExistingIndex + 1
            Wend
            Dim DeclarationIndex As Long = AppendTypeDeclaration(Declarations, DeclarationCount, DeclarationCapacity, Index + 1, Index, DeclarationEnd)
            If DeclarationIndex < 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2112", Tokens(Index).StartByte, Tokens(Index).ByteLength, "Type declaration limit exceeded")
                ParseTypeDeclarations = 0
                Exit Function
            End If
            Declarations(DeclarationIndex).FirstField = FieldCount
            Dim FieldCursor As Long = Index + 2
            While FieldCursor < DeclarationEnd - 1
                If Tokens(FieldCursor).TokenKind = 4 Or Tokens(FieldCursor).TokenKind = 9 Then
                    FieldCursor = FieldCursor + 1
                Else
                    If Tokens(FieldCursor).TokenKind <> 1 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2113", Tokens(FieldCursor).StartByte, Tokens(FieldCursor).ByteLength, "expected Type field name")
                        ParseTypeDeclarations = 0
                        Exit Function
                    End If
                    Dim FieldNameToken As Long = FieldCursor
                    Dim ExistingField As Long = Declarations(DeclarationIndex).FirstField
                    While ExistingField < FieldCount
                        If EqualsIdentifier(Tokens(Fields(ExistingField).NameToken).Spelling, Tokens(FieldNameToken).Spelling) <> 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2114", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "duplicate field name: " & Tokens(FieldNameToken).Spelling)
                            ParseTypeDeclarations = 0
                            Exit Function
                        End If
                        ExistingField = ExistingField + 1
                    Wend
                    FieldCursor = FieldCursor + 1
                    Dim FieldIsArray As Long = 0
                    If FieldCursor < DeclarationEnd Then
                        If Tokens(FieldCursor).TokenKind = 5 Then
                            FieldIsArray = 1
                            FieldCursor = FieldCursor + 1
                            If FieldCursor >= DeclarationEnd Or Tokens(FieldCursor).TokenKind <> 6 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2115", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "dynamic Type field requires empty parentheses")
                                ParseTypeDeclarations = 0
                                Exit Function
                            End If
                            FieldCursor = FieldCursor + 1
                        End If
                    End If
                    If FieldCursor >= DeclarationEnd Or Tokens(FieldCursor).TokenKind <> 1 Or EqualsKeyword(Tokens(FieldCursor).Spelling, "As") = 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2116", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "Type field requires an explicit As type")
                        ParseTypeDeclarations = 0
                        Exit Function
                    End If
                    FieldCursor = FieldCursor + 1
                    If FieldCursor >= DeclarationEnd Or Tokens(FieldCursor).TokenKind <> 1 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2117", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "expected Type field type")
                        ParseTypeDeclarations = 0
                        Exit Function
                    End If
                    Dim NewField As Long = AppendFieldDeclaration(Fields, FieldCount, FieldCapacity, DeclarationIndex, FieldNameToken, FieldCursor, FieldIsArray)
                    If NewField < 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2118", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "Type field limit exceeded")
                        ParseTypeDeclarations = 0
                        Exit Function
                    End If
                    Declarations(DeclarationIndex).FieldCount = Declarations(DeclarationIndex).FieldCount + 1
                    FieldCursor = FieldCursor + 1
                    While FieldCursor < DeclarationEnd And Tokens(FieldCursor).TokenKind <> 4
                        If Tokens(FieldCursor).TokenKind <> 9 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2119", Tokens(FieldCursor).StartByte, Tokens(FieldCursor).ByteLength, "unexpected token after Type field")
                            ParseTypeDeclarations = 0
                            Exit Function
                        End If
                        FieldCursor = FieldCursor + 1
                    Wend
                End If
            Wend
            Index = DeclarationEnd
        End If
        Index = Index + 1
    Wend
    ParseTypeDeclarations = 1
End Function

Function ResolveEntryProcedure(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef EntryProcedure As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    EntryProcedure = -1
    Dim Index As Long = 0
    While Index < ProcedureCount
        If EqualsIdentifier(Tokens(Procedures(Index).NameToken).Spelling, "Main") <> 0 Then
            If EntryProcedure >= 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3001", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "executable has more than one Main procedure")
                ResolveEntryProcedure = 0
                Exit Function
            End If
            EntryProcedure = Index
        End If
        Index = Index + 1
    Wend
    If EntryProcedure < 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3000", 0, 0, "executable requires Sub Main() or Function Main() As Long")
        ResolveEntryProcedure = 0
        Exit Function
    End If
    If Procedures(EntryProcedure).IsIntrinsic <> 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3002", Tokens(Procedures(EntryProcedure).NameToken).StartByte, Tokens(Procedures(EntryProcedure).NameToken).ByteLength, "Main cannot be Intrinsic")
        ResolveEntryProcedure = 0
        Exit Function
    End If
    If Procedures(EntryProcedure).ParameterCount <> 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3003", Tokens(Procedures(EntryProcedure).NameToken).StartByte, Tokens(Procedures(EntryProcedure).NameToken).ByteLength, "Main must not have parameters")
        ResolveEntryProcedure = 0
        Exit Function
    End If
    If Procedures(EntryProcedure).ProcedureKind = 2 Then
        If Procedures(EntryProcedure).ReturnTypeToken < 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3004", Tokens(Procedures(EntryProcedure).NameToken).StartByte, Tokens(Procedures(EntryProcedure).NameToken).ByteLength, "Function Main must return Long")
            ResolveEntryProcedure = 0
            Exit Function
        End If
        If EqualsIdentifier(Tokens(Procedures(EntryProcedure).ReturnTypeToken).Spelling, "Long") = 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3004", Tokens(Procedures(EntryProcedure).ReturnTypeToken).StartByte, Tokens(Procedures(EntryProcedure).ReturnTypeToken).ByteLength, "Function Main must return Long")
            ResolveEntryProcedure = 0
            Exit Function
        End If
    End If
    ResolveEntryProcedure = 1
End Function

Function ParseLocalDeclarations(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByRef LocalCount As Long, ByRef LocalCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim ProcedureIndex As Long = 0
    While ProcedureIndex < ProcedureCount
        If Procedures(ProcedureIndex).IsIntrinsic = 0 Then
            Dim Cursor As Long = Procedures(ProcedureIndex).HeaderToken
            While Cursor < Procedures(ProcedureIndex).EndToken And Tokens(Cursor).TokenKind <> 4
                Cursor = Cursor + 1
            Wend
            If Cursor < Procedures(ProcedureIndex).EndToken Then
                Cursor = Cursor + 1
            End If
            Dim ProcedureFirstLocal As Long = LocalCount
            While Cursor < Procedures(ProcedureIndex).EndToken - 1
                If Tokens(Cursor).TokenKind = 1 And (EqualsKeyword(Tokens(Cursor).Spelling, "Dim") <> 0 Or EqualsKeyword(Tokens(Cursor).Spelling, "Static") <> 0) Then
                    Dim DeclarationToken As Long = Cursor
                    Cursor = Cursor + 1
                    If Cursor >= Procedures(ProcedureIndex).EndToken Or Tokens(Cursor).TokenKind <> 1 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2200", Tokens(DeclarationToken).StartByte, Tokens(DeclarationToken).ByteLength, "expected local variable name")
                        ParseLocalDeclarations = 0
                        Exit Function
                    End If
                    Dim LocalNameToken As Long = Cursor
                    Dim ParameterIndex As Long = Procedures(ProcedureIndex).FirstParameter
                    Dim ParameterEnd As Long = ParameterIndex + Procedures(ProcedureIndex).ParameterCount
                    While ParameterIndex < ParameterEnd
                        If EqualsIdentifier(Tokens(Parameters(ParameterIndex).NameToken).Spelling, Tokens(LocalNameToken).Spelling) <> 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2201", Tokens(LocalNameToken).StartByte, Tokens(LocalNameToken).ByteLength, "local name duplicates a parameter: " & Tokens(LocalNameToken).Spelling)
                            ParseLocalDeclarations = 0
                            Exit Function
                        End If
                        ParameterIndex = ParameterIndex + 1
                    Wend
                    Dim ExistingLocal As Long = ProcedureFirstLocal
                    While ExistingLocal < LocalCount
                        If EqualsIdentifier(Tokens(Locals(ExistingLocal).NameToken).Spelling, Tokens(LocalNameToken).Spelling) <> 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2202", Tokens(LocalNameToken).StartByte, Tokens(LocalNameToken).ByteLength, "duplicate local name: " & Tokens(LocalNameToken).Spelling)
                            ParseLocalDeclarations = 0
                            Exit Function
                        End If
                        ExistingLocal = ExistingLocal + 1
                    Wend
                    Cursor = Cursor + 1
                    Dim LocalIsArray As Long = 0
                    If Cursor < Procedures(ProcedureIndex).EndToken And Tokens(Cursor).TokenKind = 5 Then
                        LocalIsArray = 1
                        Cursor = Cursor + 1
                        If Cursor >= Procedures(ProcedureIndex).EndToken Or Tokens(Cursor).TokenKind <> 6 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2203", Tokens(LocalNameToken).StartByte, Tokens(LocalNameToken).ByteLength, "dynamic local array requires empty parentheses")
                            ParseLocalDeclarations = 0
                            Exit Function
                        End If
                        Cursor = Cursor + 1
                    End If
                    If Cursor >= Procedures(ProcedureIndex).EndToken Or Tokens(Cursor).TokenKind <> 1 Or EqualsKeyword(Tokens(Cursor).Spelling, "As") = 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2204", Tokens(LocalNameToken).StartByte, Tokens(LocalNameToken).ByteLength, "local variable requires an explicit As type")
                        ParseLocalDeclarations = 0
                        Exit Function
                    End If
                    Cursor = Cursor + 1
                    If Cursor >= Procedures(ProcedureIndex).EndToken Or Tokens(Cursor).TokenKind <> 1 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2205", Tokens(LocalNameToken).StartByte, Tokens(LocalNameToken).ByteLength, "expected local variable type")
                        ParseLocalDeclarations = 0
                        Exit Function
                    End If
                    Dim LocalTypeToken As Long = Cursor
                    Cursor = Cursor + 1
                    Dim InitializerStart As Long = -1
                    Dim InitializerCount As Long = 0
                    If Cursor < Procedures(ProcedureIndex).EndToken And Tokens(Cursor).TokenKind = 7 Then
                        Cursor = Cursor + 1
                        InitializerStart = Cursor
                        While Cursor < Procedures(ProcedureIndex).EndToken And Tokens(Cursor).TokenKind <> 4 And Tokens(Cursor).TokenKind <> 9
                            Cursor = Cursor + 1
                        Wend
                        InitializerCount = Cursor - InitializerStart
                        If InitializerCount = 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2206", Tokens(LocalNameToken).StartByte, Tokens(LocalNameToken).ByteLength, "local initializer requires an expression")
                            ParseLocalDeclarations = 0
                            Exit Function
                        End If
                    End If
                    If Cursor < Procedures(ProcedureIndex).EndToken And Tokens(Cursor).TokenKind = 9 Then
                        Cursor = Cursor + 1
                    End If
                    If Cursor >= Procedures(ProcedureIndex).EndToken Or Tokens(Cursor).TokenKind <> 4 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2207", Tokens(LocalNameToken).StartByte, Tokens(LocalNameToken).ByteLength, "unexpected token after local declaration")
                        ParseLocalDeclarations = 0
                        Exit Function
                    End If
                    Dim NewLocal As Long = AppendLocalDeclaration(Locals, LocalCount, LocalCapacity, ProcedureIndex, LocalNameToken, LocalTypeToken, LocalIsArray, InitializerStart, InitializerCount)
                    If NewLocal < 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2208", Tokens(LocalNameToken).StartByte, Tokens(LocalNameToken).ByteLength, "local declaration limit exceeded")
                        ParseLocalDeclarations = 0
                        Exit Function
                    End If
                Else
                    Cursor = Cursor + 1
                End If
            Wend
        End If
        ProcedureIndex = ProcedureIndex + 1
    Wend
    ParseLocalDeclarations = 1
End Function

Function ParseBasicStatements(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Statements() As StatementSyntax, ByRef StatementCount As Long, ByRef StatementCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim ProcedureIndex As Long = 0
    While ProcedureIndex < ProcedureCount
        If Procedures(ProcedureIndex).IsIntrinsic = 0 Then
            Dim BlockKinds() As Long
            Dim BlockTokens() As Long
            Dim BlockSawElse() As Long
            ReDim BlockKinds(1023)
            ReDim BlockTokens(1023)
            ReDim BlockSawElse(1023)
            Dim BlockDepth As Long = 0
            Dim Cursor As Long = Procedures(ProcedureIndex).HeaderToken
            While Cursor < Procedures(ProcedureIndex).EndToken And Tokens(Cursor).TokenKind <> 4
                Cursor = Cursor + 1
            Wend
            If Cursor < Procedures(ProcedureIndex).EndToken Then
                Cursor = Cursor + 1
            End If
            While Cursor < Procedures(ProcedureIndex).EndToken - 1
                If Tokens(Cursor).TokenKind = 4 Or Tokens(Cursor).TokenKind = 9 Then
                    Cursor = Cursor + 1
                Else
                    Dim LineStart As Long = Cursor
                    Dim LineEnd As Long = Cursor
                    While LineEnd < Procedures(ProcedureIndex).EndToken And Tokens(LineEnd).TokenKind <> 4
                        LineEnd = LineEnd + 1
                    Wend
                    If Tokens(LineStart).TokenKind = 1 Then
                        If EqualsKeyword(Tokens(LineStart).Spelling, "For") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Next") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "ElseIf") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Do") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Loop") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Select") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Case") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "With") <> 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2238", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "structured statement is reserved for UBE Compiler v3: " & Tokens(LineStart).Spelling)
                            ParseBasicStatements = 0
                            Exit Function
                        End If
                    End If
                    If Tokens(LineStart).TokenKind = 1 And EqualsKeyword(Tokens(LineStart).Spelling, "If") <> 0 Then
                        If LineEnd - LineStart < 3 Or EqualsKeyword(Tokens(LineEnd - 1).Spelling, "Then") = 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2230", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "block If requires a condition followed by Then")
                            ParseBasicStatements = 0
                            Exit Function
                        End If
                        If BlockDepth >= 1024 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2237", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "structured statement nesting limit exceeded")
                            ParseBasicStatements = 0
                            Exit Function
                        End If
                        Dim IfStatementIndex As Long = AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 10, LineStart, LineEnd - 1, LineEnd - 1)
                        If IfStatementIndex < 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2214", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "statement limit exceeded")
                            ParseBasicStatements = 0
                            Exit Function
                        End If
                        BlockKinds(BlockDepth) = 10
                        BlockTokens(BlockDepth) = LineStart
                        BlockSawElse(BlockDepth) = 0
                        BlockDepth = BlockDepth + 1
                    Else
                        If Tokens(LineStart).TokenKind = 1 And EqualsKeyword(Tokens(LineStart).Spelling, "Else") <> 0 Then
                            If LineEnd <> LineStart + 1 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2231", Tokens(LineStart + 1).StartByte, Tokens(LineStart + 1).ByteLength, "unexpected token after Else")
                                ParseBasicStatements = 0
                                Exit Function
                            End If
                            Dim ElseMatchesIf As Long = 0
                            If BlockDepth > 0 Then
                                If BlockKinds(BlockDepth - 1) = 10 Then
                                    ElseMatchesIf = 1
                                End If
                            End If
                            If ElseMatchesIf = 0 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2232", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "Else has no matching block If")
                                ParseBasicStatements = 0
                                Exit Function
                            End If
                            If BlockSawElse(BlockDepth - 1) <> 0 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2233", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "block If has more than one Else")
                                ParseBasicStatements = 0
                                Exit Function
                            End If
                            BlockSawElse(BlockDepth - 1) = 1
                            Call AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 12, LineStart, LineEnd - 1, -1)
                        Else
                            Dim IsEndIf As Long = 0
                            If Tokens(LineStart).TokenKind = 1 And EqualsKeyword(Tokens(LineStart).Spelling, "End") <> 0 Then
                                If LineStart + 1 < LineEnd Then
                                    If EqualsKeyword(Tokens(LineStart + 1).Spelling, "If") <> 0 Then
                                        IsEndIf = 1
                                    End If
                                End If
                            End If
                            If IsEndIf <> 0 Then
                                If LineEnd <> LineStart + 2 Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2231", Tokens(LineStart + 2).StartByte, Tokens(LineStart + 2).ByteLength, "unexpected token after End If")
                                    ParseBasicStatements = 0
                                    Exit Function
                                End If
                                Dim EndMatchesIf As Long = 0
                                If BlockDepth > 0 Then
                                    If BlockKinds(BlockDepth - 1) = 10 Then
                                        EndMatchesIf = 1
                                    End If
                                End If
                                If EndMatchesIf = 0 Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2234", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "End If does not match the open structured statement")
                                    ParseBasicStatements = 0
                                    Exit Function
                                End If
                                BlockDepth = BlockDepth - 1
                                Call AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 13, LineStart, LineEnd - 1, -1)
                            Else
                                If Tokens(LineStart).TokenKind = 1 And EqualsKeyword(Tokens(LineStart).Spelling, "While") <> 0 Then
                                    If LineEnd = LineStart + 1 Then
                                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2236", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "While requires a condition")
                                        ParseBasicStatements = 0
                                        Exit Function
                                    End If
                                    If BlockDepth >= 1024 Then
                                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2237", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "structured statement nesting limit exceeded")
                                        ParseBasicStatements = 0
                                        Exit Function
                                    End If
                                    Dim WhileStatementIndex As Long = AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 14, LineStart, LineEnd - 1, -1)
                                    BlockKinds(BlockDepth) = 14
                                    BlockTokens(BlockDepth) = LineStart
                                    BlockSawElse(BlockDepth) = 0
                                    BlockDepth = BlockDepth + 1
                                Else
                                    If Tokens(LineStart).TokenKind = 1 And EqualsKeyword(Tokens(LineStart).Spelling, "Wend") <> 0 Then
                                        If LineEnd <> LineStart + 1 Then
                                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2231", Tokens(LineStart + 1).StartByte, Tokens(LineStart + 1).ByteLength, "unexpected token after Wend")
                                            ParseBasicStatements = 0
                                            Exit Function
                                        End If
                                        Dim WendMatchesWhile As Long = 0
                                        If BlockDepth > 0 Then
                                            If BlockKinds(BlockDepth - 1) = 14 Then
                                                WendMatchesWhile = 1
                                            End If
                                        End If
                                        If WendMatchesWhile = 0 Then
                                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2234", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "Wend does not match the open structured statement")
                                            ParseBasicStatements = 0
                                            Exit Function
                                        End If
                                        BlockDepth = BlockDepth - 1
                                        Call AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 15, LineStart, LineEnd - 1, -1)
                                    Else
                    If Tokens(LineStart).TokenKind = 1 And EqualsKeyword(Tokens(LineStart).Spelling, "Call") <> 0 Then
                        If LineStart + 1 >= LineEnd Or Tokens(LineStart + 1).TokenKind <> 1 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2210", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "expected procedure name after Call")
                            ParseBasicStatements = 0
                            Exit Function
                        End If
                        Dim CallStatementIndex As Long = AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 2, LineStart, LineEnd - 1, -1)
                        If CallStatementIndex < 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2214", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "statement limit exceeded")
                            ParseBasicStatements = 0
                            Exit Function
                        End If
                    Else
                        If Tokens(LineStart).TokenKind = 1 And EqualsKeyword(Tokens(LineStart).Spelling, "ReDim") <> 0 Then
                            Dim ReDimCursor As Long = LineStart + 1
                            Dim ReDimPreserve As Long = 0
                            If ReDimCursor < LineEnd Then
                                If EqualsKeyword(Tokens(ReDimCursor).Spelling, "Preserve") <> 0 Then
                                    ReDimPreserve = 1
                                    ReDimCursor = ReDimCursor + 1
                                End If
                            End If
                            If ReDimCursor >= LineEnd Or Tokens(ReDimCursor).TokenKind <> 1 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2217", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "ReDim requires an array name")
                                ParseBasicStatements = 0
                                Exit Function
                            End If
                            Dim ReDimNameToken As Long = ReDimCursor
                            ReDimCursor = ReDimCursor + 1
                            If ReDimCursor >= LineEnd Or Tokens(ReDimCursor).TokenKind <> 5 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2218", Tokens(ReDimNameToken).StartByte, Tokens(ReDimNameToken).ByteLength, "ReDim requires a parenthesized upper bound")
                                ParseBasicStatements = 0
                                Exit Function
                            End If
                            Dim ReDimOpenToken As Long = ReDimCursor
                            If LineEnd - ReDimOpenToken < 3 Or Tokens(LineEnd - 1).TokenKind <> 6 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2218", Tokens(ReDimOpenToken).StartByte, Tokens(ReDimOpenToken).ByteLength, "ReDim requires a parenthesized upper bound")
                                ParseBasicStatements = 0
                                Exit Function
                            End If
                            Dim ReDimStatementIndex As Long = AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 4, ReDimNameToken, LineEnd - 1, ReDimOpenToken)
                            If ReDimStatementIndex < 0 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2214", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "statement limit exceeded")
                                ParseBasicStatements = 0
                                Exit Function
                            End If
                            Statements(ReDimStatementIndex).Flags = ReDimPreserve
                        Else
                        If Tokens(LineStart).TokenKind = 1 And EqualsKeyword(Tokens(LineStart).Spelling, "Print") <> 0 Then
                            If LineStart + 1 >= LineEnd Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2215", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "Print requires an expression")
                                ParseBasicStatements = 0
                                Exit Function
                            End If
                            Call AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 3, LineStart, LineEnd - 1, -1)
                        Else
                            If Tokens(LineStart).TokenKind = 1 And EqualsKeyword(Tokens(LineStart).Spelling, "Exit") <> 0 Then
                                Dim ExitShapeValid As Long = 0
                                If LineEnd = LineStart + 2 Then
                                    If Tokens(LineStart + 1).TokenKind = 1 Then
                                        ExitShapeValid = 1
                                    End If
                                End If
                                If ExitShapeValid = 0 Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2216", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "Exit requires Sub, Function, or While")
                                    ParseBasicStatements = 0
                                    Exit Function
                                End If
                                Dim ExitKind As Long = 0
                                If EqualsKeyword(Tokens(LineStart + 1).Spelling, "Sub") <> 0 Or EqualsKeyword(Tokens(LineStart + 1).Spelling, "Function") <> 0 Then
                                    ExitKind = 5
                                Else
                                    If EqualsKeyword(Tokens(LineStart + 1).Spelling, "While") <> 0 Then
                                        ExitKind = 6
                                    End If
                                End If
                                If ExitKind = 0 Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2216", Tokens(LineStart + 1).StartByte, Tokens(LineStart + 1).ByteLength, "Exit requires Sub, Function, or While")
                                    ParseBasicStatements = 0
                                    Exit Function
                                End If
                                If ExitKind = 5 Then
                                    If EqualsKeyword(Tokens(LineStart + 1).Spelling, "Function") <> 0 And Procedures(ProcedureIndex).ProcedureKind <> 2 Then
                                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2219", Tokens(LineStart + 1).StartByte, Tokens(LineStart + 1).ByteLength, "Exit Function is only valid inside a Function")
                                        ParseBasicStatements = 0
                                        Exit Function
                                    End If
                                    If EqualsKeyword(Tokens(LineStart + 1).Spelling, "Sub") <> 0 And Procedures(ProcedureIndex).ProcedureKind <> 1 Then
                                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2219", Tokens(LineStart + 1).StartByte, Tokens(LineStart + 1).ByteLength, "Exit Sub is only valid inside a Sub")
                                        ParseBasicStatements = 0
                                        Exit Function
                                    End If
                                Else
                                    Dim HasEnclosingWhile As Long = 0
                                    Dim ExitBlockIndex As Long = BlockDepth - 1
                                    While ExitBlockIndex >= 0
                                        If BlockKinds(ExitBlockIndex) = 14 Then
                                            HasEnclosingWhile = 1
                                            Exit While
                                        End If
                                        ExitBlockIndex = ExitBlockIndex - 1
                                    Wend
                                    If HasEnclosingWhile = 0 Then
                                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2226", Tokens(LineStart + 1).StartByte, Tokens(LineStart + 1).ByteLength, "Exit While requires an enclosing While block")
                                        ParseBasicStatements = 0
                                        Exit Function
                                    End If
                                End If
                                Call AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, ExitKind, LineStart, LineEnd - 1, -1)
                            Else
                                If Tokens(LineStart).TokenKind = 1 And (EqualsKeyword(Tokens(LineStart).Spelling, "Dim") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Static") <> 0) Then
                                    Dim DeclarationStatementIndex As Long = AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 7, LineStart, LineEnd - 1, LineStart + 1)
                                    If DeclarationStatementIndex < 0 Then
                                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2214", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "statement limit exceeded")
                                        ParseBasicStatements = 0
                                        Exit Function
                                    End If
                                    If EqualsKeyword(Tokens(LineStart).Spelling, "Static") <> 0 Then
                                        Statements(DeclarationStatementIndex).Flags = 1
                                    End If
                                Else
                        Dim IgnoreLine As Long = 0
                        If Tokens(LineStart).TokenKind = 1 Then
                            If EqualsKeyword(Tokens(LineStart).Spelling, "Dim") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Static") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Print") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "If") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Else") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "End") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "While") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Wend") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "For") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Next") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "ReDim") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "Exit") <> 0 Then
                                IgnoreLine = 1
                            End If
                        End If
                        If IgnoreLine = 0 And Tokens(LineStart).TokenKind = 1 Then
                            Dim EqualsToken As Long = -1
                            Dim SearchToken As Long = LineStart + 1
                            While SearchToken < LineEnd
                                If Tokens(SearchToken).TokenKind = 7 Then
                                    EqualsToken = SearchToken
                                    Exit While
                                End If
                                SearchToken = SearchToken + 1
                            Wend
                            If EqualsToken >= 0 Then
                                If EqualsToken + 1 >= LineEnd Or Tokens(EqualsToken + 1).TokenKind = 9 Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2211", Tokens(EqualsToken).StartByte, Tokens(EqualsToken).ByteLength, "assignment requires a value")
                                    ParseBasicStatements = 0
                                    Exit Function
                                End If
                                Dim AssignmentIndex As Long = AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 1, LineStart, LineEnd - 1, EqualsToken)
                                If AssignmentIndex < 0 Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2214", Tokens(LineStart).StartByte, Tokens(LineStart).ByteLength, "statement limit exceeded")
                                    ParseBasicStatements = 0
                                    Exit Function
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
                    Cursor = LineEnd
                End If
            Wend
            If BlockDepth <> 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2235", Tokens(BlockTokens(BlockDepth - 1)).StartByte, Tokens(BlockTokens(BlockDepth - 1)).ByteLength, "unterminated structured statement")
                ParseBasicStatements = 0
                Exit Function
            End If
        End If
        ProcedureIndex = ProcedureIndex + 1
    Wend
    ParseBasicStatements = 1
End Function

Function AnalyzeBasicStatements(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim StatementIndex As Long = 0
    While StatementIndex < StatementCount
        Dim Owner As Long = Statements(StatementIndex).OwnerProcedure
        If Statements(StatementIndex).StatementKind = 1 Then
            Dim TargetToken As Long = Statements(StatementIndex).FirstToken
            Dim TargetFound As Long = 0
            Dim ParameterIndex As Long = Procedures(Owner).FirstParameter
            Dim ParameterEnd As Long = ParameterIndex + Procedures(Owner).ParameterCount
            While ParameterIndex < ParameterEnd
                If EqualsIdentifier(Tokens(Parameters(ParameterIndex).NameToken).Spelling, Tokens(TargetToken).Spelling) <> 0 Then
                    TargetFound = 1
                    Exit While
                End If
                ParameterIndex = ParameterIndex + 1
            Wend
            If TargetFound = 0 Then
                Dim LocalIndex As Long = 0
                While LocalIndex < LocalCount
                    If Locals(LocalIndex).OwnerProcedure = Owner Then
                        If EqualsIdentifier(Tokens(Locals(LocalIndex).NameToken).Spelling, Tokens(TargetToken).Spelling) <> 0 Then
                            TargetFound = 1
                            Exit While
                        End If
                    End If
                    LocalIndex = LocalIndex + 1
                Wend
            End If
            If TargetFound = 0 And Procedures(Owner).ProcedureKind = 2 Then
                If EqualsIdentifier(Tokens(Procedures(Owner).NameToken).Spelling, Tokens(TargetToken).Spelling) <> 0 Then
                    TargetFound = 1
                End If
            End If
            If TargetFound = 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3100", Tokens(TargetToken).StartByte, Tokens(TargetToken).ByteLength, "assignment target is not declared: " & Tokens(TargetToken).Spelling)
                AnalyzeBasicStatements = 0
                Exit Function
            End If
        Else
            If Statements(StatementIndex).StatementKind = 2 Then
                Dim CalleeToken As Long = Statements(StatementIndex).FirstToken + 1
                Dim CalleeFound As Long = 0
                Dim ProcedureSearch As Long = 0
                While ProcedureSearch < ProcedureCount
                    If EqualsIdentifier(Tokens(Procedures(ProcedureSearch).NameToken).Spelling, Tokens(CalleeToken).Spelling) <> 0 Then
                        CalleeFound = 1
                        Exit While
                    End If
                    ProcedureSearch = ProcedureSearch + 1
                Wend
                If CalleeFound = 0 Then
                    If ExpressionNameIsVariable(Tokens, Procedures, Parameters, Locals, LocalCount, Owner, CalleeToken) = 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3101", Tokens(CalleeToken).StartByte, Tokens(CalleeToken).ByteLength, "procedure is not declared: " & Tokens(CalleeToken).Spelling)
                        AnalyzeBasicStatements = 0
                        Exit Function
                    End If
                End If
            End If
        End If
        StatementIndex = StatementIndex + 1
    Wend
    AnalyzeBasicStatements = 1
End Function

Function ParseStoredExpressions(ByRef Tokens() As Token, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim LocalIndex As Long = 0
    While LocalIndex < LocalCount
        If Locals(LocalIndex).InitializerFirstToken >= 0 Then
            Dim LocalCursor As Long = Locals(LocalIndex).InitializerFirstToken
            Dim LocalEnd As Long = LocalCursor + Locals(LocalIndex).InitializerTokenCount
            Locals(LocalIndex).InitializerNode = ParseGeneralExpression(Tokens, LocalEnd, LocalCursor, 1, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
            If Locals(LocalIndex).InitializerNode < 0 Then
                ParseStoredExpressions = 0
                Exit Function
            End If
            If LocalCursor <> LocalEnd Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2224", Tokens(LocalCursor).StartByte, Tokens(LocalCursor).ByteLength, "unexpected token after expression")
                ParseStoredExpressions = 0
                Exit Function
            End If
        End If
        LocalIndex = LocalIndex + 1
    Wend
    Dim StatementIndex As Long = 0
    While StatementIndex < StatementCount
        Dim ExpressionStart As Long = -1
        If Statements(StatementIndex).StatementKind = 1 Then
            Dim TargetCursor As Long = Statements(StatementIndex).FirstToken
            Statements(StatementIndex).TargetNode = ParseGeneralExpression(Tokens, Statements(StatementIndex).OperatorToken, TargetCursor, 1, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
            If Statements(StatementIndex).TargetNode < 0 Then
                ParseStoredExpressions = 0
                Exit Function
            End If
            If TargetCursor <> Statements(StatementIndex).OperatorToken Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2225", Tokens(TargetCursor).StartByte, Tokens(TargetCursor).ByteLength, "unexpected token in assignment target")
                ParseStoredExpressions = 0
                Exit Function
            End If
            ExpressionStart = Statements(StatementIndex).OperatorToken + 1
        Else
            If Statements(StatementIndex).StatementKind = 4 Then
                Dim ReDimTargetCursor As Long = Statements(StatementIndex).FirstToken
                Statements(StatementIndex).TargetNode = ParseGeneralExpression(Tokens, Statements(StatementIndex).OperatorToken, ReDimTargetCursor, 1, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
                If Statements(StatementIndex).TargetNode < 0 Or ReDimTargetCursor <> Statements(StatementIndex).OperatorToken Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2225", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "invalid ReDim target")
                    ParseStoredExpressions = 0
                    Exit Function
                End If
                ExpressionStart = Statements(StatementIndex).OperatorToken + 1
            Else
            If Statements(StatementIndex).StatementKind = 2 Or Statements(StatementIndex).StatementKind = 3 Then
                ExpressionStart = Statements(StatementIndex).FirstToken + 1
            Else
                If Statements(StatementIndex).StatementKind = 10 Or Statements(StatementIndex).StatementKind = 14 Then
                    ExpressionStart = Statements(StatementIndex).FirstToken + 1
                End If
            End If
            End If
        End If
        If ExpressionStart >= 0 Then
            Dim ExpressionEnd As Long = Statements(StatementIndex).LastToken + 1
            If Statements(StatementIndex).StatementKind = 10 Then
                ExpressionEnd = Statements(StatementIndex).OperatorToken
            End If
            If Statements(StatementIndex).StatementKind = 4 Then
                ExpressionEnd = Statements(StatementIndex).LastToken
            End If
            If ExpressionEnd > ExpressionStart Then
                If Tokens(ExpressionEnd - 1).TokenKind = 9 Then
                    ExpressionEnd = ExpressionEnd - 1
                End If
            End If
            Dim StatementCursor As Long = ExpressionStart
            Statements(StatementIndex).ValueNode = ParseGeneralExpression(Tokens, ExpressionEnd, StatementCursor, 1, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
            If Statements(StatementIndex).ValueNode < 0 Then
                ParseStoredExpressions = 0
                Exit Function
            End If
            If StatementCursor <> ExpressionEnd Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2224", Tokens(StatementCursor).StartByte, Tokens(StatementCursor).ByteLength, "unexpected token after expression")
                ParseStoredExpressions = 0
                Exit Function
            End If
        End If
        StatementIndex = StatementIndex + 1
    Wend
    ParseStoredExpressions = 1
End Function

Function ExpressionNameIsVariable(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByVal Owner As Long, ByVal NameToken As Long) As Long
    Dim ParameterIndex As Long = Procedures(Owner).FirstParameter
    Dim ParameterEnd As Long = ParameterIndex + Procedures(Owner).ParameterCount
    While ParameterIndex < ParameterEnd
        If EqualsIdentifier(Tokens(Parameters(ParameterIndex).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
            ExpressionNameIsVariable = 1
            Exit Function
        End If
        ParameterIndex = ParameterIndex + 1
    Wend
    Dim LocalIndex As Long = 0
    While LocalIndex < LocalCount
        If Locals(LocalIndex).OwnerProcedure = Owner Then
            If EqualsIdentifier(Tokens(Locals(LocalIndex).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
                ExpressionNameIsVariable = 1
                Exit Function
            End If
        End If
        LocalIndex = LocalIndex + 1
    Wend
    If Procedures(Owner).ProcedureKind = 2 Then
        If EqualsIdentifier(Tokens(Procedures(Owner).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
            ExpressionNameIsVariable = 1
            Exit Function
        End If
    End If
    ExpressionNameIsVariable = 0
End Function

Function FindProcedureByToken(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByVal NameToken As Long) As Long
    Dim Index As Long = 0
    While Index < ProcedureCount
        If EqualsIdentifier(Tokens(Procedures(Index).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
            FindProcedureByToken = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    FindProcedureByToken = -1
End Function

Function ValidateExpressionNode(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByVal Owner As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim Kind As Long = Nodes(NodeIndex).NodeKind
    If Kind = 10 Or Kind = 11 Then
        ValidateExpressionNode = 1
        Exit Function
    End If
    If Kind = 12 Then
        Dim NameToken As Long = Nodes(NodeIndex).SourceToken
        If ExpressionNameIsVariable(Tokens, Procedures, Parameters, Locals, LocalCount, Owner, NameToken) <> 0 Or EqualsKeyword(Tokens(NameToken).Spelling, "True") <> 0 Or EqualsKeyword(Tokens(NameToken).Spelling, "False") <> 0 Then
            ValidateExpressionNode = 1
            Exit Function
        End If
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3102", Tokens(NameToken).StartByte, Tokens(NameToken).ByteLength, "name is not declared: " & Tokens(NameToken).Spelling)
        ValidateExpressionNode = 0
        Exit Function
    End If
    If Kind = 13 Then
        Dim CalleeNode As Long = Nodes(NodeIndex).LeftNode
        Dim ExpectedArguments As Long = -1
        If Nodes(CalleeNode).NodeKind = 12 Then
            Dim CalleeNameToken As Long = Nodes(CalleeNode).SourceToken
            Dim CalleeProcedure As Long = FindProcedureByToken(Tokens, Procedures, ProcedureCount, CalleeNameToken)
            If CalleeProcedure >= 0 Then
                ExpectedArguments = Procedures(CalleeProcedure).ParameterCount
            Else
                If ExpressionNameIsVariable(Tokens, Procedures, Parameters, Locals, LocalCount, Owner, CalleeNameToken) <> 0 Then
                    ExpectedArguments = 1
                Else
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3101", Tokens(CalleeNameToken).StartByte, Tokens(CalleeNameToken).ByteLength, "procedure is not declared: " & Tokens(CalleeNameToken).Spelling)
                    ValidateExpressionNode = 0
                    Exit Function
                End If
            End If
        Else
            If ValidateExpressionNode(Tokens, Nodes, CalleeNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Owner, Diagnostics, DiagnosticCount) = 0 Then
                ValidateExpressionNode = 0
                Exit Function
            End If
        End If
        Dim ArgumentCount As Long = 0
        Dim ArgumentLink As Long = Nodes(NodeIndex).RightNode
        While ArgumentLink >= 0
            If ValidateExpressionNode(Tokens, Nodes, Nodes(ArgumentLink).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Owner, Diagnostics, DiagnosticCount) = 0 Then
                ValidateExpressionNode = 0
                Exit Function
            End If
            ArgumentCount = ArgumentCount + 1
            ArgumentLink = Nodes(ArgumentLink).RightNode
        Wend
        If ExpectedArguments >= 0 And ArgumentCount <> ExpectedArguments Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3103", Tokens(Nodes(NodeIndex).SourceToken).StartByte, Tokens(Nodes(NodeIndex).SourceToken).ByteLength, "argument count does not match callable")
            ValidateExpressionNode = 0
            Exit Function
        End If
        ValidateExpressionNode = 1
        Exit Function
    End If
    If Kind = 14 Then
        ValidateExpressionNode = ValidateExpressionNode(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Owner, Diagnostics, DiagnosticCount)
        Exit Function
    End If
    If Kind = 16 Then
        ValidateExpressionNode = ValidateExpressionNode(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Owner, Diagnostics, DiagnosticCount)
        Exit Function
    End If
    If Kind = 15 Then
        If ValidateExpressionNode(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Owner, Diagnostics, DiagnosticCount) = 0 Then
            ValidateExpressionNode = 0
            Exit Function
        End If
        ValidateExpressionNode = ValidateExpressionNode(Tokens, Nodes, Nodes(NodeIndex).RightNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Owner, Diagnostics, DiagnosticCount)
        Exit Function
    End If
    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3104", Tokens(Nodes(NodeIndex).SourceToken).StartByte, Tokens(Nodes(NodeIndex).SourceToken).ByteLength, "unsupported expression node")
    ValidateExpressionNode = 0
End Function

Function AnalyzeStoredExpressions(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim LocalIndex As Long = 0
    While LocalIndex < LocalCount
        If Locals(LocalIndex).InitializerNode >= 0 Then
            If ValidateExpressionNode(Tokens, Nodes, Locals(LocalIndex).InitializerNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Locals(LocalIndex).OwnerProcedure, Diagnostics, DiagnosticCount) = 0 Then
                AnalyzeStoredExpressions = 0
                Exit Function
            End If
        End If
        LocalIndex = LocalIndex + 1
    Wend
    Dim StatementIndex As Long = 0
    While StatementIndex < StatementCount
        If Statements(StatementIndex).ValueNode >= 0 Then
            If ValidateExpressionNode(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Statements(StatementIndex).OwnerProcedure, Diagnostics, DiagnosticCount) = 0 Then
                AnalyzeStoredExpressions = 0
                Exit Function
            End If
        End If
        StatementIndex = StatementIndex + 1
    Wend
    AnalyzeStoredExpressions = 1
End Function

Function DeclaredTypeId(ByRef Tokens() As Token, ByVal TypeToken As Long, ByVal IsDynamicArray As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long) As Long
    Dim TypeName As String = Tokens(TypeToken).Spelling
    Dim Result As Long = 0
    If EqualsIdentifier(TypeName, "Boolean") <> 0 Then
        Result = 1
    Else
        If EqualsIdentifier(TypeName, "Long") <> 0 Then
            Result = 2
        Else
            If EqualsIdentifier(TypeName, "String") <> 0 Then
                Result = 3
            Else
                If EqualsIdentifier(TypeName, "Integer") <> 0 Then
                    Result = 4
                Else
                    If EqualsIdentifier(TypeName, "LongLong") <> 0 Then
                        Result = 5
                    Else
                        If EqualsIdentifier(TypeName, "Double") <> 0 Then
                            Result = 6
                        Else
                            Dim TypeIndex As Long = 0
                            While TypeIndex < TypeCount
                                If EqualsIdentifier(Tokens(Types(TypeIndex).NameToken).Spelling, TypeName) <> 0 Then
                                    Result = 1000 + TypeIndex
                                    Exit While
                                End If
                                TypeIndex = TypeIndex + 1
                            Wend
                        End If
                    End If
                End If
            End If
        End If
    End If
    If Result <> 0 And IsDynamicArray <> 0 Then
        Result = Result + 100000
    End If
    DeclaredTypeId = Result
End Function

Function IsNumericType(ByVal TypeId As Long) As Long
    If TypeId = 2 Or TypeId = 4 Or TypeId = 5 Or TypeId = 6 Then
        IsNumericType = 1
    Else
        IsNumericType = 0
    End If
End Function

Function ValidateDeclaredTypes(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByVal ParameterCount As Long, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim Index As Long = 0
    While Index < ParameterCount
        If DeclaredTypeId(Tokens, Parameters(Index).TypeToken, Parameters(Index).IsDynamicArray, Types, TypeCount) = 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3213", Tokens(Parameters(Index).TypeToken).StartByte, Tokens(Parameters(Index).TypeToken).ByteLength, "unknown parameter type: " & Tokens(Parameters(Index).TypeToken).Spelling)
            ValidateDeclaredTypes = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    Index = 0
    While Index < LocalCount
        If DeclaredTypeId(Tokens, Locals(Index).TypeToken, Locals(Index).IsDynamicArray, Types, TypeCount) = 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3214", Tokens(Locals(Index).TypeToken).StartByte, Tokens(Locals(Index).TypeToken).ByteLength, "unknown local type: " & Tokens(Locals(Index).TypeToken).Spelling)
            ValidateDeclaredTypes = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    Index = 0
    While Index < FieldCount
        If DeclaredTypeId(Tokens, Fields(Index).TypeToken, Fields(Index).IsDynamicArray, Types, TypeCount) = 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3215", Tokens(Fields(Index).TypeToken).StartByte, Tokens(Fields(Index).TypeToken).ByteLength, "unknown field type: " & Tokens(Fields(Index).TypeToken).Spelling)
            ValidateDeclaredTypes = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    Index = 0
    While Index < ProcedureCount
        If Procedures(Index).ProcedureKind = 2 Then
            If DeclaredTypeId(Tokens, Procedures(Index).ReturnTypeToken, 0, Types, TypeCount) = 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3216", Tokens(Procedures(Index).ReturnTypeToken).StartByte, Tokens(Procedures(Index).ReturnTypeToken).ByteLength, "unknown function result type: " & Tokens(Procedures(Index).ReturnTypeToken).Spelling)
                ValidateDeclaredTypes = 0
                Exit Function
            End If
        End If
        Index = Index + 1
    Wend
    ValidateDeclaredTypes = 1
End Function

Function IsIntegralOrBooleanType(ByVal TypeId As Long) As Long
    If TypeId = 1 Or TypeId = 2 Or TypeId = 4 Or TypeId = 5 Then
        IsIntegralOrBooleanType = 1
    Else
        IsIntegralOrBooleanType = 0
    End If
End Function

Function CommonNumericType(ByVal LeftType As Long, ByVal RightType As Long) As Long
    If IsNumericType(LeftType) = 0 Or IsNumericType(RightType) = 0 Then
        CommonNumericType = 0
        Exit Function
    End If
    If LeftType = 6 Or RightType = 6 Then
        CommonNumericType = 6
    Else
        If LeftType = 5 Or RightType = 5 Then
            CommonNumericType = 5
        Else
            If LeftType = 2 Or RightType = 2 Then
                CommonNumericType = 2
            Else
                CommonNumericType = 4
            End If
        End If
    End If
End Function

Function FindVariableType(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByVal Owner As Long, ByVal NameToken As Long) As Long
    Dim ParameterIndex As Long = Procedures(Owner).FirstParameter
    Dim ParameterEnd As Long = ParameterIndex + Procedures(Owner).ParameterCount
    While ParameterIndex < ParameterEnd
        If EqualsIdentifier(Tokens(Parameters(ParameterIndex).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
            FindVariableType = DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, Parameters(ParameterIndex).IsDynamicArray, Types, TypeCount)
            Exit Function
        End If
        ParameterIndex = ParameterIndex + 1
    Wend
    Dim LocalIndex As Long = 0
    While LocalIndex < LocalCount
        If Locals(LocalIndex).OwnerProcedure = Owner Then
            If EqualsIdentifier(Tokens(Locals(LocalIndex).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
                FindVariableType = DeclaredTypeId(Tokens, Locals(LocalIndex).TypeToken, Locals(LocalIndex).IsDynamicArray, Types, TypeCount)
                Exit Function
            End If
        End If
        LocalIndex = LocalIndex + 1
    Wend
    If Procedures(Owner).ProcedureKind = 2 Then
        If EqualsIdentifier(Tokens(Procedures(Owner).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
            FindVariableType = DeclaredTypeId(Tokens, Procedures(Owner).ReturnTypeToken, 0, Types, TypeCount)
            Exit Function
        End If
    End If
    FindVariableType = 0
End Function

Function IsAddressableExpression(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByVal Owner As Long) As Long
    Dim Kind As Long = Nodes(NodeIndex).NodeKind
    If Kind = 12 Then
        IsAddressableExpression = ExpressionNameIsVariable(Tokens, Procedures, Parameters, Locals, LocalCount, Owner, Nodes(NodeIndex).SourceToken)
        Exit Function
    End If
    If Kind = 14 Then
        IsAddressableExpression = IsAddressableExpression(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, Parameters, Locals, LocalCount, Owner)
        Exit Function
    End If
    If Kind = 13 Then
        Dim AddressedBase As Long = Nodes(NodeIndex).LeftNode
        If Nodes(AddressedBase).NodeKind = 12 Then
            IsAddressableExpression = ExpressionNameIsVariable(Tokens, Procedures, Parameters, Locals, LocalCount, Owner, Nodes(AddressedBase).SourceToken)
            Exit Function
        End If
    End If
    IsAddressableExpression = 0
End Function

Function ResolveExpressionType(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    If Nodes(NodeIndex).ResolvedType <> 0 Then
        ResolveExpressionType = Nodes(NodeIndex).ResolvedType
        Exit Function
    End If
    Dim Kind As Long = Nodes(NodeIndex).NodeKind
    Dim Result As Long = 0
    If Kind = 10 Then
        Result = 2
    Else
        If Kind = 11 Then
            Result = 3
        Else
            If Kind = 12 Then
                Dim TypedNameToken As Long = Nodes(NodeIndex).SourceToken
                If EqualsKeyword(Tokens(TypedNameToken).Spelling, "True") <> 0 Or EqualsKeyword(Tokens(TypedNameToken).Spelling, "False") <> 0 Then
                    Result = 1
                Else
                    Result = FindVariableType(Tokens, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, TypedNameToken)
                End If
            Else
                If Kind = 13 Then
                    Dim TypedCallee As Long = Nodes(NodeIndex).LeftNode
                    Dim ResolvedProcedure As Long = -1
                    Dim IndexedArray As Long = 0
                    If Nodes(TypedCallee).NodeKind = 12 Then
                        Dim TypedCalleeToken As Long = Nodes(TypedCallee).SourceToken
                        Dim VariableType As Long = FindVariableType(Tokens, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, TypedCalleeToken)
                        If VariableType >= 100000 Then
                            Result = VariableType - 100000
                            IndexedArray = 1
                        Else
                            Dim TypedProcedure As Long = FindProcedureByToken(Tokens, Procedures, ProcedureCount, TypedCalleeToken)
                            ResolvedProcedure = TypedProcedure
                            If TypedProcedure >= 0 Then
                                If Procedures(TypedProcedure).ProcedureKind = 2 Then
                                    Result = DeclaredTypeId(Tokens, Procedures(TypedProcedure).ReturnTypeToken, 0, Types, TypeCount)
                                End If
                            Else
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3209", Tokens(TypedCalleeToken).StartByte, Tokens(TypedCalleeToken).ByteLength, "expression is not callable or indexable")
                                ResolveExpressionType = 0
                                Exit Function
                            End If
                        End If
                    Else
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3209", Tokens(Nodes(TypedCallee).SourceToken).StartByte, Tokens(Nodes(TypedCallee).SourceToken).ByteLength, "expression is not callable or indexable")
                        ResolveExpressionType = 0
                        Exit Function
                    End If
                    Dim TypedArgumentLink As Long = Nodes(NodeIndex).RightNode
                    Dim TypedArgumentIndex As Long = 0
                    While TypedArgumentLink >= 0
                        Dim TypedArgumentNode As Long = Nodes(TypedArgumentLink).LeftNode
                        Dim TypedArgumentType As Long = ResolveExpressionType(Tokens, Nodes, TypedArgumentNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
                        If TypedArgumentType = 0 Then
                            ResolveExpressionType = 0
                            Exit Function
                        End If
                        If ResolvedProcedure >= 0 Then
                            If TypedArgumentIndex >= Procedures(ResolvedProcedure).ParameterCount Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3103", Tokens(Nodes(NodeIndex).SourceToken).StartByte, Tokens(Nodes(NodeIndex).SourceToken).ByteLength, "argument count does not match callable")
                                ResolveExpressionType = 0
                                Exit Function
                            End If
                            Dim TypedParameterIndex As Long = Procedures(ResolvedProcedure).FirstParameter + TypedArgumentIndex
                            Dim TypedParameterType As Long = DeclaredTypeId(Tokens, Parameters(TypedParameterIndex).TypeToken, Parameters(TypedParameterIndex).IsDynamicArray, Types, TypeCount)
                            If Parameters(TypedParameterIndex).PassingMode = 1 Or Parameters(TypedParameterIndex).PassingMode = 3 Then
                                If IsAddressableExpression(Tokens, Nodes, TypedArgumentNode, Procedures, Parameters, Locals, LocalCount, Owner) = 0 Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3202", Tokens(Nodes(TypedArgumentNode).SourceToken).StartByte, Tokens(Nodes(TypedArgumentNode).SourceToken).ByteLength, "ByRef argument must be an addressable variable")
                                    ResolveExpressionType = 0
                                    Exit Function
                                End If
                                If TypedArgumentType <> TypedParameterType Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3203", Tokens(Nodes(TypedArgumentNode).SourceToken).StartByte, Tokens(Nodes(TypedArgumentNode).SourceToken).ByteLength, "ByRef argument type must exactly match the parameter")
                                    ResolveExpressionType = 0
                                    Exit Function
                                End If
                            Else
                                If TypedArgumentType <> TypedParameterType And (IsNumericType(TypedArgumentType) = 0 Or IsNumericType(TypedParameterType) = 0) Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3204", Tokens(Nodes(TypedArgumentNode).SourceToken).StartByte, Tokens(Nodes(TypedArgumentNode).SourceToken).ByteLength, "argument type is not assignable to parameter")
                                    ResolveExpressionType = 0
                                    Exit Function
                                End If
                            End If
                        Else
                            If IndexedArray <> 0 And TypedArgumentType <> 2 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3205", Tokens(Nodes(TypedArgumentNode).SourceToken).StartByte, Tokens(Nodes(TypedArgumentNode).SourceToken).ByteLength, "array index must be Long")
                                ResolveExpressionType = 0
                                Exit Function
                            End If
                        End If
                        TypedArgumentIndex = TypedArgumentIndex + 1
                        TypedArgumentLink = Nodes(TypedArgumentLink).RightNode
                    Wend
                Else
                    If Kind = 14 Then
                        Dim BaseType As Long = ResolveExpressionType(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
                        If BaseType >= 1000 And BaseType < 100000 Then
                            Dim OwnerType As Long = BaseType - 1000
                            Dim FieldIndex As Long = Types(OwnerType).FirstField
                            Dim FieldEnd As Long = FieldIndex + Types(OwnerType).FieldCount
                            While FieldIndex < FieldEnd
                                If EqualsIdentifier(Tokens(Fields(FieldIndex).NameToken).Spelling, Tokens(Nodes(NodeIndex).SourceToken).Spelling) <> 0 Then
                                    Result = DeclaredTypeId(Tokens, Fields(FieldIndex).TypeToken, Fields(FieldIndex).IsDynamicArray, Types, TypeCount)
                                    Exit While
                                End If
                                FieldIndex = FieldIndex + 1
                            Wend
                        End If
                    Else
                        If Kind = 16 Then
                            Dim UnaryType As Long = ResolveExpressionType(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
                            Dim UnaryOperator As String = Tokens(Nodes(NodeIndex).OperatorToken).Spelling
                            If UnaryOperator = "+" Or UnaryOperator = "-" Then
                                If IsNumericType(UnaryType) <> 0 Then
                                    Result = UnaryType
                                End If
                            Else
                                If EqualsKeyword(UnaryOperator, "Not") <> 0 And IsIntegralOrBooleanType(UnaryType) <> 0 Then
                                    Result = UnaryType
                                End If
                            End If
                        Else
                            If Kind = 15 Then
                                Dim LeftType As Long = ResolveExpressionType(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
                                Dim RightType As Long = ResolveExpressionType(Tokens, Nodes, Nodes(NodeIndex).RightNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
                                Dim TypedOperator As String = Tokens(Nodes(NodeIndex).OperatorToken).Spelling
                                If TypedOperator = "=" Or TypedOperator = "<>" Or TypedOperator = "<" Or TypedOperator = ">" Or TypedOperator = "<=" Or TypedOperator = ">=" Then
                                    If LeftType = RightType Or (IsNumericType(LeftType) <> 0 And IsNumericType(RightType) <> 0) Then
                                        Result = 1
                                    End If
                                Else
                                    If TypedOperator = "&" Then
                                        If LeftType = 3 And RightType = 3 Then
                                            Result = 3
                                        End If
                                    Else
                                        If EqualsKeyword(TypedOperator, "And") <> 0 Or EqualsKeyword(TypedOperator, "Or") <> 0 Then
                                            If LeftType = RightType And IsIntegralOrBooleanType(LeftType) <> 0 Then
                                                Result = LeftType
                                            End If
                                        Else
                                            Result = CommonNumericType(LeftType, RightType)
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
    If Result = 0 And Kind <> 13 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3200", Tokens(Nodes(NodeIndex).SourceToken).StartByte, Tokens(Nodes(NodeIndex).SourceToken).ByteLength, "expression has incompatible or unresolved types")
        ResolveExpressionType = 0
        Exit Function
    End If
    Nodes(NodeIndex).ResolvedType = Result
    ResolveExpressionType = Result
End Function

Function AnalyzeExpressionTypes(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim LocalIndex As Long = 0
    While LocalIndex < LocalCount
        If Locals(LocalIndex).InitializerNode >= 0 Then
            Dim InitializerType As Long = ResolveExpressionType(Tokens, Nodes, Locals(LocalIndex).InitializerNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Locals(LocalIndex).OwnerProcedure, Diagnostics, DiagnosticCount)
            Dim LocalType As Long = DeclaredTypeId(Tokens, Locals(LocalIndex).TypeToken, Locals(LocalIndex).IsDynamicArray, Types, TypeCount)
            If InitializerType = 0 Or LocalType = 0 Or InitializerType <> LocalType Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3201", Tokens(Locals(LocalIndex).NameToken).StartByte, Tokens(Locals(LocalIndex).NameToken).ByteLength, "local initializer type is not assignable")
                AnalyzeExpressionTypes = 0
                Exit Function
            End If
        End If
        LocalIndex = LocalIndex + 1
    Wend
    Dim StatementIndex As Long = 0
    While StatementIndex < StatementCount
        If Statements(StatementIndex).ValueNode >= 0 Then
            Dim DiagnosticsBeforeStatement As Long = DiagnosticCount
            Dim StatementValueType As Long = ResolveExpressionType(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Statements(StatementIndex).OwnerProcedure, Diagnostics, DiagnosticCount)
            If StatementValueType = 0 Then
                If Statements(StatementIndex).StatementKind <> 2 Or DiagnosticCount <> DiagnosticsBeforeStatement Then
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
            End If
            If Statements(StatementIndex).StatementKind = 1 Then
                If Statements(StatementIndex).TargetNode < 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3206", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "assignment target was not parsed")
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
                If IsAddressableExpression(Tokens, Nodes, Statements(StatementIndex).TargetNode, Procedures, Parameters, Locals, LocalCount, Statements(StatementIndex).OwnerProcedure) = 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3207", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "assignment target is not addressable")
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
                Dim StatementTargetType As Long = ResolveExpressionType(Tokens, Nodes, Statements(StatementIndex).TargetNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Statements(StatementIndex).OwnerProcedure, Diagnostics, DiagnosticCount)
                If StatementTargetType = 0 Or StatementValueType = 0 Or (StatementTargetType <> StatementValueType And (IsNumericType(StatementTargetType) = 0 Or IsNumericType(StatementValueType) = 0)) Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3208", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "assigned value has an incompatible type")
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
            End If
            If Statements(StatementIndex).StatementKind = 4 Then
                Dim ReDimTargetType As Long = ResolveExpressionType(Tokens, Nodes, Statements(StatementIndex).TargetNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Statements(StatementIndex).OwnerProcedure, Diagnostics, DiagnosticCount)
                If ReDimTargetType < 100000 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3211", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "ReDim target must be a dynamic array")
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
                If StatementValueType <> 2 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3212", Tokens(Statements(StatementIndex).OperatorToken).StartByte, Tokens(Statements(StatementIndex).OperatorToken).ByteLength, "ReDim upper bound must be Long")
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
            End If
            If Statements(StatementIndex).StatementKind = 10 Or Statements(StatementIndex).StatementKind = 14 Then
                If IsIntegralOrBooleanType(StatementValueType) = 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3210", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "structured statement condition must be Boolean or integral")
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
            End If
        End If
        StatementIndex = StatementIndex + 1
    Wend
    AnalyzeExpressionTypes = 1
End Function

Function LowerProgramToIr(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeCount As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByRef IrProcedures() As IrProcedure, ByRef Instructions() As IrInstruction, ByRef InstructionCount As Long, ByRef InstructionCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    If ProcedureCount <= 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3300", 0, 0, "cannot lower a program without procedures")
        LowerProgramToIr = 0
        Exit Function
    End If
    ReDim IrProcedures(ProcedureCount - 1)
    Dim ProcedureIndex As Long = 0
    While ProcedureIndex < ProcedureCount
        IrProcedures(ProcedureIndex).SourceProcedure = ProcedureIndex
        IrProcedures(ProcedureIndex).FirstInstruction = InstructionCount
        Dim StatementIndex As Long = 0
        While StatementIndex < StatementCount
            If Statements(StatementIndex).OwnerProcedure = ProcedureIndex Then
                Dim Opcode As Long = Statements(StatementIndex).StatementKind
                Dim OperandA As Long = Statements(StatementIndex).TargetNode
                Dim OperandB As Long = Statements(StatementIndex).ValueNode
                Dim ResultType As Long = 0
                If OperandB >= 0 Then
                    If OperandB >= NodeCount Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3301", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "statement contains an invalid expression node")
                        LowerProgramToIr = 0
                        Exit Function
                    End If
                    ResultType = Nodes(OperandB).ResolvedType
                End If
                If Opcode = 7 Then
                    OperandA = -1
                    Dim LocalIndex As Long = 0
                    While LocalIndex < LocalCount
                        If Locals(LocalIndex).OwnerProcedure = ProcedureIndex Then
                            If EqualsIdentifier(Tokens(Locals(LocalIndex).NameToken).Spelling, Tokens(Statements(StatementIndex).OperatorToken).Spelling) <> 0 Then
                                OperandA = LocalIndex
                                OperandB = Locals(LocalIndex).InitializerNode
                                ResultType = DeclaredTypeId(Tokens, Locals(LocalIndex).TypeToken, Locals(LocalIndex).IsDynamicArray, Types, TypeCount)
                                Exit While
                            End If
                        End If
                        LocalIndex = LocalIndex + 1
                    Wend
                    If OperandA < 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3302", Tokens(Statements(StatementIndex).OperatorToken).StartByte, Tokens(Statements(StatementIndex).OperatorToken).ByteLength, "declaration statement has no matching local")
                        LowerProgramToIr = 0
                        Exit Function
                    End If
                End If
                If AppendIrInstruction(Instructions, InstructionCount, InstructionCapacity, Opcode, ProcedureIndex, ResultType, OperandA, OperandB, Statements(StatementIndex).FirstToken, Statements(StatementIndex).Flags) < 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3303", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "IR instruction limit exceeded")
                    LowerProgramToIr = 0
                    Exit Function
                End If
            End If
            StatementIndex = StatementIndex + 1
        Wend
        IrProcedures(ProcedureIndex).InstructionCount = InstructionCount - IrProcedures(ProcedureIndex).FirstInstruction
        ProcedureIndex = ProcedureIndex + 1
    Wend
    LowerProgramToIr = 1
End Function

Function VerifyProgramIr(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef IrProcedures() As IrProcedure, ByRef Instructions() As IrInstruction, ByVal InstructionCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim ExpectedFirst As Long = 0
    Dim ProcedureIndex As Long = 0
    While ProcedureIndex < ProcedureCount
        If IrProcedures(ProcedureIndex).SourceProcedure <> ProcedureIndex Or IrProcedures(ProcedureIndex).FirstInstruction <> ExpectedFirst Or IrProcedures(ProcedureIndex).InstructionCount < 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3304", Tokens(Procedures(ProcedureIndex).NameToken).StartByte, Tokens(Procedures(ProcedureIndex).NameToken).ByteLength, "IR procedure range is invalid")
            VerifyProgramIr = 0
            Exit Function
        End If
        Dim InstructionEnd As Long = ExpectedFirst + IrProcedures(ProcedureIndex).InstructionCount
        If InstructionEnd < ExpectedFirst Or InstructionEnd > InstructionCount Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3304", Tokens(Procedures(ProcedureIndex).NameToken).StartByte, Tokens(Procedures(ProcedureIndex).NameToken).ByteLength, "IR procedure range exceeds instruction storage")
            VerifyProgramIr = 0
            Exit Function
        End If
        Dim InstructionIndex As Long = ExpectedFirst
        While InstructionIndex < InstructionEnd
            If Instructions(InstructionIndex).OwnerProcedure <> ProcedureIndex Or Instructions(InstructionIndex).Opcode < 1 Or Instructions(InstructionIndex).Opcode > 15 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3305", Tokens(Procedures(ProcedureIndex).NameToken).StartByte, Tokens(Procedures(ProcedureIndex).NameToken).ByteLength, "IR instruction is invalid or belongs to the wrong procedure")
                VerifyProgramIr = 0
                Exit Function
            End If
            InstructionIndex = InstructionIndex + 1
        Wend
        ExpectedFirst = InstructionEnd
        ProcedureIndex = ProcedureIndex + 1
    Wend
    If ExpectedFirst <> InstructionCount Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3306", 0, 0, "IR contains instructions outside procedure ranges")
        VerifyProgramIr = 0
        Exit Function
    End If
    VerifyProgramIr = 1
End Function

Function ValidateProcedureResults(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim ProcedureIndex As Long = 0
    While ProcedureIndex < ProcedureCount
        If Procedures(ProcedureIndex).IsIntrinsic = 0 And Procedures(ProcedureIndex).ProcedureKind = 2 Then
            Dim HasResultAssignment As Long = 0
            Dim StatementIndex As Long = 0
            While StatementIndex < StatementCount
                If Statements(StatementIndex).OwnerProcedure = ProcedureIndex And Statements(StatementIndex).StatementKind = 1 Then
                    Dim TargetNode As Long = Statements(StatementIndex).TargetNode
                    If TargetNode >= 0 Then
                        If Nodes(TargetNode).NodeKind = 12 Then
                            If EqualsIdentifier(Tokens(Nodes(TargetNode).SourceToken).Spelling, Tokens(Procedures(ProcedureIndex).NameToken).Spelling) <> 0 Then
                                HasResultAssignment = 1
                                Exit While
                            End If
                        End If
                    End If
                End If
                StatementIndex = StatementIndex + 1
            Wend
            If HasResultAssignment = 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2003", Tokens(Procedures(ProcedureIndex).NameToken).StartByte, Tokens(Procedures(ProcedureIndex).NameToken).ByteLength, "Function must assign its result before returning")
                ValidateProcedureResults = 0
                Exit Function
            End If
        End If
        ProcedureIndex = ProcedureIndex + 1
    Wend
    ValidateProcedureResults = 1
End Function

Sub EmitProgramPreamble(ByRef Tokens() As Token, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByVal NewLine As String)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "; generated by UBE Compiler v2" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "target triple = ""x86_64-w64-windows-gnu""" & NewLine & NewLine)
    Dim TypeIndex As Long = 0
    While TypeIndex < TypeCount
        Dim TypeLine As String = "%ube.type." & LongToString(TypeIndex) & " = type { "
        Dim FieldIndex As Long = Types(TypeIndex).FirstField
        Dim FieldEnd As Long = FieldIndex + Types(TypeIndex).FieldCount
        While FieldIndex < FieldEnd
            If FieldIndex > Types(TypeIndex).FirstField Then
                TypeLine = TypeLine & ", "
            End If
            Dim FieldTypeId As Long = DeclaredTypeId(Tokens, Fields(FieldIndex).TypeToken, Fields(FieldIndex).IsDynamicArray, Types, TypeCount)
            Dim FieldLlvmType As String = ""
            Call LlvmTypeName(FieldTypeId, FieldLlvmType)
            TypeLine = TypeLine & FieldLlvmType
            FieldIndex = FieldIndex + 1
        Wend
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, TypeLine & " }" & NewLine)
        TypeIndex = TypeIndex + 1
    Wend
    If TypeCount > 0 Then
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, NewLine)
    End If
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_i32(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_i64(i64)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_f64(double)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_string(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_print_newline()" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_checked_add_i32(i32, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_checked_sub_i32(i32, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_checked_mul_i32(i32, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_checked_div_i32(i32, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_checked_mod_i32(i32, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_checked_neg_i32(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_concat(ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_compare(ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_length(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_byte_at(ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_slice(ptr, i32, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_string_index_of(ptr, ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_from_byte(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_long_to_string(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_runtime_set_args(i32, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_command_argument_count()" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_command_argument(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_read_all_text(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_write_all_text(ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_array_join(ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_run_tool(ptr, ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_delete_file(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_validate_resource(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_compiler_resource_llvm_escape(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_validate_library_bundle(ptr, ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_is_letter(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_simple_fold_code_point(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_array_redim(ptr, i32, i32, i64, i1)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_array_release(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_array_element(ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_array_lbound(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_array_ubound(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @puts(ptr)" & NewLine & NewLine)
End Sub

Sub EmitNameAddress(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByVal Owner As Long, ByVal NameToken As Long, ByRef Address As String, ByRef TypeId As Long)
    Address = ""
    TypeId = 0
    Dim ParameterIndex As Long = Procedures(Owner).FirstParameter
    Dim ParameterEnd As Long = ParameterIndex + Procedures(Owner).ParameterCount
    While ParameterIndex < ParameterEnd
        If EqualsIdentifier(Tokens(Parameters(ParameterIndex).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
            TypeId = DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, Parameters(ParameterIndex).IsDynamicArray, Types, TypeCount)
            If Parameters(ParameterIndex).PassingMode = 2 Then
                Address = "%param." & LongToString(ParameterIndex)
            Else
                Address = "%arg." & LongToString(ParameterIndex)
            End If
            Exit Sub
        End If
        ParameterIndex = ParameterIndex + 1
    Wend
    Dim LocalIndex As Long = 0
    While LocalIndex < LocalCount
        If Locals(LocalIndex).OwnerProcedure = Owner Then
            If EqualsIdentifier(Tokens(Locals(LocalIndex).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
                TypeId = DeclaredTypeId(Tokens, Locals(LocalIndex).TypeToken, Locals(LocalIndex).IsDynamicArray, Types, TypeCount)
                Address = "%local." & LongToString(LocalIndex)
                Exit Sub
            End If
        End If
        LocalIndex = LocalIndex + 1
    Wend
    If Procedures(Owner).ProcedureKind = 2 Then
        If EqualsIdentifier(Tokens(Procedures(Owner).NameToken).Spelling, Tokens(NameToken).Spelling) <> 0 Then
            TypeId = DeclaredTypeId(Tokens, Procedures(Owner).ReturnTypeToken, 0, Types, TypeCount)
            Address = "%result"
        End If
    End If
End Sub

Sub EmitProcedureHeader(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByVal ProcedureIndex As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByVal NewLine As String)
    Dim ReturnTypeId As Long = 0
    Dim ReturnLlvmType As String = "void"
    If Procedures(ProcedureIndex).ProcedureKind = 2 Then
        ReturnTypeId = DeclaredTypeId(Tokens, Procedures(ProcedureIndex).ReturnTypeToken, 0, Types, TypeCount)
        Call LlvmTypeName(ReturnTypeId, ReturnLlvmType)
    End If
    Dim Symbol As String = ""
    Call ProcedureLlvmSymbol(ProcedureIndex, Symbol)
    Dim Header As String = "define " & ReturnLlvmType & " " & Symbol & "("
    Dim ParameterIndex As Long = Procedures(ProcedureIndex).FirstParameter
    Dim ParameterEnd As Long = ParameterIndex + Procedures(ProcedureIndex).ParameterCount
    While ParameterIndex < ParameterEnd
        If ParameterIndex > Procedures(ProcedureIndex).FirstParameter Then
            Header = Header & ", "
        End If
        Dim ParameterTypeId As Long = DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, Parameters(ParameterIndex).IsDynamicArray, Types, TypeCount)
        Dim ParameterLlvmType As String = ""
        If Parameters(ParameterIndex).PassingMode = 2 Then
            Call LlvmTypeName(ParameterTypeId, ParameterLlvmType)
        Else
            ParameterLlvmType = "ptr"
        End If
        Header = Header & ParameterLlvmType & " %arg." & LongToString(ParameterIndex)
        ParameterIndex = ParameterIndex + 1
    Wend
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, Header & ") {" & NewLine & "entry:" & NewLine)
    ParameterIndex = Procedures(ProcedureIndex).FirstParameter
    While ParameterIndex < ParameterEnd
        If Parameters(ParameterIndex).PassingMode = 2 Then
            Dim ByValTypeId As Long = DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, Parameters(ParameterIndex).IsDynamicArray, Types, TypeCount)
            Dim ByValLlvmType As String = ""
            Call LlvmTypeName(ByValTypeId, ByValLlvmType)
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %param." & LongToString(ParameterIndex) & " = alloca " & ByValLlvmType & NewLine)
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store " & ByValLlvmType & " %arg." & LongToString(ParameterIndex) & ", ptr %param." & LongToString(ParameterIndex) & NewLine)
        End If
        ParameterIndex = ParameterIndex + 1
    Wend
    If Procedures(ProcedureIndex).ProcedureKind = 2 Then
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %result = alloca " & ReturnLlvmType & NewLine)
        Dim ResultInitial As String = "0"
        If ReturnTypeId = 3 Or ReturnTypeId >= 100000 Then
            ResultInitial = "null"
        Else
            If ReturnTypeId >= 1000 Then
                ResultInitial = "zeroinitializer"
            End If
        End If
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store " & ReturnLlvmType & " " & ResultInitial & ", ptr %result" & NewLine)
    End If
    Dim LocalIndex As Long = 0
    While LocalIndex < LocalCount
        If Locals(LocalIndex).OwnerProcedure = ProcedureIndex Then
            Dim LocalTypeId As Long = DeclaredTypeId(Tokens, Locals(LocalIndex).TypeToken, Locals(LocalIndex).IsDynamicArray, Types, TypeCount)
            Dim LocalLlvmType As String = ""
            Call LlvmTypeName(LocalTypeId, LocalLlvmType)
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %local." & LongToString(LocalIndex) & " = alloca " & LocalLlvmType & NewLine)
            Dim LocalInitial As String = "0"
            If LocalTypeId = 3 Or LocalTypeId >= 100000 Then
                LocalInitial = "null"
            Else
                If LocalTypeId >= 1000 Then
                    LocalInitial = "zeroinitializer"
                End If
            End If
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store " & LocalLlvmType & " " & LocalInitial & ", ptr %local." & LongToString(LocalIndex) & NewLine)
        End If
        LocalIndex = LocalIndex + 1
    Wend
End Sub

Sub EmitStringConstant(ByVal Value As String, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Operand As String)
    Dim Escaped As String = ""
    Call EscapeLlvmString(Value, Escaped)
    Dim ByteCount As Long = StringLength(Value) + 1
    Dim GlobalName As String = "@.ube.str." & LongToString(State.NextString)
    State.NextString = State.NextString + 1
    Call AppendText(Globals, GlobalCount, GlobalCapacity, GlobalName & " = private unnamed_addr constant [" & LongToString(ByteCount) & " x i8] c""" & Escaped & "\00""" & NewLine)
    Operand = "getelementptr inbounds ([" & LongToString(ByteCount) & " x i8], ptr " & GlobalName & ", i32 0, i32 0)"
End Sub

Sub EmitLvalueAddress(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Address As String, ByRef TypeId As Long)
    Address = ""
    TypeId = 0
    If NodeIndex < 0 Then
        State.Failed = 1
        Exit Sub
    End If
    Dim Kind As Long = Nodes(NodeIndex).NodeKind
    If Kind = 12 Then
        Call EmitNameAddress(Tokens, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, Nodes(NodeIndex).SourceToken, Address, TypeId)
        If Address = "" Then
            State.Failed = 1
        End If
        Exit Sub
    End If
    If Kind = 13 Then
        Dim CalleeNode As Long = Nodes(NodeIndex).LeftNode
        If Nodes(CalleeNode).NodeKind <> 12 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim ArrayAddress As String = ""
        Dim ArrayTypeId As Long = 0
        Call EmitNameAddress(Tokens, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, Nodes(CalleeNode).SourceToken, ArrayAddress, ArrayTypeId)
        If ArrayAddress = "" Or ArrayTypeId < 100000 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim ArgumentLink As Long = Nodes(NodeIndex).RightNode
        If ArgumentLink < 0 Or Nodes(ArgumentLink).RightNode >= 0 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim IndexOperand As String = ""
        Dim IndexTypeId As Long = 0
        Call EmitExpression(Tokens, Nodes, Nodes(ArgumentLink).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, IndexOperand, IndexTypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Dim Handle As String = ""
        Call NextLlvmRegister(State, Handle)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Handle & " = load ptr, ptr " & ArrayAddress & NewLine)
        Call NextLlvmRegister(State, Address)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Address & " = call ptr @ube_array_element(ptr " & Handle & ", i32 " & IndexOperand & ")" & NewLine)
        TypeId = ArrayTypeId - 100000
        Exit Sub
    End If
    If Kind = 14 Then
        Dim BaseAddress As String = ""
        Dim BaseTypeId As Long = 0
        Call EmitLvalueAddress(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, BaseAddress, BaseTypeId)
        If State.Failed <> 0 Or BaseTypeId < 1000 Or BaseTypeId >= 100000 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim RecordIndex As Long = BaseTypeId - 1000
        Dim FieldIndex As Long = Types(RecordIndex).FirstField
        Dim FieldEnd As Long = FieldIndex + Types(RecordIndex).FieldCount
        Dim FieldOffset As Long = 0
        While FieldIndex < FieldEnd
            If EqualsIdentifier(Tokens(Fields(FieldIndex).NameToken).Spelling, Tokens(Nodes(NodeIndex).SourceToken).Spelling) <> 0 Then
                TypeId = DeclaredTypeId(Tokens, Fields(FieldIndex).TypeToken, Fields(FieldIndex).IsDynamicArray, Types, TypeCount)
                Call NextLlvmRegister(State, Address)
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Address & " = getelementptr inbounds %ube.type." & LongToString(RecordIndex) & ", ptr " & BaseAddress & ", i32 0, i32 " & LongToString(FieldOffset) & NewLine)
                Exit Sub
            End If
            FieldOffset = FieldOffset + 1
            FieldIndex = FieldIndex + 1
        Wend
        State.Failed = 1
        Exit Sub
    End If
    State.Failed = 1
End Sub

Sub EmitExpression(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Operand As String, ByRef TypeId As Long)
    Operand = ""
    TypeId = 0
    If NodeIndex < 0 Then
        State.Failed = 1
        Exit Sub
    End If
    Dim Kind As Long = Nodes(NodeIndex).NodeKind
    TypeId = Nodes(NodeIndex).ResolvedType
    If Kind = 10 Then
        Operand = Tokens(Nodes(NodeIndex).SourceToken).Spelling
        Exit Sub
    End If
    If Kind = 11 Then
        Call EmitStringConstant(Tokens(Nodes(NodeIndex).SourceToken).Decoded, Globals, GlobalCount, GlobalCapacity, State, NewLine, Operand)
        Exit Sub
    End If
    If Kind = 12 Then
        Dim NameToken As Long = Nodes(NodeIndex).SourceToken
        If EqualsKeyword(Tokens(NameToken).Spelling, "True") <> 0 Then
            Operand = "true"
            TypeId = 1
            Exit Sub
        End If
        If EqualsKeyword(Tokens(NameToken).Spelling, "False") <> 0 Then
            Operand = "false"
            TypeId = 1
            Exit Sub
        End If
        Dim Address As String = ""
        Call EmitNameAddress(Tokens, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, NameToken, Address, TypeId)
        If Address = "" Or TypeId = 0 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim ValueType As String = ""
        Call LlvmTypeName(TypeId, ValueType)
        Call NextLlvmRegister(State, Operand)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = load " & ValueType & ", ptr " & Address & NewLine)
        Exit Sub
    End If
    If Kind = 14 Then
        Dim MemberAddress As String = ""
        Call EmitLvalueAddress(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, MemberAddress, TypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Dim MemberLlvmType As String = ""
        Call LlvmTypeName(TypeId, MemberLlvmType)
        Call NextLlvmRegister(State, Operand)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = load " & MemberLlvmType & ", ptr " & MemberAddress & NewLine)
        Exit Sub
    End If
    If Kind = 13 Then
        Dim CallCalleeNode As Long = Nodes(NodeIndex).LeftNode
        If Nodes(CallCalleeNode).NodeKind <> 12 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim CallNameToken As Long = Nodes(CallCalleeNode).SourceToken
        Dim CallVariableType As Long = FindVariableType(Tokens, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, CallNameToken)
        If CallVariableType >= 100000 Then
            Dim ElementAddress As String = ""
            Call EmitLvalueAddress(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, ElementAddress, TypeId)
            If State.Failed <> 0 Then
                Exit Sub
            End If
            Dim ElementLlvmType As String = ""
            Call LlvmTypeName(TypeId, ElementLlvmType)
            Call NextLlvmRegister(State, Operand)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = load " & ElementLlvmType & ", ptr " & ElementAddress & NewLine)
            Exit Sub
        End If
        Dim CalledProcedure As Long = FindProcedureByToken(Tokens, Procedures, ProcedureCount, CallNameToken)
        If CalledProcedure < 0 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim CallSymbol As String = ""
        If Procedures(CalledProcedure).IsIntrinsic <> 0 Then
            Call IntrinsicLlvmSymbol(Tokens(Procedures(CalledProcedure).NameToken).Spelling, CallSymbol)
        Else
            Call ProcedureLlvmSymbol(CalledProcedure, CallSymbol)
        End If
        If CallSymbol = "" Then
            State.Failed = 1
            Exit Sub
        End If
        Dim Arguments As String = ""
        Dim CallArgumentLink As Long = Nodes(NodeIndex).RightNode
        Dim CallArgumentIndex As Long = 0
        While CallArgumentLink >= 0
            If CallArgumentIndex >= Procedures(CalledProcedure).ParameterCount Then
                State.Failed = 1
                Exit Sub
            End If
            If CallArgumentIndex > 0 Then
                Arguments = Arguments & ", "
            End If
            Dim CalledParameter As Long = Procedures(CalledProcedure).FirstParameter + CallArgumentIndex
            Dim CallArgumentNode As Long = Nodes(CallArgumentLink).LeftNode
            Dim CallArgumentOperand As String = ""
            Dim CallArgumentType As Long = 0
            If Parameters(CalledParameter).PassingMode = 1 Or Parameters(CalledParameter).PassingMode = 3 Then
                Call EmitLvalueAddress(Tokens, Nodes, CallArgumentNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, CallArgumentOperand, CallArgumentType)
                If State.Failed <> 0 Then
                    Exit Sub
                End If
                Arguments = Arguments & "ptr " & CallArgumentOperand
            Else
                Call EmitExpression(Tokens, Nodes, CallArgumentNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, CallArgumentOperand, CallArgumentType)
                If State.Failed <> 0 Then
                    Exit Sub
                End If
                Dim CallArgumentLlvmType As String = ""
                Call LlvmTypeName(CallArgumentType, CallArgumentLlvmType)
                Arguments = Arguments & CallArgumentLlvmType & " " & CallArgumentOperand
            End If
            CallArgumentIndex = CallArgumentIndex + 1
            CallArgumentLink = Nodes(CallArgumentLink).RightNode
        Wend
        If Procedures(CalledProcedure).ProcedureKind = 2 Then
            TypeId = DeclaredTypeId(Tokens, Procedures(CalledProcedure).ReturnTypeToken, 0, Types, TypeCount)
            Dim CallReturnLlvmType As String = ""
            Call LlvmTypeName(TypeId, CallReturnLlvmType)
            Call NextLlvmRegister(State, Operand)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call " & CallReturnLlvmType & " " & CallSymbol & "(" & Arguments & ")" & NewLine)
        Else
            TypeId = 0
            Operand = ""
            Call AppendText(Body, BodyCount, BodyCapacity, "  call void " & CallSymbol & "(" & Arguments & ")" & NewLine)
        End If
        Exit Sub
    End If
    If Kind = 16 Then
        Dim UnaryOperand As String = ""
        Dim UnaryTypeId As Long = 0
        Call EmitExpression(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, UnaryOperand, UnaryTypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Dim UnaryOperator As String = Tokens(Nodes(NodeIndex).OperatorToken).Spelling
        If UnaryOperator = "+" Then
            Operand = UnaryOperand
            TypeId = UnaryTypeId
            Exit Sub
        End If
        Dim UnaryLlvmType As String = ""
        Call LlvmTypeName(UnaryTypeId, UnaryLlvmType)
        Call NextLlvmRegister(State, Operand)
        If UnaryOperator = "-" Then
            If UnaryTypeId = 2 Or UnaryTypeId = 4 Then
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call i32 @ube_checked_neg_i32(i32 " & UnaryOperand & ")" & NewLine)
            Else
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = sub " & UnaryLlvmType & " 0, " & UnaryOperand & NewLine)
            End If
            Exit Sub
        End If
        If EqualsKeyword(UnaryOperator, "Not") <> 0 Then
            If UnaryTypeId = 1 Then
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = xor i1 " & UnaryOperand & ", true" & NewLine)
            Else
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = xor " & UnaryLlvmType & " " & UnaryOperand & ", -1" & NewLine)
            End If
            Exit Sub
        End If
        State.Failed = 1
        Exit Sub
    End If
    If Kind = 15 Then
        Dim LeftOperand As String = ""
        Dim RightOperand As String = ""
        Dim LeftTypeId As Long = 0
        Dim RightTypeId As Long = 0
        Call EmitExpression(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, LeftOperand, LeftTypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Call EmitExpression(Tokens, Nodes, Nodes(NodeIndex).RightNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, RightOperand, RightTypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Dim BinaryOperator As String = Tokens(Nodes(NodeIndex).OperatorToken).Spelling
        Call NextLlvmRegister(State, Operand)
        If BinaryOperator = "&" Then
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call ptr @ube_string_concat(ptr " & LeftOperand & ", ptr " & RightOperand & ")" & NewLine)
            Exit Sub
        End If
        If EqualsKeyword(BinaryOperator, "And") <> 0 Or EqualsKeyword(BinaryOperator, "Or") <> 0 Then
            Dim LogicOpcode As String = "and"
            If EqualsKeyword(BinaryOperator, "Or") <> 0 Then
                LogicOpcode = "or"
            End If
            Dim LogicType As String = ""
            Call LlvmTypeName(LeftTypeId, LogicType)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = " & LogicOpcode & " " & LogicType & " " & LeftOperand & ", " & RightOperand & NewLine)
            Exit Sub
        End If
        Dim IsComparison As Long = 0
        If BinaryOperator = "=" Or BinaryOperator = "<>" Or BinaryOperator = "<" Or BinaryOperator = ">" Or BinaryOperator = "<=" Or BinaryOperator = ">=" Then
            IsComparison = 1
        End If
        If IsComparison <> 0 Then
            Dim CompareLeft As String = LeftOperand
            If LeftTypeId = 3 Then
                Dim StringCompare As String = Operand
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & StringCompare & " = call i32 @ube_string_compare(ptr " & LeftOperand & ", ptr " & RightOperand & ")" & NewLine)
                Call NextLlvmRegister(State, Operand)
                CompareLeft = StringCompare
                LeftTypeId = 2
                RightOperand = "0"
            End If
            Dim Predicate As String = "eq"
            If BinaryOperator = "<>" Then
                Predicate = "ne"
            End If
            If BinaryOperator = "<" Then
                Predicate = "slt"
            End If
            If BinaryOperator = ">" Then
                Predicate = "sgt"
            End If
            If BinaryOperator = "<=" Then
                Predicate = "sle"
            End If
            If BinaryOperator = ">=" Then
                Predicate = "sge"
            End If
            Dim CompareType As String = ""
            Call LlvmTypeName(LeftTypeId, CompareType)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = icmp " & Predicate & " " & CompareType & " " & CompareLeft & ", " & RightOperand & NewLine)
            TypeId = 1
            Exit Sub
        End If
        If LeftTypeId = 2 Or LeftTypeId = 4 Then
            Dim ArithmeticHelper As String = ""
            If BinaryOperator = "+" Then
                ArithmeticHelper = "add"
            End If
            If BinaryOperator = "-" Then
                ArithmeticHelper = "sub"
            End If
            If BinaryOperator = "*" Then
                ArithmeticHelper = "mul"
            End If
            If BinaryOperator = "\" Then
                ArithmeticHelper = "div"
            End If
            If EqualsKeyword(BinaryOperator, "Mod") <> 0 Then
                ArithmeticHelper = "mod"
            End If
            If ArithmeticHelper <> "" Then
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call i32 @ube_checked_" & ArithmeticHelper & "_i32(i32 " & LeftOperand & ", i32 " & RightOperand & ")" & NewLine)
                Exit Sub
            End If
        End If
        State.Failed = 1
        Exit Sub
    End If
    State.Failed = 1
End Sub

Sub EmitStructuredProcedureBody(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String)
    Call EmitProcedureHeader(Tokens, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, Body, BodyCount, BodyCapacity, NewLine)
    State.CurrentTerminated = 0
    Dim BlockKinds() As Long
    Dim BlockConditionLabels() As String
    Dim BlockElseLabels() As String
    Dim BlockEndLabels() As String
    Dim BlockSawElse() As Long
    ReDim BlockKinds(1023)
    ReDim BlockConditionLabels(1023)
    ReDim BlockElseLabels(1023)
    ReDim BlockEndLabels(1023)
    ReDim BlockSawElse(1023)
    Dim BlockDepth As Long = 0
    Dim StatementIndex As Long = 0
    While StatementIndex < StatementCount
        If Statements(StatementIndex).OwnerProcedure = Owner Then
            Dim Kind As Long = Statements(StatementIndex).StatementKind
            If Kind = 10 Or Kind = 14 Then
                If BlockDepth >= 1024 Then
                    State.Failed = 1
                    Exit Sub
                End If
                Dim ConditionLabel As String = "%flow." & LongToString(State.NextLabel)
                State.NextLabel = State.NextLabel + 1
                Dim BodyLabel As String = "%flow." & LongToString(State.NextLabel)
                State.NextLabel = State.NextLabel + 1
                Dim AlternateLabel As String = "%flow." & LongToString(State.NextLabel)
                State.NextLabel = State.NextLabel + 1
                Dim EndLabel As String = "%flow." & LongToString(State.NextLabel)
                State.NextLabel = State.NextLabel + 1
                If Kind = 14 Then
                    If State.CurrentTerminated = 0 Then
                        Call AppendText(Body, BodyCount, BodyCapacity, "  br label " & ConditionLabel & NewLine)
                    End If
                    Call AppendText(Body, BodyCount, BodyCapacity, StringSlice(ConditionLabel, 1, StringLength(ConditionLabel) - 1) & ":" & NewLine)
                    State.CurrentTerminated = 0
                End If
                Dim ConditionOperand As String = ""
                Dim ConditionTypeId As Long = 0
                Call EmitExpression(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, ConditionOperand, ConditionTypeId)
                If State.Failed <> 0 Then
                    Exit Sub
                End If
                If ConditionTypeId <> 1 Then
                    Dim NormalizedCondition As String = ""
                    Call NextLlvmRegister(State, NormalizedCondition)
                    Dim ConditionLlvmType As String = ""
                    Call LlvmTypeName(ConditionTypeId, ConditionLlvmType)
                    Call AppendText(Body, BodyCount, BodyCapacity, "  " & NormalizedCondition & " = icmp ne " & ConditionLlvmType & " " & ConditionOperand & ", 0" & NewLine)
                    ConditionOperand = NormalizedCondition
                End If
                Dim FalseLabel As String = EndLabel
                If Kind = 10 Then
                    FalseLabel = AlternateLabel
                End If
                Call AppendText(Body, BodyCount, BodyCapacity, "  br i1 " & ConditionOperand & ", label " & BodyLabel & ", label " & FalseLabel & NewLine)
                Call AppendText(Body, BodyCount, BodyCapacity, StringSlice(BodyLabel, 1, StringLength(BodyLabel) - 1) & ":" & NewLine)
                State.CurrentTerminated = 0
                BlockKinds(BlockDepth) = Kind
                BlockConditionLabels(BlockDepth) = ConditionLabel
                BlockElseLabels(BlockDepth) = AlternateLabel
                BlockEndLabels(BlockDepth) = EndLabel
                BlockSawElse(BlockDepth) = 0
                BlockDepth = BlockDepth + 1
            Else
                If Kind = 12 Then
                    Dim ElseBlockValid As Long = 0
                    If BlockDepth > 0 Then
                        If BlockKinds(BlockDepth - 1) = 10 Then
                            ElseBlockValid = 1
                        End If
                    End If
                    If ElseBlockValid = 0 Then
                        State.Failed = 1
                        Exit Sub
                    End If
                    If State.CurrentTerminated = 0 Then
                        Call AppendText(Body, BodyCount, BodyCapacity, "  br label " & BlockEndLabels(BlockDepth - 1) & NewLine)
                    End If
                    Call AppendText(Body, BodyCount, BodyCapacity, StringSlice(BlockElseLabels(BlockDepth - 1), 1, StringLength(BlockElseLabels(BlockDepth - 1)) - 1) & ":" & NewLine)
                    State.CurrentTerminated = 0
                    BlockSawElse(BlockDepth - 1) = 1
                Else
                    If Kind = 13 Or Kind = 15 Then
                        If BlockDepth <= 0 Then
                            State.Failed = 1
                            Exit Sub
                        End If
                        If Kind = 13 Then
                            If BlockKinds(BlockDepth - 1) <> 10 Then
                                State.Failed = 1
                                Exit Sub
                            End If
                            If State.CurrentTerminated = 0 Then
                                Call AppendText(Body, BodyCount, BodyCapacity, "  br label " & BlockEndLabels(BlockDepth - 1) & NewLine)
                            End If
                            If BlockSawElse(BlockDepth - 1) = 0 Then
                                Call AppendText(Body, BodyCount, BodyCapacity, StringSlice(BlockElseLabels(BlockDepth - 1), 1, StringLength(BlockElseLabels(BlockDepth - 1)) - 1) & ":" & NewLine)
                                Call AppendText(Body, BodyCount, BodyCapacity, "  br label " & BlockEndLabels(BlockDepth - 1) & NewLine)
                            End If
                        Else
                            If BlockKinds(BlockDepth - 1) <> 14 Then
                                State.Failed = 1
                                Exit Sub
                            End If
                            If State.CurrentTerminated = 0 Then
                                Call AppendText(Body, BodyCount, BodyCapacity, "  br label " & BlockConditionLabels(BlockDepth - 1) & NewLine)
                            End If
                        End If
                        Call AppendText(Body, BodyCount, BodyCapacity, StringSlice(BlockEndLabels(BlockDepth - 1), 1, StringLength(BlockEndLabels(BlockDepth - 1)) - 1) & ":" & NewLine)
                        State.CurrentTerminated = 0
                        BlockDepth = BlockDepth - 1
                    Else
                        If Kind = 5 Then
                            If State.CurrentTerminated = 0 Then
                                Call AppendText(Body, BodyCount, BodyCapacity, "  br label %proc.exit" & NewLine)
                                State.CurrentTerminated = 1
                            End If
                        Else
                            If Kind = 6 Then
                                Dim ExitBlock As Long = BlockDepth - 1
                                While ExitBlock >= 0
                                    If BlockKinds(ExitBlock) = 14 Then
                                        Exit While
                                    End If
                                    ExitBlock = ExitBlock - 1
                                Wend
                                If ExitBlock < 0 Then
                                    State.Failed = 1
                                    Exit Sub
                                End If
                                If State.CurrentTerminated = 0 Then
                                    Call AppendText(Body, BodyCount, BodyCapacity, "  br label " & BlockEndLabels(ExitBlock) & NewLine)
                                    State.CurrentTerminated = 1
                                End If
                            Else
                                If State.CurrentTerminated = 0 Then
                                    Call EmitSimpleStatement(Tokens, Nodes, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Statements, StatementIndex, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine)
                                    If State.Failed <> 0 Then
                                        Exit Sub
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
        StatementIndex = StatementIndex + 1
    Wend
    If BlockDepth <> 0 Then
        State.Failed = 1
        Exit Sub
    End If
    If State.CurrentTerminated = 0 Then
        Call AppendText(Body, BodyCount, BodyCapacity, "  br label %proc.exit" & NewLine)
    End If
    Call AppendText(Body, BodyCount, BodyCapacity, "proc.exit:" & NewLine)
    State.CurrentTerminated = 0
    If Procedures(Owner).ProcedureKind = 2 Then
        Dim ReturnTypeId As Long = DeclaredTypeId(Tokens, Procedures(Owner).ReturnTypeToken, 0, Types, TypeCount)
        Dim ReturnLlvmType As String = ""
        Call LlvmTypeName(ReturnTypeId, ReturnLlvmType)
        Dim ReturnOperand As String = ""
        Call NextLlvmRegister(State, ReturnOperand)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & ReturnOperand & " = load " & ReturnLlvmType & ", ptr %result" & NewLine)
        Call AppendText(Body, BodyCount, BodyCapacity, "  ret " & ReturnLlvmType & " " & ReturnOperand & NewLine & "}" & NewLine & NewLine)
    Else
        Call AppendText(Body, BodyCount, BodyCapacity, "  ret void" & NewLine & "}" & NewLine & NewLine)
    End If
End Sub

Sub EmitEntryProcedureBody(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByVal EntryProcedureIndex As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String)
    Call EmitProcedureHeader(Tokens, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, EntryProcedureIndex, Body, BodyCount, BodyCapacity, NewLine)
    Dim StatementIndex As Long = 0
    While StatementIndex < StatementCount
        If Statements(StatementIndex).OwnerProcedure = EntryProcedureIndex Then
            Dim Kind As Long = Statements(StatementIndex).StatementKind
            If Kind = 7 Then
                Dim DeclarationLocal As Long = -1
                Dim LocalIndex As Long = 0
                While LocalIndex < LocalCount
                    If Locals(LocalIndex).OwnerProcedure = EntryProcedureIndex Then
                        If EqualsIdentifier(Tokens(Locals(LocalIndex).NameToken).Spelling, Tokens(Statements(StatementIndex).OperatorToken).Spelling) <> 0 Then
                            DeclarationLocal = LocalIndex
                            Exit While
                        End If
                    End If
                    LocalIndex = LocalIndex + 1
                Wend
                If DeclarationLocal < 0 Then
                    State.Failed = 1
                    Exit Sub
                End If
                If Locals(DeclarationLocal).InitializerNode >= 0 Then
                    Dim InitializerOperand As String = ""
                    Dim InitializerTypeId As Long = 0
                    Call EmitExpression(Tokens, Nodes, Locals(DeclarationLocal).InitializerNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, EntryProcedureIndex, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, InitializerOperand, InitializerTypeId)
                    If State.Failed <> 0 Then
                        Exit Sub
                    End If
                    Dim InitializerLlvmType As String = ""
                    Call LlvmTypeName(InitializerTypeId, InitializerLlvmType)
                    Call AppendText(Body, BodyCount, BodyCapacity, "  store " & InitializerLlvmType & " " & InitializerOperand & ", ptr %local." & LongToString(DeclarationLocal) & NewLine)
                End If
            Else
                If Kind = 1 Then
                    Dim AssignmentAddress As String = ""
                    Dim AssignmentTypeId As Long = 0
                    Call EmitLvalueAddress(Tokens, Nodes, Statements(StatementIndex).TargetNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, EntryProcedureIndex, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, AssignmentAddress, AssignmentTypeId)
                    If State.Failed <> 0 Then
                        Exit Sub
                    End If
                    Dim AssignmentOperand As String = ""
                    Dim AssignmentValueType As Long = 0
                    Call EmitExpression(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, EntryProcedureIndex, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, AssignmentOperand, AssignmentValueType)
                    If State.Failed <> 0 Then
                        Exit Sub
                    End If
                    Dim AssignmentLlvmType As String = ""
                    Call LlvmTypeName(AssignmentTypeId, AssignmentLlvmType)
                    Call AppendText(Body, BodyCount, BodyCapacity, "  store " & AssignmentLlvmType & " " & AssignmentOperand & ", ptr " & AssignmentAddress & NewLine)
                Else
                    If Kind = 2 Then
                        Dim DiscardedOperand As String = ""
                        Dim DiscardedType As Long = 0
                        Call EmitExpression(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, EntryProcedureIndex, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, DiscardedOperand, DiscardedType)
                        If State.Failed <> 0 Then
                            Exit Sub
                        End If
                    Else
                        If Kind = 3 Then
                            Dim PrintOperand As String = ""
                            Dim PrintTypeId As Long = 0
                            Call EmitExpression(Tokens, Nodes, Statements(StatementIndex).ValueNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, EntryProcedureIndex, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, PrintOperand, PrintTypeId)
                            If State.Failed <> 0 Then
                                Exit Sub
                            End If
                            If PrintTypeId = 3 Then
                                Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_string(ptr " & PrintOperand & ")" & NewLine)
                            Else
                                Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_i32(i32 " & PrintOperand & ")" & NewLine)
                            End If
                            Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_newline()" & NewLine)
                        Else
                            If Kind <> 5 Then
                                State.Failed = 1
                                Exit Sub
                            End If
                        End If
                    End If
                End If
            End If
        End If
        StatementIndex = StatementIndex + 1
    Wend
    If Procedures(EntryProcedureIndex).ProcedureKind = 2 Then
        Dim ReturnTypeId As Long = DeclaredTypeId(Tokens, Procedures(EntryProcedureIndex).ReturnTypeToken, 0, Types, TypeCount)
        Dim ReturnLlvmType As String = ""
        Call LlvmTypeName(ReturnTypeId, ReturnLlvmType)
        Dim ReturnOperand As String = ""
        Call NextLlvmRegister(State, ReturnOperand)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & ReturnOperand & " = load " & ReturnLlvmType & ", ptr %result" & NewLine)
        Call AppendText(Body, BodyCount, BodyCapacity, "  ret " & ReturnLlvmType & " " & ReturnOperand & NewLine & "}" & NewLine & NewLine)
    Else
        Call AppendText(Body, BodyCount, BodyCapacity, "  ret void" & NewLine & "}" & NewLine & NewLine)
    End If
End Sub

Function ParseEntryProcedure(ByRef Tokens() As Token, ByVal Count As Long, ByRef Entry As ProcedureSyntax, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Entry.ProcedureKind = 0
    Entry.HeaderToken = -1
    Entry.EndToken = -1
    Entry.PrintExpressionNode = -1
    Entry.ResultExpressionNode = -1
    Dim Index As Long = 0
    While Index + 1 < Count
        Dim CandidateKind As Long = 0
        If Tokens(Index).TokenKind = 1 Then
            If EqualsKeyword(Tokens(Index).Spelling, "Sub") <> 0 Then
                CandidateKind = 1
            Else
                If EqualsKeyword(Tokens(Index).Spelling, "Function") <> 0 Then
                    CandidateKind = 2
                End If
            End If
        End If
        If CandidateKind <> 0 And Tokens(Index + 1).TokenKind = 1 Then
            If EqualsKeyword(Tokens(Index + 1).Spelling, "Main") <> 0 Then
                If Entry.ProcedureKind <> 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2001", Tokens(Index).StartByte, Tokens(Index).ByteLength, "duplicate Main procedure")
                    ParseEntryProcedure = 0
                    Exit Function
                End If
                Entry.ProcedureKind = CandidateKind
                Entry.HeaderToken = Index
                Dim BodyIndex As Long = Index + 2
                While BodyIndex + 1 < Count
                    If Tokens(BodyIndex).TokenKind = 1 And EqualsKeyword(Tokens(BodyIndex).Spelling, "End") <> 0 Then
                        If Tokens(BodyIndex + 1).TokenKind = 1 Then
                            If CandidateKind = 1 And EqualsKeyword(Tokens(BodyIndex + 1).Spelling, "Sub") <> 0 Then
                                Entry.EndToken = BodyIndex + 1
                                Exit While
                            End If
                            If CandidateKind = 2 And EqualsKeyword(Tokens(BodyIndex + 1).Spelling, "Function") <> 0 Then
                                Entry.EndToken = BodyIndex + 1
                                Exit While
                            End If
                        End If
                    End If
                    If Entry.PrintExpressionNode < 0 And Tokens(BodyIndex).TokenKind = 1 And EqualsKeyword(Tokens(BodyIndex).Spelling, "Print") <> 0 Then
                        If BodyIndex + 1 < Count Then
                            Dim ExpressionCursor As Long = BodyIndex + 1
                            Entry.PrintExpressionNode = ParseStringExpression(Tokens, Count, ExpressionCursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
                            If Entry.PrintExpressionNode < 0 Then
                                ParseEntryProcedure = 0
                                Exit Function
                            End If
                        End If
                    End If
                    If CandidateKind = 2 And Entry.ResultExpressionNode < 0 And Tokens(BodyIndex).TokenKind = 1 And EqualsKeyword(Tokens(BodyIndex).Spelling, "Main") <> 0 Then
                        If BodyIndex + 2 < Count Then
                            If Tokens(BodyIndex + 1).TokenKind = 7 Then
                                Dim ResultCursor As Long = BodyIndex + 2
                                Entry.ResultExpressionNode = ParseIntegerPrimary(Tokens, Count, ResultCursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
                                If Entry.ResultExpressionNode < 0 Then
                                    ParseEntryProcedure = 0
                                    Exit Function
                                End If
                            End If
                        End If
                    End If
                    BodyIndex = BodyIndex + 1
                Wend
                If Entry.EndToken < 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2004", Tokens(Index).StartByte, Tokens(Index).ByteLength, "unterminated Main procedure")
                    ParseEntryProcedure = 0
                    Exit Function
                End If
                Index = Entry.EndToken
            End If
        End If
        Index = Index + 1
    Wend
    If Entry.ProcedureKind = 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2000", 0, 0, "expected Sub Main or Function Main")
        ParseEntryProcedure = 0
        Exit Function
    End If
    If Entry.PrintExpressionNode < 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2002", Tokens(Entry.HeaderToken).StartByte, Tokens(Entry.HeaderToken).ByteLength, "Main requires a Print string statement")
        ParseEntryProcedure = 0
        Exit Function
    End If
    If Entry.ProcedureKind = 2 And Entry.ResultExpressionNode < 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2003", Tokens(Entry.HeaderToken).StartByte, Tokens(Entry.HeaderToken).ByteLength, "Function Main must assign an integer exit code")
        ParseEntryProcedure = 0
        Exit Function
    End If
    ParseEntryProcedure = 1
End Function

Sub TrimManifestText(ByVal Value As String, ByRef Result As String)
    Dim First As Long = 0
    Dim Last As Long = StringLength(Value)
    While First < Last
        Dim FirstByte As Long = StringByteAt(Value, First)
        If FirstByte = 32 Or FirstByte = 9 Then
            First = First + 1
        Else
            Exit While
        End If
    Wend
    While Last > First
        Dim LastByte As Long = StringByteAt(Value, Last - 1)
        If LastByte = 32 Or LastByte = 9 Or LastByte = 13 Then
            Last = Last - 1
        Else
            Exit While
        End If
    Wend
    Result = StringSlice(Value, First, Last - First)
End Sub

Function NormalizeProjectSourcePath(ByVal Value As String, ByRef Normalized As String) As Long
    Normalized = ""
    Dim ValueLength As Long = StringLength(Value)
    If ValueLength = 0 Then
        NormalizeProjectSourcePath = 0
        Exit Function
    End If
    Dim FirstByte As Long = StringByteAt(Value, 0)
    If FirstByte = 47 Or FirstByte = 92 Then
        NormalizeProjectSourcePath = 0
        Exit Function
    End If
    If StringIndexOf(Value, ":", 0) >= 0 Then
        NormalizeProjectSourcePath = 0
        Exit Function
    End If
    Dim SegmentStart As Long = 0
    Dim Index As Long = 0
    While Index <= ValueLength
        Dim AtSeparator As Long = 0
        If Index = ValueLength Then
            AtSeparator = 1
        Else
            Dim CurrentByte As Long = StringByteAt(Value, Index)
            If CurrentByte = 47 Or CurrentByte = 92 Then
                AtSeparator = 1
            End If
        End If
        If AtSeparator <> 0 Then
            Dim SegmentLength As Long = Index - SegmentStart
            If SegmentLength = 0 Then
                NormalizeProjectSourcePath = 0
                Exit Function
            End If
            Dim Segment As String = StringSlice(Value, SegmentStart, SegmentLength)
            If Segment = ".." Then
                NormalizeProjectSourcePath = 0
                Exit Function
            End If
            If Segment <> "." Then
                If StringLength(Normalized) > 0 Then
                    Normalized = Normalized & "/"
                End If
                Normalized = Normalized & Segment
            End If
            SegmentStart = Index + 1
        End If
        Index = Index + 1
    Wend
    Dim NormalizedLength As Long = StringLength(Normalized)
    If NormalizedLength < 4 Then
        NormalizeProjectSourcePath = 0
        Exit Function
    End If
    If EqualsIdentifier(StringSlice(Normalized, NormalizedLength - 4, 4), ".bas") = 0 Then
        NormalizeProjectSourcePath = 0
        Exit Function
    End If
    NormalizeProjectSourcePath = 1
End Function

Function ResolveSourceInput(ByVal InputPath As String, ByRef SourcePaths() As String, ByRef SourceCount As Long, ByRef SourceCapacity As Long, ByRef ErrorMessage As String) As Long
    SourceCount = 0
    ErrorMessage = ""
    Dim InputLength As Long = StringLength(InputPath)
    If InputLength >= 4 Then
        Dim InputSuffix As String = StringSlice(InputPath, InputLength - 4, 4)
        If EqualsIdentifier(InputSuffix, ".UBG") <> 0 Or EqualsIdentifier(InputSuffix, ".UBR") <> 0 Then
            ErrorMessage = "error UBE5000: project groups and resource sidecars are not compiler source inputs"
            ResolveSourceInput = 0
            Exit Function
        End If
        If EqualsIdentifier(InputSuffix, ".UBE") = 0 Then
            Call AppendText(SourcePaths, SourceCount, SourceCapacity, InputPath)
            ResolveSourceInput = 1
            Exit Function
        End If
    Else
        Call AppendText(SourcePaths, SourceCount, SourceCapacity, InputPath)
        ResolveSourceInput = 1
        Exit Function
    End If
    Dim ManifestText As String = ReadAllText(InputPath)
    Dim InvalidManifestByte As Long = -1
    If ValidateUtf8(ManifestText, InvalidManifestByte) = 0 Then
        ErrorMessage = "error UBE5001: project manifest is not valid UTF-8"
        ResolveSourceInput = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim ManifestLength As Long = StringLength(ManifestText)
    Dim LineNumber As Long = 0
    Dim SawHeader As Long = 0
    Dim SawName As Long = 0
    Dim SawKind As Long = 0
    Dim SourceRelatives() As String
    Dim SourceRelativeCount As Long = 0
    Dim SourceRelativeCapacity As Long = 0
    While Cursor <= ManifestLength
        Dim LineEnd As Long = StringIndexOf(ManifestText, StringFromByte(10), Cursor)
        If LineEnd < 0 Then
            LineEnd = ManifestLength
        End If
        Dim RawLine As String = StringSlice(ManifestText, Cursor, LineEnd - Cursor)
        Dim ManifestLine As String = ""
        Call TrimManifestText(RawLine, ManifestLine)
        LineNumber = LineNumber + 1
        If StringLength(ManifestLine) > 0 Then
            If StringByteAt(ManifestLine, 0) <> 39 Then
                If SawHeader = 0 Then
                    If ManifestLine <> "UBE-Project 1" Then
                        ErrorMessage = "error UBE5002: project manifest must begin with UBE-Project 1"
                        ResolveSourceInput = 0
                        Exit Function
                    End If
                    SawHeader = 1
                Else
                    Dim EqualsIndex As Long = StringIndexOf(ManifestLine, "=", 0)
                    If EqualsIndex < 1 Then
                        ErrorMessage = "error UBE5003: malformed project manifest entry on line " & LongToString(LineNumber)
                        ResolveSourceInput = 0
                        Exit Function
                    End If
                    Dim Key As String = ""
                    Dim RawValue As String = ""
                    Call TrimManifestText(StringSlice(ManifestLine, 0, EqualsIndex), Key)
                    Call TrimManifestText(StringSlice(ManifestLine, EqualsIndex + 1, StringLength(ManifestLine) - EqualsIndex - 1), RawValue)
                    Dim ValueLength As Long = StringLength(RawValue)
                    Dim QuotedValue As Long = 0
                    If ValueLength >= 2 Then
                        If StringByteAt(RawValue, 0) = 34 Then
                            If StringByteAt(RawValue, ValueLength - 1) = 34 Then
                                QuotedValue = 1
                            End If
                        End If
                    End If
                    If QuotedValue = 0 Then
                        ErrorMessage = "error UBE5004: project values must be quoted on line " & LongToString(LineNumber)
                        ResolveSourceInput = 0
                        Exit Function
                    End If
                    Dim EntryValue As String = StringSlice(RawValue, 1, ValueLength - 2)
                    If EqualsIdentifier(Key, "Name") <> 0 Then
                        If SawName <> 0 Then
                            ErrorMessage = "error UBE5005: duplicate project Name"
                            ResolveSourceInput = 0
                            Exit Function
                        End If
                        SawName = 1
                    Else
                        If EqualsIdentifier(Key, "Kind") <> 0 Then
                            If SawKind <> 0 Or EqualsIdentifier(EntryValue, "Exe") = 0 Then
                                ErrorMessage = "error UBE5006: project Kind must be one Exe entry"
                                ResolveSourceInput = 0
                                Exit Function
                            End If
                            SawKind = 1
                        Else
                            If EqualsIdentifier(Key, "Source") <> 0 Then
                                Dim NormalizedSource As String = ""
                                If NormalizeProjectSourcePath(EntryValue, NormalizedSource) = 0 Then
                                    ErrorMessage = "error UBE5009: project Source path is empty, absolute, or escapes the project directory"
                                    ResolveSourceInput = 0
                                    Exit Function
                                End If
                                Dim ExistingSource As Long = 0
                                While ExistingSource < SourceRelativeCount
                                    If EqualsIdentifier(SourceRelatives(ExistingSource), NormalizedSource) <> 0 Then
                                        ErrorMessage = "error UBE5010: duplicate project Source after path normalization: " & EntryValue
                                        ResolveSourceInput = 0
                                        Exit Function
                                    End If
                                    ExistingSource = ExistingSource + 1
                                Wend
                                Call AppendText(SourceRelatives, SourceRelativeCount, SourceRelativeCapacity, NormalizedSource)
                            Else
                                If EqualsIdentifier(Key, "Startup") = 0 Then
                                    ErrorMessage = "error UBE5007: unsupported project key: " & Key
                                    ResolveSourceInput = 0
                                    Exit Function
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
        If LineEnd = ManifestLength Then
            Exit While
        End If
        Cursor = LineEnd + 1
    Wend
    If SawHeader = 0 Or SawName = 0 Or SawKind = 0 Or SourceRelativeCount = 0 Then
        ErrorMessage = "error UBE5008: project requires Name, Kind, and at least one Source"
        ResolveSourceInput = 0
        Exit Function
    End If
    Dim Separator As Long = InputLength - 1
    While Separator >= 0
        Dim PathByte As Long = StringByteAt(InputPath, Separator)
        If PathByte = 47 Or PathByte = 92 Then
            Exit While
        End If
        Separator = Separator - 1
    Wend
    Dim ProjectDirectory As String = ""
    If Separator >= 0 Then
        ProjectDirectory = StringSlice(InputPath, 0, Separator + 1)
    End If
    Dim SourceIndex As Long = 0
    While SourceIndex < SourceRelativeCount
        Call AppendText(SourcePaths, SourceCount, SourceCapacity, ProjectDirectory & SourceRelatives(SourceIndex))
        SourceIndex = SourceIndex + 1
    Wend
    ResolveSourceInput = 1
End Function

Function Main() As Long
    If CommandArgumentCount() <> 2 Then
        Print "usage: ube-stage1-v2 <source.bas> <output.ll>"
        Main = 2
        Exit Function
    End If

    Dim InputPath As String = CommandArgument(0)
    Dim SourcePaths() As String
    Dim SourcePathCount As Long = 0
    Dim SourcePathCapacity As Long = 0
    Dim InputError As String = ""
    If ResolveSourceInput(InputPath, SourcePaths, SourcePathCount, SourcePathCapacity, InputError) = 0 Then
        Print InputPath & "(1,1): " & InputError
        Main = 1
        Exit Function
    End If
    Dim ResultPath As String = CommandArgument(1)
    Dim Sources() As SourceFile
    ReDim Sources(SourcePathCount - 1)
    Dim SourceChunks() As String
    Dim SourceChunkCount As Long = 0
    Dim SourceChunkCapacity As Long = 0
    Dim CombinedLength As Long = 0
    Dim LoadIndex As Long = 0
    While LoadIndex < SourcePathCount
        Sources(LoadIndex).SourceId = LoadIndex + 1
        Sources(LoadIndex).FilePath = SourcePaths(LoadIndex)
        Sources(LoadIndex).Contents = ReadAllText(SourcePaths(LoadIndex))
        Sources(LoadIndex).CombinedStart = CombinedLength
        Sources(LoadIndex).ByteLength = StringLength(Sources(LoadIndex).Contents)
        If Sources(LoadIndex).ByteLength > 16777216 Then
            Print Sources(LoadIndex).FilePath & "(1,1): error UBE1000: source exceeds the 16777216-byte limit"
            Main = 1
            Exit Function
        End If
        Dim ModuleInvalidUtf8Byte As Long = -1
        If ValidateUtf8(Sources(LoadIndex).Contents, ModuleInvalidUtf8Byte) = 0 Then
            Dim InvalidLine As Long = 1
            Dim InvalidColumn As Long = 1
            Call FindLineAndColumn(Sources(LoadIndex).Contents, ModuleInvalidUtf8Byte, InvalidLine, InvalidColumn)
            Print Sources(LoadIndex).FilePath & "(" & LongToString(InvalidLine) & "," & LongToString(InvalidColumn) & "): error UBE1005: source is not valid UTF-8"
            Main = 1
            Exit Function
        End If
        Call AppendText(SourceChunks, SourceChunkCount, SourceChunkCapacity, Sources(LoadIndex).Contents)
        Call AppendText(SourceChunks, SourceChunkCount, SourceChunkCapacity, StringFromByte(10))
        CombinedLength = CombinedLength + Sources(LoadIndex).ByteLength + 1
        LoadIndex = LoadIndex + 1
    Wend
    Dim SourceText As String = StringArrayJoin(SourceChunks, SourceChunkCount)
    Dim SourceLength As Long = StringLength(SourceText)
    If SourceLength > 67108864 Then
        Print InputPath & "(1,1): error UBE1000: combined project source exceeds the 67108864-byte limit"
        Main = 1
        Exit Function
    End If
    Dim NewLine As String = StringFromByte(10)
    Dim Tokens() As Token
    Dim TokenCount As Long = 0
    Dim TokenCapacity As Long = 0
    Dim Diagnostics() As Diagnostic
    Dim DiagnosticCount As Long = 0
    Dim LexResult As Long = LexSource(SourceText, Tokens, TokenCount, TokenCapacity, Diagnostics, DiagnosticCount)
    If LexResult <> 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    Dim SyntaxNodes() As SyntaxNode
    Dim SyntaxNodeCount As Long = 0
    Dim SyntaxNodeCapacity As Long = 0
    Dim Procedures() As ProcedureDeclarationSyntax
    Dim ProcedureCount As Long = 0
    Dim ProcedureCapacity As Long = 0
    Dim Parameters() As ParameterSyntax
    Dim ParameterCount As Long = 0
    Dim ParameterCapacity As Long = 0
    Dim TypeDeclarations() As TypeDeclarationSyntax
    Dim TypeDeclarationCount As Long = 0
    Dim TypeDeclarationCapacity As Long = 0
    Dim FieldDeclarations() As FieldDeclarationSyntax
    Dim FieldDeclarationCount As Long = 0
    Dim FieldDeclarationCapacity As Long = 0
    If ParseTypeDeclarations(Tokens, TokenCount, TypeDeclarations, TypeDeclarationCount, TypeDeclarationCapacity, FieldDeclarations, FieldDeclarationCount, FieldDeclarationCapacity, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If ParseProcedureDeclarations(Tokens, TokenCount, Procedures, ProcedureCount, ProcedureCapacity, Parameters, ParameterCount, ParameterCapacity, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    Dim EntryProcedureIndex As Long = -1
    If ResolveEntryProcedure(Tokens, Procedures, ProcedureCount, EntryProcedureIndex, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    Dim LocalDeclarations() As LocalDeclarationSyntax
    Dim LocalDeclarationCount As Long = 0
    Dim LocalDeclarationCapacity As Long = 0
    If ParseLocalDeclarations(Tokens, Procedures, ProcedureCount, Parameters, LocalDeclarations, LocalDeclarationCount, LocalDeclarationCapacity, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If ValidateDeclaredTypes(Tokens, Procedures, ProcedureCount, Parameters, ParameterCount, LocalDeclarations, LocalDeclarationCount, TypeDeclarations, TypeDeclarationCount, FieldDeclarations, FieldDeclarationCount, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    Dim Statements() As StatementSyntax
    Dim StatementCount As Long = 0
    Dim StatementCapacity As Long = 0
    If ParseBasicStatements(Tokens, Procedures, ProcedureCount, Statements, StatementCount, StatementCapacity, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If AnalyzeBasicStatements(Tokens, Procedures, ProcedureCount, Parameters, LocalDeclarations, LocalDeclarationCount, Statements, StatementCount, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If ParseStoredExpressions(Tokens, LocalDeclarations, LocalDeclarationCount, Statements, StatementCount, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If AnalyzeStoredExpressions(Tokens, SyntaxNodes, Procedures, ProcedureCount, Parameters, LocalDeclarations, LocalDeclarationCount, Statements, StatementCount, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If AnalyzeExpressionTypes(Tokens, SyntaxNodes, Procedures, ProcedureCount, Parameters, LocalDeclarations, LocalDeclarationCount, TypeDeclarations, TypeDeclarationCount, FieldDeclarations, FieldDeclarationCount, Statements, StatementCount, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If ValidateProcedureResults(Tokens, SyntaxNodes, Procedures, ProcedureCount, Statements, StatementCount, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    Dim IrProcedures() As IrProcedure
    Dim IrInstructions() As IrInstruction
    Dim IrInstructionCount As Long = 0
    Dim IrInstructionCapacity As Long = 0
    If LowerProgramToIr(Tokens, SyntaxNodes, SyntaxNodeCount, Procedures, ProcedureCount, LocalDeclarations, LocalDeclarationCount, TypeDeclarations, TypeDeclarationCount, Statements, StatementCount, IrProcedures, IrInstructions, IrInstructionCount, IrInstructionCapacity, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If VerifyProgramIr(Tokens, Procedures, ProcedureCount, IrProcedures, IrInstructions, IrInstructionCount, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    Dim ResultChunks() As String
    Dim ResultChunkCount As Long = 0
    Dim ResultChunkCapacity As Long = 0
    Call EmitProgramPreamble(Tokens, TypeDeclarations, TypeDeclarationCount, FieldDeclarations, ResultChunks, ResultChunkCount, ResultChunkCapacity, NewLine)
    Dim GlobalChunks() As String
    Dim GlobalChunkCount As Long = 0
    Dim GlobalChunkCapacity As Long = 0
    Dim BodyChunks() As String
    Dim BodyChunkCount As Long = 0
    Dim BodyChunkCapacity As Long = 0
    Dim EmitterState As LlvmEmitterState
    EmitterState.NextRegister = 0
    EmitterState.NextLabel = 0
    EmitterState.NextString = 0
    EmitterState.Failed = 0
    Dim EmittedProcedureIndex As Long = 0
    While EmittedProcedureIndex < ProcedureCount
        If Procedures(EmittedProcedureIndex).IsIntrinsic = 0 Then
            EmitterState.NextRegister = 0
            EmitterState.NextLabel = 0
            EmitterState.CurrentTerminated = 0
            Call EmitStructuredProcedureBody(Tokens, SyntaxNodes, Procedures, ProcedureCount, Parameters, LocalDeclarations, LocalDeclarationCount, TypeDeclarations, TypeDeclarationCount, FieldDeclarations, FieldDeclarationCount, Statements, StatementCount, EmittedProcedureIndex, GlobalChunks, GlobalChunkCount, GlobalChunkCapacity, BodyChunks, BodyChunkCount, BodyChunkCapacity, EmitterState, NewLine)
            If EmitterState.Failed <> 0 Then
                Exit While
            End If
        End If
        EmittedProcedureIndex = EmittedProcedureIndex + 1
    Wend
    If EmitterState.Failed <> 0 Then
        Print InputPath & "(1,1): error UBE4001: LLVM emission encountered an unsupported verified IR instruction"
        Main = 1
        Exit Function
    End If
    If GlobalChunkCount > 0 Then
        Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, StringArrayJoin(GlobalChunks, GlobalChunkCount) & NewLine)
    End If
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, StringArrayJoin(BodyChunks, BodyChunkCount))
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "define i32 @main(i32 %argc, ptr %argv) {" & NewLine & "entry:" & NewLine)
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  call void @ube_runtime_set_args(i32 %argc, ptr %argv)" & NewLine)
    Dim EntrySymbol As String = ""
    Call ProcedureLlvmSymbol(EntryProcedureIndex, EntrySymbol)
    If Procedures(EntryProcedureIndex).ProcedureKind = 2 Then
        Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  %exit.code = call i32 " & EntrySymbol & "()" & NewLine)
        Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  ret i32 %exit.code" & NewLine & "}" & NewLine)
    Else
        Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  call void " & EntrySymbol & "()" & NewLine)
        Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  ret i32 0" & NewLine & "}" & NewLine)
    End If
    Dim ResultText As String = StringArrayJoin(ResultChunks, ResultChunkCount)
    If StringLength(ResultText) > 67108864 Then
        Print ResultPath & "(1,1): error UBE4000: generated LLVM output exceeds the 67108864-byte limit"
        Main = 1
        Exit Function
    End If

    Main = WriteAllText(ResultPath, ResultText)
End Function
