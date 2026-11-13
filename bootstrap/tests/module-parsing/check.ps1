# Verifies actual UBE module parsing, retained trees and controlled diagnostics.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube module parsing ' + [guid]::NewGuid())
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
    $result = Invoke-BoundedProcess $Clang $arguments
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

$coreDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$compilerDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src'))
$files = @('BufferPrimitives.bas','FilePrimitives.bas','FileBytes.bas','Utf8.bas') | ForEach-Object { Join-Path $coreDirectory $_ }
$files += @('SourceScanner.bas','SyntaxTokens.bas','SourceParser.bas') | ForEach-Object { Join-Path $compilerDirectory $_ }
$files += Join-Path $PSScriptRoot 'ParserProbe.bas'
$manifest = Copy-Fixtures 'library' $files '2' 'Library'
$procedures = Read-Procedures $manifest
$libraryIR = Join-Path $artifacts 'parser.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$libraryIR) 'EMIT OK'
$emitted = [IO.File]::ReadAllText($libraryIR,$utf8)
# Proves the test-only page probe does not hide a production compiler dependency.
foreach ($level in @('O0','O2')) {
    $assembly = Join-Path $artifacts ("production-$level.s")
    $result = Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc',('-' + $level),'-S',$libraryIR,'-o',$assembly)
    Require ($result.ExitCode -eq 0) "Production assembly check failed: $($result.Evidence)"
    Require (-not [IO.File]::ReadAllText($assembly,$utf8).Contains('__chkstk')) 'Production routines unexpectedly require a stack probe; diagnose before accepting the harness'
    Write-Output "PASS: production-only $level assembly has no stack-probe dependency"
}
$script:lines = New-Object 'System.Collections.Generic.List[string]'
$script:globals = New-Object 'System.Collections.Generic.List[string]'
$script:assertions = New-Object 'System.Collections.Generic.List[string]'
$script:sequence = 0
$script:failure = '0'
$script:pathNumber = 0
$lines.Add('define i32 @main() {')
$lines.Add('entry:')
$lines.Add('  %ctx = getelementptr %ube.context, ptr @test.context, i32 0')
$lines.Add('  call void @ube.context.init(ptr %ctx)')
$lines.Add('  %initialized = call i1 @ube.project.init(ptr %ctx)')

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

# Loads a runtime path through ordinary UBE setters, then reads and scans the file.
function Prepare-Source([string]$Path) {
    $script:pathNumber++
    $number = $script:pathNumber
    $bytes = $utf8.GetBytes($Path)
    $rows = ($bytes | ForEach-Object { 'i8 ' + $_ }) -join ', '
    $globals.Add("@path$number = private constant [$($bytes.Length) x i8] [$rows]")
    $value = Call-Probe 'ConfigurePath' @($bytes.Length)
    Check-Value $value 0 'path allocation'
    # Generated setters have no source-language parse expectations embedded in them.
    for ($index=0; $index -lt $bytes.Length; $index++) {
        $lines.Add("  %byteptr${number}_$index = getelementptr [$($bytes.Length) x i8], ptr @path$number, i64 0, i64 $index")
        $lines.Add("  %byte${number}_$index = load volatile i8, ptr %byteptr${number}_$index")
        $lines.Add("  %widebyte${number}_$index = zext i8 %byte${number}_$index to i64")
        $value = Call-Probe 'SetPathByte' @($index,"%widebyte${number}_$index")
        Check-Value $value 0 'path byte setter'
    }
    $value = Call-Probe 'PrepareCandidate'
    Check-Value $value 0 "read and scan $Path"
}

# Parses one source into a selected independent tree and validates every link/span.
function Accept-Source([string]$Path,[int]$Slot=0,[int]$MinimumNodes=1) {
    Prepare-Source $Path
    $value = Call-Probe 'ParseCandidate' @($Slot)
    Check-Value $value 0 "parse $Path"
    $value = Call-Probe 'CheckTree' @($Slot)
    Check-Value $value 0 "all nodes reachable with bounded source spans: $Path"
    $value = Call-Probe 'TreeCount' @($Slot)
    Check-Value $value $MinimumNodes "substantial tree for $Path" 'sge'
    $script:passed++
}

