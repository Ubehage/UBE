# Builds and exercises bounded project parsing with structural binding assertions.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube source semantics ' + [guid]::NewGuid())
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
function Invoke-BoundedProcess([string]$File, [string[]]$Arguments) {
    $script:processNumber++
    $prefix = Join-Path $artifacts ('process-' + $script:processNumber)
    $start = @{ FilePath=$File; WorkingDirectory=$workingDirectory; PassThru=$true; WindowStyle='Hidden'; RedirectStandardOutput=($prefix + '.stdout'); RedirectStandardError=($prefix + '.stderr') }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @start
    try {
        $retainedHandle = $process.Handle
        if (-not $process.WaitForExit(30000)) {
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

# Requires controlled rejection with the expected diagnostic and source location.
function Assert-Rejected([string]$Name, [string]$Manifest, [string]$Code, [string]$Location) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--analyze', $Manifest)
    if ($result.ExitCode -ne 1 -or $result.Stdout -match '(?m)^ANALYZE OK\s*$' -or $result.Stderr -notmatch ('(?m)^UBE: ' + [regex]::Escape($Code) + ':')) {
        throw "$Name expected exit1 and $Code. Evidence: $($result.Evidence)"
    }
    if ($Location -and $result.Stderr -notmatch [regex]::Escape($Location)) { throw "$Name missing location $Location. Evidence: $($result.Evidence)" }
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
    if ($build.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $BootstrapExe)) { throw "VB6 build failed. Evidence: $buildDirectory" }
}
$BootstrapExe = [IO.Path]::GetFullPath($BootstrapExe)
if (-not (Test-Path -LiteralPath $BootstrapExe)) { throw "Bootstrap executable not found: $BootstrapExe" }

# Stops the gate at the first violated semantic acceptance assertion.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Decodes escaped dump fields while retaining embedded delimiters and slashes.
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

# Reconstructs symbol/type evidence without treating a zero exit as sufficient.
function Read-Bound([string]$Manifest) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--dump-bound', $Manifest)
    Require ($result.ExitCode -eq 0 -and $result.Stderr.Length -eq 0 -and $result.Stdout -match '(?m)^ANALYZE OK\r?$') "Bound dump failed. Evidence: $($result.Evidence)"
    $symbols = @{}
    $nodes = @{}
    $entry = -1
    foreach ($line in $result.Stdout.Replace("`r`n", "`n").Split("`n")) {
        if ($line.StartsWith('ENTRY ')) {
            $entry = [int]$line.Substring(6)
        } elseif ($line.StartsWith('SYMBOL ')) {
            $f = @(Decode-Fields $line.Substring(7))
            Require ($f.Count -eq 24) "Invalid SYMBOL framing: $line"
            $symbols[[int]$f[0]] = [pscustomobject]@{ Id=[int]$f[0]; Kind=$f[1]; Name=$f[2]; Type=$f[3]; Visibility=$f[4]; Module=[int]$f[5]; Scope=[int]$f[6]; Declaration=[int]$f[7]; Mode=$f[8]; Role=$f[9]; FirstParameter=[int]$f[10]; NextParameter=[int]$f[11]; ParameterCount=[int]$f[12]; Constant=$f[13] }
        } elseif ($line.StartsWith('BOUND ')) {
            $f = @(Decode-Fields $line.Substring(6))
            Require ($f.Count -eq 16) "Invalid BOUND framing: $line"
            $nodes[[int]$f[0]] = [pscustomobject]@{ Id=[int]$f[0]; Symbol=[int]$f[1]; Type=$f[2]; Converted=$f[3]; Mode=$f[4]; Writable=$f[5]; Constant=$f[6]; Scope=[int]$f[7] }
        }
    }
    Require ($symbols.Count -gt 0 -and $nodes.Count -gt 0) 'Empty binding evidence'
    return [pscustomobject]@{ Symbols=$symbols; Nodes=$nodes; Entry=$entry; Raw=$result.Stdout }
}

