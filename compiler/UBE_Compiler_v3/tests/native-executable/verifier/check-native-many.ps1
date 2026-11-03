param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Objdump,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$clang = (Resolve-Path -LiteralPath $Clang).Path
$objdump = (Resolve-Path -LiteralPath $Objdump).Path
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$caller = Join-Path $PSScriptRoot 'native-many-caller.ll'
$callee = Join-Path $PSScriptRoot 'native-many-callee.ll'
$callerObject = Join-Path $directory 'caller.o'
$calleeObject = Join-Path $directory 'callee.o'
foreach ($pair in @(@($caller, $callerObject), @($callee, $calleeObject))) {
    & $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each -c $pair[0] -o $pair[1]
    if ($LASTEXITCODE -ne 0) { throw 'LLVM compile failed' }
}
$assembly = @(& $objdump -dr $callerObject) -join "`n"
if ($LASTEXITCODE -ne 0 -or $assembly -notmatch '(?m)IMAGE_REL_AMD64_REL32\s+weighted$') { throw 'Missing caller relocation' }
$exe = Join-Path $directory 'valid.exe'
& $clang --target=x86_64-w64-windows-gnu $callerObject $calleeObject -o $exe
if ($LASTEXITCODE -ne 0) { throw 'Link failed' }
$linked = @(& $objdump '--disassemble-symbols=main,weighted' -d $exe) -join "`n"
if ($LASTEXITCODE -ne 0 -or $linked -notmatch '(?m)\bcallq\s+[^\n]*<weighted>' -or $linked -notmatch '(?m)^\s*[0-9a-f]+ <weighted>:') { throw 'Linked call or target missing' }
function Has-ObservedPlacement([string] $text) {
    $mainMatch = [regex]::Match($text, '(?ms)^\s*[0-9a-f]+ <main>:\s*\n(.*?)(?=^\s*[0-9a-f]+ <[^>]+>:|\z)')
    $calleeMatch = [regex]::Match($text, '(?ms)^\s*[0-9a-f]+ <weighted>:\s*\n(.*?)(?=^\s*[0-9a-f]+ <[^>]+>:|\z)')
    if (-not $mainMatch.Success -or -not $calleeMatch.Success) { return $false }
    $main = $mainMatch.Groups[1].Value
    $body = $calleeMatch.Groups[1].Value
    return ($main -match '(?m)movb\s+%al,\s*0x20\(%rsp\)' -and
        $main -match '(?ms)movb\s+%al,\s*0x20\(%rsp\).*?callq\s+[^\n]*<weighted>' -and
        $body -match '(?m)movzbl\s+0x28\(%rsp\),\s*%eax' -and
        $body -match '(?m)movzbl\s+%cl,\s*%ecx' -and
        $body -match '(?m)movzbl\s+%dl,\s*%edx' -and
        $body -match '(?m)movzbl\s+%r8b,\s*%r8d' -and
        $body -match '(?m)movzbl\s+%r9b,\s*%r9d')
}
if (-not (Has-ObservedPlacement $linked)) { throw 'Linked placement did not match the host observation' }
if (Has-ObservedPlacement ($linked -replace '0x28\(%rsp\)', '0x30(%rsp)')) { throw 'Changed stack-offset control was accepted' }
[IO.File]::WriteAllText((Join-Path $directory 'linked-disassembly.txt'), $linked)
& $exe
if ($LASTEXITCODE -ne 0) { throw 'Aggregate result did not equal 55' }
$source = [IO.File]::ReadAllText($caller)
$wrong = $source.Replace('%ok = icmp eq i32 %sum, 55', '%ok = icmp eq i32 %sum, 54')
if ($wrong -ceq $source) { throw 'Wrong-result control did not change expectation' }
$wrongSource = Join-Path $directory 'wrong.ll'; [IO.File]::WriteAllText($wrongSource, $wrong)
$wrongExe = Join-Path $directory 'wrong.exe'
& $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each $wrongSource $calleeObject -o $wrongExe
if ($LASTEXITCODE -ne 0) { throw 'Wrong-result control did not compile' }
& $wrongExe
if ($LASTEXITCODE -ne 1) { throw 'Wrong-result control did not fail' }
$swapped = $source.Replace('call i32 @weighted({ i8 } %a1, { i8 } %b1, { i8 } %c1, { i8 } %d1, { i8 } %e1)', 'call i32 @weighted({ i8 } %e1, { i8 } %b1, { i8 } %c1, { i8 } %d1, { i8 } %a1)')
if ($swapped -ceq $source) { throw 'Argument-swap control did not change the call' }
$swappedSource = Join-Path $directory 'swapped.ll'; [IO.File]::WriteAllText($swappedSource, $swapped)
$swappedExe = Join-Path $directory 'swapped.exe'
& $clang --target=x86_64-w64-windows-gnu -O2 -Wno-override-module -Xclang -llvm-verify-each $swappedSource $calleeObject -o $swappedExe
if ($LASTEXITCODE -ne 0) { throw 'Argument-swap control did not compile' }
& $swappedExe
if ($LASTEXITCODE -ne 1) { throw 'Argument-swap control did not fail' }
Write-Output 'Five aggregate arguments returned 55 across the linked call; wrong expected result was rejected.'
Write-Output 'Swapping the first and fifth arguments was rejected.'
Write-Output 'First four register and fifth stack observations matched; changed stack offset was rejected.'
Write-Output "Artifacts: $directory"
