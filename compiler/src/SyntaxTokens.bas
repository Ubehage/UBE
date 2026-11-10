UBE SOURCE 1 MODULE
Attribute UBE_Name = "SyntaxTokens"
' Classifies retained ASCII token spellings without allocating text or sharing mutable state.

Public Const CodeUnknown As Long = 0
Public Const CodeIdentifier As Long = 1
Public Const CodeNumber As Long = 2
Public Const CodeString As Long = 3
Public Const CodeNewline As Long = 4
Public Const CodeEnd As Long = 5
Public Const SymOpen As Long = 10
Public Const SymClose As Long = 11
Public Const SymDot As Long = 12
Public Const SymComma As Long = 13
Public Const SymColon As Long = 14
Public Const SymEqual As Long = 15
Public Const SymPlus As Long = 16
Public Const SymMinus As Long = 17
Public Const SymLess As Long = 18
Public Const SymGreater As Long = 19
Public Const SymLessEqual As Long = 20
Public Const SymGreaterEqual As Long = 21
Public Const SymNotEqual As Long = 22
Public Const SymPercent As Long = 23
Public Const SymAmpersand As Long = 24
Public Const SymCaret As Long = 25
Public Const SymStar As Long = 26
Public Const SymSlash As Long = 27
Public Const SymBackslash As Long = 28
Public Const SymBang As Long = 29
Public Const SymDollar As Long = 30
Public Const SymAt As Long = 31
Public Const SymSemicolon As Long = 32
Public Const SymAssignNamed As Long = 33
Public Const KwIf As Long = 100
Public Const KwThen As Long = 101
Public Const KwElse As Long = 102
Public Const KwElseif As Long = 103
Public Const KwEnd As Long = 104
Public Const KwSub As Long = 105
Public Const KwFunction As Long = 106
Public Const KwPublic As Long = 107
Public Const KwPrivate As Long = 108
Public Const KwFriend As Long = 109
Public Const KwGlobal As Long = 110
Public Const KwDim As Long = 111
Public Const KwStatic As Long = 112
Public Const KwConst As Long = 113
Public Const KwAs As Long = 114
Public Const KwByval As Long = 115
Public Const KwByref As Long = 116
Public Const KwOptional As Long = 117
Public Const KwParamarray As Long = 118
Public Const KwOption As Long = 119
Public Const KwExplicit As Long = 120
Public Const KwGoto As Long = 121
Public Const KwGosub As Long = 122
Public Const KwOn As Long = 123
Public Const KwError As Long = 124
Public Const KwResume As Long = 125
Public Const KwNext As Long = 126
Public Const KwExit As Long = 127
Public Const KwCall As Long = 128
Public Const KwLet As Long = 129
Public Const KwSet As Long = 130
Public Const KwLset As Long = 131
Public Const KwRset As Long = 132
Public Const KwTrue As Long = 133
Public Const KwFalse As Long = 134
Public Const KwAnd As Long = 135
Public Const KwAndalso As Long = 136
Public Const KwOr As Long = 137
Public Const KwOrelse As Long = 138
Public Const KwNot As Long = 139
Public Const KwXor As Long = 140
Public Const KwEqv As Long = 141
Public Const KwImp As Long = 142
Public Const KwMod As Long = 143
Public Const KwIs As Long = 144
Public Const KwIsnot As Long = 145
Public Const KwLike As Long = 146
Public Const KwTypeof As Long = 147
Public Const KwNew As Long = 148
Public Const KwNothing As Long = 149
Public Const KwNull As Long = 150
Public Const KwEmpty As Long = 151
Public Const KwMe As Long = 152
Public Const KwBoolean As Long = 153
Public Const KwByte As Long = 154
Public Const KwInteger As Long = 155
Public Const KwLong As Long = 156
Public Const KwLonglong As Long = 157
Public Const KwSingle As Long = 158
Public Const KwDouble As Long = 159
Public Const KwCurrency As Long = 160
Public Const KwDecimal As Long = 161
Public Const KwDate As Long = 162
Public Const KwString As Long = 163
Public Const KwObject As Long = 164
Public Const KwVariant As Long = 165
Public Const KwAny As Long = 166
Public Const KwIntptr As Long = 167
Public Const KwUintptr As Long = 168
Public Const KwFor As Long = 169
Public Const KwEach As Long = 170
Public Const KwTo As Long = 171
Public Const KwStep As Long = 172
Public Const KwDo As Long = 173
Public Const KwLoop As Long = 174
Public Const KwWhile As Long = 175
Public Const KwUntil As Long = 176
Public Const KwWend As Long = 177
Public Const KwWith As Long = 178
Public Const KwSelect As Long = 179
Public Const KwCase As Long = 180
Public Const KwReturn As Long = 181
Public Const KwStop As Long = 182
Public Const KwPrint As Long = 183
Public Const KwAsm As Long = 184
Public Const KwBytecode As Long = 185
Public Const KwDeclare As Long = 186
Public Const KwLib As Long = 187
Public Const KwAlias As Long = 188
Public Const KwType As Long = 189
Public Const KwEnum As Long = 190
Public Const KwEvent As Long = 191
Public Const KwProperty As Long = 192
Public Const KwInterface As Long = 193
Public Const KwImplements As Long = 194
Public Const KwRaiseevent As Long = 195
Public Const KwRedim As Long = 196
Public Const KwErase As Long = 197
Public Const KwLoad As Long = 198
Public Const KwUnload As Long = 199
Public Const KwIntrinsic As Long = 200
Public Const KwExport As Long = 201
Public Const KwAttribute As Long = 202
Public Const KwSynclock As Long = 203
Public Const KwCallnew As Long = 204
Public Const KwAddressof As Long = 205
Public Const KwOpen As Long = 206
Public Const KwClose As Long = 207
Public Const KwGet As Long = 208
Public Const KwPut As Long = 209
Public Const KwInput As Long = 210
Public Const KwLine As Long = 211
Public Const KwWrite As Long = 212
Public Const KwSeek As Long = 213
Public Const KwKill As Long = 214
Public Const KwName As Long = 215
Public Const KwFilecopy As Long = 216
Public Const KwMkdir As Long = 217
Public Const KwRmdir As Long = 218
Public Const KwChdir As Long = 219
Public Const KwChdrive As Long = 220
Public Const KwLock As Long = 221
Public Const KwUnlock As Long = 222
Public Const KwWidth As Long = 223
Public Const KwRandomize As Long = 224
Public Const KwWithevents As Long = 225
Public Const KwRem As Long = 226
Public Const KwDefbool As Long = 227
Public Const KwDefbyte As Long = 228
Public Const KwDefcur As Long = 229
Public Const KwDefdate As Long = 230
Public Const KwDefdbl As Long = 231
Public Const KwDefint As Long = 232
Public Const KwDeflng As Long = 233
Public Const KwDefobj As Long = 234
Public Const KwDefsng As Long = 235
Public Const KwDefstr As Long = 236
Public Const KwDefvar As Long = 237
Public Const KwUbe As Long = 1000
Public Const KwSource As Long = 1001
Public Const KwModule As Long = 1002
Public Const KwUbeName As Long = 1003
Public Const KwUbePrimitive As Long = 1004
Public Const KwPreserve As Long = 1005

