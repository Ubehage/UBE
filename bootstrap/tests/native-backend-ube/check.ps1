# Qualifies ordinary UBE native backend policy, executable-relative assets and exact message streams.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube native backend ' + [guid]::NewGuid())
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

$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'));$nl="`r`n"
$portable=@('BufferPrimitives','FilePrimitives','FileBytes','ByteText','Utf8','SystemPrimitives','StandardStreams','PathPrimitives','DirectoryPrimitives','ProcessPrimitives')
$windows=@('WindowsArguments','WindowsPaths','WindowsImages')
$compiler=@('SourceScanner','SyntaxTokens','SourceParser','ProjectSyntax','ProjectManifest','ProjectLoader','OutputPublication','NativeToolArguments','NativeBackend','CompilerAssets','CompilerMessages')
$files=@($portable|ForEach-Object{'std-lib/src/portable/'+$_+'.bas'})+@($windows|ForEach-Object{'std-lib/src/win-lib/'+$_+'.bas'})+@($compiler|ForEach-Object{'compiler/src/'+$_+'.bas'})+@('bootstrap/tests/native-backend-ube/Probe.bas')
$lines=@('UBE-Project 1','Name = "Backend"','Kind = "Library"')
foreach($file in $files){$leaf=[IO.Path]::GetFileName($file);Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $artifacts $leaf);$lines+='Source = "'+$leaf+'"'}
$manifest=Join-Path $artifacts 'project.UBE';Write-Text $manifest (($lines -join $nl)+$nl)
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest);Require ($bound.ExitCode -eq 0) "Binding failed $($bound.Evidence)"
$symbols=@{};foreach($line in ($bound.Stdout -split '\r?\n')){if($line -match '^SYMBOL (\d+)\|function\|([^|]+)\|'){$symbols[$Matches[2]]=$Matches[1]}}
$ir=Join-Path $artifacts 'backend.ll';$emission=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$manifest,$ir);Require ($emission.ExitCode -eq 0) "Emission failed $($emission.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
$production=$production.Replace('define i64 @ube.target.system.clock()','define i64 @test.real.clock()')
$production=$production.Replace('define i1 @ube.target.process.close(ptr %handle)','define i1 @test.real.close(ptr %handle)')
$production+=@'

@test.clock.step = global i64 0
@test.clock.value = global i64 0
@test.close.remaining = global i64 0
define i1 @ube.target.process.close(ptr %handle) {
entry:
 %left = load i64,ptr @test.close.remaining
 %deny = icmp ugt i64 %left,0
 br i1 %deny,label %fail,label %real
fail:
 %less = sub i64 %left,1
 store i64 %less,ptr @test.close.remaining
 ret i1 false
real:
 %result = call i1 @test.real.close(ptr %handle)
 ret i1 %result
}
define i64 @ube.target.system.clock() {
entry:
 %step = load i64,ptr @test.clock.step
 %fake = icmp ne i64 %step,0
 br i1 %fake,label %injected,label %real
injected:
 %old = load i64,ptr @test.clock.value
 %next = add i64 %old,%step
 store i64 %next,ptr @test.clock.value
 ret i64 %old
real:
 %actual = call i64 @test.real.clock()
 ret i64 %actual
}
'@

