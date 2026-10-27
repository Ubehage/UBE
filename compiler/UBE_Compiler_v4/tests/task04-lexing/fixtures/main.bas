UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

#const PickFirst = false
#if PickFirst Then
Public Sub Main()
    Print "wrong"
End Sub
#elseif true Then
Public Sub Main()
    Print "task4-ok"
End Sub
#else
Public Sub Main()
    Print "wrong"
End Sub
#end if