# Locates one independently authored syntactic span without relying on node numbering.
function Find-Span([string]$Text,[string]$Span,[int]$Kind,[int]$Slot=0,[int]$Occurrence=0) {
    $start = -1
    for ($index=0; $index -le $Occurrence; $index++) { $start = $Text.IndexOf($Span,$start+1,[StringComparison]::Ordinal) }
    Require ($start -ge 0) "Missing authored span $Span"
    $offset = $utf8.GetByteCount($Text.Substring(0,$start))
    $length = $utf8.GetByteCount($Span)
    $node = Call-Probe 'FindNode' @($Slot,$Kind,$offset,$length)
    Check-Value $node 0 "unique node kind $Kind span $Span" 'sgt'
    foreach ($pair in @(@(11,$offset),@(12,$length),@(13,($start+1)),@(14,$Span.Length))) {
        $value = Call-Probe 'NodeField' @($Slot,$node,$pair[0])
        Check-Value $value $pair[1] "exact byte/UTF16 span field $($pair[0]): $Span"
    }
    $prefix = $Text.Substring(0,$start)
    $line = 1 + ($prefix.ToCharArray() | Where-Object { $_ -eq [char]10 } | Measure-Object).Count
    $column = $start - $prefix.LastIndexOf([char]10)
    $value = Call-Probe 'NodeField' @($Slot,$node,15)
    Check-Value $value $line "physical line $Span"
    $value = Call-Probe 'NodeField' @($Slot,$node,16)
    Check-Value $value $column "UTF16 column $Span"
    return $node
}

# Checks an ordered tree edge or a scalar node property against authored syntax.
function Node-Equals([string]$Node,[int]$Field,[string]$Expected,[string]$Description,[int]$Slot=0) {
    $value = Call-Probe 'NodeField' @($Slot,$Node,$Field)
    Check-Value $value $Expected $Description
}

$fixture = @'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "TreeFixture"
' Unicode physical positions: é😀
Option Explicit
Public Type Pair
    LeftValue As Long
    RightValue As Integer
End Type
Private Values(3) As Long
Public Intrinsic Function Measure(ByRef Items() As Byte) As Long
Attribute Measure.UBE_Primitive = "Array.Length"
End Function
Public Function Calculate(ByVal A As Long, ByRef B As Long) As Long
    Dim X As Long
    X = 1 + 2 - 3
    X = 20 + _
        21
    X = Helpers.Sum((A + B), 4)
    If Not A = B And True Or False Then
        X = 8
    ElseIf A < B Then
        X = 9
    Else
        X = 10
    End If
    If A = 0 Then If B = 0 Then X = 11 Else X = 12
    Do While A > 0
        Exit Do
    Loop
    Do Until A = 0
        Exit Do
    Loop
    Do
        X = 13
    Loop While A > 0
    Do
        X = 14
    Loop Until A = 0
    Do
        Exit Do
    Loop
    On Error GoTo Failed
    GoTo Finished
Failed:
    On Error Resume Next
Finished:
    On Error GoTo 0
    Calculate = X
