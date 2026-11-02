UBE SOURCE 1 CLASS
Attribute UBE_Name = "SharedProbeWork"
' A worker owns this private output; only final State=1 commits completeness.
Public Owner As SharedProbeOwner
Public Answers() As Long
Public FoldedNames() As Byte
Public NumericValue As LongLong
Public ArithmeticValue As LongLong
Public Total As LongLong
Public WorkerId As LongLong
Public Comparisons As Long
Public ByteReads As Long
Public RecordsRead As Long
Public NameScalars As Long
Public NameEncoded As Long
Public Failure As Long
Public State As Long
Public Slot As Long
