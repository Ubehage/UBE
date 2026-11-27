UBE SOURCE 1 MODULE
Attribute UBE_Name = "ScalarBinding"

Private Type Pair
    First As Single
    Second As Double
End Type

Private Function Check(ByVal Left! As Single, ByVal Right# As Double) As Long
    Dim Values(0 To 1) As Single
    Dim Record As Pair
    Values(0) = Left!
    Record.First = Values(0)
    Record.Second = Right#
    If Record.First + Left! <> 3.0! Then Check = 1: Exit Function
    If Record.Second - Right# <> 0.0# Then Check = 2: Exit Function
    If Record.First * Left! <> 2.25! Then Check = 3: Exit Function
    If Record.Second / Right# <> 1.0# Then Check = 4: Exit Function
    If -Record.First <> -1.5! Then Check = 5: Exit Function
    If Record.First >= Record.Second Then Check = 6: Exit Function
End Function

Public Function Main() As Long
    Main = Check(1.5!, 2.0#)
End Function
