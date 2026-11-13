# Verifies native storage, borrow-slot and initialization planning over runtime-loaded UBE projects.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube native planning ' + [guid]::NewGuid())
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
$files=@('BufferPrimitives.bas','FilePrimitives.bas','FileBytes.bas','Utf8.bas') | ForEach-Object {Join-Path $coreDirectory $_}
$files+=@('SourceScanner.bas','SyntaxTokens.bas','SourceParser.bas','ProjectSyntax.bas','DeclarationBinder.bas','ConstantValues.bas','ExpressionBinder.bas','PrimitiveRoles.bas','AggregateLayout.bas','NativePlanning.bas') | ForEach-Object {Join-Path $compilerDirectory $_}
$files+=Join-Path $PSScriptRoot 'Probe.bas'
$manifest=Copy-Fixtures 'library' $files '2' 'Library'
$procedures=Read-Procedures $manifest
$libraryIR=Join-Path $artifacts 'planning.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$libraryIR) 'EMIT OK'
$emitted=[IO.File]::ReadAllText($libraryIR,$utf8)
$script:lines=New-Object 'System.Collections.Generic.List[string]'
$script:assertions=New-Object 'System.Collections.Generic.List[string]'
$script:sequence=0;$script:failure='0'
$lines.Add('define i32 @main() {');$lines.Add('entry:')
$lines.Add('  %ctx = getelementptr %ube.context, ptr @test.context, i32 0')
$lines.Add('  call void @ube.context.init(ptr %ctx)')
$lines.Add('  %initialized = call i1 @ube.project.init(ptr %ctx)')

# Creates a runtime-input project and independently compares the established host's native admission.
function Plan-Project([string]$Name,[string[]]$Sources,[int]$Code=0,[int]$Reason=0,[bool]$Executable=$false){
    Start-Project
    $folder=Join-Path $artifacts $Name;$null=New-Item -ItemType Directory $folder
    $kind='Library';$exeFlag=0;if($Executable){$kind='Exe';$exeFlag=-1}
    $manifestLines=@('UBE-Project 1','Name = "BindingFixture"',('Kind = "'+$kind+'"'))
    if($Executable){$manifestLines+='Startup = "Main"'}
    $number=0;$paths=@()
    foreach($source in $Sources){$path=Join-Path $folder ("source-$number.bas");Write-Text $path $source;Append-Source $path;$paths+=$path;$manifestLines+='Source = "'+[IO.Path]::GetFileName($path)+'"';$number++}
    $hostProject=Join-Path $folder 'project.UBE';Write-Text $hostProject ($manifestLines-join "`r`n")
    $hostResult=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$hostProject,(Join-Path $folder 'host.ll'))
    $expected=0;if($Code -ne 0){$expected=1}
    Require ($hostResult.ExitCode -eq $expected) "Host admission mismatch $Name : $($hostResult.Evidence)"
    if($Code -ne 0){$category='E_UNSUPPORTED';if($Code -eq 6){$category='E_LIMIT'};Require ($hostResult.Stderr -match $category) "Host category mismatch $Name"}
    $value=Call-Probe 'Bind' @($exeFlag);Check-Value $value $expected "$Name native planning status"
    if($Code -eq 0){$value=Call-Probe 'SummaryField' @(0);Check-Value $value 0 "$Name valid summary" 'sgt'}else{
        $value=Call-Probe 'DiagnosticField' @(0);Check-Value $value $Code "$Name diagnostic code"
        $value=Call-Probe 'DiagnosticField' @(1);Check-Value $value $Reason "$Name diagnostic reason"
        foreach($field in 0..4){$value=Call-Probe 'SummaryField' @($field);Check-Value $value 0 "$Name invalid summary cleared"}
        $value=Call-Probe 'DiagnosticField' @(7);Check-Value $value 0 "$Name positive source line" 'sgt'
    }
    $script:passed++
    return ,$paths
}

