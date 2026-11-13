UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeValues"
' Emits checked scalar operations over validated, canonically extended i64 SSA operands.

' Rejects an invalid internal operand/type request without publishing usable LLVM output.
Private Sub InvalidRequest(ByRef State As NativeEmission.EmissionState)
    State.Text.Failed = True
    State.FailureCode = 9
    State.FailureReason = 61
    State.ErrorNode = State.CurrentNode
End Sub

' Guards division before executing LLVM instructions with undefined invalid operands.
Public Function CheckedDivision(ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Continuations() As Long, ByVal LeftValue As Long, ByVal RightValue As Long, ByVal TypeCode As Long, ByVal Remainder As Boolean) As Long
    Dim Zero As Long
    Dim Low As Long
    Dim NegativeOne As Long
    Dim Test As Long
    Dim AtMinimum As Long
    Dim AtNegativeOne As Long
    Dim Exceptional As Long
    Dim Divisor As Long
    Dim Result As Long
    Dim Template As Long
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    If LeftValue < 1 Or RightValue < 1 Or ConstantValues.IntegerWidth(TypeCode) < 16 Then InvalidRequest State: Exit Function
    Zero = NativeEmission.Literal(State, Buffer, Token, Catalog, 0)
    Test = NativeEmission.NewValue(State)
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.CompareEqual, Test, RightValue, Zero, 0) Then Exit Function
    If Not NativeEmission.GuardError(State, Buffer, Token, Catalog, Seen, Continuations, Test, 11) Then Exit Function
    Low = NativeEmission.Literal(State, Buffer, Token, Catalog, ConstantValues.Minimum(TypeCode))
    NegativeOne = NativeEmission.Literal(State, Buffer, Token, Catalog, -1)
    AtMinimum = NativeEmission.NewValue(State)
    AtNegativeOne = NativeEmission.NewValue(State)
    Exceptional = NativeEmission.NewValue(State)
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.CompareEqual, AtMinimum, LeftValue, Low, 0) Then Exit Function
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.CompareEqual, AtNegativeOne, RightValue, NegativeOne, 0) Then Exit Function
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.BothConditions, Exceptional, AtMinimum, AtNegativeOne, 0) Then Exit Function
    Divisor = RightValue
    Template = LLVMTemplates.DivisionValue
    If Remainder Then
        Divisor = NativeEmission.NewValue(State)
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.SafeRemainderDivisor, Divisor, Exceptional, RightValue, 0) Then Exit Function
        Template = LLVMTemplates.RemainderValue
    Else
        If Not NativeEmission.GuardError(State, Buffer, Token, Catalog, Seen, Continuations, Exceptional, 6) Then Exit Function
    End If
    Result = NativeEmission.NewValue(State)
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, Template, Result, LeftValue, Divisor, 0) Then Exit Function
    CheckedDivision = Result
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function

' Tests whole-domain conversion safety; Boolean True is -1 and cannot become Byte.
Private Function ConversionMayFail(ByVal SourceType As Long, ByVal DestinationType As Long) As Boolean
    On Error GoTo Failed
    If SourceType = DestinationType Or DestinationType = SyntaxTokens.KwBoolean Then Exit Function
    If SourceType = SyntaxTokens.KwBoolean Then
        ConversionMayFail = DestinationType = SyntaxTokens.KwByte
    Else
        ConversionMayFail = ConstantValues.IntegerWidth(SourceType) > ConstantValues.IntegerWidth(DestinationType)
    End If
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Converts a canonical cell, guarding only conversions whose complete source domain can overflow.
Public Function ConvertValue(ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Continuations() As Long, ByVal Value As Long, ByVal SourceType As Long, ByVal DestinationType As Long) As Long
    Dim Test As Long
    Dim Result As Long
    Dim Narrow As Long
    Dim BitWidth As Long
    Dim Template As Long
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    If Value < 1 Then InvalidRequest State: Exit Function
    If SourceType <> SyntaxTokens.KwBoolean And ConstantValues.IntegerWidth(SourceType) = 0 Then InvalidRequest State: Exit Function
    If DestinationType = 0 Or SourceType = DestinationType Then ConvertValue = Value: Exit Function
    BitWidth = ConstantValues.IntegerWidth(DestinationType)
    If DestinationType <> SyntaxTokens.KwBoolean And BitWidth = 0 Then InvalidRequest State: Exit Function
    If DestinationType = SyntaxTokens.KwBoolean Then
        Test = NativeEmission.NewValue(State)
        Result = NativeEmission.NewValue(State)
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.ValueNonzero, Test, Value, 0, 0) Then Exit Function
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.BooleanSelect, Result, Test, 0, 0) Then Exit Function
    ElseIf ConversionMayFail(SourceType, DestinationType) Then
        Narrow = NativeEmission.NewValue(State)
        Result = NativeEmission.NewValue(State)
        Test = NativeEmission.NewValue(State)
        Template = LLVMTemplates.SignExtendValue
        If DestinationType = SyntaxTokens.KwByte Then Template = LLVMTemplates.ZeroExtendValue
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.TruncateValue, Narrow, Value, BitWidth, 0) Then Exit Function
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, Template, Result, Narrow, BitWidth, 0) Then Exit Function
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.DifferentValues, Test, Value, Result, 0) Then Exit Function
        If Not NativeEmission.GuardError(State, Buffer, Token, Catalog, Seen, Continuations, Test, 6) Then Exit Function
    Else
        Result = Value
    End If
    ConvertValue = Result
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function

