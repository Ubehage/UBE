UBE SOURCE 1 MODULE
Attribute UBE_Name = "Unicode"

' Generated offline by std-lib/tools/generate-unicode.ps1; do not edit tables.
' Unicode 18.0.0 data and Unicode License V3: ../../data/unicode/18.0.0/.
' Stateless, allocation/copy-free, reentrant; preserve Err and retain nothing.
' Balanced decisions: logarithmic comparisons; no mutable initialization.

' True exactly for Unicode Lu/Ll/Lt/Lm/Lo. Invalid scalar values return False.
Function IsUnicodeLetter(ByVal Scalar As Long) As Boolean
    IsUnicodeLetter = False
    If Scalar < 0 Or Scalar > 1114111 Then
        Exit Function
    End If
    If Scalar < 43816 Then
        If Scalar < 4348 Then
            If Scalar < 2749 Then
                If Scalar < 2042 Then
                    If Scalar < 1015 Then
                        If Scalar < 748 Then
                            If Scalar < 192 Then
                                If Scalar < 170 Then
                                    If Scalar >= 65 And Scalar <= 90 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 97 And Scalar <= 122 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 170 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 181 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 186 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 248 Then
                                    If Scalar >= 192 And Scalar <= 214 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 216 And Scalar <= 246 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 248 And Scalar <= 705 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 710 And Scalar <= 721 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 736 And Scalar <= 740 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 895 Then
                                If Scalar < 880 Then
                                    If Scalar = 748 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 750 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 880 And Scalar <= 884 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 886 And Scalar <= 887 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 890 And Scalar <= 893 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 908 Then
                                    If Scalar = 895 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 902 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 904 And Scalar <= 906 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 908 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 910 And Scalar <= 929 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 931 And Scalar <= 1013 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 1749 Then
                            If Scalar < 1419 Then
                                If Scalar < 1329 Then
                                    If Scalar >= 1015 And Scalar <= 1153 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1162 And Scalar <= 1327 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 1329 And Scalar <= 1366 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1368 And Scalar <= 1369 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1376 And Scalar <= 1416 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 1568 Then
                                    If Scalar >= 1419 And Scalar <= 1420 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1488 And Scalar <= 1514 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1519 And Scalar <= 1522 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 1568 And Scalar <= 1610 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1646 And Scalar <= 1647 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1649 And Scalar <= 1747 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 1808 Then
                                If Scalar < 1774 Then
                                    If Scalar = 1749 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1765 And Scalar <= 1766 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 1774 And Scalar <= 1775 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1786 And Scalar <= 1788 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 1791 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 1969 Then
                                    If Scalar = 1808 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1810 And Scalar <= 1839 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1869 And Scalar <= 1957 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 1969 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 1994 And Scalar <= 2026 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2036 And Scalar <= 2037 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                Else
                    If Scalar < 2493 Then
                        If Scalar < 2308 Then
                            If Scalar < 2112 Then
                                If Scalar < 2074 Then
                                    If Scalar = 2042 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2048 And Scalar <= 2069 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 2074 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2084 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2088 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 2160 Then
                                    If Scalar >= 2112 And Scalar <= 2136 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2144 And Scalar <= 2154 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2160 And Scalar <= 2183 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2185 And Scalar <= 2191 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2208 And Scalar <= 2249 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 2437 Then
                                If Scalar < 2384 Then
                                    If Scalar >= 2308 And Scalar <= 2361 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2365 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 2384 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2392 And Scalar <= 2401 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2417 And Scalar <= 2432 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 2474 Then
                                    If Scalar >= 2437 And Scalar <= 2444 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2447 And Scalar <= 2448 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2451 And Scalar <= 2472 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2474 And Scalar <= 2480 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2482 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2486 And Scalar <= 2489 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 2613 Then
                            If Scalar < 2556 Then
                                If Scalar < 2524 Then
                                    If Scalar = 2493 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2510 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2524 And Scalar <= 2525 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2527 And Scalar <= 2529 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2544 And Scalar <= 2545 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 2579 Then
                                    If Scalar = 2556 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2565 And Scalar <= 2570 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2575 And Scalar <= 2576 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2579 And Scalar <= 2600 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2602 And Scalar <= 2608 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2610 And Scalar <= 2611 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 2693 Then
                                If Scalar < 2649 Then
                                    If Scalar >= 2613 And Scalar <= 2614 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2616 And Scalar <= 2617 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2649 And Scalar <= 2652 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2654 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2674 And Scalar <= 2676 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 2730 Then
                                    If Scalar >= 2693 And Scalar <= 2701 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2703 And Scalar <= 2705 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2707 And Scalar <= 2728 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2730 And Scalar <= 2736 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2738 And Scalar <= 2739 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2741 And Scalar <= 2745 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            Else
                If Scalar < 3332 Then
                    If Scalar < 2979 Then
                        If Scalar < 2877 Then
                            If Scalar < 2831 Then
                                If Scalar < 2784 Then
                                    If Scalar = 2749 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2768 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2784 And Scalar <= 2785 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2809 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2821 And Scalar <= 2828 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 2858 Then
                                    If Scalar >= 2831 And Scalar <= 2832 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2835 And Scalar <= 2856 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2858 And Scalar <= 2864 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2866 And Scalar <= 2867 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2869 And Scalar <= 2873 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 2949 Then
                                If Scalar < 2911 Then
                                    If Scalar = 2877 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2908 And Scalar <= 2909 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2911 And Scalar <= 2913 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2929 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2947 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 2969 Then
                                    If Scalar >= 2949 And Scalar <= 2954 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2958 And Scalar <= 2960 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2962 And Scalar <= 2965 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2969 And Scalar <= 2970 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 2972 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2974 And Scalar <= 2975 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 3168 Then
                            If Scalar < 3086 Then
                                If Scalar < 2990 Then
                                    If Scalar >= 2979 And Scalar <= 2980 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 2984 And Scalar <= 2986 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 2990 And Scalar <= 3001 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 3024 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3077 And Scalar <= 3084 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 3133 Then
                                    If Scalar >= 3086 And Scalar <= 3088 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3090 And Scalar <= 3112 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3114 And Scalar <= 3129 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 3133 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3160 And Scalar <= 3162 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3164 And Scalar <= 3165 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 3242 Then
                                If Scalar < 3205 Then
                                    If Scalar >= 3168 And Scalar <= 3169 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 3200 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 3205 And Scalar <= 3212 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3214 And Scalar <= 3216 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3218 And Scalar <= 3240 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 3292 Then
                                    If Scalar >= 3242 And Scalar <= 3251 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3253 And Scalar <= 3257 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 3261 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 3292 And Scalar <= 3294 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3296 And Scalar <= 3297 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3313 And Scalar <= 3314 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                Else
                    If Scalar < 3762 Then
                        If Scalar < 3517 Then
                            If Scalar < 3412 Then
                                If Scalar < 3346 Then
                                    If Scalar >= 3332 And Scalar <= 3340 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3342 And Scalar <= 3344 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 3346 And Scalar <= 3386 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 3389 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 3406 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 3461 Then
                                    If Scalar >= 3412 And Scalar <= 3414 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3423 And Scalar <= 3425 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3450 And Scalar <= 3455 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 3461 And Scalar <= 3478 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3482 And Scalar <= 3505 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3507 And Scalar <= 3515 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 3713 Then
                                If Scalar < 3585 Then
                                    If Scalar = 3517 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3520 And Scalar <= 3526 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 3585 And Scalar <= 3632 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3634 And Scalar <= 3635 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3648 And Scalar <= 3654 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 3724 Then
                                    If Scalar >= 3713 And Scalar <= 3714 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 3716 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3718 And Scalar <= 3722 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 3724 And Scalar <= 3747 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 3749 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3751 And Scalar <= 3760 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 4176 Then
                            If Scalar < 3840 Then
                                If Scalar < 3776 Then
                                    If Scalar >= 3762 And Scalar <= 3763 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 3773 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 3776 And Scalar <= 3780 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 3782 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3804 And Scalar <= 3807 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 3976 Then
                                    If Scalar = 3840 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3904 And Scalar <= 3911 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 3913 And Scalar <= 3948 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 3976 And Scalar <= 3980 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4096 And Scalar <= 4138 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 4159 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 4213 Then
                                If Scalar < 4193 Then
                                    If Scalar >= 4176 And Scalar <= 4181 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4186 And Scalar <= 4189 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 4193 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4197 And Scalar <= 4198 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4206 And Scalar <= 4208 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 4295 Then
                                    If Scalar >= 4213 And Scalar <= 4225 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 4238 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4256 And Scalar <= 4293 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 4295 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 4301 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4304 And Scalar <= 4346 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        Else
            If Scalar < 8473 Then
                If Scalar < 6688 Then
                    If Scalar < 5761 Then
                        If Scalar < 4800 Then
                            If Scalar < 4704 Then
                                If Scalar < 4688 Then
                                    If Scalar >= 4348 And Scalar <= 4680 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4682 And Scalar <= 4685 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 4688 And Scalar <= 4694 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 4696 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4698 And Scalar <= 4701 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 4752 Then
                                    If Scalar >= 4704 And Scalar <= 4744 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4746 And Scalar <= 4749 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 4752 And Scalar <= 4784 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4786 And Scalar <= 4789 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4792 And Scalar <= 4798 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 4888 Then
                                If Scalar < 4808 Then
                                    If Scalar = 4800 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4802 And Scalar <= 4805 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 4808 And Scalar <= 4822 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4824 And Scalar <= 4880 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4882 And Scalar <= 4885 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 5112 Then
                                    If Scalar >= 4888 And Scalar <= 4954 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 4992 And Scalar <= 5007 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 5024 And Scalar <= 5109 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 5112 And Scalar <= 5117 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 5121 And Scalar <= 5740 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 5743 And Scalar <= 5759 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 6176 Then
                            If Scalar < 5952 Then
                                If Scalar < 5873 Then
                                    If Scalar >= 5761 And Scalar <= 5786 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 5792 And Scalar <= 5866 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 5873 And Scalar <= 5880 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 5888 And Scalar <= 5905 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 5919 And Scalar <= 5937 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 6016 Then
                                    If Scalar >= 5952 And Scalar <= 5969 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 5984 And Scalar <= 5996 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 5998 And Scalar <= 6000 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 6016 And Scalar <= 6067 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 6103 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 6108 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 6400 Then
                                If Scalar < 6279 Then
                                    If Scalar >= 6176 And Scalar <= 6264 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 6272 And Scalar <= 6276 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 6279 And Scalar <= 6312 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 6314 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 6320 And Scalar <= 6389 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 6528 Then
                                    If Scalar >= 6400 And Scalar <= 6430 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 6480 And Scalar <= 6509 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 6512 And Scalar <= 6516 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 6528 And Scalar <= 6571 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 6576 And Scalar <= 6601 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 6656 And Scalar <= 6678 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                Else
                    If Scalar < 8016 Then
                        If Scalar < 7312 Then
                            If Scalar < 7086 Then
                                If Scalar < 6917 Then
                                    If Scalar >= 6688 And Scalar <= 6740 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 6823 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 6917 And Scalar <= 6963 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 6981 And Scalar <= 6988 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7043 And Scalar <= 7072 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 7245 Then
                                    If Scalar >= 7086 And Scalar <= 7087 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7098 And Scalar <= 7141 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7168 And Scalar <= 7203 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 7245 And Scalar <= 7247 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7258 And Scalar <= 7293 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7296 And Scalar <= 7306 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 7418 Then
                                If Scalar < 7401 Then
                                    If Scalar >= 7312 And Scalar <= 7354 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7357 And Scalar <= 7359 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 7401 And Scalar <= 7404 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7406 And Scalar <= 7411 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7413 And Scalar <= 7414 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 7960 Then
                                    If Scalar = 7418 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7424 And Scalar <= 7615 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7680 And Scalar <= 7957 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 7960 And Scalar <= 7965 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 7968 And Scalar <= 8005 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8008 And Scalar <= 8013 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 8150 Then
                            If Scalar < 8064 Then
                                If Scalar < 8027 Then
                                    If Scalar >= 8016 And Scalar <= 8023 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 8025 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 8027 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 8029 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8031 And Scalar <= 8061 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 8130 Then
                                    If Scalar >= 8064 And Scalar <= 8116 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8118 And Scalar <= 8124 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 8126 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 8130 And Scalar <= 8132 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8134 And Scalar <= 8140 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8144 And Scalar <= 8147 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 8319 Then
                                If Scalar < 8178 Then
                                    If Scalar >= 8150 And Scalar <= 8155 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8160 And Scalar <= 8172 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 8178 And Scalar <= 8180 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8182 And Scalar <= 8188 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 8305 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 8455 Then
                                    If Scalar = 8319 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8335 And Scalar <= 8351 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 8450 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 8455 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8458 And Scalar <= 8467 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 8469 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            Else
                If Scalar < 42512 Then
                    If Scalar < 11696 Then
                        If Scalar < 11264 Then
                            If Scalar < 8495 Then
                                If Scalar < 8486 Then
                                    If Scalar >= 8473 And Scalar <= 8477 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 8484 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 8486 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 8488 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8490 And Scalar <= 8493 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 8517 Then
                                    If Scalar >= 8495 And Scalar <= 8505 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8508 And Scalar <= 8511 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 8517 And Scalar <= 8521 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 8526 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 8579 And Scalar <= 8580 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 11565 Then
                                If Scalar < 11506 Then
                                    If Scalar >= 11264 And Scalar <= 11492 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 11499 And Scalar <= 11502 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 11506 And Scalar <= 11507 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 11520 And Scalar <= 11557 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 11559 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 11648 Then
                                    If Scalar = 11565 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 11568 And Scalar <= 11623 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 11631 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 11648 And Scalar <= 11670 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 11680 And Scalar <= 11686 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 11688 And Scalar <= 11694 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 12445 Then
                            If Scalar < 11736 Then
                                If Scalar < 11712 Then
                                    If Scalar >= 11696 And Scalar <= 11702 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 11704 And Scalar <= 11710 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 11712 And Scalar <= 11718 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 11720 And Scalar <= 11726 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 11728 And Scalar <= 11734 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 12337 Then
                                    If Scalar >= 11736 And Scalar <= 11742 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 11823 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 12293 And Scalar <= 12294 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 12337 And Scalar <= 12341 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 12347 And Scalar <= 12348 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 12353 And Scalar <= 12438 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 12704 Then
                                If Scalar < 12540 Then
                                    If Scalar >= 12445 And Scalar <= 12447 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 12449 And Scalar <= 12538 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 12540 And Scalar <= 12543 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 12549 And Scalar <= 12591 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 12593 And Scalar <= 12686 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 19968 Then
                                    If Scalar >= 12704 And Scalar <= 12735 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 12784 And Scalar <= 12799 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 13312 And Scalar <= 19903 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 19968 And Scalar <= 42124 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 42192 And Scalar <= 42237 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 42240 And Scalar <= 42508 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                Else
                    If Scalar < 43471 Then
                        If Scalar < 43015 Then
                            If Scalar < 42775 Then
                                If Scalar < 42560 Then
                                    If Scalar >= 42512 And Scalar <= 42527 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 42538 And Scalar <= 42539 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 42560 And Scalar <= 42606 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 42623 And Scalar <= 42653 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 42656 And Scalar <= 42725 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 42978 Then
                                    If Scalar >= 42775 And Scalar <= 42783 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 42786 And Scalar <= 42888 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 42891 And Scalar <= 42973 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 42978 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 42993 And Scalar <= 43009 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43011 And Scalar <= 43013 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 43259 Then
                                If Scalar < 43072 Then
                                    If Scalar >= 43015 And Scalar <= 43018 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43020 And Scalar <= 43042 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 43072 And Scalar <= 43123 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43138 And Scalar <= 43187 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43250 And Scalar <= 43255 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 43312 Then
                                    If Scalar = 43259 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43261 And Scalar <= 43262 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43274 And Scalar <= 43301 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 43312 And Scalar <= 43334 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43360 And Scalar <= 43388 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43396 And Scalar <= 43442 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 43701 Then
                            If Scalar < 43584 Then
                                If Scalar < 43494 Then
                                    If Scalar = 43471 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43488 And Scalar <= 43492 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 43494 And Scalar <= 43503 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43514 And Scalar <= 43518 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43520 And Scalar <= 43560 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 43642 Then
                                    If Scalar >= 43584 And Scalar <= 43586 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43588 And Scalar <= 43595 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43616 And Scalar <= 43638 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 43642 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43646 And Scalar <= 43695 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 43697 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 43744 Then
                                If Scalar < 43712 Then
                                    If Scalar >= 43701 And Scalar <= 43702 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43705 And Scalar <= 43709 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 43712 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 43714 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43739 And Scalar <= 43741 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 43785 Then
                                    If Scalar >= 43744 And Scalar <= 43754 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43762 And Scalar <= 43764 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43777 And Scalar <= 43782 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 43785 And Scalar <= 43790 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43793 And Scalar <= 43798 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43808 And Scalar <= 43814 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    Else
        If Scalar < 72001 Then
            If Scalar < 68117 Then
                If Scalar < 66349 Then
                    If Scalar < 64848 Then
                        If Scalar < 64256 Then
                            If Scalar < 44032 Then
                                If Scalar < 43868 Then
                                    If Scalar >= 43816 And Scalar <= 43822 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43824 And Scalar <= 43866 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 43868 And Scalar <= 43881 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43884 And Scalar <= 43885 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 43888 And Scalar <= 44002 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 55243 Then
                                    If Scalar >= 44032 And Scalar <= 55203 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 55216 And Scalar <= 55238 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 55243 And Scalar <= 55291 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 63744 And Scalar <= 64109 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 64112 And Scalar <= 64217 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 64312 Then
                                If Scalar < 64285 Then
                                    If Scalar >= 64256 And Scalar <= 64262 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 64275 And Scalar <= 64279 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 64285 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 64287 And Scalar <= 64296 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 64298 And Scalar <= 64310 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 64323 Then
                                    If Scalar >= 64312 And Scalar <= 64316 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 64318 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 64320 And Scalar <= 64321 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 64323 And Scalar <= 64324 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 64326 And Scalar <= 64433 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 64467 And Scalar <= 64829 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 65498 Then
                            If Scalar < 65313 Then
                                If Scalar < 65008 Then
                                    If Scalar >= 64848 And Scalar <= 64911 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 64914 And Scalar <= 64967 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 65008 And Scalar <= 65019 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65136 And Scalar <= 65140 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65142 And Scalar <= 65276 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 65474 Then
                                    If Scalar >= 65313 And Scalar <= 65338 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65345 And Scalar <= 65370 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65382 And Scalar <= 65470 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 65474 And Scalar <= 65479 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65482 And Scalar <= 65487 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65490 And Scalar <= 65495 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 65599 Then
                                If Scalar < 65549 Then
                                    If Scalar >= 65498 And Scalar <= 65500 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65536 And Scalar <= 65547 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 65549 And Scalar <= 65574 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65576 And Scalar <= 65594 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65596 And Scalar <= 65597 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 66176 Then
                                    If Scalar >= 65599 And Scalar <= 65613 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65616 And Scalar <= 65629 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 65664 And Scalar <= 65786 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 66176 And Scalar <= 66204 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66208 And Scalar <= 66256 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66304 And Scalar <= 66335 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                Else
                    If Scalar < 67392 Then
                        If Scalar < 66864 Then
                            If Scalar < 66504 Then
                                If Scalar < 66384 Then
                                    If Scalar >= 66349 And Scalar <= 66368 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66370 And Scalar <= 66377 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 66384 And Scalar <= 66421 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66432 And Scalar <= 66461 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66464 And Scalar <= 66499 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 66736 Then
                                    If Scalar >= 66504 And Scalar <= 66511 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66560 And Scalar <= 66717 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 66736 And Scalar <= 66771 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66776 And Scalar <= 66811 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66816 And Scalar <= 66855 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 66967 Then
                                If Scalar < 66940 Then
                                    If Scalar >= 66864 And Scalar <= 66915 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66928 And Scalar <= 66938 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 66940 And Scalar <= 66954 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66956 And Scalar <= 66962 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66964 And Scalar <= 66965 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 67003 Then
                                    If Scalar >= 66967 And Scalar <= 66977 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66979 And Scalar <= 66993 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 66995 And Scalar <= 67001 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 67003 And Scalar <= 67004 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67008 And Scalar <= 67059 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67072 And Scalar <= 67382 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 67680 Then
                            If Scalar < 67584 Then
                                If Scalar < 67456 Then
                                    If Scalar >= 67392 And Scalar <= 67413 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67424 And Scalar <= 67431 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 67456 And Scalar <= 67461 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67463 And Scalar <= 67504 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67506 And Scalar <= 67519 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 67639 Then
                                    If Scalar >= 67584 And Scalar <= 67589 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 67592 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67594 And Scalar <= 67637 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 67639 And Scalar <= 67640 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 67644 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67647 And Scalar <= 67669 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 67872 Then
                                If Scalar < 67808 Then
                                    If Scalar >= 67680 And Scalar <= 67702 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67712 And Scalar <= 67742 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 67808 And Scalar <= 67826 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67828 And Scalar <= 67829 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67840 And Scalar <= 67861 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 68030 Then
                                    If Scalar >= 67872 And Scalar <= 67897 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67904 And Scalar <= 67929 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 67968 And Scalar <= 68023 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 68030 And Scalar <= 68031 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 68096 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68112 And Scalar <= 68115 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            Else
                If Scalar < 70272 Then
                    If Scalar < 69415 Then
                        If Scalar < 68608 Then
                            If Scalar < 68297 Then
                                If Scalar < 68192 Then
                                    If Scalar >= 68117 And Scalar <= 68119 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68121 And Scalar <= 68149 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 68192 And Scalar <= 68220 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68224 And Scalar <= 68252 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68288 And Scalar <= 68295 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 68416 Then
                                    If Scalar >= 68297 And Scalar <= 68324 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68352 And Scalar <= 68405 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 68416 And Scalar <= 68437 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68448 And Scalar <= 68466 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68480 And Scalar <= 68497 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 68975 Then
                                If Scalar < 68800 Then
                                    If Scalar >= 68608 And Scalar <= 68680 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68736 And Scalar <= 68786 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 68800 And Scalar <= 68850 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68864 And Scalar <= 68899 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 68938 And Scalar <= 68965 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 69314 Then
                                    If Scalar >= 68975 And Scalar <= 68997 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69248 And Scalar <= 69289 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69296 And Scalar <= 69297 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 69314 And Scalar <= 69319 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69337 And Scalar <= 69358 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69376 And Scalar <= 69404 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 69956 Then
                            If Scalar < 69635 Then
                                If Scalar < 69488 Then
                                    If Scalar = 69415 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69424 And Scalar <= 69445 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 69488 And Scalar <= 69505 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69552 And Scalar <= 69572 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69600 And Scalar <= 69622 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 69763 Then
                                    If Scalar >= 69635 And Scalar <= 69687 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69745 And Scalar <= 69746 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 69749 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 69763 And Scalar <= 69807 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69840 And Scalar <= 69864 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 69891 And Scalar <= 69926 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 70081 Then
                                If Scalar < 69968 Then
                                    If Scalar = 69956 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 69959 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 69968 And Scalar <= 70002 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 70006 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70019 And Scalar <= 70066 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 70144 Then
                                    If Scalar >= 70081 And Scalar <= 70084 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 70106 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 70108 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 70144 And Scalar <= 70161 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70163 And Scalar <= 70187 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70207 And Scalar <= 70208 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                Else
                    If Scalar < 70656 Then
                        If Scalar < 70453 Then
                            If Scalar < 70320 Then
                                If Scalar < 70282 Then
                                    If Scalar >= 70272 And Scalar <= 70278 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 70280 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 70282 And Scalar <= 70285 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70287 And Scalar <= 70301 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70303 And Scalar <= 70312 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 70419 Then
                                    If Scalar >= 70320 And Scalar <= 70366 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70405 And Scalar <= 70412 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70415 And Scalar <= 70416 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 70419 And Scalar <= 70440 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70442 And Scalar <= 70448 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70450 And Scalar <= 70451 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 70539 Then
                                If Scalar < 70480 Then
                                    If Scalar >= 70453 And Scalar <= 70457 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 70461 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 70480 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70493 And Scalar <= 70497 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70528 And Scalar <= 70537 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 70583 Then
                                    If Scalar = 70539 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 70542 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70544 And Scalar <= 70581 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 70583 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 70609 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 70611 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 71352 Then
                            If Scalar < 70855 Then
                                If Scalar < 70751 Then
                                    If Scalar >= 70656 And Scalar <= 70708 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70727 And Scalar <= 70730 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 70751 And Scalar <= 70753 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70784 And Scalar <= 70831 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 70852 And Scalar <= 70853 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 71168 Then
                                    If Scalar = 70855 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 71040 And Scalar <= 71086 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 71128 And Scalar <= 71131 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 71168 And Scalar <= 71215 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 71236 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 71296 And Scalar <= 71338 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 71935 Then
                                If Scalar < 71488 Then
                                    If Scalar = 71352 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 71424 And Scalar <= 71450 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 71488 And Scalar <= 71494 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 71680 And Scalar <= 71723 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 71840 And Scalar <= 71903 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 71957 Then
                                    If Scalar >= 71935 And Scalar <= 71942 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 71945 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 71948 And Scalar <= 71955 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 71957 And Scalar <= 71958 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 71960 And Scalar <= 71983 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 71999 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        Else
            If Scalar < 120071 Then
                If Scalar < 92784 Then
                    If Scalar < 73030 Then
                        If Scalar < 72349 Then
                            If Scalar < 72192 Then
                                If Scalar < 72106 Then
                                    If Scalar = 72001 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 72096 And Scalar <= 72103 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 72106 And Scalar <= 72144 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 72161 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 72163 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 72250 Then
                                    If Scalar = 72192 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 72203 And Scalar <= 72242 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 72250 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 72272 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 72284 And Scalar <= 72329 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 72714 Then
                                If Scalar < 72458 Then
                                    If Scalar = 72349 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 72368 And Scalar <= 72440 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 72458 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 72640 And Scalar <= 72672 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 72704 And Scalar <= 72712 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 72960 Then
                                    If Scalar >= 72714 And Scalar <= 72750 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 72768 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 72818 And Scalar <= 72847 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 72960 And Scalar <= 72966 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 72968 And Scalar <= 72969 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 72971 And Scalar <= 73008 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 73648 Then
                            If Scalar < 73136 Then
                                If Scalar < 73063 Then
                                    If Scalar = 73030 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 73056 And Scalar <= 73061 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 73063 And Scalar <= 73064 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 73066 And Scalar <= 73097 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 73112 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 73474 Then
                                    If Scalar >= 73136 And Scalar <= 73179 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 73201 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 73440 And Scalar <= 73458 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 73474 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 73476 And Scalar <= 73488 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 73490 And Scalar <= 73523 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 78913 Then
                                If Scalar < 74880 Then
                                    If Scalar = 73648 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 73728 And Scalar <= 74649 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 74880 And Scalar <= 75075 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 77712 And Scalar <= 77808 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 77824 And Scalar <= 78895 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 90368 Then
                                    If Scalar >= 78913 And Scalar <= 78918 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 78944 And Scalar <= 82938 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 82944 And Scalar <= 83526 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 90368 And Scalar <= 90397 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 92160 And Scalar <= 92728 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 92736 And Scalar <= 92766 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                Else
                    If Scalar < 110581 Then
                        If Scalar < 94032 Then
                            If Scalar < 93053 Then
                                If Scalar < 92928 Then
                                    If Scalar >= 92784 And Scalar <= 92862 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 92880 And Scalar <= 92909 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 92928 And Scalar <= 92975 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 92992 And Scalar <= 92995 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 93027 And Scalar <= 93047 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 93856 Then
                                    If Scalar >= 93053 And Scalar <= 93071 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 93504 And Scalar <= 93548 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 93760 And Scalar <= 93823 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 93856 And Scalar <= 93880 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 93883 And Scalar <= 93907 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 93952 And Scalar <= 94026 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 94208 Then
                                If Scalar < 94176 Then
                                    If Scalar = 94032 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 94099 And Scalar <= 94111 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 94176 And Scalar <= 94177 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 94179 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 94194 And Scalar <= 94195 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 101888 Then
                                    If Scalar >= 94208 And Scalar <= 101594 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 101631 And Scalar <= 101664 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 101760 And Scalar <= 101874 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 101888 And Scalar <= 102801 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 102816 And Scalar <= 102866 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 110576 And Scalar <= 110579 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 113808 Then
                            If Scalar < 110933 Then
                                If Scalar < 110592 Then
                                    If Scalar >= 110581 And Scalar <= 110587 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 110589 And Scalar <= 110590 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 110592 And Scalar <= 110888 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 110898 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 110928 And Scalar <= 110930 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 113664 Then
                                    If Scalar = 110933 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 110948 And Scalar <= 110952 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 110960 And Scalar <= 111355 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 113664 And Scalar <= 113770 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 113776 And Scalar <= 113788 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 113792 And Scalar <= 113800 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 119973 Then
                                If Scalar < 119894 Then
                                    If Scalar >= 113808 And Scalar <= 113817 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 119808 And Scalar <= 119892 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 119894 And Scalar <= 119964 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 119966 And Scalar <= 119967 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 119970 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 119995 Then
                                    If Scalar >= 119973 And Scalar <= 119974 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 119977 And Scalar <= 119980 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 119982 And Scalar <= 119993 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 119995 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 119997 And Scalar <= 120003 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120005 And Scalar <= 120069 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            Else
                If Scalar < 125184 Then
                    If Scalar < 122768 Then
                        If Scalar < 120514 Then
                            If Scalar < 120128 Then
                                If Scalar < 120086 Then
                                    If Scalar >= 120071 And Scalar <= 120074 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120077 And Scalar <= 120084 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 120086 And Scalar <= 120092 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120094 And Scalar <= 120121 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120123 And Scalar <= 120126 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 120138 Then
                                    If Scalar >= 120128 And Scalar <= 120132 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 120134 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 120138 And Scalar <= 120144 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120146 And Scalar <= 120486 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120488 And Scalar <= 120512 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 120656 Then
                                If Scalar < 120572 Then
                                    If Scalar >= 120514 And Scalar <= 120538 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120540 And Scalar <= 120570 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 120572 And Scalar <= 120596 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120598 And Scalar <= 120628 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120630 And Scalar <= 120654 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 120746 Then
                                    If Scalar >= 120656 And Scalar <= 120686 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120688 And Scalar <= 120712 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120714 And Scalar <= 120744 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 120746 And Scalar <= 120770 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 120772 And Scalar <= 120779 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 122624 And Scalar <= 122753 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 124608 Then
                            If Scalar < 123214 Then
                                If Scalar < 122928 Then
                                    If Scalar >= 122768 And Scalar <= 122774 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 122829 And Scalar <= 122879 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 122928 And Scalar <= 122989 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 123136 And Scalar <= 123180 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 123191 And Scalar <= 123197 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 124112 Then
                                    If Scalar = 123214 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 123536 And Scalar <= 123565 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 123584 And Scalar <= 123627 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 124112 And Scalar <= 124139 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 124368 And Scalar <= 124397 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 124400 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 124670 Then
                                If Scalar < 124644 Then
                                    If Scalar >= 124608 And Scalar <= 124638 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 124640 And Scalar <= 124642 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 124644 And Scalar <= 124645 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 124647 And Scalar <= 124653 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 124656 And Scalar <= 124660 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 124909 Then
                                    If Scalar >= 124670 And Scalar <= 124671 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 124896 And Scalar <= 124902 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 124904 And Scalar <= 124907 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 124909 And Scalar <= 124910 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 124912 And Scalar <= 124926 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 124928 And Scalar <= 125124 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                Else
                    If Scalar < 126559 Then
                        If Scalar < 126530 Then
                            If Scalar < 126500 Then
                                If Scalar < 126464 Then
                                    If Scalar >= 125184 And Scalar <= 125251 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 125259 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 126464 And Scalar <= 126467 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126469 And Scalar <= 126495 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126497 And Scalar <= 126498 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 126516 Then
                                    If Scalar = 126500 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126503 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126505 And Scalar <= 126514 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 126516 And Scalar <= 126519 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126521 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126523 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 126545 Then
                                If Scalar < 126537 Then
                                    If Scalar = 126530 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126535 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 126537 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126539 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126541 And Scalar <= 126543 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 126553 Then
                                    If Scalar >= 126545 And Scalar <= 126546 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126548 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126551 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 126553 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126555 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126557 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    Else
                        If Scalar < 126629 Then
                            If Scalar < 126580 Then
                                If Scalar < 126564 Then
                                    If Scalar = 126559 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126561 And Scalar <= 126562 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar = 126564 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126567 And Scalar <= 126570 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126572 And Scalar <= 126578 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 126592 Then
                                    If Scalar >= 126580 And Scalar <= 126583 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126585 And Scalar <= 126588 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar = 126590 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 126592 And Scalar <= 126601 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126603 And Scalar <= 126619 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126625 And Scalar <= 126627 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        Else
                            If Scalar < 183984 Then
                                If Scalar < 131072 Then
                                    If Scalar >= 126629 And Scalar <= 126633 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 126635 And Scalar <= 126651 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 131072 And Scalar <= 173791 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 173824 And Scalar <= 178206 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 178208 And Scalar <= 183981 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            Else
                                If Scalar < 196608 Then
                                    If Scalar >= 183984 And Scalar <= 191456 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 191472 And Scalar <= 192093 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 194560 And Scalar <= 195101 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                Else
                                    If Scalar >= 196608 And Scalar <= 201546 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 201552 And Scalar <= 210041 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                    If Scalar >= 249856 And Scalar <= 261183 Then
                                        IsUnicodeLetter = True
                                        Exit Function
                                    End If
                                End If
                            End If
                        End If
                    End If
                End If
            End If
        End If
    End If
