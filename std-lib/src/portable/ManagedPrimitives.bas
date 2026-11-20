UBE SOURCE 1 MODULE
Attribute UBE_Name = "ManagedPrimitives"
' Precise snapshot access for the ordinary UBE collector; see runtime/managed-memory.md.
' The compiler validates these declarations against the native managed-memory interface.

' True owns the stopped snapshot; False observes a completed round in the outputs.
Public Intrinsic Function BeginCollection(ByRef PriorWork As Long, ByRef PriorError As Long) As Boolean
Attribute BeginCollection.UBE_Primitive = "Managed.BeginCollection"
End Function

' Releases the snapshot on every exit, clears marks, and resumes parked threads.
Public Intrinsic Function EndCollection(ByVal Work As Long, ByVal ErrorNumber As Long) As Boolean
Attribute EndCollection.UBE_Primitive = "Managed.EndCollection"
End Function

' Counts are fixed until EndCollection, including after individual reclamation.
Public Intrinsic Function TrySnapshotCounts(ByRef AllocationCount As Long, ByRef RootCount As Long) As Boolean
Attribute TrySnapshotCounts.UBE_Primitive = "Managed.SnapshotCounts"
End Function

' A reclaimed snapshot slot returns zero; an invalid index returns False and Err 5.
Public Intrinsic Function TryAllocationAt(ByVal Index As Long, ByRef Handle As LongLong) As Boolean
Attribute TryAllocationAt.UBE_Primitive = "Managed.AllocationAt"
End Function

' Includes construction roots and exact fields in externally retained native owners.
Public Intrinsic Function TryRootAt(ByVal Index As Long, ByRef Handle As LongLong) As Boolean
Attribute TryRootAt.UBE_Primitive = "Managed.RootAt"
End Function

' Empty is valid and never newly marked; invalid nonzero identities return False.
Public Intrinsic Function TryMark(ByVal Handle As LongLong, ByRef Fresh As Boolean) As Boolean
Attribute TryMark.UBE_Primitive = "Managed.Mark"
End Function

Public Intrinsic Function TryMarked(ByVal Handle As LongLong, ByRef Marked As Boolean) As Boolean
Attribute TryMarked.UBE_Primitive = "Managed.Marked"
End Function

' Only exact layout-declared reference slots are returned, without following edges.
Public Intrinsic Function TryEdgeCount(ByVal Handle As LongLong, ByRef Count As Long) As Boolean
Attribute TryEdgeCount.UBE_Primitive = "Managed.EdgeCount"
End Function

Public Intrinsic Function TryEdgeAt(ByVal Handle As LongLong, ByVal Index As Long, ByRef Edge As LongLong) As Boolean
Attribute TryEdgeAt.UBE_Primitive = "Managed.EdgeAt"
End Function

' Commits complete marking. Reclamation is forbidden until this call succeeds.
Public Intrinsic Function SealCollection() As Boolean
Attribute SealCollection.UBE_Primitive = "Managed.SealCollection"
End Function

' Reclaims one unmarked identity selected by the UBE collector; no allocation occurs.
Public Intrinsic Function TryReclaim(ByVal Handle As LongLong) As Boolean
Attribute TryReclaim.UBE_Primitive = "Managed.Reclaim"
End Function

' Numeric collector workspace uses the existing program quota without recursive collection.
Public Intrinsic Function TryResizeWork(ByRef Values() As LongLong, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute TryResizeWork.UBE_Primitive = "Managed.Workspace"
End Function

Public Intrinsic Function RecordError(ByVal Number As Long) As Boolean
Attribute RecordError.UBE_Primitive = "Error.Set"
End Function
