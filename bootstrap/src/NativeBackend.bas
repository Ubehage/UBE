Attribute VB_Name = "NativeBackend"
Option Explicit

' Publishes bounded LLVM/native artifacts through same-directory staging and direct hidden tool execution.
Private Const MaximumIRBytes As Long = 16777216
Private Const MaximumLogBytes As Long = 65536
Private Const MaximumNativeBytes As Long = 67108864

Private Type SecurityAttributes
    Length As Long
    Descriptor As Long
    Inherit As Long
End Type

Private Type StartupInformation
    Size As Long
    Reserved As Long
    Desktop As Long
    Title As Long
    X As Long
    Y As Long
    XSize As Long
    YSize As Long
    XCount As Long
    YCount As Long
    Fill As Long
    Flags As Long
    Show As Integer
    ReservedSize As Integer
    ReservedPointer As Long
    InputHandle As Long
    OutputHandle As Long
    ErrorHandle As Long
End Type

Private Type ProcessInformation
    Process As Long
    Thread As Long
    ProcessId As Long
    ThreadId As Long
End Type

Private Type FileIdentity
    Attributes As Long
    CreationLow As Long
    CreationHigh As Long
    AccessLow As Long
    AccessHigh As Long
    WriteLow As Long
    WriteHigh As Long
    Volume As Long
    SizeHigh As Long
    SizeLow As Long
    Links As Long
    IndexHigh As Long
    IndexLow As Long
End Type

Private Declare Function CreateFileW Lib "kernel32" (ByVal Name As Long, ByVal Access As Long, ByVal Share As Long, ByVal Security As Long, ByVal Creation As Long, ByVal Flags As Long, ByVal Template As Long) As Long
Private Declare Function CloseHandle Lib "kernel32" (ByVal Handle As Long) As Long
Private Declare Function ReadFile Lib "kernel32" (ByVal Handle As Long, ByRef Buffer As Any, ByVal Count As Long, ByRef Completed As Long, ByVal Overlapped As Long) As Long
Private Declare Function WriteFile Lib "kernel32" (ByVal Handle As Long, ByRef Buffer As Any, ByVal Count As Long, ByRef Completed As Long, ByVal Overlapped As Long) As Long
Private Declare Function FlushFileBuffers Lib "kernel32" (ByVal Handle As Long) As Long
Private Declare Function GetFileSize Lib "kernel32" (ByVal Handle As Long, ByRef High As Long) As Long
Private Declare Function SetFilePointer Lib "kernel32" (ByVal Handle As Long, ByVal Distance As Long, ByVal High As Long, ByVal Method As Long) As Long
Private Declare Function GetFileInformationByHandle Lib "kernel32" (ByVal Handle As Long, ByRef Information As FileIdentity) As Long
Private Declare Function GetFinalPathNameByHandleW Lib "kernel32" (ByVal Handle As Long, ByVal Buffer As Long, ByVal Capacity As Long, ByVal Flags As Long) As Long
Private Declare Function GetFileAttributesW Lib "kernel32" (ByVal Name As Long) As Long
Private Declare Function CreateDirectoryW Lib "kernel32" (ByVal Name As Long, ByVal Security As Long) As Long
Private Declare Function RemoveDirectoryW Lib "kernel32" (ByVal Name As Long) As Long
Private Declare Function DeleteFileW Lib "kernel32" (ByVal Name As Long) As Long
Private Declare Function MoveFileExW Lib "kernel32" (ByVal Source As Long, ByVal Destination As Long, ByVal Flags As Long) As Long
Private Declare Function CoCreateGuid Lib "ole32" (ByRef Guid As Any) As Long
Private Declare Function WideCharToMultiByte Lib "kernel32" (ByVal Page As Long, ByVal Flags As Long, ByVal Wide As Long, ByVal Count As Long, ByRef Bytes As Any, ByVal Capacity As Long, ByVal DefaultChar As Long, ByVal UsedDefault As Long) As Long
Private Declare Function MultiByteToWideChar Lib "kernel32" (ByVal Page As Long, ByVal Flags As Long, ByRef Bytes As Any, ByVal Count As Long, ByVal Wide As Long, ByVal Capacity As Long) As Long
Private Declare Function CreateProcessW Lib "kernel32" (ByVal Application As Long, ByVal Command As Long, ByVal ProcessSecurity As Long, ByVal ThreadSecurity As Long, ByVal Inherit As Long, ByVal Flags As Long, ByVal Environment As Long, ByVal Directory As Long, ByRef Startup As StartupInformation, ByRef Information As ProcessInformation) As Long
Private Declare Function WaitForSingleObject Lib "kernel32" (ByVal Handle As Long, ByVal Milliseconds As Long) As Long
Private Declare Function GetExitCodeProcess Lib "kernel32" (ByVal Handle As Long, ByRef Code As Long) As Long
Private Declare Function CreateJobObjectW Lib "kernel32" (ByVal Security As Long, ByVal Name As Long) As Long
Private Declare Function SetInformationJobObject Lib "kernel32" (ByVal Job As Long, ByVal Class As Long, ByRef Information As Any, ByVal Length As Long) As Long
Private Declare Function AssignProcessToJobObject Lib "kernel32" (ByVal Job As Long, ByVal Process As Long) As Long
Private Declare Function TerminateJobObject Lib "kernel32" (ByVal Job As Long, ByVal Code As Long) As Long
Private Declare Function TerminateProcess Lib "kernel32" (ByVal Process As Long, ByVal Code As Long) As Long
Private Declare Function ResumeThread Lib "kernel32" (ByVal Thread As Long) As Long

