param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)
$utf8Bom = New-Object System.Text.UTF8Encoding($true, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube project loading ' + [guid]::NewGuid())
$workingDirectory = Join-Path $artifacts 'unrelated working directory'
New-Item -ItemType Directory -Path $workingDirectory -Force | Out-Null
$script:processNumber = 0
$script:passed = 0

# Quotes one Windows command-line argument, including embedded quotes/backslashes.
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

# Retains the process handle before waiting so fast exits still expose ExitCode.
# Output goes to files, avoiding redirected-pipe deadlocks and preserving evidence.
function Invoke-BoundedProcess([string]$File, [string[]]$Arguments) {
    $script:processNumber++
    $prefix = Join-Path $artifacts ('process-' + $script:processNumber)
    $start = @{
        FilePath = $File
        WorkingDirectory = $workingDirectory
        PassThru = $true
        WindowStyle = 'Hidden'
        RedirectStandardOutput = $prefix + '.stdout'
        RedirectStandardError = $prefix + '.stderr'
    }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @start
    try {
        $retainedHandle = $process.Handle
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            $null = $process.WaitForExit(5000)
            throw "Process timed out: $File. Evidence: $prefix"
        }
        $process.Refresh()
        $exitCode = $process.ExitCode
        if ($null -eq $exitCode) { throw "No exit code available for retained handle $retainedHandle" }
        return [pscustomobject]@{
            ExitCode = $exitCode
            Stdout = [IO.File]::ReadAllText($prefix + '.stdout', $utf8)
            Stderr = [IO.File]::ReadAllText($prefix + '.stderr', $utf8)
            Evidence = $prefix
        }
    } finally { $process.Dispose() }
}

# Writes fixture bytes with an explicit encoding, never a host-default code page.
function Write-Text([string]$Path, [string]$Text, [bool]$Bom = $false) {
    $null = New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Path)) -Force
    $encoding = $utf8
    if ($Bom) { $encoding = $utf8Bom }
    [IO.File]::WriteAllText($Path, $Text, $encoding)
}

# Provides a native module envelope; executable source semantics are not tested.
function Module-Text([string]$Name) {
    return "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"$Name`"`r`n' Loader fixture.`r`n"
}

# Creates isolated manifest and source files for a single independent case.
function New-Fixture([string]$Name, [string[]]$Lines, [hashtable]$Sources = @{}) {
    $folder = Join-Path $artifacts $Name
    $null = New-Item -ItemType Directory -Path $folder -Force
    foreach ($source in $Sources.Keys) { Write-Text (Join-Path $folder $source) $Sources[$source] }
    $manifest = Join-Path $folder 'project.UBE'
    Write-Text $manifest (($Lines -join "`r`n") + "`r`n")
    return $manifest
}

# Asserts rejection is actionable and cannot also advertise successful checking.
function Assert-Rejected([string]$Name, [string]$Manifest, [string]$Code, [string]$Location = '') {
    $result = Invoke-BoundedProcess $BootstrapExe @('--check', $Manifest)
    if ($result.ExitCode -ne 1 -or [string]::IsNullOrWhiteSpace($result.Stderr) -or $result.Stdout -match '(?m)^CHECK OK\s*$') {
        throw "$Name expected exit 1, stderr diagnostic and no CHECK OK; received $($result.ExitCode). Evidence: $($result.Evidence)"
    }
    if ($Code -and $result.Stderr -notmatch ('(?m)^UBE: ' + [regex]::Escape($Code) + ':')) {
        throw "$Name expected diagnostic $Code. Evidence: $($result.Evidence)"
    }
    if ($Location -and $result.Stderr -notmatch ([regex]::Escape($Location) + '(?=\s|$)')) {
        throw "$Name expected diagnostic file and line $Location. Evidence: $($result.Evidence)"
    }
    $script:passed++
    Write-Output "PASS: $Name"
}

# Compares ordered output rather than accepting a successful exit alone.
function Assert-Accepted([string]$Name, [string]$Manifest, [string[]]$Expected) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--check', $Manifest)
    $actual = $result.Stdout.Replace("`r`n", "`n").TrimEnd("`r", "`n")
    if ($result.ExitCode -ne 0 -or $result.Stderr.Length -ne 0 -or $actual -cne ($Expected -join "`n")) {
        throw "$Name output/exit mismatch. Exit=$($result.ExitCode). Evidence: $($result.Evidence)"
    }
    $script:passed++
    Write-Output "PASS: $Name"
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
    if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $BootstrapExe)) {
        throw "VB6 build failed with exit $($build.ExitCode). Evidence: $buildDirectory"
    }
}
$BootstrapExe = [IO.Path]::GetFullPath($BootstrapExe)
if (-not (Test-Path -LiteralPath $BootstrapExe)) { throw "Bootstrap executable not found: $BootstrapExe" }

