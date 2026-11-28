# Exercises the public compiler command against independent native tools with controlled diagnostic bytes.
param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube backend diagnostics '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$script:assertions=0
$script:serial=0
function Require([bool]$Value,[string]$Message){$script:assertions++;if(-not $Value){throw $Message}}
function Write-Text([string]$Path,[string]$Value){[IO.File]::WriteAllText($Path,$Value,$utf8)}
function Quote([string]$Value){'"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}
function Run([string]$File,[string[]]$Arguments,[int]$Deadline=30000){
 $script:serial++;$prefix=Join-Path $evidence ('process-'+$script:serial)
 $p=Start-Process -FilePath $File -ArgumentList (($Arguments|ForEach-Object{Quote $_}) -join ' ') -WorkingDirectory $evidence -WindowStyle Hidden -PassThru -RedirectStandardOutput ($prefix+'.stdout') -RedirectStandardError ($prefix+'.stderr')
 try{$null=$p.Handle;if(-not $p.WaitForExit($Deadline)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Exit=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8)}}finally{$p.Dispose()}
}
$importTool=Join-Path ([IO.Path]::GetDirectoryName($Clang)) 'llvm-dlltool.exe'
$definition=Join-Path $evidence 'kernel32.def'
$library=Join-Path $evidence 'kernel32.lib'
Write-Text $definition "LIBRARY KERNEL32.dll`r`nEXPORTS`r`nGetStdHandle`r`nWriteFile`r`nExitProcess`r`n"
$result=Run $importTool @('-m','i386:x86-64','-d',$definition,'-l',$library)
Require ($result.Exit -eq 0) 'Independent tool import library failed'
function Make-Tool([string]$Path,[byte[]]$Bytes){
 $escaped=($Bytes|ForEach-Object{'\'+$_.ToString('X2')}) -join ''
 $length=$Bytes.Length
 $ir=@"
declare ptr @GetStdHandle(i32)
declare i32 @WriteFile(ptr, ptr, i32, ptr, ptr)
declare void @ExitProcess(i32) noreturn
@payload = private constant [$length x i8] c"$escaped"
define i32 @main() {
entry:
  %written = alloca i32, align 4
  %stream = call ptr @GetStdHandle(i32 -12)
  %ok = call i32 @WriteFile(ptr %stream, ptr @payload, i32 $length, ptr %written, ptr null)
  call void @ExitProcess(i32 7)
  unreachable
}
"@
 Write-Text ($Path+'.ll') $ir
 $result=Run $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib','-O0',($Path+'.ll'),$library,'-Wl,/entry:main,/subsystem:console','-o',$Path)
 Require ($result.Exit -eq 0) ('Independent tool build failed: '+$result.Error)
}
$cases=@(
 @{Name='utf8';Bytes=$utf8.GetBytes("marker: caf$([char]0xE9)`r`n");Expected="Clang: marker: caf$([char]0xE9)`r`n";Code=102},
 @{Name='invalid';Bytes=[byte[]](98,97,100,0,27,255,13,10);Expected="Clang: bad???`r`n";Code=102},
 @{Name='truncated';Bytes=$utf8.GetBytes(('z'*9000));Expected=('Clang: '+('z'*8192)+"`r`n[diagnostic truncated]");Code=102},
 @{Name='flood';Bytes=$utf8.GetBytes(('f'*70000));Expected=('Clang: '+('f'*8192)+"`r`n[diagnostic truncated]");Code=101},
 @{Name='empty';Bytes=[byte[]]@();Expected='Clang: [diagnostic unavailable]';Code=102},
 @{Name='import';Bytes=$utf8.GetBytes('import-marker');Expected='llvm-dlltool: import-marker';Code=102}
)
foreach($case in $cases){
 $directory=Join-Path $evidence $case.Name;$null=New-Item -ItemType Directory -Path $directory
 $tool=Join-Path $directory 'clang.exe'
 if($case.Name -eq 'import'){
  Copy-Item -LiteralPath $Clang -Destination $tool
  Make-Tool (Join-Path $directory 'llvm-dlltool.exe') $case.Bytes
 }else{
  Copy-Item -LiteralPath $importTool -Destination (Join-Path $directory 'llvm-dlltool.exe')
  Make-Tool $tool $case.Bytes
 }
 Write-Text (Join-Path $directory 'Probe.bas') "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`nPublic Function Main() As Long`r`nMain = 42`r`nEnd Function`r`n"
 $manifest=Join-Path $directory 'Probe.UBE'
 Write-Text $manifest "UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"0`"`r`nSource = `"Probe.bas`"`r`n"
 $output=Join-Path $directory 'output.exe';Write-Text $output 'retained output sentinel'
 $before=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
 $result=Run $CompilerExe @('--build',$manifest,$output,'--clang',$tool)
 Require ($result.Exit -eq 1 -and $result.Out -ceq '') ($case.Name+': failure status')
 Require ($result.Error.Contains(('operation/code/reason 0/'+$case.Code+'/'))) ($case.Name+': original failure code')
 Require ($result.Error.Contains($case.Expected)) ($case.Name+': diagnostic payload missing or corrupted: '+$result.Error)
 Require ($result.Error.Length -lt 9000) ($case.Name+': diagnostic output was not bounded')
 Require ((Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash -ceq $before) ($case.Name+': prior output changed')
 Require (@(Get-ChildItem -LiteralPath $directory -Force -Directory -Filter '.ube-*').Count -eq 0) ($case.Name+': stage cleanup')
}
Write-Output "PASS $script:assertions assertions: tool identity, UTF8, invalid bytes, truncation/flood, empty log, primary failure, output preservation and cleanup; evidence: $evidence"
