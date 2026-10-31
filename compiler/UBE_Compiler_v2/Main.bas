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
    PackageId As Long
    ModuleName As String
    IsReference As Long
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
    NextProcedureNode As Long
End Type

Type ProcedureDeclarationSyntax
    ProcedureKind As Long
    NameToken As Long
    HeaderToken As Long
    EndToken As Long
    IsIntrinsic As Long
    IsThreadTarget As Long
    FirstParameter As Long
    ParameterCount As Long
    ReturnTypeToken As Long
    ResultIsDynamicArray As Long
    PrimitiveRole As Long
    PrimitiveNativeType As Long
    FirstNode As Long
    LastNode As Long
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

Sub EmitIntegerConversion(ByVal FromType As Long, ByVal ToType As Long, ByRef Operand As String, ByRef Chunks() As String, ByRef Count As Long, ByRef Capacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String)
    If FromType = ToType Then
        Exit Sub
    End If
    If IsIntegralOrBooleanType(FromType) = 0 Or IsIntegralOrBooleanType(ToType) = 0 Or ToType = 1 Then
        State.Failed = 1
        Exit Sub
    End If
    Dim FromLlvm As String = ""
    Dim ToLlvm As String = ""
    Call LlvmTypeName(FromType, FromLlvm)
    Call LlvmTypeName(ToType, ToLlvm)
    Dim WideOperand As String = Operand
    If FromType <> 5 Then
        Call NextLlvmRegister(State, WideOperand)
        Dim ExtendOpcode As String = "sext"
        If FromType = 7 Then
            ExtendOpcode = "zext"
        End If
        Call AppendText(Chunks, Count, Capacity, "  " & WideOperand & " = " & ExtendOpcode & " " & FromLlvm & " " & Operand & " to i64" & NewLine)
    End If
    If ToType = 5 Then
        Operand = WideOperand
        Exit Sub
    End If
    Dim NeedsCheck As Long = 0
    Dim Bits As String = "32"
    Dim UnsignedFlag As String = "0"
    If ToType = 7 Then
        NeedsCheck = 1
        Bits = "8"
        UnsignedFlag = "1"
    End If
    If ToType = 4 Then
        Bits = "16"
        If FromType <> 7 Then
            NeedsCheck = 1
        End If
    End If
    If ToType = 2 And FromType = 5 Then
        NeedsCheck = 1
    End If
    If NeedsCheck <> 0 Then
        Dim CheckedOperand As String = ""
        Call NextLlvmRegister(State, CheckedOperand)
        Call AppendText(Chunks, Count, Capacity, "  " & CheckedOperand & " = call i64 @ube_checked_narrow_i64(i64 " & WideOperand & ", i32 " & Bits & ", i32 " & UnsignedFlag & ")" & NewLine)
        WideOperand = CheckedOperand
    End If
    Call NextLlvmRegister(State, Operand)
    Call AppendText(Chunks, Count, Capacity, "  " & Operand & " = trunc i64 " & WideOperand & " to " & ToLlvm & NewLine)
End Sub

Function EvaluateIntegerConstant(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Value As Long) As Long
    ' 0 = runtime-dependent, 1 = exact Long constant, 2 = invalid constant.
    Dim Kind As Long = Nodes(NodeIndex).NodeKind
    If Kind = 10 Then
        Dim LiteralText As String = Tokens(Nodes(NodeIndex).SourceToken).Spelling
        Dim Index As Long = 0
        Value = 0
        While Index < StringLength(LiteralText)
            Dim Digit As Long = StringByteAt(LiteralText, Index) - 48
            If Digit < 0 Or Digit > 9 Then
                EvaluateIntegerConstant = 2
                Exit Function
            End If
            If Value > (2147483647 - Digit) \ 10 Then
                EvaluateIntegerConstant = 2
                Exit Function
            End If
            Value = Value * 10 + Digit
            Index = Index + 1
        Wend
        EvaluateIntegerConstant = 1
        Exit Function
    End If
    If Kind <> 15 And Kind <> 16 Then
        EvaluateIntegerConstant = 0
        Exit Function
    End If
    Dim Left As Long = 0
    Dim LeftStatus As Long = EvaluateIntegerConstant(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Left)
    Dim OperatorText As String = Tokens(Nodes(NodeIndex).OperatorToken).Spelling
    If Kind = 16 Then
        If OperatorText = "-" And Nodes(Nodes(NodeIndex).LeftNode).NodeKind = 10 Then
            If Tokens(Nodes(Nodes(NodeIndex).LeftNode).SourceToken).Spelling = "2147483648" Then
                Value = -2147483647 - 1
                EvaluateIntegerConstant = 1
                Exit Function
            End If
        End If
        If LeftStatus <> 1 Then
            EvaluateIntegerConstant = LeftStatus
            Exit Function
        End If
        Value = Left
        If OperatorText = "-" Then
            If Left = -2147483647 - 1 Then
                EvaluateIntegerConstant = 2
                Exit Function
            End If
            Value = -Left
        End If
        If EqualsKeyword(OperatorText, "Not") <> 0 Then
            Value = Not Left
        End If
        EvaluateIntegerConstant = 1
        Exit Function
    End If
    Dim Right As Long = 0
    Dim RightStatus As Long = EvaluateIntegerConstant(Tokens, Nodes, Nodes(NodeIndex).RightNode, Right)
    If LeftStatus = 0 Or RightStatus = 0 Then
        EvaluateIntegerConstant = 0
        Exit Function
    End If
    If LeftStatus = 2 Or RightStatus = 2 Then
        EvaluateIntegerConstant = 2
        Exit Function
    End If
    Dim Maximum As Long = 2147483647
    Dim Minimum As Long = -2147483647 - 1
    Dim Invalid As Long = 0
    If OperatorText = "+" Then
        If Right > 0 Then
            If Left > Maximum - Right Then
                Invalid = 1
            End If
        Else
            If Left < Minimum - Right Then
                Invalid = 1
            End If
        End If
        If Invalid = 0 Then
            Value = Left + Right
        End If
    Else
        If OperatorText = "-" Then
            If Right < 0 Then
                If Left > Maximum + Right Then
                    Invalid = 1
                End If
            Else
                If Left < Minimum + Right Then
                    Invalid = 1
                End If
            End If
            If Invalid = 0 Then
                Value = Left - Right
            End If
        Else
            If OperatorText = "*" Then
                If Left > 0 And Right > 0 Then
                    If Left > Maximum \ Right Then
                        Invalid = 1
                    End If
                End If
                If Left > 0 And Right < 0 Then
                    If Right < Minimum \ Left Then
                        Invalid = 1
                    End If
                End If
                If Left < 0 And Right > 0 Then
                    If Left < Minimum \ Right Then
                        Invalid = 1
                    End If
                End If
                If Left < 0 And Right < 0 Then
                    If Left < Maximum \ Right Then
                        Invalid = 1
                    End If
                End If
                If Invalid = 0 Then
                    Value = Left * Right
                End If
            Else
                If OperatorText = "\" Or EqualsKeyword(OperatorText, "Mod") <> 0 Then
                    If Right = 0 Then
                        Invalid = 1
                    Else
                        If Left = Minimum And Right = -1 Then
                            If OperatorText = "\" Then
                                Invalid = 1
                            End If
                            Value = 0
                        Else
                            If OperatorText = "\" Then
                                Value = Left \ Right
                            End If
                            If EqualsKeyword(OperatorText, "Mod") <> 0 Then
                                Value = Left Mod Right
                            End If
                        End If
                    End If
                Else
                    EvaluateIntegerConstant = 0
                    Exit Function
                End If
            End If
        End If
    End If
    EvaluateIntegerConstant = 1
    If Invalid <> 0 Then
        EvaluateIntegerConstant = 2
    End If
End Function

Function ValidateIntegerConstant(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByVal DestinationType As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    ValidateIntegerConstant = 1
    If DestinationType <> 2 And DestinationType <> 4 And DestinationType <> 7 Then
        Exit Function
    End If
    Dim Value As Long = 0
    Dim Status As Long = EvaluateIntegerConstant(Tokens, Nodes, NodeIndex, Value)
    Dim Invalid As Long = 0
    If Status = 2 Then
        Invalid = 1
    End If
    If Status = 1 Then
        If DestinationType = 7 Then
            If Value < 0 Or Value > 255 Then
                Invalid = 1
            End If
        End If
        If DestinationType = 4 Then
            If Value < -32768 Or Value > 32767 Then
                Invalid = 1
            End If
        End If
    End If
    If Invalid <> 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3220", Tokens(Nodes(NodeIndex).SourceToken).StartByte, Tokens(Nodes(NodeIndex).SourceToken).ByteLength, "constant is outside the destination integer range or has invalid arithmetic")
        ValidateIntegerConstant = 0
    End If
End Function

Sub LlvmTypeName(ByVal TypeId As Long, ByRef Result As String)
    If TypeId = 7 Then
        Result = "i8"
        Exit Sub
    End If
    If TypeId = 4 Then
        Result = "i16"
        Exit Sub
    End If
    If TypeId >= 100000 Or IsReferenceType(TypeId) <> 0 Or TypeId = 8 Then
        Result = "ptr"
        Exit Sub
    End If
    If TypeId = 1 Then
        Result = "i1"
    Else
        If TypeId = 2 Then
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
            Call EmitIntegerConversion(InitializerTypeId, DeclaredTypeId(Tokens, Locals(DeclarationLocal).TypeToken, Locals(DeclarationLocal).IsDynamicArray, Types, TypeCount), InitializerOperand, Body, BodyCount, BodyCapacity, State, NewLine)
            InitializerTypeId = DeclaredTypeId(Tokens, Locals(DeclarationLocal).TypeToken, Locals(DeclarationLocal).IsDynamicArray, Types, TypeCount)
            Call EmitValueStore(InitializerTypeId, "%local." & LongToString(DeclarationLocal), InitializerOperand, Locals(DeclarationLocal).InitializerNode, Body, BodyCount, BodyCapacity, State, NewLine)
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
        Call EmitIntegerConversion(AssignmentValueType, AssignmentTypeId, AssignmentOperand, Body, BodyCount, BodyCapacity, State, NewLine)
        Call EmitValueStore(AssignmentTypeId, AssignmentAddress, AssignmentOperand, Statements(StatementIndex).ValueNode, Body, BodyCount, BodyCapacity, State, NewLine)
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
        If PrintTypeId = 1 Or PrintTypeId = 4 Or PrintTypeId = 7 Then
            Call EmitIntegerConversion(PrintTypeId, 2, PrintOperand, Body, BodyCount, BodyCapacity, State, NewLine)
            PrintTypeId = 2
        End If
        If PrintTypeId = 3 Then
            Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_string(ptr " & PrintOperand & ")" & NewLine)
        Else
            If PrintTypeId = 5 Then
                Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_i64(i64 " & PrintOperand & ")" & NewLine)
            Else
                If PrintTypeId = 6 Then
                    Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_f64(double " & PrintOperand & ")" & NewLine)
                Else
                    Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_print_i32(i32 " & PrintOperand & ")" & NewLine)
                End If
            End If
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
        Dim ElementTypeId As Long = ArrayTypeId - 100000
        Dim ElementLayout As String = ""
        Call ValueLayoutSymbol(ElementTypeId, ElementLayout)
        Dim PreserveFlag As String = "0"
        If Statements(StatementIndex).Flags <> 0 Then
            PreserveFlag = "1"
        End If
        Dim NewHandle As String = ""
        Call NextLlvmRegister(State, NewHandle)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & NewHandle & " = call i32 @ube_value_try_redim(ptr " & ArrayAddress & ", i32 0, i32 " & UpperOperand & ", ptr " & ElementLayout & ", i32 " & PreserveFlag & ")" & NewLine)
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

Sub IntrinsicLlvmSymbol(ByVal IntrinsicName As String, ByRef Result As String, ByRef Signature As String)
    ' Private ABI shape: result type ID, colon, then v/r + exact parameter IDs.
    Signature = ""
    If EqualsIdentifier(IntrinsicName, "StringLength") <> 0 Then
        Signature = "2:v3"
        Result = "@ube_string_length"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringByteAt") <> 0 Then
        Signature = "2:v3,v2"
        Result = "@ube_string_byte_at"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringSlice") <> 0 Then
        Signature = "3:v3,v2,v2"
        Result = "@ube_string_slice"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringIndexOf") <> 0 Then
        Signature = "2:v3,v3,v2"
        Result = "@ube_string_index_of"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringFromByte") <> 0 Then
        Signature = "3:v2"
        Result = "@ube_string_from_byte"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "LongToString") <> 0 Then
        Signature = "3:v2"
        Result = "@ube_long_to_string"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CommandArgumentCount") <> 0 Then
        Signature = "2:"
        Result = "@ube_command_argument_count"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CommandArgument") <> 0 Then
        Signature = "3:v2"
        Result = "@ube_command_argument"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "ReadAllText") <> 0 Then
        Signature = "3:v3"
        Result = "@ube_read_all_text"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "WriteAllText") <> 0 Then
        Signature = "2:v3,v3"
        Result = "@ube_write_all_text"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "StringArrayJoin") <> 0 Then
        Signature = "3:r100003,v2"
        Result = "@ube_string_array_join"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerRunTool") <> 0 Then
        Signature = "2:v3,r100003,v2"
        Result = "@ube_compiler_run_tool"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerDeleteFile") <> 0 Then
        Signature = "2:v3"
        Result = "@ube_compiler_delete_file"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerMonotonicMilliseconds") <> 0 Then
        Signature = "2:"
        Result = "@ube_compiler_monotonic_milliseconds"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerProcessCpuMilliseconds") <> 0 Then
        Signature = "2:"
        Result = "@ube_compiler_process_cpu_milliseconds"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerPeakWorkingSetKilobytes") <> 0 Then
        Signature = "2:"
        Result = "@ube_compiler_peak_working_set_kilobytes"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerValidateResource") <> 0 Then
        Signature = "2:v3"
        Result = "@ube_compiler_validate_resource"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerResourceLlvmEscape") <> 0 Then
        Signature = "3:v3"
        Result = "@ube_compiler_resource_llvm_escape"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "CompilerValidateLibraryBundle") <> 0 Then
        Signature = "2:v3,v3,v3,v3"
        Result = "@ube_compiler_validate_library_bundle"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "UnicodeIsLetter") <> 0 Then
        Signature = "2:v2"
        Result = "@ube_unicode_is_letter"
        Exit Sub
    End If
    If EqualsIdentifier(IntrinsicName, "UnicodeSimpleFoldCodePoint") <> 0 Then
        Signature = "2:v2"
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
    DeclaredName As String
    IsReference As Long
    NameToken As Long
    HeaderToken As Long
    EndToken As Long
    FirstField As Long
    FieldCount As Long
    RepresentationToken As Long
    RepresentationType As Long
    RootCount As Long
End Type

Type FieldDeclarationSyntax
    OwnerType As Long
    NameToken As Long
    TypeToken As Long
    IsDynamicArray As Long
    ResolvedType As Long
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
    Declarations(Count).DeclaredName = ""
    Declarations(Count).IsReference = 0
    Declarations(Count).NameToken = NameToken
    Declarations(Count).HeaderToken = HeaderToken
    Declarations(Count).EndToken = EndToken
    Declarations(Count).FirstField = -1
    Declarations(Count).FieldCount = 0
    Declarations(Count).RepresentationToken = -1
    Declarations(Count).RepresentationType = 0
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
    Procedures(Count).IsThreadTarget = 0
    Procedures(Count).IsIntrinsic = IsIntrinsic
    Procedures(Count).FirstParameter = -1
    Procedures(Count).ParameterCount = 0
    Procedures(Count).ReturnTypeToken = -1
    Procedures(Count).ResultIsDynamicArray = 0
    Procedures(Count).PrimitiveRole = 0
    Procedures(Count).PrimitiveNativeType = -1
    Procedures(Count).FirstNode = -1
    Procedures(Count).LastNode = -1
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
    Nodes(Count).NextProcedureNode = -1
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

Function FindSourceIndex(ByRef Sources() As SourceFile, ByVal SourceCount As Long, ByVal StartByte As Long) As Long
    Dim Index As Long = 0
    While Index < SourceCount
        If StartByte >= Sources(Index).CombinedStart And StartByte <= Sources(Index).CombinedStart + Sources(Index).ByteLength Then
            FindSourceIndex = Index
            Exit Function
        End If
        Index = Index + 1
    Wend
    FindSourceIndex = -1
End Function

Sub ReportProjectDiagnostics(ByRef Sources() As SourceFile, ByVal SourceCount As Long, ByRef Diagnostics() As Diagnostic, ByVal Count As Long)
    Dim Index As Long = 0
    While Index < Count
        Dim MatchIndex As Long = FindSourceIndex(Sources, SourceCount, Diagnostics(Index).StartByte)
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
    If OperatorText = "=" Or OperatorText = "<" Or OperatorText = ">" Or OperatorText = "<>" Or OperatorText = "<=" Or OperatorText = ">=" Or EqualsKeyword(OperatorText, "Is") <> 0 Then
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

' Parses postfix call/index arguments outside the parenthesized-primary frame.
Function ParseGeneralArguments(ByRef Tokens() As Token, ByVal EndExclusive As Long, ByRef Cursor As Long, ByVal CalleeNode As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
                Dim CallOpenToken As Long = Cursor
                Cursor = Cursor + 1
                Dim FirstArgumentLink As Long = -1
                Dim LastArgumentLink As Long = -1
                While Cursor < EndExclusive And Tokens(Cursor).TokenKind <> 6
                    Dim ArgumentNode As Long = ParseGeneralExpression(Tokens, EndExclusive, Cursor, 1, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
                    If ArgumentNode < 0 Then
                        ParseGeneralArguments = -1
                        Exit Function
                    End If
                    Dim ArgumentLink As Long = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 17, Tokens(Cursor - 1).StartByte, ArgumentNode, -1, -1)
                    If ArgumentLink < 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2005", Tokens(CallOpenToken).StartByte, Tokens(CallOpenToken).ByteLength, "syntax node limit exceeded")
                        ParseGeneralArguments = -1
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
                            ParseGeneralArguments = -1
                            Exit Function
                        End If
                    Else
                        Exit While
                    End If
                Wend
                If Cursor >= EndExclusive Or Tokens(Cursor).TokenKind <> 6 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2223", Tokens(CallOpenToken).StartByte, Tokens(CallOpenToken).ByteLength, "expected ')' after arguments")
                    ParseGeneralArguments = -1
                    Exit Function
                End If
                Cursor = Cursor + 1
                ParseGeneralArguments = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 13, CallOpenToken, CalleeNode, FirstArgumentLink, -1)
End Function

Function ParseGeneralPrimary(ByRef Tokens() As Token, ByVal EndExclusive As Long, ByRef Cursor As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    If Cursor >= EndExclusive Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2220", 0, 0, "expected expression")
        ParseGeneralPrimary = -1
        Exit Function
    End If
    Dim ThreadToken As Long = -1
    If Tokens(Cursor).TokenKind = 1 And EqualsKeyword(Tokens(Cursor).Spelling, "CallNew") <> 0 Then
        ThreadToken = Cursor
        Cursor = Cursor + 1
        If Cursor >= EndExclusive Or EqualsKeyword(Tokens(Cursor).Spelling, "CallNew") <> 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2240", Tokens(ThreadToken).StartByte, Tokens(ThreadToken).ByteLength, "CallNew requires a statically resolved Sub call")
            ParseGeneralPrimary = -1
            Exit Function
        End If
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
                Dim PrimaryKind As Long = 12
                If EqualsKeyword(Tokens(Cursor).Spelling, "New") <> 0 Then
                    Cursor = Cursor + 1
                    If Cursor >= EndExclusive Or Tokens(Cursor).TokenKind <> 1 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3241", Tokens(Cursor - 1).StartByte, Tokens(Cursor - 1).ByteLength, "New requires a native CLASS name")
                        ParseGeneralPrimary = -1
                        Exit Function
                    End If
                    PrimaryKind = 18
                Else
                    If EqualsKeyword(Tokens(Cursor).Spelling, "Nothing") <> 0 Then
                        PrimaryKind = 19
                    End If
                End If
                ResultNode = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, PrimaryKind, Cursor, -1, -1, -1)
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
                ResultNode = ParseGeneralArguments(Tokens, EndExclusive, Cursor, ResultNode, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
                If ResultNode < 0 Then
                    ParseGeneralPrimary = -1
                    Exit Function
                End If
            Else
                Exit While
            End If
        End If
    Wend
    If ThreadToken >= 0 Then
        If Nodes(ResultNode).NodeKind <> 13 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2240", Tokens(ThreadToken).StartByte, Tokens(ThreadToken).ByteLength, "CallNew requires a statically resolved Sub call")
            ParseGeneralPrimary = -1
            Exit Function
        End If
        ResultNode = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 20, ThreadToken, ResultNode, -1, -1)
    End If
    ParseGeneralPrimary = ResultNode
End Function

