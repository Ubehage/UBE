UBE SOURCE 1 MODULE
Attribute UBE_Name = "MemberProbe"
Option Explicit

Private Function Fields() As Boolean
    Dim First As Gate
    Dim Second As Gate
    Dim ReferenceAlias As Gate
    Dim Copy As RecordTypes.Payload
    Dim Extracted As Gate
    Dim Number As Long
    On Error GoTo Failed
    Set First = New Gate
    Set Second = New Gate
    If First.Value <> 0 Or First.Text <> "" Then Exit Function
    If First.ByteValue <> 0 Or First.IntegerValue <> 0 Or First.WideValue <> 0 Then Exit Function
    If First.BooleanValue Or First.SingleValue <> 0 Or First.DoubleValue <> 0 Then Exit Function
    First.ByteValue = 255
    First.IntegerValue = -32768
    First.WideValue = 9223372036854775807
    First.BooleanValue = True
    First.SingleValue = 1.5
    First.DoubleValue = -2.25
    If First.ByteValue <> 255 Or First.IntegerValue <> -32768 Then Exit Function
    If First.WideValue <> 9223372036854775807 Or Not First.BooleanValue Then Exit Function
    If First.SingleValue <> 1.5 Or First.DoubleValue <> -2.25 Then Exit Function
    If Second.ByteValue <> 0 Or Second.IntegerValue <> 0 Or Second.WideValue <> 0 Then Exit Function
    If Second.BooleanValue Or Second.SingleValue <> 0 Or Second.DoubleValue <> 0 Then Exit Function
    If First.Link IsNot Nothing Or First.Data.Peer IsNot Nothing Then Exit Function
    If First.Data.Number <> 0 Or First.Data.Text <> "" Then Exit Function
    First.InitializeValue 10
    Second.InitializeValue 20
    If First.ReadValue() <> 11 Or Second.ReadValue() <> 21 Then Exit Function
    If First.ReadOtherPrivate(Second) <> 21 Then Exit Function
    Set ReferenceAlias = First
    ReferenceAlias.Value = 12
    If First.Value <> 12 Or Second.Value <> 20 Then Exit Function
    First.FriendValue = 9
    If ReferenceAlias.FriendValue <> 9 Then Exit Function
    First.Text = "managed field"
    First.Box = 42
    Number = First.Box
    If Number <> 42 Then Exit Function
    Set First.Link = Second
    Set First.Box = Second
    Set First.Data.Peer = Second
    First.Data.Number = 27
    First.Data.Text = "record field"
    Copy = First.Data
    First.Data.Number = 28
    If Copy.Number <> 27 Or Copy.Text <> "record field" Then Exit Function
    If Copy.Peer IsNot Second Then Exit Function
    Helpers.RewriteRecord First.Data
    If First.Data.Number <> 29 Or First.Data.Text <> "changed record" Then Exit Function
    Set Second = Nothing
    Set Extracted = First.Box
    Call Helpers.CollectGarbage()
    If First.Text <> "managed field" Or First.Link.Value <> 20 Then Exit Function
    If Extracted IsNot First.Link Or First.Data.Peer IsNot Extracted Then Exit Function
    Fields = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Function Receivers() As Boolean
    Dim First As Gate
    Dim Second As Gate
    Dim Self As Gate
    Dim Passed As Boolean
    Dim Result As Long
    On Error GoTo Failed
    Set First = New Gate
    Set Second = New Gate
    First.Value = 3
    Second.Value = 7
    Set Self = First.Self()
    If Self IsNot First Then Exit Function
    Passed = False
    Passed = First.GroupedSelf()
    If Not Passed Then Exit Function
    Result = First.Recurse(3, Second)
    If Result <> 20 Then Exit Function
    Set Self = Nothing
    Result = First.ClearCallerAndRead(First)
    If Result <> 3 Or First IsNot Nothing Then Exit Function
    Set Helpers.Held = New Gate
    Helpers.Held.Value = 8
    Helpers.Evaluations = 0
    Result = Helpers.Receiver().ReadWith(Helpers.ReplaceHeldAndCollect())
    If Result <> 13 Or Helpers.Evaluations <> 1 Then Exit Function
    If Helpers.Held.Value <> 900 Then Exit Function
    Set Helpers.Held = New Gate
    Helpers.Held.Value = 8
    Helpers.Evaluations = 0
    Result = Helpers.RewriteHeld(Helpers.Receiver().Value)
    If Result <> 77 Or Helpers.Evaluations <> 1 Then Exit Function
    If Helpers.Held IsNot Nothing Then Exit Function
    Receivers = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Function ManagedEdges() As Boolean
    Dim First As Gate
    Dim Second As Gate
    Dim Root As Gate
    On Error GoTo Failed
    Set First = New Gate
    Set Second = New Gate
    First.Text = "first cycle"
    Second.Text = "second cycle"
    Set First.Link = Second
    Set Second.Link = First
    Set Root = First
    Set First = Nothing
    Set Second = Nothing
    Call Helpers.CollectGarbage()
    If Root.Link.Link IsNot Root Then Exit Function
    If Root.Text <> "first cycle" Or Root.Link.Text <> "second cycle" Then Exit Function
    Set Root = Nothing
    Call Helpers.CollectGarbage()
    ManagedEdges = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Private Function DefaultFailure() As Boolean
    Dim Value As Gate
    Dim Original As Gate
    Dim Number As Long
    Set Value = New Gate
    Set Original = Value
    Number = 31
    Number = Value.FailValue()
    If Number <> 31 Or Err.Number <> 17 Then Exit Function
    Original.Value = 52
    Original.Value = Original.FailValue()
    If Original.Value <> 52 Or Err.Number <> 17 Then Exit Function
    Set Value = Original.FailReference()
    If Value IsNot Original Or Err.Number <> 17 Then Exit Function
    Set Value = Nothing
    Number = Value.Value
    If Number <> 31 Or Err.Number <> 91 Then Exit Function
    Number = Value.ReadValue()
    If Number <> 31 Or Err.Number <> 91 Then Exit Function
    Helpers.Effects = 0
    Number = Value.ReadWith(Helpers.SideEffect())
    If Number <> 31 Or Helpers.Effects <> 0 Or Err.Number <> 91 Then Exit Function
    Value.Value = Helpers.SideEffect()
    If Helpers.Effects <> 0 Or Err.Number <> 91 Then Exit Function
    Helpers.FailedReceiver().Value = Helpers.SideEffect()
    If Helpers.Effects <> 0 Or Err.Number <> 23 Then Exit Function
    Call Helpers.RecordError(73)
    Number = Original.ReadValue()
    If Err.Number <> 73 Then Exit Function
    DefaultFailure = True
