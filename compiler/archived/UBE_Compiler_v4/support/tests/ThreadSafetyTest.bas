UBE SOURCE 1 MODULE
Attribute UBE_Name = "ThreadSafetyTest"

Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

Dim FirstStatus As Long
Dim SecondStatus As Long
Dim FirstPath As String
Dim SecondPath As String

Sub FirstWorker()
    FirstStatus = NormalizeCompilerRelativePath("src\one.bas", FirstPath)
End Sub

Sub SecondWorker()
    SecondStatus = NormalizeCompilerRelativePath("src/two.bas", SecondPath)
End Sub

Function Main() As Long
    Dim First As LongLong
    Dim Second As LongLong
    First = CallNew FirstWorker()
    Second = CallNew SecondWorker()
    If RuntimeThreadWait(First, 5000) = 0 Or RuntimeThreadWait(Second, 5000) = 0 Then
        Main = 1
        Exit Function
    End If
    Print FirstStatus
    Print FirstPath
    Print SecondStatus
    Print SecondPath
    Main = 0
End Function
