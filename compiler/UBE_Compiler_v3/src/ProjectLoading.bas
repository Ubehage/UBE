UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProjectLoading"

' Compiler policy and ownership: PROJECT-METADATA-CONTRACT.md. Generic path,
' byte, identity and thread operations remain in UBECore.
Type ProjectPath
    Declared() As Byte
    Normalized() As Byte
    Resolved() As Byte
    LeadingParents As Long
    FirstByte As Long
    LastByte As Long
End Type

Type ProjectLimits
    MaximumManifestBytes As Long
    MaximumPackages As Long
    MaximumSources As Long
    MaximumSourceBytes As Long
    MaximumTotalSourceBytes As Long
    MaximumPathBytes As Long
    MaximumTotalPathBytes As Long
    MaximumMetadataBytes As Long
    MaximumTokens As Long
    MaximumNodes As Long
    MaximumPending As Long
    MaximumDepth As Long
End Type

' Category/code/ID/location domains are fixed in PROJECT-METADATA-CONTRACT.md.
' Location 0 invocation, 1 manifest, 2 source. Context retains input only.
Type ProjectFailure
    Kind As Long
    Code As Long
    PackageId As Long
    SourceId As Long
    Location As Long
    FirstByte As Long
    LastByte As Long
    InputFailure As SourceFailure
    FileFailure As Long
    UnitFailure As SyntaxFailure
    Context As ProjectInput
End Type

