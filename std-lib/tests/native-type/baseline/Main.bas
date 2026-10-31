Function Main() As Long
    Dim Original As RecordOctet
    Dim Copy As RecordOctet
    Print Original.Storage
    Original.Storage = 255
    Copy = Original
    Original.Storage = 9
    Call ChangeCopy(Copy)
    Print Copy.Storage
    Call ChangeStorage(Original)
    Print Original.Storage
    Dim Returned As RecordOctet = MakeRecord(7)
    Copy = Returned
    Returned.Storage = 8
    Print Copy.Storage
    Print Returned.Storage
    Print TrySetRecord(255, Copy)
    Print TrySetRecord(-1, Copy)
    Print Copy.Storage
    Print TrySetRecord(0, Copy)
    Print Copy.Storage
    Print TrySetRecord(256, Copy)
    Print Copy.Storage
    Dim Values() As RecordOctet
    ReDim Values(1)
    Print Values(0).Storage
    Values(1).Storage = 255
    Print Values(1).Storage
    Main = 0
End Function
