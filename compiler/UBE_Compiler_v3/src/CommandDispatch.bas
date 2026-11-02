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

Function TryRunProjectCheck(ByRef PathUtf8() As Byte, ByVal Jobs As Long, ByRef ExitCode As Long, ByRef FallbackCode As Long, ByRef OpenToken As Long) As Boolean
    TryRunProjectCheck = False
    ExitCode = 1
    FallbackCode = 1310
    Dim Limits As ProjectLimits
    Call DefaultProjectLimits(Limits)
    Dim Cancellation As SourceCancellation = New SourceCancellation
    If Cancellation Is Nothing Then
        Exit Function
    End If
    Dim Published As ProjectSyntax
    Dim Failure As ProjectFailure
    Failure.Kind = 5
    Failure.Code = 1310
    Failure.PackageId = -1
    Failure.SourceId = -1
    If TryParseProject(PathUtf8, Limits, Jobs, Cancellation, Published, Failure, OpenToken) Then
        FallbackCode = 1428
        Dim SemanticLimits As SemanticLimits
        Call DefaultSemanticLimits(SemanticLimits)
        Dim Checked As SemanticResult
        Dim SemanticFailure As SemanticFailure
        Call ResetSemanticFailure(SemanticFailure)
        If TryCheckProjectSemantics(Published, Jobs, SemanticLimits, Cancellation, Checked, SemanticFailure) Then
            ExitCode = 0
        Else
            If TryPrintProjectSemanticFailure(PathUtf8, Published, SemanticFailure) = False Then
                Exit Function
            End If
        End If
    Else
        If TryPrintProjectFailure(PathUtf8, Failure) = False Then
            Exit Function
        End If
    End If
    TryRunProjectCheck = True
End Function

' True means complete handling, including ordinary rejection/defer. A failed
' managed entry returns False with the caller's already-selected static fallback.
Function TryRunCompilerCommand(ByRef ExitCode As Long, ByRef FallbackCode As Long, ByRef OpenToken As Long, ByRef ReleaseCode As Long) As Boolean
    TryRunCompilerCommand = False
    ExitCode = 2
    Dim Count As Long = CommandArgumentCount()
    If Count < 2 Then
        Call PrintCompilerUsage(False)
        TryRunCompilerCommand = True
        Exit Function
    End If
    Dim OptionBytes() As Byte
    Dim PathUtf8() As Byte
    Dim ArgumentFailure As Long = 8
    If TryCommandArgument(0, OptionBytes, ArgumentFailure) = False Or TryCommandArgument(1, PathUtf8, ArgumentFailure) = False Then
        Print "error UBE1010: cannot read command argument"
        TryRunCompilerCommand = True
        Exit Function
    End If
    Dim ProjectPath As Boolean = False
    Dim CheckOption As Boolean = False
    If TryRecognizeProjectArgument(PathUtf8, ProjectPath) = False Or TryMatchCommandOption(OptionBytes, "--check", CheckOption) = False Then
        Print "error UBE1010: cannot read command argument"
        TryRunCompilerCommand = True
        Exit Function
    End If
    If CheckOption = False Then
        Call PrintCompilerUsage(ProjectPath)
        TryRunCompilerCommand = True
        Exit Function
    End If
    Dim Jobs As Long = 1
    If ProjectPath Then
        ReleaseCode = 1321
        If Count = 4 Then
            Dim JobsOption() As Byte
            Dim JobsBytes() As Byte
            If TryCommandArgument(2, JobsOption, ArgumentFailure) = False Or TryCommandArgument(3, JobsBytes, ArgumentFailure) = False Then
                Print "error UBE1010: cannot read command argument"
                TryRunCompilerCommand = True
                Exit Function
            End If
            Dim JobsOptionAccepted As Boolean = False
            Dim JobsValid As Boolean = False
            If TryMatchCommandOption(JobsOption, "--jobs", JobsOptionAccepted) = False Or TryReadCommandJobs(JobsBytes, Jobs, JobsValid) = False Then
                Print "error UBE1010: cannot read command argument"
                TryRunCompilerCommand = True
                Exit Function
            End If
            If JobsOptionAccepted = False Or JobsValid = False Then
                Call PrintCompilerUsage(True)
                TryRunCompilerCommand = True
                Exit Function
            End If
        Else
            If Count <> 2 Then
                Call PrintCompilerUsage(True)
                TryRunCompilerCommand = True
                Exit Function
            End If
        End If
        ExitCode = 1
        TryRunCompilerCommand = TryRunProjectCheck(PathUtf8, Jobs, ExitCode, FallbackCode, OpenToken)
    Else
        ReleaseCode = 1011
        If Count <> 2 Then
            Call PrintCompilerUsage(False)
            TryRunCompilerCommand = True
            Exit Function
        End If
        ExitCode = 1
        FallbackCode = 1210
        TryRunCompilerCommand = TryCheckSourcePath(PathUtf8, ExitCode, FallbackCode, OpenToken)
    End If
End Function

Function TryPrintSourceReadFailure(ByRef Failure As SourceFailure, ByVal FileFailure As Long) As Boolean
    TryPrintSourceReadFailure = False
    Dim Prepared As String
    If TryFormatSourceInputFailure(Failure, FileFailure, Prepared) = False Then
        Exit Function
    End If
    Print Prepared
    TryPrintSourceReadFailure = True
