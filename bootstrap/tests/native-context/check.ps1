# Verifies UBE-generated context and entry fragments with independent native assertions.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube native context ' + [guid]::NewGuid())
$workingDirectory = Join-Path $artifacts 'unrelated working directory'
$null = New-Item -ItemType Directory -Path $workingDirectory -Force
$script:processNumber = 0
$script:passed = 0

# Quotes one Windows process argument, retaining literal quotes and backslashes.
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

# Runs a hidden child with a retained handle, deadline and persistent evidence.
function Invoke-BoundedProcess([string]$File, [string[]]$Arguments, [int]$TimeoutMilliseconds = 30000) {
    $script:processNumber++
    $prefix = Join-Path $artifacts ('process-' + $script:processNumber)
    $start = @{ FilePath=$File; WorkingDirectory=$workingDirectory; PassThru=$true; WindowStyle='Hidden'; RedirectStandardOutput=($prefix + '.stdout'); RedirectStandardError=($prefix + '.stderr') }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @start
    try {
        $retainedHandle = $process.Handle
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill()
            $null = $process.WaitForExit(5000)
            throw "Process timeout: $File. Evidence: $prefix"
        }
        $process.Refresh()
        if ($null -eq $process.ExitCode) { throw "No exit code for retained handle $retainedHandle" }
        return [pscustomobject]@{ ExitCode=$process.ExitCode; Stdout=[IO.File]::ReadAllText($prefix + '.stdout', $utf8); Stderr=[IO.File]::ReadAllText($prefix + '.stderr', $utf8); Evidence=$prefix }
    } finally { $process.Dispose() }
}

# Writes fixture text as strict UTF-8 independently of the host code page.
function Write-Text([string]$Path, [string]$Text) {
    $null = New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Path)) -Force
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

Write-Output "Artifacts retained: $artifacts"
if (-not $BootstrapExe) {
    $project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../UBE-Bootstrap.vbp'))
    $buildDirectory = Join-Path $artifacts 'build'
    $null = New-Item -ItemType Directory -Path $buildDirectory
    $buildLog = Join-Path $buildDirectory 'vb6-build.log'
    Write-Output "VB6 version: $((Get-Item -LiteralPath $VB6).VersionInfo.FileVersion)"
    $build = Invoke-BoundedProcess $VB6 @('/make', $project, '/out', $buildLog, '/outdir', $buildDirectory)
    if (Test-Path -LiteralPath $buildLog) { Get-Content -LiteralPath $buildLog }
    $BootstrapExe = Join-Path $buildDirectory 'UBE-Bootstrap.exe'
    if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $BootstrapExe)) { throw "VB6 build failed. Evidence: $buildDirectory" }
}
$BootstrapExe = [IO.Path]::GetFullPath($BootstrapExe)
if (-not (Test-Path -LiteralPath $BootstrapExe)) { throw "Bootstrap executable not found: $BootstrapExe" }

