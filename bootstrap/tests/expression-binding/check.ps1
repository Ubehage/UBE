# Verifies actual UBE expression binding, references and checked constants.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube expression binding ' + [guid]::NewGuid())
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
    $arguments = @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR,$stackProbe) + $linkArguments + @('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
    $result = Invoke-BoundedProcess $Clang $arguments 60000
    Require ($result.ExitCode -eq 0) "Native harness build failed. Evidence: $($result.Evidence)"
    Assert-X64 $Exe
}

# The intentionally large O0 assertion driver needs the normal Windows page probe.
# This test-only leaf touches each guard page and preserves the requested size.
$stackProbe = Join-Path $artifacts 'stack-probe.s'
Write-Text $stackProbe @'
.text
.globl __chkstk
__chkstk:
    pushq %rcx
    pushq %rax
    leaq 24(%rsp), %rcx
    cmpq $4096, %rax
    jb 2f
1:
    subq $4096, %rcx
    testb $0, (%rcx)
    subq $4096, %rax
    cmpq $4096, %rax
    jae 1b
2:
    subq %rax, %rcx
    testb $0, (%rcx)
    popq %rax
    popq %rcx
    retq
'@

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

# Records the first failed independent assertion as a reproducible native exit code.
function Check-Value([string]$Actual,[string]$Expected,[string]$Description,[string]$Predicate='eq') {
    $script:sequence++
    $id = $script:sequence
    $lines.Add("  %match$id = icmp $Predicate i64 $Actual, $Expected")
    $lines.Add("  %first$id = icmp eq i32 $script:failure, 0")
    $lines.Add("  %bad$id = xor i1 %match$id, true")
    $lines.Add("  %take$id = and i1 %first$id, %bad$id")
    $lines.Add("  %failure$id = select i1 %take$id, i32 $id, i32 $script:failure")
    $script:failure = "%failure$id"
    $assertions.Add("$id $Description")
}

# Calls an actual emitted UBE procedure and separately checks its fresh status.
function Call-Probe([string]$Name,[object[]]$Arguments=@()) {
    $script:sequence++
    $id = $script:sequence
    $argsText = @($Arguments | ForEach-Object { ', i64 ' + $_ }) -join ''
    $lines.Add("  %pair$id = call { i1, i64 } @ube.proc.$($procedures[$Name])(ptr %ctx$argsText)")
    $lines.Add("  %status$id = extractvalue { i1, i64 } %pair$id, 0")
    $lines.Add("  %wide$id = zext i1 %status$id to i64")
    $lines.Add("  %value$id = extractvalue { i1, i64 } %pair$id, 1")
    Check-Value "%wide$id" 1 "$Name returns a usable result"
    return "%value$id"
}

# Creates an input module as data, never compiling its body through the host binder.
function Module-Source([string]$Name,[string]$Body) {
    return ('UBE SOURCE 1 MODULE' + "`r`n" + 'Attribute UBE_Name = "' + $Name + '"' + "`r`n" + $Body.Replace("`r`n","`n").Replace("`n","`r`n") + "`r`n")
}

# Initializes a fresh logical project while retaining independently published symbols.
function Start-Project([string]$Name='BindingFixture') {
    $bytes = $utf8.GetBytes($Name)
    $value = Call-Probe 'ResetProject' @($bytes.Length)
    Check-Value $value 0 'reset project input'
    for ($index=0; $index -lt $bytes.Length; $index++) {
        $value = Call-Probe 'SetPackageByte' @($index,$bytes[$index])
        Check-Value $value 0 'package name byte'
    }
}

# Reads one actual source path through the UBE file/scanner/parser/project pipeline.
function Append-Source([string]$Path) {
    $bytes = $utf8.GetBytes($Path)
    $value = Call-Probe 'ConfigurePath' @($bytes.Length)
    Check-Value $value 0 'path allocation'
    for ($index=0; $index -lt $bytes.Length; $index++) {
        $value = Call-Probe 'SetPathByte' @($index,$bytes[$index])
        Check-Value $value 0 'path byte'
    }
    $value = Call-Probe 'AppendFile'
    Check-Value $value 0 "append source $Path"
}

