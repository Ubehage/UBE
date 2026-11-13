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
Public Const IntrinsicSystemCommandLine As Long = 115
Public Const IntrinsicSystemWrite As Long = 116
Public Const IntrinsicFileFinalPath As Long = 117
Public Const IntrinsicPathFullPath As Long = 118
Public Const IntrinsicPathCompareOrdinal As Long = 119
Public Const IntrinsicProcessStart As Long = 120
Public Const IntrinsicProcessWait As Long = 121
Public Const IntrinsicProcessTerminate As Long = 122
Public Const IntrinsicProcessClose As Long = 123
Public Const IntrinsicFileOpenDirectory As Long = 124
Public Const IntrinsicFileIdentity As Long = 125
Public Const IntrinsicFileLength As Long = 126
Public Const IntrinsicSystemExecutablePath As Long = 127
Public Const IntrinsicSystemMonotonicMilliseconds As Long = 128
Public Const IntrinsicDirectoryCreate As Long = 129
Public Const IntrinsicDirectoryRemove As Long = 130
Public Const IntrinsicFileDelete As Long = 131
Public Const IntrinsicFileReplace As Long = 132
Public Const IntrinsicPathKind As Long = 133
Public Const ArraySnapshot As Long = 134
Public Const SnapshotValue As Long = 135
Public Const AllocateAggregateTemporary As Long = 136
Public Const IntrinsicThreadCurrentId As Long = 137
Public Const IntrinsicThreadIsAlive As Long = 138
Public Const IntrinsicThreadWait As Long = 139
Public Const IntrinsicThreadRequestStop As Long = 140
Public Const IntrinsicThreadStopRequested As Long = 141
Public Const IntrinsicThreadYield As Long = 142
Public Const NullOwner As Long = 143
Public Const LoadLocalOwner As Long = 144
Public Const IncomingOwner As Long = 145
Public Const LoadTemporaryOwner As Long = 146
Public Const LoadPinOwner As Long = 147
Public Const NewOwner As Long = 148
Public Const OwnerAllocated As Long = 149
Public Const SetTemporaryOwner As Long = 150
Public Const OwnerPayload As Long = 151
Public Const DropOwner As Long = 152
Public Const ClearTemporaryOwner As Long = 153
Public Const AllocateLocalOwner As Long = 154
Public Const AllocateTemporaryOwner As Long = 155
Public Const SetLocalOwner As Long = 156
Public Const OwnerParameter As Long = 157
Public Const OwnerEntryGuard As Long = 158
Public Const BoxAddress As Long = 159
Public Const BoxTemporaryAddress As Long = 160
Public Const InstallOwnedArray As Long = 161
Public Const StoreBoxParameter As Long = 162
Public Const RetainOwner As Long = 163
Public Const StartThread As Long = 164
Public Const ThreadThunkStart As Long = 165
Public Const CaptureAddress As Long = 166
Public Const LoadOwnerPointer As Long = 167
Public Const BooleanConstant As Long = 168
Public Const ThreadThunkEnd As Long = 169
Public Const NewArrayOwner As Long = 170
Public Const ArithmeticMultiply16 As Long = 171
Public Const ArithmeticMultiply32 As Long = 172
Public Const ArithmeticMultiply64 As Long = 173
Public Const BothConditions As Long = 174
Public Const SafeRemainderDivisor As Long = 175
Public Const DivisionValue As Long = 176
Public Const RemainderValue As Long = 177
Public Const TemplateCount As Long = 177
Public Const CatalogLength As Long = 24032
Public Const CatalogByteSum As Long = 1886443

