UBE SOURCE 1 MODULE
Attribute UBE_Name = "Diagnostics"

Type CompilerDiagnostic
    Code As String
    Path As String
    Message As String
    EmissionOrdinal As Long
End Type

' Adds one deterministic diagnostic in sequential emission order. Returns 0
' without growing storage when the frozen session limit has been reached.
Function AddCompilerDiagnostic(ByRef Values() As CompilerDiagnostic, ByRef Count As Long, ByRef Capacity As Long, ByVal MaximumCount As Long, ByVal Code As String, ByVal Path As String, ByVal Message As String) As Long
    If Count < 0 Or Count >= MaximumCount Then
        AddCompilerDiagnostic = 0
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 4
        If Capacity > 0 Then NewCapacity = Capacity * 2
        If NewCapacity > MaximumCount Then NewCapacity = MaximumCount
        If Capacity = 0 Then
            ReDim Values(NewCapacity - 1)
        Else
            ReDim Preserve Values(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Values(Count).Code = Code
    Values(Count).Path = Path
    Values(Count).Message = Message
    Values(Count).EmissionOrdinal = Count
    Count = Count + 1
    AddCompilerDiagnostic = 1
End Function

' Prints diagnostics in their stable sequential emission order.
Sub ReportCompilerDiagnostics(ByRef Values() As CompilerDiagnostic, ByVal Count As Long)
    Dim Index As Long = 0
    While Index < Count
        If Values(Index).Path = "" Then
            Print "error " & Values(Index).Code & ": " & Values(Index).Message
        Else
            Print Values(Index).Path & ": error " & Values(Index).Code & ": " & Values(Index).Message
        End If
        Index = Index + 1
    Wend
End Sub
