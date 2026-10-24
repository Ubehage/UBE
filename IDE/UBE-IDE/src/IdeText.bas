UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeText"

Sub IdeTrim(ByVal Value As String, ByRef Result As String)
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

Function IdeIsUtf8Continuation(ByVal ByteValue As Long) As Long
    If ByteValue >= 128 And ByteValue <= 191 Then
        IdeIsUtf8Continuation = 1
    Else
        IdeIsUtf8Continuation = 0
    End If
End Function

Function IdeUtf8SequenceLength(ByVal Contents As String, ByVal StartByte As Long, ByVal TotalLength As Long) As Long
    If StartByte < 0 Or StartByte >= TotalLength Then
        IdeUtf8SequenceLength = 0
        Exit Function
    End If
    Dim FirstByte As Long = StringByteAt(Contents, StartByte)
    If FirstByte < 128 Then
        IdeUtf8SequenceLength = 1
        Exit Function
    End If
    If FirstByte >= 194 And FirstByte <= 223 Then
        If StartByte + 1 < TotalLength Then
            If IdeIsUtf8Continuation(StringByteAt(Contents, StartByte + 1)) <> 0 Then
                IdeUtf8SequenceLength = 2
                Exit Function
            End If
        End If
        IdeUtf8SequenceLength = 0
        Exit Function
    End If
    If FirstByte >= 224 And FirstByte <= 239 Then
        If StartByte + 2 >= TotalLength Then
            IdeUtf8SequenceLength = 0
            Exit Function
        End If
        Dim SecondByte As Long = StringByteAt(Contents, StartByte + 1)
        Dim ThirdByte As Long = StringByteAt(Contents, StartByte + 2)
        If IdeIsUtf8Continuation(ThirdByte) = 0 Then
            IdeUtf8SequenceLength = 0
            Exit Function
        End If
        If FirstByte = 224 Then
            If SecondByte < 160 Or SecondByte > 191 Then
                IdeUtf8SequenceLength = 0
                Exit Function
            End If
        Else
            If FirstByte = 237 Then
                If SecondByte < 128 Or SecondByte > 159 Then
                    IdeUtf8SequenceLength = 0
                    Exit Function
                End If
            Else
                If IdeIsUtf8Continuation(SecondByte) = 0 Then
                    IdeUtf8SequenceLength = 0
                    Exit Function
                End If
            End If
        End If
        IdeUtf8SequenceLength = 3
        Exit Function
    End If
    If FirstByte >= 240 And FirstByte <= 244 Then
        If StartByte + 3 >= TotalLength Then
            IdeUtf8SequenceLength = 0
            Exit Function
        End If
        Dim SecondFourByte As Long = StringByteAt(Contents, StartByte + 1)
        If FirstByte = 240 Then
            If SecondFourByte < 144 Or SecondFourByte > 191 Then
                IdeUtf8SequenceLength = 0
                Exit Function
            End If
        Else
            If FirstByte = 244 Then
                If SecondFourByte < 128 Or SecondFourByte > 143 Then
                    IdeUtf8SequenceLength = 0
                    Exit Function
                End If
            Else
                If IdeIsUtf8Continuation(SecondFourByte) = 0 Then
                    IdeUtf8SequenceLength = 0
                    Exit Function
                End If
            End If
        End If
        If IdeIsUtf8Continuation(StringByteAt(Contents, StartByte + 2)) = 0 Or IdeIsUtf8Continuation(StringByteAt(Contents, StartByte + 3)) = 0 Then
            IdeUtf8SequenceLength = 0
            Exit Function
        End If
        IdeUtf8SequenceLength = 4
        Exit Function
    End If
    IdeUtf8SequenceLength = 0
End Function

