UBE SOURCE 1 MODULE
Attribute UBE_Name = "TargetAbi"

' RP5 freezes one native target without allowing its details to leak into IR.
Type TargetAbiDescription
    Triple As String
    DataLayout As String
    CallingConvention As String
    ObjectFormat As String
    PointerBits As Long
    PointerBytes As Long
    StackAlignmentBits As Long
End Type

Type AbiTypeClassification
    Supported As Long
    ClassKind As Long
    LlvmType As String
    SizeBytes As LongLong
    AlignmentBytes As Long
    PassKind As Long
    ReturnKind As Long
    IsManagedReference As Long
End Type

Function AbiClassVoid() As Long
    AbiClassVoid = 1
End Function

Function AbiClassInteger() As Long
    AbiClassInteger = 2
End Function

Function AbiClassFloating() As Long
    AbiClassFloating = 3
End Function

Function AbiClassPointer() As Long
    AbiClassPointer = 4
End Function

Function AbiClassAggregate() As Long
    AbiClassAggregate = 5
End Function

Function AbiPassDirect() As Long
    AbiPassDirect = 1
End Function

Function AbiPassIndirect() As Long
    AbiPassIndirect = 2
End Function

Function AbiReturnDirect() As Long
    AbiReturnDirect = 1
End Function

Function AbiReturnIndirect() As Long
    AbiReturnIndirect = 2
End Function

Function ResolveTargetAbi(ByRef Target As TargetDescription, ByRef Abi As TargetAbiDescription) As Long
    Abi.Triple = ""
    Abi.DataLayout = ""
    Abi.CallingConvention = ""
    Abi.ObjectFormat = ""
    Abi.PointerBits = 0
    Abi.PointerBytes = 0
    Abi.StackAlignmentBits = 0
    If EqualsFolded(Target.Triple, "x86_64-w64-windows-gnu") <> 0 Then
        If Target.PointerBits <> 64 Or EqualsFolded(Target.ObjectFormat, "COFF") = 0 Then
            ResolveTargetAbi = 0
            Exit Function
        End If
        Abi.Triple = "x86_64-w64-windows-gnu"
        Abi.DataLayout = "e-m:w-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
        Abi.CallingConvention = "win64-gnu-c"
        Abi.ObjectFormat = "COFF"
        Abi.PointerBits = 64
        Abi.PointerBytes = 8
        Abi.StackAlignmentBits = 128
        ResolveTargetAbi = 1
        Exit Function
    End If
    If EqualsFolded(Target.Triple, "x86_64-unknown-linux-gnu") <> 0 Then
        If Target.PointerBits <> 64 Or EqualsFolded(Target.ObjectFormat, "ELF") = 0 Then
            ResolveTargetAbi = 0
            Exit Function
        End If
        Abi.Triple = "x86_64-unknown-linux-gnu"
        Abi.DataLayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
        Abi.CallingConvention = "sysv-amd64-c"
        Abi.ObjectFormat = "ELF"
        Abi.PointerBits = 64
        Abi.PointerBytes = 8
        Abi.StackAlignmentBits = 128
        ResolveTargetAbi = 1
        Exit Function
    End If
    ResolveTargetAbi = 0
End Function

Sub ClearAbiTypeClassification(ByRef Result As AbiTypeClassification)
    Result.Supported = 0
    Result.ClassKind = 0
    Result.LlvmType = ""
    Result.SizeBytes = 0
    Result.AlignmentBytes = 0
    Result.PassKind = 0
    Result.ReturnKind = 0
    Result.IsManagedReference = 0
End Sub

Sub SetDirectAbiType(ByRef Result As AbiTypeClassification, ByVal ClassKind As Long, ByVal LlvmType As String, ByVal SizeBytes As LongLong, ByVal AlignmentBytes As Long)
    Result.Supported = 1
    Result.ClassKind = ClassKind
    Result.LlvmType = LlvmType
    Result.SizeBytes = SizeBytes
    Result.AlignmentBytes = AlignmentBytes
    Result.PassKind = AbiPassDirect()
    Result.ReturnKind = AbiReturnDirect()
    Result.IsManagedReference = 0
End Sub

Sub SetPointerAbiType(ByRef Result As AbiTypeClassification, ByVal IsManagedReference As Long)
    Call SetDirectAbiType(Result, AbiClassPointer(), "ptr", 8, 8)
    Result.IsManagedReference = IsManagedReference
End Sub

