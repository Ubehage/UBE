UBE SOURCE 1 MODULE
Attribute UBE_Name = "BenchmarkDriver"
Option Explicit

' Runtime input uses two deliberately bounded single-digit arguments: batch and seed.
' Zero batch measures the same image's startup/argument/reporting/shutdown baseline.
Private Function ReadInput(ByRef Batch As Long, ByRef Seed As Long) As Boolean
    Dim CommandLine() As Byte
    Dim Argument() As Byte
    Dim Count As Long
    Dim Failure As Long
    Dim Found As Boolean
    On Error GoTo Failed
    If Not BufferPrimitives.TryResizeBytes(CommandLine, 32768, False) Then Exit Function
    If Not SystemPrimitives.TryReadCommandLine(CommandLine, Count, Failure) Then Exit Function
    If Not BufferPrimitives.TryResizeBytes(CommandLine, Count, True) Then Exit Function
    If Not WindowsArguments.TryReadArgument(CommandLine, 1, Argument, Found) Then Exit Function
    If Not Found Then Exit Function
    If BufferPrimitives.ByteStorageLength(Argument) <> 1 Then Exit Function
    If Argument(0) < 48 Or Argument(0) > 57 Then Exit Function
    Batch = Argument(0) - 48
    If Not WindowsArguments.TryReadArgument(CommandLine, 2, Argument, Found) Then Exit Function
    If Not Found Then Exit Function
    If BufferPrimitives.ByteStorageLength(Argument) <> 1 Then Exit Function
    If Argument(0) < 49 Or Argument(0) > 57 Then Exit Function
    Seed = Argument(0) - 48
    If Not WindowsArguments.TryReadArgument(CommandLine, 3, Argument, Found) Then Exit Function
    If Found Then Exit Function
    ReadInput = True
    Exit Function
Failed:
    ReadInput = False
End Function

Private Function Report(ByVal Checksum As LongLong, ByVal Elapsed As LongLong, ByVal Count As Long, ByVal Seed As Long) As Boolean
    Dim Bytes(0 To 127) As Byte
    Dim Used As Long
    Dim Failure As Long
    On Error GoTo Failed
    If Not ByteText.TryAppendInteger(Bytes, Used, Checksum) Then Exit Function
    Bytes(Used) = 44: Used = Used + 1
    If Not ByteText.TryAppendInteger(Bytes, Used, Elapsed) Then Exit Function
    Bytes(Used) = 44: Used = Used + 1
    If Not ByteText.TryAppendInteger(Bytes, Used, Count) Then Exit Function
    Bytes(Used) = 44: Used = Used + 1
    If Not ByteText.TryAppendInteger(Bytes, Used, Seed) Then Exit Function
    Bytes(Used) = 10: Used = Used + 1
    Report = StandardStreams.TryWriteBytes(1, Bytes, 0, Used, Failure)
    Exit Function
Failed:
    Report = False
End Function

Public Function Main() As Long
    Dim Batch As Long
    Dim Seed As Long
    Dim Count As Long
    Dim Started As LongLong
    Dim Finished As LongLong
    Dim Checksum As LongLong
    Dim Failure As Long
    On Error GoTo Failed
    Main = 90
    If Not ReadInput(Batch, Seed) Then Main = 2: Exit Function
    Count = Batch * Workload.IterationsPerBatch
    If Not SystemPrimitives.TryMonotonicMilliseconds(Started, Failure) Then Exit Function
    Checksum = Workload.Run(Count, Seed)
    If Not SystemPrimitives.TryMonotonicMilliseconds(Finished, Failure) Then Exit Function
    If Finished < Started Then Exit Function
    If Not Report(Checksum, Finished - Started, Count, Seed) Then Exit Function
    Main = 0
    Exit Function
Failed:
    Main = 90
End Function
