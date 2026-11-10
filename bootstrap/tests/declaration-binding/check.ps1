# Verifies actual UBE declaration binding, signatures and project isolation.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube declaration binding ' + [guid]::NewGuid())
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

# Compares one resolved symbol fact against the independently authored language case.
function Symbol-Equals([string]$Symbol,[int]$Field,[string]$Expected,[string]$Description) {
    $value = Call-Probe 'SymbolField' @($Symbol,$Field)
    Check-Value $value $Expected $Description
}

$coreDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$compilerDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src'))
$files = @('BufferPrimitives.bas','FilePrimitives.bas','FileBytes.bas','Utf8.bas') | ForEach-Object { Join-Path $coreDirectory $_ }
$files += @('SourceScanner.bas','SyntaxTokens.bas','SourceParser.bas','ProjectSyntax.bas','DeclarationBinder.bas') | ForEach-Object { Join-Path $compilerDirectory $_ }
$files += Join-Path $PSScriptRoot 'DeclarationProbe.bas'
$manifest = Copy-Fixtures 'library' $files '2' 'Library'
$procedures = Read-Procedures $manifest
$libraryIR = Join-Path $artifacts 'binding.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$libraryIR) 'EMIT OK'
$emitted = [IO.File]::ReadAllText($libraryIR,$utf8)
foreach ($level in @('O0','O2')) {
    $assembly = Join-Path $artifacts ("production-$level.s")
    $result = Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc',('-' + $level),'-S',$libraryIR,'-o',$assembly)
    Require ($result.ExitCode -eq 0) "Production assembly failed: $($result.Evidence)"
    Require (-not [IO.File]::ReadAllText($assembly,$utf8).Contains('__chkstk')) 'Production routines unexpectedly require the test-only stack helper'
    Write-Output "PASS: production-only $level assembly has no stack-probe dependency"
}
$script:lines = New-Object 'System.Collections.Generic.List[string]'
$script:assertions = New-Object 'System.Collections.Generic.List[string]'
$script:sequence = 0
$script:failure = '0'
$lines.Add('define i32 @main() {')
$lines.Add('entry:')
$lines.Add('  %ctx = getelementptr %ube.context, ptr @test.context, i32 0')
$lines.Add('  call void @ube.context.init(ptr %ctx)')
$lines.Add('  %initialized = call i1 @ube.project.init(ptr %ctx)')
$primary = Module-Source 'Program' @'
Option Explicit
Private Type LocalRecord
    Own As Long
End Type
Public Type First
    Other As Helper.Second
    [Next] As First
End Type
Public Type [Long]
    Value As Byte
End Type
Dim Quoted As [Long]
Dim Qualified As BindingFixture.Helper.Second
Dim FriendlyValue As Helper.Friendly
Dim Hidden As Long
Const PrivateValue As Long = 1
Global SharedValue As Long
Public Function Main() As Long
    Dim Value As Integer
    Dim Values() As Helper.Second
    On Error GoTo Value
Value:
    Main = 0
End Function
Friend Function Echo(ByVal Incoming As Long, ByRef Result As Helper.Second, Values() As Byte) As Helper.Second
    Dim InputLocal As Byte
End Function
Private Function Narrow%() As Integer
End Function
Public Function WrongBody() As Long
    WrongBody = NoSuchFunction()
End Function
'@
$helper = Module-Source 'Helper' @'
Public Type Second
    Parent As Program.First
End Type
Private Type Secret
    Value As Long
End Type
Friend Type Friendly
    Value As Long
