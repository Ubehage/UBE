UBE SOURCE 1 MODULE
Attribute UBE_Name = "SyntaxStorage"

' TEST ONLY: comparable owned syntax stores, not a production parser or ABI.
' Inputs are borrowed for the call. SourceId is caller-owned identity metadata;
' the caller retains the immutable SourceDocument for every published byte view.
' Outputs are immutable after publication. No source payload/reference is copied.
' All mutable pending arrays have one caller. Independent calls share only input.
' Caller seeds Failure.Kind=5, CommandIndex=-1 before every managed entry: root
' admission can return False before a body executes. No status is inferred from Err.
Type SyntaxCommand
    Kind As Long
    FirstByte As Long
    LastByte As Long
    ChildCount As Long
End Type

Type SyntaxCommandBuilder
    Commands() As SyntaxCommand
    Count As Long
    MaximumRecords As Long
End Type

' Kind 0 success, 1 invalid domain/graph, 2 explicit budget, 5 storage/admission.
' Index is input-command id in construction, examined node id in projection.
' -1 denotes entry/invalid request, or empty publication with no node to name.
Type SyntaxProbeFailure
    Kind As Long
    CommandIndex As Long
End Type

Type LinkedSyntaxNode
    Kind As Long
    FirstByte As Long
    LastByte As Long
    FirstChild As Long
    NextSibling As Long
    ChildCount As Long
End Type

Type EdgeSyntaxNode
    Kind As Long
    FirstByte As Long
    LastByte As Long
    ChildStart As Long
    ChildCount As Long
End Type

' One-element arrays of these records provide existing fallible whole-value
' publication. Never publish their managed fields in separate output operations.
Type LinkedSyntaxResult
    Nodes() As LinkedSyntaxNode
    NodeCount As Long
    Root As Long
    SourceId As Long
End Type

Type EdgeSyntaxResult
    Nodes() As EdgeSyntaxNode
    Edges() As Long
    NodeCount As Long
    EdgeCount As Long
    Root As Long
    SourceId As Long
End Type

' Explicit traversal state caches each read node; no host recursion or child
' array copy. ChildCursor is a sibling id for links, an edge offset for edges.
Type SyntaxWalkFrame
    NodeIndex As Long
    Kind As Long
    FirstByte As Long
    LastByte As Long
    ChildCount As Long
    ChildOrdinal As Long
    ChildCursor As Long
    PreviousLastByte As Long
End Type

Intrinsic Function SyntaxCommandLength(ByRef Values() As SyntaxCommand) As Long
Attribute SyntaxCommandLength.UBE_Primitive = "Array.Length"
End Function

' Rootless validation helpers are observation boundaries for actual checks.
' Postorder ids make every child smaller than its parent; readers also require
' completion ids 0,1,...,N-1 to reject reuse, detached data and malformed graphs.
Function ValidateLinkedSyntaxNode(ByRef Node As LinkedSyntaxNode, ByVal NodeIndex As Long, ByVal NodeCount As Long) As Boolean
    ValidateLinkedSyntaxNode = False
    If NodeIndex < 0 Or NodeIndex >= NodeCount Or Node.Kind < 1 Then
        Exit Function
    End If
    If Node.FirstByte < 0 Or Node.LastByte < Node.FirstByte Or Node.ChildCount < 0 Or Node.ChildCount > NodeIndex Then
        Exit Function
    End If
    If Node.NextSibling < -1 Or Node.NextSibling >= NodeCount Then
        Exit Function
    End If
    If Node.ChildCount = 0 Then
        If Node.FirstChild <> -1 Then
            Exit Function
        End If
    Else
        If Node.FirstChild < 0 Or Node.FirstChild >= NodeIndex Then
            Exit Function
        End If
    End If
    ValidateLinkedSyntaxNode = True
End Function

Function ValidateEdgeSyntaxNode(ByRef Node As EdgeSyntaxNode, ByVal NodeIndex As Long, ByVal NodeCount As Long, ByVal EdgeCount As Long) As Boolean
    ValidateEdgeSyntaxNode = False
    If NodeIndex < 0 Or NodeIndex >= NodeCount Or Node.Kind < 1 Then
        Exit Function
    End If
    If Node.FirstByte < 0 Or Node.LastByte < Node.FirstByte Or Node.ChildCount < 0 Or Node.ChildCount > NodeIndex Then
        Exit Function
    End If
    If Node.ChildCount = 0 Then
        If Node.ChildStart <> -1 Then
            Exit Function
        End If
    Else
        If Node.ChildStart < 0 Or Node.ChildStart > EdgeCount Then
            Exit Function
        End If
        If Node.ChildCount > EdgeCount - Node.ChildStart Then
            Exit Function
        End If
    End If
    ValidateEdgeSyntaxNode = True