' Classifies an ordinary ASCII word; keyword codes are independent of source spelling case.
Private Function WordCode(ByRef Source() As Byte, ByVal Start As Long, ByVal Length As Long) As Long
    Dim C0 As Long
    Dim C1 As Long
    Dim C2 As Long
    Dim C3 As Long
    Dim C4 As Long
    Dim C5 As Long
    Dim C6 As Long
    Dim C7 As Long
    Dim C8 As Long
    Dim C9 As Long
    Dim C10 As Long
    Dim C11 As Long
    Dim C12 As Long
    On Error GoTo Failed
    WordCode = CodeIdentifier
    If Length < 2 Or Length > 13 Then Exit Function
    If Length > 0 Then
        C0 = Source(Start + 0)
        If C0 >= 65 And C0 <= 90 Then C0 = C0 + 32
    End If
    If Length > 1 Then
        C1 = Source(Start + 1)
        If C1 >= 65 And C1 <= 90 Then C1 = C1 + 32
    End If
    If Length > 2 Then
        C2 = Source(Start + 2)
        If C2 >= 65 And C2 <= 90 Then C2 = C2 + 32
    End If
    If Length > 3 Then
        C3 = Source(Start + 3)
        If C3 >= 65 And C3 <= 90 Then C3 = C3 + 32
    End If
    If Length > 4 Then
        C4 = Source(Start + 4)
        If C4 >= 65 And C4 <= 90 Then C4 = C4 + 32
    End If
    If Length > 5 Then
        C5 = Source(Start + 5)
        If C5 >= 65 And C5 <= 90 Then C5 = C5 + 32
    End If
    If Length > 6 Then
        C6 = Source(Start + 6)
        If C6 >= 65 And C6 <= 90 Then C6 = C6 + 32
    End If
    If Length > 7 Then
        C7 = Source(Start + 7)
        If C7 >= 65 And C7 <= 90 Then C7 = C7 + 32
    End If
    If Length > 8 Then
        C8 = Source(Start + 8)
        If C8 >= 65 And C8 <= 90 Then C8 = C8 + 32
    End If
    If Length > 9 Then
        C9 = Source(Start + 9)
        If C9 >= 65 And C9 <= 90 Then C9 = C9 + 32
    End If
    If Length > 10 Then
        C10 = Source(Start + 10)
        If C10 >= 65 And C10 <= 90 Then C10 = C10 + 32
    End If
    If Length > 11 Then
        C11 = Source(Start + 11)
        If C11 >= 65 And C11 <= 90 Then C11 = C11 + 32
    End If
    If Length > 12 Then
        C12 = Source(Start + 12)
        If C12 >= 65 And C12 <= 90 Then C12 = C12 + 32
    End If
    If Length = 2 Then
        If C0 = 105 And C1 = 102 Then WordCode = KwIf: Exit Function
        If C0 = 97 And C1 = 115 Then WordCode = KwAs: Exit Function
        If C0 = 111 And C1 = 110 Then WordCode = KwOn: Exit Function
        If C0 = 111 And C1 = 114 Then WordCode = KwOr: Exit Function
        If C0 = 105 And C1 = 115 Then WordCode = KwIs: Exit Function
        If C0 = 109 And C1 = 101 Then WordCode = KwMe: Exit Function
        If C0 = 116 And C1 = 111 Then WordCode = KwTo: Exit Function
        If C0 = 100 And C1 = 111 Then WordCode = KwDo: Exit Function
    End If
    If Length = 3 Then
        If C0 = 101 And C1 = 110 And C2 = 100 Then WordCode = KwEnd: Exit Function
        If C0 = 115 And C1 = 117 And C2 = 98 Then WordCode = KwSub: Exit Function
        If C0 = 100 And C1 = 105 And C2 = 109 Then WordCode = KwDim: Exit Function
        If C0 = 108 And C1 = 101 And C2 = 116 Then WordCode = KwLet: Exit Function
        If C0 = 115 And C1 = 101 And C2 = 116 Then WordCode = KwSet: Exit Function
        If C0 = 97 And C1 = 110 And C2 = 100 Then WordCode = KwAnd: Exit Function
        If C0 = 110 And C1 = 111 And C2 = 116 Then WordCode = KwNot: Exit Function
        If C0 = 120 And C1 = 111 And C2 = 114 Then WordCode = KwXor: Exit Function
        If C0 = 101 And C1 = 113 And C2 = 118 Then WordCode = KwEqv: Exit Function
        If C0 = 105 And C1 = 109 And C2 = 112 Then WordCode = KwImp: Exit Function
        If C0 = 109 And C1 = 111 And C2 = 100 Then WordCode = KwMod: Exit Function
        If C0 = 110 And C1 = 101 And C2 = 119 Then WordCode = KwNew: Exit Function
        If C0 = 97 And C1 = 110 And C2 = 121 Then WordCode = KwAny: Exit Function
        If C0 = 102 And C1 = 111 And C2 = 114 Then WordCode = KwFor: Exit Function
        If C0 = 97 And C1 = 115 And C2 = 109 Then WordCode = KwAsm: Exit Function
        If C0 = 108 And C1 = 105 And C2 = 98 Then WordCode = KwLib: Exit Function
        If C0 = 103 And C1 = 101 And C2 = 116 Then WordCode = KwGet: Exit Function
        If C0 = 112 And C1 = 117 And C2 = 116 Then WordCode = KwPut: Exit Function
        If C0 = 114 And C1 = 101 And C2 = 109 Then WordCode = KwRem: Exit Function
        If C0 = 117 And C1 = 98 And C2 = 101 Then WordCode = KwUbe: Exit Function
    End If
    If Length = 4 Then
        If C0 = 116 And C1 = 104 And C2 = 101 And C3 = 110 Then WordCode = KwThen: Exit Function
        If C0 = 101 And C1 = 108 And C2 = 115 And C3 = 101 Then WordCode = KwElse: Exit Function
        If C0 = 103 And C1 = 111 And C2 = 116 And C3 = 111 Then WordCode = KwGoto: Exit Function
        If C0 = 110 And C1 = 101 And C2 = 120 And C3 = 116 Then WordCode = KwNext: Exit Function
        If C0 = 101 And C1 = 120 And C2 = 105 And C3 = 116 Then WordCode = KwExit: Exit Function
        If C0 = 99 And C1 = 97 And C2 = 108 And C3 = 108 Then WordCode = KwCall: Exit Function
        If C0 = 108 And C1 = 115 And C2 = 101 And C3 = 116 Then WordCode = KwLset: Exit Function
        If C0 = 114 And C1 = 115 And C2 = 101 And C3 = 116 Then WordCode = KwRset: Exit Function
        If C0 = 116 And C1 = 114 And C2 = 117 And C3 = 101 Then WordCode = KwTrue: Exit Function
        If C0 = 108 And C1 = 105 And C2 = 107 And C3 = 101 Then WordCode = KwLike: Exit Function
        If C0 = 110 And C1 = 117 And C2 = 108 And C3 = 108 Then WordCode = KwNull: Exit Function
        If C0 = 98 And C1 = 121 And C2 = 116 And C3 = 101 Then WordCode = KwByte: Exit Function
        If C0 = 108 And C1 = 111 And C2 = 110 And C3 = 103 Then WordCode = KwLong: Exit Function
        If C0 = 100 And C1 = 97 And C2 = 116 And C3 = 101 Then WordCode = KwDate: Exit Function
        If C0 = 101 And C1 = 97 And C2 = 99 And C3 = 104 Then WordCode = KwEach: Exit Function
        If C0 = 115 And C1 = 116 And C2 = 101 And C3 = 112 Then WordCode = KwStep: Exit Function
        If C0 = 108 And C1 = 111 And C2 = 111 And C3 = 112 Then WordCode = KwLoop: Exit Function
        If C0 = 119 And C1 = 101 And C2 = 110 And C3 = 100 Then WordCode = KwWend: Exit Function
        If C0 = 119 And C1 = 105 And C2 = 116 And C3 = 104 Then WordCode = KwWith: Exit Function
        If C0 = 99 And C1 = 97 And C2 = 115 And C3 = 101 Then WordCode = KwCase: Exit Function
        If C0 = 115 And C1 = 116 And C2 = 111 And C3 = 112 Then WordCode = KwStop: Exit Function
        If C0 = 116 And C1 = 121 And C2 = 112 And C3 = 101 Then WordCode = KwType: Exit Function
        If C0 = 101 And C1 = 110 And C2 = 117 And C3 = 109 Then WordCode = KwEnum: Exit Function
        If C0 = 108 And C1 = 111 And C2 = 97 And C3 = 100 Then WordCode = KwLoad: Exit Function
        If C0 = 111 And C1 = 112 And C2 = 101 And C3 = 110 Then WordCode = KwOpen: Exit Function
        If C0 = 108 And C1 = 105 And C2 = 110 And C3 = 101 Then WordCode = KwLine: Exit Function
        If C0 = 115 And C1 = 101 And C2 = 101 And C3 = 107 Then WordCode = KwSeek: Exit Function
        If C0 = 107 And C1 = 105 And C2 = 108 And C3 = 108 Then WordCode = KwKill: Exit Function
        If C0 = 110 And C1 = 97 And C2 = 109 And C3 = 101 Then WordCode = KwName: Exit Function
        If C0 = 108 And C1 = 111 And C2 = 99 And C3 = 107 Then WordCode = KwLock: Exit Function
    End If
    If Length = 5 Then
        If C0 = 99 And C1 = 111 And C2 = 110 And C3 = 115 And C4 = 116 Then WordCode = KwConst: Exit Function
        If C0 = 98 And C1 = 121 And C2 = 118 And C3 = 97 And C4 = 108 Then WordCode = KwByval: Exit Function
        If C0 = 98 And C1 = 121 And C2 = 114 And C3 = 101 And C4 = 102 Then WordCode = KwByref: Exit Function
        If C0 = 103 And C1 = 111 And C2 = 115 And C3 = 117 And C4 = 98 Then WordCode = KwGosub: Exit Function
        If C0 = 101 And C1 = 114 And C2 = 114 And C3 = 111 And C4 = 114 Then WordCode = KwError: Exit Function
        If C0 = 102 And C1 = 97 And C2 = 108 And C3 = 115 And C4 = 101 Then WordCode = KwFalse: Exit Function
        If C0 = 105 And C1 = 115 And C2 = 110 And C3 = 111 And C4 = 116 Then WordCode = KwIsnot: Exit Function
        If C0 = 101 And C1 = 109 And C2 = 112 And C3 = 116 And C4 = 121 Then WordCode = KwEmpty: Exit Function
        If C0 = 119 And C1 = 104 And C2 = 105 And C3 = 108 And C4 = 101 Then WordCode = KwWhile: Exit Function
        If C0 = 117 And C1 = 110 And C2 = 116 And C3 = 105 And C4 = 108 Then WordCode = KwUntil: Exit Function
        If C0 = 112 And C1 = 114 And C2 = 105 And C3 = 110 And C4 = 116 Then WordCode = KwPrint: Exit Function
        If C0 = 97 And C1 = 108 And C2 = 105 And C3 = 97 And C4 = 115 Then WordCode = KwAlias: Exit Function
        If C0 = 101 And C1 = 118 And C2 = 101 And C3 = 110 And C4 = 116 Then WordCode = KwEvent: Exit Function
        If C0 = 114 And C1 = 101 And C2 = 100 And C3 = 105 And C4 = 109 Then WordCode = KwRedim: Exit Function
        If C0 = 101 And C1 = 114 And C2 = 97 And C3 = 115 And C4 = 101 Then WordCode = KwErase: Exit Function
        If C0 = 99 And C1 = 108 And C2 = 111 And C3 = 115 And C4 = 101 Then WordCode = KwClose: Exit Function
        If C0 = 105 And C1 = 110 And C2 = 112 And C3 = 117 And C4 = 116 Then WordCode = KwInput: Exit Function
        If C0 = 119 And C1 = 114 And C2 = 105 And C3 = 116 And C4 = 101 Then WordCode = KwWrite: Exit Function
        If C0 = 109 And C1 = 107 And C2 = 100 And C3 = 105 And C4 = 114 Then WordCode = KwMkdir: Exit Function
        If C0 = 114 And C1 = 109 And C2 = 100 And C3 = 105 And C4 = 114 Then WordCode = KwRmdir: Exit Function
        If C0 = 99 And C1 = 104 And C2 = 100 And C3 = 105 And C4 = 114 Then WordCode = KwChdir: Exit Function
        If C0 = 119 And C1 = 105 And C2 = 100 And C3 = 116 And C4 = 104 Then WordCode = KwWidth: Exit Function
    End If
    If Length = 6 Then
        If C0 = 101 And C1 = 108 And C2 = 115 And C3 = 101 And C4 = 105 And C5 = 102 Then WordCode = KwElseif: Exit Function
        If C0 = 112 And C1 = 117 And C2 = 98 And C3 = 108 And C4 = 105 And C5 = 99 Then WordCode = KwPublic: Exit Function
        If C0 = 102 And C1 = 114 And C2 = 105 And C3 = 101 And C4 = 110 And C5 = 100 Then WordCode = KwFriend: Exit Function
        If C0 = 103 And C1 = 108 And C2 = 111 And C3 = 98 And C4 = 97 And C5 = 108 Then WordCode = KwGlobal: Exit Function
        If C0 = 115 And C1 = 116 And C2 = 97 And C3 = 116 And C4 = 105 And C5 = 99 Then WordCode = KwStatic: Exit Function
        If C0 = 111 And C1 = 112 And C2 = 116 And C3 = 105 And C4 = 111 And C5 = 110 Then WordCode = KwOption: Exit Function
        If C0 = 114 And C1 = 101 And C2 = 115 And C3 = 117 And C4 = 109 And C5 = 101 Then WordCode = KwResume: Exit Function
        If C0 = 111 And C1 = 114 And C2 = 101 And C3 = 108 And C4 = 115 And C5 = 101 Then WordCode = KwOrelse: Exit Function
        If C0 = 116 And C1 = 121 And C2 = 112 And C3 = 101 And C4 = 111 And C5 = 102 Then WordCode = KwTypeof: Exit Function
        If C0 = 115 And C1 = 105 And C2 = 110 And C3 = 103 And C4 = 108 And C5 = 101 Then WordCode = KwSingle: Exit Function
        If C0 = 100 And C1 = 111 And C2 = 117 And C3 = 98 And C4 = 108 And C5 = 101 Then WordCode = KwDouble: Exit Function
        If C0 = 115 And C1 = 116 And C2 = 114 And C3 = 105 And C4 = 110 And C5 = 103 Then WordCode = KwString: Exit Function
        If C0 = 111 And C1 = 98 And C2 = 106 And C3 = 101 And C4 = 99 And C5 = 116 Then WordCode = KwObject: Exit Function
        If C0 = 105 And C1 = 110 And C2 = 116 And C3 = 112 And C4 = 116 And C5 = 114 Then WordCode = KwIntptr: Exit Function
        If C0 = 115 And C1 = 101 And C2 = 108 And C3 = 101 And C4 = 99 And C5 = 116 Then WordCode = KwSelect: Exit Function
        If C0 = 114 And C1 = 101 And C2 = 116 And C3 = 117 And C4 = 114 And C5 = 110 Then WordCode = KwReturn: Exit Function
        If C0 = 117 And C1 = 110 And C2 = 108 And C3 = 111 And C4 = 97 And C5 = 100 Then WordCode = KwUnload: Exit Function
        If C0 = 101 And C1 = 120 And C2 = 112 And C3 = 111 And C4 = 114 And C5 = 116 Then WordCode = KwExport: Exit Function
        If C0 = 117 And C1 = 110 And C2 = 108 And C3 = 111 And C4 = 99 And C5 = 107 Then WordCode = KwUnlock: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 99 And C4 = 117 And C5 = 114 Then WordCode = KwDefcur: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 100 And C4 = 98 And C5 = 108 Then WordCode = KwDefdbl: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 105 And C4 = 110 And C5 = 116 Then WordCode = KwDefint: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 108 And C4 = 110 And C5 = 103 Then WordCode = KwDeflng: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 111 And C4 = 98 And C5 = 106 Then WordCode = KwDefobj: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 115 And C4 = 110 And C5 = 103 Then WordCode = KwDefsng: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 115 And C4 = 116 And C5 = 114 Then WordCode = KwDefstr: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 118 And C4 = 97 And C5 = 114 Then WordCode = KwDefvar: Exit Function
        If C0 = 115 And C1 = 111 And C2 = 117 And C3 = 114 And C4 = 99 And C5 = 101 Then WordCode = KwSource: Exit Function
        If C0 = 109 And C1 = 111 And C2 = 100 And C3 = 117 And C4 = 108 And C5 = 101 Then WordCode = KwModule: Exit Function
    End If
    If Length = 7 Then
        If C0 = 112 And C1 = 114 And C2 = 105 And C3 = 118 And C4 = 97 And C5 = 116 And C6 = 101 Then WordCode = KwPrivate: Exit Function
        If C0 = 97 And C1 = 110 And C2 = 100 And C3 = 97 And C4 = 108 And C5 = 115 And C6 = 111 Then WordCode = KwAndalso: Exit Function
        If C0 = 110 And C1 = 111 And C2 = 116 And C3 = 104 And C4 = 105 And C5 = 110 And C6 = 103 Then WordCode = KwNothing: Exit Function
        If C0 = 98 And C1 = 111 And C2 = 111 And C3 = 108 And C4 = 101 And C5 = 97 And C6 = 110 Then WordCode = KwBoolean: Exit Function
        If C0 = 105 And C1 = 110 And C2 = 116 And C3 = 101 And C4 = 103 And C5 = 101 And C6 = 114 Then WordCode = KwInteger: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 99 And C3 = 105 And C4 = 109 And C5 = 97 And C6 = 108 Then WordCode = KwDecimal: Exit Function
        If C0 = 118 And C1 = 97 And C2 = 114 And C3 = 105 And C4 = 97 And C5 = 110 And C6 = 116 Then WordCode = KwVariant: Exit Function
        If C0 = 117 And C1 = 105 And C2 = 110 And C3 = 116 And C4 = 112 And C5 = 116 And C6 = 114 Then WordCode = KwUintptr: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 99 And C3 = 108 And C4 = 97 And C5 = 114 And C6 = 101 Then WordCode = KwDeclare: Exit Function
        If C0 = 99 And C1 = 97 And C2 = 108 And C3 = 108 And C4 = 110 And C5 = 101 And C6 = 119 Then WordCode = KwCallnew: Exit Function
        If C0 = 99 And C1 = 104 And C2 = 100 And C3 = 114 And C4 = 105 And C5 = 118 And C6 = 101 Then WordCode = KwChdrive: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 98 And C4 = 111 And C5 = 111 And C6 = 108 Then WordCode = KwDefbool: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 98 And C4 = 121 And C5 = 116 And C6 = 101 Then WordCode = KwDefbyte: Exit Function
        If C0 = 100 And C1 = 101 And C2 = 102 And C3 = 100 And C4 = 97 And C5 = 116 And C6 = 101 Then WordCode = KwDefdate: Exit Function
    End If
    If Length = 8 Then
        If C0 = 102 And C1 = 117 And C2 = 110 And C3 = 99 And C4 = 116 And C5 = 105 And C6 = 111 And C7 = 110 Then WordCode = KwFunction: Exit Function
        If C0 = 111 And C1 = 112 And C2 = 116 And C3 = 105 And C4 = 111 And C5 = 110 And C6 = 97 And C7 = 108 Then WordCode = KwOptional: Exit Function
        If C0 = 101 And C1 = 120 And C2 = 112 And C3 = 108 And C4 = 105 And C5 = 99 And C6 = 105 And C7 = 116 Then WordCode = KwExplicit: Exit Function
        If C0 = 108 And C1 = 111 And C2 = 110 And C3 = 103 And C4 = 108 And C5 = 111 And C6 = 110 And C7 = 103 Then WordCode = KwLonglong: Exit Function
        If C0 = 99 And C1 = 117 And C2 = 114 And C3 = 114 And C4 = 101 And C5 = 110 And C6 = 99 And C7 = 121 Then WordCode = KwCurrency: Exit Function
        If C0 = 98 And C1 = 121 And C2 = 116 And C3 = 101 And C4 = 99 And C5 = 111 And C6 = 100 And C7 = 101 Then WordCode = KwBytecode: Exit Function
        If C0 = 112 And C1 = 114 And C2 = 111 And C3 = 112 And C4 = 101 And C5 = 114 And C6 = 116 And C7 = 121 Then WordCode = KwProperty: Exit Function
        If C0 = 115 And C1 = 121 And C2 = 110 And C3 = 99 And C4 = 108 And C5 = 111 And C6 = 99 And C7 = 107 Then WordCode = KwSynclock: Exit Function
        If C0 = 102 And C1 = 105 And C2 = 108 And C3 = 101 And C4 = 99 And C5 = 111 And C6 = 112 And C7 = 121 Then WordCode = KwFilecopy: Exit Function
        If C0 = 117 And C1 = 98 And C2 = 101 And C3 = 95 And C4 = 110 And C5 = 97 And C6 = 109 And C7 = 101 Then WordCode = KwUbeName: Exit Function
        If C0 = 112 And C1 = 114 And C2 = 101 And C3 = 115 And C4 = 101 And C5 = 114 And C6 = 118 And C7 = 101 Then WordCode = KwPreserve: Exit Function
    End If
    If Length = 9 Then
        If C0 = 105 And C1 = 110 And C2 = 116 And C3 = 101 And C4 = 114 And C5 = 102 And C6 = 97 And C7 = 99 And C8 = 101 Then WordCode = KwInterface: Exit Function
        If C0 = 105 And C1 = 110 And C2 = 116 And C3 = 114 And C4 = 105 And C5 = 110 And C6 = 115 And C7 = 105 And C8 = 99 Then WordCode = KwIntrinsic: Exit Function
        If C0 = 97 And C1 = 116 And C2 = 116 And C3 = 114 And C4 = 105 And C5 = 98 And C6 = 117 And C7 = 116 And C8 = 101 Then WordCode = KwAttribute: Exit Function
        If C0 = 97 And C1 = 100 And C2 = 100 And C3 = 114 And C4 = 101 And C5 = 115 And C6 = 115 And C7 = 111 And C8 = 102 Then WordCode = KwAddressof: Exit Function
        If C0 = 114 And C1 = 97 And C2 = 110 And C3 = 100 And C4 = 111 And C5 = 109 And C6 = 105 And C7 = 122 And C8 = 101 Then WordCode = KwRandomize: Exit Function
    End If
    If Length = 10 Then
        If C0 = 112 And C1 = 97 And C2 = 114 And C3 = 97 And C4 = 109 And C5 = 97 And C6 = 114 And C7 = 114 And C8 = 97 And C9 = 121 Then WordCode = KwParamarray: Exit Function
        If C0 = 105 And C1 = 109 And C2 = 112 And C3 = 108 And C4 = 101 And C5 = 109 And C6 = 101 And C7 = 110 And C8 = 116 And C9 = 115 Then WordCode = KwImplements: Exit Function
        If C0 = 114 And C1 = 97 And C2 = 105 And C3 = 115 And C4 = 101 And C5 = 101 And C6 = 118 And C7 = 101 And C8 = 110 And C9 = 116 Then WordCode = KwRaiseevent: Exit Function
        If C0 = 119 And C1 = 105 And C2 = 116 And C3 = 104 And C4 = 101 And C5 = 118 And C6 = 101 And C7 = 110 And C8 = 116 And C9 = 115 Then WordCode = KwWithevents: Exit Function
    End If
    If Length = 13 Then
        If C0 = 117 And C1 = 98 And C2 = 101 And C3 = 95 And C4 = 112 And C5 = 114 And C6 = 105 And C7 = 109 And C8 = 105 And C9 = 116 And C10 = 105 And C11 = 118 And C12 = 101 Then WordCode = KwUbePrimitive: Exit Function
    End If
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Maps bounded lookahead to a stable kind, symbol or keyword code; brackets never become keywords.
Public Function TokenCode(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal Index As Long, ByVal Count As Long) As Long
    Dim Kind As Long
    Dim Start As Long
    Dim Length As Long
    Dim First As Long
    Dim Second As Long
    On Error GoTo Failed
    If Index < 0 Or Index >= Count Then TokenCode = CodeEnd: Exit Function
    Kind = Tokens(Index).Kind
    Start = Tokens(Index).ByteStart
    Length = Tokens(Index).ByteLength
    If Kind = SourceScanner.IdentifierToken Then TokenCode = CodeIdentifier: Exit Function
    If Kind = SourceScanner.WordToken Then TokenCode = WordCode(Source, Start, Length): Exit Function
    If Kind = SourceScanner.NumberToken Then TokenCode = CodeNumber: Exit Function
    If Kind = SourceScanner.StringToken Then TokenCode = CodeString: Exit Function
    If Kind = SourceScanner.NewlineToken Then TokenCode = CodeNewline: Exit Function
    If Kind = SourceScanner.EndToken Then TokenCode = CodeEnd: Exit Function
    If Kind <> SourceScanner.SymbolToken Then TokenCode = CodeUnknown: Exit Function
    If Length < 1 Or Length > 2 Then TokenCode = CodeUnknown: Exit Function
    First = Source(Start)
    If Length = 2 Then
        Second = Source(Start + 1)
        If First = 60 And Second = 61 Then TokenCode = SymLessEqual: Exit Function
        If First = 62 And Second = 61 Then TokenCode = SymGreaterEqual: Exit Function
        If First = 60 And Second = 62 Then TokenCode = SymNotEqual: Exit Function
        If First = 58 And Second = 61 Then TokenCode = SymAssignNamed: Exit Function
        TokenCode = CodeUnknown
        Exit Function
    End If
    If First = 40 Then TokenCode = SymOpen: Exit Function
    If First = 41 Then TokenCode = SymClose: Exit Function
    If First = 46 Then TokenCode = SymDot: Exit Function
    If First = 44 Then TokenCode = SymComma: Exit Function
    If First = 58 Then TokenCode = SymColon: Exit Function
    If First = 61 Then TokenCode = SymEqual: Exit Function
    If First = 43 Then TokenCode = SymPlus: Exit Function
    If First = 45 Then TokenCode = SymMinus: Exit Function
    If First = 60 Then TokenCode = SymLess: Exit Function
    If First = 62 Then TokenCode = SymGreater: Exit Function
    If First = 37 Then TokenCode = SymPercent: Exit Function
    If First = 38 Then TokenCode = SymAmpersand: Exit Function
    If First = 94 Then TokenCode = SymCaret: Exit Function
    If First = 42 Then TokenCode = SymStar: Exit Function
    If First = 47 Then TokenCode = SymSlash: Exit Function
    If First = 92 Then TokenCode = SymBackslash: Exit Function
    If First = 33 Then TokenCode = SymBang: Exit Function
    If First = 36 Then TokenCode = SymDollar: Exit Function
    If First = 64 Then TokenCode = SymAt: Exit Function
    If First = 59 Then TokenCode = SymSemicolon: Exit Function
    TokenCode = CodeUnknown
    Exit Function
