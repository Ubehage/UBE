UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private Function EchoSmall(ByVal value As NativeNumbers.SmallValue) As NativeNumbers.SmallValue
    EchoSmall = value
End Function
Private Function EchoWide(ByVal value As NativeNumbers.WideValue) As NativeNumbers.WideValue
    EchoWide = value
End Function
Private Sub ReplaceSmall(ByRef value As NativeNumbers.SmallValue, ByVal replacement As NativeNumbers.SmallValue)
    value = replacement
End Sub
Private Sub ReplaceWide(ByRef value As NativeNumbers.WideValue, ByVal replacement As NativeNumbers.WideValue)
    value = replacement
End Sub
Function Main() As Long
    Dim smallLow As NativeNumbers.SmallValue = NativeNumbers.PackSmall(-32768)
    Dim smallHigh As NativeNumbers.SmallValue = NativeNumbers.PackSmall(32767)
    Dim wideLow As NativeNumbers.WideValue = NativeNumbers.PackWide(-2147483648)
    Dim wideHigh As NativeNumbers.WideValue = NativeNumbers.PackWide(2147483647)
    Dim smallLowCopy As NativeNumbers.SmallValue = EchoSmall(smallLow)
    Dim smallHighCopy As NativeNumbers.SmallValue = EchoSmall(smallHigh)
    Dim wideLowCopy As NativeNumbers.WideValue = EchoWide(wideLow)
    Dim wideHighCopy As NativeNumbers.WideValue = EchoWide(wideHigh)
    Call ReplaceSmall(smallLow, smallHighCopy)
    Call ReplaceSmall(smallHigh, smallLowCopy)
    Call ReplaceWide(wideLow, wideHighCopy)
    Call ReplaceWide(wideHigh, wideLowCopy)
    Dim score As Long = 0
    If NativeNumbers.UnpackSmall(smallLowCopy) = -32768 Then score = score + 1
    If NativeNumbers.UnpackSmall(smallHighCopy) = 32767 Then score = score + 2
    If NativeNumbers.UnpackWide(wideLowCopy) = -2147483648 Then score = score + 4
    If NativeNumbers.UnpackWide(wideHighCopy) = 2147483647 Then score = score + 8
    If NativeNumbers.UnpackSmall(smallLow) = 32767 Then score = score + 16
    If NativeNumbers.UnpackSmall(smallHigh) = -32768 Then score = score + 32
    If NativeNumbers.UnpackWide(wideLow) = 2147483647 Then score = score + 64
    If NativeNumbers.UnpackWide(wideHigh) = -2147483648 Then score = score + 128
    Main = score
End Function
