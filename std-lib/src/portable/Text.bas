UBE SOURCE 1 MODULE
Attribute UBE_Name = "Text"
' Unicode text algorithms over immutable, precisely rooted UTF-8 storage.

' Counts Unicode scalar values, including embedded zero.
Public Function Length(ByRef Value As String) As LongLong
    On Error GoTo Failed
    Length = TextPrimitives.ScalarLength(Value)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Copies a logical byte span before validation, then publishes one complete value.
Public Function FromUtf8(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Count As Long) As String
    Dim Snapshot() As Byte
    Dim Capacity As Long
    Dim Position As Long
    Dim Scalar As Long
    Dim ByteWidth As Long
    Dim Scalars As LongLong
    Dim Candidate As LongLong
    Dim Failure As Long
    On Error GoTo Failed
    If Count < 0 Then Err.Raise 5
    Capacity = BufferPrimitives.ByteStorageLength(Bytes)
    If Offset < 0 Or Offset > Capacity Then Err.Raise 9
    If Count > Capacity - Offset Then Err.Raise 9
    If Count = 0 Then Exit Function
    If Not BufferPrimitives.TryResizeBytes(Snapshot, Count, False) Then GoTo Failed
    If Not BufferPrimitives.CopyByteRange(Bytes, Offset, Snapshot, 0, Count) Then GoTo Failed
    Do While Position < Count
        If Not Utf8.TryDecodeScalar(Snapshot, Position, Count, Scalar, ByteWidth) Then Err.Raise 13
        Scalars = Scalars + 1
        Position = Position + ByteWidth
    Loop
    If Not TextPrimitives.TryCreate(Count, Scalars, Candidate) Then GoTo Failed
    Position = 0
    Do While Position < Count
        If Not TextPrimitives.TryWriteByte(Candidate, Position, Snapshot(Position)) Then GoTo Failed
        Position = Position + 1
    Loop
    If Not TextPrimitives.TryPublish(FromUtf8, Candidate) Then GoTo Failed
    Candidate = 0
    Exit Function
Failed:
    Failure = Err.Number
    Call TextPrimitives.TryAbandon(Candidate)
    Err.Raise Failure
End Function

' Publishes an independent zero-based byte array only after complete copying.
Public Sub ToUtf8(ByRef Value As String, ByRef Result() As Byte)
    Dim Snapshot As String
    Dim Bytes() As Byte
    Dim Size As LongLong
    Dim Count As Long
    Dim Position As Long
    Dim Code As Byte
    On Error GoTo Failed
    Snapshot = Value
    Size = TextPrimitives.ByteLength(Snapshot)
    If Size > 2147483647 Then Err.Raise 7
    Count = Size
    If Not BufferPrimitives.TryResizeBytes(Bytes, Count, False) Then Err.Raise Err.Number
    Do While Position < Count
        If Not TextPrimitives.TryReadByte(Snapshot, Position, Code) Then Err.Raise Err.Number
        Bytes(Position) = Code
        Position = Position + 1
    Loop
    If Not BufferPrimitives.TryMoveBytes(Result, Bytes) Then Err.Raise Err.Number
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub

