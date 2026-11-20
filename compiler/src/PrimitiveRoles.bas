UBE SOURCE 1 MODULE
Attribute UBE_Name = "PrimitiveRoles"
' Grants primitive identities only to validated attributed declarations in caller-owned syntax.
Public Const ArrayLength As Long = 1
Public Const MemoryCopyBytes As Long = 2
Public Const ArrayTryResize As Long = 3
Public Const ArrayTryCopy As Long = 4
Public Const FileTryOpen As Long = 5
Public Const FileTryCreateNew As Long = 6
Public Const FileTryRead As Long = 7
Public Const FileTryWrite As Long = 8
Public Const FileTryClose As Long = 9
Public Const FileTryFlush As Long = 10
Public Const ErrorSet As Long = 11
Public Const SystemReadCommandLine As Long = 12
Public Const SystemWriteStandard As Long = 13
Public Const FileFinalPath As Long = 14
Public Const PathFullPath As Long = 15
Public Const PathCompareOrdinal As Long = 16

Public Const ProcessStart As Long = 17
Public Const ProcessWait As Long = 18
Public Const ProcessTerminate As Long = 19
Public Const ProcessClose As Long = 20

Public Const FileOpenDirectory As Long = 21
Public Const FileIdentity As Long = 22
Public Const FileLength As Long = 23
Public Const SystemExecutablePath As Long = 24
Public Const SystemMonotonicMilliseconds As Long = 25

Public Const DirectoryCreate As Long = 26
Public Const DirectoryRemove As Long = 27
Public Const FileDelete As Long = 28
Public Const FileReplace As Long = 29
Public Const PathKind As Long = 30
Public Const ThreadCurrentId As Long = 31
Public Const ThreadIsAlive As Long = 32
Public Const ThreadWait As Long = 33
Public Const ThreadRequestStop As Long = 34
Public Const ThreadStopRequested As Long = 35
Public Const ThreadYield As Long = 36
Public Const ArrayMove As Long = 37
Public Const ManagedBeginCollection As Long = 38
Public Const ManagedEndCollection As Long = 39
Public Const ManagedSnapshotCounts As Long = 40
Public Const ManagedAllocationAt As Long = 41
Public Const ManagedRootAt As Long = 42
Public Const ManagedMark As Long = 43
Public Const ManagedMarked As Long = 44
Public Const ManagedEdgeCount As Long = 45
Public Const ManagedEdgeAt As Long = 46
Public Const ManagedSealCollection As Long = 47
Public Const ManagedReclaim As Long = 48
Public Const TextByteLength As Long = 49
Public Const TextScalarLength As Long = 50
Public Const TextReadByte As Long = 51
Public Const TextCreate As Long = 52
Public Const TextWriteByte As Long = 53
Public Const TextPublish As Long = 54
Public Const TextAbandon As Long = 55
Public Const MemoryCollect As Long = 56
Public Const ManagedWorkspace As Long = 57

Private Function CollectionRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    CollectionRoleCharacter = -1
    If Role = MemoryCollect Then
        If Position = 0 Then CollectionRoleCharacter = 109: Exit Function
        If Position = 1 Then CollectionRoleCharacter = 101: Exit Function
        If Position = 2 Then CollectionRoleCharacter = 109: Exit Function
        If Position = 3 Then CollectionRoleCharacter = 111: Exit Function
        If Position = 4 Then CollectionRoleCharacter = 114: Exit Function
        If Position = 5 Then CollectionRoleCharacter = 121: Exit Function
        If Position = 6 Then CollectionRoleCharacter = 46: Exit Function
        If Position = 7 Then CollectionRoleCharacter = 99: Exit Function
        If Position = 8 Then CollectionRoleCharacter = 111: Exit Function
        If Position = 9 Then CollectionRoleCharacter = 108: Exit Function
        If Position = 10 Then CollectionRoleCharacter = 108: Exit Function
        If Position = 11 Then CollectionRoleCharacter = 101: Exit Function
        If Position = 12 Then CollectionRoleCharacter = 99: Exit Function
        If Position = 13 Then CollectionRoleCharacter = 116: Exit Function
    End If
    If Role = ManagedWorkspace Then
        If Position = 0 Then CollectionRoleCharacter = 109: Exit Function
        If Position = 1 Then CollectionRoleCharacter = 97: Exit Function
        If Position = 2 Then CollectionRoleCharacter = 110: Exit Function
        If Position = 3 Then CollectionRoleCharacter = 97: Exit Function
        If Position = 4 Then CollectionRoleCharacter = 103: Exit Function
        If Position = 5 Then CollectionRoleCharacter = 101: Exit Function
        If Position = 6 Then CollectionRoleCharacter = 100: Exit Function
        If Position = 7 Then CollectionRoleCharacter = 46: Exit Function
        If Position = 8 Then CollectionRoleCharacter = 119: Exit Function
        If Position = 9 Then CollectionRoleCharacter = 111: Exit Function
        If Position = 10 Then CollectionRoleCharacter = 114: Exit Function
        If Position = 11 Then CollectionRoleCharacter = 107: Exit Function
        If Position = 12 Then CollectionRoleCharacter = 115: Exit Function
        If Position = 13 Then CollectionRoleCharacter = 112: Exit Function
        If Position = 14 Then CollectionRoleCharacter = 97: Exit Function
        If Position = 15 Then CollectionRoleCharacter = 99: Exit Function
        If Position = 16 Then CollectionRoleCharacter = 101: Exit Function
    End If
End Function


