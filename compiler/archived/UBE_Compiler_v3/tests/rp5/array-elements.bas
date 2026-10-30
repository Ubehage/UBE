UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub UpdateValues(ByRef Values() As Long, ByRef Names() As String, ByVal Position As Long)
    Values(Position) = 42
    Values(Position) = Values(Position)
    Names(Position) = "UBE"
    Names(Position) = Names(Position)
End Sub

Sub Main()
    Dim Values() As Long
    Dim Names() As String
    ReDim Values(1 To 2)
    ReDim Names(1 To 2)
    Call UpdateValues(Values, Names, 2)
    ReDim Preserve Values(1 To 3)
    ReDim Preserve Names(1 To 3)
    Print Values(2)
    Print Names(2)
End Sub