' Compiler-selected concatenation keeps both input values rooted throughout construction.
Public Function Concat(ByVal Left As String, ByVal Right As String) As String
    Dim LeftBytes As LongLong
    Dim RightBytes As LongLong
    Dim Scalars As LongLong
    Dim Candidate As LongLong
    Dim Position As LongLong
    Dim Code As Byte
    Dim Failure As Long
    On Error GoTo Failed
    LeftBytes = TextPrimitives.ByteLength(Left)
    RightBytes = TextPrimitives.ByteLength(Right)
    If LeftBytes > 9223372036854775807^ - RightBytes Then Err.Raise 7
    Scalars = TextPrimitives.ScalarLength(Left) + TextPrimitives.ScalarLength(Right)
    If Not TextPrimitives.TryCreate(LeftBytes + RightBytes, Scalars, Candidate) Then GoTo Failed
    Do While Position < LeftBytes
        If Not TextPrimitives.TryReadByte(Left, Position, Code) Then GoTo Failed
        If Not TextPrimitives.TryWriteByte(Candidate, Position, Code) Then GoTo Failed
        Position = Position + 1
    Loop
    Position = 0
    Do While Position < RightBytes
        If Not TextPrimitives.TryReadByte(Right, Position, Code) Then GoTo Failed
        If Not TextPrimitives.TryWriteByte(Candidate, LeftBytes + Position, Code) Then GoTo Failed
        Position = Position + 1
    Loop
    If Not TextPrimitives.TryPublish(Concat, Candidate) Then GoTo Failed
    Candidate = 0
    Exit Function
Failed:
    Failure = Err.Number
    Call TextPrimitives.TryAbandon(Candidate)
    Err.Raise Failure
End Function

' Canonical UTF-8 byte order is Unicode scalar order; prefix length breaks ties.
Public Function CompareBinary(ByVal Left As String, ByVal Right As String) As Long
    Dim LeftBytes As LongLong
    Dim RightBytes As LongLong
    Dim Position As LongLong
    Dim LeftCode As Byte
    Dim RightCode As Byte
    On Error GoTo Failed
    LeftBytes = TextPrimitives.ByteLength(Left)
    RightBytes = TextPrimitives.ByteLength(Right)
    Do While Position < LeftBytes And Position < RightBytes
        If Not TextPrimitives.TryReadByte(Left, Position, LeftCode) Then Err.Raise Err.Number
        If Not TextPrimitives.TryReadByte(Right, Position, RightCode) Then Err.Raise Err.Number
        If LeftCode < RightCode Then CompareBinary = -1: Exit Function
        If LeftCode > RightCode Then CompareBinary = 1: Exit Function
        Position = Position + 1
    Loop
    If LeftBytes < RightBytes Then CompareBinary = -1
    If LeftBytes > RightBytes Then CompareBinary = 1
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Formats the exact admitted integer value without locale or floating point.
Public Function FromInteger(ByVal Value As LongLong) As String
    Dim Bytes(0 To 19) As Byte
    Dim Used As Long
    On Error GoTo Failed
    If Not ByteText.TryAppendInteger(Bytes, Used, Value) Then Err.Raise Err.Number
    FromInteger = FromUtf8(Bytes, 0, Used)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Uses the language's invariant Boolean words.
Public Function FromBoolean(ByVal Value As Boolean) As String
    Dim Bytes(0 To 4) As Byte
    Dim Used As Long
    On Error GoTo Failed
    If Not ByteText.TryAppendBoolean(Bytes, Used, Value) Then Err.Raise Err.Number
    FromBoolean = FromUtf8(Bytes, 0, Used)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Exact decimal rounding and range checking use the shared counted-byte parser.
Public Function ToInteger(ByVal Value As String, ByVal Minimum As LongLong, ByVal Maximum As LongLong) As LongLong
    Dim Bytes() As Byte
    Dim Result As LongLong
    On Error GoTo Failed
    Call ToUtf8(Value, Bytes)
    If Not InvariantNumbers.TryParseInteger(Bytes, 0, BufferPrimitives.ByteStorageLength(Bytes), Minimum, Maximum, Result) Then Err.Raise Err.Number
    ToInteger = Result
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Numeric Boolean conversion tests mathematical zero, independently of rounding.
Public Function ToBoolean(ByVal Value As String) As Boolean
    Dim Bytes() As Byte
    Dim Result As Boolean
    On Error GoTo Failed
    Call ToUtf8(Value, Bytes)
    If Not InvariantNumbers.TryParseBoolean(Bytes, 0, BufferPrimitives.ByteStorageLength(Bytes), Result) Then Err.Raise Err.Number
    ToBoolean = Result
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
