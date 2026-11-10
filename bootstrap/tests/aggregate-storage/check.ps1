# Verifies bounded arrays and finite records through binding and native execution.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube aggregate storage ' + [guid]::NewGuid())
$workingDirectory = Join-Path $artifacts 'unrelated working directory'
$null = New-Item -ItemType Directory -Path $workingDirectory -Force
$script:processNumber = 0
$script:passed = 0

# Quotes one Windows process argument, retaining literal quotes and backslashes.
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

# Runs a hidden child with a retained handle, deadline and persistent evidence.
function Invoke-BoundedProcess([string]$File, [string[]]$Arguments, [int]$TimeoutMilliseconds = 30000) {
    $script:processNumber++
    $prefix = Join-Path $artifacts ('process-' + $script:processNumber)
    $start = @{ FilePath=$File; WorkingDirectory=$workingDirectory; PassThru=$true; WindowStyle='Hidden'; RedirectStandardOutput=($prefix + '.stdout'); RedirectStandardError=($prefix + '.stderr') }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @start
    try {
        $retainedHandle = $process.Handle
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill()
            $null = $process.WaitForExit(5000)
            throw "Process timeout: $File. Evidence: $prefix"
        }
        $process.Refresh()
        if ($null -eq $process.ExitCode) { throw "No exit code for retained handle $retainedHandle" }
        return [pscustomobject]@{ ExitCode=$process.ExitCode; Stdout=[IO.File]::ReadAllText($prefix + '.stdout', $utf8); Stderr=[IO.File]::ReadAllText($prefix + '.stderr', $utf8); Evidence=$prefix }
    } finally { $process.Dispose() }
}

# Writes fixture text as strict UTF-8 independently of the host code page.
function Write-Text([string]$Path, [string]$Text) {
    $null = New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Path)) -Force
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

