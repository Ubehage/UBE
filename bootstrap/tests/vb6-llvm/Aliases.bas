Attribute VB_Name = "Aliases"
Option Explicit
' Compile-only checks for dollar spellings absent from type-library aliases.
Public Sub Main()
    ' The procedure below is never executed: it includes a dialog function.
End Sub

' Resolves names using the actual VB6 compiler without invoking the functions.
Private Sub CheckSpellings()
    Dim Text As String
    Text = Dir$("*")
    Text = InputBox$("Compile-only fixture")
    Text = TypeName$(Text)
    Text = MonthName$(1)
    Text = WeekdayName$(1)
    Text = Replace$(Text, "a", "b")
    Text = StrReverse$(Text)
    Text = Join$(Array("a", "b"))
    Text = FormatCurrency$(1)
    Text = FormatDateTime$(Date)
    Text = FormatNumber$(1)
    Text = FormatPercent$(1)
    Text = GetSetting$("UBE", "Probe", "Key")
    Text = CStr$(1)
End Sub
