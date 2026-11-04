param([Parameter(Mandatory=$true)][string]$Executable, [string]$SelectionPath='')
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))) {
    $parent=Split-Path $root -Parent
    if(-not $parent -or $parent -ceq $root) {throw 'Repository root missing'}
    $root=$parent
}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$exe=[IO.Path]::GetFullPath($Executable)
$run=Join-Path $root ('bootstrap/out/output-deferral/'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run)
$utf8=[Text.UTF8Encoding]::new($false,$true)
$flush='Intrinsic Function FlushOwned(ByVal Token As Long, ByRef Failure As Long) As Boolean'
$write='Intrinsic Function WriteOwned(ByVal Token As Long, ByRef Bytes() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Written As Long, ByRef Failure As Long) As Boolean'
$cases=@(
    @{id='flush';header=$flush;name='FlushOwned';role='File.TryFlush';code=1435;witness='"File.TryFlush"'},
    @{id='flush-case';header=$flush;name='FlushOwned';role='fIlE.tRyFlUsH';code=1435;witness='"fIlE.tRyFlUsH"'},
    @{id='write';header=$write;name='WriteOwned';role='File.TryWrite';code=1433;witness='Bytes()'},
    @{id='write-case';header=$write;name='WriteOwned';role='fIlE.tRyWrItE';code=1433;witness='Bytes()'},
    @{id='unknown';header=$flush;name='FlushOwned';role='File.WriteUnreviewed';code=1425;witness='"File.WriteUnreviewed"'},
    @{id='missing';header=$flush;name='FlushOwned';role='';code=1425;witness='FlushOwned'},
    @{id='ordinary-name';header='Function TryFlushByteFile() As Long';name='TryFlushByteFile';role='';code=0;witness=''}
)
$messages=@{1425='invalid primitive declaration or binding';1433='datatype semantics are not implemented';1435='primitive semantics are not implemented'}
$inputs=@((Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity $exe))
$checks=[Collections.Generic.List[object]]::new();$success=$false;$failure=$null
try {
    foreach($case in $cases) {
        $directory=Join-Path $run $case.id;$null=[IO.Directory]::CreateDirectory($directory)
        $source="UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"OutputBoundary`"`n"+$case.header+"`n"
        if($case.role) {$source+='Attribute '+$case.name+'.UBE_Primitive = "'+$case.role+'"'+"`n"}
        $source+="End Function`nSub Main()`nEnd Sub`n"
        $sourcePath=Join-Path $directory 'OutputBoundary.bas'
        [IO.File]::WriteAllText($sourcePath,$source,$utf8)
        $projectPath=Join-Path $directory 'OutputBoundary.UBE'
        [IO.File]::WriteAllText($projectPath,"UBE-Project 1`nName = `"OutputBoundary`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"OutputBoundary.bas`"`n",$utf8)
        $inputs+=@((Get-ArtifactIdentity $sourcePath),(Get-ArtifactIdentity $projectPath))
        $expected='';$expectedExit=0
        if($case.code) {
            $offset=$source.IndexOf($case.witness,[StringComparison]::Ordinal)
            if($offset -lt 0){throw 'Missing independent witness'}
            $before=$source.Substring(0,$offset)
            $line=($before.ToCharArray()|Where-Object {$_ -eq "`n"}|Measure-Object).Count+1
            $column=$offset-$before.LastIndexOf("`n",[StringComparison]::Ordinal)
            $byte=$utf8.GetByteCount($before)
            $expected="error UBE$($case.code): $($messages[$case.code]) (next lines: line, column, byte)`n$line`n$column`n$byte`n"
            $expectedExit=1
        }
        foreach($jobs in @(0,1,2,4)) {
            $arguments=@('--check',$sourcePath);$output=$expected
            if($jobs -gt 0) {
                $arguments=@('--check',$projectPath,'--jobs',[string]$jobs)
                if($case.code) {$output='"'+$sourcePath.Replace('\','/')+'"'+"`n"+$expected}
            }
            $record=Invoke-BoundedProcess $exe $arguments $root 60
            $passed=-not $record.timedOut -and $record.exit -eq $expectedExit -and $record.stdout -ceq $output -and $record.stderr -ceq ''
            $checks.Add([pscustomobject]@{case=$case.id;jobs=$jobs;expectedExit=$expectedExit;expected=$output;actual=$record;passed=$passed})
            if(-not $passed){throw "Output primitive diagnostic mismatch: $($case.id), jobs=$jobs"}
        }
        $files=@(Get-ChildItem -LiteralPath $directory -File -Recurse)
        if($files.Count -ne 2){throw 'Check command produced an unexpected artifact'}
    }
    if($checks.Count -ne 28){throw 'Incomplete output primitive cases'}
    foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw 'Diagnostic proof input changed'}}
    $success=$true
} catch {$failure=$_.Exception.Message}
$report=Join-Path $run 'report.json'
[pscustomobject]@{success=$success;failure=$failure;inputs=$inputs;checks=$checks.ToArray();scope='Known output role deferral, original spans, invalid/missing binding and ordinary-name controls; source and project jobs 1/2/4. No native output admission.'} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $report -Encoding UTF8
Write-Output "Evidence: $report"
if(-not $success){throw $failure}
Write-Output "PASS output primitive deferral: $($checks.Count) exact process checks"