$normal = @('UBE-Project 1', 'Name = "Example"', 'Kind = "Exe"', 'Startup = "Main"', 'Source = "Main.bas"')
$main = Module-Text 'Main'
$sources = @{ 'Main.bas' = $main }

$manifest = New-Fixture 'ordered modules with spaces' @(
    'UBE-Project 1', 'Name = "Ordered"', 'Kind = "Exe"', 'Startup = "Main"',
    'Source = "src/Zebra.bas"', 'Source = "src/deep/Alpha.bas"', 'Source = "Main.bas"'
) @{ 'src/Zebra.bas' = (Module-Text 'Zebra'); 'src/deep/Alpha.bas' = (Module-Text 'Alpha'); 'Main.bas' = $main }
Assert-Accepted 'three modules preserve manifest order from unrelated working directory' $manifest @('PROJECT Ordered','MODULE Zebra','MODULE Alpha','MODULE Main','CHECK OK')
$orderedManifest = $manifest
Assert-Accepted 'repeated load preserves identical ordered output' $orderedManifest @('PROJECT Ordered','MODULE Zebra','MODULE Alpha','MODULE Main','CHECK OK')
$sample = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../examples/multi-module/Demo.UBE'))
Assert-Accepted 'checked-in multi-module sample' $sample @('PROJECT Demo','MODULE Program','MODULE Arithmetic','CHECK OK')

$manifest = New-Fixture 'case insensitive settings' @(
    'UBE-Project 1', 'nAmE = "Settings"', 'kInD = "Exe"', 'sTaRtUp = "Main"',
    'oPtImIzAtIoN = "Size"', 'dEbUgInFoRmAtIoN = "Line"', 'sOuRcE = "Main.bas"'
) $sources
Assert-Accepted 'case insensitive keys and explicit settings' $manifest @('PROJECT Settings','MODULE Main','CHECK OK')

$manifest = New-Fixture 'default settings' $normal $sources
Assert-Accepted 'omitted optimization and debug settings' $manifest @('PROJECT Example','MODULE Main','CHECK OK')

$manifest = New-Fixture 'utf8 bom' $normal $sources
Write-Text $manifest ([IO.File]::ReadAllText($manifest, $utf8)) $true
Write-Text (Join-Path (Split-Path $manifest) 'Main.bas') ($main + "' Unicode: " + [char]0x00E6 + [char]0x03BB + [char]0x4E2D + "`r`n") $true
Assert-Accepted 'UTF8 BOM manifest and Unicode source comments' $manifest @('PROJECT Example','MODULE Main','CHECK OK')

# U+9000 and U+1F680 exercise signed AscW values and a UTF-16 surrogate pair.
$unicodeFile = 'Source' + [char]0x9000 + [char]0xD83D + [char]0xDE80 + '.bas'
$unicodeSources = @{}
$unicodeSources[$unicodeFile] = $main
$manifest = New-Fixture 'unicode filenames' ($normal[0..3] + ('Source = "' + $unicodeFile + '"')) $unicodeSources
Assert-Accepted 'Unicode filename with high BMP value and surrogate pair' $manifest @('PROJECT Example','MODULE Main','CHECK OK')

