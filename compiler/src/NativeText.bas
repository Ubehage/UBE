UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeText"
' Emits immutable byte inputs and calls ordinary UBE text support by bound identity.

' Rejects invalid internal facts before a private output can be published.
Private Function InvalidFacts(ByRef S As NativeEmission.EmissionState, ByVal Node As Long) As Boolean
    S.Text.Failed = True
    S.FailureCode = 9
    S.FailureReason = 62
    S.ErrorNode = Node
End Function

' Routes admitted text conversions through the validated ordinary library roles.
Public Function ConvertValue(ByRef A() As DeclarationBinder.BoundSymbol, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByVal Value As Long, ByVal SourceType As Long, ByVal DestinationType As Long) As Long
    Dim Symbol As Long
    Dim Low As Long
    Dim High As Long
    On Error GoTo Failed
    If SourceType = DestinationType Then ConvertValue = Value: Exit Function
    If DestinationType = SyntaxTokens.KwString Then
        If SourceType = SyntaxTokens.KwBoolean Then
            Symbol = S.ManagedRoles.FromBooleanSymbol
        ElseIf ConstantValues.IntegerWidth(SourceType) <> 0 Then
            Symbol = S.ManagedRoles.FromIntegerSymbol
        End If
        If Symbol = 0 Then Call InvalidFacts(S, Node): Exit Function
        ConvertValue = CallSupport(A, S, B, Token, Catalog, Seen, Nexts, Symbol, Node, 1, Value, 0, 0, False, True)
    ElseIf SourceType = SyntaxTokens.KwString Then
        If DestinationType = SyntaxTokens.KwBoolean Then
            ConvertValue = CallSupport(A, S, B, Token, Catalog, Seen, Nexts, S.ManagedRoles.ToBooleanSymbol, Node, 1, Value, 0, 0, False, False)
        ElseIf ConstantValues.IntegerWidth(DestinationType) <> 0 Then
            Low = NativeEmission.Literal(S, B, Token, Catalog, ConstantValues.Minimum(DestinationType))
            High = NativeEmission.Literal(S, B, Token, Catalog, ConstantValues.Maximum(DestinationType))
            ConvertValue = CallSupport(A, S, B, Token, Catalog, Seen, Nexts, S.ManagedRoles.ToIntegerSymbol, Node, 3, Value, Low, High, False, False)
        Else
            Call InvalidFacts(S, Node)
        End If
    Else
        Call InvalidFacts(S, Node)
    End If
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = Node
End Function

' Publishes a returned managed identity before failure dispatch or further calls.
Public Function TakeResult(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Node As Long) As Long
    Dim Value As Long
    On Error GoTo Failed
    Value = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.TextRootTake, Value, Node, 0, 0) Then Exit Function
    TakeResult = Value
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
End Function

' Calls an already validated ordinary support identity with prepared rooted operands.
Public Function CallSupport(ByRef A() As DeclarationBinder.BoundSymbol, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Symbol As Long, ByVal Node As Long, ByVal ArgumentCount As Long, ByVal First As Long, ByVal Second As Long, ByVal Third As Long, ByVal FirstIsReference As Boolean, ByVal ManagedResult As Boolean) As Long
    Dim Pair As Long
    Dim Value As Long
    Dim Template As Long
    On Error GoTo Failed
    If Symbol < 1 Or ArgumentCount < 1 Or ArgumentCount > 3 Then Call InvalidFacts(S, Node): Exit Function
    If Not NativeEmission.Safepoint(S, B, Token, Catalog) Then Exit Function
    If Not NativeStorage.EnsureModule(S, B, Token, Catalog, A(Symbol - 1).ModuleIndex) Then Exit Function
    Pair = NativeEmission.NewValue(S)
    If Not LLVMFormat.TryFormat(S.Text, B, Token, Catalog, LLVMTemplates.CallStart, Pair, Symbol, 0, 0) Then Exit Function
    Template = LLVMTemplates.CallValueArgument
    If FirstIsReference Then Template = LLVMTemplates.CallReferenceArgument
    If Not LLVMFormat.TryFormat(S.Text, B, Token, Catalog, Template, First, 0, 0, 0) Then Exit Function
    If ArgumentCount > 1 Then
        If Not LLVMFormat.TryFormat(S.Text, B, Token, Catalog, LLVMTemplates.CallValueArgument, Second, 0, 0, 0) Then Exit Function
    End If
    If ArgumentCount > 2 Then
        If Not LLVMFormat.TryFormat(S.Text, B, Token, Catalog, LLVMTemplates.CallValueArgument, Third, 0, 0, 0) Then Exit Function
    End If
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CallEnd, 0, 0, 0, 0) Then Exit Function
    If ManagedResult Then
        Value = TakeResult(S, B, Token, Catalog, Node)
        If Value = 0 Then Exit Function
    End If
    If Not NativeEmission.GuardCall(S, B, Token, Catalog, Seen, Nexts, Pair) Then Exit Function
    If Not NativeEmission.Safepoint(S, B, Token, Catalog) Then Exit Function
    If Not ManagedResult Then
        Value = NativeEmission.NewValue(S)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.CallValue, Value, Pair, 0, 0) Then Exit Function
    End If
    CallSupport = Value
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = Node
End Function

