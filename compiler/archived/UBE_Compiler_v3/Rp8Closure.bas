UBE SOURCE 1 MODULE
Attribute UBE_Name = "Rp8Closure"

Function IsRp8LegacyFileKeyword(ByVal Value As String) As Long
    If EqualsFolded(Value, "Open") <> 0 Or EqualsFolded(Value, "Close") <> 0 Or EqualsFolded(Value, "Input") <> 0 Or EqualsFolded(Value, "Get") <> 0 Or EqualsFolded(Value, "Put") <> 0 Or EqualsFolded(Value, "Seek") <> 0 Or EqualsFolded(Value, "Kill") <> 0 Or EqualsFolded(Value, "Name") <> 0 Or EqualsFolded(Value, "FileCopy") <> 0 Or EqualsFolded(Value, "ChDir") <> 0 Or EqualsFolded(Value, "ChDrive") <> 0 Or EqualsFolded(Value, "MkDir") <> 0 Or EqualsFolded(Value, "RmDir") <> 0 Or EqualsFolded(Value, "Lock") <> 0 Or EqualsFolded(Value, "Unlock") <> 0 Or EqualsFolded(Value, "Write") <> 0 Or EqualsFolded(Value, "Width") <> 0 Then
        IsRp8LegacyFileKeyword = 1
    Else
        IsRp8LegacyFileKeyword = 0
    End If
End Function

Function NextRp8SignificantToken(ByRef Tokens() As LexicalToken, ByVal TokenCount As Long, ByVal TokenIndex As Long) As Long
    Dim Result As Long = TokenIndex + 1
    While Result < TokenCount And (Tokens(Result).TokenKind = 10 Or Tokens(Result).TokenKind = 11 Or Tokens(Result).TokenKind = 12)
        Result = Result + 1
    Wend
    NextRp8SignificantToken = Result
End Function

