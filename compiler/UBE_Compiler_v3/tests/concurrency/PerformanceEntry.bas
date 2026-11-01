UBE SOURCE 1 MODULE
Attribute UBE_Name = "FrontendPerformanceEntry"

' Test admission adapter. All qualification and source work remain production UBE.
Function MakePerformanceCancellation() As SourceCancellation
    Set MakePerformanceCancellation = New SourceCancellation
End Function

Function TryMakePerformanceOwner(ByRef Bytes() As Byte, ByVal SourceId As Long, ByRef Published As SourceOwner) As Boolean
    TryMakePerformanceOwner = False
    Dim Pending As SourceOwner
    Set Pending = New SourceOwner
    If Pending Is Nothing Then
        Exit Function
    End If
    Dim Input As SourceInput
    Dim Failure As SourceFailure
    Failure.Kind = 5
    If BeginSourceInput(Input, ByteStorageLength(Bytes)) = False Then
        Exit Function
    End If
    If AppendSourceInput(Input, Bytes, 0, ByteStorageLength(Bytes), Failure) = False Then
        Exit Function
    End If
    If TryFinishSourceInput(Input, Pending.Document, Failure) = False Then
        Exit Function
    End If
    Pending.SourceId = SourceId
    Set Published = Pending
    TryMakePerformanceOwner = True
End Function

Function Main() As Long
    Main = 0
End Function