End Type
Public Function Supply(ByRef Value As Second) As Long
End Function
'@
$primaryPath = Join-Path $artifacts 'Program.bas'
$helperPath = Join-Path $artifacts 'Helper.bas'
Write-Text $primaryPath $primary
Write-Text $helperPath $helper
Start-Project
Append-Source $primaryPath
Append-Source $helperPath
$value = Call-Probe 'Bind' @(-1)
Check-Value $value 0 'cross-module declarations and recursive nominal graph accepted'
$script:passed++
$main = Find-Declaration $primary 'Function Main()' 'Main' 8
$entry = Call-Probe 'EntryIdentity'
Check-Value $entry $main 'entry points to actual Main declaration'
$resultSymbol = Find-Declaration $primary 'Function Main()' 'Main' 30
Symbol-Equals $resultSymbol 1 $main 'function result belongs to procedure'
Symbol-Equals $resultSymbol 5 4 'function result has separate assignment region'
Symbol-Equals $resultSymbol 7 156 'function result signature type Long'
Symbol-Equals $resultSymbol 6 0 'Public function result remains local visibility'
$mainNode = Call-Probe 'SymbolField' @($main,2)
Symbol-Equals $resultSymbol 2 $mainNode 'synthetic result retains original function declaration node'
$module = Call-Probe 'SymbolField' @($main,1)
Symbol-Equals $module 4 1 'procedure scope is module'
Symbol-Equals $module 1 0 'module scope is project namespace'
$first = Find-Declaration $primary 'Type First' 'First' 5
$second = Find-Declaration $helper 'Type Second' 'Second' 5 1
$other = Find-Declaration $primary 'Other As Helper.Second' 'Other' 6
$next = Find-Declaration $primary '[Next] As First' '[Next]' 6
$parentField = Find-Declaration $helper 'Parent As Program.First' 'Parent' 6 1
Symbol-Equals $other 1 $first 'field scope is owning Type'
Symbol-Equals $other 8 $second 'qualified forward nominal type resolved'
Symbol-Equals $next 8 $first 'self-referencing nominal identity resolved'
Symbol-Equals $parentField 8 $first 'mutually recursive nominal identity resolved'
Symbol-Equals $first 14 $other 'first declared field retained'
Symbol-Equals $other 15 $next 'field declaration order retained'
$quotedType = Find-Declaration $primary 'Type [Long]' '[Long]' 5
$quoted = Find-Declaration $primary 'Dim Quoted As [Long]' 'Quoted' 3
$qualified = Find-Declaration $primary 'Dim Qualified As BindingFixture.Helper.Second' 'Qualified' 3
$friendlyType = Find-Declaration $helper 'Type Friendly' 'Friendly' 5 1
$friendlyValue = Find-Declaration $primary 'Dim FriendlyValue As Helper.Friendly' 'FriendlyValue' 3
Symbol-Equals $quoted 8 $quotedType 'bracketed builtin spelling resolves nominal declaration'
Symbol-Equals $quoted 7 0 'bracketed nominal type is not intrinsic Long'
Symbol-Equals $qualified 8 $second 'package and module qualified nominal reference'
Symbol-Equals $friendlyValue 8 $friendlyType 'Friend Type accessible across project modules'
$echo = Find-Declaration $primary 'Function Echo(' 'Echo' 8
$input = Find-Declaration $primary 'ByVal Incoming As Long' 'Incoming' 9
$result = Find-Declaration $primary 'ByRef Result As Helper.Second' 'Result' 9
$values = Find-Declaration $primary 'Values() As Byte' 'Values' 9
Symbol-Equals $echo 6 109 'Friend procedure remains package-visible'
Symbol-Equals $echo 8 $second 'aggregate result nominal type retained without layout claim'
Symbol-Equals $echo 13 3 'exact parameter count'
Symbol-Equals $echo 11 $input 'ordered first parameter'
Symbol-Equals $input 12 $result 'ordered second parameter'
Symbol-Equals $result 12 $values 'ordered third parameter'
Symbol-Equals $input 10 115 'explicit ByVal mode'
Symbol-Equals $values 10 116 'default ByRef mode'
Symbol-Equals $values 9 1 'array parameter rank'
Symbol-Equals $values 7 154 'Byte element type'
Symbol-Equals $result 8 $second 'parameter nominal identity'
$hidden = Find-Declaration $primary 'Dim Hidden As Long' 'Hidden' 3
$constant = Find-Declaration $primary 'Const PrivateValue' 'PrivateValue' 4
$global = Find-Declaration $primary 'Global SharedValue' 'SharedValue' 3
Symbol-Equals $hidden 6 108 'default Dim is private'
Symbol-Equals $constant 6 108 'default Const is private'
Symbol-Equals $global 6 107 'Global variable is public'
$narrow = Find-Declaration $primary 'Function Narrow%' 'Narrow' 8
Symbol-Equals $narrow 7 155 'Integer declaration suffix retained'
$local = Find-Declaration $primary 'Dim Value As Integer' 'Value' 3
$label = Find-Declaration $primary 'Value:' 'Value' 28
Symbol-Equals $local 1 $main 'local scope is procedure'
Symbol-Equals $label 1 $main 'label scope is same procedure'
Symbol-Equals $local 5 2 'local value region'
Symbol-Equals $label 5 3 'label separate region'
$savedCount = Call-Probe 'CountSymbols'
$savedCapacity = Call-Probe 'RetainedCount'
$value = Call-Probe 'Bind' @(-1)
Check-Value $value 0 'repeated binding of unchanged project'
$value = Call-Probe 'CountSymbols'
Check-Value $value $savedCount 'deterministic repeated symbol count'
Symbol-Equals $other 8 $second 'deterministic repeated nominal identity'
$script:passed++

