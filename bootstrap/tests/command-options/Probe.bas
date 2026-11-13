UBE SOURCE 1 MODULE
Attribute UBE_Name = "CommandProbe"
' Asserts command admission, diagnostic freshness and preservation of caller-owned request fields.

' Compares exact command results and records against independently supplied expectations.
Public Function Check(ByRef Raw() As Byte, ByVal Mode As Long, ByVal Clang As Long, ByVal Code As Long, ByVal Argument As Long, ByVal ErrorNumber As Long) As Long
    Dim Options As CommandOptions.CommandRequest
    Dim Diagnostic As CommandOptions.CommandDiagnostic
    Dim Status As Boolean
    Options.Mode = 77
    Options.ClangArgument = 88
    Diagnostic.Code = 99
    Diagnostic.Argument = 99
    Status = FilePrimitives.SetError(71)
    Status = CommandOptions.TryParse(Raw, Options, Diagnostic)
    If Status <> (Code = 0) Then Check = 1: Exit Function
    If Diagnostic.Code <> Code Or Diagnostic.Argument <> Argument Then Check = 2: Exit Function
    If Err.Number <> ErrorNumber Then Check = 3: Exit Function
    If Code = 0 Then
        If Options.Mode <> Mode Or Options.ClangArgument <> Clang Then Check = 4: Exit Function
    Else
        If Options.Mode <> 77 Or Options.ClangArgument <> 88 Then Check = 5: Exit Function
    End If
End Function

' Requires allocation failure to preserve the old request and report the argument being read.
Public Function CheckAllocation(ByRef Raw() As Byte, ByVal ExpectedArgument As Long) As Long
    Dim Options As CommandOptions.CommandRequest
    Dim Diagnostic As CommandOptions.CommandDiagnostic
    Dim Status As Boolean
    Options.Mode = 77
    Options.ClangArgument = 88
    Diagnostic.Code = 99
    Diagnostic.Argument = 99
    Status = FilePrimitives.SetError(71)
    Status = CommandOptions.TryParse(Raw, Options, Diagnostic)
    If Status Or Diagnostic.Code <> 2 Then CheckAllocation = 1: Exit Function
    If Diagnostic.Argument <> ExpectedArgument Then CheckAllocation = 2: Exit Function
    If Options.Mode <> 77 Or Options.ClangArgument <> 88 Then CheckAllocation = 3: Exit Function
    If Err.Number <> 7 Then CheckAllocation = 4: Exit Function
End Function
