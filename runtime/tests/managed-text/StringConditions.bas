UBE SOURCE 1 MODULE
Attribute UBE_Name = "StringConditions"

Private Function Echo(ByVal Value As String) As String
    Echo = Value
End Function

Private Function IfCondition() As Boolean
    Dim Value As String
    On Error GoTo Failed
    Value = Echo("False")
    If Value Then Exit Function
    IfCondition = True
    Exit Function
Failed:
    IfCondition = False
End Function

Private Function WhileCondition() As Boolean
    Dim Value As String
    Dim Count As Long
    On Error GoTo Failed
    Value = Echo("False")
    Do While Value
        Count = Count + 1
        If Count > 2 Then Exit Function
    Loop
    If Count <> 0 Then Exit Function
    Do
        Count = Count + 1
        If Count > 2 Then Exit Function
    Loop While Value
    WhileCondition = Count = 1
    Exit Function
Failed:
    WhileCondition = False
End Function

Private Function UntilCondition() As Boolean
    Dim Value As String
    Dim Count As Long
    On Error GoTo Failed
    Value = Echo("True")
    Do Until Value
        Count = Count + 1
        If Count > 2 Then Exit Function
    Loop
    If Count <> 0 Then Exit Function
    Do
        Count = Count + 1
        If Count > 2 Then Exit Function
    Loop Until Value
    UntilCondition = Count = 1
    Exit Function
Failed:
    UntilCondition = False
End Function

Private Function InvalidCondition() As Boolean
    Dim Value As String
    On Error GoTo Unexpected
    Value = Echo("invalid")
    On Error GoTo Expected
    If Value Then Exit Function
    Exit Function
Expected:
    InvalidCondition = Err.Number = 13
    Exit Function
Unexpected:
    InvalidCondition = False
End Function

Private Function StringIndex() As Boolean
    Dim Values(0 To 2) As Long
    Dim IndexText As String
    On Error GoTo Unexpected
    Values(1) = 42
    IndexText = Echo("1")
    If Values(IndexText) <> 42 Then Exit Function
    Values(IndexText) = 73
    If Values(1) <> 73 Then Exit Function
    IndexText = Echo("invalid")
    On Error GoTo Expected
    Values(IndexText) = 99
    Exit Function
Expected:
    StringIndex = Err.Number = 13 And Values(1) = 73
    Exit Function
Unexpected:
    StringIndex = False
End Function

Public Function Main() As Long
    If Not IfCondition() Then Main = 1: Exit Function
    If Not WhileCondition() Then Main = 2: Exit Function
    If Not UntilCondition() Then Main = 3: Exit Function
    If Not InvalidCondition() Then Main = 4: Exit Function
    If Not StringIndex() Then Main = 5: Exit Function
End Function
