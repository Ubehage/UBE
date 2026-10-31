param([string]$OutputPath = (Join-Path $PSScriptRoot '../src/portable/Unicode.bas'))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$data=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../data/unicode/18.0.0'))
$provenance=Get-Content -LiteralPath (Join-Path $data 'provenance.json') -Raw | ConvertFrom-Json
if ($provenance.version -cne '18.0.0') { throw 'Wrong Unicode version' }
foreach($file in $provenance.files) {
    $path=Join-Path $data $file.name
    if ((Get-Item -LiteralPath $path).Length -ne $file.bytes -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $file.sha256) { throw "Unicode data identity differs: $($file.name)" }
}
$fold=[Collections.Generic.List[object]]::new()
foreach($line in [IO.File]::ReadAllLines((Join-Path $data 'CaseFolding.txt'))) {
    if($line -match '^([0-9A-F]+);\s+([CS]);\s+([0-9A-F]+);') {
        $fold.Add([pscustomobject]@{Low=[Convert]::ToInt32($Matches[1],16);High=[Convert]::ToInt32($Matches[1],16);Stride=0;Delta=([Convert]::ToInt32($Matches[3],16)-[Convert]::ToInt32($Matches[1],16))})
    }
}
$foldRanges=[Collections.Generic.List[object]]::new()
foreach($item in $fold | Sort-Object Low) {
    $previous=if($foldRanges.Count -gt 0){$foldRanges[$foldRanges.Count-1]}else{$null}
    $distance=if($null -ne $previous){$item.Low-$previous.High}else{0}
    if($null -ne $previous -and $item.Delta -eq $previous.Delta -and (($previous.Stride -eq 0 -and ($distance -eq 1 -or $distance -eq 2)) -or ($previous.Stride -gt 0 -and $distance -eq $previous.Stride))) {
        $previous.Stride=$distance;$previous.High=$item.High
    } else { $foldRanges.Add($item) }
}
$letters=[Collections.Generic.List[object]]::new()
foreach($line in [IO.File]::ReadAllLines((Join-Path $data 'DerivedGeneralCategory.txt'))) {
    if($line -match '^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s+;\s+L[ultmo]\b') {
        $low=[Convert]::ToInt32($Matches[1],16)
        $high=if($Matches[2]){[Convert]::ToInt32($Matches[2],16)}else{$low}
        $letters.Add([pscustomobject]@{Low=$low;High=$high})
    }
}
$letterRanges=[Collections.Generic.List[object]]::new()
foreach($item in $letters | Sort-Object Low) {
    if($letterRanges.Count -gt 0 -and $item.Low -le $letterRanges[$letterRanges.Count-1].High+1) { $letterRanges[$letterRanges.Count-1].High=[Math]::Max($item.High,$letterRanges[$letterRanges.Count-1].High) }
    else { $letterRanges.Add($item) }
}
$lines=[Collections.Generic.List[string]]::new()
$lines.Add('UBE SOURCE 1 MODULE')
$lines.Add('Attribute UBE_Name = "Unicode"')
$lines.Add('')
$lines.Add("' Generated offline by std-lib/tools/generate-unicode.ps1; do not edit tables.")
$lines.Add("' Unicode 18.0.0 data and Unicode License V3: ../../data/unicode/18.0.0/.")
$lines.Add("' Stateless, allocation/copy-free, reentrant; preserve Err and retain nothing.")
$lines.Add("' Balanced decisions: logarithmic comparisons; no mutable initialization.")
function Add-Tree($Items,[int]$First,[int]$Last,[int]$Depth,[string]$FunctionName) {
    if($First -gt $Last){return}
    $indent='    '*$Depth
    if($Last-$First -lt 4) {
        for($at=$First;$at -le $Last;++$at) {
            $item=$Items[$at]
            $condition=if($item.Low -eq $item.High){"Scalar = $($item.Low)"}else{"Scalar >= $($item.Low) And Scalar <= $($item.High)"}
            if($FunctionName -eq 'SimpleFoldUnicode' -and $item.Stride -eq 2){$condition+=" And Scalar Mod 2 = $($item.Low % 2)"}
            $lines.Add($indent+"If $condition Then")
            $result=if($FunctionName -eq 'IsUnicodeLetter'){'True'}elseif($item.Delta -gt 0){"Scalar + $($item.Delta)"}else{"Scalar - $(-$item.Delta)"}
            $lines.Add($indent+"    $FunctionName = $result")
            $lines.Add($indent+'    Exit Function')
            $lines.Add($indent+'End If')
        }
    } else {
        $middle=[int][Math]::Floor(($First+$Last+1)/2)
        $lines.Add($indent+"If Scalar < $($Items[$middle].Low) Then")
        Add-Tree $Items $First ($middle-1) ($Depth+1) $FunctionName
        $lines.Add($indent+'Else')
        Add-Tree $Items $middle $Last ($Depth+1) $FunctionName
        $lines.Add($indent+'End If')
    }
}
$lines.Add('')
$lines.Add("' True exactly for Unicode Lu/Ll/Lt/Lm/Lo. Invalid scalar values return False.")
$lines.Add('Function IsUnicodeLetter(ByVal Scalar As Long) As Boolean')
$lines.Add('    IsUnicodeLetter = False')
$lines.Add('    If Scalar < 0 Or Scalar > 1114111 Then')
$lines.Add('        Exit Function')
$lines.Add('    End If')
Add-Tree $letterRanges 0 ($letterRanges.Count-1) 1 'IsUnicodeLetter'
$lines.Add('End Function')
$lines.Add('')
$lines.Add("' Default simple folding: CaseFolding C+S, excluding F and Turkic T.")
$lines.Add("' Unlisted values, including invalid scalars, return the original Long.")
$lines.Add('Function SimpleFoldUnicode(ByVal Scalar As Long) As Long')
$lines.Add('    SimpleFoldUnicode = Scalar')
$lines.Add('    If Scalar < 0 Or Scalar > 1114111 Then')
$lines.Add('        Exit Function')
$lines.Add('    End If')
Add-Tree $foldRanges 0 ($foldRanges.Count-1) 1 'SimpleFoldUnicode'
$lines.Add('End Function')
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath),($lines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
Write-Output "Generated Unicode18: $($letterRanges.Count) letter ranges, $($fold.Count) fold mappings in $($foldRanges.Count) constant-delta stride ranges."
