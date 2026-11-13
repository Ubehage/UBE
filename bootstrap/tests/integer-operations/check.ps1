# Checks integer operator behavior through compiler CLI and native execution.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[switch]$BaselineRejection,[switch]$ModSpacingReproduction,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube integer operations '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$script:sequence=0
# Runs hidden native processes with retained handles and bounded diagnostics.
function Run([string]$File,[string[]]$Arguments) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $quoted=$Arguments|ForEach-Object {'"'+$_.Replace('"','\"')+'"'}
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=$quoted -join ' '}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(120000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();if($null -eq $p.ExitCode){throw "No retained exit status: $handle"};return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout');Error=[IO.File]::ReadAllText($prefix+'.stderr');Evidence=$prefix}}finally{$p.Dispose()}
}
# Requires an independent expected observation rather than mere successful execution.
function Require([bool]$Condition,[string]$Message) {if(-not $Condition){throw $Message}}
# Creates one isolated executable project with strict UTF-8 source.
function Fixture([string]$Name,[string]$Body,[string]$Level='0') {
 $directory=Join-Path $artifacts $Name;$null=New-Item -ItemType Directory -Path $directory -Force
 $source=Join-Path $directory 'Probe.bas'
 [IO.File]::WriteAllText($source,("UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`n"+($Body -replace '\r?\n',"`r`n")),$utf8)
 $manifest=Join-Path $directory 'Project.UBE'
 [IO.File]::WriteAllText($manifest,("UBE-Project 1`r`nName = `"IntegerOperations`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$Level`"`r`nSource = `"Probe.bas`"`r`n"),$utf8)
 return [pscustomobject]@{Manifest=$manifest;Source=$source;IR=(Join-Path $directory 'result.ll');Exe=(Join-Path $directory 'result.exe')}
}
if($ModSpacingReproduction) {
 foreach($expression in @('(5)Mod(2)','(5) Mod(2)','(5)Mod (2)')) {
  $project=Fixture ('spacing-'+$script:sequence) ("' Reproduces missing required spacing around the Mod keyword.`nPublic Function Main() As Long`nMain = $expression`nEnd Function`n")
  $result=Run $CompilerExe @('--emit-llvm',$project.Manifest,$project.IR)
  Require ($result.Code -eq 0 -and (Test-Path -LiteralPath $project.IR)) "Expected pre-fix spacing acceptance: $($result.Evidence)"
  Write-Output "BASELINE invalid Mod spacing accepted: $expression"
 }
 exit 0
}
if($BaselineRejection) {
 $control=Fixture 'addition-control' "' Confirms the same envelope and operand declarations are admitted.`nPublic Function Main() As Long`nDim Left As Long = 7`nDim Right As Long = 3`nMain = Left + Right`nEnd Function`n"
 $accepted=Run $CompilerExe @('--emit-llvm',$control.Manifest,$control.IR)
 Require ($accepted.Code -eq 0 -and (Test-Path -LiteralPath $control.IR)) "Addition control failed: $($accepted.Evidence)"
 foreach($operator in @('*','\','Mod')) {
  $name='multiply';if($operator -eq '\'){$name='division'};if($operator -eq 'Mod'){$name='modulus'}
  $project=Fixture $name ("' Isolates one currently unsupported runtime integer operator.`nPublic Function Main() As Long`nDim Left As Long = 7`nDim Right As Long = 3`nMain = Left $operator Right`nEnd Function`n")
  $result=Run $CompilerExe @('--emit-llvm',$project.Manifest,$project.IR)
  Require ($result.Code -ne 0 -and $result.Error.StartsWith('UBE: E_')) "Expected controlled rejection: $($result.Evidence)"
  Require (-not (Test-Path -LiteralPath $project.IR)) 'Rejected operator unexpectedly published IR'
  Write-Output ("BASELINE $operator exit$($result.Code): "+$result.Error.Trim())
 }
 exit 0
}
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Probe.bas'),$utf8)
$body=($source -split '\r?\n',3)[2]
foreach($level in @('0','2')) {
 $project=Fixture ('positive-O'+$level) $body $level
 $emitted=Run $CompilerExe @('--emit-llvm',$project.Manifest,$project.IR)
 Require ($emitted.Code -eq 0 -and (Test-Path -LiteralPath $project.IR)) "Emission failed: $($emitted.Evidence)"
 $originalHash=(Get-FileHash -LiteralPath $project.IR -Algorithm SHA256).Hash
 $built=Run $CompilerExe @('--build',$project.Manifest,$project.Exe,'--clang',$Clang)
 Require ($built.Code -eq 0 -and (Test-Path -LiteralPath $project.Exe)) "Build failed: $($built.Evidence)"
 $ran=Run $project.Exe @()
 Require ($ran.Code -eq 0) "Integer observations failed with exit$($ran.Code): $($ran.Evidence)"
 Write-Output "PASS O$level widths/promotion/overflow/division/remainder/precedence/evaluation/fresh FAIL"
 $originalSource=[IO.File]::ReadAllText($project.Source,$utf8)
 $changed=$originalSource.Replace('I <> 510','I <> 511')
 Require ($changed -cne $originalSource) 'Changed-input marker missing'
 [IO.File]::WriteAllText($project.Source,$changed,$utf8)
 $built=Run $CompilerExe @('--build',$project.Manifest,$project.Exe,'--clang',$Clang)
 Require ($built.Code -eq 0) "Changed build failed: $($built.Evidence)"
 $ran=Run $project.Exe @()
 Require ($ran.Code -eq 31) "Changed-input oracle expected31, got$($ran.Code): $($ran.Evidence)"
 [IO.File]::WriteAllText($project.Source,$originalSource,$utf8)
 $rebuilt=Run $CompilerExe @('--emit-llvm',$project.Manifest,$project.IR)
 Require ($rebuilt.Code -eq 0 -and (Get-FileHash -LiteralPath $project.IR -Algorithm SHA256).Hash -ceq $originalHash) 'Restoring source did not restore exact IR'
 $rebuilt=Run $CompilerExe @('--build',$project.Manifest,$project.Exe,'--clang',$Clang)
 Require ($rebuilt.Code -eq 0) "Recovery build failed: $($rebuilt.Evidence)"
 $recovered=Run $project.Exe @()
 Require ($recovered.Code -eq 0) "Recovery native oracle failed: $($recovered.Evidence)"
 Write-Output "PASS O$level changed-input negative and exact IR recovery"
}
$negatives=@(
 @('integer-product','Const Bad As Long = 300% * 300%'),
 @('long-product','Const Bad As LongLong = 2147483647& * 2&'),
 @('longlong-product','Const Bad As LongLong = 9223372036854775807^ * 2^'),
 @('maximum-square','Const Bad As LongLong = 9223372036854775807^ * 9223372036854775807^'),
 @('minimum-square','Const Bad As LongLong = -9223372036854775808^ * -9223372036854775808^'),
 @('mixed-extreme-product','Const Bad As LongLong = -9223372036854775808^ * 9223372036854775807^'),
 @('integer-division','Const Bad As Long = -32768% \ -1%'),
 @('long-division','Const Bad As LongLong = -2147483648& \ -1&'),
 @('longlong-division','Const Bad As LongLong = -9223372036854775808^ \ -1^'),
 @('zero-division','Const Bad As Long = 7 \ 0'),
 @('zero-modulus','Const Bad As Long = 7 Mod 0'),
 @('narrow-constant','Const Bad As Byte = 128 * 2'),
 @('knownzero-runtime',"Private Function Divide(ByVal Value As Long) As Long`nDivide = Value \ 0`nEnd Function")
 @('mod-no-spacing','Const Bad As Long = (5)Mod(2)'),
 @('mod-no-right-spacing','Const Bad As Long = (5) Mod(2)'),
 @('mod-no-left-spacing','Const Bad As Long = (5)Mod (2)')
)
$preserved=$project.IR;$preservedHash=(Get-FileHash -LiteralPath $preserved -Algorithm SHA256).Hash
$preservedExe=$project.Exe;$preservedExeHash=(Get-FileHash -LiteralPath $preservedExe -Algorithm SHA256).Hash
foreach($case in $negatives) {
 $invalid=Fixture $case[0] ($case[1]+"`nPublic Function Main() As Long`nMain = 0`nEnd Function`n")
 $failed=Run $CompilerExe @('--emit-llvm',$invalid.Manifest,$preserved)
 Require ($failed.Code -ne 0 -and $failed.Error.StartsWith('UBE: E_')) "Expected controlled constant rejection: $($failed.Evidence)"
 Require ((Get-FileHash -LiteralPath $preserved -Algorithm SHA256).Hash -ceq $preservedHash) 'Failed constant emission replaced a valid artifact'
 $failedBuild=Run $CompilerExe @('--build',$invalid.Manifest,$preservedExe,'--clang',$Clang)
 Require ($failedBuild.Code -ne 0 -and $failedBuild.Error.StartsWith('UBE: E_')) "Expected controlled build rejection: $($failedBuild.Evidence)"
 Require ((Get-FileHash -LiteralPath $preservedExe -Algorithm SHA256).Hash -ceq $preservedExeHash) 'Failed constant build replaced a valid executable'
 Write-Output "PASS constant rejection and preserved artifact: $($case[0])"
}
Write-Output 'PASS integer-operation CLI and native acceptance'