' Allocates a private zero-filled role map before atomic publication.
Private Intrinsic Function ResizeRoles(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeRoles.UBE_Primitive = "Array.TryResize"
End Function

' Supplies the reviewed ASCII spelling table; source text is decoded only by SyntaxTokens.
Private Function RoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    If Role = MemoryCollect Or Role = ManagedWorkspace Then RoleCharacter = CollectionRoleCharacter(Role, Position): Exit Function
    If Role >= ManagedBeginCollection And Role <= ManagedReclaim Then RoleCharacter = ManagedRoleCharacter(Role, Position): Exit Function
    If Role >= TextByteLength And Role <= TextAbandon Then RoleCharacter = TextRoleCharacter(Role, Position): Exit Function
    If Role = ArrayMove Then RoleCharacter = MoveRoleCharacter(Position): Exit Function
    If Role >= 31 And Role <= 36 Then RoleCharacter = ThreadRoleCharacter(Role, Position): Exit Function
    RoleCharacter = -1
    If Role = 1 Or Role = 2 Or Role = 3 Or Role = 4 Or Role = 11 Then
        RoleCharacter = StorageRoleCharacter(Role, Position)
        Exit Function
    End If
    If Role = 5 Or Role = 6 Or Role = 7 Or Role = 8 Or Role = 9 Or Role = 10 Or Role = 14 Or Role = 21 Or Role = 22 Or Role = 23 Or Role = 28 Or Role = 29 Then
        RoleCharacter = FileRoleCharacter(Role, Position)
        Exit Function
    End If
    If Role = 12 Or Role = 13 Or Role = 24 Or Role = 25 Then
        RoleCharacter = SystemRoleCharacter(Role, Position)
        Exit Function
    End If
    If Role = 15 Or Role = 16 Or Role = 30 Then
        RoleCharacter = PathRoleCharacter(Role, Position)
        Exit Function
    End If
    If Role = 17 Or Role = 18 Or Role = 19 Or Role = 20 Then
        RoleCharacter = ProcessRoleCharacter(Role, Position)
        Exit Function
    End If
    If Role = 26 Or Role = 27 Then
        RoleCharacter = DirectoryRoleCharacter(Role, Position)
        Exit Function
    End If
End Function

' Supplies exact attributed storage-role spelling without a language String dependency.
Private Function ManagedRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    ManagedRoleCharacter = -1
    If Position = 0 Then ManagedRoleCharacter = 109: Exit Function
    If Position = 1 Then ManagedRoleCharacter = 97: Exit Function
    If Position = 2 Then ManagedRoleCharacter = 110: Exit Function
    If Position = 3 Then ManagedRoleCharacter = 97: Exit Function
    If Position = 4 Then ManagedRoleCharacter = 103: Exit Function
    If Position = 5 Then ManagedRoleCharacter = 101: Exit Function
    If Position = 6 Then ManagedRoleCharacter = 100: Exit Function
    If Position = 7 Then ManagedRoleCharacter = 46: Exit Function
    If Role = ManagedBeginCollection Then
        If Position = 8 Then ManagedRoleCharacter = 98: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 103: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 105: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 110: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 14 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 15 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 16 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 17 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 18 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 19 Then ManagedRoleCharacter = 116: Exit Function
        If Position = 20 Then ManagedRoleCharacter = 105: Exit Function
        If Position = 21 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 22 Then ManagedRoleCharacter = 110: Exit Function
    End If
    If Role = ManagedEndCollection Then
        If Position = 8 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 110: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 100: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 14 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 15 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 16 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 17 Then ManagedRoleCharacter = 116: Exit Function
        If Position = 18 Then ManagedRoleCharacter = 105: Exit Function
        If Position = 19 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 20 Then ManagedRoleCharacter = 110: Exit Function
    End If
    If Role = ManagedSnapshotCounts Then
        If Position = 8 Then ManagedRoleCharacter = 115: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 110: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 112: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 115: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 104: Exit Function
        If Position = 14 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 15 Then ManagedRoleCharacter = 116: Exit Function
        If Position = 16 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 17 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 18 Then ManagedRoleCharacter = 117: Exit Function
        If Position = 19 Then ManagedRoleCharacter = 110: Exit Function
        If Position = 20 Then ManagedRoleCharacter = 116: Exit Function
        If Position = 21 Then ManagedRoleCharacter = 115: Exit Function
    End If
    If Role = ManagedAllocationAt Then
        If Position = 8 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 14 Then ManagedRoleCharacter = 116: Exit Function
        If Position = 15 Then ManagedRoleCharacter = 105: Exit Function
        If Position = 16 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 17 Then ManagedRoleCharacter = 110: Exit Function
        If Position = 18 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 19 Then ManagedRoleCharacter = 116: Exit Function
    End If
    If Role = ManagedRootAt Then
        If Position = 8 Then ManagedRoleCharacter = 114: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 116: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 116: Exit Function
    End If
    If Role = ManagedMark Then
        If Position = 8 Then ManagedRoleCharacter = 109: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 114: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 107: Exit Function
    End If
    If Role = ManagedMarked Then
        If Position = 8 Then ManagedRoleCharacter = 109: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 114: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 107: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 100: Exit Function
    End If
    If Role = ManagedEdgeCount Then
        If Position = 8 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 100: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 103: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 14 Then ManagedRoleCharacter = 117: Exit Function
        If Position = 15 Then ManagedRoleCharacter = 110: Exit Function
        If Position = 16 Then ManagedRoleCharacter = 116: Exit Function
    End If
    If Role = ManagedEdgeAt Then
        If Position = 8 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 100: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 103: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 116: Exit Function
    End If
    If Role = ManagedSealCollection Then
        If Position = 8 Then ManagedRoleCharacter = 115: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 14 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 15 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 16 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 17 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 18 Then ManagedRoleCharacter = 116: Exit Function
        If Position = 19 Then ManagedRoleCharacter = 105: Exit Function
        If Position = 20 Then ManagedRoleCharacter = 111: Exit Function
        If Position = 21 Then ManagedRoleCharacter = 110: Exit Function
    End If
    If Role = ManagedReclaim Then
        If Position = 8 Then ManagedRoleCharacter = 114: Exit Function
        If Position = 9 Then ManagedRoleCharacter = 101: Exit Function
        If Position = 10 Then ManagedRoleCharacter = 99: Exit Function
        If Position = 11 Then ManagedRoleCharacter = 108: Exit Function
        If Position = 12 Then ManagedRoleCharacter = 97: Exit Function
        If Position = 13 Then ManagedRoleCharacter = 105: Exit Function
        If Position = 14 Then ManagedRoleCharacter = 109: Exit Function
    End If
End Function

' Supplies exact attributed storage-role spelling without a language String dependency.
Private Function TextRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    TextRoleCharacter = -1
    If Position = 0 Then TextRoleCharacter = 116: Exit Function
    If Position = 1 Then TextRoleCharacter = 101: Exit Function
    If Position = 2 Then TextRoleCharacter = 120: Exit Function
    If Position = 3 Then TextRoleCharacter = 116: Exit Function
    If Position = 4 Then TextRoleCharacter = 46: Exit Function
    If Role = TextByteLength Then
        If Position = 5 Then TextRoleCharacter = 98: Exit Function
        If Position = 6 Then TextRoleCharacter = 121: Exit Function
        If Position = 7 Then TextRoleCharacter = 116: Exit Function
        If Position = 8 Then TextRoleCharacter = 101: Exit Function
        If Position = 9 Then TextRoleCharacter = 108: Exit Function
        If Position = 10 Then TextRoleCharacter = 101: Exit Function
        If Position = 11 Then TextRoleCharacter = 110: Exit Function
        If Position = 12 Then TextRoleCharacter = 103: Exit Function
        If Position = 13 Then TextRoleCharacter = 116: Exit Function
        If Position = 14 Then TextRoleCharacter = 104: Exit Function
    End If
    If Role = TextScalarLength Then
        If Position = 5 Then TextRoleCharacter = 115: Exit Function
        If Position = 6 Then TextRoleCharacter = 99: Exit Function
        If Position = 7 Then TextRoleCharacter = 97: Exit Function
        If Position = 8 Then TextRoleCharacter = 108: Exit Function
        If Position = 9 Then TextRoleCharacter = 97: Exit Function
        If Position = 10 Then TextRoleCharacter = 114: Exit Function
        If Position = 11 Then TextRoleCharacter = 108: Exit Function
        If Position = 12 Then TextRoleCharacter = 101: Exit Function
        If Position = 13 Then TextRoleCharacter = 110: Exit Function
        If Position = 14 Then TextRoleCharacter = 103: Exit Function
        If Position = 15 Then TextRoleCharacter = 116: Exit Function
        If Position = 16 Then TextRoleCharacter = 104: Exit Function
    End If
    If Role = TextReadByte Then
        If Position = 5 Then TextRoleCharacter = 114: Exit Function
        If Position = 6 Then TextRoleCharacter = 101: Exit Function
        If Position = 7 Then TextRoleCharacter = 97: Exit Function
        If Position = 8 Then TextRoleCharacter = 100: Exit Function
        If Position = 9 Then TextRoleCharacter = 98: Exit Function
        If Position = 10 Then TextRoleCharacter = 121: Exit Function
        If Position = 11 Then TextRoleCharacter = 116: Exit Function
        If Position = 12 Then TextRoleCharacter = 101: Exit Function
    End If
    If Role = TextCreate Then
        If Position = 5 Then TextRoleCharacter = 99: Exit Function
        If Position = 6 Then TextRoleCharacter = 114: Exit Function
        If Position = 7 Then TextRoleCharacter = 101: Exit Function
        If Position = 8 Then TextRoleCharacter = 97: Exit Function
        If Position = 9 Then TextRoleCharacter = 116: Exit Function
        If Position = 10 Then TextRoleCharacter = 101: Exit Function
    End If
    If Role = TextWriteByte Then
        If Position = 5 Then TextRoleCharacter = 119: Exit Function
        If Position = 6 Then TextRoleCharacter = 114: Exit Function
        If Position = 7 Then TextRoleCharacter = 105: Exit Function
        If Position = 8 Then TextRoleCharacter = 116: Exit Function
        If Position = 9 Then TextRoleCharacter = 101: Exit Function
        If Position = 10 Then TextRoleCharacter = 98: Exit Function
        If Position = 11 Then TextRoleCharacter = 121: Exit Function
        If Position = 12 Then TextRoleCharacter = 116: Exit Function
        If Position = 13 Then TextRoleCharacter = 101: Exit Function
    End If
    If Role = TextPublish Then
        If Position = 5 Then TextRoleCharacter = 112: Exit Function
        If Position = 6 Then TextRoleCharacter = 117: Exit Function
        If Position = 7 Then TextRoleCharacter = 98: Exit Function
        If Position = 8 Then TextRoleCharacter = 108: Exit Function
        If Position = 9 Then TextRoleCharacter = 105: Exit Function
        If Position = 10 Then TextRoleCharacter = 115: Exit Function
        If Position = 11 Then TextRoleCharacter = 104: Exit Function
    End If
    If Role = TextAbandon Then
        If Position = 5 Then TextRoleCharacter = 97: Exit Function
        If Position = 6 Then TextRoleCharacter = 98: Exit Function
        If Position = 7 Then TextRoleCharacter = 97: Exit Function
        If Position = 8 Then TextRoleCharacter = 110: Exit Function
        If Position = 9 Then TextRoleCharacter = 100: Exit Function
        If Position = 10 Then TextRoleCharacter = 111: Exit Function
        If Position = 11 Then TextRoleCharacter = 110: Exit Function
    End If
End Function

' Exact arities for managed metadata and packed-text storage roles.
Private Function ManagedParameterCount(ByVal Role As Long) As Long
    If Role = ManagedBeginCollection Then ManagedParameterCount = 2: Exit Function
    If Role = ManagedEndCollection Then ManagedParameterCount = 2: Exit Function
    If Role = ManagedSnapshotCounts Then ManagedParameterCount = 2: Exit Function
    If Role = ManagedAllocationAt Then ManagedParameterCount = 2: Exit Function
    If Role = ManagedRootAt Then ManagedParameterCount = 2: Exit Function
    If Role = ManagedMark Then ManagedParameterCount = 2: Exit Function
    If Role = ManagedMarked Then ManagedParameterCount = 2: Exit Function
    If Role = ManagedEdgeCount Then ManagedParameterCount = 2: Exit Function
    If Role = ManagedEdgeAt Then ManagedParameterCount = 3: Exit Function
    If Role = ManagedSealCollection Then ManagedParameterCount = 0: Exit Function
    If Role = ManagedReclaim Then ManagedParameterCount = 1: Exit Function
    If Role = TextByteLength Then ManagedParameterCount = 1: Exit Function
    If Role = TextScalarLength Then ManagedParameterCount = 1: Exit Function
    If Role = TextReadByte Then ManagedParameterCount = 3: Exit Function
    If Role = TextCreate Then ManagedParameterCount = 3: Exit Function
    If Role = TextWriteByte Then ManagedParameterCount = 3: Exit Function
    If Role = TextPublish Then ManagedParameterCount = 2: Exit Function
    If Role = TextAbandon Then ManagedParameterCount = 1: Exit Function
End Function

' Uses the shared exact scalar/mode signature shapes.
Private Function ManagedParameterShape(ByVal Role As Long, ByVal Position As Long) As Long
    If Role = ManagedBeginCollection Then
        If Position = 1 Then ManagedParameterShape = 4: Exit Function
        If Position = 2 Then ManagedParameterShape = 4: Exit Function
    End If
    If Role = ManagedEndCollection Then
        If Position = 1 Then ManagedParameterShape = 3: Exit Function
        If Position = 2 Then ManagedParameterShape = 3: Exit Function
    End If
    If Role = ManagedSnapshotCounts Then
        If Position = 1 Then ManagedParameterShape = 4: Exit Function
        If Position = 2 Then ManagedParameterShape = 4: Exit Function
    End If
    If Role = ManagedAllocationAt Then
        If Position = 1 Then ManagedParameterShape = 3: Exit Function
        If Position = 2 Then ManagedParameterShape = 6: Exit Function
    End If
    If Role = ManagedRootAt Then
        If Position = 1 Then ManagedParameterShape = 3: Exit Function
        If Position = 2 Then ManagedParameterShape = 6: Exit Function
    End If
    If Role = ManagedMark Then
        If Position = 1 Then ManagedParameterShape = 7: Exit Function
        If Position = 2 Then ManagedParameterShape = 8: Exit Function
    End If
    If Role = ManagedMarked Then
        If Position = 1 Then ManagedParameterShape = 7: Exit Function
        If Position = 2 Then ManagedParameterShape = 8: Exit Function
    End If
    If Role = ManagedEdgeCount Then
        If Position = 1 Then ManagedParameterShape = 7: Exit Function
        If Position = 2 Then ManagedParameterShape = 4: Exit Function
    End If
    If Role = ManagedEdgeAt Then
        If Position = 1 Then ManagedParameterShape = 7: Exit Function
        If Position = 2 Then ManagedParameterShape = 3: Exit Function
        If Position = 3 Then ManagedParameterShape = 6: Exit Function
    End If
    If Role = ManagedReclaim Then
        If Position = 1 Then ManagedParameterShape = 7: Exit Function
    End If
    If Role = TextByteLength Then
        If Position = 1 Then ManagedParameterShape = 9: Exit Function
    End If
    If Role = TextScalarLength Then
        If Position = 1 Then ManagedParameterShape = 9: Exit Function
    End If
    If Role = TextReadByte Then
        If Position = 1 Then ManagedParameterShape = 9: Exit Function
        If Position = 2 Then ManagedParameterShape = 7: Exit Function
        If Position = 3 Then ManagedParameterShape = 10: Exit Function
    End If
    If Role = TextCreate Then
        If Position = 1 Then ManagedParameterShape = 7: Exit Function
        If Position = 2 Then ManagedParameterShape = 7: Exit Function
        If Position = 3 Then ManagedParameterShape = 6: Exit Function
    End If
    If Role = TextWriteByte Then
        If Position = 1 Then ManagedParameterShape = 7: Exit Function
        If Position = 2 Then ManagedParameterShape = 7: Exit Function
        If Position = 3 Then ManagedParameterShape = 11: Exit Function
    End If
    If Role = TextPublish Then
        If Position = 1 Then ManagedParameterShape = 9: Exit Function
        If Position = 2 Then ManagedParameterShape = 7: Exit Function
    End If
    If Role = TextAbandon Then
        If Position = 1 Then ManagedParameterShape = 7: Exit Function
    End If
End Function

' Supplies the exact stable ownership-transfer role spelling.
Private Function MoveRoleCharacter(ByVal Position As Long) As Long
    MoveRoleCharacter = -1
    If Position = 0 Then MoveRoleCharacter = 97
    If Position = 1 Then MoveRoleCharacter = 114
    If Position = 2 Then MoveRoleCharacter = 114
    If Position = 3 Then MoveRoleCharacter = 97
    If Position = 4 Then MoveRoleCharacter = 121
    If Position = 5 Then MoveRoleCharacter = 46
    If Position = 6 Then MoveRoleCharacter = 109
    If Position = 7 Then MoveRoleCharacter = 111
    If Position = 8 Then MoveRoleCharacter = 118
    If Position = 9 Then MoveRoleCharacter = 101
End Function

' Supplies exact characters for the storage primitive namespace within a bounded native procedure.
Private Function StorageRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    StorageRoleCharacter = -1
    If Role = 1 Then
        If Position = 0 Then StorageRoleCharacter = 97: Exit Function
        If Position = 1 Then StorageRoleCharacter = 114: Exit Function
        If Position = 2 Then StorageRoleCharacter = 114: Exit Function
        If Position = 3 Then StorageRoleCharacter = 97: Exit Function
        If Position = 4 Then StorageRoleCharacter = 121: Exit Function
        If Position = 5 Then StorageRoleCharacter = 46: Exit Function
        If Position = 6 Then StorageRoleCharacter = 108: Exit Function
        If Position = 7 Then StorageRoleCharacter = 101: Exit Function
        If Position = 8 Then StorageRoleCharacter = 110: Exit Function
        If Position = 9 Then StorageRoleCharacter = 103: Exit Function
        If Position = 10 Then StorageRoleCharacter = 116: Exit Function
        If Position = 11 Then StorageRoleCharacter = 104: Exit Function
        Exit Function
    End If
    If Role = 2 Then
        If Position = 0 Then StorageRoleCharacter = 109: Exit Function
        If Position = 1 Then StorageRoleCharacter = 101: Exit Function
        If Position = 2 Then StorageRoleCharacter = 109: Exit Function
        If Position = 3 Then StorageRoleCharacter = 111: Exit Function
        If Position = 4 Then StorageRoleCharacter = 114: Exit Function
        If Position = 5 Then StorageRoleCharacter = 121: Exit Function
        If Position = 6 Then StorageRoleCharacter = 46: Exit Function
        If Position = 7 Then StorageRoleCharacter = 99: Exit Function
        If Position = 8 Then StorageRoleCharacter = 111: Exit Function
        If Position = 9 Then StorageRoleCharacter = 112: Exit Function
        If Position = 10 Then StorageRoleCharacter = 121: Exit Function
        If Position = 11 Then StorageRoleCharacter = 98: Exit Function
        If Position = 12 Then StorageRoleCharacter = 121: Exit Function
        If Position = 13 Then StorageRoleCharacter = 116: Exit Function
        If Position = 14 Then StorageRoleCharacter = 101: Exit Function
        If Position = 15 Then StorageRoleCharacter = 115: Exit Function
        Exit Function
    End If
    If Role = 3 Then
        If Position = 0 Then StorageRoleCharacter = 97: Exit Function
        If Position = 1 Then StorageRoleCharacter = 114: Exit Function
        If Position = 2 Then StorageRoleCharacter = 114: Exit Function
        If Position = 3 Then StorageRoleCharacter = 97: Exit Function
        If Position = 4 Then StorageRoleCharacter = 121: Exit Function
        If Position = 5 Then StorageRoleCharacter = 46: Exit Function
        If Position = 6 Then StorageRoleCharacter = 116: Exit Function
        If Position = 7 Then StorageRoleCharacter = 114: Exit Function
        If Position = 8 Then StorageRoleCharacter = 121: Exit Function
        If Position = 9 Then StorageRoleCharacter = 114: Exit Function
        If Position = 10 Then StorageRoleCharacter = 101: Exit Function
        If Position = 11 Then StorageRoleCharacter = 115: Exit Function
        If Position = 12 Then StorageRoleCharacter = 105: Exit Function
        If Position = 13 Then StorageRoleCharacter = 122: Exit Function
        If Position = 14 Then StorageRoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 4 Then
        If Position = 0 Then StorageRoleCharacter = 97: Exit Function
        If Position = 1 Then StorageRoleCharacter = 114: Exit Function
        If Position = 2 Then StorageRoleCharacter = 114: Exit Function
        If Position = 3 Then StorageRoleCharacter = 97: Exit Function
        If Position = 4 Then StorageRoleCharacter = 121: Exit Function
        If Position = 5 Then StorageRoleCharacter = 46: Exit Function
        If Position = 6 Then StorageRoleCharacter = 116: Exit Function
        If Position = 7 Then StorageRoleCharacter = 114: Exit Function
        If Position = 8 Then StorageRoleCharacter = 121: Exit Function
        If Position = 9 Then StorageRoleCharacter = 99: Exit Function
        If Position = 10 Then StorageRoleCharacter = 111: Exit Function
        If Position = 11 Then StorageRoleCharacter = 112: Exit Function
        If Position = 12 Then StorageRoleCharacter = 121: Exit Function
        Exit Function
    End If
    If Role = 11 Then
        If Position = 0 Then StorageRoleCharacter = 101: Exit Function
        If Position = 1 Then StorageRoleCharacter = 114: Exit Function
        If Position = 2 Then StorageRoleCharacter = 114: Exit Function
        If Position = 3 Then StorageRoleCharacter = 111: Exit Function
        If Position = 4 Then StorageRoleCharacter = 114: Exit Function
        If Position = 5 Then StorageRoleCharacter = 46: Exit Function
        If Position = 6 Then StorageRoleCharacter = 115: Exit Function
        If Position = 7 Then StorageRoleCharacter = 101: Exit Function
        If Position = 8 Then StorageRoleCharacter = 116: Exit Function
        Exit Function
    End If
End Function

' Supplies exact characters for the file primitive namespace within a bounded native procedure.
Private Function FileRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    FileRoleCharacter = -1
    If Role = 5 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 111: Exit Function
        If Position = 9 Then FileRoleCharacter = 112: Exit Function
        If Position = 10 Then FileRoleCharacter = 101: Exit Function
        If Position = 11 Then FileRoleCharacter = 110: Exit Function
        Exit Function
    End If
    If Role = 6 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 99: Exit Function
        If Position = 9 Then FileRoleCharacter = 114: Exit Function
        If Position = 10 Then FileRoleCharacter = 101: Exit Function
        If Position = 11 Then FileRoleCharacter = 97: Exit Function
        If Position = 12 Then FileRoleCharacter = 116: Exit Function
        If Position = 13 Then FileRoleCharacter = 101: Exit Function
        If Position = 14 Then FileRoleCharacter = 110: Exit Function
        If Position = 15 Then FileRoleCharacter = 101: Exit Function
        If Position = 16 Then FileRoleCharacter = 119: Exit Function
        Exit Function
    End If
    If Role = 7 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 114: Exit Function
        If Position = 9 Then FileRoleCharacter = 101: Exit Function
        If Position = 10 Then FileRoleCharacter = 97: Exit Function
        If Position = 11 Then FileRoleCharacter = 100: Exit Function
        Exit Function
    End If
    If Role = 8 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 119: Exit Function
        If Position = 9 Then FileRoleCharacter = 114: Exit Function
        If Position = 10 Then FileRoleCharacter = 105: Exit Function
        If Position = 11 Then FileRoleCharacter = 116: Exit Function
        If Position = 12 Then FileRoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 9 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 99: Exit Function
        If Position = 9 Then FileRoleCharacter = 108: Exit Function
        If Position = 10 Then FileRoleCharacter = 111: Exit Function
        If Position = 11 Then FileRoleCharacter = 115: Exit Function
        If Position = 12 Then FileRoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 10 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 102: Exit Function
        If Position = 9 Then FileRoleCharacter = 108: Exit Function
        If Position = 10 Then FileRoleCharacter = 117: Exit Function
        If Position = 11 Then FileRoleCharacter = 115: Exit Function
        If Position = 12 Then FileRoleCharacter = 104: Exit Function
        Exit Function
    End If
    If Role = 14 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 102: Exit Function
        If Position = 9 Then FileRoleCharacter = 105: Exit Function
        If Position = 10 Then FileRoleCharacter = 110: Exit Function
        If Position = 11 Then FileRoleCharacter = 97: Exit Function
        If Position = 12 Then FileRoleCharacter = 108: Exit Function
        If Position = 13 Then FileRoleCharacter = 112: Exit Function
        If Position = 14 Then FileRoleCharacter = 97: Exit Function
        If Position = 15 Then FileRoleCharacter = 116: Exit Function
        If Position = 16 Then FileRoleCharacter = 104: Exit Function
        Exit Function
    End If
    If Role = 21 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 111: Exit Function
        If Position = 9 Then FileRoleCharacter = 112: Exit Function
        If Position = 10 Then FileRoleCharacter = 101: Exit Function
        If Position = 11 Then FileRoleCharacter = 110: Exit Function
        If Position = 12 Then FileRoleCharacter = 100: Exit Function
        If Position = 13 Then FileRoleCharacter = 105: Exit Function
        If Position = 14 Then FileRoleCharacter = 114: Exit Function
        If Position = 15 Then FileRoleCharacter = 101: Exit Function
        If Position = 16 Then FileRoleCharacter = 99: Exit Function
        If Position = 17 Then FileRoleCharacter = 116: Exit Function
        If Position = 18 Then FileRoleCharacter = 111: Exit Function
        If Position = 19 Then FileRoleCharacter = 114: Exit Function
        If Position = 20 Then FileRoleCharacter = 121: Exit Function
        Exit Function
    End If
    If Role = 22 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 105: Exit Function
        If Position = 9 Then FileRoleCharacter = 100: Exit Function
        If Position = 10 Then FileRoleCharacter = 101: Exit Function
        If Position = 11 Then FileRoleCharacter = 110: Exit Function
        If Position = 12 Then FileRoleCharacter = 116: Exit Function
        If Position = 13 Then FileRoleCharacter = 105: Exit Function
        If Position = 14 Then FileRoleCharacter = 116: Exit Function
        If Position = 15 Then FileRoleCharacter = 121: Exit Function
        Exit Function
    End If
    If Role = 23 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 108: Exit Function
        If Position = 9 Then FileRoleCharacter = 101: Exit Function
        If Position = 10 Then FileRoleCharacter = 110: Exit Function
        If Position = 11 Then FileRoleCharacter = 103: Exit Function
        If Position = 12 Then FileRoleCharacter = 116: Exit Function
        If Position = 13 Then FileRoleCharacter = 104: Exit Function
        Exit Function
    End If
    If Role = 28 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 100: Exit Function
        If Position = 9 Then FileRoleCharacter = 101: Exit Function
        If Position = 10 Then FileRoleCharacter = 108: Exit Function
        If Position = 11 Then FileRoleCharacter = 101: Exit Function
        If Position = 12 Then FileRoleCharacter = 116: Exit Function
        If Position = 13 Then FileRoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 29 Then
        If Position = 0 Then FileRoleCharacter = 102: Exit Function
        If Position = 1 Then FileRoleCharacter = 105: Exit Function
        If Position = 2 Then FileRoleCharacter = 108: Exit Function
        If Position = 3 Then FileRoleCharacter = 101: Exit Function
        If Position = 4 Then FileRoleCharacter = 46: Exit Function
        If Position = 5 Then FileRoleCharacter = 116: Exit Function
        If Position = 6 Then FileRoleCharacter = 114: Exit Function
        If Position = 7 Then FileRoleCharacter = 121: Exit Function
        If Position = 8 Then FileRoleCharacter = 114: Exit Function
        If Position = 9 Then FileRoleCharacter = 101: Exit Function
        If Position = 10 Then FileRoleCharacter = 112: Exit Function
        If Position = 11 Then FileRoleCharacter = 108: Exit Function
        If Position = 12 Then FileRoleCharacter = 97: Exit Function
        If Position = 13 Then FileRoleCharacter = 99: Exit Function
        If Position = 14 Then FileRoleCharacter = 101: Exit Function
        Exit Function
    End If
End Function

' Supplies exact characters for the system primitive namespace within a bounded native procedure.
Private Function SystemRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    SystemRoleCharacter = -1
    If Role = 12 Then
        If Position = 0 Then SystemRoleCharacter = 115: Exit Function
        If Position = 1 Then SystemRoleCharacter = 121: Exit Function
        If Position = 2 Then SystemRoleCharacter = 115: Exit Function
        If Position = 3 Then SystemRoleCharacter = 116: Exit Function
        If Position = 4 Then SystemRoleCharacter = 101: Exit Function
        If Position = 5 Then SystemRoleCharacter = 109: Exit Function
        If Position = 6 Then SystemRoleCharacter = 46: Exit Function
        If Position = 7 Then SystemRoleCharacter = 116: Exit Function
        If Position = 8 Then SystemRoleCharacter = 114: Exit Function
        If Position = 9 Then SystemRoleCharacter = 121: Exit Function
        If Position = 10 Then SystemRoleCharacter = 114: Exit Function
        If Position = 11 Then SystemRoleCharacter = 101: Exit Function
        If Position = 12 Then SystemRoleCharacter = 97: Exit Function
        If Position = 13 Then SystemRoleCharacter = 100: Exit Function
        If Position = 14 Then SystemRoleCharacter = 99: Exit Function
        If Position = 15 Then SystemRoleCharacter = 111: Exit Function
        If Position = 16 Then SystemRoleCharacter = 109: Exit Function
        If Position = 17 Then SystemRoleCharacter = 109: Exit Function
        If Position = 18 Then SystemRoleCharacter = 97: Exit Function
        If Position = 19 Then SystemRoleCharacter = 110: Exit Function
        If Position = 20 Then SystemRoleCharacter = 100: Exit Function
        If Position = 21 Then SystemRoleCharacter = 108: Exit Function
        If Position = 22 Then SystemRoleCharacter = 105: Exit Function
        If Position = 23 Then SystemRoleCharacter = 110: Exit Function
        If Position = 24 Then SystemRoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 13 Then
        If Position = 0 Then SystemRoleCharacter = 115: Exit Function
        If Position = 1 Then SystemRoleCharacter = 121: Exit Function
        If Position = 2 Then SystemRoleCharacter = 115: Exit Function
        If Position = 3 Then SystemRoleCharacter = 116: Exit Function
        If Position = 4 Then SystemRoleCharacter = 101: Exit Function
        If Position = 5 Then SystemRoleCharacter = 109: Exit Function
        If Position = 6 Then SystemRoleCharacter = 46: Exit Function
        If Position = 7 Then SystemRoleCharacter = 116: Exit Function
        If Position = 8 Then SystemRoleCharacter = 114: Exit Function
        If Position = 9 Then SystemRoleCharacter = 121: Exit Function
        If Position = 10 Then SystemRoleCharacter = 119: Exit Function
        If Position = 11 Then SystemRoleCharacter = 114: Exit Function
        If Position = 12 Then SystemRoleCharacter = 105: Exit Function
        If Position = 13 Then SystemRoleCharacter = 116: Exit Function
        If Position = 14 Then SystemRoleCharacter = 101: Exit Function
        If Position = 15 Then SystemRoleCharacter = 115: Exit Function
        If Position = 16 Then SystemRoleCharacter = 116: Exit Function
        If Position = 17 Then SystemRoleCharacter = 97: Exit Function
        If Position = 18 Then SystemRoleCharacter = 110: Exit Function
        If Position = 19 Then SystemRoleCharacter = 100: Exit Function
        If Position = 20 Then SystemRoleCharacter = 97: Exit Function
        If Position = 21 Then SystemRoleCharacter = 114: Exit Function
        If Position = 22 Then SystemRoleCharacter = 100: Exit Function
        Exit Function
    End If
    If Role = 24 Then
        If Position = 0 Then SystemRoleCharacter = 115: Exit Function
        If Position = 1 Then SystemRoleCharacter = 121: Exit Function
        If Position = 2 Then SystemRoleCharacter = 115: Exit Function
        If Position = 3 Then SystemRoleCharacter = 116: Exit Function
        If Position = 4 Then SystemRoleCharacter = 101: Exit Function
        If Position = 5 Then SystemRoleCharacter = 109: Exit Function
        If Position = 6 Then SystemRoleCharacter = 46: Exit Function
        If Position = 7 Then SystemRoleCharacter = 116: Exit Function
        If Position = 8 Then SystemRoleCharacter = 114: Exit Function
        If Position = 9 Then SystemRoleCharacter = 121: Exit Function
        If Position = 10 Then SystemRoleCharacter = 101: Exit Function
        If Position = 11 Then SystemRoleCharacter = 120: Exit Function
        If Position = 12 Then SystemRoleCharacter = 101: Exit Function
        If Position = 13 Then SystemRoleCharacter = 99: Exit Function
        If Position = 14 Then SystemRoleCharacter = 117: Exit Function
        If Position = 15 Then SystemRoleCharacter = 116: Exit Function
        If Position = 16 Then SystemRoleCharacter = 97: Exit Function
        If Position = 17 Then SystemRoleCharacter = 98: Exit Function
        If Position = 18 Then SystemRoleCharacter = 108: Exit Function
        If Position = 19 Then SystemRoleCharacter = 101: Exit Function
        If Position = 20 Then SystemRoleCharacter = 112: Exit Function
        If Position = 21 Then SystemRoleCharacter = 97: Exit Function
        If Position = 22 Then SystemRoleCharacter = 116: Exit Function
        If Position = 23 Then SystemRoleCharacter = 104: Exit Function
        Exit Function
    End If
    If Role = 25 Then
        If Position = 0 Then SystemRoleCharacter = 115: Exit Function
        If Position = 1 Then SystemRoleCharacter = 121: Exit Function
        If Position = 2 Then SystemRoleCharacter = 115: Exit Function
        If Position = 3 Then SystemRoleCharacter = 116: Exit Function
        If Position = 4 Then SystemRoleCharacter = 101: Exit Function
        If Position = 5 Then SystemRoleCharacter = 109: Exit Function
        If Position = 6 Then SystemRoleCharacter = 46: Exit Function
        If Position = 7 Then SystemRoleCharacter = 116: Exit Function
        If Position = 8 Then SystemRoleCharacter = 114: Exit Function
        If Position = 9 Then SystemRoleCharacter = 121: Exit Function
        If Position = 10 Then SystemRoleCharacter = 109: Exit Function
        If Position = 11 Then SystemRoleCharacter = 111: Exit Function
        If Position = 12 Then SystemRoleCharacter = 110: Exit Function
        If Position = 13 Then SystemRoleCharacter = 111: Exit Function
        If Position = 14 Then SystemRoleCharacter = 116: Exit Function
        If Position = 15 Then SystemRoleCharacter = 111: Exit Function
        If Position = 16 Then SystemRoleCharacter = 110: Exit Function
        If Position = 17 Then SystemRoleCharacter = 105: Exit Function
        If Position = 18 Then SystemRoleCharacter = 99: Exit Function
        If Position = 19 Then SystemRoleCharacter = 109: Exit Function
        If Position = 20 Then SystemRoleCharacter = 105: Exit Function
        If Position = 21 Then SystemRoleCharacter = 108: Exit Function
        If Position = 22 Then SystemRoleCharacter = 108: Exit Function
        If Position = 23 Then SystemRoleCharacter = 105: Exit Function
        If Position = 24 Then SystemRoleCharacter = 115: Exit Function
        If Position = 25 Then SystemRoleCharacter = 101: Exit Function
        If Position = 26 Then SystemRoleCharacter = 99: Exit Function
        If Position = 27 Then SystemRoleCharacter = 111: Exit Function
        If Position = 28 Then SystemRoleCharacter = 110: Exit Function
        If Position = 29 Then SystemRoleCharacter = 100: Exit Function
        If Position = 30 Then SystemRoleCharacter = 115: Exit Function
        Exit Function
    End If
End Function

' Supplies exact characters for the path primitive namespace within a bounded native procedure.
Private Function PathRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    PathRoleCharacter = -1
    If Role = 15 Then
        If Position = 0 Then PathRoleCharacter = 112: Exit Function
        If Position = 1 Then PathRoleCharacter = 97: Exit Function
        If Position = 2 Then PathRoleCharacter = 116: Exit Function
        If Position = 3 Then PathRoleCharacter = 104: Exit Function
        If Position = 4 Then PathRoleCharacter = 46: Exit Function
        If Position = 5 Then PathRoleCharacter = 116: Exit Function
        If Position = 6 Then PathRoleCharacter = 114: Exit Function
        If Position = 7 Then PathRoleCharacter = 121: Exit Function
        If Position = 8 Then PathRoleCharacter = 102: Exit Function
        If Position = 9 Then PathRoleCharacter = 117: Exit Function
        If Position = 10 Then PathRoleCharacter = 108: Exit Function
        If Position = 11 Then PathRoleCharacter = 108: Exit Function
        If Position = 12 Then PathRoleCharacter = 112: Exit Function
        If Position = 13 Then PathRoleCharacter = 97: Exit Function
        If Position = 14 Then PathRoleCharacter = 116: Exit Function
        If Position = 15 Then PathRoleCharacter = 104: Exit Function
        Exit Function
    End If
    If Role = 16 Then
        If Position = 0 Then PathRoleCharacter = 112: Exit Function
        If Position = 1 Then PathRoleCharacter = 97: Exit Function
        If Position = 2 Then PathRoleCharacter = 116: Exit Function
        If Position = 3 Then PathRoleCharacter = 104: Exit Function
        If Position = 4 Then PathRoleCharacter = 46: Exit Function
        If Position = 5 Then PathRoleCharacter = 116: Exit Function
        If Position = 6 Then PathRoleCharacter = 114: Exit Function
        If Position = 7 Then PathRoleCharacter = 121: Exit Function
        If Position = 8 Then PathRoleCharacter = 99: Exit Function
        If Position = 9 Then PathRoleCharacter = 111: Exit Function
        If Position = 10 Then PathRoleCharacter = 109: Exit Function
        If Position = 11 Then PathRoleCharacter = 112: Exit Function
        If Position = 12 Then PathRoleCharacter = 97: Exit Function
        If Position = 13 Then PathRoleCharacter = 114: Exit Function
        If Position = 14 Then PathRoleCharacter = 101: Exit Function
        If Position = 15 Then PathRoleCharacter = 111: Exit Function
        If Position = 16 Then PathRoleCharacter = 114: Exit Function
        If Position = 17 Then PathRoleCharacter = 100: Exit Function
        If Position = 18 Then PathRoleCharacter = 105: Exit Function
        If Position = 19 Then PathRoleCharacter = 110: Exit Function
        If Position = 20 Then PathRoleCharacter = 97: Exit Function
        If Position = 21 Then PathRoleCharacter = 108: Exit Function
        Exit Function
    End If
    If Role = 30 Then
        If Position = 0 Then PathRoleCharacter = 112: Exit Function
        If Position = 1 Then PathRoleCharacter = 97: Exit Function
        If Position = 2 Then PathRoleCharacter = 116: Exit Function
        If Position = 3 Then PathRoleCharacter = 104: Exit Function
        If Position = 4 Then PathRoleCharacter = 46: Exit Function
        If Position = 5 Then PathRoleCharacter = 116: Exit Function
        If Position = 6 Then PathRoleCharacter = 114: Exit Function
        If Position = 7 Then PathRoleCharacter = 121: Exit Function
        If Position = 8 Then PathRoleCharacter = 107: Exit Function
        If Position = 9 Then PathRoleCharacter = 105: Exit Function
        If Position = 10 Then PathRoleCharacter = 110: Exit Function
        If Position = 11 Then PathRoleCharacter = 100: Exit Function
        Exit Function
    End If
End Function

' Supplies exact characters for the process primitive namespace within a bounded native procedure.
Private Function ProcessRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    ProcessRoleCharacter = -1
    If Role = 17 Then
        If Position = 0 Then ProcessRoleCharacter = 112: Exit Function
        If Position = 1 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 2 Then ProcessRoleCharacter = 111: Exit Function
        If Position = 3 Then ProcessRoleCharacter = 99: Exit Function
        If Position = 4 Then ProcessRoleCharacter = 101: Exit Function
        If Position = 5 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 6 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 7 Then ProcessRoleCharacter = 46: Exit Function
        If Position = 8 Then ProcessRoleCharacter = 116: Exit Function
        If Position = 9 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 10 Then ProcessRoleCharacter = 121: Exit Function
        If Position = 11 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 12 Then ProcessRoleCharacter = 116: Exit Function
        If Position = 13 Then ProcessRoleCharacter = 97: Exit Function
        If Position = 14 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 15 Then ProcessRoleCharacter = 116: Exit Function
        Exit Function
    End If
    If Role = 18 Then
        If Position = 0 Then ProcessRoleCharacter = 112: Exit Function
        If Position = 1 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 2 Then ProcessRoleCharacter = 111: Exit Function
        If Position = 3 Then ProcessRoleCharacter = 99: Exit Function
        If Position = 4 Then ProcessRoleCharacter = 101: Exit Function
        If Position = 5 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 6 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 7 Then ProcessRoleCharacter = 46: Exit Function
        If Position = 8 Then ProcessRoleCharacter = 116: Exit Function
        If Position = 9 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 10 Then ProcessRoleCharacter = 121: Exit Function
        If Position = 11 Then ProcessRoleCharacter = 119: Exit Function
        If Position = 12 Then ProcessRoleCharacter = 97: Exit Function
        If Position = 13 Then ProcessRoleCharacter = 105: Exit Function
        If Position = 14 Then ProcessRoleCharacter = 116: Exit Function
        Exit Function
    End If
    If Role = 19 Then
        If Position = 0 Then ProcessRoleCharacter = 112: Exit Function
        If Position = 1 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 2 Then ProcessRoleCharacter = 111: Exit Function
        If Position = 3 Then ProcessRoleCharacter = 99: Exit Function
        If Position = 4 Then ProcessRoleCharacter = 101: Exit Function
        If Position = 5 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 6 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 7 Then ProcessRoleCharacter = 46: Exit Function
        If Position = 8 Then ProcessRoleCharacter = 116: Exit Function
        If Position = 9 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 10 Then ProcessRoleCharacter = 121: Exit Function
        If Position = 11 Then ProcessRoleCharacter = 116: Exit Function
        If Position = 12 Then ProcessRoleCharacter = 101: Exit Function
        If Position = 13 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 14 Then ProcessRoleCharacter = 109: Exit Function
        If Position = 15 Then ProcessRoleCharacter = 105: Exit Function
        If Position = 16 Then ProcessRoleCharacter = 110: Exit Function
        If Position = 17 Then ProcessRoleCharacter = 97: Exit Function
        If Position = 18 Then ProcessRoleCharacter = 116: Exit Function
        If Position = 19 Then ProcessRoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 20 Then
        If Position = 0 Then ProcessRoleCharacter = 112: Exit Function
        If Position = 1 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 2 Then ProcessRoleCharacter = 111: Exit Function
        If Position = 3 Then ProcessRoleCharacter = 99: Exit Function
        If Position = 4 Then ProcessRoleCharacter = 101: Exit Function
        If Position = 5 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 6 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 7 Then ProcessRoleCharacter = 46: Exit Function
        If Position = 8 Then ProcessRoleCharacter = 116: Exit Function
        If Position = 9 Then ProcessRoleCharacter = 114: Exit Function
        If Position = 10 Then ProcessRoleCharacter = 121: Exit Function
        If Position = 11 Then ProcessRoleCharacter = 99: Exit Function
        If Position = 12 Then ProcessRoleCharacter = 108: Exit Function
        If Position = 13 Then ProcessRoleCharacter = 111: Exit Function
        If Position = 14 Then ProcessRoleCharacter = 115: Exit Function
        If Position = 15 Then ProcessRoleCharacter = 101: Exit Function
        Exit Function
    End If
End Function

' Supplies exact characters for the directory primitive namespace within a bounded native procedure.
Private Function DirectoryRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    DirectoryRoleCharacter = -1
    If Role = 26 Then
        If Position = 0 Then DirectoryRoleCharacter = 100: Exit Function
        If Position = 1 Then DirectoryRoleCharacter = 105: Exit Function
        If Position = 2 Then DirectoryRoleCharacter = 114: Exit Function
        If Position = 3 Then DirectoryRoleCharacter = 101: Exit Function
        If Position = 4 Then DirectoryRoleCharacter = 99: Exit Function
        If Position = 5 Then DirectoryRoleCharacter = 116: Exit Function
        If Position = 6 Then DirectoryRoleCharacter = 111: Exit Function
        If Position = 7 Then DirectoryRoleCharacter = 114: Exit Function
        If Position = 8 Then DirectoryRoleCharacter = 121: Exit Function
        If Position = 9 Then DirectoryRoleCharacter = 46: Exit Function
        If Position = 10 Then DirectoryRoleCharacter = 116: Exit Function
        If Position = 11 Then DirectoryRoleCharacter = 114: Exit Function
        If Position = 12 Then DirectoryRoleCharacter = 121: Exit Function
        If Position = 13 Then DirectoryRoleCharacter = 99: Exit Function
        If Position = 14 Then DirectoryRoleCharacter = 114: Exit Function
        If Position = 15 Then DirectoryRoleCharacter = 101: Exit Function
        If Position = 16 Then DirectoryRoleCharacter = 97: Exit Function
        If Position = 17 Then DirectoryRoleCharacter = 116: Exit Function
        If Position = 18 Then DirectoryRoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 27 Then
        If Position = 0 Then DirectoryRoleCharacter = 100: Exit Function
        If Position = 1 Then DirectoryRoleCharacter = 105: Exit Function
        If Position = 2 Then DirectoryRoleCharacter = 114: Exit Function
        If Position = 3 Then DirectoryRoleCharacter = 101: Exit Function
        If Position = 4 Then DirectoryRoleCharacter = 99: Exit Function
        If Position = 5 Then DirectoryRoleCharacter = 116: Exit Function
        If Position = 6 Then DirectoryRoleCharacter = 111: Exit Function
        If Position = 7 Then DirectoryRoleCharacter = 114: Exit Function
        If Position = 8 Then DirectoryRoleCharacter = 121: Exit Function
        If Position = 9 Then DirectoryRoleCharacter = 46: Exit Function
        If Position = 10 Then DirectoryRoleCharacter = 116: Exit Function
        If Position = 11 Then DirectoryRoleCharacter = 114: Exit Function
        If Position = 12 Then DirectoryRoleCharacter = 121: Exit Function
        If Position = 13 Then DirectoryRoleCharacter = 114: Exit Function
        If Position = 14 Then DirectoryRoleCharacter = 101: Exit Function
        If Position = 15 Then DirectoryRoleCharacter = 109: Exit Function
        If Position = 16 Then DirectoryRoleCharacter = 111: Exit Function
        If Position = 17 Then DirectoryRoleCharacter = 118: Exit Function
        If Position = 18 Then DirectoryRoleCharacter = 101: Exit Function
        Exit Function
    End If
End Function

' Supplies the exact spelling of reviewed thread roles.
Private Function ThreadRoleCharacter(ByVal Role As Long, ByVal Position As Long) As Long
    ThreadRoleCharacter = -1
    If Role = 31 Then
        If Position = 0 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 1 Then ThreadRoleCharacter = 104: Exit Function
        If Position = 2 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 3 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 4 Then ThreadRoleCharacter = 97: Exit Function
        If Position = 5 Then ThreadRoleCharacter = 100: Exit Function
        If Position = 6 Then ThreadRoleCharacter = 46: Exit Function
        If Position = 7 Then ThreadRoleCharacter = 99: Exit Function
        If Position = 8 Then ThreadRoleCharacter = 117: Exit Function
        If Position = 9 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 10 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 11 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 12 Then ThreadRoleCharacter = 110: Exit Function
        If Position = 13 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 14 Then ThreadRoleCharacter = 105: Exit Function
        If Position = 15 Then ThreadRoleCharacter = 100: Exit Function
        Exit Function
    End If
    If Role = 32 Then
        If Position = 0 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 1 Then ThreadRoleCharacter = 104: Exit Function
        If Position = 2 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 3 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 4 Then ThreadRoleCharacter = 97: Exit Function
        If Position = 5 Then ThreadRoleCharacter = 100: Exit Function
        If Position = 6 Then ThreadRoleCharacter = 46: Exit Function
        If Position = 7 Then ThreadRoleCharacter = 105: Exit Function
        If Position = 8 Then ThreadRoleCharacter = 115: Exit Function
        If Position = 9 Then ThreadRoleCharacter = 97: Exit Function
        If Position = 10 Then ThreadRoleCharacter = 108: Exit Function
        If Position = 11 Then ThreadRoleCharacter = 105: Exit Function
        If Position = 12 Then ThreadRoleCharacter = 118: Exit Function
        If Position = 13 Then ThreadRoleCharacter = 101: Exit Function
        Exit Function
    End If
    If Role = 33 Then
        If Position = 0 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 1 Then ThreadRoleCharacter = 104: Exit Function
        If Position = 2 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 3 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 4 Then ThreadRoleCharacter = 97: Exit Function
        If Position = 5 Then ThreadRoleCharacter = 100: Exit Function
        If Position = 6 Then ThreadRoleCharacter = 46: Exit Function
        If Position = 7 Then ThreadRoleCharacter = 119: Exit Function
        If Position = 8 Then ThreadRoleCharacter = 97: Exit Function
        If Position = 9 Then ThreadRoleCharacter = 105: Exit Function
        If Position = 10 Then ThreadRoleCharacter = 116: Exit Function
        Exit Function
    End If
    If Role = 34 Then
        If Position = 0 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 1 Then ThreadRoleCharacter = 104: Exit Function
        If Position = 2 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 3 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 4 Then ThreadRoleCharacter = 97: Exit Function
        If Position = 5 Then ThreadRoleCharacter = 100: Exit Function
        If Position = 6 Then ThreadRoleCharacter = 46: Exit Function
        If Position = 7 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 8 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 9 Then ThreadRoleCharacter = 113: Exit Function
        If Position = 10 Then ThreadRoleCharacter = 117: Exit Function
        If Position = 11 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 12 Then ThreadRoleCharacter = 115: Exit Function
        If Position = 13 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 14 Then ThreadRoleCharacter = 115: Exit Function
        If Position = 15 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 16 Then ThreadRoleCharacter = 111: Exit Function
        If Position = 17 Then ThreadRoleCharacter = 112: Exit Function
        Exit Function
    End If
    If Role = 35 Then
        If Position = 0 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 1 Then ThreadRoleCharacter = 104: Exit Function
        If Position = 2 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 3 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 4 Then ThreadRoleCharacter = 97: Exit Function
        If Position = 5 Then ThreadRoleCharacter = 100: Exit Function
        If Position = 6 Then ThreadRoleCharacter = 46: Exit Function
        If Position = 7 Then ThreadRoleCharacter = 115: Exit Function
        If Position = 8 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 9 Then ThreadRoleCharacter = 111: Exit Function
        If Position = 10 Then ThreadRoleCharacter = 112: Exit Function
        If Position = 11 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 12 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 13 Then ThreadRoleCharacter = 113: Exit Function
        If Position = 14 Then ThreadRoleCharacter = 117: Exit Function
        If Position = 15 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 16 Then ThreadRoleCharacter = 115: Exit Function
        If Position = 17 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 18 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 19 Then ThreadRoleCharacter = 100: Exit Function
        Exit Function
    End If
    If Role = 36 Then
        If Position = 0 Then ThreadRoleCharacter = 116: Exit Function
        If Position = 1 Then ThreadRoleCharacter = 104: Exit Function
        If Position = 2 Then ThreadRoleCharacter = 114: Exit Function
        If Position = 3 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 4 Then ThreadRoleCharacter = 97: Exit Function
        If Position = 5 Then ThreadRoleCharacter = 100: Exit Function
        If Position = 6 Then ThreadRoleCharacter = 46: Exit Function
        If Position = 7 Then ThreadRoleCharacter = 121: Exit Function
        If Position = 8 Then ThreadRoleCharacter = 105: Exit Function
        If Position = 9 Then ThreadRoleCharacter = 101: Exit Function
        If Position = 10 Then ThreadRoleCharacter = 108: Exit Function
        If Position = 11 Then ThreadRoleCharacter = 100: Exit Function
        Exit Function
    End If
End Function

' Compares every decoded character including the terminator, so names and hashes cannot confer authority.
Private Function ReadRole(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByVal Count As Long, ByVal Token As Long) As Long
    Dim Role As Long
    Dim Position As Long
    Dim Expected As Long
    Dim Actual As Long
    On Error GoTo Failed
    Role = 1
    Do While Role <= ManagedWorkspace
        Position = 0
        Do
            Expected = RoleCharacter(Role, Position)
            Actual = SyntaxTokens.SpellingByte(B, T, Token, Count, Position)
            If Expected <> Actual Then Exit Do
            If Expected = -1 Then ReadRole = Role: Exit Function
            Position = Position + 1
        Loop
        Role = Role + 1
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Records a declaration-local error without changing a previously published map.
Private Function Reject(ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef D As DeclarationBinder.BindingDiagnostic, ByVal ModuleIndex As Long, ByVal Node As Long, ByVal Code As Long, ByVal Reason As Long) As Boolean
    On Error GoTo Failed
    D.Code = Code
    D.Reason = Reason
    D.ModuleIndex = ModuleIndex
    D.Node = Node
    D.TokenIndex = N(Node - 1).FirstToken
    D.ByteOffset = N(Node - 1).ByteStart - M(ModuleIndex).ByteBase
    D.Utf16Offset = N(Node - 1).Utf16Start
    D.Line = N(Node - 1).Line
    D.Column = N(Node - 1).Column
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Returns exact arity for each reviewed primitive role.
Private Function ParameterCount(ByVal Role As Long) As Long
    If Role = MemoryCollect Then ParameterCount = 0: Exit Function
    If Role = ManagedWorkspace Then ParameterCount = 3: Exit Function
    If Role >= ManagedBeginCollection And Role <= TextAbandon Then ParameterCount = ManagedParameterCount(Role): Exit Function
    If Role = ThreadCurrentId Or Role = ThreadStopRequested Or Role = ThreadYield Then ParameterCount = 0: Exit Function
    If Role = ThreadIsAlive Or Role = ThreadRequestStop Then ParameterCount = 1: Exit Function
    If Role = ThreadWait Then ParameterCount = 2: Exit Function
    If Role = DirectoryCreate Then ParameterCount = 2: Exit Function
    If Role = DirectoryRemove Then ParameterCount = 2: Exit Function
    If Role = FileDelete Then ParameterCount = 2: Exit Function
    If Role = FileReplace Then ParameterCount = 3: Exit Function
    If Role = PathKind Then ParameterCount = 3: Exit Function
    If Role = FileOpenDirectory Then ParameterCount = 3: Exit Function
    If Role = FileIdentity Then ParameterCount = 3: Exit Function
    If Role = FileLength Then ParameterCount = 3: Exit Function
    If Role = SystemExecutablePath Then ParameterCount = 3: Exit Function
    If Role = SystemMonotonicMilliseconds Then ParameterCount = 2: Exit Function
    If Role = ProcessStart Then ParameterCount = 6: Exit Function
    If Role = ProcessWait Then ParameterCount = 5: Exit Function
    If Role = ProcessTerminate Then ParameterCount = 2: Exit Function
    If Role = ProcessClose Then ParameterCount = 2: Exit Function
    If Role = ArrayLength Or Role = ErrorSet Then ParameterCount = 1: Exit Function
    If Role = ArrayTryCopy Or Role = ArrayMove Or Role = FileTryClose Or Role = FileTryFlush Then ParameterCount = 2: Exit Function
    If Role = ArrayTryResize Or Role = FileTryCreateNew Or Role = SystemReadCommandLine Then ParameterCount = 3: Exit Function
    If Role = MemoryCopyBytes Or Role = FileTryOpen Then ParameterCount = 5: Exit Function
    If Role = FileFinalPath Or Role = PathFullPath Or Role = PathCompareOrdinal Then ParameterCount = 4: Exit Function
    ParameterCount = 6
End Function

' Classifies each formal as generic array, byte array, value Long, reference Long, or value Boolean.
Private Function ParameterShape(ByVal Role As Long, ByVal Position As Long) As Long
    If Role = ManagedWorkspace Then
        If Position = 1 Then ParameterShape = 12: Exit Function
        If Position = 2 Then ParameterShape = 3: Exit Function
        If Position = 3 Then ParameterShape = 5: Exit Function
    End If
    If Role >= ManagedBeginCollection And Role <= TextAbandon Then ParameterShape = ManagedParameterShape(Role, Position): Exit Function
    If Role >= ThreadCurrentId And Role <= ThreadYield Then ParameterShape = 7: Exit Function
    ParameterShape = 3
    If Role = DirectoryCreate Then
        If Position = 1 Then ParameterShape = 2
        If Position = 2 Then ParameterShape = 4
        Exit Function
    End If
    If Role = DirectoryRemove Then
        If Position = 1 Then ParameterShape = 2
        If Position = 2 Then ParameterShape = 4
        Exit Function
    End If
    If Role = FileDelete Then
        If Position = 1 Then ParameterShape = 2
        If Position = 2 Then ParameterShape = 4
        Exit Function
    End If
    If Role = FileReplace Then
        If Position = 1 Then ParameterShape = 2
        If Position = 2 Then ParameterShape = 2
        If Position = 3 Then ParameterShape = 4
        Exit Function
    End If
    If Role = PathKind Then
        If Position = 1 Then ParameterShape = 2
        If Position = 2 Then ParameterShape = 4
        If Position = 3 Then ParameterShape = 4
        Exit Function
    End If
    If Role = FileOpenDirectory Then
        If Position = 1 Then ParameterShape = 2
        If Position = 2 Then ParameterShape = 4
        If Position = 3 Then ParameterShape = 4
        Exit Function
    End If
    If Role = FileIdentity Then
        If Position = 1 Then ParameterShape = 3
        If Position = 2 Then ParameterShape = 2
        If Position = 3 Then ParameterShape = 4
        Exit Function
    End If
    If Role = FileLength Then
        If Position = 1 Then ParameterShape = 3
        If Position = 2 Then ParameterShape = 4
        If Position = 3 Then ParameterShape = 4
        Exit Function
    End If
    If Role = SystemExecutablePath Then
        If Position = 1 Then ParameterShape = 2
        If Position = 2 Then ParameterShape = 4
        If Position = 3 Then ParameterShape = 4
        Exit Function
    End If
    If Role = SystemMonotonicMilliseconds Then
        If Position = 1 Then ParameterShape = 6
        If Position = 2 Then ParameterShape = 4
        Exit Function
    End If
    If Role = ProcessStart Then
        If Position = 1 Then ParameterShape = 2
        If Position = 2 Then ParameterShape = 2
        If Position = 3 Then ParameterShape = 2
        If Position = 4 Then ParameterShape = 3
        If Position = 5 Then ParameterShape = 4
        If Position = 6 Then ParameterShape = 4
        Exit Function
    End If
    If Role = ProcessWait Then
        If Position = 1 Then ParameterShape = 3
        If Position = 2 Then ParameterShape = 3
        If Position = 3 Then ParameterShape = 4
        If Position = 4 Then ParameterShape = 4
        If Position = 5 Then ParameterShape = 4
        Exit Function
    End If
    If Role = ProcessTerminate Then
        If Position = 1 Then ParameterShape = 3
        If Position = 2 Then ParameterShape = 4
        Exit Function
    End If
    If Role = ProcessClose Then
        If Position = 1 Then ParameterShape = 4
        If Position = 2 Then ParameterShape = 4
        Exit Function
    End If
    If Role = ArrayLength Or Role = ArrayTryCopy Or Role = ArrayMove Then ParameterShape = 1: Exit Function
    If Role = ArrayTryResize Then
        If Position = 1 Then ParameterShape = 1
        If Position = 3 Then ParameterShape = 5
        Exit Function
    End If
    If Role = MemoryCopyBytes Then
        If Position = 1 Or Position = 3 Then ParameterShape = 2
        Exit Function
    End If
    If Role = FileTryOpen Then
        If Position = 1 Then ParameterShape = 2
        If Position >= 3 Then ParameterShape = 4
        Exit Function
    End If
    If Role = FileTryCreateNew Or Role = SystemReadCommandLine Then
        ParameterShape = 4
        If Position = 1 Then ParameterShape = 2
        Exit Function
    End If
    If Role = FileTryRead Or Role = FileTryWrite Or Role = SystemWriteStandard Then
        If Position = 2 Then ParameterShape = 2
        If Position >= 5 Then ParameterShape = 4
        Exit Function
    End If
    If Role = FileFinalPath Then
        If Position = 2 Then ParameterShape = 2
        If Position >= 3 Then ParameterShape = 4
        Exit Function
    End If
    If Role = PathFullPath Or Role = PathCompareOrdinal Then
        ParameterShape = 4
        If Position <= 2 Then ParameterShape = 2
        Exit Function
    End If
    If Role = FileTryClose Then ParameterShape = 4: Exit Function
    If Role = FileTryFlush And Position = 2 Then ParameterShape = 4
End Function

' Checks mode, scalar or nominal identity, rank, and the rank-only array declaration form.
Private Function MatchesParameter(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Symbol As Long, ByVal Shape As Long) As Boolean
    Dim Child As Long
    Dim ExpectedType As Long
    Dim ExpectedMode As Long
    On Error GoTo Failed
    If Shape = 1 Or Shape = 2 Or Shape = 12 Then
        If A(Symbol - 1).PassingMode <> SyntaxTokens.KwByref Then Exit Function
        If A(Symbol - 1).ArrayRank <> 1 Then Exit Function
        Child = N(A(Symbol - 1).DeclarationNode - 1).FirstChild
        If Child = 0 Then Exit Function
        If N(Child - 1).Kind <> SourceParser.ArrayShapeNode Or N(Child - 1).Value <> 2 Then Exit Function
        If N(Child - 1).FirstChild <> 0 Or N(Child - 1).LastChild <> 0 Then Exit Function
        If Shape = 2 Then
            If A(Symbol - 1).TypeCode <> SyntaxTokens.KwByte Or A(Symbol - 1).TypeSymbol <> 0 Then Exit Function
        End If
        If Shape = 12 Then
            If A(Symbol - 1).TypeCode <> SyntaxTokens.KwLonglong Or A(Symbol - 1).TypeSymbol <> 0 Then Exit Function
        End If
        MatchesParameter = True
        Exit Function
    End If
    If A(Symbol - 1).ArrayRank <> 0 Or A(Symbol - 1).TypeSymbol <> 0 Then Exit Function
    ExpectedType = SyntaxTokens.KwLong
    ExpectedMode = SyntaxTokens.KwByval
    If Shape = 4 Then ExpectedMode = SyntaxTokens.KwByref
    If Shape = 7 Then ExpectedType = SyntaxTokens.KwLonglong
    If Shape = 5 Then ExpectedType = SyntaxTokens.KwBoolean
    If Shape = 6 Then ExpectedType = SyntaxTokens.KwLonglong: ExpectedMode = SyntaxTokens.KwByref
    If Shape = 8 Then ExpectedType = SyntaxTokens.KwBoolean: ExpectedMode = SyntaxTokens.KwByref
    If Shape = 9 Then ExpectedType = SyntaxTokens.KwString: ExpectedMode = SyntaxTokens.KwByref
    If Shape = 10 Then ExpectedType = SyntaxTokens.KwByte: ExpectedMode = SyntaxTokens.KwByref
    If Shape = 11 Then ExpectedType = SyntaxTokens.KwByte
    MatchesParameter = A(Symbol - 1).TypeCode = ExpectedType And A(Symbol - 1).PassingMode = ExpectedMode
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Validates one signature after declaration resolution has established nominal and parameter identities.
Private Function MatchesSignature(ByRef N() As SourceParser.SyntaxNode, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Symbol As Long, ByVal Role As Long) As Boolean
    Dim ExpectedType As Long
    Dim Parameter As Long
    Dim Position As Long
    On Error GoTo Failed
    If A(Symbol - 1).Kind <> SourceParser.FunctionNode Then Exit Function
    If A(Symbol - 1).TypeSymbol <> 0 Or A(Symbol - 1).ArrayRank <> 0 Then Exit Function
    ExpectedType = SyntaxTokens.KwBoolean
    If Role = MemoryCollect Then ExpectedType = SyntaxTokens.KwLong
    If Role = TextByteLength Or Role = TextScalarLength Then ExpectedType = SyntaxTokens.KwLonglong
    If Role = ThreadCurrentId Then ExpectedType = SyntaxTokens.KwLonglong
    If Role = ThreadWait Or Role = ThreadRequestStop Then ExpectedType = SyntaxTokens.KwLong
    If Role = ArrayLength Then ExpectedType = SyntaxTokens.KwLong
    If A(Symbol - 1).TypeCode <> ExpectedType Then Exit Function
    If A(Symbol - 1).ParameterCount <> ParameterCount(Role) Then Exit Function
    Parameter = A(Symbol - 1).FirstParameter
    Position = 1
    Do While Parameter <> 0
        If MatchesParameter(N, A, Parameter, ParameterShape(Role, Position)) = False Then Exit Function
        Parameter = A(Parameter - 1).NextParameter
        Position = Position + 1
    Loop
    MatchesSignature = Position = ParameterCount(Role) + 1
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Validates metadata and publishes only declaration-node identities, never call-site authority.
Private Function BindProcedure(ByRef B() As Byte, ByRef T() As SourceScanner.SourceToken, ByRef N() As SourceParser.SyntaxNode, ByRef M() As ProjectSyntax.ParsedModule, ByRef C As ProjectSyntax.ProjectCounts, ByRef A() As DeclarationBinder.BoundSymbol, ByVal Symbol As Long, ByRef Candidate() As Long, ByRef D As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Node As Long
    Dim Child As Long
    Dim AttributeNode As Long
    Dim AttributeCount As Long
    Dim BodyCount As Long
    Dim Role As Long
    Dim First As Long
    Dim Second As Long
    Dim ModuleIndex As Long
    On Error GoTo Failed
    Node = A(Symbol - 1).DeclarationNode
    ModuleIndex = A(Symbol - 1).ModuleIndex
    Child = N(Node - 1).FirstChild
    Do While Child <> 0
        If N(Child - 1).Kind = SourceParser.PrimitiveNode Then
            AttributeCount = AttributeCount + 1
            AttributeNode = Child
        End If
        If N(Node - 1).IsIntrinsic And N(Child - 1).Kind = SourceParser.BodyNode Then
            BodyCount = BodyCount + 1
            If N(Child - 1).FirstChild <> 0 Then BindProcedure = Reject(N, M, D, ModuleIndex, Child, 3, 4): Exit Function
        End If
        Child = N(Child - 1).NextSibling
    Loop
    If N(Node - 1).IsIntrinsic = False Then
        If AttributeCount <> 0 Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 3, 1): Exit Function
        BindProcedure = True
        Exit Function
    End If
    If AttributeCount <> 1 Then BindProcedure = Reject(N, M, D, ModuleIndex, Node, 3, 2): Exit Function
    If BodyCount <> 1 Then BindProcedure = Reject(N, M, D, ModuleIndex, Node, 3, 4): Exit Function
    If N(AttributeNode - 1).NameToken < 0 Or N(AttributeNode - 1).TypeFirstToken < 0 Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 9, 1): Exit Function
    If SyntaxTokens.TokenCode(B, T, N(AttributeNode - 1).NameToken, C.TokenCount) <> SyntaxTokens.CodeString Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 9, 1): Exit Function
    If N(AttributeNode - 1).TypeFirstToken <> N(AttributeNode - 1).TypeLastToken Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 9, 1): Exit Function
    If SyntaxTokens.SameIdentifier(B, T, N(AttributeNode - 1).TypeFirstToken, A(Symbol - 1).NameToken, C.TokenCount) = False Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 3, 3): Exit Function
    Role = ReadRole(B, T, C.TokenCount, N(AttributeNode - 1).NameToken)
    If Role = 0 Then BindProcedure = Reject(N, M, D, ModuleIndex, AttributeNode, 8, 1): Exit Function
    If MatchesSignature(N, A, Symbol, Role) = False Then BindProcedure = Reject(N, M, D, ModuleIndex, Node, 3, 5): Exit Function
    If Role = ArrayTryCopy Or Role = ArrayMove Then
        First = A(Symbol - 1).FirstParameter
        Second = A(First - 1).NextParameter
        If A(First - 1).TypeCode <> A(Second - 1).TypeCode Or A(First - 1).TypeSymbol <> A(Second - 1).TypeSymbol Then BindProcedure = Reject(N, M, D, ModuleIndex, Node, 3, 6): Exit Function
    End If
    Candidate(Node - 1) = Role
    BindProcedure = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Re-derives declarations and atomically publishes reviewed primitive roles over validated project syntax.
