# Verifies complete LLVM modules emitted by the UBE compiler from runtime source.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe',
    [switch]$Measure,
    [switch]$MeasureOnly,
    [string]$MeasurementManifest = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube concurrent compilation ' + [guid]::NewGuid())
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


$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$package=Join-Path $artifacts 'compiler package'
$null = & (Join-Path $root 'bootstrap/tools/self-host-sources.ps1') -Destination $package -AdditionalSources (Join-Path $PSScriptRoot 'Probe.bas')
$manifest=Join-Path $package 'Compiler.UBE'
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Coordinator binding failed: $($bound.Evidence)"
$modules=@{};$symbols=@{};$parameters=@{};$emitterSymbol=0;$requestSymbol=0;$ordinalSymbol=0;$compilationSymbol=0;$beginSymbol=0;$stateSymbol=0;$backendSymbol=0;$startSymbol=0;$completionSymbol=0;$rangeSymbol=0;$stopSymbol=0;$nodeCountSymbol=0
foreach($line in ($bound.Stdout -split '\r?\n')) {
    if($line.StartsWith('SYMBOL ')) {
        $f=$line.Substring(7).Split('|')
        if($f[1] -eq 'module') {$modules[$f[2]]=$f[5]}
    }
}
foreach($line in ($bound.Stdout -split '\r?\n')) {
    if($line.StartsWith('SYMBOL ')) {
        $f=$line.Substring(7).Split('|')
        if($f[5] -eq $modules['Probe'] -and $f[1] -in @('function','sub')) {$symbols[$f[2]]=$f[0]}
        if($f[5] -eq $modules['NativeCompilation'] -and $f[2] -eq 'EmitRange') {$emitterSymbol=[int]$f[0]}
        if($f[5] -eq $modules['Probe'] -and $f[2] -eq 'RunRequest') {$requestSymbol=[int]$f[0]}
        if($f[1] -eq 'function' -and $f[5] -eq $modules['NativeCompilation'] -and $f[2] -eq 'TryEmit') {$compilationSymbol=[int]$f[0]}
        if($f[1] -eq 'function' -and $f[5] -eq $modules['NativeLowering'] -and $f[2] -eq 'TryBegin') {$beginSymbol=[int]$f[0]}
        if($f[1] -eq 'function' -and $f[5] -eq $modules['NativeBackend'] -and $f[2] -eq 'TryRun') {$backendSymbol=[int]$f[0]}
        if($f[1] -eq 'function' -and $f[5] -eq $modules['ProcessPrimitives'] -and $f[2] -eq 'TryStart') {$startSymbol=[int]$f[0]}
        if($f[1] -eq 'function' -and $f[5] -eq $modules['NativeCompilation'] -and $f[2] -eq 'TryObserveCompletion') {$completionSymbol=[int]$f[0]}
        if($f[1] -eq 'function' -and $f[5] -eq $modules['NativeLowering'] -and $f[2] -eq 'TryEmitRange') {$rangeSymbol=[int]$f[0]}
        if($f[1] -eq 'function' -and $f[5] -eq $modules['ThreadPrimitives'] -and $f[2] -eq 'RequestStop') {$stopSymbol=[int]$f[0]}
        if($f[1] -eq 'parameter'){$parameters[$f[6]+'/'+$f[2]]=[int]$f[0]}
    }
}
foreach($name in @('ConfigurePath','ConfigureMode','SetPathByte','Run','Observe','WriteObservation')) {Require ($symbols.ContainsKey($name)) "Missing probe $name"}
foreach($line in ($bound.Stdout -split '\r?\n')) {
    if($line.StartsWith('SYMBOL ')) {
        $f=$line.Substring(7).Split('|')
        if($f[1] -eq 'parameter' -and $f[6] -eq $emitterSymbol -and $f[2] -eq 'Ordinal') {$ordinalSymbol=[int]$f[0]}
        if($f[1] -eq 'parameter' -and $f[6] -eq $emitterSymbol -and $f[2] -eq 'NodeCount') {$nodeCountSymbol=[int]$f[0]}
        if($f[1] -eq 'parameter' -and $f[6] -eq $compilationSymbol -and $f[2] -eq 'State') {$stateSymbol=[int]$f[0]}
    }
}
Require ($ordinalSymbol -gt 0) 'Missing worker ordinal argument'
Require ($emitterSymbol -gt 0 -and $requestSymbol -gt 0) 'Missing observed worker procedures'
$library=Join-Path $artifacts 'compiler.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$library) 'EMIT OK'
$emitted=[IO.File]::ReadAllText($library,$utf8)
$null=New-Item -ItemType Directory -Path (Join-Path $artifacts 'llvm')
foreach($asset in @('templates.bin','windows-runtime.ll','kernel32.def')) {Copy-Item -LiteralPath (Join-Path $root ('compiler/llvm/'+$asset)) -Destination (Join-Path $artifacts ('llvm/'+$asset))}

# Creates two-module source inputs with distinct source-dependent outputs.
function New-Project([string]$Name,[int]$Value,[bool]$Invalid=$false,[bool]$Executable=$false,[bool]$DistinctShape=$false) {
    $folder=Join-Path $artifacts $Name
    $body="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"First`"`r`nPublic Function Value(ByVal Seed As Long) As Long`r`nValue = Seed + $Value`r`nEnd Function`r`n"
    if($Invalid){$body=$body.Replace('Seed + '+$Value,'MissingName')}
    if($DistinctShape){$body+="Private Const Extra As Long = 1`r`n"}
    Write-Text (Join-Path $folder 'First.bas') $body
    Write-Text (Join-Path $folder 'Second.bas') "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Second`"`r`nPublic Function Run(ByVal Seed As Long) As Long`r`nRun = First.Value(Seed) + $Value`r`nEnd Function`r`n"
    $path=Join-Path $folder 'project.UBE'
    Write-Text $path "UBE-Project 1`r`nName = `"ConcurrentInput`"`r`nKind = `"Library`"`r`nSource = `"First.bas`"`r`nSource = `"Second.bas`"`r`n"
    if($Executable) {
        Write-Text (Join-Path $folder 'Second.bas') "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Second`"`r`nPublic Function Main() As Long`r`nMain = First.Value(1) + $Value`r`nEnd Function`r`n"
        Write-Text $path "UBE-Project 1`r`nName = `"ConcurrentInput`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nSource = `"First.bas`"`r`nSource = `"Second.bas`"`r`n"
    }
    return $path
}

