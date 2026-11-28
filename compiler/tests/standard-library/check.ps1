# Exercises editable ordinary library discovery through the public compiler command.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube standard library '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$script:serial=0;$script:checks=0
function Require([bool]$Condition,[string]$Message){$script:checks++;if(-not $Condition){throw $Message}}
function Write-Text([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,($Text -replace '\r*\n',"`r`n"),$utf8)}
function Quote([string]$Value){'"'+[regex]::Replace([regex]::Replace($Value,'(\\*)"','$1$1\"'),'(\\+)$','$1$1')+'"'}
function Run([string]$File,[string[]]$Arguments){
 $script:serial++;$prefix=Join-Path $evidence ('process-'+$script:serial)
 $start=@{FilePath=$File;WorkingDirectory=$evidence;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.out');RedirectStandardError=($prefix+'.err')}
 if($Arguments.Count){$start.ArgumentList=($Arguments|ForEach-Object{Quote $_}) -join ' '}
 $p=Start-Process @start
 try{$null=$p.Handle;if(-not $p.WaitForExit(180000)){$p.Kill();$null=$p.WaitForExit(5000);throw "Deadline $prefix"};$p.Refresh();[pscustomobject]@{Exit=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.out',$utf8);Error=[IO.File]::ReadAllText($prefix+'.err',$utf8)}}finally{$p.Dispose()}
}
function Catalog([string]$Directory,[string]$Body,[string]$Name='UBECore'){
 $null=New-Item -ItemType Directory -Path $Directory -Force
 Write-Text (Join-Path $Directory 'Values.bas') $Body
 $path=Join-Path $Directory 'UBECore.UBE'
 Write-Text $path "UBE-Project 1`nName = `"$Name`"`nKind = `"Library`"`nDebugInformation = `"None`"`nSource = `"Values.bas`"`n"
 return $path
}
function Project([string]$Name,[string]$Expression,[string]$Optimization){
 $directory=Join-Path $evidence $Name;$null=New-Item -ItemType Directory -Path $directory -Force
 Write-Text (Join-Path $directory 'Main.bas') "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Probe`"`nPublic Function Main() As Long`nMain = $Expression`nEnd Function`n"
 $path=Join-Path $directory 'Probe.UBE'
 Write-Text $path "UBE-Project 1`nName = `"Probe`"`nKind = `"Exe`"`nStartup = `"Main`"`nDebugInformation = `"None`"`nOptimization = `"$Optimization`"`nSource = `"Main.bas`"`n"
 return $path
}
$body=@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Values"
Private Initial As Long = 40
Public Function Answer() As Long
Answer = Helper() + 2
End Function
Private Function Helper() As Long
Helper = Initial
End Function
Public Function Unused() As Long
Unused = 123456789
End Function
Private Function Hidden() As Long
Hidden = 9
End Function
'@
$library=Catalog (Join-Path $evidence 'editable library') $body
Write-Output "Evidence: $evidence"
foreach($optimization in @('0','2')){
 foreach($expression in @('Values.Answer()','Answer()','UBECore.Values.Answer()')){
  $project=Project ('qualified-'+$script:serial+'-o'+$optimization) $expression $optimization
  $output=Join-Path (Split-Path $project) 'program.exe'
  $r=Run $CompilerExe @('--build',$project,$output,'--stdlib',$library,'--clang',$Clang)
  Require ($r.Exit -eq 0 -and $r.Out -ceq "BUILD OK`r`n" -and $r.Error -ceq '') ('ordinary source lookup: '+$r.Error)
  $r=Run $output @();Require ($r.Exit -eq 42) 'Library initializer/private helper result'
 }
 $project=Project ('emission-o'+$optimization) 'Values.Answer()' $optimization
 $output=Join-Path (Split-Path $project) 'program.ll'
 $r=Run $CompilerExe @('--emit-llvm',$project,$output,'--stdlib',$library)
 Require ($r.Exit -eq 0 -and $r.Error -ceq '') ('Library emission: '+$r.Error)
 Require ([IO.File]::ReadAllText($output) -notmatch '123456789') 'Unused library procedure was emitted'
 foreach($expression in @('Values.Hidden()','Hidden()')){
  $project=Project ('private-'+$script:serial+'-o'+$optimization) $expression $optimization
  $output=Join-Path (Split-Path $project) 'program.ll';Write-Text $output 'PRESERVE'
  $r=Run $CompilerExe @('--emit-llvm',$project,$output,'--stdlib',$library)
  Require ($r.Exit -ne 0 -and $r.Error -match 'E_COMPILE' -and [IO.File]::ReadAllText($output) -ceq 'PRESERVE') 'Private library member escaped package or output changed'
 }
}
$edited=Catalog (Split-Path $library) ($body.Replace('Initial As Long = 40','Initial As Long = 41'))
$project=Project 'edited-library' 'Values.Answer()' '2';$output=Join-Path (Split-Path $project) 'program.exe'
$r=Run $CompilerExe @('--build',$project,$output,'--clang',$Clang,'--stdlib',$edited)
Require ($r.Exit -eq 0 -and $r.Error -ceq '') ('Editable library rejected: '+$r.Error)
$r=Run $output @();Require ($r.Exit -eq 43) 'Edited source did not change result'
$wrong=Catalog (Join-Path $evidence 'wrong-name') $body 'Other'
$output=Join-Path (Split-Path $project) 'failure.ll';Write-Text $output 'PRESERVE'
$r=Run $CompilerExe @('--emit-llvm',$project,$output,'--stdlib',$wrong)
Require ($r.Exit -ne 0 -and $r.Error -match '4/11/4' -and [IO.File]::ReadAllText($output) -ceq 'PRESERVE') 'Wrong standard package identity not diagnosed'
$r=Run $CompilerExe @('--emit-llvm',$project,$output,'--stdlib',(Join-Path $evidence 'missing.UBE'))
Require ($r.Exit -ne 0 -and $r.Error -match 'E_LOAD' -and [IO.File]::ReadAllText($output) -ceq 'PRESERVE') 'Missing catalog not diagnosed'
foreach($optimization in @('0','2')){
 $project=Project ('default-scalar-o'+$optimization) '42' $optimization
 $output=Join-Path (Split-Path $project) 'program.ll'
 $r=Run $CompilerExe @('--emit-llvm',$project,$output)
 Require ($r.Exit -eq 0 -and $r.Error -ceq '') ('Default catalog scalar emission: '+$r.Error)
 $ir=[IO.File]::ReadAllText($output)
 Require (([regex]::Matches($ir,'(?m)^define .*@ube\.proc\.\d+\(')).Count -eq 1) 'Unused catalog induced procedure/support bodies'
 Require (([regex]::Matches($ir,'(?m)^define .*@ube\.module\.ensure\.\d+\(')).Count -eq 1) 'Unused catalog induced module initializers'
 $project=Project ('default-text-o'+$optimization) 'Text.Length(Value)' $optimization
 $source=Join-Path (Split-Path $project) 'Main.bas'
 Write-Text $source ([IO.File]::ReadAllText($source).Replace('Main = Text.Length(Value)',"Dim Value As String = `"hello`"`nMain = Text.Length(Value)"))
 $output=Join-Path (Split-Path $project) 'program.exe'
 $r=Run $CompilerExe @('--build',$project,$output,'--clang',$Clang)
 Require ($r.Exit -eq 0 -and $r.Error -ceq '') ('Default catalog text dependency: '+$r.Error)
 $r=Run $output @();Require ($r.Exit -eq 5) 'Default text library result'
}
$library=Catalog (Split-Path $library) $body
$rootShadow=Project 'project-priority' 'Answer()' '2'
$source=Join-Path (Split-Path $rootShadow) 'Main.bas'
Write-Text $source ([IO.File]::ReadAllText($source)+"`nPrivate Function Answer() As Long`nAnswer = 73`nEnd Function`n")
$output=Join-Path (Split-Path $rootShadow) 'program.exe'
$r=Run $CompilerExe @('--build',$rootShadow,$output,'--stdlib',$library,'--clang',$Clang)
Require ($r.Exit -eq 0 -and $r.Error -ceq '') ('Project-first lookup: '+$r.Error)
$r=Run $output @();Require ($r.Exit -eq 73) 'Library overrode project declaration'
$ambiguous=Catalog (Join-Path $evidence 'ambiguous') $body
Write-Text (Join-Path (Split-Path $ambiguous) 'Other.bas') ($body.Replace('UBE_Name = "Values"','UBE_Name = "Other"'))
Write-Text $ambiguous ([IO.File]::ReadAllText($ambiguous)+"Source = `"Other.bas`"`n")
$project=Project 'ambiguous-name' 'Answer()' '2';$output=Join-Path (Split-Path $project) 'program.ll';Write-Text $output 'PRESERVE'
$r=Run $CompilerExe @('--emit-llvm',$project,$output,'--stdlib',$ambiguous)
Require ($r.Exit -ne 0 -and $r.Error -match '/4/10' -and [IO.File]::ReadAllText($output) -ceq 'PRESERVE') ('Ambiguity hidden: '+$r.Error)
$invalid=Catalog (Join-Path $evidence 'invalid-unused') ($body.Replace('Unused = 123456789','Unused = MissingName'))
$r=Run $CompilerExe @('--emit-llvm',$project,$output,'--stdlib',$invalid)
Require ($r.Exit -ne 0 -and $r.Error -match 'E_COMPILE' -and [IO.File]::ReadAllText($output) -ceq 'PRESERVE') 'Unreachable declaration hid invalid source'
foreach($protected in @($library,(Join-Path (Split-Path $library) 'Values.bas'))){
 $before=[IO.File]::ReadAllBytes($protected)
 $r=Run $CompilerExe @('--emit-llvm',$project,$protected,'--stdlib',$library)
 Require ($r.Exit -ne 0 -and $r.Error -match 'E_OUTPUT' -and [Convert]::ToBase64String([IO.File]::ReadAllBytes($protected)) -ceq [Convert]::ToBase64String($before)) 'Library input overwritten'
}
Write-Output "PASS standard library: $script:checks assertions; O0/O2 lookup, initialization, visibility, reachability, editable sources and failures."
