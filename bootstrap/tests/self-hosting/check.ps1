# Compares the documented CLI behavior of a supplied actual UBE compiler and its bootstrap seed.
param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [Parameter(Mandatory=$true)][string]$BootstrapExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe',
 [string]$CompilerSources='',
 [switch]$SeedOnly,
 [switch]$CompilerOnly,
 [switch]$ValuesOnly
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube compiler conformance '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
$script:number=0;$script:assertions=0
# Stops at the first independently specified assertion failure and retains all evidence.
function Require([bool]$Condition,[string]$Message){$script:assertions++;if(-not $Condition){throw $Message}}
# Writes strict UTF-8 deterministic fixture bytes.
function Write-Text([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,$utf8)}
# Quotes literal Windows arguments without invoking a command shell.
function Quote-Argument([string]$Value){if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value};$escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"');$escaped=[regex]::Replace($escaped,'(\\+)$','$1$1');return '"'+$escaped+'"'}
# Bounds each compiler/native child, preserving a real process handle and exact output bytes.
function Run([string]$File,[string[]]$Arguments,[string]$Directory=$artifacts,[int]$Timeout=120000){
 $script:number++;$prefix=Join-Path $artifacts ('process-'+$script:number)
 $start=@{FilePath=$File;WorkingDirectory=$Directory;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$start.ArgumentList=(($Arguments|ForEach-Object{Quote-Argument $_}) -join ' ')}
 $p=Start-Process @start
 try{$handle=$p.Handle;if(-not $p.WaitForExit($Timeout)){$p.Kill();$null=$p.WaitForExit(5000);throw "Process exceeded harness deadline: $prefix"};$p.Refresh();Require ($null -ne $p.ExitCode) "Missing retained process exit code: $handle";return [pscustomobject]@{ExitCode=$p.ExitCode;Stdout=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Stderr=[IO.File]::ReadAllText($prefix+'.stderr',$utf8);Evidence=$prefix}}
 finally{$p.Dispose()}
}
# Copies each fixture source into its own contained project; no compiler sees external source references.
function Project([string]$Name,[string[]]$Sources,[string]$Optimization){
 $directory=Join-Path $artifacts $Name;$null=New-Item -ItemType Directory -Path $directory
 $lines=@('UBE-Project 1',('Name = "'+$Name+'"'),'Kind = "Exe"','Startup = "Main"',('Optimization = "'+$Optimization+'"'));$modules=@();$copies=@()
 foreach($source in $Sources){$leaf=[IO.Path]::GetFileName($source);$destination=Join-Path $directory $leaf;Copy-Item -LiteralPath $source -Destination $destination;$text=[IO.File]::ReadAllText($destination,$utf8);Require ($text -match 'Attribute UBE_Name = "([^"]+)"') "Fixture has no module identity: $source";$modules+=$Matches[1];$copies+=$destination;$lines+='Source = "'+$leaf+'"'}
 $manifest=Join-Path $directory 'project.UBE';Write-Text $manifest (($lines -join "`r`n")+"`r`n")
 return [pscustomobject]@{Name=$Name;Directory=$directory;Manifest=$manifest;Modules=$modules;Sources=$copies}
}
# Checks each implementation's documented exact successful stdout, including the seed's inventory lines.
function Success($Result,$Compiler,$Project,[string]$Marker){
 Require ($Result.ExitCode -eq 0) "$($Compiler.Name) failed: $($Result.Evidence)"
 $expected='';if($Compiler.Seed){$expected='PROJECT '+$Project.Name+"`r`n";foreach($module in $Project.Modules){$expected+='MODULE '+$module+"`r`n"}}
 $expected+=$Marker+"`r`n"
 Require ($Result.Stdout -ceq $expected) "Unexpected exact success stdout: $($Result.Evidence)"
 Require ($Result.Stderr -ceq '') "Unexpected success stderr: $($Result.Evidence)"
}
# A controlled failure must preserve a previously published destination byte-for-byte.
function Failure($Result,[string]$Output,[string]$Hash){
 Require ($Result.ExitCode -eq 1) "Expected controlled failure exit1: $($Result.Evidence)"
 Require ($Result.Stdout -ceq '') "Failure published stdout success: $($Result.Evidence)"
 Require ($Result.Stderr.StartsWith('UBE: E_') -and $Result.Stderr.EndsWith("`r`n")) "Missing controlled diagnostic: $($Result.Evidence)"
 Require ((Get-FileHash -LiteralPath $Output -Algorithm SHA256).Hash -ceq $Hash) "Prior output changed on failure: $Output"
 Require (@(Get-ChildItem -LiteralPath ([IO.Path]::GetDirectoryName($Output)) -Force -Filter '.ube-*').Count -eq 0) "Controlled failure retained a private stage beside $Output"
}
# Compiles a no-CRT fake backend whose exit/output behavior is independent of compiler code.
function Tool([string]$Path,[string]$Body){$inputPath=$Path+'.ll';Write-Text $inputPath $Body;$link=@(Get-NativeMemoryLinkArguments $inputPath $Clang $artifacts);$r=Run $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib','-O0',$inputPath)+$link+@('-o',$Path,'-Wl,/entry:main,/subsystem:console'));Require ($r.ExitCode -eq 0) "Fake backend build failed: $($r.Evidence)"}
# Supplies the common reviewed test import helper's bounded process interface.
function Invoke-BoundedProcess([string]$File,[string[]]$Arguments){Run $File $Arguments}
. (Join-Path $PSScriptRoot '../NativeMemory.ps1')
$CompilerExe=[IO.Path]::GetFullPath($CompilerExe);$BootstrapExe=[IO.Path]::GetFullPath($BootstrapExe)
Require (Test-Path -LiteralPath $CompilerExe -PathType Leaf) 'Actual UBE compiler executable is missing'
Require (Test-Path -LiteralPath $BootstrapExe -PathType Leaf) 'Bootstrap executable is missing'
$compilers=@(@{Name='Seed';Path=$BootstrapExe;Seed=$true},@{Name='UBE';Path=$CompilerExe;Seed=$false})
Require (-not ($SeedOnly -and $CompilerOnly)) 'SeedOnly and CompilerOnly are mutually exclusive'
if($SeedOnly){$compilers=@($compilers[0]);Write-Output 'Seed-only fixture validation; this is not UBE compiler conformance.'}
if($CompilerOnly){$compilers=@($compilers[1]);Write-Output 'UBE-only conformance; reuse the separately recorded seed corpus result.'}
$fixture=Join-Path $PSScriptRoot 'fixtures';$buffer=Join-Path $root 'std-lib/src/portable/BufferPrimitives.bas';$file=Join-Path $root 'std-lib/src/portable/FilePrimitives.bas'
$corpus=@(
 @{Name='Return';Sources=@((Join-Path $fixture 'Return.bas'))},
 @{Name='Multi';Sources=@((Join-Path $fixture 'MultiMain.bas'),(Join-Path $fixture 'Support.bas'))},
 @{Name='SourceError';Sources=@((Join-Path $fixture 'Fault.bas'),(Join-Path $fixture 'ErrorMain.bas'))},
 @{Name='Arrays';Sources=@($buffer,(Join-Path $fixture 'Arrays.bas'))},
 @{Name='File';Sources=@($buffer,$file,(Join-Path $fixture 'File.bas'))},
 @{Name='Values';Sources=@($buffer,(Join-Path $fixture 'Values.bas'))},
 @{Name='IntegerOperations';Expected=0;Sources=@((Join-Path $root 'bootstrap/tests/integer-operations/Probe.bas'))},
 @{Name='UnicodeScalars';Expected=0;Sources=@($buffer,$file,(Join-Path $root 'std-lib/src/portable/FileBytes.bas'),(Join-Path $root 'std-lib/src/portable/Utf8.bas'),(Join-Path $root 'std-lib/tests/unicode-scalars/Probe.bas'))},
 @{Name='CallNew';Expected=0;Sources=@((Join-Path $root 'runtime/tests/callnew/Workers.bas'),(Join-Path $root 'runtime/tests/callnew/CaptureProbe.bas'),(Join-Path $root 'runtime/tests/callnew/Capacity.bas'),(Join-Path $root 'runtime/tests/callnew/Acceptance.bas'),(Join-Path $root 'std-lib/src/portable/ThreadPrimitives.bas'))}
)
if($ValuesOnly){$corpus=@($corpus|Where-Object{$_.Name -eq 'Values'});Write-Output 'Focused values corpus only; reuse separately recorded full CLI and negative results.'}
Write-Output "Conformance evidence: $artifacts"
foreach($compiler in $compilers){
 $usage=Run $compiler.Path @('--build');Require ($usage.ExitCode -eq 2 -and $usage.Stdout -ceq '' -and $usage.Stderr.StartsWith('UBE: E_USAGE:')) "$($compiler.Name) usage contract failed"
 foreach($level in @('0','2')){foreach($case in $corpus){
  $project=Project ($compiler.Name+$case.Name+'O'+$level) $case.Sources $level
  $ir=Join-Path $project.Directory 'output.ll';$native=Join-Path $project.Directory 'output.exe'
  $first=Run $compiler.Path @('--emit-llvm',$project.Manifest,$ir);Success $first $compiler $project 'EMIT OK'
  $hash=(Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
  $again=Run $compiler.Path @('--emit-llvm',$project.Manifest,$ir);Success $again $compiler $project 'EMIT OK'
  Require ((Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash -ceq $hash) "$($compiler.Name) nondeterministic repeated IR: $($case.Name) O$level"
  $build=Run $compiler.Path @('--build',$project.Manifest,$native,'--clang',$Clang);Success $build $compiler $project 'BUILD OK'
  $expected=42;if($case.ContainsKey('Expected')){$expected=$case.Expected}
  $run=Run $native @() $project.Directory;Require ($run.ExitCode -eq $expected -and $run.Stdout -ceq '' -and $run.Stderr -ceq '') "$($compiler.Name) corpus execution failed: $($case.Name) O$level; $($run.Evidence)"
  if($case.Name -eq 'File'){Require ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $project.Directory 'roundtrip.bin'))) -ceq 'ACqA/w==') 'Independent file-byte oracle mismatch'}
  if($case.Name -eq 'Return' -and $level -eq '0'){
   $source=$project.Sources[0];Write-Text $source ([IO.File]::ReadAllText($source,$utf8).Replace('Main = 42','Main = 43'))
   $changed=Run $compiler.Path @('--emit-llvm',$project.Manifest,$ir);Success $changed $compiler $project 'EMIT OK'
   Require ((Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash -cne $hash) 'Changed-source negative control did not change IR'
   $changed=Run $compiler.Path @('--build',$project.Manifest,$native,'--clang',$Clang);Success $changed $compiler $project 'BUILD OK'
   $changed=Run $native @() $project.Directory;Require ($changed.ExitCode -eq 43) 'Changed-source executable negative control did not return43'
  }
  if($case.Name -eq 'CallNew'){
   $source=$project.Sources[0];$original=[IO.File]::ReadAllText($source,$utf8)
   $changedSource=$original.Replace('Observed <> 41','Observed <> 42')
   Require ($changedSource -cne $original) 'Missing common source-worker ownership negative control'
   Write-Text $source $changedSource
   $changed=Run $compiler.Path @('--emit-llvm',$project.Manifest,$ir);Success $changed $compiler $project 'EMIT OK'
   Require ((Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash -cne $hash) 'Source-worker ownership mutation did not change IR'
   $changed=Run $compiler.Path @('--build',$project.Manifest,$native,'--clang',$Clang);Success $changed $compiler $project 'BUILD OK'
   $changed=Run $native @() $project.Directory
   Require ($changed.ExitCode -eq 1 -and $changed.Stdout -ceq '' -and $changed.Stderr -ceq '') 'Source-worker changed observation did not return its exact assertion failure'
   Write-Text $source $original
   $recovered=Run $compiler.Path @('--emit-llvm',$project.Manifest,$ir);Success $recovered $compiler $project 'EMIT OK'
   Require ((Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash -ceq $hash) 'Restored source-worker fixture did not recover its exact baseline IR'
   $recovered=Run $compiler.Path @('--build',$project.Manifest,$native,'--clang',$Clang);Success $recovered $compiler $project 'BUILD OK'
   $recovered=Run $native @() $project.Directory
   Require ($recovered.ExitCode -eq 0 -and $recovered.Stdout -ceq '' -and $recovered.Stderr -ceq '') 'Source-worker fixture failed recovery after the negative control'
  }
  Write-Output "PASS $($compiler.Name) $($case.Name) O$level deterministic IR and native result"
 }}
 if($ValuesOnly){continue}
 $badProject=Project ($compiler.Name+'Malformed') @((Join-Path $fixture 'Malformed.bas')) '0'
 foreach($mode in @('--emit-llvm','--build')){
  $output=Join-Path $badProject.Directory ('prior'+$mode.Substring(2)+'.bin');Write-Text $output 'prior output must survive';$hash=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
  $args=@($mode,$badProject.Manifest,$output);if($mode -eq '--build'){$args+=@('--clang',$Clang)}
  $malformed=Run $compiler.Path $args
  Failure $malformed $output $hash
  Require ($malformed.Stderr.Contains('Malformed.bas:5:17')) "Malformed source diagnostic lost its exact source location: $($malformed.Evidence)"
 }
 foreach($missing in @('manifest','source')){
  $project=Project ($compiler.Name+'Missing'+$missing) @((Join-Path $fixture 'Return.bas')) '0'
  $output=Join-Path $project.Directory 'prior.ll';Write-Text $output 'prior output must survive missing inputs';$hash=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
  if($missing -eq 'manifest'){$requested=Join-Path $project.Directory 'absent.UBE'}else{$requested=$project.Manifest;Remove-Item -LiteralPath $project.Sources[0]}
  Failure (Run $compiler.Path @('--emit-llvm',$requested,$output)) $output $hash
 }
 if(-not $compiler.Seed){
  $isolated=Join-Path $artifacts 'isolated compiler without assets';$null=New-Item -ItemType Directory -Path $isolated
  $copy=Join-Path $isolated 'UBE.exe';Copy-Item -LiteralPath $compiler.Path -Destination $copy
  $project=Project 'MissingCompilerAssets' @((Join-Path $fixture 'Return.bas')) '0'
  $output=Join-Path $project.Directory 'prior.ll';Write-Text $output 'prior output must survive missing assets';$hash=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
  $missingAssets=Run $copy @('--emit-llvm',$project.Manifest,$output)
  Failure $missingAssets $output $hash
  Require ($missingAssets.Stderr.StartsWith('UBE: E_ASSET:')) 'Actual compiler missing assets did not report E_ASSET'
 }
 $guard=Project ($compiler.Name+'Guards') @((Join-Path $fixture 'Return.bas')) '0'
 $source=$guard.Sources[0];$sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
 Failure (Run $compiler.Path @('--emit-llvm',$guard.Manifest,$source)) $source $sourceHash
 $alias=Join-Path $guard.Directory 'source-hardlink.ll';$null=New-Item -ItemType HardLink -Path $alias -Target $source
 Failure (Run $compiler.Path @('--emit-llvm',$guard.Manifest,$alias)) $alias $sourceHash
 Require ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ceq $sourceHash) 'Source changed through its hardlink'
 $manifestHash=(Get-FileHash -LiteralPath $guard.Manifest -Algorithm SHA256).Hash
 Failure (Run $compiler.Path @('--emit-llvm',$guard.Manifest,$guard.Manifest)) $guard.Manifest $manifestHash
 Write-Output "PASS $($compiler.Name) malformed source and input/output identity guards"
}

# Writes the independently specified accepted archive header so fake Clang behavior is actually reached.
$importIR=@'
declare dllimport ptr @CreateFileW(ptr,i32,i32,ptr,i32,i32,ptr)
declare dllimport i32 @WriteFile(ptr,ptr,i32,ptr,ptr)
declare dllimport i32 @CloseHandle(ptr)
@name = private constant [20 x i16] [i16 107,i16 101,i16 114,i16 110,i16 101,i16 108,i16 51,i16 50,i16 45,i16 109,i16 101,i16 109,i16 111,i16 114,i16 121,i16 46,i16 108,i16 105,i16 98,i16 0]
@header = private constant [8 x i8] c"!<arch>\0A"
define i32 @main() {
entry:
 %count = alloca i32
 %file = call ptr @CreateFileW(ptr @name,i32 1073741824,i32 0,ptr null,i32 1,i32 128,ptr null)
 %wrote = call i32 @WriteFile(ptr %file,ptr @header,i32 8,ptr %count,ptr null)
 %closed = call i32 @CloseHandle(ptr %file)
 ret i32 0
}
'@
$backendKinds=@('missing','nonzero','nooutput','timeout');if($ValuesOnly){$backendKinds=@()}
foreach($kind in $backendKinds){
 $tools=Join-Path $artifacts ('backend '+$kind);$null=New-Item -ItemType Directory -Path $tools
 Tool (Join-Path $tools 'llvm-dlltool.exe') $importIR
 $fake=Join-Path $tools 'clang.exe'
 if($kind -eq 'nonzero'){Tool $fake 'define i32 @main() { ret i32 29 }'}
 if($kind -eq 'nooutput'){Tool $fake 'define i32 @main() { ret i32 0 }'}
 if($kind -eq 'timeout'){Tool $fake 'define i32 @main() { entry: br label %loop
loop: br label %loop }'}
 foreach($compiler in $compilers){
  $project=Project ($compiler.Name+'Backend'+$kind) @((Join-Path $fixture 'Return.bas')) '0'
  $output=Join-Path $project.Directory 'prior.exe';Write-Text $output 'prior executable must survive';$hash=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
  $timer=[Diagnostics.Stopwatch]::StartNew();$failed=Run $compiler.Path @('--build',$project.Manifest,$output,'--clang',$fake);$timer.Stop()
  Failure $failed $output $hash
  if($kind -eq 'timeout'){Require ($timer.ElapsedMilliseconds -ge 29000) "Timeout fixture did not reach timed backend execution: $($failed.Evidence)"}
  if($compiler.Seed){
   if($kind -eq 'nonzero'){Require ($failed.Stderr.Contains('failed with exit 29')) 'Seed nonzero backend path was not exercised'}
   if($kind -eq 'nooutput'){Require ($failed.Stderr.Contains('not a bounded AMD64 PE32+ executable')) 'Seed nooutput validation path was not exercised'}
   if($kind -eq 'timeout'){Require ($failed.Stderr.Contains('exceeded 30 second timeout')) 'Seed timeout path was not exercised'}
  }else{
   if($kind -eq 'nonzero'){Require ($failed.Stderr.Contains('0/102/29')) 'UBE nonzero backend path was not exercised'}
   if($kind -eq 'nooutput'){Require ($failed.Stderr.Contains('0/3/0')) 'UBE nooutput validation path was not exercised'}
   if($kind -eq 'timeout'){Require ($failed.Stderr.Contains('0/100/0')) 'UBE timeout path was not exercised'}
  }
  Write-Output "PASS $($compiler.Name) $kind backend preserves prior output"
  $recovery=Run $compiler.Path @('--build',$project.Manifest,$output,'--clang',$Clang)
  Success $recovery $compiler $project 'BUILD OK'
  $native=Run $output @() $project.Directory
  Require ($native.ExitCode -eq 42 -and $native.Stdout -ceq '' -and $native.Stderr -ceq '') "Real backend recovery did not produce exit42 after $kind failure"
  Require (@(Get-ChildItem -LiteralPath $project.Directory -Force -Filter '.ube-*').Count -eq 0) "Successful backend recovery retained private stage after $kind"
 }
}

# An explicitly supplied compiler-source manifest enables rebuild qualification; no source package is inferred.
if($CompilerSources -and -not $SeedOnly){
 $manifest=[IO.Path]::GetFullPath($CompilerSources);Require (Test-Path -LiteralPath $manifest -PathType Leaf) 'CompilerSources manifest is missing'
 $first=Join-Path $artifacts 'rebuilt-compiler.exe'
 $run=Run $CompilerExe @('--build',$manifest,$first,'--clang',$Clang) $artifacts 600000
 Require ($run.ExitCode -eq 0 -and $run.Stdout -ceq "BUILD OK`r`n" -and $run.Stderr -ceq '') "Requested compiler rebuild failed: $($run.Evidence)"
 Require (Test-Path -LiteralPath $first -PathType Leaf) 'Requested compiler rebuild produced no executable'
 Write-Output "PASS explicitly supplied compiler source rebuild: $first"
}
Write-Output "PASS $script:assertions CLI conformance assertions; evidence: $artifacts"