' Performs signed arithmetic at the already-bound promoted width, checking fresh overflow before extraction.
Public Function CheckedArithmetic(ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Continuations() As Long, ByVal LeftValue As Long, ByVal RightValue As Long, ByVal TypeCode As Long, ByVal Subtract As Boolean) As Long
    Dim Operator As Long
    Operator = SyntaxTokens.SymPlus
    If Subtract Then Operator = SyntaxTokens.SymMinus
    CheckedArithmetic = EmitArithmetic(State, Buffer, Token, Catalog, Seen, Continuations, LeftValue, RightValue, TypeCode, Operator)
End Function

' Uses the same promoted-width overflow path for multiplication.
Public Function CheckedProduct(ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Continuations() As Long, ByVal LeftValue As Long, ByVal RightValue As Long, ByVal TypeCode As Long) As Long
    CheckedProduct = EmitArithmetic(State, Buffer, Token, Catalog, Seen, Continuations, LeftValue, RightValue, TypeCode, SyntaxTokens.SymStar)
End Function

' Shares operand narrowing, overflow guarding and canonical result extension.
Private Function EmitArithmetic(ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Continuations() As Long, ByVal LeftValue As Long, ByVal RightValue As Long, ByVal TypeCode As Long, ByVal Operator As Long) As Long
    Dim BitWidth As Long
    Dim Template As Long
    Dim LeftOperand As Long
    Dim RightOperand As Long
    Dim Pair As Long
    Dim Overflow As Long
    Dim Narrow As Long
    Dim Result As Long
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    BitWidth = ConstantValues.IntegerWidth(TypeCode)
    If LeftValue < 1 Or RightValue < 1 Or BitWidth < 16 Then InvalidRequest State: Exit Function
    If BitWidth = 16 Then Template = LLVMTemplates.ArithmeticAdd16: If Operator = SyntaxTokens.SymMinus Then Template = LLVMTemplates.ArithmeticSubtract16
    If BitWidth = 32 Then Template = LLVMTemplates.ArithmeticAdd32: If Operator = SyntaxTokens.SymMinus Then Template = LLVMTemplates.ArithmeticSubtract32
    If BitWidth = 64 Then Template = LLVMTemplates.ArithmeticAdd64: If Operator = SyntaxTokens.SymMinus Then Template = LLVMTemplates.ArithmeticSubtract64
    If Operator = SyntaxTokens.SymStar Then
        If BitWidth = 16 Then Template = LLVMTemplates.ArithmeticMultiply16
        If BitWidth = 32 Then Template = LLVMTemplates.ArithmeticMultiply32
        If BitWidth = 64 Then Template = LLVMTemplates.ArithmeticMultiply64
    End If
    LeftOperand = LeftValue
    RightOperand = RightValue
    If BitWidth <> 64 Then
        LeftOperand = NativeEmission.NewValue(State)
        RightOperand = NativeEmission.NewValue(State)
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.TruncateValue, LeftOperand, LeftValue, BitWidth, 0) Then Exit Function
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.TruncateValue, RightOperand, RightValue, BitWidth, 0) Then Exit Function
    End If
    Pair = NativeEmission.NewValue(State)
    Overflow = NativeEmission.NewValue(State)
    Narrow = NativeEmission.NewValue(State)
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, Template, Pair, LeftOperand, RightOperand, 0) Then Exit Function
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.OverflowFlag, Overflow, Pair, BitWidth, 0) Then Exit Function
    If Not NativeEmission.GuardError(State, Buffer, Token, Catalog, Seen, Continuations, Overflow, 6) Then Exit Function
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.ArithmeticValue, Narrow, Pair, BitWidth, 0) Then Exit Function
    Result = Narrow
    If BitWidth <> 64 Then
        Result = NativeEmission.NewValue(State)
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.SignExtendValue, Result, Narrow, BitWidth, 0) Then Exit Function
    End If
    EmitArithmetic = Result
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function

' Complements the bound logical/integer domain and restores its canonical i64 extension.
Public Function Complement(ByRef State As NativeEmission.EmissionState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByRef Seen() As Long, ByRef Continuations() As Long, ByVal Value As Long, ByVal TypeCode As Long) As Long
    Dim BitWidth As Long
    Dim Operand As Long
    Dim Inverted As Long
    Dim Result As Long
    Dim Template As Long
    On Error GoTo Failed
    If State.Text.Failed Then Exit Function
    BitWidth = ConstantValues.IntegerWidth(TypeCode)
    If TypeCode = SyntaxTokens.KwBoolean Then BitWidth = 64
    If Value < 1 Or BitWidth = 0 Then InvalidRequest State: Exit Function
    Operand = Value
    If BitWidth <> 64 Then
        Operand = NativeEmission.NewValue(State)
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.TruncateValue, Operand, Value, BitWidth, 0) Then Exit Function
    End If
    Inverted = NativeEmission.NewValue(State)
    If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, LLVMTemplates.ComplementValue, Inverted, Operand, BitWidth, 0) Then Exit Function
    Result = Inverted
    If BitWidth <> 64 Then
        Result = NativeEmission.NewValue(State)
        Template = LLVMTemplates.SignExtendValue
        If TypeCode = SyntaxTokens.KwByte Then Template = LLVMTemplates.ZeroExtendValue
        If Not NativeEmission.TryLine(State, Buffer, Token, Catalog, Template, Result, Inverted, BitWidth, 0) Then Exit Function
    End If
    Complement = Result
    Exit Function
Failed:
    State.Text.Failed = True
    State.Text.Failure = 1
    State.Text.ErrorNumber = Err.Number
    State.ErrorNode = State.CurrentNode
End Function
