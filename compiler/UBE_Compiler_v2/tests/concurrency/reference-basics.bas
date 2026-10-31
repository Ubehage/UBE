UBE SOURCE 1 MODULE
Attribute UBE_Name = "ReferenceBasics"

' Independent reference passing, record copying and lifetime controls.
Type OwnerPair
    Owner As ByteOwner
    Bytes() As Byte
End Type

' Allocate bytes through a normal borrowed array parameter.
Sub FillBytes(ByRef Data() As Byte)
    ReDim Data(2)
    Data(0) = 7
    Data(1) = 11
    Data(2) = 13
End Sub

' ByVal shares only the object's identity, including its byte storage.
Sub ChangeOwner(ByVal Owner As ByteOwner)
    Owner.Count = 99
    Owner.Data(0) = 23
    Set Owner = New ByteOwner
    Owner.Count = 101
End Sub

' Independent record copies retain references but duplicate value arrays.
Sub ChangePair(ByVal Pair As OwnerPair)
    Pair.Owner.Count = 31
    Pair.Bytes(0) = 41
    Print Pair.Bytes(0)
End Sub

' A managed return must reach a caller-rooted result slot.
Function CreateOwner() As ByteOwner
    Dim Owner As ByteOwner
    Set Owner = New ByteOwner
    Owner.Count = 53
    Set Owner.Link = Owner
    Set CreateOwner = Owner
End Function

' Exposes neutral New failure without performing a later invalid member access.
Function AllocateOwner() As ByteOwner
    Set AllocateOwner = New ByteOwner
End Function

' Neutral access must return through controlled cleanup rather than touch null.
Function ReadOwnerCount(ByVal Owner As ByteOwner) As Long
    ReadOwnerCount = Owner.Count
End Function

' An array copy duplicates its slots while retaining element identities.
Sub ChangeOwnerArray(ByVal Owners() As ByteOwner)
    Owners(0).Count = 67
    Set Owners(0) = New ByteOwner
    Owners(0).Count = 71
End Sub

' A borrowed reference parameter changes the caller's slot.
Sub ResetOwner(ByRef Owner As ByteOwner)
    Set Owner = Nothing
End Sub

' Exact output exposes shared identity, private values and neutral references.
Function Main() As Long
    Dim Owner As ByteOwner
    Dim Other As ByteOwner
    Dim Pair As OwnerPair
    Dim Owners() As ByteOwner
    Set Owner = New ByteOwner
    Set Other = Owner
    Call FillBytes(Owner.Data)
    Call ChangeOwner(Other)
    Print Owner.Count
    Print Owner.Data(0)
    If Owner Is Other Then
        Print 1
    End If
    Set Owner.Link = Owner
    Set Pair.Owner = Owner
    Call FillBytes(Pair.Bytes)
    Call ChangePair(Pair)
    Print Owner.Count
    Print Pair.Bytes(0)
    ReDim Owners(1)
    Set Owners(0) = Owner
    Call ChangeOwnerArray(Owners)
    Print Owner.Count
    If Owners(0) Is Owner Then
        Print 3
    End If
    Set Other = Nothing
    If Other Is Nothing Then
        Print 2
    End If
    Set Other = CreateOwner()
    Print Other.Count
    If Owner Is Other Then
        Main = 1
        Exit Function
    End If
    Print Owner.Link.Count
    Call ResetOwner(Other)
    If Other Is Nothing Then
        Print 4
    End If
    Main = 0
End Function
