UBE SOURCE 1 MODULE
Attribute UBE_Name = "WriterLimits"

Public Function Main() As Long
    Dim State As LLVMWriter.WriterState
    Dim Buffer() As Byte
    Dim Fragment() As Byte
    Dim Path(0 To 15) As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Index As Long
    Dim Repeat As Long
    On Error GoTo Failed
    Path(0) = 119: Path(1) = 114: Path(2) = 105: Path(3) = 116
    Path(4) = 101: Path(5) = 114: Path(6) = 45: Path(7) = 111
    Path(8) = 117: Path(9) = 116: Path(10) = 112: Path(11) = 117
    Path(12) = 116: Path(13) = 46: Path(14) = 108: Path(15) = 108
    If Not BufferPrimitives.TryResizeBytes(Fragment, 65536, False) Then Main = 1: Exit Function
    Do While Index < 65536
        Fragment(Index) = 97
        If Index Mod 64 = 63 Then Fragment(Index) = 10
        Index = Index + 1
    Loop
    If Not FilePrimitives.TryCreateNew(Path, Token, Failure) Then Main = 2: Exit Function
    If Not LLVMWriter.TryInitialize(State, Buffer) Then Main = 3: GoTo Cleanup
    Do While Repeat < 513
        If Not LLVMWriter.TryAppendSpan(State, Buffer, Token, Fragment, 0, 65536) Then Main = 4: GoTo Cleanup
        Repeat = Repeat + 1
    Loop
    If State.TotalBytes <> 33619968^ Or State.LineCount <> 525312^ Then Main = 5: GoTo Cleanup
    If Not LLVMWriter.TryFinish(State, Buffer, Token) Then Main = 6: GoTo Cleanup
    If LLVMWriter.TryAppendSpan(State, Buffer, Token, Fragment, -1, 1) Then Main = 7: GoTo Cleanup
    If State.TotalBytes <> 33619968^ Or State.LineCount <> 525312^ Then Main = 8: GoTo Cleanup
    If Not State.Failed Then Main = 9
Cleanup:
    If Not FilePrimitives.TryClose(Token, Failure) Then Main = 10
    Exit Function
Failed:
    Main = 250
    GoTo Cleanup
End Function