# Finds a symbol by its declared source name position, never by incidental symbol order.
function Find-Declaration([string]$Text,[string]$Declaration,[string]$Name,[int]$Kind,[int]$Module=0) {
    $start = $Text.IndexOf($Declaration,[StringComparison]::Ordinal)
    Require ($start -ge 0) "Missing declaration $Declaration"
    $within = $Declaration.IndexOf($Name,[StringComparison]::Ordinal)
    Require ($within -ge 0) "Missing name $Name"
    $offset = $utf8.GetByteCount($Text.Substring(0,$start+$within))
    $value = Call-Probe 'FindSymbol' @($Module,$offset,$Kind)
    Check-Value $value 0 "unique declaration $Name kind$Kind module$Module" 'sgt'
    return $value
}

# Finds one authored expression span in original module bytes without relying on allocation order.
function Find-Expression([string]$Text,[string]$Span,[int]$Kind,[int]$Module=0,[int]$Occurrence=0) {
    $start = -1
    for ($index=0; $index -le $Occurrence; $index++) { $start=$Text.IndexOf($Span,$start+1,[StringComparison]::Ordinal) }
    Require ($start -ge 0) "Missing expression span $Span"
    $offset=$utf8.GetByteCount($Text.Substring(0,$start))
    $value=Call-Probe 'FindNode' @($Module,$Kind,$offset,$utf8.GetByteCount($Span))
    Check-Value $value 0 "unique expression $Span kind$Kind module$Module" 'sgt'
    return $value
}

# Checks typed expression metadata against language-defined facts.
function Binding-Equals([string]$Node,[int]$Field,[string]$Expected,[string]$Description) {
    $value=Call-Probe 'BindingField' @($Node,$Field)
    Check-Value $value $Expected $Description
}

# Checks an exact signed integer constant, preserving all 64 bits in the observation ABI.
function Constant-Equals([string]$Node,[string]$Expected,[string]$Description) {
    Binding-Equals $Node 8 -1 "$Description known"
    $value=Call-Probe 'BindingValue' @($Node)
    Check-Value $value $Expected $Description
}

$coreDirectory=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$compilerDirectory=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src'))
$files=@('BufferPrimitives.bas','FilePrimitives.bas','FileBytes.bas','Utf8.bas') | ForEach-Object { Join-Path $coreDirectory $_ }
$files+=@('SourceScanner.bas','SyntaxTokens.bas','SourceParser.bas','ProjectSyntax.bas','DeclarationBinder.bas','ConstantValues.bas','ExpressionBinder.bas') | ForEach-Object { Join-Path $compilerDirectory $_ }
$files+=Join-Path $PSScriptRoot 'ExpressionProbe.bas'
$manifest=Copy-Fixtures 'library' $files '2' 'Library'
$procedures=Read-Procedures $manifest
$libraryIR=Join-Path $artifacts 'binding.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$libraryIR) 'EMIT OK'
$emitted=[IO.File]::ReadAllText($libraryIR,$utf8)
foreach ($level in @('O0','O2')) {
    $assembly=Join-Path $artifacts ("production-$level.s")
    $result=Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc',('-'+$level),'-S',$libraryIR,'-o',$assembly)
    Require ($result.ExitCode -eq 0) "Production assembly failed: $($result.Evidence)"
    Require (-not [IO.File]::ReadAllText($assembly,$utf8).Contains('__chkstk')) 'Production routines unexpectedly require test-only stack helper'
    Write-Output "PASS: production-only $level assembly has no stack-probe dependency"
}
$script:lines=New-Object 'System.Collections.Generic.List[string]'
$script:assertions=New-Object 'System.Collections.Generic.List[string]'
$script:sequence=0
$script:failure='0'
$lines.Add('define i32 @main() {')
$lines.Add('entry:')
$lines.Add('  %ctx = getelementptr %ube.context, ptr @test.context, i32 0')
$lines.Add('  call void @ube.context.init(ptr %ctx)')
$lines.Add('  %initialized = call i1 @ube.project.init(ptr %ctx)')
$primary=Module-Source 'Program' @'
Option Explicit
Public Const Base As Long = 40
Public Const Answer As Long = Base + 2
Public Function Evaluate(ByVal Seed As Long) As Long
    Dim Value As Long
    Dim Flag As Boolean = 2
    Dim Item As Helpers.Record
    Dim Items(0 To 2) As Helpers.Record
    Dim Counted() As Byte
    Value = BindingFixture.Helpers.Add(Seed, Answer)
    Helpers.Touch Value
    Helpers.Touch (Flag)
    Helpers.Touch (Helpers.Add(Seed, 1))
    Flag = 2
    Item.Value = Value
    Items(Seed).Value = Item.Value
    Helpers.TouchRecord Item
    Value = Helpers.Later
    If Value Then Value = Value + 1
    Do Until Flag
        Exit Do
    Loop
    On Error GoTo Failed
    GoTo Finished