End Function

Sub InitializeLinkedSyntaxFrame(ByRef Frame As SyntaxWalkFrame, ByVal NodeIndex As Long, ByRef Node As LinkedSyntaxNode)
    Frame.NodeIndex = NodeIndex
    Frame.Kind = Node.Kind
    Frame.FirstByte = Node.FirstByte
    Frame.LastByte = Node.LastByte
    Frame.ChildCount = Node.ChildCount
    Frame.ChildOrdinal = 0
    Frame.ChildCursor = Node.FirstChild
    Frame.PreviousLastByte = Node.FirstByte
End Sub

Sub InitializeEdgeSyntaxFrame(ByRef Frame As SyntaxWalkFrame, ByVal NodeIndex As Long, ByRef Node As EdgeSyntaxNode)
    Frame.NodeIndex = NodeIndex
    Frame.Kind = Node.Kind
    Frame.FirstByte = Node.FirstByte
    Frame.LastByte = Node.LastByte
    Frame.ChildCount = Node.ChildCount
    Frame.ChildOrdinal = 0
    Frame.ChildCursor = Node.ChildStart
    Frame.PreviousLastByte = Node.FirstByte
End Sub

' Iterative postorder projection reads each stored node once and follows each
' stored child once. Frames cache metadata, so a wide node needs height-sized
' workspace rather than a simultaneous frame per child. Source bytes stay borrowed
' by the caller and are never accessed or copied by these readers.
Function TryProjectLinkedSyntax(ByRef Stored() As LinkedSyntaxResult, ByVal MaximumPending As Long, ByRef Published() As SyntaxCommand, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryProjectLinkedSyntax = False
    Failure.Kind = 1
    Failure.CommandIndex = -1
    If MaximumPending < 0 Or LinkedSyntaxResultLength(Stored) <> 1 Then
        Exit Function
    End If
    Dim NodeCount As Long = Stored(0).NodeCount
    If NodeCount < 0 Or Stored(0).SourceId < 0 Or NodeCount <> LinkedSyntaxNodeLength(Stored(0).Nodes) Then
        Exit Function
    End If
    If Stored(0).Root <> NodeCount - 1 Then
        Exit Function
    End If
    Dim Builder As SyntaxCommandBuilder
    Builder.MaximumRecords = NodeCount
    Dim Frames() As SyntaxWalkFrame
    Dim FrameCount As Long = 0
    Dim EdgeVisits As Long = 0
    If NodeCount > 0 Then
        Failure.CommandIndex = Stored(0).Root
        Dim InitialNode As LinkedSyntaxNode
        Call ReadLinkedSyntaxNode(InitialNode, Stored(0).Nodes(Stored(0).Root))
        If ValidateLinkedSyntaxNode(InitialNode, Stored(0).Root, NodeCount) = False Then
            Exit Function
        End If
        If InitialNode.NextSibling <> -1 Then
            Exit Function
        End If
        Failure.Kind = 5
        If TryReserveSyntaxFrames(Frames, 1, MaximumPending, Failure) = False Then
            Exit Function
        End If
        Dim InitialFrame As SyntaxWalkFrame
        Call InitializeLinkedSyntaxFrame(InitialFrame, Stored(0).Root, InitialNode)
        Call WriteSyntaxFrame(Frames(0), InitialFrame)
        FrameCount = 1
    End If
    While FrameCount > 0
        Dim Frame As SyntaxWalkFrame
        Call ReadSyntaxFrame(Frame, Frames(FrameCount - 1))
        Failure.Kind = 1
        Failure.CommandIndex = Frame.NodeIndex
        If Frame.ChildOrdinal < Frame.ChildCount Then
            Dim ChildIndex As Long = -1
            Call ReadLinkedSyntaxChild(ChildIndex, Frame)
            If ChildIndex < Builder.Count Or ChildIndex >= Frame.NodeIndex Then
                Exit Function
            End If
            Failure.CommandIndex = ChildIndex
            If EdgeVisits >= NodeCount - 1 Then
                Exit Function
            End If
            Dim Child As LinkedSyntaxNode
            Call ReadLinkedSyntaxNode(Child, Stored(0).Nodes(ChildIndex))
            If ValidateLinkedSyntaxNode(Child, ChildIndex, NodeCount) = False Then
                Exit Function
            End If
            If Child.FirstByte < Frame.PreviousLastByte Or Child.LastByte > Frame.LastByte Then
                Exit Function
            End If
            If Frame.ChildOrdinal + 1 = Frame.ChildCount Then
                If Child.NextSibling <> -1 Then
                    Exit Function
                End If
            Else
                If Child.NextSibling <= ChildIndex Or Child.NextSibling >= Frame.NodeIndex Then
                    Exit Function
                End If
            End If
            Failure.Kind = 5
            If TryReserveSyntaxFrames(Frames, FrameCount + 1, MaximumPending, Failure) = False Then
                Exit Function
            End If
            Frame.ChildOrdinal = Frame.ChildOrdinal + 1
            Frame.ChildCursor = Child.NextSibling
            Frame.PreviousLastByte = Child.LastByte
            Call WriteSyntaxFrame(Frames(FrameCount - 1), Frame)
            Dim ChildFrame As SyntaxWalkFrame
            Call InitializeLinkedSyntaxFrame(ChildFrame, ChildIndex, Child)
            Call WriteSyntaxFrame(Frames(FrameCount), ChildFrame)
            FrameCount = FrameCount + 1
            EdgeVisits = EdgeVisits + 1
        Else
            If Frame.NodeIndex <> Builder.Count Then
                Exit Function
            End If
            Failure.Kind = 5
            If TryAppendSyntaxCommand(Builder, Frame.Kind, Frame.FirstByte, Frame.LastByte, Frame.ChildCount, Failure) = False Then
                Exit Function
            End If
            FrameCount = FrameCount - 1
        End If
    Wend
    Failure.Kind = 1
    Failure.CommandIndex = NodeCount - 1
    If Builder.Count <> NodeCount Then
        Exit Function
    End If
    If NodeCount > 0 And EdgeVisits <> NodeCount - 1 Then
        Exit Function
    End If
    Failure.Kind = 5
    If TryPublishSyntaxCommands(Builder, Published, Failure) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.CommandIndex = -1
    TryProjectLinkedSyntax = True
End Function

Function TryProjectEdgeSyntax(ByRef Stored() As EdgeSyntaxResult, ByVal MaximumPending As Long, ByRef Published() As SyntaxCommand, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryProjectEdgeSyntax = False
    Failure.Kind = 1
    Failure.CommandIndex = -1
    If MaximumPending < 0 Or EdgeSyntaxResultLength(Stored) <> 1 Then
        Exit Function
    End If
    Dim NodeCount As Long = Stored(0).NodeCount
    Dim EdgeCount As Long = Stored(0).EdgeCount
    If NodeCount < 0 Or Stored(0).SourceId < 0 Or NodeCount <> EdgeSyntaxNodeLength(Stored(0).Nodes) Then
        Exit Function
    End If
    If EdgeCount < 0 Or EdgeCount <> SyntaxLongLength(Stored(0).Edges) Or Stored(0).Root <> NodeCount - 1 Then
        Exit Function
    End If
    If NodeCount = 0 Then
        If EdgeCount <> 0 Then
            Exit Function
        End If
    Else
        If EdgeCount <> NodeCount - 1 Then
            Exit Function
        End If
    End If
    Dim Builder As SyntaxCommandBuilder
    Builder.MaximumRecords = NodeCount
    Dim Frames() As SyntaxWalkFrame
    Dim FrameCount As Long = 0
    Dim EdgeVisits As Long = 0
    If NodeCount > 0 Then
        Failure.CommandIndex = Stored(0).Root
        Dim InitialNode As EdgeSyntaxNode
        Call ReadEdgeSyntaxNode(InitialNode, Stored(0).Nodes(Stored(0).Root))
        If ValidateEdgeSyntaxNode(InitialNode, Stored(0).Root, NodeCount, EdgeCount) = False Then
            Exit Function
        End If
        Failure.Kind = 5
        If TryReserveSyntaxFrames(Frames, 1, MaximumPending, Failure) = False Then
            Exit Function
        End If
        Dim InitialFrame As SyntaxWalkFrame
        Call InitializeEdgeSyntaxFrame(InitialFrame, Stored(0).Root, InitialNode)
        Call WriteSyntaxFrame(Frames(0), InitialFrame)
        FrameCount = 1
    End If
    While FrameCount > 0
        Dim Frame As SyntaxWalkFrame
        Call ReadSyntaxFrame(Frame, Frames(FrameCount - 1))
        Failure.Kind = 1
        Failure.CommandIndex = Frame.NodeIndex
        If Frame.ChildOrdinal < Frame.ChildCount Then
            Dim ChildIndex As Long = -1
            Call ReadSyntaxEdge(ChildIndex, Stored(0).Edges(Frame.ChildCursor + Frame.ChildOrdinal))
            If ChildIndex < Builder.Count Or ChildIndex >= Frame.NodeIndex Then
                Exit Function
            End If
            Failure.CommandIndex = ChildIndex
            If EdgeVisits >= EdgeCount Then
                Exit Function
            End If
            Dim Child As EdgeSyntaxNode
            Call ReadEdgeSyntaxNode(Child, Stored(0).Nodes(ChildIndex))
            If ValidateEdgeSyntaxNode(Child, ChildIndex, NodeCount, EdgeCount) = False Then
                Exit Function
            End If
            If Child.FirstByte < Frame.PreviousLastByte Or Child.LastByte > Frame.LastByte Then
                Exit Function
            End If
            Failure.Kind = 5
            If TryReserveSyntaxFrames(Frames, FrameCount + 1, MaximumPending, Failure) = False Then
                Exit Function
            End If
            Frame.ChildOrdinal = Frame.ChildOrdinal + 1
            Frame.PreviousLastByte = Child.LastByte
            Call WriteSyntaxFrame(Frames(FrameCount - 1), Frame)
            Dim ChildFrame As SyntaxWalkFrame
            Call InitializeEdgeSyntaxFrame(ChildFrame, ChildIndex, Child)
            Call WriteSyntaxFrame(Frames(FrameCount), ChildFrame)
            FrameCount = FrameCount + 1
            EdgeVisits = EdgeVisits + 1
        Else
            If Frame.NodeIndex <> Builder.Count Then
                Exit Function
            End If
            Failure.Kind = 5
            If TryAppendSyntaxCommand(Builder, Frame.Kind, Frame.FirstByte, Frame.LastByte, Frame.ChildCount, Failure) = False Then
                Exit Function
            End If
            FrameCount = FrameCount - 1
        End If
    Wend
    Failure.Kind = 1
    Failure.CommandIndex = NodeCount - 1
    If Builder.Count <> NodeCount Or EdgeVisits <> EdgeCount Then
        Exit Function
    End If
    Failure.Kind = 5
    If TryPublishSyntaxCommands(Builder, Published, Failure) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.CommandIndex = -1
    TryProjectEdgeSyntax = True
End Function
Intrinsic Function TryResizeSyntaxCommands(ByRef Values() As SyntaxCommand, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSyntaxCommands.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryCopySyntaxCommands(ByRef Destination() As SyntaxCommand, ByRef Source() As SyntaxCommand) As Boolean
Attribute TryCopySyntaxCommands.UBE_Primitive = "Array.TryCopy"
End Function
Intrinsic Function SyntaxLongLength(ByRef Values() As Long) As Long
Attribute SyntaxLongLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeSyntaxLongs(ByRef Values() As Long, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSyntaxLongs.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function LinkedSyntaxNodeLength(ByRef Values() As LinkedSyntaxNode) As Long
Attribute LinkedSyntaxNodeLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeLinkedSyntaxNodes(ByRef Values() As LinkedSyntaxNode, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeLinkedSyntaxNodes.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function EdgeSyntaxNodeLength(ByRef Values() As EdgeSyntaxNode) As Long
Attribute EdgeSyntaxNodeLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeEdgeSyntaxNodes(ByRef Values() As EdgeSyntaxNode, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeEdgeSyntaxNodes.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function LinkedSyntaxResultLength(ByRef Values() As LinkedSyntaxResult) As Long
Attribute LinkedSyntaxResultLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeLinkedSyntaxResults(ByRef Values() As LinkedSyntaxResult, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeLinkedSyntaxResults.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryCopyLinkedSyntaxResults(ByRef Destination() As LinkedSyntaxResult, ByRef Source() As LinkedSyntaxResult) As Boolean
Attribute TryCopyLinkedSyntaxResults.UBE_Primitive = "Array.TryCopy"
End Function
Intrinsic Function EdgeSyntaxResultLength(ByRef Values() As EdgeSyntaxResult) As Long
Attribute EdgeSyntaxResultLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeEdgeSyntaxResults(ByRef Values() As EdgeSyntaxResult, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeEdgeSyntaxResults.UBE_Primitive = "Array.TryResize"
End Function
Intrinsic Function TryCopyEdgeSyntaxResults(ByRef Destination() As EdgeSyntaxResult, ByRef Source() As EdgeSyntaxResult) As Boolean
Attribute TryCopyEdgeSyntaxResults.UBE_Primitive = "Array.TryCopy"
End Function
Intrinsic Function SyntaxWalkFrameLength(ByRef Values() As SyntaxWalkFrame) As Long
Attribute SyntaxWalkFrameLength.UBE_Primitive = "Array.Length"
End Function
Intrinsic Function TryResizeSyntaxWalkFrames(ByRef Values() As SyntaxWalkFrame, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeSyntaxWalkFrames.UBE_Primitive = "Array.TryResize"
End Function

' These rootless operations are actual reads/writes, not counters synthesized
' from N. Native wrappers observe their entries and the runtime's executed copy.
Sub ReadSyntaxCommand(ByRef Destination As SyntaxCommand, ByRef Original As SyntaxCommand)
    Destination = Original
End Sub
Sub WriteSyntaxCommand(ByRef Destination As SyntaxCommand, ByRef Original As SyntaxCommand)
    Destination = Original
End Sub
Sub ReadLinkedSyntaxNode(ByRef Destination As LinkedSyntaxNode, ByRef Original As LinkedSyntaxNode)
    Destination = Original
End Sub
Sub WriteLinkedSyntaxNode(ByRef Destination As LinkedSyntaxNode, ByRef Original As LinkedSyntaxNode)
    Destination = Original
End Sub
Sub ReadEdgeSyntaxNode(ByRef Destination As EdgeSyntaxNode, ByRef Original As EdgeSyntaxNode)
    Destination = Original
End Sub
Sub WriteEdgeSyntaxNode(ByRef Destination As EdgeSyntaxNode, ByRef Original As EdgeSyntaxNode)
    Destination = Original
End Sub
Sub LinkLinkedSyntaxSibling(ByRef Node As LinkedSyntaxNode, ByVal NextSibling As Long)
    Node.NextSibling = NextSibling
End Sub
Sub StoreSyntaxEdge(ByRef Destination As Long, ByVal Child As Long)
    Destination = Child
End Sub
Sub ReadSyntaxEdge(ByRef Destination As Long, ByRef Original As Long)
    Destination = Original
End Sub
Sub ReadLinkedSyntaxChild(ByRef Destination As Long, ByRef Frame As SyntaxWalkFrame)
    Destination = Frame.ChildCursor
End Sub
Sub ReadSyntaxIndex(ByRef Destination As Long, ByRef Original As Long)
    Destination = Original
End Sub
Sub StoreSyntaxIndex(ByRef Destination As Long, ByVal Value As Long)
    Destination = Value
End Sub
Sub ReadSyntaxFrame(ByRef Destination As SyntaxWalkFrame, ByRef Original As SyntaxWalkFrame)
    Destination = Original
End Sub
Sub WriteSyntaxFrame(ByRef Destination As SyntaxWalkFrame, ByRef Original As SyntaxWalkFrame)
    Destination = Original
End Sub

' Pure checked geometric policy. Required=0 needs no allocation. Arithmetic is
' guarded before doubling; budgets are element counts, never grammar limits.
Function TrySyntaxCapacity(ByVal Capacity As Long, ByVal Required As Long, ByVal Maximum As Long, ByRef NewCapacity As Long) As Boolean
    TrySyntaxCapacity = False
    NewCapacity = 0
    If Capacity < 0 Or Required < 0 Or Maximum < 0 Or Required > Maximum Then
        Exit Function
    End If
    NewCapacity = Capacity
    If NewCapacity >= Required Then
        TrySyntaxCapacity = True
        Exit Function
    End If
    If NewCapacity = 0 Then
        NewCapacity = 8
        If NewCapacity > Maximum Then
            NewCapacity = Maximum
        End If
    End If
    While NewCapacity < Required
        If NewCapacity > 1073741823 Then
            NewCapacity = Maximum
        Else
            NewCapacity = NewCapacity * 2
            If NewCapacity > Maximum Then
                NewCapacity = Maximum
            End If
        End If
    Wend
    TrySyntaxCapacity = True
End Function

Function TryReserveSyntaxLongs(ByRef Values() As Long, ByVal Required As Long, ByVal Maximum As Long, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryReserveSyntaxLongs = False
    Failure.Kind = 2
    Dim Capacity As Long = SyntaxLongLength(Values)
    Dim NewCapacity As Long = 0
    If TrySyntaxCapacity(Capacity, Required, Maximum, NewCapacity) = False Then
        Exit Function
    End If
    If NewCapacity <> Capacity Then
        Failure.Kind = 5
        If TryResizeSyntaxLongs(Values, NewCapacity, True) = False Then
            Exit Function
        End If
    End If
    TryReserveSyntaxLongs = True
End Function

Function TryReserveLinkedSyntaxNodes(ByRef Values() As LinkedSyntaxNode, ByVal Required As Long, ByVal Maximum As Long, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryReserveLinkedSyntaxNodes = False
    Failure.Kind = 2
    Dim Capacity As Long = LinkedSyntaxNodeLength(Values)
    Dim NewCapacity As Long = 0
    If TrySyntaxCapacity(Capacity, Required, Maximum, NewCapacity) = False Then
        Exit Function
    End If
    If NewCapacity <> Capacity Then
        Failure.Kind = 5
        If TryResizeLinkedSyntaxNodes(Values, NewCapacity, True) = False Then
            Exit Function
        End If
    End If
    TryReserveLinkedSyntaxNodes = True
End Function

Function TryReserveEdgeSyntaxNodes(ByRef Values() As EdgeSyntaxNode, ByVal Required As Long, ByVal Maximum As Long, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryReserveEdgeSyntaxNodes = False
    Failure.Kind = 2
    Dim Capacity As Long = EdgeSyntaxNodeLength(Values)
    Dim NewCapacity As Long = 0
    If TrySyntaxCapacity(Capacity, Required, Maximum, NewCapacity) = False Then
        Exit Function
    End If
    If NewCapacity <> Capacity Then
        Failure.Kind = 5
        If TryResizeEdgeSyntaxNodes(Values, NewCapacity, True) = False Then
            Exit Function
        End If
    End If
    TryReserveEdgeSyntaxNodes = True
End Function

Function TryReserveSyntaxFrames(ByRef Values() As SyntaxWalkFrame, ByVal Required As Long, ByVal Maximum As Long, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryReserveSyntaxFrames = False
    Failure.Kind = 2
    Dim Capacity As Long = SyntaxWalkFrameLength(Values)
    Dim NewCapacity As Long = 0
    If TrySyntaxCapacity(Capacity, Required, Maximum, NewCapacity) = False Then
        Exit Function
    End If
    If NewCapacity <> Capacity Then
        Failure.Kind = 5
        If TryResizeSyntaxWalkFrames(Values, NewCapacity, True) = False Then
            Exit Function
        End If
    End If
    TryReserveSyntaxFrames = True
End Function

Function TryAppendSyntaxCommand(ByRef Builder As SyntaxCommandBuilder, ByVal Kind As Long, ByVal FirstByte As Long, ByVal LastByte As Long, ByVal ChildCount As Long, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryAppendSyntaxCommand = False
    Failure.Kind = 1
    Failure.CommandIndex = Builder.Count
    Dim Capacity As Long = SyntaxCommandLength(Builder.Commands)
    If Kind < 1 Or FirstByte < 0 Or LastByte < FirstByte Or ChildCount < 0 Then
        Exit Function
    End If
    If Builder.Count < 0 Or Builder.Count > Capacity Or Builder.MaximumRecords < 0 Then
        Exit Function
    End If
    Failure.Kind = 2
    If Builder.Count >= Builder.MaximumRecords Then
        Exit Function
    End If
    Dim NewCapacity As Long = 0
    If TrySyntaxCapacity(Capacity, Builder.Count + 1, Builder.MaximumRecords, NewCapacity) = False Then
        Exit Function
    End If
    If Capacity <> NewCapacity Then
        Failure.Kind = 5
        If TryResizeSyntaxCommands(Builder.Commands, NewCapacity, True) = False Then
            Exit Function
        End If
    End If
    Dim Command As SyntaxCommand
    Command.Kind = Kind
    Command.FirstByte = FirstByte
    Command.LastByte = LastByte
    Command.ChildCount = ChildCount
    Call WriteSyntaxCommand(Builder.Commands(Builder.Count), Command)
    Builder.Count = Builder.Count + 1
    Failure.Kind = 0
    TryAppendSyntaxCommand = True
End Function

' Trims only private Builder capacity. A failed publish preserves every old Out
' element. Builder's logical sequence remains available for a retry after failure.
' Published must not alias the Builder.Commands slot; Builder owns that private
' pending sequence, while Published is the caller's independent prior result.
Function TryPublishSyntaxCommands(ByRef Builder As SyntaxCommandBuilder, ByRef Published() As SyntaxCommand, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryPublishSyntaxCommands = False
    Failure.Kind = 1
    Failure.CommandIndex = -1
    If Builder.Count < 0 Or Builder.MaximumRecords < 0 Or Builder.Count > Builder.MaximumRecords Or Builder.Count > SyntaxCommandLength(Builder.Commands) Then
        Exit Function
    End If
    If Builder.Count > 0 Then
        Failure.CommandIndex = Builder.Count - 1
    End If
    Failure.Kind = 5
    If TryResizeSyntaxCommands(Builder.Commands, Builder.Count, True) = False Then
        Exit Function
    End If
    If TryCopySyntaxCommands(Published, Builder.Commands) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.CommandIndex = -1
    TryPublishSyntaxCommands = True
End Function

' Qualified UTF-8 needs only O(1) checks at span boundaries; byte offsets into
' continuation bytes cannot be original scalar boundaries. No rescanning/copy.
Function TryCheckSyntaxSpan(ByRef Document As SourceDocument, ByVal ByteCount As Long, ByVal FirstByte As Long, ByVal LastByte As Long, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryCheckSyntaxSpan = False
    Failure.Kind = 1
    If FirstByte < 0 Or LastByte < FirstByte Or LastByte > ByteCount Then
        Exit Function
    End If
    If FirstByte < ByteCount Then
        If Document.Bytes(FirstByte) >= 128 And Document.Bytes(FirstByte) < 192 Then
            Exit Function
        End If
    End If
    If LastByte < ByteCount Then
        If Document.Bytes(LastByte) >= 128 And Document.Bytes(LastByte) < 192 Then
            Exit Function
        End If
    End If
    TryCheckSyntaxSpan = True
End Function

' Commands are postorder. Each new node pops its preceding completed roots in
' source order; no child/node array value is assigned in the append loop.
' Every failing path preserves the entire old Output wrapper, arrays and metadata.
Function TryBuildLinkedSyntax(ByRef Document As SourceDocument, ByVal SourceId As Long, ByRef Commands() As SyntaxCommand, ByVal MaximumNodes As Long, ByVal MaximumEdges As Long, ByVal MaximumPending As Long, ByRef Published() As LinkedSyntaxResult, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryBuildLinkedSyntax = False
    Failure.Kind = 1
    Failure.CommandIndex = -1
    If SourceId < 0 Or MaximumNodes < 0 Or MaximumEdges < 0 Or MaximumPending < 0 Then
        Exit Function
    End If
    Dim ByteCount As Long = ByteStorageLength(Document.Bytes)
    Dim Pending() As LinkedSyntaxResult
    Failure.Kind = 5
    If TryResizeLinkedSyntaxResults(Pending, 1, False) = False Then
        Exit Function
    End If
    Pending(0).SourceId = SourceId
    Pending(0).Root = -1
    Dim Stack() As Long
    Dim StackCount As Long = 0
    Dim EdgeCount As Long = 0
    Dim Count As Long = SyntaxCommandLength(Commands)
    Dim Index As Long = 0
    While Index < Count
        Failure.Kind = 5
        Failure.CommandIndex = Index
        Dim Command As SyntaxCommand
        Call ReadSyntaxCommand(Command, Commands(Index))
        Failure.Kind = 1
        If Command.Kind < 1 Or Command.ChildCount < 0 Or Command.ChildCount > StackCount Then
            Exit Function
        End If
        Failure.Kind = 5
        If TryCheckSyntaxSpan(Document, ByteCount, Command.FirstByte, Command.LastByte, Failure) = False Then
            Exit Function
        End If
        Failure.Kind = 2
        If Index >= MaximumNodes Or Command.ChildCount > MaximumEdges - EdgeCount Then
            Exit Function
        End If
        Dim Base As Long = StackCount - Command.ChildCount
        If Base >= MaximumPending Then
            Exit Function
        End If
        Failure.Kind = 5
        If TryReserveLinkedSyntaxNodes(Pending(0).Nodes, Index + 1, MaximumNodes, Failure) = False Then
            Exit Function
        End If
        Failure.Kind = 5
        If TryReserveSyntaxLongs(Stack, Base + 1, MaximumPending, Failure) = False Then
            Exit Function
        End If
        Dim Node As LinkedSyntaxNode
        Node.Kind = Command.Kind
        Node.FirstByte = Command.FirstByte
        Node.LastByte = Command.LastByte
        Node.FirstChild = -1
        Node.NextSibling = -1
        Node.ChildCount = Command.ChildCount
        Dim ChildOrdinal As Long = 0
        Dim PreviousChild As Long = -1
        Dim PreviousLast As Long = Command.FirstByte
        While ChildOrdinal < Command.ChildCount
            Dim ChildIndex As Long = -1
            Call ReadSyntaxIndex(ChildIndex, Stack(Base + ChildOrdinal))
            Dim Child As LinkedSyntaxNode
            Call ReadLinkedSyntaxNode(Child, Pending(0).Nodes(ChildIndex))
            Failure.Kind = 1
            If Child.FirstByte < PreviousLast Or Child.LastByte > Command.LastByte Then
                Exit Function
            End If
            If ChildOrdinal = 0 Then
                Node.FirstChild = ChildIndex
            Else
                Call LinkLinkedSyntaxSibling(Pending(0).Nodes(PreviousChild), ChildIndex)
            End If
            PreviousChild = ChildIndex
            PreviousLast = Child.LastByte
            ChildOrdinal = ChildOrdinal + 1
        Wend
        Call WriteLinkedSyntaxNode(Pending(0).Nodes(Index), Node)
        Call StoreSyntaxIndex(Stack(Base), Index)
        StackCount = Base + 1
        EdgeCount = EdgeCount + Command.ChildCount
        Pending(0).NodeCount = Index + 1
        Pending(0).Root = Index
        Index = Index + 1
    Wend
    Failure.Kind = 1
    If Count > 0 And StackCount <> 1 Then
        Exit Function
    End If
    Failure.Kind = 5
    Failure.CommandIndex = Count - 1
    If TryResizeLinkedSyntaxNodes(Pending(0).Nodes, Count, True) = False Then
        Exit Function
    End If
    If TryCopyLinkedSyntaxResults(Published, Pending) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.CommandIndex = -1
    TryBuildLinkedSyntax = True
End Function

Function TryBuildEdgeSyntax(ByRef Document As SourceDocument, ByVal SourceId As Long, ByRef Commands() As SyntaxCommand, ByVal MaximumNodes As Long, ByVal MaximumEdges As Long, ByVal MaximumPending As Long, ByRef Published() As EdgeSyntaxResult, ByRef Failure As SyntaxProbeFailure) As Boolean
    TryBuildEdgeSyntax = False
    Failure.Kind = 1
    Failure.CommandIndex = -1
    If SourceId < 0 Or MaximumNodes < 0 Or MaximumEdges < 0 Or MaximumPending < 0 Then
        Exit Function
    End If
    Dim ByteCount As Long = ByteStorageLength(Document.Bytes)
    Dim Pending() As EdgeSyntaxResult
    Failure.Kind = 5
    If TryResizeEdgeSyntaxResults(Pending, 1, False) = False Then
        Exit Function
    End If
    Pending(0).SourceId = SourceId
    Pending(0).Root = -1
    Dim Stack() As Long
    Dim StackCount As Long = 0
    Dim EdgeCount As Long = 0
    Dim Count As Long = SyntaxCommandLength(Commands)
    Dim Index As Long = 0
    While Index < Count
        Failure.Kind = 5
        Failure.CommandIndex = Index
        Dim Command As SyntaxCommand
        Call ReadSyntaxCommand(Command, Commands(Index))
        Failure.Kind = 1
        If Command.Kind < 1 Or Command.ChildCount < 0 Or Command.ChildCount > StackCount Then
            Exit Function
        End If
        Failure.Kind = 5
        If TryCheckSyntaxSpan(Document, ByteCount, Command.FirstByte, Command.LastByte, Failure) = False Then
            Exit Function
        End If
        Failure.Kind = 2
        If Index >= MaximumNodes Or Command.ChildCount > MaximumEdges - EdgeCount Then
            Exit Function
        End If
        Dim Base As Long = StackCount - Command.ChildCount
        If Base >= MaximumPending Then
            Exit Function
        End If
        Failure.Kind = 5
        If TryReserveEdgeSyntaxNodes(Pending(0).Nodes, Index + 1, MaximumNodes, Failure) = False Then
            Exit Function
        End If
        Failure.Kind = 5
        If TryReserveSyntaxLongs(Pending(0).Edges, EdgeCount + Command.ChildCount, MaximumEdges, Failure) = False Then
            Exit Function
        End If
        Failure.Kind = 5
        If TryReserveSyntaxLongs(Stack, Base + 1, MaximumPending, Failure) = False Then
            Exit Function
        End If
        Dim Node As EdgeSyntaxNode
        Node.Kind = Command.Kind
        Node.FirstByte = Command.FirstByte
        Node.LastByte = Command.LastByte
        Node.ChildStart = -1
        Node.ChildCount = Command.ChildCount
        If Command.ChildCount > 0 Then
            Node.ChildStart = EdgeCount
        End If
        Dim ChildOrdinal As Long = 0
        Dim PreviousLast As Long = Command.FirstByte
        While ChildOrdinal < Command.ChildCount
            Dim ChildIndex As Long = -1
            Call ReadSyntaxIndex(ChildIndex, Stack(Base + ChildOrdinal))
            Dim Child As EdgeSyntaxNode
            Call ReadEdgeSyntaxNode(Child, Pending(0).Nodes(ChildIndex))
            Failure.Kind = 1
            If Child.FirstByte < PreviousLast Or Child.LastByte > Command.LastByte Then
                Exit Function
            End If
            Call StoreSyntaxEdge(Pending(0).Edges(EdgeCount + ChildOrdinal), ChildIndex)
            PreviousLast = Child.LastByte
            ChildOrdinal = ChildOrdinal + 1
        Wend
        Call WriteEdgeSyntaxNode(Pending(0).Nodes(Index), Node)
        Call StoreSyntaxIndex(Stack(Base), Index)
        StackCount = Base + 1
        EdgeCount = EdgeCount + Command.ChildCount
        Pending(0).NodeCount = Index + 1
        Pending(0).EdgeCount = EdgeCount
        Pending(0).Root = Index
        Index = Index + 1
    Wend
    Failure.Kind = 1
    If Count > 0 And StackCount <> 1 Then
        Exit Function
    End If
    Failure.Kind = 5
    Failure.CommandIndex = Count - 1
    If TryResizeEdgeSyntaxNodes(Pending(0).Nodes, Count, True) = False Then
        Exit Function
    End If
    If TryResizeSyntaxLongs(Pending(0).Edges, EdgeCount, True) = False Then
        Exit Function
    End If
    If TryCopyEdgeSyntaxResults(Published, Pending) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.CommandIndex = -1
    TryBuildEdgeSyntax = True
End Function