# Observes actual emitter-body lifetimes only in the emitted acceptance copy.
function Add-Observer([string]$Text,[int]$Identity,[string]$Prefix) {
    $pattern='(?ms)(^define \{ i1, i64 \} @ube\.proc\.'+$Identity+'\([^\r\n]*\) \{\r?\nentry:\r?\n)(.*?)(^\})'
    $matches=[regex]::Matches($Text,$pattern)
    Require ($matches.Count -eq 1) "Missing unique observed body $Identity"
    $match=$matches[0]
    $body=$match.Groups[2].Value
    $returns=[regex]::Matches($body,'(?m)^  ret \{ i1, i64 \}')
    Require ($returns.Count -gt 0) 'Observed body has no return edges'
    $body=[regex]::Replace($body,'(?m)^(  ret \{ i1, i64 \}[^\r\n]*)\r?$',('  call void @test.'+$Prefix+'.leave()'+"`r`n"+'$1'))
    Require ([regex]::Matches($body,('call void @test\.'+$Prefix+'\.leave\(\)')).Count -eq $returns.Count) 'Not every observed return releases its active count'
    $replacement=$match.Groups[1].Value+'  call void @test.'+$Prefix+'.enter()'+"`r`n"+$body+$match.Groups[3].Value
    return $Text.Substring(0,$match.Index)+$replacement+$Text.Substring($match.Index+$match.Length)
}

# Observes backend ownership after a real source process start and until its controlling call returns.
function Add-BackendObserver([string]$Text) {
    Require ($backendSymbol -gt 0 -and $startSymbol -gt 0) 'Missing native backend/start procedures'
    $pattern='(?ms)(^define \{ i1, i64 \} @ube\.proc\.'+$backendSymbol+'\([^\r\n]*\) \{\r?\nentry:\r?\n)(.*?)(^\})'
    $method=[regex]::Match($Text,$pattern)
    Require ($method.Success) 'Missing backend request body'
    $body="  %test.backend.entered = alloca i1, align 1`r`n  store i1 false, ptr %test.backend.entered, align 1`r`n"+$method.Groups[2].Value
    $start=[regex]::Match($body,('(?m)^  %v[0-9]+ = call \{ i1, i64 \} @ube\.proc\.'+$startSymbol+'\([^\r\n]*\)\r?\n'))
    Require ($start.Success) 'Missing real process start within backend request'
    $body=$body.Insert($start.Index+$start.Length,"  store i1 true, ptr %test.backend.entered, align 1`r`n  call void @test.backend.enter()`r`n")
    $body=[regex]::Replace($body,'(?m)^(  ret \{ i1, i64 \}[^\r\n]*)\r?$',('  call void @test.backend.release(ptr %test.backend.entered)'+"`r`n"+'$1'))
    $helper=@'
define void @test.backend.release(ptr %entered) noinline {
entry:
  %active = load i1, ptr %entered, align 1
  br i1 %active, label %release, label %done
release:
  call void @test.backend.leave()
  br label %done
done:
  ret void
}
'@
    return $Text.Substring(0,$method.Index)+$method.Groups[1].Value+$body+$method.Groups[3].Value+$Text.Substring($method.Index+$method.Length)+"`r`n"+$helper
}

# Bounds a test-only arrival barrier and records overlapping worker/request body lifetimes.
function Observer-IR([string]$Prefix,[int]$Target,[int]$Delay,[bool]$ResetFault=$false) {
    $releaseFault=''
    if($Prefix -eq 'request' -and $ResetFault){$releaseFault='  store atomic i64 0, ptr @test.failure.enabled monotonic, align 8'}
    return @"
@test.$Prefix.active = global i64 0, align 8
@test.$Prefix.maximum = global i64 0, align 8
@test.$Prefix.entered = global i64 0, align 8
@test.$Prefix.expired = global i64 0, align 8
define void @test.$Prefix.enter() noinline {
entry:
  %old = atomicrmw add ptr @test.$Prefix.active, i64 1 monotonic
  %active = add i64 %old, 1
  %peak = atomicrmw umax ptr @test.$Prefix.maximum, i64 %active monotonic
  %arrival = atomicrmw add ptr @test.$Prefix.entered, i64 1 monotonic
  %parity = and i64 %arrival, 1
  %first = icmp eq i64 %parity, 0
  %delay = select i1 %first, i32 $Delay, i32 0
  call void @Sleep(i32 %delay)
  br label %probe
probe:
  %attempt = phi i64 [ 0, %entry ], [ %next, %waiting ]
  %count = load atomic i64, ptr @test.$Prefix.entered monotonic, align 8
  %ready = icmp uge i64 %count, $Target
  br i1 %ready, label %done, label %deadline
deadline:
  %expired = icmp uge i64 %attempt, 10000
  br i1 %expired, label %failed, label %waiting
waiting:
  call void @Sleep(i32 1)
  %next = add i64 %attempt, 1
  br label %probe
failed:
  store atomic i64 1, ptr @test.$Prefix.expired monotonic, align 8
  br label %done
done:
  ret void
}
define void @test.$Prefix.leave() noinline {
entry:
  %old = atomicrmw sub ptr @test.$Prefix.active, i64 1 monotonic
$releaseFault
  ret void
}
"@
}

