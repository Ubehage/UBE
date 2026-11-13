# Verifies UBE-generated checked scalar fragments with independent native assertions.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube native values ' + [guid]::NewGuid())
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
& (Join-Path $root 'bootstrap/tools/llvm-templates.ps1')
$files = @('BufferPrimitives','FilePrimitives','FileBytes','ByteText','Utf8') | ForEach-Object { Join-Path $root ('std-lib/src/portable/'+$_+'.bas') }
$files += @('SourceScanner','SyntaxTokens','ConstantValues','LLVMWriter','LLVMTemplates','LLVMFormat','NativeEmission','NativeValues') | ForEach-Object { Join-Path $root ('compiler/src/'+$_+'.bas') }
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
    if($f[5] -eq '13' -and $f[1] -in @('function','sub')) {$symbols[$f[2]]=$f[0]}
}
foreach($name in @('ConfigurePath','SetPathByte','Emit','CheckFailures')) {Require ($symbols.ContainsKey($name)) "Missing $name"}
$emitted=[IO.File]::ReadAllText($library,$utf8)
$catalog=Join-Path $root 'compiler/llvm/templates.bin'
$specs=New-Object Collections.Generic.List[object]
# Independent public type codes and guard expectations, not values derived from emitted instructions.
foreach($source in @(153,154,155,156,157)) {
    foreach($destination in @(153,154,155,156,157)) {
        $guard=0
        if($destination -eq 154 -and $source -ne 154){$guard=-1}
        if($destination -eq 155 -and $source -gt 155){$guard=-1}
        if($destination -eq 156 -and $source -gt 156){$guard=-1}
        $specs.Add(@(0,$source,$destination,$guard))
    }
}
foreach($type in @(155,156,157)){foreach($op in @(1,2)){$specs.Add(@($op,$type,0,-1))}}
foreach($type in @(153,154,155,156,157)){$specs.Add(@(3,$type,0,0))}
$specs.Add(@(4,0,0,0));$specs.Add(@(5,0,0,0))

# Builds a runtime driver that asks actual UBE helpers to write each fragment.
function Emit-Fragments([string]$Level) {
    $lines=New-Object Collections.Generic.List[string]
    $lines.Add('@test.ctx = private global %ube.context zeroinitializer, align 8')
    $lines.Add('define i32 @main() {');$lines.Add('entry:')
    $lines.Add('  call void @ube.context.init(ptr @test.ctx)')
    $lines.Add('  %init = call i1 @ube.project.init(ptr @test.ctx)')
    $paths=New-Object Collections.Generic.List[string]
    for($n=0;$n -lt $specs.Count;$n++) {
        $path=Join-Path $artifacts ("fragment-$Level-$n.ll");$paths.Add($path)
        $names=@($path,$catalog)
        for($p=0;$p -lt 2;$p++) {
            $bytes=$utf8.GetBytes($names[$p])
            $lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.ctx, i64 {1}, i64 {2})' -f $symbols['ConfigurePath'],$p,$bytes.Length))
            for($i=0;$i -lt $bytes.Length;$i++) {$lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.ctx, i64 {1}, i64 {2}, i64 {3})' -f $symbols['SetPathByte'],$p,$i,$bytes[$i]))}
        }
        $s=$specs[$n]
        $lines.Add(('  %r{0} = call {{ i1, i64 }} @ube.proc.{1}(ptr @test.ctx, i64 {2}, i64 {3}, i64 {4}, i64 {5})' -f $n,$symbols['Emit'],$s[0],$s[1],$s[2],$s[3]))
        $lines.Add("  %fresh$n = extractvalue { i1, i64 } %r$n, 0")
        $lines.Add("  %value$n = extractvalue { i1, i64 } %r$n, 1")
        $lines.Add("  %zero$n = icmp eq i64 %value$n, 0")
        $lines.Add("  %ok$n = and i1 %fresh$n, %zero$n")
        $lines.Add("  br i1 %ok$n, label %next$n, label %bad$n")
        $lines.Add("bad${n}:");$lines.Add(('  ret i32 '+($n+1)));$lines.Add("next${n}:")
    }
    $lines.Add(('  %failures = call {{ i1, i64 }} @ube.proc.{0}(ptr @test.ctx)' -f $symbols['CheckFailures']))
    $lines.Add('  %failure.fresh = extractvalue { i1, i64 } %failures, 0')
    $lines.Add('  %failure.code = extractvalue { i1, i64 } %failures, 1')
    $lines.Add('  %failure.zero = icmp eq i64 %failure.code, 0')
    $lines.Add('  %failure.ok = and i1 %failure.fresh, %failure.zero')
    $lines.Add('  %disposed = call i1 @ube.context.dispose(ptr @test.ctx)')
    $lines.Add('  %all.ok = and i1 %disposed, %failure.ok')
    $lines.Add('  %exit = select i1 %all.ok, i32 0, i32 100');$lines.Add('  ret i32 %exit');$lines.Add('}')
    $ir=Join-Path $artifacts "driver-$Level.ll";$exe=Join-Path $artifacts "driver-$Level.exe"
    Write-Text $ir ($emitted+($lines-join "`r`n"))
    Build-Harness $ir $exe $Level
    $result=Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Actual UBE helper emission failed $Level code $($result.ExitCode): $($result.Evidence)"
    return ,$paths
}

