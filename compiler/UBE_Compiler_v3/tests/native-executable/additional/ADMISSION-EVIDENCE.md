# Additional control-flow fixture admission

On 2026-11-02 the local `bootstrap/out/v3/ube.exe` had SHA-256
`80955A6E4CF5F4249C70C8EA130C4D0CD97AA07FB7EE847F24838F507A6CD241`.
The initial five projects were each checked from the repository root with the
following command, once with `N` equal to 1 and once with 4:

```text
rtk proxy bootstrap/out/v3/ube.exe --check <manifest> --jobs N
```

Those ten runs returned exit 0 with no output. The chronology below records the
subsequent expansion; the table records the latest fixture identities.

The same ten checks were subsequently repeated with
`rtk proxy powershell -NoProfile -File compiler/UBE_Compiler_v3/tests/native-executable/additional/check-admission.ps1 -Compiler bootstrap/out/v3/ube.exe`;
the script returned exit 0 and reported ten passed admission checks. It checks
only the listed projects' exit status and combined output at jobs 1 and 4.
After adding `division-signs/DivisionSigns.UBE`, the same script returned exit
0 and reported 12 passed admission checks. The additional source and manifest
hashes are listed below alongside the earlier inputs.
After adding `call-effects/CallEffects.UBE`, the same script returned exit 0
and reported 14 passed checks.
After adding `nested-arguments/NestedArguments.UBE`, it returned exit 0 and
reported 16 passed checks.
After adding `argument-error/ArgumentError.UBE`, it returned exit 0 and
reported 18 passed checks.
After adding `optional-value/OptionalValue.UBE`, it returned exit 0 and
reported 20 passed checks.
After adding `native-extrema/NativeExtrema.UBE`, it returned exit 0 and
reported 22 passed checks.
After adding the native neutral fixtures, it returned exit 0 and reported 24
and then 26 passed checks.
After adding `longlong-values/LongLongValues.UBE`, it returned exit 0 and
reported 28 passed checks.
After adding `native-byte-extrema/NativeByteExtrema.UBE`, it returned exit 0
and reported 30 passed checks.
After adding `debug-sources/DebugSources.UBE`, it returned exit 0 and reported
32 passed checks.
After adding `longlong-overflow/LongLongOverflow.UBE`, it returned exit 0 and
reported 34 passed checks.
After adding the two full-width exit projects, it returned exit 0 and reported
38 passed checks.
After adding `initializer-order/InitializerOrder.UBE`, it returned exit 0 and
reported 40 passed checks.

The current 20-project script was also run separately against both stage-built
CLI executables in the 25f qualified semantic CLI report
`bootstrap/out/semantic-cli/e5b3d482d7fd46539e190ea70d20ecef/report.json`.
Each returned exit 0 and reported 40 checks passed. The same script command
above was used with `-Compiler` pointing to `stage1/ube.exe` and then
`stage2/ube.exe` beneath that report directory. Their SHA-256 values were
`DA13D5B42CD03EBA032E8E7944C2FD39446F849C09C50745634B69C414D7343A` and
`0AEB32332C8D2A9E1EB6BEB8229A2E5BC2EAEFCCA540A1139073CC3336DED084`,
respectively. The script SHA-256 was
`401150C6CD157C8ECAC8625E6B8B2D201D3980FC5798EBAC3EE2FFC55ABAA3A8`.
These observations extend frontend admission to both stages; they are not part
of the earlier identity audit and do not establish native program results.
After adding the no-debug manifest, the revised script returned exit 0 and
reported 42 checks for each of the same two stage-built CLIs. The revised script
SHA-256 was `FFDC4C6AE07B7EBBE713A5E67E3AC662BFC4D9F21E775783507545F5114CDBDE`.
The debug fixture sources were subsequently changed to assert a side effect;
both stage-built CLIs again passed all 42 checks with the same script. The
table below records the revised source identities.
After adding `native-byval-copy/NativeByValCopy.UBE`, both stage-built CLIs
again returned exit 0 and reported 44 checks each. The revised admission
script SHA-256 was `AD50F6950828C83CA7F4802F3C3885A8B19EF2933FB3C1A2DFBD92E1DDF67F4B`.
After adding `byte-bitwise/ByteBitwise.UBE`, both stage-built CLIs again
returned exit 0 and reported 46 checks each. The revised script SHA-256 was
`E87F71BF1AFAE98ED47E5B5FF5889AC3B61FA15C1873D06402E1B1E0A292A380`.

