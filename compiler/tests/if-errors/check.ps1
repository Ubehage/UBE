# Executes the same condition-error oracle through either the product or seed compiler.
param([Parameter(Mandatory=$true)][string]$CompilerExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube if errors '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$script:serial=0
$results=New-Object Collections.Generic.List[object]
$success=$false
Write-Output "Evidence: $evidence"
function Quote([string]$Value){'"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}
function Run([string]$File,[string[]]$Arguments){
 $script:serial++;$prefix=Join-Path $evidence ('process-'+$script:serial)
 $options=@{FilePath=$File;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{Quote $_}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Exit=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8)}}finally{$p.Dispose()}
}
try {
 $source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Probe.bas'),$utf8)
 foreach($level in @('0','2')){
  foreach($control in @($false,$true)){
   $name='O'+$level+'-control'+$control
   $folder=Join-Path $evidence $name;$null=New-Item -ItemType Directory -Path $folder
   $text=$source
   if($control){$text=$text.Replace('Main = Branches(1)', 'Main = 1 + Branches(1)')}
   [IO.File]::WriteAllText((Join-Path $folder 'Probe.bas'),$text,$utf8)
   $manifest=Join-Path $folder 'Probe.UBE'
   [IO.File]::WriteAllLines($manifest,@('UBE-Project 1','Name = "IfErrors"','Kind = "Exe"','Startup = "Main"',('Optimization = "'+$level+'"'),'DebugInformation = "None"','Source = "Probe.bas"'),$utf8)
   $exe=Join-Path $folder 'Probe.exe'
   $build=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang)
   if($build.Exit -ne 0 -or $build.Out -notmatch '(?m)^BUILD OK\r?$' -or $build.Error -ne ''){throw "Build failed $name : $($build|ConvertTo-Json -Compress)"}
   $native=Run $exe @();$expected=[int]$control
   $pass=$native.Exit -eq $expected -and $native.Out -eq '' -and $native.Error -eq ''
   $results.Add([pscustomobject]@{Case=$name;Expected=$expected;Actual=$native.Exit;Pass=$pass})
   if(-not $pass){throw "Condition oracle failed $name expected $expected actual $($native.Exit)"}
   Write-Output "PASS $name exact exit $expected"
  }
 }
 $success=$true
}finally{
 [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),(@{Success=$success;Compiler=$CompilerExe;CompilerSHA256=(Get-FileHash -LiteralPath $CompilerExe).Hash;SourceSHA256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'Probe.bas')).Hash;Results=$results.ToArray()}|ConvertTo-Json -Depth 5),$utf8)
}
