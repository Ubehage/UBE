UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeDiagnostics"

Type IdeDiagnostic
    Code As String
    MessageKey As String
    FilePath As String
    SourceLine As Long
    Column As Long
    Severity As Long
End Type

Function IdeAddDiagnostic(ByRef Items() As IdeDiagnostic, ByRef Count As Long, ByRef Capacity As Long, ByVal Code As String, ByVal FilePath As String, ByVal SourceLine As Long, ByVal Column As Long, ByVal Severity As Long) As Long
    If Count >= IdeLimitDiagnostics() Then
        IdeAddDiagnostic = 0
        Exit Function
    End If
    If Count = Capacity Then
        Dim NewCapacity As Long = 16
        If Capacity > 0 Then
            NewCapacity = Capacity * 2
        End If
        If NewCapacity > IdeLimitDiagnostics() Then
            NewCapacity = IdeLimitDiagnostics()
        End If
        If Capacity = 0 Then
            ReDim Items(NewCapacity - 1)
        Else
            ReDim Preserve Items(NewCapacity - 1)
        End If
        Capacity = NewCapacity
    End If
    Items(Count).Code = Code
    Items(Count).MessageKey = "Diagnostic." & Code
    Items(Count).FilePath = FilePath
    Items(Count).SourceLine = SourceLine
    Items(Count).Column = Column
    Items(Count).Severity = Severity
    Count = Count + 1
    IdeAddDiagnostic = 1
End Function
