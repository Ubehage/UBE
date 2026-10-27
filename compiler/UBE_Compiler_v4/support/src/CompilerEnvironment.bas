UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerEnvironment"

' Returns the number of separately captured command arguments.
Public Function CompilerArgumentCount() As Long
    CompilerArgumentCount = CommandArgumentCount()
End Function

' Returns argument Index or the intrinsic's controlled empty result when the
' index is invalid. Call CompilerArgumentCount before requesting an argument.
Public Function CompilerArgumentAt(ByVal Index As Long) As String
    CompilerArgumentAt = CommandArgument(Index)
End Function

' Returns a monotonic elapsed-time sample, or -1 when unavailable.
Public Function CompilerElapsedMilliseconds() As LongLong
    CompilerElapsedMilliseconds = CompilerMonotonicMilliseconds()
End Function

' Returns process CPU milliseconds, or -1 when unavailable.
Public Function CompilerCpuMilliseconds() As LongLong
    CompilerCpuMilliseconds = CompilerProcessCpuMilliseconds()
End Function

' Returns peak process working-set bytes, or -1 when unavailable.
Public Function CompilerPeakBytes() As LongLong
    CompilerPeakBytes = CompilerPeakWorkingSetBytes()
End Function