End Function

' Default simple folding: CaseFolding C+S, excluding F and Turkic T.
' Unlisted values, including invalid scalars, return the original Long.
Function SimpleFoldUnicode(ByVal Scalar As Long) As Long
    SimpleFoldUnicode = Scalar
    If Scalar < 0 Or Scalar > 1114111 Then
        Exit Function
    End If
    If Scalar < 7305 Then
        If Scalar < 546 Then
            If Scalar < 413 Then
                If Scalar < 390 Then
                    If Scalar < 313 Then
                        If Scalar < 216 Then
                            If Scalar >= 65 And Scalar <= 90 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                            If Scalar = 181 Then
                                SimpleFoldUnicode = Scalar + 775
                                Exit Function
                            End If
                            If Scalar >= 192 And Scalar <= 214 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                        Else
                            If Scalar >= 216 And Scalar <= 222 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                            If Scalar >= 256 And Scalar <= 302 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 306 And Scalar <= 310 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 377 Then
                            If Scalar >= 313 And Scalar <= 327 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 330 And Scalar <= 374 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 376 Then
                                SimpleFoldUnicode = Scalar - 121
                                Exit Function
                            End If
                        Else
                            If Scalar >= 377 And Scalar <= 381 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 383 Then
                                SimpleFoldUnicode = Scalar - 268
                                Exit Function
                            End If
                            If Scalar = 385 Then
                                SimpleFoldUnicode = Scalar + 210
                                Exit Function
                            End If
                            If Scalar >= 386 And Scalar <= 388 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    End If
                Else
                    If Scalar < 401 Then
                        If Scalar < 395 Then
                            If Scalar = 390 Then
                                SimpleFoldUnicode = Scalar + 206
                                Exit Function
                            End If
                            If Scalar = 391 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 393 And Scalar <= 394 Then
                                SimpleFoldUnicode = Scalar + 205
                                Exit Function
                            End If
                        Else
                            If Scalar = 395 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 398 Then
                                SimpleFoldUnicode = Scalar + 79
                                Exit Function
                            End If
                            If Scalar = 399 Then
                                SimpleFoldUnicode = Scalar + 202
                                Exit Function
                            End If
                            If Scalar = 400 Then
                                SimpleFoldUnicode = Scalar + 203
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 406 Then
                            If Scalar = 401 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 403 Then
                                SimpleFoldUnicode = Scalar + 205
                                Exit Function
                            End If
                            If Scalar = 404 Then
                                SimpleFoldUnicode = Scalar + 207
                                Exit Function
                            End If
                        Else
                            If Scalar = 406 Then
                                SimpleFoldUnicode = Scalar + 211
                                Exit Function
                            End If
                            If Scalar = 407 Then
                                SimpleFoldUnicode = Scalar + 209
                                Exit Function
                            End If
                            If Scalar = 408 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 412 Then
                                SimpleFoldUnicode = Scalar + 211
                                Exit Function
                            End If
                        End If
                    End If
                End If
            Else
                If Scalar < 444 Then
                    If Scalar < 428 Then
                        If Scalar < 422 Then
                            If Scalar = 413 Then
                                SimpleFoldUnicode = Scalar + 213
                                Exit Function
                            End If
                            If Scalar = 415 Then
                                SimpleFoldUnicode = Scalar + 214
                                Exit Function
                            End If
                            If Scalar >= 416 And Scalar <= 420 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        Else
                            If Scalar = 422 Then
                                SimpleFoldUnicode = Scalar + 218
                                Exit Function
                            End If
                            If Scalar = 423 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 425 Then
                                SimpleFoldUnicode = Scalar + 218
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 433 Then
                            If Scalar = 428 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 430 Then
                                SimpleFoldUnicode = Scalar + 218
                                Exit Function
                            End If
                            If Scalar = 431 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        Else
                            If Scalar >= 433 And Scalar <= 434 Then
                                SimpleFoldUnicode = Scalar + 217
                                Exit Function
                            End If
                            If Scalar >= 435 And Scalar <= 437 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 439 Then
                                SimpleFoldUnicode = Scalar + 219
                                Exit Function
                            End If
                            If Scalar = 440 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    End If
                Else
                    If Scalar < 478 Then
                        If Scalar < 455 Then
                            If Scalar = 444 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 452 Then
                                SimpleFoldUnicode = Scalar + 2
                                Exit Function
                            End If
                            If Scalar = 453 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        Else
                            If Scalar = 455 Then
                                SimpleFoldUnicode = Scalar + 2
                                Exit Function
                            End If
                            If Scalar = 456 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 458 Then
                                SimpleFoldUnicode = Scalar + 2
                                Exit Function
                            End If
                            If Scalar >= 459 And Scalar <= 475 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 502 Then
                            If Scalar >= 478 And Scalar <= 494 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 497 Then
                                SimpleFoldUnicode = Scalar + 2
                                Exit Function
                            End If
                            If Scalar >= 498 And Scalar <= 500 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        Else
                            If Scalar = 502 Then
                                SimpleFoldUnicode = Scalar - 97
                                Exit Function
                            End If
                            If Scalar = 503 Then
                                SimpleFoldUnicode = Scalar - 56
                                Exit Function
                            End If
                            If Scalar >= 504 And Scalar <= 542 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 544 Then
                                SimpleFoldUnicode = Scalar - 130
                                Exit Function
                            End If
                        End If
                    End If
                End If
            End If
        Else
            If Scalar < 1008 Then
                If Scalar < 895 Then
                    If Scalar < 579 Then
                        If Scalar < 573 Then
                            If Scalar >= 546 And Scalar <= 562 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 570 Then
                                SimpleFoldUnicode = Scalar + 10795
                                Exit Function
                            End If
                            If Scalar = 571 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        Else
                            If Scalar = 573 Then
                                SimpleFoldUnicode = Scalar - 163
                                Exit Function
                            End If
                            If Scalar = 574 Then
                                SimpleFoldUnicode = Scalar + 10792
                                Exit Function
                            End If
                            If Scalar = 577 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 582 Then
                            If Scalar = 579 Then
                                SimpleFoldUnicode = Scalar - 195
                                Exit Function
                            End If
                            If Scalar = 580 Then
                                SimpleFoldUnicode = Scalar + 69
                                Exit Function
                            End If
                            If Scalar = 581 Then
                                SimpleFoldUnicode = Scalar + 71
                                Exit Function
                            End If
                        Else
                            If Scalar >= 582 And Scalar <= 590 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 837 Then
                                SimpleFoldUnicode = Scalar + 116
                                Exit Function
                            End If
                            If Scalar >= 880 And Scalar <= 882 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 886 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    End If
                Else
                    If Scalar < 962 Then
                        If Scalar < 908 Then
                            If Scalar = 895 Then
                                SimpleFoldUnicode = Scalar + 116
                                Exit Function
                            End If
                            If Scalar = 902 Then
                                SimpleFoldUnicode = Scalar + 38
                                Exit Function
                            End If
                            If Scalar >= 904 And Scalar <= 906 Then
                                SimpleFoldUnicode = Scalar + 37
                                Exit Function
                            End If
                        Else
                            If Scalar = 908 Then
                                SimpleFoldUnicode = Scalar + 64
                                Exit Function
                            End If
                            If Scalar >= 910 And Scalar <= 911 Then
                                SimpleFoldUnicode = Scalar + 63
                                Exit Function
                            End If
                            If Scalar >= 913 And Scalar <= 929 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                            If Scalar >= 931 And Scalar <= 939 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 977 Then
                            If Scalar = 962 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 975 Then
                                SimpleFoldUnicode = Scalar + 8
                                Exit Function
                            End If
                            If Scalar = 976 Then
                                SimpleFoldUnicode = Scalar - 30
                                Exit Function
                            End If
                        Else
                            If Scalar = 977 Then
                                SimpleFoldUnicode = Scalar - 25
                                Exit Function
                            End If
                            If Scalar = 981 Then
                                SimpleFoldUnicode = Scalar - 15
                                Exit Function
                            End If
                            If Scalar = 982 Then
                                SimpleFoldUnicode = Scalar - 22
                                Exit Function
                            End If
                            If Scalar >= 984 And Scalar <= 1006 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    End If
                End If
            Else
                If Scalar < 1232 Then
                    If Scalar < 1021 Then
                        If Scalar < 1013 Then
                            If Scalar = 1008 Then
                                SimpleFoldUnicode = Scalar - 54
                                Exit Function
                            End If
                            If Scalar = 1009 Then
                                SimpleFoldUnicode = Scalar - 48
                                Exit Function
                            End If
                            If Scalar = 1012 Then
                                SimpleFoldUnicode = Scalar - 60
                                Exit Function
                            End If
                        Else
                            If Scalar = 1013 Then
                                SimpleFoldUnicode = Scalar - 64
                                Exit Function
                            End If
                            If Scalar = 1015 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 1017 Then
                                SimpleFoldUnicode = Scalar - 7
                                Exit Function
                            End If
                            If Scalar = 1018 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 1120 Then
                            If Scalar >= 1021 And Scalar <= 1023 Then
                                SimpleFoldUnicode = Scalar - 130
                                Exit Function
                            End If
                            If Scalar >= 1024 And Scalar <= 1039 Then
                                SimpleFoldUnicode = Scalar + 80
                                Exit Function
                            End If
                            If Scalar >= 1040 And Scalar <= 1071 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                        Else
                            If Scalar >= 1120 And Scalar <= 1152 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 1162 And Scalar <= 1214 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 1216 Then
                                SimpleFoldUnicode = Scalar + 15
                                Exit Function
                            End If
                            If Scalar >= 1217 And Scalar <= 1229 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    End If
                Else
                    If Scalar < 7297 Then
                        If Scalar < 4295 Then
                            If Scalar >= 1232 And Scalar <= 1326 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 1329 And Scalar <= 1366 Then
                                SimpleFoldUnicode = Scalar + 48
                                Exit Function
                            End If
                            If Scalar >= 4256 And Scalar <= 4293 Then
                                SimpleFoldUnicode = Scalar + 7264
                                Exit Function
                            End If
                        Else
                            If Scalar = 4295 Then
                                SimpleFoldUnicode = Scalar + 7264
                                Exit Function
                            End If
                            If Scalar = 4301 Then
                                SimpleFoldUnicode = Scalar + 7264
                                Exit Function
                            End If
                            If Scalar >= 5112 And Scalar <= 5117 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar = 7296 Then
                                SimpleFoldUnicode = Scalar - 6222
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 7301 Then
                            If Scalar = 7297 Then
                                SimpleFoldUnicode = Scalar - 6221
                                Exit Function
                            End If
                            If Scalar = 7298 Then
                                SimpleFoldUnicode = Scalar - 6212
                                Exit Function
                            End If
                            If Scalar >= 7299 And Scalar <= 7300 Then
                                SimpleFoldUnicode = Scalar - 6210
                                Exit Function
                            End If
                        Else
                            If Scalar = 7301 Then
                                SimpleFoldUnicode = Scalar - 6211
                                Exit Function
                            End If
                            If Scalar = 7302 Then
                                SimpleFoldUnicode = Scalar - 6204
                                Exit Function
                            End If
                            If Scalar = 7303 Then
                                SimpleFoldUnicode = Scalar - 6180
                                Exit Function
                            End If
                            If Scalar = 7304 Then
                                SimpleFoldUnicode = Scalar + 35267
                                Exit Function
                            End If
                        End If
                    End If
                End If
            End If
        End If
    Else
        If Scalar < 11506 Then
            If Scalar < 8168 Then
                If Scalar < 8040 Then
                    If Scalar < 7840 Then
                        If Scalar < 7680 Then
                            If Scalar = 7305 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 7312 And Scalar <= 7354 Then
                                SimpleFoldUnicode = Scalar - 3008
                                Exit Function
                            End If
                            If Scalar >= 7357 And Scalar <= 7359 Then
                                SimpleFoldUnicode = Scalar - 3008
                                Exit Function
                            End If
                        Else
                            If Scalar >= 7680 And Scalar <= 7828 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 7835 Then
                                SimpleFoldUnicode = Scalar - 58
                                Exit Function
                            End If
                            If Scalar = 7838 Then
                                SimpleFoldUnicode = Scalar - 7615
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 7976 Then
                            If Scalar >= 7840 And Scalar <= 7934 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 7944 And Scalar <= 7951 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 7960 And Scalar <= 7965 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                        Else
                            If Scalar >= 7976 And Scalar <= 7983 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 7992 And Scalar <= 7999 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 8008 And Scalar <= 8013 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 8025 And Scalar <= 8031 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                        End If
                    End If
                Else
                    If Scalar < 8126 Then
                        If Scalar < 8104 Then
                            If Scalar >= 8040 And Scalar <= 8047 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 8072 And Scalar <= 8079 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 8088 And Scalar <= 8095 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                        Else
                            If Scalar >= 8104 And Scalar <= 8111 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 8120 And Scalar <= 8121 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 8122 And Scalar <= 8123 Then
                                SimpleFoldUnicode = Scalar - 74
                                Exit Function
                            End If
                            If Scalar = 8124 Then
                                SimpleFoldUnicode = Scalar - 9
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 8147 Then
                            If Scalar = 8126 Then
                                SimpleFoldUnicode = Scalar - 7173
                                Exit Function
                            End If
                            If Scalar >= 8136 And Scalar <= 8139 Then
                                SimpleFoldUnicode = Scalar - 86
                                Exit Function
                            End If
                            If Scalar = 8140 Then
                                SimpleFoldUnicode = Scalar - 9
                                Exit Function
                            End If
                        Else
                            If Scalar = 8147 Then
                                SimpleFoldUnicode = Scalar - 7235
                                Exit Function
                            End If
                            If Scalar >= 8152 And Scalar <= 8153 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 8154 And Scalar <= 8155 Then
                                SimpleFoldUnicode = Scalar - 100
                                Exit Function
                            End If
                            If Scalar = 8163 Then
                                SimpleFoldUnicode = Scalar - 7219
                                Exit Function
                            End If
                        End If
                    End If
                End If
            Else
                If Scalar < 11360 Then
                    If Scalar < 8490 Then
                        If Scalar < 8184 Then
                            If Scalar >= 8168 And Scalar <= 8169 Then
                                SimpleFoldUnicode = Scalar - 8
                                Exit Function
                            End If
                            If Scalar >= 8170 And Scalar <= 8171 Then
                                SimpleFoldUnicode = Scalar - 112
                                Exit Function
                            End If
                            If Scalar = 8172 Then
                                SimpleFoldUnicode = Scalar - 7
                                Exit Function
                            End If
                        Else
                            If Scalar >= 8184 And Scalar <= 8185 Then
                                SimpleFoldUnicode = Scalar - 128
                                Exit Function
                            End If
                            If Scalar >= 8186 And Scalar <= 8187 Then
                                SimpleFoldUnicode = Scalar - 126
                                Exit Function
                            End If
                            If Scalar = 8188 Then
                                SimpleFoldUnicode = Scalar - 9
                                Exit Function
                            End If
                            If Scalar = 8486 Then
                                SimpleFoldUnicode = Scalar - 7517
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 8544 Then
                            If Scalar = 8490 Then
                                SimpleFoldUnicode = Scalar - 8383
                                Exit Function
                            End If
                            If Scalar = 8491 Then
                                SimpleFoldUnicode = Scalar - 8262
                                Exit Function
                            End If
                            If Scalar = 8498 Then
                                SimpleFoldUnicode = Scalar + 28
                                Exit Function
                            End If
                        Else
                            If Scalar >= 8544 And Scalar <= 8559 Then
                                SimpleFoldUnicode = Scalar + 16
                                Exit Function
                            End If
                            If Scalar = 8579 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 9398 And Scalar <= 9423 Then
                                SimpleFoldUnicode = Scalar + 26
                                Exit Function
                            End If
                            If Scalar >= 11264 And Scalar <= 11311 Then
                                SimpleFoldUnicode = Scalar + 48
                                Exit Function
                            End If
                        End If
                    End If
                Else
                    If Scalar < 11375 Then
                        If Scalar < 11364 Then
                            If Scalar = 11360 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 11362 Then
                                SimpleFoldUnicode = Scalar - 10743
                                Exit Function
                            End If
                            If Scalar = 11363 Then
                                SimpleFoldUnicode = Scalar - 3814
                                Exit Function
                            End If
                        Else
                            If Scalar = 11364 Then
                                SimpleFoldUnicode = Scalar - 10727
                                Exit Function
                            End If
                            If Scalar >= 11367 And Scalar <= 11371 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 11373 Then
                                SimpleFoldUnicode = Scalar - 10780
                                Exit Function
                            End If
                            If Scalar = 11374 Then
                                SimpleFoldUnicode = Scalar - 10749
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 11381 Then
                            If Scalar = 11375 Then
                                SimpleFoldUnicode = Scalar - 10783
                                Exit Function
                            End If
                            If Scalar = 11376 Then
                                SimpleFoldUnicode = Scalar - 10782
                                Exit Function
                            End If
                            If Scalar = 11378 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        Else
                            If Scalar = 11381 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 11390 And Scalar <= 11391 Then
                                SimpleFoldUnicode = Scalar - 10815
                                Exit Function
                            End If
                            If Scalar >= 11392 And Scalar <= 11490 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 11499 And Scalar <= 11501 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    End If
                End If
            End If
        Else
            If Scalar < 42956 Then
                If Scalar < 42923 Then
                    If Scalar < 42877 Then
                        If Scalar < 42786 Then
                            If Scalar = 11506 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 42560 And Scalar <= 42604 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 42624 And Scalar <= 42650 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        Else
                            If Scalar >= 42786 And Scalar <= 42798 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 42802 And Scalar <= 42862 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 42873 And Scalar <= 42875 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 42893 Then
                            If Scalar = 42877 Then
                                SimpleFoldUnicode = Scalar - 35332
                                Exit Function
                            End If
                            If Scalar >= 42878 And Scalar <= 42886 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 42891 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        Else
                            If Scalar = 42893 Then
                                SimpleFoldUnicode = Scalar - 42280
                                Exit Function
                            End If
                            If Scalar >= 42896 And Scalar <= 42898 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 42902 And Scalar <= 42920 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 42922 Then
                                SimpleFoldUnicode = Scalar - 42308
                                Exit Function
                            End If
                        End If
                    End If
                Else
                    If Scalar < 42931 Then
                        If Scalar < 42926 Then
                            If Scalar = 42923 Then
                                SimpleFoldUnicode = Scalar - 42319
                                Exit Function
                            End If
                            If Scalar = 42924 Then
                                SimpleFoldUnicode = Scalar - 42315
                                Exit Function
                            End If
                            If Scalar = 42925 Then
                                SimpleFoldUnicode = Scalar - 42305
                                Exit Function
                            End If
                        Else
                            If Scalar = 42926 Then
                                SimpleFoldUnicode = Scalar - 42308
                                Exit Function
                            End If
                            If Scalar = 42928 Then
                                SimpleFoldUnicode = Scalar - 42258
                                Exit Function
                            End If
                            If Scalar = 42929 Then
                                SimpleFoldUnicode = Scalar - 42282
                                Exit Function
                            End If
                            If Scalar = 42930 Then
                                SimpleFoldUnicode = Scalar - 42261
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 42949 Then
                            If Scalar = 42931 Then
                                SimpleFoldUnicode = Scalar + 928
                                Exit Function
                            End If
                            If Scalar >= 42932 And Scalar <= 42946 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 42948 Then
                                SimpleFoldUnicode = Scalar - 48
                                Exit Function
                            End If
                        Else
                            If Scalar = 42949 Then
                                SimpleFoldUnicode = Scalar - 42307
                                Exit Function
                            End If
                            If Scalar = 42950 Then
                                SimpleFoldUnicode = Scalar - 35384
                                Exit Function
                            End If
                            If Scalar >= 42951 And Scalar <= 42953 And Scalar Mod 2 = 1 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 42955 Then
                                SimpleFoldUnicode = Scalar - 42343
                                Exit Function
                            End If
                        End If
                    End If
                End If
            Else
                If Scalar < 66964 Then
                    If Scalar < 64261 Then
                        If Scalar < 42978 Then
                            If Scalar >= 42956 And Scalar <= 42970 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 42972 Then
                                SimpleFoldUnicode = Scalar - 42561
                                Exit Function
                            End If
                            If Scalar = 42973 Then
                                SimpleFoldUnicode = Scalar - 42342
                                Exit Function
                            End If
                        Else
                            If Scalar = 42978 Then
                                SimpleFoldUnicode = Scalar - 42342
                                Exit Function
                            End If
                            If Scalar = 42997 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 43884 And Scalar <= 43885 Then
                                SimpleFoldUnicode = Scalar - 33
                                Exit Function
                            End If
                            If Scalar >= 43888 And Scalar <= 43967 Then
                                SimpleFoldUnicode = Scalar - 38864
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 66736 Then
                            If Scalar = 64261 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 65313 And Scalar <= 65338 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                            If Scalar >= 66560 And Scalar <= 66599 Then
                                SimpleFoldUnicode = Scalar + 40
                                Exit Function
                            End If
                        Else
                            If Scalar >= 66736 And Scalar <= 66771 Then
                                SimpleFoldUnicode = Scalar + 40
                                Exit Function
                            End If
                            If Scalar >= 66928 And Scalar <= 66938 Then
                                SimpleFoldUnicode = Scalar + 39
                                Exit Function
                            End If
                            If Scalar >= 66940 And Scalar <= 66954 Then
                                SimpleFoldUnicode = Scalar + 39
                                Exit Function
                            End If
                            If Scalar >= 66956 And Scalar <= 66962 Then
                                SimpleFoldUnicode = Scalar + 39
                                Exit Function
                            End If
                        End If
                    End If
                Else
                    If Scalar < 122696 Then
                        If Scalar < 71840 Then
                            If Scalar >= 66964 And Scalar <= 66965 Then
                                SimpleFoldUnicode = Scalar + 39
                                Exit Function
                            End If
                            If Scalar >= 68736 And Scalar <= 68786 Then
                                SimpleFoldUnicode = Scalar + 64
                                Exit Function
                            End If
                            If Scalar >= 68944 And Scalar <= 68965 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                        Else
                            If Scalar >= 71840 And Scalar <= 71871 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                            If Scalar >= 93760 And Scalar <= 93791 Then
                                SimpleFoldUnicode = Scalar + 32
                                Exit Function
                            End If
                            If Scalar >= 93856 And Scalar <= 93880 Then
                                SimpleFoldUnicode = Scalar + 27
                                Exit Function
                            End If
                            If Scalar = 122688 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        End If
                    Else
                        If Scalar < 122728 Then
                            If Scalar >= 122696 And Scalar <= 122698 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 122701 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 122705 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                        Else
                            If Scalar >= 122728 And Scalar <= 122734 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar >= 122738 And Scalar <= 122750 And Scalar Mod 2 = 0 Then
                                SimpleFoldUnicode = Scalar + 1
                                Exit Function
                            End If
                            If Scalar = 122773 Then
                                SimpleFoldUnicode = Scalar - 122550
                                Exit Function
                            End If
                            If Scalar >= 125184 And Scalar <= 125217 Then
                                SimpleFoldUnicode = Scalar + 34
                                Exit Function
                            End If
                        End If
                    End If
                End If
            End If
        End If
    End If
End Function
