UBE SOURCE 1 MODULE
Attribute UBE_Name = "ConditionalPreprocessor"

Type PreprocessedSource
    SourceId As Long
    ProcessedText As String
    ByteCount As Long
    MapSegmentCount As Long
    WorkUnits As LongLong
    Succeeded As Long
End Type

Function BlankCompilerLine(ByVal InputText As String) As String
    Dim Result As String = ""
    Dim Index As Long = 0
    While Index < CompilerTextLength(InputText)
        Dim Value As Long = CompilerTextByteAt(InputText, Index)
        If Value = 10 Or Value = 13 Then
            Result = Result & CompilerTextFromByte(Value)
        Else
            Result = Result & " "
        End If
        Index = Index + 1
    Wend
    BlankCompilerLine = Result
End Function

Function CompactConditionalText(ByVal InputText As String) As String
    Dim Result As String = ""
    Dim Index As Long = 0
    While Index < CompilerTextLength(InputText)
        Dim Value As Long = CompilerTextByteAt(InputText, Index)
        If Value = 39 Then
            While Index < CompilerTextLength(InputText) And CompilerTextByteAt(InputText, Index) <> 10
                Index = Index + 1
            Wend
        Else
            If Value <> 32 And Value <> 9 And Value <> 13 And Value <> 10 And Value <> 95 Then Result = Result & CompilerTextFromByte(Value)
            Index = Index + 1
        End If
    Wend
    CompactConditionalText = Result
End Function

Function ConditionalMatchesFoldedAt(ByVal InputText As String, ByVal StartByte As Long, ByVal Expected As String) As Long
    If StartByte < 0 Or StartByte + CompilerTextLength(Expected) > CompilerTextLength(InputText) Then ConditionalMatchesFoldedAt = 0: Exit Function
    Dim Candidate As String = ""
    Call CompilerTextSlice(InputText, StartByte, CompilerTextLength(Expected), Candidate)
    ConditionalMatchesFoldedAt = CompilerAsciiEqualsFolded(Candidate, Expected)
End Function

Function ConditionalNameValue(ByVal Constants As String, ByVal NameText As String, ByRef Found As Long) As Long
    Dim Needle As String = "|" & NameText & "="
    Dim Index As Long = 0
    While Index + CompilerTextLength(Needle) + 1 <= CompilerTextLength(Constants)
        If ConditionalMatchesFoldedAt(Constants, Index, Needle) <> 0 Then
            Found = 1
            If CompilerTextByteAt(Constants, Index + CompilerTextLength(Needle)) = 49 Then
                ConditionalNameValue = 1
            Else
                ConditionalNameValue = 0
            End If
            Exit Function
        End If
        Index = Index + 1
    Wend
    Found = 0
    ConditionalNameValue = 0
End Function

Function EvaluateConditionalAtom(ByVal Atom As String, ByVal Constants As String, ByRef Okay As Long) As Long
    Dim Negated As Long = 0
    While ConditionalMatchesFoldedAt(Atom, 0, "Not") <> 0
        Dim Remaining As String = ""
        Call CompilerTextSlice(Atom, 3, CompilerTextLength(Atom) - 3, Remaining)
        Atom = Remaining
        Negated = 1 - Negated
    Wend
    Dim AtomResult As Long = 0
    If CompilerAsciiEqualsFolded(Atom, "True") <> 0 Then
        AtomResult = 1: Okay = 1
    Else
        If CompilerAsciiEqualsFolded(Atom, "False") <> 0 Then
            AtomResult = 0: Okay = 1
        Else
            Dim Found As Long = 0
            AtomResult = ConditionalNameValue(Constants, Atom, Found)
            Okay = Found
        End If
    End If
    If Negated <> 0 Then AtomResult = 1 - AtomResult
    EvaluateConditionalAtom = AtomResult
End Function

