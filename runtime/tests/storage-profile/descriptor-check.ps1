# Reuses retained real-thread shared-descriptor probes with the candidate lock partition.
param([Parameter(Mandatory=$true)][string]$SharedStorageEvidence)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'descriptor-stripes.ps1')
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube descriptor stripes '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
Write-Output "Evidence: $artifacts"
$utf8=New-Object Text.UTF8Encoding($false)
$script:sequence=0
# Runs native tools with bounded execution and retained process status.
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0) {
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WorkingDirectory=$artifacts;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$handle=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();if($p.ExitCode -ne $Expected){throw "Expected $Expected, got $($p.ExitCode): $prefix"}}finally{$p.Dispose()}
}
foreach($level in @('O0','O2')) {
 foreach($expected in @(42,43)) {
  $name=$level+'-'+$expected
  $input=Join-Path $SharedStorageEvidence ($name+'.ll')
  $ir=Add-DescriptorStripes ([IO.File]::ReadAllText($input))
  $stem=Join-Path $artifacts $name
  [IO.File]::WriteAllText(($stem+'.ll'),$ir,$utf8)
  Run 'C:\Program Files\LLVM\bin\clang.exe' @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-'+$level),($stem+'.ll'),(Join-Path $SharedStorageEvidence 'kernel32.lib'),'-o',($stem+'.exe'),'-Wl,/entry:main,/subsystem:console,/stack:8388608')
  $status=0;if($expected -eq 43){$status=99}
  Run ($stem+'.exe') @() $status
  Write-Output "PASS $name candidate same-descriptor concurrency, retained pins, faults, heap cleanup, exit$status"
 }
}
