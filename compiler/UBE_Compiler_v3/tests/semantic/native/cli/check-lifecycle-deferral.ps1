param([Parameter(Mandatory=$true)][string]$Executable, [string]$SelectionPath='')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = $PSScriptRoot
while (-not [IO.File]::Exists((Join-Path $root 'bootstrap/tools/verification.ps1'))) {
    $next = Split-Path $root -Parent
    if (-not $next -or $next -ceq $root) { throw 'Repository root not found.' }
    $root = $next
}
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$exe = [IO.Path]::GetFullPath($Executable)
$run = Join-Path $root ('bootstrap/out/lifecycle-deferral/' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $run -Force
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$prefix = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Hooks`"`n"
$cases = @(
    @{ Id='initialize'; Body="Private Sub Module_Initialize()`nEnd Sub`nSub Main()`nEnd Sub`n"; Witness='Module_Initialize' },
    @{ Id='terminate'; Body="Private Sub Module_Terminate()`nEnd Sub`nSub Main()`nEnd Sub`n"; Witness='Module_Terminate' },
    @{ Id='bracketed'; Body="Private Sub [mOdUlE_iNiTiAlIzE]()`nEnd Sub`nSub Main()`nEnd Sub`n"; Witness='[mOdUlE_iNiTiAlIzE]' },
    @{ Id='invalid-signature'; Body="Public Function Module_Terminate(ByVal n As Long) As Long`nEnd Function`nSub Main()`nEnd Sub`n"; Witness='Module_Terminate' },
    @{ Id='direct-call'; Body="Private Sub Module_Initialize()`nEnd Sub`nSub Main()`n    Call Module_Initialize()`nEnd Sub`n"; Witness='Module_Initialize' },
    @{ Id='unrelated-procedure'; Body="Private Sub Module_Initialize_Extra()`nEnd Sub`nSub Main()`nEnd Sub`n"; Witness='' },
    @{ Id='local-variable'; Body="Sub Main()`n    Dim Module_Initialize As Long = 2`nEnd Sub`n"; Witness='' }
)
$checks = New-Object 'System.Collections.Generic.List[object]'
foreach ($case in $cases) {
    $directory = Join-Path $run $case.Id
    $null = New-Item -ItemType Directory -Path $directory
    $source = $prefix + $case.Body
    $sourcePath = Join-Path $directory 'Hooks.bas'
    [IO.File]::WriteAllText($sourcePath, $source, $utf8)
    $expected = ''
    $expectedExit = 0
    if ($case.Witness) {
        $offset = $source.IndexOf($case.Witness, [StringComparison]::Ordinal)
        if ($offset -lt 0) { throw 'Missing independent witness.' }
        $before = $source.Substring(0, $offset)
        $line = ($before.ToCharArray() | Where-Object { $_ -eq "`n" } | Measure-Object).Count + 1
        $lastNewline = $before.LastIndexOf("`n", [StringComparison]::Ordinal)
        $column = $offset - $lastNewline
        $byte = $utf8.GetByteCount($before)
        $expected = "error UBE1400: semantic facility is not implemented (next lines: line, column, byte)`n$line`n$column`n$byte`n"
        $expectedExit = 1
    }
    $actual = Invoke-BoundedProcess $exe @('--check', $sourcePath) $root 60
    $passed = -not $actual.timedOut -and $actual.exit -eq $expectedExit -and $actual.stdout -ceq $expected -and $actual.stderr -ceq ''
    $checks.Add([pscustomobject]@{case=$case.Id; expectedExit=$expectedExit; expected=$expected; actual=$actual; passed=$passed})
    if (-not $passed) { throw "Lifecycle source check failed: $($case.Id): $($actual | ConvertTo-Json -Compress), expected=$expected" }
    $projectPath = Join-Path $directory 'Hooks.UBE'
    [IO.File]::WriteAllText($projectPath, "UBE-Project 1`nName = `"Hooks`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"Hooks.bas`"`n", $utf8)
    $projectExpected = $expected
    if ($case.Witness) { $projectExpected = '"' + $sourcePath.Replace('\', '/') + '"' + "`n" + $expected }
    foreach ($jobs in @(1, 2, 4)) {
        $actual = Invoke-BoundedProcess $exe @('--check', $projectPath, '--jobs', [string]$jobs) $root 60
        $passed = -not $actual.timedOut -and $actual.exit -eq $expectedExit -and $actual.stdout -ceq $projectExpected -and $actual.stderr -ceq ''
        $checks.Add([pscustomobject]@{case=$case.Id; jobs=$jobs; expectedExit=$expectedExit; expected=$projectExpected; actual=$actual; passed=$passed})
        if (-not $passed) { throw "Lifecycle project check failed: $($case.Id) jobs=$jobs : $($actual | ConvertTo-Json -Compress), expected=$projectExpected" }
    }
}
$multiCases = @(
    @{ Id='reference-unused'; First='App'; FirstBody="Sub Main()`nEnd Sub`n"; Second='LibraryHooks'; SecondBody="Private Sub Module_Terminate()`nEnd Sub`n"; Reference=$true; WitnessSource='LibraryHooks'; Witness='Module_Terminate' },
    @{ Id='root-first'; First='First'; FirstBody="Private Sub Module_Terminate()`nEnd Sub`n"; Second='Second'; SecondBody="Private Sub Module_Initialize()`nEnd Sub`nSub Main()`nEnd Sub`n"; Reference=$false; WitnessSource='First'; Witness='Module_Terminate' },
    @{ Id='root-reversed'; First='Second'; FirstBody="Private Sub Module_Initialize()`nEnd Sub`nSub Main()`nEnd Sub`n"; Second='First'; SecondBody="Private Sub Module_Terminate()`nEnd Sub`n"; Reference=$false; WitnessSource='Second'; Witness='Module_Initialize' }
)
foreach ($case in $multiCases) {
    $directory = Join-Path $run $case.Id
    $null = New-Item -ItemType Directory -Path $directory
    $first = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"$($case.First)`"`n" + $case.FirstBody
    $second = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"$($case.Second)`"`n" + $case.SecondBody
    [IO.File]::WriteAllText((Join-Path $directory ($case.First + '.bas')), $first, $utf8)
    [IO.File]::WriteAllText((Join-Path $directory ($case.Second + '.bas')), $second, $utf8)
    $projectText = "UBE-Project 1`nName = `"Hooks`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"$($case.First).bas`"`n"
    if ($case.Reference) {
        $projectText += "Reference = `"UBECore.UBE`"`n"
        [IO.File]::WriteAllText((Join-Path $directory 'UBECore.UBE'), "UBE-Project 1`nName = `"UBECore`"`nKind = `"Library`"`nSource = `"$($case.Second).bas`"`n", $utf8)
    } else { $projectText += "Source = `"$($case.Second).bas`"`n" }
    $projectPath = Join-Path $directory 'Hooks.UBE'
    [IO.File]::WriteAllText($projectPath, $projectText, $utf8)
    $witnessText = if ($case.WitnessSource -ceq $case.First) { $first } else { $second }
    $offset = $witnessText.IndexOf($case.Witness, [StringComparison]::Ordinal)
    if ($offset -lt 0) { throw 'Missing multi-source witness.' }
    $before = $witnessText.Substring(0, $offset)
    $line = ($before.ToCharArray() | Where-Object { $_ -eq "`n" } | Measure-Object).Count + 1
    $column = $offset - $before.LastIndexOf("`n", [StringComparison]::Ordinal)
    $byte = $utf8.GetByteCount($before)
    $witnessPath = (Join-Path $directory ($case.WitnessSource + '.bas')).Replace('\', '/')
    $expected = '"' + $witnessPath + '"' + "`nerror UBE1400: semantic facility is not implemented (next lines: line, column, byte)`n$line`n$column`n$byte`n"
    foreach ($jobs in @(1, 2, 4)) {
        $actual = Invoke-BoundedProcess $exe @('--check', $projectPath, '--jobs', [string]$jobs) $root 60
        $passed = -not $actual.timedOut -and $actual.exit -eq 1 -and $actual.stdout -ceq $expected -and $actual.stderr -ceq ''
        $checks.Add([pscustomobject]@{case=$case.Id; jobs=$jobs; expectedExit=1; expected=$expected; actual=$actual; passed=$passed})
        if (-not $passed) { throw "Lifecycle multi-source check failed: $($case.Id) jobs=$jobs : $($actual | ConvertTo-Json -Compress), expected=$expected" }
    }
}
if ($checks.Count -ne 37) { throw 'Incomplete lifecycle cases.' }
$report = Join-Path $run 'report.json'
[pscustomobject]@{success=$true;executable=(Get-ArtifactIdentity $exe);checks=$checks.ToArray();scope='Lifecycle deferral and unrelated-name controls for source and project jobs 1/2/4; not native build qualification.'} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $report -Encoding UTF8
Write-Output "Evidence: $report"
Write-Output "PASS lifecycle deferral: $($checks.Count) source/project checks."
