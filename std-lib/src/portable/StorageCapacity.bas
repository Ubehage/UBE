UBE SOURCE 1 MODULE
Attribute UBE_Name = "StorageCapacity"

' Contract: ../../STORAGE-CAPACITY-CONTRACT.md.
' Scalar geometric capacity planning; no allocation, copies, retained references,
' managed roots or Err effects. Capacity is already-owned physical storage;
' Maximum limits the logical request and never shrinks sufficient old storage.
' Failure preserves Prepared. Calls have private state and are reentrant.
Private Function NextStorageCapacity(ByVal Capacity As Long, ByVal Maximum As Long) As Long
    If Capacity > Maximum \ 2 Then
        NextStorageCapacity = Maximum
    Else
        NextStorageCapacity = Capacity * 2
    End If
End Function

Function TryGetStorageCapacity(ByVal Capacity As Long, ByVal Required As Long, ByVal Maximum As Long, ByRef Prepared As Long) As Boolean
    TryGetStorageCapacity = False
    If Capacity < 0 Or Required < 0 Or Maximum < 0 Or Required > Maximum Then
        Exit Function
    End If
    Dim Candidate As Long = Capacity
    If Candidate < Required Then
        If Candidate = 0 Then
            Candidate = 8
            If Candidate > Maximum Then
                Candidate = Maximum
            End If
        End If
        While Candidate < Required
            Candidate = NextStorageCapacity(Candidate, Maximum)
        Wend
    End If
    Prepared = Candidate
    TryGetStorageCapacity = True
End Function
