# Test-only ABI adapters. Actual production UBE bodies and runtime are preserved.
function Invoke-ProjectCliRegressions {
    param([string]$RawPath,[string[]]$SourcePaths,$Selection,[string]$Destination,
        [string]$Repository,[string]$ManifestPath)
    $ErrorActionPreference='Stop'
    $utf8=[Text.UTF8Encoding]::new($false)
    $null=New-Item -ItemType Directory -Path $Destination -Force
    $commands=[Collections.Generic.List[object]]::new()
    $checks=[Collections.Generic.List[object]]::new()
    $local=Join-Path $Repository 'compiler/UBE_Compiler_v3/tests/project-input'
    $oraclePath=Join-Path $local 'diagnostics.json'
    $oracle=Get-Content -LiteralPath $oraclePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if($oracle.schema -cne 'ube-project-diagnostic-oracles-1'){throw 'Unexpected diagnostic oracle schema'}
    $pins=@($SourcePaths)+@($RawPath,$ManifestPath,(Join-Path (Split-Path $ManifestPath -Parent) 'Main.bas'),
        (Join-Path $local 'cli-regression.c'),(Join-Path $local 'diagnostic-layout.h'),$oraclePath,
        (Join-Path $local 'cli-regressions.ps1'),(Join-Path $Repository 'bootstrap/runtime/bootstrap_runtime.c'),
        (Join-Path $Repository 'bootstrap/runtime/value_storage.h'),(Join-Path $Repository 'bootstrap/runtime/windows/file_primitives.c'),
        (Join-Path $Repository 'bootstrap/runtime/windows/thread_primitives.c'))
    $inputs=@($pins | Select-Object -Unique | ForEach-Object {Get-ArtifactIdentity $_})
    function Run-Regression([string]$Program,[string[]]$Values,[int]$Exit=0,[string]$Output='', [bool]$Compare=$true){
        $record=Invoke-BoundedProcess $Program $Values $Repository 120
        $commands.Add($record)
        if($record.timedOut -or $record.exit -ne $Exit -or $record.stderr -cne '' -or ($Compare -and $record.stdout -cne $Output)){
            throw ('CLI regression expected exit '+$Exit+' output '+$Output+'; actual '+($record | ConvertTo-Json -Depth 5))
        }
        return $record
    }
    function Quote-RegressionPath([string]$Path){
        $result='"'
        foreach($character in $Path.ToCharArray()){
            $number=[int]$character
            if($number -eq 34 -or $number -eq 92){$result+='\'+$character}
            elseif($number -lt 32 -or $number -eq 127){$result+='\x'+$number.ToString('X2')}
            else{$result+=$character}
        }
        return $result+'"'
    }
    $procedures=@{};$types=@{};$classes=@{};$procedureIndex=0;$typeIndex=0
    $sources=@($SourcePaths | Where-Object {[IO.Path]::GetExtension($_) -cne '.UBE'})
    foreach($source in $sources){
        $text=[IO.File]::ReadAllText($source)
        if($text -match '^UBE SOURCE 1 CLASS'){
            if($text -notmatch 'Attribute UBE_Name = "([^"]+)"'){throw 'Class has no identity'}
            $classes[$Matches[1]]=$typeIndex;$types[$Matches[1]]='%ube.type.'+$typeIndex;++$typeIndex
        }
        foreach($match in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')){
            $name=$match.Groups[1].Value
            if($procedures.ContainsKey($name)){throw ('Duplicate ABI procedure '+$name)}
            $procedures[$name]='ube.p'+$procedureIndex;++$procedureIndex
        }
    }
    foreach($source in $sources){foreach($match in [regex]::Matches([IO.File]::ReadAllText($source),'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')){
        $name=$match.Groups[1].Value;if($types.ContainsKey($name)){throw ('Duplicate ABI type '+$name)}
        $types[$name]='%ube.type.'+$typeIndex;++$typeIndex
    }}
    $raw=[IO.File]::ReadAllText($RawPath)
    $layouts=@{SourcePosition='i32, i32, i32, i32';SourceFailure=('i32, '+$types.SourcePosition);
        SyntaxFailure='i32, i32, i32';ProjectLimits=(('i32, '*11)+'i32');SourceCancellation='i1';
        ProjectFailure=('i32, i32, i32, i32, i32, i32, i32, '+$types.SourceFailure+', i32, '+$types.SyntaxFailure+', ptr')}
    foreach($name in $layouts.Keys){
        $line=$types[$name]+' = type { '+$layouts[$name]+' }'
        if([regex]::Matches($raw,'(?m)^'+[regex]::Escape($line)+'\r?$').Count -ne 1){throw ('Actual diagnostic layout differs: '+$name)}
    }
    $adapter=[Text.StringBuilder]::new()
    foreach($binding in @(@('regression_read','TryReadProjectInput','i1','ptr,ptr,ptr,ptr,ptr,ptr'),
        @('regression_print','TryPrintProjectFailure','i1','ptr,ptr'),
        @('regression_limits','DefaultProjectLimits','void','ptr'),@('regression_fallback','PrintProjectStorageFailure','void',''))){
        $symbol=$procedures[$binding[1]]
        $found=[regex]::Matches($raw,'(?m)^define '+$binding[2]+' @'+[regex]::Escape($symbol)+'\(([^\r\n]*)\) \{\r?$')
        if($found.Count -ne 1){throw ('Missing actual ABI '+$binding[1])}
        $actual=(@($found[0].Groups[1].Value -split ', ' | Where-Object {$_ -cne ''} | ForEach-Object {($_ -split ' ')[0]}) -join ',')
        if($actual -cne $binding[3]){throw ('Actual ABI differs: '+$binding[1]+' '+$actual)}
        $arguments=@();$parts=@($binding[3] -split ',' | Where-Object {$_ -cne ''})
        for($index=0;$index -lt $parts.Count;++$index){$arguments+=($parts[$index]+' %a'+$index)}
        $call=$arguments -join ', ';$return=$binding[2];if($return -ceq 'i1'){$return='i32'}
        $null=$adapter.AppendLine('define '+$return+' @'+$binding[0]+'('+$call+') {')
        if($return -ceq 'i32'){
            $null=$adapter.AppendLine(' %ok = call i1 @'+$symbol+'('+$call+')')
            $null=$adapter.AppendLine(' %value = zext i1 %ok to i32')
            $null=$adapter.AppendLine(' ret i32 %value')
        }else{$null=$adapter.AppendLine(' call void @'+$symbol+'('+$call+')');$null=$adapter.AppendLine(' ret void')}
        $null=$adapter.AppendLine('}')
    }
    $null=$adapter.AppendLine("define i64 @regression_failure_size() {`n ret i64 ptrtoint (ptr getelementptr ("+$types.ProjectFailure+", ptr null, i32 1) to i64)`n}")
    $null=$adapter.AppendLine("define ptr @regression_cancel_layout() {`n ret ptr @ube.object."+$classes.SourceCancellation+"`n}")
    if([regex]::Matches($raw,'(?m)^define i32 @main\(i32 %argc, ptr %argv\) \{\r?$').Count -ne 1){throw 'Actual platform entry differs'}
    $adapted=Join-Path $Destination 'production-adapted.ll'
    [IO.File]::WriteAllText($adapted,([regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @regression_main(')+"`n"+$adapter.ToString()),$utf8)
    $object=Join-Path $Destination 'production.o'
    $null=Run-Regression $Selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-c',$adapted,'-o',$object)
    $checks.Add([pscustomobject]@{assertion='actual production ABI and independent diagnostic field layouts';passed=$true})
    $source=Join-Path $local 'cli-regression.c'
    $common=@('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-I',(Join-Path $Repository 'bootstrap/runtime'),$object,$source,$Selection.unicodeRuntime.path)
    $fallback=[string]$oracle.fallback
    $manifest=Quote-RegressionPath $ManifestPath.Replace('\','/')
    $sourcePath=Quote-RegressionPath ((Join-Path (Split-Path $ManifestPath -Parent) 'Main.bas').Replace('\','/'))
    for($mode=1;$mode -le 5;++$mode){
        $executable=Join-Path $Destination ('main-'+$mode+'.exe')
        $null=Run-Regression $Selection.clang.path ($common+@(('-DREGRESSION_MAIN='+$mode),'-o',$executable))
        if($mode -eq 1){$expected=$fallback}
        elseif($mode -le 3){
            $row=@($oracle.project | Where-Object code -EQ (1316+$mode))[0]
            $expected='error UBE'+$row.code+': '+$row.message+" (next lines: path, line, column, byte)`n"+$sourcePath+"`n1`n1`n0`n"
        }else{$expected=$manifest+"`nsource(6,1): error UBE1008: could not close source file`n";if($mode -eq 5){$expected+=$oracle.release}}
        $null=Run-Regression $executable @('--check',$ManifestPath,'--jobs','4') 1 $expected
        $checks.Add([pscustomobject]@{assertion=('actual platform Main mode '+$mode+': exact output/status and native resource cleanup');passed=$true})
    }
    $executable=Join-Path $Destination 'diagnostics.exe'
    $null=Run-Regression $Selection.clang.path ($common+@('-o',$executable))
    $rows=@()
    foreach($row in $oracle.project){$rows+=[pscustomobject]@{name=('UBE'+$row.code);arguments=@($ManifestPath,[string]$row.code,'normal','0');stdout=('error UBE'+$row.code+': '+$row.message+" (next lines: path, line, column, byte)`n"+$manifest+"`n1`n1`n0`n")}}
    foreach($row in $oracle.delegated){$rows+=[pscustomobject]@{name=$row.name;arguments=@($ManifestPath,[string]$row.code,'normal','0',[string]$row.kind,[string]$row.file);stdout=($sourcePath+"`n"+$row.output)}}
    foreach($row in $rows){
        $null=Run-Regression $executable $row.arguments 0 $row.stdout
        $checks.Add([pscustomobject]@{assertion=('exact diagnostic '+$row.name+', primary preservation and complete cleanup');passed=$true})
    }
    $allocationRows=@()
    foreach($row in @($rows | Where-Object name -In @('UBE1300','input-utf8','parser-unexpected','scanner-character'))){
        $values=@($row.arguments);$values[2]='root'
        $null=Run-Regression $executable $values 0 $fallback
        $checks.Add([pscustomobject]@{assertion=('real full-root '+$row.name+': only fallback, primary preserved, cleanup');passed=$true})
        $values[2]='count'
        $counted=Run-Regression $executable $values 0 '' $false
        if(-not $counted.stdout.StartsWith($row.stdout)){throw 'Allocation observation changed diagnostic'}
        $count=($counted.stdout.Substring($row.stdout.Length) | ConvertFrom-Json).allocationPositions
        if($count -lt 1){throw 'No allocation positions observed'}
        for($position=1;$position -le $count;++$position){
            $values[2]='allocate';$values[3]=[string]$position
            $null=Run-Regression $executable $values 0 $fallback
            $checks.Add([pscustomobject]@{assertion=('actual allocator '+$row.name+' position '+$position+': only fallback, primary preserved, cleanup');passed=$true})
        }
        $allocationRows+=[pscustomobject]@{name=$row.name;positions=$count;denial='selected allocation and next allocation (covers runtime collection/retry)'}
    }
    foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw ('Pinned regression input changed: '+$identity.path)}}
    return [pscustomobject]@{inputs=$inputs;commands=@($commands.ToArray());checks=@($checks.ToArray());
        artifacts=@(Get-ChildItem -LiteralPath $Destination -File | ForEach-Object {Get-ArtifactIdentity $_.FullName});allocationPositions=$allocationRows}
}