# Exercises production request APIs with independently checked success, failure and cleanup fields.
function Run-Requests([string]$Name,[int]$Mode,[string]$First,[string]$Second,[string]$OutputA,[string]$OutputB,[int]$ExpectedA=1,[int]$ExpectedB=1,[int]$Delay=0,[string]$Level='O0',[bool]$WorkerFailure=$false,[bool]$ObserveOverlap=$true,[int]$WorkerError=73,[bool]$CompletionFailure=$false,[int]$QuotaField=0,[int]$QuotaValue=0,[int]$TimeoutMilliseconds=120000,[int]$RequestMode=1,[string]$FirstClang=$Clang,[string]$SecondClang=$Clang,[int]$FaultNodeCount=0,[bool]$BackendEarlyFailure=$false,[bool]$CatalogCopyFailure=$false) {
    $lines=New-Object Collections.Generic.List[string]
    $lines.Add('@test.context = private global %ube.context zeroinitializer, align 8')
    $lines.Add('define i32 @main() {');$lines.Add('entry:')
    $lines.Add('  call void @ube.context.init(ptr @test.context)')
    $lines.Add('  %init = call i1 @ube.project.init(ptr @test.context)')
    $paths=@($First,$Second,$OutputA,$OutputB,$FirstClang,$SecondClang)
    for($kind=0;$kind -lt 6;$kind++) {
        $bytes=$utf8.GetBytes($paths[$kind])
        $lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.context, i64 {1}, i64 {2})' -f $symbols['ConfigurePath'],$kind,$bytes.Length))
        for($i=0;$i -lt $bytes.Length;$i++) {$lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.context, i64 {1}, i64 {2}, i64 {3})' -f $symbols['SetPathByte'],$kind,$i,$bytes[$i]))}
    }
    for($request=0;$request -lt 2;$request++) {$lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.context, i64 {1}, i64 {2})' -f $symbols['ConfigureMode'],$request,$RequestMode))}
    $lines.Add(('  %run = call {{ i1, i64 }} @ube.proc.{0}(ptr @test.context, i64 {1})' -f $symbols['Run'],$Mode))
    $lines.Add('  %fresh = extractvalue { i1, i64 } %run, 0');$lines.Add('  %value = extractvalue { i1, i64 } %run, 1')
    $lines.Add('  %zero = icmp eq i64 %value, 0');$lines.Add('  %initial = and i1 %fresh, %zero');$lines.Add('  %started = and i1 %init, %initial')
    $previous='started';$n=0;$requests=1;if($Mode -gt 2){$requests=2};if($Mode -eq 6){$requests=3}
    for($request=0;$request -lt $requests;$request++) {
        $expected=$ExpectedA;if($request -gt 0){$expected=$ExpectedB}
        foreach($pair in @(@(0,$expected),@(1,1),@(8,0))) {
            $lines.Add(('  %observation{0} = call {{ i1, i64 }} @ube.proc.{1}(ptr @test.context, i64 {2}, i64 {3})' -f $n,$symbols['Observe'],$request,$pair[0]))
            $lines.Add("  %observed$n = extractvalue { i1, i64 } %observation$n, 1")
            $lines.Add("  %matches$n = icmp eq i64 %observed$n, $($pair[1])")
            $lines.Add("  %accepted$n = and i1 %$previous, %matches$n")
            $previous='accepted'+$n;$n++
        }
    }
    $rangeTarget=1;if($Mode -gt 1){$rangeTarget=2}
    if($Mode -eq 1 -and $ExpectedA -eq 0){$rangeTarget=0}
    if($CatalogCopyFailure){$rangeTarget=1}
    $requestTarget=1;if($Mode -eq 3 -or $Mode -eq 4 -or $Mode -eq 6){$requestTarget=2}
    $backendTarget=0;if($RequestMode -eq 2){$backendTarget=1;if($Mode -eq 3 -or $Mode -eq 6){$backendTarget=2}}
    if($BackendEarlyFailure){$backendTarget=0}
    if(-not $ObserveOverlap){$rangeTarget=0;$requestTarget=0;$backendTarget=0}
    $lines.Add('  %range.peak = load atomic i64, ptr @test.range.maximum monotonic, align 8')
    $lines.Add("  %range.overlap = icmp uge i64 %range.peak, $rangeTarget")
    $lines.Add('  %request.peak = load atomic i64, ptr @test.request.maximum monotonic, align 8')
    $lines.Add("  %request.overlap = icmp uge i64 %request.peak, $requestTarget")
    $lines.Add('  %range.expired = load atomic i64, ptr @test.range.expired monotonic, align 8')
    $lines.Add('  %request.expired = load atomic i64, ptr @test.request.expired monotonic, align 8')
    $lines.Add('  %expired = or i64 %range.expired, %request.expired')
    $lines.Add('  %timely = icmp eq i64 %expired, 0')
    $lines.Add('  %overlap = and i1 %range.overlap, %request.overlap')
    $lines.Add('  %range.active = load atomic i64, ptr @test.range.active monotonic, align 8')
    $lines.Add('  %request.active = load atomic i64, ptr @test.request.active monotonic, align 8')
    $lines.Add('  %active = or i64 %range.active, %request.active')
    $lines.Add('  %inactive = icmp eq i64 %active, 0')
    $lines.Add('  %finished = and i1 %inactive, %timely')
    $lines.Add('  %observed = and i1 %overlap, %finished')
    $lines.Add('  %backend.peak = load atomic i64, ptr @test.backend.maximum monotonic, align 8')
    $lines.Add("  %backend.overlap = icmp uge i64 %backend.peak, $backendTarget")
    $lines.Add('  %backend.active = load atomic i64, ptr @test.backend.active monotonic, align 8')
    $lines.Add('  %backend.inactive = icmp eq i64 %backend.active, 0')
    $lines.Add('  %backend.expired = load atomic i64, ptr @test.backend.expired monotonic, align 8')
    $lines.Add('  %backend.timely = icmp eq i64 %backend.expired, 0')
    $lines.Add('  %backend.closed = and i1 %backend.inactive, %backend.timely')
    $lines.Add('  %backend.good = and i1 %backend.closed, %backend.overlap')
    $lines.Add('  %owners.observed = and i1 %observed, %backend.good')
    $lines.Add("  %qualified = and i1 %$previous, %owners.observed")
    $previous='qualified'
    if($CatalogCopyFailure) {
        $lines.Add('  %copy.attempts = load atomic i64, ptr @test.catalog.attempts acquire, align 8')
        $lines.Add('  %copy.expired = load atomic i64, ptr @test.catalog.expired monotonic, align 8')
        $lines.Add('  %copy.second = icmp eq i64 %copy.attempts, 2')
        $lines.Add('  %copy.timely = icmp eq i64 %copy.expired, 0')
        $lines.Add('  %copy.good = and i1 %copy.second, %copy.timely')
        $lines.Add('  %copy.qualified = and i1 %qualified, %copy.good')
        $previous='copy.qualified'
    }
    if($Mode -eq 4) {
        $lines.Add('  %cancel.mask = load atomic i64, ptr @test.cancel.mask acquire, align 8')
        $lines.Add('  %cancel.expired = load atomic i64, ptr @test.cancel.expired monotonic, align 8')
        $lines.Add('  %cancel.started = icmp eq i64 %cancel.mask, 3')
        $lines.Add('  %cancel.timely = icmp eq i64 %cancel.expired, 0')
        $lines.Add('  %cancel.good = and i1 %cancel.started, %cancel.timely')
        $lines.Add('  %cancel.qualified = and i1 %qualified, %cancel.good')
        $previous='cancel.qualified'
    }
    for($request=0;$request -lt $requests;$request++) {
        $lines.Add(('  %printed{0} = call {{ i1, i64 }} @ube.proc.{1}(ptr @test.context, i64 {0})' -f $request,$symbols['WriteObservation']))
        $lines.Add("  %printed.value$request = extractvalue { i1, i64 } %printed$request, 1")
        $lines.Add("  %print.ok$request = icmp ne i64 %printed.value$request, 0")
        $lines.Add("  %report.ok$request = and i1 %$previous, %print.ok$request")
        $previous='report.ok'+$request
    }
    $lines.Add('  %disposed = call i1 @ube.context.dispose(ptr @test.context)')
    $lines.Add("  %all = and i1 %$previous, %disposed")
    $lines.Add('  %exit = select i1 %all, i32 0, i32 1');$lines.Add('  ret i32 %exit');$lines.Add('}')
    $ir=Join-Path $artifacts ($Name+'.ll');$exe=Join-Path $artifacts ($Name+'.exe')
    $observedText=$emitted
    if($QuotaField -gt 0) {
        # Seed only existing request counters after the real header; production bounds and algorithms remain unchanged.
        $offset=7;if($QuotaField -eq 2){$offset=1};if($QuotaField -eq 3){$offset=2}
        Require ($QuotaField -le 3 -and $QuotaValue -ge 0 -and $stateSymbol -gt 0 -and $beginSymbol -gt 0) 'Invalid quota seed'
        $method=[regex]::Match($observedText,('(?ms)^define \{ i1, i64 \} @ube\.proc\.'+$compilationSymbol+'\([^\r\n]*\) \{(.*?)^\}'))
        $begin=[regex]::Match($method.Groups[1].Value,('(?m)^  %v[0-9]+ = call \{ i1, i64 \} @ube\.proc\.'+$beginSymbol+'\([^\r\n]*\)\r?\n'))
        Require ($begin.Success) 'Missing unique coordinator header call for quota seed'
        $injection="  %test.quota = getelementptr i64, ptr %arg.$stateSymbol, i64 $offset`r`n  store atomic i64 $QuotaValue, ptr %test.quota monotonic, align 8`r`n"
        $observedText=$observedText.Insert($method.Groups[1].Index+$begin.Index+$begin.Length,$injection)
    }
    if($ObserveOverlap) {
        $observedText=Add-Observer $observedText $emitterSymbol 'range'
        $observedText=Add-Observer $observedText $requestSymbol 'request'
        if($RequestMode -eq 2){$observedText=Add-BackendObserver $observedText}
    }
    if($Mode -eq 4) {
        Require ($FaultNodeCount -gt 0 -and $rangeSymbol -gt 0 -and $stopSymbol -gt 0) 'Cancellation needs a distinct observed request selector'
        $method=[regex]::Match($observedText,('(?ms)^define \{ i1, i64 \} @ube\.proc\.'+$emitterSymbol+'\([^\r\n]*\) \{(.*?)^\}'))
        $call=[regex]::Match($method.Groups[1].Value,('(?m)^  %v[0-9]+ = call \{ i1, i64 \} @ube\.proc\.'+$rangeSymbol+'\([^\r\n]*\)\r?\n'))
        Require ($call.Success) 'Missing real symbol emission before cancellation barrier'
        $observedText=$observedText.Insert($method.Groups[1].Index+$call.Index+$call.Length,"  call void @test.cancel.arrive(i64 %arg.$nodeCountSymbol, i64 %arg.$ordinalSymbol)`r`n")
        $method=[regex]::Match($observedText,('(?ms)^define \{ i1, i64 \} @ube\.proc\.'+$symbols['Run']+'\([^\r\n]*\) \{(.*?)^\}'))
        $call=[regex]::Match($method.Groups[1].Value,('(?m)^  %v[0-9]+ = call \{ i1, i64 \} @ube\.proc\.'+$stopSymbol+'\([^\r\n]*\)\r?\n'))
        Require ($call.Success) 'Missing source cancellation request'
        $position=$method.Groups[1].Index+$call.Index
        $observedText=$observedText.Insert($position+$call.Length,"  store atomic i64 1, ptr @test.cancel.sent release, align 8`r`n")
        $observedText=$observedText.Insert($position,"  call void @test.cancel.wait(ptr @test.cancel.mask, i64 3)`r`n")
        $observedText+="`r`n@test.cancel.nodes = constant i64 $FaultNodeCount`r`n"
        $observedText+=@'
@test.cancel.mask = global i64 0, align 8
@test.cancel.sent = global i64 0, align 8
@test.cancel.expired = global i64 0, align 8
define void @test.cancel.wait(ptr %value, i64 %target) noinline {
entry:
  br label %probe
probe:
  %attempt = phi i64 [ 0, %entry ], [ %next, %waiting ]
  %actual = load atomic i64, ptr %value acquire, align 8
  %ready = icmp eq i64 %actual, %target
  br i1 %ready, label %done, label %deadline
deadline:
  %expired = icmp uge i64 %attempt, 10000
  br i1 %expired, label %failed, label %waiting
waiting:
  call void @Sleep(i32 1)
  %next = add i64 %attempt, 1
  br label %probe
failed:
  store atomic i64 1, ptr @test.cancel.expired monotonic, align 8
  br label %done
done:
  ret void
}
define void @test.cancel.arrive(i64 %nodes, i64 %ordinal) noinline {
entry:
  %target = load i64, ptr @test.cancel.nodes
  %wanted = icmp eq i64 %nodes, %target
  br i1 %wanted, label %arrive, label %done
arrive:
  %bit = shl i64 1, %ordinal
  %old = atomicrmw or ptr @test.cancel.mask, i64 %bit acq_rel
  call void @test.cancel.wait(ptr @test.cancel.sent, i64 1)
  br label %done
done:
  ret void
}
'@
    }
    if($BackendEarlyFailure) {
        $pattern='(?ms)(^define \{ i1, i64 \} @ube\.proc\.'+$backendSymbol+'\([^\r\n]*\) \{.*?^stmt\.[0-9]+:\r?\n)'
        $match=[regex]::Match($observedText,$pattern)
        Require ($match.Success) 'Missing backend statement before process start'
        $observedText=$observedText.Insert($match.Index+$match.Length,"  br label %return.fail`r`ntest.backend.unreached:`r`n")
    }
    $fault=0;if($WorkerFailure -or $CatalogCopyFailure){$fault=1}
    $observedText+="`r`n@test.failure.enabled = global i64 $fault, align 8`r`n"
    if($CatalogCopyFailure) {
        $method=[regex]::Match($observedText,('(?ms)^define \{ i1, i64 \} @ube\.proc\.'+$compilationSymbol+'\([^\r\n]*\) \{(.*?)^\}'))
        $body=$method.Groups[1].Value
        Require ([regex]::Matches($body,'call i1 @ube\.array\.trycopy\(').Count -eq 3) 'Expected direct, threaded and replay catalog snapshot sites'
        $body=$body.Replace('call i1 @ube.array.trycopy(','call i1 @test.catalog.copy(')
        $observedText=$observedText.Substring(0,$method.Groups[1].Index)+$body+$observedText.Substring($method.Groups[1].Index+$method.Groups[1].Length)
        $method=[regex]::Match($observedText,('(?ms)^define \{ i1, i64 \} @ube\.proc\.'+$emitterSymbol+'\([^\r\n]*\) \{(.*?)^\}'))
        $entry=[regex]::Match($method.Groups[1].Value,'(?m)^  call void @test\.range\.enter\(\)\r?\n')
        Require ($entry.Success) 'Missing real worker entry for catalog capture failure'
        $observedText=$observedText.Insert($method.Groups[1].Index+$entry.Index+$entry.Length,"  call void @test.catalog.worker()`r`n")
        $observedText+=@'
@test.catalog.attempts = global i64 0, align 8
@test.catalog.arrived = global i64 0, align 8
@test.catalog.failed = global i64 0, align 8
@test.catalog.expired = global i64 0, align 8
define void @test.catalog.wait(ptr %value) noinline {
entry:
  br label %probe
probe:
  %attempt = phi i64 [ 0, %entry ], [ %next, %waiting ]
  %actual = load atomic i64, ptr %value acquire, align 8
  %ready = icmp eq i64 %actual, 1
  br i1 %ready, label %done, label %deadline
deadline:
  %expired = icmp uge i64 %attempt, 1000
  br i1 %expired, label %failed, label %waiting
waiting:
  call void @Sleep(i32 10)
  %next = add i64 %attempt, 1
  br label %probe
failed:
  store atomic i64 1, ptr @test.catalog.expired monotonic, align 8
  br label %done
done:
  ret void
}
define void @test.catalog.worker() noinline {
entry:
  %enabled = load atomic i64, ptr @test.failure.enabled monotonic, align 8
  %armed = icmp ne i64 %enabled, 0
  br i1 %armed, label %hold, label %done
hold:
  store atomic i64 1, ptr @test.catalog.arrived release, align 8
  call void @test.catalog.wait(ptr @test.catalog.failed)
  br label %done
done:
  ret void
}
define i1 @test.catalog.copy(ptr %ctx, ptr %destination, ptr %source, i64 %stride) noinline {
entry:
  %enabled = load atomic i64, ptr @test.failure.enabled monotonic, align 8
  %armed = icmp ne i64 %enabled, 0
  br i1 %armed, label %count, label %copy
count:
  %old = atomicrmw add ptr @test.catalog.attempts, i64 1 acq_rel
  %second = icmp eq i64 %old, 1
  br i1 %second, label %fail, label %copy
fail:
  call void @test.catalog.wait(ptr @test.catalog.arrived)
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  store atomic i64 8, ptr %err monotonic, align 8
  store atomic i64 1, ptr @test.catalog.failed release, align 8
  ret i1 false
copy:
  %copied = call i1 @ube.array.trycopy(ptr %ctx, ptr %destination, ptr %source, i64 %stride)
  ret i1 %copied
}
'@
    }
    if($WorkerFailure) {
        if($CompletionFailure) {
            $method=[regex]::Match($observedText,('(?ms)^define \{ i1, i64 \} @ube\.proc\.'+$emitterSymbol+'\([^\r\n]*\) \{(.*?)^\}'))
            $returned=[regex]::Match($method.Groups[1].Value,'(?m)^  ret \{ i1, i64 \} (%v[0-9]+)\r?$')
            Require ($returned.Success) 'Missing successful worker completion for Err-zero injection'
            $injection="  %test.failure = call i1 @test.fail.range(ptr %ctx, i64 %arg.$ordinalSymbol, i64 %arg.$nodeCountSymbol)`r`n  %test.success = xor i1 %test.failure, true`r`n  %test.outcome = insertvalue { i1, i64 } $($returned.Groups[1].Value), i1 %test.success, 0`r`n  ret { i1, i64 } %test.outcome"
            $start=$method.Groups[1].Index+$returned.Index
            $observedText=$observedText.Substring(0,$start)+$injection+$observedText.Substring($start+$returned.Length)
        } else {
            $pattern='(?ms)(^define \{ i1, i64 \} @ube\.proc\.'+$emitterSymbol+'\([^\r\n]*\) \{.*?^stmt\.[0-9]+:\r?\n)'
            $match=[regex]::Match($observedText,$pattern)
            Require ($match.Success) 'Missing first worker statement for bounded failure injection'
            $injection="  %test.failure = call i1 @test.fail.range(ptr %ctx, i64 %arg.$ordinalSymbol, i64 %arg.$nodeCountSymbol)`r`n  br i1 %test.failure, label %return.fail, label %test.worker.continue`r`ntest.worker.continue:`r`n"
            $observedText=$observedText.Insert($match.Index+$match.Length,$injection)
        }
        $faultHelper=@'
define i1 @test.fail.range(ptr %ctx, i64 %ordinal, i64 %nodes) noinline {
entry:
  %enabled = load atomic i64, ptr @test.failure.enabled monotonic, align 8
  %selected = icmp eq i64 %ordinal, 0
  %armed = icmp ne i64 %enabled, 0
  %target.nodes = load i64, ptr @test.failure.nodes
  %all.nodes = icmp eq i64 %target.nodes, 0
  %same.nodes = icmp eq i64 %target.nodes, %nodes
  %target = or i1 %all.nodes, %same.nodes
  %wanted = and i1 %selected, %target
  %fail = and i1 %wanted, %armed
  br i1 %fail, label %failed, label %success
failed:
  %err = getelementptr %ube.thread, ptr %ctx, i32 0, i32 0
  store atomic i64 73, ptr %err monotonic, align 8
  ret i1 true
success:
  ret i1 false
}
'@
        $observedText+="`r`n@test.failure.nodes = constant i64 $FaultNodeCount`r`n"+$faultHelper.Replace('i64 73,',('i64 '+$WorkerError+','))
    }
    $observedText+=(Observer-IR 'range' $rangeTarget $Delay)+(Observer-IR 'request' $requestTarget 0 ($Mode -eq 5))+(Observer-IR 'backend' $backendTarget 0)
    Write-Text $ir ($observedText+($lines -join "`r`n"))
    Build-Harness $ir $exe $Level
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $result=Invoke-BoundedProcess $exe @() $TimeoutMilliseconds
    $timer.Stop()
    Require ($result.ExitCode -eq 0) "Request assertions failed $Name : $($result.Evidence)"
    $script:lastReport=$result.Stdout
    $script:lastMilliseconds=$timer.ElapsedMilliseconds
    $script:lastExecutableHash=(Get-FileHash -LiteralPath $exe).Hash
    Write-Output "PASS: $Name $Level request assertions elapsed $($timer.ElapsedMilliseconds)ms"
}

