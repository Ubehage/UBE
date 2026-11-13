UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeToolArguments"
' Builds exact reviewed LLVM tool argv with private counted buffers and no shell.
Private Const TargetWord As Long = 1
Private Const LinkerWord As Long = 2
Private Const NoStandardLibraryWord As Long = 3
Private Const LanguageSwitchWord As Long = 4
Private Const IRLanguageWord As Long = 5
Private Const NativeLanguageWord As Long = 7
Private Const OutputSwitchWord As Long = 9
Private Const ExecutableOptionsWord As Long = 11
Private Const MachineSwitchWord As Long = 12
Private Const MachineWord As Long = 13
Private Const DefinitionSwitchWord As Long = 14
Private Const LibrarySwitchWord As Long = 16

' Materializes one reviewed ASCII fragment using the admitted byte-storage profile.
Private Function FixedText(ByVal Word As Long, ByRef Result() As Byte) As Boolean
    If Word = TargetWord Then FixedText = TargetText(Result): Exit Function
    If Word = LinkerWord Then FixedText = LinkerText(Result): Exit Function
    If Word = NoStandardLibraryWord Then FixedText = NoStandardLibraryText(Result): Exit Function
    If Word = LanguageSwitchWord Then FixedText = LanguageSwitchText(Result): Exit Function
    If Word = IRLanguageWord Then FixedText = IRLanguageText(Result): Exit Function
    If Word = NativeLanguageWord Then FixedText = NativeLanguageText(Result): Exit Function
    If Word = OutputSwitchWord Then FixedText = OutputSwitchText(Result): Exit Function
    If Word = ExecutableOptionsWord Then FixedText = ExecutableOptionsText(Result): Exit Function
    If Word = MachineSwitchWord Then FixedText = MachineSwitchText(Result): Exit Function
    If Word = MachineWord Then FixedText = MachineText(Result): Exit Function
    If Word = DefinitionSwitchWord Then FixedText = DefinitionSwitchText(Result): Exit Function
    If Word = LibrarySwitchWord Then FixedText = LibrarySwitchText(Result): Exit Function
End Function

' Supplies the exact Target argument or stage filename.
Private Function TargetText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 31, False) = False Then Exit Function
    Result(0) = 45
    Result(1) = 45
    Result(2) = 116
    Result(3) = 97
    Result(4) = 114
    Result(5) = 103
    Result(6) = 101
    Result(7) = 116
    Result(8) = 61
    Result(9) = 120
    Result(10) = 56
    Result(11) = 54
    Result(12) = 95
    Result(13) = 54
    Result(14) = 52
    Result(15) = 45
    Result(16) = 112
    Result(17) = 99
    Result(18) = 45
    Result(19) = 119
    Result(20) = 105
    Result(21) = 110
    Result(22) = 100
    Result(23) = 111
    Result(24) = 119
    Result(25) = 115
    Result(26) = 45
    Result(27) = 109
    Result(28) = 115
    Result(29) = 118
    Result(30) = 99
    TargetText = True
End Function

' Supplies the exact Linker argument or stage filename.
Private Function LinkerText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 12, False) = False Then Exit Function
    Result(0) = 45
    Result(1) = 102
    Result(2) = 117
    Result(3) = 115
    Result(4) = 101
    Result(5) = 45
    Result(6) = 108
    Result(7) = 100
    Result(8) = 61
    Result(9) = 108
    Result(10) = 108
    Result(11) = 100
    LinkerText = True
End Function

' Supplies the exact NoStandardLibrary argument or stage filename.
Private Function NoStandardLibraryText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 9, False) = False Then Exit Function
    Result(0) = 45
    Result(1) = 110
    Result(2) = 111
    Result(3) = 115
    Result(4) = 116
    Result(5) = 100
    Result(6) = 108
    Result(7) = 105
    Result(8) = 98
    NoStandardLibraryText = True
End Function

' Supplies the exact LanguageSwitch argument or stage filename.
Private Function LanguageSwitchText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 2, False) = False Then Exit Function
    Result(0) = 45
    Result(1) = 120
    LanguageSwitchText = True
End Function

' Supplies the exact IRLanguage argument or stage filename.
Private Function IRLanguageText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 2, False) = False Then Exit Function
    Result(0) = 105
    Result(1) = 114
    IRLanguageText = True
End Function

