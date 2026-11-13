UBE SOURCE 1 MODULE
Attribute UBE_Name = "SharedStorage"
' Exercises program-shared arrays from independently owned native execution headers.
Private Values() As Long

' Allocates the admitted finite scalar payload through the ordinary primitive role.
Private Intrinsic Function ResizeValues(ByRef Items() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeValues.UBE_Primitive = "Array.TryResize"
End Function

' Copies a coherent retained source payload into independently owned local storage.
Private Intrinsic Function CopyValues(ByRef Target() As Long, ByRef Source() As Long) As Boolean
Attribute CopyValues.UBE_Primitive = "Array.TryCopy"
End Function

' Reads a synchronized descriptor extent.
Private Intrinsic Function ValueCount(ByRef Items() As Long) As Long
Attribute ValueCount.UBE_Primitive = "Array.Length"
End Function

' Establishes a program-specific initial value before its workers are admitted.
Public Function Prepare(ByVal Value As Long) As Long
    If Not ResizeValues(Values, 64, False) Then Prepare = 1: Exit Function
    Values(0) = Value
End Function

' Retains source storage while another worker repeatedly replaces its descriptor.
Public Function Work(ByVal Mode As Long, ByVal Expected As Long) As Long
    Dim Copy() As Long
    Dim Index As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = FilePrimitives.SetError(70 + Mode)
    Do While Index < 3000
        If Mode = 0 Then
            If Not ResizeValues(Values, 128, True) Then Work = 7: Exit Function
        Else
            If Not CopyValues(Copy, Values) Then Work = 7: Exit Function
            If ValueCount(Copy) < 64 Then Work = 2: Exit Function
            If Copy(0) <> Expected Then Work = 3: Exit Function
        End If
        If Values(0) <> Expected Then Work = 4: Exit Function
        If Err.Number <> 70 + Mode Then Work = 5: Exit Function
        Index = Index + 1
    Loop
    Exit Function
Failed:
    Work = 99
End Function

' Reads independently expected shared state after the native joins.
Public Function Value() As Long
    Value = Values(0)
End Function