' Obtains a physical host path from an already opened file or directory.
Private Function HandlePath(ByVal Handle As Long, ByRef Path As String) As Boolean
    Dim Buffer As String, Length As Long
    Buffer = String$(MaximumPathCharacters + 1, vbNullChar)
    Length = GetFinalPathNameByHandleW(Handle, StrPtr(Buffer), Len(Buffer), 0)
    If Length < 1 Or Length > MaximumPathCharacters Then Exit Function
    Path = Left$(Buffer, Length)
    If Left$(Path, 8) = "\\?\UNC\" Then
        Path = "\\" & Mid$(Path, 9)
    ElseIf Left$(Path, 4) = "\\?\" Then
        Path = Mid$(Path, 5)
    End If
    HandlePath = True
End Function

' Checks physical identity as well as normalized spelling, including existing hard-link aliases.
Private Function IsInputAlias(ByVal OutputHandle As Long, ByVal OutputPath As String, ByVal InputPath As String, ByRef Checked As Boolean) As Boolean
    Dim Handle As Long, OutputInfo As FileIdentity, InputInfo As FileIdentity
    On Error GoTo Failed
    Handle = -1
    Checked = True
    If SamePath(OutputPath, InputPath) Then IsInputAlias = True: Exit Function
    If OutputHandle = -1 Then Exit Function
    If GetFileInformationByHandle(OutputHandle, OutputInfo) = 0 Then GoTo Failed
    Handle = CreateFileW(StrPtr(InputPath), 0, 7, 0, 3, &H80, 0)
    If Handle = -1 Then GoTo Failed
    If GetFileInformationByHandle(Handle, InputInfo) = 0 Then GoTo Failed
    IsInputAlias = OutputInfo.Volume = InputInfo.Volume And OutputInfo.IndexHigh = InputInfo.IndexHigh And OutputInfo.IndexLow = InputInfo.IndexLow
    CloseHandle Handle
    Exit Function
Failed:
    On Error Resume Next
    If Handle <> -1 Then CloseHandle Handle
    Checked = False
End Function

