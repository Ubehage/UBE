UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private DepthReached As Boolean

Private Sub BeyondDepth()
    DepthReached = False
End Sub

Private Function AtDepth(ByRef Destination() As Long, ByRef Source() As Long, ByVal Remaining As Long) As Boolean
    On Error GoTo Limited
    If Remaining > 0 Then
        AtDepth = AtDepth(Destination, Source, Remaining - 1)
        Exit Function
    End If
    DepthReached = True
    If Not Move(Destination, Source) Then Exit Function
    If Length(Source) <> 0 Or Length(Destination) <> 1 Then Exit Function
    Call BeyondDepth()
    Exit Function
Limited:
    If Not DepthReached Or Err.Number <> 28 Then Exit Function
    If Not Move(Source, Destination) Then Exit Function
    AtDepth = Length(Source) = 1 And Length(Destination) = 0 And Err.Number = 28
End Function

Private Intrinsic Function Move(ByRef Destination() As Long, ByRef Source() As Long) As Boolean
Attribute Move.UBE_Primitive = "Array.Move"
End Function

Private Intrinsic Function Resize(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute Resize.UBE_Primitive = "Array.TryResize"
End Function

Private Intrinsic Function Length(ByRef Values() As Long) As Long
Attribute Length.UBE_Primitive = "Array.Length"
End Function

Private Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function

' Checks source wrapper publication, bounds, preserved errors and inline refusal.
Public Function Main() As Long
    Dim Source() As Long
    Dim Destination() As Long
    Dim Fixed(4 To 5) As Long
    If Not Resize(Source, 2, False) Then Main = 1: Exit Function
    If Not Resize(Destination, 3, False) Then Main = 2: Exit Function
    Source(0) = 123
    Source(1) = 456
    Call RecordError(91)
    If Not Move(Destination, Source) Then Main = 3: Exit Function
    If Length(Source) <> 0 Or Length(Destination) <> 2 Then Main = 4: Exit Function
    If Destination(0) <> 123 Or Destination(1) <> 456 Then Main = 5: Exit Function
    If Err.Number <> 91 Then Main = 6: Exit Function
    Fixed(4) = 71
    Fixed(5) = 73
    If Not Move(Fixed, Fixed) Then Main = 7: Exit Function
    If Move(Destination, Fixed) Then Main = 8: Exit Function
    If Err.Number <> 5 Or Fixed(4) <> 71 Or Fixed(5) <> 73 Then Main = 9: Exit Function
    If Destination(0) <> 123 Or Destination(1) <> 456 Then Main = 10: Exit Function
    If Not Move(Fixed, Destination) Then Main = 11: Exit Function
    If Length(Destination) <> 0 Or Length(Fixed) <> 2 Then Main = 12: Exit Function
    If Fixed(0) <> 123 Or Fixed(1) <> 456 Then Main = 13: Exit Function
    If Not Move(Fixed, Destination) Then Main = 14: Exit Function
    If Length(Fixed) <> 0 Then Main = 15: Exit Function
    If Not Resize(Source, 1, False) Then Main = 16: Exit Function
    Source(0) = 313
    If Not AtDepth(Destination, Source, 254) Then Main = 17: Exit Function
    If Not DepthReached Or Source(0) <> 313 Then Main = 18: Exit Function
End Function
