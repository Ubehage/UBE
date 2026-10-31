# Maintained regression for silent omission of a CallNew statement. This can
# establish controlled unsupported behavior; -RequireNative requires real work.
param(
    [string]$SelectionPath=(Join-Path $PSScriptRoot '../../../../bootstrap/out/v2/current.json'),
    [string[]]$CompilerPaths=@(),
    [string]$RuntimePath='',
    [switch]$RequireNative
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
$acceptedSelection=$null
if(-not $CompilerPaths.Count){$selection=Get-VerifiedBootstrapSelection $SelectionPath;$acceptedSelection=$selection}
if($RuntimePath -eq ''){$RuntimePath=$selection.runtime.path}
if(-not $CompilerPaths.Count){$CompilerPaths=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)}
if($CompilerPaths.Count -ne 2){throw 'The regression requires both source-built compiler stages'}
$run=Join-Path $root ('bootstrap/out/thread-statement/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force|Out-Null
$fixture=Join-Path $PSScriptRoot 'callnew-statement.bas'
$control=Join-Path $run 'ordinary-call.bas'
$body=[IO.File]::ReadAllText($fixture)
if([regex]::Matches($body,'(?m)^    CallNew RunWorker\(7\)\r?$').Count -ne 1){throw 'Maintained worker fixture changed unexpectedly'}
[IO.File]::WriteAllText($control,[regex]::Replace($body,'(?m)^    CallNew RunWorker\(7\)','    Call RunWorker(7)'),[Text.UTF8Encoding]::new($false))
$inputs=@($fixture,$control,$PSCommandPath,$RuntimePath,$selection.unicodeRuntime.path,$selection.clang.path)+$CompilerPaths|ForEach-Object {Get-ArtifactIdentity $_}
$commands=@();$cases=@();$success=$false;$failure=$null;$nativeStages=0
try {
    for($stage=0;$stage -lt 2;++$stage) {
        foreach($kind in @('control','thread')) {
            $source=$fixture;if($kind -ceq 'control'){$source=$control}
            $ir=Join-Path $run ($kind+'-stage'+($stage+1)+'.ll')
            $emit=Invoke-BoundedProcess $CompilerPaths[$stage] @($source,$ir) $root 30;$commands+=$emit
            if($emit.timedOut){throw 'Focused statement compilation timed out'}
            if($emit.exit -ne 0) {
                if($kind -cne 'thread' -or $RequireNative -or $emit.exit -ne 1 -or $emit.stdout -notmatch '\(12,5\): error UBE2240: CallNew is not supported by the qualified bootstrap subset' -or $emit.stderr -cne '' -or [IO.File]::Exists($ir)){throw ('Unexpected unsupported/error result: '+$emit.stdout+$emit.stderr)}
                $cases+=[pscustomobject]@{stage=$stage+1;kind=$kind;disposition='controlled unsupported';passed=$true;emit=$emit}
                continue
            }
            $llvm=[IO.File]::ReadAllText($ir)
            if($kind -ceq 'thread' -and $llvm -notmatch 'call i64 @ube_thread_start(?:_checked)?\('){throw 'CallNew compiled successfully but emitted no actual thread start'}
            $exe=[IO.Path]::ChangeExtension($ir,'.exe')
            $link=Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$ir,'-x','none',$RuntimePath,$selection.unicodeRuntime.path,'-o',$exe) $root 30;$commands+=$link
            if($link.timedOut -or $link.exit -ne 0){throw ('Focused native link failed: '+$link.stderr)}
            $native=Invoke-BoundedProcess $exe @() $root 10;$commands+=$native
            if($native.timedOut -or $native.exit -ne 0 -or $native.stdout -cne "7`n" -or $native.stderr -cne ''){throw 'Actual worker/control did not print the independent expected result exactly once'}
            if($kind -ceq 'thread'){++$nativeStages}
            $cases+=[pscustomobject]@{stage=$stage+1;kind=$kind;disposition='native result';passed=$true;emit=$emit;native=$native;llvm=(Get-ArtifactIdentity $ir)}
        }
    }
    foreach($input in $inputs){$now=Get-ArtifactIdentity $input.path;if($now.sha256 -cne $input.sha256 -or $now.bytes -ne $input.bytes){throw ('Focused regression input changed: '+$input.path)}}
    if($null -ne $acceptedSelection){$null=Get-VerifiedBootstrapSelection $SelectionPath}
    $success=$true
}catch{$failure=$_.Exception.Message}finally{
    $checks=@();if($success){$checks=@($cases | ForEach-Object {[pscustomobject]@{passed=$true;assertion=('statement/control '+$_.kind+' through stage '+$_.stage)}})}
    $report=[pscustomobject]@{schema='ube-thread-statement-regression-1';success=$success;failure=$failure;acceptedSelection=$acceptedSelection;checks=$checks;qualifiedConcurrency=$false;qualifiedNativeStatement=($success -and $nativeStages -eq 2);requireNative=[bool]$RequireNative;inputs=@($inputs);cases=$cases;commands=$commands;limits='Focused statement/control regression only. Two unsupported diagnostics are a safety pass, not native threading. Even native statement success does not establish shared inputs, scheduler, failures, cancellation or 1/2/4-worker compiler proof.'}
    $path=Join-Path $run 'report.json';$report|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $path -Encoding UTF8
    Write-Output ('Evidence: '+$path)
}
if(-not $success){throw $failure}
Write-Output ('PASS: '+$cases.Count+' focused statement/control checks; native statement qualified='+$report.qualifiedNativeStatement)
