UBE SOURCE 1 MODULE
Attribute UBE_Name = "TextPrimitives"
' Storage access only; validation, comparison and construction algorithms live in UBE.
' Implementation declarations: native binding/qualification remain pending.

Public Intrinsic Function ByteLength(ByRef Value As String) As LongLong
Attribute ByteLength.UBE_Primitive = "Text.ByteLength"
End Function

Public Intrinsic Function ScalarLength(ByRef Value As String) As LongLong
Attribute ScalarLength.UBE_Primitive = "Text.ScalarLength"
End Function

' Reads a byte at a zero-based storage offset from a precisely rooted String.
Public Intrinsic Function TryReadByte(ByRef Value As String, ByVal Index As LongLong, ByRef Result As Byte) As Boolean
Attribute TryReadByte.UBE_Primitive = "Text.ReadByte"
End Function

' Creates private packed storage and installs a frame-owned construction root.
Public Intrinsic Function TryCreate(ByVal ByteCount As LongLong, ByVal ScalarCount As LongLong, ByRef Candidate As LongLong) As Boolean
Attribute TryCreate.UBE_Primitive = "Text.Create"
End Function

' Only the creating thread may fill an unpublished candidate.
Public Intrinsic Function TryWriteByte(ByVal Candidate As LongLong, ByVal Index As LongLong, ByVal Value As Byte) As Boolean
Attribute TryWriteByte.UBE_Primitive = "Text.WriteByte"
End Function

' Validates UTF-8 and scalar count, then atomically publishes and consumes the construction root.
' Failure preserves both the destination and the candidate for repair or abandonment.
Public Intrinsic Function TryPublish(ByRef Destination As String, ByVal Candidate As LongLong) As Boolean
Attribute TryPublish.UBE_Primitive = "Text.Publish"
End Function

' Reads private candidate dimensions; zero denotes the empty candidate.
Public Intrinsic Function TryCandidateInfo(ByVal Candidate As LongLong, ByRef ByteCount As LongLong, ByRef ScalarCount As LongLong) As Boolean
Attribute TryCandidateInfo.UBE_Primitive = "Text.CandidateInfo"
End Function

' Reads only an unpublished candidate owned by the calling thread.
Public Intrinsic Function TryReadCandidateByte(ByVal Candidate As LongLong, ByVal Index As LongLong, ByRef Value As Byte) As Boolean
Attribute TryReadCandidateByte.UBE_Primitive = "Text.ReadCandidateByte"
End Function

' Removes the construction root without allocating or invoking collection.
Public Intrinsic Function TryAbandon(ByVal Candidate As LongLong) As Boolean
Attribute TryAbandon.UBE_Primitive = "Text.Abandon"
End Function
