# UBE Compiler v1

UBE Compiler v1 is the first executable compiler written in UBE. It is a
bootstrap proof, not a general UBE compiler. Stage zero compiles `Main.bas` to
`bootstrap/out/ube-stage1.exe`.

The v1 compiler accepts exactly two command-line arguments:

```text
ube-stage1 <source.bas> <output.ll>
```

It recognizes only a parameterless `Sub Main()` or `Function Main() As Long`
containing a printable string `Print` statement. The function form also needs
a direct integer assignment to `Main`. It emits LLVM IR for the x86-64 Windows
GNU target; the build driver invokes LLVM/Clang to link that IR.

From the repository root, build and run all bootstrap and v1 acceptance tests:

```powershell
./bootstrap/build.ps1
```

The positive and negative v1 inputs are in `tests/`. Generated IR, objects,
executables, and logs belong in `bootstrap/out/`, never in this directory.

V1 must remain preserved and buildable after later generations become
available. Its intentionally narrow source inspection is not a foundation to
extend into the full compiler; that work belongs to v2.
