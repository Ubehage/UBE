# Executes retained process ownership, wait, termination and release contracts.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube process primitives ' + [guid]::NewGuid())
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

$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$nl="`r`n"
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/ProcessPrimitives.bas','bootstrap/tests/process-primitives/Probe.bas')
$lines=@('UBE-Project 1','Name = "Processes"','Kind = "Library"')
foreach($file in $files){$leaf=[IO.Path]::GetFileName($file);Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $artifacts $leaf);$lines+='Source = "'+$leaf+'"'}
$manifest=Join-Path $artifacts 'project.UBE';Write-Text $manifest (($lines -join $nl)+$nl)
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Binding failed $($bound.Evidence)"
$symbols=@{}
foreach($line in ($bound.Stdout -split '\r?\n')){if($line -match '^SYMBOL (\d+)\|function\|([^|]+)\|'){$symbols[$Matches[2]]=$Matches[1]}}
$ir=Join-Path $artifacts 'process.ll';$emission=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$manifest,$ir)
Require ($emission.ExitCode -eq 0) "Emission failed $($emission.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
$allocator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
foreach($name in @('allocate','release')){$production=[regex]::Replace($production,'(?m)^(define[^\r\n@]*?)@ube\.target\.'+$name+'\(',('$'+'{1}@test.real.'+$name+'('))}
$observer='@test.native.kind = global i64 0'+$nl+'@test.native.after = global i64 0'+$nl+'@test.native.live = global i64 0'+$nl+'@test.attributes.live = global i64 0'+$nl
$nativeIds=@{};$nativeId=0
# Wraps only the irreducible target calls; real successful ownership changes are counted independently.
foreach($match in [regex]::Matches($production,'(?m)^define (i1|i32|ptr|void) @ube\.target\.process\.(\w+)\(([^\r\n]*)\) \{')){
 $type=$match.Groups[1].Value;$name=$match.Groups[2].Value;$params=$match.Groups[3].Value
 if($name -eq 'sleep'){continue}
 $nativeId++;$nativeIds[$name]=$nativeId
 $production=$production.Replace($match.Value,$match.Value.Replace('@ube.target.process.','@test.real.process.'))
 $observer+="define $type @ube.target.process.$name($params) {"+$nl+'entry:'+$nl
 if($type -ne 'void'){
  $failure='false';if($type -eq 'ptr'){$failure='null'};if($type -eq 'i32'){$failure='-1'}
  $observer+="%kind = load i64,ptr @test.native.kind`n%selected = icmp eq i64 %kind,$nativeId`n%after = load i64,ptr @test.native.after`n%positive = icmp ugt i64 %after,0`n%pending = and i1 %selected,%positive`nbr i1 %pending,label %count,label %real`ncount:`n%less = sub i64 %after,1`nstore i64 %less,ptr @test.native.after`n%due = icmp eq i64 %less,0`nbr i1 %due,label %fail,label %real`nfail:`nret $type $failure`nreal:`n"
 }
 $prefix='%result = ';if($type -eq 'void'){$prefix=''}
 $observer+=$prefix+"call $type @test.real.process.$name($params)"+$nl
 $amount=0;$counter='test.native.live'
 if($name -in @('job','nullinput','duplicate')){$amount=1}
 if($name -eq 'create'){$amount=2}
 if($name -eq 'close'){$amount=-1}
 if($name -eq 'attributes'){$amount=1;$counter='test.attributes.live'}
 if($name -eq 'deleteattributes'){$amount=-1;$counter='test.attributes.live'}
 if($amount -ne 0){
  if($type -eq 'ptr'){$observer+='%success = icmp ne ptr %result,null'+$nl;$condition='%success'}elseif($type -eq 'void'){$condition='true'}else{$condition='%result'}
  $observer+="%delta = select i1 $condition,i64 $amount,i64 0`n%old = load i64,ptr @$counter`n%new = add i64 %old,%delta`nstore i64 %new,ptr @$counter`n"
 }
 if($type -eq 'void'){$observer+='ret void'+$nl}else{$observer+="ret $type %result"+$nl}
 $observer+='}'+$nl
}

# Supplies independent byte-array descriptors; empty arrays use the runtime's empty bounds.
function Descriptor([string]$Name,[string]$Value){
    $bytes=$utf8.GetBytes($Value);$cells=($bytes|ForEach-Object{'i64 '+$_}) -join ', '
    return "@$Name.data = global [$($bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($bytes.Length-1),ptr @$Name.data,ptr null}"+$nl
}