' Consumes a unary prefix iteratively before constructing nodes inside out.
Function ParseGeneralUnary(ByRef Tokens() As Token, ByVal EndExclusive As Long, ByRef Cursor As Long, ByRef Nodes() As SyntaxNode, ByRef NodeCount As Long, ByRef NodeCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim FirstUnary As Long = Cursor
    While Cursor < EndExclusive
        If Tokens(Cursor).Spelling <> "+" And Tokens(Cursor).Spelling <> "-" And EqualsKeyword(Tokens(Cursor).Spelling, "Not") = 0 Then
            Exit While
        End If
        Cursor = Cursor + 1
    Wend
    Dim UnaryEnd As Long = Cursor
    Dim Operand As Long = ParseGeneralPrimary(Tokens, EndExclusive, Cursor, Nodes, NodeCount, NodeCapacity, Diagnostics, DiagnosticCount)
    If Operand < 0 Then
        ParseGeneralUnary = -1
        Exit Function
    End If
    While UnaryEnd > FirstUnary
        UnaryEnd = UnaryEnd - 1
        Operand = AppendSyntaxNode(Nodes, NodeCount, NodeCapacity, 16, UnaryEnd, Operand, -1, UnaryEnd)
        If Operand < 0 Then
            ParseGeneralUnary = -1
            Exit Function
        End If
    Wend
    ParseGeneralUnary = Operand
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

Function PrimitiveBindingRole(ByVal BindingName As String) As Long
    PrimitiveBindingRole = 0
    If EqualsIdentifier(BindingName, "Value.Pack") <> 0 Then
        PrimitiveBindingRole = 1
    End If
    If EqualsIdentifier(BindingName, "Value.Unpack") <> 0 Then
        PrimitiveBindingRole = 2
    End If
    If EqualsIdentifier(BindingName, "Array.Length") <> 0 Then
        PrimitiveBindingRole = 3
    End If
    If EqualsIdentifier(BindingName, "Array.TryResize") <> 0 Then
        PrimitiveBindingRole = 4
    End If
    If EqualsIdentifier(BindingName, "Memory.Collect") <> 0 Then
        PrimitiveBindingRole = 5
    End If
    If EqualsIdentifier(BindingName, "Array.TryCopy") <> 0 Then
        PrimitiveBindingRole = 6
    End If
    If EqualsIdentifier(BindingName, "Memory.CopyBytes") <> 0 Then
        PrimitiveBindingRole = 7
    End If
    If EqualsIdentifier(BindingName, "File.TryOpen") <> 0 Then
        PrimitiveBindingRole = 8
    End If
    If EqualsIdentifier(BindingName, "File.TryRead") <> 0 Then
        PrimitiveBindingRole = 9
    End If
    If EqualsIdentifier(BindingName, "File.TryClose") <> 0 Then
        PrimitiveBindingRole = 10
    End If
    If EqualsIdentifier(BindingName, "Process.TryArgument") <> 0 Then
        PrimitiveBindingRole = 11
    End If
    If EqualsIdentifier(BindingName, "Error.Set") <> 0 Then
        PrimitiveBindingRole = 12
    End If
    If EqualsIdentifier(BindingName, "Thread.TryCurrentId") <> 0 Then
        PrimitiveBindingRole = 13
    End If
    If EqualsIdentifier(BindingName, "Thread.TryIsAlive") <> 0 Then
        PrimitiveBindingRole = 14
    End If
    If EqualsIdentifier(BindingName, "Thread.TryRequestStop") <> 0 Then
        PrimitiveBindingRole = 15
    End If
    If EqualsIdentifier(BindingName, "Thread.TryStopRequested") <> 0 Then
        PrimitiveBindingRole = 16
    End If
    If EqualsIdentifier(BindingName, "Thread.TryWait") <> 0 Then
        PrimitiveBindingRole = 17
    End If
    If EqualsIdentifier(BindingName, "Thread.TryYield") <> 0 Then
        PrimitiveBindingRole = 18
    End If
End Function

Function ParsePrimitiveAttributes(ByRef Tokens() As Token, ByVal FirstToken As Long, ByVal EndToken As Long, ByVal NameToken As Long, ByRef Role As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Role = 0
    Dim Cursor As Long = FirstToken
    While Cursor < EndToken
        If Tokens(Cursor).TokenKind = 4 Or Tokens(Cursor).TokenKind = 9 Then
            Cursor = Cursor + 1
        Else
            If EqualsKeyword(Tokens(Cursor).Spelling, "Attribute") = 0 Or Cursor + 5 >= EndToken Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3230", Tokens(Cursor).StartByte, Tokens(Cursor).ByteLength, "intrinsic binding has no executable body; expected Attribute or End")
                ParsePrimitiveAttributes = 0
                Exit Function
            End If
            If Tokens(Cursor + 1).TokenKind <> 1 Or Tokens(Cursor + 2).Spelling <> "." Or Tokens(Cursor + 3).TokenKind <> 1 Or Tokens(Cursor + 4).Spelling <> "=" Or Tokens(Cursor + 5).TokenKind <> 3 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3230", Tokens(Cursor).StartByte, Tokens(Cursor).ByteLength, "invalid intrinsic attribute; expected a named string attribute")
                ParsePrimitiveAttributes = 0
                Exit Function
            End If
            If EqualsIdentifier(Tokens(Cursor + 3).Spelling, "UBE_Primitive") <> 0 Then
                If EqualsIdentifier(Tokens(Cursor + 1).Spelling, Tokens(NameToken).Spelling) = 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3230", Tokens(Cursor).StartByte, Tokens(Cursor).ByteLength, "primitive attribute target must name its intrinsic declaration")
                    ParsePrimitiveAttributes = 0
                    Exit Function
                End If
                If Role <> 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3230", Tokens(Cursor).StartByte, Tokens(Cursor).ByteLength, "intrinsic has duplicate or conflicting primitive bindings")
                    ParsePrimitiveAttributes = 0
                    Exit Function
                End If
                Role = PrimitiveBindingRole(Tokens(Cursor + 5).Decoded)
                If Role = 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3230", Tokens(Cursor + 5).StartByte, Tokens(Cursor + 5).ByteLength, "unknown primitive binding role")
                    ParsePrimitiveAttributes = 0
                    Exit Function
                End If
            End If
            Cursor = Cursor + 6
            If Cursor < EndToken And Tokens(Cursor).TokenKind = 9 Then
                Cursor = Cursor + 1
            End If
            If Cursor >= EndToken Or Tokens(Cursor).TokenKind <> 4 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3230", Tokens(NameToken).StartByte, Tokens(NameToken).ByteLength, "intrinsic attribute must occupy one complete line")
                ParsePrimitiveAttributes = 0
                Exit Function
            End If
        End If
    Wend
    ParsePrimitiveAttributes = 1
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
                If HeaderCursor + 1 < DeclarationEnd Then
                    If Tokens(HeaderCursor).TokenKind = 5 And Tokens(HeaderCursor + 1).TokenKind = 6 Then
                        Procedures(DeclarationIndex).ResultIsDynamicArray = 1
                        HeaderCursor = HeaderCursor + 2
                    End If
                End If
            End If
            If HeaderCursor < DeclarationEnd And Tokens(HeaderCursor).TokenKind = 9 Then
                HeaderCursor = HeaderCursor + 1
            End If
            If HeaderCursor >= DeclarationEnd Or Tokens(HeaderCursor).TokenKind <> 4 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2129", Tokens(Index).StartByte, Tokens(Index).ByteLength, "unexpected token in procedure header")
                ParseProcedureDeclarations = 0
                Exit Function
            End If
            If IntrinsicFlag <> 0 Then
                Dim ParsedRole As Long = 0
                If ParsePrimitiveAttributes(Tokens, HeaderCursor + 1, DeclarationEnd - 1, Index + 1, ParsedRole, Diagnostics, DiagnosticCount) = 0 Then
                    ParseProcedureDeclarations = 0
                    Exit Function
                End If
                Procedures(DeclarationIndex).PrimitiveRole = ParsedRole
            End If
            Index = DeclarationEnd
        End If
        Index = Index + 1
    Wend
    ParseProcedureDeclarations = 1
End Function

' Parses the shared typed-field grammar; classes additionally require Public.
Function ParseInstanceFields(ByRef Tokens() As Token, ByVal FieldCursor As Long, ByVal EndExclusive As Long, ByRef Declarations() As TypeDeclarationSyntax, ByVal DeclarationIndex As Long, ByRef Fields() As FieldDeclarationSyntax, ByRef FieldCount As Long, ByRef FieldCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
            While FieldCursor < EndExclusive
                If Tokens(FieldCursor).TokenKind = 4 Or Tokens(FieldCursor).TokenKind = 9 Then
                    FieldCursor = FieldCursor + 1
                Else
                    If Declarations(DeclarationIndex).IsReference <> 0 Then
                        If EqualsKeyword(Tokens(FieldCursor).Spelling, "Public") = 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3240", Tokens(FieldCursor).StartByte, Tokens(FieldCursor).ByteLength, "bootstrap CLASS supports only Public typed instance fields")
                            ParseInstanceFields = 0
                            Exit Function
                        End If
                        FieldCursor = FieldCursor + 1
                    End If
                    If FieldCursor >= EndExclusive Or Tokens(FieldCursor).TokenKind <> 1 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2113", Tokens(FieldCursor).StartByte, Tokens(FieldCursor).ByteLength, "expected Type field name")
                        ParseInstanceFields = 0
                        Exit Function
                    End If
                    Dim FieldNameToken As Long = FieldCursor
                    Dim ExistingField As Long = Declarations(DeclarationIndex).FirstField
                    While ExistingField < FieldCount
                        If EqualsIdentifier(Tokens(Fields(ExistingField).NameToken).Spelling, Tokens(FieldNameToken).Spelling) <> 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2114", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "duplicate field name: " & Tokens(FieldNameToken).Spelling)
                            ParseInstanceFields = 0
                            Exit Function
                        End If
                        ExistingField = ExistingField + 1
                    Wend
                    FieldCursor = FieldCursor + 1
                    Dim FieldIsArray As Long = 0
                    If FieldCursor < EndExclusive Then
                        If Tokens(FieldCursor).TokenKind = 5 Then
                            FieldIsArray = 1
                            FieldCursor = FieldCursor + 1
                            If FieldCursor >= EndExclusive Or Tokens(FieldCursor).TokenKind <> 6 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2115", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "dynamic Type field requires empty parentheses")
                                ParseInstanceFields = 0
                                Exit Function
                            End If
                            FieldCursor = FieldCursor + 1
                        End If
                    End If
                    If FieldCursor >= EndExclusive Or Tokens(FieldCursor).TokenKind <> 1 Or EqualsKeyword(Tokens(FieldCursor).Spelling, "As") = 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2116", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "Type field requires an explicit As type")
                        ParseInstanceFields = 0
                        Exit Function
                    End If
                    FieldCursor = FieldCursor + 1
                    If FieldCursor >= EndExclusive Or Tokens(FieldCursor).TokenKind <> 1 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2117", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "expected Type field type")
                        ParseInstanceFields = 0
                        Exit Function
                    End If
                    Dim NewField As Long = AppendFieldDeclaration(Fields, FieldCount, FieldCapacity, DeclarationIndex, FieldNameToken, FieldCursor, FieldIsArray)
                    If NewField < 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2118", Tokens(FieldNameToken).StartByte, Tokens(FieldNameToken).ByteLength, "Type field limit exceeded")
                        ParseInstanceFields = 0
                        Exit Function
                    End If
                    Declarations(DeclarationIndex).FieldCount = Declarations(DeclarationIndex).FieldCount + 1
                    FieldCursor = FieldCursor + 1
                    While FieldCursor < EndExclusive And Tokens(FieldCursor).TokenKind <> 4
                        If Tokens(FieldCursor).TokenKind <> 9 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2119", Tokens(FieldCursor).StartByte, Tokens(FieldCursor).ByteLength, "unexpected token after Type field")
                            ParseInstanceFields = 0
                            Exit Function
                        End If
                        FieldCursor = FieldCursor + 1
                    Wend
                End If
            Wend
    ParseInstanceFields = 1
End Function

' Admits field-only native reference declarations without changing original tokens.
Function ParseClassDeclarations(ByRef Tokens() As Token, ByVal TokenCount As Long, ByRef Sources() As SourceFile, ByVal SourceCount As Long, ByRef Declarations() As TypeDeclarationSyntax, ByRef DeclarationCount As Long, ByRef DeclarationCapacity As Long, ByRef Fields() As FieldDeclarationSyntax, ByRef FieldCount As Long, ByRef FieldCapacity As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim SourceIndex As Long = 0
    Dim Cursor As Long = 0
    While SourceIndex < SourceCount
        ' Separating newlines belong to neither declaration; retain the actual
        ' original unit boundary even when a preceding file lacks a final EOL.
        While Cursor < TokenCount And Tokens(Cursor).StartByte < Sources(SourceIndex).CombinedStart
            Cursor = Cursor + 1
        Wend
        Dim SourceStart As Long = Cursor
        While Cursor < TokenCount And Tokens(Cursor).StartByte < Sources(SourceIndex).CombinedStart + Sources(SourceIndex).ByteLength
            Cursor = Cursor + 1
        Wend
        If Sources(SourceIndex).IsReference <> 0 Then
            Dim NameToken As Long = SourceStart
            While NameToken < Cursor And Tokens(NameToken).TokenKind <> 3
                NameToken = NameToken + 1
            Wend
            If NameToken >= Cursor Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3240", Sources(SourceIndex).CombinedStart, 0, "native CLASS requires its metadata identity")
                ParseClassDeclarations = 0
                Exit Function
            End If
            Dim Existing As Long = 0
            While Existing < DeclarationCount
                If EqualsIdentifier(Declarations(Existing).DeclaredName, Sources(SourceIndex).ModuleName) <> 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2110", Tokens(NameToken).StartByte, Tokens(NameToken).ByteLength, "duplicate type name")
                    ParseClassDeclarations = 0
                    Exit Function
                End If
                Existing = Existing + 1
            Wend
            Dim DeclarationIndex As Long = AppendTypeDeclaration(Declarations, DeclarationCount, DeclarationCapacity, NameToken, SourceStart, Cursor - 1)
            If DeclarationIndex < 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2112", Tokens(NameToken).StartByte, Tokens(NameToken).ByteLength, "type declaration limit exceeded")
                ParseClassDeclarations = 0
                Exit Function
            End If
            Declarations(DeclarationIndex).DeclaredName = Sources(SourceIndex).ModuleName
            Declarations(DeclarationIndex).IsReference = 1
            Declarations(DeclarationIndex).FirstField = FieldCount
            If ParseInstanceFields(Tokens, NameToken + 1, Cursor, Declarations, DeclarationIndex, Fields, FieldCount, FieldCapacity, Diagnostics, DiagnosticCount) = 0 Then
                ParseClassDeclarations = 0
                Exit Function
            End If
        End If
        SourceIndex = SourceIndex + 1
    Wend
    ParseClassDeclarations = 1
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
                If EqualsIdentifier(Declarations(ExistingIndex).DeclaredName, Tokens(Index + 1).Spelling) <> 0 Then
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
            Declarations(DeclarationIndex).DeclaredName = Tokens(Index + 1).Spelling
            Declarations(DeclarationIndex).FirstField = FieldCount
            Dim FieldCursor As Long = Index + 2
            If FieldCursor < DeclarationEnd - 1 And EqualsKeyword(Tokens(FieldCursor).Spelling, "As") <> 0 Then
                FieldCursor = FieldCursor + 1
                If FieldCursor >= DeclarationEnd - 1 Or Tokens(FieldCursor).TokenKind <> 1 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3231", Tokens(Index).StartByte, Tokens(Index).ByteLength, "native Type requires a primitive representation")
                    ParseTypeDeclarations = 0
                    Exit Function
                End If
                Declarations(DeclarationIndex).RepresentationToken = FieldCursor
                FieldCursor = FieldCursor + 1
                If FieldCursor < DeclarationEnd - 1 And Tokens(FieldCursor).TokenKind = 9 Then
                    FieldCursor = FieldCursor + 1
                End If
                If FieldCursor >= DeclarationEnd - 1 Or Tokens(FieldCursor).TokenKind <> 4 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3231", Tokens(Index).StartByte, Tokens(Index).ByteLength, "native Type header requires a complete line")
                    ParseTypeDeclarations = 0
                    Exit Function
                End If
                While FieldCursor < DeclarationEnd - 1
                    If Tokens(FieldCursor).TokenKind <> 4 And Tokens(FieldCursor).TokenKind <> 9 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3231", Tokens(FieldCursor).StartByte, Tokens(FieldCursor).ByteLength, "native Type representation cannot declare fields or executable members")
                        ParseTypeDeclarations = 0
                        Exit Function
                    End If
                    FieldCursor = FieldCursor + 1
                Wend
            End If
            If ParseInstanceFields(Tokens, FieldCursor, DeclarationEnd - 1, Declarations, DeclarationIndex, Fields, FieldCount, FieldCapacity, Diagnostics, DiagnosticCount) = 0 Then
                ParseTypeDeclarations = 0
                Exit Function
            End If
            If Declarations(DeclarationIndex).RepresentationToken < 0 And Declarations(DeclarationIndex).FieldCount = 0 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2113", Tokens(Index).StartByte, Tokens(Index).ByteLength, "ordinary Type requires at least one field")
                ParseTypeDeclarations = 0
                Exit Function
            End If
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
        If EqualsIdentifier(Tokens(Procedures(EntryProcedure).ReturnTypeToken).Spelling, "Long") = 0 Or Procedures(EntryProcedure).ResultIsDynamicArray <> 0 Then
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
                    If Tokens(LineStart).TokenKind = 1 And (EqualsKeyword(Tokens(LineStart).Spelling, "Call") <> 0 Or EqualsKeyword(Tokens(LineStart).Spelling, "CallNew") <> 0) Then
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
                                Dim AssignmentStart As Long = LineStart
                                Dim IsSet As Long = 0
                                If EqualsKeyword(Tokens(LineStart).Spelling, "Set") <> 0 Then
                                    AssignmentStart = AssignmentStart + 1
                                    IsSet = 2
                                End If
                                Dim AssignmentIndex As Long = AppendStatement(Statements, StatementCount, StatementCapacity, ProcedureIndex, 1, AssignmentStart, LineEnd - 1, EqualsToken)
                                If AssignmentIndex >= 0 Then
                                    Statements(AssignmentIndex).Flags = IsSet
                                End If
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

Function ExpressionDepthLimit() As Long
    ExpressionDepthLimit = 128
End Function

Function ValidateExpressionNesting(ByRef Tokens() As Token, ByVal TokenCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim Limit As Long = ExpressionDepthLimit()
    Dim Parentheses As Long = 0
    Dim UnaryRun As Long = 0
    Dim Index As Long = 0
    While Index < TokenCount
        Dim Spelling As String = Tokens(Index).Spelling
        If Spelling = "(" Then
            Parentheses = Parentheses + 1
        End If
        If Spelling = ")" And Parentheses > 0 Then
            Parentheses = Parentheses - 1
        End If
        If Spelling = "+" Or Spelling = "-" Or EqualsKeyword(Spelling, "Not") <> 0 Then
            UnaryRun = UnaryRun + 1
        Else
            UnaryRun = 0
        End If
        If Parentheses > Limit Or UnaryRun >= Limit Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3222", Tokens(Index).StartByte, Tokens(Index).ByteLength, "expression exceeds the bootstrap depth limit")
            ValidateExpressionNesting = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    ValidateExpressionNesting = 1
End Function

Function ValidateExpressionDepth(ByRef Nodes() As SyntaxNode, ByVal NodeCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    ValidateExpressionDepth = 1
    If NodeCount = 0 Then
        Exit Function
    End If
    Dim Limit As Long = ExpressionDepthLimit()
    Dim Colors() As Long
    Dim Heights() As Long
    Dim WalkNodes() As Long
    Dim WalkEdges() As Long
    ReDim Colors(NodeCount - 1)
    ReDim Heights(NodeCount - 1)
    ReDim WalkNodes(Limit - 1)
    ReDim WalkEdges(Limit - 1)
    Dim Root As Long = 0
    While Root < NodeCount
        If Colors(Root) = 0 Then
            Dim Depth As Long = 0
            WalkNodes(0) = Root
            WalkEdges(0) = 0
            Colors(Root) = 1
            While Depth >= 0
                Dim CurrentNode As Long = WalkNodes(Depth)
                If WalkEdges(Depth) < 2 Then
                    Dim Child As Long = Nodes(CurrentNode).LeftNode
                    If WalkEdges(Depth) = 1 Then
                        Child = Nodes(CurrentNode).RightNode
                    End If
                    WalkEdges(Depth) = WalkEdges(Depth) + 1
                    If Child >= NodeCount Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3222", 0, 0, "invalid bootstrap expression graph")
                        ValidateExpressionDepth = 0
                        Exit Function
                    End If
                    If Child >= 0 Then
                        If Colors(Child) = 1 Or Depth >= Limit - 1 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3222", 0, 0, "expression exceeds the bootstrap depth limit")
                            ValidateExpressionDepth = 0
                            Exit Function
                        End If
                        If Colors(Child) = 0 Then
                            Depth = Depth + 1
                            WalkNodes(Depth) = Child
                            WalkEdges(Depth) = 0
                            Colors(Child) = 1
                        End If
                    End If
                Else
                    Dim Height As Long = 1
                    Dim LeftChild As Long = Nodes(CurrentNode).LeftNode
                    Dim RightChild As Long = Nodes(CurrentNode).RightNode
                    If LeftChild >= 0 Then
                        Height = Heights(LeftChild) + 1
                    End If
                    If RightChild >= 0 Then
                        If Heights(RightChild) >= Height Then
                            Height = Heights(RightChild) + 1
                        End If
                    End If
                    If Height > Limit Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3222", 0, 0, "expression exceeds the bootstrap depth limit")
                        ValidateExpressionDepth = 0
                        Exit Function
                    End If
                    Heights(CurrentNode) = Height
                    Colors(CurrentNode) = 2
                    Depth = Depth - 1
                End If
            Wend
        End If
        Root = Root + 1
    Wend
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
                If EqualsKeyword(Tokens(Statements(StatementIndex).FirstToken).Spelling, "CallNew") <> 0 Then
                    ExpressionStart = Statements(StatementIndex).FirstToken
                End If
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
    If Kind = 10 Or Kind = 11 Or Kind = 18 Or Kind = 19 Then
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
    If Kind = 16 Or Kind = 20 Then
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

' Identifies a shared identity, not its inline payload or an array of identities.
Function IsReferenceType(ByVal TypeId As Long) As Long
    IsReferenceType = 0
    If TypeId >= 20000 And TypeId < 30000 Then
        IsReferenceType = 1
    End If
End Function

Function DeclaredTypeId(ByRef Tokens() As Token, ByVal TypeToken As Long, ByVal IsDynamicArray As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long) As Long
    Dim TypeName As String = Tokens(TypeToken).Spelling
    Dim Result As Long = 0
    If EqualsIdentifier(TypeName, "Byte") <> 0 Then
        Result = 7
        If IsDynamicArray <> 0 Then
            Result = Result + 100000
        End If
        DeclaredTypeId = Result
        Exit Function
    End If
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
                                If EqualsIdentifier(Types(TypeIndex).DeclaredName, TypeName) <> 0 Then
                                    Result = 1000 + TypeIndex
                                    If Types(TypeIndex).IsReference <> 0 Then
                                        Result = 20000 + TypeIndex
                                    End If
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

Function ValidateNativeValues(ByRef Tokens() As Token, ByRef Sources() As SourceFile, ByVal SourceCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim Index As Long = 0
    While Index < TypeCount
        If Types(Index).RepresentationToken >= 0 Then
            Dim DeclarationSource As Long = FindSourceIndex(Sources, SourceCount, Tokens(Types(Index).HeaderToken).StartByte)
            If DeclarationSource < 0 Or DeclarationSource <> FindSourceIndex(Sources, SourceCount, Tokens(Types(Index).EndToken).StartByte) Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3231", Tokens(Types(Index).NameToken).StartByte, Tokens(Types(Index).NameToken).ByteLength, "native Type declaration cannot span modules")
                ValidateNativeValues = 0
                Exit Function
            End If
            Dim StorageType As Long = DeclaredTypeId(Tokens, Types(Index).RepresentationToken, 0, Types, TypeCount)
            If DeclaredTypeId(Tokens, Types(Index).NameToken, 0, Types, TypeCount) <> 1000 + Index Or (StorageType <> 2 And StorageType <> 4 And StorageType <> 7) Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3231", Tokens(Types(Index).NameToken).StartByte, Tokens(Types(Index).NameToken).ByteLength, "native Type needs a distinct name and a supported primitive representation: Byte, Integer or Long")
                ValidateNativeValues = 0
                Exit Function
            End If
            Types(Index).RepresentationType = StorageType
        End If
        Index = Index + 1
    Wend
    Index = 0
    While Index < ProcedureCount
        If Procedures(Index).IsIntrinsic <> 0 Then
            Dim Role As Long = Procedures(Index).PrimitiveRole
            If Role >= 3 Then
                If ValidateStorageBinding(Tokens, Procedures, Index, Parameters, Types, TypeCount, Diagnostics, DiagnosticCount) = 0 Then
                    ValidateNativeValues = 0
                    Exit Function
                End If
                If FindSourceIndex(Sources, SourceCount, Tokens(Procedures(Index).HeaderToken).StartByte) <> FindSourceIndex(Sources, SourceCount, Tokens(Procedures(Index).EndToken).StartByte) Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "storage primitive binding cannot cross source modules")
                    ValidateNativeValues = 0
                    Exit Function
                End If
            Else
            If Role = 0 Then
                Dim ExistingSymbol As String = ""
                Dim ExpectedSignature As String = ""
                Call IntrinsicLlvmSymbol(Tokens(Procedures(Index).NameToken).Spelling, ExistingSymbol, ExpectedSignature)
                If ExistingSymbol = "" Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "intrinsic has no implementation binding")
                    ValidateNativeValues = 0
                    Exit Function
                End If
                Dim ActualResult As Long = 0
                If Procedures(Index).ProcedureKind = 2 Then
                    ActualResult = DeclaredTypeId(Tokens, Procedures(Index).ReturnTypeToken, Procedures(Index).ResultIsDynamicArray, Types, TypeCount)
                End If
                Dim ActualSignature As String = LongToString(ActualResult) & ":"
                Dim SignatureParameter As Long = Procedures(Index).FirstParameter
                Dim SignatureEnd As Long = SignatureParameter + Procedures(Index).ParameterCount
                While SignatureParameter < SignatureEnd
                    If SignatureParameter > Procedures(Index).FirstParameter Then
                        ActualSignature = ActualSignature & ","
                    End If
                    If Parameters(SignatureParameter).PassingMode = 2 Then
                        ActualSignature = ActualSignature & "v"
                    Else
                        ActualSignature = ActualSignature & "r"
                    End If
                    ActualSignature = ActualSignature & LongToString(DeclaredTypeId(Tokens, Parameters(SignatureParameter).TypeToken, Parameters(SignatureParameter).IsDynamicArray, Types, TypeCount))
                    SignatureParameter = SignatureParameter + 1
                Wend
                If ActualSignature <> ExpectedSignature Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "bootstrap intrinsic signature does not match its registered implementation")
                    ValidateNativeValues = 0
                    Exit Function
                End If
            Else
                If Procedures(Index).ProcedureKind <> 2 Or Procedures(Index).ParameterCount <> 1 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "native primitive binding requires a Function with one exact ByVal parameter")
                    ValidateNativeValues = 0
                    Exit Function
                End If
                Dim ParameterIndex As Long = Procedures(Index).FirstParameter
                Dim ArgumentType As Long = DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, Parameters(ParameterIndex).IsDynamicArray, Types, TypeCount)
                Dim ResultType As Long = DeclaredTypeId(Tokens, Procedures(Index).ReturnTypeToken, Procedures(Index).ResultIsDynamicArray, Types, TypeCount)
                Dim NativeType As Long = ResultType - 1000
                Dim OtherType As Long = ArgumentType
                If Role = 2 Then
                    NativeType = ArgumentType - 1000
                    OtherType = ResultType
                End If
                If NativeType < 0 Or NativeType >= TypeCount Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "primitive binding requires an exact native Type and its representation")
                    ValidateNativeValues = 0
                    Exit Function
                End If
                If Types(NativeType).RepresentationType = 0 Or Types(NativeType).RepresentationType <> OtherType Or Parameters(ParameterIndex).PassingMode <> 2 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "primitive binding signature must use exact native and representation types, ByVal")
                    ValidateNativeValues = 0
                    Exit Function
                End If
                Procedures(Index).PrimitiveNativeType = NativeType
                Dim TypeSource As Long = FindSourceIndex(Sources, SourceCount, Tokens(Types(NativeType).HeaderToken).StartByte)
                Dim BindingSource As Long = FindSourceIndex(Sources, SourceCount, Tokens(Procedures(Index).HeaderToken).StartByte)
                If TypeSource < 0 Or TypeSource <> BindingSource Or BindingSource <> FindSourceIndex(Sources, SourceCount, Tokens(Procedures(Index).EndToken).StartByte) Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "native primitive bindings belong to the type's declaring module")
                    ValidateNativeValues = 0
                    Exit Function
                End If
                Dim Previous As Long = 0
                While Previous < Index
                    If Procedures(Previous).PrimitiveRole = Role And Procedures(Previous).PrimitiveNativeType = NativeType Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "native Type already has this primitive binding role")
                        ValidateNativeValues = 0
                        Exit Function
                    End If
                    Previous = Previous + 1
                Wend
            End If
            End If
        End If
        Index = Index + 1
    Wend
    ValidateNativeValues = 1
