UBE SOURCE 1 MODULE
Attribute UBE_Name = "CompilerMessages"
' Formats bounded command diagnostics and success markers without shared mutable state.

Public Const UsageError As Long = 1
Public Const LoadError As Long = 2
Public Const AssetError As Long = 3
Public Const OutputError As Long = 4
Public Const CompileError As Long = 5
Public Const BackendError As Long = 6
Public Const PublicationError As Long = 7
Public Const CleanupError As Long = 8
Public Const InternalError As Long = 9
Public Const CleanupWarning As Long = 10

' Supplies the reviewed UsageErrorText diagnostic text.
Private Function UsageErrorText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 115, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 69
    Value(6) = 95
    Value(7) = 85
    Value(8) = 83
    Value(9) = 65
    Value(10) = 71
    Value(11) = 69
    Value(12) = 58
    Value(13) = 32
    Value(14) = 101
    Value(15) = 120
    Value(16) = 112
    Value(17) = 101
    Value(18) = 99
    Value(19) = 116
    Value(20) = 101
    Value(21) = 100
    Value(22) = 32
    Value(23) = 45
    Value(24) = 45
    Value(25) = 101
    Value(26) = 109
    Value(27) = 105
    Value(28) = 116
    Value(29) = 45
    Value(30) = 108
    Value(31) = 108
    Value(32) = 118
    Value(33) = 109
    Value(34) = 32
    Value(35) = 60
    Value(36) = 112
    Value(37) = 114
    Value(38) = 111
    Value(39) = 106
    Value(40) = 101
    Value(41) = 99
    Value(42) = 116
    Value(43) = 46
    Value(44) = 85
    Value(45) = 66
    Value(46) = 69
    Value(47) = 62
    Value(48) = 32
    Value(49) = 60
    Value(50) = 111
    Value(51) = 117
    Value(52) = 116
    Value(53) = 112
    Value(54) = 117
    Value(55) = 116
    Value(56) = 46
    Value(57) = 108
    UsageErrorText = BuildUsageText(Value)
End Function

' Supplies the build-command alternative in the reviewed usage diagnostic.
Private Function BuildUsageText(ByRef Value() As Byte) As Boolean
    Value(58) = 108
    Value(59) = 62
    Value(60) = 32
    Value(61) = 111
    Value(62) = 114
    Value(63) = 32
    Value(64) = 45
    Value(65) = 45
    Value(66) = 98
    Value(67) = 117
    Value(68) = 105
    Value(69) = 108
    Value(70) = 100
    Value(71) = 32
    Value(72) = 60
    Value(73) = 112
    Value(74) = 114
    Value(75) = 111
    Value(76) = 106
    Value(77) = 101
    Value(78) = 99
    Value(79) = 116
    Value(80) = 46
    Value(81) = 85
    Value(82) = 66
    Value(83) = 69
    Value(84) = 62
    Value(85) = 32
    Value(86) = 60
    Value(87) = 111
    Value(88) = 117
    Value(89) = 116
    Value(90) = 112
    Value(91) = 117
    Value(92) = 116
    Value(93) = 46
    Value(94) = 101
    Value(95) = 120
    Value(96) = 101
    Value(97) = 62
    Value(98) = 32
    Value(99) = 91
    Value(100) = 45
    Value(101) = 45
    Value(102) = 99
    Value(103) = 108
    Value(104) = 97
    Value(105) = 110
    Value(106) = 103
    Value(107) = 32
    Value(108) = 60
    Value(109) = 112
    Value(110) = 97
    Value(111) = 116
    Value(112) = 104
    Value(113) = 62
    Value(114) = 93
    BuildUsageText = True
End Function

' Supplies the reviewed LoadErrorText diagnostic text.
Private Function LoadErrorText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 51, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 69
    Value(6) = 95
    Value(7) = 76
    Value(8) = 79
    Value(9) = 65
    Value(10) = 68
    Value(11) = 58
    Value(12) = 32
    Value(13) = 99
    Value(14) = 97
    Value(15) = 110
    Value(16) = 110
    Value(17) = 111
    Value(18) = 116
    Value(19) = 32
    Value(20) = 108
    Value(21) = 111
    Value(22) = 97
    Value(23) = 100
    Value(24) = 32
    Value(25) = 116
    Value(26) = 104
    Value(27) = 101
    Value(28) = 32
    Value(29) = 111
    Value(30) = 114
    Value(31) = 100
    Value(32) = 101
    Value(33) = 114
    Value(34) = 101
    Value(35) = 100
    Value(36) = 32
    Value(37) = 115
    Value(38) = 111
    Value(39) = 117
    Value(40) = 114
    Value(41) = 99
    Value(42) = 101
    Value(43) = 32
    Value(44) = 112
    Value(45) = 114
    Value(46) = 111
    Value(47) = 106
    Value(48) = 101
    Value(49) = 99
    Value(50) = 116
    LoadErrorText = True
