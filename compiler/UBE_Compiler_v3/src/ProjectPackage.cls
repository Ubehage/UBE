UBE SOURCE 1 CLASS
Attribute UBE_Name = "ProjectPackage"

' Private during discovery; immutable after input publication. All raw spans
' borrow Document. Reference paths retain the bounded first two declarations.
Public Document As SourceDocument
Public Metadata As ProjectManifest
Public DeclaredPath() As Byte
Public ResolvedPath() As Byte
Public DirectoryPath() As Byte
Public Identity() As Byte
Public ReferencePaths() As ProjectPath
Public PackageId As Long
Public ParentPackageId As Long
Public ReferenceFirst As Long
Public ReferenceLast As Long
