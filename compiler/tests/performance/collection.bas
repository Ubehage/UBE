UBE SOURCE 1 MODULE
Attribute UBE_Name = "Workload"
Option Explicit
Public Const IterationsPerBatch As Long = 20000

Private Intrinsic Function CollectGarbage() As Long
Attribute CollectGarbage.UBE_Primitive = "Memory.Collect"
End Function

Public Function Run(ByVal Count As Long, ByVal Seed As Long) As LongLong
    Dim First As Counter
    Dim Second As Counter
    Dim Index As Long
    Dim Total As LongLong
    On Error GoTo Failed
    If Count = 0 Then Exit Function
    For Index = 1 To Count
        Set First = New Counter
        Set Second = New Counter
        First.Value = Index + Seed
        Second.Value = Seed
        Set First.Link = Second
        Set Second.Link = First
        If First.Link.Link IsNot First Then Err.Raise 5
        Total = Total + First.ReadValue() + Second.ReadValue()
        Set First = Nothing
        Set Second = Nothing
        If (Index Mod 64) = 0 Then Call CollectGarbage()
    Next Index
    Call CollectGarbage()
    Run = Total
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