# Verifies cleanup observes every started worker before any retained close can stop progress.
function Check-SourceCleanup {
    $copy=$emitted
    $hold=$symbols['HoldCleanupFile'];$check=$symbols['CheckCleanup']
    Require ($hold -gt 0 -and $check -gt 0 -and $completionSymbol -gt 0) 'Missing cleanup regression procedures'
    foreach($spec in @(@($hold,'hold'),@($completionSymbol,'observe'))) {
        $parameter=$parameters[$spec[0].ToString()+'/Result']
        $pattern='(?ms)(^define \{ i1, i64 \} @ube\.proc\.'+$spec[0]+'\([^\r\n]*\) \{\r?\nentry:\r?\n)'
        $match=[regex]::Match($copy,$pattern)
        Require ($match.Success -and $parameter -gt 0) 'Missing retained cleanup argument'
        $copy=$copy.Insert($match.Index+$match.Length,('  call void @test.cleanup.'+$spec[1]+'(ptr %arg.'+$parameter+")`r`n"))
    }
    $pattern='(?m)^define i1 @ube\.target\.file\.close\('
    Require ([regex]::Matches($copy,$pattern).Count -eq 1) 'Missing unique file close wrapper'
    $copy=[regex]::Replace($copy,$pattern,'define i1 @test.real.file.close(')
    $copy+=@'
@test.cleanup.observed = global i64 0, align 8
@test.cleanup.expired = global i64 0, align 8
@test.cleanup.early = global i64 0, align 8
@test.cleanup.remaining = global i64 1, align 8
define void @test.cleanup.observe(ptr %result) noinline {
entry:
  %ordinal = load atomic i64, ptr %result monotonic, align 8
  %second = icmp eq i64 %ordinal, 2
  br i1 %second, label %publish, label %done
publish:
  store atomic i64 1, ptr @test.cleanup.observed release, align 8
  br label %done
done:
  ret void
}
define void @test.cleanup.hold(ptr %result) noinline {
entry:
  %ordinal = load atomic i64, ptr %result monotonic, align 8
  %second = icmp eq i64 %ordinal, 2
  br i1 %second, label %probe, label %done
probe:
  %attempt = phi i64 [ 0, %entry ], [ %next, %waiting ]
  %observed = load atomic i64, ptr @test.cleanup.observed acquire, align 8
  %ready = icmp ne i64 %observed, 0
  br i1 %ready, label %done, label %deadline
deadline:
  %expired = icmp uge i64 %attempt, 10000
  br i1 %expired, label %failed, label %waiting
waiting:
  call void @Sleep(i32 1)
  %next = add i64 %attempt, 1
  br label %probe
failed:
  store atomic i64 1, ptr @test.cleanup.expired monotonic, align 8
  br label %done
done:
  ret void
}
define i1 @ube.target.file.close(ptr %handle) {
entry:
  %observed = load atomic i64, ptr @test.cleanup.observed acquire, align 8
  %early = icmp eq i64 %observed, 0
  br i1 %early, label %bad, label %count
bad:
  store atomic i64 1, ptr @test.cleanup.early monotonic, align 8
  br label %count
count:
  %remaining = atomicrmw sub ptr @test.cleanup.remaining, i64 1 monotonic
  %fail = icmp eq i64 %remaining, 1
  br i1 %fail, label %failed, label %release
failed:
  ret i1 false
release:
  %released = call i1 @test.real.file.close(ptr %handle)
  ret i1 %released
}
'@
    foreach($level in @('O0','O2')) {
        $lines=New-Object Collections.Generic.List[string]
        $lines.Add('@test.context = private global %ube.context zeroinitializer, align 8')
        $lines.Add('define i32 @main() {');$lines.Add('entry:')
        $lines.Add('  call void @ube.context.init(ptr @test.context)')
        $lines.Add('  %init = call i1 @ube.project.init(ptr @test.context)')
        for($kind=2;$kind -lt 4;$kind++) {
            $path=Join-Path $artifacts ('cleanup-owner-'+$kind+'-'+$level+'.bin')
            $bytes=$utf8.GetBytes($path)
            $lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.context, i64 {1}, i64 {2})' -f $symbols['ConfigurePath'],$kind,$bytes.Length))
            for($i=0;$i -lt $bytes.Length;$i++) {$lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.context, i64 {1}, i64 {2}, i64 {3})' -f $symbols['SetPathByte'],$kind,$i,$bytes[$i]))}
        }
        $lines.Add(('  %check = call {{ i1, i64 }} @ube.proc.{0}(ptr @test.context)' -f $check))
        $lines.Add('  %fresh = extractvalue { i1, i64 } %check, 0');$lines.Add('  %value = extractvalue { i1, i64 } %check, 1')
        $lines.Add('  %zero = icmp eq i64 %value, 0');$lines.Add('  %good = and i1 %fresh, %zero')
        $lines.Add('  %early = load atomic i64, ptr @test.cleanup.early monotonic, align 8')
        $lines.Add('  %expired = load atomic i64, ptr @test.cleanup.expired monotonic, align 8')
        $lines.Add('  %bad = or i64 %early, %expired');$lines.Add('  %ordered = icmp eq i64 %bad, 0')
        $lines.Add('  %disposed = call i1 @ube.context.dispose(ptr @test.context)')
        $lines.Add('  %a = and i1 %init, %good');$lines.Add('  %b = and i1 %ordered, %disposed');$lines.Add('  %all = and i1 %a, %b')
        $lines.Add('  %exit = select i1 %all, i32 0, i32 1');$lines.Add('  ret i32 %exit');$lines.Add('}')
        $ir=Join-Path $artifacts ('cleanup-retry-'+$level+'.ll');$exe=Join-Path $artifacts ('cleanup-retry-'+$level+'.exe')
        Write-Text $ir ($copy+"`r`n"+($lines -join "`r`n"))
        Build-Harness $ir $exe $level
        $result=Invoke-BoundedProcess $exe @()
        Require ($result.ExitCode -eq 0) "All-worker cleanup/close retry failed $level : $($result.Evidence)"
        Write-Output "PASS: all source workers observed before retained close failure, then successful retry $level"
    }
}

