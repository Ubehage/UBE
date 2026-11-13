# Executes ordinary compiler command-option parsing with independent command and failure expectations.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube command options ' + [guid]::NewGuid())
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
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/Utf8.bas','std-lib/src/win-lib/WindowsArguments.bas','compiler/src/CommandOptions.bas','bootstrap/tests/command-options/Probe.bas')
$lines=@('UBE-Project 1','Name = "Commands"','Kind = "Library"')
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
$ir=Join-Path $artifacts 'commands.ll'
$emission=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$manifest,$ir)
Require ($emission.ExitCode -eq 0) "Emission failed $($emission.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
$allocator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
foreach($name in @('allocate','release')){
    $pattern='(?m)^(define[^\r\n@]*?)@ube\.target\.'+$name+'\('
    Require ([regex]::Matches($production,$pattern).Count -eq 1) "Missing $name wrapper"
    $production=[regex]::Replace($production,$pattern,('$'+'{1}@test.real.'+$name+'('))
}

# Supplies static input descriptors independently of the source compiler's allocation behavior.
function Descriptor([string]$Name,[byte[]]$Bytes){
    $cells=($Bytes|ForEach-Object{'i64 '+$_}) -join ', '
    return "@$Name.data = global [$($Bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Bytes.Length-1),ptr @$Name.data,ptr null}"+$nl
}

