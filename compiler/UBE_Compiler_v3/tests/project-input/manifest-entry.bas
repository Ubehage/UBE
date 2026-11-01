UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManifestProof"

Function TryMakeManifestDocument(ByRef Bytes() As Byte, ByRef Document As SourceDocument, ByRef Failure As SourceFailure) As Boolean
    TryMakeManifestDocument = False
    Dim State As SourceInput
    Failure.Kind = 5
    If BeginSourceInput(State, 1048576) = False Then
        Exit Function
    End If
    If AppendSourceInput(State, Bytes, 0, ByteStorageLength(Bytes), Failure) = False Then
        Exit Function
    End If
    Failure.Kind = 5
    TryMakeManifestDocument = TryFinishSourceInput(State, Document, Failure)
End Function

Function Main() As Long
    Main = 0
End Function
