UBE SOURCE 1 MODULE
Attribute UBE_Name = "LLVMTemplates"
' Generated from compiler/llvm/templates.json by bootstrap/tools/llvm-templates.ps1.
Public Const Branch As Long = 1
Public Const ConditionalBranch As Long = 2
Public Const Label As Long = 3
Public Const IntegerValue As Long = 4
Public Const LoadValue As Long = 5
Public Const StoreValue As Long = 6
Public Const ContextType As Long = 7
Public Const ProcedureStart As Long = 8
Public Const ValueParameter As Long = 9
Public Const ReferenceParameter As Long = 10
Public Const ProcedureBody As Long = 11
Public Const FunctionEnd As Long = 12
Public Const ContextFileType As Long = 13
Public Const ContextPrefix As Long = 14
Public Const ContextArrayRelease As Long = 15
Public Const ContextMiddle As Long = 16
Public Const EnsureModule As Long = 17
Public Const ContextSuffix As Long = 18
Public Const Entry As Long = 19
Public Const StoreError As Long = 20
Public Const FailureBranch As Long = 21
Public Const CallSuccess As Long = 22
Public Const CallSuccessBranch As Long = 23
Public Const ValueNonzero As Long = 24
Public Const BooleanSelect As Long = 25
Public Const TruncateValue As Long = 26
Public Const SignExtendValue As Long = 27
Public Const ZeroExtendValue As Long = 28
Public Const DifferentValues As Long = 29
Public Const ComplementValue As Long = 30
Public Const OverflowFlag As Long = 31
Public Const ArithmeticValue As Long = 32
Public Const ArithmeticAdd16 As Long = 33
Public Const ArithmeticSubtract16 As Long = 34
Public Const ArithmeticAdd32 As Long = 35
Public Const ArithmeticSubtract32 As Long = 36
Public Const ArithmeticAdd64 As Long = 37
Public Const ArithmeticSubtract64 As Long = 38
Public Const IntrinsicFileOpen As Long = 39
Public Const IntrinsicFileCreateNew As Long = 40
Public Const IntrinsicFileRead As Long = 41
Public Const IntrinsicFileWrite As Long = 42
Public Const IntrinsicFileClose As Long = 43
Public Const IntrinsicFileFlush As Long = 44
Public Const IntrinsicErrorSet As Long = 45
Public Const IntrinsicArrayLength As Long = 46
Public Const IntrinsicMemoryCopyBytes As Long = 47
Public Const IntrinsicArrayResize As Long = 48
Public Const IntrinsicArrayCopy As Long = 49
Public Const ContextAddress As Long = 50
Public Const ArgumentAddress As Long = 51
Public Const SlotAddress As Long = 52
Public Const TemporaryAddress As Long = 53
Public Const CellAddress As Long = 54
Public Const IndexedAddress As Long = 55
Public Const LoadPointer As Long = 56
Public Const StorePointer As Long = 57
Public Const StoreNullPointer As Long = 58
Public Const RetainBlock As Long = 59
Public Const PinBlock As Long = 60
Public Const ReleasePin As Long = 61
Public Const CollectMemory As Long = 62
Public Const ClearArray As Long = 63
Public Const BelowBound As Long = 64
Public Const AboveBound As Long = 65
Public Const EitherCondition As Long = 66
Public Const RelativeIndex As Long = 67
Public Const ElementOffset As Long = 68
Public Const LoadVolatileValue As Long = 69
Public Const StoreVolatileValue As Long = 70
Public Const StoreConstant As Long = 71
Public Const StoreVolatileConstant As Long = 72
Public Const EnsureModuleValue As Long = 73
Public Const ControlSite As Long = 74
Public Const ControlHandler As Long = 75
Public Const ControlZero As Long = 76
Public Const ControlArrayCopy As Long = 77
Public Const CompareEqual As Long = 78
Public Const CompareLessEqual As Long = 79
Public Const CompareGreaterEqual As Long = 80
Public Const BooleanAnd As Long = 81
Public Const BooleanInvert As Long = 82
Public Const IntegerAnd As Long = 83
Public Const IntegerOr As Long = 84
Public Const StoreErrorValue As Long = 85
Public Const ReturnFailureBranch As Long = 86
Public Const LoadError As Long = 87
Public Const CallStart As Long = 88
Public Const CallValueArgument As Long = 89
Public Const CallReferenceArgument As Long = 90
Public Const CallEnd As Long = 91
Public Const CallValue As Long = 92
Public Const ProcedurePointers As Long = 93
Public Const ModuleInitializeStart As Long = 94
Public Const FrameControls As Long = 95
Public Const AllocateSlot As Long = 96
Public Const StoreParameter As Long = 97
Public Const AllocateTemporary As Long = 98
Public Const AllocatePin As Long = 99
Public Const ProcedureDepth As Long = 100
Public Const FailureDispatchLabel As Long = 101
Public Const FailureHandlerDispatch As Long = 102
Public Const SwitchCase As Long = 103
Public Const SwitchEnd As Long = 104
Public Const FailureSkipDispatch As Long = 105
Public Const ReturnFailureLabel As Long = 106
Public Const ReturnDepthSuccess As Long = 107
Public Const ReturnDepthFailure As Long = 108
Public Const LoadResult As Long = 109
Public Const ReturnSuccessValue As Long = 110
Public Const ReturnFailedValue As Long = 111
Public Const ModuleEnsureDefinition As Long = 112
Public Const SourceLocation As Long = 113
Public Const TargetHeader As Long = 114
Public Const TemplateCount As Long = 114
Public Const CatalogLength As Long = 15641
Public Const CatalogByteSum As Long = 1247404

