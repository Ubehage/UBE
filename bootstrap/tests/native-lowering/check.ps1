# Verifies complete LLVM modules emitted by the UBE compiler from runtime source.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube native lowering ' + [guid]::NewGuid())
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

$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
& (Join-Path $root 'bootstrap/tools/runtime-text.ps1')
& (Join-Path $root 'bootstrap/tools/llvm-templates.ps1')
$core=@('BufferPrimitives','FilePrimitives','FileBytes','ByteText','Utf8') | ForEach-Object {Join-Path $root ('std-lib/src/portable/'+$_+'.bas')}
$compiler=@('SourceScanner','SyntaxTokens','SourceParser','ProjectSyntax','DeclarationBinder','ConstantValues','ExpressionBinder','AggregateLayout','PrimitiveRoles','LLVMWriter','LLVMTemplates','LLVMFormat','NativePlanning','NativeEmission','NativeValues','NativeStorage','NativeExpressions','NativeContext','NativeIntrinsics','NativeFrames','NativeControl','NativeLowering') | ForEach-Object {Join-Path $root ('compiler/src/'+$_+'.bas')}
$files=@($core)+@($compiler)+@(Join-Path $PSScriptRoot 'Probe.bas')
$manifest=Copy-Fixtures 'emitter' $files '0' 'Library'
$library=Join-Path $artifacts 'emitter.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$library) 'EMIT OK'
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) 'Emitter binding failed'
$symbols=@{};$probeModule=($files.Count-1).ToString()
foreach($line in ($bound.Stdout -split '\r?\n')) {
    if($line -notmatch '^SYMBOL ') {continue}
    $f=$line.Substring(7).Split('|')
    if($f[5] -eq $probeModule -and $f[1] -in @('function','sub')) {$symbols[$f[2]]=$f[0]}
}
foreach($name in @('ConfigurePath','SetPathByte','ResetProject','AppendSource','Emit','EntrySymbol','DiagnosticField')) {Require ($symbols.ContainsKey($name)) "Missing driver $name"}
$emitted=[IO.File]::ReadAllText($library,$utf8)
$catalog=Join-Path $root 'compiler/llvm/templates.bin'
$runtime=Join-Path $root 'compiler/llvm/windows-runtime.ll'

