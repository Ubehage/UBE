UBE SOURCE 1 MODULE
Attribute UBE_Name = "FormatProbe"
' Compares the portable formatter against independently generated exact byte expectations.
Private Shifted(1 To 2) As Byte

' Checks exact fragments, signed extrema, repeated slots, literal braces and line counters.
Public Function Check(ByRef Catalog() As Byte, ByRef Expected() As Byte, ByVal Template As Long, ByVal P0 As LongLong, ByVal P1 As LongLong, ByVal P2 As LongLong, ByVal P3 As LongLong, ByVal EndLine As Boolean) As Long
    Dim State As LLVMWriter.WriterState
    Dim Buffer() As Byte
    Dim Index As Long
    Dim Lines As Long
    Dim Status As Boolean
    If LLVMFormat.TryValidateCatalog(Catalog) = False Then Check = 1: Exit Function
    If LLVMWriter.TryInitialize(State, Buffer) = False Then Check = 2: Exit Function
    Status = FilePrimitives.SetError(71)
    If EndLine Then
        Status = LLVMFormat.TryLine(State, Buffer, 0, Catalog, Template, P0, P1, P2, P3)
    Else
        Status = LLVMFormat.TryFormat(State, Buffer, 0, Catalog, Template, P0, P1, P2, P3)
    End If
    If Status = False Or State.Failed Then Check = 3: Exit Function
    If Err.Number <> 71 Then Check = 4: Exit Function
    If State.Used <> BufferPrimitives.ByteStorageLength(Expected) Or State.TotalBytes <> State.Used Then Check = 5: Exit Function
    Do While Index < State.Used
        If Buffer(Index) <> Expected(Index) Then Check = 6: Exit Function
        If Expected(Index) = 10 Then Lines = Lines + 1
        Index = Index + 1
    Loop
    If State.LineCount <> Lines Then Check = 7
End Function

' Rejects malformed catalog inputs before consuming bytes and preserves an already latched failure.
Public Function CheckInvalid(ByRef Catalog() As Byte) As Long
    Dim State As LLVMWriter.WriterState
    Dim Buffer() As Byte
    Dim Changed() As Byte
    Dim Start As Long
    Dim Count As Long
    Dim Index As Long
    Dim Status As Boolean
    If LLVMWriter.TryInitialize(State, Buffer) = False Then CheckInvalid = 1: Exit Function
    Status = LLVMFormat.TryFormat(State, Buffer, 0, Catalog, 0, 0, 0, 0, 0)
    If Status Or State.Failure <> 3 Or State.Used <> 0 Or State.TotalBytes <> 0 Then CheckInvalid = 2: Exit Function
    State.Failure = 4
    Status = LLVMFormat.TryFormat(State, Buffer, 0, Catalog, 0, 0, 0, 0, 0)
    If Status Or State.Failure <> 4 Then CheckInvalid = 3: Exit Function
    If BufferPrimitives.TryCopyBytes(Changed, Catalog) = False Then CheckInvalid = 4: Exit Function
    Changed(0) = 33
    If LLVMFormat.TryValidateCatalog(Changed) Then CheckInvalid = 20: Exit Function
    Changed(0) = 127
    If LLVMFormat.TryValidateCatalog(Changed) Then CheckInvalid = 5: Exit Function
    If LLVMWriter.TryInitialize(State, Buffer) = False Then CheckInvalid = 6: Exit Function
    Status = LLVMFormat.TryFormat(State, Buffer, 0, Changed, LLVMTemplates.Branch, 1, 2, 3, 4)
    If Status Or State.Failure <> 3 Or State.Used <> 0 Then CheckInvalid = 7: Exit Function
    If BufferPrimitives.TryCopyBytes(Changed, Catalog) = False Then CheckInvalid = 8: Exit Function
    Status = LLVMTemplates.TrySpan(LLVMTemplates.Branch, Start, Count)
    Changed(Start + Count - 2) = 52
    If LLVMWriter.TryInitialize(State, Buffer) = False Then CheckInvalid = 9: Exit Function
    Status = LLVMFormat.TryFormat(State, Buffer, 0, Changed, LLVMTemplates.Branch, 1, 2, 3, 4)
    If Status Or State.Failure <> 3 Or State.Used <> 0 Or State.TotalBytes <> 0 Then CheckInvalid = 10: Exit Function
    Changed(Start + Count - 2) = 48
    Changed(Start + Count - 1) = 49
    If LLVMWriter.TryInitialize(State, Buffer) = False Then CheckInvalid = 11: Exit Function
    Status = LLVMFormat.TryFormat(State, Buffer, 0, Changed, LLVMTemplates.Branch, 1, 2, 3, 4)
    If Status Or State.Failure <> 3 Or State.Used <> 0 Then CheckInvalid = 12: Exit Function
    If BufferPrimitives.TryResizeBytes(Changed, 1, False) = False Then CheckInvalid = 13: Exit Function
    If LLVMFormat.TryValidateCatalog(Changed) Then CheckInvalid = 14: Exit Function
    If LLVMWriter.TryInitialize(State, Buffer) = False Then CheckInvalid = 15: Exit Function
    Status = LLVMFormat.TryFormat(State, Buffer, 0, Changed, LLVMTemplates.Branch, 1, 2, 3, 4)
    If Status Or State.Failure <> 3 Or State.Used <> 0 Then CheckInvalid = 16: Exit Function
    Do While Index < 2
        Shifted(Index + 1) = Catalog(Index)
        Index = Index + 1
    Loop
    If LLVMFormat.TryValidateCatalog(Shifted) Then CheckInvalid = 17: Exit Function
    If LLVMWriter.TryInitialize(State, Buffer) = False Then CheckInvalid = 18: Exit Function
    Status = LLVMFormat.TryFormat(State, Buffer, 0, Shifted, LLVMTemplates.Branch, 1, 2, 3, 4)
    If Status Or State.Failure <> 3 Or State.Used <> 0 Then CheckInvalid = 19
End Function
