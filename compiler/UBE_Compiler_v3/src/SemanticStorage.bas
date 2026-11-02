UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticStorage"
Function TryContinueSemanticPreparation(ByVal Cancellation As SourceCancellation, ByRef Failure As SemanticFailure) As Boolean
    TryContinueSemanticPreparation = False
    Call ResetSemanticFailure(Failure)
    Dim Requested As Boolean = False
    If TryThreadStopRequested(Requested) = False Then
        Exit Function
    End If
    If Requested Then
        Failure.Kind = 4
        Failure.Code = 1429
        Exit Function
    End If
    If (Cancellation Is Nothing) = False Then
        If Cancellation.Requested Then
            Failure.Kind = 4
            Failure.Code = 1429
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Failure)
    TryContinueSemanticPreparation = True
End Function
Function TryRetainSemanticSource(ByRef Original As SemanticSource, ByRef Retained As SemanticSource) As Boolean
    TryRetainSemanticSource = False
    Set Retained = Original
    If Retained Is Original Then
        TryRetainSemanticSource = True
    End If
End Function
Function TryRetainSemanticWork(ByRef Original As SourceWork, ByRef Retained As SourceWork) As Boolean
    TryRetainSemanticWork = False
    Set Retained = Original
    If Retained Is Original Then
        TryRetainSemanticWork = True
    End If
End Function
Function TryRetainSemanticOwner(ByRef Original As SourceOwner, ByRef Retained As SourceOwner) As Boolean
    TryRetainSemanticOwner = False
    Set Retained = Original
    If Retained Is Original Then
        TryRetainSemanticOwner = True
    End If
End Function

' Private context-owned geometric arenas. Scalar records contain no owner references.
Sub ReadSemanticFact(ByRef Destination As SemanticFact, ByRef Original As SemanticFact)
    Destination = Original
End Sub
Sub WriteSemanticFact(ByRef Destination As SemanticFact, ByRef Original As SemanticFact)
    Destination = Original
End Sub
Sub ReadBoundNode(ByRef Destination As BoundNode, ByRef Original As BoundNode)
    Destination = Original
End Sub
Sub WriteBoundNode(ByRef Destination As BoundNode, ByRef Original As BoundNode)
    Destination = Original
End Sub
Sub ReadSemanticDeclaration(ByRef Destination As SemanticDeclaration, ByRef Original As SemanticDeclaration)
    Destination = Original
End Sub
Sub WriteSemanticDeclaration(ByRef Destination As SemanticDeclaration, ByRef Original As SemanticDeclaration)
    Destination = Original
End Sub
Function TryReadCatalogDeclaration(ByVal Catalog As SemanticCatalog, ByVal Id As Long, ByRef Declaration As SemanticDeclaration, ByRef Failure As SemanticFailure) As Boolean
    TryReadCatalogDeclaration = False
    Call ResetSemanticFailure(Failure)
    If Catalog Is Nothing Then
        TryReadCatalogDeclaration = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Id < 0 Or Id >= Catalog.DeclarationCount Then
        TryReadCatalogDeclaration = FailSemanticDomain(Failure)
        Exit Function
    End If
    Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(Id))
    Failure.Kind = 0
    Failure.Code = 0
    TryReadCatalogDeclaration = True
End Function
Sub ReadSemanticType(ByRef Destination As SemanticType, ByRef Original As SemanticType)
    Destination = Original
End Sub
Sub WriteSemanticType(ByRef Destination As SemanticType, ByRef Original As SemanticType)
    Destination = Original
End Sub
Sub ReadSemanticName(ByRef Destination As SemanticName, ByRef Original As SemanticName)
    Destination = Original
End Sub
Sub WriteSemanticName(ByRef Destination As SemanticName, ByRef Original As SemanticName)
    Destination = Original
