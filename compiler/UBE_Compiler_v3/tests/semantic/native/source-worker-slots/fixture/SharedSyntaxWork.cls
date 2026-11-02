UBE SOURCE 1 CLASS
Attribute UBE_Name = "SharedSyntaxWork"

' Test-owned independent parser output borrowing one completed immutable token owner.
Public Owner As SourceWork
Public Syntax() As SyntaxResult
Public Failure As SyntaxFailure
Public Metrics As SyntaxMetrics
Public WorkerId As LongLong
Public State As Long
