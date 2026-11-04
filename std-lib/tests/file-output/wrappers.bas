Function OutputWrite(ByVal Token As Long, ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef WrittenCount As Long, ByRef Failure As Long) As Boolean
    OutputWrite = TryWriteByteFile(Token, Source, Start, Count, WrittenCount, Failure)
End Function

Function OutputFlush(ByVal Token As Long, ByRef Failure As Long) As Boolean
    OutputFlush = TryFlushByteFile(Token, Failure)
End Function

Function Main() As Long
    Main = 0
End Function