# Builds a native driver that reads original sources and runs only the production UBE lowering pipeline.
function Emit-Project([string]$Name,[string[]]$Sources,[string]$Level,[bool]$Executable=$false) {
    $path=Join-Path $artifacts ($Name+'-'+$Level+'.ll')
    $lines=New-Object Collections.Generic.List[string]
    $lines.Add('@test.ctx = private global %ube.context zeroinitializer, align 8')
    $lines.Add('define i32 @main() {');$lines.Add('entry:')
    $lines.Add('  call void @ube.context.init(ptr @test.ctx)')
    $lines.Add('  %init = call i1 @ube.project.init(ptr @test.ctx)')
    $lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.ctx)' -f $symbols['ResetProject']))
    $paths=@(@(0,$path),@(1,$catalog),@(3,$runtime))
    foreach($source in $Sources){$paths+=,@(2,$source)}
    $n=0;$sourceNumber=0
    foreach($item in $paths) {
        $kind=$item[0];$bytes=$utf8.GetBytes($item[1])
        $lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.ctx, i64 {1}, i64 {2})' -f $symbols['ConfigurePath'],$kind,$bytes.Length))
        for($i=0;$i -lt $bytes.Length;$i++){$lines.Add(('  call {{ i1, i64 }} @ube.proc.{0}(ptr @test.ctx, i64 {1}, i64 {2}, i64 {3})' -f $symbols['SetPathByte'],$kind,$i,$bytes[$i]))}
        if($kind -eq 2){
            $lines.Add(('  %append{0} = call {{ i1, i64 }} @ube.proc.{1}(ptr @test.ctx)' -f $n,$symbols['AppendSource']))
            $lines.Add("  %fresh$n = extractvalue { i1, i64 } %append$n, 0")
            $lines.Add("  %value$n = extractvalue { i1, i64 } %append$n, 1")
            $lines.Add("  %zero$n = icmp eq i64 %value$n, 0")
            $lines.Add("  %ok$n = and i1 %fresh$n, %zero$n")
            $lines.Add("  br i1 %ok$n, label %next$n, label %bad$n")
            $lines.Add("bad${n}:");$lines.Add(('  ret i32 '+(-100-$sourceNumber)));$lines.Add("next${n}:")
            $sourceNumber++
        }
        $n++
    }
    $flag=0;if($Executable){$flag=-1}
    $lines.Add(('  %result = call {{ i1, i64 }} @ube.proc.{0}(ptr @test.ctx, i64 {1})' -f $symbols['Emit'],$flag))
    $lines.Add('  %fresh = extractvalue { i1, i64 } %result, 0')
    $lines.Add('  %value = extractvalue { i1, i64 } %result, 1')
    $lines.Add('  %zero = icmp eq i64 %value, 0')
    $lines.Add('  %complete = and i1 %fresh, %zero')
    $lines.Add(('  %identity = call {{ i1, i64 }} @ube.proc.{0}(ptr @test.ctx)' -f $symbols['EntrySymbol']))
    $lines.Add('  %symbol = extractvalue { i1, i64 } %identity, 1')
    $lines.Add('  %disposed = call i1 @ube.context.dispose(ptr @test.ctx)')
    $lines.Add('  %good = and i1 %complete, %disposed')
    $lines.Add('  %negative = sub i64 0, %value')
    foreach($d in @(0,2,3)){
        $lines.Add(('  %diagnostic{0} = call {{ i1, i64 }} @ube.proc.{1}(ptr @test.ctx, i64 {0})' -f $d,$symbols['DiagnosticField']))
        $lines.Add("  %diagnostic.value$d = extractvalue { i1, i64 } %diagnostic$d, 1")
    }
    $lines.Add('  %code.shift = mul i64 %diagnostic.value0, 128')
    $lines.Add('  %module = add i64 %diagnostic.value2, 1')
    $lines.Add('  %code.module = add i64 %code.shift, %module')
    $lines.Add('  %line.shift = mul i64 %code.module, 65536')
    $lines.Add('  %located = add i64 %line.shift, %diagnostic.value3')
    $lines.Add('  %located.negative = sub i64 0, %located')
    $lines.Add('  %has.diagnostic = icmp ne i64 %diagnostic.value0, 0')
    $lines.Add('  %detail = select i1 %has.diagnostic, i64 %located.negative, i64 %negative')
    $lines.Add('  %failure = select i1 %zero, i64 -1, i64 %detail')
    $lines.Add('  %exit64 = select i1 %good, i64 %symbol, i64 %failure')
    $lines.Add('  %exit = trunc i64 %exit64 to i32');$lines.Add('  ret i32 %exit');$lines.Add('}')
    $ir=$path+'.driver.ll';$exe=$path+'.driver.exe'
    Write-Text $ir ($emitted+($lines-join "`r`n"));Build-Harness $ir $exe $Level
    $run=Invoke-BoundedProcess $exe @() 60000
    $minimum=1;if($Executable){$minimum=0}
    $detail='';if($run.ExitCode -lt -65536){$packed=-[long]$run.ExitCode;$line=$packed % 65536;$high=[math]::Floor($packed/65536);$module=$high % 128-1;$code=[math]::Floor($high/128);$detail=" diagnosticCode=$code module=$module line=$line"}
    Require ($run.ExitCode -ge $minimum -and $run.ExitCode -lt 16384) "UBE lowering $Name failed code $($run.ExitCode)$detail : $($run.Evidence)"
    Require (Test-Path -LiteralPath $path) 'UBE lowering did not write output'
    return [pscustomobject]@{Path=$path;Text=[IO.File]::ReadAllText($path,$utf8);Entry=$run.ExitCode}
}

# Runs one fully UBE-emitted library through its source-level bridge using a volatile runtime seed.
function Execute-Library($Output,[string]$Name,[string]$Level,[int]$Seed=1,[int]$Expected=0) {
    $tail=@"
@test.seed = private global i64 $Seed
@test.ctx = private global %ube.context zeroinitializer, align 8
define i32 @main() {
entry:
  call void @ube.context.init(ptr @test.ctx)
  %init = call i1 @ube.project.init(ptr @test.ctx)
  %seed = load volatile i64, ptr @test.seed
  %pair = call { i1, i64 } @ube.proc.$($Output.Entry)(ptr @test.ctx, i64 %seed)
  %fresh = extractvalue { i1, i64 } %pair, 0
  %value = extractvalue { i1, i64 } %pair, 1
  %disposed = call i1 @ube.context.dispose(ptr @test.ctx)
  %started = and i1 %init, %fresh
  %good = and i1 %started, %disposed
  %code = trunc i64 %value to i32
  %exit = select i1 %good, i32 %code, i32 9999
  ret i32 %exit
}
"@
    $ir=Join-Path $artifacts ($Name+'-native-'+$Level+'.ll');$exe=Join-Path $artifacts ($Name+'-native-'+$Level+'.exe')
    Write-Text $ir ($Output.Text+"`r`n"+$tail);Build-Harness $ir $exe $Level
    $run=Invoke-BoundedProcess $exe @() 60000
    Require ($run.ExitCode -eq $Expected) "Generated $Name $Level expected$Expected got$($run.ExitCode): $($run.Evidence)"
    Write-Output "PASS: fully UBE-generated $Name $Level exit$Expected"
}

