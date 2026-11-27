UBE SOURCE 1 MODULE
Attribute UBE_Name = "LLVMTemplates"
' Generated from compiler/llvm/templates.json by bootstrap/tools/llvm-templates.ps1.
Public Const UnpackSingle As Long = 1
Public Const PackSingle As Long = 2
Public Const SingleAdd As Long = 3
Public Const SingleSubtract As Long = 4
Public Const SingleMultiply As Long = 5
Public Const SingleDivide As Long = 6
Public Const SingleNegate As Long = 7
Public Const SingleEqual As Long = 8
Public Const SingleNotEqual As Long = 9
Public Const SingleLess As Long = 10
Public Const SingleGreater As Long = 11
Public Const SingleLessEqual As Long = 12
Public Const SingleGreaterEqual As Long = 13
Public Const IntegerToSingle As Long = 14
Public Const UnpackDouble As Long = 15
Public Const PackDouble As Long = 16
Public Const DoubleAdd As Long = 17
Public Const DoubleSubtract As Long = 18
Public Const DoubleMultiply As Long = 19
Public Const DoubleDivide As Long = 20
Public Const DoubleNegate As Long = 21
Public Const DoubleEqual As Long = 22
Public Const DoubleNotEqual As Long = 23
Public Const DoubleLess As Long = 24
Public Const DoubleGreater As Long = 25
Public Const DoubleLessEqual As Long = 26
Public Const DoubleGreaterEqual As Long = 27
Public Const IntegerToDouble As Long = 28
Public Const SingleToDouble As Long = 29
Public Const DoubleToSingle As Long = 30
Public Const DoubleNonfinite As Long = 31
Public Const DoubleNonzero As Long = 32
Public Const DoubleSingleOverflow As Long = 33
Public Const DoubleIntegerOverflow As Long = 34
Public Const DoubleRoundInteger As Long = 35
Public Const IntrinsicMemoryCollect As Long = 36
Public Const IntrinsicManagedWorkspace As Long = 37
Public Const Branch As Long = 38
Public Const ConditionalBranch As Long = 39
Public Const Label As Long = 40
Public Const IntegerValue As Long = 41
Public Const LoadValue As Long = 42
Public Const StoreValue As Long = 43
Public Const ContextType As Long = 44
Public Const ProcedureStart As Long = 45
Public Const ValueParameter As Long = 46
Public Const ReferenceParameter As Long = 47
Public Const ProcedureBody As Long = 48
Public Const FunctionEnd As Long = 49
Public Const ContextFileType As Long = 50
Public Const ContextPrefix As Long = 51
Public Const ContextArrayRelease As Long = 52
Public Const ContextMiddle As Long = 53
Public Const EnsureModule As Long = 54
Public Const ContextSuffix As Long = 55
Public Const Entry As Long = 56
Public Const StoreError As Long = 57
Public Const FailureBranch As Long = 58
Public Const CallSuccess As Long = 59
Public Const CallSuccessBranch As Long = 60
Public Const ValueNonzero As Long = 61
Public Const BooleanSelect As Long = 62
Public Const TruncateValue As Long = 63
Public Const SignExtendValue As Long = 64
Public Const ZeroExtendValue As Long = 65
Public Const DifferentValues As Long = 66
Public Const ComplementValue As Long = 67
Public Const OverflowFlag As Long = 68
Public Const ArithmeticValue As Long = 69
Public Const ArithmeticAdd16 As Long = 70
Public Const ArithmeticSubtract16 As Long = 71
Public Const ArithmeticAdd32 As Long = 72
Public Const ArithmeticSubtract32 As Long = 73
Public Const ArithmeticAdd64 As Long = 74
Public Const ArithmeticSubtract64 As Long = 75
Public Const IntrinsicFileOpen As Long = 76
Public Const IntrinsicFileCreateNew As Long = 77
Public Const IntrinsicFileRead As Long = 78
Public Const IntrinsicFileWrite As Long = 79
Public Const IntrinsicFileClose As Long = 80
Public Const IntrinsicFileFlush As Long = 81
Public Const IntrinsicErrorSet As Long = 82
Public Const IntrinsicArrayLength As Long = 83
Public Const IntrinsicMemoryCopyBytes As Long = 84
Public Const IntrinsicArrayResize As Long = 85
Public Const IntrinsicArrayCopy As Long = 86
Public Const ContextAddress As Long = 87
Public Const ArgumentAddress As Long = 88
Public Const SlotAddress As Long = 89
Public Const TemporaryAddress As Long = 90
Public Const CellAddress As Long = 91
Public Const IndexedAddress As Long = 92
Public Const LoadPointer As Long = 93
Public Const StorePointer As Long = 94
Public Const StoreNullPointer As Long = 95
Public Const RetainBlock As Long = 96
Public Const PinBlock As Long = 97
Public Const ReleasePin As Long = 98
Public Const CollectMemory As Long = 99
Public Const ClearArray As Long = 100
Public Const BelowBound As Long = 101
Public Const AboveBound As Long = 102
Public Const EitherCondition As Long = 103
Public Const RelativeIndex As Long = 104
Public Const ElementOffset As Long = 105
Public Const LoadVolatileValue As Long = 106
Public Const StoreVolatileValue As Long = 107
Public Const StoreConstant As Long = 108
Public Const StoreVolatileConstant As Long = 109
Public Const EnsureModuleValue As Long = 110
Public Const ControlSite As Long = 111
Public Const ControlHandler As Long = 112
Public Const ControlZero As Long = 113
Public Const ControlArrayCopy As Long = 114
Public Const CompareEqual As Long = 115
Public Const CompareLessEqual As Long = 116
Public Const CompareGreaterEqual As Long = 117
Public Const BooleanAnd As Long = 118
Public Const BooleanInvert As Long = 119
Public Const IntegerAnd As Long = 120
Public Const IntegerOr As Long = 121
Public Const StoreErrorValue As Long = 122
Public Const ReturnFailureBranch As Long = 123
Public Const LoadError As Long = 124
Public Const CallStart As Long = 125
Public Const CallValueArgument As Long = 126
Public Const CallReferenceArgument As Long = 127
Public Const CallEnd As Long = 128
Public Const CallValue As Long = 129
Public Const ProcedurePointers As Long = 130
Public Const ModuleInitializeStart As Long = 131
Public Const FrameControls As Long = 132
Public Const AllocateSlot As Long = 133
Public Const StoreParameter As Long = 134
Public Const AllocateTemporary As Long = 135
Public Const AllocatePin As Long = 136
Public Const ProcedureDepth As Long = 137
Public Const FailureDispatchLabel As Long = 138
Public Const FailureHandlerDispatch As Long = 139
Public Const SwitchCase As Long = 140
Public Const SwitchEnd As Long = 141
Public Const FailureSkipDispatch As Long = 142
Public Const ReturnFailureLabel As Long = 143
Public Const ReturnDepthSuccess As Long = 144
Public Const ReturnDepthFailure As Long = 145
Public Const LoadResult As Long = 146
Public Const ReturnSuccessValue As Long = 147
Public Const ReturnFailedValue As Long = 148
Public Const ModuleEnsureDefinition As Long = 149
Public Const SourceLocation As Long = 150
Public Const TargetHeader As Long = 151
Public Const IntrinsicSystemCommandLine As Long = 152
Public Const IntrinsicSystemWrite As Long = 153
Public Const IntrinsicFileFinalPath As Long = 154
Public Const IntrinsicPathFullPath As Long = 155
Public Const IntrinsicPathCompareOrdinal As Long = 156
Public Const IntrinsicProcessStart As Long = 157
Public Const IntrinsicProcessWait As Long = 158
Public Const IntrinsicProcessTerminate As Long = 159
Public Const IntrinsicProcessClose As Long = 160
Public Const IntrinsicFileOpenDirectory As Long = 161
Public Const IntrinsicFileIdentity As Long = 162
Public Const IntrinsicFileLength As Long = 163
Public Const IntrinsicSystemExecutablePath As Long = 164
Public Const IntrinsicSystemMonotonicMilliseconds As Long = 165
Public Const IntrinsicDirectoryCreate As Long = 166
Public Const IntrinsicDirectoryRemove As Long = 167
Public Const IntrinsicFileDelete As Long = 168
Public Const IntrinsicFileReplace As Long = 169
Public Const IntrinsicPathKind As Long = 170
Public Const ArraySnapshot As Long = 171
Public Const SnapshotValue As Long = 172
Public Const AllocateAggregateTemporary As Long = 173
Public Const IntrinsicThreadCurrentId As Long = 174
Public Const IntrinsicThreadIsAlive As Long = 175
Public Const IntrinsicThreadWait As Long = 176
Public Const IntrinsicThreadRequestStop As Long = 177
Public Const IntrinsicThreadStopRequested As Long = 178
Public Const IntrinsicThreadYield As Long = 179
Public Const NullOwner As Long = 180
Public Const LoadLocalOwner As Long = 181
Public Const IncomingOwner As Long = 182
Public Const LoadTemporaryOwner As Long = 183
Public Const LoadPinOwner As Long = 184
Public Const NewOwner As Long = 185
Public Const OwnerAllocated As Long = 186
Public Const SetTemporaryOwner As Long = 187
Public Const OwnerPayload As Long = 188
Public Const DropOwner As Long = 189
Public Const ClearTemporaryOwner As Long = 190
Public Const AllocateLocalOwner As Long = 191
Public Const AllocateTemporaryOwner As Long = 192
Public Const SetLocalOwner As Long = 193
Public Const OwnerParameter As Long = 194
Public Const OwnerEntryGuard As Long = 195
Public Const BoxAddress As Long = 196
Public Const BoxTemporaryAddress As Long = 197
Public Const InstallOwnedArray As Long = 198
Public Const StoreBoxParameter As Long = 199
Public Const RetainOwner As Long = 200
Public Const StartThread As Long = 201
Public Const ThreadThunkStart As Long = 202
Public Const CaptureAddress As Long = 203
Public Const LoadOwnerPointer As Long = 204
Public Const BooleanConstant As Long = 205
Public Const ThreadThunkEnd As Long = 206
Public Const NewArrayOwner As Long = 207
Public Const ArithmeticMultiply16 As Long = 208
Public Const ArithmeticMultiply32 As Long = 209
Public Const ArithmeticMultiply64 As Long = 210
Public Const BothConditions As Long = 211
Public Const SafeRemainderDivisor As Long = 212
Public Const DivisionValue As Long = 213
Public Const RemainderValue As Long = 214
Public Const IntrinsicArrayMove As Long = 215
Public Const TextLiteralStart As Long = 216
Public Const TextLiteralByte As Long = 217
Public Const TextLiteralLastByte As Long = 218
Public Const TextLiteralEnd As Long = 219
Public Const TextLiteralAddress As Long = 220
Public Const TextRootLoad As Long = 221
Public Const TextRootStore As Long = 222
Public Const TextRootTake As Long = 223
Public Const ManagedEntryFrame As Long = 224
Public Const ManagedTextSlots As Long = 225
Public Const ManagedTextAlias As Long = 226
Public Const ManagedSymbolRoot As Long = 227
Public Const ManagedArraySymbolRoot As Long = 228
Public Const ManagedTemporaryRoot As Long = 229
Public Const ManagedArrayTemporaryRoot As Long = 230
Public Const ManagedRestoreRoots As Long = 231
Public Const ManagedReturnValue As Long = 232
Public Const ManagedDiscardReturn As Long = 233
Public Const ManagedOffsetsStart As Long = 234
Public Const ManagedOffsetsEnd As Long = 235
Public Const ManagedValueLayout As Long = 236
Public Const ManagedStoreValue As Long = 237
Public Const ManagedGlobalOffsetsStart As Long = 238
Public Const ManagedGlobalArraysStart As Long = 239
Public Const ManagedGlobalArrayEntry As Long = 240
Public Const ManagedGlobalArrayLastEntry As Long = 241
Public Const ManagedGlobalLayout As Long = 242
Public Const ManagedProcedureDepth As Long = 243
Public Const ManagedProjectInitialize As Long = 244
Public Const ManagedOwnerLayout As Long = 245
Public Const ManagedLocalOwnerRoot As Long = 246
Public Const ManagedTemporaryOwnerRoot As Long = 247
Public Const ManagedIncomingOwnerRoot As Long = 248
Public Const ManagedPinRoot As Long = 249
Public Const AttachManagedOwner As Long = 250
Public Const AttachManagedArrayOwner As Long = 251
Public Const IntrinsicManagedBeginCollection As Long = 252
Public Const IntrinsicManagedEndCollection As Long = 253
Public Const IntrinsicManagedSnapshotCounts As Long = 254
Public Const IntrinsicManagedAllocationAt As Long = 255
Public Const IntrinsicManagedRootAt As Long = 256
Public Const IntrinsicManagedMark As Long = 257
Public Const IntrinsicManagedMarked As Long = 258
Public Const IntrinsicManagedEdgeCount As Long = 259
Public Const IntrinsicManagedEdgeAt As Long = 260
Public Const IntrinsicManagedSealCollection As Long = 261
Public Const IntrinsicManagedReclaim As Long = 262
Public Const IntrinsicTextByteLength As Long = 263
Public Const IntrinsicTextScalarLength As Long = 264
Public Const IntrinsicTextReadByte As Long = 265
Public Const IntrinsicTextCreate As Long = 266
Public Const IntrinsicTextWriteByte As Long = 267
Public Const IntrinsicTextPublish As Long = 268
Public Const IntrinsicTextAbandon As Long = 269
Public Const ManagedCaptureOffsetsStart As Long = 270
Public Const ManagedCaptureOwnersStart As Long = 271
Public Const ManagedCaptureLayout As Long = 272
Public Const AttachManagedCapture As Long = 273
Public Const CapturePayloadAddress As Long = 274
Public Const ClearCapturedOwner As Long = 275
Public Const ManagedSafepoint As Long = 276
Public Const ManagedTemporaryTable As Long = 277
Public Const ManagedTextTableEntry As Long = 278
Public Const ManagedTemporaryTableEntry As Long = 279
Public Const ManagedRetireTemporaries As Long = 280
Public Const ManagedRetireDefinition As Long = 281
Public Const IntrinsicArrayResizeManaged As Long = 282
Public Const IntrinsicArrayCopyManaged As Long = 283
Public Const ControlManagedArrayCopyStart As Long = 284
Public Const ManagedLayoutCallEnd As Long = 285
Public Const HeapFrame As Long = 286
Public Const ReleaseFrame As Long = 287
Public Const StackFrame As Long = 288
Public Const VariantTag As Long = 289
Public Const IntrinsicVariantTag As Long = 290
Public Const VariantScalar As Long = 291
Public Const VariantBoxValue As Long = 292
Public Const VariantBoxReference As Long = 293
Public Const VariantPayload As Long = 294
Public Const VariantCreatePlainRecord As Long = 295
Public Const VariantCreateRecord As Long = 296
Public Const VariantPublish As Long = 297
Public Const VariantMatchRecord As Long = 298
Public Const AllocateVariantConversion As Long = 299
Public Const StoreVariantConversion As Long = 300
Public Const LoadVariantConversion As Long = 301
Public Const LoadManagedExpression As Long = 302
Public Const EnumerationLoad As Long = 303
Public Const EnumerationStoreIndex As Long = 304
Public Const EnumerationPayload As Long = 305
Public Const EnumerationRoot As Long = 306
Public Const EnumerationCapture As Long = 307
Public Const EnumerationRelease As Long = 308
Public Const ObjectDescriptor As Long = 309
Public Const ObjectCreate As Long = 310
Public Const ObjectPublish As Long = 311
Public Const IntrinsicMonitorTryEnter As Long = 312
Public Const IntrinsicMonitorLeave As Long = 313
Public Const IntrinsicMonitorYield As Long = 314
Public Const MonitorSlots As Long = 315
Public Const MonitorCapture As Long = 316
Public Const MonitorAcquire As Long = 317
Public Const MonitorAcquired As Long = 318
Public Const MonitorRelease As Long = 319
Public Const ConstructState As Long = 320
Public Const ConstructGuard As Long = 321
Public Const VariantCreateObject As Long = 322
Public Const VariantReference As Long = 323
Public Const ObjectNominal As Long = 324
Public Const VariantCreateObjectDynamic As Long = 325
Public Const MonitorRequire As Long = 326
Public Const TemplateCount As Long = 326
Public Const CatalogLength As Long = 48582
Public Const CatalogByteSum As Long = 3892537

