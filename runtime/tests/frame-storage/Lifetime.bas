UBE SOURCE 1 MODULE
Attribute UBE_Name = "FrameLifetime"

Private Calls As Long
Private Intrinsic Function CollectGarbage() As Long
Attribute CollectGarbage.UBE_Primitive = "Memory.Collect"
End Function

Private Function Target() As Long
    Dim Values(0 To 776) As Long
    Values(0) = 747474
    Calls = Calls + 1
    Target = 99
End Function

Private Function Descend(ByVal Count As Long) As Long
    Dim DepthStorage(0 To 128) As Long
    On Error GoTo Failed
    DepthStorage(0) = Count
    If Count > 0 Then
        Descend = Descend(Count - 1)
    Else
        Descend = 17
    End If
    If DepthStorage(0) <> Count Then Err.Raise 92
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

Public Function Main() As Long
    Dim Kept As Long = 42
    Dim Rooted As String = "frame-root"
    On Error Resume Next
    Kept = Target()
    If Kept <> 42 Or Calls <> 0 Or Err.Number <> 7 Then Main = 1: Exit Function
    Call CollectGarbage()
    If Rooted <> "frame-root" Then Main = 2: Exit Function
    Kept = Target()
    If Kept <> 99 Or Calls <> 1 Or Err.Number <> 7 Then Main = 3: Exit Function
    Kept = 42
    Kept = Descend(300)
    If Kept <> 42 Or Err.Number <> 28 Then Main = 4: Exit Function
    Call CollectGarbage()
    If Rooted <> "frame-root" Then Main = 5: Exit Function
    Kept = Descend(2)
    If Kept <> 17 Or Err.Number <> 28 Then Main = 6: Exit Function
End Function