Failed:
    Err.Clear
    Value = Err.Number
    Err.Raise 5
Finished:
    Evaluate = Value
End Function
'@
$helper=Module-Source 'Helpers' @'
Public Type Record
    Value As Long
End Type
Public Const Later As Long = 9
Friend Function Add(ByVal LeftValue As Long, ByVal RightValue As Long) As Long
    Add = LeftValue + RightValue
End Function
Public Sub Touch(ByRef Value As Long)
    Value = Value + 1
End Sub
Public Sub TouchRecord(ByRef Item As Record)
    Item.Value = 1
End Sub
'@
$primaryPath=Join-Path $artifacts 'Program.bas'
$helperPath=Join-Path $artifacts 'Helpers.bas'
Write-Text $primaryPath $primary
Write-Text $helperPath $helper
Start-Project
Append-Source $primaryPath
Append-Source $helperPath
$value=Call-Probe 'Bind' @(0)
Check-Value $value 0 'full typed reference call assignment condition and label binding'
$script:passed++
$evaluate=Find-Declaration $primary 'Function Evaluate(' 'Evaluate' 8
$valueSymbol=Find-Declaration $primary 'Dim Value As Long' 'Value' 3
$addSymbol=Find-Declaration $helper 'Function Add(' 'Add' 8 1
$recordSymbol=Find-Declaration $helper 'Type Record' 'Record' 5 1
$fieldSymbol=Find-Declaration $helper 'Value As Long' 'Value' 6 1
$call=Find-Expression $primary 'BindingFixture.Helpers.Add(Seed, Answer)' 15
Binding-Equals $call 0 $addSymbol 'package-qualified call binds actual declaration'
Binding-Equals $call 2 156 'function call Long result type'
Binding-Equals $call 1 $evaluate 'call retains current lexical scope'
$seedArgument=Find-Expression $primary 'Seed' 13 0 1
Binding-Equals $seedArgument 6 1 'ByVal argument mode'
Binding-Equals $seedArgument 5 156 'ByVal argument destination Long'
$direct=Find-Expression $primary 'Value' 13 0 2
Binding-Equals $direct 0 $valueSymbol 'direct argument resolves local declaration'
Binding-Equals $direct 6 2 'direct ByRef uses alias'
Binding-Equals $direct 7 -1 'direct ByRef is writable'
Binding-Equals $direct 5 156 'direct ByRef formal type Long'
$group=Find-Expression $primary '(Flag)' 20
Binding-Equals $group 2 153 'group preserves Boolean source type'
Binding-Equals $group 5 156 'grouped ByRef converts to Long'
Binding-Equals $group 6 3 'grouped ByRef uses temporary'
Binding-Equals $group 8 0 'initialized mutable variable is not a constant reference'
$groupedCall=Find-Expression $primary '(Helpers.Add(Seed, 1))' 20
Binding-Equals $groupedCall 6 3 'grouped function result uses converted scalar temporary'
$item=Find-Expression $primary 'Item.Value' 14
Binding-Equals $item 0 $fieldSymbol 'record member binds nominal field'
Binding-Equals $item 9 1 'field access kind'
Binding-Equals $item 7 -1 'field target is writable'
$recordArgOffset=$utf8.GetByteCount($primary.Substring(0,$primary.IndexOf('Helpers.TouchRecord Item',[StringComparison]::Ordinal)+20))
$recordArgument=Call-Probe 'FindNode' @(0,13,$recordArgOffset,4)
Check-Value $recordArgument 0 'record ByRef argument node' 'sgt'
Binding-Equals $recordArgument 6 2 'record ByRef uses alias'
Binding-Equals $recordArgument 3 $recordSymbol 'record ByRef retains exact nominal identity'
$index=Find-Expression $primary 'Items(Seed)' 15
Binding-Equals $index 3 $recordSymbol 'indexed record retains nominal element identity'
Binding-Equals $index 4 0 'index removes one array rank'
Binding-Equals $index 9 2 'index access kind'
$arrayReceiver=Find-Expression $primary 'Items' 13 0 1
Binding-Equals $arrayReceiver 11 -1 'stable fixed-array reference retains bounds proof'
$bound=Call-Probe 'BindingBound' @($arrayReceiver,0)
Check-Value $bound 0 'stable array lower bound'
$bound=Call-Probe 'BindingBound' @($arrayReceiver,-1)
Check-Value $bound 2 'stable array upper bound'
$number=Find-Expression $primary 'Err.Number' 14
Binding-Equals $number 10 4 'trusted Err.Number role'
Binding-Equals $number 7 0 'trusted Err.Number is readonly'
$clear=Find-Expression $primary 'Err.Clear' 15
Binding-Equals $clear 10 3 'trusted Err.Clear role'
$raise=Find-Expression $primary 'Err.Raise 5' 15
Binding-Equals $raise 10 2 'trusted Err.Raise role'
$label=Find-Declaration $primary 'Failed:' 'Failed' 28
$handler=Find-Expression $primary 'On Error GoTo Failed' 29
Binding-Equals $handler 0 $label 'On Error resolves exact procedure-local label'
$finish=Find-Declaration $primary 'Finished:' 'Finished' 28
$jump=Find-Expression $primary 'GoTo Finished' 27
Binding-Equals $jump 0 $finish 'GoTo resolves exact procedure-local label'
$resultSymbol=Find-Declaration $primary 'Function Evaluate(' 'Evaluate' 30
$resultName=Find-Expression $primary 'Evaluate' 13 0 1
Binding-Equals $resultName 0 $resultSymbol 'function result assignment selects result declaration'
$conditionOffset=$utf8.GetByteCount($primary.Substring(0,$primary.IndexOf('If Value Then',[StringComparison]::Ordinal)+3))
$condition=Call-Probe 'FindNode' @(0,13,$conditionOffset,5)
Check-Value $condition 0 'If condition name node retained' 'sgt'
Binding-Equals $condition 5 153 'numeric If condition converts to Boolean'
$assignment=Find-Expression $primary 'Flag = 2' 21
Constant-Equals $assignment -1 'numeric assignment converts to canonical True'
$answerNode=Find-Expression $primary 'Answer As Long = Base + 2' 4
Constant-Equals $answerNode 42 'earlier same-scope constant dependency'
$later=Find-Expression $primary 'Helpers.Later' 14
Constant-Equals $later 9 'normal expression reads later-module constant'
$savedCapacity=Call-Probe 'RetainedBindings'
$savedCount=Call-Probe 'CountBindings'
$value=Call-Probe 'Bind' @(0)
Check-Value $value 0 'repeat same project analysis'
$value=Call-Probe 'CountBindings'
Check-Value $value $savedCount 'deterministic repeated binding count'
Binding-Equals $call 0 $addSymbol 'deterministic repeated selected declaration'
$script:passed++

