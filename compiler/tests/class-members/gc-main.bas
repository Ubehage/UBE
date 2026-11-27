UBE SOURCE 1 MODULE
Attribute UBE_Name = "GraphProbe"
Option Explicit

' The gate substitutes an observation-only native helper at this existing primitive call.
Private Intrinsic Function Observe() As LongLong
Attribute Observe.UBE_Primitive = "Thread.CurrentId"
End Function

Private Function HoldField(ByRef Cell As Long) As Long
    On Error GoTo Failed
    Set Helpers.Held = Nothing
    Call Helpers.CollectGarbage()
    If Observe() <> 1 Then Err.Raise 61
    Cell = 77
    HoldField = Cell
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function Main() As Long
    Dim First As Gate
    Dim Second As Gate
    Dim Owner As Gate
    Dim Victim As Gate
    Dim Number As Long
    On Error GoTo Failed
    Set First = New Gate
    Set Second = New Gate
    First.Data.Text = "embedded managed text"
    Set First.Data.Peer = Second
    Set Second.Link = First
    Second.Value = 42
    Set Second = Nothing
    Call Helpers.CollectGarbage()
    If Observe() <> 3 Then Main = 1: Exit Function
    If First.Data.Peer.Value <> 42 Or First.Data.Text <> "embedded managed text" Then Main = 2: Exit Function
    If First.Data.Peer.Link IsNot First Then Main = 3: Exit Function
    Set First = Nothing
    Call Helpers.CollectGarbage()
    If Observe() <> 0 Then Main = 4: Exit Function
    Set Owner = New Gate
    Set Victim = New Gate
    Owner.RawIdentity = Observe()
    Set Victim = Nothing
    Call Helpers.CollectGarbage()
    If Observe() <> 1 Then Main = 5: Exit Function
    Set Owner = Nothing
    Call Helpers.CollectGarbage()
    If Observe() <> 0 Then Main = 6: Exit Function
    Set Helpers.Held = New Gate
    Number = HoldField(Helpers.Held.Value)
    If Number <> 77 Then Main = 7: Exit Function
    Call Helpers.CollectGarbage()
    If Observe() <> 0 Then Main = 8: Exit Function
    Exit Function
Failed:
    Main = 99
End Function
