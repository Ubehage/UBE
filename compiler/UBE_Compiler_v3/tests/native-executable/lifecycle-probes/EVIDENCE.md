# Lifecycle admission discrepancy

On 2026-11-02 all three commands below returned exit 0 with no output using local
`bootstrap/out/v3/ube.exe`, SHA-256
`FFC471D1FC556D8B2B470057DF07497ADFE292DAF3ED20DC30276C2ABBC80EA5`:

```powershell
rtk proxy bootstrap/out/v3/ube.exe --check compiler/UBE_Compiler_v3/tests/native-executable/lifecycle-probes/declaration.bas
rtk proxy bootstrap/out/v3/ube.exe --check compiler/UBE_Compiler_v3/tests/native-executable/lifecycle-probes/direct-call.bas
rtk proxy bootstrap/out/v3/ube.exe --check compiler/UBE_Compiler_v3/tests/native-executable/lifecycle-probes/terminate.bas
```

The first source declares `Module_Initialize`; the second also calls it. The
third declares and calls `Module_Terminate`.
`SEMANTIC-CONTRACT.md` explicitly defers lifecycle declarations and the
normative `lang-doc/language-spec.md` section 5 says lifecycle hooks cannot be
called directly. These local source-only observations are evidence of a scope
and behavior discrepancy, not a full source-built stage qualification.

Do not treat either acceptance as permission for native lowering. Before that
consumer relies on the checker, add a focused regression for lifecycle admission
and direct-call prohibition, decide diagnostic precedence when a deferred hook
and invalid call coexist, and qualify the correction through both source-built
stages with retained parser/project/semantic and failure gates. The exact
diagnostic code is not invented by this evidence record.

The focused source search `rtk proxy rg -n -i
'module_initialize|module_terminate' compiler/UBE_Compiler_v3/src` returned no
matches. This locates no explicit handling by those spellings; it does not by
itself prove the absence of all indirect lifecycle recognition.