End Function

' Supplies the reviewed AssetErrorText diagnostic text.
Private Function AssetErrorText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 64, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 69
    Value(6) = 95
    Value(7) = 65
    Value(8) = 83
    Value(9) = 83
    Value(10) = 69
    Value(11) = 84
    Value(12) = 58
    Value(13) = 32
    Value(14) = 99
    Value(15) = 97
    Value(16) = 110
    Value(17) = 110
    Value(18) = 111
    Value(19) = 116
    Value(20) = 32
    Value(21) = 108
    Value(22) = 111
    Value(23) = 97
    Value(24) = 100
    Value(25) = 32
    Value(26) = 99
    Value(27) = 111
    Value(28) = 109
    Value(29) = 112
    Value(30) = 105
    Value(31) = 108
    Value(32) = 101
    Value(33) = 114
    Value(34) = 32
    Value(35) = 115
    Value(36) = 117
    Value(37) = 112
    Value(38) = 112
    Value(39) = 111
    Value(40) = 114
    Value(41) = 116
    Value(42) = 32
    Value(43) = 98
    Value(44) = 101
    Value(45) = 115
    Value(46) = 105
    Value(47) = 100
    Value(48) = 101
    Value(49) = 32
    Value(50) = 116
    Value(51) = 104
    Value(52) = 101
    Value(53) = 32
    Value(54) = 101
    Value(55) = 120
    Value(56) = 101
    Value(57) = 99
    Value(58) = 117
    Value(59) = 116
    Value(60) = 97
    Value(61) = 98
    Value(62) = 108
    Value(63) = 101
    AssetErrorText = True
End Function

' Supplies the reviewed OutputErrorText diagnostic text.
Private Function OutputErrorText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 55, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 69
    Value(6) = 95
    Value(7) = 79
    Value(8) = 85
    Value(9) = 84
    Value(10) = 80
    Value(11) = 85
    Value(12) = 84
    Value(13) = 58
    Value(14) = 32
    Value(15) = 99
    Value(16) = 97
    Value(17) = 110
    Value(18) = 110
    Value(19) = 111
    Value(20) = 116
    Value(21) = 32
    Value(22) = 112
    Value(23) = 114
    Value(24) = 101
    Value(25) = 112
    Value(26) = 97
    Value(27) = 114
    Value(28) = 101
    Value(29) = 32
    Value(30) = 97
    Value(31) = 32
    Value(32) = 115
    Value(33) = 97
    Value(34) = 102
    Value(35) = 101
    Value(36) = 32
    Value(37) = 111
    Value(38) = 117
    Value(39) = 116
    Value(40) = 112
    Value(41) = 117
    Value(42) = 116
    Value(43) = 32
    Value(44) = 100
    Value(45) = 101
    Value(46) = 115
    Value(47) = 116
    Value(48) = 105
    Value(49) = 110
    Value(50) = 97
    Value(51) = 116
    Value(52) = 105
    Value(53) = 111
    Value(54) = 110
    OutputErrorText = True
End Function

' Supplies the reviewed CompileErrorText diagnostic text.
Private Function CompileErrorText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 41, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 69
    Value(6) = 95
    Value(7) = 67
    Value(8) = 79
    Value(9) = 77
    Value(10) = 80
    Value(11) = 73
    Value(12) = 76
    Value(13) = 69
    Value(14) = 58
    Value(15) = 32
    Value(16) = 115
    Value(17) = 111
    Value(18) = 117
    Value(19) = 114
    Value(20) = 99
    Value(21) = 101
    Value(22) = 32
    Value(23) = 99
    Value(24) = 111
    Value(25) = 109
    Value(26) = 112
    Value(27) = 105
    Value(28) = 108
    Value(29) = 97
    Value(30) = 116
    Value(31) = 105
    Value(32) = 111
    Value(33) = 110
    Value(34) = 32
    Value(35) = 102
    Value(36) = 97
    Value(37) = 105
    Value(38) = 108
    Value(39) = 101
    Value(40) = 100
    CompileErrorText = True
