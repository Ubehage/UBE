param([string]$SelectionPath='', [string]$Stage1Run='', [string]$Stage2Run='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not (Test-Path -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -ceq $root){throw 'Cannot find repository root'};$root=$parent}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$run=Join-Path (Join-Path $root 'bootstrap/out/semantic-catalog') ('qualification/'+[Guid]::NewGuid().ToString('N'));$null=New-Item -ItemType Directory -Path $run -Force
$inputs=@();$commands=New-Object 'System.Collections.Generic.List[object]';$checks=New-Object 'System.Collections.Generic.List[object]';$evidence=New-Object 'System.Collections.Generic.List[object]';$bases=@();$success=$false;$failure=$null
function Assert-Fact([bool]$Condition,[string]$Meaning,$Detail=$null){if(-not $Condition){throw $Meaning};$checks.Add([pscustomobject]@{assertion=$Meaning;detail=$Detail;passed=$true})}
function Copy-Input([string]$Path,[string]$Relative){$identity=Get-ArtifactIdentity $Path;$target=Join-Path (Join-Path $run 'inputs') $Relative;$null=New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force;Copy-Item -LiteralPath $Path -Destination $target;return $identity}
function Invoke-Gate([string]$Script,[string[]]$Arguments,[int]$Seconds){$record=Invoke-BoundedProcess 'powershell.exe' (@('-NoProfile','-File',$Script)+$Arguments) $root $Seconds;$commands.Add($record);if($record.timedOut -or $record.exit -ne 0){throw ($record|ConvertTo-Json -Compress)};return $record}
function Run-Extra([string]$Base,[int]$Stage,[string]$Suite,[string]$Control=''){
 $arguments=@('-BaseRun',$Base,'-SourceName',$Suite);if($Control){$arguments+=@('-Control',$Control)}
 $record=Invoke-Gate (Join-Path $PSScriptRoot 'recheck.ps1') $arguments 420
 $match=[regex]::Match($record.stdout,'(?m)^Diagnostic recheck: (.+report\.json)\r?$');Assert-Fact $match.Success "Stage$Stage $Suite evidence path emitted"
 $path=$match.Groups[1].Value.Trim();$proof=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
 Assert-Fact (-not $proof.compile.timedOut -and $proof.compile.exit -eq 0 -and $proof.compile.stderr -ceq '') "Stage$Stage $Suite native bridge compiles with strict warnings"
 if($Control){Assert-Fact (-not $proof.actual.timedOut -and $proof.actual.exit -eq 1 -and $proof.actual.stderr.Contains('catalog assertion')) "Stage$Stage $Control actual native corruption is rejected"}
 else{
  Assert-Fact (-not $proof.actual.timedOut -and $proof.actual.exit -eq 0 -and $proof.actual.stderr -ceq '' -and $proof.actual.stdout -match '(?m)^PASS catalog .+\n$') "Stage$Stage $Suite exact native success/assertion completion"
  if($Suite -ceq 'cost'){$rows=@($proof.actual.stdout -split "`n"|Where-Object {$_.StartsWith('{')}|ForEach-Object {$_|ConvertFrom-Json});Assert-Fact ($rows.Count -eq 6 -and (($rows|ForEach-Object n)-join ',') -ceq '0,1,8,64,1024,16384' -and @($rows|Where-Object {-not $_.passed -or $_.sourceCopied -ne 0}).Count -eq 0) "Stage$Stage all preset cost sizes/zero source payload copies"}
  if($Suite -ceq 'roots'){$matched=$proof.actual.stdout -match 'rootNeed:([0-9]+) capacities:([0-9]+) realBacked:1';Assert-Fact ($matched -and [int]$Matches[1] -le 512 -and [int]$Matches[2] -eq [int]$Matches[1]+2) "Stage$Stage full real-backed root range0..exact-plus-one within fixed512 bound"}
 }
 $evidence.Add([pscustomobject]@{stage=$Stage;suite=$Suite;control=$Control;report=(Get-ArtifactIdentity $path);actual=$proof.actual;source=$proof.source;ir=$proof.ir;runtime=$proof.object})
}
try{
 $inputs+=Copy-Input $SelectionPath 'accepted-selection.json';$inputs+=Copy-Input $selection.manifest.path 'accepted-manifest.json'
 foreach($file in Get-ChildItem -LiteralPath $PSScriptRoot -File|Where-Object Extension -In @('.bas','.c','.h','.ps1','.md','.json')){$inputs+=Copy-Input $file.FullName ('catalog/'+$file.Name)}
 foreach($relative in @('bootstrap/tools/verification.ps1','compiler/UBE_Compiler_v3/tests/semantic/native/abi.ps1','compiler/UBE_Compiler_v3/tests/semantic/native/observer.ps1','compiler/UBE_Compiler_v3/tests/semantic/native/project.ps1','bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/thread_primitives.c','std-lib/tests/managed-storage/copy-probe.h','std-lib/tests/byte-storage/allocation-probe.h','std-lib/UBECore.UBE')){$inputs+=Copy-Input (Join-Path $root $relative) $relative}
 $stage1=Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe';$tools=@($stage1,$selection.compiler.path);$paths=@($Stage1Run,$Stage2Run)
 for($stage=1;$stage -le 2;++$stage){
  if(-not $paths[$stage-1]){$record=Invoke-Gate (Join-Path $PSScriptRoot 'check.ps1') @('-RequireAccepted','-SelectionPath',$SelectionPath,'-ToolPath',$tools[$stage-1]) 1200;$match=[regex]::Match($record.stdout,'(?m)^Evidence: (.+)/report\.json\r?$');if(-not $match.Success){throw 'Base catalog evidence path absent'};$paths[$stage-1]=$match.Groups[1].Value.Trim()}
  $path=Join-Path $paths[$stage-1] 'report.json';$base=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
  Assert-Fact $base.success "Stage$stage complete base catalog/failure/budget gate passed"
  Assert-Fact ($base.tool.sha256 -ceq (Get-ArtifactIdentity $tools[$stage-1]).sha256 -and $base.selection.compiler.sha256 -ceq $selection.compiler.sha256 -and $base.selection.manifest.sha256 -ceq $selection.manifest.sha256) "Stage$stage exact accepted cohort/tool basis"
  foreach($identity in $base.inputs){$actual=Get-ArtifactIdentity $identity.path;Assert-Fact ($actual.sha256 -ceq $identity.sha256 -and $actual.bytes -eq $identity.bytes) "Stage$stage exact base input unchanged" $identity.path}
  foreach($name in @('ByteKeys','SignedIntegers','Utf8Encoding','StorageCapacity')){$module=[IO.Path]::GetFullPath((Join-Path $root ('std-lib/src/portable/'+$name+'.bas')));Assert-Fact (@($base.sources|Where-Object {[string]::Equals($_,$module,[StringComparison]::OrdinalIgnoreCase)}).Count -eq 1) "Stage$stage $name consumed as exact real Core Reference input"}
  $bases+=@([pscustomobject]@{stage=$stage;report=(Get-ArtifactIdentity $path);raw=(Get-ArtifactIdentity (Join-Path $paths[$stage-1] 'catalog.ll'));tool=$base.tool;manifest=$base.manifest})
  foreach($suite in @('admission','options','cases','cost','ownership','primitive-faults','bindings','roots','cancellation')){Run-Extra $paths[$stage-1] $stage $suite}
  foreach($control in @('TYPE','EXTRA','METRIC','HEAP','SOURCE_COPY')){Run-Extra $paths[$stage-1] $stage 'cost' ('NEGATIVE_CATALOG_'+$control)}
 }
 Assert-Fact ($bases.Count -eq 2 -and $bases[0].raw.sha256 -ceq $bases[1].raw.sha256 -and $bases[0].raw.bytes -eq $bases[1].raw.bytes) 'Complete final actual-Core catalog raw LLVM is byte-identical across accepted stages'
 foreach($identity in $inputs){$actual=Get-ArtifactIdentity $identity.path;Assert-Fact ($actual.sha256 -ceq $identity.sha256 -and $actual.bytes -eq $identity.bytes) 'Final catalog gate input remains unchanged' $identity.path}
 $null=Get-VerifiedBootstrapSelection $SelectionPath;$success=$true
}catch{$failure=$_.Exception.Message}
finally{[pscustomobject]@{schema='ube-semantic-catalog-native-1';success=$success;qualifiedCatalog=$success;sourceBuildCurrent=$success;acceptedSelection=$selection;failure=$failure;inputs=$inputs;bases=$bases;checks=$checks.ToArray();evidence=$evidence.ToArray();commands=$commands.ToArray();artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Private declaration catalog component only. Actual qualified input/immutable ownership/native resources, both accepted tools. No whole checker/CLI/backend qualification. Internal published SyntaxReads metric is not claimed complete; actual native syntax read hooks qualify cost.'}|ConvertTo-Json -Depth 30|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8;Write-Output "Evidence: $run/report.json"}
if(-not $success){throw $failure};Write-Output "PASS: $($checks.Count) exact catalog component assertions; all native gates/stages qualified"
