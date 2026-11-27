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
Public Const EntryStart As Long = 56
Public Const HostedEntryGuard As Long = 57
Public Const Entry As Long = 58
Public Const StoreError As Long = 59
Public Const FailureBranch As Long = 60
Public Const CallSuccess As Long = 61
Public Const CallSuccessBranch As Long = 62
Public Const ValueNonzero As Long = 63
Public Const BooleanSelect As Long = 64
Public Const TruncateValue As Long = 65
Public Const SignExtendValue As Long = 66
Public Const ZeroExtendValue As Long = 67
Public Const DifferentValues As Long = 68
Public Const ComplementValue As Long = 69
Public Const OverflowFlag As Long = 70
Public Const ArithmeticValue As Long = 71
Public Const ArithmeticAdd16 As Long = 72
Public Const ArithmeticSubtract16 As Long = 73
Public Const ArithmeticAdd32 As Long = 74
Public Const ArithmeticSubtract32 As Long = 75
Public Const ArithmeticAdd64 As Long = 76
Public Const ArithmeticSubtract64 As Long = 77
Public Const IntrinsicFileOpen As Long = 78
Public Const IntrinsicFileCreateNew As Long = 79
Public Const IntrinsicFileRead As Long = 80
Public Const IntrinsicFileWrite As Long = 81
Public Const IntrinsicFileClose As Long = 82
Public Const IntrinsicFileFlush As Long = 83
Public Const IntrinsicErrorSet As Long = 84
Public Const IntrinsicArrayLength As Long = 85
Public Const IntrinsicMemoryCopyBytes As Long = 86
Public Const IntrinsicArrayResize As Long = 87
Public Const IntrinsicArrayCopy As Long = 88
Public Const ContextAddress As Long = 89
Public Const ArgumentAddress As Long = 90
Public Const SlotAddress As Long = 91
Public Const TemporaryAddress As Long = 92
Public Const CellAddress As Long = 93
Public Const IndexedAddress As Long = 94
Public Const LoadPointer As Long = 95
Public Const StorePointer As Long = 96
Public Const StoreNullPointer As Long = 97
Public Const RetainBlock As Long = 98
Public Const PinBlock As Long = 99
Public Const ReleasePin As Long = 100
Public Const CollectMemory As Long = 101
Public Const ClearArray As Long = 102
Public Const BelowBound As Long = 103
Public Const AboveBound As Long = 104
Public Const EitherCondition As Long = 105
Public Const RelativeIndex As Long = 106
Public Const ElementOffset As Long = 107
Public Const LoadVolatileValue As Long = 108
Public Const StoreVolatileValue As Long = 109
Public Const StoreConstant As Long = 110
Public Const StoreVolatileConstant As Long = 111
Public Const EnsureModuleValue As Long = 112
Public Const ControlSite As Long = 113
Public Const ControlHandler As Long = 114
Public Const ControlZero As Long = 115
Public Const ControlArrayCopy As Long = 116
Public Const CompareEqual As Long = 117
Public Const CompareLessEqual As Long = 118
Public Const CompareGreaterEqual As Long = 119
Public Const BooleanAnd As Long = 120
Public Const BooleanInvert As Long = 121
Public Const IntegerAnd As Long = 122
Public Const IntegerOr As Long = 123
Public Const StoreErrorValue As Long = 124
Public Const ReturnFailureBranch As Long = 125
Public Const LoadError As Long = 126
Public Const CallStart As Long = 127
Public Const CallValueArgument As Long = 128
Public Const CallReferenceArgument As Long = 129
Public Const CallEnd As Long = 130
Public Const CallValue As Long = 131
Public Const ProcedurePointers As Long = 132
Public Const ModuleInitializeStart As Long = 133
Public Const FrameControls As Long = 134
Public Const AllocateSlot As Long = 135
Public Const StoreParameter As Long = 136
Public Const AllocateTemporary As Long = 137
Public Const AllocatePin As Long = 138
Public Const ProcedureDepth As Long = 139
Public Const FailureDispatchLabel As Long = 140
Public Const FailureHandlerDispatch As Long = 141
Public Const SwitchCase As Long = 142
Public Const SwitchEnd As Long = 143
Public Const FailureSkipDispatch As Long = 144
Public Const ReturnFailureLabel As Long = 145
Public Const ReturnDepthSuccess As Long = 146
Public Const ReturnDepthFailure As Long = 147
Public Const LoadResult As Long = 148
Public Const ReturnSuccessValue As Long = 149
Public Const ReturnFailedValue As Long = 150
Public Const ModuleEnsureDefinition As Long = 151
Public Const SourceLocation As Long = 152
Public Const TargetHeader As Long = 153
Public Const IntrinsicSystemCommandLine As Long = 154
Public Const IntrinsicSystemWrite As Long = 155
Public Const IntrinsicFileFinalPath As Long = 156
Public Const IntrinsicPathFullPath As Long = 157
Public Const IntrinsicPathCompareOrdinal As Long = 158
Public Const IntrinsicProcessStart As Long = 159
Public Const IntrinsicProcessWait As Long = 160
Public Const IntrinsicProcessTerminate As Long = 161
Public Const IntrinsicProcessClose As Long = 162
Public Const IntrinsicFileOpenDirectory As Long = 163
Public Const IntrinsicFileIdentity As Long = 164
Public Const IntrinsicFileLength As Long = 165
Public Const IntrinsicSystemExecutablePath As Long = 166
Public Const IntrinsicSystemMonotonicMilliseconds As Long = 167
Public Const IntrinsicDirectoryCreate As Long = 168
Public Const IntrinsicDirectoryRemove As Long = 169
Public Const IntrinsicFileDelete As Long = 170
Public Const IntrinsicFileReplace As Long = 171
Public Const IntrinsicPathKind As Long = 172
Public Const ArraySnapshot As Long = 173
Public Const SnapshotValue As Long = 174
Public Const AllocateAggregateTemporary As Long = 175
Public Const IntrinsicThreadCurrentId As Long = 176
Public Const IntrinsicThreadIsAlive As Long = 177
Public Const IntrinsicThreadWait As Long = 178
Public Const IntrinsicThreadRequestStop As Long = 179
Public Const IntrinsicThreadStopRequested As Long = 180
Public Const IntrinsicThreadYield As Long = 181
Public Const NullOwner As Long = 182
Public Const LoadLocalOwner As Long = 183
Public Const IncomingOwner As Long = 184
Public Const LoadTemporaryOwner As Long = 185
Public Const LoadPinOwner As Long = 186
Public Const NewOwner As Long = 187
Public Const OwnerAllocated As Long = 188
Public Const SetTemporaryOwner As Long = 189
Public Const OwnerPayload As Long = 190
Public Const DropOwner As Long = 191
Public Const ClearTemporaryOwner As Long = 192
Public Const AllocateLocalOwner As Long = 193
Public Const AllocateTemporaryOwner As Long = 194
Public Const SetLocalOwner As Long = 195
Public Const OwnerParameter As Long = 196
Public Const OwnerEntryGuard As Long = 197
Public Const BoxAddress As Long = 198
Public Const BoxTemporaryAddress As Long = 199
Public Const InstallOwnedArray As Long = 200
Public Const StoreBoxParameter As Long = 201
Public Const RetainOwner As Long = 202
Public Const StartThread As Long = 203
Public Const ThreadThunkStart As Long = 204
Public Const CaptureAddress As Long = 205
Public Const LoadOwnerPointer As Long = 206
Public Const BooleanConstant As Long = 207
Public Const ThreadThunkEnd As Long = 208
Public Const NewArrayOwner As Long = 209
Public Const ArithmeticMultiply16 As Long = 210
Public Const ArithmeticMultiply32 As Long = 211
Public Const ArithmeticMultiply64 As Long = 212
Public Const BothConditions As Long = 213
Public Const SafeRemainderDivisor As Long = 214
Public Const DivisionValue As Long = 215
Public Const RemainderValue As Long = 216
Public Const IntrinsicArrayMove As Long = 217
Public Const TextLiteralStart As Long = 218
Public Const TextLiteralByte As Long = 219
Public Const TextLiteralLastByte As Long = 220
Public Const TextLiteralEnd As Long = 221
Public Const TextLiteralAddress As Long = 222
Public Const TextRootLoad As Long = 223
Public Const TextRootStore As Long = 224
Public Const TextRootTake As Long = 225
Public Const ManagedEntryFrame As Long = 226
Public Const ManagedTextSlots As Long = 227
Public Const ManagedTextAlias As Long = 228
Public Const ManagedSymbolRoot As Long = 229
Public Const ManagedArraySymbolRoot As Long = 230
Public Const ManagedTemporaryRoot As Long = 231
Public Const ManagedArrayTemporaryRoot As Long = 232
Public Const ManagedRestoreRoots As Long = 233
Public Const ManagedReturnValue As Long = 234
Public Const ManagedDiscardReturn As Long = 235
Public Const ManagedOffsetsStart As Long = 236
Public Const ManagedOffsetsEnd As Long = 237
Public Const ManagedValueLayout As Long = 238
Public Const ManagedStoreValue As Long = 239
Public Const ManagedGlobalOffsetsStart As Long = 240
Public Const ManagedGlobalArraysStart As Long = 241
Public Const ManagedGlobalArrayEntry As Long = 242
Public Const ManagedGlobalArrayLastEntry As Long = 243
Public Const ManagedGlobalLayout As Long = 244
Public Const ManagedProcedureDepth As Long = 245
Public Const ManagedProjectInitialize As Long = 246
Public Const ManagedOwnerLayout As Long = 247
Public Const ManagedLocalOwnerRoot As Long = 248
Public Const ManagedTemporaryOwnerRoot As Long = 249
Public Const ManagedIncomingOwnerRoot As Long = 250
Public Const ManagedPinRoot As Long = 251
Public Const AttachManagedOwner As Long = 252
Public Const AttachManagedArrayOwner As Long = 253
Public Const IntrinsicManagedBeginCollection As Long = 254
Public Const IntrinsicManagedEndCollection As Long = 255
Public Const IntrinsicManagedSnapshotCounts As Long = 256
Public Const IntrinsicManagedAllocationAt As Long = 257
Public Const IntrinsicManagedRootAt As Long = 258
Public Const IntrinsicManagedMark As Long = 259
Public Const IntrinsicManagedMarked As Long = 260
Public Const IntrinsicManagedEdgeCount As Long = 261
Public Const IntrinsicManagedEdgeAt As Long = 262
Public Const IntrinsicManagedSealCollection As Long = 263
Public Const IntrinsicManagedReclaim As Long = 264
Public Const IntrinsicTextByteLength As Long = 265
Public Const IntrinsicTextScalarLength As Long = 266
Public Const IntrinsicTextReadByte As Long = 267
Public Const IntrinsicTextCreate As Long = 268
Public Const IntrinsicTextWriteByte As Long = 269
Public Const IntrinsicTextPublish As Long = 270
Public Const IntrinsicTextAbandon As Long = 271
Public Const ManagedCaptureOffsetsStart As Long = 272
Public Const ManagedCaptureOwnersStart As Long = 273
Public Const ManagedCaptureLayout As Long = 274
Public Const AttachManagedCapture As Long = 275
Public Const CapturePayloadAddress As Long = 276
Public Const ClearCapturedOwner As Long = 277
Public Const ManagedSafepoint As Long = 278
Public Const ManagedTemporaryTable As Long = 279
Public Const ManagedTextTableEntry As Long = 280
Public Const ManagedTemporaryTableEntry As Long = 281
Public Const ManagedRetireTemporaries As Long = 282
Public Const ManagedRetireDefinition As Long = 283
Public Const IntrinsicArrayResizeManaged As Long = 284
Public Const IntrinsicArrayCopyManaged As Long = 285
Public Const ControlManagedArrayCopyStart As Long = 286
Public Const ManagedLayoutCallEnd As Long = 287
Public Const HeapFrame As Long = 288
Public Const ReleaseFrame As Long = 289
Public Const StackFrame As Long = 290
Public Const VariantTag As Long = 291
Public Const IntrinsicVariantTag As Long = 292
Public Const VariantScalar As Long = 293
Public Const VariantBoxValue As Long = 294
Public Const VariantBoxReference As Long = 295
Public Const VariantPayload As Long = 296
Public Const VariantCreatePlainRecord As Long = 297
Public Const VariantCreateRecord As Long = 298
Public Const VariantPublish As Long = 299
Public Const VariantMatchRecord As Long = 300
Public Const AllocateVariantConversion As Long = 301
Public Const StoreVariantConversion As Long = 302
Public Const LoadVariantConversion As Long = 303
Public Const LoadManagedExpression As Long = 304
Public Const EnumerationLoad As Long = 305
Public Const EnumerationStoreIndex As Long = 306
Public Const EnumerationPayload As Long = 307
Public Const EnumerationRoot As Long = 308
Public Const EnumerationCapture As Long = 309
Public Const EnumerationRelease As Long = 310
Public Const ObjectDescriptor As Long = 311
Public Const ObjectCreate As Long = 312
Public Const ObjectPublish As Long = 313
Public Const IntrinsicMonitorTryEnter As Long = 314
Public Const IntrinsicMonitorLeave As Long = 315
Public Const IntrinsicMonitorYield As Long = 316
Public Const MonitorSlots As Long = 317
Public Const MonitorCapture As Long = 318
Public Const MonitorAcquire As Long = 319
Public Const MonitorAcquired As Long = 320
Public Const MonitorRelease As Long = 321
Public Const ConstructState As Long = 322
Public Const ConstructGuard As Long = 323
Public Const VariantCreateObject As Long = 324
Public Const VariantReference As Long = 325
Public Const ObjectNominal As Long = 326
Public Const VariantCreateObjectDynamic As Long = 327
Public Const MonitorRequire As Long = 328
Public Const ObjectOffsetsStart As Long = 329
Public Const ObjectPayloadLayout As Long = 330
Public Const InstanceParameter As Long = 331
Public Const InstanceValue As Long = 332
Public Const InstanceRoot As Long = 333
Public Const ObjectAddress As Long = 334
Public Const ObjectAddressValid As Long = 335
Public Const TemplateCount As Long = 335
Public Const CatalogLength As Long = 49431
Public Const CatalogByteSum As Long = 3964524

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
    If Id = 56 Then Start = 6795: Count = 105: TrySpan = True: Exit Function
    If Id = 57 Then Start = 6900: Count = 162: TrySpan = True: Exit Function
    If Id = 58 Then Start = 7062: Count = 1093: TrySpan = True: Exit Function
    If Id = 59 Then Start = 8155: Count = 51: TrySpan = True: Exit Function
    If Id = 60 Then Start = 8206: Count = 28: TrySpan = True: Exit Function
    If Id = 61 Then Start = 8234: Count = 43: TrySpan = True: Exit Function
    If Id = 62 Then Start = 8277: Count = 51: TrySpan = True: Exit Function
    If Id = 63 Then Start = 8328: Count = 30: TrySpan = True: Exit Function
    If Id = 64 Then Start = 8358: Count = 40: TrySpan = True: Exit Function
    If Id = 65 Then Start = 8398: Count = 33: TrySpan = True: Exit Function
    If Id = 66 Then Start = 8431: Count = 32: TrySpan = True: Exit Function
    If Id = 67 Then Start = 8463: Count = 32: TrySpan = True: Exit Function
    If Id = 68 Then Start = 8495: Count = 34: TrySpan = True: Exit Function
    If Id = 69 Then Start = 8529: Count = 28: TrySpan = True: Exit Function
    If Id = 70 Then Start = 8557: Count = 44: TrySpan = True: Exit Function
    If Id = 71 Then Start = 8601: Count = 44: TrySpan = True: Exit Function
    If Id = 72 Then Start = 8645: Count = 77: TrySpan = True: Exit Function
    If Id = 73 Then Start = 8722: Count = 77: TrySpan = True: Exit Function
    If Id = 74 Then Start = 8799: Count = 77: TrySpan = True: Exit Function
    If Id = 75 Then Start = 8876: Count = 77: TrySpan = True: Exit Function
    If Id = 76 Then Start = 8953: Count = 77: TrySpan = True: Exit Function
    If Id = 77 Then Start = 9030: Count = 77: TrySpan = True: Exit Function
    If Id = 78 Then Start = 9107: Count = 380: TrySpan = True: Exit Function
    If Id = 79 Then Start = 9487: Count = 393: TrySpan = True: Exit Function
    If Id = 80 Then Start = 9880: Count = 408: TrySpan = True: Exit Function
    If Id = 81 Then Start = 10288: Count = 407: TrySpan = True: Exit Function
    If Id = 82 Then Start = 10695: Count = 299: TrySpan = True: Exit Function
    If Id = 83 Then Start = 10994: Count = 299: TrySpan = True: Exit Function
    If Id = 84 Then Start = 11293: Count = 314: TrySpan = True: Exit Function
    If Id = 85 Then Start = 11607: Count = 228: TrySpan = True: Exit Function
    If Id = 86 Then Start = 11835: Count = 266: TrySpan = True: Exit Function
    If Id = 87 Then Start = 12101: Count = 347: TrySpan = True: Exit Function
    If Id = 88 Then Start = 12448: Count = 321: TrySpan = True: Exit Function
    If Id = 89 Then Start = 12769: Count = 58: TrySpan = True: Exit Function
    If Id = 90 Then Start = 12827: Count = 48: TrySpan = True: Exit Function
    If Id = 91 Then Start = 12875: Count = 49: TrySpan = True: Exit Function
    If Id = 92 Then Start = 12924: Count = 49: TrySpan = True: Exit Function
    If Id = 93 Then Start = 12973: Count = 47: TrySpan = True: Exit Function
    If Id = 94 Then Start = 13020: Count = 49: TrySpan = True: Exit Function
    If Id = 95 Then Start = 13069: Count = 29: TrySpan = True: Exit Function
    If Id = 96 Then Start = 13098: Count = 28: TrySpan = True: Exit Function
    If Id = 97 Then Start = 13126: Count = 27: TrySpan = True: Exit Function
    If Id = 98 Then Start = 13153: Count = 40: TrySpan = True: Exit Function
    If Id = 99 Then Start = 13193: Count = 55: TrySpan = True: Exit Function
    If Id = 100 Then Start = 13248: Count = 162: TrySpan = True: Exit Function
    If Id = 101 Then Start = 13410: Count = 47: TrySpan = True: Exit Function
    If Id = 102 Then Start = 13457: Count = 49: TrySpan = True: Exit Function
    If Id = 103 Then Start = 13506: Count = 35: TrySpan = True: Exit Function
    If Id = 104 Then Start = 13541: Count = 35: TrySpan = True: Exit Function
    If Id = 105 Then Start = 13576: Count = 28: TrySpan = True: Exit Function
    If Id = 106 Then Start = 13604: Count = 30: TrySpan = True: Exit Function
    If Id = 107 Then Start = 13634: Count = 28: TrySpan = True: Exit Function
    If Id = 108 Then Start = 13662: Count = 64: TrySpan = True: Exit Function
    If Id = 109 Then Start = 13726: Count = 63: TrySpan = True: Exit Function
    If Id = 110 Then Start = 13789: Count = 52: TrySpan = True: Exit Function
    If Id = 111 Then Start = 13841: Count = 61: TrySpan = True: Exit Function
    If Id = 112 Then Start = 13902: Count = 50: TrySpan = True: Exit Function
    If Id = 113 Then Start = 13952: Count = 34: TrySpan = True: Exit Function
    If Id = 114 Then Start = 13986: Count = 36: TrySpan = True: Exit Function
    If Id = 115 Then Start = 14022: Count = 30: TrySpan = True: Exit Function
    If Id = 116 Then Start = 14052: Count = 87: TrySpan = True: Exit Function
    If Id = 117 Then Start = 14139: Count = 34: TrySpan = True: Exit Function
    If Id = 118 Then Start = 14173: Count = 35: TrySpan = True: Exit Function
    If Id = 119 Then Start = 14208: Count = 35: TrySpan = True: Exit Function
    If Id = 120 Then Start = 14243: Count = 29: TrySpan = True: Exit Function
    If Id = 121 Then Start = 14272: Count = 28: TrySpan = True: Exit Function
    If Id = 122 Then Start = 14300: Count = 30: TrySpan = True: Exit Function
    If Id = 123 Then Start = 14330: Count = 29: TrySpan = True: Exit Function
    If Id = 124 Then Start = 14359: Count = 53: TrySpan = True: Exit Function
    If Id = 125 Then Start = 14412: Count = 23: TrySpan = True: Exit Function
    If Id = 126 Then Start = 14435: Count = 54: TrySpan = True: Exit Function
    If Id = 127 Then Start = 14489: Count = 49: TrySpan = True: Exit Function
    If Id = 128 Then Start = 14538: Count = 11: TrySpan = True: Exit Function
    If Id = 129 Then Start = 14549: Count = 11: TrySpan = True: Exit Function
    If Id = 130 Then Start = 14560: Count = 1: TrySpan = True: Exit Function
    If Id = 131 Then Start = 14561: Count = 43: TrySpan = True: Exit Function
    If Id = 132 Then Start = 14604: Count = 132: TrySpan = True: Exit Function
    If Id = 133 Then Start = 14736: Count = 134: TrySpan = True: Exit Function
    If Id = 134 Then Start = 14870: Count = 410: TrySpan = True: Exit Function
    If Id = 135 Then Start = 15280: Count = 60: TrySpan = True: Exit Function
    If Id = 136 Then Start = 15340: Count = 61: TrySpan = True: Exit Function
    If Id = 137 Then Start = 15401: Count = 60: TrySpan = True: Exit Function
    If Id = 138 Then Start = 15461: Count = 91: TrySpan = True: Exit Function
    If Id = 139 Then Start = 15552: Count = 482: TrySpan = True: Exit Function
    If Id = 140 Then Start = 16034: Count = 17: TrySpan = True: Exit Function
    If Id = 141 Then Start = 16051: Count = 555: TrySpan = True: Exit Function
    If Id = 142 Then Start = 16606: Count = 24: TrySpan = True: Exit Function
    If Id = 143 Then Start = 16630: Count = 3: TrySpan = True: Exit Function
    If Id = 144 Then Start = 16633: Count = 64: TrySpan = True: Exit Function
    If Id = 145 Then Start = 16697: Count = 12: TrySpan = True: Exit Function
    If Id = 146 Then Start = 16709: Count = 191: TrySpan = True: Exit Function
    If Id = 147 Then Start = 16900: Count = 199: TrySpan = True: Exit Function
    If Id = 148 Then Start = 17099: Count = 59: TrySpan = True: Exit Function
    If Id = 149 Then Start = 17158: Count = 91: TrySpan = True: Exit Function
    If Id = 150 Then Start = 17249: Count = 37: TrySpan = True: Exit Function
    If Id = 151 Then Start = 17286: Count = 976: TrySpan = True: Exit Function
    If Id = 152 Then Start = 18262: Count = 44: TrySpan = True: Exit Function
    If Id = 153 Then Start = 18306: Count = 66: TrySpan = True: Exit Function
    If Id = 154 Then Start = 18372: Count = 331: TrySpan = True: Exit Function
    If Id = 155 Then Start = 18703: Count = 397: TrySpan = True: Exit Function
    If Id = 156 Then Start = 19100: Count = 368: TrySpan = True: Exit Function
    If Id = 157 Then Start = 19468: Count = 366: TrySpan = True: Exit Function
    If Id = 158 Then Start = 19834: Count = 349: TrySpan = True: Exit Function
    If Id = 159 Then Start = 20183: Count = 398: TrySpan = True: Exit Function
    If Id = 160 Then Start = 20581: Count = 373: TrySpan = True: Exit Function
    If Id = 161 Then Start = 20954: Count = 306: TrySpan = True: Exit Function
    If Id = 162 Then Start = 21260: Count = 302: TrySpan = True: Exit Function
    If Id = 163 Then Start = 21562: Count = 327: TrySpan = True: Exit Function
    If Id = 164 Then Start = 21889: Count = 326: TrySpan = True: Exit Function
    If Id = 165 Then Start = 22215: Count = 324: TrySpan = True: Exit Function
    If Id = 166 Then Start = 22539: Count = 330: TrySpan = True: Exit Function
    If Id = 167 Then Start = 22869: Count = 301: TrySpan = True: Exit Function
    If Id = 168 Then Start = 23170: Count = 305: TrySpan = True: Exit Function
    If Id = 169 Then Start = 23475: Count = 305: TrySpan = True: Exit Function
    If Id = 170 Then Start = 23780: Count = 300: TrySpan = True: Exit Function
    If Id = 171 Then Start = 24080: Count = 325: TrySpan = True: Exit Function
    If Id = 172 Then Start = 24405: Count = 322: TrySpan = True: Exit Function
    If Id = 173 Then Start = 24727: Count = 78: TrySpan = True: Exit Function
    If Id = 174 Then Start = 24805: Count = 56: TrySpan = True: Exit Function
    If Id = 175 Then Start = 24861: Count = 60: TrySpan = True: Exit Function
    If Id = 176 Then Start = 24921: Count = 144: TrySpan = True: Exit Function
    If Id = 177 Then Start = 25065: Count = 166: TrySpan = True: Exit Function
    If Id = 178 Then Start = 25231: Count = 189: TrySpan = True: Exit Function
    If Id = 179 Then Start = 25420: Count = 173: TrySpan = True: Exit Function
    If Id = 180 Then Start = 25593: Count = 264: TrySpan = True: Exit Function
    If Id = 181 Then Start = 25857: Count = 250: TrySpan = True: Exit Function
    If Id = 182 Then Start = 26107: Count = 43: TrySpan = True: Exit Function
    If Id = 183 Then Start = 26150: Count = 32: TrySpan = True: Exit Function
    If Id = 184 Then Start = 26182: Count = 49: TrySpan = True: Exit Function
    If Id = 185 Then Start = 26231: Count = 39: TrySpan = True: Exit Function
    If Id = 186 Then Start = 26270: Count = 32: TrySpan = True: Exit Function
    If Id = 187 Then Start = 26302: Count = 60: TrySpan = True: Exit Function
    If Id = 188 Then Start = 26362: Count = 214: TrySpan = True: Exit Function
    If Id = 189 Then Start = 26576: Count = 38: TrySpan = True: Exit Function
    If Id = 190 Then Start = 26614: Count = 52: TrySpan = True: Exit Function
    If Id = 191 Then Start = 26666: Count = 54: TrySpan = True: Exit Function
    If Id = 192 Then Start = 26720: Count = 37: TrySpan = True: Exit Function
    If Id = 193 Then Start = 26757: Count = 91: TrySpan = True: Exit Function
    If Id = 194 Then Start = 26848: Count = 105: TrySpan = True: Exit Function
    If Id = 195 Then Start = 26953: Count = 31: TrySpan = True: Exit Function
    If Id = 196 Then Start = 26984: Count = 16: TrySpan = True: Exit Function
    If Id = 197 Then Start = 27000: Count = 75: TrySpan = True: Exit Function
    If Id = 198 Then Start = 27075: Count = 108: TrySpan = True: Exit Function
    If Id = 199 Then Start = 27183: Count = 117: TrySpan = True: Exit Function
    If Id = 200 Then Start = 27300: Count = 80: TrySpan = True: Exit Function
    If Id = 201 Then Start = 27380: Count = 57: TrySpan = True: Exit Function
    If Id = 202 Then Start = 27437: Count = 40: TrySpan = True: Exit Function
    If Id = 203 Then Start = 27477: Count = 92: TrySpan = True: Exit Function
    If Id = 204 Then Start = 27569: Count = 134: TrySpan = True: Exit Function
    If Id = 205 Then Start = 27703: Count = 50: TrySpan = True: Exit Function
    If Id = 206 Then Start = 27753: Count = 29: TrySpan = True: Exit Function
    If Id = 207 Then Start = 27782: Count = 27: TrySpan = True: Exit Function
    If Id = 208 Then Start = 27809: Count = 19: TrySpan = True: Exit Function
    If Id = 209 Then Start = 27828: Count = 62: TrySpan = True: Exit Function
    If Id = 210 Then Start = 27890: Count = 77: TrySpan = True: Exit Function
    If Id = 211 Then Start = 27967: Count = 77: TrySpan = True: Exit Function
    If Id = 212 Then Start = 28044: Count = 77: TrySpan = True: Exit Function
    If Id = 213 Then Start = 28121: Count = 29: TrySpan = True: Exit Function
    If Id = 214 Then Start = 28150: Count = 43: TrySpan = True: Exit Function
    If Id = 215 Then Start = 28193: Count = 31: TrySpan = True: Exit Function
    If Id = 216 Then Start = 28224: Count = 31: TrySpan = True: Exit Function
    If Id = 217 Then Start = 28255: Count = 299: TrySpan = True: Exit Function
    If Id = 218 Then Start = 28554: Count = 52: TrySpan = True: Exit Function
    If Id = 219 Then Start = 28606: Count = 9: TrySpan = True: Exit Function
    If Id = 220 Then Start = 28615: Count = 7: TrySpan = True: Exit Function
    If Id = 221 Then Start = 28622: Count = 129: TrySpan = True: Exit Function
    If Id = 222 Then Start = 28751: Count = 60: TrySpan = True: Exit Function
    If Id = 223 Then Start = 28811: Count = 71: TrySpan = True: Exit Function
    If Id = 224 Then Start = 28882: Count = 65: TrySpan = True: Exit Function
    If Id = 225 Then Start = 28947: Count = 60: TrySpan = True: Exit Function
    If Id = 226 Then Start = 29007: Count = 152: TrySpan = True: Exit Function
    If Id = 227 Then Start = 29159: Count = 259: TrySpan = True: Exit Function
    If Id = 228 Then Start = 29418: Count = 58: TrySpan = True: Exit Function
    If Id = 229 Then Start = 29476: Count = 180: TrySpan = True: Exit Function
    If Id = 230 Then Start = 29656: Count = 185: TrySpan = True: Exit Function
    If Id = 231 Then Start = 29841: Count = 186: TrySpan = True: Exit Function
    If Id = 232 Then Start = 30027: Count = 191: TrySpan = True: Exit Function
    If Id = 233 Then Start = 30218: Count = 64: TrySpan = True: Exit Function
    If Id = 234 Then Start = 30282: Count = 52: TrySpan = True: Exit Function
    If Id = 235 Then Start = 30334: Count = 42: TrySpan = True: Exit Function
    If Id = 236 Then Start = 30376: Count = 57: TrySpan = True: Exit Function
    If Id = 237 Then Start = 30433: Count = 1: TrySpan = True: Exit Function
    If Id = 238 Then Start = 30434: Count = 406: TrySpan = True: Exit Function
    If Id = 239 Then Start = 30840: Count = 62: TrySpan = True: Exit Function
    If Id = 240 Then Start = 30902: Count = 60: TrySpan = True: Exit Function
    If Id = 241 Then Start = 30962: Count = 74: TrySpan = True: Exit Function
    If Id = 242 Then Start = 31036: Count = 61: TrySpan = True: Exit Function
    If Id = 243 Then Start = 31097: Count = 59: TrySpan = True: Exit Function
    If Id = 244 Then Start = 31156: Count = 178: TrySpan = True: Exit Function
    If Id = 245 Then Start = 31334: Count = 548: TrySpan = True: Exit Function
    If Id = 246 Then Start = 31882: Count = 283: TrySpan = True: Exit Function
    If Id = 247 Then Start = 32165: Count = 148: TrySpan = True: Exit Function
    If Id = 248 Then Start = 32313: Count = 184: TrySpan = True: Exit Function
    If Id = 249 Then Start = 32497: Count = 215: TrySpan = True: Exit Function
    If Id = 250 Then Start = 32712: Count = 350: TrySpan = True: Exit Function
    If Id = 251 Then Start = 33062: Count = 184: TrySpan = True: Exit Function
    If Id = 252 Then Start = 33246: Count = 96: TrySpan = True: Exit Function
    If Id = 253 Then Start = 33342: Count = 99: TrySpan = True: Exit Function
    If Id = 254 Then Start = 33441: Count = 302: TrySpan = True: Exit Function
    If Id = 255 Then Start = 33743: Count = 300: TrySpan = True: Exit Function
    If Id = 256 Then Start = 34043: Count = 312: TrySpan = True: Exit Function
    If Id = 257 Then Start = 34355: Count = 310: TrySpan = True: Exit Function
    If Id = 258 Then Start = 34665: Count = 304: TrySpan = True: Exit Function
    If Id = 259 Then Start = 34969: Count = 301: TrySpan = True: Exit Function
    If Id = 260 Then Start = 35270: Count = 303: TrySpan = True: Exit Function
    If Id = 261 Then Start = 35573: Count = 307: TrySpan = True: Exit Function
    If Id = 262 Then Start = 35880: Count = 328: TrySpan = True: Exit Function
    If Id = 263 Then Start = 36208: Count = 253: TrySpan = True: Exit Function
    If Id = 264 Then Start = 36461: Count = 280: TrySpan = True: Exit Function
    If Id = 265 Then Start = 36741: Count = 175: TrySpan = True: Exit Function
    If Id = 266 Then Start = 36916: Count = 174: TrySpan = True: Exit Function
    If Id = 267 Then Start = 37090: Count = 322: TrySpan = True: Exit Function
    If Id = 268 Then Start = 37412: Count = 324: TrySpan = True: Exit Function
    If Id = 269 Then Start = 37736: Count = 323: TrySpan = True: Exit Function
    If Id = 270 Then Start = 38059: Count = 301: TrySpan = True: Exit Function
    If Id = 271 Then Start = 38360: Count = 277: TrySpan = True: Exit Function
    If Id = 272 Then Start = 38637: Count = 65: TrySpan = True: Exit Function
    If Id = 273 Then Start = 38702: Count = 64: TrySpan = True: Exit Function
    If Id = 274 Then Start = 38766: Count = 192: TrySpan = True: Exit Function
    If Id = 275 Then Start = 38958: Count = 102: TrySpan = True: Exit Function
    If Id = 276 Then Start = 39060: Count = 47: TrySpan = True: Exit Function
    If Id = 277 Then Start = 39107: Count = 51: TrySpan = True: Exit Function
    If Id = 278 Then Start = 39158: Count = 40: TrySpan = True: Exit Function
    If Id = 279 Then Start = 39198: Count = 65: TrySpan = True: Exit Function
    If Id = 280 Then Start = 39263: Count = 152: TrySpan = True: Exit Function
    If Id = 281 Then Start = 39415: Count = 95: TrySpan = True: Exit Function
    If Id = 282 Then Start = 39510: Count = 75: TrySpan = True: Exit Function
    If Id = 283 Then Start = 39585: Count = 490: TrySpan = True: Exit Function
    If Id = 284 Then Start = 40075: Count = 366: TrySpan = True: Exit Function
    If Id = 285 Then Start = 40441: Count = 340: TrySpan = True: Exit Function
    If Id = 286 Then Start = 40781: Count = 76: TrySpan = True: Exit Function
    If Id = 287 Then Start = 40857: Count = 30: TrySpan = True: Exit Function
    If Id = 288 Then Start = 40887: Count = 620: TrySpan = True: Exit Function
    If Id = 289 Then Start = 41507: Count = 55: TrySpan = True: Exit Function
    If Id = 290 Then Start = 41562: Count = 528: TrySpan = True: Exit Function
    If Id = 291 Then Start = 42090: Count = 61: TrySpan = True: Exit Function
    If Id = 292 Then Start = 42151: Count = 165: TrySpan = True: Exit Function
    If Id = 293 Then Start = 42316: Count = 64: TrySpan = True: Exit Function
    If Id = 294 Then Start = 42380: Count = 88: TrySpan = True: Exit Function
    If Id = 295 Then Start = 42468: Count = 105: TrySpan = True: Exit Function
    If Id = 296 Then Start = 42573: Count = 60: TrySpan = True: Exit Function
    If Id = 297 Then Start = 42633: Count = 114: TrySpan = True: Exit Function
    If Id = 298 Then Start = 42747: Count = 133: TrySpan = True: Exit Function
    If Id = 299 Then Start = 42880: Count = 73: TrySpan = True: Exit Function
    If Id = 300 Then Start = 42953: Count = 90: TrySpan = True: Exit Function
    If Id = 301 Then Start = 43043: Count = 71: TrySpan = True: Exit Function
    If Id = 302 Then Start = 43114: Count = 43: TrySpan = True: Exit Function
    If Id = 303 Then Start = 43157: Count = 44: TrySpan = True: Exit Function
    If Id = 304 Then Start = 43201: Count = 56: TrySpan = True: Exit Function
    If Id = 305 Then Start = 43257: Count = 114: TrySpan = True: Exit Function
    If Id = 306 Then Start = 43371: Count = 79: TrySpan = True: Exit Function
    If Id = 307 Then Start = 43450: Count = 112: TrySpan = True: Exit Function
    If Id = 308 Then Start = 43562: Count = 396: TrySpan = True: Exit Function
    If Id = 309 Then Start = 43958: Count = 939: TrySpan = True: Exit Function
    If Id = 310 Then Start = 44897: Count = 517: TrySpan = True: Exit Function
    If Id = 311 Then Start = 45414: Count = 48: TrySpan = True: Exit Function
    If Id = 312 Then Start = 45462: Count = 134: TrySpan = True: Exit Function
    If Id = 313 Then Start = 45596: Count = 146: TrySpan = True: Exit Function
    If Id = 314 Then Start = 45742: Count = 170: TrySpan = True: Exit Function
    If Id = 315 Then Start = 45912: Count = 333: TrySpan = True: Exit Function
    If Id = 316 Then Start = 46245: Count = 309: TrySpan = True: Exit Function
    If Id = 317 Then Start = 46554: Count = 348: TrySpan = True: Exit Function
    If Id = 318 Then Start = 46902: Count = 66: TrySpan = True: Exit Function
    If Id = 319 Then Start = 46968: Count = 61: TrySpan = True: Exit Function
    If Id = 320 Then Start = 47029: Count = 40: TrySpan = True: Exit Function
    If Id = 321 Then Start = 47069: Count = 651: TrySpan = True: Exit Function
    If Id = 322 Then Start = 47720: Count = 106: TrySpan = True: Exit Function
    If Id = 323 Then Start = 47826: Count = 198: TrySpan = True: Exit Function
    If Id = 324 Then Start = 48024: Count = 128: TrySpan = True: Exit Function
    If Id = 325 Then Start = 48152: Count = 79: TrySpan = True: Exit Function
    If Id = 326 Then Start = 48231: Count = 67: TrySpan = True: Exit Function
    If Id = 327 Then Start = 48298: Count = 130: TrySpan = True: Exit Function
    If Id = 328 Then Start = 48428: Count = 336: TrySpan = True: Exit Function
    If Id = 329 Then Start = 48764: Count = 56: TrySpan = True: Exit Function
    If Id = 330 Then Start = 48820: Count = 145: TrySpan = True: Exit Function
    If Id = 331 Then Start = 48965: Count = 15: TrySpan = True: Exit Function
    If Id = 332 Then Start = 48980: Count = 30: TrySpan = True: Exit Function
    If Id = 333 Then Start = 49010: Count = 302: TrySpan = True: Exit Function
    If Id = 334 Then Start = 49312: Count = 86: TrySpan = True: Exit Function
    If Id = 335 Then Start = 49398: Count = 33: TrySpan = True: Exit Function
End Function
