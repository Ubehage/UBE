UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim iMin As Integer = -32767 - 1
    Dim iMax As Integer = 32767
    Dim lMin As Long = -2147483647 - 1
    Dim lMax As Long = 2147483647
    Dim score As Long = 0
    If iMin < iMax Then score = score + 1
    If Not (iMax < iMin) Then score = score + 1
    If iMin <= iMin Then score = score + 1
    If Not (iMax <= iMin) Then score = score + 1
    If iMax > iMin Then score = score + 1
    If Not (iMin > iMax) Then score = score + 1
    If iMax >= iMax Then score = score + 1
    If Not (iMin >= iMax) Then score = score + 1
    If iMin = iMin Then score = score + 1
    If Not (iMin = iMax) Then score = score + 1
    If iMin <> iMax Then score = score + 1
    If Not (iMax <> iMax) Then score = score + 1
    If lMin < lMax Then score = score + 1
    If Not (lMax < lMin) Then score = score + 1
    If lMin <= lMin Then score = score + 1
    If Not (lMax <= lMin) Then score = score + 1
    If lMax > lMin Then score = score + 1
    If Not (lMin > lMax) Then score = score + 1
    If lMax >= lMax Then score = score + 1
    If Not (lMin >= lMax) Then score = score + 1
    If lMin = lMin Then score = score + 1
    If Not (lMin = lMax) Then score = score + 1
    If lMin <> lMax Then score = score + 1
    If Not (lMax <> lMax) Then score = score + 1
    Main = score
End Function
