# Executes portable integer formatting and counted file-range policy with independent observations.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube byte text ' + [guid]::NewGuid())
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


$nl=[Environment]::NewLine
Write-Output "Artifacts retained: $artifacts"
$core=Join-Path $PSScriptRoot '../../../std-lib/src/portable'
$lines=@('UBE-Project 1','Name = "TextOutput"','Kind = "Library"')
foreach($name in @('BufferPrimitives','FilePrimitives','FileBytes','ByteText','ByteTextProbe')){
 $source=Join-Path $core "$name.bas"
 if($name -eq 'ByteTextProbe'){$source=Join-Path $PSScriptRoot "$name.bas"}
 Copy-Item -LiteralPath $source -Destination (Join-Path $artifacts "$name.bas")
 $lines+='Source = "'+$name+'.bas"'
}
$manifest=Join-Path $artifacts 'project.UBE'
Write-Text $manifest (($lines -join $nl)+$nl)
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Binding failed $($bound.Evidence)"
$symbols=@{}
foreach($line in ($bound.Stdout -split '\r?\n')){
 if($line -match '^SYMBOL (\d+)\|function\|([^|]+)\|'){$symbols[$Matches[2]]=$Matches[1]}
}
$ir=Join-Path $artifacts 'text.ll'
$result=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$manifest,$ir)
Require ($result.ExitCode -eq 0) "Emission failed $($result.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
# Creates independently specified counted byte storage for the observation ABI.
function Descriptor([string]$Name,[byte[]]$Bytes){
 $cells=($Bytes|ForEach-Object{'i64 '+$_}) -join ', '
 return "@$Name.data = global [$($Bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Bytes.Length-1),ptr @$Name.data,ptr null}"+$nl
}
$values=@('0','1','-1','9','10','99','100','-10','-100','255','32767','-32768','2147483647','-2147483648','9223372036854775807','-9223372036854775808')
$globals='@test.context = private global %ube.context zeroinitializer, align 8'+$nl
$code=@('define i32 @main() {','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)','br i1 %init,label %case0,label %failed')
for($i=0;$i -lt $values.Count;$i++){
 $globals+=Descriptor "expected$i" ([Text.Encoding]::ASCII.GetBytes($values[$i]))
 $globals+="@input$i = global i64 $($values[$i])"+$nl
 $next='case'+($i+1)
 $code+=@(('case'+$i+':'),"%in$i = load volatile i64,ptr @input$i","%p$i = call {i1,i64} @ube.proc.$($symbols['CheckInteger'])(ptr @test.context,i64 %in$i,ptr @expected$i)","%f$i = extractvalue {i1,i64} %p$i,0","%v$i = extractvalue {i1,i64} %p$i,1","%z$i = icmp eq i64 %v$i,0","%g$i = and i1 %f$i,%z$i","br i1 %g$i,label %$next,label %failed")
}
$code+=@('case16:',"%bounds = call {i1,i64} @ube.proc.$($symbols['CheckBounds'])(ptr @test.context,i64 1)",'%bf = extractvalue {i1,i64} %bounds,0','%bv = extractvalue {i1,i64} %bounds,1','%bz = icmp eq i64 %bv,0','%bg = and i1 %bf,%bz','br i1 %bg,label %done,label %failed','done:','%d = call i1 @ube.context.dispose(ptr @test.context)','%exit = select i1 %d,i32 0,i32 98','ret i32 %exit','failed:','%c = call i1 @ube.context.dispose(ptr @test.context)','ret i32 99','}')
$combined=$production+$nl+$globals+($code -join $nl)
$path=Join-Path $artifacts 'integer.ll'
Write-Text $path $combined
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts "integer-$level.exe"
 Build-Harness $path $exe $level
 $run=Invoke-BoundedProcess $exe @()
 Require ($run.ExitCode -eq 0) "Integer assertions failed $level $($run.Evidence)"
 Write-Output "PASS integer $level :16 exact vectors and6 publication/bounds cases"
}
$path=Join-Path $artifacts 'negative.ll'
Write-Text $path ($combined.Replace('@input0 = global i64 0','@input0 = global i64 1'))
$exe=Join-Path $artifacts 'negative.exe'
Build-Harness $path $exe 'O2'
$run=Invoke-BoundedProcess $exe @()
Require ($run.ExitCode -eq 99) 'Changed runtime input must fail exact oracle'
Write-Output 'PASS negative runtime integer control'
# Reuses the existing target fault injector and exact byte-observation wrappers.
$observer=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/FileObserver.ll'),$utf8)
$flushPattern='(define i1 @ube\.target\.file\.flush\(ptr %handle\) \{\r?\nentry:)'
Require ([regex]::Matches($observer,$flushPattern).Count -eq 1) 'Missing unique flush observation point'
$flushProbe='$1'+$nl+'  %flush.old = load i64,ptr @test.flush.calls'+$nl+'  %flush.next = add i64 %flush.old,1'+$nl+'  store i64 %flush.next,ptr @test.flush.calls'
$observer=[regex]::Replace($observer,$flushPattern,$flushProbe)+$nl+'@test.flush.calls = global i64 0'+$nl
$allocator=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../file-io/fixtures/AllocatorObserver.ll'),$utf8)
foreach($name in @('allocate','release','file.open','file.size','file.read','file.write','file.flush','file.close')){
 $pattern='(?m)^(define[^\r\n@]*?)@ube\.target\.'+[regex]::Escape($name)+'\('
 Require ([regex]::Matches($production,$pattern).Count -eq 1) "Missing $name wrapper"
 $production=[regex]::Replace($production,$pattern,('$'+'{1}@test.real.'+$name+'('))
}
foreach($i in 0..6){
 $output=Join-Path $artifacts "range-$i.bin"
 $writes=@(2,3,1,1,0,0,2)[$i]
 $writeMode=0
 if($i -in @(1,2,3)){$writeMode=@(0,2,3,1)[$i]}
 $flushes=0
 if($i -eq 6){$flushes=1}
 $harness=@('@test.context = private global %ube.context zeroinitializer,align 8',(Descriptor 'path' ($utf8.GetBytes($output))),'define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)',"store i32 $writeMode,ptr @test.write.mode","%pair = call {i1,i64} @ube.proc.$($symbols['CheckRange'])(ptr @test.context,ptr @path,i64 $i)",'%fresh = extractvalue {i1,i64} %pair,0','%value = extractvalue {i1,i64} %pair,1','%zero = icmp eq i64 %value,0','%good = and i1 %fresh,%zero','%calls = load i64,ptr @test.write.calls',"%cg = icmp eq i64 %calls,$writes",'%disposed = call i1 @ube.context.dispose(ptr @test.context)','%live = load i64,ptr @test.live','%clean = icmp eq i64 %live,0','%handles = load i64,ptr @test.handles','%closed = icmp eq i64 %handles,0','%a = and i1 %init,%good','%b = and i1 %cg,%disposed','%c = and i1 %clean,%closed','%d = and i1 %a,%b','%all = and i1 %d,%c','%exit = select i1 %all,i32 0,i32 99','ret i32 %exit','}')
 $harness=@($harness|ForEach-Object{
  if($_ -eq '%all = and i1 %d,%c'){
   '%before.flush = and i1 %d,%c'
   '%flush.calls = load i64,ptr @test.flush.calls'
   "%flush.good = icmp eq i64 %flush.calls,$flushes"
   '%all = and i1 %before.flush,%flush.good'
  }else{$_}
 })
 $path=Join-Path $artifacts "range-$i.ll"
 Write-Text $path ($production+$nl+$allocator+$nl+$observer+$nl+($harness -join $nl))
 foreach($level in @('O0','O2')){
  if(Test-Path -LiteralPath $output){Remove-Item -LiteralPath $output}
  $exe=Join-Path $artifacts "range-$i-$level.exe"
  Build-Harness $path $exe $level
  $run=Invoke-BoundedProcess $exe @()
  Require ($run.ExitCode -eq 0) "Range$i failed $level $($run.Evidence)"
  $bytes=[IO.File]::ReadAllBytes($output)
  Require ($bytes.Length -eq @(65537,17,0,2,0,0,65540)[$i]) "Wrong byte count mode$i"
  Require (@($bytes|Where-Object{$_ -ne 7}).Count -eq 0) "Wrong bytes mode$i"
  Write-Output "PASS range$i $level exact bytes/progress/Err and balanced resources"
 }
}