Public Function TryBindPrimitives(ByRef Bytes() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByRef Nodes() As SourceParser.SyntaxNode, ByRef Modules() As ProjectSyntax.ParsedModule, ByRef Counts As ProjectSyntax.ProjectCounts, ByRef PackageName() As Byte, ByVal IsExecutable As Boolean, ByRef Roles() As Long, ByRef RoleCount As Long, ByRef Diagnostic As DeclarationBinder.BindingDiagnostic) As Boolean
    Dim Symbols() As DeclarationBinder.BoundSymbol
    Dim SymbolCount As Long
    Dim EntrySymbol As Long
    Dim Candidate() As Long
    Dim Index As Long
    Dim Parent As Long
    Dim ModuleIndex As Long
    On Error GoTo StorageFailure
    RoleCount = 0
    If DeclarationBinder.TryBindDeclarations(Bytes, Tokens, Nodes, Modules, Counts, PackageName, IsExecutable, Symbols, SymbolCount, EntrySymbol, Diagnostic) = False Then Exit Function
    Index = 1
    Do While Index <= Counts.NodeCount
        If Nodes(Index - 1).Kind = SourceParser.PrimitiveNode Then
            Parent = Nodes(Index - 1).Parent
            If Parent = 0 Then GoTo InvalidPlacement
            If Nodes(Parent - 1).Kind <> SourceParser.SubNode And Nodes(Parent - 1).Kind <> SourceParser.FunctionNode Then GoTo InvalidPlacement
        End If
        Index = Index + 1
    Loop
    If ResizeRoles(Candidate, Counts.NodeCount, False) = False Then GoTo StorageFailure
    Index = 1
    Do While Index <= SymbolCount
        If Symbols(Index - 1).Kind = SourceParser.SubNode Or Symbols(Index - 1).Kind = SourceParser.FunctionNode Then
            If BindProcedure(Bytes, Tokens, Nodes, Modules, Counts, Symbols, Index, Candidate, Diagnostic) = False Then Exit Function
        End If
        Index = Index + 1
    Loop
    Roles = Candidate
    RoleCount = Counts.NodeCount
    TryBindPrimitives = True
    Exit Function
InvalidPlacement:
    ModuleIndex = 0
    Do While ModuleIndex < Counts.ModuleCount
        If Index > Modules(ModuleIndex).NodeBase And Index <= Modules(ModuleIndex).NodeBase + Modules(ModuleIndex).NodeCount Then
            TryBindPrimitives = Reject(Nodes, Modules, Diagnostic, ModuleIndex, Index, 9, 1)
            Exit Function
        End If
        ModuleIndex = ModuleIndex + 1
    Loop
StorageFailure:
    RoleCount = 0
    Diagnostic.Code = 7
    Diagnostic.Reason = 1
    Diagnostic.ModuleIndex = -1
    Diagnostic.Node = 0
    Diagnostic.TokenIndex = -1
    Diagnostic.ByteOffset = 0
    Diagnostic.Utf16Offset = 1
    Diagnostic.Line = 1
    Diagnostic.Column = 1
End Function
