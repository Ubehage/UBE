UBE SOURCE 1 MODULE
Attribute UBE_Name = "StorageProbe"
' Retains source bytes, token spans and linked tree nodes in independent values.
Private Const FirstTokenIndex As LongLong = -1
Private Const LastTokenIndex As LongLong = 1
Public Type Token
    Start As LongLong
    Length As Long
    Kind As Integer
End Type
Public Type Node
    TokenIndex As Long
    FirstChild As Long
    NextSibling As Long
End Type
Public Type Container
    Inner As Token
    Tag As Byte
End Type
Private RhsCalls As Long
Private LaterCalls As Long
Private CalleeCalls As Long
Private IndexCalls As Long
Private BooleanCall As Long
' Reads and traverses retained byte/token/tree arrays using existing label control flow.
Public Function CheckStorage(ByVal Seed As Long) As Long
    Dim Bytes(0 To 3) As Byte
    Dim ByteCopy(0 To 3) As Byte
    Dim Tokens(FirstTokenIndex To LastTokenIndex) As Token
    Dim TokenCopy(FirstTokenIndex To LastTokenIndex) As Token
    Dim Nodes(0 To 2) As Node
    Dim Original As Token
    Dim Copied As Token
    Dim Nested As Container
    Dim NestedCopy As Container
    Dim Index As Long
    Dim TokenIndex As Long
    Dim Length As Long
    Dim Total As Long
    Dim Value As Long
    Dim Matches As Boolean
    Value = Bytes(Seed)
    If Value <> 0 Then CheckStorage = 1: Exit Function
    Value = Tokens(0).Length
    If Value <> 0 Then CheckStorage = 2: Exit Function
    Bytes(0) = 97
    Bytes(1) = 43
    Bytes(2) = 195
    Bytes(3) = 164
    ByteCopy = Bytes
    ByteCopy = ByteCopy
    ByteCopy(0) = 122
    Value = Bytes(0)
    If Value <> 97 Then CheckStorage = 3: Exit Function
    Original.Start = 2
    Original.Length = 2
    Original.Kind = 1
    Copied = Original
    Matches = Copied = Original
    If Matches <> True Then CheckStorage = 9: Exit Function
    Copied.Length = 9
    Matches = Copied <> Original
    If Matches <> True Then CheckStorage = 10: Exit Function
    Original = Original
    Value = Original.Length
    If Value <> 2 Then CheckStorage = 4: Exit Function
    Tokens(-1).Start = 0
    Tokens(-1).Length = 1
    Tokens(-1).Kind = 1
    Tokens(0).Start = 1
    Tokens(0).Length = 1
    Tokens(0).Kind = 2
    Tokens(1) = Original
    TokenCopy = Tokens
    TokenCopy(1).Length = 9
    Value = Tokens(1).Length
    If Value <> 2 Then CheckStorage = 5: Exit Function
    Nodes(0).TokenIndex = 0
    Nodes(0).FirstChild = Seed
    Nodes(1).TokenIndex = -1
    Nodes(1).NextSibling = 2
    Nodes(2).TokenIndex = 1
    Nodes(2).NextSibling = -1
    Index = Nodes(0).FirstChild
Again:
    TokenIndex = Nodes(Index).TokenIndex
    Length = Tokens(TokenIndex).Length
    Total = Total + Length
    Index = Nodes(Index).NextSibling
    If Index >= 0 Then GoTo Again
    If Total <> 3 Then CheckStorage = 6: Exit Function
    Value = Bytes(2)
    If Value <> 195 Then CheckStorage = 7: Exit Function
    Value = Bytes(3)
    If Value <> 164 Then CheckStorage = 8: Exit Function
    ChangeToken Nested.Inner
    ChangeLength Nested.Inner.Length
    NestedCopy = Nested
    NestedCopy.Inner.Length = 99
    Value = Nested.Inner.Length
    If Value <> 8 Then CheckStorage = 11: Exit Function
    Matches = Nested <> NestedCopy
    If Matches <> True Then CheckStorage = 12: Exit Function
    CheckStorage = 0
End Function
' Mutates one exact record alias supplied as an array element.
Public Sub ChangeToken(ByRef Value As Token)
    Value.Length = 7
End Sub
' Mutates one scalar field alias supplied from a record array element.
Public Sub ChangeLength(ByRef Value As Long)
    Value = 8
End Sub
' Makes any duplicate evaluation of a field's indexing expression observable.
Public Function NextIndex(ByVal Seed As Long) As LongLong
    IndexCalls = IndexCalls + 1
    NextIndex = Seed
End Function
' Writes using the actual bounds supplied by a rank-only array parameter.
Public Sub SetByte(ByRef Values() As Byte, ByVal Index As LongLong, ByVal Value As Byte)
    Values(Index) = Value