' Supplies the exact NativeLanguage argument or stage filename.
Private Function NativeLanguageText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 4, False) = False Then Exit Function
    Result(0) = 110
    Result(1) = 111
    Result(2) = 110
    Result(3) = 101
    NativeLanguageText = True
End Function

' Supplies the exact OutputSwitch argument or stage filename.
Private Function OutputSwitchText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 2, False) = False Then Exit Function
    Result(0) = 45
    Result(1) = 111
    OutputSwitchText = True
End Function

' Supplies the exact ExecutableOptions argument or stage filename.
Private Function ExecutableOptionsText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 49, False) = False Then Exit Function
    Result(0) = 45
    Result(1) = 87
    Result(2) = 108
    Result(3) = 44
    Result(4) = 47
    Result(5) = 101
    Result(6) = 110
    Result(7) = 116
    Result(8) = 114
    Result(9) = 121
    Result(10) = 58
    Result(11) = 109
    Result(12) = 97
    Result(13) = 105
    Result(14) = 110
    Result(15) = 44
    Result(16) = 47
    Result(17) = 115
    Result(18) = 117
    Result(19) = 98
    Result(20) = 115
    Result(21) = 121
    Result(22) = 115
    Result(23) = 116
    Result(24) = 101
    Result(25) = 109
    Result(26) = 58
    Result(27) = 99
    Result(28) = 111
    Result(29) = 110
    Result(30) = 115
    Result(31) = 111
    Result(32) = 108
    Result(33) = 101
    Result(34) = 44
    Result(35) = 47
    Result(36) = 115
    Result(37) = 116
    Result(38) = 97
    Result(39) = 99
    Result(40) = 107
    Result(41) = 58
    Result(42) = 56
    Result(43) = 51
    Result(44) = 56
    Result(45) = 56
    Result(46) = 54
    Result(47) = 48
    Result(48) = 56
    ExecutableOptionsText = True
End Function

' Supplies the exact MachineSwitch argument or stage filename.
Private Function MachineSwitchText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 2, False) = False Then Exit Function
    Result(0) = 45
    Result(1) = 109
    MachineSwitchText = True
End Function

' Supplies the exact Machine argument or stage filename.
Private Function MachineText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 11, False) = False Then Exit Function
    Result(0) = 105
    Result(1) = 51
    Result(2) = 56
    Result(3) = 54
    Result(4) = 58
    Result(5) = 120
    Result(6) = 56
    Result(7) = 54
    Result(8) = 45
    Result(9) = 54
    Result(10) = 52
    MachineText = True
End Function

' Supplies the exact DefinitionSwitch argument or stage filename.
Private Function DefinitionSwitchText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 2, False) = False Then Exit Function
    Result(0) = 45
    Result(1) = 100
    DefinitionSwitchText = True
End Function

' Supplies the exact LibrarySwitch argument or stage filename.
Private Function LibrarySwitchText(ByRef Result() As Byte) As Boolean
    If BufferPrimitives.TryResizeBytes(Result, 2, False) = False Then Exit Function
    Result(0) = 45
    Result(1) = 108
    LibrarySwitchText = True
End Function

' Adds one separator and a fully quoted argument to private bounded construction storage.
Private Function AppendArgument(ByRef Value() As Byte, ByRef Buffer() As Byte, ByRef Used As Long, ByRef Failure As Long) As Boolean
    Dim Length As Long
    On Error GoTo Failed
    Failure = 3
    Length = BufferPrimitives.ByteStorageLength(Value)
    If Used < 0 Or Used >= 131072 Then Exit Function
    If Used > 0 Then
        Buffer(Used) = 32
        Used = Used + 1
    End If
    AppendArgument = WindowsArguments.TryAppendQuotedArgument(Value, 0, Length, Buffer, Used)
    Exit Function
Failed:
    Exit Function
End Function

' Appends a reviewed constant word without adding source-language String support.
Private Function AppendFixed(ByVal Word As Long, ByRef Buffer() As Byte, ByRef Used As Long, ByRef Failure As Long) As Boolean
    Dim Value() As Byte
    Failure = 3
    If FixedText(Word, Value) = False Then Exit Function
    AppendFixed = AppendArgument(Value, Buffer, Used, Failure)
End Function

