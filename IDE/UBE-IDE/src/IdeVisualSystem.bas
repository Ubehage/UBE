UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeVisualSystem"

Type IdeVisualTheme
    Identity As String
    Canvas As String
    Panel As String
    Editor As String
    TextColor As String
    MutedText As String
    Border As String
    Selection As String
    SelectionText As String
    Focus As String
    Diagnostic As String
    Success As String
    Warning As String
    ErrorColor As String
    DebugCurrent As String
    DebugChanged As String
    SyntaxKeyword As String
    SyntaxType As String
    SyntaxString As String
    SyntaxNumber As String
    SyntaxComment As String
    SyntaxProcedure As String
    SyntaxConstant As String
    SyntaxOperator As String
    SyntaxIdentifier As String
    UiFont As String
    UiFontFallback As String
    EditorFont As String
    EditorFontFallback As String
    ToolbarHeight As Long
    TreeRowHeight As Long
    TabHeight As Long
    StatusHeight As Long
    SpaceUnit As Long
    BorderWidth As Long
    CornerRadius As Long
    FocusWidth As Long
    AnimationMilliseconds As Long
    IconSmall As Long
    IconMedium As Long
    IconLarge As Long
End Type

Function IdeThemeColorIsValid(ByVal Value As String) As Long
    If StringLength(Value) <> 7 Or StringByteAt(Value, 0) <> 35 Then
        IdeThemeColorIsValid = 0
        Exit Function
    End If
    Dim Index As Long = 1
    While Index < 7
        Dim ByteValue As Long = StringByteAt(Value, Index)
        Dim IsDigit As Long = ByteValue >= 48 And ByteValue <= 57
        Dim IsUpper As Long = ByteValue >= 65 And ByteValue <= 70
        If IsDigit = 0 And IsUpper = 0 Then
            IdeThemeColorIsValid = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    IdeThemeColorIsValid = 1
End Function

Function IdeReadThemeLong(ByVal Contents As String, ByRef Cursor As Long, ByVal Key As String, ByRef Value As Long) As Long
    Dim TextValue As String = ""
    If IdeReadLanguageField(Contents, Cursor, Key, TextValue) = 0 Then
        IdeReadThemeLong = 0
        Exit Function
    End If
    IdeReadThemeLong = IdeParseNonnegativeLong(TextValue, Value)
End Function

Function IdeValidateVisualTheme(ByRef Theme As IdeVisualTheme) As Long
    If Theme.Identity <> "light" And Theme.Identity <> "dark" And Theme.Identity <> "high-contrast" Then
        IdeValidateVisualTheme = 0
        Exit Function
    End If
    Dim Colors() As String
    ReDim Colors(23)
    Colors(0) = Theme.Canvas
    Colors(1) = Theme.Panel
    Colors(2) = Theme.Editor
    Colors(3) = Theme.TextColor
    Colors(4) = Theme.MutedText
    Colors(5) = Theme.Border
    Colors(6) = Theme.Selection
    Colors(7) = Theme.SelectionText
    Colors(8) = Theme.Focus
    Colors(9) = Theme.Diagnostic
    Colors(10) = Theme.Success
    Colors(11) = Theme.Warning
    Colors(12) = Theme.ErrorColor
    Colors(13) = Theme.DebugCurrent
    Colors(14) = Theme.DebugChanged
    Colors(15) = Theme.SyntaxKeyword
    Colors(16) = Theme.SyntaxType
    Colors(17) = Theme.SyntaxString
    Colors(18) = Theme.SyntaxNumber
    Colors(19) = Theme.SyntaxComment
    Colors(20) = Theme.SyntaxProcedure
    Colors(21) = Theme.SyntaxConstant
    Colors(22) = Theme.SyntaxOperator
    Colors(23) = Theme.SyntaxIdentifier
    Dim Index As Long = 0
    While Index < 24
        If IdeThemeColorIsValid(Colors(Index)) = 0 Then
            IdeValidateVisualTheme = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    If StringLength(Theme.UiFont) = 0 Or StringLength(Theme.UiFontFallback) = 0 Or StringLength(Theme.EditorFont) = 0 Or StringLength(Theme.EditorFontFallback) = 0 Then
        IdeValidateVisualTheme = 0
        Exit Function
    End If
    If Theme.ToolbarHeight < 24 Or Theme.ToolbarHeight > 64 Or Theme.TreeRowHeight < 18 Or Theme.TreeRowHeight > 48 Or Theme.TabHeight < 22 Or Theme.TabHeight > 56 Or Theme.StatusHeight < 18 Or Theme.StatusHeight > 48 Then
        IdeValidateVisualTheme = 0
        Exit Function
    End If
    If Theme.SpaceUnit < 2 Or Theme.SpaceUnit > 12 Or Theme.BorderWidth < 1 Or Theme.BorderWidth > 4 Or Theme.CornerRadius < 0 Or Theme.CornerRadius > 8 Or Theme.FocusWidth < 2 Or Theme.FocusWidth > 4 Then
        IdeValidateVisualTheme = 0
        Exit Function
    End If
    If Theme.AnimationMilliseconds < 0 Or Theme.AnimationMilliseconds > 250 Or Theme.IconSmall <> 16 Or Theme.IconMedium <> 20 Or Theme.IconLarge <> 24 Then
        IdeValidateVisualTheme = 0
        Exit Function
    End If
    IdeValidateVisualTheme = 1
