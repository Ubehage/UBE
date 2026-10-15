UBE SOURCE 1 MODULE
Attribute UBE_Name = "CoreStatements"
Option Explicit On

Private Enum AccessMode As Long
    AccessRead = 1
    AccessWrite = 2
End Enum

Private Type WorkItem
    Identifier As Long
    Caption As String
End Type

Private Sub Record(ByVal Value As Long, Optional ByVal Caption As String = "")
End Sub

Public Sub Main()
    Dim Index As Long
    Dim Limit As Long
    Limit = 3

    For Index = 1 To Limit
        If Index = 2 Then
            Call Record(Value := Index, Caption := "middle")
        Else
            Record Index
        End If
    Next Index

    Select Case Limit
        Case 1 To 2
            GoTo Finished
        Case Is >= 3
            Record 3: Record 4
        Case Else
            Stop
    End Select

Finished:
End Sub

