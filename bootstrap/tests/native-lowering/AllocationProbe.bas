UBE SOURCE 1 MODULE
Attribute UBE_Name = "LoweringAllocationProbe"
' Keeps validated source pools separate from one private emission stage for fault qualification.
Private Bytes() As Byte
Private Tokens() As SourceScanner.SourceToken
Private Nodes() As SourceParser.SyntaxNode
Private Modules() As ProjectSyntax.ParsedModule
Private Counts As ProjectSyntax.ProjectCounts
Private Catalog() As Byte
Private RuntimeText() As Byte
Private Package(0 To 0) As Byte
Private State As NativeEmission.EmissionState
Private Diagnostic As DeclarationBinder.BindingDiagnostic
Private StageToken As Long

' Prepares source and installation assets before the allocation observer is armed.
Public Function Prepare(ByRef Source() As Byte, ByRef TemplateBytes() As Byte, ByRef RuntimeBytes() As Byte) As Long
    Dim ProjectError As ProjectSyntax.ProjectDiagnostic
    On Error GoTo Failed
    Package(0) = 80
    If Not ProjectSyntax.TryAppendModule(Source, Bytes, Tokens, Nodes, Modules, Counts, ProjectError) Then Prepare = 1: Exit Function
    If Not BufferPrimitives.TryCopyBytes(Catalog, TemplateBytes) Then Prepare = 2: Exit Function
    If Not BufferPrimitives.TryCopyBytes(RuntimeText, RuntimeBytes) Then Prepare = 3: Exit Function
    Diagnostic.Code = 777
    Diagnostic.Reason = 888
    Diagnostic.Node = 999
    Diagnostic.ByteOffset = 999
    Diagnostic.Line = 999
    Diagnostic.Column = 999
    State.Work = 777
    Exit Function
Failed:
    Prepare = 4
End Function

' Opens a separate private stage; ownership stays in this probe until explicit close.
Public Function OpenStage(ByRef Path() As Byte) As Boolean
    Dim Failure As Long
    OpenStage = FilePrimitives.TryCreateNew(Path, StageToken, Failure)
End Function

' Closes the stage even after failed emission; no publication is performed.
Public Function CloseStage() As Boolean
    Dim Failure As Long
    CloseStage = FilePrimitives.TryClose(StageToken, Failure)
End Function

' Calls the complete public boundary, converting unexpected wrapper refusal into False.
Public Function Attempt() As Boolean
    On Error GoTo Failed
    Attempt = NativeLowering.TryEmit(Bytes, Tokens, Nodes, Modules, Counts, Package, False, Catalog, RuntimeText, StageToken, State, Diagnostic)
    Exit Function
Failed:
    State.Text.Failed = True
End Function

' Checks controlled failure and rejects a diagnostic inherited from an earlier request.
Public Function CheckRejected(ByVal ExpectedCode As Long) As Long
    If Not State.Text.Failed Then CheckRejected = 1: Exit Function
    If Diagnostic.Code = 0 Or Diagnostic.Code = 777 Then CheckRejected = 2: Exit Function
    If ExpectedCode <> 0 And Diagnostic.Code <> ExpectedCode Then CheckRejected = 3: Exit Function
    If Diagnostic.Line < 1 Or Diagnostic.Column < 1 Or Diagnostic.Utf16Offset < 1 Then CheckRejected = 4: Exit Function
    If Diagnostic.Node = 999 Or Diagnostic.ByteOffset = 999 Then CheckRejected = 5: Exit Function
End Function

' Exposes exact state for failure origin checks without relying on sticky Err as success.
Public Function Field(ByVal Index As Long) As Long
    If Index = 0 Then Field = Diagnostic.Code
    If Index = 1 Then Field = Diagnostic.Reason
    If Index = 2 Then Field = State.Text.FileFailure
    If Index = 3 Then Field = State.Text.ErrorNumber
    If Index = 4 Then Field = State.Text.Failure
    If Index = 5 Then Field = State.Work
End Function

' Introduces a single malformed public input while preserving every unrelated pool.
Public Sub Corrupt(ByVal Mode As Long)
    If Mode = 1 Then Tokens(0).ByteStart = -1
    If Mode = 2 Then Nodes(0).Parent = 1
    If Mode = 3 Then Catalog(0) = 0
    If Mode = 4 Then RuntimeText(0) = 0
    If Mode = 5 Then Counts.NodeCount = Counts.NodeCount + 1
End Sub