End Function

Function IdeLoadVisualTheme(ByVal Contents As String, ByRef Theme As IdeVisualTheme) As Long
    If StringLength(Contents) = 0 Or StringLength(Contents) > IdeLimitTextBytes() Then
        IdeLoadVisualTheme = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        IdeLoadVisualTheme = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    If IdeReadLine(Contents, Cursor, LineText) = 0 Or LineText <> "UBE-IDE-Theme 1" Then
        IdeLoadVisualTheme = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Identity", Theme.Identity) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Canvas", Theme.Canvas) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Panel", Theme.Panel) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Editor", Theme.Editor) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Text", Theme.TextColor) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.MutedText", Theme.MutedText) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Border", Theme.Border) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Selection", Theme.Selection) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.SelectionText", Theme.SelectionText) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Focus", Theme.Focus) = 0 Then
        IdeLoadVisualTheme = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Color.Diagnostic", Theme.Diagnostic) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Success", Theme.Success) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Warning", Theme.Warning) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.Error", Theme.ErrorColor) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.DebugCurrent", Theme.DebugCurrent) = 0 Or IdeReadLanguageField(Contents, Cursor, "Color.DebugChanged", Theme.DebugChanged) = 0 Then
        IdeLoadVisualTheme = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Syntax.Keyword", Theme.SyntaxKeyword) = 0 Or IdeReadLanguageField(Contents, Cursor, "Syntax.Type", Theme.SyntaxType) = 0 Or IdeReadLanguageField(Contents, Cursor, "Syntax.String", Theme.SyntaxString) = 0 Or IdeReadLanguageField(Contents, Cursor, "Syntax.Number", Theme.SyntaxNumber) = 0 Or IdeReadLanguageField(Contents, Cursor, "Syntax.Comment", Theme.SyntaxComment) = 0 Or IdeReadLanguageField(Contents, Cursor, "Syntax.Procedure", Theme.SyntaxProcedure) = 0 Or IdeReadLanguageField(Contents, Cursor, "Syntax.Constant", Theme.SyntaxConstant) = 0 Or IdeReadLanguageField(Contents, Cursor, "Syntax.Operator", Theme.SyntaxOperator) = 0 Or IdeReadLanguageField(Contents, Cursor, "Syntax.Identifier", Theme.SyntaxIdentifier) = 0 Then
        IdeLoadVisualTheme = 0
        Exit Function
    End If
    If IdeReadLanguageField(Contents, Cursor, "Font.UI", Theme.UiFont) = 0 Or IdeReadLanguageField(Contents, Cursor, "Font.UIFallback", Theme.UiFontFallback) = 0 Or IdeReadLanguageField(Contents, Cursor, "Font.Editor", Theme.EditorFont) = 0 Or IdeReadLanguageField(Contents, Cursor, "Font.EditorFallback", Theme.EditorFontFallback) = 0 Then
        IdeLoadVisualTheme = 0
        Exit Function
    End If
    If IdeReadThemeLong(Contents, Cursor, "Metric.ToolbarHeight", Theme.ToolbarHeight) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.TreeRowHeight", Theme.TreeRowHeight) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.TabHeight", Theme.TabHeight) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.StatusHeight", Theme.StatusHeight) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.SpaceUnit", Theme.SpaceUnit) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.BorderWidth", Theme.BorderWidth) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.CornerRadius", Theme.CornerRadius) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.FocusWidth", Theme.FocusWidth) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.AnimationMilliseconds", Theme.AnimationMilliseconds) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.IconSmall", Theme.IconSmall) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.IconMedium", Theme.IconMedium) = 0 Or IdeReadThemeLong(Contents, Cursor, "Metric.IconLarge", Theme.IconLarge) = 0 Then
        IdeLoadVisualTheme = 0
        Exit Function
    End If
    If IdeReadLine(Contents, Cursor, LineText) <> 0 Then
        IdeLoadVisualTheme = 0
        Exit Function
    End If
    IdeLoadVisualTheme = IdeValidateVisualTheme(Theme)
End Function

Function IdeScaledMetric(ByVal LogicalPixels As Long, ByVal Dpi As Long, ByRef Result As Long) As Long
    If LogicalPixels < 0 Or Dpi < 96 Or Dpi > 768 Or LogicalPixels > 8192 Then
        IdeScaledMetric = 0
        Exit Function
    End If
    Result = (LogicalPixels * Dpi + 48) / 96
    IdeScaledMetric = 1
End Function