# Selects one declaration, excluding its separate implicit function-result slot.
function Find-Symbol($Bound, [string]$Name, [int]$Module = -999) {
    $matches = @($Bound.Symbols.Values | Where-Object { $_.Name -ieq $Name -and $_.Kind -ne 'result' -and ($Module -eq -999 -or $_.Module -eq $Module) })
    Require ($matches.Count -eq 1) "Expected one symbol $Name, got $($matches.Count)"
    return $matches[0]
}

# Requires exact ordered analysis summaries independently of detailed dumps.
function Assert-Accepted([string]$Name, [string]$Manifest, [string[]]$Expected) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--analyze', $Manifest)
    $actual = $result.Stdout.Replace("`r`n", "`n").TrimEnd("`n")
    Require ($result.ExitCode -eq 0 -and $result.Stderr.Length -eq 0 -and $actual -ceq ($Expected -join "`n")) "$Name analysis failed. Evidence: $($result.Evidence)"
    $script:passed++
    Write-Output "PASS: $Name"
}

$mainBody = @'
Private Value As Long
Public Function Main() As Long
    Dim Value As Long = 1
    Dim Flag As Boolean = True
    Const LocalAnswer As Long = 40 + 2
    Value = Helpers.Add(Value, LocalAnswer)
    Value = Helpers.Answer
    Helpers.Touch Value
    Helpers.Touch (Flag)
    Helpers.Take Flag
    Value = Flag
    Flag = Value
    On Error GoTo Failed
    GoTo Finished
Failed:
    Err.Clear
Finished:
    Main = Value
End Function
'@
$helpersBody = @'
Public Const Answer As Long = 40 + 2
Public Function Add(ByVal LeftValue As Long, ByVal RightValue As Long) As Long
    Add = LeftValue + RightValue
End Function
Public Sub Touch(ByRef Value As Long)
    Value = Value + 1
End Sub
Public Sub Take(ByVal Value As Long)
End Sub
'@
$scalarManifest = New-Fixture 'typed two module program' @($mainBody,$helpersBody) @('Program','Helpers') 'Exe'
Assert-Accepted 'typed scalar calls conversions scopes constants and handlers' $scalarManifest @('PROJECT SemanticFixture','MODULE Program','MODULE Helpers','ANALYZE OK')
$sample = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../examples/multi-module/Demo.UBE'))
Assert-Accepted 'checked-in Demo executable entry and qualified call' $sample @('PROJECT Demo','MODULE Program','MODULE Arithmetic','ANALYZE OK')

$oracle = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../failure-flow/SourceOracle.bas'), $utf8)
$oracleFolder = Join-Path $artifacts 'actual source oracle'
Write-Text (Join-Path $oracleFolder 'SourceOracle.bas') $oracle
$oracleManifest = Join-Path $oracleFolder 'project.UBE'
Write-Text $oracleManifest "UBE-Project 1`r`nName = `"Oracle`"`r`nKind = `"Library`"`r`nSource = `"SourceOracle.bas`"`r`n"
Assert-Accepted 'actual SourceOracle semantic acceptance without execution' $oracleManifest @('PROJECT Oracle','MODULE FailureFlowOracle','ANALYZE OK')
$oracleBound = Read-Bound $oracleManifest
Require ($oracleBound.Entry -eq 0) 'Library unexpectedly selected an executable entry'
foreach ($role in @('error.raise','error.clear','error.number')) {
    $support = @($oracleBound.Symbols.Values | Where-Object { $_.Role -eq $role })
    Require ($support.Count -eq 1 -and @($oracleBound.Nodes.Values | Where-Object { $_.Symbol -eq $support[0].Id }).Count -gt 0) "SourceOracle did not resolve trusted $role"
}
$script:passed++
Write-Output 'PASS: SourceOracle error operations retain trusted declaration identities'