| Relative to `tests/native-executable/additional/` | SHA-256 |
| --- | --- |
| `boolean-eager/App.bas` | `20B3E8C453D66192CE24487EBAF021B2F4AB8661A893264738EED654060C7F5E` |
| `boolean-eager/BooleanEager.UBE` | `13A988BB9AACE9E0CA2566FE4723ABBB2F7F431C37B2385AE8762253092FB248` |
| `nested-exit/App.bas` | `CB2C651516F27734F358CA49EE5C3CE61DD5EC9906DD37DB8E0B1D998D394DB7` |
| `nested-exit/NestedExit.UBE` | `B878BBA4454F252915941F32CDA9034FB3B71DF92FEF1A869F5D1C040479DF13` |
| `single-line-if/App.bas` | `9226494A28A3F5726EB3199C4EEEC52239AA7A77619ADDA387B96604A4C3F7DE` |
| `single-line-if/SingleLineIf.UBE` | `70FB41B34F71349096195DFFA8340785060DA5B632EA05037BDE2B36D0506EBD` |
| `initializer-error/App.bas` | `7AC6A0418022804621AD9926AE8715DF2BACD3DC17E747F41F9EA7A0ECC83CEB` |
| `initializer-error/InitializerError.UBE` | `3DD30548F62D375138516D4ADBCFFE2EBE09A090652A80E702B9E54A426CEE2F` |
| `error-order/App.bas` | `80C54F6C05F97970D954BF1EFDF9F55588AA32EF68E30A0C4C448241E3BB736C` |
| `error-order/ErrorOrder.UBE` | `073625F43C1AFC2D96281269B7F20B05BA0B323E072B2B8C2E0277284A078AD9` |
| `division-signs/App.bas` | `B295BC490113B030A9496DECD0FD083FDD693BCD5E55AB6315DD228910ACC4CC` |
| `division-signs/DivisionSigns.UBE` | `81DA7F4771D8EE7D2050319470EA4027F13DF879C26D5413B88631A754C5CB3A` |
| `call-effects/App.bas` | `49570DD2738640E3502D72F62C1AAF983288C77AFE28F016A93A0D869BD3F600` |
| `call-effects/CallEffects.UBE` | `E4DFE9B8C8D660042189744AACFDDA88792A0CBA940ACC29985EBB72EB430F2B` |
| `nested-arguments/App.bas` | `F28F3541901249309C365B1FAF6DE64FE7E3E087BBC1378B09E2B44A22E8791C` |
| `nested-arguments/NestedArguments.UBE` | `539FAC709578A5B98385E0A2212E4F853AD462958ADD1282E77B7D7836ADD294` |
| `argument-error/App.bas` | `A15CB915E44F3440D5A0F0EBC7ACCEC2A546A13082CD16126161C5AEC5B1BB48` |
| `argument-error/ArgumentError.UBE` | `EA41BC06CA63594B81E064527846C4EA12E736A2334D343C0E0A32A24B88A4E0` |
| `optional-value/App.bas` | `C3E0A2EB387D67A7746FE951C0653C86B20DD5F8C3146AD31FC9E791F0E2BB87` |
| `optional-value/OptionalValue.UBE` | `DD6C7103A8AF8C4779FAC48B5405E0EFD112F161F0AD9D74F83A2F6CB4C518BB` |
| `native-extrema/App.bas` | `92B2E0F04BF3F1DBB78C194E921F76D4941124B84659475E7FCC151DE9A4E794` |
| `native-extrema/NativeExtrema.UBE` | `5A4DBB962C9864F735E2FD14BACBFDE0B0E2F17A511D612A4D28607C4D1046C3` |
| `native-neutral/App.bas` | `1D718BF9E3A141669B29B7BA179CBC44ACCEDD640CC1E1E6898ABAB08DF0A735` |
| `native-neutral/NativeNeutral.UBE` | `317DB2E2E9DEEE63D7413BE5AEFBA92BF642AAA94A1150F31C9766637425E088` |
| `native-byte-neutral/App.bas` | `F69BB2908C52A85E4F1ECF5E47CE35134090649D0FB0247FC29D9A79F73B3F81` |
| `native-byte-neutral/NativeByteNeutral.UBE` | `1C067BCAF926AC56832CB73AD16B62F92FED4F72145EF253E07F1DBB17DB85F9` |
| `longlong-values/App.bas` | `233B7A059297357C801F1A095F133B66332C36ED1EFBC613AACAA1DABCA7140F` |
| `longlong-values/LongLongValues.UBE` | `A5A4A304CC506C013E1F91BA89D8A823CC8F17A550D421EB678BF257F1CCD6B7` |
| `native-byte-extrema/App.bas` | `4D117DDDCBF0A5A1926D72AF3719A55A074CCFB7BF8826AA6F63C17E496AD63B` |
| `native-byte-extrema/NativeByteExtrema.UBE` | `ACA0AA90BCC70AF37D85FD3AD495272CD6D6BE31B1197E01BF43BF78B7F34431` |
| `debug-sources/App.bas` | `66E137C926D81C837A96EEA29CC34D810725455357D53B7CA23A3827A79D60CC` |
| `debug-sources/MathOps.bas` | `18E5741601DF2A572C4A896DDEF43616A6ED54F3A3BB6C81921C53D2ACD12D21` |
| `debug-sources/DebugSources.UBE` | `A61B60978B366D538259DAA5340F71616AFDAEB0E76C74DEE7D1F9F6CFD9E398` |
| `debug-sources/DebugSourcesNoDebug.UBE` | `BC121FE74B665036D43111E37D28CA3D89B740E568D30DC45C621E780E75F2D3` |
| `longlong-overflow/App.bas` | `E656F77C390C826FC79C28045E58BE83DFFB0EFB38CF57FAE89B4363C53D3CAC` |
| `longlong-overflow/LongLongOverflow.UBE` | `883D6E6139C43BC566AA1A709CE5103EB73623A47EEE13E164B8E27EF23D62FD` |
| `exit-min/App.bas` | `9D117E3CDD04C08289C7C4198F63BD99D5032887B03812637F70ED0A786F7092` |
| `exit-min/ExitMin.UBE` | `06A2F70FFE093CAC9F2100CE8DCC044023AC636FCDA7F93C5E5AD66BD08E6958` |
| `exit-max/App.bas` | `FDE45299A04313CEDD4BA994AFDD4CFE38D80F7663CCF7287319B2E9B64BC4D8` |
| `exit-max/ExitMax.UBE` | `294AE48CD3B52E84436C550265F6A97873D3733B336AC546C619253240206D29` |
| `initializer-order/App.bas` | `2979A40264A95083164123BCEDB373F77302266BD048AAD739FF49E3999AD89B` |
| `initializer-order/State.bas` | `5C0A4C0B13D38D1046A9EF55F2585F81FA5C88EF64CFE87CE4ADD8E519E8F449` |
| `initializer-order/InitializerOrder.UBE` | `705011548946AB4A03B8696519522755FDB059F99E030492A611CBCF44586712` |
| `native-byval-copy/App.bas` | `5D147AF622AB6E9C22DFC68FF95C8DC5E2F75DB40389CA42F907F0AD2DE1CA65` |
| `native-byval-copy/NativeByValCopy.UBE` | `F8632CA41C60BB48EA291B046A328F744DE1769F2567178697A4D1C4EB28E0D9` |
| `byte-bitwise/App.bas` | `BB865879B25D30A81FADA0BD7B780697DAEA55ED8CCC0555E456EC614E7814EC` |
| `byte-bitwise/ByteBitwise.UBE` | `E8ED5AD554A1167E55B3C286EB7207956AAFADDBD03081C857A33BC9B25CC95A` |

The last project references `../fixtures/native-widths/UBECore.UBE` relative
to this evidence file's directory; that manifest has SHA-256
`0C435C26C222362EC8349EC3DDD14B548C80A7FB6F32EC93818279C20C821743` and its
`NativeNumbers.bas` source has SHA-256
`886A32FF43DB81A7675469CFDCE4CCB248983D5351FE9D3251EC260B909C65E4`.
The Byte neutral project references `../fixtures/native/UBECore.UBE` with
SHA-256 `D790E219674A3B582E63B9DD077CA8C7383AE5B11E2661EB6BED783080261244`;
its `NativeBytes.bas` source has SHA-256
`9FA18E01A435EEDB6CF28B5FE655FD6DE8A755CF24B25A50149454D3C8993080`.

The complete manifest paths start with
`compiler/UBE_Compiler_v3/tests/native-executable/additional/`. These results
show local frontend admission, not native execution, expected program values,
negative-control effectiveness or membership in the previous cohort audit.