# Encodes independent expected UTF-16 units including their terminator for OS-visible child checks.
function WideConstant([string]$Name,[string]$Value){
 $units=@($Value.ToCharArray()|ForEach-Object{'i16 '+[int]$_});$units+='i16 0'
 return "@$Name = private constant [$($units.Count) x i16] ["+($units -join ',')+']'+$nl
}

# Produces an actual native child with no command shell or CRT dependency.
$childIR=@'
declare dllimport ptr @GetStdHandle(i32)
declare dllimport i32 @WriteFile(ptr,ptr,i32,ptr,ptr)
declare dllimport i32 @ReadFile(ptr,ptr,i32,ptr,ptr)
declare dllimport ptr @GetCommandLineW()
declare dllimport i32 @GetCurrentDirectoryW(i32,ptr)
@message = private constant [8 x i8] c"out!err!"
@directory.buffer = private global [4097 x i16] zeroinitializer
define i1 @same(ptr %first,ptr %second) {
entry: br label %loop
loop:
 %i = phi i64 [0,%entry],[%next,%advance]
 %a = getelementptr i16,ptr %first,i64 %i
 %b = getelementptr i16,ptr %second,i64 %i
 %av = load i16,ptr %a
 %bv = load i16,ptr %b
 %eq = icmp eq i16 %av,%bv
 br i1 %eq,label %matched,label %bad
matched:
 %zero = icmp eq i16 %av,0
 br i1 %zero,label %done,label %advance
advance:
 %next = add i64 %i,1
 br label %loop
done: ret i1 true
bad: ret i1 false
}
define i32 @main() {
entry:
 %count = alloca i32
 %byte = alloca i8
 %length = call i32 @GetCurrentDirectoryW(i32 4097,ptr @directory.buffer)
 %dirgood = call i1 @same(ptr @directory.buffer,ptr @expected.directory)
 %command = call ptr @GetCommandLineW()
 %cmdgood = call i1 @same(ptr %command,ptr @expected.command)
 %stringsgood = and i1 %dirgood,%cmdgood
 br i1 %stringsgood,label %inputcheck,label %bad
inputcheck:
 %input = call ptr @GetStdHandle(i32 -10)
 store i32 99,ptr %count
 %read = call i32 @ReadFile(ptr %input,ptr %byte,i32 1,ptr %count,ptr null)
 %n = load i32,ptr %count
 %empty = icmp eq i32 %n,0
 %ok = icmp ne i32 %read,0
 %valid = and i1 %empty,%ok
 br i1 %valid,label %write,label %bad
write:
 %out = call ptr @GetStdHandle(i32 -11)
 %a = call i32 @WriteFile(ptr %out,ptr @message,i32 4,ptr %count,ptr null)
 %err = call ptr @GetStdHandle(i32 -12)
 %tail = getelementptr i8,ptr @message,i64 4
 %b = call i32 @WriteFile(ptr %err,ptr %tail,i32 4,ptr %count,ptr null)
 ret i32 42
bad:
 ret i32 43
}
'@
$child=Join-Path $artifacts ('child '+[char]0x00E6+'.exe');$childCommand='"'+$child+'" "quoted value" '+[char]0x4E2D+' "tail\\"'
$childIR+=(WideConstant 'expected.directory' $artifacts)+(WideConstant 'expected.command' $childCommand)
$childPath=Join-Path $artifacts 'child.ll';Write-Text $childPath $childIR
$link=@(Get-NativeMemoryLinkArguments $ir $Clang $artifacts)
$childDef=Join-Path $artifacts 'child.def';$childLib=Join-Path $artifacts 'child.lib'
Write-Text $childDef "LIBRARY KERNEL32.dll`nEXPORTS`nGetCurrentDirectoryW`n"
$built=Invoke-BoundedProcess (Join-Path ([IO.Path]::GetDirectoryName($Clang)) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',$childDef,'-l',$childLib)
Require ($built.ExitCode -eq 0) 'Child oracle import library failed'
$built=Invoke-BoundedProcess $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',$childPath,$childLib)+$link+@('-o',$child,'-Wl,/entry:main,/subsystem:console'))
Require ($built.ExitCode -eq 0) "Child build failed $($built.Evidence)"
$spin=Join-Path $artifacts 'spin.exe';$spinPath=Join-Path $artifacts 'spin.ll';Write-Text $spinPath 'define i32 @main() { entry: br label %loop
loop: br label %loop }'
$built=Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',$spinPath,'-o',$spin,'-Wl,/entry:main,/subsystem:console')
Require ($built.ExitCode -eq 0) "Spin child build failed $($built.Evidence)"
$tree=Join-Path $artifacts 'tree.exe';$treePath=Join-Path $artifacts 'tree.ll'
$treeIR=@'
declare dllimport i32 @CreateProcessW(ptr,ptr,ptr,ptr,i32,i32,ptr,ptr,ptr,ptr)
declare dllimport i32 @CloseHandle(ptr)
@startup = global [104 x i8] zeroinitializer,align 8
@info = global [24 x i8] zeroinitializer,align 8
define i32 @main() {
entry:
 store i32 104,ptr @startup
 %created = call i32 @CreateProcessW(ptr @tree.app,ptr @tree.command,ptr null,ptr null,i32 0,i32 134217728,ptr null,ptr null,ptr @startup,ptr @info)
 %ok = icmp ne i32 %created,0
 br i1 %ok,label %close,label %bad
close:
 %process = load ptr,ptr @info
 %threadptr = getelementptr i8,ptr @info,i64 8
 %thread = load ptr,ptr %threadptr
 %a = call i32 @CloseHandle(ptr %thread)
 %b = call i32 @CloseHandle(ptr %process)
 ret i32 55
bad: ret i32 56
}
'@
$treeIR+=$nl+(WideConstant 'tree.app' $spin)+((WideConstant 'tree.command' ('"'+$spin+'"')).Replace('private constant','global'))
Write-Text $treePath $treeIR
$built=Invoke-BoundedProcess $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',$treePath)+$link+@('-o',$tree,'-Wl,/entry:main,/subsystem:console'))
Require ($built.ExitCode -eq 0) "Tree child build failed $($built.Evidence)"

