UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticNames"
Function TrySemanticNameWord(ByVal Catalog As SemanticCatalog, ByVal NameId As Long, ByVal Expected As String, ByRef Matches As Boolean, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticNameWord = False
    Matches = False
    Call ResetSemanticFailure(Failure)
    If NameId < 0 Or NameId >= Catalog.NameCount Then
        TrySemanticNameWord = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim NameRecord As SemanticName
    Call ReadSemanticName(NameRecord, Catalog.Names(NameId))
    If NameRecord.ByteCount = StringLength(Expected) Then
        Matches = True
        Dim AtByte As Long = 0
        While Matches And AtByte < NameRecord.ByteCount
            Matches = Catalog.NameBytes.Storage(NameRecord.ByteFirst + AtByte) = StringByteAt(Expected, AtByte)
            AtByte = AtByte + 1
        Wend
    End If
    TrySemanticNameWord = True
End Function

Function TryReadCatalogSyntax(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal SyntaxId As Long, ByRef Node As SyntaxNode, ByRef Failure As SemanticFailure) As Boolean
    TryReadCatalogSyntax = False
    Call ResetSemanticFailure(Failure)
    If Catalog Is Nothing Then
        TryReadCatalogSyntax = FailSemanticDomain(Failure)
        Exit Function
    End If
    If SourceId < 0 Or SourceId >= Catalog.SourceCount Then
        TryReadCatalogSyntax = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Source As SemanticSource
    If TryRetainSemanticSource(Catalog.Sources(SourceId), Source) = False Then
        Exit Function
    End If
    If Source Is Nothing Then
        TryReadCatalogSyntax = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Work As SourceWork
    If TryRetainSemanticWork(Source.SyntaxInput, Work) = False Then
        Exit Function
    End If
    If Work Is Nothing Then
        TryReadCatalogSyntax = FailSemanticDomain(Failure)
        Exit Function
    End If
    If SyntaxResultLength(Work.Syntax) <> 1 Then
        TryReadCatalogSyntax = FailSemanticDomain(Failure)
        Exit Function
    End If
    If SyntaxId < 0 Or SyntaxId >= Work.Syntax(0).NodeCount Then
        TryReadCatalogSyntax = FailSemanticDomain(Failure)
        Exit Function
    End If
    Call ReadSyntaxNode(Node, Work.Syntax(0).Nodes(SyntaxId))
    Call ResetSemanticFailure(Failure)
    TryReadCatalogSyntax = True
End Function

Function TrySemanticNamesEqual(ByVal Catalog As SemanticCatalog, ByVal LeftId As Long, ByVal RightId As Long, ByRef Matches As Boolean, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticNamesEqual = False
    Matches = False
    Call ResetSemanticFailure(Failure)
    If LeftId < 0 Or LeftId >= Catalog.NameCount Or RightId < 0 Or RightId >= Catalog.NameCount Then
        TrySemanticNamesEqual = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Left As SemanticName
    Dim Right As SemanticName
    Call ReadSemanticName(Left, Catalog.Names(LeftId))
    Call ReadSemanticName(Right, Catalog.Names(RightId))
    If Left.ByteCount = Right.ByteCount Then
        Matches = True
        Dim Index As Long = 0
        While Matches And Index < Left.ByteCount
            Matches = Catalog.NameBytes.Storage(Left.ByteFirst + Index) = Catalog.NameBytes.Storage(Right.ByteFirst + Index)
            Index = Index + 1
        Wend
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TrySemanticNamesEqual = True
End Function

' Only parser-qualified token/name extents enter this comparison.
Function TrySemanticWord(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByRef Node As SyntaxNode, ByVal Expected As String, ByRef Matches As Boolean, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticWord = False
    Matches = False
    Call ResetSemanticFailure(Failure)
    Dim AtByte As Long = Node.FirstByte
    Dim AtText As Long = 0
    Dim Length As Long = StringLength(Expected)
    While AtByte < Node.LastByte And AtText < Length
        Dim Scalar As Long = 0
        Dim ScalarWidth As Long = 0
        If TryReadSourceScalar(Catalog.Sources(SourceId).SyntaxInput.Owner.Document.Bytes, AtByte, Scalar, ScalarWidth) = False Then
            Exit Function
        End If
        If SimpleFoldUnicode(Scalar) <> StringByteAt(Expected, AtText) Then
            Call ResetSemanticFailure(Failure)
            TrySemanticWord = True
            Exit Function
        End If
        AtByte = AtByte + ScalarWidth
        AtText = AtText + 1
    Wend
    Matches = AtByte = Node.LastByte And AtText = Length
    Call ResetSemanticFailure(Failure)
    TrySemanticWord = True
End Function

Function TryAppendSemanticScalar(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByVal Scalar As Long, ByRef Failure As SemanticFailure) As Boolean
    TryAppendSemanticScalar = False
    Call ResetSemanticFailure(Failure)
    Dim B0 As Byte = 0
    Dim B1 As Byte = 0
    Dim B2 As Byte = 0
    Dim B3 As Byte = 0
    Dim ScalarWidth As Long = 0
    If TryEncodeUtf8Scalar(Scalar, B0, B1, B2, B3, ScalarWidth) = False Then
        TryAppendSemanticScalar = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Catalog.NameBytes.Count > 2147483647 - ScalarWidth Then
        TryAppendSemanticScalar = FailSemanticBudget(Failure)
        Exit Function
    End If
    If TryAppendByte(Catalog.NameBytes, B0) = False Then
        Exit Function
    End If
    If ScalarWidth >= 2 Then
        If TryAppendByte(Catalog.NameBytes, B1) = False Then
            Exit Function
        End If
    End If
    If ScalarWidth >= 3 Then
        If TryAppendByte(Catalog.NameBytes, B2) = False Then
            Exit Function
        End If
    End If
    If ScalarWidth = 4 Then
        If TryAppendByte(Catalog.NameBytes, B3) = False Then
            Exit Function
        End If
    End If
    Catalog.Metrics.CanonicalScalars = Catalog.Metrics.CanonicalScalars + 1
    Catalog.Metrics.CanonicalBytes = Catalog.Metrics.CanonicalBytes + ScalarWidth
    Call ResetSemanticFailure(Failure)
    TryAppendSemanticScalar = True
End Function

Function TryAppendSemanticName(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByVal SourceId As Long, ByVal SyntaxId As Long, ByVal FirstByte As Long, ByVal LastByte As Long, ByVal Quoted As Boolean, ByRef NameId As Long, ByRef Failure As SemanticFailure) As Boolean
    TryAppendSemanticName = False
    NameId = -1
    Call ResetSemanticFailure(Failure)
    Dim NameRecord As SemanticName
    NameRecord.SourceId = SourceId
    NameRecord.SyntaxId = SyntaxId
    NameRecord.FirstByte = FirstByte
    NameRecord.LastByte = LastByte
    NameRecord.ByteFirst = Catalog.NameBytes.Count
    Dim AtByte As Long = FirstByte
    Dim EndByte As Long = LastByte
    If Quoted Then
        AtByte = AtByte + 1
        EndByte = EndByte - 1
    End If
    Dim Bracketed As Boolean = False
    If AtByte < EndByte Then
        Bracketed = Catalog.Sources(SourceId).SyntaxInput.Owner.Document.Bytes(AtByte) = 91
    End If
    If Bracketed Then
        AtByte = AtByte + 1
        EndByte = EndByte - 1
    End If
    While AtByte < EndByte
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Scalar As Long = 0
        Call ResetSemanticFailure(Failure)
        If Quoted Then
            If TryReadProjectNameScalar(Catalog.Sources(SourceId).SyntaxInput.Owner.Document, EndByte, Bracketed, AtByte, Scalar) = False Then
                Exit Function
            End If
        Else
            Dim ScalarWidth As Long = 0
            If TryReadSourceScalar(Catalog.Sources(SourceId).SyntaxInput.Owner.Document.Bytes, AtByte, Scalar, ScalarWidth) = False Then
                Exit Function
            End If
            If Bracketed And Scalar = 93 Then
                ScalarWidth = 2
            End If
            If ScalarWidth > EndByte - AtByte Then
                TryAppendSemanticName = FailSemanticDomain(Failure)
                Exit Function
            End If
            AtByte = AtByte + ScalarWidth
            Scalar = SimpleFoldUnicode(Scalar)
        End If
        If TryAppendSemanticScalar(Catalog, Cancellation, Scalar, Failure) = False Then
            Exit Function
        End If
    Wend
    Call ResetSemanticFailure(Failure)
    NameRecord.ByteCount = Catalog.NameBytes.Count - NameRecord.ByteFirst
    Dim Capacity As Long = SemanticNamesLength(Catalog.Names)
    Dim Prepared As Long = Capacity
    If Catalog.NameCount = 2147483647 Then
        TryAppendSemanticName = FailSemanticBudget(Failure)
        Exit Function
    End If
    If TryGetStorageCapacity(Capacity, Catalog.NameCount + 1, 2147483647, Prepared) = False Then
        TryAppendSemanticName = FailSemanticBudget(Failure)
        Exit Function
    End If
    If Prepared <> Capacity Then
        If TryResizeSemanticNames(Catalog.Names, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Call WriteSemanticName(Catalog.Names(Catalog.NameCount), NameRecord)
    NameId = Catalog.NameCount
    Catalog.NameCount = Catalog.NameCount + 1
    Call ResetSemanticFailure(Failure)
    TryAppendSemanticName = True
End Function

Function TryGetSemanticName(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal SyntaxId As Long, ByRef NameId As Long, ByRef Failure As SemanticFailure) As Boolean
    TryGetSemanticName = False
    NameId = -1
    Call ResetSemanticFailure(Failure)
    If Catalog Is Nothing Then
        TryGetSemanticName = FailSemanticDomain(Failure)
        Exit Function
    End If
    If SourceId < 0 Or SourceId >= Catalog.SourceCount Then
        TryGetSemanticName = FailSemanticDomain(Failure)
        Exit Function
    End If
    If SyntaxId < 0 Or SyntaxId >= SemanticLongsLength(Catalog.Sources(SourceId).NameMap) Then
        TryGetSemanticName = FailSemanticDomain(Failure)
        Exit Function
    End If
    NameId = Catalog.Sources(SourceId).NameMap(SyntaxId) - 1
    If NameId < 0 Or NameId >= Catalog.NameCount Then
        TryGetSemanticName = FailSemanticDomain(Failure)
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TryGetSemanticName = True
End Function

Function TryPrepareSemanticNames(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByRef Failure As SemanticFailure) As Boolean
    TryPrepareSemanticNames = False
    Call ResetSemanticFailure(Failure)
    Dim SourceId As Long = 0
    While SourceId < Catalog.SourceCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        Dim Source As SemanticSource
        If TryRetainSemanticSource(Catalog.Sources(SourceId), Source) = False Then
        Exit Function
    End If
        If Source Is Nothing Then
            TryPrepareSemanticNames = FailSemanticDomain(Failure)
            Exit Function
        End If
        Dim Work As SourceWork
        If TryRetainSemanticWork(Source.SyntaxInput, Work) = False Then
        Exit Function
    End If
        If Work Is Nothing Then
            TryPrepareSemanticNames = FailSemanticDomain(Failure)
            Exit Function
        End If
        Dim Count As Long = Work.Syntax(0).NodeCount
        If TryResizeSemanticLongs(Source.NameMap, Count, False) = False Then
            Exit Function
        End If
        Dim Index As Long = 0
        While Index < Count
            Call ResetSemanticFailure(Failure)
            If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
                Exit Function
            End If
            Dim Node As SyntaxNode
            Call ResetSemanticFailure(Failure)
            If TryReadCatalogSyntax(Catalog, SourceId, Index, Node, Failure) = False Then
                Exit Function
            End If
            If Node.Kind = 1 Then
                Dim LastByte As Long = Node.LastByte
                If Node.FirstChild >= 0 Then
                    Dim Suffix As SyntaxNode
                    If TryReadCatalogSyntax(Catalog, SourceId, Node.FirstChild, Suffix, Failure) = False Then
                        Exit Function
                    End If
                    If Suffix.Kind = 83 Then
                        LastByte = Suffix.FirstByte
                    End If
                End If
                Dim NameId As Long = -1
                If TryAppendSemanticName(Catalog, Cancellation, SourceId, Index, Node.FirstByte, LastByte, False, NameId, Failure) = False Then
                    Exit Function
                End If
                Call ResetSemanticFailure(Failure)
                Source.NameMap(Index) = NameId + 1
            End If
            Index = Index + 1
        Wend
        SourceId = SourceId + 1
    Wend
    Call ResetSemanticFailure(Failure)
    TryPrepareSemanticNames = True
End Function

' Lookup is partitioned; no search falls back after a noncallable match.
Function TrySemanticPartition(ByVal Catalog As SemanticCatalog, ByVal Partition As Long, ByVal NameId As Long, ByRef DeclId As Long, ByRef MatchCount As Long, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticPartition = False
    DeclId = -1
    MatchCount = 0
    Call ResetSemanticFailure(Failure)
    If Catalog Is Nothing Then
        TrySemanticPartition = FailSemanticDomain(Failure)
        Exit Function
    End If
    If NameId < 0 Or NameId >= Catalog.NameCount Then
        TrySemanticPartition = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim NameRecord As SemanticName
    Call ReadSemanticName(NameRecord, Catalog.Names(NameId))
    Dim FirstMatch As Long = 0
    Dim Status As Long = 5
    If TryFindByteKeyRange(Catalog.NameBytes.Storage, Catalog.Keys, Catalog.Order, Partition, NameRecord.ByteFirst, NameRecord.ByteCount, FirstMatch, MatchCount, Status) = False Then
        If Status <> 5 Then
            TrySemanticPartition = FailSemanticDomain(Failure)
        End If
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If MatchCount > 0 Then
        DeclId = Catalog.Keys(Catalog.Order(FirstMatch)).Value
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TrySemanticPartition = True
End Function

Function TryLookupSemanticName(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal ScopeDeclId As Long, ByVal NameId As Long, ByVal AssignmentTarget As Boolean, ByRef DeclId As Long, ByRef LookupLevel As Long, ByRef Failure As SemanticFailure) As Boolean
    TryLookupSemanticName = False
    DeclId = -1
    LookupLevel = 0
    Call ResetSemanticFailure(Failure)
    If Catalog Is Nothing Then
        TryLookupSemanticName = FailSemanticDomain(Failure)
        Exit Function
    End If
    If SourceId < 0 Or SourceId >= Catalog.SourceCount Or ScopeDeclId < 0 Or ScopeDeclId >= Catalog.DeclarationCount Or NameId < 0 Or NameId >= Catalog.NameCount Then
        TryLookupSemanticName = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Level As Long = 1
    Dim PackageId As Long = Catalog.Sources(SourceId).PackageId
    Dim Partition As Long = ScopeDeclId + 1
    While Level <= 5
        Call ResetSemanticFailure(Failure)
        Dim Search As Boolean = True
        If Level = 1 And ScopeDeclId < Catalog.SourceCount Then
            Search = False
        End If
        If Level = 2 Then
            Search = False
            If AssignmentTarget And ScopeDeclId >= Catalog.SourceCount Then
                Dim Procedure As SemanticDeclaration
                Call ReadSemanticDeclaration(Procedure, Catalog.Declarations(ScopeDeclId))
                If Procedure.Kind = 6 Then
                    Dim Current As SemanticName
                    Dim Query As SemanticName
                    Call ReadSemanticName(Current, Catalog.Names(Procedure.NameId))
                    Call ReadSemanticName(Query, Catalog.Names(NameId))
                    Dim Equal As Boolean = Current.ByteCount = Query.ByteCount
                    Dim AtByte As Long = 0
                    While Equal And AtByte < Current.ByteCount
                        Equal = Catalog.NameBytes.Storage(Current.ByteFirst + AtByte) = Catalog.NameBytes.Storage(Query.ByteFirst + AtByte)
                        AtByte = AtByte + 1
                    Wend
                    If Equal Then
                        DeclId = ScopeDeclId
                        LookupLevel = 2
                        Failure.Kind = 0
                        Failure.Code = 0
                        TryLookupSemanticName = True
                        Exit Function
                    End If
                End If
            End If
        End If
        If Level = 3 Then
            Partition = SourceId + 1
        End If
        If Level = 4 Then
            Partition = Catalog.DeclarationCount + 1 + PackageId
        End If
        If Level = 5 Then
            Partition = Catalog.DeclarationCount + 1 + Catalog.PackageCount + PackageId
        End If
        If Search Then
            Dim Count As Long = 0
            If TrySemanticPartition(Catalog, Partition, NameId, DeclId, Count, Failure) = False Then
                Exit Function
            End If
            Call ResetSemanticFailure(Failure)
            If Count > 1 Then
                Dim NameRecord As SemanticName
                Call ResetSemanticFailure(Failure)
                Call ReadSemanticName(NameRecord, Catalog.Names(NameId))
                Dim Diagnostic As SemanticFailure
                Call RecordSemanticDiagnostic(Diagnostic, 1407, SourceId, NameRecord.FirstByte, NameRecord.LastByte, -1, 0, 0)
                Failure = Diagnostic
                Exit Function
            End If
            If Count = 1 Then
                LookupLevel = Level
                Failure.Kind = 0
                Failure.Code = 0
                TryLookupSemanticName = True
                Exit Function
            End If
        End If
        Level = Level + 1
    Wend
    DeclId = -1
    LookupLevel = 0
    Failure.Kind = 0
    Failure.Code = 0
    TryLookupSemanticName = True
End Function

Function TryLookupSemanticQualified(ByVal Catalog As SemanticCatalog, ByVal CurrentSourceId As Long, ByVal ModuleNameId As Long, ByVal MemberNameId As Long, ByRef DeclId As Long, ByRef ModuleDeclId As Long, ByRef Failure As SemanticFailure) As Boolean
    TryLookupSemanticQualified = False
    DeclId = -1
    ModuleDeclId = -1
    Call ResetSemanticFailure(Failure)
    If Catalog Is Nothing Then
        TryLookupSemanticQualified = FailSemanticDomain(Failure)
        Exit Function
    End If
    If CurrentSourceId < 0 Or CurrentSourceId >= Catalog.SourceCount Or ModuleNameId < 0 Or ModuleNameId >= Catalog.NameCount Or MemberNameId < 0 Or MemberNameId >= Catalog.NameCount Then
        TryLookupSemanticQualified = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim Count As Long = 0
    If TrySemanticPartition(Catalog, 0, ModuleNameId, ModuleDeclId, Count, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    Dim Code As Long = 0
    If Count = 0 Then
        Code = 1406
    End If
    If Count > 1 Then
        Code = 1407
    End If
    If Code = 0 Then
        If TrySemanticPartition(Catalog, ModuleDeclId + 1, MemberNameId, DeclId, Count, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        If Count = 0 Then
            Code = 1406
        End If
        If Count > 1 Then
            Code = 1407
        End If
        If Count = 1 Then
            Dim Declaration As SemanticDeclaration
            Call ResetSemanticFailure(Failure)
            Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(DeclId))
            Dim OwnPackage As Long = Catalog.Sources(CurrentSourceId).PackageId
            Dim OtherPackage As Long = Catalog.Sources(ModuleDeclId).PackageId
            Dim Visibility As Long = Declaration.Flags And 3
            If ModuleDeclId <> CurrentSourceId Then
                If Visibility = 2 Then
                    Code = 1408
                End If
                If OwnPackage <> OtherPackage Then
                    If Visibility <> 1 Or Catalog.Sources(ModuleDeclId).PrivateModule <> 0 Then
                        Code = 1408
                    End If
                End If
            End If
        End If
    End If
    If Code <> 0 Then
        Dim NameRecord As SemanticName
        Call ResetSemanticFailure(Failure)
        Call ReadSemanticName(NameRecord, Catalog.Names(MemberNameId))
        Dim Diagnostic As SemanticFailure
        Call RecordSemanticDiagnostic(Diagnostic, Code, CurrentSourceId, NameRecord.FirstByte, NameRecord.LastByte, -1, 0, 0)
        Failure = Diagnostic
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TryLookupSemanticQualified = True
End Function
