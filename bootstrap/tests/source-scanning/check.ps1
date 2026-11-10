# Verifies the actual UBE source scanner, physical spans and controlled diagnostics.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube source scanning ' + [guid]::NewGuid())
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

. (Join-Path $PSScriptRoot '../NativeMemory.ps1')
# Compiles the same generated library+harness IR at a selected optimization level.
function Build-Harness([string]$IR, [string]$Exe, [string]$Level) {
    $linkArguments = @(Get-NativeMemoryLinkArguments $IR $Clang $artifacts)
    $arguments = @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR) + $linkArguments + @('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608')
    $result = Invoke-BoundedProcess $Clang $arguments
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

# Resolves compiler-owned procedure identifiers from the unchanged bound dump.
function Read-Procedures([string]$Manifest) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$Manifest)
    Require ($result.ExitCode -eq 0) "Binding failed: $($result.Evidence)"
    $procedures = @{}
    foreach ($line in $result.Stdout.Split("`n")) {
        if ($line.StartsWith('SYMBOL ')) {
            $fields = $line.TrimEnd("`r").Substring(7).Split('|')
            Require ($fields.Count -eq 24) 'Unexpected bound symbol framing'
            if ($fields[1] -eq 'function') { $procedures[$fields[2]] = [int]$fields[0] }
        }
    }
    return $procedures
}

$coreDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$scannerSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src/SourceScanner.bas'))
$manifest = Copy-Fixtures 'scanner library' @((Join-Path $coreDirectory 'BufferPrimitives.bas'),(Join-Path $coreDirectory 'FilePrimitives.bas'),(Join-Path $coreDirectory 'FileBytes.bas'),(Join-Path $coreDirectory 'Utf8.bas'),$scannerSource,(Join-Path $PSScriptRoot 'ScannerProbe.bas'),(Join-Path $PSScriptRoot 'ControlFlowProbe.bas')) '0' 'Library'
$procedures = Read-Procedures $manifest
$ir = Join-Path $artifacts 'source-scanner.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$emitted = [IO.File]::ReadAllText($ir,$utf8)

# Builds expected records from explicitly authored token chunks, never by lexing the input.
function New-TokenCase([string]$Name, [object[]]$Parts, [bool]$Bom = $false) {
    if ($Parts.Count -eq 2 -and $Parts[0] -is [int]) { $Parts = @(,$Parts) }
    $text = New-Object Text.StringBuilder
    $byteOffset = 0
    $unitOffset = 1
    $line = 1
    $column = 1
    if ($Bom) { [void]$text.Append([char]0xFEFF); $byteOffset = 3 }
    $records = New-Object 'System.Collections.Generic.List[object]'
    foreach ($part in $Parts) {
        $kind = [int]$part[0]
        $spelling = [string]$part[1]
        $bytes = $utf8.GetByteCount($spelling)
        if ($kind -gt 0) { $records.Add(@($kind,$byteOffset,$bytes,$line,$column,$unitOffset,$spelling.Length)) }
        [void]$text.Append($spelling)
        $byteOffset += $bytes
        $unitOffset += $spelling.Length
        $lastNewline = $spelling.LastIndexOf([char]10)
        if ($lastNewline -ge 0) { $line += ([regex]::Matches($spelling,[string][char]10)).Count; $column = $spelling.Length - $lastNewline } else { $column += $spelling.Length }
    }
    if ($records.Count -eq 0 -or $records[$records.Count - 1][0] -ne 6) { $records.Add(@(6,$byteOffset,0,$line,$column,$unitOffset,0)) }
    $records.Add(@(7,$byteOffset,0,$line,$column,$unitOffset,0))
    return [pscustomobject]@{ Name=$Name; Bytes=$utf8.GetBytes($text.ToString()); Tokens=$records.ToArray(); Diagnostic=@(0,0,0,1,1,1); Status=0 }
}
# Describes a malformed input with an independently specified first physical diagnostic.
function New-RejectedCase([string]$Name, [byte[]]$Bytes, [long[]]$Diagnostic) {
    return [pscustomobject]@{ Name=$Name; Bytes=$Bytes; Tokens=@(); Diagnostic=$Diagnostic; Status=1 }
}