$normalSummary = @('PROJECT SemanticFixture','MODULE Example','ANALYZE OK')
$manifest = New-Fixture 'sub executable entry' @("Public Sub Main()`nEnd Sub") @('Example') 'Exe'
Assert-Accepted 'Sub Main executable signature' $manifest $normalSummary
$manifest = New-Fixture 'default ByRef mode and function statement' @("Public Sub Touch(Value As Long)`nValue = 1`nEnd Sub`nPublic Function Result() As Long`nResult = 1`nEnd Function`nPublic Sub Run()`nDim Value As Long`nTouch Value`nCall Result()`nEnd Sub")
Assert-Accepted 'default ByRef and discarded function result' $manifest $normalSummary
$manifest = New-Fixture 'labels separate declaration region' @("Sub Run()`nDim Same As Long`nGoTo Same`nSame:`nSame = 1`nEnd Sub")
Assert-Accepted 'labels have separate procedure-local namespace' $manifest $normalSummary

$bound = Read-Bound $scalarManifest
$repeat = Read-Bound $scalarManifest
Require ($bound.Raw -ceq $repeat.Raw) 'Repeated semantic dump differs'
$touch = Find-Symbol $bound 'Touch' 1
$add = Find-Symbol $bound 'Add' 1
Require ($bound.Entry -gt 0 -and $bound.Symbols[$bound.Entry].Name -ieq 'Main' -and $bound.Symbols[$bound.Entry].Type -ieq 'Long' -and $bound.Symbols[$bound.Entry].ParameterCount -eq 0) 'Executable entry does not resolve to parameterless Long Main'
$mainSymbol = Find-Symbol $bound 'Main' 0
foreach ($labelName in @('Failed','Finished')) {
    $label = Find-Symbol $bound $labelName 0
    Require ($label.Kind -eq 'label' -and $label.Scope -eq $mainSymbol.Id) "Label $labelName is not scoped to Main"
    Require ($bound.Nodes[$label.Declaration].Symbol -eq $label.Id) "Label $labelName declaration binding mismatch"
    $references = @($bound.Nodes.Values | Where-Object { $_.Symbol -eq $label.Id -and $_.Id -ne $label.Declaration })
    Require ($references.Count -eq 1 -and $references[0].Scope -eq $mainSymbol.Id) "Control target $labelName does not resolve to its Main-local label"
}
Require ($touch.ParameterCount -eq 1 -and $add.ParameterCount -eq 2 -and $add.Type -ieq 'Long') 'Procedure signature evidence mismatch'
$touchParameter = $bound.Symbols[$touch.FirstParameter]
Require ($touchParameter.Mode -ieq 'ByRef' -and $touchParameter.Type -ieq 'Long') 'ByRef formal evidence mismatch'
$answer = Find-Symbol $bound 'Answer' 1
Require ($answer.Constant -eq '42' -and $answer.Type -ieq 'Long') 'Typed constant folding evidence mismatch'
Require (@($bound.Nodes.Values | Where-Object { $_.Symbol -eq $add.Id }).Count -gt 0) 'Qualified call does not bind Add symbol'
Require (@($bound.Nodes.Values | Where-Object { $_.Symbol -eq $touch.Id }).Count -gt 0) 'Qualified call does not bind Touch symbol'
$aliases = @($bound.Nodes.Values | Where-Object { $_.Mode -eq 'alias' })
$temporaries = @($bound.Nodes.Values | Where-Object { $_.Mode -eq 'temp' })
Require ($aliases.Count -eq 1 -and $aliases[0].Type -ieq 'Long' -and $aliases[0].Writable -eq '1' -and $aliases[0].Converted -ieq 'Long') 'Direct ByRef did not retain exact writable Long storage'
Require ($temporaries.Count -eq 1 -and $temporaries[0].Type -ieq 'Boolean' -and $temporaries[0].Converted -ieq 'Long') 'Grouped ByRef did not request Boolean-to-Long temporary conversion'
Require (@($bound.Nodes.Values | Where-Object { $_.Mode -eq 'value' -and $_.Type -ieq 'Boolean' -and $_.Converted -ieq 'Long' }).Count -gt 0) 'ByVal Boolean-to-Long argument conversion missing'
$valueSymbols = @($bound.Symbols.Values | Where-Object { $_.Name -ieq 'Value' -and $_.Module -eq 0 })
Require ($valueSymbols.Count -eq 2 -and $valueSymbols[0].Scope -ne $valueSymbols[1].Scope) 'Local shadow and field do not have distinct scopes'
$roles = @($bound.Symbols.Values | Where-Object { $_.Role -like 'error.*' })
foreach ($role in @('error.raise','error.clear','error.number')) { Require (@($roles | Where-Object { $_.Role -eq $role }).Count -eq 1) "Missing unique trusted role $role" }
foreach ($node in $bound.Nodes.Values) {
    Require ($node.Symbol -eq 0 -or $bound.Symbols.ContainsKey($node.Symbol)) 'Dangling bound symbol reference'
    Require ($node.Scope -eq 0 -or $bound.Symbols.ContainsKey($node.Scope)) 'Dangling bound scope reference'
}
$script:passed++
Write-Output 'PASS: deterministic scoped symbols signatures constants and trusted support identities'

