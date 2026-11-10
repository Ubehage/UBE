# Verifies token classification and decoded spelling against independent lexical expectations.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = '',
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube syntax tokens ' + [guid]::NewGuid())
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

# Requires controlled failure and verifies an existing valid artifact is unchanged.
function Assert-PreservedFailure([string]$Name, [string[]]$Arguments, [string]$Code, [string]$Artifact, [int]$TimeoutMilliseconds = 30000) {
    $before = (Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash
    $result = Invoke-BoundedProcess $BootstrapExe $Arguments $TimeoutMilliseconds
    Require ($result.ExitCode -eq 1 -and $result.Stderr -match ('(?m)^UBE: ' + [regex]::Escape($Code) + ':') -and $result.Stdout -notmatch '(?m)^(BUILD OK|EMIT OK)\r?$') "$Name failure mismatch. Evidence: $($result.Evidence)"
    Require ((Get-FileHash -LiteralPath $Artifact -Algorithm SHA256).Hash -ceq $before) "$Name changed prior artifact"
    $script:passed++
    Write-Output "PASS: $Name preserves prior artifact"
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

# Derives the word set from the established host parser, and codes from explicit public bindings.
$hostText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../src/SourceParser.bas'),$utf8)
$reservedText = ''
foreach ($match in [regex]::Matches($hostText,'(?m)^\s*Reserved = (?:Reserved & )?"([^"]+)"')) { $reservedText += $match.Groups[1].Value }
$words = @($reservedText.Split('|') | Where-Object { $_.Length -gt 0 })
Require ($words.Count -eq 138) 'Host reserved-word oracle changed; review this gate'
$contexts = @('ube','source','module','ube_name','ube_primitive','preserve')
$helperPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src/SyntaxTokens.bas'))
$helper = [IO.File]::ReadAllText($helperPath,$utf8)
$codes = @{}
foreach ($match in [regex]::Matches($helper,'(?m)^Public Const Kw(\w+) As Long = (\d+)')) { $codes[$match.Groups[1].Value.ToLowerInvariant()] = [long]$match.Groups[2].Value }
$spellings = New-Object 'System.Collections.Generic.List[string]'
$expected = New-Object 'System.Collections.Generic.List[long]'
$pairs = New-Object 'System.Collections.Generic.List[long]'
$ids = @{}

# Records six independent observations for each actual spelling.
function Add-Token([string]$Tag,[string]$Spelling,[long]$Code,[bool]$Bare=$false,[bool]$Member=$false,[bool]$Integer=$false,[bool]$Label=$false,[bool]$Module=$false) {
    if ($Tag) { $ids[$Tag] = $spellings.Count }
    $spellings.Add($Spelling)
    foreach ($value in @($Code,[long]$Bare,[long]$Member,[long]$Integer,[long]$Label,[long]$Module)) { $expected.Add($value) }
}

# Retains decoded comparison or metadata classification expectations separately from token codes.
function Add-Pair([long]$Operation,[string]$Left,[string]$Right,[long]$ExpectedValue) {
    $pairs.Add($Operation); $pairs.Add([long]$ids[$Left])
    if ($Right) { $pairs.Add([long]$ids[$Right]) } else { $pairs.Add(0) }
    $pairs.Add($ExpectedValue)
}

Add-Token 'anchor' 'anchor' 1 $true $true
foreach ($word in ($words + $contexts)) {
    $key = $word.Replace('_','')
    Require ($codes.ContainsKey($key)) "Missing explicit keyword binding: $word"
    $code = $codes[$key]
    $bare = $contexts -contains $word
    Add-Token ('lower-'+$word) $word $code $bare $true
    Add-Token ('bracket-'+$word) ('['+$word+']') 1 $true $true
    Add-Token ('upper-'+$word) $word.ToUpperInvariant() $code $bare $true
    Add-Token ('upper-bracket-'+$word) ('['+$word.ToUpperInvariant()+']') 1 $true $true
    Add-Token ('suffix-'+$word) ($word+'x') 1 $true $true
    Add-Token ('prefix-'+$word) ('q'+$word) 1 $true $true
}
$punctuation = @(
    @('(',10),@(')',11),@('.',12),@(',',13),@(':',14),@('=',15),@('+',16),@('-',17),
    @('<',18),@('>',19),@('<=',20),@('>=',21),@('<>',22),@('%',23),@('&',24),@('^',25),
    @('*',26),@('/',27),@('\',28),@('!',29),@('$',30),@('@',31),@(';',32),@(':=',33)
)
foreach ($item in $punctuation) { Add-Token '' $item[0] $item[1] }
foreach ($number in @('0','123','0001')) { Add-Token '' $number 2 $false $false $true $true }
foreach ($number in @('12%','12&','12^','&HCAFE','&hff&','&O77^','&o0%')) { Add-Token '' $number 2 $false $false $true }
foreach ($number in @('1.0','1e3','1E-2','1!','1#','1@','1f','1r','1d','.5')) { Add-Token '' $number 2 }
Add-Token 'escaped-a' '[a]]b]' 1 $true $true
Add-Token 'escaped-upper' '[A]]B]' 1 $true $true
Add-Token 'plain-ab' 'ab' 1 $true $true
Add-Token 'escaped-quote' '[A"b]' 1 $true $true
Add-Token 'ordinary-name' 'Hello' 1 $true $true
Add-Token 'bracket-name' '[hELLo]' 1 $true $true
Add-Token 'string-bracket' '"a]b"' 3
Add-Token 'string-quote' '"a""b"' 3
Add-Token 'string-name' '"HELLO"' 3 $false $false $false $false $true
Add-Token 'string-near' '"HelloX"' 3 $false $false $false $false $true
Add-Token 'module-128' ('"'+('a'*128)+'"') 3 $false $false $false $false $true
Add-Token 'module-129' ('"'+('a'*129)+'"') 3
Add-Token 'module-leading-digit' '"9Name"' 3
Add-Token 'module-empty' '""' 3
Add-Token 'module-space' '"a b"' 3
Add-Token 'module-underscore' '"_Name9"' 3 $false $false $false $false $true
Add-Token 'module-unicode' ('"'+[char]0x3A9+'"') 3
Add-Token 'metadata-near' '[UBE_Primitivex]' 1 $true $true
Add-Pair 1 'escaped-a' 'escaped-upper' 1
Add-Pair 1 'escaped-a' 'plain-ab' 0
Add-Pair 1 'ordinary-name' 'bracket-name' 1
Add-Pair 1 'escaped-a' 'string-bracket' 0
Add-Pair 1 'upper-if' 'bracket-if' 1
Add-Pair 2 'string-bracket' 'escaped-upper' 1
Add-Pair 2 'string-quote' 'escaped-quote' 1
Add-Pair 2 'string-name' 'ordinary-name' 1
Add-Pair 2 'string-near' 'ordinary-name' 0
Add-Pair 2 'ordinary-name' 'ordinary-name' 0
Add-Pair 3 'bracket-ube_primitive' '' $codes['ubeprimitive']
Add-Pair 3 'metadata-near' '' 1
Add-Pair 3 'string-name' '' 0
# Authored decoded byte oracles cover bracket/quote escapes, ASCII case folding,
# UTF-8 bytes (not UTF-16 characters), empty names and logical-position bounds.
foreach ($item in @(
    @('escaped-upper',0,97),@('escaped-upper',1,93),@('escaped-upper',2,98),@('escaped-upper',3,-1),
    @('string-quote',0,97),@('string-quote',1,34),@('string-quote',2,98),@('string-quote',3,-1),
    @('ordinary-name',0,104),@('ordinary-name',4,111),@('ordinary-name',5,-1),@('ordinary-name',-1,-1),
    @('module-empty',0,-1),@('module-unicode',0,206),@('module-unicode',1,169),@('module-unicode',2,-1)
)) {
    $pairs.Add(4); $pairs.Add([long]$ids[$item[0]]); $pairs.Add([long]$item[1]); $pairs.Add([long]$item[2])
}
foreach ($item in @(@('0001',0,48),@('0001',3,49),@('0001',4,-1),@('0001',2147483647,-1),@(':',0,-1))) {
    $pairs.Add(4); $pairs.Add([long]$spellings.IndexOf($item[0])); $pairs.Add([long]$item[1]); $pairs.Add([long]$item[2])
}
$sourceText = ($spellings -join ' ')
$sourceBytes = $utf8.GetBytes($sourceText)
$firstKeywordByte = $utf8.GetByteCount('anchor ')
# Synthetic newline/EOF are scanner output and have no spelling in sourceBytes.
Add-Token '' '' 4
Add-Token '' '' 5
$count = $spellings.Count
Require ($expected.Count -eq $count*6 -and $pairs.Count % 4 -eq 0) 'Oracle framing error'

$core = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../std-lib/src/portable'))
$scanner = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../compiler/src/SourceScanner.bas'))
$manifest = Copy-Fixtures 'token library' @((Join-Path $core 'BufferPrimitives.bas'),(Join-Path $core 'Utf8.bas'),$scanner,$helperPath,(Join-Path $PSScriptRoot 'TokenProbe.bas')) '0' 'Library'
$procedures = Read-Procedures $manifest
$ir = Join-Path $artifacts 'tokens.ll'
$null = Invoke-Compiler @('--emit-llvm',$manifest,$ir) 'EMIT OK'
$emitted = [IO.File]::ReadAllText($ir,$utf8)
$data = '@test.bytes = global ['+$sourceBytes.Length+' x i64] ['+(($sourceBytes | ForEach-Object {'i64 '+$_}) -join ', ')+'], align 8'
$oracle = '@test.expected = global ['+$expected.Count+' x i64] ['+(($expected | ForEach-Object {'i64 '+$_}) -join ', ')+'], align 8'
$comparisons = '@test.pairs = global ['+$pairs.Count+' x i64] ['+(($pairs | ForEach-Object {'i64 '+$_}) -join ', ')+'], align 8'
foreach ($seed in @(105,106)) {
    $h = @($data,$oracle,$comparisons,
        '@test.context = private global %ube.context zeroinitializer, align 8',
        ('@test.input = global i64 '+$seed),
        ('@test.source = global { i64, i64, ptr, ptr } { i64 0, i64 '+($sourceBytes.Length-1)+', ptr @test.bytes, ptr null }'),
        ('@test.oracle = global { i64, i64, ptr, ptr } { i64 0, i64 '+($expected.Count-1)+', ptr @test.expected, ptr null }'),
        ('@test.comparisons = global { i64, i64, ptr, ptr } { i64 0, i64 '+($pairs.Count-1)+', ptr @test.pairs, ptr null }'),
        'define i32 @main() {','entry:','  %ctx = getelementptr %ube.context, ptr @test.context, i32 0',
        '  call void @ube.context.init(ptr %ctx)','  %init = call i1 @ube.project.init(ptr %ctx)',
        '  %seed = load volatile i64, ptr @test.input',
        "  %character = getelementptr i64, ptr @test.bytes, i64 $firstKeywordByte",'  store i64 %seed, ptr %character',
        "  %result = call { i1, i64 } @ube.proc.$($procedures['Run'])(ptr %ctx, ptr @test.source, ptr @test.oracle, i64 $count, ptr @test.comparisons, i64 $($pairs.Count/4))",
        '  %ok = extractvalue { i1, i64 } %result, 0','  %value = extractvalue { i1, i64 } %result, 1',
        '  %disposed = call i1 @ube.context.dispose(ptr %ctx)','  %a = and i1 %init, %ok','  %valid = and i1 %a, %disposed',
        '  %answer = trunc i64 %value to i32','  %exit = select i1 %valid, i32 %answer, i32 10004','  ret i32 %exit','}')
    $combined = Join-Path $artifacts ("tokens-$seed.ll")
    Write-Text $combined ($emitted+[Environment]::NewLine+($h -join [Environment]::NewLine))
    foreach ($level in @('O0','O2')) {
        $exe = Join-Path $artifacts ("tokens-$seed-$level.exe")
        Build-Harness $combined $exe $level
        $run = Invoke-BoundedProcess $exe @()
        $expectedExit = 0
        if ($seed -eq 106) { $expectedExit = 2 }
        Require ($run.ExitCode -eq $expectedExit) "Token helper seed=$seed $level expected$expectedExit got$($run.ExitCode): $($run.Evidence)"
        $script:passed++
        Write-Output "PASS: token classification/decoded comparisons seed=$seed $level exact exit$expectedExit"
    }
}
Write-Output "PASS: $script:passed native runs; $count tokens, $($words.Count) reserved + $($contexts.Count) contextual words, $($pairs.Count/4) comparisons"

# Compiles unchanged storage policy and probes through the real source compiler.
