# Checks exact typed constants through runtime-fed native calls and independent expected values.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube constant values ' + [guid]::NewGuid())
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

# Compiles the checked-in constant engine and its actual lexical dependencies.
$core = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$compiler = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src'))
$manifest = Copy-Fixtures 'constant library' @((Join-Path $core 'BufferPrimitives.bas'),(Join-Path $core 'Utf8.bas'),(Join-Path $compiler 'SourceScanner.bas'),(Join-Path $compiler 'SyntaxTokens.bas'),(Join-Path $compiler 'ConstantValues.bas')) '0' 'Library'
$procedures = Read-Procedures $manifest
$ir = Join-Path $artifacts 'constants.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$emitted = [IO.File]::ReadAllText($ir,$utf8)
foreach($level in @('O0','O2')){
    $assembly=Join-Path $artifacts "production-$level.s"
    $result=Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc',('-'+$level),'-S',$ir,'-o',$assembly)
    Require ($result.ExitCode -eq 0) "Production assembly generation failed: $($result.Evidence)"
    Require ([IO.File]::ReadAllText($assembly,$utf8) -notmatch '__chkstk') "Production $level unexpectedly requires a CRT stack probe"
    Write-Output "PASS: unchanged production $level assembly has no __chkstk dependency"
}
$cases = New-Object Collections.Generic.List[object]
# Explicit public codes are an independent contract oracle, not values read from the implementation.
$Bool=153;$Byte=154;$Integer=155;$Long=156;$LongLong=157
function Literal([string]$Text,[int]$Context,[bool]$Negated,[string]$Value,[int]$Type,[int]$Reason=0){$cases.Add(@{Kind='Literal';Text=$Text;Context=$Context;Negated=$Negated;Value=$Value;Type=$Type;Reason=$Reason})}
function Unary([int]$Op,[string]$InputValue,[int]$InputType,[string]$Value,[int]$Type,[int]$Reason=0){$cases.Add(@{Kind='Unary';Op=$Op;Input=$InputValue;InputType=$InputType;Value=$Value;Type=$Type;Reason=$Reason})}
function Binary([int]$Op,[string]$A,[int]$AT,[string]$B,[int]$BT,[string]$Value,[int]$Type,[int]$Reason=0){$cases.Add(@{Kind='Binary';Op=$Op;A=$A;AT=$AT;B=$B;BT=$BT;Value=$Value;Type=$Type;Reason=$Reason})}
function Convert-Constant([string]$InputValue,[int]$From,[int]$To,[string]$Value,[int]$Reason=0){$cases.Add(@{Kind='Convert';Input=$InputValue;From=$From;To=$To;Value=$Value;Type=456;Reason=$Reason})}
Literal '0' 0 $false '0' $Long
Literal '255' $Byte $false '255' $Byte
Literal '256' $Byte $false '256' $Integer
Literal '1' $Byte $true '-1' $Integer
Literal '32767' $Integer $false '32767' $Integer
Literal '32768' $Integer $false '32768' $Long
Literal '32768%' $LongLong $true '-32768' $Integer
Literal '32768%' $LongLong $false '0' 0 2
Literal '2147483647' 0 $false '2147483647' $Long
Literal '2147483648' 0 $false '2147483648' $LongLong
Literal '2147483648&' $LongLong $true '-2147483648' $Long
Literal '2147483648&' $LongLong $false '0' 0 2
Literal '9223372036854775807^' 0 $false '9223372036854775807' $LongLong
Literal '9223372036854775808' 0 $true '-9223372036854775808' $LongLong
Literal '9223372036854775808' 0 $false '0' 0 2
Literal '9223372036854775809' 0 $true '0' 0 2
Literal '9999999999999999999999999' 0 $false '0' 0 2
Literal '000000000000000000000001' $LongLong $false '1' $LongLong
foreach($text in @('&HFF','&O77','1.5','1E2','1!','^','9999999999999999999999E2')){Literal $text 0 $false '0' 0 1}
Literal '9' 0 $false '0' 0 3
$cases[$cases.Count-1].Start=-1
Literal '9' 0 $false '0' 0 3
$cases[$cases.Count-1].Length=2
Literal '9' 0 $false '0' 0 3
$cases[$cases.Count-1].Length=0
Literal '9' 0 $false '0' 0 1
$cases[$cases.Count-1].TokenKind=8
foreach($lower in @(1,-1)){
    Literal '90' 0 $false '0' 0 3
    $cases[$cases.Count-1].Lower=$lower
    $cases[$cases.Count-1].ExpectedFresh=$false
    $cases[$cases.Count-1].ErrorNumber=9
}
Unary 17 '-9223372036854775808' $LongLong '0' 0 2
Unary 17 '9223372036854775807' $LongLong '-9223372036854775807' $LongLong
Unary 17 '-2147483648' $Long '0' 0 2
Unary 17 '-32768' $Integer '0' 0 2
Unary 17 '255' $Byte '-255' $Integer
Unary 16 '255' $Byte '255' $Integer
Unary 139 '255' $Byte '-256' $Integer
Unary 139 '-9223372036854775808' $LongLong '9223372036854775807' $LongLong
Unary 139 '-1' $Bool '0' $Bool
Unary 139 '0' $Bool '-1' $Bool
Unary 17 '-1' $Bool '0' 0 1
foreach($range in @(@($Integer,'32767','-32768'),@($Long,'2147483647','-2147483648'),@($LongLong,'9223372036854775807','-9223372036854775808'))){
    $t=[int]$range[0];$hi=$range[1];$lo=$range[2]
    Binary 16 $hi $t '1' $t '0' 0 2
    Binary 16 $lo $t '-1' $t '0' 0 2
    Binary 17 $lo $t '1' $t '0' 0 2
    Binary 17 $hi $t '-1' $t '0' 0 2
    Binary 17 $lo $t $lo $t '0' $t
    Binary 16 $lo $t $hi $t '-1' $t
    Binary 135 $lo $t $hi $t '0' $t
    Binary 137 $lo $t $hi $t '-1' $t
}
Binary 16 '255' $Byte '255' $Byte '510' $Integer
Binary 16 '2147483647' $Long '1' $LongLong '2147483648' $LongLong
Binary 135 '-1' $Bool '0' $Bool '0' $Bool
Binary 137 '-1' $Bool '0' $Bool '-1' $Bool
Binary 15 '-1' $Bool '-1' $Bool '-1' $Bool
Binary 22 '-1' $Bool '0' $Bool '-1' $Bool
Binary 18 '-1' $Bool '0' $Bool '0' 0 1
Binary 135 '-1' $Bool '1' $Long '0' 0 1
foreach($op in @(15,22,18,19,20,21)){
    $v='0';if($op -in @(22,18,20)){$v='-1'}
    Binary $op '-9223372036854775808' $LongLong '9223372036854775807' $LongLong $v $Bool
}
Convert-Constant '-1' $Bool $Byte '0' 2
Convert-Constant '0' $Bool $Byte '0'
Convert-Constant '-1' $Bool $LongLong '-1'
Convert-Constant '-9223372036854775808' $LongLong $Bool '-1'
Convert-Constant '0' $LongLong $Bool '0'
foreach($range in @(@($Byte,'255','256','-1'),@($Integer,'32767','32768','-32769'),@($Long,'2147483647','2147483648','-2147483649'))){
    Convert-Constant $range[1] $LongLong ([int]$range[0]) $range[1]
    Convert-Constant $range[2] $LongLong ([int]$range[0]) '0' 2
    Convert-Constant $range[3] $LongLong ([int]$range[0]) '0' 2
}
Convert-Constant '1' $Bool $Long '0' 3
Unary 16 '256' $Byte '0' 0 3
Binary 16 '1' 999 '1' $Long '0' 0 3