Function IdeValidateUtf8(ByVal Contents As String, ByRef InvalidByte As Long) As Long
    Dim TotalLength As Long = StringLength(Contents)
    Dim Index As Long = 0
    While Index < TotalLength
        Dim SequenceLength As Long = IdeUtf8SequenceLength(Contents, Index, TotalLength)
        If SequenceLength = 0 Then
            InvalidByte = Index
            IdeValidateUtf8 = 0
            Exit Function
        End If
        Index = Index + SequenceLength
    Wend
    InvalidByte = -1
    IdeValidateUtf8 = 1
End Function

Function IdeDecodeUtf8CodePoint(ByVal Value As String, ByVal StartByte As Long, ByRef CodePoint As Long, ByRef ByteCount As Long) As Long
    ByteCount = IdeUtf8SequenceLength(Value, StartByte, StringLength(Value))
    If ByteCount = 0 Then
        IdeDecodeUtf8CodePoint = 0
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
    IdeDecodeUtf8CodePoint = 1
End Function

Function IdeEqualsFolded(ByVal LeftValue As String, ByVal RightValue As String) As Long
    Dim LeftIndex As Long = 0
    Dim RightIndex As Long = 0
    Dim LeftLength As Long = StringLength(LeftValue)
    Dim RightLength As Long = StringLength(RightValue)
    While LeftIndex < LeftLength And RightIndex < RightLength
        Dim LeftCodePoint As Long = 0
        Dim RightCodePoint As Long = 0
        Dim LeftBytes As Long = 0
        Dim RightBytes As Long = 0
        If IdeDecodeUtf8CodePoint(LeftValue, LeftIndex, LeftCodePoint, LeftBytes) = 0 Or IdeDecodeUtf8CodePoint(RightValue, RightIndex, RightCodePoint, RightBytes) = 0 Then
            IdeEqualsFolded = 0
            Exit Function
        End If
        If UnicodeSimpleFoldCodePoint(LeftCodePoint) <> UnicodeSimpleFoldCodePoint(RightCodePoint) Then
            IdeEqualsFolded = 0
            Exit Function
        End If
        LeftIndex = LeftIndex + LeftBytes
        RightIndex = RightIndex + RightBytes
    Wend
    If LeftIndex = LeftLength And RightIndex = RightLength Then
        IdeEqualsFolded = 1
    Else
        IdeEqualsFolded = 0
    End If
End Function

Function IdeStartsWith(ByVal Value As String, ByVal Prefix As String) As Long
    Dim PrefixLength As Long = StringLength(Prefix)
    If StringLength(Value) < PrefixLength Then
        IdeStartsWith = 0
        Exit Function
    End If
    If StringSlice(Value, 0, PrefixLength) = Prefix Then
        IdeStartsWith = 1
    Else
        IdeStartsWith = 0
    End If
End Function

Function IdeReadLine(ByVal Contents As String, ByRef Cursor As Long, ByRef LineText As String) As Long
    Dim Length As Long = StringLength(Contents)
    If Cursor >= Length Then
        LineText = ""
        IdeReadLine = 0
        Exit Function
    End If
    Dim Start As Long = Cursor
    While Cursor < Length And StringByteAt(Contents, Cursor) <> 10
        Cursor = Cursor + 1
    Wend
    LineText = StringSlice(Contents, Start, Cursor - Start)
    If Cursor < Length Then
        Cursor = Cursor + 1
    End If
    If StringLength(LineText) > 0 Then
        If StringByteAt(LineText, StringLength(LineText) - 1) = 13 Then
            LineText = StringSlice(LineText, 0, StringLength(LineText) - 1)
        End If
    End If
    IdeReadLine = 1
End Function