$negative=@(
    @('semantic left-chain depth',("Sub Run()`r`nDim Value As Long`r`nValue = "+((@('1')*160)-join ' + ')+"`r`nEnd Sub"),6),
    @('undeclared name',"Sub Run()`r`nDim Value As Long = Missing`r`nEnd Sub",2),
    @('wrong argument count',"Sub Take(ByVal Value As Long)`r`nEnd Sub`r`nSub Run()`r`nTake`r`nEnd Sub",10),
    @('direct ByRef literal',"Sub Take(ByRef Value As Long)`r`nEnd Sub`r`nSub Run()`r`nTake 1`r`nEnd Sub",10),
    @('direct ByRef mismatch',"Sub Take(ByRef Value As Long)`r`nEnd Sub`r`nSub Run()`r`nDim Flag As Boolean`r`nTake Flag`r`nEnd Sub",10),
    @('direct ByRef function result',"Function Work() As Long`r`nWork = 1`r`nEnd Function`r`nSub Take(ByRef Value As Long)`r`nEnd Sub`r`nSub Run()`r`nTake Work()`r`nEnd Sub",10),
    @('direct ByRef constant',"Sub Take(ByRef Value As Long)`r`nEnd Sub`r`nSub Run()`r`nConst Value As Long = 1`r`nTake Value`r`nEnd Sub",10),
    @('Sub used as expression',"Sub Work()`r`nEnd Sub`r`nSub Run()`r`nDim Value As Long = Work()`r`nEnd Sub",3),
    @('bare function value',"Function Work() As Long`r`nEnd Function`r`nSub Run()`r`nDim Value As Long = Work`r`nEnd Sub",3),
    @('constant assignment',"Sub Run()`r`nConst Value As Long = 1`r`nValue = 2`r`nEnd Sub",3),
    @('constant variable dependency',"Dim Value As Long`r`nConst Bad As Long = Value",11),
    @('constant call dependency',"Function Work() As Long`r`nEnd Function`r`nConst Bad As Long = Work()",11),
    @('constant self cycle','Const Bad As Long = Bad',11),
    @('constant forward dependency',"Const First As Long = Second`r`nConst Second As Long = 1",11),
    @('Long addition overflow','Const Bad As Long = 2147483647 + 1',11),
    @('Integer explicit overflow','Const Bad As Long = 32767% + 1%',11),
    @('Long explicit overflow in wide context','Const Bad As LongLong = 2147483647& + 1&',11),
    @('LongLong addition overflow','Const Bad As LongLong = 9223372036854775807^ + 1^',11),
    @('LongLong subtraction overflow','Const Bad As LongLong = -9223372036854775808^ - 1^',11),
    @('LongLong unary overflow','Const Bad As LongLong = -(-9223372036854775808^)',11),
    @('grouped magnitude not signed literal','Const Bad As LongLong = -(9223372036854775808^)',11),
    @('True to Byte overflow','Const Bad As Byte = True',11),
    @('converted Boolean constant to Byte',"Const Flag As Boolean = 2`r`nConst Bad As Byte = Flag",11),
    @('Boolean comparison context does not widen arithmetic','Const Bad As Boolean = 2147483647 + 1 = 0',11),
    @('Byte upper conversion overflow','Const Bad As Byte = 256',11),
    @('mixed Boolean integer operators','Const Bad As Long = True + 1',8),
    @('hexadecimal deferred','Const Bad As Long = &HFF',8),
    @('missing handler',"Sub Run()`r`nOn Error GoTo Missing`r`nEnd Sub",12),
    @('missing goto',"Sub Run()`r`nGoTo Missing`r`nEnd Sub",12),
    @('local Err shadows support',"Sub Run()`r`nDim Err As Long`r`nErr.Raise 5`r`nEnd Sub",3),
    @('readonly Err Number',"Sub Run()`r`nErr.Number = 5`r`nEnd Sub",3),
    @('readonly Err Number ByRef',"Sub Take(ByRef Value As Long)`r`nEnd Sub`r`nSub Run()`r`nTake Err.Number`r`nEnd Sub",10),
    @('Err Raise arity',"Sub Run()`r`nErr.Raise`r`nEnd Sub",10),
    @('Err Clear expression',"Sub Run()`r`nDim Value As Long = Err.Clear()`r`nEnd Sub",3),
    @('reference suffix mismatch',"Sub Run()`r`nDim Value As Long`r`nValue% = 1`r`nEnd Sub",3),
    @('unknown record field',"Type Pair`r`nValue As Long`r`nEnd Type`r`nSub Run()`r`nDim Item As Pair`r`nItem.Missing = 1`r`nEnd Sub",2),
    @('stable constant index outside bounds',"Sub Run()`r`nDim Values(0 To 2) As Long`r`nDim Value As Long = Values(3)`r`nEnd Sub",11),
    @('wrong index arity',"Sub Run()`r`nDim Values(0 To 2) As Long`r`nDim Value As Long = Values(0,1)`r`nEnd Sub",10),
    @('grouped aggregate ByRef deferred',"Type Pair`r`nValue As Long`r`nEnd Type`r`nSub Take(ByRef Item As Pair)`r`nEnd Sub`r`nSub Run()`r`nDim Item As Pair`r`nTake (Item)`r`nEnd Sub",8),
    @('nominal record mismatch',"Type First`r`nValue As Long`r`nEnd Type`r`nType Second`r`nValue As Long`r`nEnd Type`r`nSub Run()`r`nDim A As First`r`nDim B As Second`r`nA = B`r`nEnd Sub",3)
)
foreach ($case in $negative) {
    Start-Project
    $path=Join-Path $artifacts ($case[0]+'.bas')
    $source=Module-Source 'Invalid' $case[1]
    Write-Text $path $source
    Append-Source $path
    $value=Call-Probe 'Bind' @(0)
    Check-Value $value 1 "reject $($case[0])"
    $value=Call-Probe 'DiagnosticField' @(0)
    Check-Value $value $case[2] "diagnostic $($case[0])"
    $value=Call-Probe 'CountBindings'
    Check-Value $value 0 'failure publishes no expression bindings'
    $value=Call-Probe 'RetainedBindings'
    Check-Value $value $savedCapacity 'failure retains prior expression backing'
    Binding-Equals $call 0 $addSymbol 'failure retains selected declaration in old binding'
    foreach ($field in @(6,7,8)) { $value=Call-Probe 'DiagnosticField' @($field); Check-Value $value 1 'failure has one-based source coordinate' 'sge' }
    if ($case[0] -eq 'undeclared name') {
        $offset=$source.IndexOf('Missing',[StringComparison]::Ordinal)
        foreach ($coordinate in @(@(2,0),@(5,$offset),@(6,($offset+1)),@(7,4),@(8,21))) {
            $value=Call-Probe 'DiagnosticField' @($coordinate[0])
            Check-Value $value $coordinate[1] 'undeclared name exact offending source position'
        }
    }
    $script:passed++
}

