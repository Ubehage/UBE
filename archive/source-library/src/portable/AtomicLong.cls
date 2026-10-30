UBE SOURCE 1 CLASS
Attribute UBE_Name = "AtomicLong"

Private Handle As LongLong

' Creates a sequentially consistent 32-bit atomic cell initialized to zero.
Private Sub Class_Initialize()
    Handle = RuntimeAtomicLongCreate(0)
End Sub

' Releases the private native cell. No user-owned resource is affected.
Private Sub Class_Terminate()
    Call RuntimeAtomicLongDestroy(Handle)
    Handle = 0
End Sub

' Returns the cell's current value with sequentially consistent ordering.
Public Function [Load]() As Long
    [Load] = RuntimeAtomicLongLoad(Handle)
End Function

' Replaces the value and returns 1 on success, or 0 with Err on failure.
Public Function Store(ByVal Value As Long) As Long
    Store = RuntimeAtomicLongStore(Handle, Value)
End Function

' Replaces the value and returns the value observed before replacement.
Public Function Exchange(ByVal Value As Long) As Long
    Exchange = RuntimeAtomicLongExchange(Handle, Value)
End Function

' Replaces Expected with Replacement when it still matches, and returns the
' value that was observed. Comparing the result with Expected reports success.
Public Function CompareExchange(ByVal Expected As Long, ByVal Replacement As Long) As Long
    CompareExchange = RuntimeAtomicLongCompareExchange(Handle, Expected, Replacement)
End Function

' Adds Delta atomically and returns the resulting value.
Public Function Add(ByVal Delta As Long) As Long
    Add = RuntimeAtomicLongAdd(Handle, Delta)
End Function

' Adds one atomically and returns the resulting value.
Public Function Increment() As Long
    Increment = RuntimeAtomicLongAdd(Handle, 1)
End Function

' Subtracts one atomically and returns the resulting value.
Public Function Decrement() As Long
    Decrement = RuntimeAtomicLongAdd(Handle, -1)
End Function
