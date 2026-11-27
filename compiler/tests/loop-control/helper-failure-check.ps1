param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube loop helper failure '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $stdout=Join-Path $evidence ($Name+'.stdout');$stderr=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;WorkingDirectory=$evidence;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline $Name"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing exit $Name"};return [pscustomobject]@{Code=$p.ExitCode;ErrorText=[IO.File]::ReadAllText($stderr);Log=([IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr))}}finally{$p.Dispose()}
}
# Direct Raise exits the helper with FAIL; its caller must report a nonzero result.
# These controls specifically reject a skipped If assertion accidentally passing Main.
$cases=@(
 @('do-control','Private Function RecursiveExit(ByVal Depth As Long) As Long',9),
 @('while-control','Private Function HandledFailure() As Long',99),
 @('for-control','Private Function NestedCall(ByVal Depth As Long) As Long',99),
 @('counted-errors','Private Function HeaderFailure(ByVal Position As Long) As Long',99),
 @('managed-local-control','Private Function Retained(ByVal Depth As Long) As Long',99)
)
foreach($case in $cases){
 $fixture=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ($case[0]+'.bas')),$utf)
 if(([regex]::Matches($fixture,[regex]::Escape($case[1]))).Count -ne 1){throw "Ambiguous helper injection $($case[0])"}
 $source="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`n"+$fixture.Replace($case[1],$case[1]+"`r`n    Err.Raise 47")
 foreach($level in @('0','2')){
  $name=$case[0]+'-o'+$level
  [IO.File]::WriteAllText((Join-Path $evidence ($name+'.bas')),$source,$utf)
  $project=Join-Path $evidence ($name+'.UBE')
  [IO.File]::WriteAllText($project,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`nSource = `"$name.bas`"`r`n",$utf)
  $exe=Join-Path $evidence ($name+'.exe')
  $r=Run $CompilerExe @('--build',$project,$exe,'--clang',$Clang) ($name+'-build')
  if($r.Code -ne 0 -or $r.Log -notmatch 'BUILD OK'){throw "Build failed $name $($r.Log)"}
  $r=Run $exe @() ($name+'-run')
  if($r.Code -ne $case[2] -or $r.ErrorText.Length -ne 0){throw "Masked helper failure $name expected $($case[2]) got $($r.Code): $($r.Log)"}
  Write-Output "PASS $name helper FAIL detected exit=$($case[2])"
 }
}
