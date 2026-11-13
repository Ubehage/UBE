# Builds and exercises bounded project parsing with structural AST assertions.
param(
    [string]$VB6 = 'C:\Program Files (x86)\Microsoft Visual Studio\VB98\VB6.EXE',
    [string]$BootstrapExe = ''
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube source parsing ' + [guid]::NewGuid())
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
function New-Fixture([string]$Name, [string[]]$Bodies, [string[]]$ModuleNames = @('Example')) {
    $folder = Join-Path $artifacts $Name
    $lines = @('UBE-Project 1', 'Name = "ParserFixture"', 'Kind = "Library"')
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
    $result = Invoke-BoundedProcess $BootstrapExe @('--parse', $Manifest)
    if ($result.ExitCode -ne 1 -or $result.Stdout -match '(?m)^PARSE OK\s*$' -or $result.Stderr -notmatch ('(?m)^UBE: ' + [regex]::Escape($Code) + ':')) {
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

# Stops the gate at the first violated acceptance assertion.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Decodes escaped NODE fields without splitting literal delimiter characters.
function Decode-Fields([string]$Record) {
    $fields = New-Object 'Collections.Generic.List[string]'
    $field = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $Record.Length; $i++) {
        $character = $Record[$i]
        if ($character -eq '\') {
            $i++
            Require ($i -lt $Record.Length) 'Truncated AST field escape'
            switch ($Record[$i]) {
                '\' { $null = $field.Append('\') }
                'p' { $null = $field.Append('|') }
                'r' { $null = $field.Append("`r") }
                'n' { $null = $field.Append("`n") }
                default { throw 'Unknown AST field escape' }
            }
        } elseif ($character -eq '|') {
            $fields.Add($field.ToString())
            $null = $field.Clear()
        } else { $null = $field.Append($character) }
    }
    $fields.Add($field.ToString())
    return $fields.ToArray()
}

# Requires a successful dump and reconstructs its documented node records.
function Read-Ast([string]$Manifest) {
    $result = Invoke-BoundedProcess $BootstrapExe @('--dump-ast', $Manifest)
    Require ($result.ExitCode -eq 0 -and $result.Stderr.Length -eq 0) "AST failed. Evidence: $($result.Evidence)"
    $lines = @($result.Stdout.Replace("`r`n", "`n").TrimEnd("`n").Split("`n"))
    Require ($lines[-1] -ceq 'PARSE OK') "Missing PARSE OK. Evidence: $($result.Evidence)"
    $nodes = @{}
    foreach ($line in $lines) {
        if ($line.StartsWith('NODE ')) {
            $fields = @(Decode-Fields $line.Substring(5))
            Require ($fields.Count -eq 13) "Unexpected AST record: $line"
            $node = [pscustomobject]@{ Id=[int]$fields[0]; Kind=$fields[1]; Text=$fields[2]; Module=[int]$fields[3]; Line=[int]$fields[4]; Column=[int]$fields[5]; FirstChild=[int]$fields[6]; NextSibling=[int]$fields[7]; Parent=[int]$fields[8]; Type=$fields[9]; Modifiers=$fields[10]; Offset=[int]$fields[11]; Length=[int]$fields[12] }
            $nodes[$node.Id] = $node
        }
    }
    Require ($nodes.Count -gt 0) 'No AST evidence'
    return [pscustomobject]@{ Nodes=$nodes; Lines=$lines; Raw=$result.Stdout; Evidence=$result.Evidence }
}

# Enumerates ordered children while rejecting broken or cyclic sibling links.
function Children($Ast, $Node) {
    $id = $Node.FirstChild
    $visited = @{}
    while ($id -ne 0) {
        Require ($Ast.Nodes.ContainsKey($id) -and -not $visited.ContainsKey($id)) 'Invalid/cyclic child link'
        $visited[$id] = $true
        $child = $Ast.Nodes[$id]
        Require ($child.Parent -eq $Node.Id) 'Child parent link mismatch'
        $child
        $id = $child.NextSibling
    }
}

# Requires exactly one node with the selected kind and source identity.
function Find-One($Ast, [string]$Kind, [string]$Text) {
    $matches = @($Ast.Nodes.Values | Where-Object { $_.Kind -ceq $Kind -and $_.Text -ieq $Text })
    Require ($matches.Count -eq 1) "Expected one $Kind '$Text', got $($matches.Count)"
    return $matches[0]
}

# Serializes subtree structure for operator, argument and branch assertions.
function Shape($Ast, $Node) {
    $children = @(Children $Ast $Node)
    if ($children.Count -eq 0) { return $Node.Kind + ':' + $Node.Text.ToLowerInvariant() }
    $parts = @($children | ForEach-Object { Shape $Ast $_ })
    return $Node.Kind + ':' + $Node.Text.ToLowerInvariant() + '(' + ($parts -join ',') + ')'
}

$body = @'
Private Trace As Long
Public Function Mix(ByVal A As Long, ByRef B As Long) As Long
    Dim Flag As Boolean
    Dim Result As Long
    Result = A + 2 + 3
    Flag = A + 1 = B And B <> 0
    If Flag Then Result = 1 Else Result = 2
    If A < B Then
        Result = Mix(A, B)
    Else
        Result = 0
    End If
    On Error GoTo Failed
    Call Touch(Result)
    Touch Result
    On Error Resume Next
    On Error GoTo 0
    GoTo Finished
Failed:
    Err.Clear
    Err.Raise 5
Finished:
    Mix = Err.Number
    Exit Function
End Function
Public Sub Touch(ByRef Value As Long)
    Value = Value + 1
    Exit Sub
End Sub
'@
$other = @'
Public Sub Other()
    Dim Flag As Boolean
    Flag = True
    If Flag Then
        Flag = False
    End If
End Sub
'@
$manifest = New-Fixture 'scalar syntax' @($body, $other) @('Scalar', 'Second')
$ast = Read-Ast $manifest
$repeat = Read-Ast $manifest
Require ($ast.Raw -ceq $repeat.Raw) 'Repeated AST output differs'
$summary = Invoke-BoundedProcess $BootstrapExe @('--parse', $manifest)
Require ($summary.ExitCode -eq 0 -and $summary.Stderr.Length -eq 0 -and $summary.Stdout.Replace("`r`n", "`n").TrimEnd("`n") -ceq "PROJECT ParserFixture`nMODULE Scalar`nMODULE Second`nPARSE OK") 'Parse summary mismatch'
$mix = Find-One $ast 'function' 'Mix'
Require ($mix.Type -ieq 'Long' -and $mix.Line -eq 4 -and $mix.Column -ge 1) 'Function result type/span mismatch'
$parameters = @(Children $ast $mix | Where-Object { $_.Kind -eq 'parameter' })
Require ($parameters.Count -eq 2 -and $parameters[0].Text -eq 'A' -and $parameters[1].Text -eq 'B' -and $parameters[0].Modifiers -match 'byval' -and $parameters[1].Modifiers -match 'byref') 'Parameter order/mode mismatch'
$shapes = @($ast.Nodes.Values | Where-Object { $_.Kind -eq 'binary' } | ForEach-Object { Shape $ast $_ })
Require ($shapes -contains 'binary:+(binary:+(name:a,number:2),number:3)') 'Addition is not left associative'
Require ($shapes -contains 'binary:and(binary:=(binary:+(name:a,number:1),name:b),binary:<>(name:b,number:0))') 'Addition/comparison/And precedence mismatch'
$three = Find-One $ast 'number' '3'
$scalarText = Module-Text 'Scalar' $body
$threeOffset = $scalarText.IndexOf('A + 2 + 3') + 'A + 2 + '.Length + 1
Require ($three.Module -eq 0 -and $three.Line -eq 7 -and $three.Column -eq 22 -and $three.Offset -eq $threeOffset -and $three.Length -eq 1) 'Literal exact UTF16 source span mismatch'
Require ($scalarText.Substring($three.Offset - 1, $three.Length) -ceq '3') 'Source span does not slice back to original literal'
$calls = @($ast.Nodes.Values | Where-Object { $_.Kind -eq 'call' } | ForEach-Object { Shape $ast $_ })
Require (@($calls | Where-Object { $_ -match '^call:.*\(name:mix,name:a,name:b\)$' }).Count -eq 1) 'Call positional argument order mismatch'
$ifs = @($ast.Nodes.Values | Where-Object { $_.Kind -eq 'if' })
Require ($ifs.Count -eq 3) 'Missing If nodes'
foreach ($node in $ifs) {
    $parts = @(Children $ast $node)
    Require ($parts.Count -ge 2 -and $parts[1].Kind -eq 'then') 'If condition/then child order mismatch'
    if ($parts.Count -gt 2) { Require ($parts[2].Kind -eq 'else') 'If else child order mismatch' }
}
$inlineIf = @($ifs | Where-Object { $_.Module -eq 0 -and $_.Line -eq 9 })
Require ($inlineIf.Count -eq 1) 'Single-line If span missing'
$inlineParts = @(Children $ast $inlineIf[0])
$thenShape = Shape $ast $inlineParts[1]
$elseShape = Shape $ast $inlineParts[2]
Require ($thenShape -match 'assignment:[^(]*\(name:result,number:1\)' -and $elseShape -match 'assignment:[^(]*\(name:result,number:2\)') 'Then/Else assignment attached to wrong branch'
foreach ($node in $ast.Nodes.Values) {
    if ($node.Module -ge 0) { Require ($node.Line -gt 0 -and $node.Column -gt 0 -and $node.Offset -ge 0 -and $node.Length -ge 0) 'Invalid source span' }
    $null = @(Children $ast $node)
}
$roots = @($ast.Nodes.Values | Where-Object { $_.Parent -eq 0 })
Require ($roots.Count -eq 1 -and $roots[0].Kind -eq 'project') 'AST must have one project root'
$pending = New-Object 'Collections.Generic.Stack[int]'
$pending.Push($roots[0].Id)
$reachable = @{}
while ($pending.Count -gt 0) {
    $id = $pending.Pop()
    Require (-not $reachable.ContainsKey($id)) 'AST has cycle or multiple parent edges'
    $reachable[$id] = $true
    foreach ($child in @(Children $ast $ast.Nodes[$id])) { $pending.Push($child.Id) }
}
Require ($reachable.Count -eq $ast.Nodes.Count) 'AST contains unreachable/orphan nodes'
$script:passed++
Write-Output 'PASS: scalar AST structure, ordering, precedence, branches, modes and spans'

$sampleManifest = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../examples/multi-module/Demo.UBE'))
$sampleAst = Read-Ast $sampleManifest
$sampleModules = @($sampleAst.Nodes.Values | Where-Object { $_.Kind -eq 'module' } | Sort-Object Module)
Require ($sampleModules.Count -eq 2 -and $sampleModules[0].Text -ceq 'Program' -and $sampleModules[1].Text -ceq 'Arithmetic') 'Checked-in sample module order mismatch'
$answerMember = Find-One $sampleAst 'member' 'Answer'
$receiver = @(Children $sampleAst $answerMember)
Require ($receiver.Count -eq 1 -and $receiver[0].Kind -eq 'name' -and $receiver[0].Text -ceq 'Arithmetic') 'Qualified sample member receiver mismatch'
$answerCall = $sampleAst.Nodes[$answerMember.Parent]
Require ($answerCall.Kind -eq 'call' -and @(Children $sampleAst $answerCall).Count -eq 1) 'Qualified sample call structure mismatch'
$script:passed++
Write-Output 'PASS: checked-in two-module sample retains qualified call syntax (not binding)'

$oracle = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../failure-flow/SourceOracle.bas'), $utf8)
$oracleFolder = Join-Path $artifacts 'actual source oracle'
Write-Text (Join-Path $oracleFolder 'SourceOracle.bas') $oracle
$oracleManifest = Join-Path $oracleFolder 'project.UBE'
Write-Text $oracleManifest "UBE-Project 1`r`nName = `"Oracle`"`r`nKind = `"Library`"`r`nSource = `"SourceOracle.bas`"`r`n"
$oracleAst = Read-Ast $oracleManifest
$oracleCases = Get-Content -Raw (Join-Path $PSScriptRoot '../failure-flow/source-oracles.json') | ConvertFrom-Json
foreach ($case in $oracleCases.cases) { $null = Find-One $oracleAst 'function' $case.procedure }
Require (@($oracleAst.Nodes.Values | Where-Object { $_.Kind -eq 'function' }).Count -eq 11) 'SourceOracle function count mismatch'
$script:passed++
Write-Output 'PASS: actual SourceOracle parsed, all callable checks represented (not executed)'

$continued = @'
Public Function Continued() As Long
    Continued = 1 + _ ' explicit continuation
        2
End Function
'@
$manifest = New-Fixture 'continuation' @($continued)
$continuedAst = Read-Ast $manifest
$plus = Find-One $continuedAst 'binary' '+'
Require ((Shape $continuedAst $plus) -eq 'binary:+(number:1,number:2)') 'Continuation changed expression structure'
$script:passed++
Write-Output 'PASS: explicit continuation with comment'

$grammarBody = @'
Rem comment at statement start
Public Function [Select](ByVal [If] As Long) As Long
    Dim [Then] As Long
    [Then] = [If] + 1: Rem after a colon
    If [If] = 0 Then Rem after Then
        [Then] = 2
    ElseIf [If] = 1 Then
        [Then] = 3
    Else Rem after Else
        [Then] = 4
    End If
    [Select] = [Then]
End Function
'@
$manifest = New-Fixture 'bracket names rem elseif' @($grammarBody)
$grammarAst = Read-Ast $manifest
$null = Find-One $grammarAst 'function' 'Select'
$grammarIfs = @($grammarAst.Nodes.Values | Where-Object { $_.Kind -eq 'if' })
Require ($grammarIfs.Count -eq 2) 'ElseIf did not create nested If structure'
$outerIf = @($grammarIfs | Where-Object { $_.Line -eq 7 })
Require ($outerIf.Count -eq 1) 'Outer If span mismatch'
$outerParts = @(Children $grammarAst $outerIf[0])
$elseChildren = @(Children $grammarAst $outerParts[2])
Require ($elseChildren.Count -eq 1 -and $elseChildren[0].Kind -eq 'if') 'ElseIf is not nested in outer else branch'
$script:passed++
Write-Output 'PASS: bracketed reserved names, Rem positions and ElseIf structure'

$labelBody = @'
Public Sub Numbered()
10 Rem comment after numeric line label
20: Rem comment after numeric colon label
    GoTo 10
End Sub
'@
$manifest = New-Fixture 'numeric line labels' @($labelBody)
$labelAst = Read-Ast $manifest
$ten = Find-One $labelAst 'label' '10'
$twenty = Find-One $labelAst 'label' '20'
$null = Find-One $labelAst 'goto' '10'
Require ($ten.Line -eq 4 -and $twenty.Line -eq 5) 'Numeric label source lines mismatch'
Require (@($labelAst.Nodes.Values | Where-Object { $_.Kind -eq 'call' }).Count -eq 0) 'Rem after numeric label became a call'
$script:passed++
Write-Output 'PASS: numeric line labels with Rem comments'

$memberBody = @'
Public Sub KeywordMember()
    Thing.Then [Rem]
End Sub
'@
$manifest = New-Fixture 'keyword member and bracket argument' @($memberBody)
$memberAst = Read-Ast $manifest
$null = Find-One $memberAst 'member' 'Then'
$null = Find-One $memberAst 'name' 'Rem'
Require (@($memberAst.Nodes.Values | Where-Object { $_.Kind -eq 'call' }).Count -eq 1) 'Keyword member call missing'
$script:passed++
Write-Output 'PASS: keyword member with explicit bracketed argument'

$operatorsBody = @'
Option Explicit On
Public Sub Operators()
    Dim Flag As Boolean
    Dim Value As Long
    Flag = 1 = 2
    Flag = 1 <> 2
    Flag = 1 < 2
    Flag = 1 > 2
    Flag = 1 <= 2
    Flag = 1 >= 2
    Value = -&H10& + +&O10&
    If True Then If False Then Value = 1 Else Value = 2
End Sub
'@
$manifest = New-Fixture 'scalar operators and nearest else' @($operatorsBody)
$operatorsAst = Read-Ast $manifest
$null = Find-One $operatorsAst 'option' 'Explicit'
foreach ($operator in @('=','<>','<','>','<=','>=')) { $null = Find-One $operatorsAst 'binary' $operator }
$minus = Find-One $operatorsAst 'unary' '-'
$positive = Find-One $operatorsAst 'unary' '+'
Require ((Shape $operatorsAst $minus) -eq 'unary:-(number:&h10&)' -and (Shape $operatorsAst $positive) -eq 'unary:+(number:&o10&)') 'Unary sign or hex/octal suffix structure mismatch'
$nearestIfs = @($operatorsAst.Nodes.Values | Where-Object { $_.Kind -eq 'if' } | Sort-Object Column)
Require ($nearestIfs.Count -eq 2) 'Nested inline If nodes missing'
$outerNearest = @(Children $operatorsAst $nearestIfs[0])
$innerNearest = @(Children $operatorsAst $nearestIfs[1])
Require ($outerNearest.Count -eq 2 -and $innerNearest.Count -eq 3 -and $innerNearest[2].Kind -eq 'else') 'Else does not bind to nearest inline If'
$outerThenChildren = @(Children $operatorsAst $outerNearest[1])
Require ($outerThenChildren.Count -eq 1 -and $outerThenChildren[0].Id -eq $nearestIfs[1].Id) 'Inner If not owned by outer then branch'
$script:passed++
Write-Output 'PASS: explicit declarations, all comparisons, signed numeric forms and nearest Else'

$escapedBody = @'
Public Sub [a|b]()
    Dim [a]]b] As Long
    Dim [a\b] As Long
    [a]]b] = 1
    [a\b] = 2