$constantsBody = @'
Public Const Base As Long = 40
Public Const Answer As Long = Base + 2
Public Function Constants() As Long
    Dim SelfValue As Long = SelfValue + 1
    Dim Wide As Long = 2147483648 + -1
    Dim Minimum As Long = -2147483648&
    Dim WideMinimum As Long = -9223372036854775808 + 9223372036854775807
    Dim Bits As Long = 6 And 3
    Dim WideBits As Long = (4294967297 And 4294967296) + -4294967296
    Dim TrueNumber As Long = True
    Dim Nonzero As Boolean = 2
    Constants = Answer
End Function
'@
$manifest = New-Fixture 'exact scalar constants' @($constantsBody)
Assert-Accepted 'wide decimal intermediates signed minimum and Long And' $manifest $normalSummary
$constantBound = Read-Bound $manifest
Require ((Find-Symbol $constantBound 'Answer').Constant -eq '42') 'Constant dependency value mismatch'
foreach ($expected in @('2147483647','-2147483648','2','-1')) { Require (@($constantBound.Nodes.Values | Where-Object { $_.Constant -eq $expected }).Count -gt 0) "Missing exact folded result $expected" }
$trueNumber = Find-Symbol $constantBound 'TrueNumber'
$nonzero = Find-Symbol $constantBound 'Nonzero'
$wideBits = Find-Symbol $constantBound 'WideBits'
Require ($constantBound.Nodes[$wideBits.Declaration].Type -ieq 'Long' -and $constantBound.Nodes[$wideBits.Declaration].Constant -eq '0') 'Wide bitwise And truncated its signed64 intermediate'
Require ($constantBound.Nodes[$trueNumber.Declaration].Type -ieq 'Long' -and $constantBound.Nodes[$trueNumber.Declaration].Constant -eq '-1') 'True-to-Long initializer did not retain converted -1'
Require ($constantBound.Nodes[$nonzero.Declaration].Type -ieq 'Boolean' -and $constantBound.Nodes[$nonzero.Declaration].Constant -eq '-1') 'Nonzero Long-to-Boolean initializer did not retain converted True'
Require ($trueNumber.Constant -eq '' -and $nonzero.Constant -eq '') 'Initialized variables incorrectly became constant symbols'
$script:passed++
Write-Output 'PASS: exact constant result evidence'

$userErrBody = "Public Sub Raise(ByVal Code As Long)`nEnd Sub"
$manifest = New-Fixture 'user Err module' @("Sub Run()`nErr.Raise 5`nEnd Sub",$userErrBody) @('Program','Err')
Assert-Accepted 'user Err module resolves ordinary Raise declaration' $manifest @('PROJECT SemanticFixture','MODULE Program','MODULE Err','ANALYZE OK')
$userBound = Read-Bound $manifest
$userRaise = Find-Symbol $userBound 'Raise' 1
Require ($userRaise.Role -eq '' -and @($userBound.Nodes.Values | Where-Object { $_.Symbol -eq $userRaise.Id }).Count -gt 0) 'User Raise received a trusted error role or was not resolved'
$script:passed++
Write-Output 'PASS: user Err member has ordinary declaration identity'

