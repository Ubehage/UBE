UBE SOURCE 1 MODULE
Attribute UBE_Name = "Program"
' Demonstrates a project entry point using another source module.
Option Explicit

' Returns the value supplied by the project's arithmetic module.
Public Function Main() As Long
    Main = Arithmetic.Answer()
End Function

