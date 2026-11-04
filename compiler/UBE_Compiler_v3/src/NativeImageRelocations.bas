UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeImageRelocations"

' Associate every loader base-relocation write with independently bound pointers.
' Expected contains alternating field and target RVAs in increasing field order.
Function TryValidateNativeImageRelocations(ByRef Bytes() As Byte, ByRef Layout As NativeObjectLayout, ByRef Expected() As LongLong, ByRef Inspection As NativeInspection, ByRef Result As NativeDefinitionRange, ByVal Cancellation As SourceCancellation, ByRef Failure As NativeFailure) As Boolean
    TryValidateNativeImageRelocations = False
    Call ResetNativeFailure(Failure)
    Dim Count As Long = NativeExpectedIntegerLength(Expected)
    If Layout.Kind <> 2 Or Layout.Length <> ByteStorageLength(Bytes) Or Layout.ImageBase < 0 Or Layout.ImageBytes < 1 Or Count < 2 Or Count Mod 2 <> 0 Then
        Exit Function
    End If
    Dim PE As LongLong = 0
    Dim DirectoryCount As LongLong = 0
    If TryReadNativeImageHeader(Bytes, Layout, Inspection, PE, DirectoryCount, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Flags As LongLong = 0
    If TryReadNativeBits(Bytes, Inspection, PE + 22, 2, Flags, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Flags Mod 2 <> 0 Then
        Exit Function
    End If
    Dim Address As LongLong = 0
    Dim Size As LongLong = 0
    If TryReadNativeImageDirectory(Bytes, Layout, 5, Inspection, Address, Size, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If Address = 0 Or Address Mod 4 <> 0 Or Size < 8 Or Size > 2147483647 Or Size Mod 4 <> 0 Then
        Exit Function
    End If
    Dim Prepared As NativeDefinitionRange
    If TryLocateNativeImageRange(Bytes, Layout, Address, Size, Inspection, Prepared, Cancellation, Failure) = False Then
        Exit Function
    End If
    Failure.Code = 1506
    If NativeReadOnlyDataCharacteristics(Prepared.Characteristics) = False Then
        Exit Function
    End If
    If TryValidateNativeContributionIsolation(Bytes, Layout, Prepared, Inspection, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Position As Long = 0
    Dim Pair As Long = 0
    Dim PreviousPage As LongLong = -1
    Dim PreviousEnd As LongLong = 0
    While Position < Prepared.ByteCount
        Failure.Code = 1506
        If Prepared.ByteCount - Position < 8 Then
            Exit Function
        End If
        Dim Page As LongLong = 0
        Dim BlockBytes As LongLong = 0
        If TryReadNativeBits(Bytes, Inspection, Prepared.FileFirst + Position, 4, Page, Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryReadNativeBits(Bytes, Inspection, Prepared.FileFirst + Position + 4, 4, BlockBytes, Cancellation, Failure) = False Then
            Exit Function
        End If
        Failure.Code = 1506
        If Page Mod 4096 <> 0 Or Page <= PreviousPage Or Page >= Layout.ImageBytes Or BlockBytes < 8 Or BlockBytes Mod 4 <> 0 Or BlockBytes > Prepared.ByteCount - Position Then
            Exit Function
        End If
        Dim BlockEnd As Long = Position + BlockBytes
        Position = Position + 8
        PreviousPage = Page
        While Position < BlockEnd
            Dim Entry As LongLong = 0
            If TryReadNativeBits(Bytes, Inspection, Prepared.FileFirst + Position, 2, Entry, Cancellation, Failure) = False Then
                Exit Function
            End If
            Position = Position + 2
            Dim Kind As Long = Entry \ 4096
            If Kind <> 0 Then
                Failure.Code = 1506
                If Kind <> 10 Or Pair >= Count Then
                    Exit Function
                End If
                Dim Field As LongLong = Page + Entry Mod 4096
                If Field < PreviousEnd Then
                    Exit Function
                End If
                If TryVisitNativeInspection(Inspection, 0, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Dim ExpectedField As LongLong = Expected(Pair)
                Dim Target As LongLong = Expected(Pair + 1)
                Failure.Code = 1509
                If ExpectedField < 0 Or ExpectedField > Layout.ImageBytes Or Target < 0 Or Target > Layout.ImageBytes Then
                    Exit Function
                End If
                If Target > SemanticLongLongMaximum() - Layout.ImageBase Then
                    Exit Function
                End If
                Failure.Code = 1506
                If Field <> ExpectedField Or NativeImageRangeOverlaps(Field, 8, Prepared) Then
                    Exit Function
                End If
                Dim Storage As NativeDefinitionRange
                If TryLocateNativeImageRange(Bytes, Layout, Field, 8, Inspection, Storage, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Failure.Code = 1506
                If NativeInitializedImageDataCharacteristics(Storage.Characteristics) = False Then
                    Exit Function
                End If
                If TryValidateNativeContributionIsolation(Bytes, Layout, Storage, Inspection, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Dim Value As LongLong = 0
                If TryReadNativeBits(Bytes, Inspection, Storage.FileFirst, 8, Value, Cancellation, Failure) = False Then
                    Exit Function
                End If
                Failure.Code = 1506
                If Value <> Layout.ImageBase + Target Then
                    Exit Function
                End If
                PreviousEnd = Field + 8
                Pair = Pair + 2
            End If
        Wend
    Wend
    Failure.Code = 1506
    If Pair <> Count Then
        Exit Function
    End If
    Result = Prepared
    Failure.Code = 0
    TryValidateNativeImageRelocations = True
End Function
