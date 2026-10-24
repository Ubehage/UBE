UBE SOURCE 1 MODULE
Attribute UBE_Name = "IdeProtocols"

Type IdeServiceEnvelope
    ProtocolVersion As Long
    RequestId As Long
    DocumentVersion As Long
    Method As String
    Status As String
    Payload As String
End Type

Function IdeLoadServiceEnvelope(ByVal Contents As String, ByRef Envelope As IdeServiceEnvelope, ByRef Diagnostics() As IdeDiagnostic, ByRef DiagnosticCount As Long, ByRef DiagnosticCapacity As Long) As Long
    Envelope.ProtocolVersion = 0
    Envelope.RequestId = 0
    Envelope.DocumentVersion = 0
    Envelope.Method = ""
    Envelope.Status = ""
    Envelope.Payload = ""
    Dim InitialDiagnosticCount As Long = DiagnosticCount
    If StringLength(Contents) > IdeLimitProtocolBytes() Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3001", "<service>", 1, 1, 2)
        IdeLoadServiceEnvelope = 0
        Exit Function
    End If
    Dim InvalidByte As Long = -1
    If IdeValidateUtf8(Contents, InvalidByte) = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3009", "<service>", 1, InvalidByte + 1, 2)
        IdeLoadServiceEnvelope = 0
        Exit Function
    End If
    Dim Cursor As Long = 0
    Dim LineText As String = ""
    If IdeReadLine(Contents, Cursor, LineText) = 0 Or LineText <> "UBE-IDE-Protocol 1" Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3002", "<service>", 1, 1, 2)
        IdeLoadServiceEnvelope = 0
        Exit Function
    End If
    Envelope.ProtocolVersion = 1
    Dim SeenRequest As Long = 0
    Dim SeenDocument As Long = 0
    Dim SeenMethod As Long = 0
    Dim SeenStatus As Long = 0
    Dim SeenPayload As Long = 0
    Dim LineNumber As Long = 1
    While IdeReadLine(Contents, Cursor, LineText) <> 0
        LineNumber = LineNumber + 1
        Dim Trimmed As String = ""
        Call IdeTrim(LineText, Trimmed)
        If StringLength(Trimmed) > 0 Then
            Dim Key As String = ""
            Dim Value As String = ""
            If IdeParseAssignment(Trimmed, Key, Value) = 0 Then
                Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3003", "<service>", LineNumber, 1, 2)
            Else
                If IdeEqualsFolded(Key, "RequestId") <> 0 Then
                    If SeenRequest <> 0 Or IdeParseNonnegativeLong(Value, Envelope.RequestId) = 0 Then
                        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3004", "<service>", LineNumber, 1, 2)
                    Else
                        SeenRequest = 1
                    End If
                Else
                    If IdeEqualsFolded(Key, "DocumentVersion") <> 0 Then
                        If SeenDocument <> 0 Or IdeParseNonnegativeLong(Value, Envelope.DocumentVersion) = 0 Then
                            Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3005", "<service>", LineNumber, 1, 2)
                        Else
                            SeenDocument = 1
                        End If
                    Else
                        If IdeEqualsFolded(Key, "Method") <> 0 Then
                            If SeenMethod <> 0 Or StringLength(Value) = 0 Then
                                Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3006", "<service>", LineNumber, 1, 2)
                            Else
                                Envelope.Method = Value
                                SeenMethod = 1
                            End If
                        Else
                            If IdeEqualsFolded(Key, "Status") <> 0 Then
                                If SeenStatus <> 0 Then
                                    Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3010", "<service>", LineNumber, 1, 2)
                                Else
                                    Envelope.Status = Value
                                    SeenStatus = 1
                                End If
                            Else
                                If IdeEqualsFolded(Key, "Payload") <> 0 Then
                                    If SeenPayload <> 0 Then
                                        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3011", "<service>", LineNumber, 1, 2)
                                    Else
                                        Envelope.Payload = Value
                                        SeenPayload = 1
                                    End If
                                Else
                                    Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3007", "<service>", LineNumber, 1, 2)
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    Wend
    If SeenRequest = 0 Or SeenDocument = 0 Or SeenMethod = 0 Then
        Call IdeAddDiagnostic(Diagnostics, DiagnosticCount, DiagnosticCapacity, "IDE3008", "<service>", 1, 1, 2)
    End If
    If DiagnosticCount = InitialDiagnosticCount Then
        IdeLoadServiceEnvelope = 1
    Else
        IdeLoadServiceEnvelope = 0
    End If
End Function

Function IdeServiceResultIsCurrent(ByRef Envelope As IdeServiceEnvelope, ByVal ExpectedRequestId As Long, ByVal CurrentDocumentVersion As Long) As Long
    If Envelope.RequestId = ExpectedRequestId And Envelope.DocumentVersion = CurrentDocumentVersion Then
        IdeServiceResultIsCurrent = 1
    Else
        IdeServiceResultIsCurrent = 0
    End If
End Function
