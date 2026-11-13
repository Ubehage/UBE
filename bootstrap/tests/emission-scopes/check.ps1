# Qualifies per-scope host emission indexes against the previous emitter and independent native results.
param(
    [string]$BootstrapExe = '',
    [Parameter(Mandatory=$true)][string]$ReferenceExe,
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube emission scopes ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $artifacts -Force
$script:processNumber = 0


# Stops on a failed independently authored acceptance assertion.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Writes deterministic UTF-8 source and IR, never the host's default text encoding.
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

# Quotes literal Windows command-line arguments including quotes and trailing backslashes.
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

# Retains a hidden child handle, bounds execution and saves each fresh process observation.
function Invoke-BoundedProcess([string]$File, [string[]]$Arguments) {
    $script:processNumber++
    $prefix = Join-Path $artifacts ('process-' + $script:processNumber)
    $start = @{ FilePath=$File; WorkingDirectory=$artifacts; WindowStyle='Hidden'; PassThru=$true; RedirectStandardOutput=($prefix + '.stdout'); RedirectStandardError=($prefix + '.stderr') }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @start
    try {
        $handle = $process.Handle
        if (-not $process.WaitForExit(60000)) { $process.Kill(); $null = $process.WaitForExit(5000); throw "Process timeout. Evidence: $prefix" }
        $process.Refresh()
        Require ($null -ne $process.ExitCode) "Missing exit code for retained handle $handle"
        return [pscustomobject]@{ ExitCode=$process.ExitCode; Stdout=[IO.File]::ReadAllText($prefix + '.stdout',$utf8); Stderr=[IO.File]::ReadAllText($prefix + '.stderr',$utf8); Evidence=$prefix }
    } finally { $process.Dispose() }
}

. (Join-Path $PSScriptRoot '../NativeMemory.ps1')

# Compiles the same emitted library plus observation harness and checks AMD64 PE framing.
function Build-Harness([string]$IR, [string]$Exe, [string]$Level) {
    $link = @(Get-NativeMemoryLinkArguments $IR $Clang $artifacts)
    $result = Invoke-BoundedProcess $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR) + $link + @('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608'))
    Require ($result.ExitCode -eq 0) "Harness compilation failed. Evidence: $($result.Evidence)"
    $bytes = [IO.File]::ReadAllBytes($Exe)
    Require ($bytes.Length -ge 64 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) 'Invalid native DOS header'
    $offset = [BitConverter]::ToInt32($bytes,0x3c)
    Require ($offset -ge 64 -and $offset -le $bytes.Length - 6) 'Invalid native PE offset'
    Require ([BitConverter]::ToUInt32($bytes,$offset) -eq 0x4550 -and [BitConverter]::ToUInt16($bytes,$offset+4) -eq 0x8664) 'Expected AMD64 PE executable'
}