# Wraps a body in its native module envelope and normalizes physical newlines.
function Module-Text([string]$Name, [string]$Body) {
    return "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"$Name`"`r`n" + $Body.Replace("`r`n", "`n").Replace("`n", "`r`n")
}

# Creates an ordered Library manifest and isolated source modules for one case.
function New-Fixture([string]$Name, [string[]]$Bodies, [string[]]$ModuleNames = @('Example'), [string]$ProjectKind = 'Library') {
    $folder = Join-Path $artifacts $Name
    $lines = @('UBE-Project 1', 'Name = "SemanticFixture"', ('Kind = "' + $ProjectKind + '"'))
    if ($ProjectKind -eq 'Exe') { $lines += 'Startup = "Main"' }
    for ($i = 0; $i -lt $Bodies.Count; $i++) {
        $file = $ModuleNames[$i] + '.bas'
        Write-Text (Join-Path $folder $file) (Module-Text $ModuleNames[$i] $Bodies[$i])
        $lines += 'Source = "' + $file + '"'
    }
    $manifest = Join-Path $folder 'project.UBE'
    Write-Text $manifest (($lines -join "`r`n") + "`r`n")
    return $manifest
}

Write-Output "Artifacts retained: $artifacts"
if (-not $BootstrapExe) {
    $project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../UBE-Bootstrap.vbp'))
    $buildDirectory = Join-Path $artifacts 'build'
    $null = New-Item -ItemType Directory -Path $buildDirectory
    $buildLog = Join-Path $buildDirectory 'vb6-build.log'
    Write-Output "VB6 version: $((Get-Item -LiteralPath $VB6).VersionInfo.FileVersion)"
    $build = Invoke-BoundedProcess $VB6 @('/make', $project, '/out', $buildLog, '/outdir', $buildDirectory)
    if (Test-Path -LiteralPath $buildLog) { Get-Content -LiteralPath $buildLog }
    $BootstrapExe = Join-Path $buildDirectory 'UBE-Bootstrap.exe'
    if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $BootstrapExe)) { throw "VB6 build failed. Evidence: $buildDirectory" }
}
$BootstrapExe = [IO.Path]::GetFullPath($BootstrapExe)
if (-not (Test-Path -LiteralPath $BootstrapExe)) { throw "Bootstrap executable not found: $BootstrapExe" }

# Stops the gate when a native acceptance assertion fails.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Verifies the DOS/PE headers and AMD64 machine field before executing output.
function Assert-X64([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    Require ($bytes.Length -ge 64 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) 'Invalid DOS executable header'
    $offset = [BitConverter]::ToInt32($bytes, 0x3c)
    Require ($offset -ge 64 -and $offset -le $bytes.Length - 6) 'Invalid PE header offset'
    Require ([BitConverter]::ToUInt32($bytes, $offset) -eq 0x4550 -and [BitConverter]::ToUInt16($bytes, $offset + 4) -eq 0x8664) 'Expected x64 PE output'
}

# Requires an emission/build command to publish its stated success marker.
function Invoke-Compiler([string[]]$Arguments, [string]$Marker) {
    $result = Invoke-BoundedProcess $BootstrapExe $Arguments
    Require ($result.ExitCode -eq 0 -and $result.Stderr.Length -eq 0 -and $result.Stdout -match ('(?m)^' + [regex]::Escape($Marker) + '\r?$')) "Compiler failed. Evidence: $($result.Evidence)"
    return $result
}

# Compiles the same generated library+harness IR at a selected optimization level.
function Build-Harness([string]$IR, [string]$Exe, [string]$Level) {
    $result = Invoke-BoundedProcess $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR,'-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
    Require ($result.ExitCode -eq 0) "Native harness build failed. Evidence: $($result.Evidence)"
    Assert-X64 $Exe
}

# Retains original module text while making a manifest for checked-in fixtures.
function Copy-Fixtures([string]$Name, [string[]]$Files, [string]$Level = '2', [string]$Kind = 'Exe') {
    $folder = Join-Path $artifacts $Name
    $lines = @('UBE-Project 1', 'Name = "NativeFixture"', ('Kind = "' + $Kind + '"'), ('Optimization = "' + $Level + '"'))
    if ($Kind -eq 'Exe') { $lines += 'Startup = "Main"' }
    foreach ($file in $Files) {
        $leaf = [IO.Path]::GetFileName($file)
        Write-Text (Join-Path $folder $leaf) ([IO.File]::ReadAllText($file, $utf8))
        $lines += 'Source = "' + $leaf + '"'
    }
    $manifest = Join-Path $folder 'project.UBE'
    Write-Text $manifest (($lines -join "`r`n") + "`r`n")
    return $manifest
}

# Requires controlled failure and verifies an existing valid artifact is unchanged.
function Assert-PreservedFailure([string]$Name, [string[]]$Arguments, [string]$Code, [string]$Artifact, [int]$TimeoutMilliseconds = 30000) {
    $before = (Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash
    $result = Invoke-BoundedProcess $BootstrapExe $Arguments $TimeoutMilliseconds
    Require ($result.ExitCode -eq 1 -and $result.Stderr -match ('(?m)^UBE: ' + [regex]::Escape($Code) + ':') -and $result.Stdout -notmatch '(?m)^(BUILD OK|EMIT OK)\r?$') "$Name failure mismatch. Evidence: $($result.Evidence)"
    Require ((Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash -ceq $before) "$Name changed prior artifact"
    $script:passed++
    Write-Output "PASS: $Name preserves prior artifact"
}

# Decodes dump delimiters without treating an escaped pipe as a new field.
function Decode-Fields([string]$Record) {
    $fields = New-Object 'Collections.Generic.List[string]'
    $field = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $Record.Length; $i++) {
        $character = $Record[$i]
        if ($character -eq '\') {
            $i++
            Require ($i -lt $Record.Length) 'Truncated dump escape'
            switch ($Record[$i]) {
                '\' { $null = $field.Append('\') }
                'p' { $null = $field.Append('|') }
                'r' { $null = $field.Append("`r") }
                'n' { $null = $field.Append("`n") }
                default { throw 'Unknown dump escape' }
            }
        } elseif ($character -eq '|') {
            $fields.Add($field.ToString())
            $null = $field.Clear()
        } else { $null = $field.Append($character) }
    }
    $fields.Add($field.ToString())
    return $fields.ToArray()
}

