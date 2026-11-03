param([Parameter(Mandatory=$true)][string] $Clang, [Parameter(Mandatory=$true)][string] $Objdump, [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$objdump = (Resolve-Path -LiteralPath $Objdump).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$caller = Join-Path $PSScriptRoot 'native-aggregate-caller.ll'
$callee = Join-Path $PSScriptRoot 'native-aggregate-callee.ll'
$callerObject = Join-Path $directory 'caller.o'; $calleeObject = Join-Path $directory 'callee.o'
foreach ($pair in @(@($caller, $callerObject), @($callee, $calleeObject))) {
    & $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each -c $pair[0] -o $pair[1]
    if ($LASTEXITCODE -ne 0) { throw 'LLVM compile failed' }
}
function Has-Calls([string] $text) {
    foreach ($name in @('echo8', 'echo16', 'echo32', 'copy8', 'copy16', 'copy32', 'replace8', 'replace16', 'replace32')) {
        if ($text -notmatch ("(?m)IMAGE_REL_AMD64_REL32\s+" + $name + '$')) { return $false }
    }
    return $true
}
$disassembly = @(& $objdump -dr $callerObject) -join "`n"
if ($LASTEXITCODE -ne 0 -or -not (Has-Calls $disassembly)) { throw 'Separate caller does not retain all expected call relocations' }
if (Has-Calls ($disassembly -replace '(?m)(IMAGE_REL_AMD64_REL32\s+)echo8$', '${1}wrong8')) { throw 'Wrong-call control accepted' }
$exe = Join-Path $directory 'valid.exe'
& $clang --target=x86_64-w64-windows-gnu $callerObject $calleeObject -o $exe
if ($LASTEXITCODE -ne 0) { throw 'Link failed' }
function Has-LinkedCalls([string] $text) {
    $match = [regex]::Match($text, '(?ms)^\s*[0-9a-f]+ <main>:\s*\n(.*?)(?=^\s*[0-9a-f]+ <[^>]+>:|\z)')
    if (-not $match.Success) { return $false }
    $main = $match.Groups[1].Value
    foreach ($name in @('echo8', 'echo16', 'echo32', 'copy8', 'copy16', 'copy32', 'replace8', 'replace16', 'replace32')) {
        if ($main -notmatch ("(?m)\bcallq\s+[^\n]*<" + $name + '>') -or $text -notmatch ("(?m)^\s*[0-9a-f]+ <" + $name + '>:')) { return $false }
    }
    return $true
}
$linked = @(& $objdump '--disassemble-symbols=main,echo8,echo16,echo32,copy8,copy16,copy32,replace8,replace16,replace32' -d $exe) -join "`n"
if ($LASTEXITCODE -ne 0 -or -not (Has-LinkedCalls $linked)) { throw 'Linked program does not retain all expected calls and targets' }
if (Has-LinkedCalls ($linked -replace '<echo8>', '<wrong8>')) { throw 'Wrong-linked-call control accepted' }
& $exe
if ($LASTEXITCODE -ne 0) { throw 'Valid aggregate execution failed' }
$source = [IO.File]::ReadAllText($caller)
$mutated = $source.Replace('%a = icmp eq i8 %o8, -1', '%a = icmp eq i8 %o8, -2')
if ($mutated -ceq $source) { throw 'Wrong-result control did not change expectation' }
$negative = Join-Path $directory 'wrong-result.ll'; [IO.File]::WriteAllText($negative, $mutated)
$badExe = Join-Path $directory 'wrong-result.exe'
& $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each $negative $calleeObject -o $badExe
if ($LASTEXITCODE -ne 0) { throw 'Wrong-result control did not compile' }
& $badExe
if ($LASTEXITCODE -ne 1) { throw 'Wrong-result control did not fail' }
$badLayout = $source.Replace('%la16 = icmp eq i64 %a16, 2', '%la16 = icmp eq i64 %a16, 1')
if ($badLayout -ceq $source) { throw 'Wrong-layout control did not change expectation' }
$badLayoutSource = Join-Path $directory 'wrong-layout.ll'; [IO.File]::WriteAllText($badLayoutSource, $badLayout)
$badLayoutExe = Join-Path $directory 'wrong-layout.exe'
& $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each $badLayoutSource $calleeObject -o $badLayoutExe
if ($LASTEXITCODE -ne 0) { throw 'Wrong-layout control did not compile' }
& $badLayoutExe
if ($LASTEXITCODE -ne 1) { throw 'Wrong-layout control did not fail' }
$badCopy = $source.Replace('%cd8 = icmp eq i8 %before8, -1', '%cd8 = icmp eq i8 %before8, 0')
if ($badCopy -ceq $source) { throw 'Wrong-copy control did not change expectation' }
$badCopySource = Join-Path $directory 'wrong-copy.ll'; [IO.File]::WriteAllText($badCopySource, $badCopy)
$badCopyExe = Join-Path $directory 'wrong-copy.exe'
& $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each $badCopySource $calleeObject -o $badCopyExe
if ($LASTEXITCODE -ne 0) { throw 'Wrong-copy control did not compile' }
& $badCopyExe
if ($LASTEXITCODE -ne 1) { throw 'Wrong-copy control did not fail' }
Write-Output 'Aggregate layout, ByVal copies and separate linked calls passed; wrong-call, wrong-result, wrong-layout and wrong-copy controls rejected.'
