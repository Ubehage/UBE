UBE SOURCE 1 MODULE
Attribute UBE_Name = "BufferProbe"
' Observes payload-relative primitives and ordinary UBECore append publication.
Public Type Entry
    Offset As LongLong
    Length As Long
End Type
Private FollowingCalls As Long
Private HandlerEntries As Long

' Uses a deliberately different declaration spelling for the same documented role.
Public Intrinsic Function CountEntries(ByRef Values() As Entry) As Long
Attribute countentries.ube_primitive = "ARRAY.LENGTH"
End Function

' Uses a deliberately different copy declaration spelling to test explicit identity.
Public Intrinsic Function MovePayload(ByRef FromValues() As Byte, ByVal FromStart As Long, ByRef ToValues() As Byte, ByVal ToStart As Long, ByVal Amount As Long) As Boolean
Attribute MovePayload.UBE_Primitive = "Memory.CopyBytes"
End Function

' Establishes a sticky error through a normal failing procedure.
Public Sub RaiseFive()
    Err.Raise 5
End Sub

' Must be evaluated after an ordinary False-returning primitive in an eager expression.
Public Function FollowingTrue() As Boolean
    FollowingCalls = FollowingCalls + 1
    FollowingTrue = True
End Function

' An ordinary similarly named function must retain its source implementation.
Public Function CopyByteRange() As Long
    CopyByteRange = 73
End Function

' Checks logical lengths, both overlap directions and zero-count endpoint rules.
Public Function CheckCopies(ByVal Seed As Long) As Long
    Dim Values(-3 To 2) As Byte
    Dim Destination(10 To 15) As Byte
    Dim Entries(4 To 6) As Entry
    Dim SingleByte(-9223372036854775808^ To -9223372036854775808^) As Byte
    Dim Status As Boolean
    Dim Value As Long
    Values(-3) = 1
    Values(-2) = 2
    Values(-1) = 3
    Values(0) = 4
    Values(1) = 5
    Values(2) = 6
    RaiseFive
    Value = BufferPrimitives.ByteStorageLength(Values)
    If Value <> 6 Then CheckCopies = 1: Exit Function
    Value = CountEntries(Entries)
    If Value <> 3 Then CheckCopies = 2: Exit Function
    Value = BufferPrimitives.ByteStorageLength(SingleByte)
    If Value <> 1 Then CheckCopies = 17: Exit Function
    If Err.Number <> 5 Then CheckCopies = 3: Exit Function
    Status = MovePayload(Values, 0, Values, Seed, 5)
    If Status <> True Then CheckCopies = 4: Exit Function
    Value = Values(-2)
    If Value <> 1 Then CheckCopies = 5: Exit Function
    Value = Values(2)
    If Value <> 5 Then CheckCopies = 6: Exit Function
    If Err.Number <> 5 Then CheckCopies = 7: Exit Function
    Status = MovePayload(Values, Seed, Values, 0, 5)
    If Status <> True Then CheckCopies = 8: Exit Function
    Value = Values(-3)
    If Value <> 1 Then CheckCopies = 9: Exit Function
    Value = Values(1)
    If Value <> 5 Then CheckCopies = 10: Exit Function
    Status = MovePayload(Values, 0, Values, 0, 6)
    If Status <> True Then CheckCopies = 11: Exit Function
    Status = MovePayload(Values, 6, Destination, 6, 0)
    If Status <> True Then CheckCopies = 12: Exit Function
    Status = MovePayload(Values, Seed, Destination, 2, 2)
    If Status <> True Then CheckCopies = 13: Exit Function
    Value = Destination(12)
    If Value <> 2 Then CheckCopies = 14: Exit Function
    Value = Destination(13)
    If Value <> 3 Then CheckCopies = 15: Exit Function
    Value = CopyByteRange()
    If Value <> 73 Then CheckCopies = 16: Exit Function
    CheckCopies = 0
End Function

