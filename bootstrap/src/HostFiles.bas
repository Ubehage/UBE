Attribute VB_Name = "HostFiles"
Option Explicit

' Bounded Windows host operations for UTF-8 files, canonical paths and command output.
Private Declare Function CreateFileW Lib "kernel32" (ByVal FileName As Long, ByVal Access As Long, ByVal Share As Long, ByVal Security As Long, ByVal Disposition As Long, ByVal Flags As Long, ByVal Template As Long) As Long
Private Declare Function ReadFile Lib "kernel32" (ByVal Handle As Long, ByRef Buffer As Any, ByVal Count As Long, ByRef Completed As Long, ByVal Overlapped As Long) As Long
Private Declare Function WriteFile Lib "kernel32" (ByVal Handle As Long, ByRef Buffer As Any, ByVal Count As Long, ByRef Completed As Long, ByVal Overlapped As Long) As Long
Private Declare Function CloseHandle Lib "kernel32" (ByVal Handle As Long) As Long
Private Declare Function GetFileSize Lib "kernel32" (ByVal Handle As Long, ByRef High As Long) As Long
Private Declare Function GetFinalPathNameByHandleW Lib "kernel32" (ByVal Handle As Long, ByVal Buffer As Long, ByVal Capacity As Long, ByVal Flags As Long) As Long
Private Declare Function GetFullPathNameW Lib "kernel32" (ByVal Name As Long, ByVal Capacity As Long, ByVal Buffer As Long, ByVal LastPart As Long) As Long
Private Declare Function MultiByteToWideChar Lib "kernel32" (ByVal Page As Long, ByVal Flags As Long, ByRef Bytes As Any, ByVal Count As Long, ByVal Wide As Long, ByVal Capacity As Long) As Long
Private Declare Function WideCharToMultiByte Lib "kernel32" (ByVal Page As Long, ByVal Flags As Long, ByVal Wide As Long, ByVal Count As Long, ByRef Bytes As Any, ByVal Capacity As Long, ByVal DefaultChar As Long, ByVal UsedDefault As Long) As Long
Private Declare Function GetStdHandle Lib "kernel32" (ByVal Which As Long) As Long
Private Declare Function GetCommandLineW Lib "kernel32" () As Long
Private Declare Function CommandLineToArgvW Lib "shell32" (ByVal CommandLine As Long, ByRef Count As Long) As Long
Private Declare Function LocalFree Lib "kernel32" (ByVal Memory As Long) As Long
Private Declare Function lstrlenW Lib "kernel32" (ByVal Text As Long) As Long
Private Declare Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" (ByRef Destination As Any, ByRef Source As Any, ByVal Count As Long)
Private Declare Function CompareStringOrdinal Lib "kernel32" (ByVal First As Long, ByVal FirstLength As Long, ByVal Second As Long, ByVal SecondLength As Long, ByVal IgnoreCase As Long) As Long

Public Const MaximumPathCharacters As Long = 32767

' Formats a controlled diagnostic and returns False to the caller.
Public Function Reject(ByRef Diagnostic As String, ByVal Code As String, ByVal Detail As String) As Boolean
    Diagnostic = "UBE: " & Code & ": " & Detail
    Reject = False
End Function

' Copies the OS-parsed Unicode arguments without inventing shell quoting rules.
Public Function ReadArguments(ByRef Arguments() As String, ByRef Count As Long, ByRef Diagnostic As String) As Boolean
    Dim Vector As Long
    Dim Pointer As Long
    Dim Index As Long
    Dim Length As Long
    On Error GoTo Failed
    Vector = CommandLineToArgvW(GetCommandLineW(), Count)
    If Vector = 0 Then GoTo Failed
    If Count < 1 Or Count > 16 Then GoTo Failed
    ReDim Arguments(0 To Count - 1)
    For Index = 0 To Count - 1
        CopyMemory Pointer, ByVal Vector + Index * 4, 4
        If Pointer = 0 Then GoTo Failed
        Length = lstrlenW(Pointer)
        If Length < 0 Or Length > MaximumPathCharacters Then GoTo Failed
        Arguments(Index) = String$(Length, vbNullChar)
        If Length > 0 Then CopyMemory ByVal StrPtr(Arguments(Index)), ByVal Pointer, Length * 2
    Next Index
    LocalFree Vector
    ReadArguments = True
    Exit Function
Failed:
    On Error Resume Next
    If Vector <> 0 Then LocalFree Vector
    ReadArguments = Reject(Diagnostic, "E_USAGE", "invalid or excessive command arguments")
End Function

' Writes UTF-8 to inherited stdout or stderr, checking complete bounded progress.
Public Function WriteOutput(ByVal Text As String, ByVal IsError As Boolean) As Boolean
    Dim Bytes() As Byte
    Dim Count As Long
    Dim Written As Long
    Dim Position As Long
    Dim Handle As Long
    On Error GoTo Failed
    Text = Text & vbCrLf
    If IsError Then Handle = GetStdHandle(-12) Else Handle = GetStdHandle(-11)
    If Handle = 0 Or Handle = -1 Then Exit Function
    Count = WideCharToMultiByte(65001, 0, StrPtr(Text), Len(Text), ByVal 0&, 0, 0, 0)
    If Count <= 0 Then Exit Function
    ReDim Bytes(0 To Count - 1)
    If WideCharToMultiByte(65001, 0, StrPtr(Text), Len(Text), Bytes(0), Count, 0, 0) <> Count Then Exit Function
    Do While Position < Count
        Written = 0
        If WriteFile(Handle, Bytes(Position), Count - Position, Written, 0) = 0 Then Exit Function
        If Written <= 0 Or Written > Count - Position Then Exit Function
        Position = Position + Written
    Loop
    WriteOutput = True
    Exit Function