End Function

Function ValidateStorageBinding(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal Index As Long, ByRef Parameters() As ParameterSyntax, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    ValidateStorageBinding = 0
    Dim Role As Long = Procedures(Index).PrimitiveRole
    Dim ResultType As Long = 0
    If Procedures(Index).ProcedureKind = 2 Then
        ResultType = DeclaredTypeId(Tokens, Procedures(Index).ReturnTypeToken, Procedures(Index).ResultIsDynamicArray, Types, TypeCount)
    End If
    Dim Valid As Long = 0
    If Role >= 8 Then
        ValidateStorageBinding = ValidateHostBinding(Tokens, Procedures, Index, Parameters, Types, TypeCount, Diagnostics, DiagnosticCount)
        Exit Function
    End If
    If Role = 6 Or Role = 7 Then
        Dim StorageFirst As Long = Procedures(Index).FirstParameter
        If Role = 6 And ResultType = 1 And Procedures(Index).ParameterCount = 2 Then
            Dim CopyArrayType As Long = DeclaredTypeId(Tokens, Parameters(StorageFirst).TypeToken, Parameters(StorageFirst).IsDynamicArray, Types, TypeCount)
            If CopyArrayType >= 100000 And Parameters(StorageFirst).PassingMode <> 2 And Parameters(StorageFirst + 1).PassingMode <> 2 And DeclaredTypeId(Tokens, Parameters(StorageFirst + 1).TypeToken, Parameters(StorageFirst + 1).IsDynamicArray, Types, TypeCount) = CopyArrayType Then
                Valid = 1
            End If
        End If
        If Role = 7 And ResultType = 1 And Procedures(Index).ParameterCount = 5 Then
            Valid = 1
            Dim StoragePart As Long = 0
            While StoragePart < 5
                Dim StorageParameter As Long = StorageFirst + StoragePart
                Dim StorageParameterType As Long = DeclaredTypeId(Tokens, Parameters(StorageParameter).TypeToken, Parameters(StorageParameter).IsDynamicArray, Types, TypeCount)
                If StoragePart = 0 Or StoragePart = 2 Then
                    If StorageParameterType <> 100007 Or Parameters(StorageParameter).PassingMode = 2 Then
                        Valid = 0
                    End If
                Else
                    If StorageParameterType <> 2 Or Parameters(StorageParameter).PassingMode <> 2 Then
                        Valid = 0
                    End If
                End If
                StoragePart = StoragePart + 1
            Wend
        End If
    Else
    If Role = 5 Then
        If ResultType = 2 And Procedures(Index).ParameterCount = 0 Then
            Valid = 1
        End If
    Else
        Dim RequiredCount As Long = 1
        Dim RequiredResult As Long = 2
        If Role = 4 Then
            RequiredCount = 3
            RequiredResult = 1
        End If
        If ResultType = RequiredResult And Procedures(Index).ParameterCount = RequiredCount Then
            Dim First As Long = Procedures(Index).FirstParameter
            Dim ArrayType As Long = DeclaredTypeId(Tokens, Parameters(First).TypeToken, Parameters(First).IsDynamicArray, Types, TypeCount)
            If ArrayType >= 100000 And Parameters(First).PassingMode <> 2 Then
                Valid = 1
                If Role = 4 Then
                    If Parameters(First + 1).PassingMode <> 2 Or Parameters(First + 2).PassingMode <> 2 Or DeclaredTypeId(Tokens, Parameters(First + 1).TypeToken, Parameters(First + 1).IsDynamicArray, Types, TypeCount) <> 2 Or DeclaredTypeId(Tokens, Parameters(First + 2).TypeToken, Parameters(First + 2).IsDynamicArray, Types, TypeCount) <> 1 Then
                        Valid = 0
                    End If
                End If
            End If
        End If
    End If
    End If
    If Valid = 0 Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "storage primitive binding has an incompatible parameter or result signature")
        Exit Function
    End If
    ValidateStorageBinding = 1
End Function

Function ValidateHostBinding(ByRef Tokens() As Token, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal Index As Long, ByRef Parameters() As ParameterSyntax, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    ValidateHostBinding = 0
    Dim Role As Long = Procedures(Index).PrimitiveRole
    Dim ExpectedSignature As String = ""
    If Role = 8 Then
        ExpectedSignature = "1:r100007,v2,r2,r2,r2"
    End If
    If Role = 9 Then
        ExpectedSignature = "1:v2,r100007,v2,v2,r2,r2"
    End If
    If Role = 10 Then
        ExpectedSignature = "1:r2,r2"
    End If
    If Role = 11 Then
        ExpectedSignature = "1:v2,r100007,r2"
    End If
    If Role = 12 Then
        ExpectedSignature = "1:v2"
    End If
    If Role = 13 Then
        ExpectedSignature = "1:r5"
    End If
    If Role = 14 Then
        ExpectedSignature = "1:v5,r1"
    End If
    If Role = 15 Then
        ExpectedSignature = "1:v5,r1"
    End If
    If Role = 16 Then
        ExpectedSignature = "1:r1"
    End If
    If Role = 17 Then
        ExpectedSignature = "1:v5,v5,r1"
    End If
    If Role = 18 Then
        ExpectedSignature = "1:"
    End If
    Dim ResultType As Long = 0
    If Procedures(Index).ProcedureKind = 2 Then
        ResultType = DeclaredTypeId(Tokens, Procedures(Index).ReturnTypeToken, Procedures(Index).ResultIsDynamicArray, Types, TypeCount)
    End If
    Dim ActualSignature As String = LongToString(ResultType) & ":"
    Dim ParameterIndex As Long = Procedures(Index).FirstParameter
    Dim ParameterEnd As Long = ParameterIndex + Procedures(Index).ParameterCount
    While ParameterIndex < ParameterEnd
        If ParameterIndex > Procedures(Index).FirstParameter Then
            ActualSignature = ActualSignature & ","
        End If
        If Parameters(ParameterIndex).PassingMode = 2 Then
            ActualSignature = ActualSignature & "v"
        Else
            ActualSignature = ActualSignature & "r"
        End If
        ActualSignature = ActualSignature & LongToString(DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, Parameters(ParameterIndex).IsDynamicArray, Types, TypeCount))
        ParameterIndex = ParameterIndex + 1
    Wend
    If ExpectedSignature = "" Or ActualSignature <> ExpectedSignature Then
        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3232", Tokens(Procedures(Index).NameToken).StartByte, Tokens(Procedures(Index).NameToken).ByteLength, "host primitive binding has an incompatible parameter or result signature")
        Exit Function
    End If
    ValidateHostBinding = 1
End Function

Sub HostPrimitiveLlvmSymbol(ByVal Role As Long, ByRef Symbol As String)
    Symbol = ""
    If Role = 8 Then
        Symbol = "ube_file_try_open"
    End If
    If Role = 9 Then
        Symbol = "ube_file_try_read"
    End If
    If Role = 10 Then
        Symbol = "ube_file_try_close"
    End If
    If Role = 11 Then
        Symbol = "ube_process_try_argument"
    End If
    If Role = 12 Then
        Symbol = "ube_error_set_number"
    End If
    If Role = 13 Then
        Symbol = "ube_thread_try_current_id"
    End If
    If Role = 14 Then
        Symbol = "ube_thread_try_is_alive"
    End If
    If Role = 15 Then
        Symbol = "ube_thread_try_request_stop"
    End If
    If Role = 16 Then
        Symbol = "ube_thread_try_stop_requested"
    End If
    If Role = 17 Then
        Symbol = "ube_thread_try_wait"
    End If
    If Role = 18 Then
        Symbol = "ube_thread_try_yield"
    End If
End Sub

Function IsNumericType(ByVal TypeId As Long) As Long
    If TypeId = 2 Or TypeId = 4 Or TypeId = 5 Or TypeId = 6 Or TypeId = 7 Then
        IsNumericType = 1
    Else
        IsNumericType = 0
    End If
End Function

Function PrepareValueLayouts(ByRef Tokens() As Token, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    PrepareValueLayouts = 1
    Dim FieldIndex As Long = 0
    While FieldIndex < FieldCount
        Fields(FieldIndex).ResolvedType = DeclaredTypeId(Tokens, Fields(FieldIndex).TypeToken, Fields(FieldIndex).IsDynamicArray, Types, TypeCount)
        FieldIndex = FieldIndex + 1
    Wend
    If TypeCount = 0 Then
        Exit Function
    End If
    Dim States() As Long
    Dim Records() As Long
    Dim Cursors() As Long
    ReDim States(TypeCount - 1)
    ReDim Records(TypeCount - 1)
    ReDim Cursors(TypeCount - 1)
    Dim Start As Long = 0
    While Start < TypeCount
        Types(Start).RootCount = 0
        Start = Start + 1
    Wend
    Start = 0
    While Start < TypeCount
        Dim Depth As Long = -1
        If States(Start) = 0 Then
            Depth = 0
            Records(0) = Start
            Cursors(0) = Types(Start).FirstField
            States(Start) = 1
        End If
        While Depth >= 0
            Dim RecordIndex As Long = Records(Depth)
            FieldIndex = Cursors(Depth)
            If Types(RecordIndex).RepresentationType <> 0 Or FieldIndex >= Types(RecordIndex).FirstField + Types(RecordIndex).FieldCount Then
                States(RecordIndex) = 2
                Depth = Depth - 1
            Else
                Dim FieldType As Long = Fields(FieldIndex).ResolvedType
                Dim Roots As Long = 0
                If FieldType >= 100000 Or IsReferenceType(FieldType) <> 0 Then
                    Roots = 1
                Else
                    If FieldType >= 1000 Then
                        Dim Child As Long = FieldType - 1000
                        If States(Child) = 1 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3221", Tokens(Fields(FieldIndex).TypeToken).StartByte, Tokens(Fields(FieldIndex).TypeToken).ByteLength, "recursive inline value layout is not supported; use an array edge")
                            PrepareValueLayouts = 0
                            Exit Function
                        End If
                        If States(Child) = 0 Then
                            Depth = Depth + 1
                            Records(Depth) = Child
                            Cursors(Depth) = Types(Child).FirstField
                            States(Child) = 1
                        Else
                            Roots = Types(Child).RootCount
                        End If
                    End If
                End If
                If Records(Depth) = RecordIndex Then
                    Types(RecordIndex).RootCount = Types(RecordIndex).RootCount + Roots
                    If Types(RecordIndex).RootCount > 65536 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3221", Tokens(Types(RecordIndex).NameToken).StartByte, Tokens(Types(RecordIndex).NameToken).ByteLength, "value layout exceeds the managed-reference limit")
                        PrepareValueLayouts = 0
                        Exit Function
                    End If
                    Cursors(Depth) = FieldIndex + 1
                End If
            End If
        Wend
        Start = Start + 1
    Wend
End Function

Sub ValueLayoutSymbol(ByVal TypeId As Long, ByRef Symbol As String)
    Symbol = "@ube.value." & LongToString(TypeId)
End Sub

Function ValueRootCount(ByVal TypeId As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long) As Long
    ValueRootCount = 0
    If TypeId >= 100000 Or IsReferenceType(TypeId) <> 0 Then
        ValueRootCount = 1
    Else
        If TypeId >= 1000 And TypeId < 1000 + TypeCount Then
            ValueRootCount = Types(TypeId - 1000).RootCount
        End If
    End If
End Function

Sub IndexProcedureNodes(ByRef Nodes() As SyntaxNode, ByVal NodeCount As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long)
    Dim ProcedureIndex As Long = 0
    While ProcedureIndex < ProcedureCount
        Procedures(ProcedureIndex).FirstNode = -1
        Procedures(ProcedureIndex).LastNode = -1
        ProcedureIndex = ProcedureIndex + 1
    Wend
    Dim NodeIndex As Long = 0
    While NodeIndex < NodeCount
        Nodes(NodeIndex).NextProcedureNode = -1
        Dim Low As Long = 0
        Dim High As Long = ProcedureCount - 1
        Dim Owner As Long = -1
        While Low <= High
            Dim Middle As Long = Low + (High - Low) \ 2
            If Nodes(NodeIndex).SourceToken < Procedures(Middle).HeaderToken Then
                High = Middle - 1
            Else
                If Nodes(NodeIndex).SourceToken > Procedures(Middle).EndToken Then
                    Low = Middle + 1
                Else
                    Owner = Middle
                    Exit While
                End If
            End If
        Wend
        If Owner >= 0 Then
            If Procedures(Owner).LastNode >= 0 Then
                Nodes(Procedures(Owner).LastNode).NextProcedureNode = NodeIndex
            Else
                Procedures(Owner).FirstNode = NodeIndex
            End If
            Procedures(Owner).LastNode = NodeIndex
        End If
        NodeIndex = NodeIndex + 1
    Wend
End Sub

Sub EmitValueRootOffsets(ByVal TypeIndex As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByVal NewLine As String)
    Dim RecordStack() As Long
    Dim FieldStack() As Long
    Dim Paths() As String
    ReDim RecordStack(TypeCount)
    ReDim FieldStack(TypeCount)
    ReDim Paths(TypeCount)
    Dim Depth As Long = 0
    RecordStack(0) = TypeIndex
    FieldStack(0) = Types(TypeIndex).FirstField
    Paths(0) = "i32 0"
    Dim OffsetText As String = ""
    While Depth >= 0
        Dim RecordIndex As Long = RecordStack(Depth)
        Dim FieldIndex As Long = FieldStack(Depth)
        If FieldIndex >= Types(RecordIndex).FirstField + Types(RecordIndex).FieldCount Then
            Depth = Depth - 1
        Else
            FieldStack(Depth) = FieldIndex + 1
            Dim FieldType As Long = Fields(FieldIndex).ResolvedType
            Dim FieldPath As String = Paths(Depth) & ", i32 " & LongToString(FieldIndex - Types(RecordIndex).FirstField)
            If FieldType >= 100000 Or IsReferenceType(FieldType) <> 0 Then
                If OffsetText <> "" Then
                    OffsetText = OffsetText & ", "
                End If
                OffsetText = OffsetText & "i64 ptrtoint (ptr getelementptr (%ube.type." & LongToString(TypeIndex) & ", ptr null, " & FieldPath & ") to i64)"
            Else
                If ValueRootCount(FieldType, Types, TypeCount) > 0 Then
                    Depth = Depth + 1
                    RecordStack(Depth) = FieldType - 1000
                    FieldStack(Depth) = Types(FieldType - 1000).FirstField
                    Paths(Depth) = FieldPath
                End If
            End If
        End If
    Wend
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "@ube.roots." & LongToString(1000 + TypeIndex) & " = private constant [" & LongToString(Types(TypeIndex).RootCount) & " x i64] [" & OffsetText & "]" & NewLine)
End Sub