Intrinsic Function TryResizeProjectPackages(ByRef Values() As ProjectPackage, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeProjectPackages.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryResizeProjectSources(ByRef Values() As ProjectSource, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeProjectSources.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryResizeProjectPaths(ByRef Values() As ProjectPath, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeProjectPaths.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryResizeProjectOwners(ByRef Values() As SourceOwner, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeProjectOwners.UBE_Primitive = "Array.TryResize"
End Function

Sub DefaultProjectLimits(ByRef Limits As ProjectLimits)
    Limits.MaximumManifestBytes = 1048576
    Limits.MaximumPackages = 2
    Limits.MaximumSources = 256
    Limits.MaximumSourceBytes = 16777216
    Limits.MaximumTotalSourceBytes = 67108864
    Limits.MaximumPathBytes = 131068
    Limits.MaximumTotalPathBytes = 4194304
    Limits.MaximumMetadataBytes = 8388608
    Limits.MaximumTokens = 1048576
    Limits.MaximumNodes = 1048576
    Limits.MaximumPending = 1048576
    Limits.MaximumDepth = 256
End Sub

Function ValidProjectLimits(ByRef Limits As ProjectLimits) As Boolean
    ValidProjectLimits = False
    If Limits.MaximumManifestBytes < 0 Or Limits.MaximumManifestBytes > 1048576 Or Limits.MaximumPackages < 0 Or Limits.MaximumPackages > 2 Or Limits.MaximumSources < 0 Or Limits.MaximumSources > 256 Then
        Exit Function
    End If
    If Limits.MaximumSourceBytes < 0 Or Limits.MaximumSourceBytes > 16777216 Or Limits.MaximumTotalSourceBytes < 0 Or Limits.MaximumTotalSourceBytes > 67108864 Then
        Exit Function
    End If
    If Limits.MaximumPathBytes < 0 Or Limits.MaximumPathBytes > 131068 Or Limits.MaximumTotalPathBytes < 0 Or Limits.MaximumTotalPathBytes > 4194304 Or Limits.MaximumMetadataBytes < 0 Or Limits.MaximumMetadataBytes > 8388608 Then
        Exit Function
    End If
    If Limits.MaximumTokens < 0 Or Limits.MaximumTokens > 1048576 Or Limits.MaximumNodes < 0 Or Limits.MaximumNodes > 1048576 Or Limits.MaximumPending < 0 Or Limits.MaximumPending > 1048576 Or Limits.MaximumDepth < 0 Or Limits.MaximumDepth > 256 Then
        Exit Function
    End If
    ValidProjectLimits = True
End Function

Sub PrepareProjectFailure(ByRef Failure As ProjectFailure)
    Failure.Kind = 5
    Failure.Code = 1310
    Failure.PackageId = -1
    Failure.SourceId = -1
    Failure.Location = 0
    Failure.FirstByte = 0
    Failure.LastByte = 0
    Failure.FileFailure = 0
    Dim EmptyInput As SourceFailure
    Dim EmptyUnit As SyntaxFailure
    Failure.InputFailure = EmptyInput
    Failure.UnitFailure = EmptyUnit
    Set Failure.Context = Nothing
End Sub

Function RejectProjectInput(ByRef Failure As ProjectFailure, ByVal Kind As Long, ByVal Code As Long) As Boolean
    RejectProjectInput = False
    Failure.Kind = Kind
    Failure.Code = Code
End Function

' Fresh status precedes every managed helper. This scalar update allocates
' nothing and keeps the current owning context and original position.
Sub ExpectProjectStorage(ByRef Kind As Long, ByRef Code As Long)
    Kind = 5
    Code = 1310
End Sub

Function TryContinueProjectInput(ByVal Cancellation As SourceCancellation, ByRef Failure As ProjectFailure) As Boolean
    TryContinueProjectInput = False
    If Cancellation.Requested Then
        Call RejectProjectInput(Failure, 8, 1317)
        Exit Function
    End If
    TryContinueProjectInput = True
End Function

' Account retained path/name/manifest payload before its next owned copy.
Function TryAccountProjectBytes(ByVal Pending As ProjectInput, ByRef Limits As ProjectLimits, ByVal Bytes As Long, ByVal IsPath As Boolean, ByRef Failure As ProjectFailure) As Boolean
    TryAccountProjectBytes = False
    If Bytes < 0 Then
        Call RejectProjectInput(Failure, 1, 1320)
        Exit Function
    End If
    If Bytes > Limits.MaximumMetadataBytes - Pending.MetadataBytes Then
        Call RejectProjectInput(Failure, 2, 1309)
        Exit Function
    End If
    If IsPath Then
        If Bytes > Limits.MaximumPathBytes Or Bytes > Limits.MaximumTotalPathBytes - Pending.PathBytes Then
            Call RejectProjectInput(Failure, 2, 1309)
            Exit Function
        End If
        Pending.PathBytes = Pending.PathBytes + Bytes
    End If
    Pending.MetadataBytes = Pending.MetadataBytes + Bytes
    TryAccountProjectBytes = True
End Function

' Decodes doubled manifest quotes once, into independent private path storage.
Function TryDecodeProjectPath(ByRef Document As SourceDocument, ByRef Entry As ProjectDeclaration, ByRef Limits As ProjectLimits, ByVal Pending As ProjectInput, ByRef Published() As Byte, ByRef Failure As ProjectFailure) As Boolean
    TryDecodeProjectPath = False
    Dim Cursor As Long = Entry.ValueFirst
    Dim Count As Long = 0
    While Cursor < Entry.ValueLast
        If Document.Bytes(Cursor) = 34 Then
            Cursor = Cursor + 1
        End If
        Count = Count + 1
        Cursor = Cursor + 1
    Wend
    If TryAccountProjectBytes(Pending, Limits, Count, True, Failure) = False Then
        Exit Function
    End If
    Dim Prepared() As Byte
    If TryResizeByteStorage(Prepared, Count, False) = False Then
        Exit Function
    End If
    Cursor = Entry.ValueFirst
    Dim Index As Long = 0
    While Cursor < Entry.ValueLast
        Prepared(Index) = Document.Bytes(Cursor)
        If Document.Bytes(Cursor) = 34 Then
            Cursor = Cursor + 1
        End If
        Cursor = Cursor + 1
        Index = Index + 1
    Wend
    TryDecodeProjectPath = TryCopyByteStorage(Published, Prepared)
End Function

Function TryProjectPathFailure(ByVal Detail As Long, ByRef Failure As ProjectFailure) As Boolean
    TryProjectPathFailure = False
    If Detail = 8 Then
        Call RejectProjectInput(Failure, 5, 1310)
    Else
        If Detail = 4 Then
            Call RejectProjectInput(Failure, 2, 1309)
        Else
            If Detail = 14 Then
                Call RejectProjectInput(Failure, 4, 1307)
            Else
                Call RejectProjectInput(Failure, 3, 1308)
            End If
        End If
    End If
End Function

Function TryPrepareProjectPath(ByVal Pending As ProjectInput, ByVal PackageInfo As ProjectPackage, ByRef Entry As ProjectDeclaration, ByVal SourcePath As Boolean, ByRef Limits As ProjectLimits, ByRef PathInfo As ProjectPath, ByRef Failure As ProjectFailure) As Boolean
    TryPrepareProjectPath = False
    Failure.Location = 1
    Failure.PackageId = PackageInfo.PackageId
    Failure.SourceId = -1
    Failure.FirstByte = Entry.ValueFirst
    Failure.LastByte = Entry.ValueLast
    PathInfo.FirstByte = Entry.ValueFirst
    PathInfo.LastByte = Entry.ValueLast
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    If TryDecodeProjectPath(PackageInfo.Document, Entry, Limits, Pending, PathInfo.Declared, Failure) = False Then
        Exit Function
    End If
    Dim Detail As Long = 8
    Dim Parents As Long = 0
    If TryNormalizeRelativePathBytes(PathInfo.Declared, PathInfo.Normalized, Parents, Detail) = False Then
        Call TryProjectPathFailure(Detail, Failure)
        Exit Function
    End If
    PathInfo.LeadingParents = Parents
    If TryAccountProjectBytes(Pending, Limits, ByteStorageLength(PathInfo.Normalized), True, Failure) = False Then
        Exit Function
    End If
    If SourcePath And Parents > 0 Then
        Call RejectProjectInput(Failure, 4, 1307)
        Exit Function
    End If
    Detail = 8
    If TryResolvePathBytes(PackageInfo.DirectoryPath, PathInfo.Normalized, PathInfo.Resolved, Detail) = False Then
        Call TryProjectPathFailure(Detail, Failure)
        Exit Function
    End If
    If TryAccountProjectBytes(Pending, Limits, ByteStorageLength(PathInfo.Resolved), True, Failure) = False Then
        Exit Function
    End If
    TryPrepareProjectPath = True
End Function

Function TryEqualProjectBytes(ByRef LeftBytes() As Byte, ByRef RightBytes() As Byte, ByRef Matches As Boolean) As Boolean
    TryEqualProjectBytes = False
    Matches = False
    Dim Count As Long = ByteStorageLength(LeftBytes)
    If Count <> ByteStorageLength(RightBytes) Then
        TryEqualProjectBytes = True
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Count
        If LeftBytes(Index) <> RightBytes(Index) Then
            TryEqualProjectBytes = True
            Exit Function
        End If
        Index = Index + 1
    Wend
    Matches = True
    TryEqualProjectBytes = True
End Function

' Both intervals are already validated quoted UBE names. Strip brackets and
' decode their existing quote/bracket escapes while reusing scalar/fold rules.
Function TryReadProjectNameScalar(ByRef Document As SourceDocument, ByVal LastByte As Long, ByVal Bracketed As Boolean, ByRef Cursor As Long, ByRef Scalar As Long) As Boolean
    TryReadProjectNameScalar = False
    Dim ScalarWidth As Long = 0
    If TryReadSourceScalar(Document.Bytes, Cursor, Scalar, ScalarWidth) = False Then
        Exit Function
    End If
    If Scalar = 34 Or (Bracketed And Scalar = 93) Then
        ScalarWidth = 2
    End If
    If ScalarWidth > LastByte - Cursor Then
        Exit Function
    End If
    Cursor = Cursor + ScalarWidth
    Scalar = SimpleFoldUnicode(Scalar)
    TryReadProjectNameScalar = True
End Function

Function TryEqualProjectNames(ByRef LeftDocument As SourceDocument, ByVal LeftFirst As Long, ByVal LeftLast As Long, ByRef RightDocument As SourceDocument, ByVal RightFirst As Long, ByVal RightLast As Long, ByRef Matches As Boolean) As Boolean
    TryEqualProjectNames = False
    Matches = False
    Dim LeftCursor As Long = LeftFirst + 1
    Dim RightCursor As Long = RightFirst + 1
    LeftLast = LeftLast - 1
    RightLast = RightLast - 1
    Dim LeftBracketed As Boolean = LeftDocument.Bytes(LeftCursor) = 91
    Dim RightBracketed As Boolean = RightDocument.Bytes(RightCursor) = 91
    If LeftBracketed Then
        LeftCursor = LeftCursor + 1
        LeftLast = LeftLast - 1
    End If
    If RightBracketed Then
        RightCursor = RightCursor + 1
        RightLast = RightLast - 1
    End If
    While LeftCursor < LeftLast And RightCursor < RightLast
        Dim LeftScalar As Long = 0
        Dim RightScalar As Long = 0
        If TryReadProjectNameScalar(LeftDocument, LeftLast, LeftBracketed, LeftCursor, LeftScalar) = False Then
            Exit Function
        End If
        If TryReadProjectNameScalar(RightDocument, RightLast, RightBracketed, RightCursor, RightScalar) = False Then
            Exit Function
        End If
        If LeftScalar <> RightScalar Then
            TryEqualProjectNames = True
            Exit Function
        End If
    Wend
    Matches = LeftCursor = LeftLast And RightCursor = RightLast
    TryEqualProjectNames = True
End Function

Function TryProjectCoreName(ByVal PackageInfo As ProjectPackage, ByRef Matches As Boolean) As Boolean
    TryProjectCoreName = False
    Matches = False
    Dim Cursor As Long = PackageInfo.Metadata.NameFirst + 1
    Dim LastByte As Long = PackageInfo.Metadata.NameLast - 1
    Dim Bracketed As Boolean = PackageInfo.Document.Bytes(Cursor) = 91
    If Bracketed Then
        Cursor = Cursor + 1
        LastByte = LastByte - 1
    End If
    Dim Index As Long = 0
    While Cursor < LastByte And Index < 7
        Dim Scalar As Long = 0
        If TryReadProjectNameScalar(PackageInfo.Document, LastByte, Bracketed, Cursor, Scalar) = False Then
            Exit Function
        End If
        If Scalar <> StringByteAt("ubecore", Index) Then
            TryProjectCoreName = True
            Exit Function
        End If
        Index = Index + 1
    Wend
    Matches = Cursor = LastByte And Index = 7
    TryProjectCoreName = True
End Function

' Private construction may retain partial metadata for diagnostics. A complete
' input is published only by TryReadProjectInput, after every token is closed.
Function TryReadProjectPackage(ByVal Pending As ProjectInput, ByVal PackageInfo As ProjectPackage, ByRef Limits As ProjectLimits, ByVal Cancellation As SourceCancellation, ByRef Failure As ProjectFailure, ByRef OpenToken As Long) As Boolean
    TryReadProjectPackage = False
    Failure.Location = 1
    Failure.PackageId = PackageInfo.PackageId
    Failure.SourceId = -1
    Failure.FirstByte = 0
    Failure.LastByte = 0
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    If TryContinueProjectInput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim MaximumBytes As Long = Limits.MaximumManifestBytes
    If MaximumBytes > Limits.MaximumMetadataBytes - Pending.MetadataBytes Then
        MaximumBytes = Limits.MaximumMetadataBytes - Pending.MetadataBytes
    End If
    Failure.InputFailure.Kind = 5
    If TryReadSourceFileIdentity(PackageInfo.ResolvedPath, MaximumBytes, PackageInfo.Document, PackageInfo.Identity, Failure.InputFailure, Failure.FileFailure, OpenToken) = False Then
        Call RecordProjectReadFailure(Failure)
        Exit Function
    End If
    If TryAccountProjectBytes(Pending, Limits, ByteStorageLength(PackageInfo.Document.Bytes), False, Failure) = False Then
        Exit Function
    End If
    If TryContinueProjectInput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim ManifestFailure As ProjectManifestFailure
    ManifestFailure.Code = 1310
    If TryReadProjectManifest(PackageInfo.Document, PackageInfo.Metadata, ManifestFailure) = False Then
        Failure.Code = ManifestFailure.Code
        Failure.Kind = 3
        If Failure.Code = 1310 Then
            Failure.Kind = 5
        End If
        If Failure.Code = 1309 Then
            Failure.Kind = 2
        End If
        If Failure.Code = 1301 Then
            Failure.Kind = 4
        End If
        Failure.FirstByte = ManifestFailure.FirstByte
        Failure.LastByte = ManifestFailure.LastByte
        Exit Function
    End If
    If PackageInfo.Metadata.UnsupportedKind <> 0 Then
        Failure.FirstByte = PackageInfo.Metadata.UnsupportedFirst
        Failure.LastByte = PackageInfo.Metadata.UnsupportedLast
        Call RejectProjectInput(Failure, 4, 1307)
        Exit Function
    End If
    TryReadProjectPackage = True
End Function

Sub RecordProjectReadFailure(ByRef Failure As ProjectFailure)
    Failure.Code = 0
    Failure.Kind = 6
    Failure.FirstByte = Failure.InputFailure.Position.ByteOffset
    Failure.LastByte = Failure.FirstByte
    If Failure.InputFailure.Kind = 5 Or Failure.FileFailure = 8 Then
        Call RejectProjectInput(Failure, 5, 1310)
    Else
        If Failure.InputFailure.Kind = 2 Then
            Call RejectProjectInput(Failure, 2, 1309)
        End If
    End If
End Sub

Function TryProjectDirectory(ByVal Pending As ProjectInput, ByVal PackageInfo As ProjectPackage, ByRef Limits As ProjectLimits, ByRef Failure As ProjectFailure) As Boolean
    TryProjectDirectory = False
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    Dim ParentPath() As Byte
    If TryResizeByteStorage(ParentPath, 2, False) = False Then
        Exit Function
    End If
    ParentPath(0) = 46
    ParentPath(1) = 46
    Dim Detail As Long = 8
    If TryResolvePathBytes(PackageInfo.ResolvedPath, ParentPath, PackageInfo.DirectoryPath, Detail) = False Then
        Call TryProjectPathFailure(Detail, Failure)
        Exit Function
    End If
    If TryAccountProjectBytes(Pending, Limits, ByteStorageLength(PackageInfo.DirectoryPath), True, Failure) = False Then
        Exit Function
    End If
    TryProjectDirectory = True
End Function

' Merge the two ordered declaration vectors without changing canonical Source
' order. Only the first excess Reference witness is retained by the manifest.
Function TryPrepareProjectDeclarations(ByVal Pending As ProjectInput, ByVal PackageInfo As ProjectPackage, ByRef Limits As ProjectLimits, ByRef Failure As ProjectFailure) As Boolean
    TryPrepareProjectDeclarations = False
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    Dim ReferenceCount As Long = PackageInfo.Metadata.ReferenceCount
    If ReferenceCount > 2 Then
        ReferenceCount = 2
    End If
    If TryResizeProjectPaths(PackageInfo.ReferencePaths, ReferenceCount, False) = False Then
        Exit Function
    End If
    Dim SourceIndex As Long = 0
    Dim ReferenceIndex As Long = 0
    Dim PackageFirst As Long = Pending.SourceCount
    Dim SourceInfo As ProjectSource
    While SourceIndex < PackageInfo.Metadata.SourceCount Or ReferenceIndex < ReferenceCount
        Dim TakeSource As Boolean = ReferenceIndex = ReferenceCount
        If SourceIndex < PackageInfo.Metadata.SourceCount And ReferenceIndex < ReferenceCount Then
            TakeSource = PackageInfo.Metadata.Sources(SourceIndex).FirstByte < PackageInfo.Metadata.References(ReferenceIndex).FirstByte
        End If
        Call ExpectProjectStorage(Failure.Kind, Failure.Code)
        If TakeSource Then
            Failure.Location = 1
            Failure.PackageId = PackageInfo.PackageId
            Failure.SourceId = -1
            Failure.FirstByte = PackageInfo.Metadata.Sources(SourceIndex).ValueFirst
            Failure.LastByte = PackageInfo.Metadata.Sources(SourceIndex).ValueLast
            If Pending.SourceCount >= Limits.MaximumSources Then
                Call RejectProjectInput(Failure, 2, 1309)
                Exit Function
            End If
            ' A failed Set preserves its old destination. Clear a loop-local
            ' constructor target first so it cannot reuse an earlier source.
            Set SourceInfo = Nothing
            If (SourceInfo Is Nothing) = False Then
                Exit Function
            End If
            Set SourceInfo = New ProjectSource
            If SourceInfo Is Nothing Then
                Exit Function
            End If
            SourceInfo.PackageId = PackageInfo.PackageId
            SourceInfo.DeclarationIndex = SourceIndex
            Set Pending.Sources(Pending.SourceCount) = SourceInfo
            If (Pending.Sources(Pending.SourceCount) Is SourceInfo) = False Then
                Exit Function
            End If
            If TryPrepareProjectPath(Pending, PackageInfo, PackageInfo.Metadata.Sources(SourceIndex), True, Limits, SourceInfo.Path, Failure) = False Then
                Exit Function
            End If
            Dim Previous As Long = PackageFirst
            While Previous < Pending.SourceCount
                Dim SamePath As Boolean = False
                If TryEqualProjectBytes(Pending.Sources(Previous).Path.Normalized, SourceInfo.Path.Normalized, SamePath) = False Then
                    Exit Function
                End If
                If SamePath Then
                    Call RejectProjectInput(Failure, 3, 1312)
                    Exit Function
                End If
                Previous = Previous + 1
            Wend
            Pending.SourceCount = Pending.SourceCount + 1
            SourceIndex = SourceIndex + 1
        Else
            If TryPrepareProjectPath(Pending, PackageInfo, PackageInfo.Metadata.References(ReferenceIndex), False, Limits, PackageInfo.ReferencePaths(ReferenceIndex), Failure) = False Then
                Exit Function
            End If
            If ReferenceIndex = 1 Then
                Dim RepeatedReference As Boolean = False
                If TryEqualProjectBytes(PackageInfo.ReferencePaths(0).Normalized, PackageInfo.ReferencePaths(1).Normalized, RepeatedReference) = False Then
                    Exit Function
                End If
                If RepeatedReference Then
                    Call RejectProjectInput(Failure, 3, 1313)
                    Exit Function
                End If
            End If
            ReferenceIndex = ReferenceIndex + 1
        End If
    Wend
    TryPrepareProjectDeclarations = True
End Function

Sub RecordProjectScannerFailure(ByRef ScanFailure As ScannerFailure, ByRef Failure As ProjectFailure)
    Failure.Kind = 7
    Failure.Code = 0
    Failure.UnitFailure.Kind = 5
    If ScanFailure.Kind <> 5 Then
        Failure.UnitFailure.Kind = 200 + ScanFailure.Kind
    End If
    Failure.UnitFailure.FirstByte = ScanFailure.First.ByteOffset
    Failure.UnitFailure.LastByte = ScanFailure.Last.ByteOffset
    Failure.FirstByte = Failure.UnitFailure.FirstByte
    Failure.LastByte = Failure.UnitFailure.LastByte
End Sub

' Successful MODULE intake recognizes metadata only. Tokens are built once in
' the existing worker. Failed envelopes alone need the raw first-error scan.
Function TryRecognizeProjectSource(ByVal SourceInfo As ProjectSource, ByRef Limits As ProjectLimits, ByRef Failure As ProjectFailure) As Boolean
    TryRecognizeProjectSource = False
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    Dim ScanFailure As ScannerFailure
    ScanFailure.Kind = 5
    Dim ExtensionKind As Long = SourcePathKind(SourceInfo.Path.Resolved)
    If TryReadSourceEnvelope(SourceInfo.Owner.Document, ExtensionKind, SourceInfo.Envelope, ScanFailure) = False Then
        Failure.UnitFailure.Kind = 5
        Dim Deferred As Boolean = False
        If TrySyntaxConditionalInput(SourceInfo.Owner.Document, Deferred, Failure.UnitFailure) = False Or Deferred Then
            Failure.Kind = 7
            Failure.Code = 0
            Failure.FirstByte = Failure.UnitFailure.FirstByte
            Failure.LastByte = Failure.UnitFailure.LastByte
            Exit Function
        End If
        If ScanFailure.Kind >= 100 And ExtensionKind = 1 Then
            Dim Tokens() As SourceToken
            Dim LexicalFailure As ScannerFailure
            LexicalFailure.Kind = 5
            If TryScanSource(SourceInfo.Owner.Document, 0, Limits.MaximumTokens, Tokens, LexicalFailure) = False Then
                If PreferSourceLexicalFailure(False, LexicalFailure, ScanFailure) Then
                    Call RecordProjectScannerFailure(LexicalFailure, Failure)
                    Exit Function
                End If
            End If
        End If
        Call RecordProjectScannerFailure(ScanFailure, Failure)
        Exit Function
    End If
    If SourceInfo.Envelope.Format <> 1 Or SourceInfo.Envelope.Kind <> 1 Then
        Failure.UnitFailure.Kind = 5
        Dim PendingConditional As Boolean = False
        If TrySyntaxConditionalInput(SourceInfo.Owner.Document, PendingConditional, Failure.UnitFailure) Then
            If PendingConditional = False Then
                Failure.UnitFailure.Kind = 5
                Call TryDeferredSyntaxEnvelope(SourceInfo.Owner.Document, SourceInfo.Envelope, Failure.UnitFailure)
            End If
        End If
        Failure.Kind = 7
        Failure.Code = 0
        Failure.FirstByte = Failure.UnitFailure.FirstByte
        Failure.LastByte = Failure.UnitFailure.LastByte
        Exit Function
    End If
    TryRecognizeProjectSource = True
End Function

Function TryReadProjectSources(ByVal Pending As ProjectInput, ByVal FirstSource As Long, ByRef Limits As ProjectLimits, ByVal Cancellation As SourceCancellation, ByRef Failure As ProjectFailure, ByRef OpenToken As Long) As Boolean
    TryReadProjectSources = False
    Dim Index As Long = FirstSource
    While Index < Pending.SourceCount
        Call ExpectProjectStorage(Failure.Kind, Failure.Code)
        Dim SourceInfo As ProjectSource = Pending.Sources(Index)
        If (SourceInfo Is Pending.Sources(Index)) = False Then
            Exit Function
        End If
        Failure.PackageId = SourceInfo.PackageId
        Failure.SourceId = Index
        Failure.Location = 2
        Failure.FirstByte = 0
        Failure.LastByte = 0
        Call ExpectProjectStorage(Failure.Kind, Failure.Code)
        If TryContinueProjectInput(Cancellation, Failure) = False Then
            Exit Function
        End If
        Set SourceInfo.Owner = New SourceOwner
        If SourceInfo.Owner Is Nothing Then
            Exit Function
        End If
        SourceInfo.Owner.SourceId = Index
        Dim MaximumBytes As Long = Limits.MaximumSourceBytes
        If MaximumBytes > Limits.MaximumTotalSourceBytes - Pending.SourceBytes Then
            MaximumBytes = Limits.MaximumTotalSourceBytes - Pending.SourceBytes
        End If
        Failure.InputFailure.Kind = 5
        If TryReadSourceFileIdentity(SourceInfo.Path.Resolved, MaximumBytes, SourceInfo.Owner.Document, SourceInfo.Identity, Failure.InputFailure, Failure.FileFailure, OpenToken) = False Then
            Call RecordProjectReadFailure(Failure)
            Exit Function
        End If
        Pending.SourceBytes = Pending.SourceBytes + ByteStorageLength(SourceInfo.Owner.Document.Bytes)
        If TryContinueProjectInput(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Previous As Long = FirstSource
        While Previous < Index
            Dim SameFile As Boolean = False
            If TryEqualProjectBytes(Pending.Sources(Previous).Identity, SourceInfo.Identity, SameFile) = False Then
                Exit Function
            End If
            If SameFile Then
                Failure.Location = 1
                Failure.FirstByte = SourceInfo.Path.FirstByte
                Failure.LastByte = SourceInfo.Path.LastByte
                Call RejectProjectInput(Failure, 3, 1312)
                Exit Function
            End If
            Previous = Previous + 1
        Wend
        If TryRecognizeProjectSource(SourceInfo, Limits, Failure) = False Then
            Exit Function
        End If
        Previous = FirstSource
        While Previous < Index
            Dim Other As ProjectSource = Pending.Sources(Previous)
            If (Other Is Pending.Sources(Previous)) = False Then
                Exit Function
            End If
            Dim SameName As Boolean = False
            If TryEqualProjectNames(Other.Owner.Document, Other.Envelope.IdentityFirst, Other.Envelope.IdentityLast, SourceInfo.Owner.Document, SourceInfo.Envelope.IdentityFirst, SourceInfo.Envelope.IdentityLast, SameName) = False Then
                Exit Function
            End If
            If SameName Then
                Failure.FirstByte = SourceInfo.Envelope.IdentityFirst
                Failure.LastByte = SourceInfo.Envelope.IdentityLast
                Call RejectProjectInput(Failure, 3, 1316)
                Exit Function
            End If
            Previous = Previous + 1
        Wend
        Index = Index + 1
    Wend
    TryReadProjectSources = True
End Function

' A further edge is queried, never recursively loaded. The caller retains a
' real failed-close token and the primary query status survives cleanup.
Function TryProbeProjectIdentity(ByRef PathUtf8() As Byte, ByRef Identity() As Byte, ByRef Failure As ProjectFailure, ByRef OpenToken As Long) As Boolean
    TryProbeProjectIdentity = False
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    Dim Length As Long = 0
    Failure.FileFailure = 8
    If TryOpenByteFile(PathUtf8, 2147483646, OpenToken, Length, Failure.FileFailure) = False Then
        Call RejectProjectInput(Failure, 6, 1311)
        If Failure.FileFailure = 8 Then
            Call ExpectProjectStorage(Failure.Kind, Failure.Code)
        End If
        Exit Function
    End If
    Dim Accepted As Boolean = TryReadByteFileIdentity(OpenToken, Identity, Failure.FileFailure)
    If Accepted = False Then
        Call RejectProjectInput(Failure, 6, 1311)
        If Failure.FileFailure = 8 Then
            Call ExpectProjectStorage(Failure.Kind, Failure.Code)
        End If
    End If
    Dim CloseFailure As Long = 0
    If TryCloseByteFile(OpenToken, CloseFailure) = False Then
        If Accepted Then
            Failure.FileFailure = CloseFailure
            Call RejectProjectInput(Failure, 6, 1311)
        End If
        Exit Function
    End If
    TryProbeProjectIdentity = Accepted
End Function

Function TryLocateProjectReference(ByVal PackageInfo As ProjectPackage, ByVal Index As Long, ByRef Failure As ProjectFailure) As Boolean
    TryLocateProjectReference = False
    Failure.Location = 1
    Failure.PackageId = PackageInfo.PackageId
    Failure.SourceId = -1
    Failure.FirstByte = PackageInfo.ReferencePaths(Index).FirstByte
    Failure.LastByte = PackageInfo.ReferencePaths(Index).LastByte
    TryLocateProjectReference = True
End Function

Function TryRejectFurtherProjectReference(ByVal Pending As ProjectInput, ByVal PackageInfo As ProjectPackage, ByVal Index As Long, ByVal Cancellation As SourceCancellation, ByRef Failure As ProjectFailure, ByRef OpenToken As Long) As Boolean
    TryRejectFurtherProjectReference = False
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    If TryLocateProjectReference(PackageInfo, Index, Failure) = False Then
        Exit Function
    End If
    If TryContinueProjectInput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Identity() As Byte
    If TryProbeProjectIdentity(PackageInfo.ReferencePaths(Index).Resolved, Identity, Failure, OpenToken) = False Then
        Exit Function
    End If
    If TryContinueProjectInput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim PackageIndex As Long = 0
    While PackageIndex < Pending.PackageCount
        Dim SameFile As Boolean = False
        If TryEqualProjectBytes(Pending.Packages(PackageIndex).Identity, Identity, SameFile) = False Then
            Exit Function
        End If
        If SameFile Then
            Dim Code As Long = 1313
            If PackageInfo.PackageId > 0 And PackageIndex < PackageInfo.PackageId Then
                Code = 1314
            End If
            Call RejectProjectInput(Failure, 3, Code)
            Exit Function
        End If
        PackageIndex = PackageIndex + 1
    Wend
    Call RejectProjectInput(Failure, 4, 1307)
End Function

Function TryReadProjectLibrary(ByVal Pending As ProjectInput, ByRef Limits As ProjectLimits, ByVal Cancellation As SourceCancellation, ByRef Failure As ProjectFailure, ByRef OpenToken As Long) As Boolean
    TryReadProjectLibrary = False
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    Dim Root As ProjectPackage = Pending.Packages(0)
    If (Root Is Pending.Packages(0)) = False Then
        Exit Function
    End If
    If Root.Metadata.ReferenceCount = 0 Then
        TryReadProjectLibrary = True
        Exit Function
    End If
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    If TryLocateProjectReference(Root, 0, Failure) = False Then
        Exit Function
    End If
    If Limits.MaximumPackages < 2 Then
        Call RejectProjectInput(Failure, 2, 1309)
        Exit Function
    End If
    Dim Library As ProjectPackage = New ProjectPackage
    If Library Is Nothing Then
        Exit Function
    End If
    Set Pending.Packages(1) = Library
    If (Pending.Packages(1) Is Library) = False Then
        Exit Function
    End If
    Pending.PackageCount = 2
    Library.PackageId = 1
    Library.ParentPackageId = 0
    Library.ReferenceFirst = Root.ReferencePaths(0).FirstByte
    Library.ReferenceLast = Root.ReferencePaths(0).LastByte
    If TryAccountProjectBytes(Pending, Limits, ByteStorageLength(Root.ReferencePaths(0).Declared), True, Failure) = False Then
        Exit Function
    End If
    If TryCopyByteStorage(Library.DeclaredPath, Root.ReferencePaths(0).Declared) = False Then
        Exit Function
    End If
    If TryAccountProjectBytes(Pending, Limits, ByteStorageLength(Root.ReferencePaths(0).Resolved), True, Failure) = False Then
        Exit Function
    End If
    If TryCopyByteStorage(Library.ResolvedPath, Root.ReferencePaths(0).Resolved) = False Then
        Exit Function
    End If
    If TryProjectDirectory(Pending, Library, Limits, Failure) = False Then
        Exit Function
    End If
    If TryReadProjectPackage(Pending, Library, Limits, Cancellation, Failure, OpenToken) = False Then
        Exit Function
    End If
    Dim SameFile As Boolean = False
    If TryEqualProjectBytes(Root.Identity, Library.Identity, SameFile) = False Then
        Exit Function
    End If
    If SameFile Or Library.Metadata.Kind <> 2 Then
        If TryLocateProjectReference(Root, 0, Failure) = False Then
            Exit Function
        End If
        Call RejectProjectInput(Failure, 3, 1313)
        Exit Function
    End If
    Dim SameName As Boolean = False
    If TryEqualProjectNames(Root.Document, Root.Metadata.NameFirst, Root.Metadata.NameLast, Library.Document, Library.Metadata.NameFirst, Library.Metadata.NameLast, SameName) = False Then
        Exit Function
    End If
    Failure.FirstByte = Library.Metadata.NameFirst
    Failure.LastByte = Library.Metadata.NameLast
    If SameName Then
        Call RejectProjectInput(Failure, 3, 1315)
        Exit Function
    End If
    Dim IsCore As Boolean = False
    If TryProjectCoreName(Library, IsCore) = False Then
        Exit Function
    End If
    If IsCore = False Then
        Call RejectProjectInput(Failure, 4, 1307)
        Exit Function
    End If
    Dim FirstSource As Long = Pending.SourceCount
    If TryPrepareProjectDeclarations(Pending, Library, Limits, Failure) = False Then
        Exit Function
    End If
    If TryReadProjectSources(Pending, FirstSource, Limits, Cancellation, Failure, OpenToken) = False Then
        Exit Function
    End If
    If Library.Metadata.ReferenceCount > 0 Then
        Call TryRejectFurtherProjectReference(Pending, Library, 0, Cancellation, Failure, OpenToken)
        Exit Function
    End If
    If Root.Metadata.ReferenceCount > 1 Then
        Call TryRejectFurtherProjectReference(Pending, Root, 1, Cancellation, Failure, OpenToken)
        Exit Function
    End If
    TryReadProjectLibrary = True
End Function

' Caller seeds Failure with PrepareProjectFailure before managed admission.
Function TryReadProjectInput(ByRef PathUtf8() As Byte, ByRef Limits As ProjectLimits, ByVal Cancellation As SourceCancellation, ByRef Published As ProjectInput, ByRef Failure As ProjectFailure, ByRef OpenToken As Long) As Boolean
    TryReadProjectInput = False
    Call PrepareProjectFailure(Failure)
    If ValidProjectLimits(Limits) = False Or Cancellation Is Nothing Or OpenToken <> 0 Then
        Call RejectProjectInput(Failure, 1, 1320)
        Exit Function
    End If
    If TryContinueProjectInput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Pending As ProjectInput = New ProjectInput
    If Pending Is Nothing Then
        Exit Function
    End If
    Set Failure.Context = Pending
    If (Failure.Context Is Pending) = False Then
        Exit Function
    End If
    Dim Length As Long = ByteStorageLength(PathUtf8)
    If TryAccountProjectBytes(Pending, Limits, Length, True, Failure) = False Then
        Exit Function
    End If
    If TryCopyByteStorage(Pending.InvocationPath, PathUtf8) = False Then
        Exit Function
    End If
    Dim Detail As Long = 8
    If TryCurrentDirectoryBytes(Pending.WorkingDirectory, Detail) = False Then
        Call TryProjectPathFailure(Detail, Failure)
        Exit Function
    End If
    If TryAccountProjectBytes(Pending, Limits, ByteStorageLength(Pending.WorkingDirectory), True, Failure) = False Then
        Exit Function
    End If
    If Limits.MaximumPackages = 0 Then
        Call RejectProjectInput(Failure, 2, 1309)
        Exit Function
    End If
    If TryResizeProjectPackages(Pending.Packages, Limits.MaximumPackages, False) = False Then
        Exit Function
    End If
    If TryResizeProjectSources(Pending.Sources, Limits.MaximumSources, False) = False Then
        Exit Function
    End If
    Dim Root As ProjectPackage = New ProjectPackage
    If Root Is Nothing Then
        Exit Function
    End If
    Root.PackageId = 0
    Root.ParentPackageId = -1
    Set Pending.Packages(0) = Root
    If (Pending.Packages(0) Is Root) = False Then
        Exit Function
    End If
    Pending.PackageCount = 1
    If TryAccountProjectBytes(Pending, Limits, Length, True, Failure) = False Then
        Exit Function
    End If
    If TryCopyByteStorage(Root.DeclaredPath, PathUtf8) = False Then
        Exit Function
    End If
    Detail = 8
    If TryResolvePathBytes(Pending.WorkingDirectory, PathUtf8, Root.ResolvedPath, Detail) = False Then
        Call TryProjectPathFailure(Detail, Failure)
        Exit Function
    End If
    If TryAccountProjectBytes(Pending, Limits, ByteStorageLength(Root.ResolvedPath), True, Failure) = False Then
        Exit Function
    End If
    If TryProjectDirectory(Pending, Root, Limits, Failure) = False Then
        Exit Function
    End If
    If TryReadProjectPackage(Pending, Root, Limits, Cancellation, Failure, OpenToken) = False Then
        Exit Function
    End If
    If Root.Metadata.Kind <> 1 Then
        Failure.FirstByte = Root.Metadata.KindFirst
        Failure.LastByte = Root.Metadata.KindLast
        Call RejectProjectInput(Failure, 4, 1307)
        Exit Function
    End If
    If TryPrepareProjectDeclarations(Pending, Root, Limits, Failure) = False Then
        Exit Function
    End If
    If TryReadProjectSources(Pending, 0, Limits, Cancellation, Failure, OpenToken) = False Then
        Exit Function
    End If
    If TryReadProjectLibrary(Pending, Limits, Cancellation, Failure, OpenToken) = False Then
        Exit Function
    End If
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    If TryResizeProjectPackages(Pending.Packages, Pending.PackageCount, True) = False Then
        Exit Function
    End If
    If TryResizeProjectSources(Pending.Sources, Pending.SourceCount, True) = False Then
        Exit Function
    End If
    If TryContinueProjectInput(Cancellation, Failure) = False Then
        Exit Function
    End If
    Pending.Validated = True
    Set Published = Pending
    If (Published Is Pending) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    Failure.PackageId = -1
    Failure.SourceId = -1
    TryReadProjectInput = True
End Function

' The sole body-work route is the established bounded source-set consumer.
Function TryParseProject(ByRef PathUtf8() As Byte, ByRef Limits As ProjectLimits, ByVal Jobs As Long, ByVal Cancellation As SourceCancellation, ByRef Published As ProjectSyntax, ByRef Failure As ProjectFailure, ByRef OpenToken As Long) As Boolean
    TryParseProject = False
    Call PrepareProjectFailure(Failure)
    If Jobs < 1 Or Jobs > 4 Or ValidProjectLimits(Limits) = False Or Cancellation Is Nothing Or OpenToken <> 0 Then
        Call RejectProjectInput(Failure, 1, 1320)
        Exit Function
    End If
    Dim Pending As ProjectSyntax = New ProjectSyntax
    If Pending Is Nothing Then
        Exit Function
    End If
    If TryReadProjectInput(PathUtf8, Limits, Cancellation, Pending.Project, Failure, OpenToken) = False Then
        Exit Function
    End If
    Call ExpectProjectStorage(Failure.Kind, Failure.Code)
    ' The scanner requires room for at least EOF. Zero remains a valid project
    ' resource budget; do not turn its exhaustion into a scanner request error.
    If Limits.MaximumTokens = 0 Then
        Failure.Location = 2
        Failure.SourceId = 0
        Failure.PackageId = Pending.Project.Sources(0).PackageId
        Failure.FirstByte = 0
        Failure.LastByte = 0
        Call RejectProjectInput(Failure, 2, 1309)
        Exit Function
    End If
    Dim Owners() As SourceOwner
    If TryResizeProjectOwners(Owners, Pending.Project.SourceCount, False) = False Then
        Exit Function
    End If
    Dim Index As Long = 0
    While Index < Pending.Project.SourceCount
        Set Owners(Index) = Pending.Project.Sources(Index).Owner
        If (Owners(Index) Is Pending.Project.Sources(Index).Owner) = False Then
            Exit Function
        End If
        Index = Index + 1
    Wend
    Dim WorkFailure As SourceSetFailure
    WorkFailure.Kind = 5
    WorkFailure.SourceId = -1
    If TryParseSources(Owners, Jobs, Limits.MaximumTokens, Limits.MaximumNodes, Limits.MaximumPending, Limits.MaximumDepth, Cancellation, Pending.Work, WorkFailure) = False Then
        Failure.SourceId = WorkFailure.SourceId
        Failure.UnitFailure = WorkFailure.UnitFailure
        Failure.FirstByte = WorkFailure.UnitFailure.FirstByte
        Failure.LastByte = WorkFailure.UnitFailure.LastByte
        Failure.Location = 0
        Failure.PackageId = 0
        If WorkFailure.SourceId >= 0 And WorkFailure.SourceId < Pending.Project.SourceCount Then
            Failure.Location = 2
            Failure.PackageId = Pending.Project.Sources(WorkFailure.SourceId).PackageId
        End If
        If WorkFailure.Kind = 1 Then
            Call RejectProjectInput(Failure, 1, 1320)
        Else
            If WorkFailure.Kind = 2 Then
                Call RejectProjectInput(Failure, 9, 1318)
            Else
                If WorkFailure.Kind = 3 Then
                    Call RejectProjectInput(Failure, 7, 0)
                Else
                    If WorkFailure.Kind = 4 Then
                        Call RejectProjectInput(Failure, 8, 1317)
                    Else
                        If WorkFailure.Kind = 6 Then
                            Call RejectProjectInput(Failure, 10, 1319)
                        Else
                            Call ExpectProjectStorage(Failure.Kind, Failure.Code)
                        End If
                    End If
                End If
            End If
        End If
        Exit Function
    End If
    Set Published = Pending
    If (Published Is Pending) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    Failure.PackageId = -1
    Failure.SourceId = -1
    TryParseProject = True
End Function
