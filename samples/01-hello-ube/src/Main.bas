UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

' This module contains the entry point for the introductory console sample.

' Prints a greeting and a small arithmetic result, then exits successfully.
Sub Main()
    ' An apostrophe begins a comment, so this explanation is not executed.
    Dim ProductName As String = "UBE"
    Dim FirstNumber As Long = 2
    Dim SecondNumber As Long = 3
    Dim Result As Long = FirstNumber + SecondNumber

    Print "Hello, " & ProductName & "!"
    Print "Welcome to native Basic programming."
    Print "2 + 3 equals:"
    Print Result
End Sub
