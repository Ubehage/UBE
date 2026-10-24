UBE SOURCE 1 MODULE
Attribute UBE_Name = "Main"

Sub Step7Expect(ByVal Condition As Long, ByVal TestName As String, ByRef Failures As Long, ByRef Assertions As Long)
    Assertions = Assertions + 1
    If Condition <> 0 Then
        Print "PASS " & TestName
    Else
        Print "FAIL " & TestName
        Failures = Failures + 1
    End If
End Sub

Function Main() As Long
    If CommandArgumentCount() <> 3 Then
        Main = 2
        Exit Function
    End If
    Dim Failures As Long = 0
    Dim Assertions As Long = 0
    Dim Light As IdeVisualTheme
    Dim Dark As IdeVisualTheme
    Dim HighContrast As IdeVisualTheme
    Call Step7Expect(IdeLoadVisualTheme(ReadAllText(CommandArgument(0)), Light), "light theme loads", Failures, Assertions)
    Call Step7Expect(IdeLoadVisualTheme(ReadAllText(CommandArgument(1)), Dark), "dark theme loads", Failures, Assertions)
    Call Step7Expect(IdeLoadVisualTheme(ReadAllText(CommandArgument(2)), HighContrast), "high contrast theme loads", Failures, Assertions)
    Call Step7Expect(Light.Identity = "light" And Dark.Identity = "dark" And HighContrast.Identity = "high-contrast", "theme identities remain distinct", Failures, Assertions)
    Call Step7Expect(Light.ToolbarHeight = Dark.ToolbarHeight And Dark.ToolbarHeight = HighContrast.ToolbarHeight, "themes share structural metrics", Failures, Assertions)
    Call Step7Expect(Light.UiFont = Dark.UiFont And Dark.UiFont = HighContrast.UiFont, "themes share UI typography", Failures, Assertions)
    Call Step7Expect(Light.EditorFont = Dark.EditorFont And Dark.EditorFont = HighContrast.EditorFont, "themes share editor typography", Failures, Assertions)
    Call Step7Expect(HighContrast.AnimationMilliseconds = 0, "high contrast disables decoration animation", Failures, Assertions)
    Call Step7Expect(Light.FocusWidth >= 2 And Dark.FocusWidth >= 2 And HighContrast.FocusWidth >= 2, "focus indicators stay visible", Failures, Assertions)
    Dim Scaled As Long = 0
    Call Step7Expect(IdeScaledMetric(Light.ToolbarHeight, 96, Scaled) And Scaled = 30, "100 percent metric is exact", Failures, Assertions)
    Call Step7Expect(IdeScaledMetric(Light.ToolbarHeight, 120, Scaled) And Scaled = 38, "125 percent metric rounds safely", Failures, Assertions)
    Call Step7Expect(IdeScaledMetric(Light.ToolbarHeight, 144, Scaled) And Scaled = 45, "150 percent metric is exact", Failures, Assertions)
    Call Step7Expect(IdeScaledMetric(Light.ToolbarHeight, 168, Scaled) And Scaled = 53, "175 percent metric rounds safely", Failures, Assertions)
    Call Step7Expect(IdeScaledMetric(Light.ToolbarHeight, 192, Scaled) And Scaled = 60, "200 percent metric is exact", Failures, Assertions)
    Call Step7Expect(IdeScaledMetric(30, 95, Scaled) = 0, "unsupported low DPI rejected", Failures, Assertions)
    Call Step7Expect(IdeThemeColorIsValid("#00A1FF"), "uppercase RGB color accepted", Failures, Assertions)
    Call Step7Expect(IdeThemeColorIsValid("#00a1ff") = 0, "noncanonical color rejected", Failures, Assertions)
    Call Step7Expect(IdeLoadVisualTheme("UBE-IDE-Theme 999", Light) = 0, "incompatible theme rejected", Failures, Assertions)
    Dim Truncated As String = "UBE-IDE-Theme 1" & StringFromByte(10) & "Identity = ""light""" & StringFromByte(10)
    Call Step7Expect(IdeLoadVisualTheme(Truncated, Light) = 0, "truncated theme rejected", Failures, Assertions)
    Call Step7Expect(Dark.SyntaxIdentifier = Dark.TextColor And Light.SyntaxIdentifier = Light.TextColor, "plain identifiers use normal text role", Failures, Assertions)
    Call Step7Expect(HighContrast.Selection <> HighContrast.Focus, "selection and focus remain distinguishable", Failures, Assertions)
    Call Step7Expect(Light.IconSmall = 16 And Light.IconMedium = 20 And Light.IconLarge = 24, "native icon sizes are frozen", Failures, Assertions)

    If Failures = 0 Then
        Print "STEP7 PASS " & LongToString(Assertions)
        Main = 0
    Else
        Print "STEP7 FAIL " & LongToString(Failures)
        Main = 1
    End If
End Function