# Expected admission and diagnostic indexes are authored without calling the implementation.
$vectors=@(
    @{Text='ube --emit-llvm project.UBE output.ll';Mode=1},
    @{Text='ube --build project.UBE output.exe';Mode=2},
    @{Text='ube --build project.UBE output.exe --clang clang.exe';Mode=2;Clang=5},
    @{Text='"compiler with spaces.exe" "--emit-llvm" "source project.UBE" "output name.ll"';Mode=1},
    @{Text='ube --"build" "C:\a\"b.UBE" "C:\out\\" --clang "C:\Program Files\LLVM\clang.exe"';Mode=2;Clang=5},
    @{Text=('ube --build "'+[char]0x00E6+'.UBE" "'+[char]0x4E2D+'.exe"');Mode=2},
    @{Text="ube`t--build`tproject.UBE`toutput.exe`t";Mode=2},
    @{Text='ube --build --literal-project --literal-output';Mode=2},
    @{Text='ube --build p o --clang --literal-clang';Mode=2;Clang=5},
    @{Text='ube';Code=1;Argument=1},
    @{Text='ube --check p';Code=1;Argument=1},
    @{Text='ube --BUILD p o';Code=1;Argument=1},
    @{Text='ube --emit-llvmx p o';Code=1;Argument=1},
    @{Text='ube --build';Code=1;Argument=2},
    @{Text='ube --build p';Code=1;Argument=3},
    @{Text='ube --build "" o';Code=1;Argument=2},
    @{Text='ube --build p ""';Code=1;Argument=3},
    @{Text='ube --emit-llvm p o --clang c';Code=1;Argument=4},
    @{Text='ube --emit-llvm p o extra';Code=1;Argument=4},
    @{Text='ube --build p o --other c';Code=1;Argument=4},
    @{Text='ube --build p o --CLANG c';Code=1;Argument=4},
    @{Text='ube --build p o --clang';Code=1;Argument=5},
    @{Text='ube --build p o --clang ""';Code=1;Argument=5},
    @{Text='ube --build p o --clang c extra';Code=1;Argument=6},
    @{Text='ube --build p o --clang c ""';Code=1;Argument=6},
    @{Text='';Code=2;Argument=0;Error=5},
    @{Bytes=[byte[]]@(117,98,101,0);Code=2;Argument=0;Error=5},
    @{Bytes=[byte[]]@(117,98,101,32,195,40);Code=2;Argument=0;Error=5}
)
$globals='@test.context = private global %ube.context zeroinitializer, align 8'+$nl
$code=New-Object Collections.Generic.List[string]
foreach($line in @('define i32 @main() {','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)')){$code.Add($line)}
for($i=0;$i -lt $vectors.Count;$i++){
    $vector=$vectors[$i];$mode=0;$clangIndex=0;$diagnostic=0;$argument=0;$errorNumber=71
    if($vector.ContainsKey('Mode')){$mode=$vector.Mode}
    if($vector.ContainsKey('Clang')){$clangIndex=$vector.Clang}
    if($vector.ContainsKey('Code')){$diagnostic=$vector.Code;$argument=$vector.Argument}
    if($vector.ContainsKey('Error')){$errorNumber=$vector.Error}
    $bytes=$null
    if($vector.ContainsKey('Bytes')){$bytes=$vector.Bytes}else{$bytes=$utf8.GetBytes($vector.Text)}
    $globals+=Descriptor "raw$i" $bytes
    foreach($line in @("%case$i = call {i1,i64} @ube.proc.$($symbols['Check'])(ptr @test.context,ptr @raw$i,i64 $mode,i64 $clangIndex,i64 $diagnostic,i64 $argument,i64 $errorNumber)","%fresh$i = extractvalue {i1,i64} %case$i,0","%value$i = extractvalue {i1,i64} %case$i,1","%zero$i = icmp eq i64 %value$i,0","%good$i = and i1 %fresh$i,%zero$i","br i1 %good$i,label %next$i,label %bad$i",("bad"+$i+':'),"%dispose$i = call i1 @ube.context.dispose(ptr @test.context)",('ret i32 '+($i+100)),("next"+$i+':'))){$code.Add($line)}
}
# The fully populated command requires three allocations per present argument and one for the absent seventh.
foreach($line in @('store i64 0,ptr @test.alloc.calls',"%baseline = call {i1,i64} @ube.proc.$($symbols['Check'])(ptr @test.context,ptr @raw2,i64 2,i64 5,i64 0,i64 0,i64 71)",'%baseline.fresh = extractvalue {i1,i64} %baseline,0','%baseline.value = extractvalue {i1,i64} %baseline,1','%baseline.zero = icmp eq i64 %baseline.value,0','%baseline.good = and i1 %baseline.fresh,%baseline.zero','%observed = load i64,ptr @test.alloc.calls','%expected = icmp eq i64 %observed,19','%measured = and i1 %baseline.good,%expected','br i1 %measured,label %fault.entry,label %failed','fault.entry:','br label %fault','fault:','%site = phi i64 [1,%fault.entry],[%next.site,%recovery]','store i64 0,ptr @test.alloc.calls','store i64 2,ptr @test.fail.remaining','store i64 %site,ptr @test.fail.after','%previous = sub i64 %site,1','%argument = udiv i64 %previous,3',"%fault.result = call {i1,i64} @ube.proc.$($symbols['CheckAllocation'])(ptr @test.context,ptr @raw2,i64 %argument)",'%fault.fresh = extractvalue {i1,i64} %fault.result,0','%fault.value = extractvalue {i1,i64} %fault.result,1','%fault.zero = icmp eq i64 %fault.value,0','%fault.good = and i1 %fault.fresh,%fault.zero','%calls = load i64,ptr @test.alloc.calls','%attempts = add i64 %site,1','%retry.failed = icmp eq i64 %calls,%attempts','%fault.qualified = and i1 %fault.good,%retry.failed','br i1 %fault.qualified,label %recovery,label %failed','recovery:',"%again = call {i1,i64} @ube.proc.$($symbols['Check'])(ptr @test.context,ptr @raw2,i64 2,i64 5,i64 0,i64 0,i64 71)",'%again.fresh = extractvalue {i1,i64} %again,0','%again.value = extractvalue {i1,i64} %again,1','%again.zero = icmp eq i64 %again.value,0','%again.good = and i1 %again.fresh,%again.zero','%next.site = add i64 %site,1','%more = icmp ule i64 %next.site,%observed','br i1 %again.good,label %advance,label %failed','advance:','br i1 %more,label %fault,label %done','done:','%disposed = call i1 @ube.context.dispose(ptr @test.context)','%live = load i64,ptr @test.live','%clean = icmp eq i64 %live,0','%complete = and i1 %disposed,%clean','%exit = select i1 %complete,i32 0,i32 98','ret i32 %exit','failed:','%cleanup = call i1 @ube.context.dispose(ptr @test.context)','ret i32 99','}')){$code.Add($line)}
# The loop returns from its explicit advance block; the phi predecessor must name that block.
$combined=$production+$nl+$allocator+$nl+$globals+(($code -join $nl).Replace('[%next.site,%recovery]','[%next.site,%advance]'))
$path=Join-Path $artifacts 'observed.ll';Write-Text $path $combined
foreach($level in @('O0','O2')){
    $exe=Join-Path $artifacts "commands-$level.exe";Build-Harness $path $exe $level
    $run=Invoke-BoundedProcess $exe @()
    Require ($run.ExitCode -eq 0) "Command assertions failed $level code=$($run.ExitCode) $($run.Evidence)"
    Write-Output "PASS $level : $($vectors.Count) exact command/diagnostic vectors, 19 allocation sites with failed retries, recovery and zero live blocks"
}
# Changes a valid mode spelling without changing its expected request result.
$original=Descriptor 'raw0' ($utf8.GetBytes($vectors[0].Text))
$changed=Descriptor 'raw0' ($utf8.GetBytes($vectors[0].Text.Replace('--emit-llvm','--Emit-llvm')))
Require ($combined.Contains($original)) 'Missing command input control'
$negative=Join-Path $artifacts 'negative.ll';Write-Text $negative ($combined.Replace($original,$changed))
$exe=Join-Path $artifacts 'negative.exe';Build-Harness $negative $exe 'O2'
$run=Invoke-BoundedProcess $exe @()
Require ($run.ExitCode -eq 100) 'Changed command must fail the unchanged request expectation'
Write-Output "PASS changed-command negative control. Evidence: $artifacts"

