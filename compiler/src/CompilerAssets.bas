UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerAssets"
' Loads reviewed target support beside the running compiler, independently of the working directory.

' Supplies the exact installed relative path for llvm/templates.bin.
Private Function TemplatePathText(ByRef Result() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Result, 18, False) Then Exit Function
    Result(0) = 108
    Result(1) = 108
    Result(2) = 118
    Result(3) = 109
    Result(4) = 47
    Result(5) = 116
    Result(6) = 101
    Result(7) = 109
    Result(8) = 112
    Result(9) = 108
    Result(10) = 97
    Result(11) = 116
    Result(12) = 101
    Result(13) = 115
    Result(14) = 46
    Result(15) = 98
    Result(16) = 105
    Result(17) = 110
    TemplatePathText = True
End Function

' Supplies the exact installed relative path for llvm/windows-runtime.ll.
Private Function RuntimePathText(ByRef Result() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Result, 23, False) Then Exit Function
    Result(0) = 108
    Result(1) = 108
    Result(2) = 118
    Result(3) = 109
    Result(4) = 47
    Result(5) = 119
    Result(6) = 105
    Result(7) = 110
    Result(8) = 100
    Result(9) = 111
    Result(10) = 119
    Result(11) = 115
    Result(12) = 45
    Result(13) = 114
    Result(14) = 117
    Result(15) = 110
    Result(16) = 116
    Result(17) = 105
    Result(18) = 109
    Result(19) = 101
    Result(20) = 46
    Result(21) = 108
    Result(22) = 108
    RuntimePathText = True
End Function

' Supplies the exact installed relative path for llvm/kernel32.def.
Private Function ImportPathText(ByRef Result() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Result, 17, False) Then Exit Function
    Result(0) = 108
    Result(1) = 108
    Result(2) = 118
    Result(3) = 109
    Result(4) = 47
    Result(5) = 107
    Result(6) = 101
    Result(7) = 114
    Result(8) = 110
    Result(9) = 101
    Result(10) = 108
    Result(11) = 51
    Result(12) = 50
    Result(13) = 46
    Result(14) = 100
    Result(15) = 101
    Result(16) = 102
    ImportPathText = True
End Function

' Selects an installed support path independently of the caller's working directory.
Private Function RelativePath(ByVal Kind As Long, ByRef Relative() As Byte, ByRef Failure As Long) As Boolean
    On Error GoTo Failed
    Failure = 8
    If Kind = 1 Then
        If Not TemplatePathText(Relative) Then Exit Function
    ElseIf Kind = 2 Then
        If Not RuntimePathText(Relative) Then Exit Function
    ElseIf Kind = 3 Then
        If Not ImportPathText(Relative) Then Exit Function
    Else
        Failure = 1
        RelativePath = FilePrimitives.SetError(5)
        Exit Function
    End If
    RelativePath = True
    Exit Function
Failed:
    Failure = 1
End Function

' Reads one bounded support asset, leaving failed-close ownership with its caller.
Private Function TryReadAsset(ByRef Parent() As Byte, ByVal Kind As Long, ByRef Result() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Relative() As Byte
    Dim Path() As Byte
    On Error GoTo Failed
    If Not RelativePath(Kind, Relative, Failure) Then Exit Function
    If Not WindowsPaths.TryResolveSource(Parent, Relative, Path, Failure) Then Exit Function
    TryReadAsset = FileBytes.TryReadAllBytes(Path, 1048576, Result, Token, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Gets the actual executable path as an independent exact-sized byte array.
Private Function TryExecutablePath(ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Executable() As Byte
    Dim Count As Long
    On Error GoTo Failed
    Failure = 8
    If Not BufferPrimitives.TryResizeBytes(Executable, 4096, False) Then Exit Function
    If Not SystemPrimitives.TryExecutablePath(Executable, Count, Failure) Then Exit Function
    If Count < 1 Or Count > 4096 Then Failure = 1: TryExecutablePath = FilePrimitives.SetError(5): Exit Function
    Failure = 8
    If Not BufferPrimitives.TryResizeBytes(Executable, Count, True) Then Exit Function
    If Not BufferPrimitives.TryCopyBytes(Result, Executable) Then Exit Function
    Failure = 0
    TryExecutablePath = True
    Exit Function
Failed:
    Failure = 1
End Function

' Returns one protected support input: zero is this executable, one through three are its assets.
Public Function TrySupportPath(ByVal Kind As Long, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
    Dim Executable() As Byte
    Dim Parent() As Byte
    Dim Relative() As Byte
    On Error GoTo Failed
    If Kind = 0 Then TrySupportPath = TryExecutablePath(Result, Failure): Exit Function
    If Not TryExecutablePath(Executable, Failure) Then Exit Function
    If Not WindowsPaths.TryParent(Executable, Parent, Failure) Then Exit Function
    If Not RelativePath(Kind, Relative, Failure) Then Exit Function
    TrySupportPath = WindowsPaths.TryResolveSource(Parent, Relative, Result, Failure)
    Exit Function
Failed:
    Failure = 1
End Function

' Fills caller-owned request scratch; no asset is usable unless the complete operation succeeds.
Public Function TryLoad(ByRef Catalog() As Byte, ByRef RuntimeText() As Byte, ByRef ImportDefinition() As Byte, ByRef Token As Long, ByRef Failure As Long) As Boolean
    Dim Executable() As Byte
    Dim Parent() As Byte
    On Error GoTo Failed
    If Token <> 0 Then Failure = 1: TryLoad = FilePrimitives.SetError(5): Exit Function
    If Not TryExecutablePath(Executable, Failure) Then Exit Function
    If Not WindowsPaths.TryParent(Executable, Parent, Failure) Then Exit Function
    If Not TryReadAsset(Parent, 1, Catalog, Token, Failure) Then Exit Function
    If Not TryReadAsset(Parent, 2, RuntimeText, Token, Failure) Then Exit Function
    If Not TryReadAsset(Parent, 3, ImportDefinition, Token, Failure) Then Exit Function
    TryLoad = True
    Exit Function
Failed:
    Failure = 1
End Function

