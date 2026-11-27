param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube foreach control '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$encoding=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $stdout=Join-Path $evidence ($Name+'.stdout');$stderr=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr;WorkingDirectory=$evidence}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(120000)){$p.Kill();throw "Deadline $Name"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing exit code $Name"};return [pscustomobject]@{Code=$p.ExitCode;ErrorText=[IO.File]::ReadAllText($stderr);Log=([IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr))}}finally{$p.Dispose()}
}
foreach($kind in @('foreach','foreach-object')){
$fixture=[IO.File]::ReadAllText((Join-Path $PSScriptRoot ($kind+'-control.bas')))
$classes=''
if($kind -eq 'foreach-object'){
 foreach($class in @('Box','OtherBox')){
  [IO.File]::WriteAllText((Join-Path $evidence ($class+'.cls')),"UBE SOURCE 1 CLASS`r`nAttribute UBE_Name = `"$class`"`r`nOption Explicit`r`n",$encoding)
  $classes+="Source = `"$class.cls`"`r`n"
 }
}
$controls=@(0,1);if($kind -eq 'foreach'){$controls+=2}
foreach($level in @('0','2')){foreach($control in $controls){
 $name="$kind-o$level-control$control"
 $expected=$control
 $source=$fixture.Replace('Private Const Control As Long = 0',"Private Const Control As Long = $control")
 if($control -eq 2){
  $expected=10
  $source=$source.Replace('Passed = Scalars()','Passed = UnexpectedFailure()')+"`r`nPrivate Function UnexpectedFailure() As Boolean`r`nErr.Raise 5`r`nEnd Function`r`n"
 }
 [IO.File]::WriteAllText((Join-Path $evidence ($name+'.bas')),$source,$encoding)
 $project=Join-Path $evidence ($name+'.UBE')
 [IO.File]::WriteAllText($project,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`nSource = `"$name.bas`"`r`n"+$classes,$encoding)
 $exe=Join-Path $evidence ($name+'.exe')
 $r=Run $CompilerExe @('--build',$project,$exe,'--clang',$Clang) ($name+'-build')
 if($r.Code -ne 0){throw "Build failed $name $($r.Log)"}
 $r=Run $exe @() ($name+'-run')
 if($r.Code -ne $expected -or $r.ErrorText.Length -ne 0){throw "Assertion failed $name expected $expected with empty stderr got $($r.Code): $($r.Log)"}
 Write-Output "PASS $name exit=$expected"
}}
}