$first=New-Project 'first source' 10
$second=New-Project 'second source' 20 $false $false $true
$invalid=New-Project 'invalid source' 30 $true
$baseline=Join-Path $artifacts 'baseline.ll'
$parallel=Join-Path $artifacts 'parallel.ll'
$simultaneousA=Join-Path $artifacts 'simultaneous-a.ll'
$simultaneousB=Join-Path $artifacts 'simultaneous-b.ll'
$secondBaseline=Join-Path $artifacts 'second-baseline.ll'
if(-not $MeasureOnly) {
Run-Requests 'single worker' 1 $first $second $baseline $simultaneousB
Run-Requests 'two workers' 2 $first $second $parallel $simultaneousB
$parallelMetrics=($script:lastReport -split '\r?\n')[0].Split(',')
Require ((Get-FileHash $baseline).Hash -eq (Get-FileHash $parallel).Hash) 'Worker count changed generated IR'
Run-Requests 'independent second baseline' 1 $second $first $secondBaseline $simultaneousA
$secondMetrics=($script:lastReport -split '\r?\n')[0].Split(',')
Require ($parallelMetrics[16] -ne $secondMetrics[16]) 'Fault/cancellation request selectors must have different observed node counts'
Run-Requests 'same process requests' 3 $first $second $simultaneousA $simultaneousB
Require ((Get-FileHash $baseline).Hash -eq (Get-FileHash $simultaneousA).Hash) 'Simultaneous request changed first IR'
Require ((Get-FileHash $simultaneousB).Hash -eq (Get-FileHash $secondBaseline).Hash) 'Second simultaneous request differs from its independent baseline'
$preserved=(Get-FileHash $simultaneousA).Hash
Run-Requests 'failed single-worker baseline' 1 $invalid $second $simultaneousA $simultaneousB 0 1
$failedBaseline=$script:lastReport
Run-Requests 'failed alongside successful' 3 $invalid $second $simultaneousA $simultaneousB 0 1
Require ($script:lastReport.StartsWith($failedBaseline,[StringComparison]::Ordinal)) 'Concurrent failure changed ordered diagnostic or source path'
Require ((Get-FileHash $simultaneousA).Hash -eq $preserved) 'Failed request changed existing output'
Run-Requests 'staggered worker schedule' 2 $first $second $parallel $simultaneousB 1 1 10 'O2'
Require ((Get-FileHash $baseline).Hash -eq (Get-FileHash $parallel).Hash) 'Delayed optimized schedule changed IR'
Run-Requests -Name 'cancelled alongside successful' -Mode 4 -First $first -Second $second -OutputA $simultaneousA -OutputB $simultaneousB -ExpectedA 0 -FaultNodeCount ([int]$parallelMetrics[16])
Require ((Get-FileHash $simultaneousA).Hash -eq $preserved) 'Cancelled request changed existing output'
Run-Requests 'worker failure then recovery' 5 $first $second $simultaneousA $simultaneousB 0 1 0 'O0' $true
Require ((Get-FileHash $simultaneousA).Hash -eq $preserved) 'Worker failure changed existing output'
Run-Requests 'completed worker Err-zero failure' 5 $first $second $simultaneousA $simultaneousB 0 1 0 'O0' $true $true 0 $true
Require ((Get-FileHash $simultaneousA).Hash -eq $preserved) 'Fresh Err-zero worker failure published output'
foreach($level in @('O0','O2')) {
    Run-Requests -Name ('second catalog copy failure '+$level) -Mode 5 -First $first -Second $second -OutputA $simultaneousA -OutputB $simultaneousB -ExpectedA 0 -Level $level -CatalogCopyFailure $true
    Require ((Get-FileHash $simultaneousA).Hash -eq $preserved -and (Get-FileHash $simultaneousB).Hash -eq (Get-FileHash $secondBaseline).Hash) 'Catalog-copy failure lost prior publication or recovery output'
}
Run-Requests -Name 'worker failure alongside successful request' -Mode 3 -First $first -Second $second -OutputA $simultaneousA -OutputB $simultaneousB -ExpectedA 0 -ExpectedB 1 -WorkerFailure $true -FaultNodeCount ([int]$parallelMetrics[16])
Require ((Get-FileHash $simultaneousA).Hash -eq $preserved -and (Get-FileHash $simultaneousB).Hash -eq (Get-FileHash $secondBaseline).Hash) 'Worker failure contaminated publication of either concurrent request'
$workSeed=10000000-[int]$parallelMetrics[9]
Run-Requests 'work quota boundary single worker' 1 $first $second $simultaneousA $simultaneousB 0 1 0 'O0' $false $true 73 $false 1 $workSeed
$quotaBaseline=($script:lastReport -split '\r?\n')
Run-Requests 'work quota boundary two workers' 2 $first $second $simultaneousA $simultaneousB 0 1 0 'O0' $false $true 73 $false 1 $workSeed
$quotaParallel=($script:lastReport -split '\r?\n')
Require ((($quotaBaseline[0].Split(',')[@(0..8)+15]) -join ',') -ceq (($quotaParallel[0].Split(',')[@(0..8)+15]) -join ',') -and $quotaBaseline[1] -ceq $quotaParallel[1]) 'Work-limit boundary changed diagnostic cursor across worker counts'
Require ($quotaParallel[0].Split(',')[3] -eq '6' -and $quotaParallel[0].Split(',')[4] -eq '56') 'Work boundary did not exercise the existing work quota'
Require ((Get-FileHash $simultaneousA).Hash -eq $preserved) 'Work-limit failure changed existing output'
Run-Requests 'competing publication' 3 $first $second $simultaneousA $simultaneousA
$competing=(Get-FileHash $simultaneousA).Hash
Require ($competing -eq (Get-FileHash $baseline).Hash -or $competing -eq (Get-FileHash $secondBaseline).Hash) 'Competing publication produced a partial or mixed artifact'
Check-SourceCleanup
$nativeFirst=New-Project 'native first source' 10 $false $true
$nativeSecond=New-Project 'native second source' 20 $false $true
$nativeA=Join-Path $artifacts 'native-a.exe'
$nativeB=Join-Path $artifacts 'native-b.exe'
$footerOutput=Join-Path $artifacts 'footer-quota.ll'
Run-Requests 'executable emission quota reference' 2 $nativeFirst $nativeSecond $footerOutput $simultaneousB
$footerMetrics=($script:lastReport -split '\r?\n')[0].Split(',')
$footerPreserved=(Get-FileHash -LiteralPath $footerOutput).Hash
foreach($quota in @(2,3)) {
    $quotaSeed=16777216-[int]$footerMetrics[11]-[int]$footerMetrics[12]
    if($quota -eq 3){$quotaSeed=500000-[int]$footerMetrics[13]-[int]$footerMetrics[14]}
    Run-Requests -Name ('footer quota '+$quota+' single worker') -Mode 1 -First $nativeFirst -Second $nativeSecond -OutputA $footerOutput -OutputB $simultaneousB -ExpectedA 0 -QuotaField $quota -QuotaValue $quotaSeed
    $footerSingle=$script:lastReport -split '\r?\n'
    Run-Requests -Name ('footer quota '+$quota+' two workers') -Mode 2 -First $nativeFirst -Second $nativeSecond -OutputA $footerOutput -OutputB $simultaneousB -ExpectedA 0 -QuotaField $quota -QuotaValue $quotaSeed
    $footerParallel=$script:lastReport -split '\r?\n'
    $fields=$footerParallel[0].Split(',')
    Require ((($footerSingle[0].Split(',')[@(0..8)+15]) -join ',') -ceq (($fields[@(0..8)+15]) -join ',') -and $footerSingle[1] -ceq $footerParallel[1]) 'Footer quota changed ordered diagnostic across worker counts'
    Require ($fields[3] -eq '6' -and $fields[4] -eq '2' -and $fields[5] -eq '4' -and $footerParallel[1].EndsWith('Second.bas',[StringComparison]::Ordinal)) 'Footer limit lost the preceding source diagnostic cursor'
    Require ((Get-FileHash -LiteralPath $footerOutput).Hash -ceq $footerPreserved) 'Footer quota failure replaced prior output'
}
Run-Requests -Name 'same process native backends' -Mode 3 -First $nativeFirst -Second $nativeSecond -OutputA $nativeA -OutputB $nativeB -RequestMode 2
Assert-X64 $nativeA;Assert-X64 $nativeB
$runA=Invoke-BoundedProcess $nativeA @();$runB=Invoke-BoundedProcess $nativeB @()
Require ($runA.ExitCode -eq 21 -and $runB.ExitCode -eq 41) 'Concurrent native backends lost source-specific executable behavior'
$nativePreserved=(Get-FileHash -LiteralPath $nativeA).Hash
Run-Requests -Name 'backend observer early return' -Mode 2 -First $nativeFirst -Second $nativeSecond -OutputA $nativeA -OutputB $nativeB -ExpectedA 0 -RequestMode 2 -BackendEarlyFailure $true
Require ((Get-FileHash -LiteralPath $nativeA).Hash -ceq $nativePreserved) 'Backend early return replaced existing executable'
$failingDirectory=Join-Path $artifacts 'failing backend'
$null=New-Item -ItemType Directory -Path $failingDirectory
$stub=Join-Path $failingDirectory 'exit7.ll'
Write-Text $stub 'define i32 @main() { ret i32 7 }'
Build-Harness $stub (Join-Path $failingDirectory 'llvm-dlltool.exe') 'O0'
$failingClang=Join-Path $failingDirectory 'clang.exe'
Copy-Item -LiteralPath (Join-Path $failingDirectory 'llvm-dlltool.exe') -Destination $failingClang
Run-Requests -Name 'failed backend alongside successful' -Mode 3 -First $nativeSecond -Second $nativeFirst -OutputA $nativeA -OutputB $nativeB -ExpectedA 0 -ExpectedB 1 -RequestMode 2 -FirstClang $failingClang
$backendFailure=($script:lastReport -split '\r?\n')[0].Split(',')
Require ($backendFailure[2] -eq '6' -and $backendFailure[4] -eq '7') 'Backend failure lost its ordered operation/exit diagnostic'
Require ((Get-FileHash -LiteralPath $nativeA).Hash -ceq $nativePreserved) 'Failed backend replaced prior executable'
$runB=Invoke-BoundedProcess $nativeB @()
Require ($runB.ExitCode -eq 21) 'Successful request was contaminated by the competing backend failure'
$timeoutDirectory=Join-Path $artifacts 'timed out backend'
$null=New-Item -ItemType Directory -Path $timeoutDirectory
$timeoutIR=Join-Path $timeoutDirectory 'wait.ll'
Write-Text $timeoutIR 'define i32 @main() { entry: br label %waiting
waiting: br label %waiting }'
Build-Harness $timeoutIR (Join-Path $timeoutDirectory 'llvm-dlltool.exe') 'O0'
$timeoutClang=Join-Path $timeoutDirectory 'clang.exe'
Copy-Item -LiteralPath (Join-Path $timeoutDirectory 'llvm-dlltool.exe') -Destination $timeoutClang
Run-Requests -Name 'timed out backend isolated and recovered' -Mode 6 -First $nativeSecond -Second $nativeFirst -OutputA $nativeA -OutputB $nativeB -ExpectedA 0 -ExpectedB 1 -RequestMode 2 -FirstClang $timeoutClang
$timeoutFailure=($script:lastReport -split '\r?\n')[0].Split(',')
Require ($timeoutFailure[2] -eq '6' -and $timeoutFailure[3] -eq '100') 'Backend timeout lost its ordered deadline diagnostic'
Require ((Get-FileHash -LiteralPath $nativeA).Hash -ceq $nativePreserved) 'Timed-out backend replaced prior executable'
$runB=Invoke-BoundedProcess $nativeB @()
Require ($runB.ExitCode -eq 21) 'Subsequent same-process native request was unusable after timeout cleanup'
}
if($Measure -or $MeasureOnly) {
    $measurementPackage=$package
    if($MeasurementManifest) {
        $MeasurementManifest=[IO.Path]::GetFullPath($MeasurementManifest)
        $measurementPackage=Split-Path -Parent $MeasurementManifest
        $ledger=Join-Path $measurementPackage 'sources.sha256'
        foreach($entry in [IO.File]::ReadAllLines($ledger)) {
            Require ($entry -match '^([A-Fa-f0-9]{64})  (.+)$') 'Malformed frozen source ledger'
            $expectedHash=$Matches[1];$sourcePath=Join-Path $measurementPackage $Matches[2]
            Require ((Get-FileHash -LiteralPath $sourcePath).Hash -ceq $expectedHash) "Frozen workload changed: $sourcePath"
        }
        Copy-Item -LiteralPath $ledger -Destination (Join-Path $artifacts 'measurement-sources.sha256')
    } else {$MeasurementManifest=$manifest}
    $sourceFiles=@(Get-ChildItem -LiteralPath $measurementPackage -Filter '*.bas' -File)
    $sourceBytes=($sourceFiles | Measure-Object -Property Length -Sum).Sum
    $measurementIdentity=@(
        ('WorkloadManifest='+$MeasurementManifest)
        ('WorkloadManifestSHA256='+(Get-FileHash -LiteralPath $MeasurementManifest).Hash)
        ('DriverIRSHA256='+(Get-FileHash -LiteralPath $library).Hash)
        ('RuntimeSHA256='+(Get-FileHash -LiteralPath (Join-Path $artifacts 'llvm/windows-runtime.ll')).Hash)
    )
    Write-Text (Join-Path $artifacts 'measurement-identity.txt') ($measurementIdentity -join "`r`n")
    $processorName=$env:PROCESSOR_IDENTIFIER
    try {$processorName=(Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name ProcessorNameString).ProcessorNameString} catch {}
    $hardware=[pscustomobject]@{Name=$processorName;LogicalProcessors=[Environment]::ProcessorCount;Architecture=$env:PROCESSOR_ARCHITECTURE;PhysicalCores='CIM unavailable in this sandbox'}
    Write-Text (Join-Path $artifacts 'measurement-host.txt') (($hardware | Format-List | Out-String)+"Sources=$($sourceFiles.Count) Bytes=$sourceBytes`r`nMode=O2 compiler driver; complete source-to-LLVM request; scheduling observer disabled`r`n")
    $measurements=@();$referenceHash='';$trial=0
    foreach($workers in @(1,2,2,1)) {
        $trial++
        $output=Join-Path $artifacts ('compiler-trial-'+$trial+'.ll')
        Run-Requests -Name ('compiler sources trial '+$trial) -Mode $workers -First $MeasurementManifest -Second $second -OutputA $output -OutputB $simultaneousB -Level 'O2' -ObserveOverlap $false -TimeoutMilliseconds 600000
        $hash=(Get-FileHash -LiteralPath $output).Hash
        if($referenceHash){Require ($hash -ceq $referenceHash) 'Compiler-source workload changed across worker counts'}else{$referenceHash=$hash}
        $measurements += [pscustomobject]@{Trial=$trial;Workers=$workers;Milliseconds=$script:lastMilliseconds;SHA256=$hash;ExecutableSHA256=$script:lastExecutableHash}
        $measurements | Export-Csv -LiteralPath (Join-Path $artifacts 'measurements.csv') -NoTypeInformation -Encoding UTF8
        Write-Output "MEASURE: trial=$trial workers=$workers elapsed=$($script:lastMilliseconds)ms sources=$($sourceFiles.Count) bytes=$sourceBytes"
    }
}
Write-Output "PASS: concurrent request basics. Evidence: $artifacts"
