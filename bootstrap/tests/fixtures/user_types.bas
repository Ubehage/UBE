Type Token
    Kind As Long
    Lexeme As String
End Type

Sub Initialize(ByRef Value As Token)
    Value.Kind = 7
    Value.Lexeme = "identifier"
End Sub

Sub AppendThird(ByRef Values() As Token)
    ReDim Preserve Values(2)
    Values(2).Kind = 13
    Values(2).Lexeme = "third"
End Sub

Sub Main()
    Dim Current As Token
    Call Initialize(Current)
    Print Current.Kind
    Print Current.Lexeme

    Dim Tokens() As Token
    ReDim Tokens(1)
    Tokens(0).Kind = 11
    Tokens(0).Lexeme = "first"
    Tokens(1).Kind = 12
    Tokens(1).Lexeme = "second"
    Call AppendThird(Tokens)
    Print Tokens(0).Kind
    Print Tokens(0).Lexeme
    Print Tokens(1).Kind
    Print Tokens(1).Lexeme
    Print Tokens(2).Kind
    Print Tokens(2).Lexeme
End Sub
