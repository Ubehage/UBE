UBE SOURCE 1 MODULE
Attribute UBE_Name = "PortablePaths"

' Converts slash-separated or backslash-separated relative input to canonical
' slash form. Empty, absolute, drive-qualified, empty-segment, and parent paths
' return 0 and leave Normalized empty. The operation is host independent.
Public Function NormalizeCompilerRelativePath(ByVal Value As String, ByRef Normalized As String) As Long
    Normalized = ""
    Dim ValueLength As Long = StringLength(Value)
    If ValueLength = 0 Then
        NormalizeCompilerRelativePath = 0
        Exit Function
    End If
    Dim FirstByte As Long = StringByteAt(Value, 0)
    If FirstByte = 47 Or FirstByte = 92 Then
        NormalizeCompilerRelativePath = 0
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < ValueLength
        If StringByteAt(Value, Index) = 58 Then
            NormalizeCompilerRelativePath = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    Dim SegmentStart As Long = 0
    Index = 0
    While Index <= ValueLength
        Dim IsSeparator As Long = 0
        If Index = ValueLength Then
            IsSeparator = 1
        Else
            Dim CurrentByte As Long = StringByteAt(Value, Index)
            If CurrentByte = 47 Or CurrentByte = 92 Then IsSeparator = 1
        End If
        If IsSeparator <> 0 Then
            Dim SegmentLength As Long = Index - SegmentStart
            If SegmentLength = 0 Then
                Normalized = ""
                NormalizeCompilerRelativePath = 0
                Exit Function
            End If
            Dim Segment As String = StringSlice(Value, SegmentStart, SegmentLength)
            If Segment = ".." Then
                Normalized = ""
                NormalizeCompilerRelativePath = 0
                Exit Function
            End If
            If Segment <> "." Then
                If StringLength(Normalized) > 0 Then Normalized = Normalized & "/"
                Normalized = Normalized & Segment
            End If
            SegmentStart = Index + 1
        End If
        Index = Index + 1
    Wend
    If StringLength(Normalized) = 0 Then
        NormalizeCompilerRelativePath = 0
    Else
        NormalizeCompilerRelativePath = 1
    End If
End Function
