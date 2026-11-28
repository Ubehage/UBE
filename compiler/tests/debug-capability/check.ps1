# Checks unmet debug requests through the public command and reusable compilation APIs.
param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe',
 [ValidateSet('0','2')][string[]]$ApiOptimization = @('0','2'),
 [switch]$SkipApi
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$CompilerExe=[IO.Path]::GetFullPath($CompilerExe)
$utf8=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube debug capability '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$script:checks=0
$script:serial=0
Write-Output "Evidence: $evidence"
function Require([bool]$Value,[string]$Message){$script:checks++;if(-not $Value){throw $Message}}
function Write-Text([string]$Path,[string]$Value){[IO.File]::WriteAllText($Path,$Value,$utf8)}
function Quote([string]$Value){'"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}
function Run([string]$File,[string[]]$Arguments,[int]$Deadline=180000){
 $script:serial++;$prefix=Join-Path $evidence ('process-'+$script:serial)
 $options=@{FilePath=$File;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{Quote $_}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit($Deadline)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Exit=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8)}}finally{$p.Dispose()}
}
function Project([string]$Name,[string]$Debug,[string]$Optimization='0',[bool]$Invalid=$false){
 $directory=Join-Path $evidence $Name;$null=New-Item -ItemType Directory -Path $directory
 $body="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`nPublic Function Main() As Long`r`nMain = 42`r`nEnd Function`r`n"
 if($Invalid){$body=$body.Replace('Main = 42','Main = MissingName')}
 Write-Text (Join-Path $directory 'Probe.bas') $body
 $lines=@('UBE-Project 1','Name = "Probe"','Kind = "Exe"','Startup = "Main"',('Optimization = "'+$Optimization+'"'),'Source = "Probe.bas"')
 if($Debug -ne 'Default'){$lines+='DebugInformation = "'+$Debug+'"'}
 $manifest=Join-Path $directory 'Probe.UBE';Write-Text $manifest (($lines -join "`r`n")+"`r`n")
 return $manifest
}
function ExpectedWarning([string]$Manifest,[int]$Mode){
 if($Mode -eq 0){return ''}
 return "UBE: W_DEBUG_UNAVAILABLE: debug information unavailable (operation/code/reason 0/$Mode/0) $Manifest`r`n"
}
$modes=@(@{Name='Default';Value=2},@{Name='Line';Value=1},@{Name='Full';Value=2},@{Name='None';Value=0})
$plainHash=''
foreach($optimization in @('0','2')){
 foreach($mode in $modes){
  $manifest=Project ($mode.Name+'-o'+$optimization) $mode.Name $optimization
  foreach($command in @('--emit-llvm','--build','--emit-llvm-ide','--build-ide')){
   $build=$command.StartsWith('--build');$leaf='program.ll';$marker='EMIT OK'
   if($build){$leaf='program.exe';$marker='BUILD OK'}
   $output=Join-Path (Split-Path $manifest) ($command.Substring(2)+'-'+$leaf)
   Write-Text $output 'PRESERVE'
   $arguments=@($command,$manifest,$output);if($build){$arguments+=@('--clang',$Clang)}
   $result=Run $CompilerExe $arguments
   Require ($result.Exit -eq 0 -and $result.Out -ceq ($marker+"`r`n")) ($command+' '+$mode.Name+': exact success')
   Require ($result.Error -ceq (ExpectedWarning $manifest $mode.Value)) ($command+' '+$mode.Name+': exact warning: '+$result.Error)
   Require ((Get-Item -LiteralPath $output).Length -gt 8) ($command+' '+$mode.Name+': published output missing')
   if($command -eq '--emit-llvm'){
    $hash=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
    if($mode.Name -eq 'Default'){$plainHash=$hash}else{Require ($hash -ceq $plainHash) 'Unsupported debug mode changed emitted LLVM'}
    Require ([IO.File]::ReadAllText($output,$utf8) -notmatch '!DICompileUnit|!DILocation|llvm\.dbg\.') 'Unexpected source debug metadata; review warning contract'
   }
   if($command -eq '--build'){
    $run=Run $output @()
    Require ($run.Exit -eq 42 -and $run.Out -ceq '' -and $run.Error -ceq '') 'Warning changed executable behavior'
   }
  }
 }
}
# Failed publication/compilation never acquires a success-only capability warning.
$invalid=Project 'invalid' 'Full' '0' $true
$invalidOutput=Join-Path (Split-Path $invalid) 'program.ll';Write-Text $invalidOutput 'PRESERVE'
$bad=Run $CompilerExe @('--emit-llvm',$invalid,$invalidOutput)
Require ($bad.Exit -eq 1 -and $bad.Out -ceq '' -and $bad.Error.StartsWith('UBE: E_') -and -not $bad.Error.Contains('W_DEBUG_UNAVAILABLE')) 'Failure was masked by capability warning'
Require ([IO.File]::ReadAllText($invalidOutput,$utf8) -ceq 'PRESERVE') 'Failed compilation replaced prior output'
$valid=Project 'publication-failure' 'Full'
$bad=Run $CompilerExe @('--emit-llvm',$valid,(Join-Path (Split-Path $valid) 'Probe.bas'))
Require ($bad.Exit -eq 1 -and $bad.Out -ceq '' -and -not $bad.Error.Contains('W_DEBUG_UNAVAILABLE')) 'Refused output received success warning'
$default=Project 'api-default' 'Default'
$none=Project 'api-none' 'None'
if(-not $SkipApi){
 foreach($optimization in $ApiOptimization){
  $package=& (Join-Path $root 'bootstrap/tools/self-host-sources.ps1') -Destination (Join-Path $evidence ('api-o'+$optimization)) -Kind Exe -Optimization $optimization -AdditionalSources (Join-Path $PSScriptRoot 'Probe.bas')
  # The probe supplies Main; omit only the CLI entry module so all request implementations remain real.
  $lines=[IO.File]::ReadAllLines($package.Manifest,$utf8) | Where-Object {$_ -cne 'Source = "CompilerCommand.bas"'}
  Write-Text $package.Manifest (($lines -join "`r`n")+"`r`n")
  Copy-Item -LiteralPath (Join-Path (Split-Path $CompilerExe) 'llvm') -Destination (Join-Path $package.Destination 'llvm') -Recurse
  $executable=Join-Path $package.Destination 'probe.exe'
  $built=Run $CompilerExe @('--build',$package.Manifest,$executable,'--clang',$Clang)
  Require ($built.Exit -eq 0 -and $built.Out -ceq "BUILD OK`r`n" -and $built.Error -ceq '') 'API probe build failed'
  $output=Join-Path $package.Destination 'request.ll'
  $run=Run $executable @($default,$none,$invalid,$output)
  Require ($run.Exit -eq 0 -and $run.Out -ceq '' -and $run.Error -ceq '') ('API metadata/reset/isolation or no-rendering assertion failed: '+$run.Exit)
  Require ([IO.File]::ReadAllText($output,$utf8) -match 'define .*@') 'API failure lost earlier published output'
 }
}
Write-Output "PASS: $script:checks assertions for debug capability reporting; API skipped=$SkipApi; API optimization=$($ApiOptimization -join ','); evidence: $evidence"
