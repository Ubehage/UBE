UBE SOURCE 1 MODULE
Attribute UBE_Name = "CommandDispatch"

Sub PrintCompilerUsage(ByVal ProjectPath As Boolean)
    If ProjectPath Then
        Print "usage: ube --check <project.UBE> [--jobs N] (N: 1..4)"
    Else
        Print "usage: ube --check <source-file>"
    End If
End Sub

Function TryMatchCommandOption(ByRef Bytes() As Byte, ByVal Expected As String, ByRef Matches As Boolean) As Boolean
    TryMatchCommandOption = False
    Matches = False
    Dim Count As Long = ByteStorageLength(Bytes)
    If Count <> StringLength(Expected) Then
        TryMatchCommandOption = True
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Count
        If Bytes(Index) <> StringByteAt(Expected, Index) Then
            TryMatchCommandOption = True
            Exit Function
        End If
        Index = Index + 1
    Wend
    Matches = True
    TryMatchCommandOption = True
End Function

Function TryRecognizeProjectArgument(ByRef Bytes() As Byte, ByRef Matches As Boolean) As Boolean
    TryRecognizeProjectArgument = False
    Matches = False
    Dim Count As Long = ByteStorageLength(Bytes)
    If Count >= 4 Then
        Dim First As Long = Bytes(Count - 3)
        Dim Second As Long = Bytes(Count - 2)
        Dim Third As Long = Bytes(Count - 1)
        If First >= 65 And First <= 90 Then
            First = First + 32
        End If
        If Second >= 65 And Second <= 90 Then
            Second = Second + 32
        End If
        If Third >= 65 And Third <= 90 Then
            Third = Third + 32
        End If
        Matches = Bytes(Count - 4) = 46 And First = 117 And Second = 98 And Third = 101
    End If
    TryRecognizeProjectArgument = True
End Function

Function TryReadCommandJobs(ByRef Bytes() As Byte, ByRef Jobs As Long, ByRef Valid As Boolean) As Boolean
    TryReadCommandJobs = False
    Valid = False
    Dim Count As Long = ByteStorageLength(Bytes)
    Dim Index As Long = 0
    Dim Value As Long = 0
    While Index < Count
        Dim Digit As Long = Bytes(Index)
        If Digit < 48 Or Digit > 57 Then
            TryReadCommandJobs = True
            Exit Function
        End If
        ' Consume every digit, but never overflow on an invalid large budget.
        If Value <= 4 Then
            Value = Value * 10 + Digit - 48
        End If
        Index = Index + 1
    Wend
    If Count > 0 And Value >= 1 And Value <= 4 Then
        Jobs = Value
        Valid = True
    End If
    TryReadCommandJobs = True
End Function

Function TryRunProjectCheck(ByRef PathUtf8() As Byte, ByVal Jobs As Long, ByRef ExitCode As Long) As Boolean
    TryRunProjectCheck = True
    ExitCode = 1
    Dim Limits As ProjectLimits
    Call DefaultProjectLimits(Limits)
    Dim Cancellation As SourceCancellation = New SourceCancellation
    If Cancellation Is Nothing Then
        Call PrintProjectStorageFailure()
        Exit Function
    End If
    Dim Published As ProjectSyntax
    Dim Failure As ProjectFailure
    Failure.Kind = 5
    Failure.Code = 1310
    Failure.PackageId = -1
    Failure.SourceId = -1
    Dim OpenToken As Long = 0
    If TryParseProject(PathUtf8, Limits, Jobs, Cancellation, Published, Failure, OpenToken) Then
        Print "error UBE1012: source checking is not implemented"
    Else
        If TryPrintProjectFailure(PathUtf8, Failure) = False Then
            Call PrintProjectStorageFailure()
        End If
    End If
    If OpenToken <> 0 Then
        Dim CloseFailure As Long = 0
        If TryCloseByteFile(OpenToken, CloseFailure) = False Then
            Print "error UBE1321: could not release project input; operating system cleanup is required"
        End If
    End If
End Function

' True means the command was handled, including ordinary rejection/unavailable
' outcomes. False is managed admission failure for the rootless Main fallback.
Function TryRunCompilerCommand(ByRef ExitCode As Long) As Boolean
    TryRunCompilerCommand = True
    ExitCode = 2
    Dim Count As Long = CommandArgumentCount()
    If Count < 2 Then
        Call PrintCompilerUsage(False)
        Exit Function
    End If
    Dim OptionBytes() As Byte
    Dim PathUtf8() As Byte
    Dim ArgumentFailure As Long = 8
    If TryCommandArgument(0, OptionBytes, ArgumentFailure) = False Or TryCommandArgument(1, PathUtf8, ArgumentFailure) = False Then
        Print "error UBE1010: cannot read command argument"
        Exit Function
    End If
    Dim ProjectPath As Boolean = False
    Dim CheckOption As Boolean = False
    If TryRecognizeProjectArgument(PathUtf8, ProjectPath) = False Or TryMatchCommandOption(OptionBytes, "--check", CheckOption) = False Then
        Print "error UBE1010: cannot read command argument"
        Exit Function
    End If
    If CheckOption = False Then
        Call PrintCompilerUsage(ProjectPath)
        Exit Function
    End If
    Dim Jobs As Long = 1
    If ProjectPath Then
        If Count = 4 Then
            Dim JobsOption() As Byte
            Dim JobsBytes() As Byte
            If TryCommandArgument(2, JobsOption, ArgumentFailure) = False Or TryCommandArgument(3, JobsBytes, ArgumentFailure) = False Then
                Print "error UBE1010: cannot read command argument"
                Exit Function
            End If
            Dim JobsOptionAccepted As Boolean = False
            Dim JobsValid As Boolean = False
            If TryMatchCommandOption(JobsOption, "--jobs", JobsOptionAccepted) = False Or TryReadCommandJobs(JobsBytes, Jobs, JobsValid) = False Then
                Print "error UBE1010: cannot read command argument"
                Exit Function
            End If
            If JobsOptionAccepted = False Or JobsValid = False Then
                Call PrintCompilerUsage(True)
                Exit Function
            End If
        Else
            If Count <> 2 Then
                Call PrintCompilerUsage(True)
                Exit Function
            End If
        End If
        ExitCode = 1
        If TryRunProjectCheck(PathUtf8, Jobs, ExitCode) = False Then
            Call PrintProjectStorageFailure()
        End If
    Else
        If Count <> 2 Then
            Call PrintCompilerUsage(False)
            Exit Function
        End If
        ExitCode = 1
        If TryCheckSourcePath(PathUtf8, ExitCode) = False Then
            Call PrintSyntaxStorageFailure()
        End If
    End If
