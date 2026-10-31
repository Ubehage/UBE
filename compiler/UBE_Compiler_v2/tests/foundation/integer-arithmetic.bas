Function Main() As Long
    Dim Left As Integer = 200
    Dim Right As Integer = 100
    Print Left + Right
    Print Left - Right
    Print Left * Right
    Print Left \ Right
    Print Left Mod Right
    Print -Right
    Dim Octet As Byte = 255
    Print Octet + Octet
    Print +Octet
    Print -Octet
    Print Octet And Octet
    Print Not Octet
    Print -2147483648
    Dim Maximum As Integer = 32767
    Dim One As Integer = 1
    Print Maximum + One
    Dim TooLarge As Long = 256
    Octet = TooLarge
    Print Octet
    Dim Zero As Integer = 0
    Print Right \ Zero
    Print Right Mod Zero
    Dim Values() As Integer
    ReDim Values(1)
    Values(0) = -32768
    Values(1) = 32767
    ReDim Preserve Values(2)
    Print Values(0)
    Print Values(1)
    Print Values(2)
    Main = 0
End Function
