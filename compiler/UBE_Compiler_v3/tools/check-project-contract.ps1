# Definition consistency only. This does not execute or qualify a project loader.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$utf8=[Text.UTF8Encoding]::new($false,$true)
$common="UBE-Project 1`nName = ""App""`nKind = ""Exe""`nStartup = ""Main""`nSource = ""src/Main.bas""`n"
$bytes=$utf8.GetBytes($common)
$checks=0
function Assert-Definition([bool]$Condition,[string]$Message){
 if(-not $Condition){throw $Message};++$script:checks
}
Assert-Definition ($common.Length -eq 81 -and $bytes.Length -eq 81) 'Common manifest exact length'
Assert-Definition ($common.Substring(67,12) -ceq 'src/Main.bas') 'Hand-authored source byte span 67..79'
Assert-Definition ($common[66] -ceq '"' -and $common[79] -ceq '"') 'Value span excludes quotes'
$before=$common.Substring(0,67);$lines=$before -split "`n"
Assert-Definition ($lines.Count -eq 5 -and $lines[4].Length -eq 10) 'Source value line 5 column 11'
Assert-Definition ($before.LastIndexOf("`n") -eq 56) 'Original source declaration line boundary'
$bom=[byte[]]@(239,187,191)+$bytes
Assert-Definition ($utf8.GetString($bom,70,12) -ceq 'src/Main.bas') 'BOM moves bytes by three'
Assert-Definition ([int]$utf8.GetString($bom)[0] -eq 65279) 'BOM has one scalar transport marker'
$crlf=$utf8.GetBytes($common.Replace("`n","`r`n"))
Assert-Definition ($utf8.GetString($crlf,71,12) -ceq 'src/Main.bas') 'Four preceding CR bytes move source span by four'
Assert-Definition ($crlf.Length -eq 86) 'Five CRLF line endings'
Assert-Definition ('UBE-Project 2'[12] -ceq '2') 'Future version column 13'
$decodeFailed=$false
try{$null=$utf8.GetString([byte[]]@(255))}catch [Text.DecoderFallbackException]{$decodeFailed=$true}
Assert-Definition $decodeFailed 'Malformed UTF-8 negative definition control'
Assert-Definition ($utf8.GetBytes('Source = "src/A""B.bas"').Length -eq 23) 'Doubled-quote fixture exact transport length'
$path=Join-Path $root 'compiler/UBE_Compiler_v3/PROJECT-INPUT-CASES.md'
$text=[IO.File]::ReadAllText($path,$utf8)
Assert-Definition ($text.Contains('columns 11..23') -and $text.Contains('bytes 67..79')) 'Document agrees with hand-authored span'
$rows=@([regex]::Matches($text,'(?m)^\| ([^|]+) \|') | ForEach-Object {$_.Groups[1].Value.Trim()} | Where-Object {$_ -notin @('Case','---','Root or library declaration')})
Assert-Definition ($rows.Count -ge 65) 'Independent manifest/path case coverage retained'
Assert-Definition (@($rows | Sort-Object -Unique).Count -eq $rows.Count) 'Unique named definition cases'
$run=Join-Path $root ('bootstrap/out/project-contract/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run -Force
$report=Join-Path $run 'report.json'
[pscustomobject]@{schema='ube-project-definition-1';success=$true;checks=$checks;namedCases=$rows.Count;nativeProjectConsumerQualified=$false;inputs=@((Get-ArtifactIdentity $path),(Get-ArtifactIdentity $PSCommandPath));scope='Hand-authored fixture transport/span and case-ledger consistency only.'} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $report -Encoding UTF8
Write-Output ($checks.ToString()+' definition consistency assertions passed; project consumer remains unimplemented.')
Write-Output ('Evidence: '+$report)