' Evaluates the bounded Boolean subset required by the Task 4 preprocessing
' corpus: constants, True/False, Not, And/AndAlso, and Or/OrElse.
Function EvaluateConditionalExpression(ByVal Expression As String, ByVal Constants As String, ByRef Okay As Long) As Long
    Okay = 0
    Dim Cursor As Long = 0
    Dim CombinedOr As Long = 0
    While Cursor < CompilerTextLength(Expression)
        Dim OrEnd As Long = Cursor
        While OrEnd < CompilerTextLength(Expression) And ConditionalMatchesFoldedAt(Expression, OrEnd, "Or") = 0
            OrEnd = OrEnd + 1
        Wend
        Dim AndStart As Long = Cursor
        Dim CombinedAnd As Long = 1
        While AndStart < OrEnd
            Dim AndEnd As Long = AndStart
            While AndEnd < OrEnd And ConditionalMatchesFoldedAt(Expression, AndEnd, "And") = 0
                AndEnd = AndEnd + 1
            Wend
            Dim Atom As String = ""
            Call CompilerTextSlice(Expression, AndStart, AndEnd - AndStart, Atom)
            Dim AtomOkay As Long = 0
            Dim AtomValue As Long = EvaluateConditionalAtom(Atom, Constants, AtomOkay)
            If AtomOkay = 0 Then EvaluateConditionalExpression = 0: Exit Function
            If AtomValue = 0 Then CombinedAnd = 0
            If AndEnd < OrEnd Then
                If ConditionalMatchesFoldedAt(Expression, AndEnd, "AndAlso") <> 0 Then
                    AndStart = AndEnd + 7
                Else
                    AndStart = AndEnd + 3
                End If
            Else
                AndStart = OrEnd
            End If
        Wend
        If CombinedAnd <> 0 Then CombinedOr = 1
        If OrEnd < CompilerTextLength(Expression) Then
            If ConditionalMatchesFoldedAt(Expression, OrEnd, "OrElse") <> 0 Then
                Cursor = OrEnd + 6
            Else
                Cursor = OrEnd + 2
            End If
        Else
            Cursor = CompilerTextLength(Expression)
        End If
    Wend
    Okay = 1
    EvaluateConditionalExpression = CombinedOr
End Function