# Installs a real input path through ordinary UBE calls in one native helper.
function Path-Initializer([string]$Path) {
    $bytes = $utf8.GetBytes($Path)
    $lines = @('define i1 @test.path(ptr %ctx) {','entry:',"  %pair = call { i1, i64 } @ube.proc.$($procedures['ConfigurePath'])(ptr %ctx, i64 $($bytes.Length))",'  %ok = extractvalue { i1, i64 } %pair, 0','  %value = extractvalue { i1, i64 } %pair, 1','  %zero = icmp eq i64 %value, 0','  %good = and i1 %ok, %zero')
    for ($index = 0; $index -lt $bytes.Length; $index++) { $lines += "  %byte$index = call { i1, i64 } @ube.proc.$($procedures['SetPathByte'])(ptr %ctx, i64 $index, i64 $($bytes[$index]))" }
    return $lines + @('  ret i1 %good','}')
}

# Compares every retained field through source getters using a constant expected-record table.
function Token-Comparator {
    $lines = @('define i1 @test.token(ptr %ctx, i64 %index, ptr %expected) {','entry:')
    $prior = 'true'
    for ($field = 0; $field -lt 7; $field++) {
        $lines += @("  %pair$field = call { i1, i64 } @ube.proc.$($procedures['TokenField'])(ptr %ctx, i64 %index, i64 $field)","  %ok$field = extractvalue { i1, i64 } %pair$field, 0", "  %value$field = extractvalue { i1, i64 } %pair$field, 1", "  %pointer$field = getelementptr i64, ptr %expected, i64 $field", "  %expected$field = load i64, ptr %pointer$field", "  %equal$field = icmp eq i64 %value$field, %expected$field", "  %good$field = and i1 %ok$field, %equal$field", "  %valid$field = and i1 $prior, %good$field")
        $prior = '%valid' + $field
    }
    return $lines + @("  ret i1 $prior",'}')
}

# Runs one complete file-backed scan and exact diagnostic/token comparison at both optimizations.
function Assert-ScanCase($Case) {
    $number = $script:passed
    $input = Join-Path $artifacts ("source-$number.bas")
    [IO.File]::WriteAllBytes($input,[byte[]]$Case.Bytes)
    $records = @($Case.Tokens)
    $rows = @($records | ForEach-Object { '[7 x i64] [' + (($_ | ForEach-Object { 'i64 ' + $_ }) -join ', ') + ']' })
    $count = $records.Count
    $lines = @(("@test.expected = private constant [$count x [7 x i64]] [" + ($rows -join ', ') + ']'), '@test.context = private global %ube.context zeroinitializer, align 8')
    $lines += @(Path-Initializer $input)
    $lines += @(Token-Comparator)
    $lines += @('define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0','  call void @ube.context.init(ptr %ctx)','  %init = call i1 @ube.project.init(ptr %ctx)','  %path = call i1 @test.path(ptr %ctx)',"  %scan = call { i1, i64 } @ube.proc.$($procedures['LoadAndScan'])(ptr %ctx)",'  %scan.ok = extractvalue { i1, i64 } %scan, 0','  %scan.value = extractvalue { i1, i64 } %scan, 1',"  %scan.match = icmp eq i64 %scan.value, $($Case.Status)",'  %scan.good = and i1 %scan.ok, %scan.match',"  %count.pair = call { i1, i64 } @ube.proc.$($procedures['TokenCount'])(ptr %ctx)",'  %count.ok = extractvalue { i1, i64 } %count.pair, 0','  %count.value = extractvalue { i1, i64 } %count.pair, 1',"  %count.match = icmp eq i64 %count.value, $count",'  %count.good = and i1 %count.ok, %count.match','  %setup = and i1 %init, %path','  %outcome = and i1 %scan.good, %count.good','  %start = and i1 %setup, %outcome')
    $prior = '%start'
    for ($field = 0; $field -lt 6; $field++) {
        $lines += @("  %diag$field = call { i1, i64 } @ube.proc.$($procedures['DiagnosticField'])(ptr %ctx, i64 $field)","  %diag.ok$field = extractvalue { i1, i64 } %diag$field, 0", "  %diag.value$field = extractvalue { i1, i64 } %diag$field, 1", "  %diag.match$field = icmp eq i64 %diag.value$field, $($Case.Diagnostic[$field])", "  %diag.good$field = and i1 %diag.ok$field, %diag.match$field", "  %diag.valid$field = and i1 $prior, %diag.good$field")
        $prior = '%diag.valid' + $field
    }
    $lines += @('  br label %check','check:','  %index = phi i64 [ 0, %entry ], [ %next, %body ]',"  %valid = phi i1 [ $prior, %entry ], [ %next.valid, %body ]", "  %more = icmp ult i64 %index, $count",'  br i1 %more, label %body, label %finish','body:',"  %row = getelementptr [$count x [7 x i64]], ptr @test.expected, i64 0, i64 %index",'  %token.good = call i1 @test.token(ptr %ctx, i64 %index, ptr %row)','  %next.valid = and i1 %valid, %token.good','  %next = add i64 %index, 1','  br label %check','finish:','  %disposed = call i1 @ube.context.dispose(ptr %ctx)','  %all = and i1 %valid, %disposed','  %exit = select i1 %all, i32 0, i32 1','  ret i32 %exit','}')
    $combined = Join-Path $artifacts ("scan-$number.ll")
    Write-Text $combined ($emitted + "`r`n" + ($lines -join "`r`n") + "`r`n")
    foreach ($level in @('O0','O2')) {
        $exe = Join-Path $artifacts ("scan-$number-$level.exe")
        Build-Harness $combined $exe $level
        $result = Invoke-BoundedProcess $exe @()
        Require ($result.ExitCode -eq 0) "$($Case.Name) $level failed: $($result.Evidence)"
        $script:passed++
        Write-Output "PASS: $($Case.Name) $level; exact token fields and diagnostic"
    }
    if ($Case.Name -eq 'runtime source identity control') {
        [IO.File]::WriteAllBytes((Join-Path $artifacts 'negative-control-bytes.bas'),[byte[]]@(43))
        [IO.File]::WriteAllBytes($input,[byte[]]@(43))
        try {
            $result = Invoke-BoundedProcess $exe @()
            Require ($result.ExitCode -eq 1) 'Changing actual source word x into symbol + must fail the unchanged token oracle'
        } finally { [IO.File]::WriteAllBytes($input,[byte[]]$Case.Bytes) }
        $script:passed++
        Write-Output 'PASS: changed on-disk token kind rejected by the unchanged native oracle'
    }
}