End Sub
Intrinsic Function SemanticFactsLength(ByRef Values() As SemanticFact) As Long
Attribute SemanticFactsLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function SemanticSourcesLength(ByRef Values() As SemanticSource) As Long
Attribute SemanticSourcesLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeSemanticFacts(ByRef Values() As SemanticFact, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticFacts.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function BoundNodesLength(ByRef Values() As BoundNode) As Long
Attribute BoundNodesLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeBoundNodes(ByRef Values() As BoundNode, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeBoundNodes.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function SemanticDeclarationsLength(ByRef Values() As SemanticDeclaration) As Long
Attribute SemanticDeclarationsLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeSemanticDeclarations(ByRef Values() As SemanticDeclaration, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticDeclarations.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function SemanticTypesLength(ByRef Values() As SemanticType) As Long
Attribute SemanticTypesLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeSemanticTypes(ByRef Values() As SemanticType, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticTypes.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function SemanticNamesLength(ByRef Values() As SemanticName) As Long
Attribute SemanticNamesLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeSemanticNames(ByRef Values() As SemanticName, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticNames.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function SemanticKeysLength(ByRef Values() As ByteKey) As Long
Attribute SemanticKeysLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeSemanticKeys(ByRef Values() As ByteKey, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticKeys.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function SemanticLongsLength(ByRef Values() As Long) As Long
Attribute SemanticLongsLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeSemanticLongs(ByRef Values() As Long, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticLongs.UBE_Primitive = "Array.TryResize"
End Function
Function FailSemanticBudget(ByRef Failure As SemanticFailure) As Boolean
    FailSemanticBudget = False
    Call ResetSemanticFailure(Failure)
    Failure.Kind = 2
    Failure.Code = 1427
End Function
Function FailSemanticDomain(ByRef Failure As SemanticFailure) As Boolean
    FailSemanticDomain = False
    Call ResetSemanticFailure(Failure)
    Failure.Kind = 1
    Failure.Code = 1426
End Function
Function TryAppendSemanticFact(ByVal Work As SemanticModuleWork, ByRef Original As SemanticFact, ByRef Id As Long) As Boolean
    TryAppendSemanticFact = False
    Id = -1
    Call ResetSemanticFailure(Work.Failure)
    If Work Is Nothing Then
        TryAppendSemanticFact = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Maximum As Long = Work.Limits.MaximumFacts
    If Work.MaximumFacts < Maximum Then
        Maximum = Work.MaximumFacts
    End If
    Dim FactCount As Long = Work.FactCount
    Dim ValueCount As Long = Work.ValueCount
    If Maximum < 0 Or FactCount < 0 Or ValueCount < 0 Then
        TryAppendSemanticFact = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If FactCount >= Maximum Or ValueCount >= Maximum - FactCount Then
        TryAppendSemanticFact = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Dim Count As Long = Work.FactCount
    Dim Capacity As Long = SemanticFactsLength(Work.Facts)
    Dim Prepared As Long = Capacity
    If TryGetStorageCapacity(Capacity, Count + 1, Maximum, Prepared) = False Then
        TryAppendSemanticFact = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Prepared <> Capacity Then
        If TryResizeSemanticFacts(Work.Facts, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Work.Failure)
    Call WriteSemanticFact(Work.Facts(Count), Original)
    Work.FactCount = Count + 1
    Work.Metrics.FactWrites = Work.Metrics.FactWrites + 1
    Id = Count
    TryAppendSemanticFact = True
End Function
Function TryAppendBoundNode(ByVal Work As SemanticModuleWork, ByRef Original As BoundNode, ByRef Id As Long) As Boolean
    TryAppendBoundNode = False
    Id = -1
    Call ResetSemanticFailure(Work.Failure)
    If Work Is Nothing Then
        TryAppendBoundNode = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim Maximum As Long = Work.Limits.MaximumFacts
    If Work.MaximumFacts < Maximum Then
        Maximum = Work.MaximumFacts
    End If
    Dim FactCount As Long = Work.FactCount
    Dim ValueCount As Long = Work.ValueCount
    If Maximum < 0 Or FactCount < 0 Or ValueCount < 0 Then
        TryAppendBoundNode = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If FactCount >= Maximum Or ValueCount >= Maximum - FactCount Then
        TryAppendBoundNode = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Dim Count As Long = Work.ValueCount
    Dim Capacity As Long = BoundNodesLength(Work.Values)
    Dim Prepared As Long = Capacity
    If TryGetStorageCapacity(Capacity, Count + 1, Maximum, Prepared) = False Then
        TryAppendBoundNode = FailSemanticBudget(Work.Failure)
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Prepared <> Capacity Then
        If TryResizeBoundNodes(Work.Values, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Work.Failure)
    Call WriteBoundNode(Work.Values(Count), Original)
    Work.ValueCount = Count + 1
    Work.Metrics.NodeWrites = Work.Metrics.NodeWrites + 1
    Id = Count
    TryAppendBoundNode = True
End Function
Function TryAppendCatalogFact(ByVal Catalog As SemanticCatalog, ByRef Original As SemanticFact, ByRef Id As Long, ByRef Failure As SemanticFailure) As Boolean
    TryAppendCatalogFact = False
    Id = -1
    Call ResetSemanticFailure(Failure)
    If Catalog Is Nothing Then
        TryAppendCatalogFact = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Maximum As Long = Catalog.Limits.MaximumFacts
    Dim FactCount As Long = Catalog.FactCount
    Dim ValueCount As Long = Catalog.ValueCount
    If Maximum < 0 Or FactCount < 0 Or ValueCount < 0 Then
        TryAppendCatalogFact = FailSemanticDomain(Failure)
        Exit Function
    End If
    If FactCount >= Maximum Or ValueCount >= Maximum - FactCount Then
        TryAppendCatalogFact = FailSemanticBudget(Failure)
        Exit Function
    End If
    Dim Count As Long = Catalog.FactCount
    Dim Capacity As Long = SemanticFactsLength(Catalog.Facts)
    Dim Prepared As Long = Capacity
    If TryGetStorageCapacity(Capacity, Count + 1, Maximum, Prepared) = False Then
        TryAppendCatalogFact = FailSemanticBudget(Failure)
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If Prepared <> Capacity Then
        If TryResizeSemanticFacts(Catalog.Facts, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Failure)
    Call WriteSemanticFact(Catalog.Facts(Count), Original)
    Catalog.FactCount = Count + 1
    Catalog.Metrics.FactWrites = Catalog.Metrics.FactWrites + 1
    Id = Count
    Call ResetSemanticFailure(Failure)
    TryAppendCatalogFact = True
End Function
Function TryAppendCatalogValue(ByVal Catalog As SemanticCatalog, ByRef Original As BoundNode, ByRef Id As Long, ByRef Failure As SemanticFailure) As Boolean
    TryAppendCatalogValue = False
    Id = -1
    Call ResetSemanticFailure(Failure)
    If Catalog Is Nothing Then
        TryAppendCatalogValue = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Maximum As Long = Catalog.Limits.MaximumFacts
    Dim FactCount As Long = Catalog.FactCount
    Dim ValueCount As Long = Catalog.ValueCount
    If Maximum < 0 Or FactCount < 0 Or ValueCount < 0 Then
        TryAppendCatalogValue = FailSemanticDomain(Failure)
        Exit Function
    End If
    If FactCount >= Maximum Or ValueCount >= Maximum - FactCount Then
        TryAppendCatalogValue = FailSemanticBudget(Failure)
        Exit Function
    End If
    Dim Count As Long = Catalog.ValueCount
    Dim Capacity As Long = BoundNodesLength(Catalog.Values)
    Dim Prepared As Long = Capacity
    If TryGetStorageCapacity(Capacity, Count + 1, Maximum, Prepared) = False Then
        TryAppendCatalogValue = FailSemanticBudget(Failure)
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If Prepared <> Capacity Then
        If TryResizeBoundNodes(Catalog.Values, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Failure)
    Call WriteBoundNode(Catalog.Values(Count), Original)
    Catalog.ValueCount = Count + 1
    Catalog.Metrics.NodeWrites = Catalog.Metrics.NodeWrites + 1
    Id = Count
    Call ResetSemanticFailure(Failure)
    TryAppendCatalogValue = True
End Function
Function TryLinkBoundChild(ByVal Work As SemanticModuleWork, ByVal Parent As Long, ByVal Child As Long, ByRef Tail As Long) As Boolean
    TryLinkBoundChild = False
    If Work Is Nothing Then
        Exit Function
    End If
    Call ResetSemanticFailure(Work.Failure)
    If Parent < 0 Or Parent >= Work.ValueCount Or Child < 0 Or Child >= Work.ValueCount Or Parent = Child Or Tail < -1 Or Tail >= Work.ValueCount Then
        TryLinkBoundChild = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    Dim ParentNode As BoundNode
    Dim ChildNode As BoundNode
    Call ReadBoundNode(ParentNode, Work.Values(Parent))
    Call ResetSemanticFailure(Work.Failure)
    Call ReadBoundNode(ChildNode, Work.Values(Child))
    If ChildNode.NextSibling <> -1 Or ParentNode.ChildCount >= Work.ValueCount Then
        TryLinkBoundChild = FailSemanticDomain(Work.Failure)
        Exit Function
    End If
    If Tail = -1 Then
        If ParentNode.ChildCount <> 0 Or ParentNode.FirstChild <> -1 Then
            TryLinkBoundChild = FailSemanticDomain(Work.Failure)
            Exit Function
        End If
        ParentNode.FirstChild = Child
    Else
        Dim LastNode As BoundNode
        Call ResetSemanticFailure(Work.Failure)
        Call ReadBoundNode(LastNode, Work.Values(Tail))
        If LastNode.NextSibling <> -1 Or ParentNode.ChildCount = 0 Then
            TryLinkBoundChild = FailSemanticDomain(Work.Failure)
            Exit Function
        End If
        LastNode.NextSibling = Child
        Call ResetSemanticFailure(Work.Failure)
        Call WriteBoundNode(Work.Values(Tail), LastNode)
    End If
    ParentNode.ChildCount = ParentNode.ChildCount + 1
    Call ResetSemanticFailure(Work.Failure)
    Call WriteBoundNode(Work.Values(Parent), ParentNode)
    Tail = Child
    TryLinkBoundChild = True
End Function
