UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Public Observed As Long

Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

Sub Worker()
    Dim Values() As Long
    Dim Count As Long = 0
    If Count > 0 Then ReDim Values(Count - 1)
    Observed = 1
    If Count = 0 Then Observed = Observed + 1
    If Count <> 0 Then Observed = Observed + 100
    If Count = 0 Then Observed = Observed * 10 Else Observed = -1
    If Count <> 0 Then Observed = -2 Else Observed = Observed + 22
End Sub

Sub Main()
    Dim Id As LongLong
    Id = CallNew Worker()
    Print RuntimeThreadWait(Id, 5000)
    Print Observed
End Sub