$negative = @(
    @('duplicate local',"Sub Main()`r`nDim X As Long`r`nDim [x] As Long`r`nEnd Sub",1,0),
    @('parameter local duplicate',"Sub Main(ByVal X As Long)`r`nDim x As Long`r`nEnd Sub",1,0),
    @('suffix duplicate',"Dim Value&`r`nDim value As Long",1,0),
    @('member kinds collide',"Type Value`r`nField As Long`r`nEnd Type`r`nDim Value As Long",1,0),
    @('duplicate field',"Type Item`r`nValue As Long`r`n[value] As Byte`r`nEnd Type",1,0),
    @('numeric label canonicalization',"Sub Test()`r`n010:`r`n10:`r`nEnd Sub",1,0),
    @('unknown type','Dim Value As Missing',2,0),
    @('non-type selected',"Dim Item As Long`r`nDim Value As Item",3,0),
    @('private external type','Dim Value As Helper.Secret',2,0),
    @('Global function',"Global Function Test() As Long`r`nEnd Function",3,0),
    @('Main parameter',"Sub Main(ByVal Value As Long)`r`nEnd Sub",5,-1),
    @('Main wrong result',"Function Main() As Byte`r`nEnd Function",5,-1),
    @('missing Main',"Sub Test()`r`nEnd Sub",5,-1)
)
foreach ($case in $negative) {
    Start-Project
    $path = Join-Path $artifacts ($case[0] + '.bas')
    $source = Module-Source 'Invalid' $case[1]
    Write-Text $path $source
    Append-Source $path
    Append-Source $helperPath
    # Supply Helper's forward reference without an entry; invalid cases remain otherwise well formed.
    $support = Join-Path $artifacts 'support.bas'
    Write-Text $support (Module-Source 'Program' "Public Type First`r`nValue As Long`r`nEnd Type")
    Append-Source $support
    $value = Call-Probe 'Bind' @($case[3])
    Check-Value $value 1 "reject $($case[0])"
    $value = Call-Probe 'DiagnosticField' @(0)
    Check-Value $value $case[2] "diagnostic category $($case[0])"
    if ($case[0] -eq 'duplicate local') {
        $offset = $source.IndexOf('[x]',[StringComparison]::Ordinal)
        foreach ($coordinate in @(@(2,0),@(5,$offset),@(6,($offset+1)),@(7,5),@(8,5))) {
            $value = Call-Probe 'DiagnosticField' @($coordinate[0])
            Check-Value $value $coordinate[1] 'duplicate declaration exact original position'
        }
    }
    foreach ($name in @('CountSymbols','EntryIdentity')) { $value = Call-Probe $name; Check-Value $value 0 'failure publishes zero logical output' }
    $value = Call-Probe 'RetainedCount'
    Check-Value $value $savedCapacity 'failed candidate preserves old symbols backing'
    Symbol-Equals $other 8 $second 'failed candidate preserves old nominal edges'
    $script:passed++
}
$projectCases = @(
    @{Name='second module missing type'; Code=2; Exe=0; Sources=@((Module-Source 'First' "Sub Test()`r`nEnd Sub"),(Module-Source 'Second' 'Dim Value As Missing'))},
    @{Name='ambiguous accessible type'; Code=4; Exe=0; Sources=@((Module-Source 'UseTypes' 'Dim Value As Shared'),(Module-Source 'A' "Public Type Shared`r`nValue As Long`r`nEnd Type"),(Module-Source 'B' "Friend Type Shared`r`nValue As Long`r`nEnd Type"))},
    @{Name='current non-type blocks fallback'; Code=3; Exe=0; Sources=@((Module-Source 'UseTypes' "Dim Item As Long`r`nDim Value As Item"),(Module-Source 'A' "Public Type Item`r`nValue As Long`r`nEnd Type"))},
    @{Name='multiple Main declarations'; Code=5; Exe=-1; Sources=@((Module-Source 'A' "Sub Main()`r`nEnd Sub"),(Module-Source 'B' "Sub Main()`r`nEnd Sub"))},
    @{Name='package module qualifier collision'; Code=8; Exe=0; Sources=@((Module-Source 'UseTypes' 'Dim Value As BindingFixture.Helper.Item'),(Module-Source 'BindingFixture' "Sub Test()`r`nEnd Sub"),(Module-Source 'Helper' "Type Item`r`nValue As Long`r`nEnd Type"))}
)
foreach ($case in $projectCases) {
    Start-Project
    $index = 0
    foreach ($source in $case.Sources) {
        $path = Join-Path $artifacts ($case.Name + '-' + $index + '.bas')
        Write-Text $path $source
        Append-Source $path
        $index++
    }
    $value = Call-Probe 'Bind' @($case.Exe)
    Check-Value $value 1 "project rejects $($case.Name)"
    $value = Call-Probe 'DiagnosticField' @(0)
    Check-Value $value $case.Code "project diagnostic $($case.Name)"
    if ($case.Name -eq 'second module missing type') {
        $source = $case.Sources[1]
        $offset = $source.IndexOf('Value',[StringComparison]::Ordinal)
        foreach ($coordinate in @(@(2,1),@(5,$offset),@(6,($offset+1)),@(7,3),@(8,5))) {
            $value = Call-Probe 'DiagnosticField' @($coordinate[0])
            Check-Value $value $coordinate[1] 'second module diagnostic uses original local source position'
        }
    }
    $value = Call-Probe 'CountSymbols'
    Check-Value $value 0 'project failure count zero'
    Symbol-Equals $other 8 $second 'project failure preserves prior nominal edge'
    $script:passed++
}
Start-Project
$libraryMain = Module-Source 'LibraryMain' "Function Main(ByVal Value As Byte) As Integer`r`nEnd Function"
$libraryPath = Join-Path $artifacts 'library-main.bas'
Write-Text $libraryPath $libraryMain
Append-Source $libraryPath
$value = Call-Probe 'Bind' @(0)
Check-Value $value 0 'Library Main is ordinary signature'
$value = Call-Probe 'EntryIdentity'
Check-Value $value 0 'Library Main has no entry identity'
$script:passed++
# Rebuild a distinct project after failures, proving no declaration leaks across requests.
Start-Project 'OtherPackage'
$freshPath = Join-Path $artifacts 'fresh.bas'
Write-Text $freshPath (Module-Source 'Fresh' "Public Sub Main()`r`nEnd Sub")
Append-Source $freshPath
$value = Call-Probe 'Bind' @(-1)
Check-Value $value 0 'independent project succeeds after failures'
$value = Call-Probe 'CountSymbols'
Check-Value $value 2 'new project contains only module and Sub Main symbols'
$script:passed++
Start-Project 'CompilerSources'
foreach ($file in $files) { Append-Source $file }
$value = Call-Probe 'Bind' @(0)
Check-Value $value 0 'actual compiler and library declaration/signature graph'
$value = Call-Probe 'CountSymbols'
Check-Value $value 1000 'substantial real source symbol graph' 'sge'
$value = Call-Probe 'EntryIdentity'
Check-Value $value 0 'library has no entry role'
$script:passed++
$beforeCorruptionCapacity = Call-Probe 'RetainedCount'
$beforeCorruptionKind = Call-Probe 'SymbolField' @(1,4)
foreach ($mode in @(1,2,3,4,5,6)) {
    Start-Project
    Append-Source $primaryPath
    Append-Source $helperPath
    $value = Call-Probe 'CorruptProject' @($mode)
    Check-Value $value 0 'mutate isolated project input'
    $value = Call-Probe 'Bind' @(0)
    Check-Value $value 1 "corrupted input mode $mode rejected without hanging"
    $value = Call-Probe 'DiagnosticField' @(0)
    $category = 9
    Check-Value $value $category "corrupted input mode $mode diagnostic"
    foreach ($name in @('CountSymbols','EntryIdentity')) { $value = Call-Probe $name; Check-Value $value 0 'corrupt input publishes no partial symbols' }
    $value = Call-Probe 'RetainedCount'
    Check-Value $value $beforeCorruptionCapacity 'corrupt input preserves old symbol storage'
    Symbol-Equals 1 4 $beforeCorruptionKind 'corrupt input preserves old symbol contents'
    $script:passed++
}
# Exercises the exact symbol ceiling independently of the lookup-work budget.
$boundaryBodies = @()
foreach ($moduleName in @('BoundaryA','BoundaryB')) {
    $builder = New-Object Text.StringBuilder
    for ($index=0; $index -lt 8191; $index++) { $null = $builder.Append('Dim V').Append($index).Append(" As Long`r`n") }
    $boundaryBodies += $builder.ToString()
}
Start-Project 'BoundaryProject'
for ($index=0; $index -lt 2; $index++) {
    $path = Join-Path $artifacts ("boundary-accepted-$index.bas")
    Write-Text $path (Module-Source (@('BoundaryA','BoundaryB')[$index]) $boundaryBodies[$index])
    Append-Source $path
}
$value = Call-Probe 'Bind' @(0)
Check-Value $value 0 'exact 16384-symbol boundary accepted'
$value = Call-Probe 'CountSymbols'
Check-Value $value 16384 '8191 variables in each of two modules plus module symbols'
$boundaryCapacity = Call-Probe 'RetainedCount'
$boundaryLastKind = Call-Probe 'SymbolField' @(16384,4)
$script:passed++
Start-Project 'BoundaryProject'
for ($index=0; $index -lt 2; $index++) {
    $path = Join-Path $artifacts ("boundary-rejected-$index.bas")
    Write-Text $path (Module-Source (@('BoundaryA','BoundaryB')[$index]) ($boundaryBodies[$index] + "Dim Extra As Long`r`n"))
    Append-Source $path
}
$value = Call-Probe 'Bind' @(0)
Check-Value $value 1 '16386 declarations exceed the symbol ceiling'
$value = Call-Probe 'DiagnosticField' @(0)
Check-Value $value 6 'symbol capacity diagnostic category'
$value = Call-Probe 'DiagnosticField' @(1)
Check-Value $value 1 'symbol capacity reason, not lookup-work exhaustion'
foreach ($name in @('CountSymbols','EntryIdentity')) { $value = Call-Probe $name; Check-Value $value 0 'limit failure publishes no partial output' }
$value = Call-Probe 'RetainedCount'
Check-Value $value $boundaryCapacity 'limit failure preserves previous backing storage'
Symbol-Equals 16384 4 $boundaryLastKind 'limit failure preserves last previously valid symbol'
$script:passed++
$lines.Add('  %disposed = call i1 @ube.context.dispose(ptr %ctx)')
$lines.Add('  %disposed.wide = zext i1 %disposed to i64')
Check-Value '%disposed.wide' 1 'all project and symbol owners disposed'
$lines.Add("  ret i32 $script:failure")
$lines.Add('}')
$harness = Join-Path $artifacts 'declarations.ll'
Write-Text $harness ($emitted + "`r`n@test.context = private global %ube.context zeroinitializer, align 8`r`n" + ($lines -join "`r`n") + "`r`n")
Write-Text (Join-Path $artifacts 'assertions.txt') ($assertions -join "`r`n")
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ("declarations-$level.exe")
    Build-Harness $harness $exe $level
    $result = Invoke-BoundedProcess $exe @() 60000
    Require ($result.ExitCode -eq 0) "Declaration gate $level assertion $($result.ExitCode) failed; see assertions.txt and $($result.Evidence)"
    Write-Output "PASS: $script:passed declaration cases and $($assertions.Count) assertions $level"
}
Write-Text $primaryPath ($primary.Replace('Friend Function Echo','Public Function Echo'))
try {
    $result = Invoke-BoundedProcess $exe @() 60000
    $expected = [int](($assertions | Where-Object { $_ -match ' Friend procedure remains package-visible$' } | Select-Object -First 1) -split ' ')[0]
    Require ($result.ExitCode -eq $expected) 'Changed runtime visibility must fail exact Friend assertion'
    Write-Output "PASS: changed runtime declaration rejected at exact assertion $expected"
} finally { Write-Text $primaryPath $primary }
Write-Output "PASS: declaration binding gate. Evidence: $artifacts"