$constantBody=@'
Public Const Base As Long = 40
Public Const Answer As Long = Base + 2
Public Const Wide As Long = 2147483648 + -1
Public Const Minimum As Long = -2147483648&
Public Const Minimum64 As LongLong = -9223372036854775808^
Public Const Maximum64 As LongLong = 9223372036854775807^
Public Const ContextWide As LongLong = 2147483647 + 1
Public Const IntegerMix As Long = 32767% + 1&
Public Const Bits As Long = (4294967297^ And 4294967296^) + -4294967296^
Public Const Negation As Long = Not 255
Public Const Logic As Boolean = Not 1 = 2 And True Or False
Public Const TrueNumber As Long = True
Public Const Nonzero As Boolean = 2
Public Const ZeroByte As Byte = False
Public Const NegatedZero As Byte = -0
Public Function Run() As Long
    Const Local As Long = Answer + 1
    Run = Local
End Function
'@
$constants=Module-Source 'Constants' $constantBody
$constantPath=Join-Path $artifacts 'constants.bas'
Write-Text $constantPath $constants
Start-Project
Append-Source $constantPath
$value=Call-Probe 'Bind' @(0)
Check-Value $value 0 'checked decimal integer constant contexts'
foreach ($expected in @(@('Answer As Long = Base + 2','42'),@('Wide As Long = 2147483648 + -1','2147483647'),@('Minimum As Long = -2147483648&','-2147483648'),@('Minimum64 As LongLong = -9223372036854775808^','-9223372036854775808'),@('Maximum64 As LongLong = 9223372036854775807^','9223372036854775807'),@('ContextWide As LongLong = 2147483647 + 1','2147483648'),@('IntegerMix As Long = 32767% + 1&','32768'),@('Bits As Long = (4294967297^ And 4294967296^) + -4294967296^','0'),@('Negation As Long = Not 255','-256'),@('Logic As Boolean = Not 1 = 2 And True Or False','-1'),@('TrueNumber As Long = True','-1'),@('Nonzero As Boolean = 2','-1'),@('ZeroByte As Byte = False','0'),@('Local As Long = Answer + 1','43'))) {
    $node=Find-Expression $constants $expected[0] 4
    Constant-Equals $node $expected[1] $expected[0]
}
$minimum=Find-Expression $constants '-9223372036854775808^' 18
Constant-Equals $minimum '-9223372036854775808' 'direct signed literal minimum'
$magnitude=Find-Expression $constants '9223372036854775808^' 16
Binding-Equals $magnitude 8 0 'magnitude child does not advertise unrepresentable positive value'
$negatedZero=Find-Expression $constants '-0' 18
Binding-Equals $negatedZero 2 155 'Byte-context unary sign promotes to Integer'
Constant-Equals $negatedZero 0 'Byte-context negated zero'
$script:passed++
$projectCases=@(
    @{Name='private procedure'; Code=2; Sources=@((Module-Source 'Program' "Sub Run()`r`nOther.Work`r`nEnd Sub"),(Module-Source 'Other' "Private Sub Work()`r`nEnd Sub"))},
    @{Name='ambiguous package name'; Code=4; Sources=@((Module-Source 'Program' "Sub Run()`r`nChoose`r`nEnd Sub"),(Module-Source 'First' "Public Sub Choose()`r`nEnd Sub"),(Module-Source 'Second' "Public Sub Choose()`r`nEnd Sub"))},
    @{Name='current procedure signature blocks fallback'; Code=10; Sources=@((Module-Source 'Program' "Sub Work(ByVal Value As Long)`r`nEnd Sub`r`nSub Run()`r`nWork`r`nEnd Sub"),(Module-Source 'Other' "Public Sub Work()`r`nEnd Sub"))},
    @{Name='local scalar blocks procedure fallback'; Code=3; Sources=@((Module-Source 'Program' "Sub Run()`r`nDim Work As Long`r`nWork 1`r`nEnd Sub"),(Module-Source 'Other' "Public Sub Work(ByVal Value As Long)`r`nEnd Sub"))},
    @{Name='crossmodule required constant'; Code=8; Sources=@((Module-Source 'Program' 'Const Value As Long = Other.Answer'),(Module-Source 'Other' 'Public Const Answer As Long = 42'))},
    @{Name='user Err missing member no fallback'; Code=2; Sources=@((Module-Source 'Program' "Sub Run()`r`nErr.Clear`r`nEnd Sub"),(Module-Source 'Err' "Public Sub Raise(ByVal Number As Long)`r`nEnd Sub"))},
    @{Name='crossprocedure label'; Code=12; Sources=@((Module-Source 'Program' "Sub First()`r`nGoTo Target`r`nEnd Sub`r`nSub Second()`r`nTarget:`r`nEnd Sub"))},
    @{Name='package module qualifier collision'; Code=8; Sources=@((Module-Source 'Program' "Sub Run()`r`nDim Value As Long = BindingFixture.Other.Work()`r`nEnd Sub"),(Module-Source 'BindingFixture' "Sub Test()`r`nEnd Sub"),(Module-Source 'Other' "Function Work() As Long`r`nEnd Function"))}
)
$constantCapacity=Call-Probe 'RetainedBindings'
foreach ($case in $projectCases) {
    Start-Project
    $index=0
    foreach ($source in $case.Sources) {
        $path=Join-Path $artifacts ($case.Name+'-'+$index+'.bas')
        Write-Text $path $source
        Append-Source $path
        $index++
    }
    $value=Call-Probe 'Bind' @(0)
    Check-Value $value 1 "project rejects $($case.Name)"
    $value=Call-Probe 'DiagnosticField' @(0)
    Check-Value $value $case.Code "project diagnostic $($case.Name)"
    $value=Call-Probe 'CountBindings'
    Check-Value $value 0 'project failure publishes zero bindings'
    $value=Call-Probe 'RetainedBindings'
    Check-Value $value $constantCapacity 'project failure preserves old bindings'
    Constant-Equals $minimum '-9223372036854775808' 'failed project preserves prior exact constant'
    $script:passed++
}
$userProgram=Module-Source 'Program' "Sub Run()`r`nErr.Raise 5`r`nEnd Sub"
$userErr=Module-Source 'Err' "Public Sub Raise(ByVal Number As Long)`r`nEnd Sub"
Start-Project
$path=Join-Path $artifacts 'user-error-caller.bas'
Write-Text $path $userProgram
Append-Source $path
$path=Join-Path $artifacts 'user-error-module.bas'
Write-Text $path $userErr
Append-Source $path
$value=Call-Probe 'Bind' @(0)
Check-Value $value 0 'user Err module ordinary call'
$userCall=Find-Expression $userProgram 'Err.Raise 5' 15
$userRaise=Find-Declaration $userErr 'Sub Raise(' 'Raise' 7 1
Binding-Equals $userCall 0 $userRaise 'user Raise declaration identity'
Binding-Equals $userCall 10 0 'user Raise has no trusted role'
$script:passed++

