Attribute VB_Name = "SuffixHost"
Option Explicit
Private Declare Sub ExitProcess Lib "kernel32" (ByVal Code As Long)
' Exercises the production seed lexer without interpreting exponentiation in its limited backend.
Public Sub Main()
    Dim Source As SourceUnit, Tokens As TokenBuffer, Diagnostic As String
    On Error GoTo Failed
    Source.FilePath = "suffix.bas"
    Source.SourceText = "2^3 42&& &H2A&& 2& ""Save && Close"""
    If Not LexSource(Source, Tokens, Diagnostic) Then ExitProcess 1
    If Tokens.Count <> 9 Then ExitProcess 2
    If Tokens.Items(0).Kind <> "number" Or Tokens.Items(0).Text <> "2" Then ExitProcess 3
    If Tokens.Items(1).Kind <> "symbol" Or Tokens.Items(1).Text <> "^" Then ExitProcess 4
    If Tokens.Items(2).Kind <> "number" Or Tokens.Items(2).Text <> "3" Then ExitProcess 5
    If Tokens.Items(3).Kind <> "number" Or Tokens.Items(3).Text <> "42&&" Then ExitProcess 6
    If Tokens.Items(4).Kind <> "number" Or Tokens.Items(4).Text <> "&H2A&&" Then ExitProcess 7
    If Tokens.Items(5).Kind <> "number" Or Tokens.Items(5).Text <> "2&" Then ExitProcess 8
    If Tokens.Items(6).Kind <> "string" Or Tokens.Items(6).Text <> """Save && Close""" Then ExitProcess 9
    If Tokens.Items(7).Kind <> "newline" Or Tokens.Items(8).Kind <> "eof" Then ExitProcess 10
    ExitProcess 0
    Exit Sub
Failed:
    ExitProcess 99
End Sub
