UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeRelocations"

' Named target association only; instruction bytes and anonymous contributions
' must be checked separately before a linked candidate can be accepted.
Function TryResolveNativeNamedRelocation(ByRef Relocation As NativeObjectRelocation, ByRef ObjectInventory As NativeSymbolInventory, ByRef ObjectBytes() As Byte, ByRef ObjectLayout As NativeObjectLayout, ByRef ImageInventory As NativeSymbolInventory, ByRef ImageBytes() As Byte, ByRef ImageLayout As NativeObjectLayout, ByRef Inspection As NativeInspection, ByRef Result As NativeDefinitionRange, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryResolveNativeNamedRelocation = False
    Call ResetNativeFailure(Failure)
    If ObjectLayout.Kind <> 1 Or ImageLayout.Kind <> 2 Or ObjectInventory.Status <> 1 Or ImageInventory.Status <> 1 Then
        Exit Function
    End If
    If ObjectLayout.Length <> ByteStorageLength(ObjectBytes) Or ObjectInventory.Length <> ObjectLayout.Length Or ObjectInventory.SymbolCapacity <> ObjectLayout.SymbolCount Or ImageLayout.Length <> ByteStorageLength(ImageBytes) Or ImageInventory.Length <> ImageLayout.Length Or ImageInventory.SymbolCapacity <> ImageLayout.SymbolCount Then
        Exit Function
    End If
    Failure.Code = 1506
    If Relocation.Kind < 1 Or Relocation.Kind > 11 Or Relocation.TargetIndex < 0 Or Relocation.TargetIndex >= ObjectLayout.SymbolCount Then
        Exit Function
    End If
    Dim Symbol As NativeObjectSymbol
    If TryReadNativeIndexedSymbol(ObjectInventory, Relocation.TargetIndex, Inspection, Symbol, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Symbol.Name.Count < 1 Or Symbol.AuxiliaryCount <> 0 Or Symbol.SectionNumber < 0 Then
        Exit Function
    End If
    If Symbol.StorageClass <> 2 And Symbol.StorageClass <> 3 Then
        Exit Function
    End If
    If Symbol.TypeCode <> 0 And Symbol.TypeCode <> 32 Then
        Exit Function
    End If
    Dim ObjectRange As NativeDefinitionRange
    If Symbol.SectionNumber = 0 Then
        ' Only ordinary external declarations, not COMMON, weak or debug rows.
        If Symbol.StorageClass <> 2 Or Symbol.Value <> 0 Then
            Exit Function
        End If
    Else
        If TryLocateNativeDefinition(ObjectInventory, ObjectBytes, ObjectLayout, ObjectBytes, Symbol.Name, 1, Inspection, ObjectRange, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If ObjectRange.SymbolIndex <> Relocation.TargetIndex Then
            Exit Function
        End If
    End If
    Dim Prepared As NativeDefinitionRange
    If TryLocateNativeDefinition(ImageInventory, ImageBytes, ImageLayout, ObjectBytes, Symbol.Name, 1, Inspection, Prepared, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Prepared.TypeCode <> 0 And Prepared.TypeCode <> 32 Then
        Exit Function
    End If
    If Symbol.SectionNumber > 0 Or Symbol.TypeCode = 32 Then
        If Prepared.TypeCode <> Symbol.TypeCode Then
            Exit Function
        End If
    End If
    If Prepared.TypeCode = 32 Then
        If Prepared.InitializedBytes <> 1 Or NativeReadableCodeCharacteristics(Prepared.Characteristics) = False Then
            Exit Function
        End If
        If Symbol.SectionNumber > 0 Then
            If ObjectRange.InitializedBytes <> 1 Or NativeReadableCodeCharacteristics(ObjectRange.Characteristics) = False Then
                Exit Function
            End If
        End If
    End If
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryResolveNativeNamedRelocation = True
End Function

Function ValidNativeRelocationTarget(ByRef Target As NativeDefinitionRange) As Boolean
    ValidNativeRelocationTarget = False
    Dim MaximumRVA As LongLong = 65536
    MaximumRVA = MaximumRVA * 65536 - 1
    If Target.SectionIndex < 0 Or Target.SectionIndex >= 96 Or Target.ByteCount < 1 Or Target.InitializedBytes < 0 Or Target.InitializedBytes > Target.ByteCount Then
        Exit Function
    End If
    If Target.SectionOffset < 0 Or Target.RelativeAddress < Target.SectionOffset Or Target.RelativeAddress > MaximumRVA Or Target.Address < Target.RelativeAddress Then
        Exit Function
    End If
    If Target.ByteCount > MaximumRVA - Target.RelativeAddress Or Target.ByteCount > SemanticLongLongMaximum() - Target.Address Then
        Exit Function
    End If
    ValidNativeRelocationTarget = True
End Function

' Compare one qualified relocation field; placement and target ownership belong
' to the caller. Arithmetic models field bits, not effective-address safety.
Function TryValidateNativeRelocationValue(ByRef Relocation As NativeObjectRelocation, ByRef Target As NativeDefinitionRange, ByVal SiteRVA As LongLong, ByRef ObjectBytes() As Byte, ByVal ObjectFirst As Long, ByRef ImageBytes() As Byte, ByVal ImageFirst As Long, ByRef Inspection As NativeInspection, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeRelocationValue = False
    Call ResetNativeFailure(Failure)
    Failure.Code = 1506
    If Relocation.Kind < 0 Or Relocation.Kind > 11 Then
        Exit Function
    End If
    Dim Width As Long = 0
    Dim RelativeEnd As Long = 0
    If Relocation.Kind > 0 Then
        Width = 4
        If Relocation.Kind = 1 Then
            Width = 8
        End If
        If Relocation.Kind = 10 Then
            Width = 2
        End If
        If Relocation.Kind >= 4 And Relocation.Kind <= 9 Then
            RelativeEnd = Relocation.Kind
        End If
    End If
    Call ResetNativeFailure(Failure)
    If Relocation.Width <> Width Or Relocation.RelativeEnd <> RelativeEnd Then
        Exit Function
    End If
    If Relocation.Kind = 0 Then
        If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
            Exit Function
        End If
        TryValidateNativeRelocationValue = True
        Exit Function
    End If
    Dim ObjectLength As Long = ByteStorageLength(ObjectBytes)
    Dim ImageLength As Long = ByteStorageLength(ImageBytes)
    If ObjectFirst < 0 Or ObjectFirst > ObjectLength Or ImageFirst < 0 Or ImageFirst > ImageLength Then
        Exit Function
    End If
    If Width > ObjectLength - ObjectFirst Or Width > ImageLength - ImageFirst Then
        Exit Function
    End If
    Dim MaximumRVA As LongLong = 65536
    MaximumRVA = MaximumRVA * 65536 - 1
    If ValidNativeRelocationTarget(Target) = False Then
        Exit Function
    End If
    If SiteRVA < 0 Or SiteRVA > MaximumRVA - Width Then
        Exit Function
    End If
    If RelativeEnd > 0 Then
        If SiteRVA > MaximumRVA - RelativeEnd Then
            Exit Function
        End If
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Adjustment As LongLong = Target.RelativeAddress
    If Relocation.Kind = 1 Or Relocation.Kind = 2 Then
        Adjustment = Target.Address
    End If
    If RelativeEnd > 0 Then
        Adjustment = Target.RelativeAddress - SiteRVA - RelativeEnd
    End If
    If Relocation.Kind = 10 Then
        Adjustment = Target.SectionIndex + 1
    End If
    If Relocation.Kind = 11 Then
        Adjustment = Target.SectionOffset
    End If
    Dim Index As Long = 0
    Dim Carry As Long = 0
    While Index < Width
        Dim Original As LongLong = 0
        Dim Linked As LongLong = 0
        If TryReadNativeBits(ObjectBytes, Inspection, ObjectFirst + Index, 1, Original, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(ImageBytes, Inspection, ImageFirst + Index, 1, Linked, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim LowByte As Long = Adjustment Mod 256
        If LowByte < 0 Then
            LowByte = LowByte + 256
        End If
        Adjustment = (Adjustment - LowByte) \ 256
        Dim Sum As Long = Original + LowByte + Carry
        Failure.Code = 1506
        If Linked <> Sum Mod 256 Then
            Exit Function
        End If
        Carry = Sum \ 256
        Index = Index + 1
    Wend
    Failure.Code = 0
    Failure.Resource = 0
    TryValidateNativeRelocationValue = True
End Function

' Relate qualified COFF fields to qualified instruction operands. Target identity,
' linked range/no-wrap, TLS base and control-flow ownership remain caller proofs.
Function TryReadNativeInstructionRelocationOffset(ByRef Instruction As NativeInstruction, ByVal InstructionOffset As LongLong, ByRef Relocation As NativeObjectRelocation, ByRef Inspection As NativeInspection, ByRef Result As LongLong, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeInstructionRelocationOffset = False
    Call ResetNativeFailure(Failure)
    Dim MaximumOffset As LongLong = 65536
    MaximumOffset = MaximumOffset * 65536 - 1
    If Instruction.ByteCount < 1 Or Instruction.ByteCount > 15 Or Instruction.Flow < 0 Or Instruction.Flow > 7 Then
        Exit Function
    End If
    If InstructionOffset < 0 Or InstructionOffset > MaximumOffset - Instruction.ByteCount Then
        Exit Function
    End If
    If Relocation.Offset < 0 Or Relocation.Offset > MaximumOffset - 4 Or Relocation.TargetIndex < 0 Or Relocation.TargetIndex > MaximumOffset Then
        Exit Function
    End If
    If Instruction.DisplacementBytes <> 0 And Instruction.DisplacementBytes <> 1 And Instruction.DisplacementBytes <> 4 Then
        Exit Function
    End If
    If Instruction.ImmediateBytes <> 0 And Instruction.ImmediateBytes <> 1 And Instruction.ImmediateBytes <> 2 And Instruction.ImmediateBytes <> 4 And Instruction.ImmediateBytes <> 8 Then
        Exit Function
    End If
    If Instruction.DisplacementBytes = 0 Then
        If Instruction.DisplacementFirst <> 0 Then
            Exit Function
        End If
    Else
        If Instruction.DisplacementFirst < 1 Or Instruction.DisplacementFirst > Instruction.ByteCount - Instruction.DisplacementBytes Then
            Exit Function
        End If
    End If
    If Instruction.ImmediateBytes = 0 Then
        If Instruction.ImmediateFirst <> 0 Then
            Exit Function
        End If
    Else
        If Instruction.ImmediateFirst < 1 Or Instruction.ImmediateFirst <> Instruction.ByteCount - Instruction.ImmediateBytes Then
            Exit Function
        End If
        If Instruction.DisplacementBytes > 0 Then
            If Instruction.DisplacementFirst + Instruction.DisplacementBytes <> Instruction.ImmediateFirst Then
                Exit Function
            End If
        End If
    End If
    If Instruction.ImmediateBytes = 0 And Instruction.DisplacementBytes > 0 Then
        If Instruction.DisplacementFirst + Instruction.DisplacementBytes <> Instruction.ByteCount Then
            Exit Function
        End If
    End If
    If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Relocation.Width <> 4 Then
        Exit Function
    End If
    Dim Relative As Boolean = Relocation.Kind >= 4 And Relocation.Kind <= 9
    If Relative Then
        If Relocation.RelativeEnd <> Relocation.Kind Then
            Exit Function
        End If
    Else
        If Relocation.Kind <> 11 Or Relocation.RelativeEnd <> 0 Then
            Exit Function
        End If
    End If
    Dim Field As Long = Instruction.DisplacementFirst
    Dim Prepared As LongLong = Instruction.MemoryDisplacement
    If Instruction.Flow >= 2 And Instruction.Flow <= 4 Then
        If Relative = False Or Instruction.ImmediateBytes <> 4 Or Instruction.DisplacementBytes <> 0 Or Instruction.MemoryBase <> -1 Or Instruction.MemoryIndex <> -1 Or Instruction.Segment <> 0 Then
            Exit Function
        End If
        Field = Instruction.ImmediateFirst
        Prepared = Instruction.RelativeOffset
    Else
        If Instruction.DisplacementBytes <> 4 Or Instruction.MemoryIndex <> -1 Or Instruction.Segment <> 0 Then
            Exit Function
        End If
        If Relative Then
            If Instruction.MemoryBase <> -2 Then
                Exit Function
            End If
            If Instruction.Flow <> 0 And Instruction.Flow <> 5 And Instruction.Flow <> 6 Then
                Exit Function
            End If
        Else
            If Instruction.MemoryBase < 0 Or Instruction.MemoryBase > 15 Or Instruction.Flow <> 0 Then
                Exit Function
            End If
        End If
    End If
    If Relocation.Offset <> InstructionOffset + Field Then
        Exit Function
    End If
    Dim Half As LongLong = 1073741824
    Half = Half * 2
    Call ResetNativeFailure(Failure)
    If Prepared < -Half Or Prepared >= Half Then
        Exit Function
    End If
    If Relative Then
        Prepared = Prepared + Instruction.ByteCount - Field - Relocation.RelativeEnd
    End If
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryReadNativeInstructionRelocationOffset = True
End Function

' Resolve the signed linked operand, without accepting modulo address truncation.
Function TryReadNativeInstructionRelocationTarget(ByRef Instruction As NativeInstruction, ByVal InstructionOffset As LongLong, ByRef Relocation As NativeObjectRelocation, ByRef Target As NativeDefinitionRange, ByVal InstructionRVA As LongLong, ByRef ImageBytes() As Byte, ByVal ImageFirst As Long, ByRef Inspection As NativeInspection, ByRef Result As LongLong, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeInstructionRelocationTarget = False
    Call ResetNativeFailure(Failure)
    If ValidNativeRelocationTarget(Target) = False Or Instruction.ByteCount < 1 Or Instruction.ByteCount > 15 Then
        Exit Function
    End If
    Dim Maximum As LongLong = 65536
    Maximum = Maximum * 65536 - 1
    If InstructionRVA < 0 Or InstructionRVA > Maximum - Instruction.ByteCount Then
        Exit Function
    End If
    If ImageFirst < 0 Or ImageFirst > ByteStorageLength(ImageBytes) Then
        Exit Function
    End If
    If Instruction.ByteCount > ByteStorageLength(ImageBytes) - ImageFirst Then
        Exit Function
    End If
    Dim Offset As LongLong = 0
    If TryReadNativeInstructionRelocationOffset(Instruction, InstructionOffset, Relocation, Inspection, Offset, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Relative As Boolean = Relocation.Kind >= 4 And Relocation.Kind <= 9
    Dim Position As LongLong = Target.SectionOffset + Offset
    Dim Displacement As LongLong = Position
    Dim Half As LongLong = 1073741824
    Half = Half * 2
    Failure.Code = 1506
    If Relative Then
        Position = Target.RelativeAddress + Offset
        If Position < 0 Or Position > Maximum Then
            Exit Function
        End If
        Dim ImageBase As LongLong = Target.Address - Target.RelativeAddress
        If Position > SemanticLongLongMaximum() - ImageBase Then
            Exit Function
        End If
        Displacement = Position - InstructionRVA - Instruction.ByteCount
        If Displacement < -Half Or Displacement >= Half Then
            Exit Function
        End If
    Else
        If Position < 0 Or Position >= Half Then
            Exit Function
        End If
    End If
    Dim Field As Long = Instruction.DisplacementFirst
    If Instruction.Flow >= 2 And Instruction.Flow <= 4 Then
        Field = Instruction.ImmediateFirst
    End If
    Dim Linked As LongLong = 0
    If TryReadNativeBits(ImageBytes, Inspection, ImageFirst + Field, 4, Linked, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeSignedInstructionField(Linked, 4) <> Displacement Then
        Exit Function
    End If
    Result = Position
    Failure.Code = 0
    Failure.Resource = 0
    TryReadNativeInstructionRelocationTarget = True
End Function
