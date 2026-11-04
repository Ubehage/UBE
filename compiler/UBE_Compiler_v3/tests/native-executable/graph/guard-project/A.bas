UBE SOURCE 1 MODULE
Attribute UBE_Name = "A"
Public Events As Long = 0
Public First As Long = B.ReadValue()
Public Tail As Long = 9
Public Function Mark(ByVal Digit As Long) As Long
 Events = Events * 10 + Digit
 Mark = Digit
End Function
Public Function ReadForeign() As Long
 ReadForeign = 77
 ReadForeign = B.Value
 Events = Events * 10 + 9
End Function
Public Sub WriteForeign()
 B.Value = Mark(4)
 Events = Events * 10 + 9
End Sub
Public Function CallForeign() As Long
 CallForeign = 77
 CallForeign = B.Accept(Mark(5))
 Events = Events * 10 + 9
End Function
Public Function NativeForeign() As B.Wide
 NativeForeign = B.Pack(Mark(6))
 Events = Events * 10 + 9
End Function
Public Function AliasRead(ByRef X As Long) As Long
 AliasRead = 77
 AliasRead = X
 Events = Events * 10 + 9
End Function
Public Sub AliasWrite(ByRef X As Long)
 X = Mark(7)
 Events = Events * 10 + 9
End Sub
Public Function ForwardRead(ByRef X As Long) As Long
 ForwardRead = 77
 ForwardRead = AliasRead(X)
 Events = Events * 10 + 8
End Function
Public Function Unused(ByRef X As Long) As Long
 Unused = 7
End Function
Public Function ForwardUnused(ByRef X As Long) As Long
 ForwardUnused = Unused(X)
End Function
Public Function UnusedGlobal() As Long
 UnusedGlobal = Unused(B.Value)
End Function
Function Main() As Long
 Events = Events + 1
 Main = First * 10 + Tail
End Function
