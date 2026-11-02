UBE SOURCE 1 MODULE
Attribute UBE_Name = "ByteKeys"

' Generic partitioned byte-key ordering; contract: ../../BYTE-KEY-CONTRACT.md.
' Inputs are immutable borrowed views; no input/source ownership is retained.
Type ByteKey
    Partition As Long
    FirstByte As Long
    ByteCount As Long
    Value As Long
End Type
Private Intrinsic Function ByteKeyByteLength(ByRef Values() As Byte) As Long
Attribute ByteKeyByteLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function ByteKeyLength(ByRef Values() As ByteKey) As Long
Attribute ByteKeyLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function ByteKeyOrderLength(ByRef Values() As Long) As Long
Attribute ByteKeyOrderLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeByteKeyOrder(ByRef Values() As Long, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeByteKeyOrder.UBE_Primitive = "Array.TryResize"
End Function
Private Intrinsic Function TryCopyByteKeyOrder(ByRef Destination() As Long, ByRef Original() As Long) As Boolean
Attribute TryCopyByteKeyOrder.UBE_Primitive = "Array.TryCopy"
End Function

Private Function TryReadByteKeyByte(ByRef Bytes() As Byte, ByVal AtByte As Long, ByRef Value As Long) As Boolean
    TryReadByteKeyByte = False
    Value = Bytes(AtByte)
    TryReadByteKeyByte = True
End Function
Private Sub WriteByteKeyOrder(ByRef Destination As Long, ByVal Value As Long)
    Destination = Value
End Sub

' Checks one key without touching its byte payload. Failure stays5 on managed
' admission denial; a detected invalid caller span sets1.
Private Function TryValidateByteKey(ByRef Keys() As ByteKey, ByVal Index As Long, ByVal ByteLength As Long, ByRef Failure As Long) As Boolean
    TryValidateByteKey = False
    If Index < 0 Or Index >= ByteKeyLength(Keys) Then
        Failure = 1
        Exit Function
    End If
    Dim FirstByte As Long = Keys(Index).FirstByte
    Dim ByteCount As Long = Keys(Index).ByteCount
    If FirstByte < 0 Or FirstByte > ByteLength Or ByteCount < 0 Then
        Failure = 1
        Exit Function
    End If
    If ByteCount > ByteLength - FirstByte Then
        Failure = 1
        Exit Function
    End If
    TryValidateByteKey = True
End Function

Private Function TryCompareByteKeySpans(ByRef Bytes() As Byte, ByVal LeftFirst As Long, ByVal LeftCount As Long, ByVal RightFirst As Long, ByVal RightCount As Long, ByRef Relation As Long) As Boolean
    TryCompareByteKeySpans = False
    Dim Index As Long = 0
    While Index < LeftCount And Index < RightCount
        Dim Left As Long = 0
        Dim Right As Long = 0
        If TryReadByteKeyByte(Bytes, LeftFirst + Index, Left) = False Then
            Exit Function
        End If
        If TryReadByteKeyByte(Bytes, RightFirst + Index, Right) = False Then
            Exit Function
        End If
        If Left < Right Then
            Relation = -1
            TryCompareByteKeySpans = True
            Exit Function
        End If
        If Left > Right Then
            Relation = 1
            TryCompareByteKeySpans = True
            Exit Function
        End If
        Index = Index + 1
    Wend
    Relation = 0
    If LeftCount < RightCount Then
        Relation = -1
    End If
    If LeftCount > RightCount Then
        Relation = 1
    End If
    TryCompareByteKeySpans = True
End Function

Private Function TryCompareByteKeys(ByRef Bytes() As Byte, ByRef Keys() As ByteKey, ByVal LeftIndex As Long, ByVal RightIndex As Long, ByRef Relation As Long) As Boolean
    TryCompareByteKeys = False
    Dim LeftPartition As Long = Keys(LeftIndex).Partition
    Dim RightPartition As Long = Keys(RightIndex).Partition
    If LeftPartition < RightPartition Then
        Relation = -1
        TryCompareByteKeys = True
        Exit Function
    End If
    If LeftPartition > RightPartition Then
        Relation = 1
        TryCompareByteKeys = True
        Exit Function
    End If
    TryCompareByteKeys = TryCompareByteKeySpans(Bytes, Keys(LeftIndex).FirstByte, Keys(LeftIndex).ByteCount, Keys(RightIndex).FirstByte, Keys(RightIndex).ByteCount, Relation)
End Function

' Complete independent ordering vector; failed preparation preserves old Order.
' Failure5 must be seeded by the caller before managed entry. No compiler cap.
Function TryOrderByteKeys(ByRef Bytes() As Byte, ByRef Keys() As ByteKey, ByVal KeyCount As Long, ByVal MaximumKeys As Long, ByRef Order() As Long, ByRef Failure As Long) As Boolean
    TryOrderByteKeys = False
    Failure = 5
    If KeyCount < 0 Or MaximumKeys < 0 Then
        Failure = 1
        Exit Function
    End If
    If KeyCount > ByteKeyLength(Keys) Then
        Failure = 1
        Exit Function
    End If
    If KeyCount > MaximumKeys Then
        Failure = 2
        Exit Function
    End If
    Dim ByteLength As Long = ByteKeyByteLength(Bytes)
    Dim Index As Long = 0
    While Index < KeyCount
        If TryValidateByteKey(Keys, Index, ByteLength, Failure) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    Dim Pending() As Long
    Dim Scratch() As Long
    If TryResizeByteKeyOrder(Pending, KeyCount, False) = False Then
        Exit Function
    End If
    If KeyCount > 1 Then
        If TryResizeByteKeyOrder(Scratch, KeyCount, False) = False Then
            Exit Function
        End If
    End If
    Index = 0
    While Index < KeyCount
        Call WriteByteKeyOrder(Pending(Index), Index)
        Index = Index + 1
    Wend
    Dim MergeWidth As Long = 1
    Dim ReadPending As Boolean = True
    While MergeWidth < KeyCount
        Dim First As Long = 0
        While First < KeyCount
            Dim LeftCount As Long = MergeWidth
            If LeftCount > KeyCount - First Then
                LeftCount = KeyCount - First
            End If
            Dim Middle As Long = First + LeftCount
            Dim RightCount As Long = MergeWidth
            If RightCount > KeyCount - Middle Then
                RightCount = KeyCount - Middle
            End If
            Dim Last As Long = Middle + RightCount
            Dim Left As Long = First
            Dim Right As Long = Middle
            Dim Destination As Long = First
            While Destination < Last
                Dim TakeLeft As Boolean = Right = Last
                Dim LeftKey As Long = -1
                Dim RightKey As Long = -1
                If Left < Middle Then
                    If ReadPending Then
                        LeftKey = Pending(Left)
                    Else
                        LeftKey = Scratch(Left)
                    End If
                Else
                    TakeLeft = False
                End If
                If Right < Last Then
                    If ReadPending Then
                        RightKey = Pending(Right)
                    Else
                        RightKey = Scratch(Right)
                    End If
                End If
                If Left < Middle And Right < Last Then
                    Dim Relation As Long = 0
                    If TryCompareByteKeys(Bytes, Keys, LeftKey, RightKey, Relation) = False Then
                        Exit Function
                    End If
                    TakeLeft = Relation <= 0
                End If
                Dim Selected As Long = RightKey
                If TakeLeft Then
                    Selected = LeftKey
                    Left = Left + 1
                Else
                    Right = Right + 1
                End If
                If ReadPending Then
                    Call WriteByteKeyOrder(Scratch(Destination), Selected)
                Else
                    Call WriteByteKeyOrder(Pending(Destination), Selected)
                End If
                Destination = Destination + 1
            Wend
            First = Last
        Wend
        ReadPending = Not ReadPending
        If MergeWidth > KeyCount \ 2 Then
            MergeWidth = KeyCount
        Else
            MergeWidth = MergeWidth * 2
        End If
    Wend
    If ReadPending = False Then
        Index = 0
        While Index < KeyCount
            Call WriteByteKeyOrder(Pending(Index), Scratch(Index))
            Index = Index + 1
        Wend
    End If
    If TryResizeByteKeyOrder(Scratch, 0, False) = False Then
        Exit Function
    End If
    If TryCopyByteKeyOrder(Order, Pending) = False Then
        Exit Function
    End If
    Failure = 0
    TryOrderByteKeys = True
End Function

Private Function TryCompareByteKeyQuery(ByRef Bytes() As Byte, ByRef Keys() As ByteKey, ByVal KeyIndex As Long, ByVal ByteLength As Long, ByVal Partition As Long, ByVal FirstByte As Long, ByVal ByteCount As Long, ByRef Relation As Long, ByRef Failure As Long) As Boolean
    TryCompareByteKeyQuery = False
    If TryValidateByteKey(Keys, KeyIndex, ByteLength, Failure) = False Then
        Exit Function
    End If
    Dim KeyPartition As Long = Keys(KeyIndex).Partition
    If KeyPartition < Partition Then
        Relation = -1
        TryCompareByteKeyQuery = True
        Exit Function
    End If
    If KeyPartition > Partition Then
        Relation = 1
        TryCompareByteKeyQuery = True
        Exit Function
    End If
    TryCompareByteKeyQuery = TryCompareByteKeySpans(Bytes, Keys(KeyIndex).FirstByte, Keys(KeyIndex).ByteCount, FirstByte, ByteCount, Relation)
End Function

Private Function TryFindByteKeyBoundary(ByRef Bytes() As Byte, ByRef Keys() As ByteKey, ByRef Order() As Long, ByVal ByteLength As Long, ByVal Partition As Long, ByVal FirstByte As Long, ByVal ByteCount As Long, ByVal Upper As Boolean, ByRef Boundary As Long, ByRef Failure As Long) As Boolean
    TryFindByteKeyBoundary = False
    Dim First As Long = 0
    Dim Count As Long = ByteKeyOrderLength(Order)
    Dim Last As Long = Count
    While First < Last
        Dim Middle As Long = First + (Last - First) \ 2
        Dim KeyIndex As Long = Order(Middle)
        If KeyIndex < 0 Or KeyIndex >= Count Then
            Failure = 1
            Exit Function
        End If
        Dim Relation As Long = 0
        If TryCompareByteKeyQuery(Bytes, Keys, KeyIndex, ByteLength, Partition, FirstByte, ByteCount, Relation, Failure) = False Then
            Exit Function
        End If
        If Relation < 0 Or (Relation = 0 And Upper) Then
            First = Middle + 1
        Else
            Last = Middle
        End If
    Wend
    Boundary = First
    TryFindByteKeyBoundary = True
End Function

' Immutable sorted Order must come from TryOrderByteKeys. Outputs are distinct,
' do not alias inputs/Failure, and commit only after both boundaries succeed.
Function TryFindByteKeyRange(ByRef Bytes() As Byte, ByRef Keys() As ByteKey, ByRef Order() As Long, ByVal Partition As Long, ByVal FirstByte As Long, ByVal ByteCount As Long, ByRef FirstMatch As Long, ByRef MatchCount As Long, ByRef Failure As Long) As Boolean
    TryFindByteKeyRange = False
    Failure = 5
    Dim Length As Long = ByteKeyByteLength(Bytes)
    If FirstByte < 0 Or FirstByte > Length Or ByteCount < 0 Then
        Failure = 1
        Exit Function
    End If
    If ByteCount > Length - FirstByte Then
        Failure = 1
        Exit Function
    End If
    If ByteKeyOrderLength(Order) > ByteKeyLength(Keys) Then
        Failure = 1
        Exit Function
    End If
    Dim Lower As Long = 0
    Dim Upper As Long = 0
    If TryFindByteKeyBoundary(Bytes, Keys, Order, Length, Partition, FirstByte, ByteCount, False, Lower, Failure) = False Then
        Exit Function
    End If
    If TryFindByteKeyBoundary(Bytes, Keys, Order, Length, Partition, FirstByte, ByteCount, True, Upper, Failure) = False Then
        Exit Function
    End If
    Dim Matches As Long = Upper - Lower
    FirstMatch = Lower
    MatchCount = Matches
    Failure = 0
    TryFindByteKeyRange = True
End Function