$frameText=Module-Source 'Frames' @'
Type Pair
First As Long
Second As Long
End Type
Public Sub Take(ByRef Value As Long)
End Sub
Public Function Work(ByRef Item As Pair, ByVal Seed As Long) As Long
Dim A As Pair
Dim B As Pair
Dim Buffer(0 To 2) As Long
Dim Value As Long
Dim Same As Boolean
A = B
Same = A = B
Take (Seed)
Buffer(Seed) = Buffer(Seed) + Buffer(Seed)
Value = Buffer(Seed)
Work = Value
End Function
'@
$framePaths=Plan-Project 'frame-facts' @($frameText)
$value=Call-Probe 'CheckScopeLists' @();Check-Value $value 0 'ascending scope ownership lists'
$work=Find-Declaration $frameText 'Function Work' 'Work' 8
$take=Find-Declaration $frameText 'Sub Take' 'Take' 7
$result=Find-Declaration $frameText 'Function Work' 'Work' 30
foreach($entry in @(@($work,1,30,'complete frame cells'),@($work,2,3,'maximum simultaneous statement pins'),@($work,3,$result,'result identity'),@($take,1,5,'ByRef scalar pointer frame'))){$value=Call-Probe 'PlanField' @($entry[0],$entry[1]);Check-Value $value $entry[2] $entry[3]}
foreach($occurrence in 0..3){$node=Find-Expression $frameText 'Buffer(Seed)' 15 0 $occurrence;$value=Call-Probe 'PinValue' @($node);$expected=$occurrence+1;if($occurrence -eq 3){$expected=1};Check-Value $value $expected 'statement-lifetime borrow slot reuse'}
$value=Call-Probe 'RejectPreconditions';Check-Value $value 0 'explicit malformed scalar preconditions clear summary without raw-fact authority'
$value=Call-Probe 'Bind' @(0);Check-Value $value 0 'recovery after rejected scratch request'

foreach($excess in @(0,1)){
    $text=Module-Source 'FrameLimit' ("Public Sub Work()`r`nDim Values(0 To "+(119+$excess)+") As Long`r`nEnd Sub")
    $code=0;$reason=0;if($excess){$code=6;$reason=50}
    $null=Plan-Project "frame-limit-$excess" @($text) $code $reason
    if(-not $excess){$symbol=Find-Declaration $text 'Sub Work' 'Work' 7;$value=Call-Probe 'PlanField' @($symbol,1);Check-Value $value 128 'exact 128-cell frame admitted'}
}
foreach($count in @(64,65)){
    $parameters=(1..$count|ForEach-Object{'ByVal Arg'+$_+' As Long'})-join ', '
    $text=Module-Source 'ParameterLimit' ('Public Sub Work('+$parameters+")`r`nEnd Sub")
    $code=0;$reason=0;if($count -eq 65){$code=6;$reason=51}
    $null=Plan-Project "parameters-$count" @($text) $code $reason
}
foreach($hook in @('Module_Initialize','mOdUlE_TeRmInAtE','[MoDuLe_InItIaLiZe]')){
    $null=Plan-Project $hook @((Module-Source 'Hooks' ("Public Sub $hook()`r`nEnd Sub"))) 8 50
}
$null=Plan-Project 'near-hook' @((Module-Source 'Hooks' "Public Sub Module_InitializeExtra()`r`nEnd Sub"))
$null=Plan-Project 'root-raise' @((Module-Source 'Root' "Public Sub Main()`r`nErr.Raise 5`r`nEnd Sub")) 8 51 $true
$null=Plan-Project 'library-main-raise' @((Module-Source 'Root' "Public Sub Main()`r`nErr.Raise 5`r`nEnd Sub"))

$first=Module-Source 'First' "Public Flag As Long`r`nPublic Values(0 To 2) As Long"
$second=Module-Source 'Second' "Public Bytes() As Byte`r`nPublic Number As Long"
$null=Plan-Project 'context-offsets' @($first,$second)
foreach($entry in @(@($first,'Flag As Long','Flag',0,0),@($first,'Values(0 To 2)','Values',0,1),@($second,'Bytes()','Bytes',1,8),@($second,'Number As Long','Number',1,12))){$symbol=Find-Declaration $entry[0] $entry[1] $entry[2] 3 $entry[3];$value=Call-Probe 'PlanField' @($symbol,0);Check-Value $value $entry[4] 'module offset across ordered modules'}
$value=Call-Probe 'SummaryField' @(3);Check-Value $value 13 'total context cells'

