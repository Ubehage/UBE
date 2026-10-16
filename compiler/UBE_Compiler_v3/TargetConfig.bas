UBE SOURCE 1 MODULE
Attribute UBE_Name = "TargetConfig"

Type TargetDescription
    Triple As String
    PlatformName As String
    ArchitectureName As String
    ObjectFormat As String
    PointerBits As Long
End Type

Type HostDescription
    Id As String
    PlatformName As String
    ArchitectureName As String
End Type

Sub ResolveBootstrapHost(ByRef Host As HostDescription)
    Host.Id = "windows-x86_64"
    Host.PlatformName = "Windows"
    Host.ArchitectureName = "x86-64"
End Sub

Function ResolveTarget(ByVal Triple As String, ByRef Target As TargetDescription, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If EqualsFolded(Triple, "x86_64-w64-windows-gnu") <> 0 Then
        Target.Triple = "x86_64-w64-windows-gnu"
        Target.PlatformName = "Windows"
        Target.ArchitectureName = "x86-64"
        Target.ObjectFormat = "COFF"
        Target.PointerBits = 64
        ResolveTarget = 1
        Exit Function
    End If
    Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "UBE3200", "<target>", 1, 1, "unsupported RP2 target: " & Triple)
    ResolveTarget = 0
End Function
