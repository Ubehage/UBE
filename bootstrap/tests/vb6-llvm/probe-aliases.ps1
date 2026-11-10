$ErrorActionPreference = 'Stop'
# Tests each candidate separately so one rejected spelling cannot hide later candidates.
$vb6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE'
$root = Join-Path ([IO.Path]::GetTempPath()) ('ube-vb6-spellings-' + [guid]::NewGuid())
New-Item -ItemType Directory $root | Out-Null
$index = 0
$lines = @(Get-Content (Join-Path $PSScriptRoot 'Aliases.bas')) + @('Text = LoadResString$(1)', 'Text = StrConv$(Text, vbUpperCase)')
foreach ($line in $lines) {
    if ($line -notmatch '^\s*Text = (.+)$') { continue }
    $expression = $Matches[1]
    $folder = Join-Path $root ([string]$index)
    New-Item -ItemType Directory $folder | Out-Null
    Copy-Item (Join-Path $PSScriptRoot 'Aliases.vbp') $folder
    @('Attribute VB_Name = "Aliases"','Option Explicit','Public Sub Main()','End Sub','Private Sub Probe()','Dim Text As String',"Text = $expression",'End Sub') | Set-Content (Join-Path $folder 'Aliases.bas') -Encoding ASCII
    $project = Join-Path $folder 'Aliases.vbp'
    $log = Join-Path $folder 'build.log'
    $process = Start-Process $vb6 -ArgumentList "/make `"$project`" /out `"$log`" /outdir `"$folder`"" -PassThru -WindowStyle Hidden
    if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'VB6 timed out.' }
    $accepted = Test-Path (Join-Path $folder 'AliasProbe.exe')
    $expectRejected = $expression.StartsWith('LoadResString$') -or $expression.StartsWith('StrConv$')
    if ($accepted -eq $expectRejected) { throw "Unexpected acceptance result for $expression" }
    $diagnostic = 'Type-declaration character does not match declared data type'
    if ($expression.StartsWith('StrConv$')) { $diagnostic = 'Sub or Function not defined' }
    if ($expectRejected -and (Get-Content $log -Raw) -notmatch $diagnostic) { throw "Unexpected rejection reason for $expression" }
    Write-Output "PASS: $expression accepted=$accepted"
    $index++
}
Write-Output "Artifacts: $root"
