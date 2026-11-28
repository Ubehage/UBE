UBE SOURCE 1 MODULE
Attribute UBE_Name = "Workload"
Option Explicit
Public Const IterationsPerBatch As Long = 2000

Public Function Run(ByVal Count As Long, ByVal Seed As Long) As LongLong
    Dim Item As Counter
    Dim Prefix As String
    Dim Expected As String
    Dim Index As Long
    Dim Total As LongLong
    On Error GoTo Failed
    If Count = 0 Then Exit Function
    Prefix = Seed
    Expected = Prefix & "é"
    Set Item = New Counter
    For Index = 1 To Count
        Item.Value = Index + Seed
        Item.Label = Prefix & "é"
        If Item.Label <> Expected Then Err.Raise 5
        Total = Total + Item.ReadValue()
    Next Index
    Run = Total
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
