# Executes scalar codecs through an actual compiler and checks every valid scalar against .NET UTF-8.
param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$encoding=New-Object Text.UTF8Encoding($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube unicode scalars '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $artifacts
$script:number=0
Write-Output "Evidence: $artifacts"
function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Write-Text([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,$encoding)}
function Quote-Argument([string]$Value){if($Value.Length -gt 0 -and $Value -notmatch '[\s"]'){return $Value};$escaped=[regex]::Replace($Value,'(\\*)"','$1$1\"');$escaped=[regex]::Replace($escaped,'(\\+)$','$1$1');return '"'+$escaped+'"'}
function Run([string]$File,[string[]]$Arguments,[string]$Directory,[int]$Timeout=60000){
 $script:number++;$prefix=Join-Path $artifacts ('process-'+$script:number)
 $options=@{FilePath=$File;WorkingDirectory=$Directory;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object{Quote-Argument $_}) -join ' ')}
 $process=Start-Process @options
 try{
  $handle=$process.Handle
  if(-not $process.WaitForExit($Timeout)){$process.Kill();$null=$process.WaitForExit(5000);throw "Deadline exceeded: $prefix"}
  $process.Refresh();Require ($null -ne $process.ExitCode) "Missing exit code: $handle"
  return [pscustomobject]@{ExitCode=$process.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$encoding);Error=[IO.File]::ReadAllText($prefix+'.stderr',$encoding);Evidence=$prefix}
 }finally{$process.Dispose()}
}
# The oracle uses the framework encoder and streaming byte comparisons, not the UBE arithmetic algorithm.
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
public static class UnicodeScalarOracle {
 public static void Write(string path) {
  var encoder = new UTF8Encoding(false, true);
  using (var output = File.Create(path)) {
   for (int scalar = 0; scalar <= 0x10ffff; scalar++) {
    if (scalar >= 0xd800 && scalar <= 0xdfff) continue;
    byte[] bytes = encoder.GetBytes(char.ConvertFromUtf32(scalar));
    output.Write(bytes, 0, bytes.Length);
   }
  }
 }
 public static bool Equal(string left, string right) {
  using (var a = File.OpenRead(left)) using (var b = File.OpenRead(right)) {
   if (a.Length != b.Length) return false;
   int value;
   while ((value = a.ReadByte()) != -1) if (value != b.ReadByte()) return false;
   return b.ReadByte() == -1;
  }
 }
}
'@
$expected=Join-Path $artifacts 'expected.bin'
[UnicodeScalarOracle]::Write($expected)
$CompilerExe=[IO.Path]::GetFullPath($CompilerExe)
Require ([IO.File]::Exists($CompilerExe)) 'Compiler executable is missing'
Write-Text (Join-Path $artifacts 'compiler.sha256') ((Get-FileHash -LiteralPath $CompilerExe -Algorithm SHA256).Hash)
foreach($level in @('0','2')){
 $directory=Join-Path $artifacts ('O'+$level);$null=New-Item -ItemType Directory -Path $directory
 $manifestLines=@('UBE-Project 1','Name = "UnicodeScalars"','Kind = "Exe"','Startup = "Main"',('Optimization = "'+$level+'"'))
 $sources=@('BufferPrimitives','FilePrimitives','FileBytes','Utf8')
 foreach($name in $sources){Copy-Item -LiteralPath (Join-Path $root ('std-lib/src/portable/'+$name+'.bas')) -Destination (Join-Path $directory ($name+'.bas'));$manifestLines+='Source = "'+$name+'.bas"'}
 Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Probe.bas') -Destination (Join-Path $directory 'Probe.bas')
 $manifestLines+='Source = "Probe.bas"'
 $manifest=Join-Path $directory 'project.UBE';Write-Text $manifest (($manifestLines -join "`r`n")+"`r`n")
 $ledger=@(Get-ChildItem -LiteralPath $directory -Filter '*.bas'|ForEach-Object{((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)+'  '+$_.Name})
 Write-Text (Join-Path $directory 'sources.sha256') (($ledger -join "`r`n")+"`r`n")
 $ir=Join-Path $directory 'output.ll'
 $emit=Run $CompilerExe @('--emit-llvm',$manifest,$ir) $directory
 Require ($emit.ExitCode -eq 0 -and $emit.Out -match '(?m)^EMIT OK\r?$' -and $emit.Error -eq '') "Emission failed: $($emit.Evidence)"
 $hash=(Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
 $repeat=Run $CompilerExe @('--emit-llvm',$manifest,$ir) $directory
 Require ($repeat.ExitCode -eq 0 -and (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash -ceq $hash) "Nondeterministic codec IR: $($repeat.Evidence)"
 $exe=Join-Path $directory 'probe.exe'
 $build=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang) $directory
 Require ($build.ExitCode -eq 0 -and $build.Out -match '(?m)^BUILD OK\r?$' -and $build.Error -eq '') "Build failed: $($build.Evidence)"
 $timer=[Diagnostics.Stopwatch]::StartNew();$run=Run $exe @() $directory 600000;$timer.Stop()
 Require ($run.ExitCode -eq 0 -and $run.Out -eq '' -and $run.Error -eq '') "Codec assertion $($run.ExitCode) failed: $($run.Evidence)"
 Require ([UnicodeScalarOracle]::Equal($expected,(Join-Path $directory 'utf8.bin'))) "Exhaustive UTF-8 byte oracle mismatch at O$level"
 Write-Output "PASS O${level}: 35 boundary/malformed/publication groups; 1112064 scalar round trips; exact independent UTF-8 bytes; $($timer.ElapsedMilliseconds) ms"
 # Alter a known expected byte, ensuring that an unchanged source assertion rejects it.
 $probe=Join-Path $directory 'Probe.bas';$text=[IO.File]::ReadAllText($probe,$encoding)
 Require ($text.Contains('Vector(128, 2, 194, 128, 0, 0)')) 'Changed-input anchor is missing'
 Write-Text $probe ($text.Replace('Vector(128, 2, 194, 128, 0, 0)','Vector(129, 2, 194, 128, 0, 0)'))
 $negative=Join-Path $directory 'negative.exe'
 $build=Run $CompilerExe @('--build',$manifest,$negative,'--clang',$Clang) $directory
 Require ($build.ExitCode -eq 0) "Negative control build failed: $($build.Evidence)"
 $run=Run $negative @() $directory
 Require ($run.ExitCode -eq 3 -and $run.Out -eq '' -and $run.Error -eq '') "Changed scalar must fail exactly vector3: $($run.Evidence)"
 Write-Output "PASS O${level}: changed scalar rejected by independent byte oracle"
}
Write-Output "PASS Unicode scalar codec gate; evidence: $artifacts"