Failed:
    Err.Raise Err.Number
End Function


' Classifies identifier contents only when a metadata consumer explicitly requests decoded spelling.
Public Function DecodedIdentifierCode(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal Index As Long, ByVal Count As Long) As Long
    On Error GoTo Failed
    If Index < 0 Or Index >= Count Then DecodedIdentifierCode = CodeUnknown: Exit Function
    If Tokens(Index).Kind = SourceScanner.WordToken Then DecodedIdentifierCode = TokenCode(Source, Tokens, Index, Count): Exit Function
    If Tokens(Index).Kind <> SourceScanner.IdentifierToken Then DecodedIdentifierCode = CodeUnknown: Exit Function
    ' No recognized keyword contains a closing bracket, so escaped brackets cannot match the table.
    DecodedIdentifierCode = WordCode(Source, Tokens(Index).ByteStart + 1, Tokens(Index).ByteLength - 2)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Accepts decoded identifiers, optionally permitting reserved words after member punctuation.
Public Function IsIdentifierToken(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal Index As Long, ByVal Count As Long, ByVal AllowReserved As Boolean) As Boolean
    Dim Code As Long
    On Error GoTo Failed
    If Index < 0 Or Index >= Count Then IsIdentifierToken = False: Exit Function
    If Tokens(Index).Kind = SourceScanner.IdentifierToken Then IsIdentifierToken = True: Exit Function
    If Tokens(Index).Kind <> SourceScanner.WordToken Then IsIdentifierToken = False: Exit Function
    Code = TokenCode(Source, Tokens, Index, Count)
    IsIdentifierToken = AllowReserved Or Code = CodeIdentifier Or Code >= 1000
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Reads and ASCII-folds one decoded spelling byte, consuming doubled quote or bracket escapes.
Private Function NextCharacter(ByRef Source() As Byte, ByRef Position As Long, ByVal Finish As Long, ByVal Closing As Long) As Long
    Dim Value As Long
    On Error GoTo Failed
    If Position >= Finish Then NextCharacter = -1: Exit Function
    Value = Source(Position)
    Position = Position + 1
    If Closing <> 0 And Value = Closing Then
        If Position < Finish Then
            If Source(Position) = Closing Then Position = Position + 1
        End If
    End If
    If Value >= 65 And Value <= 90 Then Value = Value + 32
    NextCharacter = Value
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Reads one decoded, ASCII-folded spelling byte by logical byte position.
' Tokens must belong to the matching validated source; -1 denotes the end.
Public Function SpellingByte(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal Index As Long, ByVal Count As Long, ByVal Position As Long) As Long
    Dim Cursor As Long
    Dim Finish As Long
    Dim Closing As Long
    Dim Character As Long
    Dim Offset As Long
    On Error GoTo Failed
    If Index < 0 Or Index >= Count Or Position < 0 Then SpellingByte = -1: Exit Function
    If Tokens(Index).Kind <> SourceScanner.WordToken And Tokens(Index).Kind <> SourceScanner.IdentifierToken And Tokens(Index).Kind <> SourceScanner.StringToken And Tokens(Index).Kind <> SourceScanner.NumberToken Then SpellingByte = -1: Exit Function
    Cursor = Tokens(Index).ByteStart
    Finish = Cursor + Tokens(Index).ByteLength
    If Tokens(Index).Kind = SourceScanner.IdentifierToken Then Closing = 93
    If Tokens(Index).Kind = SourceScanner.StringToken Then Closing = 34
    If Closing = 0 Then
        If Position >= Tokens(Index).ByteLength Then SpellingByte = -1: Exit Function
        Cursor = Cursor + Position
        SpellingByte = NextCharacter(Source, Cursor, Finish, Closing)
        Exit Function
    End If
    If Closing <> 0 Then Cursor = Cursor + 1: Finish = Finish - 1
    Do
        Character = NextCharacter(Source, Cursor, Finish, Closing)
        If Character = -1 Or Offset = Position Then SpellingByte = Character: Exit Function
        Offset = Offset + 1
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Compares decoded token spellings without copying bytes or materializing a String.
Private Function EqualSpelling(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal First As Long, ByVal Second As Long) As Boolean
    Dim LeftPosition As Long
    Dim RightPosition As Long
    Dim LeftFinish As Long
    Dim RightFinish As Long
    Dim LeftClosing As Long
    Dim RightClosing As Long
    Dim LeftValue As Long
    Dim RightValue As Long
    On Error GoTo Failed
    LeftPosition = Tokens(First).ByteStart
    LeftFinish = LeftPosition + Tokens(First).ByteLength
    RightPosition = Tokens(Second).ByteStart
    RightFinish = RightPosition + Tokens(Second).ByteLength
    If Tokens(First).Kind = SourceScanner.IdentifierToken Then LeftClosing = 93
    If Tokens(First).Kind = SourceScanner.StringToken Then LeftClosing = 34
    If Tokens(Second).Kind = SourceScanner.IdentifierToken Then RightClosing = 93
    If Tokens(Second).Kind = SourceScanner.StringToken Then RightClosing = 34
    If LeftClosing <> 0 Then LeftPosition = LeftPosition + 1: LeftFinish = LeftFinish - 1
    If RightClosing <> 0 Then RightPosition = RightPosition + 1: RightFinish = RightFinish - 1
    Do
        LeftValue = NextCharacter(Source, LeftPosition, LeftFinish, LeftClosing)
        RightValue = NextCharacter(Source, RightPosition, RightFinish, RightClosing)
        If LeftValue <> RightValue Then EqualSpelling = False: Exit Function
        If LeftValue = -1 Then EqualSpelling = True: Exit Function
    Loop
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Compares two identifier spellings using the admitted ASCII case-fold and bracket escapes.
Public Function SameIdentifier(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal First As Long, ByVal Second As Long, ByVal Count As Long) As Boolean
    On Error GoTo Failed
    If Not IsIdentifierToken(Source, Tokens, First, Count, True) Then SameIdentifier = False: Exit Function
    If Not IsIdentifierToken(Source, Tokens, Second, Count, True) Then SameIdentifier = False: Exit Function
    SameIdentifier = EqualSpelling(Source, Tokens, First, Second)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Compares a decoded string literal with an identifier, for source identity metadata.
