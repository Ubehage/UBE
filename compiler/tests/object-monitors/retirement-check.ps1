param([Parameter(Mandatory=$true)][string]$CompilerExe)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube retirement failure '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Source evidence: $evidence"
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Gate.cls') -Destination (Join-Path $evidence 'Gate.cls')
$original=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'retirement-failure.bas'),$utf)
foreach($mode in @('statement','return')){
 $text=$original
 if($mode -eq 'return'){
  $before='Depart(Value, False)'
  if([regex]::Matches($text,[regex]::Escape($before)).Count -ne 1){throw 'Missing return-path substitution'}
  $text=$text.Replace($before,'Depart(Value, True)')
 }
 [IO.File]::WriteAllText((Join-Path $evidence 'Main.bas'),$text,$utf)
 $project=Join-Path $evidence ($mode+'.UBE')
 [IO.File]::WriteAllText($project,"UBE-Project 1`r`nName = `"RetirementFailure`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nDebugInformation = `"None`"`r`nSource = `"Gate.cls`"`r`nSource = `"Main.bas`"`r`n",$utf)
 $ir=Join-Path $evidence ($mode+'.ll')
 $stdout=Join-Path $evidence ($mode+'.stdout');$stderr=Join-Path $evidence ($mode+'.stderr')
 $p=Start-Process -FilePath $CompilerExe -ArgumentList @('--emit-llvm',('"'+$project+'"'),('"'+$ir+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
 try{
  $null=$p.Handle
  if(-not $p.WaitForExit(30000)){$p.Kill();throw "Deadline emitting $mode"}
  $p.Refresh();$errors=[IO.File]::ReadAllText($stderr);$output=[IO.File]::ReadAllText($stdout)
  if($null -eq $p.ExitCode -or $p.ExitCode -ne 0 -or $errors.Length -ne 0 -or $output -notmatch '(?m)^EMIT OK\r?$'){throw "Failed to emit $mode : $output $errors"}
 }finally{$p.Dispose()}
 Write-Output "Checking injected retirement failure: $mode"
 & (Join-Path $PSScriptRoot 'cleanup-check.ps1') -ProgramIR $ir -RetirementFailure
}
