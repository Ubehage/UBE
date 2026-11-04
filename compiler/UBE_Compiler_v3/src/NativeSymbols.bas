UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeSymbols"

' Borrowed descriptors over the immutable snapshot used by NativeObjectLayout.
' Contract: ../NATIVE-OBJECT-IMPLEMENTATION.md. No payload allocation or copy.
Type NativeObjectName
    First As Long
    Count As Long
End Type

Type NativeObjectSymbol
    Name As NativeObjectName
    Value As LongLong
    SectionNumber As Long
    TypeCode As Long
    StorageClass As Long
    AuxiliaryCount As Long
    AuxiliaryFirst As Long
    NextIndex As Long
End Type

Type NativeObjectRelocation
    Offset As LongLong
    TargetIndex As LongLong
    Kind As Long
    Width As Long
    RelativeEnd As Long
End Type

Private Function TryReadNativeObjectName(ByRef Bytes() As Byte, ByRef Inspection As NativeInspection, ByRef Layout As NativeObjectLayout, ByVal First As Long, ByVal SymbolName As Boolean, ByRef Result As NativeObjectName, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeObjectName = False
    Call ResetNativeFailure(Failure)
    If Layout.Length <> ByteStorageLength(Bytes) Or First < 0 Or First > Layout.Length - 8 Then
        Exit Function
    End If
    Dim Prepared As NativeObjectName
    Prepared.First = First
    Dim Limit As Long = First + 8
    Dim Indirect As Boolean = False
    Dim Offset As LongLong = 0
    Dim Value As LongLong = 0
    If SymbolName Then
        If TryReadNativeBits(Bytes, Inspection, First, 4, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Value = 0 Then
            Indirect = True
            If TryReadNativeBits(Bytes, Inspection, First + 4, 4, Offset, Cancellation, Failure) = False Then
                Exit Function
            End If
        End If
    Else
        If TryReadNativeBits(Bytes, Inspection, First, 1, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Value = 47 Then
            Indirect = True
            Dim Digit As Long = 1
            While Digit < 8
                If TryReadNativeBits(Bytes, Inspection, First + Digit, 1, Value, Cancellation, Failure) = False Then
                    Exit Function
                End If
                If Value = 0 Then
                    Exit While
                End If
                Failure.Code = 1506
                If Value < 48 Or Value > 57 Then
                    Exit Function
                End If
                Offset = Offset * 10 + Value - 48
                Digit = Digit + 1
            Wend
        End If
    End If
    If Indirect Then
        Call ResetNativeFailure(Failure)
        If Layout.StringTable < 0 Or Layout.StringBytes < 0 Or Layout.StringTable > Layout.Length Then
            Exit Function
        End If
        If Layout.StringBytes > Layout.Length - Layout.StringTable Then
            Exit Function
        End If
        Failure.Code = 1506
        If Offset < 4 Or Offset >= Layout.StringBytes Then
            Exit Function
        End If
        Prepared.First = Layout.StringTable + Offset
        Limit = Layout.StringTable + Layout.StringBytes
    End If
    Dim Position As Long = Prepared.First
    While Position < Limit
        If TryReadNativeBits(Bytes, Inspection, Position, 1, Value, Cancellation, Failure) = False Then
            Exit Function
        End If
        If Value = 0 Then
            Exit While
        End If
        Position = Position + 1
    Wend
    Failure.Code = 1506
    If Indirect And Position = Limit Then
        Exit Function
    End If
    Prepared.Count = Position - Prepared.First
    Call ResetNativeFailure(Failure)
    Result = Prepared
    Failure.Code = 0
    TryReadNativeObjectName = True
End Function

Function TryReadNativeSectionName(ByRef Bytes() As Byte, ByRef Inspection As NativeInspection, ByRef Layout As NativeObjectLayout, ByVal Index As Long, ByRef Result As NativeObjectName, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeSectionName = False
    Call ResetNativeFailure(Failure)
    If Index < 0 Or Index >= Layout.SectionCount Or Layout.SectionTable < 0 Then
        Exit Function
    End If
    Dim First As LongLong = Index
    First = First * 40 + Layout.SectionTable
    If First > Layout.Length - 40 Then
        Exit Function
    End If
    TryReadNativeSectionName = TryReadNativeObjectName(Bytes, Inspection, Layout, First, False, Result, Cancellation, Failure)
End Function

' Index must be zero or the preceding primary record's NextIndex. The owner
' builds a primary-symbol index once before resolving relocation references.
Function TryReadNativeObjectSymbol(ByRef Bytes() As Byte, ByRef Inspection As NativeInspection, ByRef Layout As NativeObjectLayout, ByVal Index As Long, ByRef Result As NativeObjectSymbol, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeObjectSymbol = False
    Call ResetNativeFailure(Failure)
    If Layout.Length <> ByteStorageLength(Bytes) Or Layout.SymbolTable < 0 Or Index < 0 Or Index >= Layout.SymbolCount Then
        Exit Function
    End If
    Dim WideFirst As LongLong = Index
    WideFirst = WideFirst * 18 + Layout.SymbolTable
    If WideFirst > Layout.Length - 18 Then
        Exit Function
    End If
    Dim First As Long = WideFirst
    Dim Prepared As NativeObjectSymbol
    Dim Section As LongLong = 0
    Dim TypeCode As LongLong = 0
    Dim Storage As LongLong = 0
    Dim Auxiliary As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, First + 8, 4, Prepared.Value, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 12, 2, Section, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 14, 2, TypeCode, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 16, 1, Storage, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 17, 1, Auxiliary, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Section >= 32768 Then
        Section = Section - 65536
    End If
    If Section < -2 Or Section > Layout.SectionCount Or Auxiliary > Layout.SymbolCount - Index - 1 Then
        Exit Function
    End If
    If Auxiliary > (Layout.Length - First - 18) \ 18 Then
        Exit Function
    End If
    Prepared.SectionNumber = Section
    Prepared.TypeCode = TypeCode
    Prepared.StorageClass = Storage
    Prepared.AuxiliaryCount = Auxiliary
    Prepared.AuxiliaryFirst = First + 18
    Prepared.NextIndex = Index + 1 + Auxiliary
    Call ResetNativeFailure(Failure)
    If TryReadNativeObjectName(Bytes, Inspection, Layout, First, True, Prepared.Name, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetNativeFailure(Failure)
    Result = Prepared
    Failure.Code = 0
    TryReadNativeObjectSymbol = True
End Function

Function TryReadNativeObjectRelocation(ByRef Bytes() As Byte, ByRef Inspection As NativeInspection, ByRef Layout As NativeObjectLayout, ByRef Section As NativeObjectSection, ByVal Index As Long, ByRef Result As NativeObjectRelocation, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryReadNativeObjectRelocation = False
    Call ResetNativeFailure(Failure)
    If Layout.Kind <> 1 Or Layout.Length <> ByteStorageLength(Bytes) Or Section.RelocationTable < 0 Or Index < 0 Or Index >= Section.RelocationCount Or Section.InitializedBytes < 0 Then
        Exit Function
    End If
    Dim WideFirst As LongLong = Index
    WideFirst = WideFirst * 10 + Section.RelocationTable
    If WideFirst > Layout.Length - 10 Then
        Exit Function
    End If
    Dim First As Long = WideFirst
    Dim Prepared As NativeObjectRelocation
    Dim Kind As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, First, 4, Prepared.Offset, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 4, 4, Prepared.TargetIndex, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryReadNativeBits(Bytes, Inspection, First + 8, 2, Kind, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Kind > 11 Then
        Exit Function
    End If
    Prepared.Kind = Kind
    If Kind > 0 Then
        Prepared.Width = 4
        If Kind = 1 Then
            Prepared.Width = 8
        End If
        If Kind = 10 Then
            Prepared.Width = 2
        End If
        If Kind >= 4 And Kind <= 9 Then
            Prepared.RelativeEnd = Kind
        End If
        If Prepared.TargetIndex >= Layout.SymbolCount Or Prepared.Offset > Section.InitializedBytes Then
            Exit Function
        End If
        If Prepared.Width > Section.InitializedBytes - Prepared.Offset Then
            Exit Function
        End If
    End If
    Call ResetNativeFailure(Failure)
    Result = Prepared
    Failure.Code = 0
    TryReadNativeObjectRelocation = True
End Function
