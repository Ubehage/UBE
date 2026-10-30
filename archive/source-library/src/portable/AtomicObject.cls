UBE SOURCE 1 CLASS
Attribute UBE_Name = "AtomicObject"

Private Handle As LongLong

' Creates a sequentially consistent object-reference cell set to Nothing.
Private Sub Class_Initialize()
    Handle = RuntimeAtomicObjectCreate()
End Sub

' Releases the cell's managed root and its internal synchronization resource.
Private Sub Class_Terminate()
    Call RuntimeAtomicObjectDestroy(Handle)
    Handle = 0
End Sub

' Returns the current shared object identity, or Nothing with Err on failure.
Public Function [Load]() As Object
    Dim Result As Object
    If RuntimeAtomicObjectLoad(Handle, Result) <> 0 Then
        Set [Load] = Result
    Else
        Set [Load] = Nothing
    End If
End Function

' Replaces the shared identity and returns 1, or 0 with Err on failure.
Public Function Store(ByVal Value As Object) As Long
    Store = RuntimeAtomicObjectStore(Handle, Value)
End Function

' Replaces the identity and returns the identity observed beforehand.
Public Function Exchange(ByVal Value As Object) As Object
    Dim Observed As Object
    If RuntimeAtomicObjectExchange(Handle, Value, Observed) <> 0 Then
        Set Exchange = Observed
    Else
        Set Exchange = Nothing
    End If
End Function

' Replaces Expected with Replacement when the identities match, and returns
' the observed identity so callers can determine whether replacement occurred.
Public Function CompareExchange(ByVal Expected As Object, ByVal Replacement As Object) As Object
    Dim Observed As Object
    If RuntimeAtomicObjectCompareExchange(Handle, Expected, Replacement, Observed) <> 0 Then
        Set CompareExchange = Observed
    Else
        Set CompareExchange = Nothing
    End If
End Function
