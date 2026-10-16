UBE SOURCE 1 MODULE
Attribute UBE_Name = "Text"

Sub TrimText(ByVal Value As String, ByRef Result As String)
    Dim First As Long = 0
    Dim Last As Long = StringLength(Value)
    While First < Last
        Dim FirstByte As Long = StringByteAt(Value, First)
        If FirstByte = 32 Or FirstByte = 9 Then
            First = First + 1
        Else
            Exit While
        End If
    Wend
    While Last > First
        Dim LastByte As Long = StringByteAt(Value, Last - 1)
        If LastByte = 32 Or LastByte = 9 Or LastByte = 13 Then
            Last = Last - 1
        Else
            Exit While
        End If
    Wend
    Result = StringSlice(Value, First, Last - First)
End Sub

Function IsUtf8Continuation(ByVal Value As Long) As Long
    IsUtf8Continuation = 0
    If Value >= 128 And Value <= 191 Then
        IsUtf8Continuation = 1
    End If
End Function

Function Utf8SequenceLength(ByVal Contents As String, ByVal StartByte As Long, ByVal TotalLength As Long) As Long
    Dim FirstByte As Long = StringByteAt(Contents, StartByte)
    If FirstByte < 128 Then
        Utf8SequenceLength = 1
        Exit Function
    End If
    If FirstByte >= 194 And FirstByte <= 223 Then
        If StartByte + 1 < TotalLength Then
            If IsUtf8Continuation(StringByteAt(Contents, StartByte + 1)) <> 0 Then
                Utf8SequenceLength = 2
                Exit Function
            End If
        End If
        Utf8SequenceLength = 0
        Exit Function
    End If
    If FirstByte >= 224 And FirstByte <= 239 Then
        If StartByte + 2 >= TotalLength Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        Dim SecondByte As Long = StringByteAt(Contents, StartByte + 1)
        Dim ThirdByte As Long = StringByteAt(Contents, StartByte + 2)
        If IsUtf8Continuation(ThirdByte) = 0 Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        If FirstByte = 224 Then
            If SecondByte < 160 Or SecondByte > 191 Then
                Utf8SequenceLength = 0
                Exit Function
            End If
        Else
            If FirstByte = 237 Then
                If SecondByte < 128 Or SecondByte > 159 Then
                    Utf8SequenceLength = 0
                    Exit Function
                End If
            Else
                If IsUtf8Continuation(SecondByte) = 0 Then
                    Utf8SequenceLength = 0
                    Exit Function
                End If
            End If
        End If
        Utf8SequenceLength = 3
        Exit Function
    End If
    If FirstByte >= 240 And FirstByte <= 244 Then
        If StartByte + 3 >= TotalLength Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        Dim SecondFourByte As Long = StringByteAt(Contents, StartByte + 1)
        If FirstByte = 240 Then
            If SecondFourByte < 144 Or SecondFourByte > 191 Then
                Utf8SequenceLength = 0
                Exit Function
            End If
        Else
            If FirstByte = 244 Then
                If SecondFourByte < 128 Or SecondFourByte > 143 Then
                    Utf8SequenceLength = 0
                    Exit Function
                End If
            Else
                If IsUtf8Continuation(SecondFourByte) = 0 Then
                    Utf8SequenceLength = 0
                    Exit Function
                End If
            End If
        End If
        If IsUtf8Continuation(StringByteAt(Contents, StartByte + 2)) = 0 Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        If IsUtf8Continuation(StringByteAt(Contents, StartByte + 3)) = 0 Then
            Utf8SequenceLength = 0
            Exit Function
        End If
        Utf8SequenceLength = 4
        Exit Function
    End If
    Utf8SequenceLength = 0
End Function

Function ValidateUtf8(ByVal Contents As String, ByRef InvalidByte As Long) As Long
    Dim TotalLength As Long = StringLength(Contents)
    Dim Index As Long = 0
    While Index < TotalLength
        Dim SequenceLength As Long = Utf8SequenceLength(Contents, Index, TotalLength)
        If SequenceLength = 0 Then
            InvalidByte = Index
            ValidateUtf8 = 0
            Exit Function
        End If
        Index = Index + SequenceLength
    Wend
    InvalidByte = -1
    ValidateUtf8 = 1