$manifest = New-Fixture 'library' @('UBE-Project 1','Name = "Helpers"','Kind = "Library"','Source = "Main.bas"') $sources
Assert-Accepted 'library manifest without Startup' $manifest @('PROJECT Helpers','MODULE Main','CHECK OK')

$manifest = New-Fixture 'missing source' $normal
Assert-Rejected 'missing source' $manifest 'E_IO'
Assert-Accepted 'valid invocation after rejected invocation' $orderedManifest @('PROJECT Ordered','MODULE Zebra','MODULE Alpha','MODULE Main','CHECK OK')

$outside = Join-Path $artifacts 'Outside.bas'
Write-Text $outside (Module-Text 'Outside')
$manifest = New-Fixture 'escaping source' ($normal[0..3] + 'Source = "../Outside.bas"')
Assert-Rejected 'existing source escapes project tree' $manifest 'E_PATH'
$manifest = New-Fixture 'absolute source' ($normal[0..3] + ('Source = "' + $outside + '"'))
Assert-Rejected 'existing absolute source path' $manifest 'E_PATH'
$manifest = New-Fixture 'junction escape' ($normal[0..3] + 'Source = "linked/Outside.bas"')
$junctionTarget = Join-Path $artifacts 'external junction target'
Write-Text (Join-Path $junctionTarget 'Outside.bas') (Module-Text 'Outside')
$null = New-Item -ItemType Junction -Path (Join-Path (Split-Path $manifest) 'linked') -Target $junctionTarget
Assert-Rejected 'junction source escapes project tree' $manifest 'E_PATH'

$manifest = New-Fixture 'duplicate path' ($normal + 'Source = "./Main.bas"') $sources
Assert-Rejected 'duplicate normalized source path' $manifest 'E_DUPLICATE_SOURCE'
$manifest = New-Fixture 'duplicate module' ($normal + 'Source = "Other.bas"') @{ 'Main.bas'=$main; 'Other.bas'=(Module-Text 'mAiN') }
Assert-Rejected 'duplicate case-folded module identity' $manifest 'E_DUPLICATE_MODULE'
$manifest = New-Fixture 'duplicate key' ($normal + 'nAmE = "Other"') $sources
Assert-Rejected 'duplicate case-insensitive scalar key' $manifest 'E_DUPLICATE_KEY'
$manifest = New-Fixture 'unknown key' ($normal + 'Mystery = "value"') $sources
Assert-Rejected 'unknown manifest key' $manifest 'E_UNKNOWN_KEY'
$manifest = New-Fixture 'bad quoted value' @('UBE-Project 1','Name = "Example','Kind = "Exe"','Startup = "Main"','Source = "Main.bas"') $sources
Assert-Rejected 'unterminated quoted value' $manifest 'E_MANIFEST_SYNTAX' 'project.UBE:2'
$manifest = New-Fixture 'trailing quoted garbage' ($normal[0..3] + 'Source = "Main.bas" garbage') $sources
Assert-Rejected 'trailing text after quoted value' $manifest 'E_MANIFEST_SYNTAX' 'project.UBE:5'

$manifest = New-Fixture 'invalid utf8 manifest' $normal $sources
[IO.File]::WriteAllBytes($manifest, [byte[]](0xC3,0x28))
Assert-Rejected 'malformed UTF8 manifest' $manifest 'E_ENCODING'
$manifest = New-Fixture 'invalid utf8 source' $normal $sources
$validPrefix = $utf8.GetBytes($main)
[IO.File]::WriteAllBytes((Join-Path (Split-Path $manifest) 'Main.bas'), [byte[]]($validPrefix + [byte[]](0xC3,0x28)))
Assert-Rejected 'malformed UTF8 source' $manifest 'E_ENCODING'
$manifest = New-Fixture 'nul source' $normal @{ 'Main.bas'=($main + [char]0) }
Assert-Rejected 'source NUL' $manifest 'E_ENCODING'

