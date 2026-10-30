UBE SOURCE 1 MODULE
Attribute UBE_Name = "Session"

Type CompilerLimits
    MaximumDiagnostics As Long
    MaximumManifestBytes As Long
    MaximumManifestLines As Long
    MaximumProjectSources As Long
    MaximumProjectResources As Long
    MaximumProjectReferences As Long
    MaximumSourceBytes As LongLong
    MaximumCombinedSourceBytes As LongLong
    MaximumCombinedResourceBytes As LongLong
    MaximumTokens As Long
    MaximumParenthesisDepth As Long
    MaximumConditionalDepth As Long
    MaximumGrammarProductions As Long
    MaximumGeneratedGrammarRecords As Long
    MaximumSyntaxNodes As Long
    SyntaxNodeBaseBudget As Long
    SyntaxNodesPerToken As Long
    MaximumScopes As Long
    MaximumDeclarations As Long
    MaximumTypes As Long
    MaximumTraversalDepth As Long
    MaximumArgumentBytes As Long
    MaximumCapturedStdoutBytes As Long
    MaximumCapturedStderrBytes As Long
    MaximumArtifactBytes As LongLong
    WorkerCount As Long
End Type

Type CompilerConfiguration
    ProjectPath As String
    TargetTriple As String
    OutputPath As String
    FaultSite As String
    PublishRecord As Long
End Type

Type BuildSession
    SessionId As Long
    ProjectPath As String
    TargetTriple As String
    OutputPath As String
    FaultSite As String
    PublishRecord As Long
    MaximumDiagnostics As Long
    MaximumManifestBytes As Long
    MaximumManifestLines As Long
    MaximumProjectSources As Long
    MaximumProjectResources As Long
    MaximumProjectReferences As Long
    MaximumSourceBytes As LongLong
    MaximumCombinedSourceBytes As LongLong
    MaximumCombinedResourceBytes As LongLong
    MaximumTokens As Long
    MaximumParenthesisDepth As Long
    MaximumConditionalDepth As Long
    MaximumGrammarProductions As Long
    MaximumGeneratedGrammarRecords As Long
    MaximumSyntaxNodes As Long
    SyntaxNodeBaseBudget As Long
    SyntaxNodesPerToken As Long
    MaximumScopes As Long
    MaximumDeclarations As Long
    MaximumTypes As Long
    MaximumTraversalDepth As Long
    MaximumArgumentBytes As Long
    MaximumCapturedStdoutBytes As Long
    MaximumCapturedStderrBytes As Long
    MaximumArtifactBytes As LongLong
    WorkerCount As Long
    Sealed As Long
End Type

' Produces the frozen Task 2 limits. Callers do not mutate the returned record.
Sub InitializeCompilerLimits(ByRef Result As CompilerLimits)
    Result.MaximumDiagnostics = 100
    Result.MaximumManifestBytes = 1048576
    Result.MaximumManifestLines = 100000
    Result.MaximumProjectSources = 1024
    Result.MaximumProjectResources = 1024
    Result.MaximumProjectReferences = 256
    Result.MaximumSourceBytes = 16777216
    Result.MaximumCombinedSourceBytes = 67108864
    Result.MaximumCombinedResourceBytes = 67108864
    Result.MaximumTokens = 300000
    Result.MaximumParenthesisDepth = 10
    Result.MaximumConditionalDepth = 256
    Result.MaximumGrammarProductions = 512
    Result.MaximumGeneratedGrammarRecords = 16384
    Result.MaximumSyntaxNodes = 1250000
    Result.SyntaxNodeBaseBudget = 4096
    Result.SyntaxNodesPerToken = 2
    Result.MaximumScopes = 100000
    Result.MaximumDeclarations = 250000
    Result.MaximumTypes = 65536
    Result.MaximumTraversalDepth = 512
    Result.MaximumArgumentBytes = 4096
    Result.MaximumCapturedStdoutBytes = 16777216
    Result.MaximumCapturedStderrBytes = 16777216
    Result.MaximumArtifactBytes = 268435456
    Result.WorkerCount = 1
End Sub

' Creates the immutable session envelope used by every Task 2 phase. The
' returned record is complete when Sealed is 1 and is thereafter read-only.
Function CreateBuildSession(ByRef Configuration As CompilerConfiguration, ByRef Limits As CompilerLimits, ByRef Result As BuildSession) As Long
    Result.SessionId = 0
    Result.Sealed = 0
    If Configuration.ProjectPath = "" Or Configuration.TargetTriple = "" Then
        CreateBuildSession = 0
        Exit Function
    End If
    Result.SessionId = 1
    Result.ProjectPath = Configuration.ProjectPath
    Result.TargetTriple = Configuration.TargetTriple
    Result.OutputPath = Configuration.OutputPath
    Result.FaultSite = Configuration.FaultSite
    Result.PublishRecord = Configuration.PublishRecord
    Result.MaximumDiagnostics = Limits.MaximumDiagnostics
    Result.MaximumManifestBytes = Limits.MaximumManifestBytes
    Result.MaximumManifestLines = Limits.MaximumManifestLines
    Result.MaximumProjectSources = Limits.MaximumProjectSources
    Result.MaximumProjectResources = Limits.MaximumProjectResources
    Result.MaximumProjectReferences = Limits.MaximumProjectReferences
    Result.MaximumSourceBytes = Limits.MaximumSourceBytes
    Result.MaximumCombinedSourceBytes = Limits.MaximumCombinedSourceBytes
    Result.MaximumCombinedResourceBytes = Limits.MaximumCombinedResourceBytes
    Result.MaximumTokens = Limits.MaximumTokens
    Result.MaximumParenthesisDepth = Limits.MaximumParenthesisDepth
    Result.MaximumConditionalDepth = Limits.MaximumConditionalDepth
    Result.MaximumGrammarProductions = Limits.MaximumGrammarProductions
    Result.MaximumGeneratedGrammarRecords = Limits.MaximumGeneratedGrammarRecords
    Result.MaximumSyntaxNodes = Limits.MaximumSyntaxNodes
    Result.SyntaxNodeBaseBudget = Limits.SyntaxNodeBaseBudget
    Result.SyntaxNodesPerToken = Limits.SyntaxNodesPerToken
    Result.MaximumScopes = Limits.MaximumScopes
    Result.MaximumDeclarations = Limits.MaximumDeclarations
    Result.MaximumTypes = Limits.MaximumTypes
    Result.MaximumTraversalDepth = Limits.MaximumTraversalDepth
    Result.MaximumArgumentBytes = Limits.MaximumArgumentBytes
    Result.MaximumCapturedStdoutBytes = Limits.MaximumCapturedStdoutBytes
    Result.MaximumCapturedStderrBytes = Limits.MaximumCapturedStderrBytes
    Result.MaximumArtifactBytes = Limits.MaximumArtifactBytes
    Result.WorkerCount = Limits.WorkerCount
    Result.Sealed = 1
    CreateBuildSession = 1
End Function
