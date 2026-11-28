UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedRolesProbe"
' Observes declaration role maps without invoking managed runtime operations.

Private Intrinsic Function RoleLength(ByRef Values() As Long) As Long
Attribute RoleLength.UBE_Primitive = "Array.Length"
End Function

Public Function Check(ByRef FirstSource() As Byte, ByRef SecondSource() As Byte, ByRef Expected() As Long, ByVal ExpectedCount As Long, ByVal Code As Long, ByVal Reason As Long) As Long
    Dim Bytes() As Byte
    Dim Tokens() As SourceScanner.SourceToken
    Dim Nodes() As SourceParser.SyntaxNode
    Dim Modules() As ProjectSyntax.ParsedModule
    Dim Counts As ProjectSyntax.ProjectCounts
    Dim InputError As ProjectSyntax.ProjectDiagnostic
    Dim PackageName(0 To 0) As Byte
    Dim Roles(0 To 2) As Long
    Dim RoleCount As Long = 3
    Dim Diagnostic As DeclarationBinder.BindingDiagnostic
    Dim Status As Boolean
    Dim Index As Long
    Dim Seen As Long
    On Error GoTo Failed
    PackageName(0) = 80
    Roles(0) = 101
    Roles(1) = 202
    Roles(2) = 303
    If Not ProjectSyntax.TryAppendModule(FirstSource, Bytes, Tokens, Nodes, Modules, Counts, InputError) Then Check = 1: Exit Function
    If BufferPrimitives.ByteStorageLength(SecondSource) > 0 Then
        If Not ProjectSyntax.TryAppendModule(SecondSource, Bytes, Tokens, Nodes, Modules, Counts, InputError) Then Check = 2: Exit Function
    End If
    ' The authority fixture deliberately forges retained metadata, never source syntax.
    If Code = 8 And Reason = 84 Then Modules(0).LookupDomain = 1
    Status = PrimitiveRoles.TryBindPrimitives(Bytes, Tokens, Nodes, Modules, Counts, PackageName, False, Roles, RoleCount, Diagnostic)
    If Code <> 0 Then
        If Status Or Diagnostic.Code <> Code Or Diagnostic.Reason <> Reason Then Check = 3: Exit Function
        If RoleCount <> 0 Or RoleLength(Roles) <> 3 Then Check = 4: Exit Function
        If Roles(0) <> 101 Or Roles(1) <> 202 Or Roles(2) <> 303 Then Check = 5: Exit Function
    Else
        If Not Status Or Diagnostic.Code <> 0 Or RoleCount <> Counts.NodeCount Then Check = 6: Exit Function
        Do While Index < RoleCount
            If Nodes(Index).IsIntrinsic Then
                If Seen >= ExpectedCount Then Check = 7: Exit Function
                If Roles(Index) <> Expected(Seen) Then Check = 8: Exit Function
                Seen = Seen + 1
            Else
                If Roles(Index) <> 0 Then Check = 9: Exit Function
            End If
            Index = Index + 1
        Loop
        If Seen <> ExpectedCount Then Check = 10: Exit Function
    End If
    Exit Function
Failed:
    Check = 11
End Function
