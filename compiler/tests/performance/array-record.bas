UBE SOURCE 1 MODULE
Attribute UBE_Name = "Workload"
Option Explicit
Public Const IterationsPerBatch As Long = 100000
Private Type Cell
    Value As LongLong
    Weight As Long
End Type

Public Function Run(ByVal Count As Long, ByVal Seed As Long) As LongLong
    Dim Cells(0 To 127) As Cell
    Dim Pass As Long
    Dim Index As Long
    Dim Total As LongLong
    On Error GoTo Failed
    If Count = 0 Then Exit Function
    For Index = 0 To 127
        Cells(Index).Value = Index * Seed
        Cells(Index).Weight = Index Mod 7
    Next Index
    For Pass = 1 To Count
        For Index = 0 To 127
            Cells(Index).Value = Cells(Index).Value + Seed
        Next Index
    Next Pass
    For Index = 0 To 127
        Total = Total + Cells(Index).Value + Cells(Index).Weight
    Next Index
    Run = Total
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