' Resolves the output through its existing parent and refuses every loaded project/source alias.
Private Function ResolveOutput(ByRef Project As ProjectContext, ByVal Requested As String, ByRef Output As String, ByRef Directory As String, ByRef Diagnostic As String) As Boolean
    Dim Full As String, Leaf As String, Physical As String, Character As String
    Dim Position As Long, Index As Long, Handle As Long, Existing As Long, Attributes As Long
    Dim Checked As Boolean
    On Error GoTo Failed
    Handle = -1: Existing = -1
    If Not FullPath(Requested, Full, Diagnostic) Then GoTo Failed
    Position = InStrRev(Full, "\")
    If Position < 1 Then GoTo Failed
    Leaf = Mid$(Full, Position + 1)
    If Len(Leaf) = 0 Then GoTo Failed
    If Right$(Leaf, 1) = "." Or Right$(Leaf, 1) = " " Then GoTo Failed
    For Index = 1 To Len(Leaf)
        Character = Mid$(Leaf, Index, 1)
        If InStr(":*?<>|" & Chr$(34), Character) > 0 Or (AscW(Character) And &HFFFF&) < 32 Then GoTo Failed
    Next Index
    Directory = Left$(Full, Position)
    Handle = CreateFileW(StrPtr(Directory), 0, 7, 0, 3, &H2000000, 0)
    If Handle = -1 Then GoTo Failed
    If Not HandlePath(Handle, Directory) Then GoTo Failed
    CloseHandle Handle: Handle = -1
    If Right$(Directory, 1) <> "\" Then Directory = Directory & "\"
    Output = Directory & Leaf
    If Len(Output) > MaximumPathCharacters Then GoTo Failed
    Physical = Output
    Attributes = GetFileAttributesW(StrPtr(Output))
    If Attributes <> -1 Then
        If (Attributes And &H10) <> 0 Then GoTo Failed
        Existing = CreateFileW(StrPtr(Output), 0, 7, 0, 3, &H80, 0)
        If Existing = -1 Then GoTo Failed
        If Not HandlePath(Existing, Physical) Then GoTo Failed
    End If
    If IsInputAlias(Existing, Physical, Project.ManifestPath, Checked) Then GoTo Alias
    If Not Checked Then GoTo Failed
    For Index = 0 To Project.SourceCount - 1
        If IsInputAlias(Existing, Physical, Project.Sources(Index).FilePath, Checked) Then GoTo Alias
        If Not Checked Then GoTo Failed
    Next Index
    If Existing <> -1 Then CloseHandle Existing
    ResolveOutput = True
    Exit Function
Alias:
    Diagnostic = "UBE: E_OUTPUT: output would replace a project input: " & Output
    GoTo Cleanup
Failed:
    Diagnostic = "UBE: E_OUTPUT: cannot use output path: " & Requested
Cleanup:
    On Error Resume Next
    If Handle <> -1 Then CloseHandle Handle
    If Existing <> -1 Then CloseHandle Existing
End Function

' Reserves a fresh private staging directory alongside the destination without reusing old paths.
Private Function CreateStage(ByVal Directory As String, ByRef Stage As String, ByRef Diagnostic As String) As Boolean
    Dim Guid(0 To 3) As Long, Index As Long, Name As String
    If CoCreateGuid(Guid(0)) <> 0 Then GoTo Failed
    Name = ".ube-"
    For Index = 0 To 3
        Name = Name & Right$("00000000" & Hex$(Guid(Index)), 8)
    Next Index
    Stage = Directory & Name
    If Len(Stage) + 20 > MaximumPathCharacters Then GoTo Failed
    If CreateDirectoryW(StrPtr(Stage), 0) = 0 Then Stage = "": GoTo Failed
    CreateStage = True
    Exit Function
Failed:
    CreateStage = Reject(Diagnostic, "E_OUTPUT", "cannot create staging directory beside output")
End Function

' Deletes only known build files in the directory reserved by this invocation.
Private Sub RemoveStage(ByVal Stage As String)
    If Len(Stage) = 0 Then Exit Sub
    DeleteFileW StrPtr(Stage & "\input.ll")
    DeleteFileW StrPtr(Stage & "\output.exe")
    DeleteFileW StrPtr(Stage & "\clang.log")
    DeleteFileW StrPtr(Stage & "\import.log")
    DeleteFileW StrPtr(Stage & "\kernel32-memory.def")
    DeleteFileW StrPtr(Stage & "\kernel32-memory.lib")
    RemoveDirectoryW StrPtr(Stage)
End Sub

' Writes exact strict UTF-8 with bounded allocation, checked progress and durable completion.
Private Function WriteIR(ByVal Path As String, ByRef IR As String, ByRef Diagnostic As String) As Boolean
    Dim Bytes() As Byte, Count As Long, Position As Long, Completed As Long, Handle As Long
    On Error GoTo Failed
    Handle = -1
    If Len(IR) < 1 Or Len(IR) > MaximumIRBytes Then GoTo Failed
    Count = WideCharToMultiByte(65001, &H80, StrPtr(IR), Len(IR), ByVal 0&, 0, 0, 0)
    If Count < 1 Or Count > MaximumIRBytes Then GoTo Failed
    ReDim Bytes(0 To Count - 1)
    If WideCharToMultiByte(65001, &H80, StrPtr(IR), Len(IR), Bytes(0), Count, 0, 0) <> Count Then GoTo Failed
    Handle = CreateFileW(StrPtr(Path), &H40000000, 0, 0, 1, &H80, 0)
    If Handle = -1 Then GoTo Failed
    Do While Position < Count
        Completed = 0
        If WriteFile(Handle, Bytes(Position), Count - Position, Completed, 0) = 0 Then GoTo Failed
        If Completed < 1 Or Completed > Count - Position Then GoTo Failed
        Position = Position + Completed
    Loop
    If FlushFileBuffers(Handle) = 0 Then GoTo Failed
    If CloseHandle(Handle) = 0 Then Handle = -1: GoTo Failed
    Handle = -1
    WriteIR = True
    Exit Function
Failed:
    On Error Resume Next
    If Handle <> -1 Then CloseHandle Handle
    WriteIR = Reject(Diagnostic, "E_OUTPUT", "cannot write bounded LLVM output: " & Path)
End Function

' Applies Windows argv quoting directly; no shell interprets command text.
Private Function QuoteArgument(ByVal Value As String) As String
    Dim Result As String, Index As Long, Slashes As Long, Character As String
    Result = Chr$(34)
    For Index = 1 To Len(Value)
        Character = Mid$(Value, Index, 1)
        If Character = "\" Then
            Slashes = Slashes + 1
        Else
            If Character = Chr$(34) Then Result = Result & String$(Slashes * 2 + 1, "\") Else Result = Result & String$(Slashes, "\")
            Result = Result & Character
            Slashes = 0
        End If
    Next Index
    QuoteArgument = Result & String$(Slashes * 2, "\") & Chr$(34)
End Function

' Reads a bounded compiler diagnostic without trusting its contents as executable instructions.
Private Function ReadLog(ByVal Handle As Long) As String
    Dim Count As Long, High As Long, Completed As Long, Characters As Long
    Dim Bytes() As Byte, Text As String
    On Error GoTo Failed
    Count = GetFileSize(Handle, High)
    If High <> 0 Or Count < 1 Or Count > MaximumLogBytes Then Exit Function
    If SetFilePointer(Handle, 0, 0, 0) <> 0 Then Exit Function
    ReDim Bytes(0 To Count - 1)
    If ReadFile(Handle, Bytes(0), Count, Completed, 0) = 0 Then Exit Function
    If Completed <> Count Then Exit Function
    Characters = MultiByteToWideChar(65001, 0, Bytes(0), Count, 0, 0)
    If Characters < 1 Then Exit Function
    Text = String$(Characters, vbNullChar)
    If MultiByteToWideChar(65001, 0, Bytes(0), Count, StrPtr(Text), Characters) <> Characters Then Exit Function
    ReadLog = Left$(Replace(Text, vbNullChar, "?"), 8192)
Failed:
End Function

' Runs a selected backend tool in a kill-on-close job with bounded output and child lifetime.
Private Function RunBackendTool(ByVal Application As String, ByVal Arguments As String, ByVal Stage As String, ByVal LogName As String, ByVal ToolName As String, ByRef Diagnostic As String) As Boolean
    Dim Startup As StartupInformation, Process As ProcessInformation, Security As SecurityAttributes
    Dim JobInfo(0 To 111) As Byte, Job As Long, Log As Long, InputHandle As Long
    Dim Command As String, LogPath As String, NullPath As String
    Dim Index As Long, WaitCode As Long, ExitCode As Long, Count As Long, High As Long, Detail As String
    On Error GoTo Failed
    Log = -1: InputHandle = -1
    Security.Length = Len(Security): Security.Inherit = 1
    LogPath = Stage & "\" & LogName
    Log = CreateFileW(StrPtr(LogPath), &HC0000000, 1, VarPtr(Security), 1, &H80, 0)
    If Log = -1 Then GoTo Failed
    NullPath = "NUL"
    InputHandle = CreateFileW(StrPtr(NullPath), &H80000000, 3, VarPtr(Security), 3, &H80, 0)
    If InputHandle = -1 Then GoTo Failed
    Job = CreateJobObjectW(0, 0)
    If Job = 0 Then GoTo Failed
    ' x86 JOBOBJECT_EXTENDED_LIMIT_INFORMATION has 112 bytes; LimitFlags begins at byte16.
    JobInfo(17) = &H20
    If SetInformationJobObject(Job, 9, JobInfo(0), 112) = 0 Then GoTo Failed
    Startup.Size = Len(Startup): Startup.Flags = &H101
    Startup.InputHandle = InputHandle: Startup.OutputHandle = Log: Startup.ErrorHandle = Log
    Command = QuoteArgument(Application) & " " & Arguments
    If Len(Command) > 32766 Then Detail = "backend command exceeds Windows command limit": GoTo Failed
    If CreateProcessW(StrPtr(Application), StrPtr(Command), 0, 0, 1, &H8000004, 0, StrPtr(Stage), Startup, Process) = 0 Then Detail = "cannot start " & ToolName & ": " & Application: GoTo Failed
    If AssignProcessToJobObject(Job, Process.Process) = 0 Then Detail = "cannot contain " & ToolName & " process tree": GoTo Failed
    If ResumeThread(Process.Thread) = -1 Then GoTo Failed
    For Index = 1 To 600
        WaitCode = WaitForSingleObject(Process.Process, 50)
        Count = GetFileSize(Log, High)
        If High <> 0 Or Count < 0 Or Count > MaximumLogBytes Then Detail = ToolName & " diagnostic output exceeds 65536 bytes": GoTo Failed
        If WaitCode = 0 Then Exit For
        If WaitCode <> 258 Then GoTo Failed
    Next Index
    If WaitCode <> 0 Then Detail = ToolName & " exceeded 30 second timeout": GoTo Failed
    If GetExitCodeProcess(Process.Process, ExitCode) = 0 Then GoTo Failed
    If ExitCode <> 0 Then Detail = ToolName & " failed with exit " & CStr(ExitCode) & vbCrLf & ReadLog(Log): GoTo Failed
    RunBackendTool = True
    GoTo Cleanup
Failed:
    On Error Resume Next
    If Len(Detail) = 0 Then Detail = "cannot complete bounded " & ToolName & " invocation"
    Diagnostic = "UBE: E_BACKEND: " & Detail
    If Job <> 0 Then TerminateJobObject Job, 1
    If Process.Process <> 0 Then
        TerminateProcess Process.Process, 1
        WaitForSingleObject Process.Process, 5000
    End If
Cleanup:
    On Error Resume Next
    If Job <> 0 Then CloseHandle Job
    If Process.Thread <> 0 Then CloseHandle Process.Thread
    If Process.Process <> 0 Then CloseHandle Process.Process
    If InputHandle <> -1 Then CloseHandle InputHandle
    If Log <> -1 Then CloseHandle Log
End Function

' Checks the bounded archive produced by the installed import-library tool.
Private Function CheckImportLibrary(ByVal Path As String, ByRef Diagnostic As String) As Boolean
    Dim Handle As Long, Count As Long, High As Long, Completed As Long
    Dim Header(0 To 7) As Byte
    On Error GoTo Failed
    Handle = -1
    Handle = CreateFileW(StrPtr(Path), &H80000000, 1, 0, 3, &H80, 0)
    If Handle = -1 Then GoTo Failed
    Count = GetFileSize(Handle, High)
    If High <> 0 Or Count < 8 Or Count > 65536 Then GoTo Failed
    If ReadFile(Handle, Header(0), 8, Completed, 0) = 0 Or Completed <> 8 Then GoTo Failed
    If Header(0) <> 33 Or Header(1) <> 60 Or Header(2) <> 97 Or Header(3) <> 114 Or Header(4) <> 99 Or Header(5) <> 104 Or Header(6) <> 62 Or Header(7) <> 10 Then GoTo Failed
    CloseHandle Handle
    CheckImportLibrary = True
    Exit Function
Failed:
    On Error Resume Next
    If Handle <> -1 Then CloseHandle Handle
    CheckImportLibrary = Reject(Diagnostic, "E_BACKEND", "LLVM import tool did not produce a bounded memory import library")
End Function

' Prepares only the known target memory imports, then invokes Clang with the generated archive.
Private Function RunClang(ByVal Clang As String, ByVal Stage As String, ByVal Optimization As String, ByVal MemoryImports As Boolean, ByVal FileImports As Boolean, ByRef Diagnostic As String) As Boolean
    Dim Arguments As String, Tool As String, Definition As String, Library As String
    If MemoryImports Then
        Tool = Left$(Clang, InStrRev(Clang, "\")) & "llvm-dlltool.exe"
        Definition = "LIBRARY KERNEL32.dll" & vbCrLf & "EXPORTS" & vbCrLf & "VirtualAlloc" & vbCrLf & "VirtualFree" & vbCrLf
        If FileImports Then
            Definition = Definition & "CreateFileW" & vbCrLf & "ReadFile" & vbCrLf & "WriteFile" & vbCrLf & "CloseHandle" & vbCrLf
            Definition = Definition & "GetFileSizeEx" & vbCrLf & "GetFileType" & vbCrLf & "FlushFileBuffers" & vbCrLf & "MultiByteToWideChar" & vbCrLf
            Definition = Definition & "GetCommandLineW" & vbCrLf & "GetStdHandle" & vbCrLf & "WideCharToMultiByte" & vbCrLf
            Definition = Definition & "GetFullPathNameW" & vbCrLf & "GetFinalPathNameByHandleW" & vbCrLf & "CompareStringOrdinal" & vbCrLf
            Definition = Definition & "GetFileInformationByHandle" & vbCrLf & "GetModuleFileNameW" & vbCrLf & "GetTickCount64" & vbCrLf
            Definition = Definition & "GetCurrentProcess" & vbCrLf & "DuplicateHandle" & vbCrLf & "CreateProcessW" & vbCrLf & "InitializeProcThreadAttributeList" & vbCrLf
            Definition = Definition & "UpdateProcThreadAttribute" & vbCrLf & "DeleteProcThreadAttributeList" & vbCrLf & "CreateJobObjectW" & vbCrLf & "SetInformationJobObject" & vbCrLf
            Definition = Definition & "AssignProcessToJobObject" & vbCrLf & "ResumeThread" & vbCrLf & "WaitForSingleObject" & vbCrLf & "GetExitCodeProcess" & vbCrLf
            Definition = Definition & "QueryInformationJobObject" & vbCrLf & "TerminateJobObject" & vbCrLf & "TerminateProcess" & vbCrLf & "Sleep" & vbCrLf
            Definition = Definition & "GetLastError" & vbCrLf & "CreateDirectoryW" & vbCrLf & "RemoveDirectoryW" & vbCrLf & "DeleteFileW" & vbCrLf & "MoveFileExW" & vbCrLf & "GetFileAttributesW" & vbCrLf
            Definition = Definition & "CreateThread" & vbCrLf
        End If
        If Not WriteIR(Stage & "\kernel32-memory.def", Definition, Diagnostic) Then Exit Function
        Library = Stage & "\kernel32-memory.lib"
        Arguments = "-m i386:x86-64 -d " & QuoteArgument(Stage & "\kernel32-memory.def") & " -l " & QuoteArgument(Library)
        If Not RunBackendTool(Tool, Arguments, Stage, "import.log", "LLVM import tool", Diagnostic) Then Exit Function
        If Not CheckImportLibrary(Library, Diagnostic) Then Exit Function
    End If
    Arguments = "--target=x86_64-pc-windows-msvc -fuse-ld=lld -nostdlib " & Optimization & " -x ir " & QuoteArgument(Stage & "\input.ll")
    If MemoryImports Then Arguments = Arguments & " -x none " & QuoteArgument(Library)
    Arguments = Arguments & " -o " & QuoteArgument(Stage & "\output.exe") & " -Wl,/entry:main,/subsystem:console,/stack:8388608"
    RunClang = RunBackendTool(Clang, Arguments, Stage, "clang.log", "Clang", Diagnostic)
End Function

' Checks bounded DOS/PE headers and the AMD64 executable machine before publication.
Private Function CheckNative(ByVal Path As String, ByRef Diagnostic As String) As Boolean
    Dim Handle As Long, Count As Long, High As Long, Completed As Long, Offset As Long
    Dim Header(0 To 63) As Byte, PE(0 To 25) As Byte
    On Error GoTo Failed
    Handle = CreateFileW(StrPtr(Path), &H80000000, 1, 0, 3, &H80, 0)
    If Handle = -1 Then GoTo Failed
    Count = GetFileSize(Handle, High)
    If High <> 0 Or Count < 90 Or Count > MaximumNativeBytes Then GoTo Failed
    If ReadFile(Handle, Header(0), 64, Completed, 0) = 0 Or Completed <> 64 Then GoTo Failed
    If Header(0) <> &H4D Or Header(1) <> &H5A Or Header(63) > &H7F Then GoTo Failed
    Offset = CLng(Header(60)) + CLng(Header(61)) * 256 + CLng(Header(62)) * 65536 + CLng(Header(63)) * 16777216
    If Offset < 64 Or Offset > Count - 26 Then GoTo Failed
    If SetFilePointer(Handle, Offset, 0, 0) <> Offset Then GoTo Failed
    Completed = 0
    If ReadFile(Handle, PE(0), 26, Completed, 0) = 0 Or Completed <> 26 Then GoTo Failed
    If PE(0) <> &H50 Or PE(1) <> &H45 Or PE(2) <> 0 Or PE(3) <> 0 Then GoTo Failed
    If PE(4) <> &H64 Or PE(5) <> &H86 Or PE(24) <> &HB Or PE(25) <> 2 Then GoTo Failed
    If (PE(22) And 2) = 0 Or (PE(23) And &H20) <> 0 Then GoTo Failed
    CloseHandle Handle
    CheckNative = True
    Exit Function
Failed:
    On Error Resume Next
    If Handle <> -1 Then CloseHandle Handle
    CheckNative = Reject(Diagnostic, "E_BACKEND", "Clang output is not a bounded AMD64 PE32+ executable")
End Function

' Atomically replaces an output only after complete LLVM staging succeeds.
Public Function WriteLLVMOutput(ByRef Project As ProjectContext, ByRef IRText As String, ByVal OutputPath As String, ByRef Diagnostic As String) As Boolean
    Dim Output As String, Directory As String, Stage As String, InputPath As String
    On Error GoTo Failed
    If Not ResolveOutput(Project, OutputPath, Output, Directory, Diagnostic) Then Exit Function
    If Not CreateStage(Directory, Stage, Diagnostic) Then Exit Function
    InputPath = Stage & "\input.ll"
    If Not WriteIR(InputPath, IRText, Diagnostic) Then GoTo Cleanup
    If Not ResolveOutput(Project, OutputPath, Output, Directory, Diagnostic) Then GoTo Cleanup
    If MoveFileExW(StrPtr(InputPath), StrPtr(Output), 9) = 0 Then GoTo Failed
    WriteLLVMOutput = True
    GoTo Cleanup
Failed:
    Diagnostic = "UBE: E_OUTPUT: cannot publish LLVM output: " & OutputPath
Cleanup:
    On Error Resume Next
    RemoveStage Stage
End Function

' Builds an executable in isolation and publishes it only after exit-code and PE acceptance.
Public Function BuildNativeProject(ByRef Project As ProjectContext, ByRef IRText As String, ByVal OutputPath As String, ByVal ClangPath As String, ByRef Diagnostic As String) As Boolean
    Dim Output As String, Directory As String, Stage As String, InputPath As String, NativePath As String
    Dim Optimization As String, Clang As String
    On Error GoTo Failed
    If Project.KindName <> "exe" Then
        BuildNativeProject = Reject(Diagnostic, "E_BACKEND", "native executable build requires Kind Exe; emit LLVM for Library projects")
        Exit Function
    End If
    If Len(ClangPath) = 0 Then ClangPath = "C:\Program Files\LLVM\bin\clang.exe"
    If Not FullPath(ClangPath, Clang, Diagnostic) Then
        BuildNativeProject = Reject(Diagnostic, "E_BACKEND", "invalid Clang executable path")
        Exit Function
    End If
    Select Case FoldAscii(Project.OptimizationName)
    Case "0", "1", "2", "3"
        Optimization = "-O" & Project.OptimizationName
    Case "size"
        Optimization = "-Os"
    Case Else
        BuildNativeProject = Reject(Diagnostic, "E_BACKEND", "unsupported optimization setting")
        Exit Function
    End Select
    If Not ResolveOutput(Project, OutputPath, Output, Directory, Diagnostic) Then Exit Function
    If SamePath(Output, Clang) Then
        BuildNativeProject = Reject(Diagnostic, "E_OUTPUT", "output cannot replace the backend executable")
        Exit Function
    End If
    If InStr(IRText, "@VirtualAlloc") > 0 Then
        If SamePath(Output, Left$(Clang, InStrRev(Clang, "\")) & "llvm-dlltool.exe") Then
            BuildNativeProject = Reject(Diagnostic, "E_OUTPUT", "output cannot replace the LLVM import tool")
            Exit Function
        End If
    End If
    If Not CreateStage(Directory, Stage, Diagnostic) Then Exit Function
    InputPath = Stage & "\input.ll": NativePath = Stage & "\output.exe"
    If Not WriteIR(InputPath, IRText, Diagnostic) Then GoTo Cleanup
    If Not RunClang(Clang, Stage, Optimization, InStr(IRText, "@VirtualAlloc") > 0, InStr(IRText, "@CreateFileW") > 0, Diagnostic) Then GoTo Cleanup
    If Not CheckNative(NativePath, Diagnostic) Then GoTo Cleanup
    If Not ResolveOutput(Project, OutputPath, Output, Directory, Diagnostic) Then GoTo Cleanup
    If MoveFileExW(StrPtr(NativePath), StrPtr(Output), 9) = 0 Then
        BuildNativeProject = Reject(Diagnostic, "E_OUTPUT", "cannot atomically publish executable: " & OutputPath)
        GoTo Cleanup
    End If
    BuildNativeProject = True
    GoTo Cleanup
Failed:
    Diagnostic = "UBE: E_BACKEND: unable to complete native build"
Cleanup:
    On Error Resume Next
    RemoveStage Stage
End Function
