param([string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$fixtures = Join-Path $root 'std-lib/tests/managed-storage'
$run = Join-Path $root ('bootstrap/out/managed-values/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands = New-Object 'System.Collections.Generic.List[object]'
$checks = New-Object 'System.Collections.Generic.List[object]'
$selection = $null
$stageOneIdentity = $null
$inputs = @()
$success = $false
$failure = $null
function Invoke-Recorded([string]$File, [string[]]$Values = @()) {
    $record = Invoke-BoundedProcess $File $Values $root 30
    $commands.Add($record)
    if ($record.timedOut -or $record.exit -ne 0) {
        throw "Managed proof process failed: $File : $($record | ConvertTo-Json -Compress -Depth 5)"
    }
    return $record
}
function Invoke-Oracle([string]$Ir, [string]$Adapter, [string]$Stem, [string]$Expected, [string[]]$Defines = @()) {
    $exe = $Stem + '.exe'
    $null = Invoke-Recorded $selection.clang.path (@('--target=x86_64-w64-windows-gnu','-O2',
        '-x','ir',$Ir,'-x','c',$Adapter,'-std=c17','-Wall','-Wextra','-Werror') + $Defines +
        @('-x','none',$selection.runtime.path,$selection.unicodeRuntime.path,'-o',$exe))
    $native = Invoke-Recorded $exe
    if ($native.stdout -cne $Expected -or $native.stderr -cne '') {
        throw "Managed native oracle differs: $($native | ConvertTo-Json -Compress -Depth 5)"
    }
}
try {
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    foreach ($identity in @($selection.manifest,$selection.compiler,$selection.runtime,$selection.unicodeRuntime,$selection.clang)) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Selected artifact changed: $($identity.path)" }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Selected v2 has not passed its source-build gate' }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Source-build input changed: $($identity.path)" }
    }
    $stage1 = Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'
    $stageOneIdentity = @($accepted.artifacts | Where-Object path -CEQ $stage1)
    if ($stageOneIdentity.Count -ne 1 -or (Get-ArtifactIdentity $stage1).sha256 -cne $stageOneIdentity[0].sha256) { throw 'Stage-one artifact differs' }
    $paths = @((Join-Path $PSScriptRoot 'check-managed-values.ps1'),(Join-Path $root 'bootstrap/tools/verification.ps1'),
        (Join-Path $root 'runtime/value_storage.h')) + @(Get-ChildItem -LiteralPath $fixtures -File | ForEach-Object FullName)
    $inputs = @($paths | Sort-Object -Unique | ForEach-Object { Get-ArtifactIdentity $_ })
    $suite = Get-Content -LiteralPath (Join-Path $fixtures 'cases.json') -Raw | ConvertFrom-Json
    $stages = @($stage1,$selection.compiler.path)
    $bindings = Get-Content -LiteralPath (Join-Path $fixtures 'binding-cases.json') -Raw | ConvertFrom-Json
    foreach ($case in $bindings.cases) {
        $caseDirectory = Join-Path $run $case.name
        New-Item -ItemType Directory -Path $caseDirectory | Out-Null
        if ($null -ne $case.PSObject.Properties['source']) {
            $source = Join-Path $fixtures $case.source
        } elseif ($null -ne $case.PSObject.Properties['files']) {
            foreach ($file in $case.files.PSObject.Properties) {
                [IO.File]::WriteAllText((Join-Path $caseDirectory $file.Name),$file.Value,(New-Object Text.UTF8Encoding($false)))
            }
            $source = Join-Path $caseDirectory $case.project
        } else {
            if ($null -ne $case.PSObject.Properties['header']) {
                $text = $case.header + "`nAttribute Size.UBE_Primitive = `"$($case.role)`"`nEnd Function`n"
            } else { $text = $case.sourceText }
            $text += "`nFunction Main() As Long`nMain = 0`nEnd Function`n"
            $source = Join-Path $caseDirectory 'Main.bas'
            [IO.File]::WriteAllText($source,$text,(New-Object Text.UTF8Encoding($false)))
        }
        $records = @()
        for ($index = 0; $index -lt 2; $index++) {
            $ir = Join-Path $caseDirectory ('stage' + ($index + 1) + '.ll')
            $record = Invoke-BoundedProcess $stages[$index] @($source,$ir) $root 15
            $commands.Add($record)
            if ($record.timedOut -or $record.exit -ne 1 -or (Test-Path -LiteralPath $ir) -or
                ($record.stdout + $record.stderr) -notmatch ('error ' + [regex]::Escape($case.diagnostic) + ':')) {
                throw "Managed declaration rejection differs: $($case.name): $($record | ConvertTo-Json -Compress -Depth 5)"
            }
            $records += $record
        }
        if ($records[0].stdout -cne $records[1].stdout -or $records[0].stderr -cne $records[1].stderr) {
            throw "Managed declaration stage diagnostics differ: $($case.name)"
        }
        $checks.Add([pscustomobject]@{ name = $case.name;
            assertion = 'both stages: exact diagnostic category, exit one, no LLVM artifact and identical diagnostics'; passed = $true })
    }
    foreach ($case in $suite.positive) {
        $hashes = @()
        for ($index = 0; $index -lt 2; $index++) {
            $stem = Join-Path $run ($case.name + '-stage' + ($index + 1))
            $ir = $stem + '.ll'
            $null = Invoke-Recorded $stages[$index] @((Join-Path $fixtures $case.source),$ir)
            $raw = [IO.File]::ReadAllText($ir)
            if ([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1) { throw 'Unrecognized UBE entry wrapper' }
            $adapted = [regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @managed_value_entry(')
            $expected = $case.stdout + "err:77 dead-bytes:0`n"
            $defines = @()
            if ($null -ne $case.PSObject.Properties['layoutTypePattern']) {
                $types = [regex]::Matches($raw,'(?m)^(' + $case.layoutTypePattern + ')$')
                if ($types.Count -ne 1) { throw 'Managed record layout type is not unique' }
                $type = $types[0].Value.Split(' ')[0]
                $adapted += @"

define i64 @managed_value_size() {
  ret i64 ptrtoint (ptr getelementptr ($type, ptr null, i32 1) to i64)
}
define i64 @managed_value_alignment() {
  ret i64 ptrtoint (ptr getelementptr ({ i8, $type }, ptr null, i32 0, i32 1) to i64)
}
"@
                $defines = @('-DCHECK_LAYOUT',"-DEXPECTED_SIZE=$($case.size)","-DEXPECTED_ALIGNMENT=$($case.alignment)")
                $expected = "layout:$($case.size):$($case.alignment)`n" + $expected
            }
            $adaptedIr = $stem + '-oracle.ll'
            [IO.File]::WriteAllText($adaptedIr,$adapted,(New-Object Text.UTF8Encoding($false)))
            Invoke-Oracle $adaptedIr (Join-Path $fixtures 'entry-oracle.c') $stem $expected $defines
            $hashes += (Get-ArtifactIdentity $ir).sha256
            $checks.Add([pscustomobject]@{ name = $case.name; stage = $index + 1;
                assertion = 'independent exact UBE values, stale Err and zero dead managed payload bytes after collection; target layout where specified'; passed = $true })
        }
        if ($hashes[0] -cne $hashes[1]) { throw "Raw LLVM differs: $($case.name)" }
        $checks.Add([pscustomobject]@{ name = $case.name; assertion = 'byte-identical raw LLVM through both source-built stages'; passed = $true })
    }
    $hashes = @()
    for ($index = 0; $index -lt 2; $index++) {
        $stem = Join-Path $run ('failure-boundaries-stage' + ($index + 1))
        $ir = $stem + '.ll'
        $null = Invoke-Recorded $stages[$index] @((Join-Path $fixtures 'failure-boundaries.bas'),$ir)
        $raw = [IO.File]::ReadAllText($ir)
        # This source deliberately places six ordinary procedures before its
        # declarations. Pin each bridge signature; never substitute a UBE body.
        foreach ($signature in @('void @ube.p0\(ptr [^,]+, ptr [^)]+\)',
            'void @ube.p1\(ptr [^,]+, ptr [^)]+\)','i1 @ube.p2\(ptr [^)]+\)',
            'void @ube.p3\(ptr [^,]+, ptr [^)]+\)','void @ube.p4\(ptr [^)]+\)','void @ube.p5\(ptr [^)]+\)')) {
            if ([regex]::Matches($raw,'(?m)^define ' + $signature + ' \{').Count -ne 1) { throw "Unexpected failure bridge signature: $signature" }
        }
        if ([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1) { throw 'Unrecognized failure entry wrapper' }
        $adapted = [regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @managed_unused_entry(')
        $adapted += @'

define void @managed_initialize(ptr %source, ptr %destination) {
  call void @ube.p0(ptr %source, ptr %destination)
  ret void
}
define void @managed_copy(ptr %source, ptr %destination) {
  call void @ube.p1(ptr %source, ptr %destination)
  ret void
}
define i32 @managed_grow(ptr %destination) {
  %value = call i1 @ube.p2(ptr %destination)
  %status = zext i1 %value to i32
  ret i32 %status
}
define void @managed_observe(ptr %source, ptr %destination) {
  call void @ube.p3(ptr %source, ptr %destination)
  ret void
}
define void @managed_mutate(ptr %source) {
  call void @ube.p4(ptr %source)
  ret void
}
define void @managed_growth(ptr %destination) {
  call void @ube.p5(ptr %destination)
  ret void
}
'@
        $adaptedIr = $stem + '-oracle.ll'
        [IO.File]::WriteAllText($adaptedIr,$adapted,(New-Object Text.UTF8Encoding($false)))
        Invoke-Oracle $adaptedIr (Join-Path $fixtures 'failure-oracle.c') $stem $suite.failureStdout
        $hashes += (Get-ArtifactIdentity $ir).sha256
        $checks.Add([pscustomobject]@{ name = 'failure-boundaries'; stage = $index + 1;
            assertion = 'deterministic compiled UBE copy/growth failure atomicity, fresh resize status, single-failure retry, stale Err and cleanup'; passed = $true })
    }
    if ($hashes[0] -cne $hashes[1]) { throw 'Failure-boundary raw LLVM differs' }
    $checks.Add([pscustomobject]@{ name = 'failure-boundaries'; assertion = 'byte-identical raw LLVM through both source-built stages'; passed = $true })
    $hashes = @()
    for ($index = 0; $index -lt 2; $index++) {
        $stem = Join-Path $run ('initialization-boundaries-stage' + ($index + 1))
        $ir = $stem + '.ll'
        $null = Invoke-Recorded $stages[$index] @((Join-Path $fixtures 'initialization-boundaries.bas'),$ir)
        $raw = [IO.File]::ReadAllText($ir)
        foreach ($signature in @('void @ube.p0\(ptr [^)]+\)','i32 @ube.p1\(ptr [^)]+\)',
            'void @ube.p2\(ptr [^,]+, ptr %result.out\)','void @ube.p3\(ptr [^,]+, ptr %result.out\)',
            'i32 @ube.p4\(ptr [^)]+\)','void @ube.p5\(ptr [^)]+\)','void @ube.p6\(ptr [^)]+\)')) {
            if ([regex]::Matches($raw,'(?m)^define ' + $signature + ' \{').Count -ne 1) { throw "Unexpected initialization bridge signature: $signature" }
        }
        if ([regex]::Matches($raw,'(?m)^%ube\.type\.0 = type \{\s*ptr,\s*i32\s*\}').Count -ne 1) { throw 'Unexpected initialization record layout' }
        if ([regex]::Matches($raw,'(?m)^define i32 @main\(').Count -ne 1) { throw 'Unrecognized initialization entry wrapper' }
        $adapted = [regex]::Replace($raw,'(?m)^define i32 @main\(','define i32 @managed_unused_entry(')
        $adapted += @'

define void @managed_initialize_input(ptr %source) {
  call void @ube.p0(ptr %source)
  ret void
}
define i32 @managed_inspect_copy(ptr %source) {
  %value = load ptr, ptr %source
  %result = call i32 @ube.p1(ptr %value)
  ret i32 %result
}
define void @managed_array_result(ptr %source, ptr %result) {
  call void @ube.p2(ptr %source, ptr %result)
  ret void
}
define void @managed_record_result(ptr %source, ptr %result) {
  call void @ube.p3(ptr %source, ptr %result)
  ret void
}
define i32 @managed_first_byte(ptr %source) {
  %result = call i32 @ube.p4(ptr %source)
  ret i32 %result
}
define void @managed_mutate_input(ptr %source) {
  call void @ube.p5(ptr %source)
  ret void
}
define void @managed_initialize_record(ptr %source) {
  call void @ube.p6(ptr %source)
  ret void
}
define i64 @managed_result_size() {
  ret i64 ptrtoint (ptr getelementptr (%ube.type.0, ptr null, i32 1) to i64)
}
define i64 @managed_result_alignment() {
  ret i64 ptrtoint (ptr getelementptr ({ i8, %ube.type.0 }, ptr null, i32 0, i32 1) to i64)
}
'@
        $adaptedIr = $stem + '-oracle.ll'
        [IO.File]::WriteAllText($adaptedIr,$adapted,(New-Object Text.UTF8Encoding($false)))
        Invoke-Oracle $adaptedIr (Join-Path $fixtures 'initialization-oracle.c') $stem $suite.initializationStdout
        $hashes += (Get-ArtifactIdentity $ir).sha256
        $checks.Add([pscustomobject]@{ name = 'initialization-boundaries'; stage = $index + 1;
            assertion = 'compiled ByVal/array-result/record-result failure initialization, neutral unpublished results, caller independence, stale Err, retry, actual result layout and dead payload cleanup'; passed = $true })
    }
    if ($hashes[0] -cne $hashes[1]) { throw 'Initialization-boundary raw LLVM differs' }
    $checks.Add([pscustomobject]@{ name = 'initialization-boundaries'; assertion = 'byte-identical raw LLVM through both source-built stages'; passed = $true })
    foreach ($identity in $inputs + @($selection.manifest,$selection.compiler,$selection.runtime,$selection.unicodeRuntime,$selection.clang) + @($stageOneIdentity)) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Proof input/artifact changed: $($identity.path)" }
    }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    [pscustomobject]@{ schema = 'ube-managed-values-proof-1'; success = $success; failure = $failure;
        acceptedSelection = $selection; stageOne = $stageOneIdentity; inputs = $inputs;
        checks = @($checks.ToArray()); commands = @($commands.ToArray());
        artifacts = @(Get-ChildItem -LiteralPath $run -File | ForEach-Object { Get-ArtifactIdentity $_.FullName });
        limits = 'Compiled ordinary Byte arrays and finite managed records only. No builtin String, public owned buffer, concurrent mutation, or complete language claim.' } |
        ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8
    Write-Output "Evidence: $(Join-Path $run 'report.json')"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) managed-value assertions."