End Sub
' Preserves the classic spaced call whose argument is a grouped comparison.
Public Sub Take(ByVal Matches As Boolean)
    If Matches Then BooleanCall = 1 Else BooleanCall = 2
End Sub
' Checks aggregate/field aliases and a parameter retaining negative caller bounds.
Public Function CheckAliases(ByVal Seed As Long) As Long
    Dim Tokens(0 To 2) As Token
    Dim Shifted(-2 To 1) As Byte
    Dim Lowest(-9223372036854775808^ To -9223372036854775808^) As Byte
    Dim Highest(9223372036854775807^ To 9223372036854775807^) As Byte
    Dim Index As LongLong = Seed
    Dim Value As Long
    Value = 1
    Take (Value) = 1
    If BooleanCall <> 1 Then CheckAliases = 8: Exit Function
    ChangeToken Tokens(Index)
    Value = Tokens(Index).Length
    If Value <> 7 Then CheckAliases = 1: Exit Function
    ChangeLength Tokens(NextIndex(Seed)).Length
    If IndexCalls <> 1 Then CheckAliases = 7: Exit Function
    Value = Tokens(Index).Length
    If Value <> 8 Then CheckAliases = 2: Exit Function
    SetByte Shifted, -2, 97
    SetByte Shifted, 1, 164
    Value = Shifted(-2)
    If Value <> 97 Then CheckAliases = 3: Exit Function
    Value = Shifted(1)
    If Value <> 164 Then CheckAliases = 4: Exit Function
    Index = 1
    Let Shifted (Index) = 42
    Value = Shifted(1)
    If Value <> 42 Then CheckAliases = 9: Exit Function
    Let Shifted (Index) = 164
    Err.Clear
    SetByte Shifted, 1 + Seed, 255
    If Err.Number <> 9 Then CheckAliases = 5: Exit Function
    Value = Shifted(1)
    If Value <> 164 Then CheckAliases = 6: Exit Function
    Index = -9223372036854775808^ + (Seed + -Seed)
    SetByte Lowest, Index, 97
    Value = Lowest(Index)
    If Value <> 97 Then CheckAliases = 10: Exit Function
    Index = 9223372036854775807^ + (Seed + -Seed)
    SetByte Highest, Index, 164
    Value = Highest(Index)
    If Value <> 164 Then CheckAliases = 11: Exit Function
    CheckAliases = 0
End Function
' Records whether the right side of a failed destination access ran.
Public Function RightSide() As Long
    RhsCalls = RhsCalls + 1
    RightSide = 99
End Function
' Records whether an argument after a failed alias acquisition ran.
Public Function LaterArgument() As Long
    LaterCalls = LaterCalls + 1
    LaterArgument = 1
End Function
' Must not be entered after argument preparation reports a bounds failure.
Public Sub Receive(ByRef Value As Long, ByVal LaterValue As Long)
    CalleeCalls = CalleeCalls + 1
    Value = LaterValue
End Sub
' Verifies default statement skipping, preserving values and handler transfer for Err 9.
Public Function CheckBounds(ByVal Seed As Long) As Long
    Dim Values(-1 To 1) As Long
    Dim Index As LongLong = Seed + 1
    Dim Saved As Long = 77
    Dim HandlerEntries As Long
    Values(0) = 12
    Err.Clear
    Saved = Values(Index) + RightSide()
    If Saved <> 77 Then CheckBounds = 1: Exit Function
    If Err.Number <> 9 Then CheckBounds = 2: Exit Function
    Values(Index) = RightSide()
    If RhsCalls <> 0 Then CheckBounds = 3: Exit Function
    Receive Values(Index), LaterArgument()
    If LaterCalls <> 0 Then CheckBounds = 4: Exit Function
    If CalleeCalls <> 0 Then CheckBounds = 5: Exit Function
    Saved = Values(0)
    If Saved <> 12 Then CheckBounds = 6: Exit Function
    Index = -9223372036854775808^
    Saved = Values(Index)
    If Saved <> 12 Then CheckBounds = 7: Exit Function
    Index = 9223372036854775807^
    Saved = Values(Index)
    If Saved <> 12 Then CheckBounds = 8: Exit Function
    On Error GoTo Failed
    Values(Index) = 100
    CheckBounds = 9
    Exit Function
Failed:
    HandlerEntries = HandlerEntries + 1
    If HandlerEntries > 1 Then CheckBounds = 13: Exit Function
    If Err.Number <> 9 Then CheckBounds = 10: Exit Function
    Saved = Values(0)
    If Saved <> 12 Then CheckBounds = 11: Exit Function
    Saved = Values(Index)
    If Saved <> 12 Then CheckBounds = 12: Exit Function
    If Err.Number <> 9 Then CheckBounds = 14: Exit Function
    CheckBounds = 0
End Function