' Returns one exact span without changing caller outputs for an unknown identity.
Public Function TrySpan(ByVal Id As Long, ByRef Start As Long, ByRef Count As Long) As Boolean
    If Id = 1 Then Start = 0: Count = 16: TrySpan = True: Exit Function
    If Id = 2 Then Start = 16: Count = 39: TrySpan = True: Exit Function
    If Id = 3 Then Start = 55: Count = 5: TrySpan = True: Exit Function
    If Id = 4 Then Start = 60: Count = 24: TrySpan = True: Exit Function
    If Id = 5 Then Start = 84: Count = 55: TrySpan = True: Exit Function
    If Id = 6 Then Start = 139: Count = 54: TrySpan = True: Exit Function
    If Id = 7 Then Start = 193: Count = 247: TrySpan = True: Exit Function
    If Id = 8 Then Start = 440: Count = 41: TrySpan = True: Exit Function
    If Id = 9 Then Start = 481: Count = 14: TrySpan = True: Exit Function
    If Id = 10 Then Start = 495: Count = 14: TrySpan = True: Exit Function
    If Id = 11 Then Start = 509: Count = 3: TrySpan = True: Exit Function
    If Id = 12 Then Start = 512: Count = 1: TrySpan = True: Exit Function
    If Id = 13 Then Start = 513: Count = 48: TrySpan = True: Exit Function
    If Id = 14 Then Start = 561: Count = 2270: TrySpan = True: Exit Function
    If Id = 15 Then Start = 2831: Count = 121: TrySpan = True: Exit Function
    If Id = 16 Then Start = 2952: Count = 245: TrySpan = True: Exit Function
    If Id = 17 Then Start = 3197: Count = 58: TrySpan = True: Exit Function
    If Id = 18 Then Start = 3255: Count = 20: TrySpan = True: Exit Function
    If Id = 19 Then Start = 3275: Count = 1198: TrySpan = True: Exit Function
    If Id = 20 Then Start = 4473: Count = 51: TrySpan = True: Exit Function
    If Id = 21 Then Start = 4524: Count = 28: TrySpan = True: Exit Function
    If Id = 22 Then Start = 4552: Count = 43: TrySpan = True: Exit Function
    If Id = 23 Then Start = 4595: Count = 51: TrySpan = True: Exit Function
    If Id = 24 Then Start = 4646: Count = 30: TrySpan = True: Exit Function
    If Id = 25 Then Start = 4676: Count = 40: TrySpan = True: Exit Function
    If Id = 26 Then Start = 4716: Count = 33: TrySpan = True: Exit Function
    If Id = 27 Then Start = 4749: Count = 32: TrySpan = True: Exit Function
    If Id = 28 Then Start = 4781: Count = 32: TrySpan = True: Exit Function
    If Id = 29 Then Start = 4813: Count = 34: TrySpan = True: Exit Function
    If Id = 30 Then Start = 4847: Count = 28: TrySpan = True: Exit Function
    If Id = 31 Then Start = 4875: Count = 44: TrySpan = True: Exit Function
    If Id = 32 Then Start = 4919: Count = 44: TrySpan = True: Exit Function
    If Id = 33 Then Start = 4963: Count = 77: TrySpan = True: Exit Function
    If Id = 34 Then Start = 5040: Count = 77: TrySpan = True: Exit Function
    If Id = 35 Then Start = 5117: Count = 77: TrySpan = True: Exit Function
    If Id = 36 Then Start = 5194: Count = 77: TrySpan = True: Exit Function
    If Id = 37 Then Start = 5271: Count = 77: TrySpan = True: Exit Function
    If Id = 38 Then Start = 5348: Count = 77: TrySpan = True: Exit Function
    If Id = 39 Then Start = 5425: Count = 380: TrySpan = True: Exit Function
    If Id = 40 Then Start = 5805: Count = 393: TrySpan = True: Exit Function
    If Id = 41 Then Start = 6198: Count = 408: TrySpan = True: Exit Function
    If Id = 42 Then Start = 6606: Count = 407: TrySpan = True: Exit Function
    If Id = 43 Then Start = 7013: Count = 299: TrySpan = True: Exit Function
    If Id = 44 Then Start = 7312: Count = 299: TrySpan = True: Exit Function
    If Id = 45 Then Start = 7611: Count = 314: TrySpan = True: Exit Function
    If Id = 46 Then Start = 7925: Count = 228: TrySpan = True: Exit Function
    If Id = 47 Then Start = 8153: Count = 266: TrySpan = True: Exit Function
    If Id = 48 Then Start = 8419: Count = 337: TrySpan = True: Exit Function
    If Id = 49 Then Start = 8756: Count = 311: TrySpan = True: Exit Function
    If Id = 50 Then Start = 9067: Count = 58: TrySpan = True: Exit Function
    If Id = 51 Then Start = 9125: Count = 48: TrySpan = True: Exit Function
    If Id = 52 Then Start = 9173: Count = 49: TrySpan = True: Exit Function
    If Id = 53 Then Start = 9222: Count = 49: TrySpan = True: Exit Function
    If Id = 54 Then Start = 9271: Count = 47: TrySpan = True: Exit Function
    If Id = 55 Then Start = 9318: Count = 49: TrySpan = True: Exit Function
    If Id = 56 Then Start = 9367: Count = 29: TrySpan = True: Exit Function
    If Id = 57 Then Start = 9396: Count = 28: TrySpan = True: Exit Function
    If Id = 58 Then Start = 9424: Count = 27: TrySpan = True: Exit Function
    If Id = 59 Then Start = 9451: Count = 40: TrySpan = True: Exit Function
    If Id = 60 Then Start = 9491: Count = 31: TrySpan = True: Exit Function
    If Id = 61 Then Start = 9522: Count = 114: TrySpan = True: Exit Function
    If Id = 62 Then Start = 9636: Count = 47: TrySpan = True: Exit Function
    If Id = 63 Then Start = 9683: Count = 49: TrySpan = True: Exit Function
    If Id = 64 Then Start = 9732: Count = 35: TrySpan = True: Exit Function
    If Id = 65 Then Start = 9767: Count = 35: TrySpan = True: Exit Function
    If Id = 66 Then Start = 9802: Count = 28: TrySpan = True: Exit Function
    If Id = 67 Then Start = 9830: Count = 30: TrySpan = True: Exit Function
    If Id = 68 Then Start = 9860: Count = 28: TrySpan = True: Exit Function
    If Id = 69 Then Start = 9888: Count = 64: TrySpan = True: Exit Function
    If Id = 70 Then Start = 9952: Count = 63: TrySpan = True: Exit Function
    If Id = 71 Then Start = 10015: Count = 52: TrySpan = True: Exit Function
    If Id = 72 Then Start = 10067: Count = 61: TrySpan = True: Exit Function
    If Id = 73 Then Start = 10128: Count = 50: TrySpan = True: Exit Function
    If Id = 74 Then Start = 10178: Count = 34: TrySpan = True: Exit Function
    If Id = 75 Then Start = 10212: Count = 36: TrySpan = True: Exit Function
    If Id = 76 Then Start = 10248: Count = 30: TrySpan = True: Exit Function
    If Id = 77 Then Start = 10278: Count = 77: TrySpan = True: Exit Function
    If Id = 78 Then Start = 10355: Count = 34: TrySpan = True: Exit Function
    If Id = 79 Then Start = 10389: Count = 35: TrySpan = True: Exit Function
    If Id = 80 Then Start = 10424: Count = 35: TrySpan = True: Exit Function
    If Id = 81 Then Start = 10459: Count = 29: TrySpan = True: Exit Function
    If Id = 82 Then Start = 10488: Count = 28: TrySpan = True: Exit Function
    If Id = 83 Then Start = 10516: Count = 30: TrySpan = True: Exit Function
    If Id = 84 Then Start = 10546: Count = 29: TrySpan = True: Exit Function
    If Id = 85 Then Start = 10575: Count = 53: TrySpan = True: Exit Function
    If Id = 86 Then Start = 10628: Count = 23: TrySpan = True: Exit Function
    If Id = 87 Then Start = 10651: Count = 54: TrySpan = True: Exit Function
    If Id = 88 Then Start = 10705: Count = 49: TrySpan = True: Exit Function
    If Id = 89 Then Start = 10754: Count = 11: TrySpan = True: Exit Function
    If Id = 90 Then Start = 10765: Count = 11: TrySpan = True: Exit Function
    If Id = 91 Then Start = 10776: Count = 1: TrySpan = True: Exit Function
    If Id = 92 Then Start = 10777: Count = 43: TrySpan = True: Exit Function
    If Id = 93 Then Start = 10820: Count = 132: TrySpan = True: Exit Function
    If Id = 94 Then Start = 10952: Count = 134: TrySpan = True: Exit Function
    If Id = 95 Then Start = 11086: Count = 304: TrySpan = True: Exit Function
    If Id = 96 Then Start = 11390: Count = 41: TrySpan = True: Exit Function
    If Id = 97 Then Start = 11431: Count = 61: TrySpan = True: Exit Function
    If Id = 98 Then Start = 11492: Count = 33: TrySpan = True: Exit Function
    If Id = 99 Then Start = 11525: Count = 64: TrySpan = True: Exit Function
    If Id = 100 Then Start = 11589: Count = 425: TrySpan = True: Exit Function
    If Id = 101 Then Start = 12014: Count = 17: TrySpan = True: Exit Function
    If Id = 102 Then Start = 12031: Count = 555: TrySpan = True: Exit Function
    If Id = 103 Then Start = 12586: Count = 24: TrySpan = True: Exit Function
    If Id = 104 Then Start = 12610: Count = 3: TrySpan = True: Exit Function
    If Id = 105 Then Start = 12613: Count = 64: TrySpan = True: Exit Function
    If Id = 106 Then Start = 12677: Count = 12: TrySpan = True: Exit Function
    If Id = 107 Then Start = 12689: Count = 191: TrySpan = True: Exit Function
    If Id = 108 Then Start = 12880: Count = 199: TrySpan = True: Exit Function
    If Id = 109 Then Start = 13079: Count = 59: TrySpan = True: Exit Function
    If Id = 110 Then Start = 13138: Count = 91: TrySpan = True: Exit Function
    If Id = 111 Then Start = 13229: Count = 37: TrySpan = True: Exit Function
    If Id = 112 Then Start = 13266: Count = 976: TrySpan = True: Exit Function
    If Id = 113 Then Start = 14242: Count = 44: TrySpan = True: Exit Function
    If Id = 114 Then Start = 14286: Count = 40: TrySpan = True: Exit Function
    If Id = 115 Then Start = 14326: Count = 331: TrySpan = True: Exit Function
    If Id = 116 Then Start = 14657: Count = 397: TrySpan = True: Exit Function
    If Id = 117 Then Start = 15054: Count = 368: TrySpan = True: Exit Function
    If Id = 118 Then Start = 15422: Count = 366: TrySpan = True: Exit Function
    If Id = 119 Then Start = 15788: Count = 349: TrySpan = True: Exit Function
    If Id = 120 Then Start = 16137: Count = 398: TrySpan = True: Exit Function
    If Id = 121 Then Start = 16535: Count = 373: TrySpan = True: Exit Function
    If Id = 122 Then Start = 16908: Count = 306: TrySpan = True: Exit Function
    If Id = 123 Then Start = 17214: Count = 302: TrySpan = True: Exit Function
    If Id = 124 Then Start = 17516: Count = 327: TrySpan = True: Exit Function
    If Id = 125 Then Start = 17843: Count = 326: TrySpan = True: Exit Function
    If Id = 126 Then Start = 18169: Count = 324: TrySpan = True: Exit Function
    If Id = 127 Then Start = 18493: Count = 330: TrySpan = True: Exit Function
    If Id = 128 Then Start = 18823: Count = 301: TrySpan = True: Exit Function
    If Id = 129 Then Start = 19124: Count = 305: TrySpan = True: Exit Function
    If Id = 130 Then Start = 19429: Count = 305: TrySpan = True: Exit Function
    If Id = 131 Then Start = 19734: Count = 300: TrySpan = True: Exit Function
    If Id = 132 Then Start = 20034: Count = 325: TrySpan = True: Exit Function
    If Id = 133 Then Start = 20359: Count = 322: TrySpan = True: Exit Function
    If Id = 134 Then Start = 20681: Count = 78: TrySpan = True: Exit Function
    If Id = 135 Then Start = 20759: Count = 56: TrySpan = True: Exit Function
    If Id = 136 Then Start = 20815: Count = 41: TrySpan = True: Exit Function
    If Id = 137 Then Start = 20856: Count = 144: TrySpan = True: Exit Function
    If Id = 138 Then Start = 21000: Count = 166: TrySpan = True: Exit Function
    If Id = 139 Then Start = 21166: Count = 189: TrySpan = True: Exit Function
    If Id = 140 Then Start = 21355: Count = 173: TrySpan = True: Exit Function
    If Id = 141 Then Start = 21528: Count = 264: TrySpan = True: Exit Function
    If Id = 142 Then Start = 21792: Count = 167: TrySpan = True: Exit Function
    If Id = 143 Then Start = 21959: Count = 43: TrySpan = True: Exit Function
    If Id = 144 Then Start = 22002: Count = 32: TrySpan = True: Exit Function
    If Id = 145 Then Start = 22034: Count = 49: TrySpan = True: Exit Function
    If Id = 146 Then Start = 22083: Count = 39: TrySpan = True: Exit Function
    If Id = 147 Then Start = 22122: Count = 32: TrySpan = True: Exit Function
    If Id = 148 Then Start = 22154: Count = 60: TrySpan = True: Exit Function
    If Id = 149 Then Start = 22214: Count = 214: TrySpan = True: Exit Function
    If Id = 150 Then Start = 22428: Count = 38: TrySpan = True: Exit Function
    If Id = 151 Then Start = 22466: Count = 45: TrySpan = True: Exit Function
    If Id = 152 Then Start = 22511: Count = 54: TrySpan = True: Exit Function
    If Id = 153 Then Start = 22565: Count = 37: TrySpan = True: Exit Function
    If Id = 154 Then Start = 22602: Count = 64: TrySpan = True: Exit Function
    If Id = 155 Then Start = 22666: Count = 78: TrySpan = True: Exit Function
    If Id = 156 Then Start = 22744: Count = 31: TrySpan = True: Exit Function
    If Id = 157 Then Start = 22775: Count = 16: TrySpan = True: Exit Function
    If Id = 158 Then Start = 22791: Count = 75: TrySpan = True: Exit Function
    If Id = 159 Then Start = 22866: Count = 101: TrySpan = True: Exit Function
    If Id = 160 Then Start = 22967: Count = 110: TrySpan = True: Exit Function
    If Id = 161 Then Start = 23077: Count = 80: TrySpan = True: Exit Function
    If Id = 162 Then Start = 23157: Count = 57: TrySpan = True: Exit Function
    If Id = 163 Then Start = 23214: Count = 40: TrySpan = True: Exit Function
    If Id = 164 Then Start = 23254: Count = 92: TrySpan = True: Exit Function
    If Id = 165 Then Start = 23346: Count = 134: TrySpan = True: Exit Function
    If Id = 166 Then Start = 23480: Count = 50: TrySpan = True: Exit Function
    If Id = 167 Then Start = 23530: Count = 29: TrySpan = True: Exit Function
    If Id = 168 Then Start = 23559: Count = 27: TrySpan = True: Exit Function
    If Id = 169 Then Start = 23586: Count = 19: TrySpan = True: Exit Function
    If Id = 170 Then Start = 23605: Count = 62: TrySpan = True: Exit Function
    If Id = 171 Then Start = 23667: Count = 77: TrySpan = True: Exit Function
    If Id = 172 Then Start = 23744: Count = 77: TrySpan = True: Exit Function
    If Id = 173 Then Start = 23821: Count = 77: TrySpan = True: Exit Function
    If Id = 174 Then Start = 23898: Count = 29: TrySpan = True: Exit Function
    If Id = 175 Then Start = 23927: Count = 43: TrySpan = True: Exit Function
    If Id = 176 Then Start = 23970: Count = 31: TrySpan = True: Exit Function
    If Id = 177 Then Start = 24001: Count = 31: TrySpan = True: Exit Function
End Function
