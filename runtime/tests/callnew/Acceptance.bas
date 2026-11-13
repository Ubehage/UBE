UBE SOURCE 1 MODULE
Attribute UBE_Name = "Acceptance"
' Keeps the executable bridge separate from the reusable library assertions.
Public Function Main() As Long
    Dim Result As Long
    Result = Workers.Run()
    If Result <> 0 Then Main = Result: Exit Function
    Result = CaptureProbe.Run()
    If Result <> 0 Then Main = 100 + Result: Exit Function
    Result = WorkerCapacity.Run()
    If Result <> 0 Then Main = 200 + Result
End Function
