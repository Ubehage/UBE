UBE SOURCE 1 MODULE
Attribute UBE_Name = "InterfaceMain"

Sub Main()
    Dim Current As IValue
    Set Current = New InterfaceWorker
    Call Current.Increment()
    Print Current.Value
    Set Current = New InterfaceOtherWorker
    Call Current.Increment()
    Print Current.Value
End Sub
