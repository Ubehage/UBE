param([Parameter(Mandatory=$true)][string]$CompilerExe,[switch]$ExpectOldLimit,[string[]]$Cases=@('modules','sourcebytes','symbols','syntax'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$encoding=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube project limits '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
foreach($case in $Cases){
 $folder=Join-Path $evidence $case
 $null=New-Item -ItemType Directory -Path $folder
 $manifest=Join-Path $folder 'Probe.UBE'
 $output=Join-Path $folder 'retained.ll'
 $text="UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`n"
 $count=129
 if($case -eq 'sourcebytes' -or $case -eq 'symbols'){$count=2}
 if($case -eq 'syntax'){$count=1}
 for($index=0;$index -lt $count;$index++){
  $name='Module'+$index
  $body="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"$name`"`r`n"
  if($case -eq 'syntax'){
   $body+="Public Function Main() As Long`r`nDim Value As Long`r`n"+("Value = 1 + 2`r`n"*45000)+"End Function`r`n"
  }elseif($index -eq 0){$body+="Public Function Main() As Long`r`nEnd Function`r`n"}
  if($case -eq 'sourcebytes'){$body+=(''' harmless padding'+("x"*1000)+"`r`n")*600}
  if($case -eq 'symbols'){
   for($symbol=0;$symbol -lt 8200;$symbol++){$body+="Private Value$symbol As Long`r`n"}
  }
  [IO.File]::WriteAllText((Join-Path $folder ($name+'.bas')),$body,$encoding)
  $text+="Source = `"$name.bas`"`r`n"
 }
 [IO.File]::WriteAllText($manifest,$text,$encoding)
 [IO.File]::WriteAllText($output,'retained',$encoding)
 $process=Start-Process -FilePath $CompilerExe -ArgumentList ('--emit-llvm "'+$manifest+'" "'+$output+'"') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $folder 'stdout') -RedirectStandardError (Join-Path $folder 'stderr')
 try{
  $handle=$process.Handle
  if(-not $process.WaitForExit(60000)){$process.Kill();throw 'Deadline'}
  $process.Refresh()
  $stdout=[IO.File]::ReadAllText((Join-Path $folder 'stdout'))
  $stderr=[IO.File]::ReadAllText((Join-Path $folder 'stderr'))
  if($ExpectOldLimit){
   if($process.ExitCode -ne 1 -or $stderr -notmatch 'E_LOAD' -or [IO.File]::ReadAllText($output) -cne 'retained'){throw "Missing expected quota rejection: $case $stdout $stderr"}
   Write-Output "PASS reproduced old $case quota; destination preserved: $stderr"
  }else{
   if($process.ExitCode -ne 0 -or $stderr.Length -or $stdout -notmatch 'EMIT OK'){throw "Large project failed: $case $stdout $stderr"}
   if([IO.File]::ReadAllText($output) -notmatch 'define.*@main'){throw "Missing entry IR: $case"}
   Write-Output "PASS above-old-limit $case source project"
  }
 }finally{$process.Dispose()}
}
