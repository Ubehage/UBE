UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeStorage"

' Private ByRef provenance: a canonical global source, an incoming owner SSA
' operand, or -1 for storage with no module owner. Publish only a complete scalar.
' The declaration planner reserves ValueIdentity+1 for ordinary ByRef formals.
Function TryReadNativeStorageOwner(ByRef Target As NativeDeclarationTarget, ByVal SourceCount As Long, ByRef Result As NativeOperand) As Boolean
    TryReadNativeStorageOwner = False
    If SourceCount < 1 Or Target.SourceId < 0 Or Target.SourceId >= SourceCount Then
        Exit Function
    End If
    If Target.Kind <> 2 And Target.Kind <> 4 And Target.Kind <> 6 Then
        Exit Function
    End If
    Dim Owner As NativeOperand
    Owner.Kind = 1
    Owner.TypeId = 4
    Owner.Representation = 4
    Owner.Value = -1
    If Target.Kind = 2 And Target.Scope < SourceCount Then
        If Target.Scope < 0 Then
            Exit Function
        End If
        Owner.Value = Target.SourceId
    End If
    If Target.Kind = 4 And (Target.Flags And 4) = 0 Then
        If Target.ValueIdentity < 0 Or Target.ValueIdentity = SemanticLongLongMaximum() Then
            Exit Function
        End If
        Owner.Kind = 2
        Owner.Value = Target.ValueIdentity + 1
    End If
    Result = Owner
    TryReadNativeStorageOwner = True
End Function

' Generated storage uses the selected scalar or one-component aggregate ABI.
' Identity ownership belongs to the declaration/frame plan; referencing or
' defining an already planned address never charges that identity twice.
' Loads alone create a new SSA identity. No host allocation or target lifetime
' operation is hidden here. The procedure owner emits local slots once at entry.
Function TryLLVMAddress(ByRef Writer As NativeLLVMWriter, ByVal Identity As LongLong, ByVal GlobalStorage As Boolean) As Boolean
    TryLLVMAddress = False
    Call ResetNativeFailure(Writer.Failure)
    If Identity < 0 Then
        Exit Function
    End If
    Dim Accepted As Boolean = False
    If GlobalStorage Then
        Accepted = TryLLVMText(Writer, "@ube.g")
    Else
        Accepted = TryLLVMText(Writer, "%v")
    End If
    If Accepted = False Then
        Exit Function
    End If
    TryLLVMAddress = TryLLVMNumber(Writer, Identity)
End Function

Private Function TryLLVMStorageAlignment(ByRef Writer As NativeLLVMWriter, ByVal Representation As Long) As Boolean
    TryLLVMStorageAlignment = False
    Call ResetNativeFailure(Writer.Failure)
    Dim Alignment As Long = 1
    If Representation < 1 Or Representation > 5 Then
        Exit Function
    End If
    If Representation = 3 Then
        Alignment = 2
    End If
    If Representation = 4 Then
        Alignment = 4
    End If
    If Representation = 5 Then
        Alignment = 8
    End If
    If TryLLVMText(Writer, ", align ") = False Then
        Exit Function
    End If
    If TryLLVMNumber(Writer, Alignment) = False Then
        Exit Function
    End If
    TryLLVMStorageAlignment = TryLLVMLine(Writer, "")
End Function

Private Function ValidNativeStorage(ByRef Target As NativeDeclarationTarget, ByVal SourceCount As Long) As Boolean
    ValidNativeStorage = False
    If SourceCount < 1 Or Target.Scope < 0 Or Target.AddressIdentity < 0 Or Target.TypeId < 1 Then
        Exit Function
    End If
    If Target.Kind <> 2 And Target.Kind <> 4 And Target.Kind <> 6 Then
        Exit Function
    End If
    If Target.TypeId <= 5 Then
        If Target.Representation <> Target.TypeId Then
            Exit Function
        End If
    Else
        If Target.Representation < 2 Or Target.Representation > 4 Then
            Exit Function
        End If
    End If
    ValidNativeStorage = True
End Function