End Function

Sub FindLineAndColumn(ByVal Contents As String, ByVal TargetByte As Long, ByRef LineNumber As Long, ByRef ColumnNumber As Long)
    LineNumber = 1
    ColumnNumber = 1
    Dim Index As Long = 0
    While Index < TargetByte
        Dim CurrentByte As Long = StringByteAt(Contents, Index)
        If CurrentByte = 10 Then
            LineNumber = LineNumber + 1
            ColumnNumber = 1
        Else
            If CurrentByte <> 13 Then
                ColumnNumber = ColumnNumber + 1
            End If
        End If
        Dim CharacterBytes As Long = 1
        If CurrentByte >= 128 Then
            CharacterBytes = Utf8SequenceLength(Contents, Index, TargetByte)
            If CharacterBytes = 0 Then
                CharacterBytes = 1
            End If
        End If
        Index = Index + CharacterBytes
    Wend
End Sub

Function DecodeUtf8CodePoint(ByVal Value As String, ByVal StartByte As Long, ByRef CodePoint As Long, ByRef ByteCount As Long) As Long
    Dim TotalLength As Long = StringLength(Value)
    ByteCount = Utf8SequenceLength(Value, StartByte, TotalLength)
    If ByteCount = 0 Then
        DecodeUtf8CodePoint = 0
        Exit Function
    End If
    Dim FirstByte As Long = StringByteAt(Value, StartByte)
    If ByteCount = 1 Then
        CodePoint = FirstByte
    Else
        If ByteCount = 2 Then
            CodePoint = (FirstByte - 192) * 64 + StringByteAt(Value, StartByte + 1) - 128
        Else
            If ByteCount = 3 Then
                CodePoint = (FirstByte - 224) * 4096 + (StringByteAt(Value, StartByte + 1) - 128) * 64 + StringByteAt(Value, StartByte + 2) - 128
            Else
                CodePoint = (FirstByte - 240) * 262144 + (StringByteAt(Value, StartByte + 1) - 128) * 4096 + (StringByteAt(Value, StartByte + 2) - 128) * 64 + StringByteAt(Value, StartByte + 3) - 128
            End If
        End If
    End If
    DecodeUtf8CodePoint = 1
End Function

Function EqualsFolded(ByVal LeftValue As String, ByVal RightValue As String) As Long
    Dim LeftIndex As Long = 0
    Dim RightIndex As Long = 0
    Dim LeftLength As Long = StringLength(LeftValue)
    Dim RightLength As Long = StringLength(RightValue)
    While LeftIndex < LeftLength And RightIndex < RightLength
        Dim LeftCodePoint As Long = 0
        Dim RightCodePoint As Long = 0
        Dim LeftBytes As Long = 0
        Dim RightBytes As Long = 0
        If DecodeUtf8CodePoint(LeftValue, LeftIndex, LeftCodePoint, LeftBytes) = 0 Then
            EqualsFolded = 0
            Exit Function
        End If
        If DecodeUtf8CodePoint(RightValue, RightIndex, RightCodePoint, RightBytes) = 0 Then
            EqualsFolded = 0
            Exit Function
        End If
        If UnicodeSimpleFoldCodePoint(LeftCodePoint) <> UnicodeSimpleFoldCodePoint(RightCodePoint) Then
            EqualsFolded = 0
            Exit Function
        End If
        LeftIndex = LeftIndex + LeftBytes
        RightIndex = RightIndex + RightBytes
    Wend
    If LeftIndex = LeftLength And RightIndex = RightLength Then
        EqualsFolded = 1
    Else
        EqualsFolded = 0
    End If
End Function

Function AppendString(ByRef Values() As String, ByRef Count As Long, ByRef Capacity As Long, ByVal Value As String, ByVal Limit As Long) As Long
    If Count >= Limit Then
        AppendString = 0
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 16
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > Limit Then
            NewCapacity = Limit
        End If
        If Capacity = 0 Then
            ReDim Values(NewCapacity - 1)
        Else
            ReDim Preserve Values(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Values(Count) = Value
    Count = Count + 1
    AppendString = 1
End Function
