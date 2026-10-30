UBE SOURCE 1 MODULE
Attribute UBE_Name = "SyntaxOutput"

Sub WriteSyntaxDump(ByRef SyntaxNodes() As SyntaxNode, ByVal SyntaxNodeCount As Long, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken, ByVal GrammarRuleCount As Long)
    Print "UBE-SYNTAX 1 " & EmbeddedGrammarHash()
    Dim Index As Long = 0
    While Index < SyntaxNodeCount
        Dim RuleName As String = "<invalid>"
        If SyntaxNodes(Index).ProductionRule >= 0 And SyntaxNodes(Index).ProductionRule < GrammarRuleCount Then
            RuleName = Rules(SyntaxNodes(Index).ProductionRule).RuleName
        End If
        Dim StartByte As Long = 0
        Dim EndByte As Long = 0
        Dim LineNumber As Long = 1
        Dim ColumnNumber As Long = 1
        If SyntaxNodes(Index).FirstToken >= 0 Then
            StartByte = Tokens(SyntaxNodes(Index).FirstToken).StartByte
            LineNumber = Tokens(SyntaxNodes(Index).FirstToken).LineNumber
            ColumnNumber = Tokens(SyntaxNodes(Index).FirstToken).ColumnNumber
            EndByte = StartByte
        End If
        If SyntaxNodes(Index).LastToken >= SyntaxNodes(Index).FirstToken Then
            EndByte = Tokens(SyntaxNodes(Index).LastToken).StartByte + Tokens(SyntaxNodes(Index).LastToken).ByteLength
        End If
        Print LongToString(SyntaxNodes(Index).StableId) & "|" & LongToString(SyntaxNodes(Index).ParentNode + 1) & "|" & RuleName & "|" & LongToString(SyntaxNodes(Index).SourceId) & ":" & LongToString(StartByte) & ":" & LongToString(EndByte - StartByte) & ":" & LongToString(LineNumber) & ":" & LongToString(ColumnNumber) & "|" & LongToString(SyntaxNodes(Index).ChildCount)
        Index = Index + 1
    Wend
End Sub