End Function
'@
$fixture = $fixture.Replace("`r`n","`n").Replace("`n","`r`n") + "`r`n"
$fixturePath = Join-Path $artifacts 'tree-fixture.bas'
Write-Text $fixturePath $fixture
Accept-Source $fixturePath
$subtract = Find-Span $fixture '1 + 2 - 3' 19
$add = Find-Span $fixture '1 + 2' 19
$one = Find-Span $fixture '1' 16 0 1
$three = Find-Span $fixture '3' 16 0 1
Node-Equals $subtract 1 17 'subtraction operator'
Node-Equals $add 1 16 'addition operator'
Node-Equals $subtract 8 $add 'left associative addition child'
Node-Equals $add 7 $subtract 'addition parent'
Node-Equals $add 10 $three 'subtraction right child follows addition'
$call = Find-Span $fixture 'Helpers.Sum((A + B), 4)' 15
$member = Find-Span $fixture 'Helpers.Sum' 14
$group = Find-Span $fixture '(A + B)' 20
$four = Find-Span $fixture '4' 16
Node-Equals $call 8 $member 'call receiver first'
Node-Equals $member 10 $group 'first call argument group'
Node-Equals $group 10 $four 'second call argument follows group'
$or = Find-Span $fixture 'Not A = B And True Or False' 19
$and = Find-Span $fixture 'Not A = B And True' 19
$not = Find-Span $fixture 'Not A = B' 18
$equal = Find-Span $fixture 'A = B' 19
Node-Equals $or 1 137 'Or precedence'
Node-Equals $or 8 $and 'And binds inside Or'
Node-Equals $and 8 $not 'Not binds outside comparison'
Node-Equals $not 8 $equal 'comparison is Not operand'
$continued = Find-Span $fixture "20 + _`r`n        21" 19
Node-Equals $continued 1 16 'continued expression retains physical span'
$shape = Find-Span $fixture '(3)' 12
Node-Equals $shape 1 1 'fixed array shape'
$lower = Call-Probe 'NodeField' @(0,$shape,8)
Node-Equals $lower 0 16 'implicit lower bound is number node'
Node-Equals $lower 2 -1 'implicit lower bound has no source token'
Node-Equals $lower 12 0 'synthetic lower bound has zero byte length'
$intrinsic = Find-Span $fixture "Intrinsic Function Measure(ByRef Items() As Byte) As Long`r`nAttribute Measure.UBE_Primitive = `"Array.Length`"`r`nEnd Function" 8
Node-Equals $intrinsic 19 -1 'intrinsic declaration flag'
$primitive = Find-Span $fixture 'Attribute Measure.UBE_Primitive = "Array.Length"' 10
Node-Equals $primitive 7 $intrinsic 'primitive metadata belongs to declaration'
$inline = Find-Span $fixture 'If A = 0 Then If B = 0 Then X = 11 Else X = 12' 22
$nested = Find-Span $fixture 'If B = 0 Then X = 11 Else X = 12' 22
$outerCondition = Call-Probe 'NodeField' @(0,$inline,8)
$outerThen = Call-Probe 'NodeField' @(0,$outerCondition,10)
Node-Equals $outerThen 8 $nested 'inline nested If is outer Then child'
Node-Equals $outerThen 10 0 'nearest Else belongs to inner If, no outer Else'
Node-Equals $nested 7 $outerThen 'nested If branch parent'
$innerLast = Call-Probe 'NodeField' @(0,$nested,9)
Node-Equals $innerLast 0 24 'inner If owns Else node'
foreach ($loop in @(@("Do While A > 0`r`n        Exit Do`r`n    Loop",1),@("Do Until A = 0`r`n        Exit Do`r`n    Loop",2),@("Do`r`n        X = 13`r`n    Loop While A > 0",3),@("Do`r`n        X = 14`r`n    Loop Until A = 0",4),@("Do`r`n        Exit Do`r`n    Loop",0))) {
    $node = Find-Span $fixture $loop[0] 25
    Node-Equals $node 1 $loop[1] 'Do condition placement retained'
    $first = Call-Probe 'NodeField' @(0,$node,8)
    if ($loop[1] -eq 0) { Node-Equals $first 0 11 'unconditional Do first child body' } else {
        Node-Equals $first 0 19 'conditional Do first child expression'
        $body = Call-Probe 'NodeField' @(0,$first,10)
        Node-Equals $body 0 11 'conditional Do second child body'
    }
}
$retained = Call-Probe 'TreeCount' @(0)
$retainedStorage = Call-Probe 'RetainedCount' @(0)
$retainedRoot = Call-Probe 'TreeRoot' @(0)
foreach ($module in @('SourceScanner.bas','SyntaxTokens.bas','SourceParser.bas')) {
    Accept-Source (Join-Path $compilerDirectory $module) 1 500
    $value = Call-Probe 'TreeCount' @(0)
    Check-Value $value $retained 'first retained tree count unchanged'
    $value = Call-Probe 'TreeRoot' @(0)
    Check-Value $value $retainedRoot 'first retained root unchanged'
    $value = Call-Probe 'CheckTree' @(0)
    Check-Value $value 0 'first source and complete tree remain independent'
    Node-Equals $subtract 8 $add 'first tree edge retained after parsing another module'
}
foreach ($module in @('Utf8.bas','BufferPrimitives.bas','FileBytes.bas')) { Accept-Source (Join-Path $coreDirectory $module) 1 20 }
$recursive = @'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "RecursiveSyntax"
Public Type First
    Other As Second
End Type
Public Type Second
    Other As First
End Type
Public Type SelfNode
    [Next] As SelfNode
End Type
'@
$recursive = $recursive.Replace("`r`n","`n").Replace("`n","`r`n") + "`r`n"
$recursivePath = Join-Path $artifacts 'recursive-types.bas'
Write-Text $recursivePath $recursive
Accept-Source $recursivePath 1 7
foreach ($field in @('Other As Second','Other As First','[Next] As SelfNode')) {
    $node = Find-Span $recursive $field 6 1
    $token = Call-Probe 'NodeField' @(1,$node,3)
    $start = Call-Probe 'TokenByteStart' @(1,$token)
    $expectedStart = $recursive.IndexOf($field,[StringComparison]::Ordinal) + $field.IndexOf(' As ',[StringComparison]::Ordinal) + 4
    Check-Value $start $expectedStart 'forward/self nominal type reference retained without semantic layout rejection'
}
$envelope = 'UBE SOURCE 1 MODULE' + "`r`n" + 'Attribute UBE_Name = "DepthCase"' + "`r`n"
foreach ($depthCase in @(@('thirty grouped expressions',("Sub Main()`r`nA = " + ('(' * 30) + '1' + (')' * 30) + "`r`nEnd Sub`r`n")),@('twenty nested loops',("Sub Main()`r`n" + ("Do`r`n" * 20) + "A = 1`r`n" + ("Loop`r`n" * 20) + "End Sub`r`n")))) {
    $path = Join-Path $artifacts ($depthCase[0] + '.bas')
    Write-Text $path ($envelope + $depthCase[1])
    Accept-Source $path 1 20
}
$threadSyntax = 'UBE SOURCE 1 MODULE' + "`r`n" + 'Attribute UBE_Name = "ThreadSyntax"' + "`r`nSub Run()`r`nDim Id As LongLong`r`nId = CallNew Workers.Run(42)`r`nCallNew IdleWorker`r`nEnd Sub`r`n"
$threadPath = Join-Path $artifacts 'thread-start-syntax.bas'
Write-Text $threadPath $threadSyntax
Accept-Source $threadPath 1 10
$threadExpression = Find-Span $threadSyntax 'CallNew Workers.Run(42)' 30 1
Node-Equals $threadExpression 1 0 'thread start expression retains value form' 1
$threadTarget = Call-Probe 'NodeField' @(1,$threadExpression,8)
Node-Equals $threadTarget 0 14 'thread start uses statically qualified member' 1
$threadCapture = Call-Probe 'NodeField' @(1,$threadTarget,10)
Node-Equals $threadCapture 0 16 'thread start retains first capture after callee' 1
$threadStatement = Find-Span $threadSyntax 'CallNew IdleWorker' 30 1
Node-Equals $threadStatement 1 1 'thread start ignored-result statement retained' 1

$invalid = @(
    @('CallNew arguments require parentheses',"Sub Run()`r`nCallNew Worker 1`r`nEnd Sub`r`n",2),
    @('CallNew missing spacing',"Sub Run()`r`nCallNew[Worker]()`r`nEnd Sub`r`n",2),
    @('CallNew computed target',"Sub Run()`r`nCallNew (Worker)()`r`nEnd Sub`r`n",3),
    @('CallNew trailing capture comma',"Sub Run()`r`nCallNew Worker(1,)`r`nEnd Sub`r`n",2),
    @('expression syntax depth limit',("Sub Main()`r`nA = " + ('(' * 80) + '1' + (')' * 80) + "`r`nEnd Sub`r`n"),4),
    @('loop syntax depth limit',("Sub Main()`r`n" + ("Do`r`n" * 40) + "A = 1`r`n" + ("Loop`r`n" * 40) + "End Sub`r`n"),4),
    @('missing procedure ending',"Sub Main()`r`nDim A As Long`r`n",2),
    @('mismatched ending',"Sub Main()`r`nEnd Function`r`n",2),
    @('missing expression',"Sub Main()`r`nA =`r`nEnd Sub`r`n",2),
    @('unsupported for',"Sub Main()`r`nFor A = 1 To 2`r`nNext`r`nEnd Sub`r`n",3),
    @('missing loop',"Sub Main()`r`nDo`r`nEnd Sub`r`n",2),
    @('exit outside loop',"Sub Main()`r`nExit Do`r`nEnd Sub`r`n",2),
    @('two loop tests',"Sub Main()`r`nDo While True`r`nLoop Until False`r`nEnd Sub`r`n",2),
    @('missing member',"Sub Main()`r`nA = B.`r`nEnd Sub`r`n",2),
    @('trailing call comma',"Sub Main()`r`nA = B(1,)`r`nEnd Sub`r`n",2)
)
foreach ($case in $invalid) {
    $path = Join-Path $artifacts ($case[0] + '.bas')
    Write-Text $path ('UBE SOURCE 1 MODULE' + "`r`n" + 'Attribute UBE_Name = "Invalid"' + "`r`n" + $case[1])
    Prepare-Source $path
    $value = Call-Probe 'ParseCandidate' @(0)
    Check-Value $value 1 "controlled failure: $($case[0])"
    foreach ($name in @('TreeCount','TreeRoot')) { $value = Call-Probe $name @(0); Check-Value $value 0 "failure publishes zero $name" }
    $value = Call-Probe 'RetainedCount' @(0)
    Check-Value $value $retainedStorage 'failure preserves previously published storage'
    Node-Equals $subtract 8 $add 'failure preserves old node fields'
    $value = Call-Probe 'DiagnosticField' @(0)
    Check-Value $value $case[2] "diagnostic category: $($case[0])"
    if ($case[2] -eq 4) { $value = Call-Probe 'DiagnosticField' @(1); Check-Value $value 7 'controlled parser syntax-depth limit reason' }
    foreach ($field in @(4,5,6)) { $value = Call-Probe 'DiagnosticField' @($field); Check-Value $value 1 'one-based diagnostic coordinate' 'sge' }
    if ($case[0] -eq 'mismatched ending') {
        $source = [IO.File]::ReadAllText($path,$utf8)
        $offset = $source.IndexOf('End Function',[StringComparison]::Ordinal) + 4
        foreach ($coordinate in @(@(3,$offset),@(4,($offset+1)),@(5,4),@(6,5))) {
            $value = Call-Probe 'DiagnosticField' @($coordinate[0])
            Check-Value $value $coordinate[1] 'mismatched ending exact offending token location'
        }
    }
    $script:passed++
}
foreach ($mode in @(1,2,3,4)) {
    Prepare-Source $fixturePath
    $value = Call-Probe 'CorruptCandidate' @($mode)
    Check-Value $value 0 'isolated token metadata mutation'
    $value = Call-Probe 'ParseCandidate' @(0)
    Check-Value $value 1 "malformed token metadata mode $mode rejected"
    foreach ($name in @('TreeCount','TreeRoot')) { $value = Call-Probe $name @(0); Check-Value $value 0 'invalid metadata publishes no partial tree' }
    $value = Call-Probe 'RetainedCount' @(0)
    Check-Value $value $retainedStorage 'invalid metadata retains previous storage'
    Node-Equals $subtract 8 $add 'invalid metadata retains previous node fields'
    $value = Call-Probe 'DiagnosticField' @(0)
    Check-Value $value 2 'malformed token metadata syntax category'
    $value = Call-Probe 'DiagnosticField' @(1)
    Check-Value $value 39 'malformed token metadata admission reason'
    $script:passed++
}
$emptyPath = Join-Path $artifacts 'empty.bas'
Write-Text $emptyPath ''
Prepare-Source $emptyPath
$value = Call-Probe 'ParseCandidate' @(0)
Check-Value $value 1 'empty source syntax rejection'
$value = Call-Probe 'DiagnosticField' @(0)
Check-Value $value 2 'empty source is syntax rather than capacity failure'
$script:passed++
Accept-Source $fixturePath 0
$lines.Add('  %disposed = call i1 @ube.context.dispose(ptr %ctx)')
$lines.Add('  %disposed.wide = zext i1 %disposed to i64')
Check-Value '%disposed.wide' 1 'all source/tree owners disposed'
$lines.Add("  ret i32 $script:failure")
$lines.Add('}')
$harness = Join-Path $artifacts 'module-parser.ll'
Write-Text $harness ($emitted + "`r`n@test.context = private global %ube.context zeroinitializer, align 8`r`n" + ($globals -join "`r`n") + "`r`n" + ($lines -join "`r`n") + "`r`n")
Write-Text (Join-Path $artifacts 'assertions.txt') ($assertions -join "`r`n")
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ("module-parser-$level.exe")
    Build-Harness $harness $exe $level
    $result = Invoke-BoundedProcess $exe @() 60000
    Require ($result.ExitCode -eq 0) "Module parser $level assertion $($result.ExitCode) failed; see assertions.txt and $($result.Evidence)"
    Write-Output "PASS: $script:passed actual module/diagnostic cases and $($assertions.Count) structural assertions $level"
}
# Changes an operator while retaining the compiled independent AST expectations.
$changed = $fixture.Replace('1 + 2 - 3','1 - 2 - 3')
Write-Text $fixturePath $changed
try {
    $result = Invoke-BoundedProcess $exe @() 60000
    $expected = [int](($assertions | Where-Object { $_ -match ' addition operator$' } | Select-Object -First 1) -split ' ')[0]
    # Both versions share spans; the explicit addition operator assertion distinguishes them.
    Require ($result.ExitCode -eq $expected) 'Changed runtime source must fail the exact addition-operator assertion'
    Write-Output "PASS: changed runtime operator rejected at assertion $($result.ExitCode)"
} finally { Write-Text $fixturePath $fixture }
Write-Output "PASS: module parser gate. Evidence: $artifacts"
