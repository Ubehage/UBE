param([Parameter(Mandatory=$true)][string]$CompilerExe)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$CompilerExe=[IO.Path]::GetFullPath($CompilerExe)
$utf=New-Object Text.UTF8Encoding($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube primitive authority '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$script:serial=0;$script:checks=0
Write-Output "Evidence: $evidence"
function Require([bool]$Yes,[string]$Message){$script:checks++;if(-not $Yes){throw $Message}}
function WriteText([string]$Path,[string]$Text){[IO.File]::WriteAllText($Path,$Text,$utf)}
function Run([string]$File,[string[]]$Arguments){
 $script:serial++;$prefix=Join-Path $evidence ('process-'+$script:serial)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(180000)){$p.Kill();throw "Deadline: $prefix"};$p.Refresh();return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($prefix+'.stdout',$utf);Error=[IO.File]::ReadAllText($prefix+'.stderr',$utf)}}finally{$p.Dispose()}
}
$public=Join-Path $evidence 'public';$null=New-Item -ItemType Directory -Path $public
$sources=New-Object Collections.Generic.List[string]
foreach($line in [IO.File]::ReadAllLines((Join-Path $root 'std-lib/UBECore.UBE'))){
 if($line -match '^Source = "([^"]+)"$'){
  $path=Join-Path $root ('std-lib/'+$Matches[1]);$name=[IO.Path]::GetFileName($path)
  Copy-Item -LiteralPath $path -Destination (Join-Path $public $name)
  $sources.Add('Source = "'+$name+'"')
 }
}
foreach($path in @((Join-Path $PSScriptRoot 'Publication.bas'))){
 $name=[IO.Path]::GetFileName($path);Copy-Item -LiteralPath $path -Destination (Join-Path $public $name);$sources.Add('Source = "'+$name+'"')
}
foreach($optimization in '0','2'){
 $manifest=Join-Path $public ('public-o'+$optimization+'.UBE')
 WriteText $manifest ((@('UBE-Project 1','Name = "PublicationProbe"','Kind = "Exe"','Startup = "Main"','DebugInformation = "None"',('Optimization = "'+$optimization+'"'))+@($sources) -join "`r`n")+"`r`n")
 $exe=Join-Path $public ('public-o'+$optimization+'.exe')
 $result=Run $CompilerExe @('--build',$manifest,$exe)
 Require ($result.Code -eq 0 -and $result.Out -ceq "BUILD OK`r`n" -and $result.Error -ceq '') ('Public packaging build failed: '+$result.Error)
 $run=Run $exe @()
 Require ($run.Code -eq 0 -and $run.Out -ceq '' -and $run.Error -ceq '') ('Publication assertions failed: '+$run.Code)
}
# Exact signatures and renamed declarations do not acquire installed-support authority.
$restricted=@('Managed.BeginCollection','Managed.EndCollection','Managed.SealCollection','Managed.Reclaim','Managed.Workspace','Object.MonitorTryEnter','Object.MonitorLeave','Text.Commit')
$declarations=[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/ManagedPrimitives.bas'))+[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/ObjectPrimitives.bas'))+[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/TextPublication.bas'))
foreach($role in $restricted){
 $pattern='(?m)^(?:Public|Private) Intrinsic Function ([^\r\n]+)\r?\nAttribute ([A-Za-z0-9_]+)\.UBE_Primitive = "'+[regex]::Escape($role)+'"\r?\nEnd Function'
 $match=[regex]::Match($declarations,$pattern);Require $match.Success ('Fixture signature missing '+$role)
 foreach($rename in $false,$true){
  $dir=Join-Path $evidence ($role+'-'+$rename);$null=New-Item -ItemType Directory -Path $dir
  $body=$match.Value;if($rename){$originalName=$match.Groups[2].Value;$body=$body.Replace('Function '+$originalName+'(','Function Renamed(').Replace('Attribute '+$originalName+'.','Attribute Renamed.')}
  WriteText (Join-Path $dir 'Forged.bas') ("UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"ManagedPrimitives`"`r`n"+$body+"`r`n")
  $manifest=Join-Path $dir 'Forged.UBE';WriteText $manifest "UBE-Project 1`r`nName = `"Forged`"`r`nKind = `"Library`"`r`nDebugInformation = `"None`"`r`nSource = `"Forged.bas`"`r`n"
  $output=Join-Path $dir 'out.ll';WriteText $output 'PRESERVE'
  $result=Run $CompilerExe @('--emit-llvm',$manifest,$output)
  Require ($result.Code -eq 1 -and $result.Out -ceq '' -and $result.Error -match '8/85' -and $result.Error -match 'Forged.bas') ('Restricted role admitted or wrong diagnostic '+$role+': '+$result.Error)
  Require ([IO.File]::ReadAllText($output) -ceq 'PRESERVE') 'Rejected declaration replaced output'
 }
}
foreach($name in 'ManagedPrimitives.bas','ObjectPrimitives.bas','TextPublication.bas'){
 $dir=Join-Path $evidence ('copy-'+$name);$null=New-Item -ItemType Directory -Path $dir
 Copy-Item -LiteralPath (Join-Path $root ('std-lib/src/portable/'+$name)) -Destination (Join-Path $dir $name)
 $manifest=Join-Path $dir 'Copy.UBE';WriteText $manifest ("UBE-Project 1`r`nName = `"Copy`"`r`nKind = `"Library`"`r`nDebugInformation = `"None`"`r`nSource = `"$name`"`r`n")
 $result=Run $CompilerExe @('--emit-llvm',$manifest,(Join-Path $dir 'out.ll'))
 Require ($result.Code -eq 1 -and $result.Out -ceq '') ('Copied support module admitted '+$name)
}
# Installed support bytes are part of the admitted identity, not a path-based privilege.
$altered=Join-Path $evidence 'altered-install';$null=New-Item -ItemType Directory -Path $altered
$alteredCompiler=Join-Path $altered 'UBE.exe';Copy-Item -LiteralPath $CompilerExe -Destination $alteredCompiler
foreach($name in 'llvm','support','library'){Copy-Item -LiteralPath (Join-Path (Split-Path $CompilerExe) $name) -Destination (Join-Path $altered $name) -Recurse}
$result=Run $alteredCompiler @('--emit-llvm',(Join-Path $public 'public-o2.UBE'),(Join-Path $public 'unaltered.ll'))
Require ($result.Code -eq 0 -and $result.Error -ceq '') 'Unaltered copied installation failed'
$changed=Join-Path $altered 'support/TextPublication.bas'
WriteText $changed ([IO.File]::ReadAllText($changed)+"`r`n' altered installed bytes`r`n")
$output=Join-Path $public 'altered.ll';WriteText $output 'PRESERVE'
$result=Run $alteredCompiler @('--emit-llvm',(Join-Path $public 'public-o2.UBE'),$output)
Require ($result.Code -eq 1 -and $result.Out -ceq '' -and $result.Error -match 'UBE: E_' -and $result.Error.Contains('TextPublication.bas')) 'Altered installed support was not rejected at the modified source'
Require ([IO.File]::ReadAllText($output) -ceq 'PRESERVE') 'Altered support replaced output'
# A wrong expected scalar must be observed by the executable oracle.
$probe=Join-Path $public 'Publication.bas';$body=[IO.File]::ReadAllText($probe)
$changedBody=$body.Replace('If Value <> "A" Then Main = 16','If Value <> "B" Then Main = 16')
Require ($changedBody -cne $body) 'Missing negative-control substitution'
WriteText $probe $changedBody
$exe=Join-Path $public 'negative.exe';$result=Run $CompilerExe @('--build',(Join-Path $public 'public-o2.UBE'),$exe)
Require ($result.Code -eq 0 -and $result.Error -ceq '') 'Negative control build failed'
$run=Run $exe @();Require ($run.Code -eq 16) 'Changed-value negative control was not detected'
WriteText $probe $body
Write-Output "PASS: $script:checks gate assertions plus source publication cases at O0/O2; evidence: $evidence"
