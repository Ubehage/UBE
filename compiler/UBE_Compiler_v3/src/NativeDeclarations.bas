UBE SOURCE 1 MODULE
Attribute UBE_Name = "NativeDeclarations"

' A private target-identity index, not another declaration graph. The caller
' retains the immutable checked catalog. One ordered declaration scan records
' selected ABI representations and assigns target identities. Member links are
' declaration index+1, preserving catalog order without per-procedure rescans.
' Each 72-byte row is scalar. The 24-byte owner is never copied. Status is
' 0 unused, 1 ready, 4 failed; partial ownership remains explicitly disposable.
Type NativeDeclarationTarget
    Kind As Long
    SourceId As Long
    Scope As Long
    TypeId As Long
    Representation As Long
    Flags As Long
    Role As Long
    FirstParameter As Long
    ParameterCount As Long
    FirstMember As Long
    LastMember As Long
    NextMember As Long
    FrameIndex As Long
    ByRefIndex As Long
    ValueIdentity As LongLong
    AddressIdentity As LongLong
End Type
Type NativeDeclarationPlan
    Targets() As NativeDeclarationTarget
    Count As Long
    Status As Long
    FrameCount As Long
    ByRefCount As Long
End Type
Private Intrinsic Function NativeDeclarationsLength(ByRef Values() As SemanticDeclaration) As Long
Attribute NativeDeclarationsLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function NativeTypesLength(ByRef Values() As SemanticType) As Long
Attribute NativeTypesLength.UBE_Primitive = "Array.Length"
End Function
Private Intrinsic Function TryResizeNativeTargets(ByRef Values() As NativeDeclarationTarget, ByVal Count As Long, ByVal Keep As Boolean) As Boolean
Attribute TryResizeNativeTargets.UBE_Primitive = "Array.TryResize"
End Function
Sub ReadNativeDeclarationTarget(ByRef Destination As NativeDeclarationTarget, ByRef Original As NativeDeclarationTarget)
    Destination = Original
End Sub
Private Sub WriteNativeDeclarationTarget(ByRef Destination As NativeDeclarationTarget, ByRef Original As NativeDeclarationTarget)
    Destination = Original
End Sub

