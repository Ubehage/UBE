Attribute VB_Name = "NumericProbe"
Option Explicit
Private Sub Probe(ByVal Name As String, ByVal Text As String)
    Dim Number As Long
    Dim Truth As Boolean
    Dim Code As Long
    On Error Resume Next
    Err.Clear
    Number = CLng(Text)
    Code = Err.Number
    Print #1, Name & "|Long=" & CStr(Number) & "|Err=" & CStr(Code)
    Err.Clear
    Truth = CBool(Text)
    Code = Err.Number
    Print #1, Name & "|Boolean=" & CStr(Truth) & "|Err=" & CStr(Code)
End Sub
Public Sub Main()
    Dim Code As Variant
    Open App.Path & "\observations.txt" For Output As #1
    For Each Code In Array(9, 10, 11, 12, 13, 32, 133, 160, 5760, 8192, 8193, 8194, 8195, 8196, 8197, 8198, 8199, 8200, 8201, 8202, 8232, 8233, 8239, 8287, 12288, 65279)
        Probe "space" & CStr(Code), ChrW$(Code) & "1" & ChrW$(Code)
    Next
    For Each Code In Array("&H7FFF", "&H8000", "&HFFFF", "&HFFFFFFFF", "&H100000000", "&O177777", "&O37777777777", "-&H1", "+&H1", "&H-1", "&H1&", "&hffff", "True", "tRuE", " False ", "0.1", "1e-9999", "1e9999", "1.", ".5", "1d2", "1 2", "", "NaN", "Infinity")
        Probe CStr(Code), CStr(Code)
    Next
    Close #1
End Sub
