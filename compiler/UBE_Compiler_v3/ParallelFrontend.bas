UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerFrontend"

Dim ParallelResultSlot0 As ParallelFrontendResult
Dim ParallelResultSlot1 As ParallelFrontendResult
Dim ParallelResultSlot2 As ParallelFrontendResult
Dim ParallelResultSlot3 As ParallelFrontendResult
Dim ParallelResultSlot4 As ParallelFrontendResult
Dim ParallelResultSlot5 As ParallelFrontendResult
Dim ParallelResultSlot6 As ParallelFrontendResult
Dim ParallelResultSlot7 As ParallelFrontendResult
Dim ParallelResultSlot8 As ParallelFrontendResult
Dim ParallelResultSlot9 As ParallelFrontendResult
Dim ParallelResultSlot10 As ParallelFrontendResult
Dim ParallelResultSlot11 As ParallelFrontendResult
Dim ParallelResultSlot12 As ParallelFrontendResult
Dim ParallelResultSlot13 As ParallelFrontendResult
Dim ParallelResultSlot14 As ParallelFrontendResult
Dim ParallelResultSlot15 As ParallelFrontendResult
Dim ParallelResultSlot16 As ParallelFrontendResult
Dim ParallelResultSlot17 As ParallelFrontendResult
Dim ParallelResultSlot18 As ParallelFrontendResult
Dim ParallelResultSlot19 As ParallelFrontendResult
Dim ParallelResultSlot20 As ParallelFrontendResult
Dim ParallelResultSlot21 As ParallelFrontendResult
Dim ParallelResultSlot22 As ParallelFrontendResult
Dim ParallelResultSlot23 As ParallelFrontendResult
Dim ParallelResultSlot24 As ParallelFrontendResult
Dim ParallelResultSlot25 As ParallelFrontendResult
Dim ParallelResultSlot26 As ParallelFrontendResult
Dim ParallelResultSlot27 As ParallelFrontendResult
Dim ParallelResultSlot28 As ParallelFrontendResult
Dim ParallelResultSlot29 As ParallelFrontendResult
Dim ParallelResultSlot30 As ParallelFrontendResult
Dim ParallelResultSlot31 As ParallelFrontendResult
Public ParallelGrammarLoadLock As ParallelFrontendResult
Public ParallelParseReadyCount As Long
Public ParallelParseExpectedCount As Long
Public ParallelParseReleased As Long

Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

Function ParallelStringComesBefore(ByVal LeftValue As String, ByVal RightValue As String) As Long
    Dim LeftLength As Long = StringLength(LeftValue)
    Dim RightLength As Long = StringLength(RightValue)
    Dim SharedLength As Long = LeftLength
    If RightLength < SharedLength Then
        SharedLength = RightLength
    End If
    Dim Index As Long = 0
    While Index < SharedLength
        Dim LeftByte As Long = StringByteAt(LeftValue, Index)
        Dim RightByte As Long = StringByteAt(RightValue, Index)
        If LeftByte < RightByte Then
            ParallelStringComesBefore = 1
            Exit Function
        End If
        If LeftByte > RightByte Then
            ParallelStringComesBefore = 0
            Exit Function
        End If
        Index = Index + 1
    Wend
    If LeftLength < RightLength Then
        ParallelStringComesBefore = 1
    Else
        ParallelStringComesBefore = 0
    End If
End Function

Function ParallelDiagnosticComesBefore(ByRef LeftValue As CompilerDiagnostic, ByRef RightValue As CompilerDiagnostic) As Long
    If LeftValue.FilePath <> RightValue.FilePath Then
        ParallelDiagnosticComesBefore = ParallelStringComesBefore(LeftValue.FilePath, RightValue.FilePath)
        Exit Function
    End If
    If LeftValue.LineNumber <> RightValue.LineNumber Then
        If LeftValue.LineNumber < RightValue.LineNumber Then
            ParallelDiagnosticComesBefore = 1
        Else
            ParallelDiagnosticComesBefore = 0
        End If
        Exit Function
    End If
    If LeftValue.ColumnNumber <> RightValue.ColumnNumber Then
        If LeftValue.ColumnNumber < RightValue.ColumnNumber Then
            ParallelDiagnosticComesBefore = 1
        Else
            ParallelDiagnosticComesBefore = 0
        End If
        Exit Function
    End If
    If LeftValue.Code <> RightValue.Code Then
        ParallelDiagnosticComesBefore = ParallelStringComesBefore(LeftValue.Code, RightValue.Code)
        Exit Function
    End If
    ParallelDiagnosticComesBefore = ParallelStringComesBefore(LeftValue.Message, RightValue.Message)