' Returns one exact span without changing caller outputs for an unknown identity.
Public Function TrySpan(ByVal Id As Long, ByRef Start As Long, ByRef Count As Long) As Boolean
    If Id = 1 Then Start = 0: Count = 86: TrySpan = True: Exit Function
    If Id = 2 Then Start = 86: Count = 85: TrySpan = True: Exit Function
    If Id = 3 Then Start = 171: Count = 33: TrySpan = True: Exit Function
    If Id = 4 Then Start = 204: Count = 33: TrySpan = True: Exit Function
    If Id = 5 Then Start = 237: Count = 33: TrySpan = True: Exit Function
    If Id = 6 Then Start = 270: Count = 33: TrySpan = True: Exit Function
    If Id = 7 Then Start = 303: Count = 26: TrySpan = True: Exit Function
    If Id = 8 Then Start = 329: Count = 37: TrySpan = True: Exit Function
    If Id = 9 Then Start = 366: Count = 37: TrySpan = True: Exit Function
    If Id = 10 Then Start = 403: Count = 37: TrySpan = True: Exit Function
    If Id = 11 Then Start = 440: Count = 37: TrySpan = True: Exit Function
    If Id = 12 Then Start = 477: Count = 37: TrySpan = True: Exit Function
    If Id = 13 Then Start = 514: Count = 37: TrySpan = True: Exit Function
    If Id = 14 Then Start = 551: Count = 35: TrySpan = True: Exit Function
    If Id = 15 Then Start = 586: Count = 37: TrySpan = True: Exit Function
    If Id = 16 Then Start = 623: Count = 37: TrySpan = True: Exit Function
    If Id = 17 Then Start = 660: Count = 34: TrySpan = True: Exit Function
    If Id = 18 Then Start = 694: Count = 34: TrySpan = True: Exit Function
    If Id = 19 Then Start = 728: Count = 34: TrySpan = True: Exit Function
    If Id = 20 Then Start = 762: Count = 34: TrySpan = True: Exit Function
    If Id = 21 Then Start = 796: Count = 27: TrySpan = True: Exit Function
    If Id = 22 Then Start = 823: Count = 38: TrySpan = True: Exit Function
    If Id = 23 Then Start = 861: Count = 38: TrySpan = True: Exit Function
    If Id = 24 Then Start = 899: Count = 38: TrySpan = True: Exit Function
    If Id = 25 Then Start = 937: Count = 38: TrySpan = True: Exit Function
    If Id = 26 Then Start = 975: Count = 38: TrySpan = True: Exit Function
    If Id = 27 Then Start = 1013: Count = 38: TrySpan = True: Exit Function
    If Id = 28 Then Start = 1051: Count = 36: TrySpan = True: Exit Function
    If Id = 29 Then Start = 1087: Count = 37: TrySpan = True: Exit Function
    If Id = 30 Then Start = 1124: Count = 39: TrySpan = True: Exit Function
    If Id = 31 Then Start = 1163: Count = 268: TrySpan = True: Exit Function
    If Id = 32 Then Start = 1431: Count = 36: TrySpan = True: Exit Function
    If Id = 33 Then Start = 1467: Count = 273: TrySpan = True: Exit Function
    If Id = 34 Then Start = 1740: Count = 178: TrySpan = True: Exit Function
    If Id = 35 Then Start = 1918: Count = 862: TrySpan = True: Exit Function
    If Id = 36 Then Start = 2780: Count = 153: TrySpan = True: Exit Function
    If Id = 37 Then Start = 2933: Count = 330: TrySpan = True: Exit Function
    If Id = 38 Then Start = 3263: Count = 16: TrySpan = True: Exit Function
    If Id = 39 Then Start = 3279: Count = 39: TrySpan = True: Exit Function
    If Id = 40 Then Start = 3318: Count = 5: TrySpan = True: Exit Function
    If Id = 41 Then Start = 3323: Count = 24: TrySpan = True: Exit Function
    If Id = 42 Then Start = 3347: Count = 55: TrySpan = True: Exit Function
    If Id = 43 Then Start = 3402: Count = 54: TrySpan = True: Exit Function
    If Id = 44 Then Start = 3456: Count = 307: TrySpan = True: Exit Function
    If Id = 45 Then Start = 3763: Count = 41: TrySpan = True: Exit Function
    If Id = 46 Then Start = 3804: Count = 14: TrySpan = True: Exit Function
    If Id = 47 Then Start = 3818: Count = 14: TrySpan = True: Exit Function
    If Id = 48 Then Start = 3832: Count = 3: TrySpan = True: Exit Function
    If Id = 49 Then Start = 3835: Count = 1: TrySpan = True: Exit Function
    If Id = 50 Then Start = 3836: Count = 48: TrySpan = True: Exit Function
    If Id = 51 Then Start = 3884: Count = 2330: TrySpan = True: Exit Function
    If Id = 52 Then Start = 6214: Count = 121: TrySpan = True: Exit Function
    If Id = 53 Then Start = 6335: Count = 382: TrySpan = True: Exit Function
    If Id = 54 Then Start = 6717: Count = 58: TrySpan = True: Exit Function
    If Id = 55 Then Start = 6775: Count = 20: TrySpan = True: Exit Function
    If Id = 56 Then Start = 6795: Count = 1198: TrySpan = True: Exit Function
    If Id = 57 Then Start = 7993: Count = 51: TrySpan = True: Exit Function
    If Id = 58 Then Start = 8044: Count = 28: TrySpan = True: Exit Function
    If Id = 59 Then Start = 8072: Count = 43: TrySpan = True: Exit Function
    If Id = 60 Then Start = 8115: Count = 51: TrySpan = True: Exit Function
    If Id = 61 Then Start = 8166: Count = 30: TrySpan = True: Exit Function
    If Id = 62 Then Start = 8196: Count = 40: TrySpan = True: Exit Function
    If Id = 63 Then Start = 8236: Count = 33: TrySpan = True: Exit Function
    If Id = 64 Then Start = 8269: Count = 32: TrySpan = True: Exit Function
    If Id = 65 Then Start = 8301: Count = 32: TrySpan = True: Exit Function
    If Id = 66 Then Start = 8333: Count = 34: TrySpan = True: Exit Function
    If Id = 67 Then Start = 8367: Count = 28: TrySpan = True: Exit Function
    If Id = 68 Then Start = 8395: Count = 44: TrySpan = True: Exit Function
    If Id = 69 Then Start = 8439: Count = 44: TrySpan = True: Exit Function
    If Id = 70 Then Start = 8483: Count = 77: TrySpan = True: Exit Function
    If Id = 71 Then Start = 8560: Count = 77: TrySpan = True: Exit Function
    If Id = 72 Then Start = 8637: Count = 77: TrySpan = True: Exit Function
    If Id = 73 Then Start = 8714: Count = 77: TrySpan = True: Exit Function
    If Id = 74 Then Start = 8791: Count = 77: TrySpan = True: Exit Function
    If Id = 75 Then Start = 8868: Count = 77: TrySpan = True: Exit Function
    If Id = 76 Then Start = 8945: Count = 380: TrySpan = True: Exit Function
    If Id = 77 Then Start = 9325: Count = 393: TrySpan = True: Exit Function
    If Id = 78 Then Start = 9718: Count = 408: TrySpan = True: Exit Function
    If Id = 79 Then Start = 10126: Count = 407: TrySpan = True: Exit Function
    If Id = 80 Then Start = 10533: Count = 299: TrySpan = True: Exit Function
    If Id = 81 Then Start = 10832: Count = 299: TrySpan = True: Exit Function
    If Id = 82 Then Start = 11131: Count = 314: TrySpan = True: Exit Function
    If Id = 83 Then Start = 11445: Count = 228: TrySpan = True: Exit Function
    If Id = 84 Then Start = 11673: Count = 266: TrySpan = True: Exit Function
    If Id = 85 Then Start = 11939: Count = 347: TrySpan = True: Exit Function
    If Id = 86 Then Start = 12286: Count = 321: TrySpan = True: Exit Function
    If Id = 87 Then Start = 12607: Count = 58: TrySpan = True: Exit Function
    If Id = 88 Then Start = 12665: Count = 48: TrySpan = True: Exit Function
    If Id = 89 Then Start = 12713: Count = 49: TrySpan = True: Exit Function
    If Id = 90 Then Start = 12762: Count = 49: TrySpan = True: Exit Function
    If Id = 91 Then Start = 12811: Count = 47: TrySpan = True: Exit Function
    If Id = 92 Then Start = 12858: Count = 49: TrySpan = True: Exit Function
    If Id = 93 Then Start = 12907: Count = 29: TrySpan = True: Exit Function
    If Id = 94 Then Start = 12936: Count = 28: TrySpan = True: Exit Function
    If Id = 95 Then Start = 12964: Count = 27: TrySpan = True: Exit Function
    If Id = 96 Then Start = 12991: Count = 40: TrySpan = True: Exit Function
    If Id = 97 Then Start = 13031: Count = 55: TrySpan = True: Exit Function
    If Id = 98 Then Start = 13086: Count = 162: TrySpan = True: Exit Function
    If Id = 99 Then Start = 13248: Count = 47: TrySpan = True: Exit Function
    If Id = 100 Then Start = 13295: Count = 49: TrySpan = True: Exit Function
    If Id = 101 Then Start = 13344: Count = 35: TrySpan = True: Exit Function
    If Id = 102 Then Start = 13379: Count = 35: TrySpan = True: Exit Function
    If Id = 103 Then Start = 13414: Count = 28: TrySpan = True: Exit Function
    If Id = 104 Then Start = 13442: Count = 30: TrySpan = True: Exit Function
    If Id = 105 Then Start = 13472: Count = 28: TrySpan = True: Exit Function
    If Id = 106 Then Start = 13500: Count = 64: TrySpan = True: Exit Function
    If Id = 107 Then Start = 13564: Count = 63: TrySpan = True: Exit Function
    If Id = 108 Then Start = 13627: Count = 52: TrySpan = True: Exit Function
    If Id = 109 Then Start = 13679: Count = 61: TrySpan = True: Exit Function
    If Id = 110 Then Start = 13740: Count = 50: TrySpan = True: Exit Function
    If Id = 111 Then Start = 13790: Count = 34: TrySpan = True: Exit Function
    If Id = 112 Then Start = 13824: Count = 36: TrySpan = True: Exit Function
    If Id = 113 Then Start = 13860: Count = 30: TrySpan = True: Exit Function
    If Id = 114 Then Start = 13890: Count = 87: TrySpan = True: Exit Function
    If Id = 115 Then Start = 13977: Count = 34: TrySpan = True: Exit Function
    If Id = 116 Then Start = 14011: Count = 35: TrySpan = True: Exit Function
    If Id = 117 Then Start = 14046: Count = 35: TrySpan = True: Exit Function
    If Id = 118 Then Start = 14081: Count = 29: TrySpan = True: Exit Function
    If Id = 119 Then Start = 14110: Count = 28: TrySpan = True: Exit Function
    If Id = 120 Then Start = 14138: Count = 30: TrySpan = True: Exit Function
    If Id = 121 Then Start = 14168: Count = 29: TrySpan = True: Exit Function
    If Id = 122 Then Start = 14197: Count = 53: TrySpan = True: Exit Function
    If Id = 123 Then Start = 14250: Count = 23: TrySpan = True: Exit Function
    If Id = 124 Then Start = 14273: Count = 54: TrySpan = True: Exit Function
    If Id = 125 Then Start = 14327: Count = 49: TrySpan = True: Exit Function
    If Id = 126 Then Start = 14376: Count = 11: TrySpan = True: Exit Function
    If Id = 127 Then Start = 14387: Count = 11: TrySpan = True: Exit Function
    If Id = 128 Then Start = 14398: Count = 1: TrySpan = True: Exit Function
    If Id = 129 Then Start = 14399: Count = 43: TrySpan = True: Exit Function
    If Id = 130 Then Start = 14442: Count = 132: TrySpan = True: Exit Function
    If Id = 131 Then Start = 14574: Count = 134: TrySpan = True: Exit Function
    If Id = 132 Then Start = 14708: Count = 410: TrySpan = True: Exit Function
    If Id = 133 Then Start = 15118: Count = 60: TrySpan = True: Exit Function
    If Id = 134 Then Start = 15178: Count = 61: TrySpan = True: Exit Function
    If Id = 135 Then Start = 15239: Count = 60: TrySpan = True: Exit Function
    If Id = 136 Then Start = 15299: Count = 91: TrySpan = True: Exit Function
    If Id = 137 Then Start = 15390: Count = 482: TrySpan = True: Exit Function
    If Id = 138 Then Start = 15872: Count = 17: TrySpan = True: Exit Function
    If Id = 139 Then Start = 15889: Count = 555: TrySpan = True: Exit Function
    If Id = 140 Then Start = 16444: Count = 24: TrySpan = True: Exit Function
    If Id = 141 Then Start = 16468: Count = 3: TrySpan = True: Exit Function
    If Id = 142 Then Start = 16471: Count = 64: TrySpan = True: Exit Function
    If Id = 143 Then Start = 16535: Count = 12: TrySpan = True: Exit Function
    If Id = 144 Then Start = 16547: Count = 191: TrySpan = True: Exit Function
    If Id = 145 Then Start = 16738: Count = 199: TrySpan = True: Exit Function
    If Id = 146 Then Start = 16937: Count = 59: TrySpan = True: Exit Function
    If Id = 147 Then Start = 16996: Count = 91: TrySpan = True: Exit Function
    If Id = 148 Then Start = 17087: Count = 37: TrySpan = True: Exit Function
    If Id = 149 Then Start = 17124: Count = 976: TrySpan = True: Exit Function
    If Id = 150 Then Start = 18100: Count = 44: TrySpan = True: Exit Function
    If Id = 151 Then Start = 18144: Count = 66: TrySpan = True: Exit Function
    If Id = 152 Then Start = 18210: Count = 331: TrySpan = True: Exit Function
    If Id = 153 Then Start = 18541: Count = 397: TrySpan = True: Exit Function
    If Id = 154 Then Start = 18938: Count = 368: TrySpan = True: Exit Function
    If Id = 155 Then Start = 19306: Count = 366: TrySpan = True: Exit Function
    If Id = 156 Then Start = 19672: Count = 349: TrySpan = True: Exit Function
    If Id = 157 Then Start = 20021: Count = 398: TrySpan = True: Exit Function
    If Id = 158 Then Start = 20419: Count = 373: TrySpan = True: Exit Function
    If Id = 159 Then Start = 20792: Count = 306: TrySpan = True: Exit Function
    If Id = 160 Then Start = 21098: Count = 302: TrySpan = True: Exit Function
    If Id = 161 Then Start = 21400: Count = 327: TrySpan = True: Exit Function
    If Id = 162 Then Start = 21727: Count = 326: TrySpan = True: Exit Function
    If Id = 163 Then Start = 22053: Count = 324: TrySpan = True: Exit Function
    If Id = 164 Then Start = 22377: Count = 330: TrySpan = True: Exit Function
    If Id = 165 Then Start = 22707: Count = 301: TrySpan = True: Exit Function
    If Id = 166 Then Start = 23008: Count = 305: TrySpan = True: Exit Function
    If Id = 167 Then Start = 23313: Count = 305: TrySpan = True: Exit Function
    If Id = 168 Then Start = 23618: Count = 300: TrySpan = True: Exit Function
    If Id = 169 Then Start = 23918: Count = 325: TrySpan = True: Exit Function
    If Id = 170 Then Start = 24243: Count = 322: TrySpan = True: Exit Function
    If Id = 171 Then Start = 24565: Count = 78: TrySpan = True: Exit Function
    If Id = 172 Then Start = 24643: Count = 56: TrySpan = True: Exit Function
    If Id = 173 Then Start = 24699: Count = 60: TrySpan = True: Exit Function
    If Id = 174 Then Start = 24759: Count = 144: TrySpan = True: Exit Function
    If Id = 175 Then Start = 24903: Count = 166: TrySpan = True: Exit Function
    If Id = 176 Then Start = 25069: Count = 189: TrySpan = True: Exit Function
    If Id = 177 Then Start = 25258: Count = 173: TrySpan = True: Exit Function
    If Id = 178 Then Start = 25431: Count = 264: TrySpan = True: Exit Function
    If Id = 179 Then Start = 25695: Count = 250: TrySpan = True: Exit Function
    If Id = 180 Then Start = 25945: Count = 43: TrySpan = True: Exit Function
    If Id = 181 Then Start = 25988: Count = 32: TrySpan = True: Exit Function
    If Id = 182 Then Start = 26020: Count = 49: TrySpan = True: Exit Function
    If Id = 183 Then Start = 26069: Count = 39: TrySpan = True: Exit Function
    If Id = 184 Then Start = 26108: Count = 32: TrySpan = True: Exit Function
    If Id = 185 Then Start = 26140: Count = 60: TrySpan = True: Exit Function
    If Id = 186 Then Start = 26200: Count = 214: TrySpan = True: Exit Function
    If Id = 187 Then Start = 26414: Count = 38: TrySpan = True: Exit Function
    If Id = 188 Then Start = 26452: Count = 52: TrySpan = True: Exit Function
    If Id = 189 Then Start = 26504: Count = 54: TrySpan = True: Exit Function
    If Id = 190 Then Start = 26558: Count = 37: TrySpan = True: Exit Function
    If Id = 191 Then Start = 26595: Count = 91: TrySpan = True: Exit Function
    If Id = 192 Then Start = 26686: Count = 105: TrySpan = True: Exit Function
    If Id = 193 Then Start = 26791: Count = 31: TrySpan = True: Exit Function
    If Id = 194 Then Start = 26822: Count = 16: TrySpan = True: Exit Function
    If Id = 195 Then Start = 26838: Count = 75: TrySpan = True: Exit Function
    If Id = 196 Then Start = 26913: Count = 108: TrySpan = True: Exit Function
    If Id = 197 Then Start = 27021: Count = 117: TrySpan = True: Exit Function
    If Id = 198 Then Start = 27138: Count = 80: TrySpan = True: Exit Function
    If Id = 199 Then Start = 27218: Count = 57: TrySpan = True: Exit Function
    If Id = 200 Then Start = 27275: Count = 40: TrySpan = True: Exit Function
    If Id = 201 Then Start = 27315: Count = 92: TrySpan = True: Exit Function
    If Id = 202 Then Start = 27407: Count = 134: TrySpan = True: Exit Function
    If Id = 203 Then Start = 27541: Count = 50: TrySpan = True: Exit Function
    If Id = 204 Then Start = 27591: Count = 29: TrySpan = True: Exit Function
    If Id = 205 Then Start = 27620: Count = 27: TrySpan = True: Exit Function
    If Id = 206 Then Start = 27647: Count = 19: TrySpan = True: Exit Function
    If Id = 207 Then Start = 27666: Count = 62: TrySpan = True: Exit Function
    If Id = 208 Then Start = 27728: Count = 77: TrySpan = True: Exit Function
    If Id = 209 Then Start = 27805: Count = 77: TrySpan = True: Exit Function
    If Id = 210 Then Start = 27882: Count = 77: TrySpan = True: Exit Function
    If Id = 211 Then Start = 27959: Count = 29: TrySpan = True: Exit Function
    If Id = 212 Then Start = 27988: Count = 43: TrySpan = True: Exit Function
    If Id = 213 Then Start = 28031: Count = 31: TrySpan = True: Exit Function
    If Id = 214 Then Start = 28062: Count = 31: TrySpan = True: Exit Function
    If Id = 215 Then Start = 28093: Count = 299: TrySpan = True: Exit Function
    If Id = 216 Then Start = 28392: Count = 52: TrySpan = True: Exit Function
    If Id = 217 Then Start = 28444: Count = 9: TrySpan = True: Exit Function
    If Id = 218 Then Start = 28453: Count = 7: TrySpan = True: Exit Function
    If Id = 219 Then Start = 28460: Count = 129: TrySpan = True: Exit Function
    If Id = 220 Then Start = 28589: Count = 60: TrySpan = True: Exit Function
    If Id = 221 Then Start = 28649: Count = 71: TrySpan = True: Exit Function
    If Id = 222 Then Start = 28720: Count = 65: TrySpan = True: Exit Function
    If Id = 223 Then Start = 28785: Count = 60: TrySpan = True: Exit Function
    If Id = 224 Then Start = 28845: Count = 152: TrySpan = True: Exit Function
    If Id = 225 Then Start = 28997: Count = 259: TrySpan = True: Exit Function
    If Id = 226 Then Start = 29256: Count = 58: TrySpan = True: Exit Function
    If Id = 227 Then Start = 29314: Count = 180: TrySpan = True: Exit Function
    If Id = 228 Then Start = 29494: Count = 185: TrySpan = True: Exit Function
    If Id = 229 Then Start = 29679: Count = 186: TrySpan = True: Exit Function
    If Id = 230 Then Start = 29865: Count = 191: TrySpan = True: Exit Function
    If Id = 231 Then Start = 30056: Count = 64: TrySpan = True: Exit Function
    If Id = 232 Then Start = 30120: Count = 52: TrySpan = True: Exit Function
    If Id = 233 Then Start = 30172: Count = 42: TrySpan = True: Exit Function
    If Id = 234 Then Start = 30214: Count = 57: TrySpan = True: Exit Function
    If Id = 235 Then Start = 30271: Count = 1: TrySpan = True: Exit Function
    If Id = 236 Then Start = 30272: Count = 406: TrySpan = True: Exit Function
    If Id = 237 Then Start = 30678: Count = 62: TrySpan = True: Exit Function
    If Id = 238 Then Start = 30740: Count = 60: TrySpan = True: Exit Function
    If Id = 239 Then Start = 30800: Count = 74: TrySpan = True: Exit Function
    If Id = 240 Then Start = 30874: Count = 61: TrySpan = True: Exit Function
    If Id = 241 Then Start = 30935: Count = 59: TrySpan = True: Exit Function
    If Id = 242 Then Start = 30994: Count = 178: TrySpan = True: Exit Function
    If Id = 243 Then Start = 31172: Count = 548: TrySpan = True: Exit Function
    If Id = 244 Then Start = 31720: Count = 283: TrySpan = True: Exit Function
    If Id = 245 Then Start = 32003: Count = 148: TrySpan = True: Exit Function
    If Id = 246 Then Start = 32151: Count = 184: TrySpan = True: Exit Function
    If Id = 247 Then Start = 32335: Count = 215: TrySpan = True: Exit Function
    If Id = 248 Then Start = 32550: Count = 350: TrySpan = True: Exit Function
    If Id = 249 Then Start = 32900: Count = 184: TrySpan = True: Exit Function
    If Id = 250 Then Start = 33084: Count = 96: TrySpan = True: Exit Function
    If Id = 251 Then Start = 33180: Count = 99: TrySpan = True: Exit Function
    If Id = 252 Then Start = 33279: Count = 302: TrySpan = True: Exit Function
    If Id = 253 Then Start = 33581: Count = 300: TrySpan = True: Exit Function
    If Id = 254 Then Start = 33881: Count = 312: TrySpan = True: Exit Function
    If Id = 255 Then Start = 34193: Count = 310: TrySpan = True: Exit Function
    If Id = 256 Then Start = 34503: Count = 304: TrySpan = True: Exit Function
    If Id = 257 Then Start = 34807: Count = 301: TrySpan = True: Exit Function
    If Id = 258 Then Start = 35108: Count = 303: TrySpan = True: Exit Function
    If Id = 259 Then Start = 35411: Count = 307: TrySpan = True: Exit Function
    If Id = 260 Then Start = 35718: Count = 328: TrySpan = True: Exit Function
    If Id = 261 Then Start = 36046: Count = 253: TrySpan = True: Exit Function
    If Id = 262 Then Start = 36299: Count = 280: TrySpan = True: Exit Function
    If Id = 263 Then Start = 36579: Count = 175: TrySpan = True: Exit Function
    If Id = 264 Then Start = 36754: Count = 174: TrySpan = True: Exit Function
    If Id = 265 Then Start = 36928: Count = 322: TrySpan = True: Exit Function
    If Id = 266 Then Start = 37250: Count = 324: TrySpan = True: Exit Function
    If Id = 267 Then Start = 37574: Count = 323: TrySpan = True: Exit Function
    If Id = 268 Then Start = 37897: Count = 301: TrySpan = True: Exit Function
    If Id = 269 Then Start = 38198: Count = 277: TrySpan = True: Exit Function
    If Id = 270 Then Start = 38475: Count = 65: TrySpan = True: Exit Function
    If Id = 271 Then Start = 38540: Count = 64: TrySpan = True: Exit Function
    If Id = 272 Then Start = 38604: Count = 192: TrySpan = True: Exit Function
    If Id = 273 Then Start = 38796: Count = 102: TrySpan = True: Exit Function
    If Id = 274 Then Start = 38898: Count = 47: TrySpan = True: Exit Function
    If Id = 275 Then Start = 38945: Count = 51: TrySpan = True: Exit Function
    If Id = 276 Then Start = 38996: Count = 40: TrySpan = True: Exit Function
    If Id = 277 Then Start = 39036: Count = 65: TrySpan = True: Exit Function
    If Id = 278 Then Start = 39101: Count = 152: TrySpan = True: Exit Function
    If Id = 279 Then Start = 39253: Count = 95: TrySpan = True: Exit Function
    If Id = 280 Then Start = 39348: Count = 75: TrySpan = True: Exit Function
    If Id = 281 Then Start = 39423: Count = 490: TrySpan = True: Exit Function
    If Id = 282 Then Start = 39913: Count = 366: TrySpan = True: Exit Function
    If Id = 283 Then Start = 40279: Count = 340: TrySpan = True: Exit Function
    If Id = 284 Then Start = 40619: Count = 76: TrySpan = True: Exit Function
    If Id = 285 Then Start = 40695: Count = 30: TrySpan = True: Exit Function
    If Id = 286 Then Start = 40725: Count = 620: TrySpan = True: Exit Function
    If Id = 287 Then Start = 41345: Count = 55: TrySpan = True: Exit Function
    If Id = 288 Then Start = 41400: Count = 528: TrySpan = True: Exit Function
    If Id = 289 Then Start = 41928: Count = 61: TrySpan = True: Exit Function
    If Id = 290 Then Start = 41989: Count = 165: TrySpan = True: Exit Function
    If Id = 291 Then Start = 42154: Count = 64: TrySpan = True: Exit Function
    If Id = 292 Then Start = 42218: Count = 88: TrySpan = True: Exit Function
    If Id = 293 Then Start = 42306: Count = 105: TrySpan = True: Exit Function
    If Id = 294 Then Start = 42411: Count = 60: TrySpan = True: Exit Function
    If Id = 295 Then Start = 42471: Count = 114: TrySpan = True: Exit Function
    If Id = 296 Then Start = 42585: Count = 133: TrySpan = True: Exit Function
    If Id = 297 Then Start = 42718: Count = 73: TrySpan = True: Exit Function
    If Id = 298 Then Start = 42791: Count = 90: TrySpan = True: Exit Function
    If Id = 299 Then Start = 42881: Count = 71: TrySpan = True: Exit Function
    If Id = 300 Then Start = 42952: Count = 43: TrySpan = True: Exit Function
    If Id = 301 Then Start = 42995: Count = 44: TrySpan = True: Exit Function
    If Id = 302 Then Start = 43039: Count = 56: TrySpan = True: Exit Function
    If Id = 303 Then Start = 43095: Count = 114: TrySpan = True: Exit Function
    If Id = 304 Then Start = 43209: Count = 79: TrySpan = True: Exit Function
    If Id = 305 Then Start = 43288: Count = 112: TrySpan = True: Exit Function
    If Id = 306 Then Start = 43400: Count = 396: TrySpan = True: Exit Function
    If Id = 307 Then Start = 43796: Count = 939: TrySpan = True: Exit Function
    If Id = 308 Then Start = 44735: Count = 517: TrySpan = True: Exit Function
    If Id = 309 Then Start = 45252: Count = 48: TrySpan = True: Exit Function
    If Id = 310 Then Start = 45300: Count = 114: TrySpan = True: Exit Function
    If Id = 311 Then Start = 45414: Count = 146: TrySpan = True: Exit Function
    If Id = 312 Then Start = 45560: Count = 170: TrySpan = True: Exit Function
    If Id = 313 Then Start = 45730: Count = 333: TrySpan = True: Exit Function
    If Id = 314 Then Start = 46063: Count = 309: TrySpan = True: Exit Function
    If Id = 315 Then Start = 46372: Count = 348: TrySpan = True: Exit Function
    If Id = 316 Then Start = 46720: Count = 66: TrySpan = True: Exit Function
    If Id = 317 Then Start = 46786: Count = 61: TrySpan = True: Exit Function
    If Id = 318 Then Start = 46847: Count = 40: TrySpan = True: Exit Function
    If Id = 319 Then Start = 46887: Count = 651: TrySpan = True: Exit Function
    If Id = 320 Then Start = 47538: Count = 106: TrySpan = True: Exit Function
    If Id = 321 Then Start = 47644: Count = 198: TrySpan = True: Exit Function
    If Id = 322 Then Start = 47842: Count = 128: TrySpan = True: Exit Function
    If Id = 323 Then Start = 47970: Count = 79: TrySpan = True: Exit Function
    If Id = 324 Then Start = 48049: Count = 67: TrySpan = True: Exit Function
    If Id = 325 Then Start = 48116: Count = 130: TrySpan = True: Exit Function
    If Id = 326 Then Start = 48246: Count = 336: TrySpan = True: Exit Function
End Function