# Independent extrema and results remain exact decimal strings throughout fixture construction.
$minimum=@{153='-1';154='0';155='-32768';156='-2147483648';157='-9223372036854775808'}
$maximum=@{153='0';154='255';155='32767';156='2147483647';157='9223372036854775807'}
$vectors=New-Object Collections.Generic.List[object]
for($n=0;$n -lt $specs.Count;$n++) {
    $s=$specs[$n];$op=$s[0];$type=$s[1];$target=$s[2]
    if($op -eq 0) {
        foreach($inputValue in @($minimum[$type],$maximum[$type],'0')) {
            $x=[decimal]::Parse($inputValue);$ok=$true;$expected=$inputValue
            if($target -eq 153){$expected='0';if($x -ne 0){$expected='-1'}}
            else {$ok=$x -ge [decimal]::Parse($minimum[$target]) -and $x -le [decimal]::Parse($maximum[$target])}
            $vectors.Add(@($n,$inputValue,'0',$ok,$expected))
        }
    } elseif($op -eq 1 -or $op -eq 2) {
        $vectors.Add(@($n,'12','5',$true, $(if($op -eq 1){'17'}else{'7'})))
        $vectors.Add(@($n,$maximum[$type],$(if($op -eq 1){'1'}else{'-1'}),$false,'0'))
        $vectors.Add(@($n,$minimum[$type],$(if($op -eq 1){'-1'}else{'1'}),$false,'0'))
        $vectors.Add(@($n,$minimum[$type],'0',$true,$minimum[$type]))
        if($op -eq 2){$vectors.Add(@($n,'0',$minimum[$type],$false,'0'))}
    } elseif($op -eq 3) {
        foreach($inputValue in @($minimum[$type],$maximum[$type],'0')) {
            $x=[decimal]::Parse($inputValue);$expected=(-1-$x).ToString([Globalization.CultureInfo]::InvariantCulture)
            if($type -eq 154){$expected=(255-$x).ToString([Globalization.CultureInfo]::InvariantCulture)}
            $vectors.Add(@($n,$inputValue,'0',$true,$expected))
        }
    } else {$expected=$minimum[157];if($op -eq 5){$expected=$maximum[157]};$vectors.Add(@($n,'0','0',$true,$expected))}
}

foreach($level in @('O0','O2')) {
    $paths=Emit-Fragments $level
    $text=''
    foreach($width in @(16,32,64)){foreach($operation in @('sadd','ssub')){$text+="declare { i$width, i1 } @llvm.$operation.with.overflow.i${width}(i$width, i$width)`r`n"}}
    for($n=0;$n -lt $paths.Count;$n++) {
        $fragment=[IO.File]::ReadAllText($paths[$n],$utf8)
        $text+="define i1 @case$n(ptr %err, ptr %v3, i64 %v1, i64 %v2) {`r`nentry:`r`n"+$fragment+"  ret i1 true`r`nfailure.dispatch:`r`n  ret i1 false`r`n}`r`n"
    }
    $text+="@input = private global i64 12`r`ndefine i32 @main() {`r`nentry:`r`n  %err = alloca i64`r`n  %out = alloca i64`r`n"
    for($i=0;$i -lt $vectors.Count;$i++) {
        $v=$vectors[$i];$expected=$v[4];$errorValue=771;$flag='true'
        if(-not $v[3]){$expected='999';$errorValue=6;$flag='false'}
        $operand=''+$v[1]
        if($operand -eq '12'){$text+="  %runtime$i = load volatile i64, ptr @input`r`n";$operand="%runtime$i"}
        $text+="  store i64 771, ptr %err`r`n  store i64 999, ptr %out`r`n  %status$i = call i1 @case$($v[0])(ptr %err, ptr %out, i64 $operand, i64 $($v[2]))`r`n"
        $text+="  %fresh$i = icmp eq i1 %status$i, $flag`r`n  %result$i = load i64, ptr %out`r`n  %value$i = icmp eq i64 %result$i, $expected`r`n  %sticky$i = load i64, ptr %err`r`n  %error$i = icmp eq i64 %sticky$i, $errorValue`r`n  %both$i = and i1 %fresh$i, %value$i`r`n  %ok$i = and i1 %both$i, %error$i`r`n  br i1 %ok$i, label %next$i, label %bad$i`r`nbad${i}:`r`n  ret i32 $($i+1)`r`nnext${i}:`r`n"
    }
    $text+="  ret i32 0`r`n}`r`n"
    $ir=Join-Path $artifacts "values-$level.ll";$exe=Join-Path $artifacts "values-$level.exe"
    Write-Text $ir $text;Build-Harness $ir $exe $level
    $run=Invoke-BoundedProcess $exe @();Require ($run.ExitCode -eq 0) "Scalar vector $($run.ExitCode) failed at $level : $($run.Evidence)"
    Write-Output "PASS: $($specs.Count) actual UBE fragments, $($vectors.Count) native scalar vectors $level"
    $controlIR=Join-Path $artifacts "changed-$level.ll";$controlExe=Join-Path $artifacts "changed-$level.exe"
    Write-Text $controlIR ($text.Replace('@input = private global i64 12','@input = private global i64 13'));Build-Harness $controlIR $controlExe $level
    $control=Invoke-BoundedProcess $controlExe @();Require ($control.ExitCode -eq 76) "Changed runtime input expected assertion76 got $($control.ExitCode)"
    Write-Output "PASS: exact changed-input assertion 76 $level"
}
Write-Output "PASS: native scalar helpers. Evidence: $artifacts"
