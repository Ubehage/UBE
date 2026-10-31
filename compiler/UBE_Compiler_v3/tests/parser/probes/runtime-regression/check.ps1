param(
    [string]$RuntimeSourcePath='',
    [string]$SelectionPath='',
    [string]$ErrorStateExpression='',
    [switch]$ExpectedOldFailure
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
if(-not $RuntimeSourcePath){$RuntimeSourcePath=Join-Path $root 'runtime/bootstrap_runtime.c'}
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$RuntimeSourcePath=[IO.Path]::GetFullPath($RuntimeSourcePath)
$runtimeDirectory=Split-Path $RuntimeSourcePath -Parent
$runtimeHeader=Join-Path $runtimeDirectory 'value_storage.h'
$fileAdapter=[IO.Path]::GetFullPath((Join-Path $runtimeDirectory '../std-lib/src/win-lib/file_primitives.c'))
$run=Join-Path $root ('bootstrap/out/runtime-regression/'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run|Out-Null
$paths=@($RuntimeSourcePath,$runtimeHeader,$fileAdapter,$SelectionPath,(Join-Path $root 'bootstrap/tools/verification.ps1'))+@(Get-ChildItem -LiteralPath $PSScriptRoot -File|ForEach-Object FullName)
$inputs=@($paths|ForEach-Object {Get-ArtifactIdentity $_})
$commands=@();$checks=@();$measurements=@();$success=$false;$failure=$null;$selection=$null
function Invoke-Recorded([string]$File,[string[]]$Arguments,[int]$Timeout=30) {
    $result=Invoke-BoundedProcess $File $Arguments $root $Timeout
    $script:commands+=$result
    return $result
}
try {
    $selection=Get-Content -LiteralPath $SelectionPath -Raw|ConvertFrom-Json
    foreach($identity in @($selection.clang,$selection.unicodeRuntime)){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw 'Selected native tool artifact differs'};$inputs+=$identity}
    $runtimeIdentity=Get-ArtifactIdentity $RuntimeSourcePath
    if($ExpectedOldFailure -and $runtimeIdentity.sha256 -cne '423B64E1944D2B021120D984D75532AE49DD1495D759E0ED105A98C88F817493'){throw 'Before-fix mode requires the exact retained accepted runtime source'}
    $sourceText=[IO.File]::ReadAllText($RuntimeSourcePath)
    if(-not $ErrorStateExpression -and $sourceText -match '\bube_current_error_state\b'){$ErrorStateExpression='ube_current_error_state()'}
    if(-not $ExpectedOldFailure) {
        $productionIr=Join-Path $run 'production-runtime.ll'
        $production=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-S','-emit-llvm',$RuntimeSourcePath,'-o',$productionIr)
        if($production.timedOut -or $production.exit -ne 0){throw "Production runtime native-TLS inspection failed: $($production.stderr)"}
        $productionText=[IO.File]::ReadAllText($productionIr)
        if($productionText -match '__emutls' -or $productionText -notmatch '(?m)^@[^\r\n]* = [^\r\n]*thread_local[^\r\n]*%struct\.ube_error_state'){throw 'Production error record is not native LLVM thread_local, or emutls allocation remains'}
        $checks+=[pscustomobject]@{assertion='production LLVM error record is native thread_local and has no emutls allocator';passed=$true}
    }
    $runtime=Join-Path $run 'observed-runtime.o'
    $arguments=@('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-c','-include',(Join-Path $PSScriptRoot 'allocation-probe.h'),(Join-Path $PSScriptRoot 'runtime-observed.c'),('-DUBE_REGRESSION_RUNTIME_SOURCE="'+$RuntimeSourcePath.Replace('\','/')+'"'),'-o',$runtime)
    if($ErrorStateExpression){$arguments+=('-DUBE_REGRESSION_ERROR_STATE='+$ErrorStateExpression)}
    $build=Invoke-Recorded $selection.clang.path $arguments
    if($build.timedOut -or $build.exit -ne 0){throw "Regression runtime compilation failed: $($build.stderr)"}
    $exe=Join-Path $run 'regression.exe'
    $link=Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror',(Join-Path $PSScriptRoot 'probe.c'),('-DUBE_REGRESSION_VALUE_HEADER="'+$runtimeHeader.Replace('\','/')+'"'),$runtime,$selection.unicodeRuntime.path,'-o',$exe)
    if($link.timedOut -or $link.exit -ne 0){throw "Regression native link failed: $($link.stderr)"}
    $expectations=@{
        'trace-first'="PASS trace-first: abort/no sweep/no finalizer/marks reset/roots retained/lock released/retry/cleanup`n"
        'trace-partial'="PASS trace-partial64: abort/no sweep/no finalizer/marks reset/roots retained/lock released/retry/cleanup`n"
        'retry-success'="PASS retry-success: failed automatic trace followed by successful allocation preserves Err77/data/roots/cleanup`n"
        'fresh-error'="PASS fresh-error: all allocators denied/Err7 text and revision retained/recovery Err42/clear/thread isolation/cleanup`n"
    }
    foreach($mode in @('trace-first','trace-partial','retry-success','fresh-error')) {
        $result=Invoke-Recorded $exe @($mode) 15
        if($ExpectedOldFailure) {
            $expectedDiagnostic="UBE managed support: insufficient bookkeeping memory while tracing`n"
            if($mode -eq 'fresh-error'){$expectedDiagnostic="UBE managed support: insufficient bookkeeping memory while recording an error`n"}
            if($result.timedOut -or $result.exit -ne 70 -or $result.stdout -cne '' -or $result.stderr -cne $expectedDiagnostic){throw "Old runtime did not reproduce expected process termination: $mode"}
            $checks+=[pscustomobject]@{mode=$mode;assertion='exact old-runtime exit70 independently reproduced; regression remains failing on old body';passed=$true}
        } else {
            $outputMatches=$result.stdout -ceq $expectations[$mode]
            if($mode -eq 'fresh-error') {
                $outputMatches=$result.stdout -cmatch ('^'+[regex]::Escape($expectations[$mode])+'MEASURE first-error denied-malloc:(\d+) denied-calloc:(\d+) denied-realloc:(\d+)\n$')
                if($outputMatches){$measurements+=[pscustomobject]@{mode=$mode;failedMalloc=[long]$Matches[1];failedCalloc=[long]$Matches[2];failedRealloc=[long]$Matches[3]}}
            }
            if($result.timedOut -or $result.exit -ne 0 -or -not $outputMatches -or $result.stderr -cne ''){throw "Recoverable runtime regression failed: $mode`: $($result|ConvertTo-Json -Depth 4 -Compress)"}
            $checks+=[pscustomobject]@{mode=$mode;assertion=$expectations[$mode].Trim();passed=$true}
        }
    }
    foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw "Regression input changed: $($identity.path)"}}
    $success=$true
} catch {$failure=$_.Exception.Message}
finally {
    [pscustomobject]@{schema='ube-runtime-recoverable-oom-regression-1';success=$success;beforeFixReproduction=[bool]$ExpectedOldFailure;regressionPassed=($success -and -not $ExpectedOldFailure);failure=$failure;runtimeSource=$RuntimeSourcePath;errorStateExpression=$ErrorStateExpression;acceptedToolSelection=$selection;inputs=$inputs;checks=$checks;measurements=$measurements;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Native runtime regression only. Old source body is retained byte-for-byte; test macros intercept every runtime allocation class. No compiler/parser/production qualification is inferred.'}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if(-not $success){throw $failure}
if($ExpectedOldFailure){Write-Output 'PASS: four exact old-runtime exit70 regressions reproduced; fixed-runtime acceptance pending.'}
else{Write-Output 'PASS: four recoverable allocation/collection/error-state native regressions.'}
