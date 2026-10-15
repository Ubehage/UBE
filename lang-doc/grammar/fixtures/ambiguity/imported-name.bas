UBE SOURCE 1 MODULE
Attribute UBE_Name = "ImportedName"
Option Explicit On

' SEMANTIC-ERROR: this models two equally ranked visible declarations.
' A project-level fixture will replace the declarations when imports execute.
Private Sub Execute(ByVal Value As Long)
End Sub

Private Sub Execute(ByVal Value As String)
End Sub

Public Sub Main()
    Execute 1
End Sub

