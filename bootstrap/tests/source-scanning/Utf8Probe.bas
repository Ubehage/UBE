UBE SOURCE 1 MODULE
Attribute UBE_Name = "Utf8Probe"
' Independent byte-width, UTF-16-width, status and error observations for the portable UTF-8 helper.

' Seeds an old runtime error without making a later successful helper erase it.
Private Sub SeedError()
    Err.Raise 77
End Sub

' Checks every output, seeding widths so a missing failure reset cannot pass.
Private Function CheckArray(ByRef Bytes() As Byte, ByVal Offset As Long, ByVal Length As Long, ByVal ExpectedBytes As Long, ByVal ExpectedUtf16 As Long, ByVal ExpectedStatus As Boolean, ByVal ExpectedError As Long) As Boolean
    Dim ByteWidth As Long = 99
    Dim Utf16Width As Long = 99
    Dim Accepted As Boolean
    SeedError
    Accepted = Utf8.TrySequenceWidth(Bytes, Offset, Length, ByteWidth, Utf16Width)
    CheckArray = Accepted = ExpectedStatus And ByteWidth = ExpectedBytes And Utf16Width = ExpectedUtf16 And Err.Number = ExpectedError
End Function

' Constructs one explicit encoding without deriving expected widths from the implementation.
Private Function CheckSequence(ByVal First As Byte, ByVal Second As Byte, ByVal Third As Byte, ByVal Fourth As Byte, ByVal Length As Long, ByVal ExpectedBytes As Long, ByVal ExpectedUtf16 As Long, ByVal Accepted As Boolean) As Boolean
    Dim Bytes(0 To 3) As Byte
    Bytes(0) = First
    Bytes(1) = Second
    Bytes(2) = Third
    Bytes(3) = Fourth
    CheckSequence = CheckArray(Bytes, 0, Length, ExpectedBytes, ExpectedUtf16, Accepted, 77)
End Function

' Returns the first independent failed case; runtime input changes the ASCII oracle in the negative control.
Public Function Run(ByVal RuntimeByte As Long) As Long
    Dim Bytes(0 To 3) As Byte
    Dim Positive(1 To 4) As Byte
    Dim Negative(-1 To 2) As Byte
    Dim EmptyBytes() As Byte
    If Not CheckSequence(RuntimeByte, 0, 0, 0, 1, 1, 1, True) Then Run = 1: Exit Function
    If Not CheckSequence(0, 0, 0, 0, 1, 1, 1, True) Then Run = 2: Exit Function
    If Not CheckSequence(127, 0, 0, 0, 1, 1, 1, True) Then Run = 3: Exit Function
    If Not CheckSequence(194, 128, 0, 0, 2, 2, 1, True) Then Run = 4: Exit Function
    If Not CheckSequence(223, 191, 0, 0, 2, 2, 1, True) Then Run = 5: Exit Function
    If Not CheckSequence(224, 160, 128, 0, 3, 3, 1, True) Then Run = 6: Exit Function
    If Not CheckSequence(237, 159, 191, 0, 3, 3, 1, True) Then Run = 7: Exit Function
    If Not CheckSequence(238, 128, 128, 0, 3, 3, 1, True) Then Run = 8: Exit Function
    If Not CheckSequence(239, 191, 191, 0, 3, 3, 1, True) Then Run = 9: Exit Function
    If Not CheckSequence(240, 144, 128, 128, 4, 4, 2, True) Then Run = 10: Exit Function
    If Not CheckSequence(244, 143, 191, 191, 4, 4, 2, True) Then Run = 11: Exit Function
    If Not CheckSequence(192, 128, 0, 0, 2, 0, 0, False) Then Run = 12: Exit Function
    If Not CheckSequence(193, 191, 0, 0, 2, 0, 0, False) Then Run = 13: Exit Function
    If Not CheckSequence(224, 159, 191, 0, 3, 0, 0, False) Then Run = 14: Exit Function
    If Not CheckSequence(237, 160, 128, 0, 3, 0, 0, False) Then Run = 15: Exit Function
    If Not CheckSequence(237, 191, 191, 0, 3, 0, 0, False) Then Run = 16: Exit Function
    If Not CheckSequence(240, 143, 191, 191, 4, 0, 0, False) Then Run = 17: Exit Function
    If Not CheckSequence(244, 144, 128, 128, 4, 0, 0, False) Then Run = 18: Exit Function
    If Not CheckSequence(245, 128, 128, 128, 4, 0, 0, False) Then Run = 19: Exit Function
    If Not CheckSequence(255, 128, 128, 128, 4, 0, 0, False) Then Run = 20: Exit Function
    If Not CheckSequence(128, 0, 0, 0, 1, 0, 0, False) Then Run = 21: Exit Function
    If Not CheckSequence(194, 127, 0, 0, 2, 0, 0, False) Then Run = 22: Exit Function
    If Not CheckSequence(194, 192, 0, 0, 2, 0, 0, False) Then Run = 23: Exit Function
    If Not CheckSequence(225, 128, 65, 0, 3, 0, 0, False) Then Run = 24: Exit Function
    If Not CheckSequence(241, 128, 128, 192, 4, 0, 0, False) Then Run = 25: Exit Function
    If Not CheckSequence(194, 128, 0, 0, 1, 0, 0, False) Then Run = 26: Exit Function
    If Not CheckSequence(224, 160, 128, 0, 2, 0, 0, False) Then Run = 27: Exit Function
    If Not CheckSequence(240, 144, 128, 128, 3, 0, 0, False) Then Run = 28: Exit Function
    Bytes(0) = 65
    Bytes(1) = 194
    Bytes(2) = 128
    If Not CheckArray(Bytes, 1, 3, 2, 1, True, 77) Then Run = 29: Exit Function
    If Not CheckArray(Bytes, -1, 4, 0, 0, False, 77) Then Run = 30: Exit Function
    If Not CheckArray(Bytes, 4, 4, 0, 0, False, 77) Then Run = 31: Exit Function
    If Not CheckArray(Bytes, 0, -1, 0, 0, False, 77) Then Run = 32: Exit Function
    If Not CheckArray(Bytes, 0, 5, 0, 0, False, 77) Then Run = 33: Exit Function
    If Not CheckArray(Bytes, 0, 0, 0, 0, False, 77) Then Run = 34: Exit Function
    If Not CheckArray(Positive, 0, 4, 0, 0, False, 9) Then Run = 35: Exit Function
    If Not CheckArray(Negative, 0, 4, 0, 0, False, 9) Then Run = 36: Exit Function
    If Not CheckArray(EmptyBytes, 0, 0, 0, 0, False, 77) Then Run = 37: Exit Function
    Run = 0
End Function
