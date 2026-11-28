UBE SOURCE 1 MODULE
Attribute UBE_Name = "NumericSuffix"
Public Function Main() As Long
    Dim Wide As LongLong = -9223372036854775808&&
    Dim Small As Integer = 2%
    Dim Narrow As Single = 2!
    Dim Precise As Double = 2#
    Dim Number As Long = 2&
    If Wide <> -9223372036854775808&& Then Main = 1: Exit Function
    Wide = 9223372036854775807&&
    If Wide <> 9223372036854775807&& Then Main = 2: Exit Function
    If 2&& + 3&& <> 5&& Then Main = 3: Exit Function
    If 2^3 <> 8# Or 2^3^2 <> 64# Then Main = 4: Exit Function
    If 2&&^3&& <> 8# Then Main = 5: Exit Function
    If -2^2 <> -4# Or 2^-3 <> 0.125# Then Main = 6: Exit Function
    If Small <> 2 Or Narrow <> 2# Or Precise <> 2# Then Main = 7: Exit Function
    If Number <> 2 Then Main = 8: Exit Function
End Function
