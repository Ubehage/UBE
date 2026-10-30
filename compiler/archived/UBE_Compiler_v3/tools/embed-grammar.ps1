$ErrorActionPreference = 'Stop'

$compilerRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $compilerRoot))
$grammarPath = Join-Path $repositoryRoot 'lang-doc/grammar/ube.ebnf'
$outputPath = Join-Path $compilerRoot 'GrammarDefinition.bas'

if (-not (Test-Path -LiteralPath $grammarPath)) {
    throw "UBE grammar was not found: $grammarPath"
}

$grammarBytes = [System.IO.File]::ReadAllBytes($grammarPath)
$grammarText = [System.Text.Encoding]::UTF8.GetString($grammarBytes)
$grammarText = $grammarText.Replace("`r`n", "`n").Replace("`r", "`n")
$canonicalBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($grammarText)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $grammarHash = [System.BitConverter]::ToString($sha256.ComputeHash($canonicalBytes)).Replace('-', '')
}
finally {
    $sha256.Dispose()
}
$lines = $grammarText.Split("`n")

$result = [System.Text.StringBuilder]::new()
[void]$result.AppendLine('UBE SOURCE 1 MODULE')
[void]$result.AppendLine('Attribute UBE_Name = "GrammarDefinition"')
[void]$result.AppendLine()
[void]$result.AppendLine("' Frozen lang-doc/grammar/ube.ebnf SHA-256: $grammarHash")
[void]$result.AppendLine("Function EmbeddedGrammarHash() As String")
[void]$result.AppendLine("    EmbeddedGrammarHash = `"$grammarHash`"")
[void]$result.AppendLine('End Function')
[void]$result.AppendLine()
[void]$result.AppendLine('Sub LoadEmbeddedGrammar(ByRef GrammarText As String)')
[void]$result.AppendLine('    GrammarText = ""')
foreach ($line in $lines) {
    $escaped = $line.Replace('"', '""')
    [void]$result.AppendLine("    GrammarText = GrammarText & `"$escaped`" & StringFromByte(10)")
}
[void]$result.AppendLine('End Sub')

[System.IO.File]::WriteAllText($outputPath, $result.ToString(), [System.Text.UTF8Encoding]::new($false))
