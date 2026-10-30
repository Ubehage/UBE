UBE SOURCE 1 CLASS
Attribute UBE_Name = "AtomicLongLong"

Private Handle As LongLong

' Creates a sequentially consistent 64-bit atomic cell initialized to zero.
Private Sub Class_Initialize()
    Handle = RuntimeAtomicLongLongCreate(0)
End Sub

' Releases the private native cell. No user-owned resource is affected.
Private Sub Class_Terminate()
    Call RuntimeAtomicLongLongDestroy(Handle)
    Handle = 0
End Sub

' Returns the cell's current value with sequentially consistent ordering.
Public Function [Load]() As LongLong
    [Load] = RuntimeAtomicLongLongLoad(Handle)
End Function

' Replaces the value and returns 1 on success, or 0 with Err on failure.
Public Function Store(ByVal Value As LongLong) As Long
    Store = RuntimeAtomicLongLongStore(Handle, Value)
End Function

' Replaces the value and returns the value observed before replacement.
Public Function Exchange(ByVal Value As LongLong) As LongLong
    Exchange = RuntimeAtomicLongLongExchange(Handle, Value)
End Function

' Replaces Expected with Replacement when it still matches, and returns the
' value that was observed. Comparing the result with Expected reports success.
Public Function CompareExchange(ByVal Expected As LongLong, ByVal Replacement As LongLong) As LongLong
    CompareExchange = RuntimeAtomicLongLongCompareExchange(Handle, Expected, Replacement)
End Function

' Adds Delta atomically and returns the resulting value.
Public Function Add(ByVal Delta As LongLong) As LongLong
    Add = RuntimeAtomicLongLongAdd(Handle, Delta)
End Function

' Adds one atomically and returns the resulting value.
Public Function Increment() As LongLong
    Increment = RuntimeAtomicLongLongAdd(Handle, 1)
End Function

' Subtracts one atomically and returns the resulting value.
Public Function Decrement() As LongLong
    Decrement = RuntimeAtomicLongLongAdd(Handle, -1)
End Function
