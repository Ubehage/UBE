param([Parameter(Mandatory=$true)][string]$SelectionPath)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/wide-integers/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$commands=New-Object 'System.Collections.Generic.List[object]'
$checks=New-Object 'System.Collections.Generic.List[object]'
$inputs=@();$selection=$null;$success=$false;$failure=$null;$nativeRows=@()
function Invoke-Checked([string]$File,[string[]]$Arguments){
    $record=Invoke-BoundedProcess $File $Arguments $root 60
    $commands.Add($record)
    if($record.timedOut -or $record.exit -ne 0){throw "Wide integer process failed: $($record|ConvertTo-Json -Compress)"}
    return $record
}
function Assert-Fact([bool]$Condition,[string]$Message){
    if(-not $Condition){throw $Message}
    $checks.Add([pscustomobject]@{assertion=$Message;passed=$true})
}
try{
    $selection=Get-VerifiedBootstrapSelection $SelectionPath
    $accepted=Get-Content -LiteralPath $selection.manifest.path -Raw|ConvertFrom-Json
    $inputs=@($accepted.inputs)+@((Get-ArtifactIdentity $SelectionPath))+@(Get-ChildItem -LiteralPath $PSScriptRoot -File|ForEach-Object {Get-ArtifactIdentity $_.FullName})
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    $utf8=New-Object Text.UTF8Encoding($false)
    $hashes=@();$nativeRows=@()
    $bindings=@(@('wide_add','i64','i64,i64'),@('wide_subtract','i64','i64,i64'),@('wide_multiply','i64','i64,i64'),@('wide_divide','i64','i64,i64'),@('wide_remainder','i64','i64,i64'),@('wide_negate','i64','i64'),@('wide_to_long','i32','i64'),@('wide_to_integer','i16','i64'),@('wide_to_byte','i8','i64'))
    for($stage=0;$stage -lt 2;++$stage){
        $stem=Join-Path $run ('stage'+($stage+1));$ir=$stem+'.ll';$adapted=$stem+'-adapted.ll'
        $null=Invoke-Checked $stages[$stage] @((Join-Path $PSScriptRoot 'Arithmetic.bas'),$ir)
        $hashes+=(Get-ArtifactIdentity $ir).sha256
        $raw=[IO.File]::ReadAllText($ir);$wrappers=New-Object Text.StringBuilder
        for($index=0;$index -lt $bindings.Count;++$index){
            $binding=$bindings[$index];$symbol='ube.p'+$index
            $definitions=[regex]::Matches($raw,'(?m)^define '+$binding[1]+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
            if($definitions.Count -ne 1){throw "Absent exact wide integer ABI $($binding[0])"}
            $actual=(@($definitions[0].Groups[1].Value -split ', '|ForEach-Object {($_ -split ' ')[0]}) -join ',')
            if($actual -cne $binding[2]){throw "Wide integer ABI mismatch $($binding[0])"}
            $types=$binding[2] -split ',';$arguments=@()
            for($argument=0;$argument -lt $types.Count;++$argument){$arguments+=$types[$argument]+' %a'+$argument}
            [void]$wrappers.AppendLine('define '+$binding[1]+' @'+$binding[0]+'('+($arguments -join ', ')+") {`n %result = call "+$binding[1]+' @'+$symbol+'('+($arguments -join ', ')+")`n ret "+$binding[1]+" %result`n}")
        }
        foreach($operation in @('add','sub','mul','div','mod','neg')){
            if($raw -notmatch ('call i64 @ube_checked_'+$operation+'_i64\(')){throw "Missing checked 64-bit $operation emission"}
        }
        if([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Unexpected wide integer proof Main'}
        $text=$raw.Replace('define i32 @main(','define i32 @wide_unused_main(')+"`n"+$wrappers.ToString()
        [IO.File]::WriteAllText($adapted,$text,$utf8)
        Assert-Fact $true "Stage$($stage+1) intact UBE function signatures and all six checked 64-bit emission paths"
        foreach($negative in @($false,$true)){
            $suffix='native';$defines=@();if($negative){$suffix='negative';$defines=@('-DNEGATIVE_WIDE_VALUE')}
            $exe=$stem+'-'+$suffix+'.exe'
            $null=Invoke-Checked $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$adapted,'-x','c',(Join-Path $PSScriptRoot 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror')+$defines+@('-x','none',$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe))
            $native=Invoke-BoundedProcess $exe @() $root 30;$commands.Add($native)
            if($negative){
                Assert-Fact (-not $native.timedOut -and $native.exit -eq 1 -and $native.stderr.Contains('wide integer assertion: case 0 value 0 expected 1')) "Stage$($stage+1) native comparator rejects an independently corrupted expected value"
            }else{
                $matched=$native.stdout -match '^PASS wide integer native assertions:([0-9]+) cases:([0-9]+)\n$'
                $count=0;$assertions=0;if($matched){$assertions=[int]$Matches[1];$count=[int]$Matches[2]}
                Assert-Fact (-not $native.timedOut -and $native.exit -eq 0 -and $native.stderr -ceq '' -and $matched -and $count -ge 75 -and $assertions -eq 2*$count) "Stage$($stage+1) actual native results and fresh/preserved Err for every boundary, arithmetic and narrowing case"
                $nativeRows+=@([pscustomobject]@{stage=$stage+1;cases=$count;assertions=$assertions})
            }
        }
    }
    Assert-Fact ($hashes.Count -eq 2 -and $hashes[0] -ceq $hashes[1]) 'Intact wide integer fixture raw LLVM is byte-identical through both source-built stages'
    foreach($identity in $inputs){$actual=Get-ArtifactIdentity $identity.path;if($actual.sha256 -cne $identity.sha256 -or $actual.bytes -ne $identity.bytes){throw "Wide integer input changed: $($identity.path)"}}
    Assert-Fact $true 'All actual wide integer fixture/tool/source inputs remain byte-identical after qualification'
    $success=$true
}catch{$failure=$_.Exception.Message}
finally{
    $path=Join-Path $run 'report.json'
    [pscustomobject]@{schema='ube-wide-integer-proof-1';success=$success;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks.ToArray();native=$nativeRows;commands=$commands.ToArray();artifacts=@(Get-ChildItem -LiteralPath $run -File|ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Checked signed 64-bit bootstrap machine arithmetic and existing narrowing only. Native inputs avoid unsupported wide literal spellings; no fresh compiler semantic checking, constant folding or executable backend qualification.'}|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $path -Encoding UTF8
    Write-Output "Evidence: $path"
}
if(-not $success){throw $failure}
Write-Output "PASS: $($checks.Count) wide integer qualification assertions."