Sub EmitValueLayout(ByVal TypeId As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByVal NewLine As String)
    Dim LlvmType As String = ""
    Call LlvmTypeName(TypeId, LlvmType)
    Dim Kind As Long = 0
    Dim FieldCount As Long = 0
    Dim FieldsPointer As String = "null"
    Dim RootsPointer As String = "null"
    Dim Roots As Long = ValueRootCount(TypeId, Types, TypeCount)
    Dim LayoutSymbol As String = ""
    Call ValueLayoutSymbol(TypeId, LayoutSymbol)
    If TypeId = 3 Then
        Kind = 3
    End If
    If IsReferenceType(TypeId) <> 0 Then
        Kind = 3
        RootsPointer = "@ube.roots." & LongToString(TypeId)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, RootsPointer & " = private constant [1 x i64] [i64 0]" & NewLine)
    End If
    If TypeId >= 100000 Then
        Kind = 1
        FieldCount = 1
        FieldsPointer = "@ube.fields." & LongToString(TypeId)
        RootsPointer = "@ube.roots." & LongToString(TypeId)
        Dim ElementLayout As String = ""
        Call ValueLayoutSymbol(TypeId - 100000, ElementLayout)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, FieldsPointer & " = private constant [1 x %ube.value.field] [%ube.value.field { i64 0, ptr " & ElementLayout & " }]" & NewLine)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, RootsPointer & " = private constant [1 x i64] [i64 0]" & NewLine)
    Else
        If TypeId >= 1000 And IsReferenceType(TypeId) = 0 Then
            Dim TypeIndex As Long = TypeId - 1000
            If Types(TypeIndex).RepresentationType = 0 Then
                Kind = 2
                FieldCount = Types(TypeIndex).FieldCount
                If FieldCount > 0 Then
                    FieldsPointer = "@ube.fields." & LongToString(TypeId)
                    Dim FieldText As String = ""
                    Dim FieldIndex As Long = Types(TypeIndex).FirstField
                    While FieldIndex < Types(TypeIndex).FirstField + FieldCount
                        If FieldText <> "" Then
                            FieldText = FieldText & ", "
                        End If
                        Dim Offset As String = "ptrtoint (ptr getelementptr (" & LlvmType & ", ptr null, i32 0, i32 " & LongToString(FieldIndex - Types(TypeIndex).FirstField) & ") to i64)"
                        Dim FieldLayout As String = ""
                        Call ValueLayoutSymbol(Fields(FieldIndex).ResolvedType, FieldLayout)
                        FieldText = FieldText & "%ube.value.field { i64 " & Offset & ", ptr " & FieldLayout & " }"
                        FieldIndex = FieldIndex + 1
                    Wend
                    Call AppendText(Chunks, ChunkCount, ChunkCapacity, FieldsPointer & " = private constant [" & LongToString(FieldCount) & " x %ube.value.field] [" & FieldText & "]" & NewLine)
                End If
                If Roots > 0 Then
                    RootsPointer = "@ube.roots." & LongToString(TypeId)
                    Call EmitValueRootOffsets(TypeIndex, Types, TypeCount, Fields, Chunks, ChunkCount, ChunkCapacity, NewLine)
                End If
            End If
        End If
    End If
    Dim Size As String = "ptrtoint (ptr getelementptr (" & LlvmType & ", ptr null, i32 1) to i64)"
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, LayoutSymbol & " = private constant %ube.value.layout { i64 " & Size & ", i32 " & LongToString(Kind) & ", i32 " & LongToString(FieldCount) & ", ptr " & FieldsPointer & ", i64 " & LongToString(Roots) & ", ptr " & RootsPointer & " }" & NewLine)
End Sub

Sub EmitValueLayouts(ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByVal NewLine As String)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "%ube.gc.layout = type { i64, i64, ptr, ptr }" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "%ube.value.field = type { i64, ptr }" & NewLine & "%ube.value.layout = type { i64, i32, i32, ptr, i64, ptr }" & NewLine)
    Dim TypeId As Long = 1
    While TypeId <= 7
        Call EmitValueLayout(TypeId, Types, TypeCount, Fields, Chunks, ChunkCount, ChunkCapacity, NewLine)
        Call EmitValueLayout(100000 + TypeId, Types, TypeCount, Fields, Chunks, ChunkCount, ChunkCapacity, NewLine)
        TypeId = TypeId + 1
    Wend
    TypeId = 1000
    While TypeId < 1000 + TypeCount
        Call EmitValueLayout(TypeId, Types, TypeCount, Fields, Chunks, ChunkCount, ChunkCapacity, NewLine)
        Call EmitValueLayout(100000 + TypeId, Types, TypeCount, Fields, Chunks, ChunkCount, ChunkCapacity, NewLine)
        Dim TypeIndex As Long = TypeId - 1000
        If Types(TypeIndex).IsReference <> 0 Then
            Call EmitValueLayout(20000 + TypeIndex, Types, TypeCount, Fields, Chunks, ChunkCount, ChunkCapacity, NewLine)
            Call EmitValueLayout(120000 + TypeIndex, Types, TypeCount, Fields, Chunks, ChunkCount, ChunkCapacity, NewLine)
            Dim RootPointer As String = "null"
            If Types(TypeIndex).RootCount > 0 Then
                RootPointer = "@ube.roots." & LongToString(TypeId)
            End If
            Dim PayloadSize As String = "ptrtoint (ptr getelementptr (%ube.type." & LongToString(TypeIndex) & ", ptr null, i32 1) to i64)"
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "@ube.object." & LongToString(TypeIndex) & " = private constant %ube.gc.layout { i64 " & PayloadSize & ", i64 " & LongToString(Types(TypeIndex).RootCount) & ", ptr " & RootPointer & ", ptr null }" & NewLine)
        End If
        TypeId = TypeId + 1
    Wend
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, NewLine)
End Sub

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
            If DeclaredTypeId(Tokens, Procedures(Index).ReturnTypeToken, Procedures(Index).ResultIsDynamicArray, Types, TypeCount) = 0 Then
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
    If TypeId = 1 Or TypeId = 2 Or TypeId = 4 Or TypeId = 5 Or TypeId = 7 Then
        IsIntegralOrBooleanType = 1
    Else
        IsIntegralOrBooleanType = 0
    End If
End Function

Function CommonNumericType(ByVal LeftType As Long, ByVal RightType As Long) As Long
    If LeftType = 7 Then
        LeftType = 4
    End If
    If RightType = 7 Then
        RightType = 4
    End If
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
            FindVariableType = DeclaredTypeId(Tokens, Procedures(Owner).ReturnTypeToken, Procedures(Owner).ResultIsDynamicArray, Types, TypeCount)
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
        IsAddressableExpression = IsAddressableExpression(Tokens, Nodes, AddressedBase, Procedures, Parameters, Locals, LocalCount, Owner)
        Exit Function
    End If
    IsAddressableExpression = 0
End Function