# Stops the gate when a native acceptance assertion fails.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Verifies the DOS/PE headers and AMD64 machine field before executing output.
function Assert-X64([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    Require ($bytes.Length -ge 64 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) 'Invalid DOS executable header'
    $offset = [BitConverter]::ToInt32($bytes, 0x3c)
    Require ($offset -ge 64 -and $offset -le $bytes.Length - 6) 'Invalid PE header offset'
    Require ([BitConverter]::ToUInt32($bytes, $offset) -eq 0x4550 -and [BitConverter]::ToUInt16($bytes, $offset + 4) -eq 0x8664) 'Expected x64 PE output'
}

# Requires an emission/build command to publish its stated success marker.
function Invoke-Compiler([string[]]$Arguments, [string]$Marker) {
    $result = Invoke-BoundedProcess $BootstrapExe $Arguments
    Require ($result.ExitCode -eq 0 -and $result.Stderr.Length -eq 0 -and $result.Stdout -match ('(?m)^' + [regex]::Escape($Marker) + '\r?$')) "Compiler failed. Evidence: $($result.Evidence)"
    return $result
}

. (Join-Path $PSScriptRoot '../NativeMemory.ps1')
# Compiles the same generated library+harness IR at a selected optimization level.
function Build-Harness([string]$IR, [string]$Exe, [string]$Level) {
    $linkArguments = @(Get-NativeMemoryLinkArguments $IR $Clang $artifacts)
    $arguments = @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR) + $linkArguments + @('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
    $result = Invoke-BoundedProcess $Clang $arguments
    Require ($result.ExitCode -eq 0) "Native harness build failed. Evidence: $($result.Evidence)"
    Assert-X64 $Exe
}

# Retains original module text while making a manifest for checked-in fixtures.
function Copy-Fixtures([string]$Name, [string[]]$Files, [string]$Level = '2', [string]$Kind = 'Exe') {
    $folder = Join-Path $artifacts $Name
    $lines = @('UBE-Project 1', 'Name = "NativeFixture"', ('Kind = "' + $Kind + '"'), ('Optimization = "' + $Level + '"'))
    if ($Kind -eq 'Exe') { $lines += 'Startup = "Main"' }
    foreach ($file in $Files) {
        $leaf = [IO.Path]::GetFileName($file)
        Write-Text (Join-Path $folder $leaf) ([IO.File]::ReadAllText($file, $utf8))
        $lines += 'Source = "' + $leaf + '"'
    }
    $manifest = Join-Path $folder 'project.UBE'
    Write-Text $manifest (($lines -join "`r`n") + "`r`n")
    return $manifest
}

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
& (Join-Path $root 'bootstrap/tools/runtime-text.ps1')
& (Join-Path $root 'bootstrap/tools/llvm-templates.ps1')
$files = @('BufferPrimitives','FilePrimitives','FileBytes','ByteText','Utf8') | ForEach-Object { Join-Path $root ('std-lib/src/portable/'+$_+'.bas') }
$files += @('SourceScanner','SyntaxTokens','SourceParser','ProjectSyntax','DeclarationBinder','ConstantValues','ExpressionBinder','AggregateLayout','NativeEscapes','NativePlanning','LLVMWriter','LLVMTemplates','LLVMFormat','NativeContext') | ForEach-Object { Join-Path $root ('compiler/src/'+$_+'.bas') }
$files += Join-Path $PSScriptRoot 'Probe.bas'
$manifest=Copy-Fixtures 'emitter' $files '0' 'Library'
$library=Join-Path $artifacts 'emitter.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$library) 'EMIT OK'
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Binding failed: $($bound.Evidence)"
$symbols=@{}
foreach($line in ($bound.Stdout -split '\r?\n')) {
    if($line -notmatch '^SYMBOL ') {continue}
    $f=$line.Substring(7).Split('|')
    if([int]$f[5] -eq ($files.Count - 1) -and $f[1] -in @('function','sub')) {$symbols[$f[2]]=$f[0]}
}
foreach($name in @('ConfigurePath','SetPathByte','Emit')) {Require ($symbols.ContainsKey($name)) "Missing $name"}
$emitted=[IO.File]::ReadAllText($library,$utf8)
$runtime=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'),$utf8)
$catalog=Join-Path $root 'compiler/llvm/templates.bin'

# Executes actual UBE context emission with runtime file input and private stage output.
function Emit-Fragment([string]$Path,[bool]$Entry,[string]$Level) {
    $lines=@('@test.ctx = private global %ube.context zeroinitializer, align 8','define i32 @main() {','entry:','  call void @ube.context.init(ptr @test.ctx)','  %init = call i1 @ube.project.init(ptr @test.ctx)')
    $paths=@($Path,$catalog)
    for($p=0;$p -lt 2;$p++) {
        $bytes=$utf8.GetBytes($paths[$p])
        $lines+='  %configure'+$p+' = call { i1, i64 } @ube.proc.'+$symbols['ConfigurePath']+'(ptr @test.ctx, i64 '+$p+', i64 '+$bytes.Length+')'
        for($i=0;$i -lt $bytes.Length;$i++) {$lines+='  %path'+$p+'_'+$i+' = call { i1, i64 } @ube.proc.'+$symbols['SetPathByte']+'(ptr @test.ctx, i64 '+$p+', i64 '+$i+', i64 '+$bytes[$i]+')'}
    }
    $flag=0;if($Entry){$flag=-1}
    $lines+=@(('  %result = call { i1, i64 } @ube.proc.'+$symbols['Emit']+'(ptr @test.ctx, i64 '+$flag+')'),'  %fresh = extractvalue { i1, i64 } %result, 0','  %value = extractvalue { i1, i64 } %result, 1','  %disposed = call i1 @ube.context.dispose(ptr @test.ctx)','  %ok = and i1 %fresh, %disposed','  %status = trunc i64 %value to i32','  %exit = select i1 %ok, i32 %status, i32 100','  ret i32 %exit','}')
    $ir=$Path+'.driver.ll';$exe=$Path+'.driver.exe'
    Write-Text $ir ($emitted+($lines -join "`r`n")+"`r`n")
    Build-Harness $ir $exe $Level
    $run=Invoke-BoundedProcess $exe @()
    Require ($run.ExitCode -eq 0) "Emission failed assertion $($run.ExitCode): $($run.Evidence)"
    return [IO.File]::ReadAllText($Path,$utf8)
}

$ensure=@'
@trace = private global i64 0
define i1 @ube.module.ensure.0(ptr %ctx) {
entry:
  store i64 1, ptr @trace
  ret i1 true
}
define i1 @ube.module.ensure.1(ptr %ctx) {
entry:
  %previous = load i64, ptr @trace
  %ordered = icmp eq i64 %previous, 1
  %value = select i1 %ordered, i64 12, i64 -1
  store i64 %value, ptr @trace
  ret i1 true
}
'@

# Adds an independently authored assertion with a unique native failure exit.
function Assert-IR([string]$Condition,[int]$Code) {
    return "  br i1 $Condition, label %continue$Code, label %failure$Code`r`nfailure${Code}:`r`n  ret i32 $Code`r`ncontinue${Code}:`r`n"
}
$verify=@'
@ctx.a = private global %ube.context zeroinitializer, align 8
@ctx.b = private global %ube.context zeroinitializer, align 8
define i32 @main() {
entry:
  br label %dirty
dirty:
  %i = phi i64 [ 0, %entry ], [ %next, %dirty ]
  %slot = getelementptr i64, ptr @ctx.a, i64 %i
  store volatile i64 -1, ptr %slot
  %next = add i64 %i, 1
  %more = icmp ult i64 %next, 866
  br i1 %more, label %dirty, label %initialize
initialize:
  call void @ube.context.init(ptr @ctx.a)
  call void @ube.context.init(ptr @ctx.b)
  %size = call i64 @ube.context.size()
  %size.ok = icmp eq i64 %size, 6928
'@ + "`r`n" + (Assert-IR '%size.ok' 1) + @'
  br label %zero.check
zero.check:
  %j = phi i64 [ 0, %continue1 ], [ %jnext, %zero.next ]
  %zptr = getelementptr i64, ptr @ctx.a, i64 %j
  %z = load volatile i64, ptr %zptr
  %zero.value = icmp eq i64 %z, 0
  %program.slot = icmp eq i64 %j, 2
  %zero = or i1 %zero.value, %program.slot
  br i1 %zero, label %zero.next, label %bad.zero
bad.zero:
  ret i32 2
zero.next:
  %jnext = add i64 %j, 1
  %again = icmp ult i64 %jnext, 866
  br i1 %again, label %zero.check, label %project
project:
  %initialized = call i1 @ube.project.init(ptr @ctx.a)
  %trace.value = load i64, ptr @trace
  %ordered = icmp eq i64 %trace.value, 12
'@ + "`r`n" + (Assert-IR '%ordered' 3) + @'
  %a = call ptr @ube.storage.address(ptr @ctx.a, i64 0)
  %other = call ptr @ube.storage.address(ptr @ctx.a, i64 5)
  %b = call ptr @ube.storage.address(ptr @ctx.b, i64 0)
  %scalar = call ptr @ube.storage.address(ptr @ctx.a, i64 4)
  store i64 123, ptr %scalar
  %allocated.a = call i1 @ube.array.tryresize(ptr @ctx.a, ptr %a, i64 2, i64 0, i64 1)
  %allocated.other = call i1 @ube.array.tryresize(ptr @ctx.a, ptr %other, i64 3, i64 0, i64 1)
  %allocated.b = call i1 @ube.array.tryresize(ptr @ctx.b, ptr %b, i64 4, i64 0, i64 1)
  %both = and i1 %allocated.a, %allocated.other
  %all = and i1 %both, %allocated.b
'@ + "`r`n" + (Assert-IR '%all' 4) + @'
  %depth = getelementptr %ube.context, ptr @ctx.a, i32 0, i32 1
  store i64 1, ptr %depth
  %busy.depth = call i1 @ube.context.dispose(ptr @ctx.a)
  %refused.depth = xor i1 %busy.depth, true
'@ + "`r`n" + (Assert-IR '%refused.depth' 5) + @'
  store i64 0, ptr %depth
  %file = call ptr @ube.resource.slot(ptr @ctx.a, i64 0)
  store i64 1, ptr %file
  %busy.file = call i1 @ube.context.dispose(ptr @ctx.a)
  %refused.file = xor i1 %busy.file, true
'@ + "`r`n" + (Assert-IR '%refused.file' 6) + @'
  %head.a = call ptr @ube.memory.head(ptr @ctx.a)
  %live.a = load ptr, ptr %head.a
  %still.owned = icmp ne ptr %live.a, null
'@ + "`r`n" + (Assert-IR '%still.owned' 7) + @'
  store i64 0, ptr %file
  %disposed.a = call i1 @ube.context.dispose(ptr @ctx.a)
'@ + "`r`n" + (Assert-IR '%disposed.a' 8) + @'
  %upper.a = getelementptr i64, ptr %a, i64 1
  %upper.other = getelementptr i64, ptr %other, i64 1
  %ua = load i64, ptr %upper.a
  %uo = load i64, ptr %upper.other
  %empty.a = icmp eq i64 %ua, -1
  %empty.other = icmp eq i64 %uo, -1
  %empties = and i1 %empty.a, %empty.other
'@ + "`r`n" + (Assert-IR '%empties' 9) + @'
  %scalar.value = load i64, ptr %scalar
  %scalar.ok = icmp eq i64 %scalar.value, 123
'@ + "`r`n" + (Assert-IR '%scalar.ok' 10) + @'
  %head.b = call ptr @ube.memory.head(ptr @ctx.b)
  %live.b = load ptr, ptr %head.b
  %isolated = icmp ne ptr %live.b, null
'@ + "`r`n" + (Assert-IR '%isolated' 11) + @'
  %disposed.b = call i1 @ube.context.dispose(ptr @ctx.b)
'@ + "`r`n" + (Assert-IR '%disposed.b' 12) + @'
  %again.a = call i1 @ube.context.dispose(ptr @ctx.a)
'@ + "`r`n" + (Assert-IR '%again.a' 13) + @'
  ret i32 0
}
'@

foreach($level in @('O0','O2')) {
    $fragment=Emit-Fragment (Join-Path $artifacts ('context-'+$level+'.ll')) $false $level
    $entry=Emit-Fragment (Join-Path $artifacts ('entry-'+$level+'.ll')) $true $level
    if ($level -eq 'O0') { $firstFragment=$fragment; $firstEntry=$entry }
    else { Require ($fragment -ceq $firstFragment -and $entry -ceq $firstEntry) 'Optimization changed emitted context text' }
    Require (-not $fragment.Contains('%array.3 =')) 'Non-context array received disposal code'
    foreach($case in @('context','success','failure','busy')) {
        $suffix=$ensure
        if($case -eq 'context') {$text=$fragment+$runtime+$suffix+$verify;$expected=0}
        else {
            $body='  ret { i1, i64 } { i1 true, i64 42 }';$expected=42
            if($case -eq 'failure') {$body='  ret { i1, i64 } { i1 false, i64 999 }';$expected=1}
            if($case -eq 'busy') {$body="  %depth = getelementptr %ube.context, ptr %ctx, i32 0, i32 1`r`n  store i64 1, ptr %depth`r`n  ret { i1, i64 } { i1 true, i64 42 }";$expected=1}
            $text=$entry+$runtime+$suffix+"`r`ndefine { i1, i64 } @ube.proc.17(ptr %ctx) {`r`nentry:`r`n"+$body+"`r`n}`r`n"
        }
        $ir=Join-Path $artifacts ($case+'-'+$level+'.ll');$exe=Join-Path $artifacts ($case+'-'+$level+'.exe')
        Write-Text $ir $text
        Build-Harness $ir $exe $level
        $run=Invoke-BoundedProcess $exe @()
        Require ($run.ExitCode -eq $expected) "$case $level returned $($run.ExitCode), expected $expected; $($run.Evidence)"
        Write-Output "PASS: $case $level"
    }
}
$controlIR=Join-Path $artifacts 'changed-order.ll'
$controlExe=Join-Path $artifacts 'changed-order.exe'
Write-Text $controlIR ($fragment+$runtime+$ensure.Replace('store i64 1, ptr @trace','store i64 2, ptr @trace')+$verify)
Build-Harness $controlIR $controlExe 'O2'
$control=Invoke-BoundedProcess $controlExe @()
Require ($control.ExitCode -eq 3) "Order negative control returned $($control.ExitCode), expected exact assertion 3"
Write-Output 'PASS: eight generated-context/entry executions, four actual UBE emission runs and exact order negative control'
