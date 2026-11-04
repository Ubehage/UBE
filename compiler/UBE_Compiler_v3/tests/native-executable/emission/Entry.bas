UBE SOURCE 1 MODULE
Attribute UBE_Name = "EmissionFixture"
' Exact bootstrap declarations already used by production SourceEnvelope.
Intrinsic Function StringLength(ByVal Value As String) As Long
End Function
Intrinsic Function StringByteAt(ByVal Value As String, ByVal Index As Long) As Long
End Function
Function Main() As Long
    Main = 0
End Function
Function MakeEmissionCancellation(ByRef Result As SourceCancellation) As Boolean
    MakeEmissionCancellation = False
    Set Result = New SourceCancellation
    If (Result Is Nothing) = False Then
        MakeEmissionCancellation = True
    End If
End Function
Sub RequestEmissionCancellation(ByVal Cancellation As SourceCancellation)
    Cancellation.Requested = True
End Sub
Private Intrinsic Function ResizeTraversalFixture(ByRef Values() As BoundNode, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute ResizeTraversalFixture.UBE_Primitive = "Array.TryResize"
End Function
Function MakeTraversalNodes(ByRef Values() As BoundNode, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
    MakeTraversalNodes = ResizeTraversalFixture(Values, Count, Keep)
End Function
Private Intrinsic Function ResizeGraphFacts(ByRef Values() As SemanticFact, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute ResizeGraphFacts.UBE_Primitive = "Array.TryResize"
End Function
Function MakeGraphFacts(ByRef Values() As SemanticFact, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
    MakeGraphFacts = ResizeGraphFacts(Values, Count, Keep)
End Function
Private Intrinsic Function ResizeGraphTargets(ByRef Values() As NativeDeclarationTarget, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute ResizeGraphTargets.UBE_Primitive = "Array.TryResize"
End Function
Function MakeGraphTargets(ByRef Values() As NativeDeclarationTarget, ByVal Count As Long) As Boolean
    MakeGraphTargets = ResizeGraphTargets(Values, Count, False)
End Function
Private Intrinsic Function ResizeDeclarationFixture(ByRef Values() As SemanticDeclaration, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute ResizeDeclarationFixture.UBE_Primitive = "Array.TryResize"
End Function
Function MakeNativeDeclarations(ByRef Values() As SemanticDeclaration, ByVal Count As Long) As Boolean
    MakeNativeDeclarations = ResizeDeclarationFixture(Values, Count, False)
End Function
Private Intrinsic Function ResizeTypeFixture(ByRef Values() As SemanticType, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute ResizeTypeFixture.UBE_Primitive = "Array.TryResize"
End Function
Function MakeNativeTypes(ByRef Values() As SemanticType, ByVal Count As Long) As Boolean
    MakeNativeTypes = ResizeTypeFixture(Values, Count, False)
End Function
