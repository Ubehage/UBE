param(
 [Parameter(Mandatory=$true)][string]$SeedExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe',
 [string]$CompilerExe='',
 [string[]]$Fixtures=@('ScalarBinding','StringBinding','ConstantBinding','RoundedDivision','WorkerBinding','OperatorPrecedence','FiniteFailures','PowerBinding','AggregateBinding','NumericSuffix')
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube floating frontend '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$encoding=New-Object Text.UTF8Encoding($false,$true)
$script:sequence=0
Write-Output "Evidence: $evidence"
function Quote-Argument([string]$Value) {
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++
 $prefix=Join-Path $evidence ('process-'+$script:sequence)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object {Quote-Argument $_}) -join ' ')}
 $process=Start-Process @options
 try {
  $handle=$process.Handle
  if(-not $process.WaitForExit(180000)){$process.Kill();$null=$process.WaitForExit(5000);throw "Deadline: $prefix"}
  $process.Refresh()
  $output=[IO.File]::ReadAllText($prefix+'.stdout')
  $errors=[IO.File]::ReadAllText($prefix+'.stderr')
  if($null -eq $process.ExitCode -or $process.ExitCode -ne $Expected -or ($Expected -eq 0 -and $errors.Length)){throw "Exit $($process.ExitCode), expected $Expected; $output $errors; evidence $prefix"}
  return $output+$errors
 }finally{$process.Dispose()}
}
if(-not $CompilerExe){
 & (Join-Path $repo 'bootstrap/tools/runtime-text.ps1')
 & (Join-Path $repo 'bootstrap/tools/llvm-templates.ps1')
 & (Join-Path $repo 'bootstrap/tools/native-imports.ps1')
 & (Join-Path $repo 'runtime/managed-source-identities.ps1')
 $package=& (Join-Path $repo 'bootstrap/tools/self-host-sources.ps1') -Destination (Join-Path $evidence 'compiler') -Kind Exe -Optimization 2
 $assets=Join-Path $package.Destination 'llvm'
 $null=New-Item -ItemType Directory -Path $assets
 foreach($name in @('templates.bin','windows-runtime.ll','kernel32.def')){Copy-Item -LiteralPath (Join-Path $repo "compiler/llvm/$name") -Destination $assets}
 $null=& (Join-Path $repo 'runtime/package-managed-support.ps1') -Destination (Join-Path $package.Destination 'support')
 $ir=Join-Path $package.Destination 'seed.ll'
 $CompilerExe=Join-Path $package.Destination 'UBE.exe'
 $output=Run $SeedExe @('--emit-llvm',$package.Manifest,$ir)
 if($output -notmatch '(?m)^EMIT OK\r?$'){throw 'Seed emission marker missing'}
 $library=Join-Path $package.Destination 'kernel32.lib'
 $null=Run (Join-Path (Split-Path $Clang) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path $assets 'kernel32.def'),'-l',$library)
 $null=Run $Clang @('--target=x86_64-pc-windows-msvc','-Wno-override-module','-fuse-ld=lld','-nostdlib','-O2',$ir,$library,'-o',$CompilerExe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
 Write-Output "Compiler built: $CompilerExe"
}
foreach($name in $Fixtures){
 foreach($level in @('0','2')){
  $folder=Join-Path $evidence ($name+$level)
  $null=New-Item -ItemType Directory -Path $folder
  $source=Join-Path $folder ($name+'.bas')
  $manifest=Join-Path $folder 'Probe.UBE'
  $exe=Join-Path $folder 'Probe.exe'
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot ($name+'.bas')) -Destination $source
  [IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nDebugInformation = `"None`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`nSource = `"$name.bas`"`r`n",$encoding)
  $output=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang)
  if($output -notmatch '(?m)^BUILD OK\r?$'){throw "Build marker missing: $name O$level"}
  $null=Run $exe @()
  Write-Output "PASS $name O$level"
  if($name -eq 'WorkerBinding'){
   $original=[IO.File]::ReadAllText($source,$encoding)
   $changed=$original.Replace('If Output <> 1.75#','If Output <> 1.5#')
   if($changed -ceq $original){throw 'Worker changed-output control marker missing'}
   $controlSource=Join-Path $folder 'WorkerControl.bas'
   $controlManifest=Join-Path $folder 'Control.UBE'
   $controlExe=Join-Path $folder 'Control.exe'
   [IO.File]::WriteAllText($controlSource,$changed,$encoding)
   [IO.File]::WriteAllText($controlManifest,[IO.File]::ReadAllText($manifest,$encoding).Replace('WorkerBinding.bas','WorkerControl.bas'),$encoding)
   $output=Run $CompilerExe @('--build',$controlManifest,$controlExe,'--clang',$Clang)
   if($output -notmatch '(?m)^BUILD OK\r?$'){throw "Worker control build marker missing O$level"}
   $null=Run $controlExe @() 6
   Write-Output "PASS worker changed-output control O$level"
  }
 }
}
foreach($name in @('SuffixConflict','FloatingLogical','RoundedZero','ConstantZeroDivision','ConstantFloatOverflow','ConstantNonfiniteText','KnownZeroDivisor','ConstantPowerDomain')){
 $folder=Join-Path $evidence $name
 $null=New-Item -ItemType Directory -Path $folder
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot ($name+'.bas')) -Destination $folder
 $manifest=Join-Path $folder 'Probe.UBE'
 $ir=Join-Path $folder 'retained.ll'
 [IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nDebugInformation = `"None`"`r`nStartup = `"Main`"`r`nSource = `"$name.bas`"`r`n",$encoding)
 [IO.File]::WriteAllText($ir,'retained',$encoding)
 $output=Run $CompilerExe @('--emit-llvm',$manifest,$ir) 1
 if($output -notmatch 'E_LOAD|E_BIND|E_COMPILE' -or [IO.File]::ReadAllText($ir) -cne 'retained'){throw "Invalid rejection/publication: $name"}
 Write-Output "PASS $name rejected; destination preserved"
}
# Identifier suffixes are forbidden even when they agree with an explicit As type.
$invalidSuffixes=New-Object Collections.Generic.List[object]
foreach($suffix in @('$','%','&','&&','^','!','#','@')){
 $invalidSuffixes.Add(@{Name=('suffix-declaration-'+$invalidSuffixes.Count);Body=('Dim Value'+$suffix+' As Long')})
 $invalidSuffixes.Add(@{Name=('suffix-use-'+$invalidSuffixes.Count);Body=('Dim Value As Long'+[Environment]::NewLine+'Value'+$suffix+' = 1')})
}
$invalidSuffixes.Add(@{Name='old-longlong-suffix';Body='Dim Value As LongLong = 2^'})
$invalidSuffixes.Add(@{Name='missing-as';Body='Dim Value'})
foreach($case in $invalidSuffixes){
 $folder=Join-Path $evidence $case.Name
 $null=New-Item -ItemType Directory -Path $folder
 $source='UBE SOURCE 1 MODULE'+[Environment]::NewLine+'Attribute UBE_Name = "RejectedSuffix"'+[Environment]::NewLine+'Public Function Main() As Long'+[Environment]::NewLine+$case.Body+[Environment]::NewLine+'End Function'+[Environment]::NewLine
 [IO.File]::WriteAllText((Join-Path $folder 'Probe.bas'),$source,$encoding)
 $manifest=Join-Path $folder 'Probe.UBE'
 $lines=@('UBE-Project 1','Name = "RejectedSuffix"','Kind = "Exe"','DebugInformation = "None"','Startup = "Main"','Source = "Probe.bas"')
 [IO.File]::WriteAllText($manifest,($lines -join [Environment]::NewLine)+[Environment]::NewLine,$encoding)
 $ir=Join-Path $folder 'retained.ll'
 [IO.File]::WriteAllText($ir,'retained',$encoding)
 $output=Run $CompilerExe @('--emit-llvm',$manifest,$ir) 1
 if($output -notmatch 'E_LOAD|E_BIND|E_COMPILE' -or [IO.File]::ReadAllText($ir) -cne 'retained'){throw "Invalid suffix rejection/publication: $($case.Name)"}
 Write-Output "PASS $($case.Name) rejected; destination preserved"
}
Write-Output "PASS floating frontend source fixtures. Compiler: $CompilerExe"
