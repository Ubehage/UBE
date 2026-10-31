UBE SOURCE 1 MODULE
Attribute UBE_Name = "Utf8Cursor"

' Borrows an immutable zero-based byte array for one scalar read at ByteOffset.
' True returns a Unicode scalar and width 1..4. False (bad offset, truncated or
' malformed UTF-8) returns Scalar=0 and ScalarWidth=0; EOF is also False. No allocation,
' copying, retained references, global state or Err change. Calls are reentrant;
' callers synchronize mutation of shared Bytes. Outputs must be distinct and
' must not alias Bytes.
Function TryReadSourceScalar(ByRef Bytes() As Byte, ByVal ByteOffset As Long, ByRef Scalar As Long, ByRef ScalarWidth As Long) As Boolean
    TryReadSourceScalar = False
    Scalar = 0
    ScalarWidth = 0
    Dim Length As Long = ByteStorageLength(Bytes)
    If ByteOffset < 0 Or ByteOffset >= Length Then
        Exit Function
    End If
    Dim Decoder As Utf8Decoder
    Dim Complete As Boolean = False
    Dim Value As Long = 0
    Dim Consumed As Long = 0
    While Consumed < 4 And Consumed < Length - ByteOffset
        If FeedUtf8Byte(Decoder, Bytes(ByteOffset + Consumed), Value, Complete) = False Then
            Exit Function
        End If
        Consumed = Consumed + 1
        If Complete Then
            Scalar = Value
            ScalarWidth = Consumed
            TryReadSourceScalar = True
            Exit Function
        End If
    Wend
End Function