Failed:
    WriteOutput = False
End Function

' Resolves a bounded host path without changing process working-directory state.
Public Function FullPath(ByVal Path As String, ByRef Resolved As String, ByRef Diagnostic As String) As Boolean
    Dim Buffer As String
    Dim Length As Long
    On Error GoTo Failed
    If Len(Path) = 0 Or Len(Path) > MaximumPathCharacters Or InStr(Path, vbNullChar) <> 0 Then
        FullPath = Reject(Diagnostic, "E_PATH", "invalid or excessive path")
        Exit Function
    End If
    Buffer = String$(MaximumPathCharacters + 1, vbNullChar)
    Length = GetFullPathNameW(StrPtr(Path), Len(Buffer), StrPtr(Buffer), 0)
    If Length <= 0 Or Length > MaximumPathCharacters Then GoTo Failed
    Resolved = Left$(Buffer, Length)
    FullPath = True
    Exit Function
Failed:
    FullPath = Reject(Diagnostic, "E_PATH", "cannot normalize path")
End Function

' Compares Windows paths ordinally, independent of the user's text locale.
Public Function SamePath(ByVal First As String, ByVal Second As String) As Boolean
    SamePath = (CompareStringOrdinal(StrPtr(First), Len(First), StrPtr(Second), Len(Second), 1) = 2)
End Function

' Requires a complete directory prefix so similarly named sibling directories do not match.
Public Function PathWithin(ByVal Root As String, ByVal Path As String) As Boolean
    Dim Prefix As String
    Prefix = Root
    If Right$(Prefix, 1) <> "\" Then Prefix = Prefix & "\"
    If Len(Path) <= Len(Prefix) Then Exit Function
    PathWithin = SamePath(Left$(Path, Len(Prefix)), Prefix)
End Function

' Loads an immutable read handle, validates strict UTF-8 and returns its physical path.
Public Function ReadUtf8File(ByVal Path As String, ByVal Limit As Long, ByRef Text As String, ByRef Canonical As String, ByRef ByteCount As Long, ByRef Diagnostic As String, Optional ByVal RequiredRoot As String = "") As Boolean
    Dim Handle As Long
    Dim High As Long
    Dim Bytes() As Byte
    Dim Position As Long
    Dim Completed As Long
    Dim Start As Long
    Dim Characters As Long
    Dim Buffer As String
    Dim Length As Long
    Dim Code As String
    Dim Index As Long
    Dim Unit As Long
    On Error GoTo Unexpected
    Handle = -1
    Code = "E_IO"
    Handle = CreateFileW(StrPtr(Path), &H80000000, 1, 0, 3, &H80, 0)
    If Handle = -1 Then GoTo Failed
    ByteCount = GetFileSize(Handle, High)
    If High <> 0 Or ByteCount < 0 Or ByteCount > Limit Then
        Code = "E_LIMIT"
        GoTo Failed
    End If
    Buffer = String$(MaximumPathCharacters + 1, vbNullChar)
    Length = GetFinalPathNameByHandleW(Handle, StrPtr(Buffer), Len(Buffer), 0)
    If Length <= 0 Or Length > MaximumPathCharacters Then GoTo Failed
    Canonical = Left$(Buffer, Length)
    If Left$(Canonical, 8) = "\\?\UNC\" Then
        Canonical = "\\" & Mid$(Canonical, 9)
    ElseIf Left$(Canonical, 4) = "\\?\" Then
        Canonical = Mid$(Canonical, 5)
    End If
    If Len(RequiredRoot) > 0 Then
        If Not PathWithin(RequiredRoot, Canonical) Then
            Code = "E_PATH"
            GoTo Failed
        End If
    End If
    Text = ""
    If ByteCount > 0 Then
        ReDim Bytes(0 To ByteCount - 1)
        Do While Position < ByteCount
            Completed = 0
            If ReadFile(Handle, Bytes(Position), ByteCount - Position, Completed, 0) = 0 Then GoTo Failed
            If Completed <= 0 Or Completed > ByteCount - Position Then GoTo Failed
            Position = Position + Completed
        Loop
        If ByteCount >= 3 Then
            If Bytes(0) = &HEF And Bytes(1) = &HBB And Bytes(2) = &HBF Then Start = 3
        End If
        If Start < ByteCount Then
            Code = "E_ENCODING"
            Characters = MultiByteToWideChar(65001, 8, Bytes(Start), ByteCount - Start, 0, 0)
            If Characters <= 0 Then GoTo Failed
            Text = String$(Characters, vbNullChar)
            If MultiByteToWideChar(65001, 8, Bytes(Start), ByteCount - Start, StrPtr(Text), Characters) <> Characters Then GoTo Failed
            If InStr(Text, vbNullChar) <> 0 Then GoTo Failed
            If InStr(Replace(Text, vbCrLf, ""), vbCr) <> 0 Then GoTo Failed
            For Index = 1 To Len(Text)
                Unit = AscW(Mid$(Text, Index, 1)) And &HFFFF&
                If Unit < 32 Then
                    If Unit <> 9 And Unit <> 10 And Unit <> 13 Then GoTo Failed
                End If
                If Unit = 127 Then GoTo Failed
            Next Index
        End If
    End If
    Code = "E_IO"
    If CloseHandle(Handle) = 0 Then
        Handle = -1
        GoTo Failed
    End If
    Handle = -1
    ReadUtf8File = True
    Exit Function
Unexpected:
    Code = "E_IO"
Failed:
    On Error Resume Next
    If Handle <> -1 Then CloseHandle Handle
    ReadUtf8File = Reject(Diagnostic, Code, "cannot load " & Path)
End Function
