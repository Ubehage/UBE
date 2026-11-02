function Get-FoundationProjectSources([string]$Manifest){
 $directory=Split-Path $Manifest -Parent
 foreach($line in [IO.File]::ReadAllLines($Manifest)){if($line -match '^Source = "([^"]+)"$'){[IO.Path]::GetFullPath((Join-Path $directory $Matches[1]))}}
 foreach($line in [IO.File]::ReadAllLines($Manifest)){if($line -match '^Reference = "([^"]+)"$'){Get-FoundationProjectSources ([IO.Path]::GetFullPath((Join-Path $directory $Matches[1])))}}
}
function New-FoundationProject([string]$Repo,[string]$Run,[string]$Fixture,[hashtable]$ModulePaths,[bool]$RequireIntegrated){
 $library=Join-Path $Repo 'std-lib/UBECore.UBE';$core=@(Get-FoundationProjectSources $library);$project=Join-Path $Run 'project';$null=New-Item -ItemType Directory -Path $project -Force;$utf8=New-Object Text.UTF8Encoding($false)
 $names=@('SharedProbeOwner.cls','SharedProbeWork.cls','ArenaProbe.bas','NameProbe.bas','SharedEntry.bas');$inputs=@((Get-ArtifactIdentity $library));$modules=@();$integrated=$true
 foreach($name in @('ByteKeys','SignedIntegers','Utf8Encoding','StorageCapacity')){
  $path=$ModulePaths[$name];if(-not $path){$path=Join-Path $Repo ('std-lib/src/portable/'+$name+'.bas')};$path=[IO.Path]::GetFullPath($path)
  if(-not (Test-Path -LiteralPath $path)){throw "Required $name module absent: $path"};$admitted=@($core|Where-Object {[string]::Equals($_,$path,[StringComparison]::OrdinalIgnoreCase)})
  if($admitted.Count -ne 1){$integrated=$false;if($RequireIntegrated){throw "RequireIntegrated: $name is not an exact source of real UBECore Reference"};$copyName='External'+$name+'.bas';[IO.File]::Copy($path,(Join-Path $project $copyName));$names+=$copyName}
  $modules+=@([pscustomobject]@{name=$name;source=(Get-ArtifactIdentity $path);integrated=($admitted.Count -eq 1)})
 }
 foreach($name in @('SharedProbeOwner.cls','SharedProbeWork.cls','ArenaProbe.bas','NameProbe.bas','SharedEntry.bas')){[IO.File]::Copy((Join-Path $Fixture $name),(Join-Path $project $name))}
 $manifest=Join-Path $project 'SemanticFoundations.UBE';$reference=[Uri]::UnescapeDataString(([Uri]($project.TrimEnd('\')+'\')).MakeRelativeUri([Uri]$library).ToString());$lines=@('UBE-Project 1','Name = "SemanticFoundations"','Kind = "Exe"','Startup = "Main"')+@($names|ForEach-Object {'Source = "'+$_+'"'})+@('Reference = "'+$reference+'"');[IO.File]::WriteAllText($manifest,($lines -join "`n")+"`n",$utf8)
 $sources=@(Get-FoundationProjectSources $manifest);$procedures=@{};$types=@{};$classes=@();$ordinal=0
 foreach($source in $sources){$text=[IO.File]::ReadAllText($source);if($text -match '^UBE SOURCE 1 CLASS'){$null=$text -match 'Attribute UBE_Name = "([^"]+)"';$classes+=$Matches[1]};foreach($m in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){$name=$m.Groups[1].Value;if($procedures.ContainsKey($name)){throw "Duplicate foundation ABI procedure $name"};$procedures[$name]='ube.p'+$ordinal;++$ordinal}}
 $ordinal=0;foreach($name in $classes){$types[$name]='%ube.type.'+$ordinal;++$ordinal};foreach($source in $sources){foreach($m in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){$types[$m.Groups[1].Value]='%ube.type.'+$ordinal;++$ordinal}}
 $inputs+=@($sources|ForEach-Object {Get-ArtifactIdentity $_})+@($modules|ForEach-Object source)+(Get-ArtifactIdentity $manifest)
 $snapshot=Join-Path $Run 'reference-inputs';$null=New-Item -ItemType Directory -Path $snapshot -Force
 foreach($path in $core){$relative=[Uri]::UnescapeDataString(([Uri]((Join-Path $Repo 'std-lib').TrimEnd('\')+'\')).MakeRelativeUri([Uri]$path).ToString());$target=Join-Path $snapshot $relative;$null=New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force;[IO.File]::Copy($path,$target)}
 [IO.File]::Copy($library,(Join-Path $snapshot 'UBECore.UBE'))
 return [pscustomobject]@{manifest=(Get-ArtifactIdentity $manifest);sources=$sources;procedures=$procedures;types=$types;classes=$classes;inputs=$inputs;modules=$modules;integrated=$integrated;scope='Real UBECore Reference; missing explicit draft modules are local sources only in nonintegrated diagnostic mode.'}
}