' Resolves dependencies iteratively so an admitted expression cannot consume
' one large native semantic frame per binary/member/call nesting level.
Function ResolveExpressionType(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    ResolveExpressionType = 0
    If Nodes(NodeIndex).ResolvedType <> 0 Then
        ResolveExpressionType = Nodes(NodeIndex).ResolvedType
        Exit Function
    End If
    Dim StackNodes() As Long
    Dim StackEdges() As Long
    Dim StackArguments() As Long
    Dim Limit As Long = ExpressionDepthLimit()
    ReDim StackNodes(Limit - 1)
    ReDim StackEdges(Limit - 1)
    ReDim StackArguments(Limit - 1)
    Dim Depth As Long = 0
    StackNodes(0) = NodeIndex
    While Depth >= 0
        Dim CurrentNode As Long = StackNodes(Depth)
        Dim Kind As Long = Nodes(CurrentNode).NodeKind
        Dim Child As Long = -1
        Dim Ready As Boolean = True
        If Kind = 15 Then
            If StackEdges(Depth) < 2 Then
                Child = Nodes(CurrentNode).LeftNode
                If StackEdges(Depth) = 1 Then
                    Child = Nodes(CurrentNode).RightNode
                End If
                StackEdges(Depth) = StackEdges(Depth) + 1
                Ready = False
            End If
        Else
            If Kind = 14 Or Kind = 16 Or Kind = 20 Then
                If StackEdges(Depth) = 0 Then
                    Child = Nodes(CurrentNode).LeftNode
                    StackEdges(Depth) = 1
                    Ready = False
                End If
            Else
                If Kind = 13 Then
                    If StackEdges(Depth) = 0 Then
                        StackEdges(Depth) = 1
                        StackArguments(Depth) = Nodes(CurrentNode).RightNode
                        Dim Callee As Long = Nodes(CurrentNode).LeftNode
                        If Nodes(Callee).NodeKind <> 12 Then
                            Child = Callee
                        End If
                        Ready = False
                    Else
                        If StackArguments(Depth) >= 0 Then
                            Dim Link As Long = StackArguments(Depth)
                            Child = Nodes(Link).LeftNode
                            StackArguments(Depth) = Nodes(Link).RightNode
                            Ready = False
                        End If
                    End If
                End If
            End If
        End If
        If Ready Then
            Dim Before As Long = DiagnosticCount
            Dim Result As Long = ResolveExpressionNodeType(Tokens, Nodes, CurrentNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
            If DiagnosticCount <> Before Then
                Exit Function
            End If
            Depth = Depth - 1
        Else
            If Child >= 0 Then
                If Nodes(Child).ResolvedType = 0 Then
                    If Depth + 1 >= Limit Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3222", 0, 0, "expression exceeds the bootstrap depth limit")
                        Exit Function
                    End If
                    Depth = Depth + 1
                    StackNodes(Depth) = Child
                    StackEdges(Depth) = 0
                    StackArguments(Depth) = -1
                End If
            End If
        End If
    Wend
    ResolveExpressionType = Nodes(NodeIndex).ResolvedType
End Function

' Resolves one node whose expression children already have their types.
Function ResolveExpressionNodeType(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    If Nodes(NodeIndex).ResolvedType <> 0 Then
        ResolveExpressionNodeType = Nodes(NodeIndex).ResolvedType
        Exit Function
    End If
    Dim Kind As Long = Nodes(NodeIndex).NodeKind
    Dim Result As Long = 0
    If Kind = 20 Then
        Dim ThreadCall As Long = Nodes(NodeIndex).LeftNode
        Dim ThreadCallee As Long = Nodes(ThreadCall).LeftNode
        Dim ThreadProcedure As Long = -1
        If Nodes(ThreadCallee).NodeKind = 12 Then
            ThreadProcedure = FindProcedureByToken(Tokens, Procedures, ProcedureCount, Nodes(ThreadCallee).SourceToken)
        End If
        Dim ValidThread As Long = 0
        If ThreadProcedure >= 0 Then
            If Procedures(ThreadProcedure).ProcedureKind = 1 And Procedures(ThreadProcedure).IsIntrinsic = 0 And EqualsKeyword(Tokens(Procedures(ThreadProcedure).NameToken).Spelling, "Main") = 0 Then
                ValidThread = 1
            End If
        End If
        If ValidThread <> 0 Then
            Dim ThreadParameter As Long = Procedures(ThreadProcedure).FirstParameter
            While ThreadParameter < Procedures(ThreadProcedure).FirstParameter + Procedures(ThreadProcedure).ParameterCount
                Dim CaptureType As Long = DeclaredTypeId(Tokens, Parameters(ThreadParameter).TypeToken, Parameters(ThreadParameter).IsDynamicArray, Types, TypeCount)
                If Parameters(ThreadParameter).PassingMode <> 2 Or (IsIntegralOrBooleanType(CaptureType) = 0 And CaptureType <> 6 And IsReferenceType(CaptureType) = 0) Then
                    ValidThread = 0
                End If
                ThreadParameter = ThreadParameter + 1
            Wend
        End If
        If ValidThread = 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE2240", Tokens(Nodes(NodeIndex).SourceToken).StartByte, Tokens(Nodes(NodeIndex).SourceToken).ByteLength, "bootstrap CallNew requires a non-entry Sub with explicit ByVal scalar or CLASS parameters")
            ResolveExpressionNodeType = 0
            Exit Function
        End If
        Dim ThreadDiagnostics As Long = DiagnosticCount
        Dim ThreadCallType As Long = ResolveExpressionType(Tokens, Nodes, ThreadCall, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
        If DiagnosticCount <> ThreadDiagnostics Then
            ResolveExpressionNodeType = 0
            Exit Function
        End If
        Procedures(ThreadProcedure).IsThreadTarget = 1
        Nodes(NodeIndex).ResolvedType = 5
        ResolveExpressionNodeType = 5
        Exit Function
    End If
    If Kind = 18 Then
        Result = DeclaredTypeId(Tokens, Nodes(NodeIndex).SourceToken, 0, Types, TypeCount)
        If IsReferenceType(Result) = 0 Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3241", Tokens(Nodes(NodeIndex).SourceToken).StartByte, Tokens(Nodes(NodeIndex).SourceToken).ByteLength, "New requires a native CLASS name")
            ResolveExpressionNodeType = 0
            Exit Function
        End If
        Nodes(NodeIndex).ResolvedType = Result
        ResolveExpressionNodeType = Result
        Exit Function
    End If
    If Kind = 19 Then
        Nodes(NodeIndex).ResolvedType = 8
        ResolveExpressionNodeType = 8
        Exit Function
    End If
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
                            Nodes(TypedCallee).ResolvedType = VariableType
                            Result = VariableType - 100000
                            IndexedArray = 1
                        Else
                            Dim TypedProcedure As Long = FindProcedureByToken(Tokens, Procedures, ProcedureCount, TypedCalleeToken)
                            ResolvedProcedure = TypedProcedure
                            If TypedProcedure >= 0 Then
                                If Procedures(TypedProcedure).ProcedureKind = 2 Then
                                    Result = DeclaredTypeId(Tokens, Procedures(TypedProcedure).ReturnTypeToken, Procedures(TypedProcedure).ResultIsDynamicArray, Types, TypeCount)
                                End If
                            Else
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3209", Tokens(TypedCalleeToken).StartByte, Tokens(TypedCalleeToken).ByteLength, "expression is not callable or indexable")
                                ResolveExpressionNodeType = 0
                                Exit Function
                            End If
                        End If
                    Else
                        Dim ReceiverType As Long = ResolveExpressionType(Tokens, Nodes, TypedCallee, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
                        If ReceiverType >= 100000 Then
                            Result = ReceiverType - 100000
                            IndexedArray = 1
                        Else
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3209", Tokens(Nodes(TypedCallee).SourceToken).StartByte, Tokens(Nodes(TypedCallee).SourceToken).ByteLength, "expression is not callable or indexable")
                            ResolveExpressionNodeType = 0
                            Exit Function
                        End If
                    End If
                    Dim TypedArgumentLink As Long = Nodes(NodeIndex).RightNode
                    Dim TypedArgumentIndex As Long = 0
                    While TypedArgumentLink >= 0
                        Dim TypedArgumentNode As Long = Nodes(TypedArgumentLink).LeftNode
                        Dim TypedArgumentType As Long = ResolveExpressionType(Tokens, Nodes, TypedArgumentNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
                        If TypedArgumentType = 0 Then
                            ResolveExpressionNodeType = 0
                            Exit Function
                        End If
                        If ResolvedProcedure >= 0 Then
                            If TypedArgumentIndex >= Procedures(ResolvedProcedure).ParameterCount Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3103", Tokens(Nodes(NodeIndex).SourceToken).StartByte, Tokens(Nodes(NodeIndex).SourceToken).ByteLength, "argument count does not match callable")
                                ResolveExpressionNodeType = 0
                                Exit Function
                            End If
                            Dim TypedParameterIndex As Long = Procedures(ResolvedProcedure).FirstParameter + TypedArgumentIndex
                            Dim TypedParameterType As Long = DeclaredTypeId(Tokens, Parameters(TypedParameterIndex).TypeToken, Parameters(TypedParameterIndex).IsDynamicArray, Types, TypeCount)
                            If Parameters(TypedParameterIndex).PassingMode = 1 Or Parameters(TypedParameterIndex).PassingMode = 3 Then
                                If IsAddressableExpression(Tokens, Nodes, TypedArgumentNode, Procedures, Parameters, Locals, LocalCount, Owner) = 0 Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3202", Tokens(Nodes(TypedArgumentNode).SourceToken).StartByte, Tokens(Nodes(TypedArgumentNode).SourceToken).ByteLength, "ByRef argument must be an addressable variable")
                                    ResolveExpressionNodeType = 0
                                    Exit Function
                                End If
                                If TypedArgumentType <> TypedParameterType Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3203", Tokens(Nodes(TypedArgumentNode).SourceToken).StartByte, Tokens(Nodes(TypedArgumentNode).SourceToken).ByteLength, "ByRef argument type must exactly match the parameter")
                                    ResolveExpressionNodeType = 0
                                    Exit Function
                                End If
                            Else
                                If TypedArgumentType = 8 And IsReferenceType(TypedParameterType) <> 0 Then
                                    Nodes(TypedArgumentNode).ResolvedType = TypedParameterType
                                    TypedArgumentType = TypedParameterType
                                End If
                                If ValidateIntegerConstant(Tokens, Nodes, TypedArgumentNode, TypedParameterType, Diagnostics, DiagnosticCount) = 0 Then
                                    ResolveExpressionNodeType = 0
                                    Exit Function
                                End If
                                If TypedArgumentType <> TypedParameterType And (IsNumericType(TypedArgumentType) = 0 Or IsNumericType(TypedParameterType) = 0) Then
                                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3204", Tokens(Nodes(TypedArgumentNode).SourceToken).StartByte, Tokens(Nodes(TypedArgumentNode).SourceToken).ByteLength, "argument type is not assignable to parameter")
                                    ResolveExpressionNodeType = 0
                                    Exit Function
                                End If
                            End If
                        Else
                            If IndexedArray <> 0 And TypedArgumentType <> 2 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3205", Tokens(Nodes(TypedArgumentNode).SourceToken).StartByte, Tokens(Nodes(TypedArgumentNode).SourceToken).ByteLength, "array index must be Long")
                                ResolveExpressionNodeType = 0
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
                            If IsReferenceType(BaseType) <> 0 Then
                                OwnerType = BaseType - 20000
                            End If
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
                                    If UnaryType = 7 Then
                                        Result = 4
                                    End If
                                End If
                            Else
                                If EqualsKeyword(UnaryOperator, "Not") <> 0 And IsIntegralOrBooleanType(UnaryType) <> 0 Then
                                    Result = UnaryType
                                    If UnaryType = 7 Then
                                        Result = 4
                                    End If
                                End If
                            End If
                        Else
                            If Kind = 15 Then
                                Dim LeftType As Long = ResolveExpressionType(Tokens, Nodes, Nodes(NodeIndex).LeftNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
                                Dim RightType As Long = ResolveExpressionType(Tokens, Nodes, Nodes(NodeIndex).RightNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Diagnostics, DiagnosticCount)
                                Dim TypedOperator As String = Tokens(Nodes(NodeIndex).OperatorToken).Spelling
                                If EqualsKeyword(TypedOperator, "Is") <> 0 Then
                                    If (IsReferenceType(LeftType) <> 0 Or LeftType = 8) And (IsReferenceType(RightType) <> 0 Or RightType = 8) Then
                                        Result = 1
                                    End If
                                    If Result = 0 Then
                                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3243", Tokens(Nodes(NodeIndex).OperatorToken).StartByte, Tokens(Nodes(NodeIndex).OperatorToken).ByteLength, "Is requires reference operands")
                                    End If
                                    Nodes(NodeIndex).ResolvedType = Result
                                    ResolveExpressionNodeType = Result
                                    Exit Function
                                End If
                                If TypedOperator = "=" Or TypedOperator = "<>" Or TypedOperator = "<" Or TypedOperator = ">" Or TypedOperator = "<=" Or TypedOperator = ">=" Then
                                    If LeftType = RightType Or (IsNumericType(LeftType) <> 0 And IsNumericType(RightType) <> 0) Then
                                        Result = 1
                                        If LeftType >= 1000 Then
                                            If LeftType >= 1000 + TypeCount Then
                                                Result = 0
                                            Else
                                                If Types(LeftType - 1000).RepresentationType = 0 Or (TypedOperator <> "=" And TypedOperator <> "<>") Then
                                                    Result = 0
                                                End If
                                            End If
                                        End If
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
                                                If LeftType = 7 Then
                                                    Result = 4
                                                End If
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
        ResolveExpressionNodeType = 0
        Exit Function
    End If
    If Kind = 15 Or Kind = 16 Then
        If ValidateIntegerConstant(Tokens, Nodes, NodeIndex, Result, Diagnostics, DiagnosticCount) = 0 Then
            ResolveExpressionNodeType = 0
            Exit Function
        End If
    End If
    Nodes(NodeIndex).ResolvedType = Result
    ResolveExpressionNodeType = Result
End Function

Function AnalyzeExpressionTypes(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    Dim LocalIndex As Long = 0
    While LocalIndex < LocalCount
        If Locals(LocalIndex).InitializerNode >= 0 Then
            Dim InitializerType As Long = ResolveExpressionType(Tokens, Nodes, Locals(LocalIndex).InitializerNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Locals(LocalIndex).OwnerProcedure, Diagnostics, DiagnosticCount)
            Dim LocalType As Long = DeclaredTypeId(Tokens, Locals(LocalIndex).TypeToken, Locals(LocalIndex).IsDynamicArray, Types, TypeCount)
            If InitializerType = 0 Or LocalType = 0 Or (InitializerType <> LocalType And (IsNumericType(InitializerType) = 0 Or IsNumericType(LocalType) = 0)) Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3201", Tokens(Locals(LocalIndex).NameToken).StartByte, Tokens(Locals(LocalIndex).NameToken).ByteLength, "local initializer type is not assignable")
                AnalyzeExpressionTypes = 0
                Exit Function
            End If
        End If
        If Locals(LocalIndex).InitializerNode >= 0 Then
            If ValidateIntegerConstant(Tokens, Nodes, Locals(LocalIndex).InitializerNode, DeclaredTypeId(Tokens, Locals(LocalIndex).TypeToken, Locals(LocalIndex).IsDynamicArray, Types, TypeCount), Diagnostics, DiagnosticCount) = 0 Then
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
            If Statements(StatementIndex).StatementKind = 3 And (StatementValueType >= 1000 Or StatementValueType = 8) Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3233", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "Print requires a scalar value or an explicit native representation conversion")
                AnalyzeExpressionTypes = 0
                Exit Function
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
                If IsReferenceType(StatementTargetType) <> 0 And StatementValueType = 8 Then
                    Nodes(Statements(StatementIndex).ValueNode).ResolvedType = StatementTargetType
                    StatementValueType = StatementTargetType
                End If
                If (IsReferenceType(StatementTargetType) <> 0 And Statements(StatementIndex).Flags <> 2) Or (IsReferenceType(StatementTargetType) = 0 And Statements(StatementIndex).Flags = 2) Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3242", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "Set requires a reference assignment; reference assignment requires Set")
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
                If StatementTargetType = 0 Or StatementValueType = 0 Or (StatementTargetType <> StatementValueType And (IsNumericType(StatementTargetType) = 0 Or IsNumericType(StatementValueType) = 0)) Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE3208", Tokens(Statements(StatementIndex).FirstToken).StartByte, Tokens(Statements(StatementIndex).FirstToken).ByteLength, "assigned value has an incompatible type")
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
            End If
            If Statements(StatementIndex).StatementKind = 1 Then
                If ValidateIntegerConstant(Tokens, Nodes, Statements(StatementIndex).ValueNode, StatementTargetType, Diagnostics, DiagnosticCount) = 0 Then
                    AnalyzeExpressionTypes = 0
                    Exit Function
                End If
            End If
            If Statements(StatementIndex).StatementKind = 3 Then
                If ValidateIntegerConstant(Tokens, Nodes, Statements(StatementIndex).ValueNode, StatementValueType, Diagnostics, DiagnosticCount) = 0 Then
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
        If Types(TypeIndex).RepresentationType <> 0 Then
            Dim RepresentationLlvm As String = ""
            Call LlvmTypeName(Types(TypeIndex).RepresentationType, RepresentationLlvm)
            TypeLine = TypeLine & RepresentationLlvm
        End If
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
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_file_try_open(ptr, i32, ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_file_try_read(i32, ptr, i32, i32, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_file_try_close(ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_process_try_argument(i32, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_error_set_number(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_read_all_text(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_write_all_text(ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_string_array_join(ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_run_tool(ptr, ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_delete_file(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_monotonic_milliseconds()" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_process_cpu_milliseconds()" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_peak_working_set_kilobytes()" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_validate_resource(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_compiler_resource_llvm_escape(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_compiler_validate_library_bundle(ptr, ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_is_letter(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_unicode_simple_fold_code_point(i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_array_redim(ptr, i32, i32, i64, i1)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_checked_narrow_i64(i64, i32, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_array_release(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_array_element(ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_array_lbound(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_array_ubound(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_thread_capture_allocate(i64, i64, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_thread_capture_destroy(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i64 @ube_thread_start_checked(ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_admit()" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_thread_program_wait()" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_write_barrier(ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_try_current_id(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_try_is_alive(i64, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_try_request_stop(i64, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_try_stop_requested(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_try_wait(i64, i64, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_thread_try_yield()" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_new_object(ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_snapshot(ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_read(ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare void @ube_value_zero(ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_assign(ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_root_enter(ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_root_leave(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_try_redim(ptr, i32, i32, ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_try_resize(ptr, i32, ptr, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_array_length(ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_value_copy_bytes(ptr, i32, ptr, i32, i32)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare ptr @ube_value_array_element(ptr, i32, ptr, ptr, ptr)" & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "declare i32 @ube_gc_collect()" & NewLine)
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
            TypeId = DeclaredTypeId(Tokens, Procedures(Owner).ReturnTypeToken, Procedures(Owner).ResultIsDynamicArray, Types, TypeCount)
            Address = "%result"
        End If
    End If
End Sub

Sub EmitValueSlot(ByVal Slot As String, ByVal TypeId As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByVal NewLine As String)
    Dim LlvmType As String = ""
    Call LlvmTypeName(TypeId, LlvmType)
    Dim Initial As String = "zeroinitializer"
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %" & Slot & " = alloca " & LlvmType & NewLine)
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store " & LlvmType & " " & Initial & ", ptr %" & Slot & NewLine)
End Sub

Sub EmitValueRoot(ByVal Slot As String, ByVal TypeId As Long, ByVal Address As String, ByVal Operation As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByVal NewLine As String)
    If ValueRootCount(TypeId, Types, TypeCount) = 0 Then
        Exit Sub
    End If
    If Operation = 0 Then
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %root." & Slot & " = alloca [32 x i8], align 8" & NewLine)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store [32 x i8] zeroinitializer, ptr %root." & Slot & ", align 8" & NewLine)
    Else
        If Operation = 1 Then
            Dim LayoutSymbol As String = ""
            Call ValueLayoutSymbol(TypeId, LayoutSymbol)
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %root.status." & Slot & " = call i32 @ube_value_root_enter(ptr %root." & Slot & ", ptr " & Address & ", ptr " & LayoutSymbol & ")" & NewLine)
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %root.ok." & Slot & " = icmp ne i32 %root.status." & Slot & ", 0" & NewLine)
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  br i1 %root.ok." & Slot & ", label %root.ready." & Slot & ", label %proc.exit" & NewLine & "root.ready." & Slot & ":" & NewLine)
        Else
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  call i32 @ube_gc_root_leave(ptr %root." & Slot & ")" & NewLine)
        End If
    End If
End Sub

Sub EmitProcedureRoots(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByVal Owner As Long, ByVal Operation As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByVal NewLine As String)
    Dim ParameterIndex As Long = Procedures(Owner).FirstParameter
    While ParameterIndex < Procedures(Owner).FirstParameter + Procedures(Owner).ParameterCount
        Dim ParameterType As Long = DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, Parameters(ParameterIndex).IsDynamicArray, Types, TypeCount)
        Dim ParameterSlot As String = "arg." & LongToString(ParameterIndex)
        If Parameters(ParameterIndex).PassingMode = 2 Then
            ParameterSlot = "param." & LongToString(ParameterIndex)
            Call EmitValueRoot("incoming." & LongToString(ParameterIndex), ParameterType, "%incoming." & LongToString(ParameterIndex), Operation, Types, TypeCount, Chunks, ChunkCount, ChunkCapacity, NewLine)
        End If
        Call EmitValueRoot(ParameterSlot, ParameterType, "%" & ParameterSlot, Operation, Types, TypeCount, Chunks, ChunkCount, ChunkCapacity, NewLine)
        ParameterIndex = ParameterIndex + 1
    Wend
    If Procedures(Owner).ProcedureKind = 2 Then
        Dim ResultType As Long = DeclaredTypeId(Tokens, Procedures(Owner).ReturnTypeToken, Procedures(Owner).ResultIsDynamicArray, Types, TypeCount)
        Call EmitValueRoot("result", ResultType, "%result", Operation, Types, TypeCount, Chunks, ChunkCount, ChunkCapacity, NewLine)
    End If
    Dim LocalIndex As Long = 0
    While LocalIndex < LocalCount
        If Locals(LocalIndex).OwnerProcedure = Owner Then
            Dim LocalType As Long = DeclaredTypeId(Tokens, Locals(LocalIndex).TypeToken, Locals(LocalIndex).IsDynamicArray, Types, TypeCount)
            Call EmitValueRoot("local." & LongToString(LocalIndex), LocalType, "%local." & LongToString(LocalIndex), Operation, Types, TypeCount, Chunks, ChunkCount, ChunkCapacity, NewLine)
        End If
        LocalIndex = LocalIndex + 1
    Wend
    Dim NodeIndex As Long = Procedures(Owner).FirstNode
    While NodeIndex >= 0
        If Nodes(NodeIndex).ResolvedType >= 1000 Then
            Call EmitValueRoot("value." & LongToString(NodeIndex), Nodes(NodeIndex).ResolvedType, "%value." & LongToString(NodeIndex), Operation, Types, TypeCount, Chunks, ChunkCount, ChunkCapacity, NewLine)
        End If
        If Nodes(NodeIndex).NodeKind = 13 And Nodes(NodeIndex).LeftNode >= 0 Then
            Dim ArrayType As Long = Nodes(Nodes(NodeIndex).LeftNode).ResolvedType
            If ArrayType >= 100000 Then
                Call EmitValueRoot("borrow." & LongToString(NodeIndex), ArrayType, "%borrow." & LongToString(NodeIndex), Operation, Types, TypeCount, Chunks, ChunkCount, ChunkCapacity, NewLine)
                Call EmitValueRoot("fallback." & LongToString(NodeIndex), ArrayType - 100000, "%fallback." & LongToString(NodeIndex), Operation, Types, TypeCount, Chunks, ChunkCount, ChunkCapacity, NewLine)
            End If
        End If
        NodeIndex = Nodes(NodeIndex).NextProcedureNode
    Wend
End Sub

Sub EmitProcedureHeader(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByVal ProcedureIndex As Long, ByRef Chunks() As String, ByRef ChunkCount As Long, ByRef ChunkCapacity As Long, ByVal NewLine As String)
    Dim ReturnTypeId As Long = 0
    Dim ReturnLlvmType As String = "void"
    If Procedures(ProcedureIndex).ProcedureKind = 2 Then
        ReturnTypeId = DeclaredTypeId(Tokens, Procedures(ProcedureIndex).ReturnTypeToken, Procedures(ProcedureIndex).ResultIsDynamicArray, Types, TypeCount)
        Call LlvmTypeName(ReturnTypeId, ReturnLlvmType)
    End If
    Dim Symbol As String = ""
    Call ProcedureLlvmSymbol(ProcedureIndex, Symbol)
    Dim ResultIsManaged As Long = ValueRootCount(ReturnTypeId, Types, TypeCount)
    Dim AbiReturnType As String = ReturnLlvmType
    If ResultIsManaged > 0 Then
        AbiReturnType = "void"
    End If
    Dim Header As String = "define " & AbiReturnType & " " & Symbol & "("
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
    If ResultIsManaged > 0 Then
        If Procedures(ProcedureIndex).ParameterCount > 0 Then
            Header = Header & ", "
        End If
        Header = Header & "ptr %result.out"
    End If
    If Procedures(ProcedureIndex).IsThreadTarget <> 0 Then
        If Procedures(ProcedureIndex).ParameterCount > 0 Then
            Header = Header & ", "
        End If
        Header = Header & "ptr %thread.admitted"
    End If
    Dim IsSourceEntry As Long = EqualsIdentifier(Tokens(Procedures(ProcedureIndex).NameToken).Spelling, "Main")
    If IsSourceEntry <> 0 Then
        If Procedures(ProcedureIndex).ParameterCount > 0 Or ResultIsManaged > 0 Then
            Header = Header & ", "
        End If
        Header = Header & "ptr %entry.admitted"
    End If
    Call AppendText(Chunks, ChunkCount, ChunkCapacity, Header & ") {" & NewLine & "entry:" & NewLine)
    If ResultIsManaged > 0 Then
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %result.ready = alloca i1" & NewLine & "  store i1 false, ptr %result.ready" & NewLine)
    End If
    ParameterIndex = Procedures(ProcedureIndex).FirstParameter
    While ParameterIndex < ParameterEnd
        If Parameters(ParameterIndex).PassingMode = 2 Then
            Dim ByValTypeId As Long = DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, Parameters(ParameterIndex).IsDynamicArray, Types, TypeCount)
            Dim ByValLlvmType As String = ""
            Call LlvmTypeName(ByValTypeId, ByValLlvmType)
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %param." & LongToString(ParameterIndex) & " = alloca " & ByValLlvmType & NewLine)
            If ValueRootCount(ByValTypeId, Types, TypeCount) > 0 Then
                Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store " & ByValLlvmType & " zeroinitializer, ptr %param." & LongToString(ParameterIndex) & NewLine)
                Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %incoming." & LongToString(ParameterIndex) & " = alloca " & ByValLlvmType & NewLine)
                Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store " & ByValLlvmType & " %arg." & LongToString(ParameterIndex) & ", ptr %incoming." & LongToString(ParameterIndex) & NewLine)
            Else
                Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store " & ByValLlvmType & " %arg." & LongToString(ParameterIndex) & ", ptr %param." & LongToString(ParameterIndex) & NewLine)
            End If
        End If
        ParameterIndex = ParameterIndex + 1
    Wend
    If Procedures(ProcedureIndex).ProcedureKind = 2 Then
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %result = alloca " & ReturnLlvmType & NewLine)
        Dim ResultInitial As String = "0"
        If ReturnTypeId = 6 Then
            ResultInitial = "0.0"
        End If
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
            If LocalTypeId = 6 Then
                LocalInitial = "0.0"
            End If
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
    Dim NodeIndex As Long = Procedures(ProcedureIndex).FirstNode
    While NodeIndex >= 0
        If Nodes(NodeIndex).ResolvedType >= 1000 Then
            Call EmitValueSlot("value." & LongToString(NodeIndex), Nodes(NodeIndex).ResolvedType, Chunks, ChunkCount, ChunkCapacity, NewLine)
            Call EmitValueSlot("scratch." & LongToString(NodeIndex), Nodes(NodeIndex).ResolvedType, Chunks, ChunkCount, ChunkCapacity, NewLine)
        End If
        If Nodes(NodeIndex).NodeKind = 20 Then
            Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %thread.id." & LongToString(NodeIndex) & " = alloca i64" & NewLine)
        End If
        If Nodes(NodeIndex).NodeKind = 13 And Nodes(NodeIndex).LeftNode >= 0 Then
            Dim ArrayType As Long = Nodes(Nodes(NodeIndex).LeftNode).ResolvedType
            If ArrayType >= 100000 Then
                Call EmitValueSlot("borrow." & LongToString(NodeIndex), ArrayType, Chunks, ChunkCount, ChunkCapacity, NewLine)
                Call EmitValueSlot("fallback." & LongToString(NodeIndex), ArrayType - 100000, Chunks, ChunkCount, ChunkCapacity, NewLine)
            End If
        End If
        NodeIndex = Nodes(NodeIndex).NextProcedureNode
    Wend
    Call EmitProcedureRoots(Tokens, Nodes, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, ProcedureIndex, 0, Chunks, ChunkCount, ChunkCapacity, NewLine)
    Call EmitProcedureRoots(Tokens, Nodes, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, ProcedureIndex, 1, Chunks, ChunkCount, ChunkCapacity, NewLine)
    ParameterIndex = Procedures(ProcedureIndex).FirstParameter
    While ParameterIndex < ParameterEnd
        If Parameters(ParameterIndex).PassingMode = 2 Then
            Dim CopyType As Long = DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, Parameters(ParameterIndex).IsDynamicArray, Types, TypeCount)
            If ValueRootCount(CopyType, Types, TypeCount) > 0 Then
                Dim CopySuffix As String = LongToString(ParameterIndex)
                Dim CopyLayout As String = ""
                Call ValueLayoutSymbol(CopyType, CopyLayout)
                Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %parameter.status." & CopySuffix & " = call i32 @ube_value_assign(ptr %param." & CopySuffix & ", ptr %incoming." & CopySuffix & ", ptr " & CopyLayout & ")" & NewLine)
                Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %parameter.ok." & CopySuffix & " = icmp ne i32 %parameter.status." & CopySuffix & ", 0" & NewLine)
                Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  br i1 %parameter.ok." & CopySuffix & ", label %parameter.ready." & CopySuffix & ", label %proc.exit" & NewLine & "parameter.ready." & CopySuffix & ":" & NewLine)
            End If
        End If
        ParameterIndex = ParameterIndex + 1
    Wend
    If ResultIsManaged > 0 Then
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store i1 true, ptr %result.ready" & NewLine)
    End If
    If Procedures(ProcedureIndex).IsThreadTarget <> 0 Then
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %thread.has.observer = icmp ne ptr %thread.admitted, null" & NewLine)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  br i1 %thread.has.observer, label %thread.admit, label %thread.body" & NewLine & "thread.admit:" & NewLine)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %thread.status = call i32 @ube_thread_admit()" & NewLine & "  %thread.ok = icmp ne i32 %thread.status, 0" & NewLine)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  br i1 %thread.ok, label %thread.ready, label %proc.exit" & NewLine & "thread.ready:" & NewLine)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store i1 true, ptr %thread.admitted" & NewLine & "  br label %thread.body" & NewLine & "thread.body:" & NewLine)
    End If
    If IsSourceEntry <> 0 Then
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  %entry.has.observer = icmp ne ptr %entry.admitted, null" & NewLine)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  br i1 %entry.has.observer, label %entry.admit, label %entry.body" & NewLine & "entry.admit:" & NewLine)
        Call AppendText(Chunks, ChunkCount, ChunkCapacity, "  store i1 true, ptr %entry.admitted" & NewLine & "  br label %entry.body" & NewLine & "entry.body:" & NewLine)
    End If
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

' Emits one array element address while member walks keep a small native frame.
Sub EmitArrayAddress(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Address As String, ByRef TypeId As Long)
        Dim CalleeNode As Long = Nodes(NodeIndex).LeftNode
        Dim ArrayAddress As String = ""
        Dim ArrayTypeId As Long = 0
        If IsAddressableExpression(Tokens, Nodes, CalleeNode, Procedures, Parameters, Locals, LocalCount, Owner) <> 0 Then
            Call EmitLvalueAddress(Tokens, Nodes, CalleeNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, ArrayAddress, ArrayTypeId)
        Else
            Dim ArrayValue As String = ""
            Call EmitExpression(Tokens, Nodes, CalleeNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, ArrayValue, ArrayTypeId)
            ArrayAddress = "%value." & LongToString(CalleeNode)
        End If
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
        Call EmitIntegerConversion(IndexTypeId, 2, IndexOperand, Body, BodyCount, BodyCapacity, State, NewLine)
        Dim ElementLayout As String = ""
        Call ValueLayoutSymbol(ArrayTypeId - 100000, ElementLayout)
        Call NextLlvmRegister(State, Address)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Address & " = call ptr @ube_value_array_element(ptr " & ArrayAddress & ", i32 " & IndexOperand & ", ptr %borrow." & LongToString(NodeIndex) & ", ptr %fallback." & LongToString(NodeIndex) & ", ptr " & ElementLayout & ")" & NewLine)
        TypeId = ArrayTypeId - 100000
        Exit Sub
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
        Call EmitArrayAddress(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, Address, TypeId)
        Exit Sub
    End If
    If Kind = 14 Then
        Dim BaseAddress As String = ""
        Dim BaseTypeId As Long = 0
        Dim BaseNode As Long = Nodes(NodeIndex).LeftNode
        Dim IsReference As Long = IsReferenceType(Nodes(BaseNode).ResolvedType)
        If IsReference <> 0 Then
            Call EmitExpression(Tokens, Nodes, BaseNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, BaseAddress, BaseTypeId)
            Dim ReferenceReady As String = ""
            Call NextLlvmRegister(State, ReferenceReady)
            Dim ReferenceLabel As String = "member.ready." & LongToString(State.NextRegister)
            Dim ReferenceFailure As String = "member.failed." & LongToString(State.NextRegister)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & ReferenceReady & " = icmp ne ptr " & BaseAddress & ", null" & NewLine)
            Call AppendText(Body, BodyCount, BodyCapacity, "  br i1 " & ReferenceReady & ", label %" & ReferenceLabel & ", label %" & ReferenceFailure & NewLine & ReferenceFailure & ":" & NewLine)
            Call AppendText(Body, BodyCount, BodyCapacity, "  call i32 @ube_error_set_number(i32 91)" & NewLine & "  br label %proc.exit" & NewLine & ReferenceLabel & ":" & NewLine)
        Else
        If IsAddressableExpression(Tokens, Nodes, BaseNode, Procedures, Parameters, Locals, LocalCount, Owner) <> 0 Then
            Call EmitLvalueAddress(Tokens, Nodes, BaseNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, BaseAddress, BaseTypeId)
        Else
            Dim BaseValue As String = ""
            Call EmitExpression(Tokens, Nodes, BaseNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, BaseValue, BaseTypeId)
            BaseAddress = "%value." & LongToString(BaseNode)
        End If
        End If
        If State.Failed <> 0 Or BaseTypeId < 1000 Or BaseTypeId >= 100000 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim RecordIndex As Long = BaseTypeId - 1000
        If IsReference <> 0 Then
            RecordIndex = BaseTypeId - 20000
        End If
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

Function ScalarStorageAlignment(ByVal TypeId As Long) As Long
    ScalarStorageAlignment = 8
    If TypeId = 1 Or TypeId = 7 Then
        ScalarStorageAlignment = 1
    End If
    If TypeId = 4 Then
        ScalarStorageAlignment = 2
    End If
    If TypeId = 2 Then
        ScalarStorageAlignment = 4
    End If
End Function

Sub EmitValueLoad(ByVal TypeId As Long, ByVal Address As String, ByVal NodeIndex As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Operand As String)
    Dim LlvmType As String = ""
    Call LlvmTypeName(TypeId, LlvmType)
    Dim LoadAddress As String = Address
    If TypeId >= 1000 Then
        Dim Layout As String = ""
        Call ValueLayoutSymbol(TypeId, Layout)
        Dim Status As String = ""
        Call NextLlvmRegister(State, Status)
        LoadAddress = "%value." & LongToString(NodeIndex)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Status & " = call i32 @ube_value_read(ptr " & LoadAddress & ", ptr " & Address & ", ptr " & Layout & ")" & NewLine)
        Call NextLlvmRegister(State, Operand)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = load " & LlvmType & ", ptr " & LoadAddress & NewLine)
        Exit Sub
    End If
    Call NextLlvmRegister(State, Operand)
    If TypeId = 1 Then
        Dim BooleanByte As String = Operand
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & BooleanByte & " = load atomic i8, ptr " & Address & " seq_cst, align 1" & NewLine)
        Call NextLlvmRegister(State, Operand)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = icmp ne i8 " & BooleanByte & ", 0" & NewLine)
    Else
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = load atomic " & LlvmType & ", ptr " & Address & " seq_cst, align " & LongToString(ScalarStorageAlignment(TypeId)) & NewLine)
    End If
End Sub

Sub EmitValueStore(ByVal TypeId As Long, ByVal Address As String, ByVal Operand As String, ByVal SourceNode As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String)
    Dim LlvmType As String = ""
    Call LlvmTypeName(TypeId, LlvmType)
    If TypeId >= 1000 Then
        Dim Layout As String = ""
        Call ValueLayoutSymbol(TypeId, Layout)
        Dim Status As String = ""
        Call NextLlvmRegister(State, Status)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Status & " = call i32 @ube_value_assign(ptr " & Address & ", ptr %value." & LongToString(SourceNode) & ", ptr " & Layout & ")" & NewLine)
        Exit Sub
    End If
    If TypeId = 1 Then
        Dim BooleanByte As String = ""
        Call NextLlvmRegister(State, BooleanByte)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & BooleanByte & " = zext i1 " & Operand & " to i8" & NewLine)
        Call AppendText(Body, BodyCount, BodyCapacity, "  store atomic i8 " & BooleanByte & ", ptr " & Address & " seq_cst, align 1" & NewLine)
    Else
        Call AppendText(Body, BodyCount, BodyCapacity, "  store atomic " & LlvmType & " " & Operand & ", ptr " & Address & " seq_cst, align " & LongToString(ScalarStorageAlignment(TypeId)) & NewLine)
    End If
End Sub

Sub EmitExpression(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Operand As String, ByRef TypeId As Long)
    If NodeIndex < 0 Then
        State.Failed = 1
        Exit Sub
    End If
    TypeId = Nodes(NodeIndex).ResolvedType
    If Nodes(NodeIndex).NodeKind = 15 Or Nodes(NodeIndex).NodeKind = 16 Then
        Call EmitOperatorExpression(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, Operand, TypeId)
        Exit Sub
    End If
    Dim AddressableValue As Long = 0
    If TypeId >= 1000 Then
        If Nodes(NodeIndex).NodeKind = 12 Or Nodes(NodeIndex).NodeKind = 14 Then
            AddressableValue = 1
        End If
        If Nodes(NodeIndex).NodeKind = 13 Then
            If Nodes(Nodes(NodeIndex).LeftNode).ResolvedType >= 100000 Then
                AddressableValue = 1
            End If
        End If
    End If
    If AddressableValue <> 0 Then
        Dim Address As String = ""
        Call EmitLvalueAddress(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, Address, TypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Call EmitValueLoad(TypeId, Address, NodeIndex, Body, BodyCount, BodyCapacity, State, NewLine, Operand)
        Exit Sub
    End If
    Call EmitExpressionCore(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, Operand, TypeId)
    If State.Failed <> 0 Then
        Exit Sub
    End If
    If TypeId >= 1000 Then
        Dim AggregateType As String = ""
        Call LlvmTypeName(TypeId, AggregateType)
        Call AppendText(Body, BodyCount, BodyCapacity, "  store " & AggregateType & " " & Operand & ", ptr %scratch." & LongToString(NodeIndex) & NewLine)
        Call EmitValueLoad(TypeId, "%scratch." & LongToString(NodeIndex), NodeIndex, Body, BodyCount, BodyCapacity, State, NewLine, Operand)
    End If
End Sub

' Captures evaluated values in typed rooted storage and invokes the actual UBE Sub.
' Native admission consumes that storage exactly once on success or failure.
Sub EmitThreadStart(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Operand As String)
    Dim CallNode As Long = Nodes(NodeIndex).LeftNode
    Dim CalleeNode As Long = Nodes(CallNode).LeftNode
    Dim ProcedureIndex As Long = FindProcedureByToken(Tokens, Procedures, ProcedureCount, Nodes(CalleeNode).SourceToken)
    Dim Suffix As String = LongToString(NodeIndex)
    Dim CaptureType As String = "%ube.capture." & Suffix
    Dim ArgumentCount As Long = Procedures(ProcedureIndex).ParameterCount
    Dim Values() As String
    Dim LlvmTypes() As String
    Dim ParameterTypes() As Long
    ReDim Values(ArgumentCount)
    ReDim LlvmTypes(ArgumentCount)
    ReDim ParameterTypes(ArgumentCount)
    Dim Index As Long = 0
    Dim ArgumentLink As Long = Nodes(CallNode).RightNode
    Dim TypeText As String = ""
    Dim RootText As String = ""
    Dim RootCount As Long = 0
    Dim EntryText As String = "define private void @ube.thread.entry." & Suffix & "(ptr %capture) {" & NewLine & "entry:" & NewLine
    EntryText = EntryText & "  %admitted = alloca i1" & NewLine & "  store i1 false, ptr %admitted" & NewLine
    Dim Arguments As String = ""
    While Index < ArgumentCount
        Dim ArgumentNode As Long = Nodes(ArgumentLink).LeftNode
        Dim ActualType As Long = 0
        Dim ArgumentValue As String = ""
        Call EmitExpression(Tokens, Nodes, ArgumentNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, ArgumentValue, ActualType)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Dim ParameterIndex As Long = Procedures(ProcedureIndex).FirstParameter + Index
        ParameterTypes(Index) = DeclaredTypeId(Tokens, Parameters(ParameterIndex).TypeToken, 0, Types, TypeCount)
        Call EmitIntegerConversion(ActualType, ParameterTypes(Index), ArgumentValue, Body, BodyCount, BodyCapacity, State, NewLine)
        Values(Index) = ArgumentValue
        Dim ParameterLlvmType As String = ""
        Call LlvmTypeName(ParameterTypes(Index), ParameterLlvmType)
        LlvmTypes(Index) = ParameterLlvmType
        If Index > 0 Then
            TypeText = TypeText & ", "
            Arguments = Arguments & ", "
        End If
        TypeText = TypeText & LlvmTypes(Index)
        Dim FieldSuffix As String = LongToString(Index)
        Dim FieldPath As String = "getelementptr (" & CaptureType & ", ptr null, i32 0, i32 " & FieldSuffix & ")"
        If IsReferenceType(ParameterTypes(Index)) <> 0 Then
            If RootCount > 0 Then
                RootText = RootText & ", "
            End If
            RootText = RootText & "i64 ptrtoint (ptr " & FieldPath & " to i64)"
            RootCount = RootCount + 1
        End If
        EntryText = EntryText & "  %field." & FieldSuffix & " = getelementptr " & CaptureType & ", ptr %capture, i32 0, i32 " & FieldSuffix & NewLine
        EntryText = EntryText & "  %argument." & FieldSuffix & " = load " & LlvmTypes(Index) & ", ptr %field." & FieldSuffix & NewLine
        Arguments = Arguments & LlvmTypes(Index) & " %argument." & FieldSuffix
        ArgumentLink = Nodes(ArgumentLink).RightNode
        Index = Index + 1
    Wend
    If ArgumentCount > 0 Then
        Arguments = Arguments & ", "
    End If
    Arguments = Arguments & "ptr %admitted"
    Dim ProcedureSymbol As String = ""
    Call ProcedureLlvmSymbol(ProcedureIndex, ProcedureSymbol)
    EntryText = EntryText & "  call void " & ProcedureSymbol & "(" & Arguments & ")" & NewLine & "  ret void" & NewLine & "}" & NewLine
    Call AppendText(Globals, GlobalCount, GlobalCapacity, CaptureType & " = type { " & TypeText & " }" & NewLine)
    Dim RootsPointer As String = "null"
    If RootCount > 0 Then
        RootsPointer = "@ube.capture.roots." & Suffix
        Call AppendText(Globals, GlobalCount, GlobalCapacity, RootsPointer & " = private constant [" & LongToString(RootCount) & " x i64] [" & RootText & "]" & NewLine)
    End If
    Dim Size As String = "ptrtoint (ptr getelementptr (" & CaptureType & ", ptr null, i32 1) to i64)"
    Call AppendText(Globals, GlobalCount, GlobalCapacity, EntryText)
    Dim Capture As String = ""
    Dim Available As String = ""
    Call NextLlvmRegister(State, Capture)
    Call NextLlvmRegister(State, Available)
    Call AppendText(Body, BodyCount, BodyCapacity, "  store i64 0, ptr %thread.id." & Suffix & NewLine)
    Call AppendText(Body, BodyCount, BodyCapacity, "  " & Capture & " = call ptr @ube_thread_capture_allocate(i64 " & Size & ", i64 " & LongToString(RootCount) & ", ptr " & RootsPointer & ")" & NewLine)
    Call AppendText(Body, BodyCount, BodyCapacity, "  " & Available & " = icmp ne ptr " & Capture & ", null" & NewLine)
    Call AppendText(Body, BodyCount, BodyCapacity, "  br i1 " & Available & ", label %thread.capture." & Suffix & ", label %thread.complete." & Suffix & NewLine & "thread.capture." & Suffix & ":" & NewLine)
    Index = 0
    While Index < ArgumentCount
        Dim FieldAddress As String = ""
        Call NextLlvmRegister(State, FieldAddress)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & FieldAddress & " = getelementptr " & CaptureType & ", ptr " & Capture & ", i32 0, i32 " & LongToString(Index) & NewLine)
        If IsReferenceType(ParameterTypes(Index)) <> 0 Then
            Call AppendText(Body, BodyCount, BodyCapacity, "  call i32 @ube_gc_write_barrier(ptr null, ptr " & FieldAddress & ", ptr " & Values(Index) & ")" & NewLine)
        Else
            Call AppendText(Body, BodyCount, BodyCapacity, "  store " & LlvmTypes(Index) & " " & Values(Index) & ", ptr " & FieldAddress & NewLine)
        End If
        Index = Index + 1
    Wend
    Dim Id As String = ""
    Call NextLlvmRegister(State, Id)
    Call AppendText(Body, BodyCount, BodyCapacity, "  " & Id & " = call i64 @ube_thread_start_checked(ptr @ube.thread.entry." & Suffix & ", ptr " & Capture & ", ptr @ube_thread_capture_destroy)" & NewLine)
    Call AppendText(Body, BodyCount, BodyCapacity, "  store i64 " & Id & ", ptr %thread.id." & Suffix & NewLine & "  br label %thread.complete." & Suffix & NewLine & "thread.complete." & Suffix & ":" & NewLine)
    Call NextLlvmRegister(State, Operand)
    Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = load i64, ptr %thread.id." & Suffix & NewLine)
End Sub

' Evaluates eager operator dependencies with a bounded explicit continuation stack.
Sub EmitOperatorExpression(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Operand As String, ByRef TypeId As Long)
    Dim Limit As Long = ExpressionDepthLimit()
    Dim StackNodes() As Long
    Dim StackSteps() As Long
    Dim LeftValues() As String
    Dim RightValues() As String
    Dim LeftTypes() As Long
    Dim RightTypes() As Long
    ReDim StackNodes(Limit - 1)
    ReDim StackSteps(Limit - 1)
    ReDim LeftValues(Limit - 1)
    ReDim RightValues(Limit - 1)
    ReDim LeftTypes(Limit - 1)
    ReDim RightTypes(Limit - 1)
    Dim Depth As Long = 0
    StackNodes(0) = NodeIndex
    While Depth >= 0
        Dim CurrentNode As Long = StackNodes(Depth)
        Dim Kind As Long = Nodes(CurrentNode).NodeKind
        Dim Child As Long = -1
        Dim Completed As Boolean = False
        Dim CurrentOperand As String = ""
        Dim CurrentType As Long = Nodes(CurrentNode).ResolvedType
        Dim ConstantValue As Long = 0
        Dim ConstantReady As Boolean = False
        If StackSteps(Depth) = 0 And (CurrentType = 2 Or CurrentType = 4 Or CurrentType = 7) Then
            ConstantReady = EvaluateIntegerConstant(Tokens, Nodes, CurrentNode, ConstantValue) = 1
        End If
        If ConstantReady Then
            CurrentOperand = LongToString(ConstantValue)
            Completed = True
        Else
            If Kind = 15 Or Kind = 16 Then
                If StackSteps(Depth) = 0 Then
                    StackSteps(Depth) = 1
                    Child = Nodes(CurrentNode).LeftNode
                Else
                    If Kind = 15 And StackSteps(Depth) = 2 Then
                        StackSteps(Depth) = 3
                        Child = Nodes(CurrentNode).RightNode
                    Else
                        Call EmitOperatorValue(Tokens, Nodes, CurrentNode, Types, TypeCount, LeftValues(Depth), LeftTypes(Depth), RightValues(Depth), RightTypes(Depth), Body, BodyCount, BodyCapacity, State, NewLine, CurrentOperand, CurrentType)
                        Completed = True
                    End If
                End If
            Else
                Call EmitExpression(Tokens, Nodes, CurrentNode, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, CurrentOperand, CurrentType)
                Completed = True
            End If
        End If
        If State.Failed <> 0 Then
            Exit Sub
        End If
        If Completed Then
            Depth = Depth - 1
            If Depth < 0 Then
                Operand = CurrentOperand
                TypeId = CurrentType
            Else
                If StackSteps(Depth) = 1 Then
                    LeftValues(Depth) = CurrentOperand
                    LeftTypes(Depth) = CurrentType
                    StackSteps(Depth) = 2
                Else
                    RightValues(Depth) = CurrentOperand
                    RightTypes(Depth) = CurrentType
                    StackSteps(Depth) = 4
                End If
            End If
        Else
            If Child < 0 Or Depth + 1 >= Limit Then
                State.Failed = 1
                Exit Sub
            End If
            Depth = Depth + 1
            StackNodes(Depth) = Child
            StackSteps(Depth) = 0
        End If
    Wend
End Sub

' Emits an operator from evaluated operands without recursively visiting its tree.
Sub EmitOperatorValue(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByVal LeftOperand As String, ByVal LeftTypeId As Long, ByVal RightOperand As String, ByVal RightTypeId As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Operand As String, ByRef TypeId As Long)
    Dim Kind As Long = Nodes(NodeIndex).NodeKind
    TypeId = Nodes(NodeIndex).ResolvedType
    If Kind = 16 Then
        Dim UnaryOperand As String = LeftOperand
        Dim UnaryTypeId As Long = LeftTypeId
        Dim UnaryOperator As String = Tokens(Nodes(NodeIndex).OperatorToken).Spelling
        If UnaryOperator = "+" Then
            Operand = UnaryOperand
            Call EmitIntegerConversion(UnaryTypeId, TypeId, Operand, Body, BodyCount, BodyCapacity, State, NewLine)
            Exit Sub
        End If
        Call EmitIntegerConversion(UnaryTypeId, TypeId, UnaryOperand, Body, BodyCount, BodyCapacity, State, NewLine)
        UnaryTypeId = TypeId
        Dim UnaryLlvmType As String = ""
        Call LlvmTypeName(UnaryTypeId, UnaryLlvmType)
        Call NextLlvmRegister(State, Operand)
        If UnaryOperator = "-" Then
            If UnaryTypeId = 2 Or UnaryTypeId = 4 Then
                Call EmitIntegerConversion(UnaryTypeId, 2, UnaryOperand, Body, BodyCount, BodyCapacity, State, NewLine)
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call i32 @ube_checked_neg_i32(i32 " & UnaryOperand & ")" & NewLine)
                Call EmitIntegerConversion(2, TypeId, Operand, Body, BodyCount, BodyCapacity, State, NewLine)
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
        Dim BinaryOperator As String = Tokens(Nodes(NodeIndex).OperatorToken).Spelling
        Call NextLlvmRegister(State, Operand)
        If BinaryOperator = "&" Then
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call ptr @ube_string_concat(ptr " & LeftOperand & ", ptr " & RightOperand & ")" & NewLine)
            Exit Sub
        End If
        If LeftTypeId >= 1000 And LeftTypeId < 1000 + TypeCount Then
            If Types(LeftTypeId - 1000).RepresentationType = 0 Or LeftTypeId <> RightTypeId Or (BinaryOperator <> "=" And BinaryOperator <> "<>") Then
                State.Failed = 1
                Exit Sub
            End If
            Dim CompareAggregate As String = ""
            Call LlvmTypeName(LeftTypeId, CompareAggregate)
            Dim LeftScalar As String = ""
            Dim RightScalar As String = ""
            Call NextLlvmRegister(State, LeftScalar)
            Call NextLlvmRegister(State, RightScalar)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & LeftScalar & " = extractvalue " & CompareAggregate & " " & LeftOperand & ", 0" & NewLine)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & RightScalar & " = extractvalue " & CompareAggregate & " " & RightOperand & ", 0" & NewLine)
            RightTypeId = Types(LeftTypeId - 1000).RepresentationType
            LeftTypeId = RightTypeId
            LeftOperand = LeftScalar
            RightOperand = RightScalar
        End If
        If IsNumericType(LeftTypeId) <> 0 And IsNumericType(RightTypeId) <> 0 Then
            Dim PromotedType As Long = CommonNumericType(LeftTypeId, RightTypeId)
            Call EmitIntegerConversion(LeftTypeId, PromotedType, LeftOperand, Body, BodyCount, BodyCapacity, State, NewLine)
            Call EmitIntegerConversion(RightTypeId, PromotedType, RightOperand, Body, BodyCount, BodyCapacity, State, NewLine)
            LeftTypeId = PromotedType
            RightTypeId = PromotedType
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
        If EqualsKeyword(BinaryOperator, "Is") <> 0 Then
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = icmp eq ptr " & LeftOperand & ", " & RightOperand & NewLine)
            TypeId = 1
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
                Call EmitIntegerConversion(LeftTypeId, 2, LeftOperand, Body, BodyCount, BodyCapacity, State, NewLine)
                Call EmitIntegerConversion(RightTypeId, 2, RightOperand, Body, BodyCount, BodyCapacity, State, NewLine)
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call i32 @ube_checked_" & ArithmeticHelper & "_i32(i32 " & LeftOperand & ", i32 " & RightOperand & ")" & NewLine)
                Call EmitIntegerConversion(2, TypeId, Operand, Body, BodyCount, BodyCapacity, State, NewLine)
                Exit Sub
            End If
        End If
        State.Failed = 1
        Exit Sub
    End If
    State.Failed = 1
End Sub

' Emits one call/index operation without placing its large frame on operator walks.
Sub EmitProcedureCall(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Operand As String, ByRef TypeId As Long)
        Dim CallCalleeNode As Long = Nodes(NodeIndex).LeftNode
        If Nodes(CallCalleeNode).ResolvedType >= 100000 Then
            Dim ElementAddress As String = ""
            Call EmitLvalueAddress(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, ElementAddress, TypeId)
            If State.Failed <> 0 Then
                Exit Sub
            End If
            Call EmitValueLoad(TypeId, ElementAddress, NodeIndex, Body, BodyCount, BodyCapacity, State, NewLine, Operand)
            Exit Sub
        End If
        If Nodes(CallCalleeNode).NodeKind <> 12 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim CallNameToken As Long = Nodes(CallCalleeNode).SourceToken
        Dim CalledProcedure As Long = FindProcedureByToken(Tokens, Procedures, ProcedureCount, CallNameToken)
        If CalledProcedure < 0 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim CallSymbol As String = ""
        If Procedures(CalledProcedure).IsIntrinsic <> 0 Then
            Dim BoundSignature As String = ""
            Call IntrinsicLlvmSymbol(Tokens(Procedures(CalledProcedure).NameToken).Spelling, CallSymbol, BoundSignature)
        Else
            Call ProcedureLlvmSymbol(CalledProcedure, CallSymbol)
        End If
        If CallSymbol = "" And Procedures(CalledProcedure).PrimitiveRole = 0 Then
            State.Failed = 1
            Exit Sub
        End If
        Dim Arguments As String = ""
        Dim BoundArrayAddress As String = ""
        Dim BoundCount As String = ""
        Dim BoundPreserve As String = ""
        Dim BoundDestinationStart As String = ""
        Dim BoundByteCount As String = ""
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
                Dim ExpectedArgumentType As Long = DeclaredTypeId(Tokens, Parameters(CalledParameter).TypeToken, Parameters(CalledParameter).IsDynamicArray, Types, TypeCount)
                Call EmitIntegerConversion(CallArgumentType, ExpectedArgumentType, CallArgumentOperand, Body, BodyCount, BodyCapacity, State, NewLine)
                CallArgumentType = ExpectedArgumentType
                Dim CallArgumentLlvmType As String = ""
                Call LlvmTypeName(CallArgumentType, CallArgumentLlvmType)
                Arguments = Arguments & CallArgumentLlvmType & " " & CallArgumentOperand
            End If
            If Procedures(CalledProcedure).PrimitiveRole >= 3 Then
                If CallArgumentIndex = 0 Then
                    BoundArrayAddress = CallArgumentOperand
                End If
                If CallArgumentIndex = 1 Then
                    BoundCount = CallArgumentOperand
                End If
                If CallArgumentIndex = 2 Then
                    BoundPreserve = CallArgumentOperand
                End If
                If CallArgumentIndex = 3 Then
                    BoundDestinationStart = CallArgumentOperand
                End If
                If CallArgumentIndex = 4 Then
                    BoundByteCount = CallArgumentOperand
                End If
            End If
            CallArgumentIndex = CallArgumentIndex + 1
            CallArgumentLink = Nodes(CallArgumentLink).RightNode
        Wend
        If Procedures(CalledProcedure).PrimitiveRole >= 8 Then
            Call HostPrimitiveLlvmSymbol(Procedures(CalledProcedure).PrimitiveRole, CallSymbol)
            If CallSymbol = "" Then
                State.Failed = 1
                Exit Sub
            End If
            Dim HostStatus As String = ""
            Call NextLlvmRegister(State, HostStatus)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & HostStatus & " = call i32 @" & CallSymbol & "(" & Arguments & ")" & NewLine)
            Call NextLlvmRegister(State, Operand)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = icmp ne i32 " & HostStatus & ", 0" & NewLine)
            TypeId = 1
            Exit Sub
        End If
        If Procedures(CalledProcedure).PrimitiveRole >= 3 Then
            Call NextLlvmRegister(State, Operand)
            TypeId = 2
            If Procedures(CalledProcedure).PrimitiveRole = 3 Then
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call i32 @ube_value_array_length(ptr " & BoundArrayAddress & ")" & NewLine)
            End If
            If Procedures(CalledProcedure).PrimitiveRole = 4 Then
                Dim BoundElementLayout As String = ""
                Dim BoundArrayType As Long = DeclaredTypeId(Tokens, Parameters(Procedures(CalledProcedure).FirstParameter).TypeToken, 1, Types, TypeCount)
                Call ValueLayoutSymbol(BoundArrayType - 100000, BoundElementLayout)
                Dim WidePreserve As String = Operand
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & WidePreserve & " = zext i1 " & BoundPreserve & " to i32" & NewLine)
                Dim ResizeStatus As String = ""
                Call NextLlvmRegister(State, ResizeStatus)
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & ResizeStatus & " = call i32 @ube_value_try_resize(ptr " & BoundArrayAddress & ", i32 " & BoundCount & ", ptr " & BoundElementLayout & ", i32 " & WidePreserve & ")" & NewLine)
                Call NextLlvmRegister(State, Operand)
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = icmp ne i32 " & ResizeStatus & ", 0" & NewLine)
                TypeId = 1
            End If
            If Procedures(CalledProcedure).PrimitiveRole = 5 Then
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call i32 @ube_gc_collect()" & NewLine)
            End If
            If Procedures(CalledProcedure).PrimitiveRole = 6 Or Procedures(CalledProcedure).PrimitiveRole = 7 Then
                Dim CopyStatus As String = Operand
                If Procedures(CalledProcedure).PrimitiveRole = 6 Then
                    Dim CopyLayout As String = ""
                    Call ValueLayoutSymbol(DeclaredTypeId(Tokens, Parameters(Procedures(CalledProcedure).FirstParameter).TypeToken, 1, Types, TypeCount), CopyLayout)
                    Call AppendText(Body, BodyCount, BodyCapacity, "  " & CopyStatus & " = call i32 @ube_value_assign(ptr " & BoundArrayAddress & ", ptr " & BoundCount & ", ptr " & CopyLayout & ")" & NewLine)
                Else
                    Call AppendText(Body, BodyCount, BodyCapacity, "  " & CopyStatus & " = call i32 @ube_value_copy_bytes(ptr " & BoundArrayAddress & ", i32 " & BoundCount & ", ptr " & BoundPreserve & ", i32 " & BoundDestinationStart & ", i32 " & BoundByteCount & ")" & NewLine)
                End If
                Call NextLlvmRegister(State, Operand)
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = icmp ne i32 " & CopyStatus & ", 0" & NewLine)
                TypeId = 1
            End If
            Exit Sub
        End If
        If Procedures(CalledProcedure).PrimitiveRole <> 0 Then
            Dim NativeIndex As Long = Procedures(CalledProcedure).PrimitiveNativeType
            If NativeIndex < 0 Or NativeIndex >= TypeCount Or CallArgumentIndex <> 1 Then
                State.Failed = 1
                Exit Sub
            End If
            Dim NativeLlvmType As String = ""
            Call LlvmTypeName(1000 + NativeIndex, NativeLlvmType)
            Call NextLlvmRegister(State, Operand)
            If Procedures(CalledProcedure).PrimitiveRole = 1 Then
                Dim StorageLlvmType As String = ""
                Call LlvmTypeName(Types(NativeIndex).RepresentationType, StorageLlvmType)
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = insertvalue " & NativeLlvmType & " zeroinitializer, " & StorageLlvmType & " " & CallArgumentOperand & ", 0" & NewLine)
                TypeId = 1000 + NativeIndex
            Else
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = extractvalue " & NativeLlvmType & " " & CallArgumentOperand & ", 0" & NewLine)
                TypeId = Types(NativeIndex).RepresentationType
            End If
            Exit Sub
        End If
        If Procedures(CalledProcedure).IsThreadTarget <> 0 Then
            If Arguments <> "" Then
                Arguments = Arguments & ", "
            End If
            Arguments = Arguments & "ptr null"
        End If
        If Procedures(CalledProcedure).IsIntrinsic = 0 And EqualsIdentifier(Tokens(Procedures(CalledProcedure).NameToken).Spelling, "Main") <> 0 Then
            If Arguments <> "" Then
                Arguments = Arguments & ", "
            End If
            Arguments = Arguments & "ptr null"
        End If
        If Procedures(CalledProcedure).ProcedureKind = 2 Then
            TypeId = DeclaredTypeId(Tokens, Procedures(CalledProcedure).ReturnTypeToken, Procedures(CalledProcedure).ResultIsDynamicArray, Types, TypeCount)
            Dim CallReturnLlvmType As String = ""
            Call LlvmTypeName(TypeId, CallReturnLlvmType)
            Call NextLlvmRegister(State, Operand)
            If ValueRootCount(TypeId, Types, TypeCount) > 0 Then
                Dim ResultLayout As String = ""
                Call ValueLayoutSymbol(TypeId, ResultLayout)
                Call AppendText(Body, BodyCount, BodyCapacity, "  call void @ube_value_zero(ptr %value." & LongToString(NodeIndex) & ", ptr " & ResultLayout & ")" & NewLine)
                If Arguments <> "" Then
                    Arguments = Arguments & ", "
                End If
                Arguments = Arguments & "ptr %value." & LongToString(NodeIndex)
                Call AppendText(Body, BodyCount, BodyCapacity, "  call void " & CallSymbol & "(" & Arguments & ")" & NewLine)
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = load " & CallReturnLlvmType & ", ptr %value." & LongToString(NodeIndex) & NewLine)
            Else
                Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = call " & CallReturnLlvmType & " " & CallSymbol & "(" & Arguments & ")" & NewLine)
            End If
        Else
            TypeId = 0
            Operand = ""
            Call AppendText(Body, BodyCount, BodyCapacity, "  call void " & CallSymbol & "(" & Arguments & ")" & NewLine)
        End If
        Exit Sub
End Sub

Sub EmitExpressionCore(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByVal NodeIndex As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String, ByRef Operand As String, ByRef TypeId As Long)
    Operand = ""
    TypeId = 0
    If NodeIndex < 0 Then
        State.Failed = 1
        Exit Sub
    End If
    Dim Kind As Long = Nodes(NodeIndex).NodeKind
    TypeId = Nodes(NodeIndex).ResolvedType
    If TypeId = 2 Or TypeId = 4 Or TypeId = 7 Then
        Dim ConstantValue As Long = 0
        If EvaluateIntegerConstant(Tokens, Nodes, NodeIndex, ConstantValue) = 1 Then
            Operand = LongToString(ConstantValue)
            Exit Sub
        End If
    End If
    If Kind = 20 Then
        Call EmitThreadStart(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, Operand)
        Exit Sub
    End If
    If Kind = 18 Then
        Dim NewStatus As String = ""
        Call NextLlvmRegister(State, NewStatus)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & NewStatus & " = call i32 @ube_value_new_object(ptr %value." & LongToString(NodeIndex) & ", ptr @ube.object." & LongToString(TypeId - 20000) & ")" & NewLine)
        Call NextLlvmRegister(State, Operand)
        Call AppendText(Body, BodyCount, BodyCapacity, "  " & Operand & " = load ptr, ptr %value." & LongToString(NodeIndex) & NewLine)
        Exit Sub
    End If
    If Kind = 19 Then
        Operand = "null"
        If IsReferenceType(TypeId) <> 0 Then
            Call AppendText(Body, BodyCount, BodyCapacity, "  store ptr null, ptr %value." & LongToString(NodeIndex) & NewLine)
        End If
        Exit Sub
    End If
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
        Call EmitValueLoad(TypeId, Address, NodeIndex, Body, BodyCount, BodyCapacity, State, NewLine, Operand)
        Exit Sub
    End If
    If Kind = 14 Then
        Dim MemberAddress As String = ""
        Call EmitLvalueAddress(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, MemberAddress, TypeId)
        If State.Failed <> 0 Then
            Exit Sub
        End If
        Call EmitValueLoad(TypeId, MemberAddress, NodeIndex, Body, BodyCount, BodyCapacity, State, NewLine, Operand)
        Exit Sub
    End If
    If Kind = 13 Then
        Call EmitProcedureCall(Tokens, Nodes, NodeIndex, Procedures, ProcedureCount, Parameters, Locals, LocalCount, Types, TypeCount, Fields, FieldCount, Owner, Globals, GlobalCount, GlobalCapacity, Body, BodyCount, BodyCapacity, State, NewLine, Operand, TypeId)
        Exit Sub
    End If
    State.Failed = 1
End Sub

Sub EmitStructuredProcedureBody(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByVal Owner As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String)
    Call EmitProcedureHeader(Tokens, Nodes, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, Body, BodyCount, BodyCapacity, NewLine)
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
        Dim ReturnTypeId As Long = DeclaredTypeId(Tokens, Procedures(Owner).ReturnTypeToken, Procedures(Owner).ResultIsDynamicArray, Types, TypeCount)
        Dim ReturnLlvmType As String = ""
        Call LlvmTypeName(ReturnTypeId, ReturnLlvmType)
        If ValueRootCount(ReturnTypeId, Types, TypeCount) > 0 Then
            Dim ReturnLayout As String = ""
            Call ValueLayoutSymbol(ReturnTypeId, ReturnLayout)
            Call AppendText(Body, BodyCount, BodyCapacity, "  %result.can.publish = load i1, ptr %result.ready" & NewLine)
            Call AppendText(Body, BodyCount, BodyCapacity, "  br i1 %result.can.publish, label %result.publish, label %result.cleanup" & NewLine & "result.publish:" & NewLine)
            Call AppendText(Body, BodyCount, BodyCapacity, "  call i32 @ube_value_assign(ptr %result.out, ptr %result, ptr " & ReturnLayout & ")" & NewLine)
            Call AppendText(Body, BodyCount, BodyCapacity, "  br label %result.cleanup" & NewLine & "result.cleanup:" & NewLine)
            Call EmitProcedureRoots(Tokens, Nodes, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, 2, Body, BodyCount, BodyCapacity, NewLine)
            Call AppendText(Body, BodyCount, BodyCapacity, "  ret void" & NewLine & "}" & NewLine & NewLine)
        Else
            Dim ReturnOperand As String = ""
            Call NextLlvmRegister(State, ReturnOperand)
            Call AppendText(Body, BodyCount, BodyCapacity, "  " & ReturnOperand & " = load " & ReturnLlvmType & ", ptr %result" & NewLine)
            Call EmitProcedureRoots(Tokens, Nodes, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, 2, Body, BodyCount, BodyCapacity, NewLine)
            Call AppendText(Body, BodyCount, BodyCapacity, "  ret " & ReturnLlvmType & " " & ReturnOperand & NewLine & "}" & NewLine & NewLine)
        End If
    Else
        Call EmitProcedureRoots(Tokens, Nodes, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, Owner, 2, Body, BodyCount, BodyCapacity, NewLine)
        Call AppendText(Body, BodyCount, BodyCapacity, "  ret void" & NewLine & "}" & NewLine & NewLine)
    End If
End Sub

Sub EmitEntryProcedureBody(ByRef Tokens() As Token, ByRef Nodes() As SyntaxNode, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Parameters() As ParameterSyntax, ByRef Locals() As LocalDeclarationSyntax, ByVal LocalCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Fields() As FieldDeclarationSyntax, ByVal FieldCount As Long, ByRef Statements() As StatementSyntax, ByVal StatementCount As Long, ByVal EntryProcedureIndex As Long, ByRef Globals() As String, ByRef GlobalCount As Long, ByRef GlobalCapacity As Long, ByRef Body() As String, ByRef BodyCount As Long, ByRef BodyCapacity As Long, ByRef State As LlvmEmitterState, ByVal NewLine As String)
    Call EmitProcedureHeader(Tokens, Nodes, Procedures, Parameters, Locals, LocalCount, Types, TypeCount, EntryProcedureIndex, Body, BodyCount, BodyCapacity, NewLine)
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
                    Call EmitIntegerConversion(InitializerTypeId, DeclaredTypeId(Tokens, Locals(DeclarationLocal).TypeToken, Locals(DeclarationLocal).IsDynamicArray, Types, TypeCount), InitializerOperand, Body, BodyCount, BodyCapacity, State, NewLine)
                    InitializerTypeId = DeclaredTypeId(Tokens, Locals(DeclarationLocal).TypeToken, Locals(DeclarationLocal).IsDynamicArray, Types, TypeCount)
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
                    Call EmitIntegerConversion(AssignmentValueType, AssignmentTypeId, AssignmentOperand, Body, BodyCount, BodyCapacity, State, NewLine)
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
                            If PrintTypeId = 1 Or PrintTypeId = 4 Or PrintTypeId = 7 Then
                                Call EmitIntegerConversion(PrintTypeId, 2, PrintOperand, Body, BodyCount, BodyCapacity, State, NewLine)
                                PrintTypeId = 2
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
    If EqualsIdentifier(StringSlice(Normalized, NormalizedLength - 4, 4), ".bas") = 0 And EqualsIdentifier(StringSlice(Normalized, NormalizedLength - 4, 4), ".cls") = 0 Then
        NormalizeProjectSourcePath = 0
        Exit Function
    End If
    NormalizeProjectSourcePath = 1
End Function

' Validates one bare identifier using the existing Unicode lexer contract.
Function IsBootstrapIdentity(ByVal Value As String) As Long
    IsBootstrapIdentity = 0
    Dim Length As Long = StringLength(Value)
    If Length = 0 Or Length > 255 Then
        Exit Function
    End If
    Dim Index As Long = IdentifierStartLength(Value, 0, Length)
    If Index = 0 Then
        Exit Function
    End If
    While Index < Length
        Dim Width As Long = IdentifierPartLength(Value, Index, Length)
        If Width = 0 Then
            Exit Function
        End If
        Index = Index + Width
    Wend
    IsBootstrapIdentity = 1
End Function

Function DecodeProjectValue(ByVal RawValue As String, ByRef Value As String) As Long
    DecodeProjectValue = 0
    Value = ""
    Dim Length As Long = StringLength(RawValue)
    If Length < 2 Then
        Exit Function
    End If
    If StringByteAt(RawValue, 0) <> 34 Or StringByteAt(RawValue, Length - 1) <> 34 Then
        Exit Function
    End If
    Dim Index As Long = 1
    While Index < Length - 1
        Dim Current As Long = StringByteAt(RawValue, Index)
        If Current < 32 Then
            Exit Function
        End If
        If Current = 34 Then
            Index = Index + 1
            If Index >= Length - 1 Then
                Exit Function
            End If
            If StringByteAt(RawValue, Index) <> 34 Then
                Exit Function
            End If
        End If
        Value = Value & StringFromByte(Current)
        Index = Index + 1
    Wend
    DecodeProjectValue = 1
End Function

' Lexical normalization retains explicit parent segments for relative roots;
' references never discover directories or consult an environment search path.
Function NormalizeBootstrapPath(ByVal Value As String, ByRef Result As String) As Long
    NormalizeBootstrapPath = 0
    Result = ""
    Dim Length As Long = StringLength(Value)
    If Length = 0 Or Length > 4096 Then
        Exit Function
    End If
    Dim Segments() As String
    ReDim Segments(255)
    Dim Count As Long = 0
    Dim Start As Long = 0
    Dim Index As Long = 0
    Dim Prefix As String = ""
    If StringByteAt(Value, 0) = 47 Or StringByteAt(Value, 0) = 92 Then
        Prefix = "/"
        Start = 1
        Index = 1
    End If
    While Index <= Length
        Dim Separator As Long = 0
        If Index = Length Then
            Separator = 1
        Else
            If StringByteAt(Value, Index) = 47 Or StringByteAt(Value, Index) = 92 Then
                Separator = 1
            End If
        End If
        If Separator <> 0 Then
            Dim Part As String = StringSlice(Value, Start, Index - Start)
            If StringLength(Part) = 0 Then
                Exit Function
            End If
            If Part = ".." Then
                If Count > 0 Then
                    If Segments(Count - 1) <> ".." And StringIndexOf(Segments(Count - 1), ":", 0) < 0 Then
                        Count = Count - 1
                    Else
                        If Count >= 256 Then
                            Exit Function
                        End If
                        Segments(Count) = Part
                        Count = Count + 1
                    End If
                Else
                    If Prefix <> "" Then
                        Exit Function
                    End If
                    Segments(Count) = Part
                    Count = Count + 1
                End If
            Else
                If Part <> "." Then
                    If Count >= 256 Then
                        Exit Function
                    End If
                    Segments(Count) = Part
                    Count = Count + 1
                End If
            End If
            Start = Index + 1
        End If
        Index = Index + 1
    Wend
    Result = Prefix
    Index = 0
    While Index < Count
        If Index > 0 Then
            Result = Result & "/"
        End If
        Result = Result & Segments(Index)
        Index = Index + 1
    Wend
    If StringLength(Result) = 0 Then
        Exit Function
    End If
    NormalizeBootstrapPath = 1
End Function

Function ResolveBootstrapReference(ByVal ProjectPath As String, ByVal RelativePath As String, ByRef Result As String) As Long
    ResolveBootstrapReference = 0
    Dim Length As Long = StringLength(RelativePath)
    If Length < 4 Or Length > 4096 Then
        Exit Function
    End If
    If StringByteAt(RelativePath, 0) = 47 Or StringByteAt(RelativePath, 0) = 92 Or StringIndexOf(RelativePath, ":", 0) >= 0 Then
        Exit Function
    End If
    If EqualsIdentifier(StringSlice(RelativePath, Length - 4, 4), ".UBE") = 0 Then
        Exit Function
    End If
    Dim Separator As Long = StringLength(ProjectPath) - 1
    While Separator >= 0
        If StringByteAt(ProjectPath, Separator) = 47 Or StringByteAt(ProjectPath, Separator) = 92 Then
            Exit While
        End If
        Separator = Separator - 1
    Wend
    ResolveBootstrapReference = NormalizeBootstrapPath(StringSlice(ProjectPath, 0, Separator + 1) & RelativePath, Result)
End Function

Function ResolveSourceInput(ByVal InputPath As String, ByRef SourcePaths() As String, ByRef SourceCount As Long, ByRef SourceCapacity As Long, ByRef SourcePackages() As Long, ByRef PackageNames() As String, ByRef PackageCount As Long, ByRef ErrorMessage As String) As Long
    ResolveSourceInput = 0
    SourceCount = 0
    PackageCount = 1
    ReDim SourcePackages(4351)
    ReDim PackageNames(16)
    Dim Length As Long = StringLength(InputPath)
    If Length < 4 Then
        Call AppendText(SourcePaths, SourceCount, SourceCapacity, InputPath)
        ResolveSourceInput = 1
        Exit Function
    End If
    Dim Suffix As String = StringSlice(InputPath, Length - 4, 4)
    If EqualsIdentifier(Suffix, ".UBG") <> 0 Or EqualsIdentifier(Suffix, ".UBR") <> 0 Then
        ErrorMessage = "error UBE5000: project groups and resource sidecars are not compiler source inputs"
        Exit Function
    End If
    If EqualsIdentifier(Suffix, ".UBE") = 0 Then
        If EqualsIdentifier(Suffix, ".bas") = 0 Then
            ErrorMessage = "error UBE5000: bootstrap source inputs must be .bas or .UBE files"
            Exit Function
        End If
        Call AppendText(SourcePaths, SourceCount, SourceCapacity, InputPath)
        ResolveSourceInput = 1
        Exit Function
    End If
    Dim ProjectPath As String = ""
    If NormalizeBootstrapPath(InputPath, ProjectPath) = 0 Then
        ErrorMessage = "error UBE5012: invalid or excessive project path"
        Exit Function
    End If
    Dim References() As String
    Dim ReferenceCount As Long = 0
    Dim ReferenceCapacity As Long = 0
    Dim PackageName As String = ""
    If ReadBootstrapProject(ProjectPath, 0, PackageName, References, ReferenceCount, ReferenceCapacity, SourcePaths, SourceCount, SourceCapacity, ErrorMessage) = 0 Then
        Exit Function
    End If
    PackageNames(0) = PackageName
    Dim Paths() As String
    ReDim Paths(16)
    Paths(0) = ProjectPath
    Dim Index As Long = 0
    While Index < ReferenceCount
        Dim ReferencePath As String = References(Index)
        Dim Existing As Long = 0
        While Existing < PackageCount
            If EqualsIdentifier(Paths(Existing), ReferencePath) <> 0 Then
                ErrorMessage = "error UBE5013: self-reference, cycle, or duplicate normalized Reference path"
                Exit Function
            End If
            Existing = Existing + 1
        Wend
        Paths(PackageCount) = ReferencePath
        Dim Nested() As String
        Dim NestedCount As Long = 0
        Dim NestedCapacity As Long = 0
        Dim FirstSource As Long = SourceCount
        If ReadBootstrapProject(ReferencePath, 1, PackageName, Nested, NestedCount, NestedCapacity, SourcePaths, SourceCount, SourceCapacity, ErrorMessage) = 0 Then
            Exit Function
        End If
        PackageNames(PackageCount) = PackageName
        Existing = 0
        While Existing < PackageCount
            If EqualsIdentifier(PackageNames(Existing), PackageNames(PackageCount)) <> 0 Then
                ErrorMessage = "error UBE5014: duplicate folded project package Name"
                Exit Function
            End If
            Existing = Existing + 1
        Wend
        While FirstSource < SourceCount
            SourcePackages(FirstSource) = PackageCount
            FirstSource = FirstSource + 1
        Wend
        PackageCount = PackageCount + 1
        Index = Index + 1
    Wend
    ResolveSourceInput = 1
End Function

Function BootstrapTextStartsWith(ByVal Value As String, ByVal Prefix As String) As Long
    BootstrapTextStartsWith = 0
    If StringLength(Value) >= StringLength(Prefix) Then
        BootstrapTextStartsWith = EqualsIdentifier(StringSlice(Value, 0, StringLength(Prefix)), Prefix)
    End If
End Function

' A BOM is a permitted initial encoding signature, not part of header text.
' Callers keep the original bytes and offsets; only their header cursor moves.
Function Utf8HeaderStart(ByVal Contents As String) As Long
    Utf8HeaderStart = 0
    If StringLength(Contents) >= 3 Then
        If StringByteAt(Contents, 0) = 239 And StringByteAt(Contents, 1) = 187 And StringByteAt(Contents, 2) = 191 Then
            Utf8HeaderStart = 3
        End If
    End If
End Function

Function ValidateBootstrapEnvelope(ByVal Contents As String, ByVal RequireNative As Long, ByRef ModuleName As String, ByRef IsReference As Long, ByRef ErrorMessage As String) As Long
    IsReference = 0
    ValidateBootstrapEnvelope = 0
    ModuleName = ""
    Dim Cursor As Long = Utf8HeaderStart(Contents)
    Dim Length As Long = StringLength(Contents)
    Dim EnvelopeState As Long = 0
    While Cursor < Length
        Dim LineEnd As Long = StringIndexOf(Contents, StringFromByte(10), Cursor)
        If LineEnd < 0 Then
            LineEnd = Length
        End If
        Dim EnvelopeLine As String = ""
        Call TrimManifestText(StringSlice(Contents, Cursor, LineEnd - Cursor), EnvelopeLine)
        If StringLength(EnvelopeLine) > 0 Then
            If StringByteAt(EnvelopeLine, 0) <> 39 Then
                If EnvelopeState = 0 Then
                    If EqualsIdentifier(EnvelopeLine, "UBE SOURCE 1 MODULE") <> 0 Or EqualsIdentifier(EnvelopeLine, "UBE SOURCE 1 CLASS") <> 0 Then
                        IsReference = EqualsIdentifier(EnvelopeLine, "UBE SOURCE 1 CLASS")
                        EnvelopeState = 1
                    Else
                        ' Existing bare bootstrap diagnostics may begin with
                        ' the continuation of an intrinsic binding. Let its
                        ' established metadata/ownership validator diagnose it;
                        ' a referenced native package still requires its header.
                        Dim BootstrapMetadata As Long = 0
                        If RequireNative = 0 And BootstrapTextStartsWith(EnvelopeLine, "Attribute") <> 0 Then
                            Dim AttributeEquals As Long = StringIndexOf(EnvelopeLine, "=", 0)
                            If AttributeEquals > 0 Then
                                Dim AttributeKey As String = ""
                                Call TrimManifestText(StringSlice(EnvelopeLine, 0, AttributeEquals), AttributeKey)
                                Dim AttributeKeyLength As Long = StringLength(AttributeKey)
                                If AttributeKeyLength >= 14 Then
                                    BootstrapMetadata = EqualsIdentifier(StringSlice(AttributeKey, AttributeKeyLength - 14, 14), ".UBE_Primitive")
                                End If
                            End If
                        End If
                        If RequireNative <> 0 Or BootstrapTextStartsWith(EnvelopeLine, "UBE ") <> 0 Or EqualsIdentifier(EnvelopeLine, "UBE") <> 0 Or BootstrapTextStartsWith(EnvelopeLine, "Attribute") <> 0 And BootstrapMetadata = 0 Then
                            ErrorMessage = "error UBE5020: native source requires UBE SOURCE 1 MODULE and UBE_Name"
                            Exit Function
                        End If
                        ValidateBootstrapEnvelope = 1
                        Exit Function
                    End If
                Else
                    If EnvelopeState = 1 Then
                        Dim EqualsIndex As Long = StringIndexOf(EnvelopeLine, "=", 0)
                        If EqualsIndex < 1 Then
                            ErrorMessage = "error UBE5021: native source requires one valid Attribute UBE_Name"
                            Exit Function
                        End If
                        Dim Key As String = ""
                        Call TrimManifestText(StringSlice(EnvelopeLine, 0, EqualsIndex), Key)
                        Dim RawName As String = ""
                        Call TrimManifestText(StringSlice(EnvelopeLine, EqualsIndex + 1, StringLength(EnvelopeLine) - EqualsIndex - 1), RawName)
                        If EqualsIndex < 1 Or EqualsIdentifier(Key, "Attribute UBE_Name") = 0 Or DecodeProjectValue(RawName, ModuleName) = 0 Or IsBootstrapIdentity(ModuleName) = 0 Then
                            ErrorMessage = "error UBE5021: native source requires one valid Attribute UBE_Name"
                            Exit Function
                        End If
                        EnvelopeState = 2
                    Else
                        If BootstrapTextStartsWith(EnvelopeLine, "UBE ") <> 0 Or EqualsIdentifier(EnvelopeLine, "UBE") <> 0 Or BootstrapTextStartsWith(EnvelopeLine, "Attribute UBE_") <> 0 Then
                            ErrorMessage = "error UBE5022: duplicate native header or unknown reserved module attribute"
                            Exit Function
                        End If
                    End If
                End If
            End If
        End If
        Cursor = LineEnd + 1
    Wend
    If EnvelopeState = 1 Or RequireNative <> 0 And EnvelopeState <> 2 Then
        ErrorMessage = "error UBE5021: native source requires one valid Attribute UBE_Name"
        Exit Function
    End If
    ValidateBootstrapEnvelope = 1
End Function

' Runs after the existing native ownership/signature checks, preserving their
' specific diagnostics while guarding remaining cross-module declarations.
Function ValidateSourceDeclarationBoundaries(ByRef Tokens() As Token, ByRef Sources() As SourceFile, ByVal SourceCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    ValidateSourceDeclarationBoundaries = 0
    Dim Index As Long = 0
    While Index < ProcedureCount
        If FindSourceIndex(Sources, SourceCount, Tokens(Procedures(Index).HeaderToken).StartByte) <> FindSourceIndex(Sources, SourceCount, Tokens(Procedures(Index).EndToken).StartByte) Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5029", Tokens(Procedures(Index).HeaderToken).StartByte, Tokens(Procedures(Index).HeaderToken).ByteLength, "procedure declaration cannot cross source-module boundaries")
            Exit Function
        End If
        Index = Index + 1
    Wend
    Index = 0
    While Index < TypeCount
        If FindSourceIndex(Sources, SourceCount, Tokens(Types(Index).HeaderToken).StartByte) <> FindSourceIndex(Sources, SourceCount, Tokens(Types(Index).EndToken).StartByte) Then
            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5029", Tokens(Types(Index).HeaderToken).StartByte, Tokens(Types(Index).HeaderToken).ByteLength, "type declaration cannot cross source-module boundaries")
            Exit Function
        End If
        Index = Index + 1
    Wend
    ValidateSourceDeclarationBoundaries = 1
End Function

' Source references deliberately expose a closed Public-only subset. Reject
' unsupported syntax before the old global lookup can grant extra visibility.
Function ValidateBootstrapPackages(ByRef Tokens() As Token, ByVal TokenCount As Long, ByRef Sources() As SourceFile, ByVal SourceCount As Long, ByRef PackageNames() As String, ByVal PackageCount As Long, ByRef Types() As TypeDeclarationSyntax, ByVal TypeCount As Long, ByRef Procedures() As ProcedureDeclarationSyntax, ByVal ProcedureCount As Long, ByRef Diagnostics() As Diagnostic, ByRef DiagnosticCount As Long) As Long
    ValidateBootstrapPackages = 0
    Dim Index As Long = 0
    Dim InProcedure As Long = 0
    Dim InType As Long = 0
    While Index < TokenCount
        Dim SourceIndex As Long = FindSourceIndex(Sources, SourceCount, Tokens(Index).StartByte)
        Dim PackageId As Long = 0
        If SourceIndex >= 0 Then
            PackageId = Sources(SourceIndex).PackageId
        Else
            If Tokens(Index).TokenKind = 1 Then
                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5028", Tokens(Index).StartByte, Tokens(Index).ByteLength, "declaration token is outside its source module")
                Exit Function
            End If
        End If
        Dim LineStart As Long = 0
        If Index = 0 Then
            LineStart = 1
        Else
            If Tokens(Index - 1).TokenKind = 4 Then
                LineStart = 1
            End If
        End If
        If PackageCount > 1 And Tokens(Index).TokenKind = 1 Then
            If Index + 1 < TokenCount Then
                If Tokens(Index + 1).Spelling = "." Then
                    Dim NameIndex As Long = 0
                    While NameIndex < PackageCount
                        If EqualsIdentifier(Tokens(Index).Spelling, PackageNames(NameIndex)) <> 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5026", Tokens(Index).StartByte, Tokens(Index).ByteLength, "package/module qualification is outside the direct-reference bootstrap subset")
                            Exit Function
                        End If
                        NameIndex = NameIndex + 1
                    Wend
                    NameIndex = 0
                    While NameIndex < SourceCount
                        If StringLength(Sources(NameIndex).ModuleName) > 0 And EqualsIdentifier(Tokens(Index).Spelling, Sources(NameIndex).ModuleName) <> 0 Then
                            Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5026", Tokens(Index).StartByte, Tokens(Index).ByteLength, "package/module qualification is outside the direct-reference bootstrap subset")
                            Exit Function
                        End If
                        NameIndex = NameIndex + 1
                    Wend
                End If
            End If
        End If
        If PackageId > 0 And Tokens(Index).TokenKind = 1 Then
            Dim Word As String = Tokens(Index).Spelling
            If LineStart <> 0 Then
                If EqualsKeyword(Word, "Private") <> 0 Or EqualsKeyword(Word, "Friend") <> 0 Or EqualsKeyword(Word, "Global") <> 0 Or EqualsKeyword(Word, "Option") <> 0 Then
                    Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5023", Tokens(Index).StartByte, Tokens(Index).ByteLength, "referenced packages require the Public-only bootstrap declaration subset")
                    Exit Function
                End If
                Dim HeaderIndex As Long = Index
                If EqualsKeyword(Word, "Public") <> 0 Then
                    HeaderIndex = HeaderIndex + 1
                End If
                If HeaderIndex < TokenCount Then
                    If EqualsKeyword(Tokens(HeaderIndex).Spelling, "Intrinsic") <> 0 Then
                        HeaderIndex = HeaderIndex + 1
                    End If
                End If
                Dim HeaderWord As String = Tokens(HeaderIndex).Spelling
                If Sources(SourceIndex).IsReference <> 0 Then
                    HeaderWord = "Attribute"
                End If
                If InProcedure = 0 And InType = 0 Then
                    If EqualsKeyword(HeaderWord, "Sub") <> 0 Or EqualsKeyword(HeaderWord, "Function") <> 0 Then
                        InProcedure = 1
                    Else
                        If EqualsKeyword(HeaderWord, "Type") <> 0 Then
                            InType = 1
                        Else
                            If EqualsKeyword(Word, "UBE") = 0 And EqualsKeyword(Word, "Attribute") = 0 Then
                                Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5023", Tokens(Index).StartByte, Tokens(Index).ByteLength, "unsupported top-level declaration in referenced package")
                                Exit Function
                            End If
                        End If
                    End If
                Else
                    If EqualsKeyword(Word, "End") <> 0 And Index + 1 < TokenCount Then
                        If EqualsKeyword(Tokens(Index + 1).Spelling, "Sub") <> 0 Or EqualsKeyword(Tokens(Index + 1).Spelling, "Function") <> 0 Then
                            InProcedure = 0
                        End If
                        If EqualsKeyword(Tokens(Index + 1).Spelling, "Type") <> 0 Then
                            InType = 0
                        End If
                    End If
                End If
            End If
            Dim DeclarationIndex As Long = 0
            While DeclarationIndex < ProcedureCount
                If EqualsIdentifier(Word, Tokens(Procedures(DeclarationIndex).NameToken).Spelling) <> 0 Then
                    Dim DeclarationSource As Long = FindSourceIndex(Sources, SourceCount, Tokens(Procedures(DeclarationIndex).NameToken).StartByte)
                    If Sources(DeclarationSource).PackageId <> PackageId Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5024", Tokens(Index).StartByte, Tokens(Index).ByteLength, "referenced library cannot name executable or independent-library declarations in this bootstrap subset")
                        Exit Function
                    End If
                    If EqualsKeyword(Word, "Main") <> 0 Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5025", Tokens(Index).StartByte, Tokens(Index).ByteLength, "Main must belong to the executable package")
                        Exit Function
                    End If
                End If
                DeclarationIndex = DeclarationIndex + 1
            Wend
            DeclarationIndex = 0
            While DeclarationIndex < TypeCount
                If EqualsIdentifier(Word, Types(DeclarationIndex).DeclaredName) <> 0 Then
                    Dim TypeSource As Long = FindSourceIndex(Sources, SourceCount, Tokens(Types(DeclarationIndex).NameToken).StartByte)
                    If Sources(TypeSource).PackageId <> PackageId Then
                        Call AppendDiagnostic(Diagnostics, DiagnosticCount, "UBE5024", Tokens(Index).StartByte, Tokens(Index).ByteLength, "referenced library cannot name executable or independent-library declarations in this bootstrap subset")
                        Exit Function
                    End If
                End If
                DeclarationIndex = DeclarationIndex + 1
            Wend
        End If
        Index = Index + 1
    Wend
    ValidateBootstrapPackages = 1
End Function

Function ReadBootstrapProject(ByVal InputPath As String, ByVal IsLibrary As Long, ByRef ProjectName As String, ByRef ReferencePaths() As String, ByRef ReferenceCount As Long, ByRef ReferenceCapacity As Long, ByRef SourcePaths() As String, ByRef SourceCount As Long, ByRef SourceCapacity As Long, ByRef ErrorMessage As String) As Long
    ErrorMessage = ""
    Dim InputLength As Long = StringLength(InputPath)
    Dim ManifestText As String = ReadAllText(InputPath)
    If StringLength(ManifestText) > 1048576 Then
        ErrorMessage = "error UBE5011: project manifest exceeds the 1048576-byte bootstrap limit"
        ReadBootstrapProject = 0
        Exit Function
    End If
    Dim InvalidManifestByte As Long = -1
    If ValidateUtf8(ManifestText, InvalidManifestByte) = 0 Then
        ErrorMessage = "error UBE5001: project manifest is not valid UTF-8"
        ReadBootstrapProject = 0
        Exit Function
    End If
    Dim Cursor As Long = Utf8HeaderStart(ManifestText)
    Dim ManifestLength As Long = StringLength(ManifestText)
    Dim LineNumber As Long = 0
    Dim SawHeader As Long = 0
    Dim SawName As Long = 0
    Dim SawKind As Long = 0
    Dim SawStartup As Long = 0
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
                        ReadBootstrapProject = 0
                        Exit Function
                    End If
                    SawHeader = 1
                Else
                    Dim EqualsIndex As Long = StringIndexOf(ManifestLine, "=", 0)
                    If EqualsIndex < 1 Then
                        ErrorMessage = "error UBE5003: malformed project manifest entry on line " & LongToString(LineNumber)
                        ReadBootstrapProject = 0
                        Exit Function
                    End If
                    Dim Key As String = ""
                    Dim RawValue As String = ""
                    Call TrimManifestText(StringSlice(ManifestLine, 0, EqualsIndex), Key)
                    Call TrimManifestText(StringSlice(ManifestLine, EqualsIndex + 1, StringLength(ManifestLine) - EqualsIndex - 1), RawValue)
                    Dim EntryValue As String = ""
                    If DecodeProjectValue(RawValue, EntryValue) = 0 Then
                        ErrorMessage = "error UBE5004: project values must be quoted on line " & LongToString(LineNumber)
                        ReadBootstrapProject = 0
                        Exit Function
                    End If
                    If EqualsIdentifier(Key, "Name") <> 0 Then
                        If SawName <> 0 Then
                            ErrorMessage = "error UBE5005: duplicate project Name"
                            ReadBootstrapProject = 0
                            Exit Function
                        End If
                        If IsBootstrapIdentity(EntryValue) = 0 Then
                            ErrorMessage = "error UBE5015: project Name must be a valid bootstrap identifier"
                            ReadBootstrapProject = 0
                            Exit Function
                        End If
                        ProjectName = EntryValue
                        SawName = 1
                    Else
                        If EqualsIdentifier(Key, "Kind") <> 0 Then
                            Dim ExpectedKind As String = "Exe"
                            If IsLibrary <> 0 Then
                                ExpectedKind = "Library"
                            End If
                            If SawKind <> 0 Or EqualsIdentifier(EntryValue, ExpectedKind) = 0 Then
                                ErrorMessage = "error UBE5006: project Kind must match the executable or referenced Library role"
                                ReadBootstrapProject = 0
                                Exit Function
                            End If
                            SawKind = 1
                        Else
                            If EqualsIdentifier(Key, "Source") <> 0 Then
                                Dim NormalizedSource As String = ""
                                If NormalizeProjectSourcePath(EntryValue, NormalizedSource) = 0 Then
                                    ErrorMessage = "error UBE5009: project Source path is empty, absolute, or escapes the project directory"
                                    ReadBootstrapProject = 0
                                    Exit Function
                                End If
                                Dim ExistingSource As Long = 0
                                While ExistingSource < SourceRelativeCount
                                    If EqualsIdentifier(SourceRelatives(ExistingSource), NormalizedSource) <> 0 Then
                                        ErrorMessage = "error UBE5010: duplicate project Source after path normalization: " & EntryValue
                                        ReadBootstrapProject = 0
                                        Exit Function
                                    End If
                                    ExistingSource = ExistingSource + 1
                                Wend
                                If SourceRelativeCount >= 256 Then
                                    ErrorMessage = "error UBE5016: project exceeds the 256-source bootstrap limit"
                                    ReadBootstrapProject = 0
                                    Exit Function
                                End If
                                Call AppendText(SourceRelatives, SourceRelativeCount, SourceRelativeCapacity, NormalizedSource)
                            Else
                                If EqualsIdentifier(Key, "Startup") <> 0 Then
                                    If IsLibrary <> 0 Or SawStartup <> 0 Or EqualsIdentifier(EntryValue, "Main") = 0 Then
                                        ErrorMessage = "error UBE5017: Exe requires one Startup Main; Library forbids Startup"
                                        ReadBootstrapProject = 0
                                        Exit Function
                                    End If
                                    SawStartup = 1
                                Else
                                    If EqualsIdentifier(Key, "Reference") <> 0 Then
                                        If IsLibrary <> 0 Then
                                            ErrorMessage = "error UBE5018: nested source references and dependency cycles are outside the direct-reference bootstrap subset"
                                            ReadBootstrapProject = 0
                                            Exit Function
                                        End If
                                        Dim ReferencePath As String = ""
                                        If ReferenceCount >= 16 Or ResolveBootstrapReference(InputPath, EntryValue, ReferencePath) = 0 Then
                                            ErrorMessage = "error UBE5019: Reference requires a relative .UBE path and at most 16 direct libraries"
                                            ReadBootstrapProject = 0
                                            Exit Function
                                        End If
                                        Call AppendText(ReferencePaths, ReferenceCount, ReferenceCapacity, ReferencePath)
                                    Else
                                        ErrorMessage = "error UBE5007: unsupported project key: " & Key
                                        ReadBootstrapProject = 0
                                        Exit Function
                                    End If
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
        ReadBootstrapProject = 0
        Exit Function
    End If
    If IsLibrary = 0 And SawStartup = 0 Then
        ErrorMessage = "error UBE5017: Exe requires one Startup Main; Library forbids Startup"
        ReadBootstrapProject = 0
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
    ReadBootstrapProject = 1
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
    Dim SourcePackages() As Long
    Dim PackageNames() As String
    Dim PackageCount As Long = 0
    If ResolveSourceInput(InputPath, SourcePaths, SourcePathCount, SourcePathCapacity, SourcePackages, PackageNames, PackageCount, InputError) = 0 Then
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
        Sources(LoadIndex).PackageId = SourcePackages(LoadIndex)
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
        Dim RequireNative As Long = 0
        If PackageCount > 1 Then
            RequireNative = 1
        End If
        Dim ModuleName As String = ""
        Dim IsReference As Long = 0
        If ValidateBootstrapEnvelope(Sources(LoadIndex).Contents, RequireNative, ModuleName, IsReference, InputError) = 0 Then
            Print Sources(LoadIndex).FilePath & "(1,1): " & InputError
            Main = 1
            Exit Function
        End If
        Sources(LoadIndex).IsReference = IsReference
        Sources(LoadIndex).ModuleName = ModuleName
        Dim PreviousModule As Long = 0
        While PreviousModule < LoadIndex
            If Sources(PreviousModule).PackageId = Sources(LoadIndex).PackageId And StringLength(Sources(LoadIndex).ModuleName) > 0 Then
                If EqualsIdentifier(Sources(PreviousModule).ModuleName, Sources(LoadIndex).ModuleName) <> 0 Then
                    Print Sources(LoadIndex).FilePath & "(1,1): error UBE5027: duplicate folded module identity in package"
                    Main = 1
                    Exit Function
                End If
            End If
            PreviousModule = PreviousModule + 1
        Wend
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
    If ValidateExpressionNesting(Tokens, TokenCount, Diagnostics, DiagnosticCount) = 0 Then
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
    If ParseClassDeclarations(Tokens, TokenCount, Sources, SourcePathCount, TypeDeclarations, TypeDeclarationCount, TypeDeclarationCapacity, FieldDeclarations, FieldDeclarationCount, FieldDeclarationCapacity, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
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
    If ValidateBootstrapPackages(Tokens, TokenCount, Sources, SourcePathCount, PackageNames, PackageCount, TypeDeclarations, TypeDeclarationCount, Procedures, ProcedureCount, Diagnostics, DiagnosticCount) = 0 Then
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
    If ValidateNativeValues(Tokens, Sources, SourcePathCount, TypeDeclarations, TypeDeclarationCount, Procedures, ProcedureCount, Parameters, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If ValidateSourceDeclarationBoundaries(Tokens, Sources, SourcePathCount, TypeDeclarations, TypeDeclarationCount, Procedures, ProcedureCount, Diagnostics, DiagnosticCount) = 0 Then
        Call ReportProjectDiagnostics(Sources, SourcePathCount, Diagnostics, DiagnosticCount)
        Main = 1
        Exit Function
    End If
    If PrepareValueLayouts(Tokens, TypeDeclarations, TypeDeclarationCount, FieldDeclarations, FieldDeclarationCount, Diagnostics, DiagnosticCount) = 0 Then
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
    If ValidateExpressionDepth(SyntaxNodes, SyntaxNodeCount, Diagnostics, DiagnosticCount) = 0 Then
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
    Call IndexProcedureNodes(SyntaxNodes, SyntaxNodeCount, Procedures, ProcedureCount)
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
    Call EmitValueLayouts(TypeDeclarations, TypeDeclarationCount, FieldDeclarations, ResultChunks, ResultChunkCount, ResultChunkCapacity, NewLine)
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
    Dim EntryFailureOperand As String = ""
    Call EmitStringConstant("UBE runtime: cannot enter Main: managed root or argument admission failed; release roots or memory and retry.", GlobalChunks, GlobalChunkCount, GlobalChunkCapacity, EmitterState, NewLine, EntryFailureOperand)
    If GlobalChunkCount > 0 Then
        Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, StringArrayJoin(GlobalChunks, GlobalChunkCount) & NewLine)
    End If
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, StringArrayJoin(BodyChunks, BodyChunkCount))
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "define i32 @main(i32 %argc, ptr %argv) {" & NewLine & "entry:" & NewLine)
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  %entry.admitted = alloca i1" & NewLine & "  store i1 false, ptr %entry.admitted" & NewLine)
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  call void @ube_runtime_set_args(i32 %argc, ptr %argv)" & NewLine)
    Dim EntrySymbol As String = ""
    Call ProcedureLlvmSymbol(EntryProcedureIndex, EntrySymbol)
    If Procedures(EntryProcedureIndex).ProcedureKind = 2 Then
        Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  %exit.code = call i32 " & EntrySymbol & "(ptr %entry.admitted)" & NewLine)
    Else
        Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  call void " & EntrySymbol & "(ptr %entry.admitted)" & NewLine)
    End If
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  call void @ube_thread_program_wait()" & NewLine)
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  %entry.did.admit = load i1, ptr %entry.admitted" & NewLine)
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  br i1 %entry.did.admit, label %entry.complete, label %entry.failure" & NewLine & "entry.failure:" & NewLine)
    Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  call i32 @puts(ptr " & EntryFailureOperand & ")" & NewLine & "  ret i32 70" & NewLine & "entry.complete:" & NewLine)
    If Procedures(EntryProcedureIndex).ProcedureKind = 2 Then
        Call AppendText(ResultChunks, ResultChunkCount, ResultChunkCapacity, "  ret i32 %exit.code" & NewLine & "}" & NewLine)
    Else
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
