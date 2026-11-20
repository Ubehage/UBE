# Records current String admission boundaries; this is not a managed-text implementation gate.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube managed text admission '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$script:sequence=0
# Quotes literal Windows arguments, including a terminal backslash.
function Quote-Argument([string]$Value) {
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
# Retains process handles and captures bounded, hidden CLI executions.
function Run([string]$File,[string[]]$Arguments) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $quoted=($Arguments|ForEach-Object {Quote-Argument $_}) -join ' '
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=$quoted}
 $p=Start-Process @options
 try {$handle=$p.Handle;if(-not $p.WaitForExit(30000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing exit status: $handle"};return [pscustomobject]@{Code=$p.ExitCode;Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8);Evidence=$prefix}} finally {$p.Dispose()}
}
function Require([bool]$Condition,[string]$Message) {if(-not $Condition){throw $Message}}
# Isolates each missing admission path behind the same valid module and executable entry.
function Fixture([string]$Name,[string]$Body) {
 $directory=Join-Path $artifacts $Name;$null=New-Item -ItemType Directory -Path $directory
 [IO.File]::WriteAllText((Join-Path $directory 'Probe.bas'),("UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`n"+($Body -replace '\r?\n',"`r`n")),$utf8)
 $manifest=Join-Path $directory 'Project.UBE'
 [IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"TextAdmission`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nSource = `"Probe.bas`"`r`n",$utf8)
 return $manifest
}
$control=Fixture 'numeric-control' "' Valid numeric storage and result control.`nPublic Function Main() As Long`nDim Value As Long = 21`nMain = Value * 2`nEnd Function`n"
$ir=Join-Path $artifacts 'preserved.ll';$exe=Join-Path $artifacts 'preserved.exe'
$result=Run $CompilerExe @('--emit-llvm',$control,$ir)
Require ($result.Code -eq 0 -and $result.Error.Length -eq 0 -and (Test-Path -LiteralPath $ir)) "Numeric emission control failed: $($result.Evidence)"
$result=Run $CompilerExe @('--build',$control,$exe,'--clang',$Clang)
Require ($result.Code -eq 0 -and $result.Error.Length -eq 0 -and (Test-Path -LiteralPath $exe)) "Numeric build control failed: $($result.Evidence)"
$irHash=(Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
$exeHash=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
$result=Run $exe @()
Require ($result.Code -eq 42 -and $result.Error.Length -eq 0) "Numeric native observation failed: $($result.Evidence)"
Write-Output 'PASS numeric control publishes IR and executable and returns expected42'
$cases=@(
 @('string-local',"Public Function Main() As Long`nDim Value As String`nMain = 0`nEnd Function`n",'8/3/4','4:14'),
 @('string-literal',"Public Function Main() As Long`nDim Value As Long = `"text`"`nMain = Value`nEnd Function`n",'8/3/11','4:21'),
 @('string-function-result',"Private Function Value() As String`nEnd Function`nPublic Function Main() As Long`nMain = 0`nEnd Function`n",'8/3/4','3:29')
)
foreach($case in $cases) {
 $manifest=Fixture $case[0] $case[1]
 foreach($mode in @('--emit-llvm','--build')) {
  $target=$ir;$expected=$irHash;if($mode -eq '--build'){$target=$exe;$expected=$exeHash}
  $result=Run $CompilerExe @($mode,$manifest,$target)
  $expectedDiagnostic='UBE: E_LOAD: cannot load the ordered source project (operation/code/reason '+$case[2]+') '+(Join-Path (Split-Path $manifest) 'Probe.bas')+':'+$case[3]
  Require ($result.Code -eq 1 -and $result.Error.Trim() -ceq $expectedDiagnostic) "Expected exact controlled source rejection: $($result.Evidence)"
  Require ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ceq $expected) "Rejected source replaced prior artifact: $($result.Evidence)"
  Write-Output ("BASELINE $($case[0]) $mode exit1 preserved: "+$result.Error.Trim())
 }
}
$result=Run $CompilerExe @('--emit-llvm',$control,$ir)
Require ($result.Code -eq 0 -and $result.Error.Length -eq 0 -and (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash -ceq $irHash) 'Numeric control did not recover exact IR after rejected requests'
Write-Output 'PASS current String admission rejection, prior IR/EXE preservation, and numeric recovery'