End Function

Function TryCheckSourcePath(ByRef PathUtf8() As Byte, ByRef ExitCode As Long) As Boolean
    TryCheckSourcePath = True
    Dim Document As SourceDocument
    Dim Failure As SourceFailure
    Dim FileFailure As Long = 0
    Dim OpenToken As Long = 0
    ExitCode = 1
    Failure.Kind = 5
    Failure.Position.LineNumber = 1
    Failure.Position.Column = 1
    If TryReadSourceFile(PathUtf8, 16777216, Document, Failure, FileFailure, OpenToken) = False Then
        Call PrintSourceFailure(Failure, FileFailure)
        If OpenToken <> 0 Then
            Dim CloseFailure As Long = 0
            If TryCloseByteFile(OpenToken, CloseFailure) = False Then
                Print "error UBE1011: could not release source file; operating system cleanup is required"
            End If
        End If
        Exit Function
    End If
    ' A pending conditional stream is outside this grammar consumer. Notice it
    ' before an inactive quote/attribute could fail whole-file scan/envelope work.
    Dim SyntaxFailure As SyntaxFailure
    SyntaxFailure.Kind = 5
    Dim PendingConditional As Boolean = False
    If TrySyntaxConditionalInput(Document, PendingConditional, SyntaxFailure) = False Then
        If TryPrintSourceSyntaxFailure(Document, SyntaxFailure) = False Then
            Call PrintSyntaxStorageFailure()
        End If
        Exit Function
    End If
    If PendingConditional Then
        If TryPrintSourceSyntaxFailure(Document, SyntaxFailure) = False Then
            Call PrintSyntaxStorageFailure()
        End If
        Exit Function
    End If
    Dim Envelope As SourceEnvelope
    Dim ScanFailure As ScannerFailure
    ScanFailure.Kind = 5
    ScanFailure.First.ByteOffset = Document.ContentStart
    ScanFailure.First.LineNumber = 1
    ScanFailure.First.Column = 1
    ScanFailure.Last = ScanFailure.First
    Dim ExtensionKind As Long = SourcePathKind(PathUtf8)
    Dim EnvelopeAccepted As Boolean = TryReadSourceEnvelope(Document, ExtensionKind, Envelope, ScanFailure)
    ' The raw scanner owns core tokens; opaque designer/legacy fragments remain
    ' exact source views for their grammar consumer, not fabricated core tokens.
    Dim LexicalFailure As ScannerFailure
    LexicalFailure.Kind = 5
    LexicalFailure.First.ByteOffset = Document.ContentStart
    LexicalFailure.First.LineNumber = 1
    LexicalFailure.First.Column = 1
    LexicalFailure.Last = LexicalFailure.First
    Dim LexicalAccepted As Boolean = True
    Dim ScanCore As Boolean = EnvelopeAccepted And Envelope.Format = 1 And Envelope.Kind = 1
    If EnvelopeAccepted = False And ScanFailure.Kind >= 100 And ExtensionKind = 1 Then
        ScanCore = True
    End If
    If ScanCore Then
        Dim Tokens() As SourceToken
        LexicalAccepted = TryScanSource(Document, 0, 1048576, Tokens, LexicalFailure)
    End If
    If LexicalAccepted = False Then
        Dim PreferLexical As Boolean = PreferSourceLexicalFailure(EnvelopeAccepted, LexicalFailure, ScanFailure)
        If PreferLexical Then
            Call PrintScannerFailure(LexicalFailure)
            Exit Function
        End If
    End If
    If EnvelopeAccepted = False Then
        Call PrintScannerFailure(ScanFailure)
        Exit Function
    End If
    If ScanCore Then
        Dim Syntax() As SyntaxResult
        Dim SyntaxMetrics As SyntaxMetrics
        SyntaxFailure.Kind = 5
        If TryParseSyntax(Document, Tokens, 3, 0, 1048576, 1048576, 256, Syntax, SyntaxFailure, SyntaxMetrics) = False Then
            If TryPrintSourceSyntaxFailure(Document, SyntaxFailure) = False Then
                Call PrintSyntaxStorageFailure()
            End If
            Exit Function
        End If
    Else
        SyntaxFailure.Kind = 5
        If TryDeferredSyntaxEnvelope(Document, Envelope, SyntaxFailure) = False Then
            SyntaxFailure.Kind = 5
        End If
        If TryPrintSourceSyntaxFailure(Document, SyntaxFailure) = False Then
            Call PrintSyntaxStorageFailure()
        End If
        Exit Function
    End If
    Print "error UBE1012: source checking is not implemented"
End Function