End Function

' Supplies the reviewed BackendErrorText diagnostic text.
Private Function BackendErrorText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 55, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 69
    Value(6) = 95
    Value(7) = 66
    Value(8) = 65
    Value(9) = 67
    Value(10) = 75
    Value(11) = 69
    Value(12) = 78
    Value(13) = 68
    Value(14) = 58
    Value(15) = 32
    Value(16) = 110
    Value(17) = 97
    Value(18) = 116
    Value(19) = 105
    Value(20) = 118
    Value(21) = 101
    Value(22) = 32
    Value(23) = 116
    Value(24) = 111
    Value(25) = 111
    Value(26) = 108
    Value(27) = 32
    Value(28) = 111
    Value(29) = 114
    Value(30) = 32
    Value(31) = 111
    Value(32) = 117
    Value(33) = 116
    Value(34) = 112
    Value(35) = 117
    Value(36) = 116
    Value(37) = 32
    Value(38) = 118
    Value(39) = 97
    Value(40) = 108
    Value(41) = 105
    Value(42) = 100
    Value(43) = 97
    Value(44) = 116
    Value(45) = 105
    Value(46) = 111
    Value(47) = 110
    Value(48) = 32
    Value(49) = 102
    Value(50) = 97
    Value(51) = 105
    Value(52) = 108
    Value(53) = 101
    Value(54) = 100
    BackendErrorText = True
End Function

' Supplies the reviewed PublicationErrorText diagnostic text.
Private Function PublicationErrorText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 50, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 69
    Value(6) = 95
    Value(7) = 79
    Value(8) = 85
    Value(9) = 84
    Value(10) = 80
    Value(11) = 85
    Value(12) = 84
    Value(13) = 58
    Value(14) = 32
    Value(15) = 99
    Value(16) = 97
    Value(17) = 110
    Value(18) = 110
    Value(19) = 111
    Value(20) = 116
    Value(21) = 32
    Value(22) = 112
    Value(23) = 117
    Value(24) = 98
    Value(25) = 108
    Value(26) = 105
    Value(27) = 115
    Value(28) = 104
    Value(29) = 32
    Value(30) = 116
    Value(31) = 104
    Value(32) = 101
    Value(33) = 32
    Value(34) = 99
    Value(35) = 111
    Value(36) = 109
    Value(37) = 112
    Value(38) = 108
    Value(39) = 101
    Value(40) = 116
    Value(41) = 101
    Value(42) = 100
    Value(43) = 32
    Value(44) = 111
    Value(45) = 117
    Value(46) = 116
    Value(47) = 112
    Value(48) = 117
    Value(49) = 116
    PublicationErrorText = True
End Function

' Supplies the reviewed CleanupErrorText diagnostic text.
Private Function CleanupErrorText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 49, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 69
    Value(6) = 95
    Value(7) = 67
    Value(8) = 76
    Value(9) = 69
    Value(10) = 65
    Value(11) = 78
    Value(12) = 85
    Value(13) = 80
    Value(14) = 58
    Value(15) = 32
    Value(16) = 116
    Value(17) = 101
    Value(18) = 109
    Value(19) = 112
    Value(20) = 111
    Value(21) = 114
    Value(22) = 97
    Value(23) = 114
    Value(24) = 121
    Value(25) = 32
    Value(26) = 114
    Value(27) = 101
    Value(28) = 115
    Value(29) = 111
    Value(30) = 117
    Value(31) = 114
    Value(32) = 99
    Value(33) = 101
    Value(34) = 32
    Value(35) = 99
    Value(36) = 108
    Value(37) = 101
    Value(38) = 97
    Value(39) = 110
    Value(40) = 117
    Value(41) = 112
    Value(42) = 32
    Value(43) = 102
    Value(44) = 97
    Value(45) = 105
    Value(46) = 108
    Value(47) = 101
    Value(48) = 100
    CleanupErrorText = True
End Function