End Function

Private Function HandledFailure() As Boolean
    Dim Value As Gate
    Dim Number As Long
    Dim Phase As Long
    On Error GoTo Caught
    Set Value = New Gate
    Number = 31
    Phase = 1
    Number = Value.FailValue()
    Exit Function
Caught:
    If Phase <> 1 Or Number <> 31 Or Err.Number <> 17 Then Exit Function
    HandledFailure = True
End Function

Private Function HandledNothing() As Boolean
    Dim Value As Gate
    On Error GoTo Caught
    Helpers.Effects = 0
    Value.Value = Helpers.SideEffect()
    Exit Function
Caught:
    If Err.Number <> 91 Or Helpers.Effects <> 0 Then Exit Function
    HandledNothing = True
End Function

Public Function Main() As Long
    Dim Passed As Boolean
    On Error GoTo Unexpected
    ' ESCAPING CONTROL
    Passed = False
    Passed = Fields()
    If Not Passed Then Main = 1: Exit Function
    Passed = False
    Passed = Receivers()
    If Not Passed Then Main = 2: Exit Function
    Passed = False
    Passed = ManagedEdges()
    If Not Passed Then Main = 3: Exit Function
    Passed = False
    Passed = DefaultFailure()
    If Not Passed Then Main = 4: Exit Function
    Passed = False
    Passed = HandledFailure()
    If Not Passed Then Main = 5: Exit Function
    Passed = False
    Passed = HandledNothing()
    If Not Passed Then Main = 6: Exit Function
    Exit Function
Unexpected:
    Main = 99
End Function
