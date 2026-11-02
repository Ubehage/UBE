UBE SOURCE 1 MODULE
Attribute UBE_Name = "CatalogCancellationFixture"
Function TryMakeCatalogCancellation(ByVal Requested As Long, ByRef Published As SourceCancellation) As Boolean
    TryMakeCatalogCancellation = False
    Dim Pending As SourceCancellation
    Set Pending = New SourceCancellation
    If Pending Is Nothing Then
        Exit Function
    End If
    Pending.Requested = Requested <> 0
    Set Published = Pending
    If Published Is Pending Then
        TryMakeCatalogCancellation = True
    End If
End Function