$negativeCases = @(
    @{ Name='undeclared value'; Body="Sub Run()`nMissing = 1`nEnd Sub"; Code='E_NAME'; Line=4 },
    @{ Name='Public Dim invalid introducer'; Body='Public Dim Value As Long'; Code='E_PARSE'; Line=3 },
    @{ Name='bare function not implicit call'; Body="Function GetValue() As Long`nEnd Function`nSub Run()`nDim Value As Long = GetValue`nEnd Sub"; Code='E_TYPE'; Line=6 },
    @{ Name='duplicate casefold locals'; Body="Sub Run()`nDim Value As Long`nDim vAlUe As Long`nEnd Sub"; Code='E_DUPLICATE'; Line=5 },
    @{ Name='duplicate suffix bracket identity'; Body="Sub Run()`nDim X&`nDim [x] As Long`nEnd Sub"; Code='E_DUPLICATE'; Line=5 },
    @{ Name='Global procedure invalid'; Body="Global Sub Run()`nEnd Sub"; Code='E_TYPE'; Line=3 },
    @{ Name='parameter local collision'; Body="Sub Run(ByVal Value As Long)`nDim Value As Long`nEnd Sub"; Code='E_DUPLICATE'; Line=4 },
    @{ Name='member procedure collision'; Body="Private Value As Long`nSub Value()`nEnd Sub"; Code='E_DUPLICATE'; Line=4 },
    @{ Name='too few arguments'; Body="Sub Take(ByVal Value As Long)`nEnd Sub`nSub Run()`nTake`nEnd Sub"; Code='E_ARGUMENT'; Line=6 },
    @{ Name='too many arguments'; Body="Sub Take()`nEnd Sub`nSub Run()`nTake 1`nEnd Sub"; Code='E_ARGUMENT'; Line=6 },
    @{ Name='direct ByRef literal'; Body="Sub Take(ByRef Value As Long)`nEnd Sub`nSub Run()`nTake 1`nEnd Sub"; Code='E_ARGUMENT'; Line=6 },
    @{ Name='direct ByRef type mismatch'; Body="Sub Take(ByRef Value As Long)`nEnd Sub`nSub Run()`nDim Flag As Boolean`nTake Flag`nEnd Sub"; Code='E_ARGUMENT'; Line=7 },
    @{ Name='direct ByRef constant'; Body="Sub Take(ByRef Value As Long)`nEnd Sub`nSub Run()`nConst Value As Long = 1`nTake Value`nEnd Sub"; Code='E_ARGUMENT'; Line=7 },
    @{ Name='Sub used as value'; Body="Sub Take()`nEnd Sub`nSub Run()`nDim Value As Long`nValue = Take()`nEnd Sub"; Code='E_TYPE'; Line=7 },
    @{ Name='assignment to other function'; Body="Function Value() As Long`nEnd Function`nSub Run()`nValue = 1`nEnd Sub"; Code='E_TYPE'; Line=6 },
    @{ Name='assignment to constant'; Body="Sub Run()`nConst Value As Long = 1`nValue = 2`nEnd Sub"; Code='E_TYPE'; Line=5 },
    @{ Name='constant reads variable'; Body="Dim Value As Long`nConst Bad As Long = Value"; Code='E_CONSTANT'; Line=4 },
    @{ Name='constant calls function'; Body="Function Value() As Long`nEnd Function`nConst Bad As Long = Value()"; Code='E_CONSTANT'; Line=5 },
    @{ Name='constant self cycle'; Body='Const Bad As Long = Bad'; Code='E_CONSTANT'; Line=3 },
    @{ Name='constant dependency cycle'; Body="Const First As Long = Second`nConst Second As Long = First"; Code='E_CONSTANT'; Line=3 },
    @{ Name='Long addition overflow'; Body="Sub Run()`nDim Value As Long = 2147483647 + 1`nEnd Sub"; Code='E_CONSTANT'; Line=4 },
    @{ Name='Long assignment overflow'; Body="Sub Run()`nDim Value As Long = 2147483648`nEnd Sub"; Code='E_CONSTANT'; Line=4 },
    @{ Name='Long suffix literal overflow'; Body="Sub Run()`nDim Value As Long = 2147483648&`nEnd Sub"; Code='E_CONSTANT'; Line=4 },
    @{ Name='signed64 literal overflow'; Body="Sub Run()`nDim Value As Long = 9223372036854775808`nEnd Sub"; Code='E_CONSTANT'; Line=4 },
    @{ Name='signed64 arithmetic overflow'; Body="Sub Run()`nDim Value As Long = 9223372036854775807 + 1`nEnd Sub"; Code='E_CONSTANT'; Line=4 },
    @{ Name='signed64 unary overflow'; Body="Sub Run()`nDim Value As Long = -(-9223372036854775808)`nEnd Sub"; Code='E_CONSTANT'; Line=4 },
    @{ Name='grouped suffix magnitude invalid'; Body="Sub Run()`nDim Value As Long = -(2147483648&)`nEnd Sub"; Code='E_CONSTANT'; Line=4 },
    @{ Name='missing goto label'; Body="Sub Run()`nGoTo Missing`nEnd Sub"; Code='E_LABEL'; Line=4 },
    @{ Name='missing handler label'; Body="Sub Run()`nOn Error GoTo Missing`nEnd Sub"; Code='E_LABEL'; Line=4 },
    @{ Name='cross procedure goto'; Body="Sub Other()`nTarget:`nEnd Sub`nSub Run()`nGoTo Target`nEnd Sub"; Code='E_LABEL'; Line=7 },
    @{ Name='duplicate folded label'; Body="Sub Run()`nTarget:`ntArGeT:`nEnd Sub"; Code='E_DUPLICATE'; Line=5 },
    @{ Name='local Err shadows support'; Body="Sub Run()`nDim Err As Long`nErr.Raise 5`nEnd Sub"; Code='E_TYPE'; Line=5 },
    @{ Name='readonly Err Number assignment'; Body="Sub Run()`nErr.Number = 5`nEnd Sub"; Code='E_TYPE'; Line=4 },
    @{ Name='readonly Err Number ByRef'; Body="Sub Take(ByRef Value As Long)`nEnd Sub`nSub Run()`nTake Err.Number`nEnd Sub"; Code='E_ARGUMENT'; Line=6 },
    @{ Name='Err Raise wrong arity'; Body="Sub Run()`nErr.Raise`nEnd Sub"; Code='E_ARGUMENT'; Line=4 },
    @{ Name='Err Clear used as value'; Body="Sub Run()`nDim Value As Long = Err.Clear()`nEnd Sub"; Code='E_TYPE'; Line=4 },
    @{ Name='hex semantics deferred'; Body="Sub Run()`nDim Value As Long = &H10&`nEnd Sub"; Code='E_UNSUPPORTED'; Line=4 },
    @{ Name='mixed Boolean numeric operator deferred'; Body="Sub Run()`nDim Value As Long = True + 1`nEnd Sub"; Code='E_UNSUPPORTED'; Line=4 }
)
foreach ($case in $negativeCases) {
    $manifest = New-Fixture $case.Name @($case.Body)
    Assert-Rejected $case.Name $manifest $case.Code ('Example.bas:' + $case.Line + ':')
}

