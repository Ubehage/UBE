UBE SOURCE 1 MODULE
Attribute UBE_Name = "SemanticDeclarations"

Function TrySemanticAttributeTarget(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal SyntaxId As Long, ByVal EnclosingId As Long, ByRef Matches As Boolean, ByRef Code As Long, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticAttributeTarget = False
    Matches = False
    Code = 1425
    Call ResetSemanticFailure(Failure)
    If EnclosingId < Catalog.SourceCount Or EnclosingId >= Catalog.DeclarationCount Then
        TrySemanticAttributeTarget = True
        Exit Function
    End If
    Dim Prefix As SyntaxNode
    If TryReadCatalogSyntax(Catalog, SourceId, SyntaxId, Prefix, Failure) = False Then
        Exit Function
    End If
    If Prefix.Kind = 1 Then
        Dim WrittenName As Long = -1
        If TryGetSemanticName(Catalog, SourceId, SyntaxId, WrittenName, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        Dim Declaration As SemanticDeclaration
        Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(EnclosingId))
        If TrySemanticNamesEqual(Catalog, WrittenName, Declaration.NameId, Matches, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
    Else
        If Prefix.Kind = 34 Then
            Dim First As SyntaxNode
            If TryReadCatalogSyntax(Catalog, SourceId, Prefix.FirstChild, First, Failure) = False Then
                Exit Function
            End If
            If First.Kind <> 1 Then
                Code = 1400
            Else
                Dim Second As SyntaxNode
                If TryReadCatalogSyntax(Catalog, SourceId, First.NextSibling, Second, Failure) = False Then
                    Exit Function
                End If
                If Second.Kind = 1 And Second.NextSibling < 0 Then
                    Dim ModuleName As Long = -1
                    Dim MemberName As Long = -1
                    If TryGetSemanticName(Catalog, SourceId, Prefix.FirstChild, ModuleName, Failure) = False Then
                        Exit Function
                    End If
                    Call ResetSemanticFailure(Failure)
                    If TryGetSemanticName(Catalog, SourceId, First.NextSibling, MemberName, Failure) = False Then
                        Exit Function
                    End If
                    Call ResetSemanticFailure(Failure)
                    Dim Selected As Long = -1
                    Dim ModuleId As Long = -1
                    Dim LookupFailure As SemanticFailure
                    Call ResetSemanticFailure(LookupFailure)
                    If TryLookupSemanticQualified(Catalog, SourceId, ModuleName, MemberName, Selected, ModuleId, LookupFailure) = False Then
                        If LookupFailure.Kind <> 3 And LookupFailure.Kind <> 8 Then
                            Failure = LookupFailure
                            Exit Function
                        End If
                    Else
                        Matches = Selected = EnclosingId
                    End If
                End If
            End If
        End If
    End If
    If Matches Then
        Code = 0
    End If
    Call ResetSemanticFailure(Failure)
    TrySemanticAttributeTarget = True
End Function

Type SemanticDeclarationFrame
    SyntaxId As Long
    Scope As Long
    Depth As Long
End Type
Intrinsic Function SemanticDeclarationFramesLength(ByRef Values() As SemanticDeclarationFrame) As Long
Attribute SemanticDeclarationFramesLength.UBE_Primitive = "Array.Length"
End Function

Function TrySemanticDeclarationTypeAnchor(ByVal Catalog As SemanticCatalog, ByRef Declaration As SemanticDeclaration, ByRef Anchor As SyntaxNode, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticDeclarationTypeAnchor = False
    Dim Node As SyntaxNode
    If TryReadCatalogSyntax(Catalog, Declaration.SourceId, Declaration.SyntaxId, Node, Failure) = False Then
        Exit Function
    End If
    If Declaration.Kind = 5 Or Declaration.Kind = 6 Then
        If TryReadCatalogSyntax(Catalog, Declaration.SourceId, Node.FirstChild, Node, Failure) = False Then
            Exit Function
        End If
        Dim ResultId As Long = -1
        If TrySemanticChild(Catalog, Declaration.SourceId, Node, 57, ResultId, Failure) = False Then
            Exit Function
        End If
        If ResultId >= 0 Then
            If TryReadCatalogSyntax(Catalog, Declaration.SourceId, ResultId, Node, Failure) = False Then
                Exit Function
            End If
        End If
    End If
    Dim ClauseId As Long = -1
    If TrySemanticChild(Catalog, Declaration.SourceId, Node, 80, ClauseId, Failure) = False Then
        Exit Function
    End If
    If ClauseId >= 0 Then
        If TryReadCatalogSyntax(Catalog, Declaration.SourceId, ClauseId, Node, Failure) = False Then
            Exit Function
        End If
        Dim TypeId As Long = -1
        If TrySemanticChild(Catalog, Declaration.SourceId, Node, 74, TypeId, Failure) = False Then
            Exit Function
        End If
        If TryReadCatalogSyntax(Catalog, Declaration.SourceId, TypeId, Anchor, Failure) = False Then
            Exit Function
        End If
    Else
        Dim NameId As Long = -1
        If TrySemanticChild(Catalog, Declaration.SourceId, Node, 1, NameId, Failure) = False Then
            Exit Function
        End If
        If TryReadCatalogSyntax(Catalog, Declaration.SourceId, NameId, Anchor, Failure) = False Then
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Failure)
    TrySemanticDeclarationTypeAnchor = True
End Function

Function TrySemanticParameterModeAnchor(ByVal Catalog As SemanticCatalog, ByRef Parameter As SemanticDeclaration, ByRef Anchor As SyntaxNode, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticParameterModeAnchor = False
    Dim Node As SyntaxNode
    If TryReadCatalogSyntax(Catalog, Parameter.SourceId, Parameter.SyntaxId, Node, Failure) = False Then
        Exit Function
    End If
    Anchor = Node
    Dim Current As Long = Node.FirstChild
    While Current >= 0
        Dim Child As SyntaxNode
        If TryReadCatalogSyntax(Catalog, Parameter.SourceId, Current, Child, Failure) = False Then
            Exit Function
        End If
        If Child.Kind = 78 Then
            Dim Matches As Boolean = False
            If TrySemanticWord(Catalog, Parameter.SourceId, Child, "byref", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Anchor = Child
                Call ResetSemanticFailure(Failure)
                TrySemanticParameterModeAnchor = True
                Exit Function
            End If
        End If
        Current = Child.NextSibling
    Wend
    Call ResetSemanticFailure(Failure)
    TrySemanticParameterModeAnchor = True
End Function
Function TryRecordSemanticAttribute(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal SyntaxId As Long, ByVal Scope As Long, ByRef Failure As SemanticFailure) As Boolean
    TryRecordSemanticAttribute = False
    Dim Fact As SemanticFact
    Fact.SourceId = SourceId
    Fact.SyntaxId = SyntaxId
    Fact.Kind = 8
    Fact.TypeId = -1
    Fact.Target = Scope
    Fact.Auxiliary = -1
    Fact.Extra = -1
    Dim Id As Long = -1
    If TryAppendCatalogFact(Catalog, Fact, Id, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    TryRecordSemanticAttribute = True
End Function

Function TryRecordSemanticCatalogBinding(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal SyntaxId As Long, ByVal Target As Long, ByVal TypeId As Long, ByVal Role As Long, ByVal Level As Long, ByRef Failure As SemanticFailure) As Boolean
    TryRecordSemanticCatalogBinding = False
    Call ResetSemanticFailure(Failure)
    Dim Binding As SemanticFact
    Binding.SourceId = SourceId
    Binding.SyntaxId = SyntaxId
    Binding.Kind = 2
    Binding.TypeId = TypeId
    Binding.Target = Target
    Binding.Left = Role
    Binding.Right = Level
    Binding.Auxiliary = -1
    Binding.Extra = -1
    Dim Id As Long = -1
    If TryAppendCatalogFact(Catalog, Binding, Id, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    TryRecordSemanticCatalogBinding = True
End Function

' Preparation records already-resolved identities; public frozen lookups stay pure.
Function TryRecordSemanticTypeBindings(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal SyntaxId As Long, ByVal TypeId As Long, ByRef Failure As SemanticFailure) As Boolean
    TryRecordSemanticTypeBindings = False
    Call ResetSemanticFailure(Failure)
    If TypeId < 6 Then
        TryRecordSemanticTypeBindings = True
        Exit Function
    End If
    Dim Native As SemanticType
    Call ReadSemanticType(Native, Catalog.Types(TypeId))
    Dim Declaration As SemanticDeclaration
    Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(Native.Declaration))
    Dim TypeNode As SyntaxNode
    If TryReadCatalogSyntax(Catalog, SourceId, SyntaxId, TypeNode, Failure) = False Then
        Exit Function
    End If
    Dim First As SyntaxNode
    If TryReadCatalogSyntax(Catalog, SourceId, TypeNode.FirstChild, First, Failure) = False Then
        Exit Function
    End If
    Dim Level As Long = 3
    If Declaration.SourceId <> SourceId Then
        Level = 4
        Call ResetSemanticFailure(Failure)
        If Catalog.Sources(Declaration.SourceId).PackageId <> Catalog.Sources(SourceId).PackageId Then
            Level = 5
        End If
    End If
    Dim NameSyntaxId As Long = TypeNode.FirstChild
    If First.NextSibling >= 0 Then
        If TryRecordSemanticCatalogBinding(Catalog, SourceId, NameSyntaxId, Declaration.SourceId, 0, 6, Level, Failure) = False Then
            Exit Function
        End If
        NameSyntaxId = First.NextSibling
        Level = 6
    End If
    If TryRecordSemanticCatalogBinding(Catalog, SourceId, NameSyntaxId, Native.Declaration, TypeId, 7, Level, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    TryRecordSemanticTypeBindings = True
End Function

Function TryValidateSemanticAttribute(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByVal FactId As Long, ByRef Diagnostic As SemanticFailure, ByRef Failure As SemanticFailure) As Boolean
    TryValidateSemanticAttribute = False
    Call ResetSemanticFailure(Failure)
    Dim Fact As SemanticFact
    Call ReadSemanticFact(Fact, Catalog.Facts(FactId))
    Dim AttributeNode As SyntaxNode
    If TryReadCatalogSyntax(Catalog, Fact.SourceId, Fact.SyntaxId, AttributeNode, Failure) = False Then
        Exit Function
    End If
    Dim Target As SyntaxNode
    If TryReadCatalogSyntax(Catalog, Fact.SourceId, AttributeNode.FirstChild, Target, Failure) = False Then
        Exit Function
    End If
    Dim Primitive As Boolean = False
    Dim AttributeName As SyntaxNode
    Dim TargetNameSyntaxId As Long = -1
    If Target.Kind = 34 Then
        Dim Base As SyntaxNode
        If TryReadCatalogSyntax(Catalog, Fact.SourceId, Target.FirstChild, Base, Failure) = False Then
            Exit Function
        End If
        If Base.NextSibling >= 0 Then
            TargetNameSyntaxId = Target.FirstChild
            If TryReadCatalogSyntax(Catalog, Fact.SourceId, Base.NextSibling, AttributeName, Failure) = False Then
                Exit Function
            End If
            Dim AttributeNameId As Long = -1
            If TryGetSemanticName(Catalog, Fact.SourceId, Base.NextSibling, AttributeNameId, Failure) = False Then
                Exit Function
            End If
            Call ResetSemanticFailure(Failure)
            If TrySemanticNameWord(Catalog, AttributeNameId, "ube_primitive", Primitive, Failure) = False Then
                Exit Function
            End If
        End If
    Else
        Dim ModuleIdentity As Boolean = False
        If TrySemanticWord(Catalog, Fact.SourceId, Target, "ube_name", ModuleIdentity, Failure) = False Then
            Exit Function
        End If
        If ModuleIdentity Then
            Fact.Left = 1
            Fact.Target = Fact.SourceId
        Else
            Fact.Target = -1
        End If
    End If
    If Primitive Then
        Fact.Left = 2
        Dim Value As SyntaxNode
        If TryReadCatalogSyntax(Catalog, Fact.SourceId, Target.NextSibling, Value, Failure) = False Then
            Exit Function
        End If
        Dim Literal As SyntaxNode
        If TryReadCatalogSyntax(Catalog, Fact.SourceId, Value.FirstChild, Literal, Failure) = False Then
            Exit Function
        End If
        Dim Code As Long = 0
        Dim ErrorAnchor As SyntaxNode
        ErrorAnchor = Literal
        Dim TargetMatches As Boolean = False
        If TrySemanticAttributeTarget(Catalog, Fact.SourceId, TargetNameSyntaxId, Fact.Target, TargetMatches, Code, Failure) = False Then
            Exit Function
        End If
        If TargetMatches = False Then
            If TryReadCatalogSyntax(Catalog, Fact.SourceId, TargetNameSyntaxId, ErrorAnchor, Failure) = False Then
                Exit Function
            End If
        End If
        Dim Role As Long = 0
        If Code = 0 Then
        Dim IsString As Boolean = Literal.Kind = 2 And Literal.LastByte - Literal.FirstByte >= 2
        Call ResetSemanticFailure(Failure)
        If IsString Then
            IsString = Catalog.Sources(Fact.SourceId).SyntaxInput.Owner.Document.Bytes(Literal.FirstByte) = 34
        End If
        If IsString = False Or Value.NextSibling >= 0 Then
            Code = 1425
        Else
            Dim RoleText As SyntaxNode
            RoleText = Literal
            RoleText.FirstByte = RoleText.FirstByte + 1
            RoleText.LastByte = RoleText.LastByte - 1
            Dim Matches As Boolean = False
            If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "value.pack", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Role = 1
            End If
            If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "value.unpack", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Role = 2
            End If
            If Role = 0 Then
                Code = 1425
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "array.length", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "array.tryresize", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "array.trycopy", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "memory.collect", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "memory.copybytes", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "file.tryopen", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "file.tryread", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "file.trywrite", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "file.tryflush", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "file.tryclose", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "process.tryargument", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "error.set", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "thread.trycurrentid", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "thread.tryisalive", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "thread.tryrequeststop", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "thread.trystoprequested", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "thread.trywait", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
                If TrySemanticWord(Catalog, Fact.SourceId, RoleText, "thread.tryyield", Matches, Failure) = False Then
                    Exit Function
                End If
                If Matches Then
                    Code = 1435
                End If
            End If
        End If
        End If
        If Code = 0 Then
            Call ResetSemanticFailure(Failure)
            If Fact.Target < Catalog.SourceCount Or Fact.Target >= Catalog.DeclarationCount Then
                Code = 1425
            Else
                Dim Procedure As SemanticDeclaration
                Call ReadSemanticDeclaration(Procedure, Catalog.Declarations(Fact.Target))
                Dim SameName As Boolean = TargetMatches
                If Procedure.Kind <> 6 Or (Procedure.Flags And 16) = 0 Or Procedure.ParameterCount <> 1 Or Procedure.Auxiliary <> 0 Or SameName = False Then
                    Code = 1425
                    If SameName = False Then
                        If TryReadCatalogSyntax(Catalog, Fact.SourceId, TargetNameSyntaxId, ErrorAnchor, Failure) = False Then
                            Exit Function
                        End If
                    End If
                Else
                    Dim SignatureReady As Boolean = False
                    Dim SignatureSelected As Boolean = False
                    If TrySemanticIntrinsicSignatureReady(Catalog, Cancellation, Procedure, SignatureReady, SignatureSelected, Failure) = False Then
                        Exit Function
                    End If
                    If SignatureReady And SignatureSelected Then
                    Dim Parameter As SemanticDeclaration
                    Call ResetSemanticFailure(Failure)
                    Call ReadSemanticDeclaration(Parameter, Catalog.Declarations(Procedure.FirstParameter))
                    If (Parameter.Flags And 4) = 0 Or (Parameter.Flags And 8) <> 0 Then
                        Code = 1425
                        If TrySemanticParameterModeAnchor(Catalog, Parameter, ErrorAnchor, Failure) = False Then
                            Exit Function
                        End If
                    Else
                        Dim NativeTypeId As Long = Procedure.TypeId
                        Dim RepresentationTypeId As Long = Parameter.TypeId
                        If Role = 2 Then
                            NativeTypeId = Parameter.TypeId
                            RepresentationTypeId = Procedure.TypeId
                        End If
                        If NativeTypeId < 6 Or NativeTypeId >= Catalog.TypeCount Then
                            Code = 1425
                            If Role = 1 Then
                                If TrySemanticDeclarationTypeAnchor(Catalog, Procedure, ErrorAnchor, Failure) = False Then
                                    Exit Function
                                End If
                            Else
                                If TrySemanticDeclarationTypeAnchor(Catalog, Parameter, ErrorAnchor, Failure) = False Then
                                    Exit Function
                                End If
                            End If
                        Else
                            Dim NativeType As SemanticType
                            Call ReadSemanticType(NativeType, Catalog.Types(NativeTypeId))
                            Dim NativeDeclaration As SemanticDeclaration
                            Call ReadSemanticDeclaration(NativeDeclaration, Catalog.Declarations(NativeType.Declaration))
                            If NativeDeclaration.SourceId <> Procedure.SourceId Then
                                Code = 1425
                            Else
                            If NativeType.Representation < 2 Or NativeType.Representation > 4 Then
                                ' The native declaration already records its
                                ' representation deferral. No mismatch is known.
                                Procedure.Auxiliary = -1
                                Call ResetSemanticFailure(Failure)
                                Call WriteSemanticDeclaration(Catalog.Declarations(Fact.Target), Procedure)
                            Else
                            If NativeType.Representation <> RepresentationTypeId Then
                                Code = 1425
                            End If
                            If Role = 1 Then
                                If NativeType.PackDeclaration >= 0 Then
                                    Code = 1425
                                End If
                                NativeType.PackDeclaration = Fact.Target
                            Else
                                If NativeType.UnpackDeclaration >= 0 Then
                                    Code = 1425
                                End If
                                NativeType.UnpackDeclaration = Fact.Target
                            End If
                            If Code = 0 Then
                                Procedure.Auxiliary = Role
                                Call WriteSemanticType(Catalog.Types(NativeTypeId), NativeType)
                                Call WriteSemanticDeclaration(Catalog.Declarations(Fact.Target), Procedure)
                            End If
                            End If
                            End If
                        End If
                    End If
                    Else
                        ' The binding is written but cannot be typed yet. Keep
                        ' its type diagnostic; do not invent a missing binding.
                        Procedure.Auxiliary = -1
                        Call ResetSemanticFailure(Failure)
                        Call WriteSemanticDeclaration(Catalog.Declarations(Fact.Target), Procedure)
                    End If
                End If
            End If
        End If
        If Code <> 0 Then
            Call RecordSemanticDiagnostic(Diagnostic, Code, Fact.SourceId, ErrorAnchor.FirstByte, ErrorAnchor.LastByte, -1, 0, 0)
            Call ResetSemanticFailure(Failure)
            If Fact.Target >= Catalog.SourceCount And Fact.Target < Catalog.DeclarationCount Then
                Dim InvalidBinding As SemanticDeclaration
                Call ReadSemanticDeclaration(InvalidBinding, Catalog.Declarations(Fact.Target))
                If InvalidBinding.Auxiliary = 0 Then
                    InvalidBinding.Auxiliary = -1
                    Call WriteSemanticDeclaration(Catalog.Declarations(Fact.Target), InvalidBinding)
                End If
            End If
        Else
            Dim BindingSyntaxId As Long = TargetNameSyntaxId
            Dim BindingTarget As SyntaxNode
            If TryReadCatalogSyntax(Catalog, Fact.SourceId, BindingSyntaxId, BindingTarget, Failure) = False Then
                Exit Function
            End If
            If BindingTarget.Kind = 34 Then
                Dim BindingPrefix As SyntaxNode
                If TryReadCatalogSyntax(Catalog, Fact.SourceId, BindingTarget.FirstChild, BindingPrefix, Failure) = False Then
                    Exit Function
                End If
                BindingSyntaxId = BindingPrefix.NextSibling
            End If
            Dim BoundDeclaration As SemanticDeclaration
            Call ResetSemanticFailure(Failure)
            Call ReadSemanticDeclaration(BoundDeclaration, Catalog.Declarations(Fact.Target))
            If TryRecordSemanticCatalogBinding(Catalog, Fact.SourceId, BindingSyntaxId, Fact.Target, BoundDeclaration.TypeId, 9, 8, Failure) = False Then
                Exit Function
            End If
        End If
        Fact.Right = Role
        Fact.SyntaxId = Value.FirstChild
    Else
        If Target.Kind = 34 Then
            Fact.Target = -1
        End If
    End If
    Call ResetSemanticFailure(Failure)
    Call WriteSemanticFact(Catalog.Facts(FactId), Fact)
    Call ResetSemanticFailure(Failure)
    TryValidateSemanticAttribute = True
End Function

Function TryPrepareSemanticTypes(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByRef Failure As SemanticFailure) As Boolean
    TryPrepareSemanticTypes = False
    Call ResetSemanticFailure(Failure)
    Dim NativeCount As Long = 0
    Dim Id As Long = Catalog.SourceCount
    While Id < Catalog.DeclarationCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        If Catalog.Declarations(Id).Kind = 7 Then
            NativeCount = NativeCount + 1
        End If
        Id = Id + 1
    Wend
    If TryResizeSemanticTypes(Catalog.Types, NativeCount + 6, False) = False Then
        Exit Function
    End If
    Catalog.TypeCount = NativeCount + 6
    Id = 0
    While Id < 6
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim TypeInfo As SemanticType
        TypeInfo.Declaration = -1
        TypeInfo.Representation = -1
        TypeInfo.PackDeclaration = -1
        TypeInfo.UnpackDeclaration = -1
        TypeInfo.Kind = 2
        If Id = 0 Then
            TypeInfo.Kind = 0
        End If
        If Id = 1 Then
            TypeInfo.Kind = 1
            TypeInfo.Maximum = 1
        End If
        If Id = 2 Then
            TypeInfo.Bits = 8
            TypeInfo.Maximum = 255
        End If
        If Id = 3 Then
            TypeInfo.Bits = 16
            TypeInfo.Minimum = -32768
            TypeInfo.Maximum = 32767
        End If
        If Id = 4 Then
            TypeInfo.Bits = 32
            TypeInfo.Minimum = -2147483647 - 1
            TypeInfo.Maximum = 2147483647
        End If
        If Id = 5 Then
            TypeInfo.Bits = 64
            Dim Half As LongLong = 2147483648
            Dim Maximum As LongLong = Half * Half
            Maximum = (Maximum - 1) * 2 + 1
            TypeInfo.Maximum = Maximum
            TypeInfo.Minimum = -Maximum - 1
        End If
        Call WriteSemanticType(Catalog.Types(Id), TypeInfo)
        Id = Id + 1
    Wend
    Id = Catalog.SourceCount
    Dim NativeId As Long = 6
    While Id < Catalog.DeclarationCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Declaration As SemanticDeclaration
        Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(Id))
        If Declaration.Kind = 7 Then
            Dim Native As SemanticType
            Native.Kind = 3
            Native.Declaration = Id
            Native.Representation = -1
            Native.PackDeclaration = -1
            Native.UnpackDeclaration = -1
            Call WriteSemanticType(Catalog.Types(NativeId), Native)
            Declaration.TypeId = NativeId
            Call WriteSemanticDeclaration(Catalog.Declarations(Id), Declaration)
            NativeId = NativeId + 1
        End If
        Id = Id + 1
    Wend
    Call ResetSemanticFailure(Failure)
    TryPrepareSemanticTypes = True
End Function

' Flag128 records only an already-diagnosed deferred signature component.
' Missing binding requires no deferral; typed role decisions also need Selected.
Function TrySemanticIntrinsicSignatureReady(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByRef Procedure As SemanticDeclaration, ByRef Ready As Boolean, ByRef Selected As Boolean, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticIntrinsicSignatureReady = False
    Ready = False
    Selected = False
    Call ResetSemanticFailure(Failure)
    Dim HasDeferred As Boolean = (Procedure.Flags And 128) <> 0
    Dim TypesAvailable As Boolean = Procedure.TypeId >= 0
    Dim Ordinal As Long = 0
    While Ordinal < Procedure.ParameterCount
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Parameter As SemanticDeclaration
        Call ReadSemanticDeclaration(Parameter, Catalog.Declarations(Procedure.FirstParameter + Ordinal))
        If (Parameter.Flags And 128) <> 0 Then
            HasDeferred = True
        End If
        If Parameter.TypeId < 0 Then
            TypesAvailable = False
        End If
        Ordinal = Ordinal + 1
    Wend
    If HasDeferred = False Then
        Ready = True
    End If
    Selected = TypesAvailable
    TrySemanticIntrinsicSignatureReady = True
End Function

Function TryBuildSemanticDeclarations(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByRef Failure As SemanticFailure) As Boolean
    TryBuildSemanticDeclarations = False
    Call ResetSemanticFailure(Failure)
    If Catalog Is Nothing Then
        TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Catalog.SourceCount < 1 Or Catalog.SourceCount > 256 Or Catalog.PackageCount < 1 Or Catalog.PackageCount > 2 Then
        TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Catalog.Limits.MaximumDeclarations < 0 Or Catalog.Limits.MaximumDeclarations > 1048576 Or Catalog.Limits.MaximumFacts < 0 Or Catalog.Limits.MaximumFacts > 1048576 Or Catalog.Limits.MaximumPending < 0 Or Catalog.Limits.MaximumPending > 1048576 Or Catalog.Limits.MaximumDepth < 0 Or Catalog.Limits.MaximumDepth > 256 Then
        TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Catalog.DeclarationCount <> 0 Or Catalog.NameCount <> 0 Or Catalog.TypeCount <> 0 Or Catalog.KeyCount <> 0 Or Catalog.FactCount <> 0 Or Catalog.ValueCount <> 0 Then
        TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
        Exit Function
    End If
    If SemanticSourcesLength(Catalog.Sources) <> Catalog.SourceCount Then
        TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
        Exit Function
    End If
    If Catalog.SourceCount > Catalog.Limits.MaximumDeclarations Then
        TryBuildSemanticDeclarations = FailSemanticBudget(Failure)
        Exit Function
    End If
    Dim ValidateSource As Long = 0
    While ValidateSource < Catalog.SourceCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim InputSource As SemanticSource
        If TryRetainSemanticSource(Catalog.Sources(ValidateSource), InputSource) = False Then
        Exit Function
    End If
        If InputSource Is Nothing Then
            TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
            Exit Function
        End If
        If InputSource.SourceId <> ValidateSource Or InputSource.PackageId < 0 Or InputSource.PackageId >= Catalog.PackageCount Then
            TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
            Exit Function
        End If
        Dim InputWork As SourceWork
        If TryRetainSemanticWork(InputSource.SyntaxInput, InputWork) = False Then
        Exit Function
    End If
        If InputWork Is Nothing Then
            TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
            Exit Function
        End If
        Dim InputOwner As SourceOwner
        If TryRetainSemanticOwner(InputWork.Owner, InputOwner) = False Then
        Exit Function
    End If
        If InputOwner Is Nothing Then
            TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
            Exit Function
        End If
        If InputWork.State <> 1 Or SyntaxResultLength(InputWork.Syntax) <> 1 Then
            TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
            Exit Function
        End If
        Dim SyntaxCount As Long = InputWork.Syntax(0).NodeCount
        Dim RootId As Long = InputWork.Syntax(0).Root
        If SyntaxCount < 1 Or SyntaxCount > SyntaxNodeLength(InputWork.Syntax(0).Nodes) Or RootId < 0 Or RootId >= SyntaxCount Then
            TryBuildSemanticDeclarations = FailSemanticDomain(Failure)
            Exit Function
        End If
        ValidateSource = ValidateSource + 1
    Wend
    If TryPrepareSemanticNames(Catalog, Cancellation, Failure) = False Then
        Exit Function
    End If
    Dim Diagnostic As SemanticFailure
    Dim SourceId As Long = 0
    While SourceId < Catalog.SourceCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        Dim Source As SemanticSource
        If TryRetainSemanticSource(Catalog.Sources(SourceId), Source) = False Then
        Exit Function
    End If
        Dim ModuleInfo As SemanticDeclaration
        Call NewSemanticDeclaration(ModuleInfo, SourceId, -1, -1, 1)
        ModuleInfo.TypeId = 0
        ModuleInfo.Flags = 1
        If Source.Envelope.HasIdentity Then
            If TryAppendSemanticName(Catalog, Cancellation, SourceId, -1, Source.Envelope.IdentityFirst, Source.Envelope.IdentityLast, True, ModuleInfo.NameId, Failure) = False Then
                Exit Function
            End If
        End If
        Dim Id As Long = -1
        If TryAppendSemanticDeclaration(Catalog, ModuleInfo, Id, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        Source.ModuleDeclaration = Id
        If Source.Envelope.Format = 1 And Source.Envelope.HasIdentity Then
            Dim RootNode As SyntaxNode
            If TryReadCatalogSyntax(Catalog, SourceId, Source.SyntaxInput.Syntax(0).Root, RootNode, Failure) = False Then
                Exit Function
            End If
            Dim ModuleFact As SemanticFact
            ModuleFact.SourceId = SourceId
            ModuleFact.SyntaxId = RootNode.FirstChild
            ModuleFact.Kind = 8
            ModuleFact.TypeId = -1
            ModuleFact.Target = Id
            ModuleFact.Left = 1
            ModuleFact.Auxiliary = -1
            ModuleFact.Extra = -1
            Dim ModuleFactId As Long = -1
            If TryAppendCatalogFact(Catalog, ModuleFact, ModuleFactId, Failure) = False Then
                Exit Function
            End If
        End If
        SourceId = SourceId + 1
    Wend
    SourceId = 0
    While SourceId < Catalog.SourceCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        Catalog.Sources(SourceId).FirstDeclaration = Catalog.DeclarationCount
        If TryCollectSemanticSource(Catalog, Cancellation, SourceId, Diagnostic, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        Catalog.Sources(SourceId).DeclarationCount = Catalog.DeclarationCount - Catalog.Sources(SourceId).FirstDeclaration
        SourceId = SourceId + 1
    Wend
    If TryPrepareSemanticTypes(Catalog, Cancellation, Failure) = False Then
        Exit Function
    End If
    If TryPrepareSemanticIndex(Catalog, Cancellation, Diagnostic, Failure) = False Then
        Exit Function
    End If
    Dim DeclarationId As Long = Catalog.SourceCount
    While DeclarationId < Catalog.DeclarationCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        If TryResolveSemanticDeclaration(Catalog, DeclarationId, Diagnostic, Failure) = False Then
            Exit Function
        End If
        DeclarationId = DeclarationId + 1
    Wend
    Dim FactId As Long = 0
    Call ResetSemanticFailure(Failure)
    Dim MetadataCount As Long = Catalog.FactCount
    While FactId < MetadataCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        If Catalog.Facts(FactId).Kind = 8 And Catalog.Facts(FactId).Left <> 1 Then
            If TryValidateSemanticAttribute(Catalog, Cancellation, FactId, Diagnostic, Failure) = False Then
                Exit Function
            End If
        End If
        FactId = FactId + 1
    Wend
    DeclarationId = Catalog.SourceCount
    While DeclarationId < Catalog.DeclarationCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Procedure As SemanticDeclaration
        Call ResetSemanticFailure(Failure)
        Call ReadSemanticDeclaration(Procedure, Catalog.Declarations(DeclarationId))
        If (Procedure.Flags And 16) <> 0 And Procedure.Auxiliary = 0 Then
            Dim SignatureReady As Boolean = False
            Dim SignatureSelected As Boolean = False
            If TrySemanticIntrinsicSignatureReady(Catalog, Cancellation, Procedure, SignatureReady, SignatureSelected, Failure) = False Then
                Exit Function
            End If
            If SignatureReady Then
                Dim NameRecord As SemanticName
                Call ReadSemanticName(NameRecord, Catalog.Names(Procedure.NameId))
                Call RecordSemanticDiagnostic(Diagnostic, 1425, Procedure.SourceId, NameRecord.FirstByte, NameRecord.LastByte, -1, 0, 0)
            End If
        End If
        DeclarationId = DeclarationId + 1
    Wend
    If Diagnostic.Kind <> 0 Then
        Failure = Diagnostic
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    If TryResizeSemanticDeclarations(Catalog.Declarations, Catalog.DeclarationCount, True) = False Then
        Exit Function
    End If
    If TryResizeSemanticNames(Catalog.Names, Catalog.NameCount, True) = False Then
        Exit Function
    End If
    If TryResizeByteStorage(Catalog.NameBytes.Storage, Catalog.NameBytes.Count, True) = False Then
        Exit Function
    End If
    Failure.Kind = 0
    Failure.Code = 0
    TryBuildSemanticDeclarations = True
End Function
Function TryAppendSemanticKey(ByVal Catalog As SemanticCatalog, ByVal Partition As Long, ByVal DeclarationId As Long, ByRef Failure As SemanticFailure) As Boolean
    TryAppendSemanticKey = False
    Call ResetSemanticFailure(Failure)
    Dim Declaration As SemanticDeclaration
    Dim NameRecord As SemanticName
    Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(DeclarationId))
    If Declaration.NameId < 0 Then
        Call ResetSemanticFailure(Failure)
        TryAppendSemanticKey = True
        Exit Function
    End If
    Call ReadSemanticName(NameRecord, Catalog.Names(Declaration.NameId))
    Dim Capacity As Long = SemanticKeysLength(Catalog.Keys)
    Dim Prepared As Long = Capacity
    If Catalog.KeyCount = 2147483647 Then
        TryAppendSemanticKey = FailSemanticBudget(Failure)
        Exit Function
    End If
    If TryGetStorageCapacity(Capacity, Catalog.KeyCount + 1, 2147483647, Prepared) = False Then
        TryAppendSemanticKey = FailSemanticBudget(Failure)
        Exit Function
    End If
    If Prepared <> Capacity Then
        If TryResizeSemanticKeys(Catalog.Keys, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Catalog.Keys(Catalog.KeyCount).Partition = Partition
    Catalog.Keys(Catalog.KeyCount).FirstByte = NameRecord.ByteFirst
    Catalog.Keys(Catalog.KeyCount).ByteCount = NameRecord.ByteCount
    Catalog.Keys(Catalog.KeyCount).Value = DeclarationId
    Catalog.KeyCount = Catalog.KeyCount + 1
    Call ResetSemanticFailure(Failure)
    TryAppendSemanticKey = True
End Function
Function TryPrepareSemanticIndex(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByRef Diagnostic As SemanticFailure, ByRef Failure As SemanticFailure) As Boolean
    TryPrepareSemanticIndex = False
    Call ResetSemanticFailure(Failure)
    Dim Id As Long = 0
    While Id < Catalog.DeclarationCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Declaration As SemanticDeclaration
        Call ResetSemanticFailure(Failure)
        Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(Id))
        If Declaration.Kind = 1 Then
            If TryAppendSemanticKey(Catalog, 0, Id, Failure) = False Then
                Exit Function
            End If
        Else
            If TryAppendSemanticKey(Catalog, Declaration.Scope + 1, Id, Failure) = False Then
                Exit Function
            End If
            Call ResetSemanticFailure(Failure)
            If Declaration.Scope < Catalog.SourceCount Then
                Dim Visibility As Long = Declaration.Flags And 3
                If Visibility = 1 Or Visibility = 3 Then
                    Dim PackageId As Long = Catalog.Sources(Declaration.SourceId).PackageId
                    If TryAppendSemanticKey(Catalog, Catalog.DeclarationCount + 1 + PackageId, Id, Failure) = False Then
                        Exit Function
                    End If
                    Call ResetSemanticFailure(Failure)
                    If Visibility = 1 And Catalog.Sources(Declaration.SourceId).PrivateModule = 0 Then
                        ' Admitted graph has at most the root and one direct reference.
                        If PackageId = 1 Then
                            If TryAppendSemanticKey(Catalog, Catalog.DeclarationCount + 1 + Catalog.PackageCount, Id, Failure) = False Then
                                Exit Function
                            End If
                        End If
                    End If
                End If
            End If
        End If
        Id = Id + 1
    Wend
    Call ResetSemanticFailure(Failure)
    If TryResizeSemanticKeys(Catalog.Keys, Catalog.KeyCount, True) = False Then
        Exit Function
    End If
    Dim Status As Long = 5
    If TryOrderByteKeys(Catalog.NameBytes.Storage, Catalog.Keys, Catalog.KeyCount, Catalog.KeyCount, Catalog.Order, Status) = False Then
        If Status <> 5 Then
            TryPrepareSemanticIndex = FailSemanticDomain(Failure)
        End If
        Exit Function
    End If
    Id = Catalog.SourceCount
    While Id < Catalog.DeclarationCount
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Candidate As SemanticDeclaration
        Call ResetSemanticFailure(Failure)
        Call ReadSemanticDeclaration(Candidate, Catalog.Declarations(Id))
        Dim First As Long = 0
        Dim Count As Long = 0
        Dim NameRecord As SemanticName
        Call ReadSemanticName(NameRecord, Catalog.Names(Candidate.NameId))
        Status = 5
        If TryFindByteKeyRange(Catalog.NameBytes.Storage, Catalog.Keys, Catalog.Order, Candidate.Scope + 1, NameRecord.ByteFirst, NameRecord.ByteCount, First, Count, Status) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        If Count > 1 Then
            Dim OriginalId As Long = Catalog.Keys(Catalog.Order(First)).Value
            If OriginalId <> Id Then
                Dim Original As SemanticDeclaration
                Dim OriginalName As SemanticName
                Call ReadSemanticDeclaration(Original, Catalog.Declarations(OriginalId))
                Call ReadSemanticName(OriginalName, Catalog.Names(Original.NameId))
                Dim Written As SyntaxNode
                Dim Earlier As SyntaxNode
                If TryReadCatalogSyntax(Catalog, Candidate.SourceId, NameRecord.SyntaxId, Written, Failure) = False Then
                    Exit Function
                End If
                If TryReadCatalogSyntax(Catalog, Original.SourceId, OriginalName.SyntaxId, Earlier, Failure) = False Then
                    Exit Function
                End If
                Call RecordSemanticDiagnostic(Diagnostic, 1402, Candidate.SourceId, Written.FirstByte, Written.LastByte, Original.SourceId, Earlier.FirstByte, Earlier.LastByte)
            End If
        End If
        Id = Id + 1
    Wend
    Call ResetSemanticFailure(Failure)
    TryPrepareSemanticIndex = True
End Function

Function TryPrepareSemanticOptions(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal SyntaxId As Long, ByRef Seen As Long, ByRef Diagnostic As SemanticFailure, ByRef Failure As SemanticFailure) As Boolean
    TryPrepareSemanticOptions = False
    Dim Node As SyntaxNode
    If TryReadCatalogSyntax(Catalog, SourceId, SyntaxId, Node, Failure) = False Then
        Exit Function
    End If
    Dim Fact As SemanticFact
    Fact.SourceId = SourceId
    Fact.SyntaxId = SyntaxId
    Fact.Kind = 7
    Fact.Target = -1
    Fact.TypeId = -1
    Fact.Auxiliary = -1
    Dim Current As Long = Node.FirstChild
    Dim Mask As Long = 0
    Dim InvalidValue As Boolean = False
    While Current >= 0
        Dim Word As SyntaxNode
        If TryReadCatalogSyntax(Catalog, SourceId, Current, Word, Failure) = False Then
            Exit Function
        End If
        Dim Matches As Boolean = False
        If TrySemanticWord(Catalog, SourceId, Word, "explicit", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Fact.Left = 1
                Mask = 1
        End If
        If TrySemanticWord(Catalog, SourceId, Word, "compare", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Fact.Left = 2
                Mask = 2
        End If
        If TrySemanticWord(Catalog, SourceId, Word, "base", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Fact.Left = 3
                Mask = 4
        End If
        If TrySemanticWord(Catalog, SourceId, Word, "private", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Fact.Left = 4
                Mask = 8
        End If
        If TrySemanticWord(Catalog, SourceId, Word, "on", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Fact.Right = 1
        End If
        If TrySemanticWord(Catalog, SourceId, Word, "text", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Fact.Right = 1
        End If
        If TrySemanticWord(Catalog, SourceId, Word, "1", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Fact.Right = 1
        End If
        If TrySemanticWord(Catalog, SourceId, Word, "off", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            InvalidValue = True
            Call RecordSemanticDiagnostic(Diagnostic, 1423, SourceId, Word.FirstByte, Word.LastByte, -1, 0, 0)
        End If
        If TrySemanticWord(Catalog, SourceId, Word, "database", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            InvalidValue = True
            Call RecordSemanticDiagnostic(Diagnostic, 1424, SourceId, Word.FirstByte, Word.LastByte, -1, 0, 0)
        End If
        Current = Word.NextSibling
    Wend
    If (Seen And Mask) <> 0 And InvalidValue = False Then
        Call RecordSemanticDiagnostic(Diagnostic, 1400, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
    End If
    Seen = Seen Or Mask
    If Fact.Left = 1 Or Fact.Left = 4 Then
        Fact.Right = 1
    End If
    Call ResetSemanticFailure(Failure)
    If Fact.Left = 4 Then
        Catalog.Sources(SourceId).PrivateModule = 1
    End If
    Dim FactId As Long = -1
    If TryAppendCatalogFact(Catalog, Fact, FactId, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    TryPrepareSemanticOptions = True
End Function

Function TryCollectSemanticSource(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByVal SourceId As Long, ByRef Diagnostic As SemanticFailure, ByRef Failure As SemanticFailure) As Boolean
    TryCollectSemanticSource = False
    Call ResetSemanticFailure(Failure)
    Dim Stack() As SemanticDeclarationFrame
    Dim Pending As Long = 1
    If Catalog.Limits.MaximumPending < 1 Then
        TryCollectSemanticSource = FailSemanticBudget(Failure)
        Exit Function
    End If
    If TryResizeSemanticDeclarationFrames(Stack, 1, False) = False Then
        Exit Function
    End If
    Stack(0).SyntaxId = Catalog.Sources(SourceId).SyntaxInput.Syntax(0).Root
    Stack(0).Scope = SourceId
    Stack(0).Depth = 0
    Dim SeenOptions As Long = 0
    While Pending > 0
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        If Pending > Catalog.Metrics.MaximumPending Then
            Catalog.Metrics.MaximumPending = Pending
        End If
        Pending = Pending - 1
        Dim Frame As SemanticDeclarationFrame
        Call CopySemanticDeclarationFrame(Frame, Stack(Pending))
        Dim Node As SyntaxNode
        If TryReadCatalogSyntax(Catalog, SourceId, Frame.SyntaxId, Node, Failure) = False Then
            Exit Function
        End If
        Dim ChildId As Long = -1
        Dim ChildScope As Long = Frame.Scope
        Dim ChildDepth As Long = Frame.Depth
        If Node.Kind = 45 Or Node.Kind = 46 Or Node.Kind = 48 Or (Node.Kind >= 67 And Node.Kind <= 71) Then
            ChildId = Node.FirstChild
            If Node.Kind >= 67 And Node.Kind <= 71 Then
                ChildDepth = ChildDepth + 1
            End If
        End If
        If Node.Kind = 65 Or Node.Kind = 66 Then
            If TryCollectSemanticProcedure(Catalog, Cancellation, SourceId, Frame.SyntaxId, ChildScope, ChildId, Diagnostic, Failure) = False Then
                Exit Function
            End If
            ChildDepth = 1
        End If
        If Node.Kind = 54 Or Node.Kind = 55 Then
            Dim Flags As Long = 2
            If TrySemanticModifiers(Catalog, SourceId, Node, 2, Node.Kind = 54, Flags, Diagnostic, Failure) = False Then
                Exit Function
            End If
            Dim Current As Long = Node.FirstChild
            While Current >= 0
                Call ResetSemanticFailure(Failure)
                If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
                    Exit Function
                End If
                Dim Declarator As SyntaxNode
                If TryReadCatalogSyntax(Catalog, SourceId, Current, Declarator, Failure) = False Then
                    Exit Function
                End If
                If Declarator.Kind = 77 Then
                    Dim Kind As Long = 2
                    If Node.Kind = 55 Then
                        Kind = 3
                    End If
                    Dim Id As Long = -1
                    If TryCollectSemanticStorage(Catalog, Cancellation, SourceId, Current, Frame.Scope, Kind, Flags, Id, Diagnostic, Failure) = False Then
                        Exit Function
                    End If
                End If
                Current = Declarator.NextSibling
            Wend
        End If
        If Node.Kind = 64 Then
            Dim NativeDeclaration As SemanticDeclaration
            Call NewSemanticDeclaration(NativeDeclaration, SourceId, Frame.SyntaxId, SourceId, 7)
            If TrySemanticModifiers(Catalog, SourceId, Node, 1, False, NativeDeclaration.Flags, Diagnostic, Failure) = False Then
                Exit Function
            End If
            Dim NativeName As Long = -1
            If TrySemanticChild(Catalog, SourceId, Node, 1, NativeName, Failure) = False Then
                Exit Function
            End If
            If TryGetSemanticName(Catalog, SourceId, NativeName, NativeDeclaration.NameId, Failure) = False Then
                Exit Function
            End If
            Call ResetSemanticFailure(Failure)
            Dim NativeId As Long = -1
            If TryAppendSemanticDeclaration(Catalog, NativeDeclaration, NativeId, Failure) = False Then
                Exit Function
            End If
        End If
        If Node.Kind = 63 Then
            Dim RecordNameId As Long = -1
            If TrySemanticChild(Catalog, SourceId, Node, 1, RecordNameId, Failure) = False Then
                Exit Function
            End If
            Dim RecordName As SyntaxNode
            If TryReadCatalogSyntax(Catalog, SourceId, RecordNameId, RecordName, Failure) = False Then
                Exit Function
            End If
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, RecordName.LastByte, -1, 0, 0)
        End If
        If Node.Kind = 51 Then
            If TryPrepareSemanticOptions(Catalog, SourceId, Frame.SyntaxId, SeenOptions, Diagnostic, Failure) = False Then
                Exit Function
            End If
        End If
        If Node.Kind = 52 Then
            If TryRecordSemanticAttribute(Catalog, SourceId, Frame.SyntaxId, Frame.Scope, Failure) = False Then
                Exit Function
            End If
        End If
        Call ResetSemanticFailure(Failure)
        If ChildDepth > Catalog.Limits.MaximumDepth Then
            TryCollectSemanticSource = FailSemanticBudget(Failure)
            Exit Function
        End If
        Call ResetSemanticFailure(Failure)
        If ChildDepth > Catalog.Metrics.MaximumDepth Then
            Catalog.Metrics.MaximumDepth = ChildDepth
        End If
        Dim Extra As Long = 0
        If Node.NextSibling >= 0 Then
            Extra = Extra + 1
        End If
        If ChildId >= 0 Then
            Extra = Extra + 1
        End If
        If Extra > Catalog.Limits.MaximumPending - Pending Then
            TryCollectSemanticSource = FailSemanticBudget(Failure)
            Exit Function
        End If
        Dim Capacity As Long = SemanticDeclarationFramesLength(Stack)
        Dim Prepared As Long = Capacity
        If TryGetStorageCapacity(Capacity, Pending + Extra, Catalog.Limits.MaximumPending, Prepared) = False Then
            TryCollectSemanticSource = FailSemanticBudget(Failure)
            Exit Function
        End If
        If Prepared <> Capacity Then
            If TryResizeSemanticDeclarationFrames(Stack, Prepared, True) = False Then
                Exit Function
            End If
        End If
        If Node.NextSibling >= 0 Then
            Frame.SyntaxId = Node.NextSibling
            Call CopySemanticDeclarationFrame(Stack(Pending), Frame)
            Pending = Pending + 1
        End If
        If ChildId >= 0 Then
            Frame.SyntaxId = ChildId
            Frame.Scope = ChildScope
            Frame.Depth = ChildDepth
            Call CopySemanticDeclarationFrame(Stack(Pending), Frame)
            Pending = Pending + 1
        End If
        Catalog.Metrics.Transitions = Catalog.Metrics.Transitions + 1
    Wend
    Call ResetSemanticFailure(Failure)
    TryCollectSemanticSource = True
End Function
Function TryResolveSemanticType(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByVal ScopeDeclId As Long, ByVal TypeSyntaxId As Long, ByRef TypeId As Long, ByRef Failure As SemanticFailure) As Boolean
    TryResolveSemanticType = False
    TypeId = -1
    Dim Node As SyntaxNode
    If TryReadCatalogSyntax(Catalog, SourceId, TypeSyntaxId, Node, Failure) = False Then
        Exit Function
    End If
    If Node.Kind = 80 Or Node.Kind = 57 Then
        Dim ChildId As Long = -1
        If Node.Kind = 57 Then
            If TrySemanticChild(Catalog, SourceId, Node, 80, ChildId, Failure) = False Then
                Exit Function
            End If
        Else
            If TrySemanticChild(Catalog, SourceId, Node, 74, ChildId, Failure) = False Then
                Exit Function
            End If
        End If
        If ChildId < 0 Then
            TryResolveSemanticType = FailSemanticDomain(Failure)
            Exit Function
        End If
        TypeSyntaxId = ChildId
        If TryReadCatalogSyntax(Catalog, SourceId, ChildId, Node, Failure) = False Then
            Exit Function
        End If
        If Node.Kind = 80 Then
            If TrySemanticChild(Catalog, SourceId, Node, 74, ChildId, Failure) = False Then
                Exit Function
            End If
            TypeSyntaxId = ChildId
            If TryReadCatalogSyntax(Catalog, SourceId, ChildId, Node, Failure) = False Then
                Exit Function
            End If
        End If
    End If
    Dim Diagnostic As SemanticFailure
    If Node.Kind <> 74 Then
        TryResolveSemanticType = FailSemanticDomain(Failure)
        Exit Function
    End If
    Dim First As SyntaxNode
    If TryReadCatalogSyntax(Catalog, SourceId, Node.FirstChild, First, Failure) = False Then
        Exit Function
    End If
    If First.Kind <> 1 Or First.NextSibling >= 0 Then
        If First.NextSibling >= 0 Then
            Dim Second As SyntaxNode
            If TryReadCatalogSyntax(Catalog, SourceId, First.NextSibling, Second, Failure) = False Then
                Exit Function
            End If
            If Second.Kind = 1 And Second.NextSibling < 0 Then
                Dim ModuleName As Long = -1
                Dim MemberName As Long = -1
                If TryGetSemanticName(Catalog, SourceId, Node.FirstChild, ModuleName, Failure) = False Then
                    Exit Function
                End If
                Call ResetSemanticFailure(Failure)
                If TryGetSemanticName(Catalog, SourceId, First.NextSibling, MemberName, Failure) = False Then
                    Exit Function
                End If
                Call ResetSemanticFailure(Failure)
                Dim DeclarationId As Long = -1
                Dim ModuleId As Long = -1
                If TryLookupSemanticQualified(Catalog, SourceId, ModuleName, MemberName, DeclarationId, ModuleId, Failure) = False Then
                    If Failure.Code = 1406 Then
                        Failure.Code = 1404
                    End If
                    Exit Function
                End If
                Call ResetSemanticFailure(Failure)
                Dim Declaration As SemanticDeclaration
                Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(DeclarationId))
                If Declaration.Kind = 7 Then
                    TypeId = Declaration.TypeId
                    Failure.Kind = 0
                    Failure.Code = 0
                    TryResolveSemanticType = True
                    Exit Function
                End If
                Call RecordSemanticDiagnostic(Diagnostic, 1405, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
                Failure = Diagnostic
                Exit Function
            End If
        End If
        Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
        Failure = Diagnostic
        Exit Function
    End If
    Dim Bare As Boolean = False
    Call ResetSemanticFailure(Failure)
    Bare = Catalog.Sources(SourceId).SyntaxInput.Owner.Document.Bytes(First.FirstByte) <> 91
    If Bare Then
        Dim Matches As Boolean = False
        If TrySemanticWord(Catalog, SourceId, First, "boolean", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            TypeId = 1
            Failure.Kind = 0
            Failure.Code = 0
            TryResolveSemanticType = True
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "byte", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            TypeId = 2
            Failure.Kind = 0
            Failure.Code = 0
            TryResolveSemanticType = True
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "integer", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            TypeId = 3
            Failure.Kind = 0
            Failure.Code = 0
            TryResolveSemanticType = True
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "long", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            TypeId = 4
            Failure.Kind = 0
            Failure.Code = 0
            TryResolveSemanticType = True
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "longlong", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            TypeId = 5
            Failure.Kind = 0
            Failure.Code = 0
            TryResolveSemanticType = True
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "any", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1405, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "string", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "single", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "double", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "longptr", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "currency", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "decimal", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "date", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "variant", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
        If TrySemanticWord(Catalog, SourceId, First, "object", Matches, Failure) = False Then
            Exit Function
        End If
        If Matches Then
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
            Failure = Diagnostic
            Exit Function
        End If
    End If
    Dim NameId As Long = -1
    If TryGetSemanticName(Catalog, SourceId, Node.FirstChild, NameId, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    Dim Selected As Long = -1
    Dim Level As Long = 0
    ' Procedure regions contain values and parameters, never datatype declarations.
    ' Resolve an As-type from its containing module before package/reference scopes.
    If TryLookupSemanticName(Catalog, SourceId, SourceId, NameId, False, Selected, Level, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    Dim Code As Long = 1404
    If Selected >= 0 Then
        Dim Found As SemanticDeclaration
        Call ResetSemanticFailure(Failure)
        Call ReadSemanticDeclaration(Found, Catalog.Declarations(Selected))
        Code = 1405
        If Found.Kind = 7 Then
            TypeId = Found.TypeId
            Failure.Kind = 0
            Failure.Code = 0
            TryResolveSemanticType = True
            Exit Function
        End If
    End If
    Call RecordSemanticDiagnostic(Diagnostic, Code, SourceId, Node.FirstByte, Node.LastByte, -1, 0, 0)
    Failure = Diagnostic
End Function

Function TryResolveSemanticDeclaration(ByVal Catalog As SemanticCatalog, ByVal Id As Long, ByRef Diagnostic As SemanticFailure, ByRef Failure As SemanticFailure) As Boolean
    TryResolveSemanticDeclaration = False
    Call ResetSemanticFailure(Failure)
    Dim Declaration As SemanticDeclaration
    Call ReadSemanticDeclaration(Declaration, Catalog.Declarations(Id))
    If Declaration.Kind = 1 Then
        Call ResetSemanticFailure(Failure)
        TryResolveSemanticDeclaration = True
        Exit Function
    End If
    Dim Node As SyntaxNode
    If TryReadCatalogSyntax(Catalog, Declaration.SourceId, Declaration.SyntaxId, Node, Failure) = False Then
        Exit Function
    End If
    Dim Container As SyntaxNode
    Container = Node
    If Declaration.Kind = 5 Or Declaration.Kind = 6 Then
        If TryReadCatalogSyntax(Catalog, Declaration.SourceId, Node.FirstChild, Container, Failure) = False Then
            Exit Function
        End If
    End If
    Dim NameSyntaxId As Long = -1
    If TrySemanticChild(Catalog, Declaration.SourceId, Container, 1, NameSyntaxId, Failure) = False Then
        Exit Function
    End If
    Dim NameRecord As SyntaxNode
    If TryReadCatalogSyntax(Catalog, Declaration.SourceId, NameSyntaxId, NameRecord, Failure) = False Then
        Exit Function
    End If
    Dim SuffixType As Long = -1
    If NameRecord.FirstChild >= 0 Then
        Dim Suffix As SyntaxNode
        If TryReadCatalogSyntax(Catalog, Declaration.SourceId, NameRecord.FirstChild, Suffix, Failure) = False Then
            Exit Function
        End If
        If Suffix.Kind = 83 Then
            Call ResetSemanticFailure(Failure)
            Dim Character As Long = Catalog.Sources(Declaration.SourceId).SyntaxInput.Owner.Document.Bytes(Suffix.FirstByte)
            SuffixType = -2
            If Character = 37 Then
                SuffixType = 3
            End If
            If Character = 38 Then
                SuffixType = 4
            End If
            If Character = 94 Then
                SuffixType = 5
            End If
            Declaration.Flags = Declaration.Flags Or 32
        End If
    End If
    Dim Clause As Long = -1
    If Declaration.Kind = 6 Then
        Dim ResultId As Long = -1
        If TrySemanticChild(Catalog, Declaration.SourceId, Container, 57, ResultId, Failure) = False Then
            Exit Function
        End If
        If ResultId >= 0 Then
            Dim Result As SyntaxNode
            If TryReadCatalogSyntax(Catalog, Declaration.SourceId, ResultId, Result, Failure) = False Then
                Exit Function
            End If
            If TrySemanticChild(Catalog, Declaration.SourceId, Result, 80, Clause, Failure) = False Then
                Exit Function
            End If
        End If
    Else
        If Declaration.Kind = 7 Then
            If TrySemanticChild(Catalog, Declaration.SourceId, Container, 74, Clause, Failure) = False Then
                Exit Function
            End If
        Else
            If TrySemanticChild(Catalog, Declaration.SourceId, Container, 80, Clause, Failure) = False Then
                Exit Function
            End If
        End If
    End If
    Dim SelectedType As Long = -1
    Dim TypeDiagnostic As SemanticFailure
    If Clause >= 0 Then
        Declaration.Flags = Declaration.Flags Or 64
        If TryResolveSemanticType(Catalog, Declaration.SourceId, Declaration.Scope, Clause, SelectedType, Failure) = False Then
            If Failure.Kind <> 3 And Failure.Kind <> 8 Then
                Exit Function
            End If
            TypeDiagnostic = Failure
            If TypeDiagnostic.Kind = 8 Then
                Declaration.Flags = Declaration.Flags Or 128
            End If
            If Declaration.Kind = 7 And TypeDiagnostic.Code = 1433 Then
                TypeDiagnostic.Code = 1434
            End If
            Call RecordSemanticDiagnostic(Diagnostic, TypeDiagnostic.Code, TypeDiagnostic.SourceId, TypeDiagnostic.FirstByte, TypeDiagnostic.LastByte, TypeDiagnostic.RelatedSourceId, TypeDiagnostic.RelatedFirst, TypeDiagnostic.RelatedLast)
        End If
        Call ResetSemanticFailure(Failure)
        Dim ClauseNode As SyntaxNode
        If TryReadCatalogSyntax(Catalog, Declaration.SourceId, Clause, ClauseNode, Failure) = False Then
            Exit Function
        End If
        Dim Current As Long = ClauseNode.FirstChild
        While Current >= 0
            Dim Part As SyntaxNode
            If TryReadCatalogSyntax(Catalog, Declaration.SourceId, Current, Part, Failure) = False Then
                Exit Function
            End If
            If Part.Kind = 78 Or Part.Kind = 79 Then
                Declaration.Flags = Declaration.Flags Or 128
                Call RecordSemanticDiagnostic(Diagnostic, 1400, Declaration.SourceId, Part.FirstByte, Part.LastByte, -1, 0, 0)
            End If
            Current = Part.NextSibling
        Wend
    Else
        If Declaration.Kind = 5 Then
            SelectedType = 0
        Else
            If SuffixType >= 0 Then
                SelectedType = SuffixType
            Else
                Dim Code As Long = 1401
                If SuffixType = -2 Then
                    Code = 1433
                    Declaration.Flags = Declaration.Flags Or 128
                End If
                Call RecordSemanticDiagnostic(Diagnostic, Code, Declaration.SourceId, NameRecord.FirstByte, NameRecord.LastByte, -1, 0, 0)
            End If
        End If
    End If
    If Clause >= 0 And SuffixType <> -1 And SelectedType >= 0 Then
        If SuffixType <> SelectedType Then
            Call RecordSemanticDiagnostic(Diagnostic, 1403, Declaration.SourceId, NameRecord.FirstByte, NameRecord.LastByte, -1, 0, 0)
        End If
    End If
    If Declaration.Kind = 7 Then
        If SelectedType <> 2 And SelectedType <> 3 And SelectedType <> 4 Then
            Dim Representation As SyntaxNode
            If TryReadCatalogSyntax(Catalog, Declaration.SourceId, Clause, Representation, Failure) = False Then
                Exit Function
            End If
            Call RecordSemanticDiagnostic(Diagnostic, 1434, Declaration.SourceId, Representation.FirstByte, Representation.LastByte, -1, 0, 0)
        Else
            Call ResetSemanticFailure(Failure)
            Dim Native As SemanticType
            Call ReadSemanticType(Native, Catalog.Types(Declaration.TypeId))
            Native.Representation = SelectedType
            Call WriteSemanticType(Catalog.Types(Declaration.TypeId), Native)
            Declaration.Auxiliary = SelectedType
        End If
    Else
        Declaration.TypeId = SelectedType
    End If
    Call ResetSemanticFailure(Failure)
    Call WriteSemanticDeclaration(Catalog.Declarations(Id), Declaration)
    If Clause >= 0 And SelectedType >= 0 Then
        Dim TypeSyntax As Long = Clause
        Dim TypeClause As SyntaxNode
        If TryReadCatalogSyntax(Catalog, Declaration.SourceId, Clause, TypeClause, Failure) = False Then
            Exit Function
        End If
        If TypeClause.Kind = 80 Then
            If TrySemanticChild(Catalog, Declaration.SourceId, TypeClause, 74, TypeSyntax, Failure) = False Then
                Exit Function
            End If
        End If
        Call ResetSemanticFailure(Failure)
        Dim Fact As SemanticFact
        Fact.SourceId = Declaration.SourceId
        Fact.SyntaxId = TypeSyntax
        Fact.Kind = 4
        Fact.TypeId = SelectedType
        Fact.Target = -1
        Fact.Left = Id
        Fact.Auxiliary = -1
        If SelectedType >= 6 Then
            Fact.Target = Catalog.Types(SelectedType).Declaration
        Else
            Fact.Flags = 1
        End If
        Dim FactId As Long = -1
        If TryAppendCatalogFact(Catalog, Fact, FactId, Failure) = False Then
            Exit Function
        End If
        If TryRecordSemanticTypeBindings(Catalog, Declaration.SourceId, TypeSyntax, SelectedType, Failure) = False Then
            Exit Function
        End If
    End If
    Call ResetSemanticFailure(Failure)
    TryResolveSemanticDeclaration = True
End Function
Intrinsic Function TryResizeSemanticDeclarationFrames(ByRef Values() As SemanticDeclarationFrame, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeSemanticDeclarationFrames.UBE_Primitive = "Array.TryResize"
End Function
Sub CopySemanticDeclarationFrame(ByRef Destination As SemanticDeclarationFrame, ByRef Original As SemanticDeclarationFrame)
    Destination = Original
End Sub
Function TryAppendSemanticDeclaration(ByVal Catalog As SemanticCatalog, ByRef Declaration As SemanticDeclaration, ByRef Id As Long, ByRef Failure As SemanticFailure) As Boolean
    TryAppendSemanticDeclaration = False
    Id = -1
    Call ResetSemanticFailure(Failure)
    If Catalog.DeclarationCount >= Catalog.Limits.MaximumDeclarations Then
        TryAppendSemanticDeclaration = FailSemanticBudget(Failure)
        Exit Function
    End If
    Dim Capacity As Long = SemanticDeclarationsLength(Catalog.Declarations)
    Dim Prepared As Long = Capacity
    If TryGetStorageCapacity(Capacity, Catalog.DeclarationCount + 1, Catalog.Limits.MaximumDeclarations, Prepared) = False Then
        TryAppendSemanticDeclaration = FailSemanticBudget(Failure)
        Exit Function
    End If
    If Capacity <> Prepared Then
        If TryResizeSemanticDeclarations(Catalog.Declarations, Prepared, True) = False Then
            Exit Function
        End If
    End If
    Call WriteSemanticDeclaration(Catalog.Declarations(Catalog.DeclarationCount), Declaration)
    Id = Catalog.DeclarationCount
    Catalog.DeclarationCount = Catalog.DeclarationCount + 1
    Catalog.Metrics.DeclarationWrites = Catalog.Metrics.DeclarationWrites + 1
    Call ResetSemanticFailure(Failure)
    TryAppendSemanticDeclaration = True
End Function
Function TrySemanticChild(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByRef Parent As SyntaxNode, ByVal Kind As Long, ByRef ChildId As Long, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticChild = False
    ChildId = -1
    Call ResetSemanticFailure(Failure)
    Dim Current As Long = Parent.FirstChild
    While Current >= 0
        Dim Child As SyntaxNode
        If TryReadCatalogSyntax(Catalog, SourceId, Current, Child, Failure) = False Then
            Exit Function
        End If
        If Child.Kind = Kind Then
            ChildId = Current
            Call ResetSemanticFailure(Failure)
            TrySemanticChild = True
            Exit Function
        End If
        Current = Child.NextSibling
    Wend
    Call ResetSemanticFailure(Failure)
    TrySemanticChild = True
End Function
Sub NewSemanticDeclaration(ByRef Declaration As SemanticDeclaration, ByVal SourceId As Long, ByVal SyntaxId As Long, ByVal Scope As Long, ByVal Kind As Long)
    Dim Blank As SemanticDeclaration
    Declaration = Blank
    Declaration.SourceId = SourceId
    Declaration.SyntaxId = SyntaxId
    Declaration.Scope = Scope
    Declaration.Kind = Kind
    Declaration.NameId = -1
    Declaration.TypeId = -1
    Declaration.FirstParameter = -1
    Declaration.InitializerSyntaxId = -1
    Declaration.BodySyntaxId = -1
End Sub
Function TrySemanticModifiers(ByVal Catalog As SemanticCatalog, ByVal SourceId As Long, ByRef Parent As SyntaxNode, ByVal DefaultVisibility As Long, ByVal AllowGlobal As Boolean, ByRef Flags As Long, ByRef Diagnostic As SemanticFailure, ByRef Failure As SemanticFailure) As Boolean
    TrySemanticModifiers = False
    Flags = DefaultVisibility
    Dim WrittenVisibility As Boolean = False
    Dim WrittenDim As Boolean = False
    Dim ModifiersId As Long = -1
    If TrySemanticChild(Catalog, SourceId, Parent, 85, ModifiersId, Failure) = False Then
        Exit Function
    End If
    If ModifiersId >= 0 Then
        Dim Modifiers As SyntaxNode
        If TryReadCatalogSyntax(Catalog, SourceId, ModifiersId, Modifiers, Failure) = False Then
            Exit Function
        End If
        Dim Current As Long = Modifiers.FirstChild
        While Current >= 0
            Dim Word As SyntaxNode
            If TryReadCatalogSyntax(Catalog, SourceId, Current, Word, Failure) = False Then
                Exit Function
            End If
            Dim Known As Boolean = False
            Dim Matches As Boolean = False
            If TrySemanticWord(Catalog, SourceId, Word, "public", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Known = True
                Flags = (Flags And -4) Or 1
            WrittenVisibility = True
            End If
            If TrySemanticWord(Catalog, SourceId, Word, "global", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Known = True
                Flags = (Flags And -4) Or 1
            WrittenVisibility = True
            If AllowGlobal = False Then
                Call RecordSemanticDiagnostic(Diagnostic, 1405, SourceId, Word.FirstByte, Word.LastByte, -1, 0, 0)
            End If
            End If
            If TrySemanticWord(Catalog, SourceId, Word, "private", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Known = True
                Flags = (Flags And -4) Or 2
            WrittenVisibility = True
            End If
            If TrySemanticWord(Catalog, SourceId, Word, "friend", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Known = True
                Flags = (Flags And -4) Or 3
            WrittenVisibility = True
            End If
            If TrySemanticWord(Catalog, SourceId, Word, "intrinsic", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Known = True
                Flags = Flags Or 16
            End If
            If TrySemanticWord(Catalog, SourceId, Word, "dim", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Known = True
            WrittenDim = True
            End If
            If TrySemanticWord(Catalog, SourceId, Word, "const", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Known = True
            End If
            If Known = False Then
                Call RecordSemanticDiagnostic(Diagnostic, 1400, SourceId, Word.FirstByte, Word.LastByte, -1, 0, 0)
            End If
            Current = Word.NextSibling
        Wend
        If WrittenVisibility And WrittenDim Then
            Call RecordSemanticDiagnostic(Diagnostic, 1405, SourceId, Modifiers.FirstByte, Modifiers.LastByte, -1, 0, 0)
        End If
    End If
    Call ResetSemanticFailure(Failure)
    TrySemanticModifiers = True
End Function

Function TryCollectSemanticStorage(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByVal SourceId As Long, ByVal SyntaxId As Long, ByVal Scope As Long, ByVal Kind As Long, ByVal Flags As Long, ByRef Id As Long, ByRef Diagnostic As SemanticFailure, ByRef Failure As SemanticFailure) As Boolean
    TryCollectSemanticStorage = False
    Dim Node As SyntaxNode
    If TryReadCatalogSyntax(Catalog, SourceId, SyntaxId, Node, Failure) = False Then
        Exit Function
    End If
    Dim Declaration As SemanticDeclaration
    Call NewSemanticDeclaration(Declaration, SourceId, SyntaxId, Scope, Kind)
    Declaration.Flags = Flags
    Dim Current As Long = Node.FirstChild
    While Current >= 0
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Child As SyntaxNode
        If TryReadCatalogSyntax(Catalog, SourceId, Current, Child, Failure) = False Then
            Exit Function
        End If
        If Child.Kind = 1 Then
            If TryGetSemanticName(Catalog, SourceId, Current, Declaration.NameId, Failure) = False Then
                Exit Function
            End If
            Call ResetSemanticFailure(Failure)
        End If
        If Child.Kind = 79 Then
            Dim ArrayName As SemanticName
            Call ResetSemanticFailure(Failure)
            Call ReadSemanticName(ArrayName, Catalog.Names(Declaration.NameId))
            Declaration.Flags = Declaration.Flags Or 128
            Call RecordSemanticDiagnostic(Diagnostic, 1433, SourceId, ArrayName.FirstByte, Child.LastByte, -1, 0, 0)
        End If
        If Child.Kind = 81 Then
            Declaration.InitializerSyntaxId = Child.FirstChild
        End If
        If Child.Kind = 78 Then
            Dim Matches As Boolean = False
            If TrySemanticWord(Catalog, SourceId, Child, "byval", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Declaration.Flags = Declaration.Flags Or 4
            End If
            If TrySemanticWord(Catalog, SourceId, Child, "optional", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Declaration.Flags = Declaration.Flags Or 8
            End If
            If TrySemanticWord(Catalog, SourceId, Child, "paramarray", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Declaration.Flags = Declaration.Flags Or 128
                Call RecordSemanticDiagnostic(Diagnostic, 1400, SourceId, Child.FirstByte, Child.LastByte, -1, 0, 0)
            End If
        End If
        Current = Child.NextSibling
    Wend
    If Declaration.NameId < 0 Then
        TryCollectSemanticStorage = FailSemanticDomain(Failure)
        Exit Function
    End If
    If TryAppendSemanticDeclaration(Catalog, Declaration, Id, Failure) = False Then
        Exit Function
    End If
    Call ResetSemanticFailure(Failure)
    TryCollectSemanticStorage = True
End Function

Function TryCollectSemanticProcedure(ByVal Catalog As SemanticCatalog, ByVal Cancellation As SourceCancellation, ByVal SourceId As Long, ByVal SyntaxId As Long, ByRef ProcedureId As Long, ByRef BodyId As Long, ByRef Diagnostic As SemanticFailure, ByRef Failure As SemanticFailure) As Boolean
    TryCollectSemanticProcedure = False
    BodyId = -1
    Dim Node As SyntaxNode
    If TryReadCatalogSyntax(Catalog, SourceId, SyntaxId, Node, Failure) = False Then
        Exit Function
    End If
    Dim Header As SyntaxNode
    If TryReadCatalogSyntax(Catalog, SourceId, Node.FirstChild, Header, Failure) = False Then
        Exit Function
    End If
    Dim Declaration As SemanticDeclaration
    Call NewSemanticDeclaration(Declaration, SourceId, SyntaxId, SourceId, 5)
    If TrySemanticModifiers(Catalog, SourceId, Header, 1, False, Declaration.Flags, Diagnostic, Failure) = False Then
        Exit Function
    End If
    Dim Current As Long = Header.FirstChild
    Dim ParametersId As Long = -1
    While Current >= 0
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Child As SyntaxNode
        If TryReadCatalogSyntax(Catalog, SourceId, Current, Child, Failure) = False Then
            Exit Function
        End If
        If Child.Kind = 78 Then
            Dim Matches As Boolean = False
            If TrySemanticWord(Catalog, SourceId, Child, "function", Matches, Failure) = False Then
                Exit Function
            End If
            If Matches Then
                Declaration.Kind = 6
            End If
        End If
        If Child.Kind = 1 Then
            If TryGetSemanticName(Catalog, SourceId, Current, Declaration.NameId, Failure) = False Then
                Exit Function
            End If
            Call ResetSemanticFailure(Failure)
        End If
        If Child.Kind = 47 Then
            ParametersId = Current
        End If
        Current = Child.NextSibling
    Wend
    ' Module lifecycle hooks are not part of the bounded semantic subset.
    ' Names are already unescaped and case-folded by the shared name owner.
    ' Defer before body checking so a hook cannot be silently accepted as an
    ' ordinary procedure, even if it is unused or has an unsupported signature.
    If Declaration.NameId >= 0 Then
        Dim LifecycleName As Boolean = False
        If TrySemanticNameWord(Catalog, Declaration.NameId, "module_initialize", LifecycleName, Failure) = False Then
            Exit Function
        End If
        If LifecycleName = False Then
            If TrySemanticNameWord(Catalog, Declaration.NameId, "module_terminate", LifecycleName, Failure) = False Then
                Exit Function
            End If
        End If
        If LifecycleName Then
            Dim LifecycleSpan As SemanticName
            Call ReadSemanticName(LifecycleSpan, Catalog.Names(Declaration.NameId))
            Call RecordSemanticDiagnostic(Diagnostic, 1400, SourceId, LifecycleSpan.FirstByte, LifecycleSpan.LastByte, -1, 0, 0)
        End If
    End If
    Current = Header.NextSibling
    While Current >= 0
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Part As SyntaxNode
        If TryReadCatalogSyntax(Catalog, SourceId, Current, Part, Failure) = False Then
            Exit Function
        End If
        If Part.Kind = 46 Then
            BodyId = Current
            Declaration.BodySyntaxId = Current
        End If
        If Part.Kind = 58 Then
            Dim EndWord As SyntaxNode
            If TryReadCatalogSyntax(Catalog, SourceId, Part.FirstChild, EndWord, Failure) = False Then
                Exit Function
            End If
            Dim EndMatches As Boolean = False
            Dim Expected As String = "sub"
            If Declaration.Kind = 6 Then
                Expected = "function"
            End If
            If TrySemanticWord(Catalog, SourceId, EndWord, Expected, EndMatches, Failure) = False Then
                Exit Function
            End If
            If EndMatches = False Then
                Call RecordSemanticDiagnostic(Diagnostic, 1420, SourceId, Part.FirstByte, Part.LastByte, -1, 0, 0)
            End If
        End If
        Current = Part.NextSibling
    Wend
    If TryAppendSemanticDeclaration(Catalog, Declaration, ProcedureId, Failure) = False Then
        Exit Function
    End If
    Current = Header.NextSibling
    While Current >= 0
        Call ResetSemanticFailure(Failure)
        If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
            Exit Function
        End If
        Dim Metadata As SyntaxNode
        If TryReadCatalogSyntax(Catalog, SourceId, Current, Metadata, Failure) = False Then
            Exit Function
        End If
        If Metadata.Kind = 52 Then
            If TryRecordSemanticAttribute(Catalog, SourceId, Current, ProcedureId, Failure) = False Then
                Exit Function
            End If
        End If
        Current = Metadata.NextSibling
    Wend
    If ParametersId >= 0 Then
        Dim Parameters As SyntaxNode
        If TryReadCatalogSyntax(Catalog, SourceId, ParametersId, Parameters, Failure) = False Then
            Exit Function
        End If
        Current = Parameters.FirstChild
        Dim OptionalSeen As Boolean = False
        While Current >= 0
            Call ResetSemanticFailure(Failure)
            If TryContinueSemanticPreparation(Cancellation, Failure) = False Then
                Exit Function
            End If
            Dim ParameterId As Long = -1
            If TryCollectSemanticStorage(Catalog, Cancellation, SourceId, Current, ProcedureId, 4, 2, ParameterId, Diagnostic, Failure) = False Then
                Exit Function
            End If
            Dim Parameter As SemanticDeclaration
            Call ResetSemanticFailure(Failure)
            Call ReadSemanticDeclaration(Parameter, Catalog.Declarations(ParameterId))
            Parameter.Ordinal = Declaration.ParameterCount
            If Declaration.FirstParameter < 0 Then
                Declaration.FirstParameter = ParameterId
            End If
            Declaration.ParameterCount = Declaration.ParameterCount + 1
            If (Parameter.Flags And 8) <> 0 Then
                OptionalSeen = True
                If Parameter.InitializerSyntaxId < 0 Then
                    Dim ParameterName As SemanticName
                    Call ReadSemanticName(ParameterName, Catalog.Names(Parameter.NameId))
                    Call RecordSemanticDiagnostic(Diagnostic, 1419, SourceId, ParameterName.FirstByte, ParameterName.LastByte, -1, 0, 0)
                End If
            Else
                If OptionalSeen Or Parameter.InitializerSyntaxId >= 0 Then
                    Dim BadName As SemanticName
                    Call ReadSemanticName(BadName, Catalog.Names(Parameter.NameId))
                    Call RecordSemanticDiagnostic(Diagnostic, 1419, SourceId, BadName.FirstByte, BadName.LastByte, -1, 0, 0)
                End If
            End If
            Call WriteSemanticDeclaration(Catalog.Declarations(ParameterId), Parameter)
            Dim ParameterSyntax As SyntaxNode
            If TryReadCatalogSyntax(Catalog, SourceId, Current, ParameterSyntax, Failure) = False Then
                Exit Function
            End If
            Current = ParameterSyntax.NextSibling
        Wend
    End If
    Call ResetSemanticFailure(Failure)
    Call WriteSemanticDeclaration(Catalog.Declarations(ProcedureId), Declaration)
    Call ResetSemanticFailure(Failure)
    TryCollectSemanticProcedure = True
End Function
