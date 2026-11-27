# This gate records the pre-implementation boundary, not successful IS_IN_IDE support.
param([Parameter(Mandatory=$true)][string]$CompilerExe)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=[Text.UTF8Encoding]::new($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube ide admission '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$results=New-Object Collections.Generic.List[object]
Write-Output "Evidence: $evidence"
function Run([string[]]$Arguments,[string]$Name) {
 $stdout=Join-Path $evidence ($Name+'.stdout')
 $stderr=Join-Path $evidence ($Name+'.stderr')
 $quoted=($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' '
 $process=Start-Process -FilePath $CompilerExe -ArgumentList $quoted -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
 try {
  $null=$process.Handle
  if(-not $process.WaitForExit(30000)){$process.Kill();throw "Deadline: $Name"}
  $process.Refresh()
  if($null -eq $process.ExitCode){throw "Missing exit status: $Name"}
  return [pscustomobject]@{Code=$process.ExitCode;Out=[IO.File]::ReadAllText($stdout,$utf);Error=[IO.File]::ReadAllText($stderr,$utf)}
 } finally {$process.Dispose()}
}
function Project([string]$Name,[string[]]$Lines) {
 $source=Join-Path $evidence ($Name+'.bas')
 $text=@('UBE SOURCE 1 MODULE','Attribute UBE_Name = "Probe"','Option Explicit')+$Lines
 [IO.File]::WriteAllText($source,($text -join "`r`n")+"`r`n",$utf)
 $manifest=Join-Path $evidence ($Name+'.UBE')
 [IO.File]::WriteAllText($manifest,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nSource = `"$Name.bas`"`r`n",$utf)
 return $manifest
}
$control=Project 'control' @('Public Function Main() As Long','Main = 0','End Function')
$reference=Join-Path $evidence 'control.ll'
$success=$false
try {
 $run=Run @('--emit-llvm',$control,$reference) 'control'
 if($run.Code -ne 0 -or $run.Out -notmatch 'EMIT OK' -or $run.Error.Length -ne 0){throw "Control emission failed: $($run.Out) $($run.Error)"}
 $referenceHash=(Get-FileHash -LiteralPath $reference -Algorithm SHA256).Hash
 if([IO.File]::ReadAllText($reference,$utf) -notmatch 'define'){throw 'Control did not emit function definitions'}
 $results.Add([pscustomobject]@{Case='control';Pass=$true;LLVM=$referenceHash})
 $cases=@(
  @{Name='builtin';Lines=@('Public Function Main() As Long','If IS_IN_IDE Then Main = 1','End Function');Diagnostic='E_COMPILE';Detail='0/2/10';Location='5:4'},
  @{Name='conditional';Lines=@('#If IS_IN_IDE Then','Public Function Main() As Long','Main = 1','End Function','#Else','Public Function Main() As Long','Main = 0','End Function','#End If');Diagnostic='E_LOAD';Detail='8/3/2';Location='4:1'}
 )
 foreach($case in $cases) {
  $manifest=Project $case.Name $case.Lines
  $output=Join-Path $evidence ($case.Name+'.ll')
  [IO.File]::WriteAllText($output,'PRESERVE',$utf)
  $run=Run @('--emit-llvm',$manifest,$output) $case.Name
  $log=$run.Out+$run.Error
  if($run.Code -ne 1 -or -not $log.Contains($case.Diagnostic) -or -not $log.Contains($case.Detail) -or -not $log.Contains($case.Name+'.bas:'+$case.Location)){throw "Unexpected baseline diagnostic: $($case.Name): $log"}
  if([IO.File]::ReadAllText($output,$utf) -cne 'PRESERVE'){throw "Output changed after rejected $($case.Name)"}
  $recovery=Join-Path $evidence ($case.Name+'-recovery.ll')
  $run=Run @('--emit-llvm',$control,$recovery) ($case.Name+'-recovery')
  if($run.Code -ne 0 -or $run.Error.Length -ne 0 -or (Get-FileHash -LiteralPath $recovery -Algorithm SHA256).Hash -cne $referenceHash){throw "Nondeterministic recovery after $($case.Name)"}
  if(@(Get-ChildItem -LiteralPath $evidence -Force -Filter '*.ube-*').Count){throw "Leaked publication stage after $($case.Name)"}
  $results.Add([pscustomobject]@{Case=$case.Name;Pass=$true;Diagnostic=$case.Diagnostic;Detail=$case.Detail;Location=$case.Location;OutputPreserved=$true;RecoveryIdentical=$true})
  Write-Output "PASS baseline $($case.Name): located rejection, preserved output, identical recovery"
 }
 $success=$true
} finally {
 $report=[pscustomobject]@{Success=$success;Scope='Pre-implementation admission baseline only';Compiler=[IO.Path]::GetFullPath($CompilerExe);CompilerSha256=(Get-FileHash -LiteralPath $CompilerExe -Algorithm SHA256).Hash;Results=$results.ToArray()}
 [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),($report|ConvertTo-Json -Depth 5),$utf)
}
Write-Output 'PASS control emission and two unsupported-feature baselines; no implementation claim.'
