# Historical admission baseline: these rejection expectations belong to the pre-member compiler.
param([Parameter(Mandatory=$true)][string]$CompilerExe)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=[Text.UTF8Encoding]::new($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube class member baseline '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$results=New-Object Collections.Generic.List[object]
Write-Output "Evidence: $evidence"
$success=$false
try {
 foreach($name in @('empty','field','method','me')) {
  $folder=Join-Path $evidence $name;$null=New-Item -ItemType Directory -Path $folder
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot ($name+'.cls')) -Destination (Join-Path $folder 'Gate.cls')
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Main.bas') -Destination $folder
  $manifest=Join-Path $folder 'Probe.UBE'
  [IO.File]::WriteAllLines($manifest,@('UBE-Project 1','Name = "Probe"','Kind = "Exe"','Startup = "Main"','DebugInformation = "None"','Source = "Gate.cls"','Source = "Main.bas"'),$utf)
  $output=Join-Path $folder 'out.ll';$sentinel=[byte[]]@(0,255,83,69,78,84,73,78,69,76)
  [IO.File]::WriteAllBytes($output,$sentinel);$prior=(Get-FileHash -LiteralPath $output).Hash
  $stdout=Join-Path $folder 'stdout.txt';$stderr=Join-Path $folder 'stderr.txt'
  $p=Start-Process -FilePath $CompilerExe -ArgumentList @('--emit-llvm',('"'+$manifest+'"'),('"'+$output+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  try {
   $null=$p.Handle
   if(-not $p.WaitForExit(30000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $name"}
   $p.Refresh();if($null -eq $p.ExitCode){throw "Missing status: $name"}
   $code=$p.ExitCode;$out=[IO.File]::ReadAllText($stdout,$utf);$errorText=[IO.File]::ReadAllText($stderr,$utf)
  }finally{$p.Dispose()}
  if($name -eq 'empty') {
   if($code -ne 0 -or $out -cne "EMIT OK`r`n" -or $errorText -ne '' -or [IO.File]::ReadAllText($output,$utf) -notmatch 'define .*@'){throw "Empty-class control failed: $code $out $errorText"}
  } else {
   $location=(Join-Path $folder 'Gate.cls')+':4:1'
   $expected="UBE: E_LOAD: cannot load the ordered source project (operation/code/reason 8/3/42) $location`r`n"
   if($code -ne 1 -or $out -ne '' -or $errorText -cne $expected -or (Get-FileHash -LiteralPath $output).Hash -cne $prior){throw "Expected exact class-member rejection and unchanged bytes: $name $code $out $errorText"}
  }
  if(@(Get-ChildItem -LiteralPath $folder -Force -Filter '*.ube-*').Count){throw "Leaked publication stage: $name"}
  $results.Add([pscustomobject]@{Name=$name;ExitCode=$code;Stdout=$out;Stderr=$errorText;Pass=$true;OutputPreserved=($name -ne 'empty')})
  Write-Output "PASS $name exit=$code"
 }
 $success=$true
}finally {
 [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),(@{Success=$success;Compiler=$CompilerExe;CompilerSHA256=(Get-FileHash -LiteralPath $CompilerExe).Hash;Results=$results.ToArray()}|ConvertTo-Json -Depth 5),$utf)
}
Write-Output 'PASS: four class-member baseline cases; emission only, no native execution claim.'