Function TryPrepareNativeDeclarations(ByRef Plan As NativeDeclarationPlan, ByRef Declarations() As SemanticDeclaration, ByVal DeclarationCount As Long, ByRef Types() As SemanticType, ByVal TypeCount As Long, ByVal SourceCount As Long, ByRef Writer As NativeLLVMWriter) As Boolean
    TryPrepareNativeDeclarations = False
    Call ResetNativeFailure(Writer.Failure)
    If Plan.Status <> 0 Or Plan.Count <> 0 Or Plan.FrameCount <> 0 Or Plan.ByRefCount <> 0 Or SourceCount < 1 Or DeclarationCount < SourceCount Or TypeCount < 6 Then
        Exit Function
    End If
    If DeclarationCount > NativeDeclarationsLength(Declarations) Or TypeCount > NativeTypesLength(Types) Then
        Exit Function
    End If
    Plan.Status = 4
    Dim Bytes As LongLong = DeclarationCount
    Bytes = Bytes * 72
    If TryChargeNativeResource(Writer.Limits, Writer.Usage, 1, Bytes, Writer.Failure) = False Then
        Exit Function
    End If
    Dim Allocated As Boolean = False
    Call ResetNativeFailure(Writer.Failure)
    If TryContinueNativeOutput(Writer.Cancellation, Writer.Failure) Then
        Call ResetNativeFailure(Writer.Failure)
        Allocated = TryResizeNativeTargets(Plan.Targets, DeclarationCount, False)
        If Allocated = False Then
            Writer.Failure.Code = 1502
            Writer.Failure.Resource = 1
        End If
    End If
    If Allocated = False Then
        Dim Cleanup As NativeFailure
        Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
        Exit Function
    End If
    Plan.Count = DeclarationCount
    Call ResetNativeFailure(Writer.Failure)
    If TryContinueNativeOutput(Writer.Cancellation, Writer.Failure) = False Then
        Exit Function
    End If
    Dim Id As Long = 0
    While Id < DeclarationCount
        Call ResetNativeFailure(Writer.Failure)
        If TryVisitNativeIndex(Writer.Limits, Writer.Usage, Writer.Cancellation, Writer.Failure) = False Then
            Exit Function
        End If
        Call ResetNativeFailure(Writer.Failure)
        Dim Declaration As SemanticDeclaration
        Call ReadSemanticDeclaration(Declaration, Declarations(Id))
        If Declaration.Kind < 1 Or Declaration.Kind > 7 Or Declaration.SourceId < 0 Or Declaration.SourceId >= SourceCount Then
            Exit Function
        End If
        If Declaration.TypeId < 0 Or Declaration.TypeId >= TypeCount Then
            Exit Function
        End If
        Dim Target As NativeDeclarationTarget
        Target.Kind = Declaration.Kind
        Target.SourceId = Declaration.SourceId
        Target.Scope = Declaration.Scope
        Target.TypeId = Declaration.TypeId
        Target.Representation = Declaration.TypeId
        Target.Flags = Declaration.Flags
        Target.Role = Declaration.Auxiliary
        Target.FirstParameter = Declaration.FirstParameter
        Target.ParameterCount = Declaration.ParameterCount
        Target.ValueIdentity = -1
        Target.AddressIdentity = -1
        Target.FrameIndex = -1
        Target.ByRefIndex = -1
        If Target.TypeId >= 6 Then
            If Types(Target.TypeId).Kind <> 3 Then
                Exit Function
            End If
            Target.Representation = Types(Target.TypeId).Representation
            If Target.Representation < 2 Or Target.Representation > 4 Then
                Exit Function
            End If
        End If
        If Id < SourceCount Then
            If Target.Kind <> 1 Or Target.SourceId <> Id Or Target.Scope <> -1 Or Target.TypeId <> 0 Then
                Exit Function
            End If
        Else
            If Target.Kind = 1 Or Target.Scope < 0 Or Target.Scope >= Id Then
                Exit Function
            End If
            Dim Parent As NativeDeclarationTarget
            Call ReadNativeDeclarationTarget(Parent, Plan.Targets(Target.Scope))
            If Parent.Kind <> 1 And Parent.Kind <> 5 And Parent.Kind <> 6 Then
                Exit Function
            End If
            If Parent.SourceId <> Target.SourceId Then
                Exit Function
            End If
            If Target.Kind = 2 Then
                If TryLLVMIdentity(Writer, Target.AddressIdentity) = False Then
                    Exit Function
                End If
            End If
            If Target.Kind = 5 Or Target.Kind = 6 Then
                If Parent.Kind <> 1 Or Target.ParameterCount < 0 Then
                    Exit Function
                End If
                If Target.ParameterCount > 0 Then
                    If Target.FirstParameter <= Id Or Target.FirstParameter > DeclarationCount - Target.ParameterCount Then
                        Exit Function
                    End If
                End If
                If Target.Role = 0 Then
                    Target.FrameIndex = Plan.FrameCount
                    Plan.FrameCount = Plan.FrameCount + 1
                    If TryLLVMIdentity(Writer, Target.ValueIdentity) = False Then
                        Exit Function
                    End If
                    If Target.Kind = 6 Then
                        If TryLLVMIdentity(Writer, Target.AddressIdentity) = False Then
                            Exit Function
                        End If
                    End If
                Else
                    If Target.Kind <> 6 Or (Target.Role <> 1 And Target.Role <> 2) Then
                        Exit Function
                    End If
                End If
            End If
            If Target.Kind = 4 Then
                If (Parent.Kind <> 5 And Parent.Kind <> 6) Or Id < Parent.FirstParameter Or Id - Parent.FirstParameter >= Parent.ParameterCount Then
                    Exit Function
                End If
                If Declaration.Ordinal <> Id - Parent.FirstParameter Then
                    Exit Function
                End If
                If (Target.Flags And 4) = 0 Then
                    Target.ByRefIndex = Plan.ByRefCount
                    Plan.ByRefCount = Plan.ByRefCount + 1
                End If
                If Parent.Role = 0 Then
                    If TryLLVMIdentity(Writer, Target.ValueIdentity) = False Then
                        Exit Function
                    End If
                    Target.AddressIdentity = Target.ValueIdentity
                    If (Target.Flags And 4) <> 0 Then
                        If TryLLVMIdentity(Writer, Target.AddressIdentity) = False Then
                            Exit Function
                        End If
                    Else
                        ' The private owner-module argument immediately follows
                        ' the incoming pointer identity. No target field is needed.
                        Dim OwnerIdentity As LongLong = 0
                        If TryLLVMIdentity(Writer, OwnerIdentity) = False Then
                            Exit Function
                        End If
                    End If
                End If
            End If
            If Parent.LastMember > 0 Then
                Plan.Targets(Parent.LastMember - 1).NextMember = Id + 1
            Else
                Parent.FirstMember = Id + 1
            End If
            Parent.LastMember = Id + 1
            Call WriteNativeDeclarationTarget(Plan.Targets(Target.Scope), Parent)
        End If
        Call WriteNativeDeclarationTarget(Plan.Targets(Id), Target)
        Id = Id + 1
    Wend
    Plan.Status = 1
    Writer.Failure.Code = 0
    Writer.Failure.Resource = 0
    TryPrepareNativeDeclarations = True
End Function

Function TryDisposeNativeDeclarations(ByRef Plan As NativeDeclarationPlan, ByRef Writer As NativeLLVMWriter) As Boolean
    TryDisposeNativeDeclarations = False
    Call ResetNativeFailure(Writer.Failure)
    If TryResizeNativeTargets(Plan.Targets, 0, False) = False Then
        Exit Function
    End If
    Dim Bytes As LongLong = Plan.Count
    Bytes = Bytes * 72
    Dim Cleanup As NativeFailure
    Call TryReleaseNativeResource(Writer.Usage, 1, Bytes, Cleanup)
    Plan.Count = 0
    Plan.Status = 0
    Plan.FrameCount = 0
    Plan.ByRefCount = 0
    Writer.Failure.Code = 0
    Writer.Failure.Resource = 0
    TryDisposeNativeDeclarations = True
End Function