$fixtures=@(
 'integer-types/fixtures/IntegerProbe.bas',
 'aggregate-storage/fixtures/StorageProbe.bas',
 'aggregate-storage/fixtures/QuotedTypes.bas',
 'dynamic-storage/fixtures/DynamicProbe.bas',
 'counted-buffers/fixtures/BufferProbe.bas',
 'file-io/fixtures/FileProbe.bas',
 'source-scanning/ControlFlowProbe.bas'
) | ForEach-Object {Join-Path $root ('bootstrap/tests/'+$_)}
$types=@('Byte','Integer','Long','LongLong','Boolean')
$matrix="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"ConversionMatrix`"`r`n"
foreach($source in $types){foreach($destination in $types){$matrix+="Public Function From${source}To${destination}(ByVal Value As $source) As $destination`r`nFrom${source}To${destination} = Value`r`nEnd Function`r`n"}}
foreach($destination in $types){$matrix+="Public Function Echo${destination}(ByVal Value As $destination) As $destination`r`nEcho${destination} = Value`r`nEnd Function`r`n"}
$matrixPath=Join-Path $artifacts 'ConversionMatrix.bas';Write-Text $matrixPath $matrix
$fixtures+=,$matrixPath
$checks=@(
 'IntegerProbe.CheckArithmetic','IntegerProbe.CheckFailures','IntegerProbe.CheckByRef',
 'StorageProbe.CheckStorage','StorageProbe.CheckAliases','StorageProbe.CheckBounds','QuotedTypes.CheckBracketed',
 'DynamicProbe.CheckSourceBuffer','DynamicProbe.CheckValues','DynamicProbe.CheckPins','DynamicProbe.CheckIndexCapture','DynamicProbe.CheckCleanup',
 'BufferProbe.CheckCopies','BufferProbe.CheckStatus','BufferProbe.CheckAppend','BufferProbe.CheckAppendValidation','BufferProbe.CheckConversion',
 'ControlFlowProbe.Run'
)
$roundtrip=Join-Path $artifacts 'full-pipeline-roundtrip.bin'
$pathBytes=$utf8.GetBytes($roundtrip)
$bridge="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Harness`"`r`nPublic Function Run(ByVal Seed As Long) As Long`r`nDim Result As Long`r`nOn Error GoTo Failed`r`n"
$checkNumber=1
foreach($check in $checks){$bridge+="Result = $check(Seed)`r`nIf Result <> 0 Then Run = $($checkNumber*100) + Result: Exit Function`r`n";$checkNumber++}
$bridge+="Result = FileProbe.Configure($($pathBytes.Length), $($pathBytes.Length))`r`nIf Result <> 0 Then Run = 2001: Exit Function`r`n"
for($i=0;$i -lt $pathBytes.Length;$i++){$bridge+="Result = FileProbe.SetPathByte(0, $i, $($pathBytes[$i]))`r`nResult = FileProbe.SetPathByte(1, $i, $($pathBytes[$i]))`r`n"}
$bridge+="Result = FileProbe.CheckRoundTrip(Seed)`r`nIf Result <> 0 Then Run = 2100 + Result: Exit Function`r`nExit Function`r`nFailed:`r`nRun = 9000 + Err.Number`r`nEnd Function`r`n"
$bridgePath=Join-Path $artifacts 'Harness.bas';Write-Text $bridgePath $bridge
$sources=@($core)+@(Join-Path $root 'std-lib/src/portable/ByteBuffers.bas')+@($fixtures)+@($bridgePath)
foreach($level in @('O0','O2')) {
    $output=Emit-Project 'full-profile' $sources $level
    Require ($output.Text -match '(?m)^; module [0-9]+, node [0-9]+, line [0-9]+, column [0-9]+') 'Source-location comments missing from complete generated IR'
    Require ($output.Text -match '(?m)^; module 6, node [1-9][0-9]*, line 16, column 9\r?$') 'IntegerProbe runtime Byte initializer lost its exact module/line/column'
    if($level -eq 'O0'){$firstOutput=$output.Text}else{Require ($output.Text -ceq $firstOutput) 'Emitter optimization changed deterministic generated IR'}
    if(Test-Path -LiteralPath $roundtrip){Remove-Item -LiteralPath $roundtrip}
    Execute-Library $output 'full-profile' $level
    Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes($roundtrip)) -ceq [Convert]::ToBase64String([byte[]](0..255))) 'Roundtrip bytes differ from independent 0..255 oracle'
    Execute-Library $output 'changed-input' $level 2 101
}