' Reject reserved legacy file syntax before the general grammar explores its
' intentionally broad expression alternatives. This also bounds malformed
' compatibility input that would otherwise cause excessive parser work.
Sub ValidateRp8TokenSurface(ByRef Sources() As SourceDocument, ByRef Tokens() As LexicalToken, ByVal TokenCount As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    Dim AtLineStart As Long = 1
    Dim TokenIndex As Long = 0
    While TokenIndex < TokenCount
        If Tokens(TokenIndex).TokenKind = 9 Then
            AtLineStart = 1
        Else
            If Tokens(TokenIndex).TokenKind <> 10 And Tokens(TokenIndex).TokenKind <> 11 And Tokens(TokenIndex).TokenKind <> 12 Then
                If AtLineStart <> 0 Then
                    Dim Reject As Long = IsRp8LegacyFileKeyword(Tokens(TokenIndex).Spelling)
                    Dim RejectGraphics As Long = 0
                    Dim NextToken As Long = NextRp8SignificantToken(Tokens, TokenCount, TokenIndex)
                    If EqualsFolded(Tokens(TokenIndex).Spelling, "Line") <> 0 Then
                        If NextToken < TokenCount Then
                            If EqualsFolded(Tokens(NextToken).Spelling, "Input") <> 0 Then
                                Reject = 1
                            Else
                                RejectGraphics = 1
                            End If
                        Else
                            RejectGraphics = 1
                        End If
                    End If
                    If EqualsFolded(Tokens(TokenIndex).Spelling, "Circle") <> 0 Or EqualsFolded(Tokens(TokenIndex).Spelling, "PSet") <> 0 Or EqualsFolded(Tokens(TokenIndex).Spelling, "PaintPicture") <> 0 Then
                        RejectGraphics = 1
                    End If
                    If EqualsFolded(Tokens(TokenIndex).Spelling, "Print") <> 0 Then
                        If NextToken < TokenCount Then
                            If Tokens(NextToken).Spelling = "#" Then
                                Reject = 1
                            End If
                        End If
                    End If
                    If EqualsFolded(Tokens(TokenIndex).Spelling, "Date") <> 0 Or EqualsFolded(Tokens(TokenIndex).Spelling, "Time") <> 0 Then
                        If NextToken < TokenCount Then
                            If Tokens(NextToken).Spelling = "=" Then
                                Dim ClockPath As String = "<source>"
                                If Tokens(TokenIndex).SourceId > 0 Then
                                    ClockPath = Sources(Tokens(TokenIndex).SourceId - 1).FilePath
                                End If
                                Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE4055", ClockPath, Tokens(TokenIndex).LineNumber, Tokens(TokenIndex).ColumnNumber, "legacy host-clock assignment is not portable; use an explicit permission-aware platform API")
                            End If
                        End If
                    End If
                    If Reject <> 0 Then
                        Dim SourcePath As String = "<source>"
                        If Tokens(TokenIndex).SourceId > 0 Then
                            SourcePath = Sources(Tokens(TokenIndex).SourceId - 1).FilePath
                        End If
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE4054", SourcePath, Tokens(TokenIndex).LineNumber, Tokens(TokenIndex).ColumnNumber, "legacy file statements are reserved; use the explicit UBECore file API")
                    End If
                    If RejectGraphics <> 0 Then
                        Dim GraphicsPath As String = "<source>"
                        If Tokens(TokenIndex).SourceId > 0 Then
                            GraphicsPath = Sources(Tokens(TokenIndex).SourceId - 1).FilePath
                        End If
                        Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE4056", GraphicsPath, Tokens(TokenIndex).LineNumber, Tokens(TokenIndex).ColumnNumber, "classic graphics statements are reserved; use an explicitly linked graphics library")
                    End If
                End If
                AtLineStart = 0
            End If
        End If
        TokenIndex = TokenIndex + 1
    Wend
End Sub

' RP8 must never silently accept a frozen form that the backend cannot yet
' honor. These targeted diagnostics are part of the release contract and keep
' unsupported compatibility work distinct from malformed syntax.
Sub ValidateRp8Closure(ByRef Sources() As SourceDocument, ByRef SyntaxNodes() As SyntaxNode, ByVal SyntaxNodeCount As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef Rules() As GrammarRule, ByRef Tokens() As LexicalToken, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    Dim NodeIndex As Long = 0
    While NodeIndex < SyntaxNodeCount
        Dim RuleName As String = Rules(SyntaxNodes(NodeIndex).ProductionRule).RuleName
        If EqualsFolded(RuleName, "address-of-expression") <> 0 Then
            Call AddSemanticDiagnostic("UBE4050", NodeIndex, "AddressOf native callback thunks are reserved but not supported by this RP8 target adapter", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
        If EqualsFolded(RuleName, "variable-hook") <> 0 Then
            Call AddSemanticDiagnostic("UBE4051", NodeIndex, "variable Get/Set hooks are reserved but not supported by the RP8 lowering pipeline", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
        If EqualsFolded(RuleName, "sub-function-declaration") <> 0 Or EqualsFolded(RuleName, "property-declaration") <> 0 Then
            If SyntaxNodeContainsToken(NodeIndex, "ForceInline", SyntaxNodes, Tokens) <> 0 Then
                Call AddSemanticDiagnostic("UBE4052", NodeIndex, "ForceInline is reserved until hygienic mandatory expansion can be proven", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        If EqualsFolded(RuleName, "external-declaration") <> 0 Then
            Call AddSemanticDiagnostic("UBE4053", NodeIndex, "foreign Declare imports are reserved; use a generated UBE library ABI until native import lowering is available", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
        If EqualsFolded(RuleName, "io-statement") <> 0 Then
            Dim PlainPrint As Long = FirstDescendantSyntaxNode(NodeIndex, "print-statement", SyntaxNodes, SyntaxLinks, Rules, 0)
            If PlainPrint < 0 Or SyntaxNodeContainsToken(NodeIndex, "#", SyntaxNodes, Tokens) <> 0 Then
                Call AddSemanticDiagnostic("UBE4054", NodeIndex, "legacy file statements are reserved; use the explicit UBECore file API", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        If EqualsFolded(RuleName, "assignment-statement") <> 0 Then
            Dim AssignmentHead As String = Tokens(SyntaxNodes(NodeIndex).FirstToken).Spelling
            If EqualsFolded(AssignmentHead, "Date") <> 0 Or EqualsFolded(AssignmentHead, "Time") <> 0 Then
                Call AddSemanticDiagnostic("UBE4055", NodeIndex, "legacy host-clock assignment is not portable; use an explicit permission-aware platform API", Sources, SyntaxNodes, Tokens, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            End If
        End If
        NodeIndex = NodeIndex + 1
    Wend
End Sub
