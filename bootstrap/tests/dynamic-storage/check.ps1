# Verifies dynamic value storage, replacement publication and pinned call aliases.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$LoweredIR = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube dynamic storage ' + [guid]::NewGuid())
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

# Wraps a body in its native module envelope and normalizes physical newlines.
function Module-Text([string]$Name, [string]$Body) {
    return "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"$Name`"`r`n" + $Body.Replace("`r`n", "`n").Replace("`n", "`r`n")
}

# Creates an ordered Library manifest and isolated source modules for one case.
function New-Fixture([string]$Name, [string[]]$Bodies, [string[]]$ModuleNames = @('Example'), [string]$ProjectKind = 'Library') {
    $folder = Join-Path $artifacts $Name
    $lines = @('UBE-Project 1', 'Name = "SemanticFixture"', ('Kind = "' + $ProjectKind + '"'))
    if ($ProjectKind -eq 'Exe') { $lines += 'Startup = "Main"' }
    for ($i = 0; $i -lt $Bodies.Count; $i++) {
        $file = $ModuleNames[$i] + '.bas'
        Write-Text (Join-Path $folder $file) (Module-Text $ModuleNames[$i] $Bodies[$i])
        $lines += 'Source = "' + $file + '"'
    }
    $manifest = Join-Path $folder 'project.UBE'
    Write-Text $manifest (($lines -join "`r`n") + "`r`n")
    return $manifest
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

# Requires controlled failure and verifies an existing valid artifact is unchanged.
function Assert-PreservedFailure([string]$Name, [string[]]$Arguments, [string]$Code, [string]$Artifact, [int]$TimeoutMilliseconds = 30000) {
    $before = (Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash
    $result = Invoke-BoundedProcess $BootstrapExe $Arguments $TimeoutMilliseconds
    Require ($result.ExitCode -eq 1 -and $result.Stderr -match ('(?m)^UBE: ' + [regex]::Escape($Code) + ':') -and $result.Stdout -notmatch '(?m)^(BUILD OK|EMIT OK)\r?$') "$Name failure mismatch. Evidence: $($result.Evidence)"
    Require ((Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash -ceq $before) "$Name changed prior artifact"
    $script:passed++
    Write-Output "PASS: $Name preserves prior artifact"
}

# Resolves compiler-owned procedure identifiers from the unchanged bound dump.
function Read-Procedures([string]$Manifest) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$Manifest)
    Require ($result.ExitCode -eq 0) "Binding failed: $($result.Evidence)"
    $procedures = @{}
    foreach ($line in $result.Stdout.Split("`n")) {
        if ($line.StartsWith('SYMBOL ')) {
            $fields = $line.TrimEnd("`r").Substring(7).Split('|')
            Require ($fields.Count -eq 24) 'Unexpected bound symbol framing'
            if ($fields[1] -eq 'function') { $procedures[$fields[2]] = [int]$fields[0] }
        }
    }
    return $procedures
}

# Replaces only target wrapper definitions; production allocation algorithms stay intact.
function Add-AllocatorObserver([string]$Text) {
    foreach ($name in @('allocate','release')) {
        $pattern = '(?m)^(define[^\r\n@]*?)@ube\.target\.' + $name + '\('
        Require ([regex]::Matches($Text,$pattern).Count -eq 1) "Missing unique target wrapper $name"
        $Text = [regex]::Replace($Text,$pattern,('${1}@test.real.' + $name + '('))
    }
    return $Text + "`r`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures/AllocatorObserver.ll'),$utf8)
}

$coreDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$manifest = Copy-Fixtures 'dynamic library' @((Join-Path $coreDirectory 'BufferPrimitives.bas'),(Join-Path $PSScriptRoot 'fixtures/DynamicProbe.bas'),(Join-Path $PSScriptRoot 'fixtures/AllocationProbe.bas'),(Join-Path $PSScriptRoot 'fixtures/QuotaProbe.bas'),(Join-Path $PSScriptRoot 'fixtures/ArgumentProbe.bas')) '0' 'Library'
$procedures = Read-Procedures $manifest
if ($LoweredIR) {
    # Compiler-owned identities differ; map only unique first source statements in the identical corpus.
    $reference = Join-Path $artifacts 'bootstrap-reference.ll'
    $null = Invoke-Compiler @('--emit-llvm',$manifest,$reference) 'EMIT OK'
    $referenceText = [IO.File]::ReadAllText($reference,$utf8)
    $nativeText = [IO.File]::ReadAllText($LoweredIR,$utf8)
    $locations = @{}
    foreach ($definition in [regex]::Matches($nativeText,'(?ms)^define \{ i1, i64 \} @ube\.proc\.(\d+)\([^\r\n]*\) \{(.*?)^\}')) {
        $location = [regex]::Match($definition.Groups[2].Value,'; module (\d+), node \d+, line (\d+), column (\d+)')
        if ($location.Success) {
            $key = $location.Groups[1].Value + ':' + $location.Groups[2].Value + ':' + $location.Groups[3].Value
            Require (-not $locations.ContainsKey($key)) 'Ambiguous native procedure source location'
            $locations[$key] = [int]$definition.Groups[1].Value
        }
    }
    foreach ($name in @($procedures.Keys)) {
        $definition = [regex]::Match($referenceText,('(?ms)^define \{ i1, i64 \} @ube\.proc\.' + $procedures[$name] + '\([^\r\n]*\) \{(.*?)^\}'))
        $location = [regex]::Match($definition.Groups[1].Value,'; source module=(\d+) line=(\d+) column=(\d+)')
        if ($location.Success) {
            $key = $location.Groups[1].Value + ':' + $location.Groups[2].Value + ':' + $location.Groups[3].Value
            Require ($locations.ContainsKey($key)) "Missing native procedure location for $name"
            $procedures[$name] = $locations[$key]
        }
    }
}
$ir = Join-Path $artifacts 'dynamic-storage.ll'
if ($LoweredIR) { Copy-Item -LiteralPath $LoweredIR -Destination $ir } else { $null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK' }
$again = Join-Path $artifacts 'dynamic-storage-again.ll'
if (-not $LoweredIR) {
    $null = Invoke-Compiler @('--emit-llvm',$manifest,$again) 'EMIT OK'
    Require ((Get-FileHash $ir).Hash -eq (Get-FileHash $again).Hash) 'Emission must be deterministic'
    $script:passed++
}
$observed = Add-AllocatorObserver ([IO.File]::ReadAllText($ir,$utf8))
$cases = @(
    @{Name='CheckByValRecord'; Prepare=$false; Fail=0; Quota=0; Calls=-1},
    @{Name='CheckByValArray'; Prepare=$false; Fail=0; Quota=0; Calls=-1},
    @{Name='CheckByValPinnedRecord'; Prepare=$false; Fail=0; Quota=0; Calls=-1},
    @{Name='CheckByValCopyFailure'; Prepare=$true; Setup='PrepareArguments'; Fail=2; Quota=0; Calls=3},
    @{Name='CheckByValSecondCopyFailure'; Prepare=$true; Setup='PrepareArguments'; Fail=0; Quota=2; Calls=4},
    @{Name='CheckByValLaterFailure'; Prepare=$true; Setup='PrepareArguments'; Fail=0; Quota=2; Calls=2},
    @{Name='CheckByValDepthFailure'; Prepare=$true; Setup='PrepareArguments'; Fail=0; Quota=0; Calls=1},
    @{Name='CheckHeapQuota'; Prepare=$false; Fail=0; Quota=0; Calls=15},
    @{Name='CheckSourceBuffer'; Prepare=$false; Fail=0; Quota=0; Calls=-1},
    @{Name='CheckValues'; Prepare=$false; Fail=0; Quota=0; Calls=-1},
    @{Name='CheckPins'; Prepare=$false; Fail=0; Quota=0; Calls=-1},
    @{Name='CheckIndexCapture'; Prepare=$false; Fail=0; Quota=0; Calls=-1},
    @{Name='CheckCleanup'; Prepare=$false; Fail=0; Quota=0; Calls=-1},
    @{Name='CheckCounts'; Prepare=$true; Fail=0; Quota=0; Calls=0},
    @{Name='CheckRejectedResize'; Prepare=$true; Fail=2; Quota=0; Calls=2},
    @{Name='CheckRetry'; Prepare=$true; Fail=1; Quota=0; Calls=2},
    @{Name='CheckRejectedCopy'; Prepare=$true; Fail=2; Quota=0; Calls=2},
    @{Name='CheckAssignmentFailure'; Prepare=$true; Fail=2; Quota=0; Calls=2},
    @{Name='CheckRejectedResize'; Prepare=$true; Fail=0; Quota=2; Calls=2}
)
foreach ($case in $cases) {
    $stem = $case.Name + '-' + $case.Fail + '-' + $case.Quota
    $harness = @('@test.input = global i64 1','@test.context = private global %ube.context zeroinitializer, align 8','define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0','  call void @ube.context.init(ptr %ctx)','  %init = call i1 @ube.project.init(ptr %ctx)','  %seed = load volatile i64, ptr @test.input')
    if ($case.Prepare) {
        $setupName = 'Prepare'
        if ($case.ContainsKey('Setup')) { $setupName = $case.Setup }
        $harness += @("  %setup = call { i1, i64 } @ube.proc.$($procedures[$setupName])(ptr %ctx, i64 %seed)",'  %setup.ok = extractvalue { i1, i64 } %setup, 0','  %setup.value = extractvalue { i1, i64 } %setup, 1','  %setup.zero = icmp eq i64 %setup.value, 0','  %setup.good = and i1 %setup.ok, %setup.zero','  %started = and i1 %init, %setup.good')
    } else { $harness += '  %started = and i1 %init, true' }
    if ($case.Name -eq 'CheckByValDepthFailure') { $harness += @('  %depth.ptr = getelementptr %ube.thread, ptr %ctx, i32 0, i32 1','  store atomic i64 255, ptr %depth.ptr monotonic, align 8') }
    $harness += @('  store i64 0, ptr @test.alloc.calls',"  store i64 $($case.Fail), ptr @test.fail.remaining", "  store i64 $($case.Quota), ptr @test.max.live", "  %result = call { i1, i64 } @ube.proc.$($procedures[$case.Name])(ptr %ctx, i64 %seed)",'  %ok = extractvalue { i1, i64 } %result, 0','  %value = extractvalue { i1, i64 } %result, 1','  %zero = icmp eq i64 %value, 0','  %good = and i1 %ok, %zero','  %calls = load i64, ptr @test.alloc.calls')
    if ($case.Name -eq 'CheckByValDepthFailure') { $harness += '  store atomic i64 0, ptr %depth.ptr monotonic, align 8' }
    if ($case.Calls -ge 0) { $harness += "  %attempts = icmp eq i64 %calls, $($case.Calls)" } else { $harness += '  %attempts = icmp uge i64 %calls, 0' }
    $harness += @('  %disposed = call i1 @ube.context.dispose(ptr %ctx)','  %live = load i64, ptr @test.live','  %clean = icmp eq i64 %live, 0','  %a = and i1 %started, %good','  %b = and i1 %attempts, %disposed','  %c = and i1 %a, %b','  %all = and i1 %c, %clean','  %exit = select i1 %all, i32 0, i32 1','  ret i32 %exit','}')
    $combined = Join-Path $artifacts ($stem + '.ll')
    Write-Text $combined ($observed + "`r`n" + ($harness -join "`r`n") + "`r`n")
    foreach ($level in @('O0','O2')) {
        $exe = Join-Path $artifacts ($stem + '-' + $level + '.exe')
        Build-Harness $combined $exe $level
        $result = Invoke-BoundedProcess $exe @()
        Require ($result.ExitCode -eq 0) "$stem $level failed: $($result.Evidence)"
        $script:passed++
        Write-Output "PASS: $stem $level with zero live allocations after disposal"
    }
    if ($case.Name -eq 'CheckIndexCapture') {
        $control = Join-Path $artifacts 'changed-runtime-input.ll'
        Write-Text $control ([IO.File]::ReadAllText($combined,$utf8).Replace('@test.input = global i64 1','@test.input = global i64 2'))
        $controlExe = Join-Path $artifacts 'changed-runtime-input.exe'
        Build-Harness $control $controlExe 'O2'
        $controlResult = Invoke-BoundedProcess $controlExe @()
        Require ($controlResult.ExitCode -eq 1) 'Negative control must detect changed captured bounds'
        $script:passed++
        Write-Output 'PASS: changed volatile input invalidates the captured-bounds observation'
    }
}
$disposeHarness = @'
@test.context = private global %ube.context zeroinitializer, align 8
@test.input = global i64 1
define i32 @main() {
entry:
  %ctx = getelementptr %ube.context, ptr @test.context, i32 0
  call void @ube.context.init(ptr %ctx)
  %init = call i1 @ube.project.init(ptr %ctx)
  %seed = load volatile i64, ptr @test.input
  %setup = call { i1, i64 } @ube.proc.PREPARE(ptr %ctx, i64 %seed)
  %setup.ok = extractvalue { i1, i64 } %setup, 0
  %setup.value = extractvalue { i1, i64 } %setup, 1
  %setup.zero = icmp eq i64 %setup.value, 0
  %setup.good = and i1 %setup.ok, %setup.zero
  store i64 2, ptr @test.release.failures
  %first = call i1 @ube.context.dispose(ptr %ctx)
  %first.false = xor i1 %first, true
  %retained = load i64, ptr @test.live
  %retained.two = icmp eq i64 %retained, 2
  store i64 0, ptr @test.release.failures
  %second = call i1 @ube.context.dispose(ptr %ctx)
  %live = load i64, ptr @test.live
  %clean = icmp eq i64 %live, 0
  %a = and i1 %init, %setup.good
  %b = and i1 %first.false, %retained.two
  %c = and i1 %second, %clean
  %d = and i1 %a, %b
  %all = and i1 %d, %c
  %exit = select i1 %all, i32 0, i32 1
  ret i32 %exit
}
'@
$disposeIR = Join-Path $artifacts 'release-retry.ll'
Write-Text $disposeIR ($observed + "`r`n" + $disposeHarness.Replace('ube.proc.PREPARE',('ube.proc.' + $procedures['Prepare'])))
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ('release-retry-' + $level + '.exe')
    Build-Harness $disposeIR $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Failed release must remain recoverable on later disposal: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: failed target releases retained for later disposal $level"
}

