param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../../bootstrap/out/v2/current.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/source-input/' + [Guid]::NewGuid().ToString('N'))
$project = Join-Path $run 'project'
New-Item -ItemType Directory -Path $project -Force | Out-Null
$fixture = Join-Path $root 'compiler/UBE_Compiler_v3/tests/source-input'
$paths = @('compiler/UBE_Compiler_v3/tools/check-source-input.ps1',
    'compiler/UBE_Compiler_v3/SourceInput.bas','compiler/UBE_Compiler_v3/SourceFile.bas',
    'compiler/UBE_Compiler_v3/Main.bas','compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE',
    'compiler/UBE_Compiler_v3/SOURCE-INPUT-CONTRACT.md','std-lib/UBECore.UBE',
    'compiler/UBE_Compiler_v2/tests/file-input/binding-cases.json',
    'runtime/bootstrap_runtime.c','std-lib/src/win-lib/file_primitives.c','runtime/value_storage.h',
    'std-lib/tests/managed-storage/copy-probe.h','std-lib/tests/byte-storage/allocation-probe.h',
    'bootstrap/tools/verification.ps1') | ForEach-Object { Join-Path $root $_ }
$paths += @(Get-ChildItem -LiteralPath $fixture -File | ForEach-Object FullName)
$inputs = @($paths | ForEach-Object { Get-ArtifactIdentity $_ })
$commands = @(); $checks = @(); $measurements = @(); $selection = $null
$success = $false; $failure = $null
function Invoke-Recorded([string]$File,[string[]]$Arguments = @(),[int]$Timeout = 60) {
    $result = Invoke-BoundedProcess $File $Arguments $root $Timeout
    $script:commands += $result
    if ($result.timedOut -or $result.exit -ne 0) { throw "Source-input process failed: $($result | ConvertTo-Json -Compress -Depth 5)" }
    return $result
}
function Assert-Process([string]$File,[string[]]$Arguments,[int]$Exit,[string]$Stdout,[string]$Label) {
    $before = @(Get-ChildItem -LiteralPath $run -File -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + $_.Length }) -join "`n"
    $result = Invoke-BoundedProcess $File $Arguments $run 30
    $script:commands += $result
    if ($result.timedOut -or $result.exit -ne $Exit -or $result.stdout -cne $Stdout -or $result.stderr -cne '') {
        throw "$Label failed: $($result | ConvertTo-Json -Compress -Depth 5)"
    }
    $after = @(Get-ChildItem -LiteralPath $run -File -Recurse | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + $_.Length }) -join "`n"
    if ($before -cne $after) { throw "$Label created or resized an unexpected output artifact" }
    $script:checks += [pscustomobject]@{ assertion=$Label; passed=$true }
}
function Get-ProjectSources([string]$Manifest) {
    $directory = Split-Path $Manifest -Parent
    $lines = [IO.File]::ReadAllLines($Manifest)
    foreach ($line in $lines) {
        if ($line -match '^Source = "([^"]+)"$') { [IO.Path]::GetFullPath((Join-Path $directory $Matches[1])) }
    }
    foreach ($line in $lines) {
        if ($line -match '^Reference = "([^"]+)"$') { Get-ProjectSources ([IO.Path]::GetFullPath((Join-Path $directory $Matches[1]))) }
    }
}
try {
    $inputs += Get-ArtifactIdentity $SelectionPath
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($property in $selection.PSObject.Properties) {
        if ($property.Name -ne 'schema') {
            if ((Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256) { throw "Selected artifact changed: $($property.Name)" }
            $inputs += $property.Value
        }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected compiler has not passed its source acceptance gate' }
    foreach ($identity in @($selection.compiler,$selection.runtime,$selection.unicodeRuntime)) {
        $artifact = @($accepted.artifacts | Where-Object path -CEQ $identity.path)
        if ($artifact.Count -ne 1 -or $artifact[0].sha256 -cne $identity.sha256) { throw 'Selected artifact differs from immutable accepted manifest' }
    }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted input changed: $($identity.path)" }
    }
    foreach ($path in @('runtime/bootstrap_runtime.c','std-lib/src/win-lib/file_primitives.c')) {
        $runtimeInput = @($accepted.inputs | Where-Object path -CEQ (Join-Path $root $path))
        if ($runtimeInput.Count -ne 1 -or $runtimeInput[0].sha256 -cne (Get-ArtifactIdentity (Join-Path $root $path)).sha256) { throw "Instrumented source differs from accepted runtime input: $path" }
    }
    $inputs += @($accepted.inputs)
    $stage1 = Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
    $stageIdentity = @($accepted.artifacts | Where-Object path -CEQ $stage1)
    if ($stageIdentity.Count -ne 1 -or (Get-ArtifactIdentity $stage1).sha256 -cne $stageIdentity[0].sha256) { throw 'Stage-one compiler identity differs' }
    $inputs += $stageIdentity[0]
    $stages = @($stage1,$selection.compiler.path)
    foreach ($name in @('SourceInput.bas','SourceFile.bas')) {
        Copy-Item -LiteralPath (Join-Path $root ('compiler/UBE_Compiler_v3/' + $name)) -Destination (Join-Path $project $name)
        if ((Get-ArtifactIdentity (Join-Path $project $name)).sha256 -cne (Get-ArtifactIdentity (Join-Path $root ('compiler/UBE_Compiler_v3/' + $name))).sha256) { throw "Production copy differs: $name" }
    }
    Copy-Item -LiteralPath (Join-Path $fixture 'Entry.bas') -Destination (Join-Path $project 'Entry.bas')
    if ((Get-ArtifactIdentity (Join-Path $project 'Entry.bas')).sha256 -cne (Get-ArtifactIdentity (Join-Path $fixture 'Entry.bas')).sha256) { throw 'Test entry copy differs' }
    $manifest = Join-Path $project 'InputProof.UBE'
    [IO.File]::WriteAllText($manifest,"UBE-Project 1`nName = `"SourceInputProof`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"SourceInput.bas`"`nSource = `"SourceFile.bas`"`nSource = `"Entry.bas`"`nReference = `"../../../../../std-lib/UBECore.UBE`"`n",(New-Object Text.UTF8Encoding($false)))
    $ordered = @(Get-ProjectSources $manifest)
    $inputs += @(Get-ProjectSources (Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE') | ForEach-Object { Get-ArtifactIdentity $_ })
    $inputs += @($ordered | Where-Object { -not $_.StartsWith($project,[StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { Get-ArtifactIdentity $_ })
    $procedures = @{}; $types = @{}; $procedureIndex = 0; $typeIndex = 0
    foreach ($source in $ordered) {
        $text = [IO.File]::ReadAllText($source)
        foreach ($match in [regex]::Matches($text,'(?m)^(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b')) {
            if ($procedures.ContainsKey($match.Groups[1].Value)) { throw 'Duplicate test bridge procedure name' }
            $procedures[$match.Groups[1].Value] = 'ube.p' + $procedureIndex; ++$procedureIndex
        }
        foreach ($match in [regex]::Matches($text,'(?m)^Type ([A-Za-z_][A-Za-z_0-9]*)\b')) {
            $types[$match.Groups[1].Value] = '%ube.type.' + $typeIndex; ++$typeIndex
        }
    }
    $bindings = @{
        BEGIN=@('BeginSourceInput','i1','ptr,i32'); APPEND=@('AppendSourceInput','i1','ptr,ptr,i32,i32,ptr');
        FINISH=@('TryFinishSourceInput','i1','ptr,ptr,ptr'); FILE=@('TryReadSourceFile','i1','ptr,i32,ptr,ptr,ptr,ptr');
        SCOPED=@('ScopedSourceInput','i1','i1'); COPY=@('CopySourceDocument','i1','ptr,ptr');
        FEED=@('FeedUtf8Byte','i1','ptr,i8,ptr,ptr'); RESERVE=@('TryReserveByteBuffer','i1','ptr,i32') }
    $observedRuntime = Join-Path $run 'observed-runtime.o'
    $null = Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-DUBE_FILE_TESTING','-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),'-c',(Join-Path $fixture 'runtime-observed.c'),'-o',$observedRuntime)
    $hashes = @(); $compilerHashes = @(); $rejectionResults = @{}
    for ($index = 0; $index -lt 2; ++$index) {
        $stem = Join-Path $run ('stage' + ($index+1)); $ir = $stem + '.ll'
        $null = Invoke-Recorded $stages[$index] @($manifest,$ir)
        $raw = [IO.File]::ReadAllText($ir)
        $adapter = [IO.File]::ReadAllText((Join-Path $fixture 'adapters.ll'))
        foreach ($key in $bindings.Keys) {
            $binding = $bindings[$key]; $symbol = $procedures[$binding[0]]
            $definitions = [regex]::Matches($raw,'(?m)^define ' + $binding[1] + ' @' + [regex]::Escape($symbol) + '\(([^\r\n]*)\) \{\r?$')
            if ($definitions.Count -ne 1) { throw "Missing exact bridge: $($binding[0])" }
            $actualTypes = @($definitions[0].Groups[1].Value -split ', ' | ForEach-Object { ($_ -split ' ')[0] }) -join ','
            if ($actualTypes -cne $binding[2]) { throw "Unexpected bridge signature: $($binding[0]) = $actualTypes" }
            $adapter = $adapter.Replace('@' + $key + '@','@' + $symbol)
        }
        $expectedTypes = @{
            SourcePosition='i32, i32, i32, i32'; SourceFailure=('i32, ' + $types.SourcePosition);
            SourceDocument='ptr, i32, i32, i32'; Utf8Decoder='i32, i32, i32, i1'; ByteBuffer='ptr, i32';
            SourceInput=($types.ByteBuffer + ', ' + $types.Utf8Decoder + ', ' + $types.SourcePosition + ', ' + $types.SourcePosition + ', ' + $types.SourcePosition + ', i32, i32, i1, i1') }
        foreach ($name in $expectedTypes.Keys) {
            $pattern = '(?m)^' + [regex]::Escape($types[$name] + ' = type { ' + $expectedTypes[$name] + ' }') + '\r?$'
            if ([regex]::Matches($raw,$pattern).Count -ne 1) { throw "Unexpected production record: $name" }
        }
        if ([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1) { throw 'Unexpected executable entry wrapper' }
        $adapted = [regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @source_unused_entry(')
        $adapted = [regex]::Replace($adapted,'(?m)^define i1 @' + [regex]::Escape($procedures.FeedUtf8Byte) + '\(','define i1 @source_feed_body(')
        $adapted = [regex]::Replace($adapted,'(?m)^define i1 @' + [regex]::Escape($procedures.TryReserveByteBuffer) + '\(','define i1 @source_reserve_body(')
        $layoutExpressions = @()
        foreach ($name in @('SourceInput','SourceDocument','SourceFailure','SourcePosition','Utf8Decoder','ByteBuffer')) {
            $layoutExpressions += 'ptrtoint (ptr getelementptr (' + $types[$name] + ', ptr null, i32 1) to i64)'
        }
        foreach ($part in @(@('SourceInput',1),@('SourceInput',2),@('SourceInput',3),@('SourceInput',4),@('SourceInput',5),@('SourceInput',6),@('SourceInput',7),@('SourceInput',8),@('SourceDocument',1),@('SourceDocument',2),@('SourceDocument',3),@('SourceFailure',1))) {
            $layoutExpressions += 'ptrtoint (ptr getelementptr (' + $types[$part[0]] + ', ptr null, i32 0, i32 ' + $part[1] + ') to i64)'
        }
        $layout = "`ndefine i64 @source_layout(i32 %index) {`n  switch i32 %index, label %invalid [`n"
        for ($i = 0; $i -lt $layoutExpressions.Count; ++$i) { $layout += "    i32 $i, label %case$i`n" }
        $layout += "  ]`ninvalid:`n  ret i64 -1`n"
        for ($i = 0; $i -lt $layoutExpressions.Count; ++$i) { $layout += "case${i}:`n  ret i64 " + $layoutExpressions[$i] + "`n" }
        $layout += "}`n"
        $adaptedIr = $stem + '-adapted.ll'
        [IO.File]::WriteAllText($adaptedIr,$adapted + "`n" + $adapter + $layout,(New-Object Text.UTF8Encoding($false)))
        foreach ($instrumented in @($false,$true)) {
            $mode = 'exact'; $runtime = $selection.runtime.path; $defines = @()
            if ($instrumented) { $mode = 'observed'; $runtime = $observedRuntime; $defines = @('-DOBSERVE_INPUT') }
            $exe = $stem + '-' + $mode + '.exe'
            $null = Invoke-Recorded $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$adaptedIr,'-x','c',(Join-Path $fixture 'probe.c'),'-std=c11','-Wall','-Wextra','-Werror') + $defines + @('-x','none',$runtime,$selection.unicodeRuntime.path,'-o',$exe))
            $native = Invoke-Recorded $exe
            if ($native.stderr -cne '' -or $native.stdout -notmatch '(?m)^PASS source input assertions:(\d+)\r?$') { throw 'Unexpected source proof result' }
            $checks += [pscustomobject]@{ stage=$index+1; assertion=($mode + ' runtime: split/range/snapshot/position/Err/cleanup/worker/file oracles'); assertions=[long]$Matches[1]; passed=$true }
            if ($instrumented) {
                $allRows = @($native.stdout -split "`n" | Where-Object { $_.StartsWith('{') } | ForEach-Object { $_ | ConvertFrom-Json })
                $rows = @($allRows | Where-Object kind -CEQ 'input')
                $fileRows = @($allRows | Where-Object kind -CEQ 'file')
                $sizes = @(0,1,31,4095,4096,4097,16384,65536)
                if ($rows.Count -ne $sizes.Count -or $fileRows.Count -ne $sizes.Count) { throw 'Wrong source/file cost measurement count' }
                for ($m = 0; $m -lt $rows.Count; ++$m) {
                    if ($rows[$m].n -ne $sizes[$m] -or $rows[$m].feedCalls -ne $sizes[$m] -or $rows[$m].appendPayloadCopiedBytes -ne $sizes[$m] -or $rows[$m].snapshotCopiedBytes -gt 2*$sizes[$m] -or ($sizes[$m] -gt 0 -and ($rows[$m].totalCopiedBytes -ge 5*$sizes[$m] -or $rows[$m].growthCopiedBytes -ge 2*$sizes[$m]))) { throw 'Independent source cost budget failed' }
                    $measurements += [pscustomobject]@{ stage=$index+1; actual=$rows[$m]; sampledProcessPeakWorkingSetBytes=$native.sampledPeakWorkingSetBytes }
                    if ($fileRows[$m].n -ne $sizes[$m] -or $fileRows[$m].actualBytesRead -ne $sizes[$m] -or $fileRows[$m].actualBytesPublished -ne $sizes[$m] -or $fileRows[$m].scratchPayloadAllocations -ne 1) { throw 'Independent actual file read/copy oracle failed' }
                    $measurements += [pscustomobject]@{ stage=$index+1; actual=$fileRows[$m]; sampledProcessPeakWorkingSetBytes=$native.sampledPeakWorkingSetBytes }
                }
            }
        }
        $suite = Get-Content -LiteralPath (Join-Path $root 'compiler/UBE_Compiler_v2/tests/file-input/binding-cases.json') -Raw | ConvertFrom-Json
        foreach ($case in $suite.cases) {
            $source = Join-Path $run ($case.name + '.bas'); $output = Join-Path $run ('stage' + ($index+1) + '-' + $case.name + '.ll')
            $text = $case.header + "`nAttribute Bound.UBE_Primitive = `"" + $case.role + "`"`nEnd Function`nFunction Main() As Long`nMain = 0`nEnd Function`n"
            [IO.File]::WriteAllText($source,$text,(New-Object Text.UTF8Encoding($false)))
            $rejection = Invoke-BoundedProcess $stages[$index] @($source,$output) $root 10; $commands += $rejection
            if ($rejection.timedOut -or $rejection.exit -ne 1 -or ($rejection.stdout+$rejection.stderr) -notmatch $case.diagnostic -or (Test-Path -LiteralPath $output)) { throw "Binding rejection failed: $($case.name)" }
            if ($index -eq 0) { $rejectionResults[$case.name] = $rejection }
            else {
                $previous = $rejectionResults[$case.name]
                if ($rejection.stdout -cne $previous.stdout -or $rejection.stderr -cne $previous.stderr -or $rejection.exit -ne $previous.exit) { throw "Binding rejection diagnostics differ between stages: $($case.name)" }
            }
            $checks += [pscustomobject]@{ stage=$index+1; assertion=('host signature rejects ' + $case.name); passed=$true }
        }
        $compilerIr = $stem + '-compiler.ll'; $compilerExe = $stem + '-compiler.exe'
        $null = Invoke-Recorded $stages[$index] @((Join-Path $root 'compiler/UBE_Compiler_v3/UBE_Compiler_v3.UBE'),$compilerIr) 300
        $null = Invoke-Recorded $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',$compilerIr,$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$compilerExe)
        $unicode = Join-Path $run 'source-名-é.bas'
        $validSource = "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Main`"`r`nSub Main()`r`n    Dim " + [char]945 + " As Long`r`n    " + [char]945 + " = 1`r`nEnd Sub`r`n"
        [IO.File]::WriteAllBytes($unicode,([byte[]]@(239,187,191) + (New-Object Text.UTF8Encoding($false)).GetBytes($validSource)))
        Assert-Process $compilerExe @() 2 "usage: ube --check <source-file>`n" "stage $($index+1): missing command arguments"
        Assert-Process $compilerExe @('--unknown',$unicode) 2 "usage: ube --check <source-file>`n" "stage $($index+1): unsupported command"
        Assert-Process $compilerExe @('--check',$unicode) 1 "error UBE1012: source checking is not implemented`n" "stage $($index+1): Unicode path exact bytes intake followed by controlled unsupported checking"
        $cliHeader = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Main`"`n"
        $cliCases = @(
            @{name='headerless';source="Option Explicit On`n";message="source(1,1): error UBE1100: missing source header at byte 0`n"},
            @{name='unknown-reserved-attribute';source=($cliHeader+"Attribute UBE_Future = True`n");message="source(3,11): error UBE1100: unknown reserved source attribute at byte 58`n"},
            @{name='unterminated-string';source=($cliHeader+'"abc');message="source(3,1): error UBE1100: unterminated string at byte 48`n"},
            @{name='invalid-identity';source="UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"`"`n";message="source(2,22): error UBE1100: invalid source identity at byte 41`n"},
            @{name='lexical-before-reserved-attribute';source=($cliHeader+"`"bad`nAttribute UBE_Bad = True`n");message="source(3,1): error UBE1100: unterminated string at byte 48`n"},
            @{name='unterminated-identity-lexical-priority';source="UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Main`n";message="source(2,22): error UBE1100: unterminated string at byte 41`n"},
            @{name='extension-kind';source="UBE SOURCE 1 CLASS`nAttribute UBE_Name = `"Main`"`n";message="source(1,14): error UBE1100: source kind does not match the file extension at byte 13`n"}
        )
        foreach ($cli in $cliCases) {
            $cliPath = Join-Path $run ('cli-'+$cli.name+'.bas')
            [IO.File]::WriteAllText($cliPath,$cli.source,(New-Object Text.UTF8Encoding($false)))
            Assert-Process $compilerExe @('--check',$cliPath) 1 $cli.message "stage $($index+1): real envelope/scanner CLI $($cli.name)"
        }
        Assert-Process $compilerExe @('--check',(Join-Path $run 'absent.bas')) 1 "source(1,1): error UBE1008: cannot open source; check its path and read permissions`n" "stage $($index+1): missing file"
        $invalid = Join-Path $run 'invalid.bas'; [IO.File]::WriteAllBytes($invalid,[byte[]]@(195,169,10,65,226,65))
        Assert-Process $compilerExe @('--check',$invalid) 1 "source(2,2): error UBE1005: invalid UTF-8 at byte 4`n" "stage $($index+1): invalid UTF8 byte versus scalar position"
        [IO.File]::WriteAllBytes($invalid,[byte[]]@(195,169,13))
        Assert-Process $compilerExe @('--check',$invalid) 1 "source(1,2): error UBE1006: isolated carriage return at byte 2`n" "stage $($index+1): isolated CR at EOF"
        $large = Join-Path $run 'oversized.bas'; $stream = [IO.File]::OpenWrite($large); try { $stream.SetLength(16777217) } finally { $stream.Dispose() }
        Assert-Process $compilerExe @('--check',$large) 1 "source(1,1): error UBE1000: source byte limit exceeded`n" "stage $($index+1): byte size limit before reading"
        $hashes += (Get-ArtifactIdentity $ir).sha256; $compilerHashes += (Get-ArtifactIdentity $compilerIr).sha256
    }
    if ($hashes[0] -cne $hashes[1] -or $compilerHashes[0] -cne $compilerHashes[1]) { throw 'Raw source proof or production compiler LLVM differs between stages' }
    $checks += [pscustomobject]@{ assertion='byte-identical raw LLVM for intact source consumer and complete production manifest through both accepted stages'; passed=$true }
    foreach ($name in @('SourceInput.bas','SourceFile.bas')) {
        if ((Get-ArtifactIdentity (Join-Path $project $name)).sha256 -cne (Get-ArtifactIdentity (Join-Path $root ('compiler/UBE_Compiler_v3/' + $name))).sha256) { throw 'Production test copy changed' }
    }
    if ((Get-ArtifactIdentity (Join-Path $project 'Entry.bas')).sha256 -cne (Get-ArtifactIdentity (Join-Path $fixture 'Entry.bas')).sha256) { throw 'Test entry copy changed' }
    foreach ($identity in $inputs) { if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Proof input changed: $($identity.path)" } }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ schema='ube-source-input-proof-1'; success=$success; failure=$failure; acceptedSelection=$selection;
        inputs=$inputs; checks=$checks; measurements=$measurements; commands=$commands;
        limits='The C harness proves source-input assertions; explicit production CLI cases separately check envelope/scanner diagnostics and controlled unavailable checking. Full scanner function qualification belongs to the separate scanner gate. No parser, semantic checking or output program is qualified. Native C workers qualify private consumers and immutable sharing, not UBE scheduling. Measured calloc arguments are requested zero initialization, not physical writes. Process working set includes C harness/runtime. Test copies preserve complete production source/envelopes and actual declared UBECore Reference; only generated entry/ABI wrappers instrument test executables.';
        artifacts=@(Get-ChildItem -LiteralPath $run -File -Recurse | ForEach-Object { Get-ArtifactIdentity $_.FullName }) } |
        ConvertTo-Json -Depth 14 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) source-input acceptance checks through both accepted stages."
