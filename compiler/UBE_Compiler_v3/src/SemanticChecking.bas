UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticChecking"

' Compiler-owned context construction and complete publication. Every source
' owner is retained by reference; no original source/token/syntax payload copy.
Intrinsic Function TryResizeSemanticSources(ByRef Values() As SemanticSource, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticSources.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function SemanticModuleWorksLength(ByRef Values() As SemanticModuleWork) As Long
Attribute SemanticModuleWorksLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function SemanticInputWorksLength(ByRef Values() As SourceWork) As Long
Attribute SemanticInputWorksLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeSemanticModuleWorks(ByRef Values() As SemanticModuleWork, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticModuleWorks.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryResizeSemanticModuleResults(ByRef Values() As SemanticModuleResult, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticModuleResults.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryCopySemanticFacts(ByRef Destination() As SemanticFact, ByRef Original() As SemanticFact) As Boolean
Attribute TryCopySemanticFacts.UBE_Primitive = "Array.TryCopy"
End Function
Intrinsic Function TryCopyBoundNodes(ByRef Destination() As BoundNode, ByRef Original() As BoundNode) As Boolean
Attribute TryCopyBoundNodes.UBE_Primitive = "Array.TryCopy"
End Function

Function ValidSemanticLimits(ByRef Limits As SemanticLimits) As Boolean
    ValidSemanticLimits = Limits.MaximumDeclarations >= 0 And Limits.MaximumDeclarations <= 1048576 And Limits.MaximumFacts >= 0 And Limits.MaximumFacts <= 1048576 And Limits.MaximumPending >= 0 And Limits.MaximumPending <= 1048576 And Limits.MaximumDepth >= 0 And Limits.MaximumDepth <= 256
End Function

Private Function TryMakeSemanticSource(ByVal Catalog As SemanticCatalog, ByVal Work As SourceWork, ByRef Envelope As SourceEnvelope, ByVal SourceId As Long, ByVal PackageId As Long, ByRef Failure As SemanticFailure) As Boolean
    TryMakeSemanticSource = False
    Call ResetSemanticFailure(Failure)
    If Work Is Nothing Then
        TryMakeSemanticSource = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Work.State <> 1 Or Work.Owner Is Nothing Then
        TryMakeSemanticSource = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Work.Owner.SourceId <> SourceId Or SyntaxResultLength(Work.Syntax) <> 1 Then
        TryMakeSemanticSource = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Work.Syntax(0).SourceId <> SourceId Then
        TryMakeSemanticSource = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Envelope.Kind <> 1 Then
        Failure.Kind = 8
        Failure.Code = 1400
        Failure.SourceId = SourceId
        Exit Function
    End If
    Dim Source As SemanticSource
    Set Source = New SemanticSource
    If Source Is Nothing Then
        Exit Function
    End If
    Set Source.SyntaxInput = Work
    If (Source.SyntaxInput Is Work) = False Then
        Exit Function
    End If
    Source.Envelope = Envelope
    Source.SourceId = SourceId
    Source.PackageId = PackageId
    Source.ModuleDeclaration = SourceId
    Set Catalog.Sources(SourceId) = Source
    If (Catalog.Sources(SourceId) Is Source) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TryMakeSemanticSource = True
End Function

' Reserve against a conservative mathematical bound. A source whose estimate
' exceeds the entire remaining allowance runs alone with that actual allowance;
' estimates never reject an otherwise feasible source by themselves.
Private Function SemanticBoundedProduct(ByVal Count As Long, ByVal Factor As Long, ByVal Extra As Long) As Long
    SemanticBoundedProduct = 1048576
    If Count < 0 Or Factor < 0 Or Extra < 0 Or Extra >= 1048576 Then
        Exit Function
    End If
    If Factor = 0 Then
        SemanticBoundedProduct = Extra
        Exit Function
    End If
    If Count <= (1048576 - Extra) \ Factor Then
        SemanticBoundedProduct = Count * Factor + Extra
    End If
End Function

Private Function TryPublishSemanticModule(ByVal Work As SemanticModuleWork) As Boolean
    TryPublishSemanticModule = False
    Call ResetSemanticFailure(Work.Failure)
    Dim Prepared As SemanticModuleResult
    Set Prepared = New SemanticModuleResult
    If Prepared Is Nothing Then
        Exit Function
    End If
    Set Prepared.Catalog = Work.Catalog
    If (Prepared.Catalog Is Work.Catalog) = False Then
        Exit Function
    End If
    Prepared.SourceId = Work.Source.SourceId
    Prepared.Root = Work.Root
    Prepared.FactCount = Work.FactCount
    Prepared.ValueCount = Work.ValueCount
    Prepared.Metrics = Work.Metrics
    If SemanticFactsLength(Work.Facts) <> Work.FactCount Then
        If TryResizeSemanticFacts(Work.Facts, Work.FactCount, True) = False Then
            Exit Function
        End If
    End If
    If BoundNodesLength(Work.Values) <> Work.ValueCount Then
        If TryResizeBoundNodes(Work.Values, Work.ValueCount, True) = False Then
            Exit Function
        End If
    End If
    If TryCopySemanticFacts(Prepared.Facts, Work.Facts) = False Then
        Exit Function
    End If
    If TryCopyBoundNodes(Prepared.Values, Work.Values) = False Then
        Exit Function
    End If
    If TryContinueSemanticWork(Work) = False Then
        Exit Function
    End If
    Set Work.Result = Prepared
    If (Work.Result Is Prepared) = False Then
        Exit Function
    End If
    Work.Failure.Kind = 0
    Work.Failure.Code = 0
    TryPublishSemanticModule = True
End Function

' The static target shares only the frozen catalog/source owners. Body arrays,
' diagnostics and expression/statement stacks belong to this one Work object.
Sub ProcessSemanticModule(ByVal Work As SemanticModuleWork)
    If Work Is Nothing Then
        Exit Sub
    End If
    Call ResetSemanticFailure(Work.Failure)
    Work.State = 2
    If TryCurrentThreadId(Work.WorkerId) = False Then
        Exit Sub
    End If
    If TryContinueSemanticWork(Work) = False Then
        If Work.Failure.Kind = 4 Then
            Work.State = 3
        End If
        Exit Sub
    End If
    If TryBindSemanticModule(Work) Then
        Call ResetSemanticFailure(Work.Failure)
        If TryPublishSemanticModule(Work) Then
            Work.State = 1
            Exit Sub
        End If
    End If
    If Work.Failure.Kind = 4 Then
        Work.State = 3
    End If
End Sub

Private Sub RecordSemanticInfrastructure(ByRef Failure As SemanticFailure, ByVal Kind As Long, ByVal SourceId As Long)
    Dim Code As Long = 1428
    If Kind = 2 Then
        Code = 1427
    End If
    If Kind = 4 Then
        Code = 1429
    End If
    If Kind = 6 Then
        Code = 1436
    End If
    If Kind = 7 Then
        Code = 1437
    End If
    If Failure.Kind = 0 Or Failure.Kind = 3 Or Failure.Kind = 8 Then
        Call ResetSemanticFailure(Failure)
        Failure.Kind = Kind
        Failure.Code = Code
        Failure.SourceId = SourceId
    Else
        If Failure.Kind = Kind And SourceId >= 0 Then
            If Failure.SourceId < 0 Or SourceId < Failure.SourceId Then
                Failure.SourceId = SourceId
            End If
        End If
    End If
End Sub

Private Sub CopySourceWorkerSemanticFailure(ByRef Slots As SourceWorkerSlots, ByRef Failure As SemanticFailure)
    If Slots.FirstInfrastructureKind <> 0 Then
        Dim Kind As Long = 5
        If Slots.FirstInfrastructureKind = 2 Then
            Kind = 6
        End If
        If Slots.FirstInfrastructureKind = 4 Then
            Kind = 4
        End If
        If Slots.FirstInfrastructureKind = 6 Then
            Kind = 7
        End If
        Call RecordSemanticInfrastructure(Failure, Kind, Slots.FirstInfrastructureSource)
    End If
End Sub

' Managed admission can fail before any body executes. A fresh Boolean encloses
' every managed preparation/completion access while native IDs are outstanding;
' on False the caller closes admission and continues its rootless drain.
Private Function TryGetSemanticReservations(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal FactFactor As Long, ByVal PendingFactor As Long, ByRef FactReservation As Long, ByRef PendingReservation As Long) As Boolean
    TryGetSemanticReservations = False
    Dim Nodes As Long = Catalog.Sources(SourceId).SyntaxInput.Syntax(0).NodeCount
    If Nodes < 1 Then
        Exit Function
    End If
    FactReservation = SemanticBoundedProduct(Nodes, FactFactor, 16)
    PendingReservation = SemanticBoundedProduct(Nodes, PendingFactor, 8)
    TryGetSemanticReservations = True
End Function

Private Function TryPrepareSemanticAdmission(ByRef Pending() As SemanticModuleWork, ByVal SourceId As Long, ByVal FactReservation As Long, ByVal PendingReservation As Long, ByRef Selected As SemanticModuleWork) As Boolean
    TryPrepareSemanticAdmission = False
    Dim Work As SemanticModuleWork
    Set Work = Pending(SourceId)
    If Work Is Nothing Then
        Exit Function
    End If
    Work.MaximumFacts = FactReservation
    Work.MaximumPending = PendingReservation
    If Work.MaximumFacts <> FactReservation Or Work.MaximumPending <> PendingReservation Then
        Exit Function
    End If
    Set Selected = Work
    If (Selected Is Work) = False Then
        Exit Function
    End If
    TryPrepareSemanticAdmission = True
End Function

Private Function TryTakeSemanticCompletion(ByRef Pending() As SemanticModuleWork, ByVal SourceId As Long, ByRef Modules() As SemanticModuleResult, ByRef Used As Long, ByRef FactReservation As Long, ByRef PendingReservation As Long, ByRef UnitFailure As SemanticFailure) As Boolean
    TryTakeSemanticCompletion = False
    Call ResetSemanticFailure(UnitFailure)
    Dim Work As SemanticModuleWork
    Set Work = Pending(SourceId)
    If Work Is Nothing Then
        Exit Function
    End If
    FactReservation = Work.MaximumFacts
    PendingReservation = Work.MaximumPending
    Used = Work.FactCount + Work.ValueCount
    If Work.State = 1 Then
        If Work.Result Is Nothing Then
            Exit Function
        End If
        Set Modules(SourceId) = Work.Result
        If (Modules(SourceId) Is Work.Result) = False Then
            Exit Function
        End If
        UnitFailure.Kind = 0
        UnitFailure.Code = 0
    Else
        UnitFailure = Work.Failure
        If Work.State = 0 Or UnitFailure.Kind = 0 Then
            Call ResetSemanticFailure(UnitFailure)
        End If
    End If
    TryTakeSemanticCompletion = True
End Function

' The shared rootless source-slot controller owns native IDs and drain. Parser
' work is already complete before this invocation borrows that same Jobs budget.
Private Function TryBindSemanticSources(ByVal Catalog As SemanticCatalog, ByVal Jobs As Long, ByVal Cancellation As SourceCancellation, ByRef Modules() As SemanticModuleResult, ByRef Failure As SemanticFailure) As Boolean
    TryBindSemanticSources = False
    Call ResetSemanticFailure(Failure)
    Dim Pending() As SemanticModuleWork
    If TryResizeSemanticModuleWorks(Pending, Catalog.SourceCount, False) = False Then
        Exit Function
    End If
    If TryResizeSemanticModuleResults(Modules, Catalog.SourceCount, False) = False Then
        Exit Function
    End If
    Dim MaximumParameters As Long = 0
    Dim Index As Long = 0
    While Index < Catalog.DeclarationCount
        Dim Declaration As SemanticDeclaration
        Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(Index))
        If Declaration.ParameterCount > MaximumParameters Then
            MaximumParameters = Declaration.ParameterCount
        End If
        Index = Index + 1
    Wend
    Dim FactFactor As Long = 1048576
    Dim PendingFactor As Long = 1048576
    If MaximumParameters < 262140 Then
        FactFactor = 16 + 4 * MaximumParameters
    End If
    If MaximumParameters < 1048572 Then
        PendingFactor = 4 + MaximumParameters
    End If
    Index = 0
    While Index < Catalog.SourceCount
        Dim Work As SemanticModuleWork
        Set Work = Nothing
        Set Work = New SemanticModuleWork
        If Work Is Nothing Then
            Exit Function
        End If
        Set Work.Catalog = Catalog
        Set Work.Source = Catalog.Sources(Index)
        Set Work.Cancellation = Cancellation
        If (Work.Catalog Is Catalog) = False Or (Work.Source Is Catalog.Sources(Index)) = False Or (Work.Cancellation Is Cancellation) = False Then
            Exit Function
        End If
        Work.Limits = Catalog.Limits
        Call ResetSemanticFailure(Work.Failure)
        Set Pending(Index) = Work
        If (Pending(Index) Is Work) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    Dim Slots As SourceWorkerSlots
    If TryInitializeSourceWorkerSlots(Slots, Jobs, Catalog.SourceCount) = False Then
        TryBindSemanticSources = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Blank As SemanticFailure
    Failure = Blank
    Failure.SourceId = -1
    Failure.RelatedSourceId = -1
    Dim RemainingFacts As Long = Catalog.Limits.MaximumFacts - Catalog.FactCount - Catalog.ValueCount
    Dim MaximumPending As Long = Catalog.Limits.MaximumPending
    Dim ReservedFacts As Long = 0
    Dim ReservedPending As Long = 0
    Dim Finished As Boolean = False
    While Finished = False
        Dim NativeCancellation As Boolean = False
        If TryThreadStopRequested(NativeCancellation) = False Then
            Call RecordSourceWorkerFailure(Slots, 5, -1)
        End If
        Dim AllowAdmission As Boolean = False
        Dim FactReservation As Long = 0
        Dim PendingReservation As Long = 0
        If Slots.NextSource < Slots.Total And Slots.StopAdmission = False Then
            If TryGetSemanticReservations(Catalog, Slots.NextSource, FactFactor, PendingFactor, FactReservation, PendingReservation) = False Then
                Call RecordSourceWorkerFailure(Slots, 5, Slots.NextSource)
            Else
                If Slots.Active = 0 Then
                    If FactReservation > RemainingFacts Then
                        FactReservation = RemainingFacts
                    End If
                    If PendingReservation > MaximumPending Then
                        PendingReservation = MaximumPending
                    End If
                End If
                AllowAdmission = FactReservation <= RemainingFacts - ReservedFacts And PendingReservation <= MaximumPending - ReservedPending
            End If
        End If
        Dim Slot As Long = -1
        Dim SourceIndex As Long = -1
        Dim Action As Long = NextSourceWorkerAction(Slots, NativeCancellation Or Cancellation.Requested, AllowAdmission, Slot, SourceIndex)
        Call CopySourceWorkerSemanticFailure(Slots, Failure)
        If Action = 1 Then
            If TryPrepareSemanticAdmission(Pending, SourceIndex, FactReservation, PendingReservation, Work) = False Then
                Call RecordSourceWorkerFailure(Slots, 5, SourceIndex)
            Else
                ReservedFacts = ReservedFacts + FactReservation
                ReservedPending = ReservedPending + PendingReservation
                Dim Id As LongLong = CallNew ProcessSemanticModule(Work)
                Call CommitSourceWorkerAdmission(Slots, Slot, Id)
            End If
        Else
            If Action = 2 Then
                Dim Used As Long = 0
                Dim UnitFailure As SemanticFailure
                Call ResetSemanticFailure(UnitFailure)
                If TryTakeSemanticCompletion(Pending, SourceIndex, Modules, Used, FactReservation, PendingReservation, UnitFailure) = False Then
                    Call RecordSourceWorkerFailure(Slots, 5, SourceIndex)
                Else
                    ReservedFacts = ReservedFacts - FactReservation
                    ReservedPending = ReservedPending - PendingReservation
                    RemainingFacts = RemainingFacts - Used
                    If UnitFailure.Kind <> 0 Then
                        If UnitFailure.Kind = 3 Or UnitFailure.Kind = 8 Then
                            Call RecordSemanticDiagnostic(Failure, UnitFailure.Code, UnitFailure.SourceId, UnitFailure.FirstByte, UnitFailure.LastByte, UnitFailure.RelatedSourceId, UnitFailure.RelatedFirst, UnitFailure.RelatedLast)
                        Else
                            Dim Infrastructure As Long = 5
                            If UnitFailure.Kind = 2 Then
                                Infrastructure = 2
                            End If
                            If UnitFailure.Kind = 4 Then
                                Infrastructure = 4
                            End If
                            ' Source-slot kind2 means start failure; semantic
                            ' budget retains its own disposition in Failure.
                            Call RecordSemanticInfrastructure(Failure, Infrastructure, SourceIndex)
                            Call RecordSourceWorkerFailure(Slots, 5, SourceIndex)
                        End If
                    End If
                End If
            Else
                If Action = 3 Then
                    Finished = True
                End If
            End If
        End If
        Call CopySourceWorkerSemanticFailure(Slots, Failure)
    Wend
    If Failure.Kind <> 0 Then
        Exit Function
    End If
    TryBindSemanticSources = True
End Function

Private Function TrySemanticMainName(ByVal Catalog As SemanticCatalog, ByVal NameId As Long, ByRef Matches As Boolean, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticMainName = False
    Matches = False
    Call ResetSemanticFailure(Failure)
    Dim NameRecord As SemanticName
    If NameId < 0 Or NameId >= Catalog.NameCount Then
        TrySemanticMainName = FailSemanticDomain(Failure)
        Exit Function
    End If
    Call ReadSemanticName(NameRecord, Catalog.Names(NameId))
    If NameRecord.ByteCount = 4 Then
        Dim First As Long = NameRecord.ByteFirst
        Matches = Catalog.NameBytes.Storage(First) = 109 And Catalog.NameBytes.Storage(First + 1) = 97 And Catalog.NameBytes.Storage(First + 2) = 105 And Catalog.NameBytes.Storage(First + 3) = 110
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TrySemanticMainName = True
End Function

Private Function TrySelectSemanticEntry(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByRef Entry As Long, ByRef Failure As SemanticFailure) As Boolean
    TrySelectSemanticEntry = False
    Entry = -1
    Call ResetSemanticFailure(Failure)
    Dim Found As Long = 0
    Dim Second As Long = -1
    Dim Index As Long = 0
    While Index < Catalog.DeclarationCount
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Declaration As SemanticDeclaration
        Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(Index))
        If Declaration.Kind = 5 Or Declaration.Kind = 6 Then
            If Catalog.Sources(Declaration.SourceId).PackageId = 0 Then
                Dim Matches As Boolean = False
                If TrySemanticMainName(Catalog, Declaration.NameId, Matches, Failure) = False Then
                    Exit Function
                End If
                Call ResetSemanticFailure(Failure)
                If Matches Then
                    Found = Found + 1
                    If Found = 1 Then
                        Entry = Index
                    End If
                    If Found = 2 Then
                        Second = Index
                    End If
                End If
            End If
        End If
        Index = Index + 1
    Wend
    Dim Diagnostic As SemanticFailure
    If Found = 0 Then
        Dim Eof As Long = ByteStorageLength(Catalog.Sources(0).SyntaxInput.Owner.Document.Bytes)
        Call RecordSemanticDiagnostic(Diagnostic, 1422, 0, Eof, Eof, -1, 0, 0)
    Else
        Dim Candidate As Long = Entry
        If Found > 1 Then
            Candidate = Second
        End If
        Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(Candidate))
        If Found > 1 Or Declaration.ParameterCount <> 0 Or (Declaration.Kind = 6 And Declaration.TypeId <> 4) Or (Declaration.Flags And 16) <> 0 Then
            Dim NameRecord As SemanticName
            Call ReadSemanticName(NameRecord, Catalog.Names(Declaration.NameId))
            Dim WrittenName As SyntaxNode
            If TryReadCatalogSyntax(Catalog, Declaration.SourceId, NameRecord.SyntaxId, WrittenName, Failure) = False Then
                Exit Function
            End If
            Call RecordSemanticDiagnostic(Diagnostic, 1422, Declaration.SourceId, WrittenName.FirstByte, WrittenName.LastByte, -1, 0, 0)
        End If
    End If
    If Diagnostic.Kind <> 0 Then
        Failure = Diagnostic
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TrySelectSemanticEntry = True
End Function

Private Function TryFinishSemanticChecking(ByVal Catalog As SemanticCatalog, ByVal Jobs As Long, ByVal Cancellation As SourceCancellation, ByRef Published As SemanticResult, ByRef Failure As SemanticFailure) As Boolean
    TryFinishSemanticChecking = False
    Call ResetSemanticFailure(Failure)
    If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryBuildSemanticDeclarations(Catalog, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If TryPrepareSemanticConstants(Catalog, Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    Dim Prepared As SemanticResult
    Set Prepared = New SemanticResult
    If Prepared Is Nothing Then
        Exit Function
    End If
    Set Prepared.Catalog = Catalog
    If (Prepared.Catalog Is Catalog) = False Then
        Exit Function
    End If
    If TryBindSemanticSources(Catalog, Jobs, Cancellation, Prepared.Modules, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If TrySelectSemanticEntry(Catalog, Cancellation, Prepared.EntryDeclaration, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    Set Published = Prepared
    If (Published Is Prepared) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TryFinishSemanticChecking = True
End Function

Function TryCheckProjectSemantics(ByVal SyntaxInput As ProjectSyntax, ByVal Jobs As Long, ByRef Limits As SemanticLimits, ByVal Cancellation As SourceCancellation, ByRef Published As SemanticResult, ByRef Failure As SemanticFailure) As Boolean
    TryCheckProjectSemantics = False
    Call ResetSemanticFailure(Failure)
    If SyntaxInput Is Nothing Or Cancellation Is Nothing Then
        TryCheckProjectSemantics = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Jobs < 1 Or Jobs > 4 Or ValidSemanticLimits(Limits) = False Then
        TryCheckProjectSemantics = FailSemanticDomain(Failure)
        Exit Function
    End If
    If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
        Exit Function
    End If
    If SyntaxInput.Project Is Nothing Then
        TryCheckProjectSemantics = FailSemanticDomain(Failure)
        Exit Function
    End If
    If SyntaxInput.Project.Validated = False Or SyntaxInput.Project.SourceCount < 1 Or SyntaxInput.Project.SourceCount > 256 Or SyntaxInput.Project.PackageCount < 1 Or SyntaxInput.Project.PackageCount > 2 Then
        TryCheckProjectSemantics = FailSemanticDomain(Failure)
        Exit Function
    End If
    If SemanticInputWorksLength(SyntaxInput.Work) <> SyntaxInput.Project.SourceCount Then
        TryCheckProjectSemantics = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Catalog As SemanticCatalog
    Set Catalog = New SemanticCatalog
    If Catalog Is Nothing Then
        Exit Function
    End If
    Set Catalog.SyntaxInput = SyntaxInput
    If (Catalog.SyntaxInput Is SyntaxInput) = False Then
        Exit Function
    End If
    Catalog.SourceCount = SyntaxInput.Project.SourceCount
    Catalog.PackageCount = SyntaxInput.Project.PackageCount
    Catalog.Limits = Limits
    If TryResizeSemanticSources(Catalog.Sources, Catalog.SourceCount, False) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Catalog.SourceCount
        Call ResetSemanticFailure(Failure)
        If TryMakeSemanticSource(Catalog, SyntaxInput.Work(Index), SyntaxInput.Project.Sources(Index).Envelope, Index, SyntaxInput.Project.Sources(Index).PackageId, Failure) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    Call ResetSemanticFailure(Failure)
    TryCheckProjectSemantics = TryFinishSemanticChecking(Catalog, Jobs, Cancellation, Published, Failure)
End Function

Function TryCheckSourceSemantics(ByVal SyntaxInput As SourceWork, ByRef Envelope As SourceEnvelope, ByVal Jobs As Long, ByRef Limits As SemanticLimits, ByVal Cancellation As SourceCancellation, ByRef Published As SemanticResult, ByRef Failure As SemanticFailure) As Boolean
    TryCheckSourceSemantics = False
    Call ResetSemanticFailure(Failure)
    If SyntaxInput Is Nothing Or Cancellation Is Nothing Then
        TryCheckSourceSemantics = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Jobs < 1 Or Jobs > 4 Or ValidSemanticLimits(Limits) = False Then
        TryCheckSourceSemantics = FailSemanticDomain(Failure)
        Exit Function
    End If
    If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Catalog As SemanticCatalog
    Set Catalog = New SemanticCatalog
    If Catalog Is Nothing Then
        Exit Function
    End If
    Catalog.SourceCount = 1
    Catalog.PackageCount = 1
    Catalog.Limits = Limits
    If TryResizeSemanticSources(Catalog.Sources, 1, False) = False Then
        Exit Function
    End If
    If TryMakeSemanticSource(Catalog, SyntaxInput, Envelope, 0, 0, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    TryCheckSourceSemantics = TryFinishSemanticChecking(Catalog, Jobs, Cancellation, Published, Failure)
End Function