' Creates a value through the same ordinary UTF-8 constructor used by source code.
Public Function Literal(ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long) As Long
    Dim Address As Long
    Dim Offset As Long
    Dim Count As Long
    Dim Value As Long
    On Error GoTo Failed
    If E(Node - 1).ConstantTextLength = 0 Then
        Value = NativeEmission.Literal(S, B, Token, Catalog, 0)
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.TextRootStore, Node, Value, 0, 0) Then Exit Function
        Literal = Value
        Exit Function
    End If
    Address = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.TextLiteralAddress, Address, Node, 0, 0) Then Exit Function
    Offset = NativeEmission.Literal(S, B, Token, Catalog, 0)
    Count = NativeEmission.Literal(S, B, Token, Catalog, E(Node - 1).ConstantTextLength)
    Literal = CallSupport(A, S, B, Token, Catalog, Seen, Nexts, S.ManagedRoles.FromUtf8Symbol, Node, 3, Address, Offset, Count, True, True)
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = Node
End Function

' Literal bytes are nonmanaged read-only inputs, never unrooted managed identities.
' Their descriptors use the existing Byte array ABI consumed by Text.FromUtf8.
Public Function TryEmitLiterals(ByRef E() As ExpressionBinder.BoundExpression, ByVal NodeCount As Long, ByRef Arena() As Byte, ByVal Used As Long, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Node As Long = 1
    Dim Start As Long
    Dim Count As Long
    Dim Position As Long
    Dim Template As Long
    On Error GoTo Failed
    If S.Text.Failed Then Exit Function
    If Used < 0 Or Used > BufferPrimitives.ByteStorageLength(Arena) Then TryEmitLiterals = InvalidFacts(S, 0): Exit Function
    Do While Node <= NodeCount
        If Not NativeEmission.Charge(S) Then Exit Function
        If E(Node - 1).TypeCode = SyntaxTokens.KwString And E(Node - 1).ConstantKnown Then
            Start = E(Node - 1).ConstantTextStart
            Count = E(Node - 1).ConstantTextLength
            If Start < 0 Or Count < 0 Or Start > Used Then TryEmitLiterals = InvalidFacts(S, Node): Exit Function
            If Count > Used - Start Then TryEmitLiterals = InvalidFacts(S, Node): Exit Function
            If Count > 0 Then
                If Not LLVMFormat.TryFormat(S.Text, B, Token, Catalog, LLVMTemplates.TextLiteralStart, Node, Count, 0, 0) Then Exit Function
                Position = 0
                Do While Position < Count
                    If Not NativeEmission.Charge(S) Then Exit Function
                    Template = LLVMTemplates.TextLiteralByte
                    If Position = Count - 1 Then Template = LLVMTemplates.TextLiteralLastByte
                    If Not LLVMFormat.TryFormat(S.Text, B, Token, Catalog, Template, Arena(Start + Position), 0, 0, 0) Then Exit Function
                    Position = Position + 1
                Loop
                If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.TextLiteralEnd, Node, Count - 1, 0, 0) Then Exit Function
            End If
        End If
        Node = Node + 1
    Loop
    TryEmitLiterals = True
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = Node
End Function
