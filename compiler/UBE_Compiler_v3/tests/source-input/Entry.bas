UBE SOURCE 1 MODULE
Attribute UBE_Name = "SourceInputProof"

Function ScopedSourceInput(ByVal Cancel As Boolean) As Boolean
    ScopedSourceInput = False
    Dim State As SourceInput
    Dim Document As SourceDocument
    Dim Failure As SourceFailure
    Dim Bytes() As Byte
    ReDim Bytes(0)
    Bytes(0) = 65
    If BeginSourceInput(State, 1) = False Then
        Exit Function
    End If
    If AppendSourceInput(State, Bytes, 0, 1, Failure) = False Then
        Exit Function
    End If
    If Cancel Then
        Exit Function
    End If
    ScopedSourceInput = TryFinishSourceInput(State, Document, Failure)
End Function

Function CopySourceDocument(ByRef Destination As SourceDocument, ByRef Original As SourceDocument) As Boolean
    Destination = Original
    CopySourceDocument = True
End Function

Function Main() As Long
    Main = 0
End Function