$a=Module-Source 'A' "Public Value As Long = B.ReadValue()`r`nPublic Function ReadValue() As Long`r`nReadValue = Value`r`nEnd Function"
$b=Module-Source 'B' "Public Value As Long = C.ReadValue()`r`nPublic Function ReadValue() As Long`r`nReadValue = Value`r`nEnd Function"
$c=Module-Source 'C' "Public Value As Long = 1`r`nPublic Function ReadValue() As Long`r`nReadValue = Value`r`nEnd Function"
$null=Plan-Project 'initialization-chain' @($a,$b,$c)
foreach($row in 0..2){foreach($column in 0..2){$expected=0;if($column -gt $row){$expected=1};$value=Call-Probe 'Dependency' @($row,$column);Check-Value $value $expected 'dependency transitive closure chain'}}
$a=Module-Source 'A' "Public Value As Long = B.LeftValue() + C.RightValue()"
$b=Module-Source 'B' "Public Function LeftValue() As Long`r`nLeftValue = D.ReadValue()`r`nEnd Function"
$c=Module-Source 'C' "Public Function RightValue() As Long`r`nRightValue = D.ReadValue()`r`nEnd Function"
$d=Module-Source 'D' "Public Function ReadValue() As Long`r`nReadValue = 1`r`nEnd Function"
$null=Plan-Project 'initialization-diamond' @($a,$b,$c,$d)
foreach($column in 1..3){$value=Call-Probe 'Dependency' @(0,$column);Check-Value $value 1 'initializer traverses source call diamond'}
$a=Module-Source 'A' "Public Value As Long = B.ReadValue()`r`nPublic Function ReadValue() As Long`r`nReadValue = Value`r`nEnd Function"
$b=Module-Source 'B' "Public Value As Long = A.ReadValue()`r`nPublic Function ReadValue() As Long`r`nReadValue = Value`r`nEnd Function"
$null=Plan-Project 'initialization-cycle' @($a,$b) 8 52
$a=Module-Source 'A' "Public Value As Long = B.ReadValue()`r`nPublic Function ReadValue() As Long`r`nReadValue = 1`r`nEnd Function"
$b=Module-Source 'B' "Public Function ReadValue() As Long`r`nReadValue = A.ReadValue()`r`nEnd Function"
$null=Plan-Project 'call-return-to-origin' @($a,$b) 8 52
$offset=$b.IndexOf('A.ReadValue()');$value=Call-Probe 'DiagnosticField' @(2);Check-Value $value 1 'cycle diagnostic second module'
$value=Call-Probe 'DiagnosticField' @(5);Check-Value $value $offset 'cycle diagnostic original source byte offset'
$recursive=Module-Source 'Recursion' "Public Value As Long = Again(1)`r`nPublic Function Again(ByVal N As Long) As Long`r`nIf N > 0 Then`r`nAgain = Again(N - 1)`r`nEnd If`r`nEnd Function"
$null=Plan-Project 'same-module-recursion' @($recursive)
$value=Call-Probe 'Dependency' @(0,0);Check-Value $value 0 'same-module recursion is not a cross-module cycle'

Start-Project 'CompilerSources'
foreach($file in $files){Append-Source $file}
$value=Call-Probe 'Bind' @(0);Check-Value $value 0 'actual compiler and library bodies pass native planning'
$value=Call-Probe 'SummaryField' @(1);Check-Value $value 20000 'actual substantial syntax input' 'sge'
$script:passed++
$lines.Add('  %disposed = call i1 @ube.context.dispose(ptr %ctx)')
$lines.Add('  %disposed.wide = zext i1 %disposed to i64');Check-Value '%disposed.wide' 1 'all planning/project owners disposed'
$lines.Add("  ret i32 $script:failure");$lines.Add('}')
$harness=Join-Path $artifacts 'planning-check.ll'
Write-Text $harness ($emitted+"`r`n@test.context = private global %ube.context zeroinitializer, align 8`r`n"+($lines-join "`r`n"))
Write-Text (Join-Path $artifacts 'assertions.txt') ($assertions-join "`r`n")
foreach($level in @('O0','O2')){
    $exe=Join-Path $artifacts "planning-$level.exe";Build-Harness $harness $exe $level
    $result=Invoke-BoundedProcess $exe @() 60000
    Require ($result.ExitCode -eq 0) "Planning $level assertion $($result.ExitCode) failed: $($result.Evidence)"
    Write-Output "PASS: $script:passed planning cases, $($assertions.Count) assertions $level"
    Write-Text $framePaths[0] ($frameText.Replace('Buffer(0 To 2)','Buffer(0 To 3)'))
    try{$result=Invoke-BoundedProcess $exe @() 60000;$expected=[int](($assertions|Where-Object{$_ -match ' complete frame cells$'}|Select-Object -First 1)-split ' ')[0];Require ($result.ExitCode -eq $expected) "Changed frame input control expected $expected got $($result.ExitCode)";Write-Output "PASS: runtime frame mutation detected exactly at assertion $expected $level"}finally{Write-Text $framePaths[0] $frameText}
}
Write-Output "PASS: native planning gate. Evidence: $artifacts"
