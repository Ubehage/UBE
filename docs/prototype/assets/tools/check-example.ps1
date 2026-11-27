param(
    [Parameter(Mandatory=$true)][string]$CompilerExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$evidence = Join-Path $env:TEMP ('ube help example ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $evidence
$utf8 = New-Object Text.UTF8Encoding($false)
$source = [IO.File]::ReadAllText((Join-Path $root 'examples/Ticket.bas'))
$html = [IO.File]::ReadAllText((Join-Path $root 'pages/if.html'))
$match = [regex]::Match($html, '<code id="example-source">([\s\S]*?)</code>')
if (-not $match.Success) { throw 'Displayed example source is missing.' }
$displayed = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
$headerMatch = [regex]::Match($source, '\AUBE SOURCE 1 MODULE\r?\nAttribute UBE_Name = "Ticket"\r?\n\r?\n')
if (-not $headerMatch.Success) { throw 'Native test fixture header is missing.' }
$header = $headerMatch.Value
$source = $source.Substring($header.Length)
if ($displayed.Replace("`r`n", "`n").Trim() -cne $source.Replace("`r`n", "`n").Trim()) { throw 'Displayed code and native fixture body differ.' }
function Quote-Argument([string]$Value) { return '"' + $Value + '"' }
function Run-Process([string]$File, [string[]]$Arguments, [int]$Expected, [string]$Prefix) {
    $options = @{FilePath=$File; WindowStyle='Hidden'; PassThru=$true; RedirectStandardOutput=($Prefix+'.stdout'); RedirectStandardError=($Prefix+'.stderr')}
    if ($Arguments.Count) { $options.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @options
    try {
        $handle = $process.Handle
        if (-not $process.WaitForExit(60000)) { $process.Kill(); throw 'Example process exceeded its deadline.' }
        $process.Refresh()
        if ($process.ExitCode -ne $Expected) { throw "Expected exit $Expected, got $($process.ExitCode). See $Prefix" }
        if ([IO.File]::ReadAllText($Prefix+'.stderr').Length) { throw "Unexpected stderr. See $Prefix" }
        return [IO.File]::ReadAllText($Prefix+'.stdout')
    } finally { $process.Dispose() }
}
foreach ($level in @(0,2)) {
    foreach ($age in @(12,16,30)) {
        $folder = Join-Path $evidence "age-$age-O$level"
        $null = New-Item -ItemType Directory -Path $folder
        $text = $header + $displayed.Replace('Age = 12', "Age = $age")
        [IO.File]::WriteAllText((Join-Path $folder 'Ticket.bas'), $text, $utf8)
        $manifest = [IO.File]::ReadAllText((Join-Path $root 'examples/Ticket.UBE')) + "`r`nOptimization = `"$level`"`r`n"
        [IO.File]::WriteAllText((Join-Path $folder 'Ticket.UBE'), $manifest, $utf8)
        $exe = Join-Path $folder 'Ticket.exe'
        $output = Run-Process $CompilerExe @('--build', (Join-Path $folder 'Ticket.UBE'), $exe, '--clang', $Clang) 0 (Join-Path $folder 'build')
        if ($output -notmatch '(?m)^BUILD OK\r?$') { throw "Missing build marker: $folder" }
        $expected = if ($age -lt 16) { 10 } else { 20 }
        $output = Run-Process $exe @() $expected (Join-Path $folder 'run')
        if ($output.Length) { throw 'Unexpected program stdout.' }
        Write-Output "PASS age $age at O$level returns $expected; stdout/stderr empty"
    }
}
Write-Output "PASS exact displayed code with native fixture header and six native runs. Evidence: $evidence"
Get-FileHash -LiteralPath $CompilerExe -Algorithm SHA256 | Format-List
