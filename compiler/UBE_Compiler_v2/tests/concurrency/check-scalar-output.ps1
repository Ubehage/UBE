param([string]$CandidateDirectory='',[string]$SelectionPath='',[int[]]$Stages=@(1,2),[switch]$ExpectInvalidIr)

# Thread identities must print through their real scalar ABI, not i32.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$acceptedSelection=$null
if($CandidateDirectory -eq '') {
    if($SelectionPath -eq ''){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
    $selection=Get-VerifiedBootstrapSelection $SelectionPath
    $acceptedSelection=$selection
    $compilerPaths=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    $runtimePath=$selection.runtime.path
} else {
    $selection=Get-Content -LiteralPath (Join-Path $root 'bootstrap/out/v2/current.json') -Raw | ConvertFrom-Json
    $compilerPaths=@((Join-Path $CandidateDirectory 'compiler-stage1.exe'),(Join-Path $CandidateDirectory 'compiler-stage2.exe'))
    $runtimePath=Join-Path $CandidateDirectory 'bootstrap_runtime.o'
}
$run=Join-Path $root ('bootstrap/out/scalar-output/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$source=Join-Path $PSScriptRoot 'scalar-output.bas'
$cases=@();$success=$false
try {
    foreach($stage in $Stages) {
        $compiler=$compilerPaths[$stage-1]
        $ir=Join-Path $run ('stage'+$stage+'.ll');$exe=Join-Path $run ('stage'+$stage+'.exe')
        $emit=Invoke-BoundedProcess $compiler @($source,$ir) $root 30
        if($emit.timedOut -or $emit.exit -ne 0){throw ('Scalar source: '+$emit.stdout+$emit.stderr)}
        $link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$ir,'-x','none',$runtimePath,$selection.unicodeRuntime.path,'-o',$exe) $root 30
        if($ExpectInvalidIr) {
            $llvm=[IO.File]::ReadAllText($ir)
            $wideLoad=[regex]::Match($llvm,'(?m)^  (?<id>%r[0-9]+) = load atomic i64,.*$')
            if(-not $wideLoad.Success -or -not $llvm.Contains('call void @ube_print_i32(i32 '+$wideLoad.Groups['id'].Value+')') -or -not $llvm.Contains('store double 0, ptr')){throw 'Before control did not reproduce both wrong scalar forms'}
            if($link.timedOut -or $link.exit -eq 0 -or $link.stderr -notmatch "defined with type 'i64' but expected 'i32'|integer/byte constant must have integer/byte type"){throw ('Expected invalid scalar IR: '+$link.stderr)}
            $native=$null
        } else {
            if($link.timedOut -or $link.exit -ne 0){throw ('Scalar link: '+$link.stderr)}
            $native=Invoke-BoundedProcess $exe @() $root 10
            if($native.timedOut -or $native.exit -ne 0 -or $native.stdout.Replace("`r",'') -cne "81`n0`n" -or $native.stderr -cne ''){throw ('Scalar native: '+($native | ConvertTo-Json -Compress))}
        }
        $cases+=[pscustomobject]@{stage=$stage;compiler=(Get-ArtifactIdentity $compiler);ir=(Get-ArtifactIdentity $ir);emit=$emit;link=$link;native=$native}
    }
    if($null -ne $acceptedSelection){$null=Get-VerifiedBootstrapSelection $SelectionPath}
    $success=$true
} catch {$failure=$_.Exception.Message}
$checks=@()
if($success) {
    foreach($case in $cases){$checks+=[pscustomobject]@{passed=$true;assertion=('native controlled outcomes through source-built stage '+$case.stage)}}
}
$report=[pscustomobject]@{success=$success;acceptedSelection=$acceptedSelection;checks=$checks;reproducedInvalidIr=[bool]$ExpectInvalidIr;qualifiedConcurrency=$false;source=(Get-ArtifactIdentity $source);cases=$cases;failure=$(if($success){''}else{$failure})}
$path=Join-Path $run 'report.json';$report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Output ('Evidence: '+$path)
if(-not $success){throw $failure}
Write-Output ('PASS scalar output; invalid-IR before control='+[bool]$ExpectInvalidIr)
