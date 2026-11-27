UBE SOURCE 1 CLASS
Attribute UBE_Name = "Gate"
Option Explicit
Public Value As Long
Public ByteValue As Byte
Public IntegerValue As Integer
Public WideValue As LongLong
Public BooleanValue As Boolean
Public SingleValue As Single
Public DoubleValue As Double
Public RawIdentity As LongLong
Public Text As String
Public Box As Variant
Public Link As Gate
Public Data As RecordTypes.Payload
Friend FriendValue As Long
Private Hidden As Long

Public Sub InitializeValue(ByVal Number As Long)
    Value = Number
    Me.Hidden = Number + 1
End Sub

Private Function Offset() As Long
    Offset = Hidden - Value
End Function

Public Function ReadValue() As Long
    ReadValue = Me.Value + Offset()
End Function

Public Function ReadWith(ByVal Addend As Long) As Long
    ReadWith = Me.Value + Addend
End Function

Public Function ReadOtherPrivate(ByVal Other As Gate) As Long
    ReadOtherPrivate = Other.Hidden
End Function

Public Function Self() As Gate
    Set Self = Me
End Function

Public Function GroupedSelf() As Boolean
    Dim Before As Gate
    On Error GoTo Failed
    Set Before = Me
    Helpers.ClearReference (Me)
    GroupedSelf = Me Is Before
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function Recurse(ByVal Depth As Long, ByVal Other As Gate) As Long
    Dim Child As Long
    On Error GoTo Failed
    If Depth = 0 Then Recurse = Value: Exit Function
    Child = Other.Recurse(Depth - 1, Me)
    Recurse = Value + Child
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function ClearCallerAndRead(ByRef CallerReference As Gate) As Long
    On Error GoTo Failed
    Helpers.ClearAndCollect CallerReference
    ClearCallerAndRead = Me.Value
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function FailValue() As Long
    On Error GoTo WrongHandler
    Err.Raise 17
    FailValue = 100
    Exit Function
WrongHandler:
    FailValue = 101
End Function

Public Function FailReference() As Gate
    Err.Raise 17
End Function
