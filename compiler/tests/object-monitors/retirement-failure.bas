UBE SOURCE 1 MODULE
Attribute UBE_Name = "RetirementFailureProbe"
Option Explicit

Private Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function

Private Function Depart(ByVal Value As Gate, ByVal Returning As Boolean) As Boolean
    On Error GoTo LocalHandler
    SyncLock Value
        If Returning Then
            Depart = True
            Exit Function
        End If
    End SyncLock
    Depart = True
    Exit Function
LocalHandler:
    Call RecordError(99)
    Depart = True
End Function

Public Function Main() As Long
    Dim Value As Gate
    Dim Kept As Boolean
    Set Value = New Gate
    Kept = True
    On Error GoTo Caught
    Kept = Depart(Value, False)
    Main = 1
    Exit Function
Caught:
    If Err.Number <> 5 Then Main = 2: Exit Function
    If Not Kept Then Main = 3: Exit Function
    On Error GoTo 0
    SyncLock Value
        Main = 0
    End SyncLock
End Function
