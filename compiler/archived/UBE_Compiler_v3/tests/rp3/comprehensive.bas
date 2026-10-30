UBE SOURCE 1 MODULE
Attribute UBE_Name = "Comprehensive"
Option Explicit On
Option Compare Binary
Option Base 0
Implements IWorker
DefLng A-Z
Public Const Answer As Long = 42
Private Dim Values(0 To 3) As Long
Private Dim FixedText As String * 12
Private Dim ShortValue% = 1
Private WithEvents Source As Object
Public Changed As Long
On Get ReadChanged
On Set WriteChanged
End Variable
Type Pair
    Left As Long
    Right As Long
End Type
Enum AccessMode As Long
    AccessRead = 1
    AccessWrite
End Enum
Event Updated(ByVal Value As Long)
Public Interface IWorker
    Sub Start(ByVal Value As Long)
    Function Result() As Long
    Property Get Item(ByVal Index As Long) As Long
    Property Let Item(ByVal Index As Long, ByVal Value As Long)
    Property Set Owner(ByVal Value As Object)
    Event Finished()
End Interface
Public Declare Function NativeValue Lib "native" Alias "native_value" (ByVal Value As Long) As Long
Public Intrinsic Function IntrinsicValue(ByVal Value As Long) As Long
End Function

Public Function Identity(ByVal Value As Long, Optional ByVal Other As Long = 1) As Long
Attribute Identity.Description = "identity"
    Identity = Value + Other
End Function

Public Property Get Current() As Long
    Current = Answer
End Property

Public Property Let Current(ByVal Value As Long)
    Changed = Value
End Property

Public Property Set Owner(ByVal Value As Object)
    Set Source = Value
End Property

Sub Main()
    Dim Index As Long = 0
    Dim Item As Long
    Dim More() As Long
    Const LocalValue As Long = 2
    Dim Watched As Long
    On Get ReadWatched
    On Set WriteWatched
    End Variable
    Changed = Identity(Answer, Other := LocalValue)
    Let Item = (Changed * 2) \ 1 Mod 3
    Set Source = New Object
    Call Identity(Item)
    Identity Item, LocalValue
    CallNew Worker(Item)
    Changed = TypeOf Source Is Object
    Changed = True And Not False
    Set Source = Nothing
    Changed = Empty
    Changed = Null
    Changed = AddressOf Worker
    Changed = Me!Value
    If Item = 0 Then Print "zero" Else Print "nonzero"
    If Item > 0 Then
        Dim Nested As Long = 1
        Print Nested
    ElseIf Item < 0 Then
        Print "negative"
    Else
        Print "zero"
    End If
    Select Case Item
        Case 0, 1 To 3, Is > 9
            Print Item
        Case Else
            Print "other"
    End Select
    For Index = 0 To 3 Step 1
        If Index = 2 Then Exit For
    Next Index
    For Each Item In Values
        Print Item
    Next Item
    Do While Item > 0
        Item = Item - 1
        If Item = 2 Then Exit Do
    Loop
    Do
        Item = Item + 1
    Loop Until Item > 2
    While Item > 0
        Item = Item - 1
        If Item = 1 Then Exit While
    Wend
    With Source
        .ToString
    End With
    SyncLock Source
        Print "locked"
    End SyncLock
    ReDim Preserve More(0 To 8)
    Erase More
    Mid$("abc", 1, 1) = "x"
    RaiseEvent Updated(Item)
    Load Source
    Unload Source
    SavePicture Source, "picture.bin"
    On Error Resume Next
    Resume Next
    Error 5
    GoSub Finished
    GoTo Finished
Finished:
    Return
    Asm "nop"
    Bytecode "00"
    Stop
    End
End Sub

Sub Worker(ByVal Value As Long)
    Print Value
End Sub

Sub FileStatements()
    Dim Value As Long
    Open "data.bin" For Binary Access Read Write Lock Read Write As #1 Len = 8
    Print #1, "value"; Value
    Input #1, Value
    Line Input #1, Value
    Get #1, , Value
    Put #1, , Value
    Seek #1, 1
    Lock #1, 1 To 8
    Unlock #1
    Write #1, Value, , "done"
    Width #1, 80
    Close #1
    FileCopy "a", "b"
    ChDir "."
    MkDir "folder"
    RmDir "folder"
    Kill "b"
    Name "a" As "b"
End Sub
