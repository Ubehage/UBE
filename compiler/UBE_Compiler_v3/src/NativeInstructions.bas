UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeInstructions"

Type NativeInstruction
    ByteCount As Long
    Flow As Long
    WrittenRegisters As Long
    MemoryBytes As Long
    MemoryBase As Long
    MemoryIndex As Long
    MemoryScale As Long
    MemoryWrite As Long
    Segment As Long
    DisplacementFirst As Long
    DisplacementBytes As Long
    ImmediateFirst As Long
    ImmediateBytes As Long
    TargetRegister As Long
    RelativeOffset As LongLong
    MemoryDisplacement As LongLong
End Type

Private Function TryReadNativeInstructionField(ByRef Bytes() As Byte, ByVal First As Long, ByVal Available As Long, ByRef Cursor As Long, ByVal Width As Long, ByRef Inspection As NativeInspection, ByRef Value As LongLong, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeInstructionField = False
    Failure.Code = 1506
    If Width > 15 - Cursor Or Width > Available - Cursor Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + Cursor, Width, Value, Cancellation, Failure) = False Then
        Exit Function
    End If
    Cursor = Cursor + Width
    TryReadNativeInstructionField = True
End Function

Private Sub AddNativeRegisterWrite(ByRef Mask As Long, ByVal Register As Long, ByVal ByteOperand As Boolean, ByVal Rex As Long)
    If ByteOperand And Rex < 0 And Register >= 4 And Register <= 7 Then
        Register = Register - 4
    End If
    Dim Bit As Long = 1
    While Register > 0
        Bit = Bit * 2
        Register = Register - 1
    Wend
    If (Mask \ Bit) Mod 2 = 0 Then
        Mask = Mask + Bit
    End If
End Sub

Function NativeSignedInstructionField(ByVal Value As LongLong, ByVal Width As Long) As LongLong
    Dim Half As LongLong = 128
    If Width = 4 Then
        Half = 1073741824
        Half = Half * 2
    End If
    NativeSignedInstructionField = Value
    If Value >= Half Then
        NativeSignedInstructionField = Value - Half * 2
    End If
End Function

