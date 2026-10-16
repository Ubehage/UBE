UBE SOURCE 1 MODULE
Attribute UBE_Name = "Limits"

' RP2 keeps all resource ceilings in one module so later phases can share the
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
    LimitSyntaxDepth = 512
End Function

Function LimitGeneratedBytes() As Long
    LimitGeneratedBytes = 67108864
End Function

Function LimitTokenCount() As Long
    LimitTokenCount = 100000
End Function

Function LimitConditionalDepth() As Long
    LimitConditionalDepth = 256
End Function

Function LimitConditionalConstants() As Long
    LimitConditionalConstants = 4096
End Function