# Reconstructs aggregate metadata while preserving the established scalar columns.
function Read-Bindings([string]$Manifest) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$Manifest)
    Require ($result.ExitCode -eq 0 -and $result.Stderr.Length -eq 0) "Binding failed: $($result.Evidence)"
    $symbols = @{}
    $nodes = @{}
    foreach ($line in $result.Stdout.Replace("`r`n","`n").Split("`n")) {
        if ($line.StartsWith('SYMBOL ')) {
            $f = @(Decode-Fields $line.Substring(7))
            Require ($f.Count -eq 24) 'Invalid aggregate symbol framing'
            $symbols[[int]$f[0]] = [pscustomobject]@{ Id=[int]$f[0]; Kind=$f[1]; Name=$f[2]; Type=$f[3]; Module=[int]$f[5]; Scope=[int]$f[6]; Declaration=[int]$f[7]; Mode=$f[8]; TypeSymbol=[int]$f[14]; Rank=[int]$f[15]; HasBounds=$f[16]; Lower=$f[17]; Upper=$f[18]; ElementCells=[int]$f[19]; StorageCells=[int]$f[20]; Offset=[int]$f[21]; FirstField=[int]$f[22]; NextField=[int]$f[23] }
        } elseif ($line.StartsWith('BOUND ')) {
            $f = @(Decode-Fields $line.Substring(6))
            Require ($f.Count -eq 16) 'Invalid aggregate binding framing'
            $nodes[[int]$f[0]] = [pscustomobject]@{ Id=[int]$f[0]; Symbol=[int]$f[1]; Type=$f[2]; Converted=$f[3]; Mode=$f[4]; Writable=$f[5]; Scope=[int]$f[7]; TypeSymbol=[int]$f[8]; Rank=[int]$f[9]; HasBounds=$f[10]; Lower=$f[11]; Upper=$f[12]; ElementCells=[int]$f[13]; StorageCells=[int]$f[14]; Access=$f[15] }
        }
    }
    return [pscustomobject]@{ Symbols=$symbols; Nodes=$nodes }
}

# Selects one source declaration by kind and name without confusing result storage.
function Find-Symbol($Bound, [string]$Kind, [string]$Name) {
    $found = @($Bound.Symbols.Values | Where-Object { $_.Name -ieq $Name -and $_.Kind -eq $Kind })
    Require ($found.Count -eq 1) "Expected one $Kind $Name"
    return $found[0]
}

# Requires a semantic/profile rejection with an actionable physical source location.
function Assert-Rejected([string]$Name, [string]$Body, [string]$Code) {
    $manifest = New-Fixture $Name @($Body) @('Example') 'Library'
    $result = Invoke-BoundedProcess $BootstrapExe @('--analyze',$manifest)
    Require ($result.ExitCode -eq 1 -and $result.Stderr -match ('(?m)^UBE: ' + [regex]::Escape($Code) + ':') -and $result.Stderr -match 'Example\.bas:\d+:\d+' -and $result.Stdout -notmatch 'ANALYZE OK') "$Name expected $Code with location. Evidence: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: $Name"
}