' Returns one exact span without changing caller outputs for an unknown identity.
Public Function TrySpan(ByVal Id As Long, ByRef Start As Long, ByRef Count As Long) As Boolean
    If Id = 1 Then Start = 0: Count = 16: TrySpan = True: Exit Function
    If Id = 2 Then Start = 16: Count = 39: TrySpan = True: Exit Function
    If Id = 3 Then Start = 55: Count = 5: TrySpan = True: Exit Function
    If Id = 4 Then Start = 60: Count = 24: TrySpan = True: Exit Function
    If Id = 5 Then Start = 84: Count = 29: TrySpan = True: Exit Function
    If Id = 6 Then Start = 113: Count = 28: TrySpan = True: Exit Function
    If Id = 7 Then Start = 141: Count = 91: TrySpan = True: Exit Function
    If Id = 8 Then Start = 232: Count = 41: TrySpan = True: Exit Function
    If Id = 9 Then Start = 273: Count = 14: TrySpan = True: Exit Function
    If Id = 10 Then Start = 287: Count = 14: TrySpan = True: Exit Function
    If Id = 11 Then Start = 301: Count = 3: TrySpan = True: Exit Function
    If Id = 12 Then Start = 304: Count = 1: TrySpan = True: Exit Function
    If Id = 13 Then Start = 305: Count = 44: TrySpan = True: Exit Function
    If Id = 14 Then Start = 349: Count = 1330: TrySpan = True: Exit Function
    If Id = 15 Then Start = 1679: Count = 122: TrySpan = True: Exit Function
    If Id = 16 Then Start = 1801: Count = 260: TrySpan = True: Exit Function
    If Id = 17 Then Start = 2061: Count = 58: TrySpan = True: Exit Function
    If Id = 18 Then Start = 2119: Count = 20: TrySpan = True: Exit Function
    If Id = 19 Then Start = 2139: Count = 896: TrySpan = True: Exit Function
    If Id = 20 Then Start = 3035: Count = 25: TrySpan = True: Exit Function
    If Id = 21 Then Start = 3060: Count = 28: TrySpan = True: Exit Function
    If Id = 22 Then Start = 3088: Count = 43: TrySpan = True: Exit Function
    If Id = 23 Then Start = 3131: Count = 51: TrySpan = True: Exit Function
    If Id = 24 Then Start = 3182: Count = 30: TrySpan = True: Exit Function
    If Id = 25 Then Start = 3212: Count = 40: TrySpan = True: Exit Function
    If Id = 26 Then Start = 3252: Count = 33: TrySpan = True: Exit Function
    If Id = 27 Then Start = 3285: Count = 32: TrySpan = True: Exit Function
    If Id = 28 Then Start = 3317: Count = 32: TrySpan = True: Exit Function
    If Id = 29 Then Start = 3349: Count = 34: TrySpan = True: Exit Function
    If Id = 30 Then Start = 3383: Count = 28: TrySpan = True: Exit Function
    If Id = 31 Then Start = 3411: Count = 44: TrySpan = True: Exit Function
    If Id = 32 Then Start = 3455: Count = 44: TrySpan = True: Exit Function
    If Id = 33 Then Start = 3499: Count = 77: TrySpan = True: Exit Function
    If Id = 34 Then Start = 3576: Count = 77: TrySpan = True: Exit Function
    If Id = 35 Then Start = 3653: Count = 77: TrySpan = True: Exit Function
    If Id = 36 Then Start = 3730: Count = 77: TrySpan = True: Exit Function
    If Id = 37 Then Start = 3807: Count = 77: TrySpan = True: Exit Function
    If Id = 38 Then Start = 3884: Count = 77: TrySpan = True: Exit Function
    If Id = 39 Then Start = 3961: Count = 380: TrySpan = True: Exit Function
    If Id = 40 Then Start = 4341: Count = 393: TrySpan = True: Exit Function
    If Id = 41 Then Start = 4734: Count = 408: TrySpan = True: Exit Function
    If Id = 42 Then Start = 5142: Count = 407: TrySpan = True: Exit Function
    If Id = 43 Then Start = 5549: Count = 299: TrySpan = True: Exit Function
    If Id = 44 Then Start = 5848: Count = 299: TrySpan = True: Exit Function
    If Id = 45 Then Start = 6147: Count = 289: TrySpan = True: Exit Function
    If Id = 46 Then Start = 6436: Count = 435: TrySpan = True: Exit Function
    If Id = 47 Then Start = 6871: Count = 3792: TrySpan = True: Exit Function
    If Id = 48 Then Start = 10663: Count = 337: TrySpan = True: Exit Function
    If Id = 49 Then Start = 11000: Count = 311: TrySpan = True: Exit Function
    If Id = 50 Then Start = 11311: Count = 69: TrySpan = True: Exit Function
    If Id = 51 Then Start = 11380: Count = 48: TrySpan = True: Exit Function
    If Id = 52 Then Start = 11428: Count = 49: TrySpan = True: Exit Function
    If Id = 53 Then Start = 11477: Count = 49: TrySpan = True: Exit Function
    If Id = 54 Then Start = 11526: Count = 47: TrySpan = True: Exit Function
    If Id = 55 Then Start = 11573: Count = 49: TrySpan = True: Exit Function
    If Id = 56 Then Start = 11622: Count = 29: TrySpan = True: Exit Function
    If Id = 57 Then Start = 11651: Count = 28: TrySpan = True: Exit Function
    If Id = 58 Then Start = 11679: Count = 27: TrySpan = True: Exit Function
    If Id = 59 Then Start = 11706: Count = 40: TrySpan = True: Exit Function
    If Id = 60 Then Start = 11746: Count = 31: TrySpan = True: Exit Function
    If Id = 61 Then Start = 11777: Count = 104: TrySpan = True: Exit Function
    If Id = 62 Then Start = 11881: Count = 47: TrySpan = True: Exit Function
    If Id = 63 Then Start = 11928: Count = 39: TrySpan = True: Exit Function
    If Id = 64 Then Start = 11967: Count = 35: TrySpan = True: Exit Function
    If Id = 65 Then Start = 12002: Count = 35: TrySpan = True: Exit Function
    If Id = 66 Then Start = 12037: Count = 28: TrySpan = True: Exit Function
    If Id = 67 Then Start = 12065: Count = 30: TrySpan = True: Exit Function
    If Id = 68 Then Start = 12095: Count = 28: TrySpan = True: Exit Function
    If Id = 69 Then Start = 12123: Count = 38: TrySpan = True: Exit Function
    If Id = 70 Then Start = 12161: Count = 37: TrySpan = True: Exit Function
    If Id = 71 Then Start = 12198: Count = 26: TrySpan = True: Exit Function
    If Id = 72 Then Start = 12224: Count = 35: TrySpan = True: Exit Function
    If Id = 73 Then Start = 12259: Count = 50: TrySpan = True: Exit Function
    If Id = 74 Then Start = 12309: Count = 34: TrySpan = True: Exit Function
    If Id = 75 Then Start = 12343: Count = 36: TrySpan = True: Exit Function
    If Id = 76 Then Start = 12379: Count = 30: TrySpan = True: Exit Function
    If Id = 77 Then Start = 12409: Count = 77: TrySpan = True: Exit Function
    If Id = 78 Then Start = 12486: Count = 34: TrySpan = True: Exit Function
    If Id = 79 Then Start = 12520: Count = 35: TrySpan = True: Exit Function
    If Id = 80 Then Start = 12555: Count = 35: TrySpan = True: Exit Function
    If Id = 81 Then Start = 12590: Count = 29: TrySpan = True: Exit Function
    If Id = 82 Then Start = 12619: Count = 28: TrySpan = True: Exit Function
    If Id = 83 Then Start = 12647: Count = 30: TrySpan = True: Exit Function
    If Id = 84 Then Start = 12677: Count = 29: TrySpan = True: Exit Function
    If Id = 85 Then Start = 12706: Count = 27: TrySpan = True: Exit Function
    If Id = 86 Then Start = 12733: Count = 23: TrySpan = True: Exit Function
    If Id = 87 Then Start = 12756: Count = 28: TrySpan = True: Exit Function
    If Id = 88 Then Start = 12784: Count = 49: TrySpan = True: Exit Function
    If Id = 89 Then Start = 12833: Count = 11: TrySpan = True: Exit Function
    If Id = 90 Then Start = 12844: Count = 11: TrySpan = True: Exit Function
    If Id = 91 Then Start = 12855: Count = 1: TrySpan = True: Exit Function
    If Id = 92 Then Start = 12856: Count = 43: TrySpan = True: Exit Function
    If Id = 93 Then Start = 12899: Count = 134: TrySpan = True: Exit Function
    If Id = 94 Then Start = 13033: Count = 135: TrySpan = True: Exit Function
    If Id = 95 Then Start = 13168: Count = 304: TrySpan = True: Exit Function
    If Id = 96 Then Start = 13472: Count = 41: TrySpan = True: Exit Function
    If Id = 97 Then Start = 13513: Count = 35: TrySpan = True: Exit Function
    If Id = 98 Then Start = 13548: Count = 33: TrySpan = True: Exit Function
    If Id = 99 Then Start = 13581: Count = 64: TrySpan = True: Exit Function
    If Id = 100 Then Start = 13645: Count = 347: TrySpan = True: Exit Function
    If Id = 101 Then Start = 13992: Count = 17: TrySpan = True: Exit Function
    If Id = 102 Then Start = 14009: Count = 555: TrySpan = True: Exit Function
    If Id = 103 Then Start = 14564: Count = 24: TrySpan = True: Exit Function
    If Id = 104 Then Start = 14588: Count = 3: TrySpan = True: Exit Function
    If Id = 105 Then Start = 14591: Count = 64: TrySpan = True: Exit Function
    If Id = 106 Then Start = 14655: Count = 12: TrySpan = True: Exit Function
    If Id = 107 Then Start = 14667: Count = 139: TrySpan = True: Exit Function
    If Id = 108 Then Start = 14806: Count = 147: TrySpan = True: Exit Function
    If Id = 109 Then Start = 14953: Count = 33: TrySpan = True: Exit Function
    If Id = 110 Then Start = 14986: Count = 91: TrySpan = True: Exit Function
    If Id = 111 Then Start = 15077: Count = 37: TrySpan = True: Exit Function
    If Id = 112 Then Start = 15114: Count = 443: TrySpan = True: Exit Function
    If Id = 113 Then Start = 15557: Count = 44: TrySpan = True: Exit Function
    If Id = 114 Then Start = 15601: Count = 40: TrySpan = True: Exit Function
End Function
