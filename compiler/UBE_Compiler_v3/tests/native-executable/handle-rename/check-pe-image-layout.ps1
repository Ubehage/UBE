param([Parameter(Mandatory=$true)][string] $Probe,
      [Parameter(Mandatory=$true)][string] $UncheckedProbe,
      [Parameter(Mandatory=$true)][string] $Executable,
      [Parameter(Mandatory=$true)][string] $OutputDirectory,
      [string] $ControlExecutable)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$checked = (Resolve-Path -LiteralPath $Probe).Path
$unchecked = (Resolve-Path -LiteralPath $UncheckedProbe).Path
$original = (Resolve-Path -LiteralPath $Executable).Path
$bytes = [IO.File]::ReadAllBytes($original)
if ($bytes.Length -lt 1024 -or $bytes.Length -gt 67108864) { throw 'Fixture size outside test bounds' }
$pe = [int][BitConverter]::ToUInt32($bytes,60)
$opt = $pe + 24
$table = $opt + [BitConverter]::ToUInt16($bytes,$pe+20)
$count = [BitConverter]::ToUInt16($bytes,$pe+6)
$headers = [BitConverter]::ToUInt32($bytes,$opt+60)
$image = [BitConverter]::ToUInt32($bytes,$opt+56)
if ($count -lt 2 -or $table + 40*$count -gt $headers -or $headers -le 512 -or $headers -ge $image -or $image -gt 67108864 -or [BitConverter]::ToUInt32($bytes,$opt+108) -ne 16) { throw 'Fixture cannot support layout mutations' }
$sections = @()
for ($i=0;$i -lt $count;$i++) {
    $p = $table + 40*$i
    $sections += [pscustomobject]@{ header=$p; va=[uint64][BitConverter]::ToUInt32($bytes,$p+12); virtualSize=[uint64][BitConverter]::ToUInt32($bytes,$p+8); rawSize=[uint64][BitConverter]::ToUInt32($bytes,$p+16); raw=[uint64][BitConverter]::ToUInt32($bytes,$p+20); flags=[BitConverter]::ToUInt32($bytes,$p+36) }
}
$entry = [uint64][BitConverter]::ToUInt32($bytes,$opt+16)
$code = @($sections | Where-Object { ($_.flags -band 0x20000000) -ne 0 -and $entry -ge $_.va -and $entry -lt $_.va+$_.virtualSize })
$zeroFill = @($sections | Where-Object { $_.virtualSize -gt $_.rawSize -and $_.rawSize -gt 0 })
if ($code.Count -ne 1 -or $code[0].virtualSize -ge $code[0].rawSize -or $zeroFill.Count -lt 1 -or $sections[0].va -lt $headers+20) { throw 'Fixture lacks entry padding, zero fill or header gap' }
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
function Set-U32([byte[]] $data,[int] $offset,[uint32] $value) {
    [BitConverter]::GetBytes($value).CopyTo($data,$offset)
    if ([BitConverter]::ToUInt32($data,$offset) -ne $value) { throw 'Mutation write mismatch' }
}
function Set-U16([byte[]] $data,[int] $offset,[uint16] $value) {
    [BitConverter]::GetBytes($value).CopyTo($data,$offset)
    if ([BitConverter]::ToUInt16($data,$offset) -ne $value) { throw 'Mutation write mismatch' }
}
function Check([string] $tool,[string] $path,[bool] $accept) {
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName=$tool
    $process.StartInfo.Arguments='"'+$path+'"'
    $process.StartInfo.UseShellExecute=$false
    $process.StartInfo.CreateNoWindow=$true
    $process.StartInfo.RedirectStandardOutput=$true
    try {
        if (-not $process.Start()) { throw 'Layout probe did not start' }
        $read=$process.StandardOutput.ReadToEndAsync()
        if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Layout probe timed out' }
        $wanted=if ($accept) { 0 } else { 1 }
        $message=if ($accept) { 'structure accepted' } else { 'structure rejected' }
        if ($process.ExitCode -ne $wanted -or $read.Result.Trim() -cne $message) { throw "Unexpected layout result for $path, accept=$accept" }
    } finally { $process.Dispose() }
}
Check $checked $original $true
Check $unchecked $original $true
if ($ControlExecutable) { Check $checked (Resolve-Path -LiteralPath $ControlExecutable).Path $true }
# Independent minimal, non-executed images exercise declared count boundaries.
$boundaries=@()
foreach ($shape in @(@{name='sections-96';sections=96;directories=16;accept=$true},
                     @{name='sections-97';sections=97;directories=16;accept=$false},
                     @{name='directories-17';sections=1;directories=17;accept=$false})) {
    $optionalBytes=112+8*$shape.directories
    $sectionTable=64+24+$optionalBytes
    $headerBytes=[int]([Math]::Ceiling(($sectionTable+40*$shape.sections)/512.0)*512)
    $firstRva=[uint32]([Math]::Ceiling($headerBytes/4096.0)*4096)
    $minimal=[byte[]]::new($headerBytes+512)
    Set-U16 $minimal 0 0x5A4D; Set-U32 $minimal 60 64
    Set-U32 $minimal 64 0x4550; Set-U16 $minimal 68 0x8664
    Set-U16 $minimal 70 $shape.sections; Set-U16 $minimal 84 $optionalBytes; Set-U16 $minimal 86 2
    Set-U16 $minimal 88 0x20B; Set-U32 $minimal (88+4) 512; Set-U32 $minimal (88+16) $firstRva
    Set-U32 $minimal (88+32) 4096; Set-U32 $minimal (88+36) 512
    Set-U32 $minimal (88+56) ($firstRva+4096); Set-U32 $minimal (88+60) $headerBytes
    Set-U16 $minimal (88+68) 3; Set-U32 $minimal (88+108) $shape.directories
    Set-U32 $minimal ($sectionTable+8) 1; Set-U32 $minimal ($sectionTable+12) $firstRva
    Set-U32 $minimal ($sectionTable+16) 512; Set-U32 $minimal ($sectionTable+20) $headerBytes
    Set-U32 $minimal ($sectionTable+36) 0x60000020; $minimal[$headerBytes]=0xC3
    $path=Join-Path $root ($shape.name+'.exe'); [IO.File]::WriteAllBytes($path,$minimal)
    Check $unchecked $path $true; Check $checked $path $shape.accept
    $boundaries += [pscustomobject]@{name=$shape.name;accepted=$shape.accept;omittedLayoutAccepted=$true;sha256=(Get-FileHash -LiteralPath $path).Hash}
    Write-Output "$($shape.name) : accepted=$($shape.accept); complete synthetic tables; no execution."
}
$names=@('overlay','certificate-file-offset','global-pointer-zero-size','subsystem','file-alignment-small','section-alignment-small','section-alignment-not-power-two','headers-too-small','headers-unaligned','headers-outside-file','image-unaligned','section-unaligned','section-overlap','raw-overlap','raw-in-headers','import-in-gap','import-in-headers','import-in-zero-fill','directory-address-zero','directory-size-zero','reserved-directory','clr-directory','global-pointer-nonzero-size','entry-in-padding','certificate-unaligned')
$results=@()
foreach ($name in $names) {
    $data=[byte[]]$bytes.Clone()
    $import=$opt+112+8
    $certificate=$opt+112+4*8
    $globalPointer=$opt+112+8*8
    $accept=$name -in @('overlay','certificate-file-offset','global-pointer-zero-size')
    switch ($name) {
        'overlay' { $data=[byte[]]::new($bytes.Length+16); [Array]::Copy($bytes,$data,$bytes.Length); $data[$data.Length-1]=0xAA }
        'certificate-file-offset' {
            $offset=[uint32]([Math]::Ceiling([Math]::Max([double]$image,[double]$bytes.Length)/8)*8)
            $data=[byte[]]::new($offset+8); [Array]::Copy($bytes,$data,$bytes.Length)
            Set-U32 $data $certificate $offset; Set-U32 $data ($certificate+4) 8
        }
        'global-pointer-zero-size' { Set-U32 $data $globalPointer $sections[0].va; Set-U32 $data ($globalPointer+4) 0 }
        'subsystem' { Set-U16 $data ($opt+68) 2 }
        'file-alignment-small' { Set-U32 $data ($opt+36) 256 }
        'section-alignment-small' { Set-U32 $data ($opt+32) 2048 }
        'section-alignment-not-power-two' { Set-U32 $data ($opt+32) 3072 }
        'headers-too-small' { Set-U32 $data ($opt+60) 512 }
        'headers-unaligned' { Set-U32 $data ($opt+60) ($headers+1) }
        'headers-outside-file' { Set-U32 $data ($opt+60) ([uint32]::MaxValue) }
        'image-unaligned' { Set-U32 $data ($opt+56) ($image+1) }
        'section-unaligned' { Set-U32 $data ($sections[1].header+12) ($sections[1].va+1) }
        'section-overlap' { Set-U32 $data ($sections[1].header+12) $sections[0].va }
        'raw-overlap' { Set-U32 $data ($sections[1].header+20) $sections[0].raw }
        'raw-in-headers' { Set-U32 $data ($sections[0].header+20) 0 }
        'import-in-gap' { Set-U32 $data $import $headers; Set-U32 $data ($import+4) 20 }
        'import-in-headers' { Set-U32 $data $import 64; Set-U32 $data ($import+4) 20 }
        'import-in-zero-fill' { Set-U32 $data $import ($zeroFill[0].va+$zeroFill[0].rawSize); Set-U32 $data ($import+4) 1 }
        'directory-address-zero' { Set-U32 $data $import 0; Set-U32 $data ($import+4) 1 }
        'directory-size-zero' { Set-U32 $data ($import+4) 0 }
        'reserved-directory' { Set-U32 $data ($opt+112+7*8) $sections[0].va; Set-U32 $data ($opt+112+7*8+4) 1 }
        'clr-directory' { Set-U32 $data ($opt+112+14*8) $sections[0].va; Set-U32 $data ($opt+112+14*8+4) 1 }
        'global-pointer-nonzero-size' { Set-U32 $data $globalPointer $sections[0].va; Set-U32 $data ($globalPointer+4) 1 }
        'entry-in-padding' { Set-U32 $data ($opt+16) ($code[0].va+$code[0].virtualSize) }
        'certificate-unaligned' {
            $data=[byte[]]::new($bytes.Length+16); [Array]::Copy($bytes,$data,$bytes.Length)
            Set-U32 $data $certificate ($bytes.Length+1); Set-U32 $data ($certificate+4) 8
        }
    }
    $path=Join-Path $root ($name+'.exe')
    [IO.File]::WriteAllBytes($path,$data)
    if ((Get-FileHash -LiteralPath $path).Hash -eq (Get-FileHash -LiteralPath $original).Hash) { throw "Mutation did not change fixture: $name" }
    Check $unchecked $path $true
    Check $checked $path $accept
    $results += [pscustomobject]@{ name=$name; accepted=$accept; omittedLayoutAccepted=$true; sha256=(Get-FileHash -LiteralPath $path).Hash }
    Write-Output "$name : accepted=$accept; omitted-layout control accepted."
}
$identityPaths=@($checked,$unchecked,$original,$PSCommandPath,(Join-Path $PSScriptRoot 'pe-structure.c'))
if ($ControlExecutable) { $identityPaths += (Resolve-Path -LiteralPath $ControlExecutable).Path }
$identities=$identityPaths | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash} }
[pscustomobject]@{identities=$identities;boundaries=$boundaries;results=$results} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $root 'report.json') -Encoding UTF8
Write-Output "Layout evidence: $root"
