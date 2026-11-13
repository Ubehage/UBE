UBE SOURCE 1 MODULE
Attribute UBE_Name = "NamespaceProbe"
' Exercises individual namespace mutations without hiding publication or cleanup policy.
Public Function Main() As Long
    Dim Directory(0 To 4) As Byte
    Dim First(0 To 6) As Byte
    Dim Second(0 To 6) As Byte
    Dim Missing(0 To 6) As Byte
    Dim Invalid(0 To 0) As Byte
    Dim Value(0 To 0) As Byte
    Dim Token As Long
    Dim Count As Long
    Dim Length As Long
    Dim Kind As Long
    Dim Failure As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Directory(0) = 115: Directory(1) = 116: Directory(2) = 97: Directory(3) = 103: Directory(4) = 101
    First(0) = 115: First(1) = 116: First(2) = 97: First(3) = 103: First(4) = 101: First(5) = 92: First(6) = 97
    Second = First: Second(6) = 98
    Missing = First: Missing(6) = 122
    Invalid(0) = 60
    Status = FilePrimitives.SetError(678)
    If Not PathPrimitives.TryKind(Directory, Kind, Failure) Then Main = 1: Exit Function
    If Kind <> 0 Or Failure <> 0 Or Err.Number <> 678 Then Main = 2: Exit Function
    If Not DirectoryPrimitives.TryCreate(Directory, Failure) Then Main = 3: Exit Function
    If DirectoryPrimitives.TryCreate(Directory, Failure) Then Main = 4: Exit Function
    If Failure <> 17 Or Err.Number <> 58 Then Main = 5: Exit Function
    If Not PathPrimitives.TryKind(Directory, Kind, Failure) Then Main = 6: Exit Function
    If Kind <> 2 Then Main = 7: Exit Function
    If Not FilePrimitives.TryCreateNew(First, Token, Failure) Then Main = 8: Exit Function
    Value(0) = 42
    If Not FilePrimitives.TryWrite(Token, Value, 0, 1, Count, Failure) Then Main = 9: GoTo Cleanup
    If Not FilePrimitives.TryClose(Token, Failure) Then Main = 10: Exit Function
    If Not FilePrimitives.TryCreateNew(Second, Token, Failure) Then Main = 11: Exit Function
    Value(0) = 9
    If Not FilePrimitives.TryWrite(Token, Value, 0, 1, Count, Failure) Then Main = 12: GoTo Cleanup
    If Not FilePrimitives.TryClose(Token, Failure) Then Main = 13: Exit Function
    If Not PathPrimitives.TryKind(Second, Kind, Failure) Then Main = 14: Exit Function
    If Kind <> 1 Then Main = 15: Exit Function
    If DirectoryPrimitives.TryCreate(Second, Failure) Then Main = 16: Exit Function
    If Failure <> 17 Or Err.Number <> 58 Then Main = 17: Exit Function
    If DirectoryPrimitives.TryRemove(Directory, Failure) Then Main = 18: Exit Function
    If Failure <> 5 Then Main = 19: Exit Function
    If FilePrimitives.TryDelete(Directory, Failure) Then Main = 20: Exit Function
    If Failure <> 5 Then Main = 21: Exit Function
    If FilePrimitives.TryReplace(Missing, Second, Failure) Then Main = 22: Exit Function
    If Failure <> 18 Or Err.Number <> 53 Then Main = 23: Exit Function
    If Not FilePrimitives.TryOpen(Second, 1, Token, Length, Failure) Then Main = 24: Exit Function
    If Not FilePrimitives.TryRead(Token, Value, 0, 1, Count, Failure) Then Main = 25: GoTo Cleanup
    If Count <> 1 Or Value(0) <> 9 Then Main = 26: GoTo Cleanup
    If Not FilePrimitives.TryClose(Token, Failure) Then Main = 27: Exit Function
    If Not FilePrimitives.TryReplace(First, Second, Failure) Then Main = 28: Exit Function
    If Not PathPrimitives.TryKind(First, Kind, Failure) Then Main = 29: Exit Function
    If Kind <> 0 Then Main = 30: Exit Function
    If Not FilePrimitives.TryOpen(Second, 1, Token, Length, Failure) Then Main = 31: Exit Function
    If Not FilePrimitives.TryRead(Token, Value, 0, 1, Count, Failure) Then Main = 32: GoTo Cleanup
    If Count <> 1 Or Value(0) <> 42 Then Main = 33: GoTo Cleanup
    If Not FilePrimitives.TryClose(Token, Failure) Then Main = 34: Exit Function
    Kind = 81
    If PathPrimitives.TryKind(Invalid, Kind, Failure) Then Main = 35: Exit Function
    If Kind <> 81 Or Failure <> 5 Then Main = 36: Exit Function
    If Not FilePrimitives.TryDelete(Second, Failure) Then Main = 37: Exit Function
    If FilePrimitives.TryDelete(Second, Failure) Then Main = 38: Exit Function
    If Failure <> 18 Or Err.Number <> 53 Then Main = 39: Exit Function
    If Not DirectoryPrimitives.TryRemove(Directory, Failure) Then Main = 40: Exit Function
    If DirectoryPrimitives.TryRemove(Directory, Failure) Then Main = 41: Exit Function
    If Failure <> 18 Or Err.Number <> 53 Then Main = 42: Exit Function
    Status = FilePrimitives.SetError(345)
    If Not PathPrimitives.TryKind(Missing, Kind, Failure) Then Main = 43: Exit Function
    If Kind <> 0 Or Failure <> 0 Or Err.Number <> 345 Then Main = 44: Exit Function
    Exit Function
Cleanup:
    If Not FilePrimitives.TryClose(Token, Failure) Then Main = 45
    Exit Function
Failed:
    Main = 90
    GoTo Cleanup
End Function
