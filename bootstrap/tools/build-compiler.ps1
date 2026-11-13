# Builds the current UBE compiler with a supplied qualified source compiler and ships its fixed support assets.
param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [Parameter(Mandatory=$true)][string]$Destination,
 [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe',
 [ValidateSet('0','2')][string]$Optimization = '2',
 [ValidateRange(1000,600000)][int]$TimeoutMilliseconds = 180000
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$encoding=New-Object Text.UTF8Encoding($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$CompilerExe=[IO.Path]::GetFullPath($CompilerExe)
if(-not [IO.File]::Exists($CompilerExe)){throw "Source compiler is missing: $CompilerExe"}
& (Join-Path $PSScriptRoot 'runtime-text.ps1')
& (Join-Path $PSScriptRoot 'llvm-templates.ps1')
& (Join-Path $PSScriptRoot 'native-imports.ps1')
$package=& (Join-Path $PSScriptRoot 'self-host-sources.ps1') -Destination $Destination -Kind Exe -Optimization $Optimization
$assets=Join-Path $package.Destination 'llvm'
$null=New-Item -ItemType Directory -Path $assets
foreach($name in @('templates.bin','windows-runtime.ll','kernel32.def')){
 Copy-Item -LiteralPath (Join-Path $root ('compiler/llvm/'+$name)) -Destination (Join-Path $assets $name)
}
$executable=Join-Path $package.Destination 'UBE.exe'
$stdout=Join-Path $package.Destination 'build.stdout'
$stderr=Join-Path $package.Destination 'build.stderr'
# Quotes each literal Windows argument, including its terminal backslashes.
function Quote-Argument([string]$Value){
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
$arguments=@('--build',$package.Manifest,$executable,'--clang',$Clang)
$timer=[Diagnostics.Stopwatch]::StartNew()
$process=Start-Process -FilePath $CompilerExe -ArgumentList (($arguments|ForEach-Object{Quote-Argument $_}) -join ' ') -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try{
 $retainedHandle=$process.Handle
 if(-not $process.WaitForExit($TimeoutMilliseconds)){$process.Kill();$null=$process.WaitForExit(5000);throw "Compiler build deadline exceeded; evidence: $($package.Destination)"}
 $process.Refresh()
 if($null -eq $process.ExitCode){throw "No exit code for retained handle $retainedHandle"}
 $output=[IO.File]::ReadAllText($stdout,$encoding)
 $errors=[IO.File]::ReadAllText($stderr,$encoding)
 if($process.ExitCode -ne 0 -or $output -notmatch '(?m)^BUILD OK\r?$' -or $errors.Length -ne 0){
  throw "Compiler build failed (exit $($process.ExitCode)); evidence: $($package.Destination)`n$errors"
 }
}finally{$timer.Stop();$process.Dispose()}
$bytes=[IO.File]::ReadAllBytes($executable)
if($bytes.Length -lt 90 -or $bytes[0] -ne 77 -or $bytes[1] -ne 90){throw 'Compiler output has no bounded DOS header'}
$offset=[BitConverter]::ToInt32($bytes,60)
if($offset -lt 64 -or $offset -gt $bytes.Length-26){throw 'Compiler output has an invalid PE offset'}
if([BitConverter]::ToUInt32($bytes,$offset) -ne 17744 -or [BitConverter]::ToUInt16($bytes,$offset+4) -ne 34404 -or [BitConverter]::ToUInt16($bytes,$offset+24) -ne 523){throw 'Compiler output is not AMD64 PE32+'}
Write-Output "BUILD: $executable"
Write-Output "Compiler process elapsed milliseconds: $($timer.ElapsedMilliseconds)"
Write-Output 'This build alone does not establish self-hosting or compiler conformance.'
[pscustomobject]@{Executable=$executable;Manifest=$package.Manifest;SourceLedger=(Join-Path $package.Destination 'sources.sha256');SHA256=(Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash}
