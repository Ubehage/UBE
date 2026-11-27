UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeObjects"
' Emits nominal class identities and managed reference operations without value-record copying.

' Distinct descriptors retain the declaration identity even for classes with no fields.
Public Function TryDeclarations(ByRef A() As DeclarationBinder.BoundSymbol, ByVal SymbolCount As Long, ByRef State As LLVMWriter.WriterState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Boolean
    Dim Index As Long
    On Error GoTo Failed
    If State.Failed Then Exit Function
    Do While Index < SymbolCount
        If A(Index).Kind = SourceParser.ClassNode Then
            If Not LLVMFormat.TryFormat(State, B, Token, Catalog, LLVMTemplates.ObjectDescriptor, Index + 1, 0, 0, 0) Then Exit Function
            If Not LLVMWriter.TryEndLine(State, B, Token) Then Exit Function
        End If
        Index = Index + 1
    Loop
    TryDeclarations = True
    Exit Function
Failed:
    State.Failed = True
    State.Failure = 1
    State.ErrorNumber = Err.Number
End Function

' The result slot is already an exact expression root before allocation can collect.
Public Function Create(ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long) As Long
    Dim Symbol As Long
    Dim Status As Long
    Dim Value As Long
    On Error GoTo Failed
    Symbol = E(Node - 1).TypeSymbol
    If Symbol < 1 Then GoTo Invalid
    If A(Symbol - 1).Kind <> SourceParser.ClassNode Or E(Node - 1).TypeCode <> SyntaxTokens.KwObject Then GoTo Invalid
    Status = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ObjectCreate, Status, Symbol, Node, L(A(Symbol - 1).DeclarationNode - 1).InstanceCells * 8) Then Exit Function
    If Not NativeEmission.GuardStatus(S, B, Token, Catalog, Seen, Nexts, Status) Then Exit Function
    Value = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.LoadManagedExpression, Value, Node, 0, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ObjectPublish, Value, Value, 0, 0) Then Exit Function
    Create = Value
    Exit Function
Invalid:
    S.Text.Failed = True
    S.FailureCode = 9
    S.FailureReason = 62
    S.ErrorNode = Node
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = Node
End Function

' Reads the immutable hidden receiver retained by this invocation.
Public Function CurrentInstance(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte) As Long
    Dim Value As Long
    Value = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.InstanceValue, Value, 0, 0, 0) Then Exit Function
    CurrentInstance = Value
End Function

' Captures explicit receivers before later operands can replace their source storage.
Public Function CaptureReceiver(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByRef E() As ExpressionBinder.BoundExpression, ByRef L() As AggregateLayout.StorageFact, ByRef P() As NativePlanning.NativeSymbolPlan, ByRef Pins() As Long, ByRef Escapes() As NativeEscapes.EscapeFact, ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Node As Long, ByRef Terminated As Boolean) As Long
    Dim Receiver As Long
    Dim Value As Long
    On Error GoTo Failed
    Receiver = E(Node - 1).InstanceReceiver
    If Receiver = 0 Then
        Value = CurrentInstance(S, B, Token, Catalog)
    Else
        Value = NativeExpressions.EmitExpression(N, A, E, L, P, Pins, Escapes, S, B, Token, Catalog, Seen, Nexts, Receiver, Terminated)
        If Value = 0 Or Terminated Then Exit Function
        If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.TextRootStore, Node, Value, 0, 0) Then Exit Function
    End If
    CaptureReceiver = Value
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
    S.ErrorNode = Node
End Function

' Uses the runtime's checked nominal lookup while the caller retains the exact identity.
Public Function PayloadAddress(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Nexts() As Long, ByVal Identity As Long, ByVal ClassSymbol As Long) As Long
    Dim Address As Long
    Dim Accepted As Long
    On Error GoTo Failed
    Address = NativeEmission.NewValue(S)
    Accepted = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ObjectAddress, Address, Identity, ClassSymbol, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.ObjectAddressValid, Accepted, Address, 0, 0) Then Exit Function
    If Not NativeEmission.GuardStatus(S, B, Token, Catalog, Seen, Nexts, Accepted) Then Exit Function
    PayloadAddress = Address
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
End Function

' Only already-bound Is/IsNot operations reach this identity comparison.
Public Function CompareIdentity(ByRef S As NativeEmission.EmissionState, ByRef B() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal LeftValue As Long, ByVal RightValue As Long, ByVal Operator As Long) As Long
    Dim Template As Long
    Dim Test As Long
    Dim Value As Long
    On Error GoTo Failed
    If Operator = SyntaxTokens.KwIs Then Template = LLVMTemplates.CompareEqual
    If Operator = SyntaxTokens.KwIsnot Then Template = LLVMTemplates.DifferentValues
    If Template = 0 Or LeftValue < 1 Or RightValue < 1 Then GoTo Invalid
    Test = NativeEmission.NewValue(S)
    Value = NativeEmission.NewValue(S)
    If Not NativeEmission.TryLine(S, B, Token, Catalog, Template, Test, LeftValue, RightValue, 0) Then Exit Function
    If Not NativeEmission.TryLine(S, B, Token, Catalog, LLVMTemplates.BooleanSelect, Value, Test, 0, 0) Then Exit Function
    CompareIdentity = Value
    Exit Function
Invalid:
    S.Text.Failed = True
    S.FailureCode = 9
    S.FailureReason = 62
    Exit Function
Failed:
    S.Text.Failed = True
    S.Text.Failure = 1
    S.Text.ErrorNumber = Err.Number
End Function
