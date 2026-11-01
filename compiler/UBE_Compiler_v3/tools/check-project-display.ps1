param([string]$SelectionPath=(Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'),[switch]$DiagnosticOnly)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/project-display-proof/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory $run -Force
$utf8=[Text.UTF8Encoding]::new($false)
$source=Join-Path $root 'compiler/UBE_Compiler_v3/src/ProjectDisplay.bas'
$entry=Join-Path $root 'compiler/UBE_Compiler_v3/tests/project-input/display-entry.bas'
$native=Join-Path $root 'compiler/UBE_Compiler_v3/tests/project-input/display.c'
$inputs=@();$commands=@();$checks=@();$success=$false;$failure=$null;$selection=$null
function Run-DisplayProcess([string]$Program,[string[]]$Values){
    $record=Invoke-BoundedProcess $Program $Values $root 180;$script:commands+=$record
    if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne ''){throw ($record | ConvertTo-Json -Depth 6)}
    return $record
}
try{
    if($DiagnosticOnly){$selection=Get-Content $SelectionPath -Raw | ConvertFrom-Json}else{$selection=Get-VerifiedBootstrapSelection $SelectionPath}
    foreach($property in $selection.PSObject.Properties){if($property.Name -ne 'schema'){
        if((Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256){throw 'Selected tool changed'};$inputs+=$property.Value
    }}
    $accepted=Get-Content $selection.manifest.path -Raw | ConvertFrom-Json
    if(-not $accepted.success){throw 'Selected build was not accepted'}
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    foreach($stage in $stages){$record=@($accepted.artifacts | Where-Object path -CEQ $stage);if($record.Count -ne 1 -or (Get-ArtifactIdentity $stage).sha256 -cne $record[0].sha256){throw 'Stage identity differs'};$inputs+=$record[0]}
    foreach($path in @($source,$entry,$native,$PSCommandPath,(Join-Path $root 'bootstrap/tools/verification.ps1'),(Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c'),(Join-Path $root 'bootstrap/runtime/value_storage.h'),(Join-Path $root 'bootstrap/runtime/windows/file_primitives.c'),(Join-Path $root 'bootstrap/runtime/windows/thread_primitives.c'))){$inputs+=Get-ArtifactIdentity $path}
    $before=Join-Path $root 'compiler/UBE_Compiler_v3/tests/project-input/display-before-oom.json'
    if((Get-ArtifactIdentity $before).sha256 -cne 'F9D63757317E17293E30FE648685EDE08F367C5C03F8D8F4CEACC4E2FA1DAE79'){throw 'Before-fix crash capture changed'}
    $capture=Get-Content $before -Raw | ConvertFrom-Json
    if($capture.success -or $capture.commands[-1].exit -ne 70 -or $capture.commands[-1].stderr -cne "UBE runtime: out of memory while allocating a string`n"){throw 'Missing actual crash reproduction'}
    $inputs+=@((Get-ArtifactIdentity $before),(Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/PROJECT-DISPLAY-CONTRACT.md')),(Get-ArtifactIdentity (Join-Path $root 'compiler/UBE_Compiler_v3/PROJECT-DIAGNOSTICS.md')))
    Copy-Item $source (Join-Path $run 'ProjectDisplay.bas');Copy-Item $entry (Join-Path $run 'Entry.bas')
    $manifest=Join-Path $run 'DisplayProof.UBE'
    [IO.File]::WriteAllText($manifest,"UBE-Project 1`nName = ""DisplayProof""`nKind = ""Exe""`nStartup = ""Main""`nSource = ""ProjectDisplay.bas""`nSource = ""Entry.bas""`n",$utf8)
    $procedure=0;$symbol=$null
    foreach($path in @($source,$entry)){foreach($match in [regex]::Matches([IO.File]::ReadAllText($path),'(?m)^(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){if($match.Groups[1].Value -ceq 'TryFormatProjectPath'){$symbol='ube.p'+$procedure};$procedure++}}
    $prior=$null
    for($index=0;$index -lt 2;++$index){
        $stem=Join-Path $run ('stage'+$index)
        $null=Run-DisplayProcess $stages[$index] @($manifest,($stem+'.ll'))
        $raw=[IO.File]::ReadAllText($stem+'.ll');$identity=Get-ArtifactIdentity ($stem+'.ll');$inputs+=$identity
        if($prior -and $prior -cne $identity.sha256){throw 'Unequal stage LLVM'};$prior=$identity.sha256
        if([regex]::Matches($raw,'(?m)^define i1 @'+[regex]::Escape($symbol)+'\(ptr [^,]+, ptr [^)]+\) \{').Count -ne 1){throw 'Actual display ABI differs'}
        $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @display_unused_main(')+"`ndefine i32 @display_format(ptr %bytes, ptr %result) {`n %ok = call i1 @"+$symbol+"(ptr %bytes, ptr %result)`n %value = zext i1 %ok to i32`n ret i32 %value`n}`n"
        [IO.File]::WriteAllText($stem+'-adapted.ll',$adapted,$utf8)
        $null=Run-DisplayProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',(Join-Path $root 'bootstrap/runtime'),($stem+'-adapted.ll'),$native,$selection.unicodeRuntime.path,'-o',($stem+'.exe'))
        $result=Run-DisplayProcess ($stem+'.exe') @()
        if($result.stdout -notmatch '^PASS project display allocation-positions:[1-9][0-9]* assertions:[0-9]+\r?\n$'){throw 'Unexpected display result'}
        $checks+=[pscustomobject]@{assertion="stage $($index+1): exact escaped metadata, limits, every allocator position/retry, full root capacity, old output/input retention and cleanup";output=$result.stdout;passed=$true}
        $negative=Invoke-BoundedProcess ($stem+'.exe') @('--disconnect-observer') $root 180
        $commands+=$negative
        if($negative.timedOut -or $negative.exit -ne 1 -or $negative.stdout -cne '' -or $negative.stderr -notmatch 'positions>0'){throw 'Disconnected display observer was not rejected'}
        $checks+=[pscustomobject]@{assertion="stage $($index+1): deliberately disconnected allocator observer is rejected";output=$negative.stderr;passed=$true}
    }
    foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw 'Pinned input changed'}}
    $success=$true
}catch{$failure=$_.Exception.Message}finally{
    $report=Join-Path $run 'report.json'
    [pscustomobject]@{schema='ube-project-display-proof-1';success=$success;qualified=($success -and -not $DiagnosticOnly);diagnosticOnly=[bool]$DiagnosticOnly;acceptedSelection=$selection;inputs=$inputs;commands=$commands;checks=$checks;artifacts=@(Get-ChildItem $run -File -Recurse | ForEach-Object {Get-ArtifactIdentity $_.FullName});failure=$failure;scope='Bounded bootstrap metadata display; no source conversion, full String lifecycle claim or CLI integration.'} | ConvertTo-Json -Depth 10 | Set-Content $report -Encoding UTF8
    Write-Output ('Evidence: '+$report)
}
if(-not $success){throw $failure}
Write-Output ($checks.Count.ToString()+' project display groups passed.')