End Sub
'@
$manifest = New-Fixture 'escaped AST fields' @($escapedBody)
$escapedAst = Read-Ast $manifest
$null = Find-One $escapedAst 'sub' 'a|b'
$null = Find-One $escapedAst 'variable' 'a]b'
$null = Find-One $escapedAst 'variable' 'a\b'
$script:passed++
Write-Output 'PASS: escaped AST field delimiters and bracket-identifier decoding'

$threadBody = "Sub Worker(ByVal Value As Long)`nEnd Sub`nSub Run()`nDim Id As LongLong`nId = CallNew Worker(42)`nCallNew Other.Worker`nEnd Sub"
$threadManifest = New-Fixture 'thread start syntax' @($threadBody)
$threadAst = Read-Ast $threadManifest
$threadExpression = Find-One $threadAst 'thread-start' 'expression'
$threadStatement = Find-One $threadAst 'thread-start' 'statement'
$threadChildren = @(Children $threadAst $threadExpression)
Require ($threadChildren.Count -eq 2 -and $threadChildren[0].Kind -eq 'name' -and $threadChildren[0].Text -eq 'Worker' -and $threadChildren[1].Kind -eq 'number' -and $threadChildren[1].Text -eq '42') 'CallNew expression lost static callee/capture order'
$threadChildren = @(Children $threadAst $threadStatement)
Require ($threadChildren.Count -eq 1 -and $threadChildren[0].Kind -eq 'member' -and $threadChildren[0].Text -eq 'Worker') 'CallNew statement lost qualified static callee'
$script:passed++
Write-Output 'PASS: thread start expression and ignored-result statement retain distinct AST nodes'

