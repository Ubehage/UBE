UBE SOURCE 1 MODULE
Attribute UBE_Name = "ForeignAbiOutput"

Function ForeignAbiCType(ByVal TypeIndex As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByVal IsResult As Long) As String
    If TypeIndex < 0 Or TypeIndex >= TypeCount Then
        ForeignAbiCType = "void"
        Exit Function
    End If
    Dim Kind As Long = Types(TypeIndex).TypeKind
    If Kind = 4 Then
        ForeignAbiCType = "int32_t"
        Exit Function
    End If
    If Kind = 5 Then
        ForeignAbiCType = "int64_t"
        Exit Function
    End If
    If Kind = 12 Or Kind = 30 Or (Kind >= 50 And Kind <= 52) Then
        ForeignAbiCType = "uint64_t"
        Exit Function
    End If
    ForeignAbiCType = "void"
End Function

Function ForeignAbiSignatureHash(ByVal FunctionIndex As Long, ByRef Symbols() As SemanticSymbol, ByRef Functions() As IrFunction, ByRef Parameters() As IrParameter, ByRef Types() As SemanticType) As Long
    Dim SymbolIndex As Long = Functions(FunctionIndex).SymbolIndex
    Dim SignatureText As String = Symbols(SymbolIndex).SymbolName & "|"
    If Functions(FunctionIndex).ResultType >= 0 Then
        SignatureText = SignatureText & LongToString(Types(Functions(FunctionIndex).ResultType).TypeKind)
    Else
        SignatureText = SignatureText & "void"
    End If
    Dim Offset As Long = 0
    While Offset < Functions(FunctionIndex).ParameterCount
        Dim ParameterIndex As Long = Functions(FunctionIndex).FirstParameter + Offset
        SignatureText = SignatureText & "|" & LongToString(Types(Parameters(ParameterIndex).TypeIndex).TypeKind)
        SignatureText = SignatureText & ":" & LongToString(Parameters(ParameterIndex).PassingMode)
        Offset = Offset + 1
    Wend
    Dim HashValue As Long
    HashValue = 5381
    Dim ByteIndex As Long = 0
    While ByteIndex < StringLength(SignatureText)
        HashValue = ((HashValue Mod 65075262) * 33 + StringByteAt(SignatureText, ByteIndex)) Mod 2147483647
        ByteIndex = ByteIndex + 1
    Wend
    ForeignAbiSignatureHash = HashValue
End Function

' Writes the declarations paired with a Library LLVM artifact.  Object-like
' values are opaque generation-checked handles; no managed address is exposed.
Function WriteForeignAbiHeader(ByVal OutputPath As String, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long, ByRef Functions() As IrFunction, ByVal FunctionCount As Long, ByRef Parameters() As IrParameter) As Long
    Dim N As String = StringFromByte(10)
    Dim QuoteText As String = StringFromByte(34)
    Dim Header As String = "#ifndef UBE_GENERATED_ABI_H" & N
    Header = Header & "#define UBE_GENERATED_ABI_H" & N & N
    Header = Header & "#include <stdint.h>" & N & N
    Header = Header & "#if defined(_WIN32)" & N
    Header = Header & "#define UBE_ABI_IMPORT __declspec(dllimport)" & N
    Header = Header & "#else" & N & "#define UBE_ABI_IMPORT" & N & "#endif" & N & N
    Header = Header & "#ifdef __cplusplus" & N & "extern " & QuoteText & "C" & QuoteText & " {" & N & "#endif" & N & N
    Header = Header & "UBE_ABI_IMPORT extern const int32_t ube_library_abi_major;" & N
    Header = Header & "UBE_ABI_IMPORT extern const int32_t ube_library_abi_minor;" & N
    Header = Header & "UBE_ABI_IMPORT extern const int32_t ube_library_pointer_bits;" & N
    Header = Header & "UBE_ABI_IMPORT extern const int32_t ube_library_endianness;" & N
    Header = Header & "UBE_ABI_IMPORT extern const int32_t ube_library_calling_convention;" & N
    Header = Header & "UBE_ABI_IMPORT extern const char ube_library_target[23];" & N
    Header = Header & "UBE_ABI_IMPORT extern const int32_t ube_library_export_count;" & N
    Dim ExportCount As Long = 0
    Dim ExportScan As Long = 0
    While ExportScan < FunctionCount
        Dim ExportSymbol As Long = Functions(ExportScan).SymbolIndex
        If ExportSymbol >= 0 Then
            If (Symbols(ExportSymbol).Flags And 64) <> 0 Then
                ExportCount = ExportCount + 1
            End If
        End If
        ExportScan = ExportScan + 1
    Wend
    Dim SignatureCount As Long = ExportCount
    If SignatureCount = 0 Then
        SignatureCount = 1
    End If
    Header = Header & "UBE_ABI_IMPORT extern const uint64_t ube_library_export_signature_hashes[" & LongToString(SignatureCount) & "];" & N
    Header = Header & "UBE_ABI_IMPORT int32_t ube_library_copy_diagnostic(char* buffer, uint64_t capacity, uint64_t* required);" & N
    Header = Header & "UBE_ABI_IMPORT int32_t ube_library_copy_handle(uint64_t handle, uint64_t* copied);" & N
    Header = Header & "UBE_ABI_IMPORT int32_t ube_library_release_handle(uint64_t handle);" & N
    Header = Header & "UBE_ABI_IMPORT int32_t ube_library_shutdown(void);" & N & N

    Dim FunctionIndex As Long = 0
    While FunctionIndex < FunctionCount
        Dim SymbolIndex As Long = Functions(FunctionIndex).SymbolIndex
        If SymbolIndex >= 0 Then
            If (Symbols(SymbolIndex).Flags And 64) <> 0 Then
                Header = Header & "UBE_ABI_IMPORT int32_t ube_export_" & HexEncode(Symbols(SymbolIndex).SymbolName) & "("
                Dim ParameterOffset As Long = 0
                While ParameterOffset < Functions(FunctionIndex).ParameterCount
                    If ParameterOffset > 0 Then
                        Header = Header & ", "
                    End If
                    Dim ParameterIndex As Long = Functions(FunctionIndex).FirstParameter + ParameterOffset
                    Dim ParameterType As String = ForeignAbiCType(Parameters(ParameterIndex).TypeIndex, Types, TypeCount, 0)
                    If Parameters(ParameterIndex).PassingMode = IrPassingByRef() Then
                        ParameterType = ParameterType & "*"
                    End If
                    Header = Header & ParameterType & " a" & LongToString(ParameterOffset)
                    ParameterOffset = ParameterOffset + 1
                Wend
                If Functions(FunctionIndex).ResultType >= 0 Then
                    If ParameterOffset > 0 Then
                        Header = Header & ", "
                    End If
                    Header = Header & ForeignAbiCType(Functions(FunctionIndex).ResultType, Types, TypeCount, 1) & "* result"
                    ParameterOffset = ParameterOffset + 1
                End If
                If ParameterOffset = 0 Then
                    Header = Header & "void"
                End If
                Header = Header & ");" & N
            End If
        End If
        FunctionIndex = FunctionIndex + 1
    Wend
    Header = Header & N & "#ifdef __cplusplus" & N & "}" & N & "#endif" & N & N
    Header = Header & "#endif" & N
    WriteForeignAbiHeader = WriteAllText(OutputPath & ".h", Header)
End Function
