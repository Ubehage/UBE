UBE SOURCE 1 MODULE
Attribute UBE_Name = "RP7ComponentLifecycleMain"

Sub Main()
    Dim Window As New LifecycleForm
    Dim AliasValue As LifecycleForm
    Set AliasValue = Window
    Load Window
    Load Window
    Window.RefuseUnload = 1
    Unload Window
    Print AliasValue Is Window
    Window.RefuseUnload = 0
    Unload Window
    Print AliasValue Is Nothing
End Sub