foreach($level in @('O0','O2')){
 $script:step=0;$script:code=New-Object Collections.Generic.List[string]
 # Emits fresh-status and exact-value assertions, retaining a stable failed-case exit number.
 function Check([string]$Name,[string]$Arguments,[long]$Expected){
  $script:step++;$id=$script:step;$args='ptr @test.context';if($Arguments){$args+=','+$Arguments}
  foreach($line in @("%r$id = call {i1,i64} @ube.proc.$($symbols[$Name])($args)","%s$id = extractvalue {i1,i64} %r$id,0","%v$id = extractvalue {i1,i64} %r$id,1","%e$id = icmp eq i64 %v$id,$Expected","%g$id = and i1 %s$id,%e$id","br i1 %g$id,label %next$id,label %bad$id",("bad"+$id+':'),"ret i32 $id",("next"+$id+':'))){$script:code.Add($line)}
 }
 # Selects a single native failure by call ordinal, then permits retries to reach the real OS.
 function Fault([string]$Name,[long]$After=1){$code.Add("store i64 $($nativeIds[$Name]),ptr @test.native.kind");$code.Add("store i64 $After,ptr @test.native.after")}
 function ClearFault(){$code.Add('store i64 0,ptr @test.native.kind')}
 function CleanOwners(){
  $script:step++;$id=$script:step
  foreach($line in @("%handles$id = load i64,ptr @test.native.live","%attrs$id = load i64,ptr @test.attributes.live","%hc$id = icmp eq i64 %handles$id,0","%ac$id = icmp eq i64 %attrs$id,0","%cc$id = and i1 %hc$id,%ac$id","br i1 %cc$id,label %next$id,label %bad$id",("bad"+$id+':'),"ret i32 $id",("next"+$id+':'))){$code.Add($line)}
 }
 $log=Join-Path $artifacts ($level+'.log')
 $globals='@test.context = private global %ube.context zeroinitializer, align 8'+$nl
 $globals+=Descriptor 'app' $child;$globals+=Descriptor 'command' $childCommand
 $globals+=Descriptor 'directory' $artifacts;$globals+=Descriptor 'log' $log
 $globals+=Descriptor 'spin' $spin;$globals+=Descriptor 'spincommand' ('"'+$spin+'"')
 $globals+=Descriptor 'tree' $tree;$globals+=Descriptor 'treecommand' ('"'+$tree+'"')
 $globals+=Descriptor 'empty' '';$globals+=Descriptor 'missing' (Join-Path $artifacts 'missing.exe')
 $globals+=Descriptor 'nul' ([string][char]0)
 $globals+=Descriptor 'longpath' ('a'*4097)
 $globals+=Descriptor 'longcommand' ('a'*32767)
 foreach($line in @('define i32 @main() {','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)')){$code.Add($line)}
 Check 'PrepareLog' 'ptr @log' 0
 Check 'StartAttempt' 'ptr @empty,ptr @command,ptr @directory' 1
 Check 'Field' 'i64 0' 0
 foreach($invalid in @('nul','longpath')){Check 'StartAttempt' "ptr @$invalid,ptr @command,ptr @directory" 1;Check 'Field' 'i64 0' 0}
 Check 'StartAttempt' 'ptr @app,ptr @longcommand,ptr @directory' 1
 Check 'Field' 'i64 0' 0
 $code.Add('store i64 0,ptr @test.alloc.calls');$code.Add('store i64 1,ptr @test.fail.after');$code.Add('store i64 2,ptr @test.fail.remaining')
 Check 'StartAttempt' 'ptr @app,ptr @command,ptr @directory' 3
 Check 'Field' 'i64 0' 0
 Check 'StartAttempt' 'ptr @app,ptr @command,ptr @directory' 0
 Check 'CheckKinds' '' 0
 Check 'CheckAliases' '' 0
 Check 'WaitOnce' 'i64 5001' 1
 Check 'Field' 'i64 1' 77
 Check 'Field' 'i64 2' 88
 Check 'WaitComplete' '' 0
 Check 'Field' 'i64 1' 1
 Check 'Field' 'i64 2' 42
 Check 'Field' 'i64 4' 71
 Check 'CloseOnce' '' 0
 Check 'Field' 'i64 0' 0
 Check 'StartAttempt' 'ptr @spin,ptr @spincommand,ptr @directory' 0
 Check 'WaitOnce' 'i64 0' 0
 Check 'Field' 'i64 1' 0
 Check 'Field' 'i64 2' 88
 Check 'CloseOnce' '' 12
 Check 'CleanupChild' '' 0
 Check 'StartAttempt' 'ptr @missing,ptr @command,ptr @directory' 5
 Check 'CleanupChild' '' 0
 CleanOwners
 foreach($target in @('job','limit','nullinput','duplicate','attributes','handles','create','assign','resume')){
  Fault $target
  Check 'StartAttempt' 'ptr @app,ptr @command,ptr @directory' 5
  ClearFault
  Check 'CleanupChild' '' 0
  CleanOwners
 }
 Fault 'attributes' 2
 Check 'StartAttempt' 'ptr @app,ptr @command,ptr @directory' 5
 ClearFault;Check 'CleanupChild' '' 0;CleanOwners
 foreach($target in @('wait','exit','accounting')){
  Check 'StartAttempt' 'ptr @app,ptr @command,ptr @directory' 0
  Fault $target
  Check 'WaitOnce' 'i64 5000' 5
  Check 'Field' 'i64 1' 77
  Check 'Field' 'i64 2' 88
  ClearFault;Check 'WaitComplete' '' 0;Check 'CleanupChild' '' 0;CleanOwners
 }
 for($close=1;$close -le 5;$close++){
  Check 'StartAttempt' 'ptr @app,ptr @command,ptr @directory' 0
  Check 'WaitComplete' '' 0
  Fault 'close' $close
  Check 'CloseOnce' '' 7
  ClearFault;Check 'CloseOnce' '' 0;CleanOwners
 }
 Check 'StartAttempt' 'ptr @spin,ptr @spincommand,ptr @directory' 0
 Fault 'terminatejob';Check 'StopOnce' '' 5
 ClearFault;Check 'CleanupChild' '' 0;CleanOwners
 Fault 'assign';Check 'StartAttempt' 'ptr @spin,ptr @spincommand,ptr @directory' 5
 Fault 'terminate';Check 'StopOnce' '' 5
 ClearFault;Check 'CleanupChild' '' 0;CleanOwners
 Check 'StartAttempt' 'ptr @tree,ptr @treecommand,ptr @directory' 0
 Check 'WaitOnce' 'i64 5000' 0
 Check 'Field' 'i64 1' 0
 Check 'Field' 'i64 2' 88
 Check 'CloseOnce' '' 12
 Check 'CleanupChild' '' 0
 CleanOwners
 Check 'CloseLog' '' 0
 foreach($line in @('%disposed = call i1 @ube.context.dispose(ptr @test.context)','%live = load i64,ptr @test.live','%clean = icmp eq i64 %live,0','%complete = and i1 %disposed,%clean','%exit = select i1 %complete,i32 0,i32 98','ret i32 %exit','}')){$code.Add($line)}
 $observed=Join-Path $artifacts ($level+'.ll');Write-Text $observed ($production+$nl+$allocator+$nl+$observer+$nl+$globals+($code -join $nl))
 $exe=Join-Path $artifacts ($level+'.exe');Build-Harness $observed $exe $level
 $run=Invoke-BoundedProcess $exe @();Require ($run.ExitCode -eq 0) "$level assertion $($run.ExitCode) failed; evidence $($run.Evidence)"
 $logText=[IO.File]::ReadAllText($log)
 Require ($logText -ceq ('out!err!'*9)) "$level private stdout/stderr log mismatch"
 Write-Output "$level process assertions $step passed; private NUL input and combined log exact"
}
Write-Output "Process evidence: $artifacts"

