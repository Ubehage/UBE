# Verifies actual UBE intrinsic-role signatures and finite storage facts.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube semantic storage ' + [guid]::NewGuid())
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

# Checks one representation fact without recomputing layouts in the observer.
function Layout-Equals([string]$Node,[int]$Field,[string]$Expected,[string]$Description) {
    $value=Call-Probe 'LayoutField' @($Node,$Field)
    Check-Value $value $Expected $Description
}

# Creates attributed declarations with arbitrary names from reviewed role signatures.
function Primitive-Source([string]$Name,[string]$Parameters,[string]$Result,[string]$Role) {
    return 'Public Intrinsic Function '+$Name+'('+$Parameters+') As '+$Result+"`r`n"+'Attribute '+$Name+'.UBE_Primitive = "'+$Role+'"'+"`r`nEnd Function`r`n"
}

$coreDirectory=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$compilerDirectory=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src'))
$files=@('BufferPrimitives.bas','FilePrimitives.bas','FileBytes.bas','Utf8.bas') | ForEach-Object { Join-Path $coreDirectory $_ }
$files+=@('SourceScanner.bas','SyntaxTokens.bas','SourceParser.bas','ProjectSyntax.bas','DeclarationBinder.bas','ConstantValues.bas','ExpressionBinder.bas','PrimitiveRoles.bas','AggregateLayout.bas') | ForEach-Object { Join-Path $compilerDirectory $_ }
$files+=Join-Path $PSScriptRoot 'Probe.bas'
$manifest=Copy-Fixtures 'library' $files '2' 'Library'
$procedures=Read-Procedures $manifest
$libraryIR=Join-Path $artifacts 'semantic-storage.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$libraryIR) 'EMIT OK'
$emitted=[IO.File]::ReadAllText($libraryIR,$utf8)
foreach ($level in @('O0','O2')) {
    $assembly=Join-Path $artifacts ("production-$level.s")
    $result=Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc',('-'+$level),'-S',$libraryIR,'-o',$assembly) 60000
    Require ($result.ExitCode -eq 0) "Production assembly failed: $($result.Evidence)"
    Require (-not [IO.File]::ReadAllText($assembly,$utf8).Contains('__chkstk')) 'Production unexpectedly requires test driver stack helper'
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
$roles=@(
    @('Array.Length','ByRef Values() As Byte','Long'),
    @('Memory.CopyBytes','ByRef Source() As Byte, ByVal SourceStart As Long, ByRef Destination() As Byte, ByVal DestinationStart As Long, ByVal Count As Long','Boolean'),
    @('Array.TryResize','ByRef Values() As Byte, ByVal Count As Long, ByVal Preserve As Boolean','Boolean'),
    @('Array.TryCopy','ByRef Destination() As Byte, ByRef Source() As Byte','Boolean'),
    @('File.TryOpen','ByRef PathUtf8() As Byte, ByVal MaximumBytes As Long, ByRef Token As Long, ByRef Length As Long, ByRef Failure As Long','Boolean'),
    @('File.TryCreateNew','ByRef PathUtf8() As Byte, ByRef Token As Long, ByRef Failure As Long','Boolean'),
    @('File.TryRead','ByVal Token As Long, ByRef Destination() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef ReadCount As Long, ByRef Failure As Long','Boolean'),
    @('File.TryWrite','ByVal Token As Long, ByRef Source() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef WrittenCount As Long, ByRef Failure As Long','Boolean'),
    @('File.TryClose','ByRef Token As Long, ByRef Failure As Long','Boolean'),
    @('File.TryFlush','ByVal Token As Long, ByRef Failure As Long','Boolean'),
    @('Error.Set','ByVal Number As Long','Boolean')
)
$roleBody=''
for($index=0;$index -lt $roles.Count;$index++) { $roleBody+=Primitive-Source ('P'+($index+1)) $roles[$index][1] $roles[$index][2] $roles[$index][0] }
$roleBody+="Public Function TryRead() As Long`r`nTryRead = 1`r`nEnd Function`r`n"
$roleText=Module-Source 'DeclaredRoles' ($roleBody.Replace('Attribute P1.UBE_Primitive = "Array.Length"','Attribute p1.UBE_Primitive = "aRrAy.LeNgTh"'))
$rolePath=Join-Path $artifacts 'declared-roles.bas'
Write-Text $rolePath $roleText
Start-Project
Append-Source $rolePath
$value=Call-Probe 'Bind' @(0,0)
Check-Value $value 0 'all eleven exact role signatures accepted'
$roleNodes=@()
for($index=0;$index -lt $roles.Count;$index++) {
    $name='P'+($index+1)
    $node=Find-Declaration $roleText ('Function '+$name+'(') $name 8
    $roleNodes+=$node
    $value=Call-Probe 'RoleValue' @($node)
    Check-Value $value ($index+1) ('canonical role '+$roles[$index][0])
}
$ordinary=Find-Declaration $roleText 'Function TryRead()' 'TryRead' 8
$value=Call-Probe 'RoleValue' @($ordinary)
Check-Value $value 0 'ordinary familiar spelling carries no primitive authority'
$value=Call-Probe 'InvalidRolePlacements'
Check-Value $value 0 'roles exist only on procedure declarations'
$roleCapacity=Call-Probe 'RetainedCount' @(0)
$script:passed++
$roleNegatives=New-Object 'System.Collections.Generic.List[object]'
for($index=0;$index -lt $roles.Count;$index++) {
    $wrong='Long'; if($index -eq 0){$wrong='Boolean'}
    $roleNegatives.Add(@(('wrong result '+$roles[$index][0]),(Primitive-Source 'Wrong' $roles[$index][1] $wrong $roles[$index][0]),3,5,0))
}
$roleNegatives.Add(@('missing attribute',"Public Intrinsic Function Wrong(ByRef Values() As Byte) As Long`r`nEnd Function",3,2,0))
$roleNegatives.Add(@('duplicate attribute',((Primitive-Source 'Wrong' $roles[0][1] 'Long' 'Array.Length').Replace('End Function',('Attribute Wrong.UBE_Primitive = "Array.Length"'+"`r`nEnd Function"))),3,2,0))
$roleNegatives.Add(@('wrong target',((Primitive-Source 'Wrong' $roles[0][1] 'Long' 'Array.Length').Replace('Attribute Wrong.','Attribute Other.')),3,3,0))
$roleNegatives.Add(@('ordinary attribute',((Primitive-Source 'Wrong' $roles[0][1] 'Long' 'Array.Length').Replace('Public Intrinsic Function','Public Function')),3,1,0))
$roleNegatives.Add(@('unknown role',(Primitive-Source 'Wrong' $roles[0][1] 'Long' 'Memory.Collect'),8,1,0))
$roleNegatives.Add(@('whitespace role not normalized',(Primitive-Source 'Wrong' $roles[0][1] 'Long' ' Array.Length'),8,1,0))
$roleNegatives.Add(@('array by value',(Primitive-Source 'Wrong' 'ByVal Values() As Byte' 'Long' 'Array.Length'),3,5,0))
$roleNegatives.Add(@('file output by value',(Primitive-Source 'Wrong' 'ByVal Token As Long, ByRef Failure As Long' 'Boolean' 'File.TryClose'),3,5,0))
$roleNegatives.Add(@('file byte element mismatch',(Primitive-Source 'Wrong' ($roles[4][1].Replace('As Byte','As Integer')) 'Boolean' 'File.TryOpen'),3,5,0))
$roleNegatives.Add(@('scalar instead of array',(Primitive-Source 'Wrong' 'ByRef Values As Byte' 'Long' 'Array.Length'),3,5,0))
$roleNegatives.Add(@('extra parameter',(Primitive-Source 'Wrong' 'ByVal Number As Long, ByVal Extra As Long' 'Boolean' 'Error.Set'),3,5,0))
$roleNegatives.Add(@('Intrinsic Main entry',(Primitive-Source 'Main' $roles[0][1] 'Long' 'Array.Length'),3,6,-1))
foreach($case in $roleNegatives) {
    Start-Project
    $path=Join-Path $artifacts ($case[0]+'.bas')
    Write-Text $path (Module-Source 'InvalidRole' $case[1])
    Append-Source $path
    $value=Call-Probe 'Bind' @(0,$case[4])
    Check-Value $value 1 ('reject '+$case[0])
    foreach($pair in @(@(0,$case[2]),@(1,$case[3]))) { $value=Call-Probe 'DiagnosticField' @($pair[0]); Check-Value $value $pair[1] ('diagnostic '+$case[0]) }
    $value=Call-Probe 'OutputCount' @(0); Check-Value $value 0 'role failure count zero'
    $value=Call-Probe 'RetainedCount' @(0); Check-Value $value $roleCapacity 'role failure preserves backing'
    $value=Call-Probe 'RoleValue' @($roleNodes[0]); Check-Value $value 1 'role failure preserves prior identity'
    $script:passed++
}

$layoutText=Module-Source 'StorageValues' @'
Public Type Inner
    Small As Byte
    Wide As LongLong
End Type
Public Type Outer
    Header As Long
    Nested As Inner
    Flag As Boolean
End Type
Private Fixed(-2 To 1) As Outer
Private Dynamic() As Inner
Private Scalar As Integer
Public Sub Inspect(ByRef Items() As Outer, ByRef Item As Inner, ByVal Number As Long)
    Dim Local As Outer
    Dim Scalars(0 To 2) As Long
    Dim Value As Long = Items(Number).Header
    Dim FlagValue As Boolean = Items(Number).Flag
    Value = Scalars(Number)
End Sub
'@
$layoutPath=Join-Path $artifacts 'storage-values.bas'
Write-Text $layoutPath $layoutText
Start-Project
Append-Source $layoutPath
$value=Call-Probe 'Bind' @(1,0)
Check-Value $value 0 'finite nested records and owned/borrowed arrays'
$inner=Find-Declaration $layoutText 'Type Inner' 'Inner' 5
$outer=Find-Declaration $layoutText 'Type Outer' 'Outer' 5
$header=Find-Declaration $layoutText 'Header As Long' 'Header' 6
$nested=Find-Declaration $layoutText 'Nested As Inner' 'Nested' 6
$flag=Find-Declaration $layoutText 'Flag As Boolean' 'Flag' 6
Layout-Equals $inner 0 2 'Inner flattened element width'
Layout-Equals $outer 1 4 'Outer flattened storage width'
Layout-Equals $header 2 0 'first field offset'
Layout-Equals $nested 2 1 'nested record field offset'
Layout-Equals $nested 0 2 'nested record field width'
Layout-Equals $flag 2 3 'last field offset after nested record'
$fixed=Find-Declaration $layoutText 'Fixed(-2 To 1)' 'Fixed' 3
$dynamic=Find-Declaration $layoutText 'Dynamic()' 'Dynamic' 3
$borrowed=Find-Declaration $layoutText 'ByRef Items()' 'Items' 9
$byrefRecord=Find-Declaration $layoutText 'ByRef Item As Inner' 'Item' 9
$local=Find-Declaration $layoutText 'Local As Outer' 'Local' 3
Layout-Equals $fixed 0 4 'fixed array element stride'
Layout-Equals $fixed 1 20 'fixed array four descriptors plus four records'
Layout-Equals $dynamic 0 2 'dynamic record array stride'
Layout-Equals $dynamic 1 4 'dynamic owner only descriptor'
Layout-Equals $borrowed 0 4 'borrowed array retains known element stride'
Layout-Equals $borrowed 1 0 'borrowed array has no owned cells'
Layout-Equals $byrefRecord 1 2 'ByRef record logical value width, not pointer ABI'
Layout-Equals $local 1 4 'local record flattened width'
$indexed=Find-Expression $layoutText 'Items(Number)' 15
Layout-Equals $indexed 0 4 'indexed record element width'
Layout-Equals $indexed 1 4 'indexed record logical value storage'
$scalarIndex=Find-Expression $layoutText 'Scalars(Number)' 15
Layout-Equals $scalarIndex 0 1 'indexed scalar element width'
Layout-Equals $scalarIndex 1 1 'indexed scalar has one logical value cell'
$indexedField=Find-Expression $layoutText 'Items(Number).Flag' 14
Layout-Equals $indexedField 0 1 'indexed-record field width'
Layout-Equals $indexedField 2 3 'indexed-record field offset relative to element'
$layoutCapacity=Call-Probe 'RetainedCount' @(1)
$script:passed++
foreach($mode in @(1,2,3)) {
    Start-Project
    Append-Source $layoutPath
    $value=Call-Probe 'CorruptShape' @($mode); Check-Value $value 0 'controlled shape metadata mutation'
    $value=Call-Probe 'Bind' @(1,0); Check-Value $value 1 'invalid shape metadata rejected'
    $value=Call-Probe 'DiagnosticField' @(0); Check-Value $value 9 'shape input diagnostic'
    $value=Call-Probe 'DiagnosticField' @(1); Check-Value $value 46 'shape metadata diagnostic reason'
    $value=Call-Probe 'OutputCount' @(1); Check-Value $value 0 'invalid shape publishes no layout'
    $value=Call-Probe 'RetainedCount' @(1); Check-Value $value $layoutCapacity 'invalid shape preserves old output'
    Layout-Equals $outer 1 4 'invalid shape retains prior record facts'
    $script:passed++
}
$layoutNegatives=New-Object 'System.Collections.Generic.List[object]'
Start-Project
$source=Module-Source 'InvalidRankOnly' ((Primitive-Source 'Measure' 'ByRef Values() As Byte' 'Long' 'Array.Length')+"Dim Owned(0 To 1) As Byte`r`n")
$path=Join-Path $artifacts 'rank-only-with-children.bas'; Write-Text $path $source; Append-Source $path
$value=Call-Probe 'CorruptShape' @(4); Check-Value $value 0 'rank-only parameter retains complete fixed-bound subtree mutation'
foreach($mode in @(0,1)) {
    $value=Call-Probe 'Bind' @($mode,0); Check-Value $value 1 'rank-only shape with bounds rejected by both passes'
    $code=3; $reason=5; if($mode -eq 1){$code=9; $reason=46}
    $value=Call-Probe 'DiagnosticField' @(0); Check-Value $value $code 'rank-only bounds category'
    $value=Call-Probe 'DiagnosticField' @(1); Check-Value $value $reason 'rank-only bounds reason'
    $value=Call-Probe 'OutputCount' @($mode); Check-Value $value 0 'rank-only bounds publish no partial output'
}
$script:passed++
Start-Project
Append-Source $layoutPath
$value=Call-Probe 'CorruptPrimitivePlacement'; Check-Value $value 0 'primitive metadata placement mutation'
$value=Call-Probe 'Bind' @(0,0); Check-Value $value 1 'module-level primitive metadata rejected'
$value=Call-Probe 'DiagnosticField' @(0); Check-Value $value 9 'primitive placement input diagnostic'
$value=Call-Probe 'DiagnosticField' @(1); Check-Value $value 1 'primitive placement diagnostic reason'
$value=Call-Probe 'OutputCount' @(0); Check-Value $value 0 'invalid placement publishes no roles'
$value=Call-Probe 'RetainedCount' @(0); Check-Value $value $roleCapacity 'invalid placement preserves old role storage'
$value=Call-Probe 'RoleValue' @($roleNodes[0]); Check-Value $value 1 'invalid placement preserves old role identity'
$script:passed++
$layoutNegatives.Add(@('unused recursive type',"Type Recursive`r`nSelf As Recursive`r`nEnd Type",8,40))
$layoutNegatives.Add(@('mutual recursive types',"Type First`r`nOther As Second`r`nEnd Type`r`nType Second`r`nOther As First`r`nEnd Type",8,40))
$record128="Type Wide`r`n"
for($index=0;$index -lt 128;$index++){ $record128+='F'+$index+" As Long`r`n" }
$record129=$record128+"Extra As Long`r`nEnd Type"
$record128+="End Type"
$layoutNegatives.Add(@('record cell129',$record129,6,42))
$depth64=''; $depth65=''
for($index=0;$index -lt 65;$index++) {
    $next='Long'; if($index -lt 64){$next='T'+($index+1)}
    $depth65+='Type T'+$index+"`r`nValue As "+$next+"`r`nEnd Type`r`n"
    if($index -lt 64){ $next='Long'; if($index -lt 63){$next='T'+($index+1)}; $depth64+='Type T'+$index+"`r`nValue As "+$next+"`r`nEnd Type`r`n" }
}
$layoutNegatives.Add(@('record depth65',$depth65,6,41))
$layoutNegatives.Add(@('module context65537','Dim Values(0 To 65532) As Long',6,43))
foreach($case in $layoutNegatives) {
    Start-Project
    $path=Join-Path $artifacts ($case[0]+'.bas')
    Write-Text $path (Module-Source 'InvalidLayout' $case[1])
    Append-Source $path
    $value=Call-Probe 'Bind' @(1,0); Check-Value $value 1 ('reject '+$case[0])
    foreach($pair in @(@(0,$case[2]),@(1,$case[3]))) { $value=Call-Probe 'DiagnosticField' @($pair[0]); Check-Value $value $pair[1] ('layout diagnostic '+$case[0]) }
    $value=Call-Probe 'OutputCount' @(1); Check-Value $value 0 'layout failure count zero'
    $value=Call-Probe 'RetainedCount' @(1); Check-Value $value $layoutCapacity 'layout failure preserves backing'
    Layout-Equals $outer 1 4 'layout failure preserves old record facts'
    $script:passed++
}
foreach($case in @(@('record128',$record128,'Type Wide','Wide',5,128),@('depth64',$depth64,'Type T0','T0',5,1),@('context65536','Dim Values(0 To 65531) As Long','Values(','Values',3,65536))) {
    Start-Project
    $path=Join-Path $artifacts ($case[0]+'.bas')
    $source=Module-Source 'Boundary' $case[1]
    Write-Text $path $source
    Append-Source $path
    $value=Call-Probe 'Bind' @(1,0); Check-Value $value 0 ('exact boundary '+$case[0])
    $node=Find-Declaration $source $case[2] $case[3] $case[4]
    Layout-Equals $node 1 $case[5] ('exact storage '+$case[0])
    $script:passed++
}
# Logical array bounds include signed64 extrema without overflowing extent calculation.
$extreme=Module-Source 'ExtremeBounds' "Dim Low(-9223372036854775808^ To -9223372036854775808^) As Byte`r`nDim High(9223372036854775807^ To 9223372036854775807^) As Long"
Start-Project
$path=Join-Path $artifacts 'extreme-bounds.bas'; Write-Text $path $extreme; Append-Source $path
$value=Call-Probe 'Bind' @(1,0); Check-Value $value 0 'single elements at signed64 bounds'
foreach($name in @('Low','High')) { $node=Find-Declaration $extreme ($name+'(') $name 3; Layout-Equals $node 1 5 'four descriptor cells plus one extreme-index element' }
$script:passed++
# Qualified and unqualified names selecting the same record satisfy TryCopy's nominal rule.
$nominalPrefix="Public Type Item`r`nValue As Long`r`nEnd Type`r`nPublic Type Other`r`nValue As Long`r`nEnd Type`r`n"
foreach($same in @($true,$false)) {
    $sourceType='CopyRecords.Item'; if(-not $same){$sourceType='Other'}
    $source=Module-Source 'CopyRecords' ($nominalPrefix+(Primitive-Source 'CopyValues' ('ByRef Destination() As Item, ByRef Source() As '+$sourceType) 'Boolean' 'Array.TryCopy'))
    Start-Project
    $path=Join-Path $artifacts ('nominal-copy-'+$same+'.bas'); Write-Text $path $source; Append-Source $path
    $value=Call-Probe 'Bind' @(0,0)
    if($same){
        Check-Value $value 0 'TryCopy resolves qualified nominal identity'
        $node=Find-Declaration $source 'Function CopyValues(' 'CopyValues' 8
        $value=Call-Probe 'RoleValue' @($node); Check-Value $value 4 'TryCopy nominal role identity'
    }else{
        Check-Value $value 1 'TryCopy rejects structurally equal unrelated records'
        $value=Call-Probe 'DiagnosticField' @(0); Check-Value $value 3 'nominal signature diagnostic'
        $value=Call-Probe 'DiagnosticField' @(1); Check-Value $value 6 'nominal signature mismatch reason'
    }
    $script:passed++
}
# Library Main remains an arbitrary intrinsic declaration name.
Start-Project
$source=Module-Source 'LibraryMain' (Primitive-Source 'Main' 'ByRef Values() As Long' 'Long' 'Array.Length')
$path=Join-Path $artifacts 'library-main.bas'; Write-Text $path $source; Append-Source $path
$value=Call-Probe 'Bind' @(0,0); Check-Value $value 0 'Library intrinsic Main is not an executable entry'
$node=Find-Declaration $source 'Function Main(' 'Main' 8
$value=Call-Probe 'RoleValue' @($node); Check-Value $value 1 'Library arbitrary Main role'
$script:passed++
# A body in an intrinsic declaration is rejected by the actual parser before binding.
Start-Project
$path=Join-Path $artifacts 'intrinsic-body.bas'
$source=Module-Source 'InvalidBody' ((Primitive-Source 'Wrong' $roles[0][1] 'Long' 'Array.Length').Replace('End Function',"Wrong = 1`r`nEnd Function"))
Write-Text $path $source
$pathBytes=$utf8.GetBytes($path)
$value=Call-Probe 'ConfigurePath' @($pathBytes.Length); Check-Value $value 0 'invalid-body path allocated'
for($index=0;$index -lt $pathBytes.Length;$index++){ $value=Call-Probe 'SetPathByte' @($index,$pathBytes[$index]); Check-Value $value 0 'invalid-body path byte' }
$value=Call-Probe 'AppendFile'; Check-Value $value 2 'intrinsic implementation body rejected during parsing'
$value=Call-Probe 'ProjectDiagnosticField' @(0); Check-Value $value 2 'intrinsic body parser stage'
$script:passed++
# Actual source declarations and bodies qualify both independent complete passes.
$goodPath=Join-Path $artifacts 'diagnostic-first.bas'
Write-Text $goodPath (Module-Source 'FirstModule' "Sub Work()`r`nEnd Sub")
foreach($mode in @(0,1)) {
    Start-Project
    Append-Source $goodPath
    if($mode -eq 0){
        $source=Module-Source 'SecondModule' ((Primitive-Source 'Broken' $roles[0][1] 'Long' 'Array.Length').Replace('Attribute Broken.','Attribute Other.'))
        $needle='Attribute Other.'; $code=3; $reason=3; $line=4
    }else{
        $source=Module-Source 'SecondModule' $record129
        $needle='Extra As Long'; $code=6; $reason=42; $line=132
    }
    $path=Join-Path $artifacts ('diagnostic-second-'+$mode+'.bas')
    Write-Text $path $source; Append-Source $path
    $value=Call-Probe 'Bind' @($mode,0); Check-Value $value 1 'new pass second-module diagnostic'
    $offset=$source.IndexOf($needle,[StringComparison]::Ordinal)
    foreach($pair in @(@(0,$code),@(1,$reason),@(2,1),@(5,$offset),@(6,($offset+1)),@(7,$line),@(8,1))) {
        $value=Call-Probe 'DiagnosticField' @($pair[0]); Check-Value $value $pair[1] 'new pass exact original second-module coordinate'
    }
    $script:passed++
}
foreach($excess in @(0,1)) {
    Start-Project
    for($module=0;$module -lt 2;$module++) {
        $upper=32763
        if($module -eq 1){$upper+=$excess}
        $source=Module-Source ('Context'+$module) ('Dim Values(0 To '+$upper+') As Long')
        $path=Join-Path $artifacts ('split-context-'+$excess+'-'+$module+'.bas')
        Write-Text $path $source; Append-Source $path
    }
    $value=Call-Probe 'Bind' @(1,0); Check-Value $value $excess 'module storage limit applies to total project context'
    if($excess -eq 1){
        $value=Call-Probe 'DiagnosticField' @(0); Check-Value $value 6 'aggregate context limit category'
        $value=Call-Probe 'DiagnosticField' @(1); Check-Value $value 43 'aggregate context limit reason'
        $value=Call-Probe 'DiagnosticField' @(2); Check-Value $value 1 'aggregate context limit points to second module'
    }
    $script:passed++
}
Start-Project 'CompilerSources'
foreach($file in $files){Append-Source $file}
foreach($mode in @(0,1)) {
    $value=Call-Probe 'Bind' @($mode,0); Check-Value $value 0 'actual compiler/library semantic storage pass'
    $value=Call-Probe 'OutputCount' @($mode); Check-Value $value 18000 'substantial actual project facts' 'sge'
    $script:passed++
}
# Repeat the original layout project after failures and unrelated source projects.
Start-Project
Append-Source $layoutPath
$value=Call-Probe 'Bind' @(1,0); Check-Value $value 0 'independent layout request recovery'
Layout-Equals $fixed 1 20 'original layout identity and size reproducible'
$script:passed++
$lines.Add('  %disposed = call i1 @ube.context.dispose(ptr %ctx)')
$lines.Add('  %disposed.wide = zext i1 %disposed to i64')
Check-Value '%disposed.wide' 1 'all project and semantic result owners disposed'
$lines.Add("  ret i32 $script:failure")
$lines.Add('}')
$harness=Join-Path $artifacts 'storage-check.ll'
Write-Text $harness ($emitted+"`r`n@test.context = private global %ube.context zeroinitializer, align 8`r`n"+($lines -join "`r`n")+"`r`n")
Write-Text (Join-Path $artifacts 'assertions.txt') ($assertions -join "`r`n")
foreach($level in @('O0','O2')) {
    $exe=Join-Path $artifacts ("storage-check-$level.exe")
    Build-Harness $harness $exe $level
    $result=Invoke-BoundedProcess $exe @() 60000
    Require ($result.ExitCode -eq 0) "Semantic storage $level assertion $($result.ExitCode) failed; see assertions.txt and $($result.Evidence)"
    Write-Output "PASS: $script:passed semantic storage cases and $($assertions.Count) assertions $level"
}
# Same-width scalar roles have identical signatures; metadata selects their distinct authority.
Write-Text $rolePath ($roleText.Replace('File.TryRead','File.TryWrite'))
try{
    $result=Invoke-BoundedProcess $exe @() 60000
    $expected=[int](($assertions | Where-Object {$_ -match ' canonical role File.TryRead$'} | Select-Object -First 1) -split ' ')[0]
    Require ($result.ExitCode -eq $expected) 'Changed role metadata must fail the exact unchanged role assertion'
    Write-Output "PASS: changed runtime primitive role rejected at assertion $expected"
}finally{Write-Text $rolePath $roleText}
Write-Output "PASS: semantic storage gate. Evidence: $artifacts"
