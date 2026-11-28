UBE SOURCE 1 MODULE
' Bounded garbage regression: fixed live values must not require allocation failure to collect.
Attribute UBE_Name = "Workload"
Option Explicit
Public Const IterationsPerBatch As Long = 128
' The gate substitutes a read-only native observer at this allowed primitive call.
Private Intrinsic Function Observe() As LongLong
Attribute Observe.UBE_Primitive = "Thread.CurrentId"
End Function
Private Intrinsic Function Collect() As Long
Attribute Collect.UBE_Primitive = "Memory.Collect"
End Function
Private Intrinsic Function SetError(ByVal Number As Long) As Boolean
Attribute SetError.UBE_Primitive = "Error.Set"
End Function
Private Function CountAllocations(ByRef RootTotal As Long) As Long
 Dim Observed As LongLong
 Observed = Observe()
 RootTotal = Observed Mod 1000
 CountAllocations = Observed \ 1000
End Function
Private Sub AllocateWorker(ByVal Item As Counter, ByVal Count As Long, ByVal Seed As Long)
 Dim Index As Long
 Dim Prefix As String
 Dim Expected As String
 On Error GoTo Failed
 Prefix = Seed
 Expected = Prefix & "é"
 Call SetError(55)
 For Index = 1 To Count
  SyncLock Item
   Item.Label = Prefix & "é"
   If Item.Label <> Expected Then Err.Raise 5
   Item.Value = Item.Value + Index + Seed
  End SyncLock
 Next Index
 If Err.Number <> 55 Then Err.Raise 5
 SyncLock Item
  Item.Value = Item.Value + 1
 End SyncLock
 Exit Sub
Failed:
 Err.Raise Err.Number
End Sub
Public Function Run(ByVal Count As Long, ByVal Seed As Long) As LongLong
 Dim Item As Counter
 Dim Prefix As String
 Dim Expected As String
 Dim Index As Long
 Dim Before As Long
 Dim After As Long
 Dim BeforeRoots As Long
 Dim AfterRoots As Long
 Dim Total As LongLong
 Dim FirstWorker As LongLong
 Dim SecondWorker As LongLong
 On Error GoTo Failed
 Prefix = Seed
 Expected = Prefix & "é"
 Set Item = New Counter
 Call SetError(55)
 For Index = 1 To Count
  Item.Value = Index + Seed
  Item.Label = Prefix & "é"
  If Item.Label <> Expected Then Err.Raise 5
  Total = Total + Item.ReadValue()
  If Seed = 2 Then Call Collect()
 Next Index
 If Seed = 3 Then
  Item.Value = 0
  FirstWorker = CallNew AllocateWorker(Item, Count, Seed)
  SecondWorker = CallNew AllocateWorker(Item, Count, Seed)
  If ThreadPrimitives.Wait(FirstWorker, 20000) <> 1 Then Err.Raise 5
  If ThreadPrimitives.Wait(SecondWorker, 20000) <> 1 Then Err.Raise 5
  If Item.ReadValue() <> Count * (Count + 1) + 2 * Seed * Count + 2 Then Err.Raise 5
 End If
 If Err.Number <> 55 Then Err.Raise 5
 Before = CountAllocations(BeforeRoots)
 Call Collect()
 After = CountAllocations(AfterRoots)
 If Item.Label <> Expected Then Err.Raise 5
 If Total <> Count * (Count + 1) \ 2 + Seed * Count Then Err.Raise 5
 Run = Before * 1000000000&& + After * 1000000&& + BeforeRoots * 1000 + AfterRoots
 Exit Function
Failed:
 Err.Raise Err.Number
End Function
