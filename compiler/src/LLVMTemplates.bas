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
Public Const TemplateCount As Long = 170
Public Const CatalogLength As Long = 23487
Public Const CatalogByteSum As Long = 1843860

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
    If Id = 14 Then Start = 561: Count = 2090: TrySpan = True: Exit Function
    If Id = 15 Then Start = 2651: Count = 121: TrySpan = True: Exit Function
    If Id = 16 Then Start = 2772: Count = 245: TrySpan = True: Exit Function
    If Id = 17 Then Start = 3017: Count = 58: TrySpan = True: Exit Function
    If Id = 18 Then Start = 3075: Count = 20: TrySpan = True: Exit Function
    If Id = 19 Then Start = 3095: Count = 1198: TrySpan = True: Exit Function
    If Id = 20 Then Start = 4293: Count = 51: TrySpan = True: Exit Function
    If Id = 21 Then Start = 4344: Count = 28: TrySpan = True: Exit Function
    If Id = 22 Then Start = 4372: Count = 43: TrySpan = True: Exit Function
    If Id = 23 Then Start = 4415: Count = 51: TrySpan = True: Exit Function
    If Id = 24 Then Start = 4466: Count = 30: TrySpan = True: Exit Function
    If Id = 25 Then Start = 4496: Count = 40: TrySpan = True: Exit Function
    If Id = 26 Then Start = 4536: Count = 33: TrySpan = True: Exit Function
    If Id = 27 Then Start = 4569: Count = 32: TrySpan = True: Exit Function
    If Id = 28 Then Start = 4601: Count = 32: TrySpan = True: Exit Function
    If Id = 29 Then Start = 4633: Count = 34: TrySpan = True: Exit Function
    If Id = 30 Then Start = 4667: Count = 28: TrySpan = True: Exit Function
    If Id = 31 Then Start = 4695: Count = 44: TrySpan = True: Exit Function
    If Id = 32 Then Start = 4739: Count = 44: TrySpan = True: Exit Function
    If Id = 33 Then Start = 4783: Count = 77: TrySpan = True: Exit Function
    If Id = 34 Then Start = 4860: Count = 77: TrySpan = True: Exit Function
    If Id = 35 Then Start = 4937: Count = 77: TrySpan = True: Exit Function
    If Id = 36 Then Start = 5014: Count = 77: TrySpan = True: Exit Function
    If Id = 37 Then Start = 5091: Count = 77: TrySpan = True: Exit Function
    If Id = 38 Then Start = 5168: Count = 77: TrySpan = True: Exit Function
    If Id = 39 Then Start = 5245: Count = 380: TrySpan = True: Exit Function
    If Id = 40 Then Start = 5625: Count = 393: TrySpan = True: Exit Function
    If Id = 41 Then Start = 6018: Count = 408: TrySpan = True: Exit Function
    If Id = 42 Then Start = 6426: Count = 407: TrySpan = True: Exit Function
    If Id = 43 Then Start = 6833: Count = 299: TrySpan = True: Exit Function
    If Id = 44 Then Start = 7132: Count = 299: TrySpan = True: Exit Function
    If Id = 45 Then Start = 7431: Count = 314: TrySpan = True: Exit Function
    If Id = 46 Then Start = 7745: Count = 228: TrySpan = True: Exit Function
    If Id = 47 Then Start = 7973: Count = 266: TrySpan = True: Exit Function
    If Id = 48 Then Start = 8239: Count = 337: TrySpan = True: Exit Function
    If Id = 49 Then Start = 8576: Count = 311: TrySpan = True: Exit Function
    If Id = 50 Then Start = 8887: Count = 58: TrySpan = True: Exit Function
    If Id = 51 Then Start = 8945: Count = 48: TrySpan = True: Exit Function
    If Id = 52 Then Start = 8993: Count = 49: TrySpan = True: Exit Function
    If Id = 53 Then Start = 9042: Count = 49: TrySpan = True: Exit Function
    If Id = 54 Then Start = 9091: Count = 47: TrySpan = True: Exit Function
    If Id = 55 Then Start = 9138: Count = 49: TrySpan = True: Exit Function
    If Id = 56 Then Start = 9187: Count = 29: TrySpan = True: Exit Function
    If Id = 57 Then Start = 9216: Count = 28: TrySpan = True: Exit Function
    If Id = 58 Then Start = 9244: Count = 27: TrySpan = True: Exit Function
    If Id = 59 Then Start = 9271: Count = 40: TrySpan = True: Exit Function
    If Id = 60 Then Start = 9311: Count = 31: TrySpan = True: Exit Function
    If Id = 61 Then Start = 9342: Count = 114: TrySpan = True: Exit Function
    If Id = 62 Then Start = 9456: Count = 47: TrySpan = True: Exit Function
    If Id = 63 Then Start = 9503: Count = 49: TrySpan = True: Exit Function
    If Id = 64 Then Start = 9552: Count = 35: TrySpan = True: Exit Function
    If Id = 65 Then Start = 9587: Count = 35: TrySpan = True: Exit Function
    If Id = 66 Then Start = 9622: Count = 28: TrySpan = True: Exit Function
    If Id = 67 Then Start = 9650: Count = 30: TrySpan = True: Exit Function
    If Id = 68 Then Start = 9680: Count = 28: TrySpan = True: Exit Function
    If Id = 69 Then Start = 9708: Count = 64: TrySpan = True: Exit Function
    If Id = 70 Then Start = 9772: Count = 63: TrySpan = True: Exit Function
    If Id = 71 Then Start = 9835: Count = 52: TrySpan = True: Exit Function
    If Id = 72 Then Start = 9887: Count = 61: TrySpan = True: Exit Function
    If Id = 73 Then Start = 9948: Count = 50: TrySpan = True: Exit Function
    If Id = 74 Then Start = 9998: Count = 34: TrySpan = True: Exit Function
    If Id = 75 Then Start = 10032: Count = 36: TrySpan = True: Exit Function
    If Id = 76 Then Start = 10068: Count = 30: TrySpan = True: Exit Function
    If Id = 77 Then Start = 10098: Count = 77: TrySpan = True: Exit Function
    If Id = 78 Then Start = 10175: Count = 34: TrySpan = True: Exit Function
    If Id = 79 Then Start = 10209: Count = 35: TrySpan = True: Exit Function
    If Id = 80 Then Start = 10244: Count = 35: TrySpan = True: Exit Function
    If Id = 81 Then Start = 10279: Count = 29: TrySpan = True: Exit Function
    If Id = 82 Then Start = 10308: Count = 28: TrySpan = True: Exit Function
    If Id = 83 Then Start = 10336: Count = 30: TrySpan = True: Exit Function
    If Id = 84 Then Start = 10366: Count = 29: TrySpan = True: Exit Function
    If Id = 85 Then Start = 10395: Count = 53: TrySpan = True: Exit Function
    If Id = 86 Then Start = 10448: Count = 23: TrySpan = True: Exit Function
    If Id = 87 Then Start = 10471: Count = 54: TrySpan = True: Exit Function
    If Id = 88 Then Start = 10525: Count = 49: TrySpan = True: Exit Function
    If Id = 89 Then Start = 10574: Count = 11: TrySpan = True: Exit Function
    If Id = 90 Then Start = 10585: Count = 11: TrySpan = True: Exit Function
    If Id = 91 Then Start = 10596: Count = 1: TrySpan = True: Exit Function
    If Id = 92 Then Start = 10597: Count = 43: TrySpan = True: Exit Function
    If Id = 93 Then Start = 10640: Count = 132: TrySpan = True: Exit Function
    If Id = 94 Then Start = 10772: Count = 134: TrySpan = True: Exit Function
    If Id = 95 Then Start = 10906: Count = 304: TrySpan = True: Exit Function
    If Id = 96 Then Start = 11210: Count = 41: TrySpan = True: Exit Function
    If Id = 97 Then Start = 11251: Count = 61: TrySpan = True: Exit Function
    If Id = 98 Then Start = 11312: Count = 33: TrySpan = True: Exit Function
    If Id = 99 Then Start = 11345: Count = 64: TrySpan = True: Exit Function
    If Id = 100 Then Start = 11409: Count = 425: TrySpan = True: Exit Function
    If Id = 101 Then Start = 11834: Count = 17: TrySpan = True: Exit Function
    If Id = 102 Then Start = 11851: Count = 555: TrySpan = True: Exit Function
    If Id = 103 Then Start = 12406: Count = 24: TrySpan = True: Exit Function
    If Id = 104 Then Start = 12430: Count = 3: TrySpan = True: Exit Function
    If Id = 105 Then Start = 12433: Count = 64: TrySpan = True: Exit Function
    If Id = 106 Then Start = 12497: Count = 12: TrySpan = True: Exit Function
    If Id = 107 Then Start = 12509: Count = 191: TrySpan = True: Exit Function
    If Id = 108 Then Start = 12700: Count = 199: TrySpan = True: Exit Function
    If Id = 109 Then Start = 12899: Count = 59: TrySpan = True: Exit Function
    If Id = 110 Then Start = 12958: Count = 91: TrySpan = True: Exit Function
    If Id = 111 Then Start = 13049: Count = 37: TrySpan = True: Exit Function
    If Id = 112 Then Start = 13086: Count = 976: TrySpan = True: Exit Function
    If Id = 113 Then Start = 14062: Count = 44: TrySpan = True: Exit Function
    If Id = 114 Then Start = 14106: Count = 40: TrySpan = True: Exit Function
    If Id = 115 Then Start = 14146: Count = 331: TrySpan = True: Exit Function
    If Id = 116 Then Start = 14477: Count = 397: TrySpan = True: Exit Function
    If Id = 117 Then Start = 14874: Count = 368: TrySpan = True: Exit Function
    If Id = 118 Then Start = 15242: Count = 366: TrySpan = True: Exit Function
    If Id = 119 Then Start = 15608: Count = 349: TrySpan = True: Exit Function
    If Id = 120 Then Start = 15957: Count = 398: TrySpan = True: Exit Function
    If Id = 121 Then Start = 16355: Count = 373: TrySpan = True: Exit Function
    If Id = 122 Then Start = 16728: Count = 306: TrySpan = True: Exit Function
    If Id = 123 Then Start = 17034: Count = 302: TrySpan = True: Exit Function
    If Id = 124 Then Start = 17336: Count = 327: TrySpan = True: Exit Function
    If Id = 125 Then Start = 17663: Count = 326: TrySpan = True: Exit Function
    If Id = 126 Then Start = 17989: Count = 324: TrySpan = True: Exit Function
    If Id = 127 Then Start = 18313: Count = 330: TrySpan = True: Exit Function
    If Id = 128 Then Start = 18643: Count = 301: TrySpan = True: Exit Function
    If Id = 129 Then Start = 18944: Count = 305: TrySpan = True: Exit Function
    If Id = 130 Then Start = 19249: Count = 305: TrySpan = True: Exit Function
    If Id = 131 Then Start = 19554: Count = 300: TrySpan = True: Exit Function
    If Id = 132 Then Start = 19854: Count = 325: TrySpan = True: Exit Function
    If Id = 133 Then Start = 20179: Count = 322: TrySpan = True: Exit Function
    If Id = 134 Then Start = 20501: Count = 78: TrySpan = True: Exit Function
    If Id = 135 Then Start = 20579: Count = 56: TrySpan = True: Exit Function
    If Id = 136 Then Start = 20635: Count = 41: TrySpan = True: Exit Function
    If Id = 137 Then Start = 20676: Count = 144: TrySpan = True: Exit Function
    If Id = 138 Then Start = 20820: Count = 166: TrySpan = True: Exit Function
    If Id = 139 Then Start = 20986: Count = 189: TrySpan = True: Exit Function
    If Id = 140 Then Start = 21175: Count = 173: TrySpan = True: Exit Function
    If Id = 141 Then Start = 21348: Count = 264: TrySpan = True: Exit Function
    If Id = 142 Then Start = 21612: Count = 167: TrySpan = True: Exit Function
    If Id = 143 Then Start = 21779: Count = 43: TrySpan = True: Exit Function
    If Id = 144 Then Start = 21822: Count = 32: TrySpan = True: Exit Function
    If Id = 145 Then Start = 21854: Count = 49: TrySpan = True: Exit Function
    If Id = 146 Then Start = 21903: Count = 39: TrySpan = True: Exit Function
    If Id = 147 Then Start = 21942: Count = 32: TrySpan = True: Exit Function
    If Id = 148 Then Start = 21974: Count = 60: TrySpan = True: Exit Function
    If Id = 149 Then Start = 22034: Count = 214: TrySpan = True: Exit Function
    If Id = 150 Then Start = 22248: Count = 38: TrySpan = True: Exit Function
    If Id = 151 Then Start = 22286: Count = 45: TrySpan = True: Exit Function
    If Id = 152 Then Start = 22331: Count = 54: TrySpan = True: Exit Function
    If Id = 153 Then Start = 22385: Count = 37: TrySpan = True: Exit Function
    If Id = 154 Then Start = 22422: Count = 64: TrySpan = True: Exit Function
    If Id = 155 Then Start = 22486: Count = 78: TrySpan = True: Exit Function
    If Id = 156 Then Start = 22564: Count = 31: TrySpan = True: Exit Function
    If Id = 157 Then Start = 22595: Count = 16: TrySpan = True: Exit Function
    If Id = 158 Then Start = 22611: Count = 75: TrySpan = True: Exit Function
    If Id = 159 Then Start = 22686: Count = 101: TrySpan = True: Exit Function
    If Id = 160 Then Start = 22787: Count = 110: TrySpan = True: Exit Function
    If Id = 161 Then Start = 22897: Count = 80: TrySpan = True: Exit Function
    If Id = 162 Then Start = 22977: Count = 57: TrySpan = True: Exit Function
    If Id = 163 Then Start = 23034: Count = 40: TrySpan = True: Exit Function
    If Id = 164 Then Start = 23074: Count = 92: TrySpan = True: Exit Function
    If Id = 165 Then Start = 23166: Count = 134: TrySpan = True: Exit Function
    If Id = 166 Then Start = 23300: Count = 50: TrySpan = True: Exit Function
    If Id = 167 Then Start = 23350: Count = 29: TrySpan = True: Exit Function
    If Id = 168 Then Start = 23379: Count = 27: TrySpan = True: Exit Function
    If Id = 169 Then Start = 23406: Count = 19: TrySpan = True: Exit Function
    If Id = 170 Then Start = 23425: Count = 62: TrySpan = True: Exit Function
End Function
