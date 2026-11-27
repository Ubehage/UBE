UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private Const Control As Long = 0
Private Intrinsic Function Tag(ByVal Value As Variant) As Long
Attribute Tag.UBE_Primitive = "Variant.Tag"
End Function
Private Intrinsic Function Collect() As Long
Attribute Collect.UBE_Primitive = "Memory.Collect"
End Function
Public Function Main() As Long
    Dim ActualTag As Long
    Dim First As Box
    Dim Copy As Box
    Dim Wrong As OtherBox
    Dim Generic As Object
    Dim Values(0 To 1) As Box
    Dim Replacement(0 To 1) As Box
    Dim Item As Variant
    Dim Saved As Variant
    Dim EmptyValue As Variant
    Dim Seen As Long
    Dim Result As Long
    Main = 10
    Set First = New Box
    Set Values(0) = First
    For Each Item In Values
        ActualTag = -1
        ActualTag = Tag(Item)
        If ActualTag <> 9 Then Exit Function
        Set Copy = Item
        If Seen = 0 Then
            If Copy IsNot First Then Exit Function
            Values = Replacement
            Result = Collect()
        Else
            If Copy IsNot Nothing Then Exit Function
        End If
        Seen = Seen + 1
    Next Item
    If Seen <> 2 Then Exit Function
    Main = 20
    Set Saved = First
    Set Copy = Saved
    Set Generic = Saved
    If Copy IsNot First Or Generic IsNot First Then Exit Function
    Set Copy = Nothing
    Set Item = Generic
    Set Copy = Item
    If Copy IsNot First Then Exit Function
    Set Wrong = Saved
    If Wrong IsNot Nothing Or Err.Number <> 13 Then Exit Function
    Main = 30
    Item = 42
    Set Copy = Item
    If Copy IsNot First Or Err.Number <> 13 Then Exit Function
    Set Saved = Item
    ActualTag = -1
    ActualTag = Tag(Saved)
    If ActualTag <> 9 Or Err.Number <> 13 Then Exit Function
    Set Copy = Saved
    If Copy IsNot First Then Exit Function
    Main = 40
    Set Item = Nothing
    ActualTag = -1
    ActualTag = Tag(Item)
    If ActualTag <> 9 Then Exit Function
    Set Copy = Item
    If Copy IsNot Nothing Then Exit Function
    Set Copy = First
    Set Copy = EmptyValue
    If Copy IsNot Nothing Then Exit Function
    Set Saved = EmptyValue
    ActualTag = -1
    ActualTag = Tag(Saved)
    If ActualTag <> 0 Then Exit Function
    Main = Control
End Function