$entryCases = @(
    @{ Name='missing Main'; Bodies=@("Sub Other()`nEnd Sub"); Modules=@('Example') },
    @{ Name='Main parameter'; Bodies=@("Sub Main(ByVal Value As Long)`nEnd Sub"); Modules=@('Example') },
    @{ Name='Main result type'; Bodies=@("Function Main() As Boolean`nEnd Function"); Modules=@('Example') },
    @{ Name='multiple Main'; Bodies=@("Sub Main()`nEnd Sub", "Sub Main()`nEnd Sub"); Modules=@('First','Second') },
    @{ Name='invalid Main beside valid Main'; Bodies=@("Sub Main(ByVal Value As Long)`nEnd Sub", "Sub Main()`nEnd Sub"); Modules=@('First','Second') }
)
foreach ($case in $entryCases) {
    $manifest = New-Fixture $case.Name $case.Bodies $case.Modules 'Exe'
    Assert-Rejected $case.Name $manifest 'E_ENTRY' ''
}
$manifest = New-Fixture 'private foreign procedure' @("Sub Run()`nOther.Hidden`nEnd Sub", "Private Sub Hidden()`nEnd Sub") @('Program','Other')
Assert-Rejected 'private procedure inaccessible from another module' $manifest 'E_NAME' 'Program.bas:4:'
foreach ($declaration in @('Dim Value As Long','Const Value As Long = 1')) {
    $caseName = 'default private ' + $declaration.Split(' ')[0]
    $manifest = New-Fixture $caseName @("Sub Run()`nDim Result As Long = Other.Value`nEnd Sub",$declaration) @('Program','Other')
    Assert-Rejected $caseName $manifest 'E_NAME' 'Program.bas:4:'
}
$manifest = New-Fixture 'Global field visible' @("Sub Run()`nOther.Value = 1`nEnd Sub",'Global Value As Long') @('Program','Other')
Assert-Accepted 'Global module variable is public' $manifest @('PROJECT SemanticFixture','MODULE Program','MODULE Other','ANALYZE OK')
$manifest = New-Fixture 'selected signature no fallback' @("Sub Choose(ByVal Value As Long)`nEnd Sub`nSub Run()`nChoose`nEnd Sub", "Public Sub Choose()`nEnd Sub") @('Program','Other')
Assert-Rejected 'current module wrong arity does not fall back to package member' $manifest 'E_ARGUMENT' 'Program.bas:6:'
$manifest = New-Fixture 'local shadow no fallback' @("Sub Run()`nDim Choose As Long`nChoose 1`nEnd Sub", "Public Sub Choose(ByVal Value As Long)`nEnd Sub") @('Program','Other')
Assert-Rejected 'local storage shadow does not fall back to package procedure' $manifest 'E_TYPE' 'Program.bas:5:'
$manifest = New-Fixture 'ambiguous package procedure' @("Sub Run()`nChoose`nEnd Sub", "Public Sub Choose()`nEnd Sub", "Public Sub Choose()`nEnd Sub") @('Program','First','Second')
Assert-Rejected 'package lookup ambiguity is not manifest order' $manifest 'E_AMBIGUOUS' 'Program.bas:4:'
$manifest = New-Fixture 'qualified ambiguous package members' @("Sub Run()`nFirst.Choose`nSecond.Choose`nEnd Sub", "Public Sub Choose()`nEnd Sub", "Public Sub Choose()`nEnd Sub") @('Program','First','Second')
Assert-Accepted 'qualification resolves otherwise ambiguous public members' $manifest @('PROJECT SemanticFixture','MODULE Program','MODULE First','MODULE Second','ANALYZE OK')
$qualifiedBound = Read-Bound $manifest
foreach ($moduleIndex in @(1,2)) {
    $choice = Find-Symbol $qualifiedBound 'Choose' $moduleIndex
    Require (@($qualifiedBound.Nodes.Values | Where-Object { $_.Symbol -eq $choice.Id }).Count -gt 0) 'Qualified call bound to wrong declaration'
}
$script:passed++
Write-Output 'PASS: distinct qualified symbol identities'
$manifest = New-Fixture 'package qualified friend call' @("Sub Run()`nSemanticFixture.Helpers.Touch`nEnd Sub", "Friend Sub Touch()`nEnd Sub") @('Program','Helpers')
Assert-Accepted 'package-qualified Friend procedure is visible within package' $manifest @('PROJECT SemanticFixture','MODULE Program','MODULE Helpers','ANALYZE OK')
$packageBound = Read-Bound $manifest
$friend = Find-Symbol $packageBound 'Touch' 1
Require (@($packageBound.Nodes.Values | Where-Object { $_.Symbol -eq $friend.Id }).Count -gt 0 -and $friend.Visibility -ieq 'Friend') 'Package-qualified Friend declaration binding mismatch'
$script:passed++
Write-Output 'PASS: package qualifier and Friend visibility evidence'
$manifest = New-Fixture 'package qualified function arguments' @("Sub Run()`nDim Value As Long = SemanticFixture.Helpers.Add(1, 2)`nEnd Sub",$helpersBody) @('Program','Helpers')
Assert-Accepted 'package-qualified function with positional arguments' $manifest @('PROJECT SemanticFixture','MODULE Program','MODULE Helpers','ANALYZE OK')
$packageFunctionBound = Read-Bound $manifest
$packageAdd = Find-Symbol $packageFunctionBound 'Add' 1
Require (@($packageFunctionBound.Nodes.Values | Where-Object { $_.Symbol -eq $packageAdd.Id }).Count -gt 0) 'Package-qualified function selected wrong declaration'
$script:passed++
Write-Output 'PASS: package-qualified function identity'
$manifest = New-Fixture 'cross module constant dependency deferred' @('Const Value As Long = Helpers.Answer',$helpersBody) @('Program','Helpers')
Assert-Rejected 'cross-module required constant dependency explicitly deferred' $manifest 'E_UNSUPPORTED' 'Program.bas:3:'
$manifest = New-Fixture 'package module qualifier collision' @("Sub Run()`nDim Value As Long = SemanticFixture.Helper.Value()`nEnd Sub", "Function Value() As Long`nValue = 1`nEnd Function", "Function Value() As Long`nValue = 2`nEnd Function") @('Program','SemanticFixture','Helper')
Assert-Rejected 'colliding package and module qualifier explicitly deferred' $manifest 'E_UNSUPPORTED' 'Program.bas:4:'
$manifest = New-Fixture 'user Err missing member' @("Sub Run()`nErr.Clear`nEnd Sub",$userErrBody) @('Program','Err')
Assert-Rejected 'user Err module prevents builtin member fallback' $manifest 'E_NAME' 'Program.bas:4:'
$failedDump = Invoke-BoundedProcess $BootstrapExe @('--dump-bound', $manifest)
Require ($failedDump.ExitCode -eq 1 -and $failedDump.Stdout -notmatch '(?m)^(SYMBOL |BOUND |ANALYZE OK)') 'Failed analysis published partial binding evidence'
$script:passed++
Write-Output 'PASS: no partial symbol or binding publication on failed module'

