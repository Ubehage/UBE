UBE SOURCE 1 MODULE
Attribute UBE_Name = "Cancellation"

Type CancellationToken
    Requested As Long
End Type

' Initializes one coordinator-owned cooperative cancellation token.
Sub InitializeCancellation(ByRef Token As CancellationToken)
    Token.Requested = 0
End Sub

' Makes cancellation sticky for the remainder of the build session.
Sub RequestCancellation(ByRef Token As CancellationToken)
    Token.Requested = 1
End Sub

' Returns 1 after cancellation has been requested and 0 otherwise.
Function IsCancellationRequested(ByRef Token As CancellationToken) As Long
    If Token.Requested <> 0 Then
        IsCancellationRequested = 1
    Else
        IsCancellationRequested = 0
    End If
End Function
