UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Function Main() As Long
    Dim small As Integer = -32767 - 1
    Dim large As Integer = 32767
    Dim minimum As Long = -2147483647 - 1
    Dim maximum As Long = 2147483647
    Dim wideMinimum As LongLong = -9223372036854775808
    Dim wideMaximum As LongLong = 9223372036854775807
    Dim wideBit As LongLong = 4294967296
    Dim wideZero As LongLong = 0
    Dim byteMinimum As Byte = 0
    Dim byteMaximum As Byte = 255
    Dim score As Long = 0
    If small < large Then score = score + 1
    If large < small Then
    Else
        score = score + 1
    End If
    If minimum <= minimum Then score = score + 1
    If maximum <= minimum Then
    Else
        score = score + 1
    End If
    If maximum > minimum Then score = score + 1
    If minimum > maximum Then
    Else
        score = score + 1
    End If
    If large >= large Then score = score + 1
    If small >= large Then
    Else
        score = score + 1
    End If
    If minimum = minimum Then score = score + 1
    If minimum = maximum Then
    Else
        score = score + 1
    End If
    If minimum <> maximum Then score = score + 1
    If large <> large Then
    Else
        score = score + 1
    End If
    If wideMinimum < wideMaximum Then score = score + 1
    If Not (wideMaximum < wideMinimum) Then score = score + 1
    If wideMinimum <= wideMinimum Then score = score + 1
    If Not (wideMaximum <= wideMinimum) Then score = score + 1
    If wideBit > wideZero Then score = score + 1
    If Not (wideMinimum > wideMaximum) Then score = score + 1
    If wideMaximum >= wideMaximum Then score = score + 1
    If Not (wideMinimum >= wideMaximum) Then score = score + 1
    If wideBit = wideBit Then score = score + 1
    If Not (wideBit = wideZero) Then score = score + 1
    If wideBit <> wideZero Then score = score + 1
    If Not (wideMinimum <> wideMinimum) Then score = score + 1
    If byteMinimum < byteMaximum Then score = score + 1
    If Not (byteMaximum < byteMinimum) Then score = score + 1
    If byteMinimum <= byteMinimum Then score = score + 1
    If Not (byteMaximum <= byteMinimum) Then score = score + 1
    If byteMaximum > byteMinimum Then score = score + 1
    If Not (byteMinimum > byteMaximum) Then score = score + 1
    If byteMaximum >= byteMaximum Then score = score + 1
    If Not (byteMinimum >= byteMaximum) Then score = score + 1
    If byteMinimum = byteMinimum Then score = score + 1
    If Not (byteMinimum = byteMaximum) Then score = score + 1
    If byteMinimum <> byteMaximum Then score = score + 1
    If Not (byteMaximum <> byteMaximum) Then score = score + 1
    Main = score
End Function