$manifest = Copy-Fixtures 'aggregate library' @((Join-Path $PSScriptRoot 'fixtures/StorageProbe.bas'),(Join-Path $PSScriptRoot 'fixtures/QuotedTypes.bas')) '0' 'Library'
$bound = Read-Bindings $manifest
$token = Find-Symbol $bound 'type' 'Token'
$nodeType = Find-Symbol $bound 'type' 'Node'
Require ($token.Id -ne $nodeType.Id) 'Distinct nominal records share an identity'
$fields = @()
$fieldId = $token.FirstField
$seenFields = @{}
while ($fieldId -ne 0) {
    Require (-not $seenFields.ContainsKey($fieldId) -and $bound.Symbols.ContainsKey($fieldId)) 'Broken or cyclic record field chain'
    $seenFields[$fieldId] = $true
    $field = $bound.Symbols[$fieldId]
    Require ($field.Scope -eq $token.Id) 'Field owner is not its nominal Type'
    Require ($bound.Nodes[$field.Declaration].Scope -eq $token.Id) 'Field declaration binding scope differs from its owning Type'
    $fields += $field
    $fieldId = $field.NextField
}
Require ($fields.Count -eq 3 -and $fields[0].Name -eq 'Start' -and $fields[0].Type -eq 'LongLong' -and $fields[1].Name -eq 'Length' -and $fields[1].Type -eq 'Long' -and $fields[2].Name -eq 'Kind' -and $fields[2].Type -eq 'Integer') 'Record field order/types mismatch'
Require ($fields[0].Offset -lt $fields[1].Offset -and $fields[1].Offset -lt $fields[2].Offset) 'Record fields overlap or reorder'
$tokenArrays = @($bound.Symbols.Values | Where-Object { $_.Kind -eq 'variable' -and $_.Name -eq 'Tokens' -and $_.HasBounds -eq '1' -and $_.Lower -eq '-1' })
Require ($tokenArrays.Count -eq 1 -and $tokenArrays[0].Rank -eq 1 -and $tokenArrays[0].Upper -eq '1' -and $tokenArrays[0].TypeSymbol -eq $token.Id -and $tokenArrays[0].ElementCells -gt 0) 'Array bounds or nominal element identity mismatch'
$parameter = Find-Symbol $bound 'parameter' 'Values'
Require ($parameter.Rank -eq 1 -and $parameter.HasBounds -eq '0' -and $parameter.Mode -eq 'ByRef' -and $parameter.Type -eq 'Byte') 'Rank-only Byte array parameter incorrectly acquired fixed bounds'
Require (@($bound.Nodes.Values | Where-Object { $_.Access -eq 'index' -and $_.Writable -eq '1' }).Count -gt 0) 'No writable index bindings'
Require (@($bound.Nodes.Values | Where-Object { $_.Access -eq 'field' -and $_.Mode -eq 'alias' }).Count -gt 0) 'Record field ByRef alias identity missing'
$script:passed++
Write-Output 'PASS: nominal fields, ordered layout, array bounds and exact field/index bindings'
$shadowType = Find-Symbol $bound 'type' 'Long'
$pipeType = Find-Symbol $bound 'type' 'A|B'
$custom = Find-Symbol $bound 'variable' 'Custom'
$piped = Find-Symbol $bound 'variable' 'Piped'
$primitive = Find-Symbol $bound 'variable' 'Primitive'
Require ($custom.TypeSymbol -eq $shadowType.Id -and $custom.TypeSymbol -ne 0 -and $primitive.TypeSymbol -eq 0 -and $primitive.Type -eq 'Long') 'Bracketed Long did not resolve nominally alongside primitive Long'
Require ($piped.TypeSymbol -eq $pipeType.Id -and $piped.Type.Contains('A|B')) 'Escaped nominal Type name was not retained in symbol metadata'
Require (@($bound.Nodes.Values | Where-Object { $_.TypeSymbol -eq $pipeType.Id -and $_.Type.Contains('A|B') }).Count -gt 0) 'Escaped Type name missing from bound records'
$ast = Invoke-BoundedProcess $BootstrapExe @('--dump-ast',$manifest)
Require ($ast.ExitCode -eq 0) 'Cannot inspect bracketed Type AST'
$pipedAstFound = $false
foreach ($line in $ast.Stdout.Replace("`r`n","`n").Split("`n")) {
    if ($line.StartsWith('NODE ')) {
        $f = @(Decode-Fields $line.Substring(5))
        Require ($f.Count -eq 13) 'Escaped AST Type name broke record framing'
        if ($f[1] -eq 'variable' -and $f[2] -eq 'Piped') { $pipedAstFound = $f[9].Contains('A|B') }
    }
}
Require $pipedAstFound 'AST lost bracketed pipe Type annotation'
$script:passed++
Write-Output 'PASS: bracketed intrinsic-name Type identity and escaped nominal dump fields'

