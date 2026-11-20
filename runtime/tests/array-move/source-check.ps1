# Executes the ownership-transfer role through a supplied source compiler.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube array move source '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
$utf8=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $artifacts"
$script:sequence=0
function Quote-Argument([string]$Value) {
 if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value}
 $escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"')
 $escaped=[regex]::Replace($escaped,'(\\+)$','$1$1')
 return '"'+$escaped+'"'
}
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object{Quote-Argument $_}) -join ' ')}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();if($p.ExitCode -ne $Expected){throw "Expected $Expected, got $($p.ExitCode): $prefix"}}finally{$p.Dispose()}
}
$source=Join-Path $artifacts 'Probe.bas'
$original=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Probe.bas'),$utf8)
foreach($level in @('0','2')) {
 $manifest=Join-Path $artifacts ('Project'+$level+'.UBE')
 $text="UBE-Project 1`r`nName = `"ArrayMoveTest`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`nSource = `"Probe.bas`"`r`n"
 [IO.File]::WriteAllText($manifest,$text,$utf8)
 foreach($negative in @($false,$true)) {
  $body=$original
  if($negative){$body=$body.Replace('Destination(0) <> 123 Or Destination(1) <> 456 Then Main = 5','Destination(0) <> 124 Or Destination(1) <> 456 Then Main = 5')}
  [IO.File]::WriteAllText($source,$body,$utf8)
  $exe=Join-Path $artifacts ('Probe'+$level+'-'+$negative+'.exe')
  Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang)
  $expected=0;if($negative){$expected=5}
  Run $exe @() $expected
  Write-Output "PASS O$level negative=$negative exact transfer assertions"
 }
 $body=$original.Replace('AtDepth(Destination, Source, 254)','AtDepth(Destination, Source, 253)')
 if($body -eq $original){throw 'Missing depth-boundary control marker'}
 [IO.File]::WriteAllText($source,$body,$utf8)
 $exe=Join-Path $artifacts ('DepthControl'+$level+'.exe')
 Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang)
 Run $exe @() 17
 Write-Output "PASS O$level changed depth boundary rejected; intrinsic commit bypasses exhausted ordinary depth"
}
# Invalid signatures must be refused before either binder emits a callable role.
$invalid=@{
 'element-type'=$original.Replace('ByRef Destination() As Long, ByRef Source() As Long','ByRef Destination() As Long, ByRef Source() As Byte');
 'result-type'=$original.Replace('Function Move(ByRef Destination() As Long, ByRef Source() As Long) As Boolean','Function Move(ByRef Destination() As Long, ByRef Source() As Long) As Long');
 'scalar-source'=$original.Replace('ByRef Destination() As Long, ByRef Source() As Long','ByRef Destination() As Long, ByRef Source As Long')
}
foreach($name in $invalid.Keys) {
 $body=[regex]::Replace($invalid[$name],'(?s)Public Function Main\(\) As Long.*','Public Function Main() As Long'+[Environment]::NewLine+'End Function'+[Environment]::NewLine)
 $body=[regex]::Replace($body,'(?s)Private DepthReached As Boolean.*?(?=Private Intrinsic Function Move)','')
 [IO.File]::WriteAllText($source,$body,$utf8)
 $exe=Join-Path $artifacts ('invalid-'+$name+'.exe')
 Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang) 1
 if(Test-Path -LiteralPath $exe){throw "Invalid role published executable: $name"}
 $stdout=[IO.File]::ReadAllText((Join-Path $artifacts ('process-'+$script:sequence+'.stdout')))
 $stdout+=[IO.File]::ReadAllText((Join-Path $artifacts ('process-'+$script:sequence+'.stderr')))
 if($stdout -notmatch 'E_TYPE|operation/code/reason 0/3/[56]'){throw "Expected controlled type rejection: $name"}
 Write-Output "PASS invalid Array.Move signature $name"
}
