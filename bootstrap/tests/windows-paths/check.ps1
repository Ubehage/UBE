# Executes bounded Windows path policy with exact bytes, OS oracles and allocation failures.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube windows paths ' + [guid]::NewGuid())
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
$files=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/PathPrimitives.bas','std-lib/src/portable/Utf8.bas','std-lib/src/win-lib/WindowsPaths.bas','bootstrap/tests/windows-paths/Probe.bas')
$lines=@('UBE-Project 1','Name = "Paths"','Kind = "Library"')
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
$ir=Join-Path $artifacts 'paths.ll'
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

# Uses Windows normalization and ordinal comparison directly, without a culture-sensitive approximation.
Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class WindowsPathOracle {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern uint GetFullPathNameW(string path, uint capacity, StringBuilder buffer, IntPtr part);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern int CompareStringOrdinal(string first, int firstLength, string second, int secondLength, bool ignoreCase);
    public static string Full(string path) {
        StringBuilder buffer = new StringBuilder(32768);
        uint length = GetFullPathNameW(path,32768,buffer,IntPtr.Zero);
        if(length==0 || length>=32768) throw new InvalidOperationException("Full-path oracle failed");
        return buffer.ToString();
    }
    public static bool Same(string first,string second) {
        int result = CompareStringOrdinal(first,first.Length,second,second.Length,true);
        if(result==0) throw new InvalidOperationException("Ordinal oracle failed");
        return result==2;
    }
}
'@
$vectors=New-Object Collections.Generic.List[object]
foreach($item in @(
    @('C:\Root\file.bas','C:\Root\file.bas'),@('\\?\C:\Root\file.bas','C:\Root\file.bas'),
    @('\\?\UNC\server\share\dir\file.bas','\\server\share\dir\file.bas'),@('\\server\share\','\\server\share'),
    @('C:/Root/file.bas','C:\Root\file.bas'),@('C:\Root\','C:\Root'),@('C:\','C:\')
)){$vectors.Add(@{Op=1;First=$item[0];Expected=$item[1]})}
foreach($item in @(@('C:\Root\file.bas','C:\Root'),@('C:\file.bas','C:\'),@('C:\','C:\'),@('\\server\share\file.bas','\\server\share'),@('\\server\share','\\server\share'),@('\\?\UNC\server\share\dir\file.bas','\\server\share\dir'))){$vectors.Add(@{Op=2;First=$item[0];Expected=$item[1]})}
foreach($relative in @('file.bas','src/file.bas','src/../file.bas','./file.bas','.bas','a//b.bas',('src/'+[char]0x00E6+[char]0x4E2D+'.bas'))){$vectors.Add(@{Op=3;First='C:\Root';Second=$relative;Expected=[WindowsPathOracle]::Full('C:\Root\'+$relative)})}
foreach($item in @(@('C:\Root','C:\Root\file.bas',$true),@('C:\Root','c:\ROOT\dir\file.bas',$true),@('C:\Root','C:\RootSibling\file.bas',$false),@('C:\Root','C:\Root',$false),@('C:\','C:\file.bas',$true),@('\\server\share','\\SERVER\SHARE\file.bas',$true),@('\\server\share','\\server\share2\file.bas',$false))){$vectors.Add(@{Op=4;First=$item[0];Second=$item[1];Expected='OK';Value=$item[2]})}
foreach($item in @(@('C:\Root','c:\ROOT'),@('C:\Root','C:\RootSibling'),@('\\?\C:\Root','c:\ROOT'),@('\\?\UNC\server\share','\\SERVER\SHARE'))){$left=$item[0].Replace('\\?\UNC\','\\').Replace('\\?\','');$vectors.Add(@{Op=5;First=$item[0];Second=$item[1];Expected='OK';Value=[WindowsPathOracle]::Same($left,$item[1])})}
foreach($pair in @(@([char]0x00E6,[char]0x00C6),@([char]0x017F,'S'),@([char]0x0131,'I'),@([char]0x212A,'K'))){
    $first='C:\'+$pair[0];$second='c:\'+$pair[1]
    $equal=[WindowsPathOracle]::Same($first,$second)
    $vectors.Add(@{Op=5;First=$first;Second=$second;Expected='OK';Value=$equal})
    $vectors.Add(@{Op=4;First=$first;Second=($second+'\file.bas');Expected='OK';Value=$equal})
}
foreach($invalid in @('','relative','C:relative','\rooted','\\.\pipe\name','\\?\GLOBALROOT\Device\name','\\server','\\server\','C:\Root\..\outside','C:\Root\.\file','C:\a:b','C:\a?b','C:\a|b')){$vectors.Add(@{Op=1;First=$invalid;Expected='OK';Failure=1})}
foreach($invalid in @('','..\outside.bas','a\..\..\outside.bas','\rooted.bas','/rooted.bas','C:\absolute.bas','file:stream.bas','a?b.bas','a*b.bas','a"b.bas','a<b.bas','a>b.bas','a|b.bas',"a`tb.bas")){$vectors.Add(@{Op=3;First='C:\Root';Second=$invalid;Expected='OK';Failure=1})}
$vectors.Add(@{Op=1;FirstBytes=[byte[]]@(67,58,92,195,40);Expected='OK';Failure=1})
$vectors.Add(@{Op=1;FirstBytes=[byte[]]@(67,58,92,0);Expected='OK';Failure=1})
$vectors.Add(@{Op=1;First=('C:\'+('a'*4094));Expected='OK';Failure=1})
$vectors.Add(@{Op=1;First='\\?\C:\Root\file.bas';Expected='C:\Root\file.bas';Alias=1})
$vectors.Add(@{Op=2;First='C:\Root\file.bas';Expected='C:\Root';Alias=1})
$vectors.Add(@{Op=3;First='C:\Root';Second='src/../file.bas';Expected='C:\Root\file.bas';Alias=1})
$vectors.Add(@{Op=3;First='C:\Root';Second='src/../file.bas';Expected='C:\Root\file.bas';Alias=2})
$vectors.Add(@{Op=1;First='C:\Root\..\outside';Expected='C:\Root\..\outside';Failure=1;Alias=1})
$vectors.Add(@{Op=3;First='C:\Root';Second='..\outside.bas';Expected='C:\Root';Failure=1;Alias=1})
$vectors.Add(@{Op=3;First='C:\Root';Second='..\outside.bas';Expected='..\outside.bas';Failure=1;Alias=2})
$vectors.Add(@{Op=4;First='C:\Root';Second='C:\Root\..\outside';Expected='OK';Failure=1})
$vectors.Add(@{Op=5;First='C:\Root';Second='relative';Expected='OK';Failure=1})
$globals='@test.context = private global %ube.context zeroinitializer, align 8'+$nl
$code=New-Object Collections.Generic.List[string]
foreach($line in @('define i32 @main() {','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)')){$code.Add($line)}
for($i=0;$i -lt $vectors.Count;$i++){
    $vector=$vectors[$i];$second='';$value=0;$failure=0;$alias=0
    if($vector.ContainsKey('Second')){$second=$vector.Second}
    if($vector.ContainsKey('Value') -and $vector.Value){$value=-1}
    if($vector.ContainsKey('Failure')){$failure=$vector.Failure}
    if($vector.ContainsKey('Alias')){$alias=$vector.Alias}
    if($vector.ContainsKey('FirstBytes')){$firstBytes=$vector.FirstBytes}else{$firstBytes=$utf8.GetBytes($vector.First)}
    $globals+=Descriptor "first$i" $firstBytes
    $globals+=Descriptor "second$i" ($utf8.GetBytes($second))
    $globals+=Descriptor "expected$i" ($utf8.GetBytes($vector.Expected))
    foreach($line in @("%case$i = call {i1,i64} @ube.proc.$($symbols['Check'])(ptr @test.context,i64 $($vector.Op),ptr @first$i,ptr @second$i,ptr @expected$i,i64 $value,i64 $failure,i64 $alias)","%fresh$i = extractvalue {i1,i64} %case$i,0","%value$i = extractvalue {i1,i64} %case$i,1","%zero$i = icmp eq i64 %value$i,0","%good$i = and i1 %fresh$i,%zero$i","br i1 %good$i,label %next$i,label %bad$i",("bad"+$i+':'),"%dispose$i = call i1 @ube.context.dispose(ptr @test.context)",('ret i32 '+($i+100)),("next"+$i+':'))){$code.Add($line)}
}
$baselines=@(@(1,'\\?\C:\Root\dir\','','C:\Root\dir',0),@(2,'C:\Root\file.bas','','C:\Root',0),@(3,'C:\Root','folder\..\file.bas','C:\Root\file.bas',0),@(4,'C:\Root','c:\root\file.bas','OK',-1),@(5,'C:\Root','c:\ROOT','OK',-1))
foreach($baseline in $baselines){
    $op=$baseline[0]
    $globals+=Descriptor "base.first$op" ($utf8.GetBytes($baseline[1]))
    $globals+=Descriptor "base.second$op" ($utf8.GetBytes($baseline[2]))
    $globals+=Descriptor "base.expected$op" ($utf8.GetBytes($baseline[3]))
    foreach($line in @('store i64 0,ptr @test.alloc.calls',"%baseline$op = call {i1,i64} @ube.proc.$($symbols['Check'])(ptr @test.context,i64 $op,ptr @base.first$op,ptr @base.second$op,ptr @base.expected$op,i64 $($baseline[4]),i64 0,i64 0)","%baseline.value$op = extractvalue {i1,i64} %baseline$op,1","%baseline.zero$op = icmp eq i64 %baseline.value$op,0","%observed$op = load i64,ptr @test.alloc.calls","%present$op = icmp ugt i64 %observed$op,0","%bounded$op = icmp ule i64 %observed$op,128","%bounds$op = and i1 %present$op,%bounded$op","%measured$op = and i1 %baseline.zero$op,%bounds$op","br i1 %measured$op,label %fault.entry$op,label %failed",("fault.entry"+$op+':'),"br label %fault$op",("fault"+$op+':'),"%site$op = phi i64 [1,%fault.entry$op],[%next.site$op,%advance$op]",'store i64 0,ptr @test.alloc.calls','store i64 2,ptr @test.fail.remaining',"store i64 %site$op,ptr @test.fail.after","%fault.result$op = call {i1,i64} @ube.proc.$($symbols['CheckAllocation'])(ptr @test.context,i64 $op,ptr @base.first$op,ptr @base.second$op)","%fault.value$op = extractvalue {i1,i64} %fault.result$op,1","%fault.zero$op = icmp eq i64 %fault.value$op,0","%calls$op = load i64,ptr @test.alloc.calls","%attempts$op = add i64 %site$op,1","%retry.failed$op = icmp eq i64 %calls$op,%attempts$op","%qualified$op = and i1 %fault.zero$op,%retry.failed$op","br i1 %qualified$op,label %recovery$op,label %failed",("recovery"+$op+':'),"%again$op = call {i1,i64} @ube.proc.$($symbols['Check'])(ptr @test.context,i64 $op,ptr @base.first$op,ptr @base.second$op,ptr @base.expected$op,i64 $($baseline[4]),i64 0,i64 0)","%again.value$op = extractvalue {i1,i64} %again$op,1","%again.good$op = icmp eq i64 %again.value$op,0","%next.site$op = add i64 %site$op,1","%more$op = icmp ule i64 %next.site$op,%observed$op","br i1 %again.good$op,label %advance$op,label %failed",("advance"+$op+':'),"br i1 %more$op,label %fault$op,label %done$op",("done"+$op+':'))){$code.Add($line)}
}
foreach($line in @('%disposed = call i1 @ube.context.dispose(ptr @test.context)','%live = load i64,ptr @test.live','%clean = icmp eq i64 %live,0','%complete = and i1 %disposed,%clean','%exit = select i1 %complete,i32 0,i32 98','ret i32 %exit','failed:','%cleanup = call i1 @ube.context.dispose(ptr @test.context)','ret i32 99','}')){$code.Add($line)}
$combined=$production+$nl+$allocator+$nl+$globals+($code -join $nl)
$path=Join-Path $artifacts 'observed.ll';Write-Text $path $combined
foreach($level in @('O0','O2')){
    $exe=Join-Path $artifacts "paths-$level.exe";Build-Harness $path $exe $level
    $run=Invoke-BoundedProcess $exe @()
    Require ($run.ExitCode -eq 0) "Path assertions failed $level code=$($run.ExitCode) $($run.Evidence)"
    Write-Output "PASS $level : $($vectors.Count) path vectors, each measured helper allocation/retry, recovery and zero live blocks"
}
$original=Descriptor 'first0' ($utf8.GetBytes($vectors[0].First))
$changed=Descriptor 'first0' ($utf8.GetBytes($vectors[0].First.Replace('Root','Boot')))
Require ($combined.Contains($original)) 'Missing path input control'
$negative=Join-Path $artifacts 'negative.ll';Write-Text $negative ($combined.Replace($original,$changed))
$exe=Join-Path $artifacts 'negative.exe';Build-Harness $negative $exe 'O2'
$run=Invoke-BoundedProcess $exe @()
Require ($run.ExitCode -eq 100) 'Changed path must fail the unchanged byte expectation'
Write-Output "PASS changed-path negative control. Evidence: $artifacts"

