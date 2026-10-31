UBE SOURCE 1 MODULE
Attribute UBE_Name = "FileBytes"

' Counted byte files and arguments. The caller owns every token explicitly;
' copying its Long value does not duplicate the external resource. Close on
' success, error and cancellation. Contract: ../../FILE-BYTES-CONTRACT.md.
' Failure domain: 0 success; 1 invalid request; 2 invalid path; 3 open/query;
' 4 too large; 5 read; 6 premature EOF; 7 close; 8 allocation; 9 stale token;
' 10 cancellation; 11 grew; 12 missing argument; 13 busy.
' Success preserves Err. Every failure returns fresh False and sets Err.

' Borrows counted UTF-8 path; no normalization. Requires Token=0. On failure
' Length=0. Ordinary failure preserves Token; failed OS cleanup returns a live
' Token/Failure7 for caller retry. Size precedes read-payload allocation.
Intrinsic Function TryOpenByteFile(ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByRef Token As Long, ByRef Length As Long, ByRef Failure As Long) As Boolean
Attribute TryOpenByteFile.UBE_Primitive = "File.TryOpen"
End Function

' Borrows existing Byte-array storage for the call; Start is payload-relative.
' Count 0..65536, ReadCount 0..Count. Failure preserves destination, sets
' ReadCount=0. Positive partial reads are progress; zero means EOF.
Intrinsic Function TryReadByteFile(ByVal Token As Long, ByRef Destination() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef ReadCount As Long, ByRef Failure As Long) As Boolean
Attribute TryReadByteFile.UBE_Primitive = "File.TryRead"
End Function

' Releases an owned resource explicitly. Token=0 is successful. Successful
' close sets Token=0; real close failure retains ownership for retry.
Intrinsic Function TryCloseByteFile(ByRef Token As Long, ByRef Failure As Long) As Boolean
Attribute TryCloseByteFile.UBE_Primitive = "File.TryClose"
End Function

' Independent exact UTF-8 argument bytes, excluding executable argument zero.
' Result unchanged on failure. No argument reference survives this call.
Intrinsic Function TryCommandArgument(ByVal Index As Long, ByRef Result() As Byte, ByRef Failure As Long) As Boolean
Attribute TryCommandArgument.UBE_Primitive = "Process.TryArgument"
End Function

' Records a positive recoverable error Number and returns False. This explicit
' operation enables UBE policy to publish its failure after external cleanup.
Intrinsic Function RecordErrorNumber(ByVal Number As Long) As Boolean
Attribute RecordErrorNumber.UBE_Primitive = "Error.Set"
End Function
