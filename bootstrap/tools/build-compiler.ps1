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
& (Join-Path $root 'runtime/managed-source-identities.ps1')
$project=Join-Path $root 'compiler/Compiler.UBE'
$projectHash=(Get-FileHash -LiteralPath $project -Algorithm SHA256).Hash
$package=& (Join-Path $PSScriptRoot 'self-host-sources.ps1') -Destination $Destination -Kind Exe -Optimization $Optimization
$assets=Join-Path $package.Destination 'llvm'
$null=New-Item -ItemType Directory -Path $assets
foreach($name in @('templates.bin','windows-runtime.ll','kernel32.def')){
 Copy-Item -LiteralPath (Join-Path $root ('compiler/llvm/'+$name)) -Destination (Join-Path $assets $name)
}
$null = & (Join-Path $root 'runtime/package-managed-support.ps1') -Destination (Join-Path $package.Destination 'support')
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
$buildManifest=$package.Manifest
$arguments=@('--build',$buildManifest,$executable,'--clang',$Clang)
[IO.File]::WriteAllText((Join-Path $package.Destination 'build-input.json'), ([pscustomobject]@{ Manifest=$buildManifest; RepositoryProjectSHA256=$projectHash; Arguments=$arguments } | ConvertTo-Json), $encoding)
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
if ((Get-FileHash -LiteralPath $project -Algorithm SHA256).Hash -cne $projectHash) { throw 'Compiler project changed during build' }
foreach ($source in $package.Sources) {
 if ((Get-FileHash -LiteralPath $source.OriginalPath -Algorithm SHA256).Hash -cne $source.SHA256) { throw 'Compiler source changed during build' }
}
foreach ($source in @($package.LibrarySources) + @($package.LibraryManifests)) {
 if ((Get-FileHash -LiteralPath $source.OriginalPath -Algorithm SHA256).Hash -cne $source.SHA256) { throw 'Standard library source/catalog changed during build' }
}
$bytes=[IO.File]::ReadAllBytes($executable)
if($bytes.Length -lt 90 -or $bytes[0] -ne 77 -or $bytes[1] -ne 90){throw 'Compiler output has no bounded DOS header'}
$offset=[BitConverter]::ToInt32($bytes,60)
if($offset -lt 64 -or $offset -gt $bytes.Length-26){throw 'Compiler output has an invalid PE offset'}
if([BitConverter]::ToUInt32($bytes,$offset) -ne 17744 -or [BitConverter]::ToUInt16($bytes,$offset+4) -ne 34404 -or [BitConverter]::ToUInt16($bytes,$offset+24) -ne 523){throw 'Compiler output is not AMD64 PE32+'}
Write-Output "BUILD: $executable"
Write-Output "Compiler process elapsed milliseconds: $($timer.ElapsedMilliseconds)"
Write-Output 'This build alone does not establish self-hosting or compiler conformance.'
[pscustomobject]@{Executable=$executable;Manifest=$buildManifest;SourceLedger=(Join-Path $package.Destination 'sources.sha256');SHA256=(Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash}
