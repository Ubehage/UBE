UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerFiles"

' Reads a required nonempty UTF-8 control file. Returns 1 with Contents on
' success and 0 with Contents empty for a missing, unreadable, or empty file.
Public Function ReadRequiredCompilerText(ByVal Path As String, ByRef Contents As String) As Long
    Contents = ReadAllText(Path)
    If StringLength(Contents) = 0 Then
        ReadRequiredCompilerText = 0
    Else
        ReadRequiredCompilerText = 1
    End If
End Function

' Reads compiler-owned UTF-8 text without imposing nonempty policy. The caller
' validates emptiness and format before publishing a phase result.
Public Function ReadCompilerText(ByVal Path As String) As String
    ReadCompilerText = ReadAllText(Path)
End Function

' Publishes Contents using the bootstrap ABI's sibling-temp, close, and atomic
' replace contract. Returns 0 on success or the documented nonzero status.
Public Function PublishCompilerText(ByVal Path As String, ByVal Contents As String) As Long
    PublishCompilerText = WriteAllText(Path, Contents)
End Function

' Removes a compiler-owned artifact. Missing files succeed; invalid paths and
' host rejection return the bootstrap ABI's documented nonzero status.
Public Function RemoveCompilerArtifact(ByVal Path As String) As Long
    RemoveCompilerArtifact = CompilerDeleteFile(Path)
End Function