Function TryReadNativeInstruction(ByRef Bytes() As Byte, ByVal First As Long, ByVal Available As Long, ByRef Inspection As NativeInspection, ByRef Result As NativeInstruction, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeInstruction = False
    Call ResetNativeFailure(Failure)
    If First < 0 Or Available < 1 Or First > ByteStorageLength(Bytes) Then
        Exit Function
    End If
    If Available > ByteStorageLength(Bytes) - First Then
        Exit Function
    End If
    Dim Prepared As NativeInstruction
    Prepared.MemoryBase = -1
    Prepared.MemoryIndex = -1
    Prepared.TargetRegister = -1
    Dim Cursor As Long = 0
    Dim Value As LongLong = 0
    Dim Opcode As Long = 0
    Dim Rex As Long = -1
    Dim Operand16 As Boolean = False
    Dim Prefix As Boolean = True
    While Prefix
        If TryReadNativeInstructionField(Bytes, First, Available, Cursor, 1, Inspection, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        Opcode = Value
        Failure.Code = 1506
        Prefix = False
        If Opcode = 102 Then
            If Rex >= 0 Then
                Exit Function
            End If
            Operand16 = True
            Prefix = True
        End If
        If Opcode = 46 Or Opcode = 101 Then
            If Rex >= 0 Or Prepared.Segment <> 0 Then
                Exit Function
            End If
            Prepared.Segment = Opcode
            Prefix = True
        End If
        If Opcode >= 64 And Opcode <= 79 Then
            If Rex >= 0 Then
                Exit Function
            End If
            Rex = Opcode - 64
            Prefix = True
        End If
    Wend
    Dim RexB As Long = 0
    Dim RexX As Long = 0
    Dim RexR As Long = 0
    Dim Wide As Boolean = False
    If Rex >= 0 Then
        RexB = Rex Mod 2 * 8
        RexX = (Rex \ 2) Mod 2 * 8
        RexR = (Rex \ 4) Mod 2 * 8
        Wide = Rex >= 8
    End If
    Dim OperandBytes As Long = 4
    If Operand16 Then
        OperandBytes = 2
    End If
    If Wide Then
        OperandBytes = 8
    End If
    Dim WordImmediate As Long = OperandBytes
    If WordImmediate = 8 Then
        WordImmediate = 4
    End If
    Dim Recognized As Boolean = False
    Dim ModRM As Boolean = False
    Dim ByteOperand As Boolean = False
    Dim RegisterWrite As Boolean = False
    Dim RMWrite As Boolean = False
    Dim MemoryOnly As Boolean = False
    Dim Nop As Boolean = False
    Dim Group As Long = 0
    Dim Immediate As Long = 0
    Dim Branch As Boolean = False
    Dim Register As Long = -1
    Dim MemoryWidth As Long = OperandBytes
    Dim Secondary As Long = -1
    If Opcode = 15 Then
        If TryReadNativeInstructionField(Bytes, First, Available, Cursor, 1, Inspection, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        Secondary = Value
        If Secondary = 31 Then
            Recognized = True
            ModRM = True
            Nop = True
            Group = 1
        End If
        If Secondary = 182 Or Secondary = 190 Or Secondary = 183 Or Secondary = 191 Then
            Recognized = True
            ModRM = True
            RegisterWrite = True
            MemoryWidth = 1
            If Secondary = 183 Or Secondary = 191 Then
                MemoryWidth = 2
            End If
        End If
        If Secondary = 175 Or (Secondary >= 64 And Secondary <= 79) Then
            Recognized = True
            ModRM = True
            RegisterWrite = True
        End If
        If Secondary >= 144 And Secondary <= 159 Then
            Recognized = True
            ModRM = True
            ByteOperand = True
            RMWrite = True
        End If
        If Secondary >= 128 And Secondary <= 143 Then
            Recognized = True
            Branch = True
            Immediate = 4
            Prepared.Flow = 2
        End If
        If Secondary = 11 Then
            Recognized = True
            Prepared.Flow = 7
        End If
    Else
        If Opcode <= 59 And Opcode Mod 8 <= 3 Then
            Recognized = True
            ModRM = True
            ByteOperand = Opcode Mod 2 = 0
            If Opcode < 56 Then
                RMWrite = Opcode Mod 4 < 2
                RegisterWrite = Opcode Mod 4 >= 2
            End If
        End If
        If Opcode <= 61 And (Opcode Mod 8 = 4 Or Opcode Mod 8 = 5) Then
            Recognized = True
            ByteOperand = Opcode Mod 2 = 0
            Immediate = WordImmediate
            If ByteOperand Then
                Immediate = 1
            End If
            If Opcode < 60 Then
                Register = 0
            End If
        End If
        If Opcode >= 136 And Opcode <= 141 Then
            If Opcode <> 140 Then
                Recognized = True
                ModRM = True
                ByteOperand = Opcode = 136 Or Opcode = 138
                RMWrite = Opcode = 136 Or Opcode = 137
                RegisterWrite = Opcode = 138 Or Opcode = 139 Or Opcode = 141
                MemoryOnly = Opcode = 141
            End If
        End If
        If Opcode >= 132 And Opcode <= 135 Then
            Recognized = True
            ModRM = True
            ByteOperand = Opcode Mod 2 = 0
            RMWrite = Opcode >= 134
            RegisterWrite = Opcode >= 134
        End If
        If Opcode = 99 Or Opcode = 105 Or Opcode = 107 Then
            Recognized = True
            ModRM = True
            RegisterWrite = True
            If Opcode = 99 Then
                If Wide = False Then
                    Exit Function
                End If
                MemoryWidth = 4
            End If
            If Opcode = 105 Then
                Immediate = WordImmediate
            End If
            If Opcode = 107 Then
                Immediate = 1
            End If
        End If
        If Opcode = 128 Or Opcode = 129 Or Opcode = 131 Then
            Recognized = True
            ModRM = True
            ByteOperand = Opcode = 128
            Group = 2
            Immediate = 1
            If Opcode = 129 Then
                Immediate = WordImmediate
            End If
        End If
        If Opcode = 198 Or Opcode = 199 Then
            Recognized = True
            ModRM = True
            ByteOperand = Opcode = 198
            RMWrite = True
            Group = 1
            Immediate = WordImmediate
            If ByteOperand Then
                Immediate = 1
            End If
        End If
        If Opcode = 192 Or Opcode = 193 Or (Opcode >= 208 And Opcode <= 211) Then
            Recognized = True
            ModRM = True
            ByteOperand = Opcode Mod 2 = 0
            RMWrite = True
            Group = 3
            If Opcode = 192 Or Opcode = 193 Then
                Immediate = 1
            End If
        End If
        If Opcode = 246 Or Opcode = 247 Or Opcode = 254 Or Opcode = 255 Or Opcode = 143 Then
            Recognized = True
            ModRM = True
            ByteOperand = Opcode = 246 Or Opcode = 254
            Group = 4
            If Opcode = 254 Or Opcode = 255 Then
                Group = 5
            End If
            If Opcode = 143 Then
                Group = 6
            End If
        End If
        If Opcode >= 176 And Opcode <= 191 Then
            Recognized = True
            ByteOperand = Opcode < 184
            Register = Opcode Mod 8 + RexB
            Immediate = OperandBytes
            If ByteOperand Then
                Immediate = 1
            End If
        End If
        If Opcode >= 144 And Opcode <= 151 Then
            Recognized = True
            Register = Opcode - 144 + RexB
            If Register = 0 Then
                Nop = True
                Register = -1
            Else
                Call AddNativeRegisterWrite(Prepared.WrittenRegisters, 0, False, Rex)
            End If
        End If
        If Opcode >= 80 And Opcode <= 95 Then
            Recognized = True
            Call AddNativeRegisterWrite(Prepared.WrittenRegisters, 4, False, Rex)
            If Opcode >= 88 Then
                Register = Opcode Mod 8 + RexB
            End If
        End If
        If Opcode = 104 Or Opcode = 106 Then
            Recognized = True
            Call AddNativeRegisterWrite(Prepared.WrittenRegisters, 4, False, Rex)
            Immediate = 1
            If Opcode = 104 Then
                Immediate = WordImmediate
            End If
        End If
        If Opcode = 152 Or Opcode = 153 Then
            Recognized = True
            Register = 0
            If Opcode = 153 Then
                Register = 2
            End If
        End If
        If Opcode = 168 Or Opcode = 169 Then
            Recognized = True
            Immediate = WordImmediate
            If Opcode = 168 Then
                Immediate = 1
            End If
        End If
        If Opcode = 195 Then
            Recognized = True
            Prepared.Flow = 1
        End If
        If Opcode = 204 Then
            If Cursor <> 1 Then
                Exit Function
            End If
            Recognized = True
            Prepared.Flow = 7
        End If
        If Opcode = 201 Then
            Recognized = True
            Prepared.WrittenRegisters = 48
        End If
        If Opcode = 232 Or Opcode = 233 Or Opcode = 235 Or (Opcode >= 112 And Opcode <= 127) Then
            Recognized = True
            Branch = True
            Immediate = 1
            Prepared.Flow = 2
            If Opcode = 232 Or Opcode = 233 Then
                Immediate = 4
            End If
            If Opcode = 233 Or Opcode = 235 Then
                Prepared.Flow = 3
            End If
            If Opcode = 232 Then
                Prepared.Flow = 4
                Prepared.WrittenRegisters = 16
            End If
        End If
    End If
    Failure.Code = 1506
    If Recognized = False Then
        Exit Function
    End If
    If Prepared.Segment = 46 And Nop = False Then
        Exit Function
    End If
    If Branch And Operand16 Then
        Exit Function
    End If
    If Register >= 0 Then
        Call AddNativeRegisterWrite(Prepared.WrittenRegisters, Register, ByteOperand, Rex)
    End If
    Dim HasMemory As Boolean = False
    If ModRM Then
        If TryReadNativeInstructionField(Bytes, First, Available, Cursor, 1, Inspection, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Mode As Long = Value \ 64
        Dim Reg As Long = (Value \ 8) Mod 8
        Dim RM As Long = Value Mod 8
        Failure.Code = 1506
        If MemoryOnly And Mode = 3 Then
            Exit Function
        End If
        If Group > 0 Then
            If RexR <> 0 Then
                Exit Function
            End If
            If Group = 1 And Reg <> 0 Then
                Exit Function
            End If
            If Group = 2 Then
                RMWrite = Reg <> 7
            End If
            If Group = 3 And Reg = 6 Then
                Exit Function
            End If
            If Group = 4 Then
                If Reg = 1 Then
                    Exit Function
                End If
                If Reg = 0 Then
                    Immediate = WordImmediate
                    If ByteOperand Then
                        Immediate = 1
                    End If
                End If
                RMWrite = Reg = 2 Or Reg = 3
                If Reg >= 4 Then
                    Call AddNativeRegisterWrite(Prepared.WrittenRegisters, 0, False, Rex)
                    If ByteOperand = False Then
                        Call AddNativeRegisterWrite(Prepared.WrittenRegisters, 2, False, Rex)
                    End If
                End If
            End If
            If Group = 5 Then
                If Reg = 3 Or Reg = 5 Or Reg = 7 Or (Opcode = 254 And Reg > 1) Then
                    Exit Function
                End If
                RMWrite = Reg < 2
                If Reg = 2 Then
                    Prepared.Flow = 5
                End If
                If Reg = 4 Then
                    Prepared.Flow = 6
                End If
                If Reg = 2 Or Reg = 6 Then
                    Call AddNativeRegisterWrite(Prepared.WrittenRegisters, 4, False, Rex)
                End If
                If Reg >= 2 Then
                    MemoryWidth = 8
                    If Reg = 6 And Operand16 Then
                        MemoryWidth = 2
                    End If
                End If
            End If
            If Group = 6 Then
                If Reg <> 0 Then
                    Exit Function
                End If
                RMWrite = True
                MemoryWidth = 8
                If Operand16 Then
                    MemoryWidth = 2
                End If
                Call AddNativeRegisterWrite(Prepared.WrittenRegisters, 4, False, Rex)
            End If
        End If
        If RegisterWrite Then
            Call AddNativeRegisterWrite(Prepared.WrittenRegisters, Reg + RexR, ByteOperand, Rex)
        End If
        If Mode = 3 Then
            If Prepared.Flow = 5 Or Prepared.Flow = 6 Then
                Prepared.TargetRegister = RM + RexB
            End If
            If RMWrite Then
                Call AddNativeRegisterWrite(Prepared.WrittenRegisters, RM + RexB, ByteOperand, Rex)
            End If
        Else
            HasMemory = True
            Prepared.MemoryBase = RM + RexB
            Prepared.MemoryScale = 1
            Prepared.MemoryBytes = MemoryWidth
            If ByteOperand Then
                Prepared.MemoryBytes = 1
            End If
            If RMWrite Then
                Prepared.MemoryWrite = 1
            End If
            Dim Displacement As Long = 0
            If Mode = 1 Then
                Displacement = 1
            End If
            If Mode = 2 Then
                Displacement = 4
            End If
            If RM = 5 And Mode = 0 Then
                Prepared.MemoryBase = -2
                Displacement = 4
            End If
            If RM = 4 Then
                If TryReadNativeInstructionField(Bytes, First, Available, Cursor, 1, Inspection, Value, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Dim Base As Long = Value Mod 8
                Dim Scale As Long = Value \ 64
                Dim Index As Long = (Value \ 8) Mod 8
                Prepared.MemoryBase = Base + RexB
                If Index <> 4 Or RexX <> 0 Then
                    Prepared.MemoryIndex = Index + RexX
                End If
                While Scale > 0
                    Prepared.MemoryScale = Prepared.MemoryScale * 2
                    Scale = Scale - 1
                Wend
                If Base = 5 And Mode = 0 Then
                    Prepared.MemoryBase = -3
                    Displacement = 4
                End If
            End If
            If Displacement > 0 Then
                Prepared.DisplacementFirst = Cursor
                Prepared.DisplacementBytes = Displacement
                If TryReadNativeInstructionField(Bytes, First, Available, Cursor, Displacement, Inspection, Value, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Prepared.MemoryDisplacement = NativeSignedInstructionField(Value, Displacement)
            End If
        End If
    End If
    Failure.Code = 1506
    If Prepared.Segment = 101 And HasMemory = False Then
        Exit Function
    End If
    If Nop Or MemoryOnly Then
        Prepared.MemoryBytes = 0
    End If
    If Immediate > 0 Then
        Prepared.ImmediateFirst = Cursor
        Prepared.ImmediateBytes = Immediate
        If TryReadNativeInstructionField(Bytes, First, Available, Cursor, Immediate, Inspection, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Branch Then
            Prepared.RelativeOffset = NativeSignedInstructionField(Value, Immediate)
        End If
    End If
    Prepared.ByteCount = Cursor
    Result = Prepared
    Failure.Code = 0
    Failure.Resource = 0
    TryReadNativeInstruction = True
End Function
