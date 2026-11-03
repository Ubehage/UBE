param(
    [Parameter(Mandatory = $true)][string[]]$Compiler,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$out = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($out) | Out-Null
$caseDir = Join-Path $out ([Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($caseDir) | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $caseDir 'App.bas'), "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"App`"`nPublic Sub Main()`nEnd Sub`n", $utf8)
$header = "UBE-Project 1`nName = `"Settings`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"App.bas`"`n"
$count = 0
foreach ($opt in @('0', '1', '2', '3', 'Size', 'invalid')) {
    foreach ($debug in @('None', 'Line', 'Full', 'invalid')) {
        $manifest = Join-Path $caseDir ("case-$opt-$debug.UBE")
        [IO.File]::WriteAllText($manifest, ($header + "Optimization = `"$opt`"`nDebugInformation = `"$debug`"`n"), $utf8)
        $valid = ($opt -ne 'invalid' -and $debug -ne 'invalid')
        foreach ($cli in $Compiler) {
            foreach ($jobs in @(1, 4)) {
                $output = @(& $cli --check $manifest --jobs $jobs 2>&1 | ForEach-Object { "$_" })
                $status = $LASTEXITCODE
                if ($valid -and ($status -ne 0 -or $output.Count -ne 0)) {
                    throw "Valid $opt/$debug rejected by $cli jobs=$jobs : $status $output"
                }
                if (-not $valid -and ($status -ne 1 -or ($output -join "`n") -notmatch 'UBE1306')) {
                    throw "Invalid $opt/$debug did not report UBE1306 by $cli jobs=$jobs : $status $output"
                }
                $count++
            }
        }
    }
}
Write-Output "Passed $count frontend settings admission checks in $caseDir; native build behavior was not tested."
