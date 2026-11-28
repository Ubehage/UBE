UBE SOURCE 1 MODULE
Attribute UBE_Name = "Workload"
Option Explicit
Public Const IterationsPerBatch As Long = 2000000

Private Function Term(ByVal Index As Long, ByVal Seed As Long) As LongLong
    On Error GoTo Failed
    Term = Index * Seed + (Index Mod 7)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function Run(ByVal Count As Long, ByVal Seed As Long) As LongLong
    Dim Index As Long
    Dim Total As LongLong
    On Error GoTo Failed
    For Index = 1 To Count
        Total = Total + Term(Index, Seed)
    Next Index
    Run = Total
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
