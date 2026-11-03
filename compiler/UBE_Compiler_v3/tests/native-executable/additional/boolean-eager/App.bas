UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private leftCount As Long
Private rightCount As Long
Private Function LeftValue(ByVal value As Boolean) As Boolean
    leftCount = leftCount + 1
    LeftValue = value
End Function
Private Function RightValue(ByVal value As Boolean) As Boolean
    rightCount = rightCount + 1
    RightValue = value
End Function
Function Main() As Long
    Dim ff As Boolean = LeftValue(False) And RightValue(False)
    Dim ft As Boolean = LeftValue(False) And RightValue(True)
    Dim tf As Boolean = LeftValue(True) And RightValue(False)
    Dim tt As Boolean = LeftValue(True) And RightValue(True)
    If ff OrElse ft OrElse tf OrElse (tt = False) OrElse leftCount <> 4 OrElse rightCount <> 4 Then
        Main = 91
        Exit Function
    End If
    leftCount = 0
    rightCount = 0
    ff = LeftValue(False) Or RightValue(False)
    ft = LeftValue(False) Or RightValue(True)
    tf = LeftValue(True) Or RightValue(False)
    tt = LeftValue(True) Or RightValue(True)
    If ff OrElse (ft = False) OrElse (tf = False) OrElse (tt = False) OrElse leftCount <> 4 OrElse rightCount <> 4 Then
        Main = 92
        Exit Function
    End If
    Main = 63
End Function
