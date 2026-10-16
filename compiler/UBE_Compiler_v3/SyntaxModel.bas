UBE SOURCE 1 MODULE
Attribute UBE_Name = "SyntaxModel"

Type SyntaxNode
    StableId As Long
    ProductionRule As Long
    SourceId As Long
    FirstToken As Long
    LastToken As Long
    ParentNode As Long
    FirstChildLink As Long
    LastChildLink As Long
    ChildCount As Long
End Type

Type SyntaxChildLink
    NodeIndex As Long
    NextLink As Long
End Type

Type ParseProgress
    FurthestToken As Long
    Expected As String
    LimitExceeded As Long
End Type

Function AppendSyntaxNode(ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxNodeCapacity As Long, ByVal ProductionRule As Long, ByVal SourceId As Long, ByVal FirstToken As Long, ByVal ParentNode As Long) As Long
    If SyntaxNodeCount >= LimitSyntaxNodes() Then
        AppendSyntaxNode = -1
        Exit Function
    End If
    If SyntaxNodeCount = SyntaxNodeCapacity Then
        Dim NewCapacity As Long = 1024
        If SyntaxNodeCapacity > 0 Then
            NewCapacity = SyntaxNodeCapacity * 2
        End If
        If NewCapacity > LimitSyntaxNodes() Then
            NewCapacity = LimitSyntaxNodes()
        End If
        If SyntaxNodeCapacity = 0 Then
            ReDim SyntaxNodes(NewCapacity - 1)
        Else
            ReDim Preserve SyntaxNodes(NewCapacity - 1)
        End If
        SyntaxNodeCapacity = NewCapacity
    End If
    Dim Result As Long = SyntaxNodeCount
    SyntaxNodes(Result).StableId = Result + 1
    SyntaxNodes(Result).ProductionRule = ProductionRule
    SyntaxNodes(Result).SourceId = SourceId
    SyntaxNodes(Result).FirstToken = FirstToken
    SyntaxNodes(Result).LastToken = FirstToken - 1
    SyntaxNodes(Result).ParentNode = ParentNode
    SyntaxNodes(Result).FirstChildLink = -1
    SyntaxNodes(Result).LastChildLink = -1
    SyntaxNodes(Result).ChildCount = 0
    SyntaxNodeCount = SyntaxNodeCount + 1
    AppendSyntaxNode = Result
End Function

Function AppendSyntaxChild(ByRef SyntaxNodes() As SyntaxNode, ByVal ParentNode As Long, ByVal ChildNode As Long, ByRef SyntaxLinks() As SyntaxChildLink, ByRef SyntaxLinkCount As Long, ByRef SyntaxLinkCapacity As Long) As Long
    If ParentNode < 0 Then
        AppendSyntaxChild = 1
        Exit Function
    End If
    If SyntaxLinkCount >= LimitSyntaxNodes() Then
        AppendSyntaxChild = 0
        Exit Function
    End If
    If SyntaxLinkCount = SyntaxLinkCapacity Then
        Dim NewCapacity As Long = 1024
        If SyntaxLinkCapacity > 0 Then
            NewCapacity = SyntaxLinkCapacity * 2
        End If
        If NewCapacity > LimitSyntaxNodes() Then
            NewCapacity = LimitSyntaxNodes()
        End If
        If SyntaxLinkCapacity = 0 Then
            ReDim SyntaxLinks(NewCapacity - 1)
        Else
            ReDim Preserve SyntaxLinks(NewCapacity - 1)
        End If
        SyntaxLinkCapacity = NewCapacity
    End If
    Dim LinkIndex As Long = SyntaxLinkCount
    SyntaxLinks(LinkIndex).NodeIndex = ChildNode
    SyntaxLinks(LinkIndex).NextLink = -1
    If SyntaxNodes(ParentNode).FirstChildLink < 0 Then
        SyntaxNodes(ParentNode).FirstChildLink = LinkIndex
    Else
        SyntaxLinks(SyntaxNodes(ParentNode).LastChildLink).NextLink = LinkIndex
    End If
    SyntaxNodes(ParentNode).LastChildLink = LinkIndex
    SyntaxNodes(ParentNode).ChildCount = SyntaxNodes(ParentNode).ChildCount + 1
    SyntaxLinkCount = SyntaxLinkCount + 1
    AppendSyntaxChild = 1
End Function

Sub RecordParseExpectation(ByVal TokenPosition As Long, ByVal Expected As String, ByRef Progress As ParseProgress)
    If TokenPosition > Progress.FurthestToken Then
        Progress.FurthestToken = TokenPosition
        Progress.Expected = Expected
    Else
        If TokenPosition = Progress.FurthestToken Then
            If StringLength(Progress.Expected) = 0 Then
                Progress.Expected = Expected
            End If
        End If
    End If
End Sub

Sub RestoreSyntaxCheckpoint(ByVal ParentNode As Long, ByVal SavedNodeCount As Long, ByVal SavedLinkCount As Long, ByVal SavedFirstChild As Long, ByVal SavedLastChild As Long, ByVal SavedChildCount As Long, ByRef SyntaxNodes() As SyntaxNode, ByRef SyntaxNodeCount As Long, ByRef SyntaxLinkCount As Long)
    SyntaxNodeCount = SavedNodeCount
    SyntaxLinkCount = SavedLinkCount
    If ParentNode >= 0 Then
        SyntaxNodes(ParentNode).FirstChildLink = SavedFirstChild
        SyntaxNodes(ParentNode).LastChildLink = SavedLastChild
        SyntaxNodes(ParentNode).ChildCount = SavedChildCount
    End If
End Sub
