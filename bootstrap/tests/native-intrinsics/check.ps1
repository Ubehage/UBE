# Verifies identity-bound intrinsic wrappers emitted by actual UBE source.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube native intrinsics ' + [guid]::NewGuid())
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
$files=@('BufferPrimitives','FilePrimitives','FileBytes','ByteText','Utf8') | ForEach-Object {Join-Path $root ('std-lib/src/portable/'+$_+'.bas')}
$files+=@('SourceScanner','SyntaxTokens','SourceParser','ProjectSyntax','DeclarationBinder','ConstantValues','ExpressionBinder','AggregateLayout','PrimitiveRoles','LLVMWriter','LLVMTemplates','LLVMFormat','NativeIntrinsics') | ForEach-Object {Join-Path $root ('compiler/src/'+$_+'.bas')}
$files+=Join-Path $PSScriptRoot 'Probe.bas'
$manifest=Copy-Fixtures 'emitter' $files '0' 'Library'
$library=Join-Path $artifacts 'emitter.ll'
$null=Invoke-Compiler @('--emit-llvm',$manifest,$library) 'EMIT OK'
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) 'Emitter binding failed'
$symbols=@{}
foreach($line in ($bound.Stdout -split '\r?\n')) {
    if($line -notmatch '^SYMBOL ') {continue}
    $f=$line.Substring(7).Split('|')
    if($f[5] -eq '18' -and $f[1] -in @('function','sub')) {$symbols[$f[2]]=$f[0]}
}
$emitted=[IO.File]::ReadAllText($library,$utf8)
$runtime=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'),$utf8)
$catalog=Join-Path $root 'compiler/llvm/templates.bin'
$roles=@(
 @('Array.Length','ByRef A() As Byte','Long'),
 @('Memory.CopyBytes','ByRef A() As Byte, ByVal S As Long, ByRef B() As Byte, ByVal D As Long, ByVal N As Long','Boolean'),
 @('Array.TryResize','ByRef A() As Byte, ByVal N As Long, ByVal P As Boolean','Boolean'),
 @('Array.TryCopy','ByRef A() As Byte, ByRef B() As Byte','Boolean'),
 @('File.TryOpen','ByRef A() As Byte, ByVal N As Long, ByRef T As Long, ByRef L As Long, ByRef F As Long','Boolean'),
 @('File.TryCreateNew','ByRef A() As Byte, ByRef T As Long, ByRef F As Long','Boolean'),
 @('File.TryRead','ByVal T As Long, ByRef A() As Byte, ByVal S As Long, ByVal N As Long, ByRef P As Long, ByRef F As Long','Boolean'),
 @('File.TryWrite','ByVal T As Long, ByRef A() As Byte, ByVal S As Long, ByVal N As Long, ByRef P As Long, ByRef F As Long','Boolean'),
 @('File.TryClose','ByRef T As Long, ByRef F As Long','Boolean'),
 @('File.TryFlush','ByVal T As Long, ByRef F As Long','Boolean'),
 @('Error.Set','ByVal N As Long','Boolean'),
 @('Array.TryResize','ByRef A() As Pair, ByVal N As Long, ByVal P As Boolean','Boolean'),
 @('Array.TryCopy','ByRef A() As Pair, ByRef B() As Pair','Boolean'))
