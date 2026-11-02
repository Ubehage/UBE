param(
    [string]$SelectionPath='',
    [switch]$DiagnosticOnly,
    [string]$BuildReport
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=$PSScriptRoot
while(-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))){$parent=Split-Path $root -Parent;if(-not $parent -or $parent -eq $root){throw 'Repository root not found'};$root=$parent}
if(-not $SelectionPath){$SelectionPath=Join-Path $root 'bootstrap/out/v2/current.json'}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
. (Join-Path $root 'compiler/UBE_Compiler_v3/tests/project-input/cli-regressions.ps1')
$run=Join-Path $root ('bootstrap/out/project-cli/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory $run -Force
$utf8=[Text.UTF8Encoding]::new($false)
$inputs=@();$artifacts=@();$commands=@();$checks=@();$success=$false;$failure=$null;$selection=$null
$production=Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'
$definitions=Join-Path $root 'compiler/UBE_Compiler_v3/tests/project-input/cli.json'
if([IO.File]::Exists((Join-Path $PSScriptRoot 'cli.json'))){$definitions=Join-Path $PSScriptRoot 'cli.json'}
function Get-CliInputs([string]$Manifest){
    $Manifest
    foreach($line in [IO.File]::ReadAllLines($Manifest)){
        if($line -match '^Source = "([^"]+)"$'){[IO.Path]::GetFullPath((Join-Path (Split-Path $Manifest -Parent) $Matches[1]))}
    }
    foreach($line in [IO.File]::ReadAllLines($Manifest)){
        if($line -match '^Reference = "([^"]+)"$'){Get-CliInputs ([IO.Path]::GetFullPath((Join-Path (Split-Path $Manifest -Parent) $Matches[1])))}
    }
}
function Run-CliBuild([string]$Program,[string[]]$Values,[int]$Timeout=900){
    $record=Invoke-BoundedProcess $Program $Values $root $Timeout;$script:commands+=$record
    if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne ''){throw ($record | ConvertTo-Json -Depth 5)}
    return $record
}
function Quote-CliPath([string]$Value){
    $builder=[Text.StringBuilder]::new();$null=$builder.Append('"')
    foreach($character in $Value.ToCharArray()){
        $code=[int]$character
        if($code -eq 34 -or $code -eq 92){$null=$builder.Append('\').Append($character)}
        elseif($code -lt 32 -or $code -eq 127){$null=$builder.Append('\x').Append($code.ToString('X2'))}
        else{$null=$builder.Append($character)}
    }
    $null=$builder.Append('"');return $builder.ToString()
}
function Write-CliFixture([string]$Path,[string]$Text){
    $null=New-Item -ItemType Directory (Split-Path $Path -Parent) -Force
    [IO.File]::WriteAllText($Path,$Text,$utf8)
}
function Cli-Snapshot{
    return @(Get-ChildItem $run -Recurse -File | Sort-Object FullName | ForEach-Object {Get-ArtifactIdentity $_.FullName})
}
try{
    if($BuildReport -and -not $DiagnosticOnly){throw 'Build reuse is diagnostic only'}
    if($DiagnosticOnly){$selection=Get-Content $SelectionPath -Raw | ConvertFrom-Json}else{$selection=Get-VerifiedBootstrapSelection $SelectionPath}
    foreach($property in $selection.PSObject.Properties){if($property.Name -ne 'schema'){
        if((Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256){throw 'Selected artifact changed'};$inputs+=$property.Value
    }}
    $accepted=Get-Content $selection.manifest.path -Raw | ConvertFrom-Json
    if(-not $accepted.success){throw 'Selected compiler was not accepted'}
    $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    foreach($stage in $stages){$record=@($accepted.artifacts | Where-Object path -CEQ $stage);if($record.Count -ne 1 -or (Get-ArtifactIdentity $stage).sha256 -cne $record[0].sha256){throw 'Stage identity differs'};$inputs+=$record[0]}
    $sourcePaths=@(Get-CliInputs $production)
    $inputs+=@($sourcePaths | ForEach-Object {Get-ArtifactIdentity $_})
    foreach($relative in @('bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c','bootstrap/runtime/windows/thread_primitives.c','compiler/UBE_Compiler_v3/PROJECT-DIAGNOSTICS.md','compiler/UBE_Compiler_v3/PROJECT-CLI-IMPLEMENTATION.md')){$inputs+=Get-ArtifactIdentity (Join-Path $root $relative)}
    $inputs+=@((Get-ArtifactIdentity $definitions),(Get-ArtifactIdentity $PSCommandPath),(Get-ArtifactIdentity (Join-Path $root 'bootstrap/tools/verification.ps1')))
    $reuse=$null
    if($BuildReport){
        $reuse=Get-Content $BuildReport -Raw | ConvertFrom-Json
        if(-not $reuse.success){throw 'Reused CLI build did not complete its own gate'}
        $inputs+=Get-ArtifactIdentity $BuildReport
        foreach($path in $sourcePaths){
            $record=@($reuse.inputs | Where-Object path -CEQ $path)
            if($record.Count -lt 1 -or @($record | Where-Object sha256 -CNE (Get-ArtifactIdentity $path).sha256).Count -ne 0){throw ('Reused source differs: '+$path)}
        }
        foreach($stage in $stages){$record=@($reuse.inputs | Where-Object path -CEQ $stage);if($record.Count -lt 1 -or @($record | Where-Object sha256 -CNE (Get-ArtifactIdentity $stage).sha256).Count -ne 0){throw 'Reused compiler differs'}}
    }
    $definition=Get-Content $definitions -Raw -Encoding UTF8 | ConvertFrom-Json
    if($definition.schema -cne 'ube-project-cli-cases-1'){throw 'Wrong case schema'}
    $cases=@()
    foreach($case in $definition.cases){
        $folder=Join-Path $run ('fixtures/'+$case.name)
        $manifest=Join-Path $folder 'App.UBE';$sourcePath=Join-Path $folder 'Main.bas'
        $projectText=[string]$definition.project;$sourceText=[string]$definition.source
        if($case.PSObject.Properties['replace']){$projectText=$projectText.Replace($case.replace[0],$case.replace[1])}
        if($case.PSObject.Properties['append']){$projectText+=$case.append}
        if($case.PSObject.Properties['manifestByteCount']){$projectText='x'*[int]$case.manifestByteCount}
        if($case.PSObject.Properties['sourceSuffix']){$sourceText+=$case.sourceSuffix}
        if($case.PSObject.Properties['sourceReplace']){$sourceText=$sourceText.Replace($case.sourceReplace[0],$case.sourceReplace[1])}
        if($case.PSObject.Properties['sourceExtension']){
            $sourcePath=Join-Path $folder ('Main'+$case.sourceExtension)
            $projectText=$projectText.Replace('Main.bas',('Main'+$case.sourceExtension))
        }
        if($case.PSObject.Properties['crlf']){$projectText=$projectText.Replace("`n","`r`n")}
        if($case.PSObject.Properties['bom']){$projectText=[char]65279+$projectText}
        Write-CliFixture $manifest $projectText;Write-CliFixture $sourcePath $sourceText
        if($case.PSObject.Properties['bytes']){[IO.File]::WriteAllBytes($manifest,[byte[]]$case.bytes)}
        if($case.PSObject.Properties['files']){
            foreach($file in $case.files){
                $contents=''
                if($file.PSObject.Properties['text']){$contents=[string]$file.text}else{
                    $contents=[string]$definition.source
                    if($file.PSObject.Properties['sourceName']){$contents=$contents.Replace('"Main"',('"'+$file.sourceName+'"'))}
                }
                Write-CliFixture (Join-Path $folder $file.path) $contents
            }
        }
        $upper=Join-Path $folder 'Upper.UBE';Write-CliFixture $upper $projectText
        $unicodeFolder=Join-Path $folder ('unicode-'+[char]0x00C5+[char]0x03A9+[char]::ConvertFromUtf32(0x1F642))
        $unicode=Join-Path $unicodeFolder 'App.UBE';Write-CliFixture $unicode $projectText
        Write-CliFixture (Join-Path $unicodeFolder 'Main.bas') $sourceText
        $values=@();$expected='';$exit=1
        if($case.PSObject.Properties['args']){
            foreach($value in $case.args){$values+=([string]$value).Replace('{project}',$manifest).Replace('{source}',$sourcePath).Replace('{upper}',$upper).Replace('{unicode}',$unicode)}
            $expected=[string]$definition.($case.output);$exit=[int]$case.exit
            if($case.output -in @('semantic','semanticCore')){
                $semanticPath=$sourcePath
                if($case.name -ceq 'unicode-path'){$semanticPath=Join-Path $unicodeFolder 'Main.bas'}
                if($case.output -ceq 'semanticCore'){$semanticPath=Join-Path $root 'std-lib/src/portable/Utf8.bas'}
                $expected=(Quote-CliPath $semanticPath.Replace('\','/'))+"`n"+$expected
            }
        }else{
            $values=@('--check',$manifest)
            if($case.PSObject.Properties['code']){
                $errorPath=$manifest
                if($case.PSObject.Properties['errorPath']){$errorPath=Join-Path $folder $case.errorPath}
                $expected='error UBE'+$case.code+': '+$case.message+" (next lines: path, line, column, byte)`n"+(Quote-CliPath $errorPath.Replace('\','/'))+"`n"+$case.line+"`n"+$case.column+"`n"+$case.byte+"`n"
            }else{
                $errorPath=$sourcePath
                if($case.PSObject.Properties['inputLine']){$errorPath=$manifest}
                $expected=(Quote-CliPath $errorPath.Replace('\','/'))+"`n"
                if($case.PSObject.Properties['inputLine']){$expected+=$case.inputLine}
                elseif($case.PSObject.Properties['sourceLine']){$expected+=$case.sourceLine}
                else{$expected+=$case.sourceHeader+"`n"+$case.line+"`n"+$case.column+"`n"+$case.byte+"`n"}
            }
        }
        $cases+=[pscustomobject]@{name=$case.name;arguments=$values;exit=$exit;stdout=$expected}
    }
    $inputs+=@(Get-ChildItem (Join-Path $run 'fixtures') -Recurse -File | ForEach-Object {Get-ArtifactIdentity $_.FullName})
    # Diagnostic runs still use current production runtime source, including its
    # recoverable legacy String storage; no production body is rewritten.
    $runtime=Join-Path $run 'runtime.o'
    $null=Run-CliBuild $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-c',(Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c'),'-o',$runtime)
    $prior=$null
    for($index=0;$index -lt 2;++$index){
        $stem=Join-Path $run ('stage'+($index+1))
        if($reuse){
            $record=@($reuse.artifacts | Where-Object {[IO.Path]::GetFileName($_.path) -ceq ('stage'+($index+1)+'.ll')})
            if($record.Count -ne 1 -or (Get-ArtifactIdentity $record[0].path).sha256 -cne $record[0].sha256){throw 'Reused raw LLVM differs'}
            Copy-Item $record[0].path ($stem+'.ll')
        }else{$null=Run-CliBuild $stages[$index] @($production,($stem+'.ll'))}
        $identity=Get-ArtifactIdentity ($stem+'.ll');$artifacts+=$identity
        if($prior -and $prior -cne $identity.sha256){throw 'Unequal raw production LLVM'};$prior=$identity.sha256
        $null=Run-CliBuild $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',($stem+'.ll'),$runtime,$selection.unicodeRuntime.path,'-o',($stem+'.exe'))
        $artifacts+=Get-ArtifactIdentity ($stem+'.exe')
        foreach($case in $cases){
            $before=Cli-Snapshot
            $actual=Invoke-BoundedProcess ($stem+'.exe') $case.arguments $run 60
            $commands+=$actual
            if($actual.timedOut -or $actual.exit -ne $case.exit -or $actual.stdout -cne $case.stdout -or $actual.stderr -cne ''){throw ('CLI case '+$case.name+' expected '+$case.stdout+' actual '+($actual | ConvertTo-Json -Depth 5))}
            $after=Cli-Snapshot
            if(($before | ConvertTo-Json -Depth 5 -Compress) -cne ($after | ConvertTo-Json -Depth 5 -Compress)){throw 'CLI modified or created a file'}
            $checks+=[pscustomobject]@{assertion="stage $($index+1): exact CLI $($case.name), exit/stdout/stderr and no changed artifact";passed=$true}
        }
        $regression=Invoke-ProjectCliRegressions -RawPath ($stem+'.ll') -SourcePaths @($sourcePaths | Where-Object {[IO.Path]::GetExtension($_) -in @('.bas','.cls')}) -Selection $selection -Destination (Join-Path $run ('regression-stage'+($index+1))) -Repository $root -ManifestPath (Join-Path $run 'fixtures/default/App.UBE')
        $inputs+=@($regression.inputs)
        $commands+=@($regression.commands)
        $checks+=@($regression.checks)
    }
    foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw 'Pinned input changed'}}
    $success=$true
}catch{$failure=$_.Exception.Message}finally{
    $report=Join-Path $run 'report.json'
    [pscustomobject]@{schema='ube-project-cli-evidence-1';success=$success;qualified=($success -and -not $DiagnosticOnly);diagnosticOnly=[bool]$DiagnosticOnly;acceptedSelection=$selection;buildReport=$BuildReport;inputs=$inputs;commands=$commands;checks=$checks;artifacts=@(Get-ChildItem $run -Recurse -File | ForEach-Object {Get-ArtifactIdentity $_.FullName});failure=$failure;remaining='Complete synthetic diagnostic/allocator/root/close process controls, broader intake cases, refreshed retained/source gates and parallel performance acceptance.'} | ConvertTo-Json -Depth 12 | Set-Content $report -Encoding UTF8
    Write-Output ('Evidence: '+$report)
}
if(-not $success){throw $failure}
Write-Output ($checks.Count.ToString()+' project CLI assertions passed.')