$manifest = New-Fixture 'near semantic expression depth' @("Function Run() As Long`nRun = " + ((1..110 | ForEach-Object { '1' }) -join ' + ') + "`nEnd Function")
Assert-Accepted 'long left associative expression below semantic depth limit' $manifest $normalSummary
$manifest = New-Fixture 'semantic expression depth limit' @("Function Run() As Long`nRun = " + ((1..150 | ForEach-Object { '1' }) -join ' + ') + "`nEnd Function")
Assert-Rejected 'semantic recursion bounded independently of parser nesting' $manifest 'E_LIMIT' 'Example.bas:'

# Split declarations so each module remains below the lexical token cap.
$halfA = ((1..8500 | ForEach-Object { 'Private A' + $_ + ' As Long' }) -join "`n")
$halfB = ((1..8500 | ForEach-Object { 'Private B' + $_ + ' As Long' }) -join "`n")
$manifest = New-Fixture 'semantic symbol limit' @($halfA,$halfB) @('SymbolsA','SymbolsB')
Assert-Rejected 'semantic symbol count bounded' $manifest 'E_LIMIT' 'SymbolsB.bas:'

Assert-Accepted 'valid invocation after all rejected analyses' $scalarManifest @('PROJECT SemanticFixture','MODULE Program','MODULE Helpers','ANALYZE OK')
Write-Output "PASS: $($script:passed) source-semantics cases; no lowering or execution claims."