$invalidCases = @(
    @{ Name='CallNew arguments require parentheses'; Body="Sub Run()`nCallNew Worker 1`nEnd Sub"; Code='E_UNSUPPORTED'; Location='Example.bas:4:' },
    @{ Name='CallNew requires spacing'; Body="Sub Run()`nCallNew[Worker]()`nEnd Sub"; Code='E_PARSE'; Location='Example.bas:4:' },
    @{ Name='CallNew rejects computed target'; Body="Sub Run()`nCallNew (Worker)()`nEnd Sub"; Code='E_UNSUPPORTED'; Location='Example.bas:4:' },
    @{ Name='CallNew rejects trailing capture comma'; Body="Sub Run()`nCallNew Worker(1,)`nEnd Sub"; Code='E_PARSE'; Location='Example.bas:4:' },
    @{ Name='unterminated string'; Body="Sub Main()`nErr.Raise `"unterminated`nEnd Sub"; Code='E_LEXICAL'; Location='Example.bas:4:' },
    @{ Name='truncated hex'; Body="Sub Main()`nErr.Raise &H`nEnd Sub"; Code='E_LEXICAL'; Location='Example.bas:4:' },
    @{ Name='invalid character'; Body="Sub Main()`nErr.Raise ?`nEnd Sub"; Code='E_LEXICAL'; Location='Example.bas:4:' },
    @{ Name='unfinished continuation'; Body="Sub Main()`nErr.Raise 1 + _"; Code='E_LEXICAL'; Location='Example.bas:4:' },
    @{ Name='mismatched procedure end'; Body="Sub Main()`nEnd Function"; Code='E_PARSE'; Location='Example.bas:4:' },
    @{ Name='missing procedure end'; Body="Sub Main()`nErr.Clear"; Code='E_PARSE'; Location='Example.bas:' },
    @{ Name='missing endif'; Body="Sub Main()`nIf True Then`nErr.Clear`nEnd Sub"; Code='E_PARSE'; Location='Example.bas:6:' },
    @{ Name='unexpected else'; Body="Sub Main()`nElse`nEnd Sub"; Code='E_PARSE'; Location='Example.bas:4:' },
    @{ Name='missing operand'; Body="Sub Main()`nDim X As Long`nX = 1 +`nEnd Sub"; Code='E_PARSE'; Location='Example.bas:5:' },
    @{ Name='continued physical error line'; Body="Sub Main()`nDim X As Long`nX = 1 + _`n    ?`nEnd Sub"; Code='E_LEXICAL'; Location='Example.bas:6:' },
    @{ Name='unsupported loop'; Body="Sub Main()`nWhile True`nWend`nEnd Sub"; Code='E_UNSUPPORTED'; Location='Example.bas:4:' },
    @{ Name='unsupported string storage'; Body="Sub Main()`nDim X As String`nEnd Sub"; Code='E_UNSUPPORTED'; Location='Example.bas:4:' },
    @{ Name='unsupported asm'; Body="Sub Main()`nAsm`nEnd Asm`nEnd Sub"; Code='E_UNSUPPORTED'; Location='Example.bas:4:' },
    @{ Name='reserved procedure name'; Body="Sub Empty()`nEnd Sub"; Code='E_UNSUPPORTED'; Location='Example.bas:3:' },
    @{ Name='member keyword must not start Rem comment'; Body="Sub Main()`nThing.Then Rem text`nEnd Sub"; Code='E_UNSUPPORTED'; Location='Example.bas:4:' },
    @{ Name='Option Explicit Off'; Body="Option Explicit Off`nSub Main()`nEnd Sub"; Code='E_UNSUPPORTED'; Location='Example.bas:3:' },
    @{ Name='Dim requires spacing'; Body="Sub Main()`nDim[x] As Long`nEnd Sub"; Code='E_PARSE'; Location='Example.bas:4:' },
    @{ Name='ByVal requires spacing'; Body="Sub Main(ByVal[x] As Long)`nEnd Sub"; Code='E_PARSE'; Location='Example.bas:3:' },
    @{ Name='GoTo requires spacing'; Body="Sub Main()`nGoTo[label]`nlabel:`nEnd Sub"; Code='E_PARSE'; Location='Example.bas:4:' }
)
foreach ($case in $invalidCases) {
    $manifest = New-Fixture $case.Name @($case.Body)
    Assert-Rejected $case.Name $manifest $case.Code $case.Location
}
$manifest = New-Fixture 'second module syntax error' @("Sub First()`nEnd Sub", "Sub Second()`nElse`nEnd Sub") @('First','Second')
Assert-Rejected 'second module location and no published success' $manifest 'E_PARSE' 'Second.bas:4:'
$dumpFailure = Invoke-BoundedProcess $BootstrapExe @('--dump-ast', $manifest)
Require ($dumpFailure.ExitCode -eq 1 -and $dumpFailure.Stdout -notmatch '(?m)^(NODE |PARSE OK)') 'Failed module published partial AST/success'

$manifest = New-Fixture 'near expression nesting bound' @("Function Deep() As Long`nDeep = " + ('(' * 60) + '1' + (')' * 60) + "`nEnd Function")
$deepAst = Read-Ast $manifest
Require (@($deepAst.Nodes.Values | Where-Object { $_.Kind -eq 'group' }).Count -eq 60) 'Near-bound nested groups not retained'
$script:passed++
Write-Output 'PASS: sixty nested expression groups accepted'
$manifest = New-Fixture 'expression nesting bound' @("Function Deep() As Long`nDeep = " + ('(' * 70) + '1' + (')' * 70) + "`nEnd Function")
Assert-Rejected 'expression nesting bounded' $manifest 'E_LIMIT' 'Example.bas:'
$manifest = New-Fixture 'token count bound' @("Sub Main()`n" + ("Err.Clear`n" * 22000) + 'End Sub')
Assert-Rejected 'token count bounded' $manifest 'E_LIMIT' 'Example.bas:'
$manifest = New-Fixture 'token length bound' @("Sub Main()`nErr.Raise `"" + ('x' * 4097) + "`"`nEnd Sub")
Assert-Rejected 'token length bounded' $manifest 'E_LIMIT' 'Example.bas:'
$largeBody = "Sub Main()`nDim X As Long`n" + ("X = 1 + 2`n" * 6000) + 'End Sub'
$manifest = New-Fixture 'project node count bound' @($largeBody,$largeBody,$largeBody) @('NodesA','NodesB','NodesC')
$expanded = Invoke-BoundedProcess $BootstrapExe @('--dump-ast', $manifest)
Require ($expanded.ExitCode -eq 0 -and ([regex]::Matches($expanded.Stdout, '(?m)^NODE ')).Count -eq 90013) 'Project above former65536 node ceiling was not retained'
$script:passed++
Write-Output 'PASS: 90013 project nodes accepted across three modules'
# Each assignment has five nodes; each module/sub/block/variable envelope has four.
# Four6000-assignment modules plus2210 assignments and one extra variable reach131072 including the project root.
$lastBody = "Sub Main()`nDim X As Long`nDim Y As Long`n" + ("X = 1 + 2`n" * 2210) + 'End Sub'
$manifest = New-Fixture 'exact project node bound' @($largeBody,$largeBody,$largeBody,$largeBody,$lastBody) @('NodesA','NodesB','NodesC','NodesD','NodesE')
$exact = Invoke-BoundedProcess $BootstrapExe @('--dump-ast', $manifest)
Require ($exact.ExitCode -eq 0 -and ([regex]::Matches($exact.Stdout, '(?m)^NODE ')).Count -eq 131072) 'Exact131072 project node capacity failed'
$script:passed++
Write-Output 'PASS: exactly131072 project nodes retained'
$lastBody = $lastBody.Replace('Dim Y As Long', "Dim Y As Long`nDim Z As Long")
$manifest = New-Fixture 'excess project node bound' @($largeBody,$largeBody,$largeBody,$largeBody,$lastBody) @('NodesA','NodesB','NodesC','NodesD','NodesE')
Assert-Rejected 'project AST node131073 refused' $manifest 'E_LIMIT' 'NodesE.bas:'

$blankBody = ("`n" * 50000) + "Sub EmptyBody()`nEnd Sub"
$manifest = New-Fixture 'near aggregate token bound' @($blankBody,$blankBody,$blankBody,$blankBody,$blankBody) @('TokensA','TokensB','TokensC','TokensD','TokensE')
$tokenAst = Read-Ast $manifest
Require (@($tokenAst.Nodes.Values | Where-Object { $_.Kind -eq 'sub' }).Count -eq 5) 'Near aggregate token bound lost procedures'
$script:passed++
Write-Output 'PASS: aggregate approximately 250000 tokens accepted'
$manifest = New-Fixture 'aggregate token bound' @($blankBody,$blankBody,$blankBody,$blankBody,$blankBody,$blankBody) @('TokensA','TokensB','TokensC','TokensD','TokensE','TokensF')
Assert-Rejected 'aggregate tokens bounded across modules' $manifest 'E_LIMIT' 'TokensF.bas:'

$manifest = New-Fixture 'valid after rejection' @("Sub Main()`nEnd Sub")
$recovered = Read-Ast $manifest
$null = Find-One $recovered 'sub' 'Main'
$script:passed++
Write-Output 'PASS: independent valid invocation after invalid inputs'
Write-Output "PASS: $($script:passed) source-parsing cases; AST assertions only, no execution claims."
