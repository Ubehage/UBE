UBE SOURCE 1 MODULE
Attribute UBE_Name = "LeaseProbe"
' Exercises real physical output ownership independently of compiler command rendering.
Public Function CheckPair(ByRef First() As Byte, ByRef Second() As Byte, ByVal Overlap As Boolean) As Long
    Dim Output() As Byte
    Dim Other() As Byte
    Dim Snapshot() As Byte
    Dim OtherSnapshot() As Byte
    Dim NameToken As Long
    Dim FileToken As Long
    Dim OtherName As Long
    Dim OtherFile As Long
    Dim Token As Long
    Dim Failure As Long
    Dim Accepted As Boolean
    If Not OutputPublication.TryReserve(First, Output, Snapshot, NameToken, FileToken, Token, Failure) Then CheckPair = 1000 + Failure: Exit Function
    Accepted = OutputPublication.TryReserve(Second, Other, OtherSnapshot, OtherName, OtherFile, Token, Failure)
    If Accepted = Overlap Then CheckPair = 2: Exit Function
    If Overlap And Failure <> 19 Then CheckPair = 3: Exit Function
    If Not OutputPublication.TryRelease(OtherFile, Failure) Then CheckPair = 4: Exit Function
    If Not OutputPublication.TryRelease(OtherName, Failure) Then CheckPair = 5: Exit Function
    If Not OutputPublication.TryRelease(FileToken, Failure) Then CheckPair = 6: Exit Function
    If Not OutputPublication.TryRelease(NameToken, Failure) Then CheckPair = 7: Exit Function
    If Token <> 0 Then CheckPair = 8: Exit Function
    If Not OutputPublication.TryReserve(Second, Other, OtherSnapshot, OtherName, OtherFile, Token, Failure) Then CheckPair = 9: Exit Function
    If Not OutputPublication.TryRelease(OtherFile, Failure) Then CheckPair = 10: Exit Function
    If Not OutputPublication.TryRelease(OtherName, Failure) Then CheckPair = 11: Exit Function
End Function

' Holds old and candidate identity reservations across a real atomic replacement.
Public Function PublishHold(ByRef Path() As Byte, ByRef Stage() As Byte, ByRef NameToken As Long, ByRef FileToken As Long, ByRef StageToken As Long) As Long
    Dim Output() As Byte
    Dim Snapshot() As Byte
    Dim Source() As Byte
    Dim Token As Long
    Dim Failure As Long
    If Not OutputPublication.TryReserve(Path, Output, Snapshot, NameToken, FileToken, Token, Failure) Then PublishHold = 1: Exit Function
    If Not OutputPublication.TryReserveStage(Stage, OutputPublication.InputIR, StageToken, Token, Failure) Then PublishHold = 2: Exit Function
    If Not OutputPublication.TryValidateReservation(Output, Snapshot, Token, Failure) Then PublishHold = 3: Exit Function
    If Not OutputPublication.TryStagePath(Stage, OutputPublication.InputIR, Source, Failure) Then PublishHold = 4: Exit Function
    If Not FilePrimitives.TryReplace(Source, Output, Failure) Then PublishHold = 5: Exit Function
    ' The old snapshot must reject this intentionally changed inode even while the leases are retained.
    If OutputPublication.TryValidateReservation(Output, Snapshot, Token, Failure) Then PublishHold = 6: Exit Function
    If Failure <> 19 Then PublishHold = 7
End Function

' Holds one lease while the native harness coordinates a second process and owner death.
Public Function Hold(ByRef Path() As Byte, ByRef NameToken As Long, ByRef FileToken As Long) As Long
    Dim Output() As Byte
    Dim Snapshot() As Byte
    Dim Token As Long
    Dim Failure As Long
    If Not OutputPublication.TryReserve(Path, Output, Snapshot, NameToken, FileToken, Token, Failure) Then Hold = Failure
End Function
