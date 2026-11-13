UBE SOURCE 1 MODULE
Attribute UBE_Name = "BackendProbe"
Private HeldFile As Long
Private HeldProcess As Long
' Observes the ordinary backend's explicit results and retained owners.
Public Function BuildCase(ByRef Clang() As Byte, ByRef Stage() As Byte, ByRef Definition() As Byte, ByVal Expected As Long) As Long
    Dim FileToken As Long
    Dim ProcessToken As Long
    Dim Failure As Long
    Dim ExitCode As Long
    Dim Status As Boolean
    Status = NativeBackend.TryBuild(Clang, Stage, 0, Definition, FileToken, ProcessToken, Failure, ExitCode)
    If Expected = 0 Then
        If Not Status Or Failure <> 0 Then BuildCase = 1000 + Failure: Exit Function
    Else
        If Status Or Failure <> Expected Then BuildCase = 2000 + Failure: Exit Function
    End If
    If FileToken <> 0 Or ProcessToken <> 0 Then BuildCase = 3000
End Function

' A denied cleanup close must preserve timeout diagnostics and return both live owners to the caller.
Public Function RetainedCase(ByRef Application() As Byte, ByRef Command() As Byte, ByRef Stage() As Byte, ByRef Log() As Byte) As Long
    Dim Failure As Long
    Dim ExitCode As Long
    If NativeBackend.TryRun(Application, Command, Stage, Log, HeldFile, HeldProcess, Failure, ExitCode) Then RetainedCase = 1: Exit Function
    If Failure <> 100 Or Err.Number <> 57 Then RetainedCase = 2: Exit Function
    If HeldFile <= 0 Or HeldProcess <= 0 Then RetainedCase = 3
End Function

' Retries explicit returned ownership after the injected close failure is removed.
Public Function RecoverCase() As Long
    Dim Failure As Long = 100
    Dim Status As Boolean
    Status = FilePrimitives.SetError(57)
    If Not NativeBackend.TryStop(HeldProcess, Failure) Then RecoverCase = 1: Exit Function
    If HeldProcess <> 0 Or Failure <> 100 Or Err.Number <> 57 Then RecoverCase = 2: Exit Function
    If Not FileBytes.TryClosePreservingError(HeldFile, Failure) Then RecoverCase = 3: Exit Function
    If HeldFile <> 0 Or Failure <> 100 Or Err.Number <> 57 Then RecoverCase = 4
End Function

' Checks policy failures and ordinary cleanup without conflating process exit with runtime status.
Public Function RunCase(ByRef Application() As Byte, ByRef Command() As Byte, ByRef Stage() As Byte, ByRef Log() As Byte, ByVal Expected As Long) As Long
    Dim FileToken As Long
    Dim ProcessToken As Long
    Dim Failure As Long
    Dim ExitCode As Long
    Dim Status As Boolean
    Status = NativeBackend.TryRun(Application, Command, Stage, Log, FileToken, ProcessToken, Failure, ExitCode)
    If Expected = 0 Then
        If Not Status Or Failure <> 0 Then RunCase = 1000 + Failure: Exit Function
    Else
        If Status Or Failure <> Expected Then RunCase = 2000 + Failure: Exit Function
    End If
    If FileToken <> 0 Or ProcessToken <> 0 Then RunCase = 3000
End Function

' Checks exact asset bytes supplied beside this executable, independently of its current directory.
Public Function AssetsCase(ByVal Expected As Long) As Long
    Dim Catalog() As Byte
    Dim Runtime() As Byte
    Dim Definition() As Byte
    Dim Token As Long
    Dim Failure As Long
    Dim Status As Boolean
    Status = CompilerAssets.TryLoad(Catalog, Runtime, Definition, Token, Failure)
    If Expected <> 0 Then
        If Status Or Failure <> 3 Or Token <> 0 Or Err.Number <> 57 Then AssetsCase = 1
        Exit Function
    End If
    If Not Status Or Failure <> 0 Or Token <> 0 Then AssetsCase = 2: Exit Function
    If BufferPrimitives.ByteStorageLength(Catalog) <> 3 Then AssetsCase = 3: Exit Function
    If Catalog(0) <> 65 Or Catalog(1) <> 66 Or Catalog(2) <> 67 Then AssetsCase = 4: Exit Function
    If BufferPrimitives.ByteStorageLength(Runtime) <> 2 Then AssetsCase = 5: Exit Function
    If Runtime(0) <> 68 Or Runtime(1) <> 69 Then AssetsCase = 6: Exit Function
    If BufferPrimitives.ByteStorageLength(Definition) <> 1 Then AssetsCase = 7: Exit Function
    If Definition(0) <> 70 Then AssetsCase = 8
End Function

' Publishes exact diagnostic and success stream vectors.
Public Function MessagesCase(ByRef Path() As Byte) As Long
    If Not CompilerMessages.TryWriteError(5, 2, 3, -4, Path, 12, 7) Then MessagesCase = 1: Exit Function
    If Not CompilerMessages.TryWriteSuccess(1) Then MessagesCase = 2: Exit Function
    If Not CompilerMessages.TryWriteSuccess(2) Then MessagesCase = 3: Exit Function
    If CompilerMessages.TryWriteSuccess(0) Then MessagesCase = 4
End Function
