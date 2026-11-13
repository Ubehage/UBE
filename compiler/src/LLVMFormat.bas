UBE SOURCE 1 MODULE
Attribute UBE_Name = "LLVMFormat"
' Substitutes exact numeric operands into reviewed ASCII fragments without managed Strings.

' Invalid template input latches the writer without masking an earlier emission failure.
Private Function Reject(ByRef State As LLVMWriter.WriterState) As Boolean
    If State.Failed Then Exit Function
    State.Failed = True
    State.Failure = 3
    State.ErrorNumber = Err.Number
End Function

' Checks accidental catalog corruption; full source parity is enforced by the generation tool.
Public Function TryValidateCatalog(ByRef Catalog() As Byte) As Boolean
    Dim Length As Long
    Dim Index As Long
    Dim Character As Long
    Dim Sum As Long
    On Error GoTo InvalidCatalog
    Length = BufferPrimitives.ByteStorageLength(Catalog)
    If Length <> LLVMTemplates.CatalogLength Then Exit Function
    Do While Index < Length
        Character = Catalog(Index)
        If Character <> 9 And Character <> 10 And Character <> 13 Then
            If Character < 32 Or Character > 126 Then Exit Function
        End If
        Sum = Sum + Character
        Index = Index + 1
    Loop
    TryValidateCatalog = Sum = LLVMTemplates.CatalogByteSum
    Exit Function
InvalidCatalog:
    TryValidateCatalog = False
End Function

' Validates all characters and numeric placeholders before emitting any part of the fragment.
Private Function ValidSpan(ByRef Catalog() As Byte, ByVal Start As Long, ByVal Count As Long) As Boolean
    Dim Length As Long
    Dim Position As Long
    Dim Finish As Long
    Dim Character As Long
    Dim NextCharacter As Long
    Dim Probe As Byte
    On Error GoTo InvalidSpan
    Length = BufferPrimitives.ByteStorageLength(Catalog)
    If Start < 0 Or Count < 0 Or Start > Length Then Exit Function
    If Count > Length - Start Then Exit Function
    If Length > 0 Then
        Probe = Catalog(0)
        Probe = Catalog(Length - 1)
    End If
    Position = Start
    Finish = Start + Count
    Do While Position < Finish
        Character = Catalog(Position)
        If Character <> 9 And Character <> 10 And Character <> 13 Then
            If Character < 32 Or Character > 126 Then Exit Function
        End If
        If Character = 123 And Position + 1 < Finish Then
            NextCharacter = Catalog(Position + 1)
            If NextCharacter >= 48 And NextCharacter <= 57 Then
                If NextCharacter > 51 Or Finish - Position < 3 Then Exit Function
                If Catalog(Position + 2) <> 125 Then Exit Function
            End If
        End If
        Position = Position + 1
    Loop
    ValidSpan = True
    Exit Function
InvalidSpan:
    ValidSpan = False
End Function

' Formats one selected span after callers validate the immutable complete catalog once per request.
Public Function TryFormat(ByRef State As LLVMWriter.WriterState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Template As Long, ByVal P0 As LongLong, ByVal P1 As LongLong, ByVal P2 As LongLong, ByVal P3 As LongLong) As Boolean
    Dim Start As Long
    Dim Count As Long
    Dim Position As Long
    Dim Finish As Long
    Dim LiteralStart As Long
    Dim Slot As Long
    Dim Value As LongLong
    On Error GoTo InvalidTemplate
    If State.Failed Then Exit Function
    If LLVMTemplates.TrySpan(Template, Start, Count) = False Then TryFormat = Reject(State): Exit Function
    If ValidSpan(Catalog, Start, Count) = False Then TryFormat = Reject(State): Exit Function
    Position = Start
    LiteralStart = Start
    Finish = Start + Count
    Do While Position < Finish
        Slot = -1
        If Catalog(Position) = 123 And Finish - Position >= 3 Then
            If Catalog(Position + 1) >= 48 And Catalog(Position + 1) <= 51 Then Slot = Catalog(Position + 1) - 48
        End If
        If Slot >= 0 Then
            If LLVMWriter.TryAppendSpan(State, Buffer, Token, Catalog, LiteralStart, Position - LiteralStart) = False Then Exit Function
            Value = P0
            If Slot = 1 Then Value = P1
            If Slot = 2 Then Value = P2
            If Slot = 3 Then Value = P3
            If LLVMWriter.TryAppendInteger(State, Buffer, Token, Value) = False Then Exit Function
            Position = Position + 3
            LiteralStart = Position
        Else
            Position = Position + 1
        End If
    Loop
    TryFormat = LLVMWriter.TryAppendSpan(State, Buffer, Token, Catalog, LiteralStart, Finish - LiteralStart)
    Exit Function
InvalidTemplate:
    TryFormat = Reject(State)
End Function

' Appends one CRLF after a formatted fragment; embedded template newlines remain unchanged.
Public Function TryLine(ByRef State As LLVMWriter.WriterState, ByRef Buffer() As Byte, ByVal Token As Long, ByRef Catalog() As Byte, ByVal Template As Long, ByVal P0 As LongLong, ByVal P1 As LongLong, ByVal P2 As LongLong, ByVal P3 As LongLong) As Boolean
    On Error GoTo InvalidTemplate
    If TryFormat(State, Buffer, Token, Catalog, Template, P0, P1, P2, P3) = False Then Exit Function
    TryLine = LLVMWriter.TryEndLine(State, Buffer, Token)
    Exit Function
InvalidTemplate:
    TryLine = Reject(State)
End Function
