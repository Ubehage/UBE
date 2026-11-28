UBE SOURCE 1 MODULE
Attribute UBE_Name = "CancellationSchedule"
Public Target As Long
Public Owner As LongLong
Public Visits As Long
Public ObservedAt As Long

' Called only from isolated test copies, never from production compiler source.
Public Sub Visit(ByVal Kind As Long)
    If Kind <> Target Or ThreadPrimitives.CurrentId() <> Owner Then Exit Sub
    Visits = Visits + 1
    If Visits = 17 Then
        If ThreadPrimitives.RequestStop(Owner) <> 1 Then Err.Raise 5
        ObservedAt = Visits
    End If
End Sub
