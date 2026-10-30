UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Public Observed As Long

Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

Sub Main()
    Dim Id As LongLong
    Id = CallNew Worker(41)
    Print Id > 0
    Print RuntimeThreadWait(Id, 5000)
    Print Observed
End Sub

Sub Worker(ByVal Value As Long)
    Observed = Value + 1
End Sub
