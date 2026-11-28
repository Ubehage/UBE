# Checks scanner cancellation without changing unaffected lexical validation.
param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [string]$Clang='C:\Program Files\LLVM\bin\clang.exe',
 [switch]$NegativeControl
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf8=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube conditional cancellation '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$script:serial=0
Write-Output "Evidence: $evidence"
function Require([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Write-Text([string]$Path,[string]$Value){[IO.File]::WriteAllText($Path,$Value,$utf8)}
function Quote([string]$Value){'"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}
function Run([string]$File,[string[]]$Arguments,[int]$Deadline=180000){
 $script:serial++;$prefix=Join-Path $evidence ('process-'+$script:serial)
 $options=@{FilePath=$File;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{Quote $_}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit($Deadline)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Exit=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf8);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf8)}}finally{$p.Dispose()}
}
foreach($optimization in @('0','2')){
 $folder=Join-Path $evidence ('o'+$optimization)
 $null=New-Item -ItemType Directory -Path $folder
 $sources=@('std-lib/src/portable/BufferPrimitives.bas','std-lib/src/portable/FilePrimitives.bas','std-lib/src/portable/Utf8.bas','std-lib/src/portable/ThreadPrimitives.bas','compiler/src/SourceScanner.bas','std-lib/src/portable/TextPrimitives.bas','compiler/src/SyntaxTokens.bas','compiler/src/ConstantValues.bas','compiler/src/ConstantText.bas','compiler/src/ConditionalSource.bas','compiler/src/ConditionalExpressions.bas','std-lib/src/portable/ByteText.bas','std-lib/src/portable/InvariantNumbers.bas','std-lib/src/portable/BinaryFloat.bas','std-lib/src/portable/BinaryFloatValues.bas','std-lib/src/portable/BinaryFloatMath.bas','std-lib/src/portable/BinaryFloatPower.bas','std-lib/src/portable/BinaryFloatText.bas','compiler/src/SourceParser.bas','compiler/tests/scanner-cancellation/Schedule.bas','compiler/tests/scanner-cancellation/ConditionalProbe.bas')
 $lines=@('UBE-Project 1','Name = "ScannerCancellation"','Kind = "Exe"','Startup = "Main"','DebugInformation = "None"',('Optimization = "'+$optimization+'"'))
 foreach($source in $sources){
  $leaf=Split-Path $source -Leaf
  Copy-Item -LiteralPath (Join-Path $root $source) -Destination (Join-Path $folder $leaf)
  $scopes=@{}
  if($leaf -eq 'ConditionalSource.bas'){
   $names=@('DirectiveWord','AddConstant','TrySelect')
   for($i=0;$i -lt $names.Count;$i++){$scopes[$names[$i]]=$i+1}
  } elseif($leaf -eq 'ConditionalExpressions.bas'){
   $names=@('ResolveName','ValidateInputs','ReadExpression')
   for($i=0;$i -lt $names.Count;$i++){$scopes[$names[$i]]=$i+4}
  }
  if($scopes.Count){
   $path=Join-Path $folder $leaf
   $current='';$hits=@{};$output=New-Object 'Collections.Generic.List[string]'
   foreach($line in [IO.File]::ReadAllLines($path)){
    if($line -match '^(?:Private|Public) Function (\w+)'){$current=$Matches[1]}
    if($scopes.ContainsKey($current) -and $line -match '^(\s*)If Not Checkpoint\('){
     $output.Add($Matches[1]+'CancellationSchedule.Visit '+$scopes[$current])
     $hits[$current]=$true
    }
    $output.Add($line)
   }
   foreach($name in $scopes.Keys){Require ($hits.ContainsKey($name)) ('Missing checkpoint scope '+$name)}
   $instrumented=($output -join [Environment]::NewLine)+[Environment]::NewLine
   if($NegativeControl){
    $instrumented=$instrumented.Replace('If ThreadPrimitives.StopRequested() Then','If False Then')
   }
   Write-Text $path $instrumented
  }
  $lines+='Source = "'+$leaf+'"'
 }
 $manifest=Join-Path $folder 'probe.UBE'
 Write-Text $manifest (($lines -join "`r`n")+"`r`n")
 $probe=Join-Path $folder 'probe.exe'
 $built=Run $CompilerExe @('--build',$manifest,$probe,'--clang',$Clang)
 Require ($built.Exit -eq 0 -and $built.Out -match '(?m)^BUILD OK\r?$' -and $built.Error -ceq '') ('Probe build failed: '+$built.Error)
 $r=Run $probe @() 120000
 $expected=0; if($NegativeControl){$expected=103}
 Require ($r.Exit -eq $expected -and $r.Out -ceq '' -and $r.Error -ceq '') ('Scanner cancellation O'+$optimization+' failed: exit '+$r.Exit+' '+$r.Error)
 if($NegativeControl){Write-Output "PASS O$optimization : disabled checkpoint rejected with exact exit $expected"} else { Write-Output "PASS O$optimization : 6 deterministic conditional-loop stops, bounded observation, unchanged outputs, per-thread Err" }
}
Write-Output "PASS scanner cancellation; evidence: $evidence"