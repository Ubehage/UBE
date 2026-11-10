UBE SOURCE 1 MODULE
Attribute UBE_Name = "QuotaProbe"
' Exercises the production charged-page quota with finite record payloads.
Public Type WideRecord
    Cell0 As LongLong
    Cell1 As LongLong
    Cell2 As LongLong
    Cell3 As LongLong
    Cell4 As LongLong
    Cell5 As LongLong
    Cell6 As LongLong
    Cell7 As LongLong
    Cell8 As LongLong
    Cell9 As LongLong
    Cell10 As LongLong
    Cell11 As LongLong
    Cell12 As LongLong
    Cell13 As LongLong
    Cell14 As LongLong
    Cell15 As LongLong
    Cell16 As LongLong
    Cell17 As LongLong
    Cell18 As LongLong
    Cell19 As LongLong
    Cell20 As LongLong
    Cell21 As LongLong
    Cell22 As LongLong
    Cell23 As LongLong
    Cell24 As LongLong
    Cell25 As LongLong
    Cell26 As LongLong
    Cell27 As LongLong
    Cell28 As LongLong
    Cell29 As LongLong
    Cell30 As LongLong
    Cell31 As LongLong
    Cell32 As LongLong
    Cell33 As LongLong
    Cell34 As LongLong
    Cell35 As LongLong
    Cell36 As LongLong
    Cell37 As LongLong
    Cell38 As LongLong
    Cell39 As LongLong
    Cell40 As LongLong
    Cell41 As LongLong
    Cell42 As LongLong
    Cell43 As LongLong
    Cell44 As LongLong
    Cell45 As LongLong
    Cell46 As LongLong
    Cell47 As LongLong
    Cell48 As LongLong
    Cell49 As LongLong
    Cell50 As LongLong
    Cell51 As LongLong
    Cell52 As LongLong
    Cell53 As LongLong
    Cell54 As LongLong
    Cell55 As LongLong
    Cell56 As LongLong
    Cell57 As LongLong
    Cell58 As LongLong
    Cell59 As LongLong
    Cell60 As LongLong
    Cell61 As LongLong
    Cell62 As LongLong
    Cell63 As LongLong
    Cell64 As LongLong
    Cell65 As LongLong
    Cell66 As LongLong
    Cell67 As LongLong
    Cell68 As LongLong
    Cell69 As LongLong
    Cell70 As LongLong
    Cell71 As LongLong
    Cell72 As LongLong
    Cell73 As LongLong
    Cell74 As LongLong
    Cell75 As LongLong
    Cell76 As LongLong
    Cell77 As LongLong
    Cell78 As LongLong
    Cell79 As LongLong
    Cell80 As LongLong
    Cell81 As LongLong
    Cell82 As LongLong
    Cell83 As LongLong
    Cell84 As LongLong
    Cell85 As LongLong
    Cell86 As LongLong
    Cell87 As LongLong
    Cell88 As LongLong
    Cell89 As LongLong
    Cell90 As LongLong
    Cell91 As LongLong
    Cell92 As LongLong
    Cell93 As LongLong
    Cell94 As LongLong
    Cell95 As LongLong
    Cell96 As LongLong
    Cell97 As LongLong
    Cell98 As LongLong
    Cell99 As LongLong
    Cell100 As LongLong
    Cell101 As LongLong
    Cell102 As LongLong
    Cell103 As LongLong
    Cell104 As LongLong
    Cell105 As LongLong
    Cell106 As LongLong
    Cell107 As LongLong
    Cell108 As LongLong
    Cell109 As LongLong
    Cell110 As LongLong
    Cell111 As LongLong
    Cell112 As LongLong
    Cell113 As LongLong
    Cell114 As LongLong
    Cell115 As LongLong
    Cell116 As LongLong
    Cell117 As LongLong
    Cell118 As LongLong
    Cell119 As LongLong
    Cell120 As LongLong
    Cell121 As LongLong
    Cell122 As LongLong
    Cell123 As LongLong
    Cell124 As LongLong
    Cell125 As LongLong
    Cell126 As LongLong
    Cell127 As LongLong
End Type
Private Block0() As WideRecord
Private Block1() As WideRecord
Private Block2() As WideRecord
Private Block3() As WideRecord
Private Block4() As WideRecord
Private Block5() As WideRecord
Private Block6() As WideRecord
Private Block7() As WideRecord
Private Block8() As WideRecord
Private Block9() As WideRecord
Private Block10() As WideRecord
Private Block11() As WideRecord
Private Block12() As WideRecord
Private Block13() As WideRecord
Private Block14() As WideRecord
Private Block15() As WideRecord

' Requests storage with 128 scalar cells per logical array element.
Public Intrinsic Function ResizeWide(ByRef Values() As WideRecord, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute ResizeWide.UBE_Primitive = "Array.TryResize"
End Function

' Fifteen charged 4MiB payloads fit; the sixteenth exceeds the 64MiB page quota.
Public Function CheckHeapQuota(ByVal Seed As Long) As Long
    Dim Status As Boolean
    Dim Value As LongLong
    Status = ResizeWide(Block0, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 1: Exit Function
    Status = ResizeWide(Block1, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 2: Exit Function
    Status = ResizeWide(Block2, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 3: Exit Function
    Status = ResizeWide(Block3, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 4: Exit Function
    Status = ResizeWide(Block4, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 5: Exit Function
    Status = ResizeWide(Block5, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 6: Exit Function
    Status = ResizeWide(Block6, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 7: Exit Function
    Status = ResizeWide(Block7, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 8: Exit Function
    Status = ResizeWide(Block8, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 9: Exit Function
    Status = ResizeWide(Block9, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 10: Exit Function
    Status = ResizeWide(Block10, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 11: Exit Function
    Status = ResizeWide(Block11, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 12: Exit Function
    Status = ResizeWide(Block12, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 13: Exit Function
    Status = ResizeWide(Block13, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 14: Exit Function
    Status = ResizeWide(Block14, 4095 + Seed, False)
    If Status = False Then CheckHeapQuota = 15: Exit Function
    Block0(0).Cell0 = 13
    Status = ResizeWide(Block15, 4095 + Seed, False)
    If Status <> False Then CheckHeapQuota = 16: Exit Function
    If Err.Number <> 7 Then CheckHeapQuota = 17: Exit Function
    Value = Block0(0).Cell0
    If Value <> 13 Then CheckHeapQuota = 18: Exit Function
    CheckHeapQuota = 0
End Function
