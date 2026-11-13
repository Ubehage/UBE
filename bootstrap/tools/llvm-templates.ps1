# Rebuilds or verifies the exact compiler-owned ASCII fragment catalog and UBE span constants.
param([switch]$Write)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$jsonPath = Join-Path $root 'compiler/llvm/templates.json'
$poolPath = Join-Path $root 'compiler/llvm/templates.bin'
$sourcePath = Join-Path $root 'compiler/src/LLVMTemplates.bas'
$utf8 = New-Object Text.UTF8Encoding($false,$true)
$json = [IO.File]::ReadAllText($jsonPath,$utf8)
if (-not $json.TrimStart().StartsWith('[')) { throw 'Template catalog must be an ordered JSON array.' }
$items = ConvertFrom-Json -InputObject $json
if ($items.Count -eq 0 -or $items.Count -gt 4096) { throw 'Template count must be 1..4096.' }
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$bytes = New-Object 'System.Collections.Generic.List[byte]'
$declarations = New-Object 'System.Collections.Generic.List[string]'
$spans = New-Object 'System.Collections.Generic.List[string]'
$reserved = @('CatalogLength','CatalogByteSum','TemplateCount','TrySpan','Id','Start','Count')
$keywords = [IO.File]::ReadAllText((Join-Path $root 'compiler/src/SyntaxTokens.bas'),$utf8)
foreach ($match in [regex]::Matches($keywords,'(?m)^Public Const Kw([A-Za-z0-9]+) As Long')) { $reserved += $match.Groups[1].Value }
$id = 0
$sum = 0
foreach ($item in $items) {
    $properties = @($item.PSObject.Properties.Name)
    if ($properties.Count -ne 2 -or 'name' -notin $properties -or 'text' -notin $properties) { throw 'Template entries require exactly name and text.' }
    if ($item.name -isnot [string] -or $item.text -isnot [string]) { throw 'Template name/text must be strings.' }
    $name = $item.name
    if ($name -cnotmatch '^[A-Z][A-Za-z0-9]{0,127}$' -or $name -in $reserved) { throw "Invalid or reserved template name: $name" }
    if (-not $seen.Add($name)) { throw "Duplicate template name: $name" }
    $text = $item.text -replace '\r\n?', "`n"
    $text = $text.Replace("`n", "`r`n")
    if ($text.Length -eq 0 -or $text.Length -gt 1048576) { throw "Template text length outside1..1048576: $name" }
    for ($index = 0; $index -lt $text.Length; $index++) {
        $character = [int][char]$text[$index]
        if ($character -ne 9 -and $character -ne 10 -and $character -ne 13 -and ($character -lt 32 -or $character -gt 126)) { throw "Non-ASCII/control character: $name" }
        if ($character -eq 123 -and $index + 1 -lt $text.Length -and [char]::IsDigit($text[$index + 1])) {
            if ($index + 2 -ge $text.Length -or $text[$index + 1] -lt '0' -or $text[$index + 1] -gt '3' -or $text[$index + 2] -ne '}') { throw "Unknown numeric placeholder: $name" }
        }
    }
    $id++
    $start = $bytes.Count
    foreach ($value in [Text.Encoding]::ASCII.GetBytes($text)) { $bytes.Add($value); $sum += $value }
    if ($bytes.Count -gt 1048576) { throw 'Template catalog exceeds1MiB.' }
    $declarations.Add("Public Const $name As Long = $id")
    $spans.Add("    If Id = $id Then Start = $start" + ': Count = ' + $text.Length + ': TrySpan = True: Exit Function')
}
$lines = @('UBE SOURCE 1 MODULE','Attribute UBE_Name = "LLVMTemplates"',"' Generated from compiler/llvm/templates.json by bootstrap/tools/llvm-templates.ps1.")
$lines += $declarations.ToArray()
$lines += @("Public Const TemplateCount As Long = $id","Public Const CatalogLength As Long = $($bytes.Count)","Public Const CatalogByteSum As Long = $sum",'',"' Returns one exact span without changing caller outputs for an unknown identity.",'Public Function TrySpan(ByVal Id As Long, ByRef Start As Long, ByRef Count As Long) As Boolean')
$lines += $spans.ToArray()
$lines += 'End Function'
$sourceBytes = [Text.Encoding]::ASCII.GetBytes(($lines -join ([string][char]13+[char]10)) + [char]13 + [char]10)
$poolBytes = $bytes.ToArray()
if ($Write) {
    [IO.File]::WriteAllBytes($poolPath,$poolBytes)
    [IO.File]::WriteAllBytes($sourcePath,$sourceBytes)
} else {
    foreach ($pair in @(@($poolPath,$poolBytes),@($sourcePath,$sourceBytes))) {
        if (-not [IO.File]::Exists($pair[0])) { throw "Missing generated output: $($pair[0])" }
        $actual = [IO.File]::ReadAllBytes($pair[0])
        if ([Convert]::ToBase64String($actual) -cne [Convert]::ToBase64String($pair[1])) { throw "Generated output differs: $($pair[0]); run -Write after review." }
    }
}
Write-Output "PASS: $id templates; $($bytes.Count) ASCII bytes; sum$sum; exact generated parity."
