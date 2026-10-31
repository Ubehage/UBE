UBE SOURCE 1 MODULE
Attribute UBE_Name = "ThreadStatement"

' Regression: an unsupported thread statement must not silently omit its work.
' Starts the observable target only after CallNew is actually implemented.
Sub RunWorker(ByVal Value As Long)
    Print Value
End Sub

' A successful compilation must not turn this worker invocation into no work.
Function Main() As Long
    CallNew RunWorker(7)
    Main = 0
End Function
