# Exercises installed support discovery/protection and failed-request artifact preservation.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe',[switch]$SkipIntegrityCheck)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube support install '+[guid]::NewGuid())
$install=Join-Path $artifacts 'compiler'
$null=New-Item -ItemType Directory -Path $install
$CompilerExe=[IO.Path]::GetFullPath($CompilerExe)
$parent=[IO.Path]::GetDirectoryName($CompilerExe)
$compiler=Join-Path $install 'UBE.exe'
Copy-Item -LiteralPath $CompilerExe -Destination $compiler
Copy-Item -LiteralPath (Join-Path $parent 'llvm') -Destination $install -Recurse
Copy-Item -LiteralPath (Join-Path $parent 'support') -Destination $install -Recurse
$script:sequence=0
function Require([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Quote-Argument([string]$Value){
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
function Run([string[]]$Arguments,[string]$Executable=$compiler){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$Executable;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object{Quote-Argument $_}) -join ' ')}
 $p=Start-Process @options
 try{
  $handle=$p.Handle
  if(-not $p.WaitForExit(60000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Timeout: $prefix"}
  $p.Refresh();Require ($null -ne $p.ExitCode) "No exit status: $handle"
  return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8);Evidence=$prefix}
 }finally{$p.Dispose()}
}
function Fixture([string]$Name,[string]$Body){
 $folder=Join-Path $artifacts $Name;$null=New-Item -ItemType Directory -Path $folder
 [IO.File]::WriteAllText((Join-Path $folder 'Main.bas'),"UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"MainModule`"`r`n"+$Body,$utf8)
 $path=Join-Path $folder 'Project.UBE'
 [IO.File]::WriteAllText($path,"UBE-Project 1`r`nName=`"Fixture`"`r`nKind=`"Exe`"`r`nStartup=`"Main`"`r`nSource=`"Main.bas`"`r`n",$utf8)
 return $path
}
$numeric=Fixture 'numeric' "Public Function Main() As Long`r`nMain = 42`r`nEnd Function`r`n"
$text=Fixture 'text' "Public Function Main() As Long`r`nDim Value As String`r`nMain = 42`r`nEnd Function`r`n"
$target=Join-Path $artifacts 'preserved.ll'
$r=Run @('--emit-llvm',$numeric,$target)
Require ($r.Code -eq 0 -and $r.Out.Trim() -ceq 'EMIT OK' -and $r.Error.Length -eq 0) "Numeric baseline failed: $($r.Evidence)"
$hash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
$executable=Join-Path $artifacts 'preserved.exe'
$r=Run @('--build',$numeric,$executable,'--clang',$Clang)
Require ($r.Code -eq 0 -and $r.Out.Trim() -ceq 'BUILD OK' -and $r.Error.Length -eq 0) "Numeric executable baseline failed: $($r.Evidence)"
$executableHash=(Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
$r=Run @() $executable
Require ($r.Code -eq 42 -and $r.Error.Length -eq 0) 'Numeric executable did not return the independent expected value'
function Reject-ManagedAsset([bool]$Integrity){
 foreach($mode in @('--emit-llvm','--build')){
  $output=$target;$expectedHash=$hash;$arguments=@($mode,$text,$output)
  if($mode -eq '--build'){$output=$executable;$expectedHash=$executableHash;$arguments=@($mode,$text,$output,'--clang',$Clang)}
  $result=Run $arguments
  Require ($result.Code -eq 1 -and $result.Error -match '^UBE: E_ASSET:') "Invalid managed asset not reported by $mode : $($result.Evidence)"
  if($Integrity){Require ($result.Error -match '9/11/3') "Compiled integrity check did not reject changed source: $($result.Evidence)"}
  Require ((Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash -ceq $expectedHash) "Invalid asset replaced prior artifact: $mode"
 }
}
$support=Join-Path $install 'support'
$manifest=Join-Path $support 'Managed.UBE'
$assets=@(Get-ChildItem -LiteralPath $support -File | Where-Object {$_.Extension -ieq '.bas' -or $_.Name -ieq 'Managed.UBE'})
Require ($assets.Count -ge 2) 'No installed support source closure'
foreach($asset in $assets){
 $before=(Get-FileHash -LiteralPath $asset.FullName -Algorithm SHA256).Hash
 $r=Run @('--emit-llvm',$numeric,$asset.FullName)
 Require ($r.Code -eq 1 -and $r.Error -match '^UBE: E_OUTPUT:') "Installed input overwrite was not rejected: $($r.Evidence)"
 Require ((Get-FileHash -LiteralPath $asset.FullName -Algorithm SHA256).Hash -ceq $before) "Input changed: $($asset.Name)"
}
$source=Join-Path $support 'Text.bas'
$sourceBytes=[IO.File]::ReadAllBytes($source)
$sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$alias=Join-Path $artifacts 'source-alias.ll'
$null=New-Item -ItemType HardLink -Path $alias -Target $source
$r=Run @('--emit-llvm',$numeric,$alias)
Require ($r.Code -eq 1 -and $r.Error -match '^UBE: E_OUTPUT:') "Hard-link overwrite was not rejected: $($r.Evidence)"
Require ((Get-FileHash -LiteralPath $alias -Algorithm SHA256).Hash -ceq $sourceHash -and (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ceq $sourceHash) 'Hard-link rejection changed protected input bytes'
$heldManifest=Join-Path $support 'Managed.held'
Move-Item -LiteralPath $manifest -Destination $heldManifest
try{
 $r=Run @('--emit-llvm',$numeric,$target)
 Require ($r.Code -eq 0 -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ceq $hash) "Numeric compiler unexpectedly requires managed manifest: $($r.Evidence)"
 Reject-ManagedAsset $false
}finally{Move-Item -LiteralPath $heldManifest -Destination $manifest}
$heldSource=Join-Path $support 'Text.held'
Move-Item -LiteralPath $source -Destination $heldSource
try{
 $r=Run @('--emit-llvm',$numeric,$target)
 Require ($r.Code -eq 0) "Numeric compiler unexpectedly requires managed source: $($r.Evidence)"
 Reject-ManagedAsset $false
}finally{Move-Item -LiteralPath $heldSource -Destination $source}
if(-not $SkipIntegrityCheck){
 try{
  [IO.File]::AppendAllText($source,"`r`n' changed installed algorithm source`r`n",$utf8)
  Reject-ManagedAsset $true
 }finally{[IO.File]::WriteAllBytes($source,$sourceBytes)}
}else{Write-Output 'UNVERIFIED: installed source integrity (explicitly skipped for a compiler predating that check)'}
$r=Run @('--emit-llvm',$numeric,$target)
Require ($r.Code -eq 0 -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ceq $hash) 'Repaired installation did not recover exact IR'
Require ((Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash -ceq $executableHash) 'Failed requests changed the retained executable'
Write-Output "PASS installed asset protections ($($assets.Count) paths and a hard link), optional numeric assets, missing String assets, prior IR/EXE preservation and recovery. Evidence: $artifacts"
