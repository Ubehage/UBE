' Independent semantic oracle for the adopted opaque native value.
Function Main() As Long
    Dim Original As Octet
    Dim Copy As Octet
    Print UnpackOctet(Original)
    Print Original = Copy
    Print Original <> PackOctet(255)
    Original = PackOctet(255)
    Copy = Original
    Original = PackOctet(9)
    Call ChangeCopy(Copy)
    Print UnpackOctet(Copy)
    Call ChangeStorage(Original)
    Print UnpackOctet(Original)
    Dim Returned As Octet = ReturnCopy(Copy)
    Returned = PackOctet(7)
    Print UnpackOctet(Copy)
    Print UnpackOctet(Returned)
    Print TrySetValue(255, Copy)
    Print TrySetValue(-1, Copy)
    Print UnpackOctet(Copy)
    Print TrySetValue(0, Copy)
    Print UnpackOctet(Copy)
    Print TrySetValue(256, Copy)
    Print UnpackOctet(Copy)
    Main = 0
End Function