Function ClassifyTargetAbiType(ByVal TypeIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Abi As TargetAbiDescription, ByRef Result As AbiTypeClassification) As Long
    Call ClearAbiTypeClassification(Result)
    If Abi.PointerBits <> 64 Or TypeIndex < 0 Or TypeIndex >= TypeCount Then
        ClassifyTargetAbiType = 0
        Exit Function
    End If
    Dim AbiTypeName As String = Types(TypeIndex).TypeName
    If EqualsFolded(AbiTypeName, "Boolean") <> 0 Then
        Call SetDirectAbiType(Result, AbiClassInteger(), "i1", 1, 1)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If EqualsFolded(AbiTypeName, "Byte") <> 0 Then
        Call SetDirectAbiType(Result, AbiClassInteger(), "i8", 1, 1)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If EqualsFolded(AbiTypeName, "Integer") <> 0 Then
        Call SetDirectAbiType(Result, AbiClassInteger(), "i16", 2, 2)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If EqualsFolded(AbiTypeName, "Long") <> 0 Then
        Call SetDirectAbiType(Result, AbiClassInteger(), "i32", 4, 4)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If EqualsFolded(AbiTypeName, "LongLong") <> 0 Or EqualsFolded(AbiTypeName, "Currency") <> 0 Then
        Call SetDirectAbiType(Result, AbiClassInteger(), "i64", 8, 8)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If EqualsFolded(AbiTypeName, "Single") <> 0 Then
        Call SetDirectAbiType(Result, AbiClassFloating(), "float", 4, 4)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If EqualsFolded(AbiTypeName, "Double") <> 0 Or EqualsFolded(AbiTypeName, "Date") <> 0 Then
        Call SetDirectAbiType(Result, AbiClassFloating(), "double", 8, 8)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If EqualsFolded(AbiTypeName, "IntPtr") <> 0 Or EqualsFolded(AbiTypeName, "UIntPtr") <> 0 Then
        Call SetDirectAbiType(Result, AbiClassInteger(), "i64", 8, 8)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If EqualsFolded(AbiTypeName, "String") <> 0 Or Types(TypeIndex).TypeKind = 40 Or Types(TypeIndex).TypeKind = 41 Then
        Call SetPointerAbiType(Result, 1)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If Types(TypeIndex).TypeKind = 27 Then
        Call SetDirectAbiType(Result, AbiClassInteger(), "i32", 4, 4)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If Types(TypeIndex).TypeKind = 30 Or (Types(TypeIndex).TypeKind >= 50 And Types(TypeIndex).TypeKind <= 52) Or EqualsFolded(AbiTypeName, "Object") <> 0 Or EqualsFolded(AbiTypeName, "Variant") <> 0 Or EqualsFolded(AbiTypeName, "Nothing") <> 0 Or EqualsFolded(AbiTypeName, "Empty") <> 0 Or EqualsFolded(AbiTypeName, "Null") <> 0 Then
        Call SetPointerAbiType(Result, 1)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If EqualsFolded(AbiTypeName, "Any") <> 0 Then
        Call SetPointerAbiType(Result, 0)
        ClassifyTargetAbiType = 1
        Exit Function
    End If
    If Types(TypeIndex).TypeSymbol >= 0 Then
        Result.Supported = 1
        Result.ClassKind = AbiClassAggregate()
        Result.LlvmType = "%ube.type." & LongToString(Types(TypeIndex).StableId)
        Result.SizeBytes = 0
        Result.AlignmentBytes = 0
        Result.PassKind = AbiPassIndirect()
        Result.ReturnKind = AbiReturnIndirect()
        Result.IsManagedReference = 0
    End If
    ClassifyTargetAbiType = Result.Supported
End Function

' Internal symbols depend only on deterministic semantic identities. Source
' paths and user spelling are deliberately absent, so relocation cannot alter
' generated LLVM. The caller adds LLVM's @ or % sigil for its context.
Function MangleInternalSymbol(ByVal PackageStableId As Long, ByVal SourceStableId As Long, ByVal SymbolStableId As Long) As String
    If PackageStableId <= 0 Or SourceStableId <= 0 Or SymbolStableId <= 0 Then
        MangleInternalSymbol = ""
        Exit Function
    End If
    MangleInternalSymbol = "ube_i_p" & LongToString(PackageStableId) & "_s" & LongToString(SourceStableId) & "_y" & LongToString(SymbolStableId)
End Function

Function InternalLinkageName() As String
    InternalLinkageName = "internal"
End Function

Function ExportLinkageName() As String
    ExportLinkageName = "dllexport"
End Function