$nl=[Environment]::NewLine
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
Write-Output "Artifacts retained: $artifacts"
if(-not $BootstrapExe){
 $build=Join-Path $artifacts 'build'
 $null=New-Item -ItemType Directory -Path $build
 $log=Join-Path $build 'vb6-build.log'
 $result=Invoke-BoundedProcess $VB6 @('/make',(Join-Path $root 'bootstrap/UBE-Bootstrap.vbp'),'/out',$log,'/outdir',$build)
 if(Test-Path -LiteralPath $log){Get-Content -LiteralPath $log}
 $BootstrapExe=Join-Path $build 'UBE-Bootstrap.exe'
 Require ($result.ExitCode -eq 0 -and (Test-Path -LiteralPath $BootstrapExe)) "VB6 build failed $($result.Evidence)"
}
Write-Output "Fresh host: $BootstrapExe"
# Publishes isolated fixture files with one shared manifest path for old/new comparisons.
function Fixture([string]$Name,[hashtable]$Sources){
 $directory=Join-Path $artifacts $Name
 $null=New-Item -ItemType Directory -Path $directory
 $lines=@('UBE-Project 1','Name = "ScopeChecks"','Kind = "Library"')
 foreach($name in ($Sources.Keys|Sort-Object)){
  Write-Text (Join-Path $directory $name) $Sources[$name]
  $lines+='Source = "'+$name+'"'
 }
 $manifest=Join-Path $directory 'project.UBE'
 Write-Text $manifest (($lines -join $nl)+$nl)
 return $manifest
}
# Requires byte-identical output for the same exact paths, preserving source-location comments.
function Compare-Corpus([string]$Manifest){
 $directory=[IO.Path]::GetDirectoryName($Manifest)
 $old=Join-Path $directory 'old.ll'
 $new=Join-Path $directory 'new.ll'
 $before=Invoke-BoundedProcess $ReferenceExe @('--emit-llvm',$Manifest,$old)
 $after=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$Manifest,$new)
 Require ($before.ExitCode -eq 0 -and $after.ExitCode -eq 0) "Corpus emission failed $($before.Evidence) $($after.Evidence)"
 Require ((Get-FileHash -LiteralPath $old -Algorithm SHA256).Hash -ceq (Get-FileHash -LiteralPath $new -Algorithm SHA256).Hash) "IR order/cleanup changed: $Manifest"
 Write-Output "PASS exact old/new IR bytes: $Manifest"
}
$core=Join-Path $root 'std-lib/src/portable/BufferPrimitives.bas'
foreach($name in @('dynamic-storage','aggregate-storage')){
 $leaf='DynamicProbe.bas'
 if($name -eq 'aggregate-storage'){$leaf='StorageProbe.bas'}
 $sources=@{}
 $sources[$leaf]=[IO.File]::ReadAllText((Join-Path $root "bootstrap/tests/$name/fixtures/$leaf"),$utf8)
 $sources['BufferPrimitives.bas']=[IO.File]::ReadAllText($core,$utf8)
 Compare-Corpus (Fixture $name $sources)
}
$complex=@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "ScopeCorpus"
' Exercises scope-local arrays, grouped ByRef slots and multiple failure continuations.
Private Intrinsic Function Resize(ByRef Values() As Long, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
Attribute Resize.UBE_Primitive = "Array.TryResize"
End Function
Private Sub Touch(ByRef Value As Long)
    Value = Value + 2
End Sub
Private Function Failing(ByVal Value As Long) As Long
    If Value < 0 Then Err.Raise 5
    Failing = Value
End Function
Public Function Run(ByVal Seed As Long) As Long
    Dim Values() As Long
    Dim Fixed(0 To 1) As Long
    Dim Status As Boolean
    On Error GoTo Failed
    Status = Resize(Values, 2, False)
    Values(0) = Seed
    Call Touch((Values(0)))
    Fixed(0) = Failing(Seed)
    Run = Values(0) + Fixed(0)
    Exit Function
Failed:
    Call Touch((Seed))
    Run = -1
End Function
' A second local owner detects accidentally shared cleanup indexes.
Public Function Other(ByVal Seed As Long) As Long
    Dim Bytes() As Long
    Dim Status As Boolean
    On Error Resume Next
    Status = Resize(Bytes, 1, False)
    Bytes(0) = Seed
    Call Touch((Bytes(0)))
    Other = Bytes(0)
End Function
'@
Compare-Corpus (Fixture 'handlers-temporaries' @{'ScopeCorpus.bas'=$complex})
# A compact project exceeds the old repeated-scan budget while staying below all declared source limits.
$functionCount=400
$source=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "ManyScopes"',"' Each function has an independently expected result and a separate declaration region.")
for($i=0;$i -lt $functionCount;$i++){
 $source+="Public Function F$i(ByVal Seed As Long) As Long"
 foreach($local in 0..11){$source+="    Dim Local$local As Long"}
 $source+="    F$i = Seed + $i"
 $source+='End Function'
}
$manifest=Fixture 'many-scopes' @{'ManyScopes.bas'=(($source -join $nl)+$nl)}
$output=Join-Path ([IO.Path]::GetDirectoryName($manifest)) 'output.ll'
$sentinel=[Text.Encoding]::ASCII.GetBytes('unchanged output sentinel')
[IO.File]::WriteAllBytes($output,$sentinel)
$old=Invoke-BoundedProcess $ReferenceExe @('--emit-llvm',$manifest,$output)
Require ($old.ExitCode -eq 1 -and $old.Stderr -match 'E_LIMIT.*emission work limit exceeded') "Old emitter must reproduce scan-limit failure: $($old.Evidence)"
Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes($output)) -ceq [Convert]::ToBase64String($sentinel)) 'Failed old emission changed existing output'
Write-Output 'PASS old repeated-scan limit reproduced; sentinel output preserved'
$new=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$manifest,$output)
Require ($new.ExitCode -eq 0) "Indexed emitter failed: $($new.Evidence)"
$repeat=Join-Path ([IO.Path]::GetDirectoryName($manifest)) 'repeat.ll'
$again=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$manifest,$repeat)
Require ($again.ExitCode -eq 0) "Repeated emission failed $($again.Evidence)"
Require ((Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash -ceq (Get-FileHash -LiteralPath $repeat -Algorithm SHA256).Hash) 'Indexed emission is nondeterministic'
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Symbol binding failed $($bound.Evidence)"
$symbols=@{}
foreach($line in ($bound.Stdout -split '\r?\n')){
 if($line -match '^SYMBOL (\d+)\|function\|F(\d+)\|'){$symbols[[int]$Matches[2]]=$Matches[1]}
}
Require ($symbols.Count -eq $functionCount) 'Missing independently mapped source procedures'
$entries=@()
foreach($i in 0..($functionCount-1)){$entries+='ptr @ube.proc.'+$symbols[$i]}
$harness=@'
@test.context = private global %ube.context zeroinitializer,align 8
@test.input = global i64 1
@test.procedures = private constant [COUNT x ptr] [FUNCTIONS]
define i32 @main(){
entry:
  call void @ube.context.init(ptr @test.context)
  %init = call i1 @ube.project.init(ptr @test.context)
  %input = load volatile i64,ptr @test.input
  br i1 %init,label %next,label %unavailable
next:
  %index = phi i64 [0,%entry],[%following,%accepted]
  %slot = getelementptr [COUNT x ptr],ptr @test.procedures,i64 0,i64 %index
  %procedure = load ptr,ptr %slot
  %pair = call {i1,i64} %procedure(ptr @test.context,i64 %input)
  %fresh = extractvalue {i1,i64} %pair,0
  %value = extractvalue {i1,i64} %pair,1
  %expected = add i64 %index,1
  %matches = icmp eq i64 %value,%expected
  %good = and i1 %fresh,%matches
  br i1 %good,label %accepted,label %failed
accepted:
  %following = add i64 %index,1
  %more = icmp ult i64 %following,COUNT
  br i1 %more,label %next,label %done
done:
  %disposed = call i1 @ube.context.dispose(ptr @test.context)
  %status = select i1 %disposed,i32 0,i32 253
  ret i32 %status
failed:
  %cleanup = call i1 @ube.context.dispose(ptr @test.context)
  %ordinal = add i64 %index,1
  %code = trunc i64 %ordinal to i32
  ret i32 %code
unavailable:
  ret i32 254
}
'@
$combined=[IO.File]::ReadAllText($output,$utf8)+$nl+$harness.Replace('COUNT',[string]$functionCount).Replace('FUNCTIONS',($entries -join ', '))
$path=Join-Path $artifacts 'scopes.ll'
Write-Text $path $combined
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts "$level.exe"
 Build-Harness $path $exe $level
 $run=Invoke-BoundedProcess $exe @()
 Require ($run.ExitCode -eq 0) "Independent function results failed $level $($run.Evidence)"
 Write-Output "PASS all$functionCount independently mapped function results at$level"
}
$path=Join-Path $artifacts 'negative.ll'
Write-Text $path ($combined.Replace('@test.input = global i64 1','@test.input = global i64 2'))
$exe=Join-Path $artifacts 'negative.exe'
Build-Harness $path $exe 'O2'
$run=Invoke-BoundedProcess $exe @()
Require ($run.ExitCode -eq 1) 'Changed runtime input must fail precisely first function result'
Write-Output "PASS emission-scope regression and negative control. Fresh host: $BootstrapExe"