$ir = Join-Path $artifacts 'aggregate.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$checks = @('CheckStorage','CheckAliases','CheckBounds','CheckBracketed')
$harness = @('@test.input = global i64 1','@test.context = private global %ube.context zeroinitializer, align 8','define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0')
$prior = '0'
for ($index = 0; $index -lt $checks.Count; $index++) {
    $symbol = Find-Symbol $bound 'function' $checks[$index]
    $bit = 1 -shl $index
    $harness += @('  call void @ube.context.init(ptr %ctx)',"  %init$index = call i1 @ube.project.init(ptr %ctx)","  %input$index = load volatile i64, ptr @test.input","  %pair$index = call { i1, i64 } @ube.proc.$($symbol.Id)(ptr %ctx, i64 %input$index)","  %ok$index = extractvalue { i1, i64 } %pair$index, 0","  %value$index = extractvalue { i1, i64 } %pair$index, 1","  %zero$index = icmp eq i64 %value$index, 0","  %good$index = and i1 %ok$index, %zero$index","  %ready$index = and i1 %good$index, %init$index","  %fail$index = select i1 %ready$index, i32 0, i32 $bit","  %mask$index = or i32 $prior, %fail$index")
    $prior = '%mask' + $index
}
$harness += @("  ret i32 $prior",'}')
$combined = Join-Path $artifacts 'aggregate-with-harness.ll'
Write-Text $combined ([IO.File]::ReadAllText($ir,$utf8) + "`r`n" + ($harness -join "`r`n") + "`r`n")
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ('aggregate-' + $level + '.exe')
    Build-Harness $combined $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Aggregate runtime failed at $level; mask=$($result.ExitCode) (1 storage/tree,2 aliases,4 bounds,8 bracketed types). Evidence: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: retained source bytes/tree, value copies, aliases and checked bounds $level"
}
$control = Join-Path $artifacts 'aggregate-input-two.ll'
Write-Text $control ([IO.File]::ReadAllText($combined,$utf8).Replace('@test.input = global i64 1','@test.input = global i64 2'))
$controlExe = Join-Path $artifacts 'aggregate-input-two.exe'
Build-Harness $control $controlExe 'O2'
$controlRun = Invoke-BoundedProcess $controlExe @()
Require ($controlRun.ExitCode -eq 1) "Changed tree start must fail the retained-tree oracle only; received $($controlRun.ExitCode)"
$script:passed++
Write-Output 'PASS: changed runtime tree input is detected by the source oracle'