' False is a usable result, does not enter handlers, and does not skip later operands.
Public Function CheckStatus(ByVal Seed As Long) As Long
    Dim Source(0 To 2) As Byte
    Dim Destination(-1 To 1) As Byte
    Dim Status As Boolean = True
    Dim Offset As Long
    Dim Value As Long
    Destination(-1) = 11
    Destination(0) = 22
    Destination(1) = 33
    On Error GoTo Unexpected
    Offset = -Seed
    Status = MovePayload(Source, 0, Destination, 0, Offset) And FollowingTrue()
    If Status <> False Then CheckStatus = 1: Exit Function
    If Err.Number <> 5 Then CheckStatus = 2: Exit Function
    If FollowingCalls <> 1 Then CheckStatus = 3: Exit Function
    Status = MovePayload(Source, Offset, Destination, 0, 1)
    If Status <> False Then CheckStatus = 4: Exit Function
    If Err.Number <> 9 Then CheckStatus = 5: Exit Function
    Status = MovePayload(Source, 0, Destination, Offset, 1)
    If Status <> False Then CheckStatus = 6: Exit Function
    Offset = 2147483647
    Status = MovePayload(Source, Offset, Destination, 0, Seed)
    If Status <> False Then CheckStatus = 7: Exit Function
    Status = MovePayload(Source, 0, Destination, Offset, Seed)
    If Status <> False Then CheckStatus = 8: Exit Function
    Status = MovePayload(Source, 0, Destination, 0, Offset)
    If Status <> False Then CheckStatus = 9: Exit Function
    Offset = -2147483648&
    Status = MovePayload(Source, 0, Destination, 0, Offset)
    If Status <> False Then CheckStatus = 20: Exit Function
    If Err.Number <> 5 Then CheckStatus = 21: Exit Function
    Status = MovePayload(Source, Offset, Destination, 0, Seed)
    If Status <> False Then CheckStatus = 22: Exit Function
    If Err.Number <> 9 Then CheckStatus = 23: Exit Function
    Status = MovePayload(Source, 0, Destination, Offset, Seed)
    If Status <> False Then CheckStatus = 24: Exit Function
    Status = MovePayload(Source, 2, Destination, 0, Seed + 1)
    If Status <> False Then CheckStatus = 10: Exit Function
    Status = MovePayload(Source, 0, Destination, 2, Seed + 1)
    If Status <> False Then CheckStatus = 11: Exit Function
    Status = MovePayload(Source, 3 + Seed, Destination, 3, 0)
    If Status <> False Then CheckStatus = 12: Exit Function
    Status = MovePayload(Source, 3, Destination, 3, 0)
    If Status <> True Then CheckStatus = 13: Exit Function
    If Err.Number <> 9 Then CheckStatus = 14: Exit Function
    Value = Destination(-1)
    If Value <> 11 Then CheckStatus = 15: Exit Function
    Value = Destination(0)
    If Value <> 22 Then CheckStatus = 16: Exit Function
    Value = Destination(1)
    If Value <> 33 Then CheckStatus = 17: Exit Function
    If HandlerEntries <> 0 Then CheckStatus = 18: Exit Function
    CheckStatus = 0
    Exit Function
Unexpected:
    HandlerEntries = HandlerEntries + 1
    CheckStatus = 19
End Function

