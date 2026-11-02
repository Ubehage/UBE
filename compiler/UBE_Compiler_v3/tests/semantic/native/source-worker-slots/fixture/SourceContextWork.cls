UBE SOURCE 1 CLASS
Attribute UBE_Name = "SourceContextWork"

' Test-owned invocation context; source owners are shared, outputs stay private.
Public Inputs() As SourceOwner
Public Published() As SourceWork
Public Cancellation As SourceCancellation
Public Failure As SourceSetFailure
Public WorkerId As LongLong
Public State As Long