# Executes real entry generation, forward initialization dependencies, recoverable initializer errors and depth refusal.
$entrySources=@()
$entryBodies=@(
 @('First',"Public Value As Long = Second.GetValue() + 1"),
 @('Second',"Public Value As Long = 4`r`nPublic Calls As Long`r`nPublic Function GetValue() As Long`r`nCalls = Calls + 1`r`nGetValue = Value`r`nEnd Function"),
 @('Fault',"Public Before As Long = 3`r`nPublic Missing As Long = Fail()`r`nPublic Following As Long = 7`r`nPrivate Function Fail() As Long`r`nErr.Raise 5`r`nFail = 99`r`nEnd Function"),
 @('Depth',"Public Function Dive(ByVal Count As Long) As Long`r`nIf Count = 0 Then Dive = 1: Exit Function`r`nDive = Dive(Count - 1)`r`nEnd Function"),
 @('Entry',@'
Public Function Main() As Long
    Dim Value As Long = 77
    On Error GoTo Failed
    If First.Value <> 5 Then Main = 1: Exit Function
    If Second.Calls <> 1 Then Main = 2: Exit Function
    If Fault.Before <> 3 Or Fault.Missing <> 0 Or Fault.Following <> 7 Then Main = 3: Exit Function
    If Err.Number <> 5 Then Main = 4: Exit Function
    Err.Clear
    Value = Depth.Dive(300)
    If Value <> 0 Then Main = 5: Exit Function
    If Err.Number <> 28 Then Main = 6: Exit Function
    Err.Clear
    Value = Depth.Dive(5)
    If Value <> 1 Or Err.Number <> 0 Then Main = 7: Exit Function
    Main = 42
    Exit Function
Failed:
    Main = 80 + Err.Number
End Function
'@)
)
foreach($item in $entryBodies){$path=Join-Path $artifacts ($item[0]+'.bas');Write-Text $path ("UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `""+$item[0]+"`"`r`n"+$item[1]);$entrySources+=,$path}
foreach($level in @('O0','O2')) {
    $entry=Emit-Project 'entry-initialization-depth' $entrySources $level $true
    if($level -eq 'O0'){$firstEntry=$entry.Text}else{Require ($entry.Text -ceq $firstEntry) 'Entry emission changed between native optimization levels'}
    $exe=Join-Path $artifacts ('entry-'+$level+'.exe');Build-Harness $entry.Path $exe $level
    $run=Invoke-BoundedProcess $exe @() 60000
    Require ($run.ExitCode -eq 42) "Entry/initializer/depth assertion$($run.ExitCode) failed $level : $($run.Evidence)"
    Write-Output "PASS: executable entry, dependency initialization, initializer FAIL continuation and recursion guard $level"
}

# The compiler and portable-library procedure bodies themselves must be lowered by UBE and accepted by LLVM.
$actual=Emit-Project 'compiler-sources' (@($core)+@($compiler)) 'O0'
foreach($level in @('O0','O2')) {
    $object=Join-Path $artifacts ('compiler-sources-'+$level+'.obj')
    $result=Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc',('-'+$level),'-c',$actual.Path,'-o',$object) 60000
    Require ($result.ExitCode -eq 0) "UBE-generated compiler LLVM failed $level : $($result.Evidence)"
    Require ((Get-Item -LiteralPath $object).Length -gt 0) 'LLVM emitted no compiler object'
    $undefined=Invoke-BoundedProcess (Join-Path ([IO.Path]::GetDirectoryName($Clang)) 'llvm-nm.exe') @('--undefined-only',$object)
    Require ($undefined.ExitCode -eq 0 -and $undefined.Stdout -notmatch '__chkstk|memcpy|memmove|memset') "Generated compiler has unavailable helper dependency $level : $($undefined.Evidence)"
    $allowed=@('__imp_CloseHandle','__imp_CreateFileW','__imp_FlushFileBuffers','__imp_GetFileSizeEx','__imp_GetFileType','__imp_MultiByteToWideChar','__imp_ReadFile','__imp_VirtualAlloc','__imp_VirtualFree','__imp_WriteFile')
    foreach($line in ($undefined.Stdout -split '\r?\n')){if($line.Trim().Length -gt 0){Require ($line -match '^\s*U\s+(\S+)\s*$') 'Unrecognized undefined-symbol evidence';Require ($Matches[1] -in $allowed) "Unexpected generated compiler dependency $($Matches[1])"}}
    Write-Output "PASS: actual compiler/library bodies lowered by UBE and LLVM compiled $level"
}
Write-Output "PASS: complete UBE native lowering. Evidence: $artifacts"
