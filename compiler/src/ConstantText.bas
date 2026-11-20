UBE SOURCE 1 MODULE
Attribute UBE_Name = "ConstantText"
' Owns immutable UTF-8 spans in a request-local, zero-based constant arena.

' Checks a logical span without overflow; unused arena capacity is not a value.
Private Function ValidSpan(ByVal Used As Long, ByVal Start As Long, ByVal Length As Long) As Boolean
    If Used < 0 Or Start < 0 Or Length < 0 Or Start > Used Then Exit Function
    ValidSpan = Length <= Used - Start
End Function

' Appends an already canonical byte span; callers retain source ownership during the operation.
Public Function TryAppendBytes(ByRef Source() As Byte, ByVal SourceStart As Long, ByVal SourceLength As Long, ByRef Arena() As Byte, ByRef Used As Long, ByRef Start As Long, ByRef Length As Long) As Boolean
    On Error GoTo Failed
    If Not ValidSpan(BufferPrimitives.ByteStorageLength(Source), SourceStart, SourceLength) Then Exit Function
    If Not Reserve(Arena, Used, SourceLength) Then Exit Function
    If Not BufferPrimitives.CopyByteRange(Source, SourceStart, Arena, Used, SourceLength) Then Exit Function
    Start = Used
    Length = SourceLength
    Used = Used + SourceLength
    TryAppendBytes = True
    Exit Function
Failed:
    TryAppendBytes = False
End Function

' Reserves growth without changing the published logical prefix.
Private Function Reserve(ByRef Arena() As Byte, ByVal Used As Long, ByVal Additional As Long) As Boolean
    Dim Capacity As Long
    Dim Required As Long
    Dim Growth As Long
    Dim Endpoint As Byte
    On Error GoTo Failed
    Capacity = BufferPrimitives.ByteStorageLength(Arena)
    If Used < 0 Or Used > Capacity Or Additional < 0 Then Exit Function
    If Additional > 2147483647 - Used Then Exit Function
    If Capacity > 0 Then
        Endpoint = Arena(0)
        Endpoint = Arena(Capacity - 1)
    End If
    Required = Used + Additional
    If Required <= Capacity Then Reserve = True: Exit Function
    Growth = Capacity
    If Growth < 64 Then Growth = 64
    Do While Growth < Required
        If Growth > 1073741823 Then Growth = Required: Exit Do
        Growth = Growth * 2
    Loop
    Reserve = BufferPrimitives.TryResizeBytes(Arena, Growth, True)
    Exit Function
Failed:
    Reserve = False
End Function

' Counts a quoted source spelling, checking quotes and canonical UTF-8 before allocation.
Private Function LiteralLength(ByRef Source() As Byte, ByVal Start As Long, ByVal Length As Long, ByRef DecodedLength As Long) As Boolean
    Dim Position As Long
    Dim Finish As Long
    Dim Count As Long
    Dim ByteWidth As Long
    Dim Utf16Width As Long
    Dim Value As Long
    On Error GoTo Failed
    If Not ValidSpan(BufferPrimitives.ByteStorageLength(Source), Start, Length) Then Exit Function
    If Length < 2 Then Exit Function
    Finish = Start + Length - 1
    If Source(Start) <> 34 Or Source(Finish) <> 34 Then Exit Function
    Position = Start + 1
    Do While Position < Finish
        Value = Source(Position)
        If Value = 10 Or Value = 13 Then Exit Function
        If Value = 34 Then
            If Position + 1 >= Finish Then Exit Function
            If Source(Position + 1) <> 34 Then Exit Function
            Position = Position + 2
            Count = Count + 1
        Else
            If Not Utf8.TrySequenceWidth(Source, Position, Finish, ByteWidth, Utf16Width) Then Exit Function
            Position = Position + ByteWidth
            Count = Count + ByteWidth
        End If
    Loop
    DecodedLength = Count
    LiteralLength = True
    Exit Function
Failed:
    LiteralLength = False
End Function

' Appends literal bytes without case folding; only a successful append publishes its span.
' Source and Arena must be distinct; outputs must also be distinct caller-owned variables.
Public Function TryAppendLiteral(ByRef Source() As Byte, ByVal SourceStart As Long, ByVal SourceLength As Long, ByRef Arena() As Byte, ByRef Used As Long, ByRef Start As Long, ByRef Length As Long) As Boolean
    Dim Count As Long
    Dim Position As Long
    Dim Finish As Long
    Dim Written As Long
    Dim Value As Byte
    On Error GoTo Failed
    If Not LiteralLength(Source, SourceStart, SourceLength, Count) Then Exit Function
    If Not Reserve(Arena, Used, Count) Then Exit Function
    Position = SourceStart + 1
    Finish = SourceStart + SourceLength - 1
    Do While Position < Finish
        Value = Source(Position)
        Position = Position + 1
        If Value = 34 Then Position = Position + 1
        Arena(Used + Written) = Value
        Written = Written + 1
    Loop
    Start = Used
    Length = Count
    Used = Used + Count
    TryAppendLiteral = True
    Exit Function
Failed:
    TryAppendLiteral = False
End Function

' Materializes concatenation after validating both immutable source spans and reserving once.
Public Function TryConcatenate(ByRef Arena() As Byte, ByRef Used As Long, ByVal LeftStart As Long, ByVal LeftLength As Long, ByVal RightStart As Long, ByVal RightLength As Long, ByRef Start As Long, ByRef Length As Long) As Boolean
    Dim Count As Long
    On Error GoTo Failed
    If Not ValidSpan(Used, LeftStart, LeftLength) Then Exit Function
    If Not ValidSpan(Used, RightStart, RightLength) Then Exit Function
    If RightLength > 2147483647 - LeftLength Then Exit Function
    Count = LeftLength + RightLength
    If Not Reserve(Arena, Used, Count) Then Exit Function
    If Not BufferPrimitives.CopyByteRange(Arena, LeftStart, Arena, Used, LeftLength) Then Exit Function
    If Not BufferPrimitives.CopyByteRange(Arena, RightStart, Arena, Used + LeftLength, RightLength) Then Exit Function
    Start = Used
    Length = Count
    Used = Used + Count
    TryConcatenate = True
    Exit Function
Failed:
    TryConcatenate = False
End Function

' Canonical UTF-8 lexical byte order is Unicode scalar order, independent of the host locale.
Public Function TryCompare(ByRef Arena() As Byte, ByVal Used As Long, ByVal LeftStart As Long, ByVal LeftLength As Long, ByVal RightStart As Long, ByVal RightLength As Long, ByRef Result As Long) As Boolean
    Dim Index As Long
    Dim Value As Long
    On Error GoTo Failed
    If Used > BufferPrimitives.ByteStorageLength(Arena) Then Exit Function
    If Not ValidSpan(Used, LeftStart, LeftLength) Then Exit Function
    If Not ValidSpan(Used, RightStart, RightLength) Then Exit Function
    Do While Index < LeftLength And Index < RightLength
        If Arena(LeftStart + Index) < Arena(RightStart + Index) Then Value = -1: Exit Do
        If Arena(LeftStart + Index) > Arena(RightStart + Index) Then Value = 1: Exit Do
        Index = Index + 1
    Loop
    If Value = 0 Then
        If LeftLength < RightLength Then Value = -1
        If LeftLength > RightLength Then Value = 1
    End If
    Result = Value
    TryCompare = True
    Exit Function
Failed:
    TryCompare = False
End Function