' Supplies the reviewed InternalErrorText diagnostic text.
Private Function InternalErrorText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 40, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 69
    Value(6) = 95
    Value(7) = 73
    Value(8) = 78
    Value(9) = 84
    Value(10) = 69
    Value(11) = 82
    Value(12) = 78
    Value(13) = 65
    Value(14) = 76
    Value(15) = 58
    Value(16) = 32
    Value(17) = 99
    Value(18) = 111
    Value(19) = 109
    Value(20) = 112
    Value(21) = 105
    Value(22) = 108
    Value(23) = 101
    Value(24) = 114
    Value(25) = 32
    Value(26) = 114
    Value(27) = 101
    Value(28) = 113
    Value(29) = 117
    Value(30) = 101
    Value(31) = 115
    Value(32) = 116
    Value(33) = 32
    Value(34) = 102
    Value(35) = 97
    Value(36) = 105
    Value(37) = 108
    Value(38) = 101
    Value(39) = 100
    InternalErrorText = True
End Function

' Supplies the reviewed DetailsText diagnostic text.
Private Function DetailsText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 24, False) Then Exit Function
    Value(0) = 32
    Value(1) = 40
    Value(2) = 111
    Value(3) = 112
    Value(4) = 101
    Value(5) = 114
    Value(6) = 97
    Value(7) = 116
    Value(8) = 105
    Value(9) = 111
    Value(10) = 110
    Value(11) = 47
    Value(12) = 99
    Value(13) = 111
    Value(14) = 100
    Value(15) = 101
    Value(16) = 47
    Value(17) = 114
    Value(18) = 101
    Value(19) = 97
    Value(20) = 115
    Value(21) = 111
    Value(22) = 110
    Value(23) = 32
    DetailsText = True
End Function

' Supplies the reviewed EmitText diagnostic text.
Private Function EmitText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 9, False) Then Exit Function
    Value(0) = 69
    Value(1) = 77
    Value(2) = 73
    Value(3) = 84
    Value(4) = 32
    Value(5) = 79
    Value(6) = 75
    Value(7) = 13
    Value(8) = 10
    EmitText = True
End Function

' Supplies the reviewed BuildText diagnostic text.
Private Function BuildText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 10, False) Then Exit Function
    Value(0) = 66
    Value(1) = 85
    Value(2) = 73
    Value(3) = 76
    Value(4) = 68
    Value(5) = 32
    Value(6) = 79
    Value(7) = 75
    Value(8) = 13
    Value(9) = 10
    BuildText = True
End Function

' Reports cleanup failure after a completed publication without relabeling the build as failed.
Private Function CleanupWarningText(ByRef Value() As Byte) As Boolean
    If Not BufferPrimitives.TryResizeBytes(Value, 60, False) Then Exit Function
    Value(0) = 85
    Value(1) = 66
    Value(2) = 69
    Value(3) = 58
    Value(4) = 32
    Value(5) = 87
    Value(6) = 95
    Value(7) = 67
    Value(8) = 76
    Value(9) = 69
    Value(10) = 65
    Value(11) = 78
    Value(12) = 85
    Value(13) = 80
    Value(14) = 58
    Value(15) = 32
    Value(16) = 111
    Value(17) = 117
    Value(18) = 116
    Value(19) = 112
    Value(20) = 117
    Value(21) = 116
    Value(22) = 32
    Value(23) = 105
    Value(24) = 115
    Value(25) = 32
    Value(26) = 99
    Value(27) = 111
    Value(28) = 109
    Value(29) = 112
    Value(30) = 108
    Value(31) = 101
    Value(32) = 116
    Value(33) = 101
    Value(34) = 59
    Value(35) = 32
    Value(36) = 116
    Value(37) = 101
    Value(38) = 109
    Value(39) = 112
    Value(40) = 111
    Value(41) = 114
    Value(42) = 97
    Value(43) = 114
    Value(44) = 121
    Value(45) = 32
    Value(46) = 99
    Value(47) = 108
    Value(48) = 101
    Value(49) = 97
    Value(50) = 110
    Value(51) = 117
    Value(52) = 112
    Value(53) = 32
    Value(54) = 102
    Value(55) = 97
    Value(56) = 105
    Value(57) = 108
    Value(58) = 101
    Value(59) = 100
    CleanupWarningText = True
End Function


