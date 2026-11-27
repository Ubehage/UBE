# Records the pre-admission compiler baseline; use the frozen integer/String compiler.
param([Parameter(Mandatory=$true)][string]$CompilerExe)
$ErrorActionPreference='Stop'
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube floating baseline '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false)
foreach($kind in @('Long','Single','Double')) {
 $source=@"
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Public Function Main() As Long
    Dim Value As $kind
    Value = 1
End Function
"@
 $manifest=@"
UBE-Project 1
Name = "Probe"
Kind = "Exe"
Startup = "Main"
Source = "$kind.bas"
"@
 [IO.File]::WriteAllText((Join-Path $evidence "$kind.bas"),$source,$utf)
 $project=Join-Path $evidence "$kind.UBE"
 [IO.File]::WriteAllText($project,$manifest,$utf)
 $output=Join-Path $evidence "$kind.ll"
 [IO.File]::WriteAllText($output,'SENTINEL',$utf)
 $stderr=Join-Path $evidence "$kind.stderr"
 $stdout=Join-Path $evidence "$kind.stdout"
 $process=Start-Process -FilePath $CompilerExe -ArgumentList @('--emit-llvm',('"'+$project+'"'),('"'+$output+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
 $null=$process.Handle
 if(-not $process.WaitForExit(60000)){$process.Kill();throw 'Compiler deadline exceeded'}
 $process.Refresh()
 $code=$process.ExitCode
 $process.Dispose()
 $log=[IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
 [IO.File]::WriteAllText((Join-Path $evidence "$kind.log"),($log -join [Environment]::NewLine),$utf)
 if($kind -eq 'Long') {
  if($code -ne 0 -or [IO.File]::ReadAllText($output) -eq 'SENTINEL'){throw "Integer control failed: $log"}
 } else {
  if($code -eq 0 -or [IO.File]::ReadAllText($output) -ne 'SENTINEL'){throw "Rejection or output preservation failed: $kind"}
  if(($log -join ' ') -notmatch 'E_'){throw "Missing diagnostic: $kind"}
 }
 Write-Output "$kind exit=$code $log"
}
Write-Output "PASS integer control, two floating rejections and preserved outputs; evidence: $evidence"
