UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManifestProbe"
' Checks parser observations against independent runtime expectations.
' Reserves sentinel span storage for atomic-publication observations.
Private Intrinsic Function ResizeSpans(ByRef Values() As ProjectManifest.ValueSpan, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeSpans.UBE_Primitive = "Array.TryResize"
End Function
' Observes published storage independently of the metadata count.
Private Intrinsic Function SpanLength(ByRef Values() As ProjectManifest.ValueSpan) As Long
Attribute SpanLength.UBE_Primitive = "Array.Length"
End Function
' Compares every decoded byte against the independently supplied value.
Private Function SameBytes(ByRef A() As Byte, ByRef B() As Byte) As Boolean
    Dim I As Long
    Dim Count As Long
    Count = BufferPrimitives.ByteStorageLength(A)
    If Count <> BufferPrimitives.ByteStorageLength(B) Then Exit Function
    Do While I < Count
        If A(I) <> B(I) Then Exit Function
        I = I + 1
    Loop
    SameBytes = True
End Function
' Checks exact metadata, ordered values, diagnostics and preserved failure outputs.
Public Function CheckManifest(ByRef Text() As Byte, ByVal Code As Long, ByVal Count As Long, ByVal Executable As Boolean, ByVal Optimization As Long, ByVal DebugInfo As Long, ByRef ExpectedName() As Byte, ByRef First() As Byte, ByRef Last() As Byte, ByVal FirstLine As Long) As Long
    Dim Paths() As ProjectManifest.ValueSpan
    Dim Info As ProjectManifest.ManifestInfo
    Dim Diagnostic As ProjectManifest.ManifestDiagnostic
    Dim Decoded() As Byte
    Dim Status As Boolean
    If ResizeSpans(Paths, 1, False) = False Then CheckManifest = 1: Exit Function
    Paths(0).Start = 73
    Paths(0).Length = 74
    Paths(0).Line = 75
    Info.NameStart = 71
    Info.NameLength = 72
    Info.SourceCount = 76
    Info.IsExecutable = True
    Info.Optimization = 77
    Info.DebugInformation = 78
    Status = FilePrimitives.SetError(91)
    Status = ProjectManifest.TryParse(Text, Paths, Info, Diagnostic)
    If Diagnostic.Code <> Code Then CheckManifest = 2: Exit Function
    If Code <> 0 Then
        If Status Then CheckManifest = 3: Exit Function
        If Info.NameStart <> 71 Or Info.NameLength <> 72 Or Info.SourceCount <> 76 Or Info.IsExecutable = False Or Info.Optimization <> 77 Or Info.DebugInformation <> 78 Then CheckManifest = 4: Exit Function
        If SpanLength(Paths) <> 1 Then CheckManifest = 5: Exit Function
        If Paths(0).Start <> 73 Or Paths(0).Length <> 74 Or Paths(0).Line <> 75 Then CheckManifest = 6: Exit Function
        If Diagnostic.Line < 1 Or Diagnostic.Column < 1 Then CheckManifest = 7: Exit Function
        Exit Function
    End If
    If Status = False Or Diagnostic.Line <> 0 Or Diagnostic.Column <> 0 Then CheckManifest = 8: Exit Function
    If Err.Number <> 91 Then CheckManifest = 9: Exit Function
    If Info.SourceCount <> Count Or SpanLength(Paths) <> Count Then CheckManifest = 10: Exit Function
    If Info.IsExecutable <> Executable Or Info.Optimization <> Optimization Or Info.DebugInformation <> DebugInfo Then CheckManifest = 11: Exit Function
    If ProjectManifest.TryCopyValue(Text, Info.NameStart, Info.NameLength, Decoded) = False Then CheckManifest = 12: Exit Function
    If SameBytes(Decoded, ExpectedName) = False Then CheckManifest = 13: Exit Function
    If ProjectManifest.TryCopyValue(Text, Paths(0).Start, Paths(0).Length, Decoded) = False Then CheckManifest = 14: Exit Function
    If SameBytes(Decoded, First) = False Or Paths(0).Line <> FirstLine Then CheckManifest = 15: Exit Function
    If ProjectManifest.TryCopyValue(Text, Paths(Count - 1).Start, Paths(Count - 1).Length, Decoded) = False Then CheckManifest = 16: Exit Function
    If SameBytes(Decoded, Last) = False Then CheckManifest = 17: Exit Function
End Function
' Checks quoted-value decoding and bounded rejection without destination mutation.
Public Function CheckDecode(ByRef Text() As Byte, ByVal Start As Long, ByVal Length As Long, ByRef Expected() As Byte, ByVal Valid As Boolean) As Long
    Dim Result(0 To 0) As Byte
    Dim Status As Boolean
    Result(0) = 79
    Status = ProjectManifest.TryCopyValue(Text, Start, Length, Result)
    If Status <> Valid Then CheckDecode = 1: Exit Function
    If Valid Then
        If SameBytes(Result, Expected) = False Then CheckDecode = 2
    Else
        If BufferPrimitives.ByteStorageLength(Result) <> 1 Then CheckDecode = 3: Exit Function
        If Result(0) <> 79 Then CheckDecode = 4
    End If
End Function