# Requires a source-located semantic rejection without publishing any bound success.
function Assert-Rejected([string]$Name, [string]$Body, [string]$Code) {
    $project = New-Fixture $Name @($Body)
    $result = Invoke-BoundedProcess $BootstrapExe @('--analyze',$project)
    Require ($result.ExitCode -eq 1 -and $result.Stderr -match ('^UBE: ' + $Code + ':') -and $result.Stderr -match 'Example\.bas:\d+:\d+' -and $result.Stdout -notmatch 'ANALYZE OK') "${Name} expected ${Code}: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: $Name"
}
$resize = 'Public Intrinsic Function Grow(ByRef Values() As Byte, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean'
$role = 'Attribute Grow.UBE_Primitive = "Array.TryResize"'
foreach ($case in @(
    @{Name='resize wrong count type'; Header=$resize.Replace('Count As Long','Count As LongLong')},
    @{Name='resize wrong preservation type'; Header=$resize.Replace('Preserve As Boolean','Preserve As Long')},
    @{Name='resize wrong count passing mode'; Header=$resize.Replace('ByVal Count','ByRef Count')},
    @{Name='resize scalar receiver'; Header=$resize.Replace('Values()','Values')}
)) { Assert-Rejected $case.Name ($case.Header + "`n" + $role + "`nEnd Function") 'E_TYPE' }
$copy = 'Public Intrinsic Function Clone(ByRef Destination() As Byte, ByRef Source() As Long) As Boolean'
Assert-Rejected 'copy different element type' ($copy + "`nAttribute Clone.UBE_Primitive = `"Array.TryCopy`"`nEnd Function") 'E_TYPE'
$recordBody = "Public Type FirstRecord`n Value As Long`nEnd Type`nPublic Type SecondRecord`n Value As Long`nEnd Type`nPublic Intrinsic Function Clone(ByRef Destination() As FirstRecord, ByRef Source() As SecondRecord) As Boolean`nAttribute Clone.UBE_Primitive = `"Array.TryCopy`"`nEnd Function"
Assert-Rejected 'copy distinct nominal records' $recordBody 'E_TYPE'
Assert-Rejected 'rank two deferred' "Sub Example()`n Dim Values(0 To 1, 0 To 1) As Long`nEnd Sub" 'E_UNSUPPORTED'
Assert-Rejected 'ReDim syntax deferred' "Sub Example()`n Dim Values() As Long`n ReDim Values(2)`nEnd Sub" 'E_UNSUPPORTED'
$qualified = New-Fixture 'same qualified record identity' @("Public Type Item`n Value As Long`nEnd Type`nPublic Intrinsic Function Clone(ByRef Destination() As Item, ByRef Source() As Example.Item) As Boolean`nAttribute Clone.UBE_Primitive = `"Array.TryCopy`"`nEnd Function")
$null = Invoke-Compiler @('--analyze',$qualified) 'ANALYZE OK'
$script:passed++
$invalid = New-Fixture 'invalid publication' @($recordBody)
Assert-PreservedFailure 'invalid nominal copy binding' @('--emit-llvm',$invalid,$ir) 'E_TYPE' $ir
$nativeProject = New-Fixture 'native import publication' @("Function Main() As Long`n Main = 0`nEnd Function") @('Example') 'Exe'
$nativeOutput = Join-Path $artifacts 'preserved-native.exe'
$null = Invoke-Compiler @('--build',$nativeProject,$nativeOutput,'--clang',$Clang) 'BUILD OK'
Assert-X64 $nativeOutput
$toolDirectory = Join-Path $artifacts 'isolated target tools'
$null = New-Item -ItemType Directory -Path $toolDirectory
$fakeClang = Join-Path $toolDirectory 'clang.exe'
$stubIR = Join-Path $toolDirectory 'stub.ll'
Write-Text $stubIR "define i32 @main() {`nentry:`n ret i32 0`n}`n"
Build-Harness $stubIR $fakeClang 'O0'
Assert-PreservedFailure 'missing native import tool' @('--build',$nativeProject,$nativeOutput,'--clang',$fakeClang) 'E_BACKEND' $nativeOutput
foreach ($status in @(7,0)) {
    Write-Text $stubIR "define i32 @main() {`nentry:`n ret i32 $status`n}`n"
    $fakeImportTool = Join-Path $toolDirectory 'llvm-dlltool.exe'
    Build-Harness $stubIR $fakeImportTool 'O0'
    Assert-PreservedFailure ("invalid native import tool status $status") @('--build',$nativeProject,$nativeOutput,'--clang',$fakeClang) 'E_BACKEND' $nativeOutput
}
Write-Output "PASS: $($script:passed) dynamic storage groups. Evidence: $artifacts"
