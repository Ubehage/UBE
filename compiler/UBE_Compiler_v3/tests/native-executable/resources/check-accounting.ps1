param([string]$SelectionPath='')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))) {$root=Split-Path $root -Parent;if(-not $root){throw 'Repository root missing'}}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
$selection=Get-VerifiedBootstrapSelection $SelectionPath
$run=Join-Path $root ('bootstrap/out/native-accounting/'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run)
$source=Join-Path $root 'compiler/UBE_Compiler_v3/src/NativeResources.bas'
$probe=Join-Path $PSScriptRoot 'accounting.c'
$inputs=@((Get-ArtifactIdentity $source),(Get-ArtifactIdentity $probe),(Get-ArtifactIdentity $PSCommandPath))
$text=[IO.File]::ReadAllText($source).Replace("`r`n","`n")
$prefix="UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"NativeResources`"`n"
if(-not $text.StartsWith($prefix,[StringComparison]::Ordinal)){throw 'Unexpected source envelope'}
$text=$text.Substring($prefix.Length)+"`nFunction Main() As Long`nMain = 0`nEnd Function`n"
$fixture=Join-Path $run 'Resources.bas';[IO.File]::WriteAllText($fixture,$text,[Text.UTF8Encoding]::new($false))
$names=@{};$ordinal=0
foreach($m in [regex]::Matches($text,'(?m)^(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)')) {$names[$m.Groups[1].Value]='ube.p'+$ordinal;++$ordinal}
$commands=@();$checks=@();$success=$false;$failure=$null;$prior=''
function Run([string]$File,[string[]]$Arguments) {
    $r=Invoke-BoundedProcess $File $Arguments $root 180
    $script:commands+=@($r)
    if($r.timedOut -or $r.exit -ne 0){throw ($r|ConvertTo-Json -Compress)}
    return $r
}
try {
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    for($i=0;$i -lt 2;++$i) {
        $raw=Join-Path $run ('stage'+$i+'.ll');$exe=Join-Path $run ('stage'+$i+'.exe')
        $null=Run $stages[$i] @($fixture,$raw)
        $identity=Get-ArtifactIdentity $raw
        if($prior -and $prior -cne $identity.sha256){throw 'Resource accounting LLVM differs across stages'};$prior=$identity.sha256
        $ir=[IO.File]::ReadAllText($raw)
        $allowed=@($names.ResetNativeFailure,$names.ValidNativeLimits,'ube_checked_add_i64','ube_checked_sub_i64')
        foreach($name in @('DefaultNativeLimits','ResetNativeFailure','ValidNativeLimits','TryChargeNativeResource','TryReleaseNativeResource','TryAdmitNativeCandidateLength')) {
            $body=[regex]::Matches($ir,'(?ms)^define [^\n]+ @'+[regex]::Escape($names[$name])+'\([^\n]*\) \{.*?^\}')
            if($body.Count -ne 1){throw 'Missing unique production resource body'}
            foreach($call in [regex]::Matches($body[0].Value,'(?m)^.*\b(?:call|invoke)\b.*$')) {
                $target=[regex]::Match($call.Value,'@([A-Za-z0-9_.]+)\(')
                if(-not $target.Success -or $target.Groups[1].Value -notin $allowed){throw 'Resource accounting acquired an unqualified managed or indirect call'}
            }
        }
        $ir=$ir.Replace('define i32 @main(','define i32 @native_unused_main(')
        $ir+="`ndefine void @native_defaults(ptr %limits) {`n call void @$($names.DefaultNativeLimits)(ptr %limits)`n ret void`n}`n"
        foreach($item in @(@('native_charge','TryChargeNativeResource','ptr %limits, ptr %usage, i32 %category, i64 %amount, ptr %failure'),@('native_release','TryReleaseNativeResource','ptr %usage, i32 %category, i64 %amount, ptr %failure'),@('native_candidate','TryAdmitNativeCandidateLength','ptr %limits, i64 %length, ptr %failure'))) {
            $ir+="define i32 @$($item[0])($($item[2])) {`n %ok = call i1 @$($names[$item[1]])($($item[2]))`n %result = zext i1 %ok to i32`n ret i32 %result`n}`n"
        }
        $adapted=Join-Path $run ('stage'+$i+'-native.ll');[IO.File]::WriteAllText($adapted,$ir,[Text.UTF8Encoding]::new($false))
        $null=Run $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-Wall','-Wextra','-Werror',$adapted,$probe,$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe)
        $r=Run $exe @()
        if($r.stderr -cne '' -or $r.stdout -notmatch '^PASS native resource accounting [1-9][0-9]* assertions\n$'){throw 'Accounting oracle did not complete'}
        $checks+=@([pscustomobject]@{stage=$i+1;passed=$true;assertion='Exact independent resource boundary results and scalar-only direct call inventory';raw=$identity;output=$r.stdout})
    }
    foreach($input in $inputs){if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256){throw 'Accounting proof input changed'}}
    $success=$true
} catch {$failure=$_.Exception.Message}
[pscustomobject]@{success=$success;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});scope='Scalar native resource admission/release only; not actual emitter measurements or complete resource acceptance'} | ConvertTo-Json -Depth 15 | Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output "Evidence: $run/report.json"
if(-not $success){throw $failure}
