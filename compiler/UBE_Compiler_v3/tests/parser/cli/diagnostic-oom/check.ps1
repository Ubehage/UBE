# Bind the maintained synthetic regression to the actual production definitions.
# Only wrappers and the unused platform entry name differ in generated test IR.
function Invoke-ParserDiagnosticRegression([string]$RawPath,[string[]]$Sources,$Selection,[string]$Destination,[string]$Repository) {
    New-Item -ItemType Directory -Path $Destination -Force|Out-Null
    $fixture=$PSScriptRoot
    $raw=[IO.File]::ReadAllText($RawPath);$procedures=@{};$types=@{};$procedureIndex=0;$typeIndex=0
    # The emitter reserves every reference-class payload type before declaring
    # any record, including records in modules earlier in the source closure.
    foreach($source in $Sources) {
        $text=[IO.File]::ReadAllText($source)
        if($text -match '(?m)^UBE SOURCE 1 CLASS\r?$') {
            $declarations=[regex]::Matches($text,'(?m)^Attribute UBE_Name = "([A-Za-z_][A-Za-z_0-9]*)"\r?$')
            if($declarations.Count -ne 1){throw "Actual diagnostic class identity differs: $source"}
            $name=$declarations[0].Groups[1].Value
            if($types.ContainsKey($name)){throw "Duplicate diagnostic ABI type $name"}
            $types[$name]='%ube.type.'+$typeIndex;++$typeIndex
        }
    }
    foreach($source in $Sources) {
        $text=[IO.File]::ReadAllText($source)
        foreach($match in [regex]::Matches($text,'(?m)^(?:(?:Public|Private|Friend) )?(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')) {
            $name=$match.Groups[1].Value
            if($procedures.ContainsKey($name)){throw "Duplicate diagnostic ABI procedure $name"}
            $procedures[$name]='ube.p'+$procedureIndex;++$procedureIndex
        }
        foreach($match in [regex]::Matches($text,'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')) {
            $name=$match.Groups[1].Value
            if($types.ContainsKey($name)){throw "Duplicate diagnostic ABI type $name"}
            $types[$name]='%ube.type.'+$typeIndex;++$typeIndex
        }
    }
    $helper=$procedures.TryPrintSourceSyntaxFailure;$fallback=$procedures.PrintSyntaxStorageFailure
    if(-not $helper -or -not $fallback){throw 'Actual parser diagnostic functions are absent'}
    $helperBodies=[regex]::Matches($raw,'(?ms)^define i1 @'+[regex]::Escape($helper)+'\(ptr %arg\.\d+, ptr %arg\.\d+\) \{\r?\n.*?^\}\r?$')
    $fallbackBodies=[regex]::Matches($raw,'(?ms)^define void @'+[regex]::Escape($fallback)+'\(\) \{\r?\n.*?^\}\r?$')
    if($helperBodies.Count -ne 1 -or $fallbackBodies.Count -ne 1){throw 'Actual diagnostic signatures do not match the checked C adapter'}
    if($helperBodies[0].Value -match '@ube_(long_to_string|string_concat)\('){throw 'Parser diagnostic reintroduced allocating String formatting'}
    if($fallbackBodies[0].Value -match '@ube_(?:gc_root_enter(?:_layout)?|value_root_enter|allocate_string|long_to_string|string_concat)\('){throw 'Static parser fallback requires managed admission or String allocation'}
    foreach($layout in @(@('SourceDocument','ptr, i32, i32, i32'),@('SyntaxFailure','i32, i32, i32'))) {
        if(-not $types.ContainsKey($layout[0]) -or [regex]::Matches($raw,'(?m)^'+[regex]::Escape($types[$layout[0]]+' = type { '+$layout[1]+' }')+'\r?$').Count -ne 1){throw "Actual diagnostic record layout differs: $($layout[0])"}
    }
    if([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1){throw 'Unexpected actual production entry point'}
    $adapted=[regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @diagnostic_unused_main(')
    $adapted+="`ndefine i32 @diagnostic_actual_helper(ptr %document, ptr %failure) {`n %result = call i1 @"+$helper+"(ptr %document, ptr %failure)`n %status = zext i1 %result to i32`n ret i32 %status`n}`n"
    $adapted+="define void @diagnostic_actual_fallback() {`n call void @"+$fallback+"()`n ret void`n}`n"
    $utf8=New-Object Text.UTF8Encoding($false)
    $adapter=Join-Path $Destination 'adapted.ll';[IO.File]::WriteAllText($adapter,$adapted,$utf8)
    $runtime=Join-Path $Destination 'runtime.o';$exe=Join-Path $Destination 'probe.exe'
    $commands=@();$cases=@();$checks=@();$success=$false;$failure=$null
    $inputPaths=@($RawPath)+@($Sources)+@($Selection.clang.path,$Selection.unicodeRuntime.path,(Join-Path $Repository 'runtime/bootstrap_runtime.c'),(Join-Path $Repository 'runtime/value_storage.h'),(Join-Path $Repository 'std-lib/src/win-lib/file_primitives.c'))
    $inputPaths+=@(Get-ChildItem -LiteralPath $fixture -File|ForEach-Object FullName)
    $inputs=@($inputPaths|ForEach-Object {$_}|Sort-Object -Unique|ForEach-Object {Get-ArtifactIdentity $_})
    try {
        # Historical captures are immutable pre-fix evidence, not current successes.
        foreach($before in @(@('before-kind5.json','E02733E558F45C93773CDDB25DD180F18925214505A67684DEDFEB7DEA348896'),@('before-kind5-kind101.json','648F6CCAD114C8A5EF8DCC7EF12BE87DD9DB65306D231D74BBC654467C423DC5'))) {
            $path=Join-Path $fixture $before[0]
            if((Get-ArtifactIdentity $path).sha256 -cne $before[1]){throw 'Retained before-fix fatal reproduction report changed'}
            $record=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
            if(-not $record.controlPassed -or -not $record.reproducedFatalFailure){throw 'Retained capture did not reproduce the fatal path'}
        }
        $build=Invoke-BoundedProcess $Selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-include',(Join-Path $fixture 'allocation-probe.h'),'-c',(Join-Path $fixture 'runtime.c'),'-o',$runtime) $Repository 60
        $commands+=$build
        if($build.timedOut -or $build.exit -ne 0){throw "Intact observed diagnostic runtime did not compile: $($build.stderr)"}
        $link=Invoke-BoundedProcess $Selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-x','ir',$adapter,'-x','c',(Join-Path $fixture 'probe.c'),'-x','none',$runtime,$Selection.unicodeRuntime.path,'-o',$exe) $Repository 120
        $commands+=$link
        if($link.timedOut -or $link.exit -ne 0){throw "Actual diagnostic helper regression did not link: $($link.stderr)"}
        # These independent expected messages cover every new syntax failure kind.
        $messages=@{
            1='error UBE1209: invalid parser input';2='error UBE1208: parser resource limit exceeded';
            3='error UBE1200: source syntax family is not implemented';5='error UBE1210: insufficient syntax storage';
            101='error UBE1201: expected expression';102='error UBE1202: expected token';103='error UBE1203: unexpected token';
            104='error UBE1204: expected identifier';105='error UBE1205: invalid call syntax';106='error UBE1206: unterminated block';
            107='error UBE1207: unexpected terminator';999='error UBE1209: invalid parser input'
        }
        foreach($mode in @('control','deny')) {
            foreach($kind in @($messages.Keys|Sort-Object)) {
                $actual=Invoke-BoundedProcess $exe @($mode,[string]$kind) $Repository 15
                $commands+=$actual
                $expected=$messages[$kind]+" (next lines: line, column, byte)`n1`n1`n0`n"
                $passed=-not $actual.timedOut -and $actual.exit -eq 0 -and $actual.stdout -ceq $expected -and $actual.stderr -ceq "MEASURE runtime malloc:0 calloc:0 realloc:0`n"
                $cases+=[pscustomobject]@{mode=$mode;kind=$kind;expectedStdout=$expected;actual=$actual;passed=$passed}
                if(-not $passed){throw "Actual diagnostic helper failed $mode Kind$kind"}
            }
            $actual=Invoke-BoundedProcess $exe @($mode,'position') $Repository 15
            $commands+=$actual
            $expected="error UBE1210: insufficient syntax storage`n"
            $passed=-not $actual.timedOut -and $actual.exit -eq 0 -and $actual.stdout -ceq $expected -and $actual.stderr -ceq "MEASURE runtime malloc:0 calloc:0 realloc:0`n"
            $cases+=[pscustomobject]@{mode=$mode;kind='invalid position';expectedStdout=$expected;actual=$actual;passed=$passed}
            if(-not $passed){throw 'Position preparation failure did not return fresh False and print static fallback'}
        }
        $actual=Invoke-BoundedProcess $exe @('deny','admission') $Repository 60
        $commands+=$actual
        $passed=-not $actual.timedOut -and $actual.exit -eq 0 -and $actual.stdout -ceq "error UBE1210: insufficient syntax storage`n" -and $actual.stderr -ceq "MEASURE runtime malloc:0 calloc:0 realloc:0`n"
        $cases+=[pscustomobject]@{mode='deny';kind='real full root registry';expectedStdout="error UBE1210: insufficient syntax storage`n";actual=$actual;passed=$passed}
        if(-not $passed){throw 'Real root admission failure did not return fresh False, Err7 and actual static fallback'}
        foreach($identity in $inputs) {
            $after=Get-ArtifactIdentity $identity.path
            if($after.sha256 -cne $identity.sha256 -or $after.bytes -ne $identity.bytes){throw "Diagnostic regression input changed: $($identity.path)"}
        }
        $checks=@('All eleven new failure kinds and unknown-kind default have exact headers and numeric coordinates','All successful helpers preserve incoming Err77 and document/failure bytes','Persistent runtime allocator denial causes zero malloc/calloc/realloc attempts','Position preparation failure returns fresh False and preserves Err77','Actual full root registry returns fresh False and Err7, retains every root, and permits actual rootless static fallback','All roots are released and all input identities remain unchanged')
        $success=$true
    } catch {$failure=$_.Exception.Message} finally {
        $artifacts=@($adapter,$runtime,$exe|Where-Object {[IO.File]::Exists($_)}|ForEach-Object {Get-ArtifactIdentity $_})
        $report=[pscustomobject]@{schema='ube-parser-diagnostic-oom-regression-1';success=$success;failure=$failure;helper=$helper;fallback=$fallback;inputs=$inputs;artifacts=$artifacts;checks=$checks;cases=$cases;commands=$commands;scope='Intact actual production UBE helper/fallback bodies and complete production runtime. Only generated native export wrappers and runtime allocation observation differ. Counts cover runtime allocator calls, not CRT internals. Historical pre-fix reports pin Kind5/101 exit70 separately.'}
        $reportPath=Join-Path $Destination 'report.json'
        [IO.File]::WriteAllText($reportPath,($report|ConvertTo-Json -Depth 25),$utf8)
    }
    if(-not $success){throw "$failure; diagnostic evidence: $reportPath"}
    return [pscustomobject]@{report=(Get-ArtifactIdentity $reportPath);cases=$cases.Count;helper=$helper;fallback=$fallback;artifacts=$artifacts;inputs=$inputs}
}
