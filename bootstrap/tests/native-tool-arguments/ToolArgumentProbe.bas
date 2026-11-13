UBE SOURCE 1 MODULE
Attribute UBE_Name = "ToolArgumentProbe"
' Observes exact tool command bytes, input/output aliases and failed publication.

' Compares every command byte against independently authored expected text.
Private Function SameBytes(ByRef A() As Byte, ByRef B() As Byte) As Boolean
    Dim Index As Long
    Dim Length As Long
    Length = BufferPrimitives.ByteStorageLength(A)
    If Length <> BufferPrimitives.ByteStorageLength(B) Then Exit Function
    Do While Index < Length
        If A(Index) <> B(Index) Then Exit Function
        Index = Index + 1
    Loop
    SameBytes = True
End Function

' Selects the actual public command builder without adding source behavior.
Private Function Build(ByRef Application() As Byte, ByRef Stage() As Byte, ByVal Optimization As Long, ByVal ImportTool As Boolean, ByRef Command() As Byte, ByRef Failure As Long) As Boolean
    If ImportTool Then
        Build = NativeToolArguments.TryImportCommand(Application, Stage, Command, Failure)
    Else
        Build = NativeToolArguments.TryClangCommand(Application, Stage, Optimization, Command, Failure)
    End If
End Function

' Checks successful or failed construction without performing filesystem output.
Public Function CheckBuild(ByRef Application() As Byte, ByRef Stage() As Byte, ByVal Optimization As Long, ByVal ImportTool As Boolean, ByRef Expected() As Byte, ByVal Success As Boolean) As Long
    Dim Command(0 To 1) As Byte
    Dim Failure As Long = 79
    Dim Status As Boolean
    Command(0) = 73
    Command(1) = 74
    Status = FilePrimitives.SetError(91)
    Status = Build(Application, Stage, Optimization, ImportTool, Command, Failure)
    If Status <> Success Then CheckBuild = 1: Exit Function
    If Success Then
        If Failure <> 0 Or Err.Number <> 91 Then CheckBuild = 2: Exit Function
        If SameBytes(Command, Expected) = False Then CheckBuild = 3
    Else
        If Failure = 0 Then CheckBuild = 4: Exit Function
        If BufferPrimitives.ByteStorageLength(Command) <> 2 Then CheckBuild = 5: Exit Function
        If Command(0) <> 73 Or Command(1) <> 74 Then CheckBuild = 6
    End If
End Function

' Writes actual successful bytes for the independent Windows argv oracle, including input aliases.
Public Function WriteCase(ByRef Application() As Byte, ByRef Stage() As Byte, ByVal Optimization As Long, ByVal ImportTool As Boolean, ByRef Expected() As Byte, ByRef OutputPath() As Byte, ByVal AliasMode As Long) As Long
    Dim ApplicationCopy() As Byte
    Dim StageCopy() As Byte
    Dim Command() As Byte
    Dim Failure As Long
    Dim Token As Long
    Dim Status As Boolean
    On Error GoTo Failed
    If BufferPrimitives.TryCopyBytes(ApplicationCopy, Application) = False Then WriteCase = 1: Exit Function
    If BufferPrimitives.TryCopyBytes(StageCopy, Stage) = False Then WriteCase = 2: Exit Function
    Status = FilePrimitives.SetError(91)
    If AliasMode = 1 Then
        Status = Build(ApplicationCopy, StageCopy, Optimization, ImportTool, ApplicationCopy, Failure)
        If Status = False Then WriteCase = 3: Exit Function
        If BufferPrimitives.TryCopyBytes(Command, ApplicationCopy) = False Then WriteCase = 4: Exit Function
    ElseIf AliasMode = 2 Then
        Status = Build(ApplicationCopy, StageCopy, Optimization, ImportTool, StageCopy, Failure)
        If Status = False Then WriteCase = 5: Exit Function
        If BufferPrimitives.TryCopyBytes(Command, StageCopy) = False Then WriteCase = 6: Exit Function
    Else
        Status = Build(ApplicationCopy, StageCopy, Optimization, ImportTool, Command, Failure)
        If Status = False Then WriteCase = 7: Exit Function
    End If
    If Failure <> 0 Or Err.Number <> 91 Then WriteCase = 8: Exit Function
    If SameBytes(Command, Expected) = False Then WriteCase = 9: Exit Function
    If FilePrimitives.TryCreateNew(OutputPath, Token, Failure) = False Then WriteCase = 10: Exit Function
    If FileBytes.TryWriteAllBytes(Token, Command, Failure) = False Then WriteCase = 11
Cleanup:
    If FilePrimitives.TryClose(Token, Failure) = False Then WriteCase = 12
    Exit Function
Failed:
    WriteCase = 13
    GoTo Cleanup
End Function