$arrayBody=Module-Source 'ArrayEffects' @'
Public Intrinsic Function Resize(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute Resize.UBE_Primitive = "Array.TryResize"
End Function
Public Sub Run()
    Dim Values(0 To 2) As Long
    Dim Value As Long = Values(100)
End Sub
'@
Start-Project
$path=Join-Path $artifacts 'array-effects.bas'
Write-Text $path $arrayBody
Append-Source $path
$value=Call-Probe 'Bind' @(0)
Check-Value $value 0 'mutating primitive declaration invalidates current fixed-bound proof'
$receiver=Find-Expression $arrayBody 'Values' 13 0 2
Binding-Equals $receiver 11 0 'effect-invalidated reference retains no static bound proof'
$script:passed++

# A complete current compiler/library project must check its bodies, not only declarations.
Start-Project
$recursive=Module-Source 'RecursiveValues' @'
Public Type Node
    [Next] As Node
End Type
Public Sub Compare(ByRef A As Node, ByRef B As Node)
    Dim EqualValue As Boolean = A = B
    Dim UnequalValue As Boolean = A <> B
End Sub
'@
$path=Join-Path $artifacts 'recursive-comparison.bas'
Write-Text $path $recursive
Append-Source $path
$value=Call-Probe 'Bind' @(0)
Check-Value $value 0 'recursive nominal record comparisons type-check without layout execution'
foreach ($span in @('A = B','A <> B')) {
    $node=Find-Expression $recursive $span 19
    Binding-Equals $node 2 153 'same nominal record comparison produces Boolean'
    Binding-Equals $node 8 0 'record comparison is not an invented scalar constant'
}
$script:passed++
Start-Project
$path=Join-Path $artifacts 'bounded-depth.bas'
Write-Text $path (Module-Source 'DepthCase' ("Sub Run()`r`nDim Value As Long`r`nValue = "+((@('1')*24)-join ' + ')+"`r`nEnd Sub"))
Append-Source $path
$value=Call-Probe 'Bind' @(0)
Check-Value $value 0 'bounded left-associative expression accepted'
$script:passed++
Start-Project 'CompilerSources'
foreach ($file in $files) { Append-Source $file }
$value=Call-Probe 'Bind' @(0)
Check-Value $value 0 'actual compiler and library expression bodies'
$value=Call-Probe 'CountBindings'
Check-Value $value 18000 'substantial actual-source bound expression project' 'sge'
$script:passed++
# Recheck the original project after all invalid and independent inputs.
Start-Project
Append-Source $primaryPath
Append-Source $helperPath
$value=Call-Probe 'Bind' @(0)
Check-Value $value 0 'valid project recovery after independent analyses'
Binding-Equals $call 0 $addSymbol 'original declaration identity recovered deterministically'
$script:passed++
$recoveredCapacity=Call-Probe 'RetainedBindings'
foreach ($mode in @(1,3,5)) {
    Start-Project
    Append-Source $primaryPath
    Append-Source $helperPath
    $value=Call-Probe 'CorruptProject' @($mode)
    Check-Value $value 0 'isolate malformed semantic input'
    $value=Call-Probe 'Bind' @(0)
    Check-Value $value 1 'malformed pool rejected by expression pipeline'
    $value=Call-Probe 'DiagnosticField' @(0)
    Check-Value $value 9 'malformed pool input diagnostic'
    $value=Call-Probe 'CountBindings'
    Check-Value $value 0 'malformed input publishes zero bindings'
    $value=Call-Probe 'RetainedBindings'
    Check-Value $value $recoveredCapacity 'malformed input retains previous expression backing'
    Binding-Equals $call 0 $addSymbol 'malformed input preserves previous selected declaration'
    $script:passed++
}
$lines.Add('  %disposed = call i1 @ube.context.dispose(ptr %ctx)')
$lines.Add('  %disposed.wide = zext i1 %disposed to i64')
Check-Value '%disposed.wide' 1 'all syntax/declaration/expression owners disposed'
$lines.Add("  ret i32 $script:failure")
$lines.Add('}')
$harness=Join-Path $artifacts 'expressions.ll'
Write-Text $harness ($emitted+"`r`n@test.context = private global %ube.context zeroinitializer, align 8`r`n"+($lines -join "`r`n")+"`r`n")
Write-Text (Join-Path $artifacts 'assertions.txt') ($assertions -join "`r`n")
foreach ($level in @('O0','O2')) {
    $exe=Join-Path $artifacts ("expressions-$level.exe")
    Build-Harness $harness $exe $level
    $result=Invoke-BoundedProcess $exe @() 60000
    Require ($result.ExitCode -eq 0) "Expression gate $level assertion $($result.ExitCode) failed; see assertions.txt and $($result.Evidence)"
    Write-Output "PASS: $script:passed expression cases and $($assertions.Count) assertions $level"
}
# Changing actual source ByRef grouping must alter the retained argument mode.
Write-Text $primaryPath ($primary.Replace('Helpers.Touch (Flag)','Helpers.Touch (Seed)'))
try {
    $result=Invoke-BoundedProcess $exe @() 60000
    $expected=[int](($assertions | Where-Object { $_ -match ' group preserves Boolean source type$' } | Select-Object -First 1) -split ' ')[0]
    Require ($result.ExitCode -eq $expected) 'Changed runtime grouped argument must fail exact source-type assertion'
    Write-Output "PASS: changed runtime expression rejected at assertion $expected"
} finally { Write-Text $primaryPath $primary }
Write-Output "PASS: expression binding gate. Evidence: $artifacts"