Function IdeParseAssignment(ByVal LineText As String, ByRef Key As String, ByRef Value As String) As Long
    Dim EqualsIndex As Long = StringIndexOf(LineText, "=", 0)
    If EqualsIndex < 1 Then
        IdeParseAssignment = 0
        Exit Function
    End If
    Call IdeTrim(StringSlice(LineText, 0, EqualsIndex), Key)
    Dim RawValue As String = ""
    Call IdeTrim(StringSlice(LineText, EqualsIndex + 1, StringLength(LineText) - EqualsIndex - 1), RawValue)
    If StringLength(Key) = 0 Or StringLength(RawValue) < 2 Then
        IdeParseAssignment = 0
        Exit Function
    End If
    If StringByteAt(RawValue, 0) <> 34 Or StringByteAt(RawValue, StringLength(RawValue) - 1) <> 34 Then
        IdeParseAssignment = 0
        Exit Function
    End If
    Value = ""
    Dim ValueIndex As Long = 1
    Dim ValueLast As Long = StringLength(RawValue) - 1
    While ValueIndex < ValueLast
        Dim CurrentByte As Long = StringByteAt(RawValue, ValueIndex)
        If CurrentByte = 34 Then
            If ValueIndex + 1 >= ValueLast Or StringByteAt(RawValue, ValueIndex + 1) <> 34 Then
                IdeParseAssignment = 0
                Exit Function
            End If
            Value = Value & StringFromByte(34)
            ValueIndex = ValueIndex + 2
        Else
            Value = Value & StringSlice(RawValue, ValueIndex, 1)
            ValueIndex = ValueIndex + 1
        End If
    Wend
    IdeParseAssignment = 1
End Function

Function IdeNormalizeRelativePath(ByVal Path As String, ByRef Normalized As String) As Long
    Normalized = ""
    Dim PathLength As Long = StringLength(Path)
    If PathLength = 0 Then
        IdeNormalizeRelativePath = 0
        Exit Function
    End If
    If StringByteAt(Path, 0) = 47 Or StringByteAt(Path, 0) = 92 Or StringIndexOf(Path, ":", 0) >= 0 Then
        IdeNormalizeRelativePath = 0
        Exit Function
    End If
    Dim SegmentStart As Long = 0
    Dim Index As Long = 0
    While Index <= PathLength
        Dim IsSeparator As Long = 0
        If Index = PathLength Then
            IsSeparator = 1
        Else
            Dim CurrentByte As Long = StringByteAt(Path, Index)
            If CurrentByte = 47 Or CurrentByte = 92 Then
                IsSeparator = 1
            End If
        End If
        If IsSeparator <> 0 Then
            Dim SegmentLength As Long = Index - SegmentStart
            If SegmentLength = 0 Then
                IdeNormalizeRelativePath = 0
                Exit Function
            End If
            Dim Segment As String = StringSlice(Path, SegmentStart, SegmentLength)
            If Segment = ".." Then
                IdeNormalizeRelativePath = 0
                Exit Function
            End If
            If Segment <> "." Then
                If StringLength(Normalized) > 0 Then
                    Normalized = Normalized & "/"
                End If
                Normalized = Normalized & Segment
            End If
            SegmentStart = Index + 1
        End If
        Index = Index + 1
    Wend
    If StringLength(Normalized) = 0 Then
        IdeNormalizeRelativePath = 0
    Else
        IdeNormalizeRelativePath = 1
    End If
End Function

Function IdeParseNonnegativeLong(ByVal Value As String, ByRef Result As Long) As Long
    If StringLength(Value) = 0 Then
        IdeParseNonnegativeLong = 0
        Exit Function
    End If
    Dim Parsed As Long = 0
    Dim Index As Long = 0
    While Index < StringLength(Value)
        Dim Digit As Long = StringByteAt(Value, Index) - 48
        If Digit < 0 Or Digit > 9 Then
            IdeParseNonnegativeLong = 0
            Exit Function
        End If
        If Parsed > 214748364 Then
            IdeParseNonnegativeLong = 0
            Exit Function
        End If
        Parsed = Parsed * 10 + Digit
        If Parsed < 0 Then
            IdeParseNonnegativeLong = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    Result = Parsed
    IdeParseNonnegativeLong = 1
End Function
