param([Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$reference = Join-Path $PSScriptRoot 'tool-output-reference.ps1'
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$allByteExpectation = [Text.StringBuilder]::new()
foreach ($byte in 0..255) {
    if ($byte -lt 0x20 -or $byte -eq 0x7F) { [void]$allByteExpectation.Append(('\u{' + ('{0:X}' -f $byte) + '}')) }
    elseif ($byte -eq 0x5C) { [void]$allByteExpectation.Append('\\') }
    elseif ($byte -lt 0x80) { [void]$allByteExpectation.Append([char]$byte) }
    else { [void]$allByteExpectation.Append(('\x{0:X2}' -f $byte)) }
}
$cases = @(
    @{ name='empty'; bytes=[byte[]]@(); expected=''; truncated=$false },
    @{ name='backslash'; bytes=[byte[]](0x41,0x5C,0x42); expected='A\\B'; truncated=$false },
    @{ name='newline'; bytes=[byte[]](0x41,0x0A,0x42); expected='A\u{A}B'; truncated=$false },
    @{ name='invalid'; bytes=[byte[]](0xFF,0xE2,0x82); expected='\xFF\xE2\x82'; truncated=$false },
    @{ name='overlong'; bytes=[byte[]](0xC0,0xAF,0xED,0xA0,0x80,0xF4,0x90,0x80,0x80); expected='\xC0\xAF\xED\xA0\x80\xF4\x90\x80\x80'; truncated=$false },
    @{ name='invalid-then-ascii'; bytes=[byte[]](0xE2,0x28,0xA1); expected='\xE2(\xA1'; truncated=$false },
    @{ name='c1-control'; bytes=[byte[]](0x41,0xC2,0x85,0x42); expected='A\u{85}B'; truncated=$false },
    @{ name='bidi'; bytes=[byte[]](0x41,0xE2,0x80,0xAE,0x42); expected='A\u{202E}B'; truncated=$false },
    @{ name='supplementary-format'; bytes=[byte[]](0xF3,0xA0,0x80,0x81); expected='\u{E0001}'; truncated=$false },
    @{ name='separators'; bytes=[byte[]](0x41,0xE2,0x80,0xA8,0xE2,0x80,0xA9,0x42); expected='A\u{2028}\u{2029}B'; truncated=$false },
    @{ name='unicode'; bytes=[byte[]](0xC3,0xA6,0xF0,0x90,0x90,0x80); expected=([string][char]0xE6 + [char]::ConvertFromUtf32(0x10400)); truncated=$false },
    @{ name='exact'; bytes=[byte[]](@(0x1F) * 4096); expected=('\u{1F}' * 4096); truncated=$false },
    @{ name='excess'; bytes=[byte[]](@(0x1F) * 4097); expected=('\u{1F}' * 4096); truncated=$true },
    @{ name='split'; bytes=[byte[]](@(0x41) * 4095 + @(0xE2,0x82,0xAC)); expected=(('A' * 4095) + '\xE2'); truncated=$true }
    @{ name='split-four-two'; bytes=[byte[]](@(0x41) * 4094 + @(0xF0,0x90,0x80,0x80)); expected=(('A' * 4094) + '\xF0\x90'); truncated=$true }
    @{ name='split-four-three'; bytes=[byte[]](@(0x41) * 4093 + @(0xF0,0x90,0x80,0x80)); expected=(('A' * 4093) + '\xF0\x90\x80'); truncated=$true }
    @{ name='all-bytes'; bytes=[byte[]](0..255); expected=$allByteExpectation.ToString(); truncated=$false }
)
function Matches-Expected($actual, [string] $expected, [bool] $truncated) {
    return $actual.text -ceq $expected -and $actual.truncated -eq $truncated
}
foreach ($case in $cases) {
    $path = Join-Path $directory ($case.name + '.bin')
    [IO.File]::WriteAllBytes($path, $case.bytes)
    $actual = (& $reference -InputFile $path) | ConvertFrom-Json
    if (-not (Matches-Expected $actual $case.expected $case.truncated)) { throw "Mismatch: $($case.name)" }
    if ((Matches-Expected $actual ($case.expected + '!') $case.truncated) -or
        (Matches-Expected $actual $case.expected (-not $case.truncated))) { throw "Negative control accepted: $($case.name)" }
}
Write-Output "Passed $($cases.Count) tool-output reference examples and altered-value controls."
