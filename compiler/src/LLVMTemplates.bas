UBE SOURCE 1 MODULE
Attribute UBE_Name = "LLVMTemplates"
' Generated from compiler/llvm/templates.json by bootstrap/tools/llvm-templates.ps1.
Public Const IntrinsicMemoryCollect As Long = 1
Public Const IntrinsicManagedWorkspace As Long = 2
Public Const Branch As Long = 3
Public Const ConditionalBranch As Long = 4
Public Const Label As Long = 5
Public Const IntegerValue As Long = 6
Public Const LoadValue As Long = 7
Public Const StoreValue As Long = 8
Public Const ContextType As Long = 9
Public Const ProcedureStart As Long = 10
Public Const ValueParameter As Long = 11
Public Const ReferenceParameter As Long = 12
Public Const ProcedureBody As Long = 13
Public Const FunctionEnd As Long = 14
Public Const ContextFileType As Long = 15
Public Const ContextPrefix As Long = 16
Public Const ContextArrayRelease As Long = 17
Public Const ContextMiddle As Long = 18
Public Const EnsureModule As Long = 19
Public Const ContextSuffix As Long = 20
Public Const Entry As Long = 21
Public Const StoreError As Long = 22
Public Const FailureBranch As Long = 23
Public Const CallSuccess As Long = 24
Public Const CallSuccessBranch As Long = 25
Public Const ValueNonzero As Long = 26
Public Const BooleanSelect As Long = 27
Public Const TruncateValue As Long = 28
Public Const SignExtendValue As Long = 29
Public Const ZeroExtendValue As Long = 30
Public Const DifferentValues As Long = 31
Public Const ComplementValue As Long = 32
Public Const OverflowFlag As Long = 33
Public Const ArithmeticValue As Long = 34
Public Const ArithmeticAdd16 As Long = 35
Public Const ArithmeticSubtract16 As Long = 36
Public Const ArithmeticAdd32 As Long = 37
Public Const ArithmeticSubtract32 As Long = 38
Public Const ArithmeticAdd64 As Long = 39
Public Const ArithmeticSubtract64 As Long = 40
Public Const IntrinsicFileOpen As Long = 41
Public Const IntrinsicFileCreateNew As Long = 42
Public Const IntrinsicFileRead As Long = 43
Public Const IntrinsicFileWrite As Long = 44
Public Const IntrinsicFileClose As Long = 45
Public Const IntrinsicFileFlush As Long = 46
Public Const IntrinsicErrorSet As Long = 47
Public Const IntrinsicArrayLength As Long = 48
Public Const IntrinsicMemoryCopyBytes As Long = 49
Public Const IntrinsicArrayResize As Long = 50
Public Const IntrinsicArrayCopy As Long = 51
Public Const ContextAddress As Long = 52
Public Const ArgumentAddress As Long = 53
Public Const SlotAddress As Long = 54
Public Const TemporaryAddress As Long = 55
Public Const CellAddress As Long = 56
Public Const IndexedAddress As Long = 57
Public Const LoadPointer As Long = 58
Public Const StorePointer As Long = 59
Public Const StoreNullPointer As Long = 60
Public Const RetainBlock As Long = 61
Public Const PinBlock As Long = 62
Public Const ReleasePin As Long = 63
Public Const CollectMemory As Long = 64
Public Const ClearArray As Long = 65
Public Const BelowBound As Long = 66
Public Const AboveBound As Long = 67
Public Const EitherCondition As Long = 68
Public Const RelativeIndex As Long = 69
Public Const ElementOffset As Long = 70
Public Const LoadVolatileValue As Long = 71
Public Const StoreVolatileValue As Long = 72
Public Const StoreConstant As Long = 73
Public Const StoreVolatileConstant As Long = 74
Public Const EnsureModuleValue As Long = 75
Public Const ControlSite As Long = 76
Public Const ControlHandler As Long = 77
Public Const ControlZero As Long = 78
Public Const ControlArrayCopy As Long = 79
Public Const CompareEqual As Long = 80
Public Const CompareLessEqual As Long = 81
Public Const CompareGreaterEqual As Long = 82
Public Const BooleanAnd As Long = 83
Public Const BooleanInvert As Long = 84
Public Const IntegerAnd As Long = 85
Public Const IntegerOr As Long = 86
Public Const StoreErrorValue As Long = 87
Public Const ReturnFailureBranch As Long = 88
Public Const LoadError As Long = 89
Public Const CallStart As Long = 90
Public Const CallValueArgument As Long = 91
Public Const CallReferenceArgument As Long = 92
Public Const CallEnd As Long = 93
Public Const CallValue As Long = 94
Public Const ProcedurePointers As Long = 95
Public Const ModuleInitializeStart As Long = 96
Public Const FrameControls As Long = 97
Public Const AllocateSlot As Long = 98
Public Const StoreParameter As Long = 99
Public Const AllocateTemporary As Long = 100
Public Const AllocatePin As Long = 101
Public Const ProcedureDepth As Long = 102
Public Const FailureDispatchLabel As Long = 103
Public Const FailureHandlerDispatch As Long = 104
Public Const SwitchCase As Long = 105
Public Const SwitchEnd As Long = 106
Public Const FailureSkipDispatch As Long = 107
Public Const ReturnFailureLabel As Long = 108
Public Const ReturnDepthSuccess As Long = 109
Public Const ReturnDepthFailure As Long = 110
Public Const LoadResult As Long = 111
Public Const ReturnSuccessValue As Long = 112
Public Const ReturnFailedValue As Long = 113
Public Const ModuleEnsureDefinition As Long = 114
Public Const SourceLocation As Long = 115
Public Const TargetHeader As Long = 116
Public Const IntrinsicSystemCommandLine As Long = 117
Public Const IntrinsicSystemWrite As Long = 118
Public Const IntrinsicFileFinalPath As Long = 119
Public Const IntrinsicPathFullPath As Long = 120
Public Const IntrinsicPathCompareOrdinal As Long = 121
Public Const IntrinsicProcessStart As Long = 122
Public Const IntrinsicProcessWait As Long = 123
Public Const IntrinsicProcessTerminate As Long = 124
Public Const IntrinsicProcessClose As Long = 125
Public Const IntrinsicFileOpenDirectory As Long = 126
Public Const IntrinsicFileIdentity As Long = 127
Public Const IntrinsicFileLength As Long = 128
Public Const IntrinsicSystemExecutablePath As Long = 129
Public Const IntrinsicSystemMonotonicMilliseconds As Long = 130
Public Const IntrinsicDirectoryCreate As Long = 131
Public Const IntrinsicDirectoryRemove As Long = 132
Public Const IntrinsicFileDelete As Long = 133
Public Const IntrinsicFileReplace As Long = 134
Public Const IntrinsicPathKind As Long = 135
Public Const ArraySnapshot As Long = 136
Public Const SnapshotValue As Long = 137
Public Const AllocateAggregateTemporary As Long = 138
Public Const IntrinsicThreadCurrentId As Long = 139
Public Const IntrinsicThreadIsAlive As Long = 140
Public Const IntrinsicThreadWait As Long = 141
Public Const IntrinsicThreadRequestStop As Long = 142
Public Const IntrinsicThreadStopRequested As Long = 143
Public Const IntrinsicThreadYield As Long = 144
Public Const NullOwner As Long = 145
Public Const LoadLocalOwner As Long = 146
Public Const IncomingOwner As Long = 147
Public Const LoadTemporaryOwner As Long = 148
Public Const LoadPinOwner As Long = 149
Public Const NewOwner As Long = 150
Public Const OwnerAllocated As Long = 151
Public Const SetTemporaryOwner As Long = 152
Public Const OwnerPayload As Long = 153
Public Const DropOwner As Long = 154
Public Const ClearTemporaryOwner As Long = 155
Public Const AllocateLocalOwner As Long = 156
Public Const AllocateTemporaryOwner As Long = 157
Public Const SetLocalOwner As Long = 158
Public Const OwnerParameter As Long = 159
Public Const OwnerEntryGuard As Long = 160
Public Const BoxAddress As Long = 161
Public Const BoxTemporaryAddress As Long = 162
Public Const InstallOwnedArray As Long = 163
Public Const StoreBoxParameter As Long = 164
Public Const RetainOwner As Long = 165
Public Const StartThread As Long = 166
Public Const ThreadThunkStart As Long = 167
Public Const CaptureAddress As Long = 168
Public Const LoadOwnerPointer As Long = 169
Public Const BooleanConstant As Long = 170
Public Const ThreadThunkEnd As Long = 171
Public Const NewArrayOwner As Long = 172
Public Const ArithmeticMultiply16 As Long = 173
Public Const ArithmeticMultiply32 As Long = 174
Public Const ArithmeticMultiply64 As Long = 175
Public Const BothConditions As Long = 176
Public Const SafeRemainderDivisor As Long = 177
Public Const DivisionValue As Long = 178
Public Const RemainderValue As Long = 179
Public Const IntrinsicArrayMove As Long = 180
Public Const TextLiteralStart As Long = 181
Public Const TextLiteralByte As Long = 182
Public Const TextLiteralLastByte As Long = 183
Public Const TextLiteralEnd As Long = 184
Public Const TextLiteralAddress As Long = 185
Public Const TextRootLoad As Long = 186
Public Const TextRootStore As Long = 187
Public Const TextRootTake As Long = 188
Public Const ManagedEntryFrame As Long = 189
Public Const ManagedTextSlots As Long = 190
Public Const ManagedTextAlias As Long = 191
Public Const ManagedSymbolRoot As Long = 192
Public Const ManagedArraySymbolRoot As Long = 193
Public Const ManagedTemporaryRoot As Long = 194
Public Const ManagedArrayTemporaryRoot As Long = 195
Public Const ManagedRestoreRoots As Long = 196
Public Const ManagedReturnValue As Long = 197
Public Const ManagedDiscardReturn As Long = 198
Public Const ManagedOffsetsStart As Long = 199
Public Const ManagedOffsetsEnd As Long = 200
Public Const ManagedValueLayout As Long = 201
Public Const ManagedStoreValue As Long = 202
Public Const ManagedGlobalOffsetsStart As Long = 203
Public Const ManagedGlobalArraysStart As Long = 204
Public Const ManagedGlobalArrayEntry As Long = 205
Public Const ManagedGlobalArrayLastEntry As Long = 206
Public Const ManagedGlobalLayout As Long = 207
Public Const ManagedProcedureDepth As Long = 208
Public Const ManagedProjectInitialize As Long = 209
Public Const ManagedOwnerLayout As Long = 210
Public Const ManagedLocalOwnerRoot As Long = 211
Public Const ManagedTemporaryOwnerRoot As Long = 212
Public Const ManagedIncomingOwnerRoot As Long = 213
Public Const ManagedPinRoot As Long = 214
Public Const AttachManagedOwner As Long = 215
Public Const AttachManagedArrayOwner As Long = 216
Public Const IntrinsicManagedBeginCollection As Long = 217
Public Const IntrinsicManagedEndCollection As Long = 218
Public Const IntrinsicManagedSnapshotCounts As Long = 219
Public Const IntrinsicManagedAllocationAt As Long = 220
Public Const IntrinsicManagedRootAt As Long = 221
Public Const IntrinsicManagedMark As Long = 222
Public Const IntrinsicManagedMarked As Long = 223
Public Const IntrinsicManagedEdgeCount As Long = 224
Public Const IntrinsicManagedEdgeAt As Long = 225
Public Const IntrinsicManagedSealCollection As Long = 226
Public Const IntrinsicManagedReclaim As Long = 227
Public Const IntrinsicTextByteLength As Long = 228
Public Const IntrinsicTextScalarLength As Long = 229
Public Const IntrinsicTextReadByte As Long = 230
Public Const IntrinsicTextCreate As Long = 231
Public Const IntrinsicTextWriteByte As Long = 232
Public Const IntrinsicTextPublish As Long = 233
Public Const IntrinsicTextAbandon As Long = 234
Public Const ManagedCaptureOffsetsStart As Long = 235
Public Const ManagedCaptureOwnersStart As Long = 236
Public Const ManagedCaptureLayout As Long = 237
Public Const AttachManagedCapture As Long = 238
Public Const CapturePayloadAddress As Long = 239
Public Const ClearCapturedOwner As Long = 240
Public Const ManagedSafepoint As Long = 241
Public Const ManagedTemporaryTable As Long = 242
Public Const ManagedTextTableEntry As Long = 243
Public Const ManagedTemporaryTableEntry As Long = 244
Public Const ManagedRetireTemporaries As Long = 245
Public Const ManagedRetireDefinition As Long = 246
Public Const IntrinsicArrayResizeManaged As Long = 247
Public Const IntrinsicArrayCopyManaged As Long = 248
Public Const ControlManagedArrayCopyStart As Long = 249
Public Const ManagedLayoutCallEnd As Long = 250
Public Const TemplateCount As Long = 250
Public Const CatalogLength As Long = 37392
Public Const CatalogByteSum As Long = 2959678

