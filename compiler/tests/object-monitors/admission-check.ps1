param(
 [Parameter(Mandatory=$true)][string]$CompilerExe,
 [switch]$AdmissionBaseline,
 [switch]$ReferencedPackages,
 [string]$HeaderMismatchLocation='1:14',
 [string]$DuplicateLocation='1:1'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube class admission '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
function WriteText([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,$utf)}
function Run([string]$Project,[string]$Output,[string]$Name){
 $stdout=Join-Path $evidence ($Name+'.stdout');$stderr=Join-Path $evidence ($Name+'.stderr')
 $p=Start-Process -FilePath $CompilerExe -ArgumentList @('--emit-llvm',('"'+$Project+'"'),('"'+$Output+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
 try{
  $null=$p.Handle
  if(-not $p.WaitForExit(30000)){$p.Kill();throw "Deadline: $Name"}
  $p.Refresh()
  if($null -eq $p.ExitCode){throw "Missing exit code: $Name"}
  return [pscustomobject]@{Code=$p.ExitCode;Log=([IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr));Error=[IO.File]::ReadAllText($stderr)}
 }finally{$p.Dispose()}
}
function Source([string]$Kind,[string]$Name,[string]$Body=''){
 return "UBE SOURCE 1 $Kind`r`nAttribute UBE_Name = `"$Name`"`r`n"+$Body
}
function Main([string]$Type='Gate'){
 return Source 'MODULE' 'Runner' "Public Function Main() As Long`r`nDim Value As $Type`r`nMain = 42`r`nEnd Function`r`n"
}
function Project([string]$Name,[System.Collections.Specialized.OrderedDictionary]$Sources,[string]$Reference=''){
 $folder=Join-Path $evidence $Name
 $null=New-Item -ItemType Directory -Path $folder
 $manifest="UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`n"
 foreach($file in $Sources.Keys){WriteText (Join-Path $folder $file) $Sources[$file];$manifest+="Source = `"$file`"`r`n"}
 if($Reference -ne ''){$manifest+="Reference = `"$Reference`"`r`n"}
 $path=Join-Path $folder 'Probe.UBE';WriteText $path $manifest
 return $path
}
function Reject([string]$Name,[System.Collections.Specialized.OrderedDictionary]$Sources,[string]$File,[string]$Location,[string]$Code='E_',[string]$Detail=''){
 $project=Project $Name $Sources
 $output=Join-Path (Split-Path $project) 'out.ll';WriteText $output 'SENTINEL'
 $r=Run $project $output $Name
 if($r.Code -ne 1 -or $r.Log -notmatch [regex]::Escape($Code) -or -not $r.Log.Contains($File+':'+$Location) -or [IO.File]::ReadAllText($output) -cne 'SENTINEL'){
  throw "Expected located controlled rejection and preserved output: $Name $($r.Log)"
 }
 if($Detail -ne '' -and -not $r.Log.Contains('operation/code/reason '+$Detail)){throw "Wrong rejection category: $Name $($r.Log)"}
 Write-Output "PASS rejected $Name at ${File}:$Location"
}
function Accept([string]$Name,[System.Collections.Specialized.OrderedDictionary]$Sources,[string]$Reference=''){
 $project=Project $Name $Sources $Reference
 $output=Join-Path (Split-Path $project) 'out.ll';WriteText $output 'SENTINEL'
 $r=Run $project $output $Name
 if($r.Code -ne 0 -or $r.Error.Length -ne 0 -or [IO.File]::ReadAllText($output) -notmatch 'define .*@'){
  throw "Expected source admission and LLVM emission: $Name $($r.Log)"
 }
 Write-Output "PASS admitted $Name (emission only)"
}
$class=Source 'CLASS' 'Gate'
$explicit=Source 'CLASS' 'Gate' "Option Explicit`r`n"
if($AdmissionBaseline){
 Reject 'class-baseline' ([ordered]@{'Gate.cls'=$explicit;'Main.bas'=(Main)}) 'Probe.UBE' '5:1' 'E_LOAD'
 exit 0
}
Accept 'empty-class' ([ordered]@{'Gate.cls'=$class;'Main.bas'=(Main)})
Accept 'explicit-class' ([ordered]@{'Gate.cls'=$explicit;'Main.bas'=(Main)})
Accept 'package-class' ([ordered]@{'Gate.cls'=$class;'Main.bas'=(Main 'Probe.Gate')})
# Variable declaration nodes begin at the declared name, after the Dim keyword.
Reject 'repeated-package-class' ([ordered]@{'Gate.cls'=$class;'Main.bas'=(Main 'Probe.Probe.Gate')}) 'Main.bas' '4:5'
Reject 'module-shadows-package' ([ordered]@{'Gate.cls'=$class;'Main.bas'=((Main 'Probe.Gate').Replace('UBE_Name = "Runner"','UBE_Name = "Probe"'))}) 'Main.bas' '4:5'
Accept 'contextual-class-name' ([ordered]@{'Gate.cls'=$class;'Main.bas'=(Source 'MODULE' 'Probe' "Public Function Main() As Long`r`nDim Class As Long`r`nClass = 42`r`nMain = Class`r`nEnd Function`r`n")})
Reject 'class-bas-extension' ([ordered]@{'Gate.bas'=$class;'Main.bas'=(Main)}) 'Gate.bas' $HeaderMismatchLocation
Reject 'module-cls-extension' ([ordered]@{'Gate.cls'=(Source 'MODULE' 'Gate');'Main.bas'=(Main)}) 'Gate.cls' $HeaderMismatchLocation
# ProjectSyntax rejects a duplicate module identity before publication, at the source start.
Reject 'duplicate-class-module' ([ordered]@{'Gate.cls'=$class;'Main.bas'=(Source 'MODULE' 'Gate' "Public Function Main() As Long`r`nEnd Function`r`n")}) 'Main.bas' $DuplicateLocation 'E_LOAD' '8/3/1'
foreach($member in @(
 @('field','Public Value As Long'),
 @('initialize',"Private Sub Class_Initialize()`r`nEnd Sub"),
 @('terminate',"Private Sub Class_Terminate()`r`nEnd Sub"),
 @('method',"Public Sub Run()`r`nEnd Sub")
)){
 Reject ('unsupported-'+$member[0]) ([ordered]@{'Gate.cls'=($explicit+$member[1]+"`r`n");'Main.bas'=(Main)}) 'Gate.cls' '4:1'
}
if($ReferencedPackages){
$library=Join-Path $evidence 'Library'
$null=New-Item -ItemType Directory -Path $library
WriteText (Join-Path $library 'Gate.cls') $class
WriteText (Join-Path $library 'Library.UBE') "UBE-Project 1`r`nName = `"Library`"`r`nKind = `"Library`"`r`nSource = `"Gate.cls`"`r`n"
Accept 'referenced-class' ([ordered]@{'Main.bas'=(Main 'Library.Gate')}) '../Library/Library.UBE'
}
