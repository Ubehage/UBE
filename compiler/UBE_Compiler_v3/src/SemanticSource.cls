UBE SOURCE 1 CLASS
Attribute UBE_Name = "SemanticSource"
' Frozen association; no original document/token/node payload is copied.
Public SyntaxInput As SourceWork
Public Envelope As SourceEnvelope
Public SourceId As Long
Public PackageId As Long
Public ModuleDeclaration As Long
Public FirstDeclaration As Long
Public DeclarationCount As Long
Public PrivateModule As Long
' Stored name index plus one; zero means that syntax node is not a Name.
Public NameMap() As Long