' Returns one exact span without changing caller outputs for an unknown identity.
Public Function TrySpan(ByVal Id As Long, ByRef Start As Long, ByRef Count As Long) As Boolean
    If Id = 1 Then Start = 0: Count = 153: TrySpan = True: Exit Function
    If Id = 2 Then Start = 153: Count = 330: TrySpan = True: Exit Function
    If Id = 3 Then Start = 483: Count = 16: TrySpan = True: Exit Function
    If Id = 4 Then Start = 499: Count = 39: TrySpan = True: Exit Function
    If Id = 5 Then Start = 538: Count = 5: TrySpan = True: Exit Function
    If Id = 6 Then Start = 543: Count = 24: TrySpan = True: Exit Function
    If Id = 7 Then Start = 567: Count = 55: TrySpan = True: Exit Function
    If Id = 8 Then Start = 622: Count = 54: TrySpan = True: Exit Function
    If Id = 9 Then Start = 676: Count = 307: TrySpan = True: Exit Function
    If Id = 10 Then Start = 983: Count = 41: TrySpan = True: Exit Function
    If Id = 11 Then Start = 1024: Count = 14: TrySpan = True: Exit Function
    If Id = 12 Then Start = 1038: Count = 14: TrySpan = True: Exit Function
    If Id = 13 Then Start = 1052: Count = 3: TrySpan = True: Exit Function
    If Id = 14 Then Start = 1055: Count = 1: TrySpan = True: Exit Function
    If Id = 15 Then Start = 1056: Count = 48: TrySpan = True: Exit Function
    If Id = 16 Then Start = 1104: Count = 2330: TrySpan = True: Exit Function
    If Id = 17 Then Start = 3434: Count = 121: TrySpan = True: Exit Function
    If Id = 18 Then Start = 3555: Count = 382: TrySpan = True: Exit Function
    If Id = 19 Then Start = 3937: Count = 58: TrySpan = True: Exit Function
    If Id = 20 Then Start = 3995: Count = 20: TrySpan = True: Exit Function
    If Id = 21 Then Start = 4015: Count = 1198: TrySpan = True: Exit Function
    If Id = 22 Then Start = 5213: Count = 51: TrySpan = True: Exit Function
    If Id = 23 Then Start = 5264: Count = 28: TrySpan = True: Exit Function
    If Id = 24 Then Start = 5292: Count = 43: TrySpan = True: Exit Function
    If Id = 25 Then Start = 5335: Count = 51: TrySpan = True: Exit Function
    If Id = 26 Then Start = 5386: Count = 30: TrySpan = True: Exit Function
    If Id = 27 Then Start = 5416: Count = 40: TrySpan = True: Exit Function
    If Id = 28 Then Start = 5456: Count = 33: TrySpan = True: Exit Function
    If Id = 29 Then Start = 5489: Count = 32: TrySpan = True: Exit Function
    If Id = 30 Then Start = 5521: Count = 32: TrySpan = True: Exit Function
    If Id = 31 Then Start = 5553: Count = 34: TrySpan = True: Exit Function
    If Id = 32 Then Start = 5587: Count = 28: TrySpan = True: Exit Function
    If Id = 33 Then Start = 5615: Count = 44: TrySpan = True: Exit Function
    If Id = 34 Then Start = 5659: Count = 44: TrySpan = True: Exit Function
    If Id = 35 Then Start = 5703: Count = 77: TrySpan = True: Exit Function
    If Id = 36 Then Start = 5780: Count = 77: TrySpan = True: Exit Function
    If Id = 37 Then Start = 5857: Count = 77: TrySpan = True: Exit Function
    If Id = 38 Then Start = 5934: Count = 77: TrySpan = True: Exit Function
    If Id = 39 Then Start = 6011: Count = 77: TrySpan = True: Exit Function
    If Id = 40 Then Start = 6088: Count = 77: TrySpan = True: Exit Function
    If Id = 41 Then Start = 6165: Count = 380: TrySpan = True: Exit Function
    If Id = 42 Then Start = 6545: Count = 393: TrySpan = True: Exit Function
    If Id = 43 Then Start = 6938: Count = 408: TrySpan = True: Exit Function
    If Id = 44 Then Start = 7346: Count = 407: TrySpan = True: Exit Function
    If Id = 45 Then Start = 7753: Count = 299: TrySpan = True: Exit Function
    If Id = 46 Then Start = 8052: Count = 299: TrySpan = True: Exit Function
    If Id = 47 Then Start = 8351: Count = 314: TrySpan = True: Exit Function
    If Id = 48 Then Start = 8665: Count = 228: TrySpan = True: Exit Function
    If Id = 49 Then Start = 8893: Count = 266: TrySpan = True: Exit Function
    If Id = 50 Then Start = 9159: Count = 347: TrySpan = True: Exit Function
    If Id = 51 Then Start = 9506: Count = 321: TrySpan = True: Exit Function
    If Id = 52 Then Start = 9827: Count = 58: TrySpan = True: Exit Function
    If Id = 53 Then Start = 9885: Count = 48: TrySpan = True: Exit Function
    If Id = 54 Then Start = 9933: Count = 49: TrySpan = True: Exit Function
    If Id = 55 Then Start = 9982: Count = 49: TrySpan = True: Exit Function
    If Id = 56 Then Start = 10031: Count = 47: TrySpan = True: Exit Function
    If Id = 57 Then Start = 10078: Count = 49: TrySpan = True: Exit Function
    If Id = 58 Then Start = 10127: Count = 29: TrySpan = True: Exit Function
    If Id = 59 Then Start = 10156: Count = 28: TrySpan = True: Exit Function
    If Id = 60 Then Start = 10184: Count = 27: TrySpan = True: Exit Function
    If Id = 61 Then Start = 10211: Count = 40: TrySpan = True: Exit Function
    If Id = 62 Then Start = 10251: Count = 55: TrySpan = True: Exit Function
    If Id = 63 Then Start = 10306: Count = 162: TrySpan = True: Exit Function
    If Id = 64 Then Start = 10468: Count = 47: TrySpan = True: Exit Function
    If Id = 65 Then Start = 10515: Count = 49: TrySpan = True: Exit Function
    If Id = 66 Then Start = 10564: Count = 35: TrySpan = True: Exit Function
    If Id = 67 Then Start = 10599: Count = 35: TrySpan = True: Exit Function
    If Id = 68 Then Start = 10634: Count = 28: TrySpan = True: Exit Function
    If Id = 69 Then Start = 10662: Count = 30: TrySpan = True: Exit Function
    If Id = 70 Then Start = 10692: Count = 28: TrySpan = True: Exit Function
    If Id = 71 Then Start = 10720: Count = 64: TrySpan = True: Exit Function
    If Id = 72 Then Start = 10784: Count = 63: TrySpan = True: Exit Function
    If Id = 73 Then Start = 10847: Count = 52: TrySpan = True: Exit Function
    If Id = 74 Then Start = 10899: Count = 61: TrySpan = True: Exit Function
    If Id = 75 Then Start = 10960: Count = 50: TrySpan = True: Exit Function
    If Id = 76 Then Start = 11010: Count = 34: TrySpan = True: Exit Function
    If Id = 77 Then Start = 11044: Count = 36: TrySpan = True: Exit Function
    If Id = 78 Then Start = 11080: Count = 30: TrySpan = True: Exit Function
    If Id = 79 Then Start = 11110: Count = 87: TrySpan = True: Exit Function
    If Id = 80 Then Start = 11197: Count = 34: TrySpan = True: Exit Function
    If Id = 81 Then Start = 11231: Count = 35: TrySpan = True: Exit Function
    If Id = 82 Then Start = 11266: Count = 35: TrySpan = True: Exit Function
    If Id = 83 Then Start = 11301: Count = 29: TrySpan = True: Exit Function
    If Id = 84 Then Start = 11330: Count = 28: TrySpan = True: Exit Function
    If Id = 85 Then Start = 11358: Count = 30: TrySpan = True: Exit Function
    If Id = 86 Then Start = 11388: Count = 29: TrySpan = True: Exit Function
    If Id = 87 Then Start = 11417: Count = 53: TrySpan = True: Exit Function
    If Id = 88 Then Start = 11470: Count = 23: TrySpan = True: Exit Function
    If Id = 89 Then Start = 11493: Count = 54: TrySpan = True: Exit Function
    If Id = 90 Then Start = 11547: Count = 49: TrySpan = True: Exit Function
    If Id = 91 Then Start = 11596: Count = 11: TrySpan = True: Exit Function
    If Id = 92 Then Start = 11607: Count = 11: TrySpan = True: Exit Function
    If Id = 93 Then Start = 11618: Count = 1: TrySpan = True: Exit Function
    If Id = 94 Then Start = 11619: Count = 43: TrySpan = True: Exit Function
    If Id = 95 Then Start = 11662: Count = 132: TrySpan = True: Exit Function
    If Id = 96 Then Start = 11794: Count = 134: TrySpan = True: Exit Function
    If Id = 97 Then Start = 11928: Count = 304: TrySpan = True: Exit Function
    If Id = 98 Then Start = 12232: Count = 41: TrySpan = True: Exit Function
    If Id = 99 Then Start = 12273: Count = 61: TrySpan = True: Exit Function
    If Id = 100 Then Start = 12334: Count = 33: TrySpan = True: Exit Function
    If Id = 101 Then Start = 12367: Count = 64: TrySpan = True: Exit Function
    If Id = 102 Then Start = 12431: Count = 425: TrySpan = True: Exit Function
    If Id = 103 Then Start = 12856: Count = 17: TrySpan = True: Exit Function
    If Id = 104 Then Start = 12873: Count = 555: TrySpan = True: Exit Function
    If Id = 105 Then Start = 13428: Count = 24: TrySpan = True: Exit Function
    If Id = 106 Then Start = 13452: Count = 3: TrySpan = True: Exit Function
    If Id = 107 Then Start = 13455: Count = 64: TrySpan = True: Exit Function
    If Id = 108 Then Start = 13519: Count = 12: TrySpan = True: Exit Function
    If Id = 109 Then Start = 13531: Count = 191: TrySpan = True: Exit Function
    If Id = 110 Then Start = 13722: Count = 199: TrySpan = True: Exit Function
    If Id = 111 Then Start = 13921: Count = 59: TrySpan = True: Exit Function
    If Id = 112 Then Start = 13980: Count = 91: TrySpan = True: Exit Function
    If Id = 113 Then Start = 14071: Count = 37: TrySpan = True: Exit Function
    If Id = 114 Then Start = 14108: Count = 976: TrySpan = True: Exit Function
    If Id = 115 Then Start = 15084: Count = 44: TrySpan = True: Exit Function
    If Id = 116 Then Start = 15128: Count = 40: TrySpan = True: Exit Function
    If Id = 117 Then Start = 15168: Count = 331: TrySpan = True: Exit Function
    If Id = 118 Then Start = 15499: Count = 397: TrySpan = True: Exit Function
    If Id = 119 Then Start = 15896: Count = 368: TrySpan = True: Exit Function
    If Id = 120 Then Start = 16264: Count = 366: TrySpan = True: Exit Function
    If Id = 121 Then Start = 16630: Count = 349: TrySpan = True: Exit Function
    If Id = 122 Then Start = 16979: Count = 398: TrySpan = True: Exit Function
    If Id = 123 Then Start = 17377: Count = 373: TrySpan = True: Exit Function
    If Id = 124 Then Start = 17750: Count = 306: TrySpan = True: Exit Function
    If Id = 125 Then Start = 18056: Count = 302: TrySpan = True: Exit Function
    If Id = 126 Then Start = 18358: Count = 327: TrySpan = True: Exit Function
    If Id = 127 Then Start = 18685: Count = 326: TrySpan = True: Exit Function
    If Id = 128 Then Start = 19011: Count = 324: TrySpan = True: Exit Function
    If Id = 129 Then Start = 19335: Count = 330: TrySpan = True: Exit Function
    If Id = 130 Then Start = 19665: Count = 301: TrySpan = True: Exit Function
    If Id = 131 Then Start = 19966: Count = 305: TrySpan = True: Exit Function
    If Id = 132 Then Start = 20271: Count = 305: TrySpan = True: Exit Function
    If Id = 133 Then Start = 20576: Count = 300: TrySpan = True: Exit Function
    If Id = 134 Then Start = 20876: Count = 325: TrySpan = True: Exit Function
    If Id = 135 Then Start = 21201: Count = 322: TrySpan = True: Exit Function
    If Id = 136 Then Start = 21523: Count = 78: TrySpan = True: Exit Function
    If Id = 137 Then Start = 21601: Count = 56: TrySpan = True: Exit Function
    If Id = 138 Then Start = 21657: Count = 41: TrySpan = True: Exit Function
    If Id = 139 Then Start = 21698: Count = 144: TrySpan = True: Exit Function
    If Id = 140 Then Start = 21842: Count = 166: TrySpan = True: Exit Function
    If Id = 141 Then Start = 22008: Count = 189: TrySpan = True: Exit Function
    If Id = 142 Then Start = 22197: Count = 173: TrySpan = True: Exit Function
    If Id = 143 Then Start = 22370: Count = 264: TrySpan = True: Exit Function
    If Id = 144 Then Start = 22634: Count = 250: TrySpan = True: Exit Function
    If Id = 145 Then Start = 22884: Count = 43: TrySpan = True: Exit Function
    If Id = 146 Then Start = 22927: Count = 32: TrySpan = True: Exit Function
    If Id = 147 Then Start = 22959: Count = 49: TrySpan = True: Exit Function
    If Id = 148 Then Start = 23008: Count = 39: TrySpan = True: Exit Function
    If Id = 149 Then Start = 23047: Count = 32: TrySpan = True: Exit Function
    If Id = 150 Then Start = 23079: Count = 60: TrySpan = True: Exit Function
    If Id = 151 Then Start = 23139: Count = 214: TrySpan = True: Exit Function
    If Id = 152 Then Start = 23353: Count = 38: TrySpan = True: Exit Function
    If Id = 153 Then Start = 23391: Count = 52: TrySpan = True: Exit Function
    If Id = 154 Then Start = 23443: Count = 54: TrySpan = True: Exit Function
    If Id = 155 Then Start = 23497: Count = 37: TrySpan = True: Exit Function
    If Id = 156 Then Start = 23534: Count = 64: TrySpan = True: Exit Function
    If Id = 157 Then Start = 23598: Count = 78: TrySpan = True: Exit Function
    If Id = 158 Then Start = 23676: Count = 31: TrySpan = True: Exit Function
    If Id = 159 Then Start = 23707: Count = 16: TrySpan = True: Exit Function
    If Id = 160 Then Start = 23723: Count = 75: TrySpan = True: Exit Function
    If Id = 161 Then Start = 23798: Count = 108: TrySpan = True: Exit Function
    If Id = 162 Then Start = 23906: Count = 117: TrySpan = True: Exit Function
    If Id = 163 Then Start = 24023: Count = 80: TrySpan = True: Exit Function
    If Id = 164 Then Start = 24103: Count = 57: TrySpan = True: Exit Function
    If Id = 165 Then Start = 24160: Count = 40: TrySpan = True: Exit Function
    If Id = 166 Then Start = 24200: Count = 92: TrySpan = True: Exit Function
    If Id = 167 Then Start = 24292: Count = 134: TrySpan = True: Exit Function
    If Id = 168 Then Start = 24426: Count = 50: TrySpan = True: Exit Function
    If Id = 169 Then Start = 24476: Count = 29: TrySpan = True: Exit Function
    If Id = 170 Then Start = 24505: Count = 27: TrySpan = True: Exit Function
    If Id = 171 Then Start = 24532: Count = 19: TrySpan = True: Exit Function
    If Id = 172 Then Start = 24551: Count = 62: TrySpan = True: Exit Function
    If Id = 173 Then Start = 24613: Count = 77: TrySpan = True: Exit Function
    If Id = 174 Then Start = 24690: Count = 77: TrySpan = True: Exit Function
    If Id = 175 Then Start = 24767: Count = 77: TrySpan = True: Exit Function
    If Id = 176 Then Start = 24844: Count = 29: TrySpan = True: Exit Function
    If Id = 177 Then Start = 24873: Count = 43: TrySpan = True: Exit Function
    If Id = 178 Then Start = 24916: Count = 31: TrySpan = True: Exit Function
    If Id = 179 Then Start = 24947: Count = 31: TrySpan = True: Exit Function
    If Id = 180 Then Start = 24978: Count = 299: TrySpan = True: Exit Function
    If Id = 181 Then Start = 25277: Count = 52: TrySpan = True: Exit Function
    If Id = 182 Then Start = 25329: Count = 9: TrySpan = True: Exit Function
    If Id = 183 Then Start = 25338: Count = 7: TrySpan = True: Exit Function
    If Id = 184 Then Start = 25345: Count = 129: TrySpan = True: Exit Function
    If Id = 185 Then Start = 25474: Count = 60: TrySpan = True: Exit Function
    If Id = 186 Then Start = 25534: Count = 71: TrySpan = True: Exit Function
    If Id = 187 Then Start = 25605: Count = 65: TrySpan = True: Exit Function
    If Id = 188 Then Start = 25670: Count = 60: TrySpan = True: Exit Function
    If Id = 189 Then Start = 25730: Count = 136: TrySpan = True: Exit Function
    If Id = 190 Then Start = 25866: Count = 290: TrySpan = True: Exit Function
    If Id = 191 Then Start = 26156: Count = 58: TrySpan = True: Exit Function
    If Id = 192 Then Start = 26214: Count = 164: TrySpan = True: Exit Function
    If Id = 193 Then Start = 26378: Count = 169: TrySpan = True: Exit Function
    If Id = 194 Then Start = 26547: Count = 170: TrySpan = True: Exit Function
    If Id = 195 Then Start = 26717: Count = 175: TrySpan = True: Exit Function
    If Id = 196 Then Start = 26892: Count = 64: TrySpan = True: Exit Function
    If Id = 197 Then Start = 26956: Count = 52: TrySpan = True: Exit Function
    If Id = 198 Then Start = 27008: Count = 42: TrySpan = True: Exit Function
    If Id = 199 Then Start = 27050: Count = 57: TrySpan = True: Exit Function
    If Id = 200 Then Start = 27107: Count = 1: TrySpan = True: Exit Function
    If Id = 201 Then Start = 27108: Count = 406: TrySpan = True: Exit Function
    If Id = 202 Then Start = 27514: Count = 62: TrySpan = True: Exit Function
    If Id = 203 Then Start = 27576: Count = 60: TrySpan = True: Exit Function
    If Id = 204 Then Start = 27636: Count = 74: TrySpan = True: Exit Function
    If Id = 205 Then Start = 27710: Count = 61: TrySpan = True: Exit Function
    If Id = 206 Then Start = 27771: Count = 59: TrySpan = True: Exit Function
    If Id = 207 Then Start = 27830: Count = 178: TrySpan = True: Exit Function
    If Id = 208 Then Start = 28008: Count = 491: TrySpan = True: Exit Function
    If Id = 209 Then Start = 28499: Count = 283: TrySpan = True: Exit Function
    If Id = 210 Then Start = 28782: Count = 148: TrySpan = True: Exit Function
    If Id = 211 Then Start = 28930: Count = 168: TrySpan = True: Exit Function
    If Id = 212 Then Start = 29098: Count = 199: TrySpan = True: Exit Function
    If Id = 213 Then Start = 29297: Count = 304: TrySpan = True: Exit Function
    If Id = 214 Then Start = 29601: Count = 168: TrySpan = True: Exit Function
    If Id = 215 Then Start = 29769: Count = 96: TrySpan = True: Exit Function
    If Id = 216 Then Start = 29865: Count = 99: TrySpan = True: Exit Function
    If Id = 217 Then Start = 29964: Count = 302: TrySpan = True: Exit Function
    If Id = 218 Then Start = 30266: Count = 300: TrySpan = True: Exit Function
    If Id = 219 Then Start = 30566: Count = 312: TrySpan = True: Exit Function
    If Id = 220 Then Start = 30878: Count = 310: TrySpan = True: Exit Function
    If Id = 221 Then Start = 31188: Count = 304: TrySpan = True: Exit Function
    If Id = 222 Then Start = 31492: Count = 301: TrySpan = True: Exit Function
    If Id = 223 Then Start = 31793: Count = 303: TrySpan = True: Exit Function
    If Id = 224 Then Start = 32096: Count = 307: TrySpan = True: Exit Function
    If Id = 225 Then Start = 32403: Count = 328: TrySpan = True: Exit Function
    If Id = 226 Then Start = 32731: Count = 253: TrySpan = True: Exit Function
    If Id = 227 Then Start = 32984: Count = 280: TrySpan = True: Exit Function
    If Id = 228 Then Start = 33264: Count = 175: TrySpan = True: Exit Function
    If Id = 229 Then Start = 33439: Count = 174: TrySpan = True: Exit Function
    If Id = 230 Then Start = 33613: Count = 322: TrySpan = True: Exit Function
    If Id = 231 Then Start = 33935: Count = 324: TrySpan = True: Exit Function
    If Id = 232 Then Start = 34259: Count = 323: TrySpan = True: Exit Function
    If Id = 233 Then Start = 34582: Count = 301: TrySpan = True: Exit Function
    If Id = 234 Then Start = 34883: Count = 277: TrySpan = True: Exit Function
    If Id = 235 Then Start = 35160: Count = 65: TrySpan = True: Exit Function
    If Id = 236 Then Start = 35225: Count = 64: TrySpan = True: Exit Function
    If Id = 237 Then Start = 35289: Count = 192: TrySpan = True: Exit Function
    If Id = 238 Then Start = 35481: Count = 102: TrySpan = True: Exit Function
    If Id = 239 Then Start = 35583: Count = 47: TrySpan = True: Exit Function
    If Id = 240 Then Start = 35630: Count = 51: TrySpan = True: Exit Function
    If Id = 241 Then Start = 35681: Count = 40: TrySpan = True: Exit Function
    If Id = 242 Then Start = 35721: Count = 47: TrySpan = True: Exit Function
    If Id = 243 Then Start = 35768: Count = 152: TrySpan = True: Exit Function
    If Id = 244 Then Start = 35920: Count = 95: TrySpan = True: Exit Function
    If Id = 245 Then Start = 36015: Count = 75: TrySpan = True: Exit Function
    If Id = 246 Then Start = 36090: Count = 490: TrySpan = True: Exit Function
    If Id = 247 Then Start = 36580: Count = 366: TrySpan = True: Exit Function
    If Id = 248 Then Start = 36946: Count = 340: TrySpan = True: Exit Function
    If Id = 249 Then Start = 37286: Count = 76: TrySpan = True: Exit Function
    If Id = 250 Then Start = 37362: Count = 30: TrySpan = True: Exit Function
End Function