$typeA = "Type FirstType`nValue As Long`nEnd Type`n"
$typeB = "Type SecondType`nValue As Long`nEnd Type`n"
$negative = @(
    @{ Name='nominal record assignment'; Body=($typeA + $typeB + "Sub Run()`nDim A As FirstType`nDim B As SecondType`nA = B`nEnd Sub"); Code='E_TYPE' },
    @{ Name='nominal record ByRef'; Body=($typeA + $typeB + "Sub Take(ByRef A As FirstType)`nEnd Sub`nSub Run()`nDim B As SecondType`nTake B`nEnd Sub"); Code='E_ARGUMENT' },
    @{ Name='unknown field'; Body=($typeA + "Sub Run()`nDim A As FirstType`nA.Missing = 1`nEnd Sub"); Code='E_NAME' },
    @{ Name='record ordering'; Body=($typeA + "Sub Run()`nDim A As FirstType`nDim B As FirstType`nDim Flag As Boolean = A < B`nEnd Sub"); Code='E_TYPE' },
    @{ Name='different element array assignment'; Body="Sub Run()`nDim A(0 To 1) As Byte`nDim B(0 To 1) As Integer`nA = B`nEnd Sub"; Code='E_TYPE' },
    @{ Name='scalar suffix cannot annotate array use'; Body="Sub Run()`nDim A(0 To 1) As Long`nDim V As Long = A&(0)`nEnd Sub"; Code='E_TYPE' },
    @{ Name='different element array ByRef'; Body="Sub Take(ByRef A() As Integer)`nEnd Sub`nSub Run()`nDim B(0 To 1) As Byte`nTake B`nEnd Sub"; Code='E_ARGUMENT' },
    @{ Name='different bounds copy deferred'; Body="Sub Run()`nDim A(0 To 1) As Byte`nDim B(-1 To 0) As Byte`nA = B`nEnd Sub"; Code='E_UNSUPPORTED' },
    @{ Name='unknown bounds copy deferred'; Body="Sub Copy(ByRef A() As Byte, ByRef B() As Byte)`nA = B`nEnd Sub"; Code='E_UNSUPPORTED' },
    @{ Name='known invalid index'; Body="Sub Run()`nDim A(-1 To 1) As Byte`nA(2) = 1`nEnd Sub"; Code='E_CONSTANT' },
    @{ Name='inverted bounds'; Body='Dim A(1 To -1) As Byte'; Code='E_CONSTANT' },
    @{ Name='array element count bound'; Body='Dim A(0 To 4096) As Byte'; Code='E_LIMIT' },
    @{ Name='dynamic array deferred'; Body='Dim A() As Byte'; Code='E_UNSUPPORTED' },
    @{ Name='multidimensional array deferred'; Body='Dim A(0 To 1, 0 To 1) As Byte'; Code='E_UNSUPPORTED' },
    @{ Name='ReDim deferred'; Body="Sub Run()`nDim A(0 To 1) As Byte`nReDim A(0 To 2)`nEnd Sub"; Code='E_UNSUPPORTED' },
    @{ Name='recursive record deferred'; Body="Type Link`nNextLink As Link`nEnd Type"; Code='E_UNSUPPORTED' },
    @{ Name='record array field deferred'; Body="Type Buffer`nValues(0 To 1) As Byte`nEnd Type"; Code='E_UNSUPPORTED' },
    @{ Name='managed field deferred'; Body="Type Buffer`nValue As String`nEnd Type"; Code='E_UNSUPPORTED' },
    @{ Name='record ByVal deferred'; Body=($typeA + "Sub Take(ByVal A As FirstType)`nEnd Sub"); Code='E_UNSUPPORTED' },
    @{ Name='array ByVal deferred'; Body="Sub Take(ByVal A() As Byte)`nEnd Sub"; Code='E_UNSUPPORTED' },
    @{ Name='record result deferred'; Body=($typeA + "Function MakeValue() As FirstType`nEnd Function"); Code='E_UNSUPPORTED' },
    @{ Name='array result deferred'; Body="Function MakeValue() As Byte()`nEnd Function"; Code='E_UNSUPPORTED' },
    @{ Name='grouped record ByRef deferred'; Body=($typeA + "Sub Take(ByRef A As FirstType)`nEnd Sub`nSub Run()`nDim A As FirstType`nTake (A)`nEnd Sub"); Code='E_UNSUPPORTED' },
    @{ Name='grouped array ByRef deferred'; Body="Sub Take(ByRef A() As Byte)`nEnd Sub`nSub Run()`nDim A(0 To 1) As Byte`nTake (A)`nEnd Sub"; Code='E_UNSUPPORTED' },
    @{ Name='duplicate casefold field'; Body="Type Data`nValue As Long`nvAlUe As Long`nEnd Type"; Code='E_DUPLICATE' },
    @{ Name='empty Type'; Body="Type Data`nEnd Type"; Code='E_PARSE' },
    @{ Name='field initializer forbidden'; Body="Type Data`nValue As Long = 1`nEnd Type"; Code='E_PARSE' }
)
foreach ($case in $negative) { Assert-Rejected $case.Name $case.Body $case.Code }
$oversizedRecord = "Type WideRecord`n" + ((1..129 | ForEach-Object { 'Field' + $_ + ' As Long' }) -join "`n") + "`nEnd Type"
Assert-Rejected 'flattened record cell limit' $oversizedRecord 'E_LIMIT'
$deepTypes = @()
for ($depth = 0; $depth -lt 65; $depth++) {
    $fieldType = 'Long'
    if ($depth -lt 64) { $fieldType = 'Depth' + ($depth + 1) }
    $deepTypes += @("Type Depth$depth", "Value As $fieldType", 'End Type')
}
Assert-Rejected 'forward record layout depth limit' ($deepTypes -join "`n") 'E_LIMIT'
$privateManifest = New-Fixture 'private qualified Type' @("Sub Run()`nDim Value As Secret.Hidden`nEnd Sub", "Private Type Hidden`nValue As Long`nEnd Type") @('Program','Secret') 'Library'
$privateResult = Invoke-BoundedProcess $BootstrapExe @('--analyze',$privateManifest)
Require ($privateResult.ExitCode -eq 1 -and $privateResult.Stderr -match '(?m)^UBE: E_NAME:' -and $privateResult.Stderr -match 'Program\.bas:\d+:\d+') 'Private Type was visible from another module'
$script:passed++
Write-Output 'PASS: private nominal Type inaccessible across modules'
$contextDeclarations = ((1..17 | ForEach-Object { 'Private Values' + $_ + '(0 To 4095) As LongLong' }) -join "`n")
$contextManifest = New-Fixture 'module aggregate context limit' @($contextDeclarations) @('Example') 'Library'
$beforeContext = (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
$contextResult = Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$contextManifest,$ir)
Require ($contextResult.ExitCode -eq 1 -and $contextResult.Stderr -match '(?m)^UBE: E_LIMIT:' -and $contextResult.Stderr -match 'native module storage context limit exceeded' -and $contextResult.Stdout -notmatch 'EMIT OK') 'Module context exceeded limit without its specific controlled diagnostic'
Require ((Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash -eq $beforeContext) 'Context limit rejection modified previous artifact'
$script:passed++
Write-Output 'PASS: module storage context limit rejects before publication'
$frameManifest = New-Fixture 'aggregate copy scratch frame limit' @("Sub Run()`nDim First(0 To 40) As Long`nDim Second(0 To 40) As Long`nSecond = First`nEnd Sub") @('Example') 'Library'
$beforeFrame = (Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash
$frameResult = Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$frameManifest,$ir)
Require ($frameResult.ExitCode -eq 1 -and $frameResult.Stderr -match '(?m)^UBE: E_LIMIT:' -and $frameResult.Stderr -match 'native storage/temporary frame limit exceeded' -and $frameResult.Stdout -notmatch 'EMIT OK') 'Aggregate copy scratch was omitted from native frame accounting'
Require ((Get-FileHash -LiteralPath $ir -Algorithm SHA256).Hash -eq $beforeFrame) 'Frame limit rejection modified previous artifact'
$script:passed++
Write-Output 'PASS: native frame limit includes aggregate copy snapshot cells'
$invalid = New-Fixture 'invalid aggregate publication' @('Dim A(1 To -1) As Byte') @('Example') 'Library'
Assert-PreservedFailure 'aggregate diagnostic' @('--emit-llvm',$invalid,$ir) 'E_CONSTANT' $ir
Write-Output "PASS: $($script:passed) aggregate storage groups; fixed storage only, no heap allocation claims."
