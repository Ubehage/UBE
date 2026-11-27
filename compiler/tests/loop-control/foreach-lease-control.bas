UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private Const Mode As Long = 0
Private Intrinsic Function Observe() As LongLong
Attribute Observe.UBE_Primitive = "Thread.CurrentId"
End Function
Private Intrinsic Function Resize(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute Resize.UBE_Primitive = "Array.TryResize"
End Function

Private Sub RaiseFailure()
    Err.Raise 5
End Sub

Private Function Scopes() As Boolean
    Dim Values() As Long
    Dim Outer As Variant
    Dim Inner As Variant
    Dim Value As Long
    If Not Resize(Values, 2, False) Then Exit Function
    Values(0) = 11
    For Each Outer In Values
        If Observe() <> 1 Then Exit Function
        For Each Inner In Values
            If Observe() <> 2 Then Exit Function
            Exit For
        Next Inner
        If Observe() <> 1 Then Exit Function
        Exit Loop
    Next Outer
    If Observe() <> 0 Then Exit Function
    Value = Outer
    If Value <> 11 Then Exit Function
    Value = Inner
    If Value <> 11 Then Exit Function
    Scopes = True
End Function

Private Function DefaultFailure() As Boolean
    Dim Values() As Long
    Dim Item As Variant
    Dim Seen As Long
    If Not Resize(Values, 2, False) Then Exit Function
    For Each Item In Values
        Seen = Seen + 1
    Next Item
    If Seen <> 0 Or Err.Number <> 7 Then Exit Function
    If Observe() <> 0 Then Exit Function
    DefaultFailure = True
End Function

Private Function HandlerOut() As Long
    Dim Values() As Long
    Dim Item As Variant
    Dim Value As Long
    HandlerOut = 30
    If Not Resize(Values, 2, False) Then Exit Function
    Values(0) = 11
    On Error GoTo Outside
    For Each Item In Values
        HandlerOut = 31
        If Observe() <> 1 Then Exit Function
        RaiseFailure
    Next Item
    Exit Function
Outside:
    HandlerOut = 32
    If Observe() <> 0 Then Exit Function
    HandlerOut = 33
    Value = Item
    If Value <> 11 Then Exit Function
    HandlerOut = 0
End Function

Private Function HandlerIn() As Boolean
    Dim Values() As Long
    Dim Item As Variant
    Dim Seen As Long
    If Not Resize(Values, 2, False) Then Exit Function
    On Error GoTo Inside
    For Each Item In Values
        If Seen = 0 Then RaiseFailure
Inside:
        If Observe() <> 1 Then Exit Function
        Seen = Seen + 1
    Next Item
    If Observe() <> 0 Or Seen <> 2 Then Exit Function
    HandlerIn = True
End Function

Private Function RootRange() As Boolean
    Dim Values(-3 To -2) As String
    Dim Item As Variant
    Dim Text As String
    Values(-3) = "retained control value"
    For Each Item In Values
        Exit Loop
    Next Item
    If Observe() <> 0 Then Exit Function
    Text = Item
    If Text <> "retained control value" Then Exit Function
    RootRange = True
End Function

Public Function Main() As Long
    Main = 1
    If Mode = 0 Then
        If Scopes() Then Main = 0
    ElseIf Mode = 1 Then
        If DefaultFailure() Then Main = 0
    ElseIf Mode = 2 Then
        Main = HandlerOut()
    ElseIf Mode = 3 Then
        If HandlerIn() Then Main = 0
    ElseIf Mode = 4 Then
        If RootRange() Then Main = 0
    End If
End Function