# Creates independent counted input storage for emitted UBE function calls.
function Descriptor([string]$Name,[string]$Value){$bytes=$utf8.GetBytes($Value);$cells=($bytes|ForEach-Object{'i64 '+$_}) -join ',';return "@$Name.data = global [$($bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($bytes.Length-1),ptr @$Name.data,ptr null}"+$nl}
$bin=Join-Path $artifacts 'bin';$assets=Join-Path $bin 'llvm';$null=New-Item -ItemType Directory -Path $assets -Force
Write-Text (Join-Path $assets 'templates.bin') 'ABC';Write-Text (Join-Path $assets 'windows-runtime.ll') 'DE';Write-Text (Join-Path $assets 'kernel32.def') 'F'
$definition=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/kernel32.def'),$utf8)
# Builds independently authored native tools; their only behavior is an exact output or exit code.
function Tool([string]$Path,[string]$Body){$inputPath=$Path+'.ll';Write-Text $inputPath $Body;Build-Harness $inputPath $Path 'O0'}
$zero=Join-Path $artifacts 'zero.exe';Tool $zero 'define i32 @main() { ret i32 0 }'
$bad=Join-Path $artifacts 'bad.exe';Tool $bad 'define i32 @main() { ret i32 29 }'
$spin=Join-Path $artifacts 'spin.exe';Tool $spin 'define i32 @main() { entry: br label %loop
loop: br label %loop }'
$flood=Join-Path $artifacts 'flood.exe'
$floodIR=@'
declare dllimport ptr @GetStdHandle(i32)
declare dllimport i32 @WriteFile(ptr,ptr,i32,ptr,ptr)
declare dllimport ptr @CreateFileW(ptr,i32,i32,ptr,i32,i32,ptr)
@bytes = global [65537 x i8] zeroinitializer
define i32 @main() {
entry:
 %count = alloca i32
 %out = call ptr @GetStdHandle(i32 -11)
 %status = call i32 @WriteFile(ptr %out,ptr @bytes,i32 65537,ptr %count,ptr null)
 ret i32 0
}
'@
Tool $flood $floodIR
# Produces a fake tool that creates one exact artifact in its supplied working directory.
function WriterTool([string]$Path,[string]$Leaf,[byte[]]$Bytes){
 $wide=@($Leaf.ToCharArray()|ForEach-Object{'i16 '+[int]$_});$wide+='i16 0';$data=@($Bytes|ForEach-Object{'i8 '+$_})
 $body=@'
declare dllimport ptr @CreateFileW(ptr,i32,i32,ptr,i32,i32,ptr)
declare dllimport i32 @WriteFile(ptr,ptr,i32,ptr,ptr)
declare dllimport i32 @CloseHandle(ptr)
define i32 @main() {
entry:
 %count = alloca i32
 %file = call ptr @CreateFileW(ptr @name,i32 1073741824,i32 0,ptr null,i32 1,i32 128,ptr null)
 %status = call i32 @WriteFile(ptr %file,ptr @data,i32 SIZE,ptr %count,ptr null)
 %closed = call i32 @CloseHandle(ptr %file)
 ret i32 0
}
'@
 $body=$body.Replace('SIZE',[string]$Bytes.Length)+$nl+"@name = private constant [$($wide.Count) x i16] ["+($wide -join ',')+']'+$nl+"@data = private constant [$($Bytes.Length) x i8] ["+($data -join ',')+']'+$nl
 Tool $Path $body
}
$fakeTools=@{}
foreach($name in @('badarchive','nooutput','badimage')){
 $dir=Join-Path $artifacts $name;$null=New-Item -ItemType Directory -Path $dir
 $import=Join-Path $dir 'llvm-dlltool.exe';$fakeClang=Join-Path $dir 'clang.exe';$fakeTools[$name]=$fakeClang
 if($name -eq 'badarchive'){WriterTool $import 'kernel32-memory.lib' ($utf8.GetBytes('invalid!'))}else{WriterTool $import 'kernel32-memory.lib' ($utf8.GetBytes("!<arch>`n"))}
 if($name -eq 'badimage'){WriterTool $fakeClang 'output.exe' ([byte[]]@(77,90,0,0))}else{Copy-Item -LiteralPath $zero -Destination $fakeClang}
}
foreach($level in @('O0','O2')){
 $stage=Join-Path $artifacts ($level+' stage');$null=New-Item -ItemType Directory -Path $stage
 Write-Text (Join-Path $stage 'input.ll') 'define i32 @main() { ret i32 42 }'
 $globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
 $globals+=Descriptor 'clang' $Clang;$globals+=Descriptor 'stage' $stage;$globals+=Descriptor 'definition' $definition;$globals+=Descriptor 'path' 'src/example.bas'
 $code=New-Object Collections.Generic.List[string];$script:case=0
 # Asserts fresh runtime status and the probe's exact result before proceeding.
 function Check([string]$Name,[string]$Arguments){
  $script:case++;$id=$script:case;$args='ptr @test.context';if($Arguments){$args+=','+$Arguments}
  foreach($line in @("%r$id = call {i1,i64} @ube.proc.$($symbols[$Name])($args)","%s$id = extractvalue {i1,i64} %r$id,0","%v$id = extractvalue {i1,i64} %r$id,1","%e$id = icmp eq i64 %v$id,0","%g$id = and i1 %s$id,%e$id","br i1 %g$id,label %next$id,label %bad$id",("bad"+$id+':'),"%exit$id = trunc i64 %v$id to i32","%failed$id = select i1 %e$id,i32 99,i32 %exit$id","ret i32 %failed$id",("next"+$id+':'))){$code.Add($line)}
 }
 foreach($line in @('define i32 @main() {','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)')){$code.Add($line)}
 Check 'BuildCase' 'ptr @clang,ptr @stage,ptr @definition,i64 0'
 foreach($entry in @(@('zero',$zero,0),@('bad',$bad,102),@('flood',$flood,101),@('timeout',$spin,100))){
  $name=$entry[0];$globals+=Descriptor ($name+'.app') $entry[1];$globals+=Descriptor ($name+'.command') ('"'+$entry[1]+'"');$globals+=Descriptor ($name+'.log') (Join-Path $stage ($name+'.log'))
  if($name -eq 'timeout'){$code.Add('store i64 30000,ptr @test.clock.step');$code.Add('store i64 0,ptr @test.clock.value')}
  Check 'RunCase' "ptr @$name.app,ptr @$name.command,ptr @stage,ptr @$name.log,i64 $($entry[2])"
  $code.Add('store i64 0,ptr @test.clock.step')
 }
 foreach($entry in @(@('badarchive',103),@('nooutput',3),@('badimage',16))){
  $name=$entry[0];$private=Join-Path $artifacts ($level+' '+$name);$null=New-Item -ItemType Directory -Path $private
  Write-Text (Join-Path $private 'input.ll') 'define i32 @main() { ret i32 42 }'
  $globals+=Descriptor ($name+'.clang') $fakeTools[$name];$globals+=Descriptor ($name+'.stage') $private
  Check 'BuildCase' "ptr @$name.clang,ptr @$name.stage,ptr @definition,i64 $($entry[1])"
 }
 Check 'AssetsCase' 'i64 0'
 $globals+=Descriptor 'retained.log' (Join-Path $stage 'retained.log')
 $code.Add('store i64 30000,ptr @test.clock.step');$code.Add('store i64 0,ptr @test.clock.value');$code.Add('store i64 10,ptr @test.close.remaining')
 Check 'RetainedCase' 'ptr @timeout.app,ptr @timeout.command,ptr @stage,ptr @retained.log'
 $code.Add('store i64 0,ptr @test.clock.step');$code.Add('store i64 0,ptr @test.close.remaining')
 Check 'RecoverCase' ''
 Check 'MessagesCase' 'ptr @path'
 foreach($line in @('%disposed = call i1 @ube.context.dispose(ptr @test.context)','%exit = select i1 %disposed,i32 0,i32 99','ret i32 %exit','}')){$code.Add($line)}
 $observed=Join-Path $artifacts ($level+'.ll');Write-Text $observed ($production+$nl+$globals+($code -join $nl));$exe=Join-Path $bin ($level+'.exe');Build-Harness $observed $exe $level
 $run=Invoke-BoundedProcess $exe @();Require ($run.ExitCode -eq 0) "$level backend probe failed $($run.ExitCode); $($run.Evidence)"
 Require ($run.Stdout -ceq "EMIT OK`r`nBUILD OK`r`n") "$level success stream mismatch"
 Require ($run.Stderr -ceq "UBE: E_COMPILE: source compilation failed (operation/code/reason 2/3/-4) src/example.bas:12:7`r`n") "$level diagnostic stream mismatch"
 $native=Invoke-BoundedProcess (Join-Path $stage 'output.exe') @();Require ($native.ExitCode -eq 42) "$level private built executable did not exit42"
 $missingBin=Join-Path $artifacts ($level+' missing assets');$null=New-Item -ItemType Directory -Path $missingBin
 $missingIR=Join-Path $missingBin 'missing.ll';$missingExe=Join-Path $missingBin 'missing.exe'
 $missingCode=@"
@missing.context = private global %ube.context zeroinitializer,align 8
define i32 @main() {
entry:
 call void @ube.context.init(ptr @missing.context)
 %init = call i1 @ube.project.init(ptr @missing.context)
 %result = call {i1,i64} @ube.proc.$($symbols['AssetsCase'])(ptr @missing.context,i64 1)
 %fresh = extractvalue {i1,i64} %result,0
 %value = extractvalue {i1,i64} %result,1
 %disposed = call i1 @ube.context.dispose(ptr @missing.context)
 %exit = trunc i64 %value to i32
 %good = and i1 %disposed,%fresh
 %final = select i1 %good,i32 %exit,i32 99
 ret i32 %final
}
"@
 Write-Text $missingIR ($production+$nl+$missingCode);Build-Harness $missingIR $missingExe $level
 $missingAssets=Join-Path $missingBin 'llvm';$null=New-Item -ItemType Directory -Path $missingAssets
 foreach($asset in @('templates.bin','windows-runtime.ll','kernel32.def')){
  $failedAsset=Invoke-BoundedProcess $missingExe @();Require ($failedAsset.ExitCode -eq 0) "$level missing $asset failure/ownership mismatch"
  Write-Text (Join-Path $missingAssets $asset) 'present'
 }
 Write-Output "$level $case backend/policy/message probes, 3 missing assets, unknown-CWD assets and actual built exit42 passed"
}
Write-Output "Backend evidence: $artifacts"

