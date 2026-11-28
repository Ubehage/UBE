UBE SOURCE 1 CLASS
Attribute UBE_Name = "Counter"
Option Explicit
Public Value As LongLong
Public Label As String
Public Link As Counter

Public Function ReadValue() As LongLong
    ReadValue = Me.Value
End Function

Public Sub Add(ByVal Amount As LongLong)
    On Error GoTo Failed
    Value = Value + Amount
    Exit Sub
Failed:
    Err.Raise Err.Number
End Sub