Public Function StringEqualsIdentifier(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal StringIndex As Long, ByVal NameIndex As Long, ByVal Count As Long) As Boolean
    On Error GoTo Failed
    If StringIndex < 0 Or StringIndex >= Count Then StringEqualsIdentifier = False: Exit Function
    If Tokens(StringIndex).Kind <> SourceScanner.StringToken Then StringEqualsIdentifier = False: Exit Function
    If Not IsIdentifierToken(Source, Tokens, NameIndex, Count, True) Then StringEqualsIdentifier = False: Exit Function
    StringEqualsIdentifier = EqualSpelling(Source, Tokens, StringIndex, NameIndex)
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Validates the quoted native module name against the loader's ASCII identifier contract.
Public Function IsModuleNameToken(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal Index As Long, ByVal Count As Long) As Boolean
    Dim Position As Long
    Dim Finish As Long
    Dim Value As Long
    Dim Initial As Boolean = True
    Dim Valid As Boolean
    On Error GoTo Failed
    If Index < 0 Or Index >= Count Then IsModuleNameToken = False: Exit Function
    If Tokens(Index).Kind <> SourceScanner.StringToken Then IsModuleNameToken = False: Exit Function
    If Tokens(Index).ByteLength < 3 Or Tokens(Index).ByteLength > 130 Then IsModuleNameToken = False: Exit Function
    Position = Tokens(Index).ByteStart + 1
    Finish = Position + Tokens(Index).ByteLength - 2
    Do While Position < Finish
        Value = Source(Position)
        Valid = (Value >= 65 And Value <= 90) Or (Value >= 97 And Value <= 122) Or Value = 95
        If Not Initial Then Valid = Valid Or (Value >= 48 And Value <= 57)
        If Not Valid Then IsModuleNameToken = False: Exit Function
        Initial = False
        Position = Position + 1
    Loop
    IsModuleNameToken = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Recognizes unsigned decimal statement labels, without consuming integer type suffixes.
