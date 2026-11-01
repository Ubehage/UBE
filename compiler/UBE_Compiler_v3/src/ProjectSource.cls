UBE SOURCE 1 CLASS
Attribute UBE_Name = "ProjectSource"

' One file's compiler association; workers receive Owner only. SourceId remains
' Owner.SourceId, never the physical identity or worker completion position.
Public Owner As SourceOwner
Public Path As ProjectPath
Public Identity() As Byte
Public Envelope As SourceEnvelope
Public PackageId As Long
Public DeclarationIndex As Long