End Function
Function TryPrintSourceScanFailure(ByRef Failure As ScannerFailure) As Boolean
    TryPrintSourceScanFailure = False
    Dim Prepared As String
    If TryFormatSourceScannerFailure(Failure, Prepared) = False Then
        Exit Function
    End If
    Print Prepared
    TryPrintSourceScanFailure = True
End Function

Function TryCheckSourcePath(ByRef PathUtf8() As Byte, ByRef ExitCode As Long, ByRef FallbackCode As Long, ByRef OpenToken As Long) As Boolean
    TryCheckSourcePath = False
    ExitCode = 1
    Dim Work As SourceWork
    Dim Owner As SourceOwner
    Set Work = New SourceWork
    Set Owner = New SourceOwner
    If Work Is Nothing Or Owner Is Nothing Then
        Exit Function
    End If
    Owner.SourceId = 0
    Set Work.Owner = Owner
    If (Work.Owner Is Owner) = False Then
        Exit Function
    End If
    FallbackCode = 1007
    Dim Failure As SourceFailure
    Dim FileFailure As Long = 0
    Failure.Kind = 5
    Failure.Position.LineNumber = 1
    Failure.Position.Column = 1
    ' Read directly into its retained owner, rather than cloning local source
    ' bytes/tokens/syntax when semantic checking needs their lifetime extended.
    If TryReadSourceFile(PathUtf8, 16777216, Owner.Document, Failure, FileFailure, OpenToken) = False Then
        TryCheckSourcePath = TryPrintSourceReadFailure(Failure, FileFailure)
        Exit Function
    End If
    FallbackCode = 1210
    Dim PendingConditional As Boolean = False
    Work.Failure.Kind = 5
    If TrySyntaxConditionalInput(Owner.Document, PendingConditional, Work.Failure) = False Then
        TryCheckSourcePath = TryPrintSourceSyntaxFailure(Owner.Document, Work.Failure)
        Exit Function
    End If
    If PendingConditional Then
        TryCheckSourcePath = TryPrintSourceSyntaxFailure(Owner.Document, Work.Failure)
        Exit Function
    End If
    FallbackCode = 1100
    Dim Envelope As SourceEnvelope
    Dim ScanFailure As ScannerFailure
    ScanFailure.Kind = 5
    ScanFailure.First.ByteOffset = Owner.Document.ContentStart
    ScanFailure.First.LineNumber = 1
    ScanFailure.First.Column = 1
    ScanFailure.Last = ScanFailure.First
    Dim ExtensionKind As Long = SourcePathKind(PathUtf8)
    Dim EnvelopeAccepted As Boolean = TryReadSourceEnvelope(Owner.Document, ExtensionKind, Envelope, ScanFailure)
    Dim LexicalFailure As ScannerFailure
    LexicalFailure.Kind = 5
    LexicalFailure.First.ByteOffset = Owner.Document.ContentStart
    LexicalFailure.First.LineNumber = 1
    LexicalFailure.First.Column = 1
    LexicalFailure.Last = LexicalFailure.First
    Dim LexicalAccepted As Boolean = True
    Dim ScanCore As Boolean = EnvelopeAccepted And Envelope.Format = 1 And Envelope.Kind = 1
    If EnvelopeAccepted = False And ScanFailure.Kind >= 100 And ExtensionKind = 1 Then
        ScanCore = True
    End If
    If ScanCore Then
        LexicalAccepted = TryScanSource(Owner.Document, 0, 1048576, Work.Tokens, LexicalFailure)
    End If
    If LexicalAccepted = False Then
        Dim PreferLexical As Boolean = PreferSourceLexicalFailure(EnvelopeAccepted, LexicalFailure, ScanFailure)
        If PreferLexical Then
            TryCheckSourcePath = TryPrintSourceScanFailure(LexicalFailure)
            Exit Function
        End If
    End If
    If EnvelopeAccepted = False Then
        TryCheckSourcePath = TryPrintSourceScanFailure(ScanFailure)
        Exit Function
    End If
    FallbackCode = 1210
    Work.Failure.Kind = 5
    If ScanCore Then
        If TryParseSyntax(Owner.Document, Work.Tokens, 3, 0, 1048576, 1048576, 256, Work.Syntax, Work.Failure, Work.Metrics) = False Then
            TryCheckSourcePath = TryPrintSourceSyntaxFailure(Owner.Document, Work.Failure)
            Exit Function
        End If
    Else
        If TryDeferredSyntaxEnvelope(Owner.Document, Envelope, Work.Failure) = False Then
            Work.Failure.Kind = 5
        End If
        TryCheckSourcePath = TryPrintSourceSyntaxFailure(Owner.Document, Work.Failure)
        Exit Function
    End If
    Work.State = 1
    FallbackCode = 1428
    Dim Limits As SemanticLimits
    Call DefaultSemanticLimits(Limits)
    Dim Cancellation As SourceCancellation = New SourceCancellation
    If Cancellation Is Nothing Then
        Exit Function
    End If
    Dim Checked As SemanticResult
    Dim SemanticFailure As SemanticFailure
    Call ResetSemanticFailure(SemanticFailure)
    If TryCheckSourceSemantics(Work, Envelope, 1, Limits, Cancellation, Checked, SemanticFailure) Then
        ExitCode = 0
    Else
        If TryPrintSourceSemanticFailure(Work, SemanticFailure) = False Then
            Exit Function
        End If
    End If
    TryCheckSourcePath = True
End Function