' Verifies the ordinary wrapper's validation raises without changing storage or counts.
Public Function CheckAppendValidation(ByVal Seed As Long) As Long
    Dim Source(0 To 0) As Byte
    Dim Destination(0 To 1) As Byte
    Dim Used As Long = -Seed
    Dim Result As Long = 77
    Dim Value As Long
    Dim ExpectedUsed As Long = Used
    Destination(0) = 41
    Destination(1) = 42
    Result = ByteBuffers.AppendBytes(Destination, Used, Source, 0, 1)
    If Result <> 77 Then CheckAppendValidation = 1: Exit Function
    If Used <> ExpectedUsed Then CheckAppendValidation = 2: Exit Function
    If Err.Number <> 5 Then CheckAppendValidation = 3: Exit Function
    Used = 0
    Result = ByteBuffers.AppendBytes(Destination, Used, Source, 0, -Seed)
    If Result <> 77 Then CheckAppendValidation = 4: Exit Function
    If Used <> 0 Then CheckAppendValidation = 5: Exit Function
    If Err.Number <> 5 Then CheckAppendValidation = 6: Exit Function
    Used = 2 + Seed
    ExpectedUsed = Used
    Result = ByteBuffers.AppendBytes(Destination, Used, Source, 0, 0)
    If Result <> 77 Then CheckAppendValidation = 7: Exit Function
    If Used <> ExpectedUsed Then CheckAppendValidation = 8: Exit Function
    If Err.Number <> 9 Then CheckAppendValidation = 9: Exit Function
    Value = Destination(0)
    If Value <> 41 Then CheckAppendValidation = 10: Exit Function
    Value = Destination(1)
    If Value <> 42 Then CheckAppendValidation = 11: Exit Function
    CheckAppendValidation = 0
End Function

' A failing argument conversion remains language FAIL rather than primitive False.
Public Function CheckConversion(ByVal Seed As Long) As Long
    Dim Source(0 To 1) As Byte
    Dim Destination(0 To 1) As Byte
    Dim WideCount As LongLong = 2147483647^ + Seed
    Dim Status As Boolean = True
    Dim Value As Long
    Destination(0) = 88
    On Error GoTo Narrowed
    Status = BufferPrimitives.CopyByteRange(Source, 0, Destination, 0, WideCount)
    CheckConversion = 1
    Exit Function
Narrowed:
    If Status <> True Then CheckConversion = 2: Exit Function
    If Err.Number <> 6 Then CheckConversion = 3: Exit Function
    Value = Destination(0)
    If Value <> 88 Then CheckConversion = 4: Exit Function
    CheckConversion = 0
End Function

' Ordinary UBECore appends commit Used only after copying and propagate real FAIL.
Public Function CheckAppend(ByVal Seed As Long) As Long
    Dim Source(-2 To 0) As Byte
    Dim Destination(5 To 9) As Byte
    Dim Used As Long = Seed
    Dim Result As Long = 77
    Dim Value As Long
    Source(-2) = 97
    Source(-1) = 195
    Source(0) = 164
    Destination(5) = 43
    RaiseFive
    Result = ByteBuffers.AppendBytes(Destination, Used, Source, 0, 3)
    If Result <> 4 Then CheckAppend = 1: Exit Function
    If Used <> 4 Then CheckAppend = 2: Exit Function
    If Err.Number <> 5 Then CheckAppend = 3: Exit Function
    Value = Destination(6)
    If Value <> 97 Then CheckAppend = 4: Exit Function
    Value = Destination(8)
    If Value <> 164 Then CheckAppend = 5: Exit Function
    Result = 77
    Result = ByteBuffers.AppendBytes(Destination, Used, Source, 0, 2)
    If Result <> 77 Then CheckAppend = 6: Exit Function
    If Used <> 4 Then CheckAppend = 7: Exit Function
    If Err.Number <> 9 Then CheckAppend = 8: Exit Function
    Value = Destination(9)
    If Value <> 0 Then CheckAppend = 9: Exit Function
    On Error GoTo Failed
    Result = ByteBuffers.AppendBytes(Destination, Used, Source, -Seed, 1)
    CheckAppend = 10
    Exit Function
Failed:
    If Result <> 77 Then CheckAppend = 11: Exit Function
    If Used <> 4 Then CheckAppend = 12: Exit Function
    If Err.Number <> 9 Then CheckAppend = 13: Exit Function
    Value = Destination(9)
    If Value <> 0 Then CheckAppend = 14: Exit Function
    CheckAppend = 0
End Function