$source="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Roles`"`r`nPublic Type Pair`r`n A As Long`r`n B As Long`r`nEnd Type`r`n"
for($i=0;$i -lt $roles.Count;$i++) {$source+='Public Intrinsic Function R'+($i+1)+'('+$roles[$i][1]+') As '+$roles[$i][2]+"`r`n"+'Attribute R'+($i+1)+'.UBE_Primitive = "'+$roles[$i][0]+"`"`r`nEnd Function`r`n"}
$source+="Public Function TryRead() As Long`r`nTryRead = 99`r`nEnd Function`r`n"
$sourcePath=Join-Path $artifacts 'roles.bas';Write-Text $sourcePath $source

# Runs the actual UBE parser, semantic passes and wrapper emitter on file bytes.
function Emit-Fragment([string]$Path,[string]$Level) {
    $lines=@('@test.ctx = private global %ube.context zeroinitializer, align 8','define i32 @main() {','entry:','  call void @ube.context.init(ptr @test.ctx)','  %init = call i1 @ube.project.init(ptr @test.ctx)')
    $paths=@($Path,$catalog,$sourcePath)
    for($p=0;$p -lt 3;$p++) {
        $bytes=$utf8.GetBytes($paths[$p])
        $lines+='  %configure'+$p+' = call { i1, i64 } @ube.proc.'+$symbols['ConfigurePath']+'(ptr @test.ctx, i64 '+$p+', i64 '+$bytes.Length+')'
        for($i=0;$i -lt $bytes.Length;$i++) {$lines+='  %path'+$p+'_'+$i+' = call { i1, i64 } @ube.proc.'+$symbols['SetPathByte']+'(ptr @test.ctx, i64 '+$p+', i64 '+$i+', i64 '+$bytes[$i]+')'}
    }
    $lines+=@(('  %result = call { i1, i64 } @ube.proc.'+$symbols['Emit']+'(ptr @test.ctx)'),'  %fresh = extractvalue { i1, i64 } %result, 0','  %value = extractvalue { i1, i64 } %result, 1','  %disposed = call i1 @ube.context.dispose(ptr @test.ctx)','  %ok = and i1 %fresh, %disposed','  %status = trunc i64 %value to i32','  %exit = select i1 %ok, i32 %status, i32 100','  ret i32 %exit','}')
    $ir=$Path+'.driver.ll';$exe=$Path+'.driver.exe'
    Write-Text $ir ($emitted+($lines -join "`r`n")+"`r`n")
    Build-Harness $ir $exe $Level
    $run=Invoke-BoundedProcess $exe @() 60000
    Require ($run.ExitCode -eq 0) "Wrapper emission failed $($run.ExitCode): $($run.Evidence)"
    return [IO.File]::ReadAllText($Path,$utf8)
}

# Adds exact native status/payload assertions; no sticky-error shortcut is used.
function Check-Result([string]$Name,[string]$Expected) {
    $script:assertion++
    $n=$script:assertion
    return "  %fresh$n = extractvalue { i1, i64 } $Name, 0`r`n  %value$n = extractvalue { i1, i64 } $Name, 1`r`n  %equal$n = icmp eq i64 %value$n, $Expected`r`n  %ok$n = and i1 %fresh$n, %equal$n`r`n"+(Check-Condition "%ok$n" $n)
}

# Fails with a stable assertion identity rather than accepting process completion alone.
function Check-Condition([string]$Condition,[int]$Number) {
    return "  br i1 $Condition, label %continue$Number, label %failure$Number`r`nfailure${Number}:`r`n  ret i32 $Number`r`ncontinue${Number}:`r`n"
}

foreach($level in @('O0','O2')) {
    $fragment=Emit-Fragment (Join-Path $artifacts ('wrappers-'+$level+'.ll')) $level
    if($level -eq 'O0') {$first=$fragment} else {Require ($first -ceq $fragment) 'Optimization changed wrapper emission'}
    $ids=@([regex]::Matches($fragment,'define \{ i1, i64 \} @ube.proc.([0-9]+)') | ForEach-Object {$_.Groups[1].Value})
    Require ($ids.Count -eq 13) 'Expected thirteen attributed wrappers, no ordinary-name wrapper'
    $proc=@{};for($i=1;$i -le 13;$i++) {$proc[$i]='@ube.proc.'+$ids[$i-1]}
    $filePath=Join-Path $artifacts ('roundtrip-'+$level+'.bin')
    $pathBytes=$utf8.GetBytes($filePath)
    $pathCells=($pathBytes | ForEach-Object {'i64 '+$_}) -join ', '
    $prefix="%ube.resource = type { i64, ptr, ptr, i64, i64 }`r`n%ube.context = type { i64, i64, [0 x i64], [0 x i64], ptr, i64, i64, [64 x %ube.resource] }`r`n"
    $globals="@ctx = private global %ube.context zeroinitializer, align 8`r`n@a = private global [4 x i64] zeroinitializer`r`n@b = private global [4 x i64] zeroinitializer`r`n@r = private global [4 x i64] zeroinitializer`r`n@s = private global [4 x i64] zeroinitializer`r`n@seed = private global i64 65`r`n@path.data = private global ["+$pathBytes.Length+" x i64] ["+$pathCells+"]`r`n@path = private global { i64, i64, ptr, ptr } { i64 0, i64 "+($pathBytes.Length-1)+", ptr @path.data, ptr null }`r`n"
    $body="define i32 @main() {`r`nentry:`r`n  %token = alloca i64`r`n  %failure = alloca i64`r`n  %progress = alloca i64`r`n  %length = alloca i64`r`n  store i64 0, ptr %token`r`n"
    $script:assertion=0
    $body+='  %set = call { i1, i64 } '+$proc[11]+"(ptr @ctx, i64 57)`r`n"+(Check-Result '%set' '0')
    $body+='  %resize = call { i1, i64 } '+$proc[3]+"(ptr @ctx, ptr @a, i64 5, i64 0)`r`n"+(Check-Result '%resize' '-1')
    $body+='  %len = call { i1, i64 } '+$proc[1]+"(ptr @ctx, ptr @a)`r`n"+(Check-Result '%len' '5')
    $body+="  %err = load i64, ptr @ctx`r`n  %sticky = icmp eq i64 %err, 57`r`n"+(Check-Condition '%sticky' 100)
    $body+="  %data.ptr = getelementptr i64, ptr @a, i64 2`r`n  %data = load ptr, ptr %data.ptr`r`n  %seed.value = load volatile i64, ptr @seed`r`n  store i64 %seed.value, ptr %data`r`n"
    for($i=1;$i -lt 5;$i++) {$body+="  %cell$i = getelementptr i64, ptr %data, i64 $i`r`n  store i64 "+(65+$i)+", ptr %cell$i`r`n"}
    $body+='  %back = call { i1, i64 } '+$proc[2]+"(ptr @ctx, ptr @a, i64 0, ptr @a, i64 1, i64 4)`r`n"+(Check-Result '%back' '-1')
    $body+='  %forward = call { i1, i64 } '+$proc[2]+"(ptr @ctx, ptr @a, i64 1, ptr @a, i64 0, i64 4)`r`n"+(Check-Result '%forward' '-1')
    $body+='  %bad = call { i1, i64 } '+$proc[2]+"(ptr @ctx, ptr @a, i64 4, ptr @a, i64 0, i64 2)`r`n"+(Check-Result '%bad' '0')
    $body+="  %bad.err = load i64, ptr @ctx`r`n  %bad.code = icmp eq i64 %bad.err, 9`r`n"+(Check-Condition '%bad.code' 101)
    $body+='  %negative = call { i1, i64 } '+$proc[2]+"(ptr @ctx, ptr @a, i64 0, ptr @a, i64 0, i64 -1)`r`n"+(Check-Result '%negative' '0')
    $body+="  %negative.err = load i64, ptr @ctx`r`n  %negative.code = icmp eq i64 %negative.err, 5`r`n"+(Check-Condition '%negative.code' 106)
    $body+='  %record = call { i1, i64 } '+$proc[12]+"(ptr @ctx, ptr @r, i64 2, i64 0)`r`n"+(Check-Result '%record' '-1')
    $body+="  %rdptr = getelementptr i64, ptr @r, i64 2`r`n  %rd = load ptr, ptr %rdptr`r`n  %field = getelementptr i64, ptr %rd, i64 3`r`n  store i64 987, ptr %field`r`n"
    $body+='  %record.grow = call { i1, i64 } '+$proc[12]+"(ptr @ctx, ptr @r, i64 3, i64 -1)`r`n"+(Check-Result '%record.grow' '-1')
    $body+='  %record.copy = call { i1, i64 } '+$proc[13]+"(ptr @ctx, ptr @s, ptr @r)`r`n"+(Check-Result '%record.copy' '-1')
    $body+="  %sdptr = getelementptr i64, ptr @s, i64 2`r`n  %sd = load ptr, ptr %sdptr`r`n  %sfptr = getelementptr i64, ptr %sd, i64 3`r`n  %sf = load i64, ptr %sfptr`r`n  %stride = icmp eq i64 %sf, 987`r`n"+(Check-Condition '%stride' 102)
    $body+="  store i64 -2, ptr @a`r`n  %upper = getelementptr i64, ptr @a, i64 1`r`n  store i64 2, ptr %upper`r`n"
    $body+='  %copy = call { i1, i64 } '+$proc[4]+"(ptr @ctx, ptr @b, ptr @a)`r`n"+(Check-Result '%copy' '-1')
    $body+="  %lower.b = load i64, ptr @b`r`n  %bounds = icmp eq i64 %lower.b, -2`r`n"+(Check-Condition '%bounds' 103)
    $body+="  %independent.ptr = getelementptr i64, ptr @b, i64 2`r`n  %independent.data = load ptr, ptr %independent.ptr`r`n  store i64 999, ptr %independent.data`r`n  %original.value = load i64, ptr %data`r`n  %independent = icmp eq i64 %original.value, %seed.value`r`n"+(Check-Condition '%independent' 107)
    $body+='  %create = call { i1, i64 } '+$proc[6]+"(ptr @ctx, ptr @path, ptr %token, ptr %failure)`r`n"+(Check-Result '%create' '-1')
    $body+="  %handle = load i64, ptr %token`r`n"
    $body+='  %write = call { i1, i64 } '+$proc[8]+"(ptr @ctx, i64 %handle, ptr @a, i64 0, i64 5, ptr %progress, ptr %failure)`r`n"+(Check-Result '%write' '-1')
    $body+='  %flush = call { i1, i64 } '+$proc[10]+"(ptr @ctx, i64 %handle, ptr %failure)`r`n"+(Check-Result '%flush' '-1')
    $body+='  %close = call { i1, i64 } '+$proc[9]+"(ptr @ctx, ptr %token, ptr %failure)`r`n"+(Check-Result '%close' '-1')
    $body+='  %open = call { i1, i64 } '+$proc[5]+"(ptr @ctx, ptr @path, i64 5, ptr %token, ptr %length, ptr %failure)`r`n"+(Check-Result '%open' '-1')
    $body+="  %reader = load i64, ptr %token`r`n"
    $body+='  %read = call { i1, i64 } '+$proc[7]+"(ptr @ctx, i64 %reader, ptr @b, i64 0, i64 5, ptr %progress, ptr %failure)`r`n"+(Check-Result '%read' '-1')
    $body+='  %read.close = call { i1, i64 } '+$proc[9]+"(ptr @ctx, ptr %token, ptr %failure)`r`n"+(Check-Result '%read.close' '-1')
    $body+="  %file.size = load i64, ptr %length`r`n  %file.progress = load i64, ptr %progress`r`n  %closed.token = load i64, ptr %token`r`n  %fresh.failure = load i64, ptr %failure`r`n  %size.ok = icmp eq i64 %file.size, 5`r`n  %progress.ok = icmp eq i64 %file.progress, 5`r`n  %closed.ok = icmp eq i64 %closed.token, 0`r`n  %failure.ok = icmp eq i64 %fresh.failure, 0`r`n  %file.one = and i1 %size.ok, %progress.ok`r`n  %file.two = and i1 %closed.ok, %failure.ok`r`n  %file.all = and i1 %file.one, %file.two`r`n"+(Check-Condition '%file.all' 108)
    $body+="  %bdptr = getelementptr i64, ptr @b, i64 2`r`n  %bd = load ptr, ptr %bdptr`r`n  %first.byte = load i64, ptr %bd`r`n  %content = icmp eq i64 %first.byte, 65`r`n"+(Check-Condition '%content' 104)
    foreach($array in @('a','b','r','s')) {$body+='  call void @ube.array.clear(ptr @'+$array+")`r`n"}
    $body+="  %collected = call i1 @ube.memory.collect(ptr @ctx)`r`n  %headptr = getelementptr %ube.context, ptr @ctx, i32 0, i32 4`r`n  %head = load ptr, ptr %headptr`r`n  %empty = icmp eq ptr %head, null`r`n"+(Check-Condition '%empty' 105)+"  ret i32 0`r`n}`r`n"
    $ir=Join-Path $artifacts ('execute-'+$level+'.ll');$exe=Join-Path $artifacts ('execute-'+$level+'.exe')
    $text=$prefix+$runtime+$fragment+$globals+$body
    Write-Text $ir $text;Build-Harness $ir $exe $level
    $run=Invoke-BoundedProcess $exe @()
    Require ($run.ExitCode -eq 0) "Wrapper $level assertion $($run.ExitCode): $($run.Evidence)"
    Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes($filePath)) -ceq [Convert]::ToBase64String([byte[]]@(65,66,67,68,68))) 'Independent file bytes differ'
    Write-Output "PASS: all eleven roles, record stride, authority and file bytes $level"
}
$controlPath=Join-Path $artifacts 'negative.ll';$controlExe=Join-Path $artifacts 'negative.exe'
# The prior roundtrip file is moved aside so exclusive creation remains a normal successful step.
Move-Item -LiteralPath $filePath -Destination ($filePath+'.baseline')
Write-Text $controlPath $text.Replace('@seed = private global i64 65','@seed = private global i64 90')
Build-Harness $controlPath $controlExe 'O2'
$control=Invoke-BoundedProcess $controlExe @()
Require ($control.ExitCode -eq 104) "Changed-input control returned $($control.ExitCode), expected104"
Write-Output 'PASS: changed runtime payload rejected at exact content assertion104'
