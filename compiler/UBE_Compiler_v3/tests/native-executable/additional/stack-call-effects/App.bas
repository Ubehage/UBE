UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private argumentCount As Long = 0
Private entryCount As Long = 0
Private Function Argument() As Long
    argumentCount = argumentCount + 1
    Argument = 7
End Function
Private Function Work(ByVal value As Long) As Long
    entryCount = entryCount + 1
    Work = value + 1
End Function
Function Main() As Long
    Dim result As Long = Work(Argument())
    Main = argumentCount * 100 + entryCount * 10 + result
End Function