Public Function IsDecimalLabelToken(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal Index As Long, ByVal Count As Long) As Boolean
    Dim Position As Long
    Dim Finish As Long
    Dim Value As Long
    On Error GoTo Failed
    If Index < 0 Or Index >= Count Then IsDecimalLabelToken = False: Exit Function
    If Tokens(Index).Kind <> SourceScanner.NumberToken Then IsDecimalLabelToken = False: Exit Function
    Position = Tokens(Index).ByteStart
    Finish = Position + Tokens(Index).ByteLength
    If Position = Finish Then IsDecimalLabelToken = False: Exit Function
    Do While Position < Finish
        Value = Source(Position)
        If Value < 48 Or Value > 57 Then IsDecimalLabelToken = False: Exit Function
        Position = Position + 1
    Loop
    IsDecimalLabelToken = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function

' Recognizes integral spelling and its optional integer suffix, leaving magnitude checks to binding.
Public Function IsIntegerToken(ByRef Source() As Byte, ByRef Tokens() As SourceScanner.SourceToken, ByVal Index As Long, ByVal Count As Long) As Boolean
    Dim Position As Long
    Dim Finish As Long
    Dim Value As Long
    Dim Radix As Long = 10
    Dim Valid As Boolean
    On Error GoTo Failed
    If Index < 0 Or Index >= Count Then IsIntegerToken = False: Exit Function
    If Tokens(Index).Kind <> SourceScanner.NumberToken Then IsIntegerToken = False: Exit Function
    Position = Tokens(Index).ByteStart
    Finish = Position + Tokens(Index).ByteLength
    If Position >= Finish Then IsIntegerToken = False: Exit Function
    Value = Source(Finish - 1)
    If Value = 37 Or Value = 38 Or Value = 94 Then Finish = Finish - 1
    If Position >= Finish Then IsIntegerToken = False: Exit Function
    If Source(Position) = 38 Then
        If Finish - Position < 3 Then IsIntegerToken = False: Exit Function
        Value = Source(Position + 1)
        If Value >= 65 And Value <= 90 Then Value = Value + 32
        If Value = 104 Then
            Radix = 16
        ElseIf Value = 111 Then
            Radix = 8
        Else
            IsIntegerToken = False
            Exit Function
        End If
        Position = Position + 2
    End If
    Do While Position < Finish
        Value = Source(Position)
        If Value >= 65 And Value <= 90 Then Value = Value + 32
        Valid = Value >= 48 And Value <= 57
        If Radix = 8 Then Valid = Value >= 48 And Value <= 55
        If Radix = 16 Then Valid = Valid Or (Value >= 97 And Value <= 102)
        If Not Valid Then IsIntegerToken = False: Exit Function
        Position = Position + 1
    Loop
    IsIntegerToken = True
    Exit Function
Failed:
    Err.Raise Err.Number
End Function