Function RunPreprocessorForSource(ByVal Session As BuildSession, ByRef Source As ImmutableSourceSnapshot, ByRef Result As PreprocessedSource, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Result.Succeeded = 0: Result.SourceId = Source.SourceId: Result.ProcessedText = ""
    Dim ParentActive() As Long
    Dim BranchTaken() As Long
    Dim CurrentActive() As Long
    Dim ElseSeen() As Long
    ReDim ParentActive(Session.MaximumConditionalDepth - 1): ReDim BranchTaken(Session.MaximumConditionalDepth - 1)
    ReDim CurrentActive(Session.MaximumConditionalDepth - 1): ReDim ElseSeen(Session.MaximumConditionalDepth - 1)
    Dim Depth As Long = 0
    Dim Active As Long = 1
    Dim Constants As String = ""
    Dim Cursor As Long = 0
    While Cursor < Source.ByteCount
        Dim GroupStart As Long = Cursor
        Dim GroupText As String = ""
        Dim ContinueGroup As Long = 1
        While ContinueGroup <> 0 And Cursor < Source.ByteCount
            Dim PhysicalLine As String = ""
            Dim PhysicalStart As Long = 0
            If ReadCompilerLine(Source.Contents, Cursor, PhysicalLine, PhysicalStart) = 0 Then
                ContinueGroup = 0
            Else
                Dim RawLength As Long = Cursor - PhysicalStart
                Dim RawLine As String = ""
                Call CompilerTextSlice(Source.Contents, PhysicalStart, RawLength, RawLine)
                GroupText = GroupText & RawLine
                Dim Probe As Long = CompilerTextLength(PhysicalLine) - 1
                While Probe >= 0 And (CompilerTextByteAt(PhysicalLine, Probe) = 32 Or CompilerTextByteAt(PhysicalLine, Probe) = 9)
                    Probe = Probe - 1
                Wend
                If Probe < 0 Or CompilerTextByteAt(PhysicalLine, Probe) <> 95 Then ContinueGroup = 0
            End If
        Wend
        Dim Compact As String = CompactConditionalText(GroupText)
        If CompilerTextMatchesAt(Compact, 0, "#") = 0 Then
            If Active <> 0 Then
                Result.ProcessedText = Result.ProcessedText & GroupText
            Else
                Result.ProcessedText = Result.ProcessedText & BlankCompilerLine(GroupText)
            End If
        Else
            Dim Handled As Long = 0
            If ConditionalMatchesFoldedAt(Compact, 0, "#Const") <> 0 Then
                Handled = 1
                If Active <> 0 Then
                    Dim EqualOffset As Long = 6
                    While EqualOffset < CompilerTextLength(Compact) And CompilerTextByteAt(Compact, EqualOffset) <> 61
                        EqualOffset = EqualOffset + 1
                    Wend
                    Dim ConstantName As String = ""
                    Dim ConstantValue As String = ""
                    If EqualOffset > 6 And EqualOffset < CompilerTextLength(Compact) - 1 Then
                        Call CompilerTextSlice(Compact, 6, EqualOffset - 6, ConstantName)
                        Call CompilerTextSlice(Compact, EqualOffset + 1, CompilerTextLength(Compact) - EqualOffset - 1, ConstantValue)
                    End If
                    Dim ValueOkay As Long = 0
                    Dim BooleanValue As Long = EvaluateConditionalAtom(ConstantValue, Constants, ValueOkay)
                    Dim Existing As Long = 0
                    Call ConditionalNameValue(Constants, ConstantName, Existing)
                    If ConstantName = "" Or ValueOkay = 0 Or Existing <> 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3501", Source.FilePath, "malformed or duplicate #Const directive"): RunPreprocessorForSource = 0: Exit Function
                    Constants = Constants & "|" & ConstantName & "=" & CompilerLongToText(BooleanValue) & "|"
                End If
            End If
            If ConditionalMatchesFoldedAt(Compact, 0, "#If") <> 0 Then
                Handled = 1
                If Depth >= Session.MaximumConditionalDepth Or CompilerTextLength(Compact) < 7 Or ConditionalMatchesFoldedAt(Compact, CompilerTextLength(Compact) - 4, "Then") = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3504", Source.FilePath, "malformed #If condition"): RunPreprocessorForSource = 0: Exit Function
                Dim Expression As String = ""
                Call CompilerTextSlice(Compact, 3, CompilerTextLength(Compact) - 7, Expression)
                Dim ConditionOkay As Long = 0
                Dim ConditionValue As Long = 0
                If Active <> 0 Then
                    ConditionValue = EvaluateConditionalExpression(Expression, Constants, ConditionOkay)
                Else
                    ConditionOkay = 1
                End If
                If ConditionOkay = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3504", Source.FilePath, "malformed #If condition"): RunPreprocessorForSource = 0: Exit Function
                ParentActive(Depth) = Active: CurrentActive(Depth) = 0
                If Active <> 0 And ConditionValue <> 0 Then CurrentActive(Depth) = 1
                BranchTaken(Depth) = CurrentActive(Depth): ElseSeen(Depth) = 0: Active = CurrentActive(Depth): Depth = Depth + 1
            End If
            If ConditionalMatchesFoldedAt(Compact, 0, "#ElseIf") <> 0 Then
                Handled = 1
                If Depth = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3506", Source.FilePath, "#ElseIf has no matching open #If"): RunPreprocessorForSource = 0: Exit Function
                If ElseSeen(Depth - 1) <> 0 Or CompilerTextLength(Compact) < 11 Or ConditionalMatchesFoldedAt(Compact, CompilerTextLength(Compact) - 4, "Then") = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3506", Source.FilePath, "malformed #ElseIf condition"): RunPreprocessorForSource = 0: Exit Function
                Dim ElseIfExpression As String = ""
                Call CompilerTextSlice(Compact, 7, CompilerTextLength(Compact) - 11, ElseIfExpression)
                Dim ElseIfOkay As Long = 1
                Dim ElseIfValue As Long = 0
                If ParentActive(Depth - 1) <> 0 And BranchTaken(Depth - 1) = 0 Then ElseIfValue = EvaluateConditionalExpression(ElseIfExpression, Constants, ElseIfOkay)
                If ElseIfOkay = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3506", Source.FilePath, "malformed #ElseIf condition"): RunPreprocessorForSource = 0: Exit Function
                CurrentActive(Depth - 1) = 0
                If ParentActive(Depth - 1) <> 0 And BranchTaken(Depth - 1) = 0 And ElseIfValue <> 0 Then CurrentActive(Depth - 1) = 1: BranchTaken(Depth - 1) = 1
                Active = CurrentActive(Depth - 1)
            End If
            If CompilerAsciiEqualsFolded(Compact, "#Else") <> 0 Then
                Handled = 1
                If Depth = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3507", Source.FilePath, "#Else has no matching open #If"): RunPreprocessorForSource = 0: Exit Function
                If ElseSeen(Depth - 1) <> 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3507", Source.FilePath, "duplicate #Else directive"): RunPreprocessorForSource = 0: Exit Function
                ElseSeen(Depth - 1) = 1: CurrentActive(Depth - 1) = 0
                If ParentActive(Depth - 1) <> 0 And BranchTaken(Depth - 1) = 0 Then CurrentActive(Depth - 1) = 1: BranchTaken(Depth - 1) = 1
                Active = CurrentActive(Depth - 1)
            End If
            If CompilerAsciiEqualsFolded(Compact, "#EndIf") <> 0 Then
                Handled = 1
                If Depth = 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3508", Source.FilePath, "#End If has no matching open #If"): RunPreprocessorForSource = 0: Exit Function
                Depth = Depth - 1: Active = ParentActive(Depth)
            End If
            If Handled = 0 And Active <> 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3509", Source.FilePath, "unknown conditional-compilation directive"): RunPreprocessorForSource = 0: Exit Function
            Result.ProcessedText = Result.ProcessedText & BlankCompilerLine(GroupText)
        End If
    Wend
    If Depth <> 0 Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3510", Source.FilePath, "unterminated #If directive"): RunPreprocessorForSource = 0: Exit Function
    Result.ByteCount = CompilerTextLength(Result.ProcessedText): Result.MapSegmentCount = 1: Result.WorkUnits = Source.ByteCount: Result.Succeeded = 1
    If Result.ByteCount <> Source.ByteCount Then Call AddCompilerDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Session.MaximumDiagnostics, "UBE3513", Source.FilePath, "preprocessor source map lost byte identity"): RunPreprocessorForSource = 0: Exit Function
    RunPreprocessorForSource = 1
End Function
