Attribute VB_Name = "SourceLexer"
Option Explicit

' Scans bounded source tokens with physical UTF-16 spans and logical line joining.
Public Const MaximumSourceTokens As Long = 65536
Public Const MaximumTokenCharacters As Long = 4096

Public Type SourceToken
    Kind As String
    Text As String
    Line As Long
    Column As Long
    Offset As Long
    Length As Long
End Type

Public Type TokenBuffer
    Items() As SourceToken
    Count As Long
End Type

' Reports the first lexical failure with its physical source position.
Private Function LexError(ByRef Source As SourceUnit, ByRef Diagnostic As String, ByVal Code As String, ByVal Detail As String, ByVal Line As Long, ByVal Column As Long) As Boolean
    LexError = Reject(Diagnostic, Code, Source.FilePath & ":" & CStr(Line) & ":" & CStr(Column) & " " & Detail)
End Function

' Recognizes the explicitly admitted ASCII bare-identifier character set.
Private Function NameStart(ByVal Character As String) As Boolean
    If Len(Character) <> 1 Then Exit Function
    NameStart = (Character >= "A" And Character <= "Z") Or (Character >= "a" And Character <= "z") Or Character = "_"
End Function

' Recognizes one decimal digit without accepting the empty end-of-input sentinel.
Private Function Digit(ByVal Character As String) As Boolean
    If Len(Character) <> 1 Then Exit Function
    Digit = Character >= "0" And Character <= "9"
End Function

' Decodes bracket escaping while preserving bare identifier spelling.
Public Function TokenIdentifier(ByRef Token As SourceToken) As String
    If Token.Kind = "identifier" Then
        TokenIdentifier = Replace(Mid$(Token.Text, 2, Len(Token.Text) - 2), "]]", "]")
    Else
        TokenIdentifier = Token.Text
    End If
End Function

' Appends only after checking bounds; capacity grows geometrically to a fixed ceiling.
Private Function AddToken(ByRef Source As SourceUnit, ByRef Buffer As TokenBuffer, ByVal Kind As String, ByVal Start As Long, ByVal Length As Long, ByVal Line As Long, ByVal Column As Long, ByRef Diagnostic As String, ByVal TokenLimit As Long) As Boolean
    Dim Capacity As Long
    If Buffer.Count >= TokenLimit Then
        AddToken = LexError(Source, Diagnostic, "E_LIMIT", "source token count exceeded", Line, Column)
        Exit Function
    End If
    If Length > MaximumTokenCharacters Then
        AddToken = LexError(Source, Diagnostic, "E_LIMIT", "token length exceeded", Line, Column)
        Exit Function
    End If
    Capacity = UBound(Buffer.Items) + 1
    If Buffer.Count = Capacity Then
        Capacity = Capacity * 2
        If Capacity > TokenLimit Then Capacity = TokenLimit
        ReDim Preserve Buffer.Items(0 To Capacity - 1)
    End If
    With Buffer.Items(Buffer.Count)
        .Kind = Kind
        .Text = Mid$(Source.SourceText, Start, Length)
        .Line = Line
        .Column = Column
        .Offset = Start
        .Length = Length
    End With
    Buffer.Count = Buffer.Count + 1
    AddToken = True
End Function

' Tests Rem's required following whitespace/newline boundary (including inserted EOF newline).
Private Function RemComment(ByRef Text As String, ByVal Position As Long) As Boolean
    Dim Following As String
    If FoldAscii(Mid$(Text, Position, 3)) <> "rem" Then Exit Function
    Following = Mid$(Text, Position + 3, 1)
    RemComment = Following = "" Or Following = " " Or Following = vbTab Or Following = vbCr Or Following = vbLf
End Function

