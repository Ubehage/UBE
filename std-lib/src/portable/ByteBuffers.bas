UBE SOURCE 1 MODULE
Attribute UBE_Name = "ByteBuffers"
' Implements counted-buffer publication policy as ordinary portable UBE source.

' Appends a source span and publishes the new used count only after successful copying.
Public Function AppendBytes(ByRef Destination() As Byte, ByRef Used As Long, ByRef Source() As Byte, ByVal SourceStart As Long, ByVal Count As Long) As Long
    Dim Capacity As Long
    Dim Remaining As Long
    Dim Copied As Boolean
    If Used < 0 Then Err.Raise 5
    If Count < 0 Then Err.Raise 5
    Capacity = BufferPrimitives.ByteStorageLength(Destination)
    If Used > Capacity Then Err.Raise 9
    Remaining = Capacity + -Used
    If Count > Remaining Then Err.Raise 9
    Copied = BufferPrimitives.CopyByteRange(Source, SourceStart, Destination, Used, Count)
    If Copied = False Then Err.Raise Err.Number
    Used = Used + Count
    AppendBytes = Used
End Function
