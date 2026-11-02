UBE SOURCE 1 CLASS
Attribute UBE_Name = "SemanticModuleResult"
' Complete immutable per-source result; Catalog retains every original owner.
Public Catalog As SemanticCatalog
Public SourceId As Long
Public Facts() As SemanticFact
Public FactCount As Long
Public Values() As BoundNode
Public ValueCount As Long
Public Root As Long
Public Metrics As SemanticMetrics
