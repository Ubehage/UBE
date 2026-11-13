# Executes Windows argument encoding with exact bytes and an independent Windows parser oracle.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube windows arguments ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $artifacts -Force
$script:processNumber = 0
$BootstrapExe = [IO.Path]::GetFullPath($BootstrapExe)

# Stops on a failed independently authored acceptance assertion.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Writes deterministic UTF-8 source and IR, never the host's default text encoding.
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

# Quotes literal Windows command-line arguments including quotes and trailing backslashes.
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

# Retains a hidden child handle, bounds execution and saves each fresh process observation.
function Invoke-BoundedProcess([string]$File, [string[]]$Arguments) {
    $script:processNumber++
    $prefix = Join-Path $artifacts ('process-' + $script:processNumber)
    $start = @{ FilePath=$File; WorkingDirectory=$artifacts; WindowStyle='Hidden'; PassThru=$true; RedirectStandardOutput=($prefix + '.stdout'); RedirectStandardError=($prefix + '.stderr') }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @start
    try {
        $handle = $process.Handle
        if (-not $process.WaitForExit(60000)) { $process.Kill(); $null = $process.WaitForExit(5000); throw "Process timeout. Evidence: $prefix" }
        $process.Refresh()
        Require ($null -ne $process.ExitCode) "Missing exit code for retained handle $handle"
        return [pscustomobject]@{ ExitCode=$process.ExitCode; Stdout=[IO.File]::ReadAllText($prefix + '.stdout',$utf8); Stderr=[IO.File]::ReadAllText($prefix + '.stderr',$utf8); Evidence=$prefix }
    } finally { $process.Dispose() }
}

. (Join-Path $PSScriptRoot '../NativeMemory.ps1')

# Compiles the same emitted library plus observation harness and checks AMD64 PE framing.
function Build-Harness([string]$IR, [string]$Exe, [string]$Level) {
    $link = @(Get-NativeMemoryLinkArguments $IR $Clang $artifacts)
    $result = Invoke-BoundedProcess $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR) + $link + @('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608'))
    Require ($result.ExitCode -eq 0) "Harness compilation failed. Evidence: $($result.Evidence)"
    $bytes = [IO.File]::ReadAllBytes($Exe)
    Require ($bytes.Length -ge 64 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) 'Invalid native DOS header'
    $offset = [BitConverter]::ToInt32($bytes,0x3c)
    Require ($offset -ge 64 -and $offset -le $bytes.Length - 6) 'Invalid native PE offset'
    Require ([BitConverter]::ToUInt32($bytes,$offset) -eq 0x4550 -and [BitConverter]::ToUInt16($bytes,$offset+4) -eq 0x8664) 'Expected AMD64 PE executable'
}

$nl="`r`n"
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
Write-Output "Artifacts retained: $artifacts"
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/FileBytes.bas','std-lib/src/portable/Utf8.bas','std-lib/src/win-lib/WindowsArguments.bas','bootstrap/tests/windows-arguments/ArgumentProbe.bas')
$lines=@('UBE-Project 1','Name = "Arguments"','Kind = "Library"')
foreach($file in $files){
    $leaf=[IO.Path]::GetFileName($file)
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $artifacts $leaf)
    $lines+='Source = "'+$leaf+'"'
}
$manifest=Join-Path $artifacts 'project.UBE'
Write-Text $manifest (($lines -join $nl)+$nl)
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Binding failed $($bound.Evidence)"
$symbols=@{}
foreach($line in ($bound.Stdout -split '\r?\n')){
    if($line -match '^SYMBOL (\d+)\|function\|([^|]+)\|'){$symbols[$Matches[2]]=$Matches[1]}
}
$ir=Join-Path $artifacts 'arguments.ll'
$emission=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$manifest,$ir)
Require ($emission.ExitCode -eq 0) "Emission failed $($emission.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
$allocator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
foreach($name in @('allocate','release')){
    $pattern='(?m)^(define[^\r\n@]*?)@ube\.target\.'+$name+'\('
    Require ([regex]::Matches($production,$pattern).Count -eq 1) "Missing $name wrapper"
    $production=[regex]::Replace($production,$pattern,('$'+'{1}@test.real.'+$name+'('))
}

