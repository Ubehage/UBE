# Installs the ordinary library catalog selected for the compilation target.
param(
 [Parameter(Mandatory=$true)][string]$Destination,
 [ValidateSet('Windows-x64')][string]$Target = 'Windows-x64',
 [string]$LibraryRoot = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')))
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$encoding=New-Object Text.UTF8Encoding($false,$true)
$sourceRoot=[IO.Path]::GetFullPath($LibraryRoot).TrimEnd([char[]]@('\','/'))
$targetRoot=[IO.Path]::GetFullPath($Destination).TrimEnd([char[]]@('\','/'))
if(Test-Path -LiteralPath $targetRoot){throw "Library destination already exists: $targetRoot"}

# Plain ancestors make lexical source/destination containment meaningful.
function Assert-PlainPath([string]$Path){
 $current=$Path
 while($current){
  if(Test-Path -LiteralPath $current){
   $item=Get-Item -LiteralPath $current -Force
   if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Redirected library path: $current"}
   if($current -cne $Path -and -not $item.PSIsContainer){throw "Non-directory library ancestor: $current"}
  }
  $current=[IO.Path]::GetDirectoryName($current)
 }
}
Assert-PlainPath $targetRoot
Assert-PlainPath $sourceRoot
$manifests=@('UBECore.UBE')
if($Target -eq 'Windows-x64'){$manifests+='UBECore.Windows.UBE'}
$records=New-Object Collections.Generic.List[object]
$seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$modules=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$manifestRecords=New-Object Collections.Generic.List[object]
foreach($name in $manifests){
 $manifest=Join-Path $sourceRoot $name
 Assert-PlainPath $manifest
 $manifestBytes=[IO.File]::ReadAllBytes($manifest)
 $lines=[regex]::Split($encoding.GetString($manifestBytes),'\r\n|\n|\r')
 if($lines.Count -lt 4 -or $lines[0] -cne 'UBE-Project 1'){throw "Invalid library manifest: $manifest"}
 $hasName=$false;$hasKind=$false
 foreach($line in ($lines|Select-Object -Skip 1)){
  if(-not $line.Trim() -or $line.TrimStart().StartsWith("'")){continue}
  if($line -match '^Name = "[A-Za-z_][A-Za-z0-9_]*"$'){
   if($hasName){throw "Repeated library name: $manifest"};$hasName=$true;continue
  }
  if($line -ceq 'Kind = "Library"'){
   if($hasKind){throw "Repeated library kind: $manifest"};$hasKind=$true;continue
  }
  if($line -notmatch '^Source = "(src/[A-Za-z0-9_./-]+\.bas)"$'){throw "Unsupported library entry: $manifest : $line"}
  $relative=$Matches[1]
  if(($relative -split '/') -contains '..' -or ($relative -split '/') -contains '.'){throw "Noncanonical library path: $relative"}
  if(-not $seen.Add($relative)){throw "Repeated library source: $relative"}
  $path=[IO.Path]::GetFullPath((Join-Path $sourceRoot $relative))
  if(-not $path.StartsWith($sourceRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "Library source escapes root: $relative"}
  Assert-PlainPath $path
  $item=Get-Item -LiteralPath $path -Force
  if($item.PSIsContainer){throw "Library source is a directory: $relative"}
  $bytes=[IO.File]::ReadAllBytes($path)
  $text=$encoding.GetString($bytes)
  $declarations=[regex]::Matches($text,'(?m)^Attribute UBE_Name = "([A-Za-z_][A-Za-z0-9_]*)"\r?$')
  if($declarations.Count -ne 1 -or -not $modules.Add($declarations[0].Groups[1].Value)){throw "Missing or duplicate library module identity: $relative"}
  $hasher=[Security.Cryptography.SHA256]::Create()
  try{$hash=[BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace('-','')}finally{$hasher.Dispose()}
  $records.Add([pscustomobject]@{OriginalPath=$path;RelativePath=$relative;Bytes=$bytes;SHA256=$hash})
 }
 if(-not $hasName -or -not $hasKind){throw "Incomplete library manifest: $manifest"}
 $hasher=[Security.Cryptography.SHA256]::Create()
 try{$hash=[BitConverter]::ToString($hasher.ComputeHash($manifestBytes)).Replace('-','')}finally{$hasher.Dispose()}
 $manifestRecords.Add([pscustomobject]@{OriginalPath=$manifest;SHA256=$hash})
}
if($records.Count -eq 0 -or $records.Count -gt 512){throw 'Library catalog must contain 1..512 source modules'}
$catalog=@('UBE-Project 1','Name = "UBECore"','Kind = "Library"')
$ledger=@()
foreach($record in $records){$catalog+='Source = "'+$record.RelativePath+'"';$ledger+=$record.SHA256+'  '+$record.RelativePath}

# Each write is exclusive and the completed manifest is published last.
function Write-NewFile([string]$Relative,[byte[]]$Bytes){
 $path=[IO.Path]::GetFullPath((Join-Path $targetRoot $Relative))
 if(-not $path.StartsWith($targetRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Library package path escaped destination'}
 $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
 $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write($Bytes,0,$Bytes.Length)}finally{$stream.Dispose()}
}
foreach($record in $records){
 Write-NewFile $record.RelativePath $record.Bytes
 if((Get-FileHash -LiteralPath $record.OriginalPath -Algorithm SHA256).Hash -cne $record.SHA256){throw "Library source changed during packaging: $($record.OriginalPath)"}
}
foreach($record in $manifestRecords){
 if((Get-FileHash -LiteralPath $record.OriginalPath -Algorithm SHA256).Hash -cne $record.SHA256){throw "Library manifest changed during packaging: $($record.OriginalPath)"}
}
Write-NewFile 'sources.sha256' ($encoding.GetBytes(($ledger -join "`r`n")+"`r`n"))
Write-NewFile 'UBECore.UBE' ($encoding.GetBytes(($catalog -join "`r`n")+"`r`n"))
[pscustomobject]@{Manifest=(Join-Path $targetRoot 'UBECore.UBE');Target=$Target;SourceCount=$records.Count;Sources=$records.ToArray();Manifests=$manifestRecords.ToArray()}
