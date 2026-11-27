param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$encoding=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube writer limits '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
function Run([string]$File,[string]$Arguments,[string]$Folder){
 $process=Start-Process -FilePath $File -ArgumentList $Arguments -WorkingDirectory $Folder -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Folder 'stdout') -RedirectStandardError (Join-Path $Folder 'stderr')
 try{
  $handle=$process.Handle
  if(-not $process.WaitForExit(60000)){$process.Kill();throw 'Deadline'}
  $process.Refresh()
  if($process.ExitCode -ne 0 -or (Get-Item -LiteralPath (Join-Path $Folder 'stderr')).Length){throw "Process failed $($process.ExitCode): $Folder"}
 }finally{$process.Dispose()}
}
foreach($level in @('0','2')){
 $folder=Join-Path $evidence ('O'+$level)
 $null=New-Item -ItemType Directory -Path $folder
 $manifest=Join-Path $folder 'Probe.UBE'
 $exe=Join-Path $folder 'Probe.exe'
 $text="UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in @('BufferPrimitives','FilePrimitives','FileBytes','ByteText')){
  Copy-Item -LiteralPath (Join-Path $repo "std-lib/src/portable/$name.bas") -Destination $folder
  $text+="Source = `"$name.bas`"`r`n"
 }
 Copy-Item -LiteralPath (Join-Path $repo 'compiler/src/LLVMWriter.bas') -Destination $folder
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'WriterLimits.bas') -Destination $folder
 $text+="Source = `"LLVMWriter.bas`"`r`nSource = `"WriterLimits.bas`"`r`n"
 [IO.File]::WriteAllText($manifest,$text,$encoding)
 Run $CompilerExe ('--build "'+$manifest+'" "'+$exe+'" --clang "'+$Clang+'"') $folder
 Run $exe ' ' $folder
 if((Get-Item -LiteralPath (Join-Path $folder 'writer-output.ll')).Length -ne 33619968){throw 'Output length differs'}
 Write-Output "PASS O$level streamed 33,619,968 bytes / 525,312 lines; invalid append preserved counters"
}