Function TryEmitNativeStore(ByRef Writer As NativeLLVMWriter, ByRef Target As NativeDeclarationTarget, ByVal SourceCount As Long, ByRef Value As NativeOperand) As Boolean
    TryEmitNativeStore = False
    Call ResetNativeFailure(Writer.Failure)
    If ValidNativeStorage(Target, SourceCount) = False Or Target.TypeId <> Value.TypeId Or Target.Representation <> Value.Representation Then
        Exit Function
    End If
    If TryLLVMText(Writer, "  store ") = False Then
        Exit Function
    End If
    If TryLLVMTypedOperand(Writer, Value) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", ptr ") = False Then
        Exit Function
    End If
    If TryLLVMAddress(Writer, Target.AddressIdentity, Target.Kind = 2 And Target.Scope < SourceCount) = False Then
        Exit Function
    End If
    TryEmitNativeStore = TryLLVMStorageAlignment(Writer, Target.Representation)
End Function

Function TryEmitNativeLoad(ByRef Writer As NativeLLVMWriter, ByRef Target As NativeDeclarationTarget, ByVal SourceCount As Long, ByRef Result As NativeOperand) As Boolean
    TryEmitNativeLoad = False
    Call ResetNativeFailure(Writer.Failure)
    If ValidNativeStorage(Target, SourceCount) = False Then
        Exit Function
    End If
    Dim Prepared As NativeOperand
    If TryLLVMInstruction(Writer, Target.TypeId, Target.Representation, Prepared) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, "load ") = False Then
        Exit Function
    End If
    If TryLLVMType(Writer, Target.Representation, Target.TypeId >= 6) = False Then
        Exit Function
    End If
    If TryLLVMText(Writer, ", ptr ") = False Then
        Exit Function
    End If
    If TryLLVMAddress(Writer, Target.AddressIdentity, Target.Kind = 2 And Target.Scope < SourceCount) = False Then
        Exit Function
    End If
    If TryLLVMStorageAlignment(Writer, Target.Representation) = False Then
        Exit Function
    End If
    Result = Prepared
    TryEmitNativeLoad = True
End Function

' Define a global neutral slot or an entry-block local slot. A ByVal parameter
' starts with its incoming value; a ByRef parameter already is caller storage
' and receives no alloca, neutral store or copy. Function results start neutral.
Function TryEmitNativeStorage(ByRef Writer As NativeLLVMWriter, ByRef Target As NativeDeclarationTarget, ByVal SourceCount As Long) As Boolean
    TryEmitNativeStorage = False
    Call ResetNativeFailure(Writer.Failure)
    If ValidNativeStorage(Target, SourceCount) = False Then
        Exit Function
    End If
    If Target.Kind = 4 And (Target.Flags And 4) = 0 Then
        If Target.ValueIdentity <> Target.AddressIdentity Then
            Exit Function
        End If
        TryEmitNativeStorage = True
        Exit Function
    End If
    Dim GlobalStorage As Boolean = Target.Kind = 2 And Target.Scope < SourceCount
    If GlobalStorage = False Then
        If TryLLVMText(Writer, "  ") = False Then
            Exit Function
        End If
    End If
    If TryLLVMAddress(Writer, Target.AddressIdentity, GlobalStorage) = False Then
        Exit Function
    End If
    Dim Accepted As Boolean = False
    If GlobalStorage Then
        Accepted = TryLLVMText(Writer, " = global ")
    Else
        Accepted = TryLLVMText(Writer, " = alloca ")
    End If
    If Accepted = False Then
        Exit Function
    End If
    If TryLLVMType(Writer, Target.Representation, Target.TypeId >= 6) = False Then
        Exit Function
    End If
    If GlobalStorage Then
        If TryLLVMText(Writer, " zeroinitializer") = False Then
            Exit Function
        End If
    End If
    If TryLLVMStorageAlignment(Writer, Target.Representation) = False Then
        Exit Function
    End If
    If GlobalStorage = False Then
        Dim Initial As NativeOperand
        Initial.Kind = 1
        Initial.TypeId = Target.TypeId
        Initial.Representation = Target.Representation
        If Target.Kind = 4 Then
            Initial.Kind = 2
            Initial.Value = Target.ValueIdentity
        End If
        If TryEmitNativeStore(Writer, Target, SourceCount, Initial) = False Then
            Exit Function
        End If
    End If
    TryEmitNativeStorage = True
End Function
