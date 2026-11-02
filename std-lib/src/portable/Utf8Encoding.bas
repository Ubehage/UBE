UBE SOURCE 1 MODULE
Attribute UBE_Name = "Utf8Encoding"

' Contract: ../../UTF8-ENCODING-CONTRACT.md.
' Encodes one Unicode scalar into four byte slots (unused slots zero) and width.
' Invalid scalars preserve all outputs. Outputs must be distinct. No allocation,
' payload copying, managed roots, retained state or Err change; reentrant.
Function TryEncodeUtf8Scalar(ByVal Scalar As Long, ByRef B0 As Byte, ByRef B1 As Byte, ByRef B2 As Byte, ByRef B3 As Byte, ByRef ScalarWidth As Long) As Boolean
    TryEncodeUtf8Scalar = False
    If Scalar < 0 Or Scalar > 1114111 Then
        Exit Function
    End If
    If Scalar >= 55296 And Scalar <= 57343 Then
        Exit Function
    End If
    Dim C0 As Byte = 0
    Dim C1 As Byte = 0
    Dim C2 As Byte = 0
    Dim C3 As Byte = 0
    Dim Count As Long = 1
    If Scalar <= 127 Then
        C0 = Scalar
    Else
        If Scalar <= 2047 Then
            Count = 2
            C0 = 192 + Scalar \ 64
            C1 = 128 + Scalar Mod 64
        Else
            If Scalar <= 65535 Then
                Count = 3
                C0 = 224 + Scalar \ 4096
                C1 = 128 + (Scalar \ 64) Mod 64
                C2 = 128 + Scalar Mod 64
            Else
                Count = 4
                C0 = 240 + Scalar \ 262144
                C1 = 128 + (Scalar \ 4096) Mod 64
                C2 = 128 + (Scalar \ 64) Mod 64
                C3 = 128 + Scalar Mod 64
            End If
        End If
    End If
    B0 = C0
    B1 = C1
    B2 = C2
    B3 = C3
    ScalarWidth = Count
    TryEncodeUtf8Scalar = True
End Function
