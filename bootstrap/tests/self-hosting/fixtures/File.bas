UBE SOURCE 1 MODULE
Attribute UBE_Name = "Entry"
' Roundtrips exact bytes through explicit file owners in the harness's private working directory.
Public Function Main() As Long
    Dim Path(0 To 12) As Byte
    Dim Bytes(0 To 3) As Byte
    Dim ReadBack(0 To 3) As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Progress As Long
    Dim Length As Long
    Path(0) = 114: Path(1) = 111: Path(2) = 117: Path(3) = 110
    Path(4) = 100: Path(5) = 116: Path(6) = 114: Path(7) = 105
    Path(8) = 112: Path(9) = 46: Path(10) = 98: Path(11) = 105: Path(12) = 110
    Bytes(0) = 0: Bytes(1) = 42: Bytes(2) = 128: Bytes(3) = 255
    If Not FilePrimitives.TryCreateNew(Path, Token, Failure) Then Main = 1: Exit Function
    If Not FilePrimitives.TryWrite(Token, Bytes, 0, 4, Progress, Failure) Then Main = 2: Exit Function
    If Progress <> 4 Then Main = 3: Exit Function
    If Not FilePrimitives.TryClose(Token, Failure) Then Main = 4: Exit Function
    If Not FilePrimitives.TryOpen(Path, 16, Token, Length, Failure) Then Main = 5: Exit Function
    If Length <> 4 Then Main = 6: Exit Function
    If Not FilePrimitives.TryRead(Token, ReadBack, 0, 4, Progress, Failure) Then Main = 7: Exit Function
    If Progress <> 4 Then Main = 8: Exit Function
    If Not FilePrimitives.TryClose(Token, Failure) Then Main = 9: Exit Function
    If ReadBack(0) <> 0 Or ReadBack(1) <> 42 Or ReadBack(2) <> 128 Or ReadBack(3) <> 255 Then Main = 10: Exit Function
    Main = 42
End Function
