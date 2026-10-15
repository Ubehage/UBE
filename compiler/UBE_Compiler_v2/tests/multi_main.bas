Function Main() As Long
    Dim Item As SharedPair
    Item.Left = 3
    Item.Right = 4
    Dim Total As Long = AddPair(Item)
    Print ModuleMessage(Total)
    Main = Total
End Function
