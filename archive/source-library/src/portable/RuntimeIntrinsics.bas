UBE SOURCE 1 MODULE
Attribute UBE_Name = "RuntimeIntrinsics"

' Private target hooks needed by the first callable UBECore slice. These are
' compiler contracts, not public source-library procedures.
Intrinsic Function StringLength(ByVal Value As String) As Long
End Function

Intrinsic Function StringByteAt(ByVal Value As String, ByVal Index As Long) As Long
End Function

Intrinsic Function LongToString(ByVal Value As Long) As String
End Function

Intrinsic Function ManagedCollectGarbage() As Long
End Function

Intrinsic Function ManagedVariantEmpty() As Variant
End Function

Intrinsic Function ManagedVariantNull() As Variant
End Function

Intrinsic Function ManagedVariantFromLong(ByVal Value As Long) As Variant
End Function

Intrinsic Function ManagedVariantCopy(ByVal Value As Variant) As Variant
End Function

Intrinsic Function ManagedVariantTag(ByVal Value As Variant) As Long
End Function

Intrinsic Function ManagedVariantGetLong(ByVal Value As Variant, ByRef Result As Long) As Long
End Function

' Returns the calling thread's current recoverable error number.
Intrinsic Function RuntimeErrorNumber() As Long
End Function

' Returns an independent copy of the calling thread's error description.
Intrinsic Function RuntimeErrorDescription() As String
End Function

' Returns an independent copy of the calling thread's error source.
Intrinsic Function RuntimeErrorSource() As String
End Function

' Clears only the calling thread's recoverable error record.
Intrinsic Sub RuntimeErrorClear()
End Sub

' Records a recoverable error in only the calling thread.
Intrinsic Sub RuntimeErrorSet(ByVal Number As Long, ByVal Description As String, ByVal Source As String)
End Sub

' Returns the stable native-thread identifier assigned to the calling thread.
Intrinsic Function RuntimeCurrentThreadId() As LongLong
End Function

' Returns True while an issued thread identifier is still executing.
Intrinsic Function RuntimeThreadIsAlive(ByVal Id As LongLong) As Boolean
End Function

' Waits for completion, cancellation, or timeout using the UBE 1/0 convention.
Intrinsic Function RuntimeThreadWait(ByVal Id As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

' Records the target thread's sticky cooperative stop request.
Intrinsic Function RuntimeThreadRequestStop(ByVal Id As LongLong) As Long
End Function

' Returns True when the current worker has a pending stop request.
Intrinsic Function RuntimeThreadStopRequested() As Boolean
End Function

' Offers another runnable native thread an execution opportunity.
Intrinsic Sub RuntimeThreadYield()
End Sub

' Allocates and operates on a sequentially consistent 32-bit atomic cell.
Intrinsic Function RuntimeAtomicLongCreate(ByVal InitialValue As Long) As LongLong
End Function
Intrinsic Sub RuntimeAtomicLongDestroy(ByVal Handle As LongLong)
End Sub
Intrinsic Function RuntimeAtomicLongLoad(ByVal Handle As LongLong) As Long
End Function
Intrinsic Function RuntimeAtomicLongStore(ByVal Handle As LongLong, ByVal Value As Long) As Long
End Function
Intrinsic Function RuntimeAtomicLongExchange(ByVal Handle As LongLong, ByVal Value As Long) As Long
End Function
Intrinsic Function RuntimeAtomicLongCompareExchange(ByVal Handle As LongLong, ByVal Expected As Long, ByVal Replacement As Long) As Long
End Function
Intrinsic Function RuntimeAtomicLongAdd(ByVal Handle As LongLong, ByVal Delta As Long) As Long
End Function

' Allocates and operates on a sequentially consistent 64-bit atomic cell.
Intrinsic Function RuntimeAtomicLongLongCreate(ByVal InitialValue As LongLong) As LongLong
End Function
Intrinsic Sub RuntimeAtomicLongLongDestroy(ByVal Handle As LongLong)
End Sub
Intrinsic Function RuntimeAtomicLongLongLoad(ByVal Handle As LongLong) As LongLong
End Function
Intrinsic Function RuntimeAtomicLongLongStore(ByVal Handle As LongLong, ByVal Value As LongLong) As Long
End Function
Intrinsic Function RuntimeAtomicLongLongExchange(ByVal Handle As LongLong, ByVal Value As LongLong) As LongLong
End Function
Intrinsic Function RuntimeAtomicLongLongCompareExchange(ByVal Handle As LongLong, ByVal Expected As LongLong, ByVal Replacement As LongLong) As LongLong
End Function
Intrinsic Function RuntimeAtomicLongLongAdd(ByVal Handle As LongLong, ByVal Delta As LongLong) As LongLong
End Function

' Creates and operates on the target adapter behind a ThreadEvent object.
Intrinsic Function RuntimeThreadEventCreate(ByVal ManualReset As Long, ByVal InitiallySignaled As Long) As LongLong
End Function
Intrinsic Sub RuntimeThreadEventDestroy(ByVal Handle As LongLong)
End Sub
Intrinsic Function RuntimeThreadEventSet(ByVal Handle As LongLong) As Long
End Function
Intrinsic Function RuntimeThreadEventReset(ByVal Handle As LongLong) As Long
End Function
Intrinsic Function RuntimeThreadEventWait(ByVal Handle As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

' Creates and operates on the target adapter behind a Semaphore object.
Intrinsic Function RuntimeSemaphoreCreate(ByVal InitialCount As LongLong, ByVal MaximumCount As LongLong) As LongLong
End Function
Intrinsic Sub RuntimeSemaphoreDestroy(ByVal Handle As LongLong)
End Sub
Intrinsic Function RuntimeSemaphoreWait(ByVal Handle As LongLong, ByVal TimeoutMilliseconds As LongLong) As Long
End Function
Intrinsic Function RuntimeSemaphoreRelease(ByVal Handle As LongLong, ByVal PermitCount As LongLong) As Long
End Function

' Creates and operates on the target adapter behind a MessageQueue object.
Intrinsic Function RuntimeMessageQueueCreate() As LongLong
End Function
Intrinsic Sub RuntimeMessageQueueDestroy(ByVal Handle As LongLong)
End Sub
Intrinsic Function RuntimeMessageQueueEnqueue(ByVal Handle As LongLong, ByVal Value As Variant) As Long
End Function
Intrinsic Function RuntimeMessageQueueDequeue(ByVal Handle As LongLong, ByRef Value As Variant, ByVal TimeoutMilliseconds As LongLong) As Long
End Function

' Creates and operates on the rooted cell behind an AtomicObject instance.
Intrinsic Function RuntimeAtomicObjectCreate() As LongLong
End Function
Intrinsic Sub RuntimeAtomicObjectDestroy(ByVal Handle As LongLong)
End Sub
Intrinsic Function RuntimeAtomicObjectLoad(ByVal Handle As LongLong, ByRef Value As Object) As Long
End Function
Intrinsic Function RuntimeAtomicObjectStore(ByVal Handle As LongLong, ByVal Value As Object) As Long
End Function
Intrinsic Function RuntimeAtomicObjectExchange(ByVal Handle As LongLong, ByVal Value As Object, ByRef Observed As Object) As Long
End Function
Intrinsic Function RuntimeAtomicObjectCompareExchange(ByVal Handle As LongLong, ByVal Expected As Object, ByVal Replacement As Object, ByRef Observed As Object) As Long
End Function
