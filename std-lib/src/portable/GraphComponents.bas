UBE SOURCE 1 MODULE
Attribute UBE_Name = "GraphComponents"

' Iterative directed components; see ../../GRAPH-COMPONENTS-CONTRACT.md.
' Matrix is immutable and borrowed. One owner retains exactly 20*Capacity
' payload bytes; no compiler policy or cancellation object enters this module.
Type GraphComponentSlot
    Seen As Long
    Order As Long
    Component As Long
    Vertex As Long
    Neighbor As Long
End Type
Type GraphComponents
    Slots() As GraphComponentSlot
    Capacity As Long
    Status As Long
    Direction As Long
    Index As Long
    StackCount As Long
    OrderCount As Long
    ComponentCount As Long
End Type
Private Intrinsic Function GraphMatrixLength(ByRef Matrix() As Long) As Long
Attribute GraphMatrixLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function GraphSlotsLength(ByRef Slots() As GraphComponentSlot) As Long
Attribute GraphSlotsLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeGraphSlots(ByRef Slots() As GraphComponentSlot, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeGraphSlots.UBE_Primitive = "Array.TryResize"
End Function

' Fresh empty owner only. Caller admits 20*VertexCount payload before entry.
' A failed allocation leaves Status 4 and Capacity 0; disposal is still valid.
Function TryBeginGraphComponents(ByRef State As GraphComponents, ByRef Matrix() As Long, ByVal VertexCount As Long, ByRef Failure As Long) As Boolean
    TryBeginGraphComponents = False
    Failure = 5
    If State.Status <> 0 Or State.Capacity <> 0 Then
        Failure = 1
        Exit Function
    End If
    State.Status = 4
    If VertexCount < 0 Or GraphSlotsLength(State.Slots) <> 0 Then
        Failure = 1
        Exit Function
    End If
    Dim Cells As LongLong = VertexCount
    Cells = Cells * VertexCount
    If Cells > GraphMatrixLength(Matrix) Then
        Failure = 1
        Exit Function
    End If
    If TryResizeGraphSlots(State.Slots, VertexCount, False) = False Then
        Exit Function
    End If
    State.Capacity = VertexCount
    State.Direction = 0
    State.Index = 0
    State.StackCount = 0
    State.OrderCount = 0
    State.ComponentCount = 0
    State.Status = 1
    If VertexCount = 0 Then
        State.Status = 2
    End If
    Failure = 0
    TryBeginGraphComponents = True
End Function

Private Function ValidGraphComponentOwner(ByRef State As GraphComponents, ByRef Failure As Long) As Boolean
    ValidGraphComponentOwner = False
    Failure = 1
    If State.Capacity < 0 Or State.Capacity > GraphSlotsLength(State.Slots) Then
        Exit Function
    End If
    If State.Direction < 0 Or State.Direction > 2 Then
        Exit Function
    End If
    If State.StackCount < 0 Or State.StackCount > State.Capacity Then
        Exit Function
    End If
    If State.OrderCount < 0 Or State.OrderCount > State.Capacity Then
        Exit Function
    End If
    If State.ComponentCount < 0 Or State.ComponentCount > State.Capacity Then
        Exit Function
    End If
    If State.Index < -1 Or State.Index > State.Capacity Then
        Exit Function
    End If
    Failure = 0
    ValidGraphComponentOwner = True
End Function

' Push only an unseen/unassigned vertex; mark before it becomes reachable
' again. Stack fields and per-vertex fields occupy disjoint record members.
Private Function TryPushGraphVertex(ByRef State As GraphComponents, ByVal Vertex As Long, ByVal MaximumPending As Long, ByRef PeakPending As Long, ByRef Failure As Long) As Boolean
    TryPushGraphVertex = False
    Failure = 1
    If Vertex < 0 Or Vertex >= State.Capacity Or State.StackCount >= State.Capacity Then
        Exit Function
    End If
    If State.StackCount >= MaximumPending Then
        Failure = 2
        Exit Function
    End If
    If State.Direction = 1 Then
        State.Slots(Vertex).Seen = 1
    Else
        State.Slots(Vertex).Component = State.ComponentCount
    End If
    State.Slots(State.StackCount).Vertex = Vertex
    State.Slots(State.StackCount).Neighbor = 0
    State.StackCount = State.StackCount + 1
    If State.StackCount > PeakPending Then
        PeakPending = State.StackCount
    End If
    Failure = 0
    TryPushGraphVertex = True
End Function

Private Function TryGraphComponentTransition(ByRef State As GraphComponents, ByRef Matrix() As Long, ByVal MaximumPending As Long, ByRef PeakPending As Long, ByRef Failure As Long) As Boolean
    TryGraphComponentTransition = False
    Failure = 1
    If State.Direction = 0 Then
        If State.Index < 0 Or State.Index >= State.Capacity Then
            Exit Function
        End If
        State.Slots(State.Index).Seen = 0
        State.Slots(State.Index).Order = 0
        State.Slots(State.Index).Component = 0
        State.Slots(State.Index).Vertex = 0
        State.Slots(State.Index).Neighbor = 0
        State.Index = State.Index + 1
        If State.Index = State.Capacity Then
            State.Index = 0
            State.Direction = 1
        End If
        Failure = 0
        TryGraphComponentTransition = True
        Exit Function
    End If
    If State.StackCount > 0 Then
        Dim Top As Long = State.StackCount - 1
        Dim Vertex As Long = State.Slots(Top).Vertex
        Dim Neighbor As Long = State.Slots(Top).Neighbor
        If Vertex < 0 Or Vertex >= State.Capacity Or Neighbor < 0 Or Neighbor > State.Capacity Then
            Exit Function
        End If
        If Neighbor < State.Capacity Then
            State.Slots(Top).Neighbor = Neighbor + 1
            Dim Cell As Long = Vertex * State.Capacity + Neighbor
            If State.Direction = 2 Then
                Cell = Neighbor * State.Capacity + Vertex
            End If
            If Matrix(Cell) <> 0 Then
                Dim Fresh As Boolean = State.Slots(Neighbor).Seen = 0
                If State.Direction = 2 Then
                    Fresh = State.Slots(Neighbor).Component = 0
                End If
                If Fresh Then
                    Failure = 5
                    If TryPushGraphVertex(State, Neighbor, MaximumPending, PeakPending, Failure) = False Then
                        Exit Function
                    End If
                End If
            End If
        Else
            If State.Direction = 1 Then
                If State.OrderCount >= State.Capacity Then
                    Exit Function
                End If
                State.Slots(State.OrderCount).Order = Vertex
                State.OrderCount = State.OrderCount + 1
            End If
            State.StackCount = Top
        End If
        Failure = 0
        TryGraphComponentTransition = True
        Exit Function
    End If
    If State.Direction = 1 Then
        If State.Index < 0 Then
            Exit Function
        End If
        If State.Index < State.Capacity Then
            Dim NextVertex As Long = State.Index
            State.Index = State.Index + 1
            If State.Slots(NextVertex).Seen = 0 Then
                Failure = 5
                If TryPushGraphVertex(State, NextVertex, MaximumPending, PeakPending, Failure) = False Then
                    Exit Function
                End If
            End If
        Else
            If State.OrderCount <> State.Capacity Then
                Exit Function
            End If
            State.Direction = 2
            State.Index = State.Capacity - 1
        End If
    Else
        If State.Index >= State.Capacity Then
            Exit Function
        End If
        If State.Index >= 0 Then
            Dim OrderedVertex As Long = State.Slots(State.Index).Order
            State.Index = State.Index - 1
            If OrderedVertex < 0 Or OrderedVertex >= State.Capacity Then
                Exit Function
            End If
            If State.Slots(OrderedVertex).Component = 0 Then
                If State.ComponentCount >= State.Capacity Then
                    Exit Function
                End If
                State.ComponentCount = State.ComponentCount + 1
                Failure = 5
                If TryPushGraphVertex(State, OrderedVertex, MaximumPending, PeakPending, Failure) = False Then
                    Exit Function
                End If
            End If
        Else
            State.Status = 2
        End If
    End If
    Failure = 0
    TryGraphComponentTransition = True
End Function

' Borrow the unchanged matrix from begin. No allocation or copying occurs.
' Caller limits the allowance to remaining work and checks cancellation between
' calls. MaximumPending is checked before each push; Pending and PeakPending
' report the live stack and this call's peak, including a failing transition.
' Caller seeds both from its prior live count before managed entry. Work reports
' actual attempted transitions; partial labels remain private.
Function TryAdvanceGraphComponents(ByRef State As GraphComponents, ByRef Matrix() As Long, ByVal MaximumWork As Long, ByVal MaximumPending As Long, ByRef Work As Long, ByRef Pending As Long, ByRef PeakPending As Long, ByRef Complete As Boolean, ByRef Failure As Long) As Boolean
    TryAdvanceGraphComponents = False
    Failure = 5
    Work = 0
    Complete = False
    If (State.Status <> 1 And State.Status <> 2) Or MaximumWork < 0 Or MaximumPending < 0 Then
        If State.Status = 1 Then
            State.Status = 4
        End If
        Failure = 1
        Exit Function
    End If
    If ValidGraphComponentOwner(State, Failure) = False Then
        State.Status = 4
        Exit Function
    End If
    Pending = State.StackCount
    PeakPending = Pending
    If Pending > MaximumPending Then
        State.Status = 4
        Failure = 2
        Exit Function
    End If
    Dim Cells As LongLong = State.Capacity
    Cells = Cells * State.Capacity
    If Cells > GraphMatrixLength(Matrix) Then
        State.Status = 4
        Failure = 1
        Exit Function
    End If
    While Work < MaximumWork And State.Status = 1
        Failure = 5
        Work = Work + 1
        Dim Accepted As Boolean = TryGraphComponentTransition(State, Matrix, MaximumPending, PeakPending, Failure)
        Pending = State.StackCount
        If Accepted = False Then
            State.Status = 4
            Exit Function
        End If
    Wend
    Complete = State.Status = 2
    Failure = 0
    TryAdvanceGraphComponents = True
End Function

' Output is meaningful only after completion. Invalid reads preserve Label.
Function TryReadGraphComponent(ByRef State As GraphComponents, ByVal Vertex As Long, ByRef Label As Long, ByRef Failure As Long) As Boolean
    TryReadGraphComponent = False
    Failure = 5
    If State.Status <> 2 Or Vertex < 0 Or Vertex >= State.Capacity Then
        Failure = 1
        Exit Function
    End If
    If State.Capacity > GraphSlotsLength(State.Slots) Then
        Failure = 1
        Exit Function
    End If
    Dim Found As Long = State.Slots(Vertex).Component
    If Found < 1 Or Found > State.ComponentCount Then
        Failure = 1
        Exit Function
    End If
    Label = Found
    Failure = 0
    TryReadGraphComponent = True
End Function

' Ends payload ownership after success, failure or caller cancellation.
Function TryDisposeGraphComponents(ByRef State As GraphComponents, ByRef Failure As Long) As Boolean
    TryDisposeGraphComponents = False
    Failure = 5
    If TryResizeGraphSlots(State.Slots, 0, False) = False Then
        Exit Function
    End If
    State.Capacity = 0
    State.Status = 0
    State.Direction = 0
    State.Index = 0
    State.StackCount = 0
    State.OrderCount = 0
    State.ComponentCount = 0
    Failure = 0
    TryDisposeGraphComponents = True
End Function