' Scans the complete native file; the parser consumes its envelope and admits syntax.
Public Function LexSource(ByRef Source As SourceUnit, ByRef Buffer As TokenBuffer, ByRef Diagnostic As String, Optional ByVal TokenLimit As Long = 65536) As Boolean
    Dim Position As Long, Start As Long, Column As Long, Line As Long
    Dim StartColumn As Long, StartLine As Long, Finish As Long, Depth As Long
    Dim Character As String, Following As String, Kind As String, Word As String
    Dim StatementStart As Boolean, Closed As Boolean
    Dim RealNumber As Boolean, Radix As Long, DigitsStart As Long, Code As Long
    Dim DecodedLength As Long, Index As Long
    Dim NumericLabel As Boolean, MemberWord As Boolean
    On Error GoTo Unexpected
    Buffer.Count = 0
    Diagnostic = ""
    If Len(Source.SourceText) > MaximumSourceBytes Then
        LexSource = LexError(Source, Diagnostic, "E_LIMIT", "source character count exceeded", 1, 1)
        Exit Function
    End If
    If TokenLimit < 2 Or TokenLimit > MaximumSourceTokens Then
        LexSource = LexError(Source, Diagnostic, "E_LIMIT", "source token budget exhausted or invalid", 1, 1)
        Exit Function
    End If
    If TokenLimit < 256 Then ReDim Buffer.Items(0 To TokenLimit - 1) Else ReDim Buffer.Items(0 To 255)
    Position = 1: Column = 1: Line = 1: StatementStart = True
    Do While Position <= Len(Source.SourceText)
        Character = Mid$(Source.SourceText, Position, 1)
        Start = Position: StartLine = Line: StartColumn = Column
        If Character = " " Or Character = vbTab Then
            Position = Position + 1: Column = Column + 1
        ElseIf Character = vbCr Or Character = vbLf Then
            Finish = Position + 1
            If Character = vbCr Then
                If Mid$(Source.SourceText, Finish, 1) <> vbLf Then
                    LexSource = LexError(Source, Diagnostic, "E_LEXICAL", "lone carriage return", Line, Column): Exit Function
                End If
                Finish = Finish + 1
            End If
            If Not AddToken(Source, Buffer, "newline", Position, Finish - Position, Line, Column, Diagnostic, TokenLimit) Then Exit Function
            Position = Finish: Line = Line + 1: Column = 1: StatementStart = True
        ElseIf Character = "'" Or (StatementStart And RemComment(Source.SourceText, Position)) Then
            Do While Position <= Len(Source.SourceText)
                Character = Mid$(Source.SourceText, Position, 1)
                If Character = vbCr Or Character = vbLf Then Exit Do
                Position = Position + 1: Column = Column + 1
            Loop
        Else
            ' A continuation removes exactly its physical newline, preserving subsequent spans.
            If Character = "_" And Position > 1 Then
                Following = Mid$(Source.SourceText, Position - 1, 1)
                If Following = " " Or Following = vbTab Then
                    Finish = Position + 1
                    Do While Mid$(Source.SourceText, Finish, 1) = " " Or Mid$(Source.SourceText, Finish, 1) = vbTab
                        Finish = Finish + 1
                    Loop
                    If Mid$(Source.SourceText, Finish, 1) = "'" Or RemComment(Source.SourceText, Finish) Then
                        Do While Finish <= Len(Source.SourceText)
                            Following = Mid$(Source.SourceText, Finish, 1)
                            If Following = vbCr Or Following = vbLf Then Exit Do
                            Finish = Finish + 1
                        Loop
                    End If
                    Following = Mid$(Source.SourceText, Finish, 1)
                    If Following = vbCr Or Following = vbLf Or Following = "" Then
                        If Following = "" Then
                            LexSource = LexError(Source, Diagnostic, "E_LEXICAL", "continuation has no following line", Line, Column): Exit Function
                        End If
                        If Following = vbCr Then
                            Finish = Finish + 1
                            If Mid$(Source.SourceText, Finish, 1) <> vbLf Then
                                LexSource = LexError(Source, Diagnostic, "E_LEXICAL", "lone carriage return", Line, Column): Exit Function
                            End If
                        End If
                        Position = Finish + 1: Line = Line + 1: Column = 1
                        GoTo NextCharacter
                    End If
                End If
            End If
            Kind = "symbol"
            If Character = Chr$(34) Or Character = "[" Then
                If Character = "[" Then Kind = "identifier": Following = "]" Else Kind = "string": Following = Chr$(34)
                Position = Position + 1: Closed = False: DecodedLength = 0
                Do While Position <= Len(Source.SourceText)
                    Character = Mid$(Source.SourceText, Position, 1)
                    If Character = vbCr Or Character = vbLf Then Exit Do
                    If Character = Following Then
                        Position = Position + 1
                        If Mid$(Source.SourceText, Position, 1) <> Following Then Closed = True: Exit Do
                    End If
                    If Kind = "identifier" Then
                        Code = AscW(Character) And &HFFFF&
                        If Code < 32 Or Code > 126 Then
                            LexSource = LexError(Source, Diagnostic, "E_UNSUPPORTED", "non-ASCII bracketed identifier", Line, Column): Exit Function
                        End If
                    End If
                    DecodedLength = DecodedLength + 1
                    Position = Position + 1
                    If Position - Start > MaximumTokenCharacters Then
                        LexSource = LexError(Source, Diagnostic, "E_LIMIT", "token length exceeded", Line, Column): Exit Function
                    End If
                Loop
                If Not Closed Then
                    LexSource = LexError(Source, Diagnostic, "E_LEXICAL", "unterminated or excessive quoted token", Line, Column): Exit Function
                End If
                If Kind = "identifier" Then
                    If DecodedLength = 0 Or DecodedLength > MaximumIdentifierCharacters Then
                        LexSource = LexError(Source, Diagnostic, "E_LIMIT", "bracketed identifier length must be 1 to 128", Line, Column): Exit Function
                    End If
                End If
            ElseIf NameStart(Character) Then
                Kind = "name"
                Do
                    Position = Position + 1
                    Character = Mid$(Source.SourceText, Position, 1)
                Loop While NameStart(Character) Or Digit(Character)
                If Position - Start > MaximumIdentifierCharacters Then
                    LexSource = LexError(Source, Diagnostic, "E_LIMIT", "identifier length exceeded", Line, Column): Exit Function
                End If
                If StatementStart And FoldAscii(Mid$(Source.SourceText, Start, Position - Start)) = "asm" Then
                    LexSource = LexError(Source, Diagnostic, "E_UNSUPPORTED", "inline assembly is outside the scalar profile", Line, Column): Exit Function
                End If
            ElseIf Digit(Character) Or (Character = "." And Digit(Mid$(Source.SourceText, Position + 1, 1))) Or (Character = "&" And (FoldAscii(Mid$(Source.SourceText, Position + 1, 1)) = "h" Or FoldAscii(Mid$(Source.SourceText, Position + 1, 1)) = "o")) Then
                Kind = "number": RealNumber = False: Radix = 10
                If Character = "&" Then
                    If FoldAscii(Mid$(Source.SourceText, Position + 1, 1)) = "h" Then Radix = 16 Else Radix = 8
                    Position = Position + 2
                End If
                DigitsStart = Position
                Do While Position <= Len(Source.SourceText)
                    Character = FoldAscii(Mid$(Source.SourceText, Position, 1))
                    If Radix = 16 Then
                        If Not Digit(Character) And Not (Character >= "a" And Character <= "f") Then Exit Do
                    ElseIf Radix = 8 Then
                        If Character < "0" Or Character > "7" Then Exit Do
                    Else
                        If Not Digit(Character) Then Exit Do
                    End If
                    Position = Position + 1
                Loop
                If Radix <> 10 And Position = DigitsStart Then
                    LexSource = LexError(Source, Diagnostic, "E_LEXICAL", "based integer requires digits", Line, Column): Exit Function
                End If
                If Radix = 10 Then
                    If Mid$(Source.SourceText, Position, 1) = "." Then
                        RealNumber = True: Position = Position + 1
                        Do While Digit(Mid$(Source.SourceText, Position, 1)): Position = Position + 1: Loop
                    End If
                    If FoldAscii(Mid$(Source.SourceText, Position, 1)) = "e" Then
                        RealNumber = True: Position = Position + 1
                        Character = Mid$(Source.SourceText, Position, 1)
                        If Character = "+" Or Character = "-" Then Position = Position + 1
                        DigitsStart = Position
                        Do While Digit(Mid$(Source.SourceText, Position, 1)): Position = Position + 1: Loop
                        If Position = DigitsStart Then
                            LexSource = LexError(Source, Diagnostic, "E_LEXICAL", "exponent requires digits", Line, Column): Exit Function
                        End If
                    End If
                End If
                Character = FoldAscii(Mid$(Source.SourceText, Position, 1))
                If Len(Character) > 0 Then
                    If InStr("%&^", Character) > 0 And Not RealNumber Then
                        Position = Position + 1
                    ElseIf InStr("!#@frd", Character) > 0 And Radix = 10 Then
                        Position = Position + 1
                    End If
                End If
                Character = Mid$(Source.SourceText, Position, 1)
                If NameStart(Character) Or Digit(Character) Then
                    LexSource = LexError(Source, Diagnostic, "E_LEXICAL", "invalid numeric literal boundary", Line, Column): Exit Function
                End If
            Else
                Code = AscW(Character) And &HFFFF&
                If Code > 127 Or Character = "#" Then
                    LexSource = LexError(Source, Diagnostic, "E_UNSUPPORTED", "character or literal outside scalar source profile", Line, Column): Exit Function
                End If
                If InStr("()+-*/\\^&=<>.,:;%!@$", Character) = 0 Then
                    LexSource = LexError(Source, Diagnostic, "E_LEXICAL", "invalid source character", Line, Column): Exit Function
                End If
                Position = Position + 1
                Word = Mid$(Source.SourceText, Start, 2)
                If Word = "<=" Or Word = ">=" Or Word = "<>" Or Word = ":=" Then Position = Position + 1
            End If
            If Not AddToken(Source, Buffer, Kind, Start, Position - Start, StartLine, StartColumn, Diagnostic, TokenLimit) Then Exit Function
            Word = FoldAscii(Buffer.Items(Buffer.Count - 1).Text)
            MemberWord = False
            If Buffer.Count > 1 Then
                Following = Buffer.Items(Buffer.Count - 2).Text
                MemberWord = Following = "." Or Following = "!"
            End If
            NumericLabel = StatementStart And Kind = "number" And Depth = 0
            If NumericLabel Then
                For Index = 1 To Len(Word)
                    If Not Digit(Mid$(Word, Index, 1)) Then NumericLabel = False: Exit For
                Next Index
            End If
            If Kind = "symbol" Then
                If Word = "(" Then Depth = Depth + 1
                If Word = ")" Then Depth = Depth - 1
            End If
            StatementStart = NumericLabel Or (Word = ":" And Depth = 0) Or (Kind = "name" And Not MemberWord And (Word = "then" Or Word = "else"))
            Column = Column + Position - Start
        End If
NextCharacter:
    Loop
    If Buffer.Count > 0 Then
        If Buffer.Items(Buffer.Count - 1).Kind <> "newline" Then
            If Not AddToken(Source, Buffer, "newline", Position, 0, Line, Column, Diagnostic, TokenLimit) Then Exit Function
        End If
    Else
        If Not AddToken(Source, Buffer, "newline", Position, 0, Line, Column, Diagnostic, TokenLimit) Then Exit Function
    End If
    If Not AddToken(Source, Buffer, "eof", Position, 0, Line, Column, Diagnostic, TokenLimit) Then Exit Function
    LexSource = True
    Exit Function
Unexpected:
    On Error Resume Next
    LexSource = LexError(Source, Diagnostic, "E_INTERNAL", "unable to tokenize source", Line, Column)
End Function