$manifest = New-Fixture 'missing source header' $normal @{ 'Main.bas'='Attribute UBE_Name = "Main"' }
Assert-Rejected 'missing native source header' $manifest 'E_SOURCE_HEADER' 'Main.bas:1'
$manifest = New-Fixture 'missing source identity' $normal @{ 'Main.bas'="UBE SOURCE 1 MODULE`r`n' No identity.`r`n" }
Assert-Rejected 'missing source identity' $manifest 'E_SOURCE_IDENTITY'
$manifest = New-Fixture 'unknown reserved attribute' $normal @{ 'Main.bas'=("UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Main`"`r`nAttribute UBE_Unknown = `"x`"`r`n") }
Assert-Rejected 'unknown reserved envelope attribute' $manifest 'E_SOURCE_IDENTITY' 'Main.bas:3'
$manifest = New-Fixture 'malformed reserved attribute' $normal @{ 'Main.bas'=("UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Main`"`r`nAttribute UBE_Unknown = `"x`r`n") }
Assert-Rejected 'malformed reserved envelope attribute' $manifest 'E_SOURCE_IDENTITY' 'Main.bas:3'
$manifest = New-Fixture 'uninterpreted source body' $normal @{ 'Main.bas'=($main + "Public Sub Main()`r`nAttribute UBE_Unknown = `"x`"`r`nEnd Sub`r`n") }
Assert-Accepted 'attribute-like text after source body begins is not envelope metadata' $manifest @('PROJECT Example','MODULE Main','CHECK OK')
$manifest = New-Fixture 'source kind mismatch' $normal @{ 'Main.bas'="UBE SOURCE 1 CLASS`r`nAttribute UBE_Name = `"Main`"`r`n" }
Assert-Rejected 'source kind extension mismatch' $manifest 'E_SOURCE_HEADER' 'Main.bas:1'
$manifest = New-Fixture 'unsupported extension' ($normal[0..3] + 'Source = "Main.cls"') @{ 'Main.cls'="UBE SOURCE 1 CLASS`r`nAttribute UBE_Name = `"Main`"`r`n" }
Assert-Rejected 'unsupported source extension' $manifest 'E_UNSUPPORTED'
$manifest = New-Fixture 'manifest version' (@('UBE-Project 2') + $normal[1..4]) $sources
Assert-Rejected 'unsupported manifest version' $manifest 'E_MANIFEST_HEADER'
$manifest = New-Fixture 'source version' $normal @{ 'Main.bas'="UBE SOURCE 2 MODULE`r`nAttribute UBE_Name = `"Main`"`r`n" }
Assert-Rejected 'unsupported source version' $manifest 'E_SOURCE_HEADER'
$manifest = New-Fixture 'empty manifest' @() $sources
Write-Text $manifest ''
Assert-Rejected 'empty manifest' $manifest 'E_MANIFEST_HEADER'
$manifest = New-Fixture 'empty source' $normal @{ 'Main.bas'='' }
Assert-Rejected 'empty source' $manifest 'E_SOURCE_HEADER'

foreach ($key in @('Name','Kind','Startup','Source')) {
    $manifest = New-Fixture ('missing ' + $key) @($normal | Where-Object { $_ -notmatch ('^' + $key + ' =') }) $sources
    Assert-Rejected ('missing required ' + $key) $manifest 'E_REQUIRED'
}
foreach ($key in @('Reference','Resource','LibraryReference','StartupForm')) {
    $manifest = New-Fixture ('unsupported ' + $key) ($normal + ($key + ' = "unsupported"')) $sources
    Assert-Rejected ('explicitly unsupported ' + $key) $manifest 'E_UNSUPPORTED'
}
$manifest = New-Fixture 'library startup' @('UBE-Project 1','Name = "Helpers"','Kind = "Library"','Startup = "Main"','Source = "Main.bas"') $sources
Assert-Rejected 'Library rejects Startup' $manifest 'E_VALUE'
$manifest = New-Fixture 'unsupported kind' @('UBE-Project 1','Name = "Example"','Kind = "Unknown"','Startup = "Main"','Source = "Main.bas"') $sources
Assert-Rejected 'unsupported project Kind' $manifest 'E_VALUE'

$manifest = New-Fixture 'manifest byte limit' $normal $sources
Write-Text $manifest (' ' * 65537)
Assert-Rejected 'manifest exceeds 64KiB' $manifest 'E_LIMIT'
$manifest = New-Fixture 'source byte limit' $normal @{ 'Main.bas'=($main + "'" + ('x' * (1048576 - $utf8.GetByteCount($main)))) }
Assert-Rejected 'source exceeds 1MiB by one byte' $manifest 'E_LIMIT'
$manifest = New-Fixture 'source exact byte limit' $normal @{ 'Main.bas'=($main + "'" + ('x' * (1048575 - $utf8.GetByteCount($main)))) }
Assert-Accepted 'source at 1MiB bound' $manifest @('PROJECT Example','MODULE Main','CHECK OK')

$totalSources = @{}
$totalLines = @('UBE-Project 1','Name = "Total"','Kind = "Library"')
for ($i = 1; $i -le 9; $i++) {
    $header = Module-Text ('M' + $i)
    $body = $header
    if ($i -le 8) { $body += "'" + ('x' * (1048575 - $utf8.GetByteCount($header))) }
    $totalSources[('M' + $i + '.bas')] = $body
    $totalLines += 'Source = "M' + $i + '.bas"'
}
$manifest = New-Fixture 'aggregate byte limit' $totalLines $totalSources
Assert-Rejected 'sources exceed total 8MiB' $manifest 'E_LIMIT'

$manySources = @{}
$manyLines = @('UBE-Project 1','Name = "Many"','Kind = "Library"')
$manyExpected = @('PROJECT Many')
for ($i = 1; $i -le 128; $i++) {
    $manySources[('M' + $i + '.bas')] = Module-Text ('M' + $i)
    $manyLines += 'Source = "M' + $i + '.bas"'
    $manyExpected += 'MODULE M' + $i
}
$manifest = New-Fixture 'source count bound' $manyLines $manySources
Assert-Accepted '128 sources at count bound' $manifest ($manyExpected + 'CHECK OK')
$manySources['M129.bas'] = Module-Text 'M129'
$manifest = New-Fixture 'source count limit' ($manyLines + 'Source = "M129.bas"') $manySources
Assert-Rejected '129 sources exceed count limit' $manifest 'E_LIMIT'

$manifest = New-Fixture 'identifier length limit' $normal @{ 'Main.bas'=(Module-Text ('M' * 129)) }
Assert-Rejected 'module identifier exceeds 128 characters' $manifest 'E_IDENTIFIER'

foreach ($arguments in @(@('--unknown'), @('--check'), @('--check', $manifest, 'extra'))) {
    $result = Invoke-BoundedProcess $BootstrapExe $arguments
    if ($result.ExitCode -ne 2 -or $result.Stderr -notmatch '(?m)^UBE: E_USAGE:') { throw "CLI usage expected exit 2 and E_USAGE diagnostic. Evidence: $($result.Evidence)" }
    $script:passed++
    Write-Output ('PASS: usage ' + ($arguments -join ' '))
}
$result = Invoke-BoundedProcess $BootstrapExe @()
if ($result.ExitCode -ne 2 -or $result.Stderr -notmatch '(?m)^UBE: E_USAGE:') { throw "Empty CLI expected exit 2 and E_USAGE diagnostic. Evidence: $($result.Evidence)" }
$script:passed++
Write-Output "PASS: $($script:passed) project-loading/CLI cases. No semantic parser or native compilation claims."