' Selects the command operation whose failure is being reported.
Private Function Prefix(ByVal Kind As Long, ByRef Value() As Byte) As Boolean
    If Kind = UsageError Then Prefix = UsageErrorText(Value): Exit Function
    If Kind = LoadError Then Prefix = LoadErrorText(Value): Exit Function
    If Kind = AssetError Then Prefix = AssetErrorText(Value): Exit Function
    If Kind = OutputError Then Prefix = OutputErrorText(Value): Exit Function
    If Kind = CompileError Then Prefix = CompileErrorText(Value): Exit Function
    If Kind = BackendError Then Prefix = BackendErrorText(Value): Exit Function
    If Kind = PublicationError Then Prefix = PublicationErrorText(Value): Exit Function
    If Kind = CleanupError Then Prefix = CleanupErrorText(Value): Exit Function
    If Kind = InternalError Then Prefix = InternalErrorText(Value): Exit Function
    If Kind = CleanupWarning Then Prefix = CleanupWarningText(Value): Exit Function
    Prefix = InternalErrorText(Value)
End Function

' Appends a bounded exact byte span to private diagnostic storage.
Private Function Append(ByRef Value() As Byte, ByRef Buffer() As Byte, ByRef Used As Long) As Boolean
    Dim Length As Long
    Length = BufferPrimitives.ByteStorageLength(Value)
    If Used < 0 Or Used > 5120 Then Exit Function
    If Length > 5120 - Used Then Exit Function
    If Not BufferPrimitives.CopyByteRange(Value, 0, Buffer, Used, Length) Then Exit Function
    Used = Used + Length
    Append = True
End Function

' Reports one located failure; false means diagnostic output itself could not complete.
Public Function TryWriteError(ByVal Kind As Long, ByVal Operation As Long, ByVal Code As Long, ByVal Reason As Long, ByRef Path() As Byte, ByVal SourceLine As Long, ByVal SourceColumn As Long) As Boolean
    Dim Buffer() As Byte
    Dim Text() As Byte
    Dim Used As Long
    Dim Failure As Long
    On Error GoTo Failed
    If BufferPrimitives.ByteStorageLength(Path) > 4096 Then Exit Function
    If Not BufferPrimitives.TryResizeBytes(Buffer, 5120, False) Then Exit Function
    If Not Prefix(Kind, Text) Then Exit Function
    If Not Append(Text, Buffer, Used) Then Exit Function
    If Not DetailsText(Text) Then Exit Function
    If Not Append(Text, Buffer, Used) Then Exit Function
    If Not ByteText.TryAppendInteger(Buffer, Used, Operation) Then Exit Function
    Buffer(Used) = 47: Used = Used + 1
    If Not ByteText.TryAppendInteger(Buffer, Used, Code) Then Exit Function
    Buffer(Used) = 47: Used = Used + 1
    If Not ByteText.TryAppendInteger(Buffer, Used, Reason) Then Exit Function
    Buffer(Used) = 41: Used = Used + 1
    Buffer(Used) = 32: Used = Used + 1
    If Not Append(Path, Buffer, Used) Then Exit Function
    If SourceLine > 0 Then
        Buffer(Used) = 58: Used = Used + 1
        If Not ByteText.TryAppendInteger(Buffer, Used, SourceLine) Then Exit Function
        Buffer(Used) = 58: Used = Used + 1
        If Not ByteText.TryAppendInteger(Buffer, Used, SourceColumn) Then Exit Function
    End If
    Buffer(Used) = 13: Used = Used + 1
    Buffer(Used) = 10: Used = Used + 1
    TryWriteError = StandardStreams.TryWriteBytes(2, Buffer, 0, Used, Failure)
    Exit Function
Failed:
    TryWriteError = False
End Function

' Writes the exact success marker only after output publication has completed.
Public Function TryWriteSuccess(ByVal Mode As Long) As Boolean
    Dim Text() As Byte
    Dim Failure As Long
    On Error GoTo Failed
    If Mode = 1 Then
        If Not EmitText(Text) Then Exit Function
    ElseIf Mode = 2 Then
        If Not BuildText(Text) Then Exit Function
    Else
        Exit Function
    End If
    TryWriteSuccess = StandardStreams.TryWriteBytes(1, Text, 0, BufferPrimitives.ByteStorageLength(Text), Failure)
    Exit Function
Failed:
    TryWriteSuccess = False
End Function