$globals = '@test.context = private global %ube.context zeroinitializer' + "`r`n"
$body = @('define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0','  call void @ube.context.init(ptr %ctx)','  %init = call i1 @ube.project.init(ptr %ctx)','  %err = getelementptr %ube.context, ptr %ctx, i32 0, i32 0','  %value = alloca i64','  %type = alloca i64','  %reason = alloca i64','  br i1 %init, label %case1, label %failed.init','failed.init:','  ret i32 10000')
$index=0
$wrappers=@{}
foreach($case in $cases){
    $index++;$prefix='c'+$index
    $body+=@("case${index}:",'  store i64 77, ptr %err','  store i64 123, ptr %value','  store i64 456, ptr %type','  store i64 789, ptr %reason')
    $args=@('ptr %ctx')
    if($case.Kind -eq 'Literal'){
        $bytes=$utf8.GetBytes($case.Text)
        $lower=0;if($case.ContainsKey('Lower')){$lower=$case.Lower}
        $start=0;if($case.ContainsKey('Start')){$start=$case.Start}
        $length=$bytes.Count;if($case.ContainsKey('Length')){$length=$case.Length}
        $tokenKind=3;if($case.ContainsKey('TokenKind')){$tokenKind=$case.TokenKind}
        $globals+=('@'+$prefix+'.bytes = global ['+$bytes.Count+' x i64] ['+(($bytes|ForEach-Object{'i64 '+$_})-join ', ')+']')+"`r`n"
        $globals+=('@'+$prefix+'.source = global {i64,i64,ptr,ptr} {i64 '+$lower+',i64 '+($lower+$bytes.Count-1)+',ptr @'+$prefix+'.bytes,ptr null}')+"`r`n"
        $globals+=('@'+$prefix+'.token = global [7 x i64] [i64 '+$tokenKind+',i64 '+$start+',i64 '+$length+',i64 1,i64 1,i64 1,i64 '+$bytes.Count+']')+"`r`n"
        if($index -eq 1){$body+=@('  %control = load volatile i64, ptr @test.control','  store i64 %control, ptr @c1.bytes')}
        $neg=0;if($case.Negated){$neg=-1}
        $args+=@("ptr @$prefix.source","ptr @$prefix.token",('i64 '+$case.Context),"i64 $neg")
    } elseif($case.Kind -eq 'Unary'){$args+=@(('i64 '+$case.Op),('i64 '+$case.Input),('i64 '+$case.InputType))
    } elseif($case.Kind -eq 'Binary'){$args+=@(('i64 '+$case.Op),('i64 '+$case.A),('i64 '+$case.AT),('i64 '+$case.B),('i64 '+$case.BT))
    } else {$args+=@(('i64 '+$case.Input),('i64 '+$case.From),('i64 '+$case.To))}
    $args+='ptr %value';if($case.Kind -ne 'Convert'){$args+='ptr %type'};$args+='ptr %reason'
    # One opaque test call boundary per API prevents ninety independent probes inflating main's stack after inlining.
    if(-not $wrappers.ContainsKey($case.Kind)){
        $formals=@();$argumentIndex=0
        foreach($argument in $args){$formals+=($argument.Split(' ')[0]+' %a'+$argumentIndex);$argumentIndex++}
        $signature=$formals -join ','
        $globals+="define {i1,i64} @test.call.$($case.Kind)($signature) noinline {`r`n  %result = call {i1,i64} @ube.proc.$($procedures['Try'+$case.Kind])($signature)`r`n  ret {i1,i64} %result`r`n}`r`n"
        $wrappers[$case.Kind]=$true
    }
    $status=-1;$value=$case.Value;$type=$case.Type
    if($case.Reason -ne 0){$status=0;$value='123';$type=456}
    $body+=@(("  %$prefix.result = call {i1,i64} @test.call.$($case.Kind)("+($args -join ',')+')'),"  %$prefix.fresh = extractvalue {i1,i64} %$prefix.result, 0","  %$prefix.status = extractvalue {i1,i64} %$prefix.result, 1","  %$prefix.status.ok = icmp eq i64 %$prefix.status, $status")
    foreach($field in @('value','type','reason','err')){
        $expected=77;if($case.ContainsKey('ErrorNumber')){$expected=$case.ErrorNumber};if($field -eq 'value'){$expected=$value};if($field -eq 'type'){$expected=$type};if($field -eq 'reason'){$expected=$case.Reason}
        $body+=@("  %$prefix.$field = load i64, ptr %$field","  %$prefix.$field.ok = icmp eq i64 %$prefix.$field, $expected")
    }
    $fresh='true';if($case.ContainsKey('ExpectedFresh') -and -not $case.ExpectedFresh){$fresh='false'}
    $body+=@("  %$prefix.fresh.ok = icmp eq i1 %$prefix.fresh, $fresh","  %$prefix.a = and i1 %$prefix.fresh.ok, %$prefix.status.ok","  %$prefix.b = and i1 %$prefix.value.ok, %$prefix.type.ok","  %$prefix.c = and i1 %$prefix.reason.ok, %$prefix.err.ok","  %$prefix.d = and i1 %$prefix.a, %$prefix.b","  %$prefix.ok = and i1 %$prefix.d, %$prefix.c")
    $next='done';if($index -lt $cases.Count){$next='case'+($index+1)}
    $body+=@("  br i1 %$prefix.ok, label %$next, label %failed.$index","failed.${index}:","  ret i32 $index")
}
$body+=@('done:','  %disposed = call i1 @ube.context.dispose(ptr %ctx)','  %exit = select i1 %disposed, i32 0, i32 10001','  ret i32 %exit','}')
foreach($seed in @(48,49)){
    # The large assertion driver is not production code; optimize the called compiler procedures, not its assertion graph.
    $combined=Join-Path $artifacts "constants-$seed.ll"
    Write-Text $combined ($emitted+"`r`n"+$globals+"@test.control = global i64 $seed`r`n"+($body-join "`r`n").Replace('define i32 @main() {','define i32 @main() noinline optnone {'))
    foreach($level in @('O0','O2')){
        $exe=Join-Path $artifacts "constants-$seed-$level.exe"
        Build-Harness $combined $exe $level
        $result=Invoke-BoundedProcess $exe @()
        $expected=0;if($seed -eq 49){$expected=1}
        Require ($result.ExitCode -eq $expected) "Constants $seed $level expected $expected got $($result.ExitCode): $($result.Evidence)"
        Write-Output "PASS: constants $seed $level ($($cases.Count) authored vectors; control exit $expected)"
    }
}
Write-Output "PASS: exact constants O0/O2 and both runtime controls. Evidence: $artifacts"
