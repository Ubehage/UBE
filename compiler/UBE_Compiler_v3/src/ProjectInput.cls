UBE SOURCE 1 CLASS
Attribute UBE_Name = "ProjectInput"

' One request's owned discovery context. Validated instances are immutable.
' Failed construction may be retained only as explicit diagnostic context.
Public InvocationPath() As Byte
Public WorkingDirectory() As Byte
Public Packages() As ProjectPackage
Public Sources() As ProjectSource
Public PackageCount As Long
Public SourceCount As Long
Public SourceBytes As Long
Public PathBytes As Long
Public MetadataBytes As Long
Public Validated As Boolean
