param([string]$CandidateDirectory='',[string]$SelectionPath='',[int[]]$Stages=@(1,2),[switch]$ExpectRejection)

# Class admission uses original unit boundaries, regardless of manifest order.
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
$run=Join-Path $root ('bootstrap/out/reference-order/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
$entry=Join-Path $run 'Entry.bas';$owner=Join-Path $run 'ByteOwner.cls';$manifest=Join-Path $run 'Reordered.UBE'
[IO.File]::WriteAllText($entry,[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'reference-basics.bas')).TrimEnd([char[]]"`r`n"),$utf8)
[IO.File]::WriteAllText($owner,"`r`n' Original leading trivia stays inside the CLASS unit.`r`n"+[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'ByteOwner.cls')),$utf8)
[IO.File]::WriteAllText($manifest,"UBE-Project 1`nName = `"Reordered`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"Entry.bas`"`nSource = `"ByteOwner.cls`"`n",$utf8)
$cases=@();$success=$false
try {
    foreach($stage in $Stages) {
        $compiler=$compilerPaths[$stage-1]
        $ir=Join-Path $run ('stage'+$stage+'.ll');$exe=Join-Path $run ('stage'+$stage+'.exe')
        $emit=Invoke-BoundedProcess $compiler @($manifest,$ir) $root 30
        if($ExpectRejection) {
            if($emit.timedOut -or $emit.exit -ne 1 -or $emit.stdout -notmatch 'error UBE5029: type declaration cannot cross source-module boundaries' -or [IO.File]::Exists($ir)){throw ('Expected order regression: '+$emit.stdout+$emit.stderr)}
            $link=$null;$native=$null
        } else {
            if($emit.timedOut -or $emit.exit -ne 0){throw ('Reordered source: '+$emit.stdout+$emit.stderr)}
            $link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$ir,'-x','none',$runtimePath,$selection.unicodeRuntime.path,'-o',$exe) $root 30
            if($link.timedOut -or $link.exit -ne 0){throw ('Reordered link: '+$link.stderr)}
            $native=Invoke-BoundedProcess $exe @() $root 10
            if($native.timedOut -or $native.exit -ne 0 -or $native.stdout.Replace("`r",'') -cne "99`n23`n1`n41`n31`n7`n67`n3`n2`n53`n67`n4`n" -or $native.stderr -cne ''){throw ('Reordered result: '+($native | ConvertTo-Json -Compress))}
        }
        $cases+=[pscustomobject]@{stage=$stage;emit=$emit;link=$link;native=$native;compiler=(Get-ArtifactIdentity $compiler)}
    }
    if($null -ne $acceptedSelection){$null=Get-VerifiedBootstrapSelection $SelectionPath}
    $success=$true
}catch{$failure=$_.Exception.Message}
$checks=@()
if($success) {
    foreach($case in $cases){$checks+=[pscustomobject]@{passed=$true;assertion=('native controlled outcomes through source-built stage '+$case.stage)}}
}
$report=[pscustomobject]@{success=$success;acceptedSelection=$acceptedSelection;checks=$checks;reproducedOrderRejection=[bool]$ExpectRejection;qualifiedConcurrency=$false;inputs=@($entry,$owner,$manifest | ForEach-Object {Get-ArtifactIdentity $_});cases=$cases;failure=$(if($success){''}else{$failure})}
$path=Join-Path $run 'report.json';$report | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Output ('Evidence: '+$path)
if(-not $success){throw $failure}
Write-Output ('PASS source order; reproduced rejection='+[bool]$ExpectRejection)
