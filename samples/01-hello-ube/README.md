# Hello, UBE!

Hello, UBE! is the first UBE sample and the only console program in the sample
collection. It introduces the smallest complete native UBE application before
later samples move into the visual designer and windowed user interfaces.

The program demonstrates:

- apostrophe comments;
- a parameterless `Sub Main()` entry point;
- explicitly typed `String` and `Long` variables;
- string concatenation and console `Print` statements; and
- simple integer addition.

## Program output

```text
Hello, UBE!
Welcome to native Basic programming.
2 + 3 equals:
5
```

The program waits for no input and returns the successful process exit code
zero when `Main` finishes.

## Build and run

First run the repository bootstrap build so the pinned compiler toolchain and
runtime objects have been verified:

```powershell
& ../../bootstrap/build.ps1
```

Then run the sample smoke test from this directory:

```powershell
& ./tests/smoke.ps1
```

The smoke test uses the preserved UBE Compiler v3 RP8 executable and LLVM/Clang
23, builds into a unique temporary directory, runs the resulting program,
checks its complete output and exit code, and removes its temporary files. Its
parameters may be used to select other compatible compiler, Clang, and runtime
object paths.

When the UBE IDE sample browser is available, open `HelloUBE.UBE` and use the
normal Build and Run commands. The `.UBE` file is the project manifest;
`src/Main.bas` contains the source code.

## Try next

Change the greeting, choose different `Long` values, or add another `Print`
statement. Keep every variable explicitly typed so compiler diagnostics remain
clear and predictable.