# Supplies static descriptors independently of the compiler's allocation implementation.
function Descriptor([string]$Name,[byte[]]$Bytes){
    $cells=($Bytes|ForEach-Object{'i64 '+$_}) -join ', '
    return "@$Name.data = global [$($Bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Bytes.Length-1),ptr @$Name.data,ptr null}"+$nl
}

# Expected strings are authored directly, without invoking a quoting implementation.
$vectors=@(
    @{Text='';Expected='""'},
    @{Text='abc';Expected='"abc"'},
    @{Text='a b';Expected='"a b"'},
    @{Text="a`tb";Expected="`"a`tb`""},
    @{Text='"';Expected='"\""'},
    @{Text='a"b';Expected='"a\"b"'},
    @{Text='a\b';Expected='"a\b"'},
    @{Text='a\\b';Expected='"a\\b"'},
    @{Text='a\';Expected='"a\\"'},
    @{Text='a\\';Expected='"a\\\\"'},
    @{Text='a\"b';Expected='"a\\\"b"'},
    @{Text='a\\"b';Expected='"a\\\\\"b"'},
    @{Text=([string][char]0x00E6+[char]0x03A9+[char]0x4E2D);Expected=('"'+[char]0x00E6+[char]0x03A9+[char]0x4E2D+'"')},
    @{Text='a b';Expected='"a b"';Source='!a b?';Start=1},
    @{Text='a\"b\';Expected='"a\\\"b\\"';Alias=$true}
)
$globals='@test.context = private global %ube.context zeroinitializer, align 8'+$nl
$code=@('define i32 @main() {','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
$outputs=@()
for($i=0;$i -lt $vectors.Count;$i++){
    $vector=$vectors[$i];$source=$vector.Text;$start=0;$alias=0
    if($vector.ContainsKey('Source')){$source=$vector.Source;$start=$vector.Start}
    if($vector.ContainsKey('Alias')){$alias=-1}
    $output=Join-Path $artifacts "quoted-$i.bin";$outputs+=$output
    $globals+=Descriptor "source$i" ($utf8.GetBytes($source))
    $globals+=Descriptor "expected$i" ($utf8.GetBytes($vector.Expected))
    $globals+=Descriptor "path$i" ($utf8.GetBytes($output))
    $count=$utf8.GetByteCount($vector.Text)
    $next='case'+($i+1)
    $code+=@(('case'+$i+':'),"%p$i = call {i1,i64} @ube.proc.$($symbols['CheckCase'])(ptr @test.context,ptr @source$i,i64 $start,i64 $count,ptr @expected$i,ptr @path$i,i64 $alias)","%f$i = extractvalue {i1,i64} %p$i,0","%v$i = extractvalue {i1,i64} %p$i,1","%z$i = icmp eq i64 %v$i,0","%g$i = and i1 %f$i,%z$i","br i1 %g$i,label %$next,label %failed")
}
$code+=('case'+$vectors.Count+':')
foreach($mode in 0..9){
    if($mode -eq 9){$code+=@('store i64 2,ptr @test.fail.remaining','store i64 0,ptr @test.fail.after','store i64 0,ptr @test.alloc.calls')}
    $code+=@("%b$mode = call {i1,i64} @ube.proc.$($symbols['CheckFailure'])(ptr @test.context,i64 $mode)","%bf$mode = extractvalue {i1,i64} %b$mode,0","%bv$mode = extractvalue {i1,i64} %b$mode,1","%bz$mode = icmp eq i64 %bv$mode,0","%bg$mode = and i1 %bf$mode,%bz$mode","br i1 %bg$mode,label %bound$mode,label %failed",("bound"+$mode+':'))
}
$code+=@('%calls = load i64,ptr @test.alloc.calls','%two = icmp eq i64 %calls,2','br i1 %two,label %recovery,label %failed','recovery:',"%retry = call {i1,i64} @ube.proc.$($symbols['TryAppendQuotedArgument'])(ptr @test.context,ptr @source1,i64 0,i64 3,ptr @recovery.buffer,ptr @recovery.used)",'%retry.fresh = extractvalue {i1,i64} %retry,0','%retry.value = extractvalue {i1,i64} %retry,1','%retry.true = icmp eq i64 %retry.value,-1','%retry.good = and i1 %retry.fresh,%retry.true','br i1 %retry.good,label %done,label %failed','done:','%disposed = call i1 @ube.context.dispose(ptr @test.context)','%live = load i64,ptr @test.live','%clean = icmp eq i64 %live,0','%good = and i1 %disposed,%clean','%exit = select i1 %good,i32 0,i32 98','ret i32 %exit','failed:','%cleanup = call i1 @ube.context.dispose(ptr @test.context)','ret i32 99','}')
$globals+=Descriptor 'recovery.buffer' ([byte[]](0,0,0,0,0,0))
$globals+='@recovery.used = global i64 0'+$nl
$combined=$production+$nl+$allocator+$nl+$globals+($code -join $nl)
$path=Join-Path $artifacts 'observed.ll';Write-Text $path $combined

# Calls the native Windows argument parser, copying results before releasing its allocation.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class WindowsArgumentOracle {
    [DllImport("shell32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern IntPtr CommandLineToArgvW(string commandLine, out int count);
    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr value);
    public static string[] Parse(string commandLine) {
        int count;
        IntPtr pointer = CommandLineToArgvW(commandLine, out count);
        if (pointer == IntPtr.Zero) throw new InvalidOperationException("CommandLineToArgvW failed");
        try {
            string[] result = new string[count];
            for (int i=0; i<count; i++) result[i] = Marshal.PtrToStringUni(Marshal.ReadIntPtr(pointer,i*IntPtr.Size));
            return result;
        } finally { LocalFree(pointer); }
    }
}
'@
foreach($level in @('O0','O2')){
    foreach($output in $outputs){if(Test-Path -LiteralPath $output){Remove-Item -LiteralPath $output}}
    $exe=Join-Path $artifacts "arguments-$level.exe";Build-Harness $path $exe $level
    $run=Invoke-BoundedProcess $exe @()
    Require ($run.ExitCode -eq 0) "Argument assertions failed $level $($run.Evidence)"
    $quoted=@()
    for($i=0;$i -lt $vectors.Count;$i++){
        $actual=[IO.File]::ReadAllBytes($outputs[$i]);$expected=$utf8.GetBytes($vectors[$i].Expected)
        Require ([Convert]::ToBase64String($actual) -ceq [Convert]::ToBase64String($expected)) "Exact quoted bytes differ vector$i $level"
        $quoted+=$utf8.GetString($actual)
    }
    $arguments=[WindowsArgumentOracle]::Parse('probe.exe '+($quoted -join ' '))
    Require ($arguments.Count -eq $vectors.Count+1 -and $arguments[0] -ceq 'probe.exe') 'Windows oracle returned wrong argument count'
    for($i=0;$i -lt $vectors.Count;$i++){Require ($arguments[$i+1] -ceq $vectors[$i].Text) "Windows roundtrip differs vector$i $level"}
    Write-Output "PASS $level : 15 exact byte vectors and Windows roundtrips; 10 preservation/failure cases, two failed allocations, recovery and zero live blocks"
}
$negative=Join-Path $artifacts 'negative.ll'
Require ($combined.Contains('@source1.data = global [3 x i64] [i64 97, i64 98, i64 99]')) 'Missing changed-input control'
Write-Text $negative ($combined.Replace('@source1.data = global [3 x i64] [i64 97, i64 98, i64 99]','@source1.data = global [3 x i64] [i64 120, i64 98, i64 99]'))
foreach($output in $outputs){if(Test-Path -LiteralPath $output){Remove-Item -LiteralPath $output}}
$exe=Join-Path $artifacts 'negative.exe';Build-Harness $negative $exe 'O2'
$run=Invoke-BoundedProcess $exe @()
Require ($run.ExitCode -eq 99) 'Changed source bytes did not reject unchanged exact expectations'
Write-Output "PASS changed-input negative control. Evidence: $artifacts"

# Enumerates short raw syntax combinations; expectations come only from Windows itself.
$rawLines=New-Object Collections.Generic.List[string]
$rawLines.Add('app ')
$words=@('')
foreach($length in 1..5){
    $nextWords=@()
    foreach($word in $words){foreach($character in @('a',' ','\','"')){$nextWords+=($word+$character)}}
    foreach($word in $nextWords){$rawLines.Add('app '+$word)}
    $words=$nextWords
}
foreach($raw in @('app', ' app a', "`tapp a", '"app name" arg', '"app"tail arg', 'app"quoted name" arg', '"unterminated app name', '"" a', 'a\"b c', 'app "a"""b" c', 'app a\\\"b', "app a`tb", ('app '+[char]0x00E6+[char]0x4E2D))){$rawLines.Add($raw)}
$readGlobals='@test.context = private global %ube.context zeroinitializer, align 8'+$nl+'@failure.code = global i32 99'+$nl
$readCode=New-Object Collections.Generic.List[string]
foreach($line in @('define i32 @main() {','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)')){$readCode.Add($line)}
$readCases=0
$caseDescriptions=New-Object Collections.Generic.List[string]
foreach($raw in $rawLines){
    $expectedArguments=[WindowsArgumentOracle]::Parse($raw)
    for($request=0;$request -le $expectedArguments.Count;$request++){
        $id=$readCases;$readCases++
        $expected='';$found=0
        if($request -lt $expectedArguments.Count){$expected=$expectedArguments[$request];$found=-1}
        $readGlobals+=Descriptor "raw$id" ($utf8.GetBytes($raw))
        $readGlobals+=Descriptor "want$id" ($utf8.GetBytes($expected))
        $caseDescriptions.Add("$id request=$request raw=<$raw> expected=<$expected> found=$found")
        foreach($line in @("%read$id = call {i1,i64} @ube.proc.$($symbols['CheckRead'])(ptr @test.context,ptr @raw$id,i64 $request,ptr @want$id,i64 $found,i64 0)","%rf$id = extractvalue {i1,i64} %read$id,0","%rv$id = extractvalue {i1,i64} %read$id,1","%rz$id = icmp eq i64 %rv$id,0","%rg$id = and i1 %rf$id,%rz$id","br i1 %rg$id,label %next$id,label %bad$id",("bad"+$id+':'),"%dispose$id = call i1 @ube.context.dispose(ptr @test.context)",('ret i32 '+($id+100)),("next"+$id+':'))){$readCode.Add($line)}
    }
}
# Destination aliasing is tested separately from ordinary and missing-argument publication.
$readGlobals+=Descriptor 'alias.raw' ($utf8.GetBytes('app "hello world"'))
$readGlobals+=Descriptor 'alias.want' ($utf8.GetBytes('hello world'))
$readCode.Add('store i32 10,ptr @failure.code')
$readCode.Add("%alias = call {i1,i64} @ube.proc.$($symbols['CheckRead'])(ptr @test.context,ptr @alias.raw,i64 1,ptr @alias.want,i64 -1,i64 -1)")
$readCode.Add('%alias.value = extractvalue {i1,i64} %alias,1')
$readCode.Add('%alias.good = icmp eq i64 %alias.value,0')
$readCode.Add('br i1 %alias.good,label %invalid,label %failure')
$readCode.Add('invalid:')
$invalid=@(
    @{Bytes=[byte[]]@();Request=0;Error=5},
    @{Bytes=$utf8.GetBytes('app');Request=-1;Error=5},
    @{Bytes=[byte[]]@(97,0,98);Request=0;Error=5},
    @{Bytes=[byte[]]@(97,32,195,40);Request=1;Error=5}
    @{Bytes=$utf8.GetBytes(('a' * 131073));Request=0;Error=5}
)
for($i=0;$i -lt $invalid.Count;$i++){
    $item=$invalid[$i]
    $readCode.Add(('store i32 '+(20+$i)+',ptr @failure.code'))
    $readGlobals+=Descriptor "invalid$i" $item.Bytes
    foreach($line in @("%invalid$i = call {i1,i64} @ube.proc.$($symbols['CheckReadFailure'])(ptr @test.context,ptr @invalid$i,i64 $($item.Request),i64 $($item.Error))","%iv$i = extractvalue {i1,i64} %invalid$i,1","%iz$i = icmp eq i64 %iv$i,0","br i1 %iz$i,label %invalid.next$i,label %failure",("invalid.next"+$i+':'))){$readCode.Add($line)}
}
$readGlobals+=Descriptor 'fault.raw' ($utf8.GetBytes('app value'))
foreach($site in 1..3){
    $readCode.Add(('store i32 '+(30+$site)+',ptr @failure.code'))
    foreach($line in @('store i64 0,ptr @test.alloc.calls','store i64 2,ptr @test.fail.remaining',"store i64 $site,ptr @test.fail.after","%fault$site = call {i1,i64} @ube.proc.$($symbols['CheckReadFailure'])(ptr @test.context,ptr @fault.raw,i64 1,i64 7)","%fv$site = extractvalue {i1,i64} %fault$site,1","%fz$site = icmp eq i64 %fv$site,0","%fc$site = load i64,ptr @test.alloc.calls",("%fe$site = icmp eq i64 %fc$site,"+($site+1)),"%fg$site = and i1 %fz$site,%fe$site","br i1 %fg$site,label %fault.next$site,label %failure",("fault.next"+$site+':'))){$readCode.Add($line)}
}
foreach($line in @("%recovered = call {i1,i64} @ube.proc.$($symbols['CheckRead'])(ptr @test.context,ptr @alias.raw,i64 1,ptr @alias.want,i64 -1,i64 0)",'%recovered.value = extractvalue {i1,i64} %recovered,1','%recovered.good = icmp eq i64 %recovered.value,0','%disposed = call i1 @ube.context.dispose(ptr @test.context)','%live = load i64,ptr @test.live','%clean = icmp eq i64 %live,0','%clean.all = and i1 %disposed,%clean','%all = and i1 %clean.all,%recovered.good','%exit = select i1 %all,i32 0,i32 98','ret i32 %exit','failure:','%failed.dispose = call i1 @ube.context.dispose(ptr @test.context)','ret i32 99','}')){$readCode.Add($line)}
$readCode[$readCode.Count-2]='%failed.code = load i32,ptr @failure.code'+$nl+'ret i32 %failed.code'
$readIR=Join-Path $artifacts 'read.ll'
Write-Text $readIR ($production+$nl+$allocator+$nl+$readGlobals+($readCode -join $nl))
Write-Text (Join-Path $artifacts 'read-cases.txt') ($caseDescriptions -join $nl)
foreach($level in @('O0','O2')){
    $exe=Join-Path $artifacts "read-$level.exe";Build-Harness $readIR $exe $level
    $run=Invoke-BoundedProcess $exe @()
    $detail=''
    if($run.ExitCode -ge 100 -and $run.ExitCode -lt $readCases+100){$detail=$caseDescriptions[$run.ExitCode-100]}
    Require ($run.ExitCode -eq 0) "Raw parser failed $level code=$($run.ExitCode) $detail Evidence:$($run.Evidence)"
    Write-Output "PASS raw parser $level : $readCases Windows-oracle comparisons, alias, invalid input, three allocation sites/retries, recovery and zero live blocks"
}
$readText=[IO.File]::ReadAllText($readIR,$utf8)
$control='@raw0.data = global [4 x i64] [i64 97, i64 112, i64 112, i64 32]'
Require ($readText.Contains($control)) 'Missing raw-parser runtime input control'
$readNegative=Join-Path $artifacts 'read-negative.ll'
Write-Text $readNegative ($readText.Replace($control,'@raw0.data = global [4 x i64] [i64 120, i64 112, i64 112, i64 32]'))
$exe=Join-Path $artifacts 'read-negative.exe';Build-Harness $readNegative $exe 'O2'
$run=Invoke-BoundedProcess $exe @()
Require ($run.ExitCode -eq 100) 'Changed raw bytes did not reject the Windows oracle expectation'
Write-Output "PASS raw-parser changed-input negative control. Evidence: $artifacts"


