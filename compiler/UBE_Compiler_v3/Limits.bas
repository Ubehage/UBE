UBE SOURCE 1 MODULE
Attribute UBE_Name = "Limits"

' RP3 keeps all resource ceilings in one module so later phases can share the
' same bounded behavior without scattering unexplained numeric limits.

Function LimitDiagnosticCount() As Long
    LimitDiagnosticCount = 100
End Function

Function LimitManifestBytes() As Long
    LimitManifestBytes = 1048576
End Function

Function LimitManifestLines() As Long
    LimitManifestLines = 100000
End Function

Function LimitProjectSources() As Long
    LimitProjectSources = 1024
End Function

Function LimitProjectResources() As Long
    LimitProjectResources = 1024
End Function

Function LimitProjectReferences() As Long
    LimitProjectReferences = 256
End Function

Function LimitSourceBytes() As Long
    LimitSourceBytes = 16777216
End Function

Function LimitCombinedSourceBytes() As Long
    LimitCombinedSourceBytes = 67108864
End Function

Function LimitSyntaxDepth() As Long
    LimitSyntaxDepth = 2048
End Function

Function LimitGeneratedBytes() As Long
    LimitGeneratedBytes = 67108864
End Function

Function LimitTokenCount() As Long
    ' Compiler-sized projects exceed the early-preview ceiling. Keep the
    ' limit explicit and bounded while allowing the RP7 self-build corpus.
    LimitTokenCount = 300000
End Function

Function LimitConditionalDepth() As Long
    LimitConditionalDepth = 256
End Function

Function LimitConditionalConstants() As Long
    LimitConditionalConstants = 4096
End Function

Function LimitGrammarRules() As Long
    LimitGrammarRules = 512
End Function

Function LimitGrammarNodes() As Long
    LimitGrammarNodes = 16384
End Function

Function LimitSyntaxNodes() As Long
    LimitSyntaxNodes = 1250000
End Function

Function LimitSemanticScopes() As Long
    LimitSemanticScopes = 100000
End Function

Function LimitSemanticSymbols() As Long
    LimitSemanticSymbols = 250000
End Function

Function LimitSemanticTypes() As Long
    LimitSemanticTypes = 65536
End Function

Function LimitSemanticDepth() As Long
    LimitSemanticDepth = 512
End Function
