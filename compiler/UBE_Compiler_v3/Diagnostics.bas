Type CompilerDiagnostic
    Code As String
    FilePath As String
    LineNumber As Long
    ColumnNumber As Long
    Message As String
End Type

Function AddDiagnostic(ByRef Diagnostics() As CompilerDiagnostic, ByRef Count As Long, ByRef Capacity As Long, ByVal Code As String, ByVal FilePath As String, ByVal LineNumber As Long, ByVal ColumnNumber As Long, ByVal Message As String) As Long
    If Count >= LimitDiagnosticCount() Then
        AddDiagnostic = 0
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 8
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > LimitDiagnosticCount() Then
            NewCapacity = LimitDiagnosticCount()
        End If
        If Capacity = 0 Then
            ReDim Diagnostics(NewCapacity - 1)
        Else
            ReDim Preserve Diagnostics(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Diagnostics(Count).Code = Code
    Diagnostics(Count).FilePath = FilePath
    Diagnostics(Count).LineNumber = LineNumber
    Diagnostics(Count).ColumnNumber = ColumnNumber
    Diagnostics(Count).Message = Message
    Count = Count + 1
    AddDiagnostic = 1
End Function

Sub ReportDiagnostics(ByRef Diagnostics() As CompilerDiagnostic, ByVal Count As Long)
    Dim Index As Long = 0
    While Index < Count
        Print Diagnostics(Index).FilePath & "(" & LongToString(Diagnostics(Index).LineNumber) & "," & LongToString(Diagnostics(Index).ColumnNumber) & "): error " & Diagnostics(Index).Code & ": " & Diagnostics(Index).Message
        Index = Index + 1
    Wend
End Sub
