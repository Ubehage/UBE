UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticOutput"

Sub WriteSemanticDump(ByRef State As SemanticState, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByRef Scopes() As SemanticScope, ByVal ScopeCount As Long, ByRef Symbols() As SemanticSymbol, ByVal SymbolCount As Long)
    Print "UBE-SEMANTICS 1"
    Print "summary|types=" & LongToString(TypeCount) & "|scopes=" & LongToString(ScopeCount) & "|symbols=" & LongToString(SymbolCount) & "|entries=" & LongToString(State.EntryCount) & "|expressions=" & LongToString(State.TypedExpressionCount) & "/" & LongToString(State.ExpressionCount)
    Dim Index As Long = 0
    While Index < SymbolCount
        Print "symbol|" & LongToString(Symbols(Index).StableId) & "|kind=" & LongToString(Symbols(Index).SymbolKind) & "|scope=" & LongToString(Symbols(Index).ScopeIndex + 1) & "|name=" & Symbols(Index).SymbolName & "|type=" & LongToString(Symbols(Index).DeclaredType)
        Index = Index + 1
    Wend
End Sub