End Function

Sub SortParallelDiagnostics(ByRef Diagnostics() As CompilerDiagnostic, ByVal DiagnosticCount As Long)
    Dim Index As Long = 1
    While Index < DiagnosticCount
        Dim Value As CompilerDiagnostic = Diagnostics(Index)
        Dim Position As Long = Index
        While Position > 0 And ParallelDiagnosticComesBefore(Value, Diagnostics(Position - 1)) <> 0
            Diagnostics(Position) = Diagnostics(Position - 1)
            Position = Position - 1
        Wend
        Diagnostics(Position) = Value
        Index = Index + 1
    Wend
End Sub

Sub ParallelLexWorker(ByVal Result As ParallelFrontendResult)
    Dim Source As SourceDocument
    Source.SourceId = Result.SourceId
    Source.FilePath = Result.SourceFilePath
    Source.Contents = Result.SourceContents
    Source.CombinedStartByte = Result.SourceCombinedStartByte
    Source.ByteLength = Result.SourceByteLength
    Source.LocationByte = 0
    Source.LocationLine = 1
    Source.LocationColumn = 1
    Source.ReferenceDepth = Result.SourceReferenceDepth
    Dim Tokens() As LexicalToken
    Dim TokenCount As Long = 0
    Dim TokenCapacity As Long = 0
    Dim SyntaxNodes() As SyntaxNode
    Dim SyntaxNodeCount As Long = 0
    Dim SyntaxNodeCapacity As Long = 0
    Dim SyntaxLinks() As SyntaxChildLink
    Dim SyntaxLinkCount As Long = 0
    Dim SyntaxLinkCapacity As Long = 0
    Dim Diagnostics() As CompilerDiagnostic
    Dim DiagnosticCount As Long = 0
    Dim DiagnosticCapacity As Long = 0
    Dim PreprocessedText As String = ""
    If PreprocessOneSource(Source, PreprocessedText, Diagnostics, DiagnosticCount, DiagnosticCapacity) <> 0 Then
        Call LexOneSource(Source, PreprocessedText, Tokens, TokenCount, TokenCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    End If
    If DiagnosticCount = 0 And Result.ParseRequested <> 0 Then
        Dim GrammarRules() As GrammarRule
        Dim GrammarRuleCount As Long = 0
        Dim GrammarNodes() As GrammarExpression
        Dim GrammarNodeCount As Long = 0
        Dim GrammarLinks() As GrammarChildLink
        Dim GrammarLinkCount As Long = 0
        SyncLock ParallelGrammarLoadLock
            Call LoadGrammarModel(GrammarRules, GrammarRuleCount, GrammarNodes, GrammarNodeCount, GrammarLinks, GrammarLinkCount, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            ParallelParseReadyCount = ParallelParseReadyCount + 1
            If ParallelParseReadyCount = ParallelParseExpectedCount Then
                ParallelParseReleased = 1
            End If
        End SyncLock
        Dim ParseReleased As Long = 0
        While ParseReleased = 0
            SyncLock ParallelGrammarLoadLock
                ParseReleased = ParallelParseReleased
            End SyncLock
        Wend
        If DiagnosticCount = 0 Then
            Call ParseOneSource(Source, GrammarRules, GrammarRuleCount, GrammarNodes, GrammarLinks, Tokens, 0, TokenCount, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity)
        End If
    End If
    Call SortParallelDiagnostics(Diagnostics, DiagnosticCount)
    SyncLock ParallelGrammarLoadLock
        Call Result.StoreWorkerResult(Tokens, TokenCount, SyntaxNodes, SyntaxNodeCount, SyntaxLinks, SyntaxLinkCount, Diagnostics, DiagnosticCount)
    End SyncLock
End Sub

Sub AddParallelFrontendDiagnostic(ByVal Code As String, ByVal Message As String, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    Call AddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, Code, "<compiler-frontend>", 1, 1, Message)
End Sub

Function AcquireParallelResultSlot(ByVal Index As Long) As ParallelFrontendResult
    If Index = 0 Then
        If ParallelResultSlot0 Is Nothing Then
            Set ParallelResultSlot0 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot0
        Exit Function
    End If
    If Index = 1 Then
        If ParallelResultSlot1 Is Nothing Then
            Set ParallelResultSlot1 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot1
        Exit Function
    End If
    If Index = 2 Then
        If ParallelResultSlot2 Is Nothing Then
            Set ParallelResultSlot2 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot2
        Exit Function
    End If
    If Index = 3 Then
        If ParallelResultSlot3 Is Nothing Then
            Set ParallelResultSlot3 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot3
        Exit Function
    End If
    If Index = 4 Then
        If ParallelResultSlot4 Is Nothing Then
            Set ParallelResultSlot4 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot4
        Exit Function
    End If
    If Index = 5 Then
        If ParallelResultSlot5 Is Nothing Then
            Set ParallelResultSlot5 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot5
        Exit Function
    End If
    If Index = 6 Then
        If ParallelResultSlot6 Is Nothing Then
            Set ParallelResultSlot6 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot6
        Exit Function
    End If
    If Index = 7 Then
        If ParallelResultSlot7 Is Nothing Then
            Set ParallelResultSlot7 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot7
        Exit Function
    End If
    If Index = 8 Then
        If ParallelResultSlot8 Is Nothing Then
            Set ParallelResultSlot8 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot8
        Exit Function
    End If
    If Index = 9 Then
        If ParallelResultSlot9 Is Nothing Then
            Set ParallelResultSlot9 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot9
        Exit Function
    End If
    If Index = 10 Then
        If ParallelResultSlot10 Is Nothing Then
            Set ParallelResultSlot10 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot10
        Exit Function
    End If
    If Index = 11 Then
        If ParallelResultSlot11 Is Nothing Then
            Set ParallelResultSlot11 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot11
        Exit Function
    End If
    If Index = 12 Then
        If ParallelResultSlot12 Is Nothing Then
            Set ParallelResultSlot12 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot12
        Exit Function
    End If
    If Index = 13 Then
        If ParallelResultSlot13 Is Nothing Then
            Set ParallelResultSlot13 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot13
        Exit Function
    End If
    If Index = 14 Then
        If ParallelResultSlot14 Is Nothing Then
            Set ParallelResultSlot14 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot14
        Exit Function
    End If
    If Index = 15 Then
        If ParallelResultSlot15 Is Nothing Then
            Set ParallelResultSlot15 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot15
        Exit Function
    End If
    If Index = 16 Then
        If ParallelResultSlot16 Is Nothing Then
            Set ParallelResultSlot16 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot16
        Exit Function
    End If
    If Index = 17 Then
        If ParallelResultSlot17 Is Nothing Then
            Set ParallelResultSlot17 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot17
        Exit Function
    End If
    If Index = 18 Then
        If ParallelResultSlot18 Is Nothing Then
            Set ParallelResultSlot18 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot18
        Exit Function
    End If
    If Index = 19 Then
        If ParallelResultSlot19 Is Nothing Then
            Set ParallelResultSlot19 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot19
        Exit Function
    End If
    If Index = 20 Then
        If ParallelResultSlot20 Is Nothing Then
            Set ParallelResultSlot20 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot20
        Exit Function
    End If
    If Index = 21 Then
        If ParallelResultSlot21 Is Nothing Then
            Set ParallelResultSlot21 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot21
        Exit Function
    End If
    If Index = 22 Then
        If ParallelResultSlot22 Is Nothing Then
            Set ParallelResultSlot22 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot22
        Exit Function
    End If
    If Index = 23 Then
        If ParallelResultSlot23 Is Nothing Then
            Set ParallelResultSlot23 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot23
        Exit Function
    End If
    If Index = 24 Then
        If ParallelResultSlot24 Is Nothing Then
            Set ParallelResultSlot24 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot24
        Exit Function
    End If
    If Index = 25 Then
        If ParallelResultSlot25 Is Nothing Then
            Set ParallelResultSlot25 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot25
        Exit Function
    End If
    If Index = 26 Then
        If ParallelResultSlot26 Is Nothing Then
            Set ParallelResultSlot26 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot26
        Exit Function
    End If
    If Index = 27 Then
        If ParallelResultSlot27 Is Nothing Then
            Set ParallelResultSlot27 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot27
        Exit Function
    End If
    If Index = 28 Then
        If ParallelResultSlot28 Is Nothing Then
            Set ParallelResultSlot28 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot28
        Exit Function
    End If
    If Index = 29 Then
        If ParallelResultSlot29 Is Nothing Then
            Set ParallelResultSlot29 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot29
        Exit Function
    End If
    If Index = 30 Then
        If ParallelResultSlot30 Is Nothing Then
            Set ParallelResultSlot30 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot30
        Exit Function
    End If
    If Index = 31 Then
        If ParallelResultSlot31 Is Nothing Then
            Set ParallelResultSlot31 = New ParallelFrontendResult
        End If
        Set AcquireParallelResultSlot = ParallelResultSlot31
        Exit Function
    End If
End Function

Function ParallelFrontendJobs(ByVal RequestedJobs As Long, ByVal SourceCount As Long) As Long
    Dim Result As Long = RequestedJobs
    If Result < 1 Then
        Result = 1
    End If
    If Result > SourceCount Then
        Result = SourceCount
    End If
    If Result > 32 Then
        Result = 32
    End If
    If Result < 1 Then
        Result = 1
    End If
    ParallelFrontendJobs = Result
End Function

Sub MergeOneParallelDiagnosticSet(ByVal Result As ParallelFrontendResult, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long)
    Call Result.MergeDiagnostics(Diagnostics, DiagnosticCount, DiagnosticCapacity)
End Sub

Function EnsureParallelTokenCapacity(ByRef Items() As LexicalToken, ByRef Capacity As Long, ByVal RequiredCount As Long) As Long
    If RequiredCount > LimitTokenCount() Then
        EnsureParallelTokenCapacity = 0
        Exit Function
    End If
    If Capacity = 0 Then
        Capacity = 512
        ReDim Items(Capacity - 1)
    End If
    While Capacity < RequiredCount
        Dim NewCapacity As Long = Capacity * 2
        If NewCapacity > LimitTokenCount() Then
            NewCapacity = LimitTokenCount()
        End If
        ReDim Preserve Items(NewCapacity - 1)
        Capacity = NewCapacity
    Wend
    EnsureParallelTokenCapacity = 1
End Function

Function EnsureParallelSyntaxNodeCapacity(ByRef Items() As SyntaxNode, ByRef Capacity As Long, ByVal RequiredCount As Long) As Long
    If RequiredCount > LimitSyntaxNodes() Then
        EnsureParallelSyntaxNodeCapacity = 0
        Exit Function
    End If
    If Capacity = 0 Then
        Capacity = 1024
        ReDim Items(Capacity - 1)
    End If
    While Capacity < RequiredCount
        Dim NewCapacity As Long = Capacity * 2
        If NewCapacity > LimitSyntaxNodes() Then
            NewCapacity = LimitSyntaxNodes()
        End If
        ReDim Preserve Items(NewCapacity - 1)
        Capacity = NewCapacity
    Wend
    EnsureParallelSyntaxNodeCapacity = 1
End Function

Function EnsureParallelSyntaxLinkCapacity(ByRef Items() As SyntaxChildLink, ByRef Capacity As Long, ByVal RequiredCount As Long) As Long
    If RequiredCount > LimitSyntaxNodes() Then
        EnsureParallelSyntaxLinkCapacity = 0
        Exit Function
    End If
    If Capacity = 0 Then
        Capacity = 1024
        ReDim Items(Capacity - 1)
    End If
    While Capacity < RequiredCount
        Dim NewCapacity As Long = Capacity * 2
        If NewCapacity > LimitSyntaxNodes() Then
            NewCapacity = LimitSyntaxNodes()
        End If
        ReDim Preserve Items(NewCapacity - 1)
        Capacity = NewCapacity
    Wend
    EnsureParallelSyntaxLinkCapacity = 1
End Function

Function RunParallelLexWorkers(ByRef Sources() As SourceDocument, ByVal SourceCount As Long, ByVal EffectiveJobs As Long, ByVal ParseRequested As Long, ByVal FaultSite As String, ByRef SourceTokenStarts() As Long, ByRef SourceTokenLimits() As Long, ByRef Tokens() As LexicalToken, ByRef TokenCount As Long, ByRef TokenCapacity As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxNodeCapacity As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef SyntaxLinkCount As Long, ByRef SyntaxLinkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    If EqualsFolded(FaultSite, "frontend-worker-creation") <> 0 Then
        Call AddParallelFrontendDiagnostic("UBE5310", "parallel frontend worker creation failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunParallelLexWorkers = 0
        Exit Function
    End If
    TokenCount = 0
    If ParallelGrammarLoadLock Is Nothing Then
        Set ParallelGrammarLoadLock = New ParallelFrontendResult
    End If
    Dim ThreadIds() As LongLong
    ReDim ThreadIds(EffectiveJobs - 1)
    Dim SourceBase As Long = 0
    While SourceBase < SourceCount
        Dim PlannedCount As Long = EffectiveJobs
        If PlannedCount > SourceCount - SourceBase Then
            PlannedCount = SourceCount - SourceBase
        End If
        Dim BatchCount As Long = 0
        ParallelParseReadyCount = 0
        ParallelParseExpectedCount = PlannedCount
        ParallelParseReleased = 0
        While BatchCount < PlannedCount
            Dim Result As ParallelFrontendResult
            Set Result = AcquireParallelResultSlot(BatchCount)
            Call Result.ResetResult()
            Call Result.SetSource(Sources(SourceBase + BatchCount))
            Result.ParseRequested = ParseRequested
            If ParseRequested = 0 Then
                Result.PublishTokens = 1
            Else
                Result.PublishTokens = 0
            End If
            ThreadIds(BatchCount) = CallNew ParallelLexWorker(Result)
            If ThreadIds(BatchCount) <= 0 Then
                Call AddParallelFrontendDiagnostic("UBE5310", "parallel frontend worker creation failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                SyncLock ParallelGrammarLoadLock
                    ParallelParseExpectedCount = BatchCount
                    If ParallelParseReadyCount = ParallelParseExpectedCount Then
                        ParallelParseReleased = 1
                    End If
                End SyncLock
                Exit While
            End If
            BatchCount = BatchCount + 1
        Wend
        Dim WaitIndex As Long = 0
        While WaitIndex < BatchCount
            Dim WaitResult As ParallelFrontendResult
            Set WaitResult = AcquireParallelResultSlot(WaitIndex)
            If RuntimeThreadWait(ThreadIds(WaitIndex), -1) = 0 Then
                Call AddParallelFrontendDiagnostic("UBE5311", "parallel frontend worker drain failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Else
                If WaitResult.Completed = 0 Then
                    Call AddParallelFrontendDiagnostic("UBE5311", "parallel frontend worker returned without a result", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
            WaitIndex = WaitIndex + 1
        Wend
        If BatchCount <> PlannedCount Then
            RunParallelLexWorkers = 0
            Exit Function
        End If
        Dim MergeIndex As Long = 0
        While MergeIndex < BatchCount
            Dim MergeResult As ParallelFrontendResult
            Set MergeResult = AcquireParallelResultSlot(MergeIndex)
            Call MergeOneParallelDiagnosticSet(MergeResult, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            SourceTokenStarts(SourceBase + MergeIndex) = TokenCount
            If EnsureParallelTokenCapacity(Tokens, TokenCapacity, TokenCount + MergeResult.TokenCount) = 0 Then
                Call AddParallelFrontendDiagnostic("UBE3601", "project token count exceeds the configured limit", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunParallelLexWorkers = 0
                Exit Function
            End If
            Call MergeResult.CopyTokens(Tokens, TokenCount)
            SourceTokenLimits(SourceBase + MergeIndex) = TokenCount
            If ParseRequested <> 0 Then
                If EnsureParallelSyntaxNodeCapacity(SyntaxNodes, SyntaxNodeCapacity, SyntaxNodeCount + MergeResult.SyntaxNodeCount) = 0 Or EnsureParallelSyntaxLinkCapacity(SyntaxLinks, SyntaxLinkCapacity, SyntaxLinkCount + MergeResult.SyntaxLinkCount) = 0 Then
                    Call AddParallelFrontendDiagnostic("UBE3701", "project syntax tree exceeds the configured limit", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                    RunParallelLexWorkers = 0
                    Exit Function
                End If
                Call MergeResult.CopySyntax(SyntaxNodes, SyntaxNodeCount, SyntaxLinks, SyntaxLinkCount, SourceTokenStarts(SourceBase + MergeIndex))
            End If
            MergeIndex = MergeIndex + 1
        Wend
        SourceBase = SourceBase + BatchCount
    Wend
    If EqualsFolded(FaultSite, "frontend-worker-wait") <> 0 Then
        Call AddParallelFrontendDiagnostic("UBE5311", "parallel frontend worker drain failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
        RunParallelLexWorkers = 0
        Exit Function
    End If
    RunParallelLexWorkers = 1
End Function

Function RunParallelParseWorkers(ByRef Sources() As SourceDocument, ByVal SourceCount As Long, ByVal EffectiveJobs As Long, ByRef SourceTokenStarts() As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxNodeCapacity As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef SyntaxLinkCount As Long, ByRef SyntaxLinkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Dim ThreadIds() As LongLong
    ReDim ThreadIds(EffectiveJobs - 1)
    Dim SourceBase As Long = 0
    While SourceBase < SourceCount
        Dim PlannedCount As Long = EffectiveJobs
        If PlannedCount > SourceCount - SourceBase Then
            PlannedCount = SourceCount - SourceBase
        End If
        Dim BatchCount As Long = 0
        ParallelParseReadyCount = 0
        ParallelParseExpectedCount = PlannedCount
        ParallelParseReleased = 0
        While BatchCount < PlannedCount
            Dim Result As ParallelFrontendResult
            Set Result = AcquireParallelResultSlot(BatchCount)
            Call Result.ResetResult()
            Call Result.SetSource(Sources(SourceBase + BatchCount))
            Result.ParseRequested = 1
            Result.PublishTokens = 0
            ThreadIds(BatchCount) = CallNew ParallelLexWorker(Result)
            If ThreadIds(BatchCount) <= 0 Then
                Call AddParallelFrontendDiagnostic("UBE5310", "parallel frontend worker creation failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                SyncLock ParallelGrammarLoadLock
                    ParallelParseExpectedCount = BatchCount
                    If ParallelParseReadyCount = ParallelParseExpectedCount Then
                        ParallelParseReleased = 1
                    End If
                End SyncLock
                Exit While
            End If
            BatchCount = BatchCount + 1
        Wend
        Dim WaitIndex As Long = 0
        While WaitIndex < BatchCount
            Dim WaitResult As ParallelFrontendResult
            Set WaitResult = AcquireParallelResultSlot(WaitIndex)
            If RuntimeThreadWait(ThreadIds(WaitIndex), -1) = 0 Then
                Call AddParallelFrontendDiagnostic("UBE5311", "parallel frontend worker drain failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
            Else
                If WaitResult.Completed = 0 Then
                    Call AddParallelFrontendDiagnostic("UBE5311", "parallel frontend worker returned without a result", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                End If
            End If
            WaitIndex = WaitIndex + 1
        Wend
        If BatchCount <> PlannedCount Then
            RunParallelParseWorkers = 0
            Exit Function
        End If
        Dim MergeIndex As Long = 0
        While MergeIndex < BatchCount
            Dim MergeResult As ParallelFrontendResult
            Set MergeResult = AcquireParallelResultSlot(MergeIndex)
            Call MergeOneParallelDiagnosticSet(MergeResult, Diagnostics, DiagnosticCount, DiagnosticCapacity)
            If EnsureParallelSyntaxNodeCapacity(SyntaxNodes, SyntaxNodeCapacity, SyntaxNodeCount + MergeResult.SyntaxNodeCount) = 0 Or EnsureParallelSyntaxLinkCapacity(SyntaxLinks, SyntaxLinkCapacity, SyntaxLinkCount + MergeResult.SyntaxLinkCount) = 0 Then
                Call AddParallelFrontendDiagnostic("UBE3701", "project syntax tree exceeds the configured limit", Diagnostics, DiagnosticCount, DiagnosticCapacity)
                RunParallelParseWorkers = 0
                Exit Function
            End If
            Call MergeResult.CopySyntax(SyntaxNodes, SyntaxNodeCount, SyntaxLinks, SyntaxLinkCount, SourceTokenStarts(SourceBase + MergeIndex))
            MergeIndex = MergeIndex + 1
        Wend
        SourceBase = SourceBase + BatchCount
    Wend
    RunParallelParseWorkers = 1
End Function

Function RunCompilerFrontend(ByRef Sources() As SourceDocument, ByVal SourceCount As Long, ByVal OutputMode As Long, ByVal RequestedJobs As Long, ByVal FaultSite As String, ByRef Tokens() As LexicalToken, ByRef TokenCount As Long, ByRef TokenCapacity As Long, ByRef GrammarRules() As GrammarRule, ByRef GrammarRuleCount As Long, ByRef GrammarNodes() As GrammarExpression, ByRef GrammarNodeCount As Long, ByRef GrammarLinks() As GrammarChildLink, ByRef GrammarLinkCount As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxNodeCapacity As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef SyntaxLinkCount As Long, ByRef SyntaxLinkCapacity As Long, ByRef Diagnostics() As CompilerDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long, ByRef Performance As CompilerPerformanceProfile, ByRef FailedPhase As Long) As Long
    Dim EffectiveJobs As Long = ParallelFrontendJobs(RequestedJobs, SourceCount)
    Performance.RequestedJobs = RequestedJobs
    Performance.EffectiveJobs = EffectiveJobs
    If EffectiveJobs > 1 Then
        Performance.ExecutionParallel = 1
    End If
    Dim SourceTokenStarts() As Long
    Dim SourceTokenLimits() As Long
    ReDim SourceTokenStarts(SourceCount - 1)
    ReDim SourceTokenLimits(SourceCount - 1)

    Dim PhaseStart As Long = BeginProfilePhase(Performance)
    If RunParallelLexWorkers(Sources, SourceCount, EffectiveJobs, 0, FaultSite, SourceTokenStarts, SourceTokenLimits, Tokens, TokenCount, TokenCapacity, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Performance.FrontEndMilliseconds = EndProfilePhase(Performance, PhaseStart)
        FailedPhase = 1
        RunCompilerFrontend = 0
        Exit Function
    End If
    Performance.FrontEndMilliseconds = EndProfilePhase(Performance, PhaseStart)
    If DiagnosticCount <> 0 Then
        FailedPhase = 1
        RunCompilerFrontend = 0
        Exit Function
    End If
    If OutputMode <> 1 And OutputMode <> 2 Then
        Call ValidateRp8TokenSurface(Sources, Tokens, TokenCount, Diagnostics, DiagnosticCount, DiagnosticCapacity)
    End If
    If DiagnosticCount <> 0 Then
        FailedPhase = 1
        RunCompilerFrontend = 0
        Exit Function
    End If

    PhaseStart = BeginProfilePhase(Performance)
    If LoadGrammarModel(GrammarRules, GrammarRuleCount, GrammarNodes, GrammarNodeCount, GrammarLinks, GrammarLinkCount, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Performance.GrammarMilliseconds = EndProfilePhase(Performance, PhaseStart)
        FailedPhase = 2
        RunCompilerFrontend = 0
        Exit Function
    End If
    Performance.GrammarMilliseconds = EndProfilePhase(Performance, PhaseStart)
    If OutputMode = 1 Then
        RunCompilerFrontend = 1
        Exit Function
    End If

    PhaseStart = BeginProfilePhase(Performance)
    If RunParallelParseWorkers(Sources, SourceCount, EffectiveJobs, SourceTokenStarts, SyntaxNodes, SyntaxNodeCount, SyntaxNodeCapacity, SyntaxLinks, SyntaxLinkCount, SyntaxLinkCapacity, Diagnostics, DiagnosticCount, DiagnosticCapacity) = 0 Then
        Performance.ParseMilliseconds = EndProfilePhase(Performance, PhaseStart)
        FailedPhase = 3
        RunCompilerFrontend = 0
        Exit Function
    End If
    If EqualsFolded(FaultSite, "frontend-merge") <> 0 Then
        Call AddParallelFrontendDiagnostic("UBE5312", "parallel frontend deterministic merge failed", Diagnostics, DiagnosticCount, DiagnosticCapacity)
    End If
    Performance.ParseMilliseconds = EndProfilePhase(Performance, PhaseStart)
    If DiagnosticCount <> 0 Then
        FailedPhase = 3
        RunCompilerFrontend = 0
        Exit Function
    End If
    RunCompilerFrontend = 1
End Function
