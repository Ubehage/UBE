UBE SOURCE 1 MODULE
Attribute UBE_Name = "ProjectDisplay"

' Bounded CLI metadata only. This uses the temporary bootstrap String surface;
' source documents stay in Byte arrays. Input paths are zero-based counted bytes.
' The complete older display is retained on failure. No output occurs here.
Intrinsic Function StringFromByte(ByVal Value As Long) As String
End Function
Intrinsic Function StringArrayJoin(ByRef Values() As String, ByVal Count As Long) As String
End Function
Intrinsic Function TryResizeProjectDisplayPieces(ByRef Values() As String, ByVal Count As Long, ByVal KeepValues As Boolean) As Boolean
Attribute TryResizeProjectDisplayPieces.UBE_Primitive = "Array.TryResize"
End Function

Function ProjectDisplayHexDigit(ByVal Value As Long) As String
    If Value < 10 Then
        ProjectDisplayHexDigit = StringFromByte(Value + 48)
    Else
        ProjectDisplayHexDigit = StringFromByte(Value + 55)
    End If
End Function

Function TryFormatProjectPath(ByRef Bytes() As Byte, ByRef Published As String) As Boolean
    TryFormatProjectPath = False
    Dim Count As Long = ByteStorageLength(Bytes)
    If Count > 131068 Then
        Exit Function
    End If
    If Count = 0 Then
        Published = """"""
        TryFormatProjectPath = True
        Exit Function
    End If
    Dim Pieces() As String
    If TryResizeProjectDisplayPieces(Pieces, Count, False) = False Then
        Exit Function
    End If
    Dim ExpectedLength As Long = 0
    Dim Index As Long = 0
    While Index < Count
        Dim Value As Long = Bytes(Index)
        Dim ExpectedPiece As Long = 1
        Dim Piece As String
        If Value < 32 Or Value = 127 Then
            Piece = "\x" & ProjectDisplayHexDigit(Value \ 16) & ProjectDisplayHexDigit(Value Mod 16)
            ExpectedPiece = 4
        Else
            If Value = 34 Or Value = 92 Then
                Piece = "\" & StringFromByte(Value)
                ExpectedPiece = 2
            Else
                Piece = StringFromByte(Value)
            End If
        End If
        If StringLength(Piece) <> ExpectedPiece Then
            Exit Function
        End If
        Pieces(Index) = Piece
        If StringLength(Pieces(Index)) <> ExpectedPiece Then
            Exit Function
        End If
        ExpectedLength = ExpectedLength + ExpectedPiece
        Index = Index + 1
    Wend
    Dim Joined As String = StringArrayJoin(Pieces, Count)
    If StringLength(Joined) <> ExpectedLength Then
        Exit Function
    End If
    Dim Prepared As String = """" & Joined & """"
    If StringLength(Prepared) <> ExpectedLength + 2 Then
        Exit Function
    End If
    Published = Prepared
    TryFormatProjectPath = True
End Function
