param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe',[switch]$Locks)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube object references '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
function Run([string]$Exe,[string[]]$Arguments,[string]$Name,[int]$Expected){
 $stdout=Join-Path $evidence ($Name+'.stdout');$stderr=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$Exe;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
 if($Arguments.Count){$options.ArgumentList=(@($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' ')}
 $p=Start-Process @options
 try{
  $null=$p.Handle
  if(-not $p.WaitForExit(30000)){$p.Kill();throw "Deadline: $Name"}
  $p.Refresh()
  $errorText=[IO.File]::ReadAllText($stderr)
  if($null -eq $p.ExitCode -or $p.ExitCode -ne $Expected -or $errorText.Length){throw "Expected $Expected, got $($p.ExitCode): $Name $errorText"}
  return [IO.File]::ReadAllText($stdout)
 }finally{$p.Dispose()}
}
$fixture='references'
if($Locks){$fixture='locks'}
$original=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ($fixture+'.bas')),$utf)
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Gate.cls') -Destination (Join-Path $evidence 'Gate.cls')
foreach($level in @('0','2')){
 foreach($control in @('positive','expectation','escaping-failure')){
  $name=$fixture+'-O'+$level+'-'+$control
  $text=$original
  if($control -eq 'expectation'){
   $before='If A IsNot B Then Main = 1: Exit Function'
   $after='If A Is B Then Main = 1: Exit Function'
   if($Locks){$before='If BodyCount <> 1 Or Evaluations <> 1 Then Exit Function';$after='If BodyCount <> 2 Or Evaluations <> 1 Then Exit Function'}
   if([regex]::Matches($text,[regex]::Escape($before)).Count -ne 1){throw 'Missing identity assertion control'}
   $text=$text.Replace($before,$after)
  }
  if($control -eq 'escaping-failure'){
   $main=$text.IndexOf('Public Function Main() As Long')
   if($main -lt 0){throw 'Missing source entrypoint'}
   $start=$text.IndexOf('    On Error GoTo Unexpected',$main)
   if($start -lt 0){throw 'Missing unexpected-FAIL entry handler'}
   $finish=$start+'    On Error GoTo Unexpected'.Length
   $text=$text.Insert($finish,"`n    Call UnexpectedFailure()")
   $text+="`nPrivate Sub UnexpectedFailure()`n    Err.Raise 51`nEnd Sub`n"
  }
  [IO.File]::WriteAllText((Join-Path $evidence 'Main.bas'),$text,$utf)
  $project=Join-Path $evidence ($name+'.UBE')
  [IO.File]::WriteAllText($project,"UBE-Project 1`r`nName = `"ObjectReferences`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`nSource = `"Gate.cls`"`r`nSource = `"Main.bas`"`r`n",$utf)
  $exe=Join-Path $evidence ($name+'.exe')
  $built=Run $CompilerExe @('--build',$project,$exe,'--clang',$Clang) ($name+'-build') 0
  if($built -notmatch '(?m)^BUILD OK\r?$'){throw "Missing build success: $name"}
  $expected=0
  if($control -eq 'expectation'){$expected=1}
  if($control -eq 'escaping-failure'){$expected=90}
  $null=Run $exe @() ($name+'-run') $expected
  if($Locks -and $control -eq 'positive'){
   $ir=Join-Path $evidence ($name+'.ll')
   $emitted=Run $CompilerExe @('--emit-llvm',$project,$ir) ($name+'-emit') 0
   if($emitted -notmatch '(?m)^EMIT OK\r?$'){throw "Missing emission success: $name"}
   Write-Output "Cleanup oracle input: $ir"
  }
  Write-Output "PASS $name expected exit $expected"
 }
}
