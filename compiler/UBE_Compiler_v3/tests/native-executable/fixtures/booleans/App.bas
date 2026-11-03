UBE SOURCE 1 MODULE
Attribute UBE_Name = "App"
Private trace As Long
Private Function Touch() As Boolean
    trace = trace + 1
    Touch = True
End Function
Function Main() As Long
    Dim t As Boolean = True
    Dim f As Boolean = False
    Dim ok As Boolean = (Not t) = False AndAlso (Not f) = True
    ok = ok AndAlso (t Xor t) = False AndAlso (t Xor f) = True
    ok = ok AndAlso (f Xor t) = True AndAlso (f Xor f) = False
    ok = ok AndAlso (t Eqv t) = True AndAlso (t Eqv f) = False
    ok = ok AndAlso (f Eqv t) = False AndAlso (f Eqv f) = True
    ok = ok AndAlso (t Imp t) = True AndAlso (t Imp f) = False
    ok = ok AndAlso (f Imp t) = True AndAlso (f Imp f) = True
    ok = ok AndAlso (t = t) AndAlso (t <> f) AndAlso (f = f)
    Dim skipOr As Boolean = t OrElse Touch()
    Dim runOr As Boolean = f OrElse Touch()
    Dim skipAnd As Boolean = f AndAlso Touch()
    Dim runAnd As Boolean = t AndAlso Touch()
    If ok AndAlso skipOr AndAlso runOr AndAlso (skipAnd = False) AndAlso runAnd AndAlso trace = 2 Then
        Main = 61
    Else
        Main = 99
    End If
End Function
