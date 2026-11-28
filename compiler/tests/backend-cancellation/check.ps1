# Real worker stop requests before launch and after an independently observed child start.
param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe',
 [ValidateSet('0','2')][string]$Optimization='2',
 [switch]$WithoutCancellation,
 [ValidateSet('1','2')][string[]]$Modes=@('1','2')
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube backend cancellation '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$script:serial=0
Write-Output "Evidence: $evidence"
function Require([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Write-Text([string]$Path,[string]$Value){[IO.File]::WriteAllText($Path,$Value,$utf8)}
function Quote([string]$Value){'"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}
function Run([string]$File,[string[]]$Arguments,[int]$Deadline=180000){
 $script:serial++;$prefix=Join-Path $evidence ('process-'+$script:serial)
 $options=@{FilePath=$File;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{Quote $_}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit($Deadline)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Exit=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8)}}finally{$p.Dispose()}
}
$package=& (Join-Path $root 'bootstrap/tools/self-host-sources.ps1') -Destination (Join-Path $evidence 'package') -Kind Exe -Optimization $Optimization -AdditionalSources (Join-Path $PSScriptRoot 'Probe.bas')
$lines=[IO.File]::ReadAllLines($package.Manifest,$utf8) | Where-Object {$_ -cne 'Source = "CompilerCommand.bas"'}
Write-Text $package.Manifest (($lines -join "`r`n")+"`r`n")
if($WithoutCancellation){
 $path=Join-Path $package.Destination 'NativeBackend.bas'
 $source=[IO.File]::ReadAllText($path,$utf8)
 $source=[regex]::Replace($source,'(?m)^    +If ThreadPrimitives\.StopRequested\(\) Then Failure = Cancelled: (Exit Function|GoTo Cleanup)\r?\n','')
 Require (-not $source.Contains('ThreadPrimitives.StopRequested()')) 'Negative control retained cancellation'
 Write-Text $path $source
}
$probe=Join-Path $package.Destination 'probe.exe'
$built=Run $CompilerExe @('--build',$package.Manifest,$probe,'--clang',$Clang)
Require ($built.Exit -eq 0) ('Probe build failed: '+$built.Error)
$definition=Join-Path $evidence 'kernel32.def'
$library=Join-Path $evidence 'kernel32.lib'
Write-Text $definition "LIBRARY KERNEL32.dll`r`nEXPORTS`r`nCreateFileW`r`nCloseHandle`r`nSleep`r`nExitProcess`r`n"
$r=Run (Join-Path (Split-Path $Clang) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',$definition,'-l',$library)
Require ($r.Exit -eq 0) 'Import library failed'
$marker=Join-Path $evidence 'started'
$bytes=[Text.Encoding]::Unicode.GetBytes($marker+[char]0)
$escaped=($bytes|ForEach-Object{'\'+$_.ToString('X2')}) -join ''
$child=Join-Path $evidence 'child.exe'
$ir=@"
declare ptr @CreateFileW(ptr, i32, i32, ptr, i32, i32, ptr)
declare i32 @CloseHandle(ptr)
declare void @Sleep(i32)
declare void @ExitProcess(i32) noreturn
@marker = private constant [$($bytes.Length) x i8] c"$escaped"
define i32 @main() {
entry:
  %h = call ptr @CreateFileW(ptr @marker, i32 1073741824, i32 7, ptr null, i32 2, i32 128, ptr null)
  %ok = call i32 @CloseHandle(ptr %h)
  call void @Sleep(i32 20000)
  call void @ExitProcess(i32 0)
  unreachable
}
"@
Write-Text ($child+'.ll') $ir
$r=Run $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib','-O0',($child+'.ll'),$library,'-Wl,/entry:main,/subsystem:console','-o',$child)
Require ($r.Exit -eq 0) ('Child build failed: '+$r.Error)
$recovery=Join-Path $evidence 'recovery.exe'
Write-Text ($recovery+'.ll') "declare void @ExitProcess(i32) noreturn`r`ndefine i32 @main() { call void @ExitProcess(i32 0) unreachable }`r`n"
$r=Run $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib','-O0',($recovery+'.ll'),$library,'-Wl,/entry:main,/subsystem:console','-o',$recovery)
Require ($r.Exit -eq 0) 'Recovery child build failed'
foreach($mode in $Modes){
 $log=Join-Path $evidence ('log-'+$mode)
 $r=Run $probe @($child,$recovery,$evidence,$log,(Join-Path $evidence ('recovery-'+$mode)),$marker,$mode) 35000
 Require ($r.Exit -eq 0 -and $r.Out -ceq '' -and $r.Error -ceq '') ('Cancellation mode '+$mode+' failed: exit '+$r.Exit+' '+$r.Error)
 if($mode -eq '1'){Require (-not (Test-Path -LiteralPath $marker) -and -not (Test-Path -LiteralPath $log)) 'Pre-stopped request launched a child or opened a log'}
 else{Require (Test-Path -LiteralPath $marker) 'Child was never observed running'}
 Require (@(Get-Process -Name child -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $child}).Count -eq 0) 'Cancelled child remains alive'
 Write-Output "PASS mode $mode : cancellation code104, released owners, isolated caller, successful subsequent tool"
}
Write-Output "PASS backend cancellation O$Optimization; negative control=$WithoutCancellation; evidence: $evidence"
