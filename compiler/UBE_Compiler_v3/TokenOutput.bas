UBE SOURCE 1 MODULE
Attribute UBE_Name = "TokenOutput"

Function TokenKindName(ByVal Kind As Long) As String
    If Kind = 1 Then
        TokenKindName = "keyword"
    Else
        If Kind = 2 Then
            TokenKindName = "identifier"
        Else
            If Kind = 3 Then
                TokenKindName = "bracket-identifier"
            Else
                If Kind = 4 Then
                    TokenKindName = "integer"
                Else
                    If Kind = 5 Then
                        TokenKindName = "real"
                    Else
                        If Kind = 6 Then
                            TokenKindName = "string"
                        Else
                            If Kind = 7 Then
                                TokenKindName = "date"
                            Else
                                If Kind = 8 Then
                                    TokenKindName = "punctuation"
                                Else
                                    If Kind = 9 Then
                                        TokenKindName = "newline"
                                    Else
                                        If Kind = 10 Then
                                            TokenKindName = "comment"
                                        Else
                                            If Kind = 11 Then
                                                TokenKindName = "spacing"
                                            Else
                                                If Kind = 12 Then
                                                    TokenKindName = "continuation"
                                                Else
                                                    TokenKindName = "eof"
                                                End If
                                            End If
                                        End If
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    End If
End Function

Function HexDigit(ByVal Value As Long) As String
    If Value < 10 Then
        HexDigit = StringFromByte(48 + Value)
    Else
        HexDigit = StringFromByte(55 + Value)
    End If
End Function

Function HexEncode(ByVal Value As String) As String
    Dim Result As String = ""
    Dim Index As Long = 0
    While Index < StringLength(Value)
        Dim CurrentByte As Long = StringByteAt(Value, Index)
        Result = Result & HexDigit(CurrentByte \ 16) & HexDigit(CurrentByte Mod 16)
        Index = Index + 1
    Wend
    HexEncode = Result
End Function

Sub WriteTokenDump(ByRef Tokens() As LexicalToken, ByVal TokenCount As Long)
    Print "UBE-TOKENS 1"
    Dim Index As Long = 0
    While Index < TokenCount
        Print LongToString(Tokens(Index).SourceId) & ":" & LongToString(Tokens(Index).StartByte) & ":" & LongToString(Tokens(Index).ByteLength) & ":" & LongToString(Tokens(Index).LineNumber) & ":" & LongToString(Tokens(Index).ColumnNumber) & "|" & TokenKindName(Tokens(Index).TokenKind) & "|" & HexEncode(Tokens(Index).Spelling) & "|" & HexEncode(Tokens(Index).Decoded)
        Index = Index + 1
    Wend
End Sub