' Reuses the publication owner's reviewed leaf paths before adding a quoted argument.
Private Function AppendLeaf(ByVal Kind As Long, ByRef Stage() As Byte, ByRef Buffer() As Byte, ByRef Used As Long, ByRef Failure As Long) As Boolean
    Dim Path() As Byte
    If OutputPublication.TryStagePath(Stage, Kind, Path, Failure) = False Then Exit Function
    AppendLeaf = AppendArgument(Path, Buffer, Used, Failure)
End Function

' Validates absolute paths and creates private command storage before any caller result changes.
Private Function BeginCommand(ByRef Application() As Byte, ByRef Stage() As Byte, ByRef Directory() As Byte, ByRef Buffer() As Byte, ByRef Used As Long, ByRef Failure As Long) As Boolean
    Dim ProgramPath() As Byte
    If WindowsPaths.TryNormalizePhysical(Application, ProgramPath, Failure) = False Then Exit Function
    If ProgramPath(BufferPrimitives.ByteStorageLength(ProgramPath) - 1) = 92 Then Failure = 1: BeginCommand = FilePrimitives.SetError(5): Exit Function
    If WindowsPaths.TryNormalizePhysical(Stage, Directory, Failure) = False Then Exit Function
    Failure = 3
    If BufferPrimitives.TryResizeBytes(Buffer, 131072, False) = False Then Exit Function
    BeginCommand = AppendArgument(ProgramPath, Buffer, Used, Failure)
End Function

' Publishes independent exact-sized command bytes only after construction succeeds.
Private Function Publish(ByRef Buffer() As Byte, ByVal Used As Long, ByRef Command() As Byte, ByRef Failure As Long) As Boolean
    Failure = 3
    If Used < 1 Or Used > 131072 Then Exit Function
    If BufferPrimitives.TryResizeBytes(Buffer, Used, True) = False Then Exit Function
    If BufferPrimitives.TryCopyBytes(Command, Buffer) = False Then Exit Function
    Failure = 0
    Publish = True
End Function

' Builds the reviewed Windows x64 Clang argv; UTF-16 process limits remain an invocation check.
Public Function TryClangCommand(ByRef Application() As Byte, ByRef Stage() As Byte, ByVal Optimization As Long, ByRef Command() As Byte, ByRef Failure As Long) As Boolean
    Dim Buffer() As Byte
    Dim Directory() As Byte
    Dim Level(0 To 2) As Byte
    Dim Used As Long
    On Error GoTo Failed
    Failure = 1
    If Optimization < 0 Or Optimization > 4 Then TryClangCommand = FilePrimitives.SetError(5): Exit Function
    If BeginCommand(Application, Stage, Directory, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(TargetWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(LinkerWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(NoStandardLibraryWord, Buffer, Used, Failure) = False Then Exit Function
    Level(0) = 45
    Level(1) = 79
    Level(2) = 48 + Optimization
    If Optimization = 4 Then Level(2) = 115
    If AppendArgument(Level, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(LanguageSwitchWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(IRLanguageWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendLeaf(OutputPublication.InputIR, Directory, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(LanguageSwitchWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(NativeLanguageWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendLeaf(OutputPublication.ImportLibrary, Directory, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(OutputSwitchWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendLeaf(OutputPublication.Executable, Directory, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(ExecutableOptionsWord, Buffer, Used, Failure) = False Then Exit Function
    TryClangCommand = Publish(Buffer, Used, Command, Failure)
    Exit Function
Failed:
    Failure = 1
    Exit Function
End Function

' Builds llvm-dlltool argv for the reviewed stage-local kernel32 import definition/archive.
Public Function TryImportCommand(ByRef Application() As Byte, ByRef Stage() As Byte, ByRef Command() As Byte, ByRef Failure As Long) As Boolean
    Dim Buffer() As Byte
    Dim Directory() As Byte
    Dim Used As Long
    On Error GoTo Failed
    Failure = 1
    If BeginCommand(Application, Stage, Directory, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(MachineSwitchWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(MachineWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(DefinitionSwitchWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendLeaf(OutputPublication.ImportDefinition, Directory, Buffer, Used, Failure) = False Then Exit Function
    If AppendFixed(LibrarySwitchWord, Buffer, Used, Failure) = False Then Exit Function
    If AppendLeaf(OutputPublication.ImportLibrary, Directory, Buffer, Used, Failure) = False Then Exit Function
    TryImportCommand = Publish(Buffer, Used, Command, Failure)
    Exit Function
Failed:
    Failure = 1
    Exit Function
End Function

