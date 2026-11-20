UBE SOURCE 1 MODULE
Attribute UBE_Name = "CollectorProbe"
' Exercises the production traversal with the deterministic test snapshot adapter.
Public Function Main() As Long
    Dim I As Long
    Dim Work As Long
    Call ManagedPrimitives.Reset()
    ' A long reachable cycle, duplicate roots and a disconnected cycle.
    Do While I < 128
        ManagedPrimitives.Live(I) = True
        ManagedPrimitives.NextEdge(I) = I + 2
        I = I + 1
    Loop
    ManagedPrimitives.NextEdge(99) = 1
    ManagedPrimitives.NextEdge(127) = 101
    ManagedPrimitives.Root = 1
    Call ManagedPrimitives.RecordError(42)
    Work = ManagedMemory.Collect(True)
    If Work <> 1 Or Err.Number <> 42 Or ManagedPrimitives.Releases <> 28 Or ManagedPrimitives.EndCount <> 1 Then Main = 1: Exit Function
    I = 0
    Do While I < 128
        If ManagedPrimitives.Live(I) <> (I < 100) Then Main = 2: Exit Function
        I = I + 1
    Loop
    ' Removing the root collects the remaining cycle; a repeated empty pass is idle.
    ManagedPrimitives.Root = 0
    If ManagedMemory.Collect(True) <> 1 Then Main = 3: Exit Function
    If ManagedPrimitives.Releases <> 128 Then Main = 4: Exit Function
    If ManagedMemory.Collect(True) <> 0 Then Main = 5: Exit Function
    ' Workspace, traversal and late snapshot failures must perform no sweep.
    I = 1
    Do While I <= 5
        If I <> 3 And I <> 4 Then
            Call ManagedPrimitives.Reset()
            ManagedPrimitives.Live(0) = True
            ManagedPrimitives.Live(1) = True
            ManagedPrimitives.Root = 1
            ManagedPrimitives.Mode = I
            Call ManagedPrimitives.RecordError(42)
            Work = ManagedMemory.Collect(True)
            If Work <> 0 Or ManagedPrimitives.Releases <> 0 Or ManagedPrimitives.Sealed Or ManagedPrimitives.EndCount <> 1 Then Main = 6: Exit Function
            If I = 5 Then
                If Err.Number <> 5 Then Main = 7: Exit Function
            Else
                If Err.Number <> 7 Then Main = 8: Exit Function
            End If
            ' Cleared marks must allow successful traversal and later reclamation.
            ManagedPrimitives.Mode = 0
            If ManagedMemory.Collect(True) <> 1 Then Main = 9: Exit Function
            If Not ManagedPrimitives.Live(0) Or ManagedPrimitives.Live(1) Then Main = 10: Exit Function
        End If
        I = I + 1
    Loop
    ' A failed native release retains its object while other eligible releases proceed.
    Call ManagedPrimitives.Reset()
    ManagedPrimitives.Live(0) = True
    ManagedPrimitives.Live(1) = True
    ManagedPrimitives.Mode = 3
    Work = ManagedMemory.Collect(True)
    If Work <> 1 Or Err.Number <> 57 Or ManagedPrimitives.Releases <> 1 Or Not ManagedPrimitives.Live(0) Then Main = 11: Exit Function
    ' Joining another collector must not call End, and opportunistic errors stay private.
    Call ManagedPrimitives.Reset()
    ManagedPrimitives.Mode = 4
    Call ManagedPrimitives.RecordError(42)
    If ManagedMemory.Collect(False) <> 1 Or Err.Number <> 42 Or ManagedPrimitives.EndCount <> 0 Then Main = 12: Exit Function
    If ManagedMemory.Collect(True) <> 1 Or Err.Number <> 7 Then Main = 13: Exit Function
    ' An owned opportunistic round also preserves Err after workspace failure.
    Call ManagedPrimitives.Reset()
    ManagedPrimitives.Mode = 1
    ManagedPrimitives.Live(0) = True
    Call ManagedPrimitives.RecordError(42)
    Work = ManagedMemory.Collect(False)
    If Work <> 0 Or Err.Number <> 42 Or Not ManagedPrimitives.Live(0) Or ManagedPrimitives.EndCount <> 1 Then Main = 14: Exit Function
    ' A nonzero invalid edge aborts before sealing and leaves every object live.
    Call ManagedPrimitives.Reset()
    ManagedPrimitives.Live(0) = True
    ManagedPrimitives.Root = 1
    ManagedPrimitives.NextEdge(0) = 129
    Work = ManagedMemory.Collect(True)
    If Work <> 0 Or Err.Number <> 5 Or ManagedPrimitives.Sealed Or ManagedPrimitives.Releases <> 0 Or ManagedPrimitives.EndCount <> 1 Then Main = 15: Exit Function
End Function
