# Tests production UBE traversal against a deterministic snapshot adapter.
# This is algorithm qualification, not native GC/root/safepoint qualification.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$encoding=New-Object Text.UTF8Encoding($false,$true)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube collector algorithm '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
$script:sequence=0
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
  if(-not $process.WaitForExit(60000)){$process.Kill();$null=$process.WaitForExit(5000);throw "Deadline: $prefix"}
  $process.Refresh()
  $errors=[IO.File]::ReadAllText($prefix+'.stderr')
  if($null -eq $process.ExitCode -or $process.ExitCode -ne $Expected -or $errors.Length){throw "Exit $($process.ExitCode), expected $Expected; $errors; evidence $prefix"}
 }finally{$process.Dispose()}
}
Copy-Item -LiteralPath (Join-Path $repo 'std-lib/src/portable/ManagedMemory.bas') -Destination $evidence
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'CollectorModel.bas') -Destination $evidence
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'CollectorProbe.bas') -Destination $evidence
$probe=Join-Path $evidence 'CollectorProbe.bas'
$original=[IO.File]::ReadAllText($probe,$encoding)
$collector=Join-Path $evidence 'ManagedMemory.bas'
$collectorOriginal=[IO.File]::ReadAllText($collector,$encoding)
foreach($level in @('0','2')) {
 $manifest=Join-Path $evidence ('Project'+$level+'.UBE')
 $text="UBE-Project 1`r`nName = `"CollectorAlgorithm`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in @('ManagedMemory','CollectorModel','CollectorProbe')){$text+="Source = `"$name.bas`"`r`n"}
 [IO.File]::WriteAllText($manifest,$text,$encoding)
 $exe=Join-Path $evidence ('Probe'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang)
 if([IO.File]::ReadAllText((Join-Path $evidence ('process-'+$script:sequence+'.stdout'))) -notmatch '(?m)^BUILD OK\r?$'){throw 'Missing build success marker'}
 Run $exe @()
 Write-Output "PASS O$level cycles, roots, failure without sweep, recovery, release error and joined-round status"
 $changed=$original.Replace('ManagedPrimitives.Releases <> 28','ManagedPrimitives.Releases <> 27')
 if($changed -ceq $original){throw 'Missing negative control marker'}
 [IO.File]::WriteAllText($probe,$changed,$encoding)
 $negative=Join-Path $evidence ('Negative'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$negative,'--clang',$Clang)
 Run $negative @() 1
 [IO.File]::WriteAllText($probe,$original,$encoding)
 Write-Output "PASS O$level changed reclamation count rejected"
 $missingRetirement=$collectorOriginal.Replace('If Not ManagedPrimitives.TryResizeWork(Pending, 0, False) Then','If False Then')
 if($missingRetirement -ceq $collectorOriginal){throw 'Missing workspace retirement control marker'}
 [IO.File]::WriteAllText($collector,$missingRetirement,$encoding)
 $negative=Join-Path $evidence ('UnretiredWorkspace'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$negative,'--clang',$Clang)
 Run $negative @() 1
 [IO.File]::WriteAllText($collector,$collectorOriginal,$encoding)
 Write-Output "PASS O$level workspace must retire before snapshot release"
}
