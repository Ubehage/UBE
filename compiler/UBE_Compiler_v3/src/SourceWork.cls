UBE SOURCE 1 CLASS
Attribute UBE_Name = "SourceWork"

' Fresh private work per invocation; published complete work is immutable.
Public Owner As SourceOwner
Public Tokens() As SourceToken
Public Syntax() As SyntaxResult
Public Failure As SyntaxFailure
Public Metrics As SyntaxMetrics
Public WorkerId As LongLong
Public State As Long
Public MaximumTokens As Long
Public MaximumNodes As Long
Public MaximumPending As Long
Public MaximumDepth As Long