$cases = New-Object 'System.Collections.Generic.List[object]'
$cases.Add((New-TokenCase 'empty source' @()))
$cases.Add((New-TokenCase 'runtime source identity control' @(@(1,'x'))))
$cases.Add((New-TokenCase 'native envelope CRLF' @(@(1,'UBE'),@(0,' '),@(1,'SOURCE'),@(0,' '),@(3,'1'),@(0,' '),@(1,'MODULE'),@(6,"`r`n"),@(1,'Attribute'),@(0,' '),@(1,'UBE_Name'),@(0,' '),@(5,'='),@(0,' '),@(4,'"Example"'),@(6,"`r`n"))))
$sample = New-TokenCase 'checked-in Arithmetic module' @(@(1,'UBE'),@(0,' '),@(1,'SOURCE'),@(0,' '),@(3,'1'),@(0,' '),@(1,'MODULE'),@(6,"`n"),@(1,'Attribute'),@(0,' '),@(1,'UBE_Name'),@(0,' '),@(5,'='),@(0,' '),@(4,'"Arithmetic"'),@(6,"`n"),@(0,"' Supplies a value to the separate program module."),@(6,"`n"),@(1,'Option'),@(0,' '),@(1,'Explicit'),@(6,"`n"),@(6,"`n"),@(0,"' Returns the sample program's expected result."),@(6,"`n"),@(1,'Public'),@(0,' '),@(1,'Function'),@(0,' '),@(1,'Answer'),@(5,'('),@(5,')'),@(0,' '),@(1,'As'),@(0,' '),@(1,'Long'),@(6,"`n"),@(0,'    '),@(1,'Answer'),@(0,' '),@(5,'='),@(0,' '),@(3,'42'),@(6,"`n"),@(1,'End'),@(0,' '),@(1,'Function'),@(6,"`n"))
$sampleBytes = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot '../../examples/multi-module/src/Arithmetic.bas'))
Require ([Convert]::ToBase64String($sampleBytes) -ceq [Convert]::ToBase64String($sample.Bytes)) 'Checked-in Arithmetic source changed; update its independent token expectations explicitly'
$sample.Bytes = $sampleBytes
$cases.Add($sample)
$numberParts = New-Object 'System.Collections.Generic.List[object]'
foreach ($spelling in @('1&','1%','2^','&Hff&','&O77','.5','12.','1e-3','7F','8!','9#','10@','11R','12D')) { $numberParts.Add(@(3,$spelling)); $numberParts.Add(@(0,' ')) }
$cases.Add((New-TokenCase 'numeric spellings and suffixes' $numberParts.ToArray()))
$cases.Add((New-TokenCase 'operators and literal adjacency' @(@(3,'1'),@(0,' '),@(5,'&'),@(0,' '),@(1,'x'),@(5,':='),@(3,'2'),@(5,'<='),@(3,'3'),@(5,'<>'),@(3,'4'),@(5,'>='),@(3,'5'),@(5,'('),@(1,'a'),@(5,':'),@(1,'b'),@(5,')'),@(5,'!'),@(5,'$'))))
$unicode = [string][char]0x00E9 + [char]0xD83D + [char]0xDE00
$cases.Add((New-TokenCase 'quoted Unicode BOM and bracket escapes' @(@(4,('"a""' + $unicode + '"')),@(0,' '),@(2,'[a]]b]'),@(6,"`n"),@(1,'x')) $true))
$cases.Add((New-TokenCase 'physical continuation spans' @(@(1,'x'),@(0,' '),@(5,'='),@(0,' '),@(3,'1'),@(0," _ ' joined`r`n  "),@(5,'+'),@(0,' '),@(3,'2'),@(6,"`n"))))
$cases.Add((New-TokenCase 'Rem contexts and member keywords' @(@(0,"Rem first"),@(6,"`n"),@(3,'10'),@(0,' Rem label'),@(6,"`n"),@(1,'If'),@(0,' '),@(1,'True'),@(0,' '),@(1,'Then'),@(0,' Rem inline'),@(6,"`n"),@(1,'Thing'),@(5,'.'),@(1,'Then'),@(0,' '),@(1,'Rem'),@(0,' '),@(1,'text'),@(6,"`n"),@(1,'x'),@(5,':'),@(0,' Rem after colon'))))
$cases.Add((New-TokenCase 'comments retain final physical EOF' @(@(1,'x'),@(6,"`n"),@(0,('  '' ' + $unicode)))))
$cases.Add((New-TokenCase '128 character identifier' @(@(1,('a' * 128)))))
$cases.Add((New-TokenCase '128 decoded bracket characters' @(@(2,('[' + ('a' * 127) + ']]]')))))
$cases.Add((New-TokenCase '4096 byte quoted token' @(@(4,('"' + ('a' * 4094) + '"')))))
$cases.Add((New-TokenCase 'one MiB comment and synthetic EOF' @(@(0,("'" + ('a' * 1048575))))))
$limitParts = New-Object 'System.Collections.Generic.List[object]'
for ($index = 0; $index -lt 65534; $index++) { $limitParts.Add(@(5,'+')) }
$cases.Add((New-TokenCase '65536 token boundary including synthetic terminals' $limitParts.ToArray()))
$cases.Add((New-TokenCase 'bracketed words do not introduce Rem comments' @(@(2,'[Then]'),@(0,' '),@(1,'Rem'),@(0,' '),@(1,'value'),@(6,"`n"),@(1,'Thing'),@(5,'.'),@(1,'Rem'),@(6,"`n"),@(1,'If'),@(0,' '),@(1,'False'),@(0,' '),@(1,'Then'),@(0,' '),@(1,'x'),@(0,' '),@(1,'Else'),@(0,' Rem comment'))))
$cases.Add((New-TokenCase 'colon-equals is not a statement separator' @(@(1,'x'),@(5,':='),@(1,'Rem'),@(0,' '),@(1,'value'))))
$cases.Add((New-TokenCase 'continuation with Unicode comment' @(@(1,'x'),@(0,(' _ ''' + $unicode + "`r`n`t")),@(5,'+'),@(3,'1'))))
$negative = @(
    @{Name='unterminated string'; Text='"abc'; Diag=@(2,1,0,1,1,1)},
    @{Name='unterminated bracket'; Text='[abc'; Diag=@(2,1,0,1,1,1)},
    @{Name='empty bracket'; Text='[]'; Diag=@(4,4,0,1,1,1)},
    @{Name='Unicode bracket rejected at token start'; Text=('[a' + [char]0x03A9 + ']'); Diag=@(3,2,0,1,1,1)},
    @{Name='Unicode bare identifier deferred'; Text=([string][char]0x03A9); Diag=@(3,2,0,1,1,1)},
    @{Name='based literal needs digits'; Text='&H'; Diag=@(2,2,0,1,1,1)},
    @{Name='invalid octal digit'; Text='&O8'; Diag=@(2,2,0,1,1,1)},
    @{Name='truncated exponent'; Text='1e+'; Diag=@(2,2,0,1,1,1)},
    @{Name='numeric word boundary'; Text='123abc'; Diag=@(2,2,0,1,1,1)},
    @{Name='dangling continuation'; Text='x _'; Diag=@(2,3,2,3,1,3)},
    @{Name='continuation comment without physical newline'; Text="x _ 'tail"; Diag=@(2,3,2,3,1,3)},
    @{Name='lone CR'; Text="x`rz"; Diag=@(1,3,1,2,1,2)},
    @{Name='invalid punctuation'; Text='{'; Diag=@(2,4,0,1,1,1)},
    @{Name='assembly rejected before payload lexing'; Text="Asm`n{opaque 'payload`nEnd Asm"; Diag=@(3,1,0,1,1,1)},
    @{Name='date and directive boundary deferred'; Text='#2026-11-10#'; Diag=@(3,2,0,1,1,1)},
    @{Name='identifier length exceeded'; Text=('a' * 129); Diag=@(4,4,0,1,1,1)},
    @{Name='bracket decoded length exceeded'; Text=('[' + ('a' * 129) + ']'); Diag=@(4,4,0,1,1,1)},
    @{Name='quoted token character limit'; Text=('"' + ('a' * 4095) + '"'); Diag=@(4,2,0,1,1,1)},
    @{Name='unclosed token character limit'; Text=('"' + ('a' * 4096)); Diag=@(4,2,0,1,1,1)},
    @{Name='EOF token exceeds bounded vector'; Text=('+' * 65535); Diag=@(4,3,65535,65536,1,65536)}
)
foreach ($case in $negative) { $cases.Add((New-RejectedCase $case.Name $utf8.GetBytes($case.Text) $case.Diag)) }
$cases.Add((New-RejectedCase 'malformed UTF8 inside ignored comment' ([byte[]]@(39,32,192,175)) @(1,1,2,3,1,3)))
$cases.Add((New-RejectedCase 'NUL inside ignored comment' ([byte[]]@(39,97,0)) @(1,2,2,3,1,3)))
$badPrefix = "'" + [char]0xD83D + [char]0xDE00 + "`r`n"
$cases.Add((New-RejectedCase 'invalid scalar after supplementary comment CRLF' ([byte[]](@($utf8.GetBytes($badPrefix)) + @(237,160,128))) @(1,1,7,6,2,1)))
foreach ($case in $cases) { Assert-ScanCase $case }
$control = @('@test.input = global i64 1','@test.context = private global %ube.context zeroinitializer, align 8','define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0','  call void @ube.context.init(ptr %ctx)','  %init = call i1 @ube.project.init(ptr %ctx)','  %input = load volatile i64, ptr @test.input',"  %pair = call { i1, i64 } @ube.proc.$($procedures['Run'])(ptr %ctx, i64 %input)",'  %ok = extractvalue { i1, i64 } %pair, 0','  %value = extractvalue { i1, i64 } %pair, 1','  %disposed = call i1 @ube.context.dispose(ptr %ctx)','  %a = and i1 %init, %ok','  %good = and i1 %a, %disposed','  %result = trunc i64 %value to i32','  %exit = select i1 %good, i32 %result, i32 255','  ret i32 %exit','}')
$controlIR = Join-Path $artifacts 'control-flow.ll'
Write-Text $controlIR ($emitted + "`r`n" + ($control -join "`r`n") + "`r`n")
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ("control-flow-$level.exe")
    Build-Harness $controlIR $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Control-flow source oracle failed ${level}: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: actual Do/If failure semantics and runtime operators $level"
}
$controlNegative = Join-Path $artifacts 'control-flow-negative.ll'
Write-Text $controlNegative ([IO.File]::ReadAllText($controlIR,$utf8).Replace('@test.input = global i64 1','@test.input = global i64 0'))
$controlExe = Join-Path $artifacts 'control-flow-negative.exe'
Build-Harness $controlNegative $controlExe 'O2'
$result = Invoke-BoundedProcess $controlExe @()
Require ($result.ExitCode -eq 22) "Control-flow changed-input observation expected22: $($result.Evidence)"
$script:passed++
Write-Output 'PASS: changed control-flow input produces exact failure count22'
Write-Output "PASS: $($script:passed) source scanning groups. Evidence: $artifacts"
