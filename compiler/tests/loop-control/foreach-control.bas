UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private Const Control As Long = 0
Private Type Entry
    Number As Long
    Text As String
End Type
Private Type OtherEntry
    Number As Long
    Text As String
End Type

Private Intrinsic Function Tag(ByVal Value As Variant) As Long
Attribute Tag.UBE_Primitive = "Variant.Tag"
End Function

Private Intrinsic Function Collect() As Long
Attribute Collect.UBE_Primitive = "Memory.Collect"
End Function

Private Intrinsic Function Resize(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute Resize.UBE_Primitive = "Array.TryResize"
End Function

Private Sub RaiseFailure()
    Err.Raise 5
End Sub

Private Function Scalars() As Boolean
    Dim ActualTag As Long
    Dim Value As Variant
    Dim Copy As Variant
    Dim Number As Long
    Dim Small As Byte = 251
    Dim Wide As LongLong = 9007199254740993
    Dim Fraction As Double = 1.5
    Dim DecodedFraction As Double
    Dim Text As String
    Dim Result As Long
    ActualTag = -1
    ActualTag = Tag(Value)
    If ActualTag <> 0 Then Exit Function
    Number = Value
    If Number <> 0 Then Exit Function
    Text = Value
    If Text <> "" Then Exit Function
    Value = Small
    ActualTag = -1
    ActualTag = Tag(Value)
    If ActualTag <> 17 Then Exit Function
    Copy = Value
    Number = Copy
    If Number <> 251 Then Exit Function
    Value = Wide
    ActualTag = -1
    ActualTag = Tag(Value)
    If ActualTag <> 20 Then Exit Function
    Wide = Value
    If Wide <> 9007199254740993 Then Exit Function
    Value = Fraction
    ActualTag = -1
    ActualTag = Tag(Value)
    If ActualTag <> 5 Then Exit Function
    DecodedFraction = Value
    If DecodedFraction <> 1.5 Then Exit Function
    Value = "kept boxed text"
    Copy = Value
    Value = 42
    Result = Collect()
    ActualTag = -1
    ActualTag = Tag(Copy)
    If ActualTag <> 8 Then Exit Function
    Text = Copy
    If Text <> "kept boxed text" Then Exit Function
    Scalars = True
End Function

Private Function Numbers(ByVal Depth As Long) As Boolean
    Dim ActualTag As Long
    Dim Values() As Long
    Dim Replacement(0 To 1) As Long
    Dim EmptyValues() As Long
    Dim Item As Variant
    Dim Seen As Long
    Dim Number As Long
    Dim Result As Long
    Dim Passed As Boolean
    If Not Resize(Values, 2, False) Then Exit Function
    Values(0) = 10
    Values(1) = 20
    Replacement(0) = 90
    Replacement(1) = 91
    Item = 42
    For Each Item In EmptyValues
        Exit Function
    Next Item
    Number = Item
    If Number <> 42 Then Exit Function
    For Each Item In Values
        ActualTag = -1
        ActualTag = Tag(Item)
        If ActualTag <> 3 Then Exit Function
        Number = Item
        Seen = Seen + 1
        If Seen = 1 Then
            If Number <> 10 Then Exit Function
            Values = Replacement
            Result = Collect()
            If Depth > 0 Then
                Passed = False
                Passed = Numbers(Depth - 1)
                If Not Passed Then Exit Function
            End If
        Else
            If Number <> 20 Then Exit Function
        End If
    Next Item
    If Seen <> 2 Then Exit Function
    Number = Item
    If Number <> 20 Then Exit Function
    If Values(0) <> 90 Or Values(1) <> 91 Then Exit Function
    Numbers = True
End Function

Private Function TextValues() As Boolean
    Dim Values(-2 To -1) As String
    Dim Replacement(-2 To -1) As String
    Dim Item As Variant
    Dim Text As String
    Dim Seen As Long
    Dim Result As Long
    Values(-2) = "original first"
    Values(-1) = "original second"
    Replacement(-2) = "replacement first"
    Replacement(-1) = "replacement second"
    For Each Item In Values
        Seen = Seen + 1
        Text = Item
        If Seen = 1 Then
            If Text <> "original first" Then Exit Function
            Values = Replacement
            Result = Collect()
        Else
            If Text <> "original second" Then Exit Function
        End If
    Next Item
    If Seen <> 2 Then Exit Function
    Result = Collect()
    TextValues = True
End Function

Private Function Mixed() As Boolean
    Dim Values(0 To 1) As Long
    Dim Item As Variant
    Dim Inner As Variant
    Dim Index As Long
    Dim Seen As Long
    Dim Number As Long
    Values(0) = 3
    Values(1) = 4
    For Each Item In Values
        For Index = 1 To 2
            While True
                Do
                    For Each Inner In Values
                        Seen = Seen + 1
                        Exit For
                    Next Inner
                    Exit Loop
                Loop
            Wend
        Next Index
    Next Item
    If Seen <> 1 Then Exit Function
    Number = Item
    If Number <> 3 Or Index <> 1 Then Exit Function
    Number = Inner
    If Number <> 3 Then Exit Function
    For Index = 1 To 2
        For Each Item In Values
            Seen = Seen + 1
            Exit For
        Next Item
    Next Index
    If Seen <> 3 Then Exit Function
    Mixed = True
End Function

Private Function RecursiveExit(ByVal Depth As Long) As Long
    Dim Values(0 To 1) As Long
    Dim Item As Variant
    Dim Number As Long
    Dim Seen As Long
    Dim Child As Long
    Values(0) = Depth + 10
    Values(1) = Depth + 20
    For Each Item In Values
        Seen = Seen + 1
        If Depth > 0 Then Child = RecursiveExit(Depth - 1)
        Do
            Exit Loop
        Loop
        RecursiveExit = 100
        Exit Function
    Next Item
    Number = Item
    If Seen <> 1 Or Number <> Depth + 10 Then RecursiveExit = 101: Exit Function
    If Depth > 0 And Child <> Depth Then RecursiveExit = 102: Exit Function
    RecursiveExit = Child + 1
End Function

Private Function ReadRecord(ByVal Value As Variant) As Long
    Dim Item As Entry
    Item = Value
    ReadRecord = Item.Number
End Function

Private Function Records() As Boolean
    Dim ActualTag As Long
    Dim Values(0 To 1) As Entry
    Dim Replacement(0 To 1) As Entry
    Dim Item As Variant
    Dim Copy As Entry
    Dim Wrong As OtherEntry
    Dim Seen As Long
    Dim Result As Long
    Values(0).Number = 7
    Values(0).Text = "first record"
    Values(1).Number = 8
    Values(1).Text = "second record"
    For Each Item In Values
        ActualTag = -1
        ActualTag = Tag(Item)
        If ActualTag <> 36 Then Exit Function
        Copy = Item
        Seen = Seen + 1
        If Seen = 1 Then
            If Copy.Number <> 7 Or Copy.Text <> "first record" Then Exit Function
            Values(0).Number = 99
            Copy.Number = 50
            Copy = Item
            If Copy.Number <> 7 Then Exit Function
            Values = Replacement
            Result = Collect()
        Else
            If Copy.Number <> 8 Or Copy.Text <> "second record" Then Exit Function
        End If
    Next Item
    If Seen <> 2 Then Exit Function
    Item = Copy
    Copy.Number = 45
    Result = -1
    Result = ReadRecord(Item)
    If Result <> 8 Then Exit Function
    Result = -1
    Result = ReadRecord(Copy)
    If Result <> 45 Then Exit Function
    Wrong.Number = 61
    Wrong = Item
    If Wrong.Number <> 61 Or Err.Number <> 13 Then Exit Function
    Records = True
End Function

Private Function VariantElements() As Boolean
    Dim ActualTag As Long
    Dim Values(0 To 2) As Variant
    Dim Item As Variant
    Dim Small As Byte = 4
    Dim Number As Long
    Dim Text As String
    Dim Seen As Long
    Values(0) = Small
    Values(1) = "mixed value"
    For Each Item In Values
        ActualTag = -1
        ActualTag = Tag(Item)
        If Seen = 0 Then
            If ActualTag <> 17 Then Exit Function
            Number = Item
            If Number <> 4 Then Exit Function
        ElseIf Seen = 1 Then
            If ActualTag <> 8 Then Exit Function
            Text = Item
            If Text <> "mixed value" Then Exit Function
        Else
            If ActualTag <> 0 Then Exit Function
        End If
        Seen = Seen + 1
    Next Item
    If Seen <> 3 Then Exit Function
    VariantElements = True
End Function

Private Function Failures() As Boolean
    Dim Values(0 To 1) As String
    Dim Replacement(0 To 1) As String
    Dim Item As Variant
    Dim Number As Long
    Dim Seen As Long
    Dim Result As Long
    Values(0) = "invalid first"
    Values(1) = "invalid second"
    For Each Item In Values
        Number = 27
        Number = Item
        If Number <> 27 Or Err.Number <> 13 Then Exit Function
        Seen = Seen + 1
    Next Item
    If Seen <> 2 Then Exit Function
    On Error GoTo Handled
    For Each Item In Values
        Values = Replacement
        Number = Item
        Exit Function
    Next Item
    Exit Function
Handled:
    Result = Collect()
    If Number <> 27 Or Err.Number <> 13 Then Exit Function
    If Values(0) <> "" Or Values(1) <> "" Then Exit Function
    Failures = True
End Function

Private Function InnerHandler() As Boolean
    Dim Values(0 To 1) As String
    Dim Replacement(0 To 1) As String
    Dim Item As Variant
    Dim Seen As Long
    Dim Number As Long
    Dim Result As Long
    Values(0) = "1"
    Values(1) = "2"
    On Error GoTo InIteration
    For Each Item In Values
        Seen = Seen + 1
        If Seen = 1 Then
            Values = Replacement
            RaiseFailure
        End If
InIteration:
        Result = Collect()
        Number = Item
        If Number <> Seen Then Exit Function
    Next Item
    If Seen <> 2 Then Exit Function
    InnerHandler = True
End Function

Private Function Reentry() As Boolean
    Dim Values() As Long
    Dim Replacement(0 To 1) As Long
    Dim Item As Variant
    Dim Again As Boolean
    Dim Seen As Long
    Dim Number As Long
    If Not Resize(Values, 2, False) Then Exit Function
    Values(0) = 1
    Values(1) = 2
    Replacement(0) = 3
    Replacement(1) = 4
Restart:
    For Each Item In Values
        If Not Again Then
            Again = True
            Values = Replacement
            GoTo Restart
        End If
        Number = Item
        Seen = Seen + Number
    Next Item
    If Seen <> 7 Then Exit Function
    Reentry = True
End Function

Private Function Mutations() As Boolean
    Dim Values(0 To 2) As Long
    Dim DynamicValues() As Long
    Dim Item As Variant
    Dim Seen As Long
    Dim Number As Long
    Dim Total As Long
    Values(0) = 1
    Values(1) = 2
    Values(2) = 3
    For Each Item In Values
        Number = Item
        Total = Total + Number
        If Seen = 0 Then
            Values(1) = 7
            Values(2) = 8
        End If
        Seen = Seen + 1
    Next Item
    If Seen <> 3 Or Total <> 16 Then Exit Function
    If Not Resize(DynamicValues, 2, False) Then Exit Function
    DynamicValues(0) = 10
    DynamicValues(1) = 20
    Seen = 0
    For Each Item In DynamicValues
        Number = Item
        If Seen = 0 Then
            If Number <> 10 Then Exit Function
            If Not Resize(DynamicValues, 3, True) Then Exit Function
            DynamicValues(1) = 90
            DynamicValues(2) = 91
        Else
            If Number <> 20 Then Exit Function
        End If
        Seen = Seen + 1
    Next Item
    If Seen <> 2 Then Exit Function
    Mutations = True
End Function

Public Function Main() As Long
    Dim Passed As Boolean
    Dim Number As Long
    Main = 10
    Passed = False
    Passed = Scalars()
    If Not Passed Then Exit Function
    Main = 20
    Passed = False
    Passed = Numbers(3)
    If Not Passed Then Exit Function
    Main = 30
    Passed = False
    Passed = TextValues()
    If Not Passed Then Exit Function
    Main = 40
    Passed = False
    Passed = Mixed()
    If Not Passed Then Exit Function
    Main = 50
    Passed = False
    Passed = VariantElements()
    If Not Passed Then Exit Function
    Main = 60
    Passed = False
    Passed = Failures()
    If Not Passed Then Exit Function
    Main = 70
    Passed = False
    Passed = Records()
    If Not Passed Then Exit Function
    Main = 80
    Passed = False
    Passed = InnerHandler()
    If Not Passed Then Exit Function
    Main = 90
    Passed = False
    Passed = Reentry()
    If Not Passed Then Exit Function
    Main = 100
    Passed = False
    Passed = Mutations()
    If Not Passed Then Exit Function
    Main = 110
    Number = -1
    Number = RecursiveExit(4)
    If Number <> 5 Then Exit Function
    Main = Control
End Function
