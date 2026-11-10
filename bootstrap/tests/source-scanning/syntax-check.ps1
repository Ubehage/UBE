# Exercises scanner syntax dependencies with exact constants and controlled diagnostics.
param([Parameter(Mandatory=$true)][string]$BootstrapExe)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Join-Path ([IO.Path]::GetTempPath()) ('ube scanning syntax ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $root -Force
$exe = [IO.Path]::GetFullPath($BootstrapExe)
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Bootstrap executable does not exist: $exe" }
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)
$script:passed = 0

# Creates an isolated native module, bounds the child, and checks exact success or diagnostic evidence.
function Run-Case([string]$Name, [string]$Body, [string]$Code = '', [hashtable]$Constants = @{}) {
    $folder = Join-Path $root ('focused-' + $Name)
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $manifest = Join-Path $folder 'project.UBE'
    [IO.File]::WriteAllText($manifest, "UBE-Project 1`r`nName = `"Focus`"`r`nKind = `"Library`"`r`nSource = `"Probe.bas`"`r`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $folder 'Probe.bas'), "UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`n" + $Body.Replace("`r`n", "`n").Replace("`n", "`r`n") + "`r`n", $utf8)
    $process = Start-Process -FilePath $exe -ArgumentList ('--dump-bound "' + $manifest + '"') -WorkingDirectory $root -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $folder 'stdout') -RedirectStandardError (Join-Path $folder 'stderr')
    try {
        $handle = $process.Handle
        if (-not $process.WaitForExit(30000)) { $process.Kill(); $null = $process.WaitForExit(5000); throw "Timeout: $Name. Evidence: $folder" }
        $process.Refresh()
        if ($null -eq $process.ExitCode) { throw "Missing exit code for retained handle $handle. Evidence: $folder" }
        $output = [IO.File]::ReadAllText((Join-Path $folder 'stdout'), $utf8)
        $errorText = [IO.File]::ReadAllText((Join-Path $folder 'stderr'), $utf8)
        if ($Code) {
            if ($process.ExitCode -ne 1 -or $errorText -notmatch ('^UBE: ' + $Code + ':') -or $errorText -notmatch 'Probe\.bas:\d+:\d+' -or $output -match 'ANALYZE OK') { throw "Unexpected rejection $Name : $errorText. Evidence: $folder" }
        } else {
            if ($process.ExitCode -ne 0 -or $errorText -or $output -notmatch '(?m)^ANALYZE OK\s*$') { throw "Unexpected failure $Name : $errorText. Evidence: $folder" }
            foreach ($key in $Constants.Keys) {
                $row = @($output -split '\r?\n' | Where-Object { $_ -match ('^SYMBOL [0-9]+\|constant\|' + $key + '\|') })
                if ($row.Count -ne 1) { throw "Missing constant $key in $Name" }
                $value = ($row[0] -split '\|')[13]
                if ($value -cne [string]$Constants[$key]) { throw "Wrong folded constant $key : $value" }
            }
        }
    } finally { $process.Dispose() }
    $script:passed++
    Write-Output "PASS: $Name"
}
Run-Case 'folding' @'
Option Explicit
Const Precedence As Boolean = Not 1 = 2 And True Or False
Const Bits As Long = 1 Or 2 And 4
Const Difference As Long = 10 - 3 - 2
Const Complement As LongLong = Not 9223372036854775807^
Const NegativeBits As LongLong = -9223372036854775808^ Or 1^
Const BooleanFlip As Boolean = Not True
'@ '' @{Precedence='-1';Bits='1';Difference='5';Complement='-9223372036854775808';NegativeBits='-9223372036854775807';BooleanFlip='0'}
Run-Case 'loops' @'
Sub ProbeLoops(ByVal Value As Long)
Do While Value > 0
 Value = Value - 1
 Do
  Exit Do
 Loop
Loop
Do Until Value = 0
 Value = 0
Loop
Do
 Value = Value + 1
Loop While Value < 2
Do
 Value = Value - 1
Loop Until Value = 0
End Sub
'@
Run-Case 'runtime-condition' @'
Function Condition(ByVal Value As Long) As Boolean
 Err.Raise Value
End Function
Sub Work(ByVal Value As Long)
 If Condition(Value) Then Value = 1
 Do While Condition(Value)
  Exit Do
 Loop
End Sub
'@
Run-Case 'both-conditions' "Sub Work()`nDo While True`nLoop Until False`nEnd Sub" 'E_PARSE'
Run-Case 'exit-outside' "Sub Work()`nExit Do`nEnd Sub" 'E_PARSE'
Run-Case 'missing-loop' "Sub Work()`nDo`nEnd Sub" 'E_PARSE'
Run-Case 'stray-loop' "Sub Work()`nLoop`nEnd Sub" 'E_PARSE'
Run-Case 'missing-condition' "Sub Work()`nDo While`nLoop`nEnd Sub" 'E_PARSE'
Run-Case 'unparenthesized-not' "Const Value As Long = 1 + Not 2" 'E_PARSE'
Run-Case 'subtraction-overflow' "Const Value As Long = -2147483648& - 1&" 'E_CONSTANT'
Run-Case 'mixed-or' "Const Value As Boolean = True Or 1" 'E_UNSUPPORTED'
Run-Case 'boolean-subtract' "Const Value As Boolean = True - False" 'E_UNSUPPORTED'
Run-Case 'resume-deferred' "Sub Work()`nResume`nEnd Sub" 'E_UNSUPPORTED'
Write-Output "PASS: $script:passed focused parser/binder cases. Artifacts: $root"
