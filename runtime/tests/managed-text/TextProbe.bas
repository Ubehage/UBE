UBE SOURCE 1 MODULE
Attribute UBE_Name = "TextProbe"
' Native managed String acceptance client; no substitute storage implementation.

Private GlobalText As String
Private EvaluationTrace As Long
Private Type CaptionRecord
    Marker As Long
    Caption As String
End Type

Private Intrinsic Function ResizeTexts(ByRef Values() As String, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeTexts.UBE_Primitive = "Array.TryResize"
End Function

Private Function Echo(ByVal Value As String) As String
    On Error GoTo Failed
    Echo = Value
    Value = "callee changed"
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Sub ReplaceText(ByRef Value As String)
    Value = "replaced"
End Sub

Private Function StepText(ByVal Digit As Long, ByVal Value As String) As String
    On Error GoTo Failed
    EvaluationTrace = (EvaluationTrace * 10) + Digit
    StepText = Value
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Function FailedText() As String
    EvaluationTrace = (EvaluationTrace * 10) + 2
    Err.Raise 13
End Function

Private Function Evaluation() As Boolean
    Dim Value As String = "preserved"
    On Error GoTo Unexpected
    EvaluationTrace = 0
    Value = StepText(1, "A") & StepText(2, "B") & StepText(3, "C")
    If Value <> "ABC" Or EvaluationTrace <> 123 Then Exit Function
    Value = "preserved"
    EvaluationTrace = 0
    On Error GoTo Expected
    Value = StepText(1, "A") & FailedText() & StepText(3, "C")
    Exit Function
Expected:
    Evaluation = Value = "preserved" And EvaluationTrace = 12 And Err.Number = 13
    Exit Function
Unexpected:
    Evaluation = False
End Function

Private Function Worker(ByVal Payload As String, ByRef Output As String) As String
    On Error GoTo Failed
    Output = Payload & " child"
    Worker = "ignored result"
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Function Captures() As Boolean
    Dim Payload As String = "captured"
    Dim Output As String
    Dim Id As LongLong
    Dim IdText As String
    On Error GoTo Failed
    Id = CallNew Worker(Payload, Output)
    Payload = "parent changed"
    Call Memory.CollectGarbage()
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Then Exit Function
    If Output <> "captured child" Or Payload <> "parent changed" Then Exit Function
    ' Both the captured argument and returned thread ID cross String boundaries.
    IdText = CallNew Worker(42, Output)
    Id = IdText
    Call Memory.CollectGarbage()
    If ThreadPrimitives.Wait(Id, 5000) <> 1 Then Exit Function
    Captures = Output = "42 child"
    Exit Function
Failed:
    Captures = False
End Function

Private Function Aggregates() As Boolean
    Dim First As CaptionRecord
    Dim Second As CaptionRecord
    Dim Values() As String
    Dim Copies() As String
    On Error GoTo Failed
    GlobalText = Echo("global value")
    If GlobalText <> "global value" Then Exit Function
    First.Marker = 17
    First.Caption = Echo("record value")
    Second = First
    Call ReplaceText(First.Caption)
    If Second.Caption <> "record value" Or First.Caption <> "replaced" Or Second.Marker <> 17 Then Exit Function
    If First = Second Then Exit Function
    First.Caption = Echo("record value")
    If First <> Second Then Exit Function
    If Not ResizeTexts(Values, 3, False) Then Exit Function
    If Values(0) <> "" Or Values(1) <> "" Or Values(2) <> "" Then Exit Function
    Values(0) = Echo("zero")
    Values(1) = Second.Caption
    Values(2) = GlobalText
    Copies = Values
    Call ReplaceText(Values(1))
    Call Memory.CollectGarbage()
    If Copies(1) <> "record value" Or Values(1) <> "replaced" Then Exit Function
    If Not ResizeTexts(Values, 5, True) Then Exit Function
    If Values(0) <> "zero" Or Values(1) <> "replaced" Or Values(2) <> "global value" Or Values(3) <> "" Or Values(4) <> "" Then Exit Function
    Aggregates = True
    Exit Function
Failed:
    Aggregates = False
End Function

Private Function RoundTrip() As Boolean
    Dim Bytes(0 To 8) As Byte
    Dim Result() As Byte
    Dim Value As String
    Dim Copy As String
    Dim Index As Long
    On Error GoTo Failed
    ' U+0041, U+0000, U+20AC, U+1F642: four scalars in nine bytes.
    Bytes(0) = 65
    Bytes(1) = 0
    Bytes(2) = 226
    Bytes(3) = 130
    Bytes(4) = 172
    Bytes(5) = 240
    Bytes(6) = 159
    Bytes(7) = 153
    Bytes(8) = 130
    Call FilePrimitives.SetError(42)
    Value = Text.FromUtf8(Bytes, 0, 9)
    If Text.Length(Value) <> 4 Or Err.Number <> 42 Then Exit Function
    Copy = Value
    Value = "changed"
    Call Text.ToUtf8(Copy, Result)
    If BufferPrimitives.ByteStorageLength(Result) <> 9 Then Exit Function
    Do While Index < 9
        If Result(Index) <> Bytes(Index) Then Exit Function
        Index = Index + 1
    Loop
    Bytes(0) = 90
    Result(0) = 88
    Call Text.ToUtf8(Copy, Result)
    If Result(0) <> 65 Or Err.Number <> 42 Then Exit Function
    RoundTrip = True
    Exit Function
Failed:
    RoundTrip = False
End Function

Private Function Values() As Boolean
    Dim EmptyText As String
    Dim Value As String
    Dim Copy As String
    Dim Bytes() As Byte
    On Error GoTo Failed
    If Text.Length(EmptyText) <> 0 Then Exit Function
    Call Text.ToUtf8(EmptyText, Bytes)
    If BufferPrimitives.ByteStorageLength(Bytes) <> 0 Then Exit Function
    Value = "A" & "b" & "C"
    Copy = Value
    Value = "different"
    If Copy <> "AbC" Or Value <> "different" Then Exit Function
    If "a" <= "A" Or "ab" >= "abc" Or "abc" <> "abc" Then Exit Function
    If Text.CompareBinary("a", "A") <> 1 Then Exit Function
    If Text.CompareBinary("ab", "abc") <> -1 Then Exit Function
    If Text.Concat(EmptyText, Copy) <> Copy Then Exit Function
    If Text.Concat(Copy, EmptyText) <> Copy Then Exit Function
    Values = True
    Exit Function
Failed:
    Values = False
End Function

Private Function Conversion() As Boolean
    Dim Value As String
    On Error GoTo Failed
    Value = Text.FromInteger(-9223372036854775808&&)
    If Value <> "-9223372036854775808" Then Exit Function
    If Text.ToInteger(Value, -9223372036854775808&&, 9223372036854775807&&) <> -9223372036854775808&& Then Exit Function
    If Text.FromBoolean(True) <> "True" Or Text.FromBoolean(False) <> "False" Then Exit Function
    If Text.ToInteger("2.5", -100, 100) <> 2 Then Exit Function
    If Text.ToInteger("3.5", -100, 100) <> 4 Then Exit Function
    If Not Text.ToBoolean("1e-99999") Or Text.ToBoolean("-0.0") Then Exit Function
    Conversion = True
    Exit Function
Failed:
    Conversion = False
End Function

Private Function LanguageConversions() As Boolean
    Dim Value As String
    Dim Number As LongLong
    Dim Flag As Boolean
    On Error GoTo Failed
    Number = -9223372036854775808&&
    Value = Number
    If Value <> "-9223372036854775808" Then Exit Function
    Number = 0
    Number = Value
    If Number <> -9223372036854775808&& Then Exit Function
    Flag = True
    Value = Flag
    If Value <> "True" Then Exit Function
    Value = Echo("3.5")
    Number = Value
    If Number <> 4 Then Exit Function
    Value = Echo("1e-99999")
    Flag = Value
    If Not Flag Then Exit Function
    Number = 42
    Value = Number & Flag
    If Value <> "42True" Then Exit Function
    Value = "a""b"
    If Text.Length(Value) <> 3 Then Exit Function
    LanguageConversions = True
    Exit Function
Failed:
    LanguageConversions = False
End Function

Private Function ConversionFailure() As Boolean
    Dim Value As String
    Dim Number As Long = 73
    On Error GoTo Unexpected
    Value = Echo("2147483648")
    On Error GoTo Expected
    Number = Value
    Exit Function
Expected:
    ConversionFailure = Number = 73 And Err.Number = 6
    Exit Function
Unexpected:
    ConversionFailure = False
End Function

Private Function CollectionPressure() As Boolean
    Dim Retained As String
    Dim Value As String
    Dim Index As Long
    On Error GoTo Failed
    Retained = Echo("retained through pressure")
    Call FilePrimitives.SetError(42)
    ' Exercise repeated allocations beyond the former fixed block quota.
    Do While Index < 5000
        Value = "short-lived allocation"
        Index = Index + 1
    Loop
    Value = ""
    If Memory.CollectGarbage() <> 1 Or Err.Number <> 42 Then Exit Function
    If Memory.CollectGarbage() <> 0 Or Err.Number <> 42 Then Exit Function
    If Retained <> "retained through pressure" Then Exit Function
    CollectionPressure = True
    Exit Function
Failed:
    CollectionPressure = False
End Function

Private Function FillRetained(ByRef Values() As String, ByRef Stored As Long) As Boolean
    On Error GoTo Failed
    Do While Stored < 5000
        Values(Stored) = "retained"
        Stored = Stored + 1
    Loop
    FillRetained = True
Failed:
End Function

Private Function RetainedGrowth() As Boolean
    Dim Values() As String
    Dim Stored As Long
    Dim Value As String
    On Error GoTo Failed
    If Not ResizeTexts(Values, 5000, False) Then Exit Function
    If Not FillRetained(Values, Stored) Then Exit Function
    If Stored <> 5000 Then Exit Function
    Call Memory.CollectGarbage()
    If Text.Length(Values(0)) <> 8 Or Text.Length(Values(Stored - 1)) <> 8 Then Exit Function
    Values(0) = "replacement"
    If Values(0) <> "replacement" Or Values(Stored - 1) <> "retained" Then Exit Function
    If Not ResizeTexts(Values, 0, False) Then Exit Function
    Call FilePrimitives.SetError(42)
    If Memory.CollectGarbage() <> 1 Or Err.Number <> 42 Then Exit Function
    Value = Echo("recovered")
    RetainedGrowth = Value = "recovered" And Err.Number = 42
    Exit Function
Failed:
    RetainedGrowth = False
End Function

Private Function RejectMalformed() As Boolean
    Dim Bytes(0 To 1) As Byte
    Dim Value As String = "preserved"
    On Error GoTo Expected
    ' An overlong U+0000 must not publish a usable result.
    Bytes(0) = 192
    Bytes(1) = 128
    Value = Text.FromUtf8(Bytes, 0, 2)
    Exit Function
Expected:
    RejectMalformed = Err.Number = 13 And Value = "preserved"
End Function

Public Function Main() As Long
    On Error GoTo Failed
    If Not RoundTrip() Then Main = 1: Exit Function
    If Not Values() Then Main = 2: Exit Function
    If Not Conversion() Then Main = 3: Exit Function
    If Not RejectMalformed() Then Main = 4: Exit Function
    If Not Aggregates() Then Main = 5: Exit Function
    If Not Captures() Then Main = 6: Exit Function
    If Not Evaluation() Then Main = 7: Exit Function
    If Not LanguageConversions() Then Main = 8: Exit Function
    If Not ConversionFailure() Then Main = 9: Exit Function
    If Not CollectionPressure() Then Main = 10: Exit Function
    If Not RetainedGrowth() Then Main = 11: Exit Function
    Exit Function
Failed:
    Main = 250
End Function
