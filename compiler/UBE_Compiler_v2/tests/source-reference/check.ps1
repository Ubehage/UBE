param([Parameter(Mandatory=$true)][string]$SelectionPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run = Join-Path $root ('bootstrap/out/source-reference/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$commands = @()
$checks = @()
$fixtureSnapshots = @()
$inputs = @()
$selection = $null
$success = $false
$failure = $null
$encoding = New-Object Text.UTF8Encoding($false)
function Write-Fixture([string]$Relative,[string]$Text) {
    $path = Join-Path $run $Relative
    New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($path,$Text,$encoding)
    return $path
}
function Native-Module([string]$Name,[string]$Body) {
    return "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"$Name`"`n$Body`n"
}
function Exe-Project([string]$Name,[string]$Sources,[string]$Extra = '') {
    return "UBE-Project 1`nName = `"$Name`"`nKind = `"Exe`"`nStartup = `"Main`"`n$Sources`n$Extra"
}
function Test-Project([string]$Name,[string]$Project,[string]$ExpectedOutput = '',[string]$Diagnostic = '',[int]$ExpectedExit = 1) {
    $path = Write-Fixture ($Name + '.UBE') $Project
    $snapshot = Join-Path $run ('inputs/' + $Name)
    foreach ($fixture in @(Get-ChildItem -LiteralPath $run -Recurse -File | Where-Object { $_.Extension -in @('.bas','.UBE') -and $_.FullName -notlike ((Join-Path $run 'inputs') + '*') })) {
        $relative = $fixture.FullName.Substring($run.Length + 1)
        $destination = Join-Path $snapshot $relative
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        [IO.File]::Copy($fixture.FullName,$destination)
    }
    $script:fixtureSnapshots += [pscustomobject]@{case=$Name;files=@(Get-ChildItem -LiteralPath $snapshot -Recurse -File | ForEach-Object {Get-ArtifactIdentity $_.FullName})}
    $irHashes = @()
    $diagnostics = @()
    for ($index = 0; $index -lt 2; $index++) {
        $stem = Join-Path $run ($Name + '-stage' + ($index + 1))
        $ir = $stem + '.ll'
        $emission = Invoke-BoundedProcess $stages[$index] @($path,$ir) $root 30
        $script:commands += $emission
        if ($emission.timedOut) { throw "Compiler timed out: $Name" }
        if ($Diagnostic -ne '') {
            if ($emission.exit -ne $ExpectedExit -or ($emission.stdout+$emission.stderr).IndexOf($Diagnostic,[StringComparison]::Ordinal) -lt 0 -or (Test-Path $ir)) {
                throw "Rejection failed: ${Name}: $($emission | ConvertTo-Json -Compress)"
            }
            $diagnostics += $emission.stdout + $emission.stderr
            $script:checks += [pscustomobject]@{assertion="$Name stage $($index+1): expected diagnostic/status and no LLVM";passed=$true}
        } else {
            if ($emission.exit -ne 0 -or $emission.stdout -cne '' -or $emission.stderr -cne '' -or -not (Test-Path $ir)) { throw "Emission failed: ${Name}: $($emission.stdout)$($emission.stderr)" }
            $link = Invoke-BoundedProcess $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',$ir,$selection.runtime.path,$selection.unicodeRuntime.path,'-o',($stem+'.exe')) $root 30
            $script:commands += $link
            if ($link.timedOut -or $link.exit -ne 0) { throw "Link failed: ${Name}: $($link.stderr)" }
            $native = Invoke-BoundedProcess ($stem+'.exe') @() $root 30
            $script:commands += $native
            if ($native.timedOut -or $native.exit -ne 0 -or $native.stdout -cne $ExpectedOutput -or $native.stderr -cne '') { throw "Native oracle failed: ${Name}: $($native | ConvertTo-Json -Compress)" }
            $script:checks += [pscustomobject]@{assertion="$Name stage $($index+1): exact native stdout/exit/stderr";passed=$true}
            $irHashes += (Get-ArtifactIdentity $ir).sha256
        }
    }
    if ($Diagnostic -eq '') {
        if ($irHashes[0] -cne $irHashes[1]) { throw "LLVM differs: $Name" }
        $script:checks += [pscustomobject]@{assertion="${Name}: byte-identical LLVM through both source-built stages";passed=$true}
    } elseif ($diagnostics[0] -cne $diagnostics[1]) { throw "Diagnostics differ: $Name" }
}
try {
    $selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
    $inputs += Get-ArtifactIdentity $SelectionPath
    foreach ($property in $selection.PSObject.Properties) {
        if ($property.Name -ne 'schema' -and (Get-ArtifactIdentity $property.Value.path).sha256 -cne $property.Value.sha256) { throw "Selection changed: $($property.Name)" }
    }
    $accepted = Get-Content -LiteralPath $selection.manifest.path -Raw | ConvertFrom-Json
    if (-not $accepted.success) { throw 'Source-build manifest unsuccessful' }
    foreach ($identity in $accepted.inputs) {
        if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Accepted input changed: $($identity.path)" }
    }
    $inputs += @($accepted.inputs)
    $stages = @((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
    foreach ($stage in $stages) {
        $identity = @($accepted.artifacts | Where-Object path -CEQ $stage)
        if ($identity.Count -ne 1 -or (Get-ArtifactIdentity $stage).sha256 -cne $identity[0].sha256) { throw 'Stage identity mismatch' }
    }
    $inputs += @(Get-ChildItem -LiteralPath $PSScriptRoot -File | ForEach-Object {Get-ArtifactIdentity $_.FullName})
    $inputs += @((Join-Path $root 'std-lib/UBECore.UBE'),(Join-Path $root 'std-lib/src/portable/LibraryIdentity.bas'),(Join-Path $root 'std-lib/src/portable/Utf8.bas'),(Join-Path $root 'std-lib/src/portable/ByteBuffer.bas')) | ForEach-Object {Get-ArtifactIdentity $_}
    $main = Native-Module 'Main' "Function Main() As Long`nPrint Value()`nMain = 0`nEnd Function"
    Write-Fixture 'Main.bas' $main | Out-Null
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Public Function Value() As Long`nValue = 23`nEnd Function") | Out-Null
    $library = "UBE-Project 1`nName = `"ProbeLibrary`"`nKind = `"Library`"`nSource = `"Library.bas`"`n"
    Write-Fixture 'library/Library.UBE' $library | Out-Null
    $source = 'Source = "Main.bas"'
    $reference = 'Reference = "library/Library.UBE"'
    $project = Exe-Project 'Probe' $source $reference
    Test-Project 'direct-public' $project "23`n"
    Write-Fixture 'Minimal.bas' (Native-Module 'Minimal' "Function Main() As Long`nMain = 0`nEnd Function") | Out-Null
    Test-Project 'native-eof-short-lines-regression' (Exe-Project 'Minimal' 'Source = "Minimal.bas"') ''
    Write-Fixture 'Bare.bas' "Function Main() As Long`nMain = 0`nEnd Function`n" | Out-Null
    Test-Project 'bare-eof-regression' (Exe-Project 'Bare' 'Source = "Bare.bas"') ''
    Write-Fixture 'RecordHead.bas' "Type AcrossModules`nFirst As Long`n" | Out-Null
    Write-Fixture 'RecordTail.bas' "Second As Long`nEnd Type`nFunction Main() As Long`nMain = 0`nEnd Function`n" | Out-Null
    Test-Project 'cross-module-ordinary-record' (Exe-Project 'RecordBoundary' "Source = `"RecordHead.bas`"`nSource = `"RecordTail.bas`"") '' 'UBE5029'
    Write-Fixture 'ShortName.bas' "UBE SOURCE 1 MODULE`nx`nFunction Main() As Long`nMain = 0`nEnd Function`n" | Out-Null
    Test-Project 'short-name-line-regression' (Exe-Project 'ShortName' 'Source = "ShortName.bas"') '' 'UBE5021'
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Function Value() As Long`nValue = 23`nEnd Function") | Out-Null
    Test-Project 'direct-default-public' $project "23`n"
    Write-Fixture 'library/Library.UBE' (([string][char]0xFEFF) + $library) | Out-Null
    Test-Project 'bom-library-manifest' $project "23`n"
    Write-Fixture 'library/Library.UBE' $library | Out-Null
    $bomMain = Native-Module 'BomMain' "Function Main() As Long`nPrint BomHelper()`nMain = 0`nEnd Function"
    $bomHelper = Native-Module 'BomHelper' "Function BomHelper() As Long`nBomHelper = 42`nEnd Function"
    Write-Fixture 'BomMain.bas' (([string][char]0xFEFF) + $bomMain) | Out-Null
    Write-Fixture 'BomHelper.bas' (([string][char]0xFEFF) + $bomHelper) | Out-Null
    $bomProject = Exe-Project 'BomProof' "Source = `"BomMain.bas`"`nSource = `"BomHelper.bas`"" 'Reference = "../../../../std-lib/UBECore.UBE"'
    Test-Project 'bom-native-modules' $bomProject "42`n"
    Write-Fixture 'BomMain.bas' $bomMain | Out-Null
    Write-Fixture 'BomHelper.bas' $bomHelper | Out-Null
    Test-Project 'bom-executable-manifest' (([string][char]0xFEFF) + $bomProject) "42`n"
    Write-Fixture 'library/Tail.bas' (Native-Module 'Tail' "Function Tail() As Long`nTail = 4`nEnd Function") | Out-Null
    Write-Fixture 'library/Library.UBE' ($library + "Source = `"Tail.bas`"`n") | Out-Null
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Function Value() As Long`nValue = 23") | Out-Null
    Test-Project 'cross-module-declaration' $project '' 'UBE5029'
    Write-Fixture 'library/Library.UBE' $library | Out-Null
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Function Value() As Long`nValue = 23`nEnd Function") | Out-Null
    Write-Fixture 'second/Library.bas' (Native-Module 'Library' "Function OtherValue() As Long`nOtherValue = 31`nEnd Function") | Out-Null
    Write-Fixture 'second/Library.UBE' "UBE-Project 1`nName = `"Independent`"`nKind = `"Library`"`nSource = `"Library.bas`"`n" | Out-Null
    Write-Fixture 'Two.bas' (Native-Module 'Two' "Function Main() As Long`nPrint Value()`nPrint OtherValue()`nMain = 0`nEnd Function") | Out-Null
    $two = Exe-Project 'Two' 'Source = "Two.bas"' ($reference + "`nReference = `"second/Library.UBE`"`n")
    Test-Project 'independent-public-packages' $two "23`n31`n"
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Function Value() As Long`nValue = OtherValue()`nEnd Function") | Out-Null
    Test-Project 'independent-library-visibility' $two '' 'UBE5024'
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Function Value() As Long`nValue = 23`nEnd Function") | Out-Null
    Test-Project 'duplicate-reference' ($project + "`nReference = `"library/./Library.UBE`"`n") '' 'UBE5013'
    Test-Project 'self-reference' (Exe-Project 'Probe' $source 'Reference = "self-reference.UBE"') '' 'UBE5013'
    Test-Project 'absolute-reference' (Exe-Project 'Probe' $source 'Reference = "C:/Library.UBE"') '' 'UBE5019'
    Test-Project 'excessive-reference-path' (Exe-Project 'Probe' $source ('Reference = "' + ('x' * 4097) + '.UBE"')) '' 'UBE5019'
    Test-Project 'reference-bound' (Exe-Project 'Probe' $source (($reference + "`n") * 17)) '' 'UBE5019'
    Test-Project 'source-bound' (Exe-Project 'Probe' ((0..256 | ForEach-Object {'Source = "M' + $_ + '.bas"'}) -join "`n")) '' 'UBE5016'
    Test-Project 'source-escape' (Exe-Project 'Probe' 'Source = "../Main.bas"') '' 'UBE5009'
    Test-Project 'startup-value' ($project.Replace('Startup = "Main"','Startup = "Other"')) '' 'UBE5017'
    Test-Project 'startup-missing' ($project.Replace("Startup = `"Main`"`n",'')) '' 'UBE5017'
    Test-Project 'startup-duplicate' ($project + "`nStartup = `"Main`"`n") '' 'UBE5017'
    Test-Project 'name-invalid' ($project.Replace('Name = "Probe"','Name = "Bad Name"')) '' 'UBE5015'
    Test-Project 'name-duplicate' ($project.Replace('Name = "Probe"','Name = "probelibrary"')) '' 'UBE5014'
    Test-Project 'standalone-library' $library '' 'UBE5006'
    Write-Fixture 'library/Library.UBE' ($library.Replace('Kind = "Library"','Kind = "Exe"')) | Out-Null
    Test-Project 'reference-executable' $project '' 'UBE5006'
    Write-Fixture 'library/Library.UBE' ($library + "Startup = `"Main`"`n") | Out-Null
    Test-Project 'library-startup' $project '' 'UBE5017'
    Write-Fixture 'library/Library.UBE' ($library + "Reference = `"../nested-reference.UBE`"`n") | Out-Null
    Test-Project 'nested-reference' $project '' 'UBE5018'
    Write-Fixture 'library/Library.UBE' $library | Out-Null
    foreach ($visibility in @('Private','Friend')) {
        Write-Fixture 'library/Library.bas' (Native-Module 'Library' "$visibility Function Value() As Long`nValue = 23`nEnd Function") | Out-Null
        Test-Project ('visibility-'+$visibility) $project '' 'UBE5023'
    }
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Dim SharedValue As Long`nFunction Value() As Long`nValue = 23`nEnd Function") | Out-Null
    Test-Project 'module-storage' $project '' 'UBE5023'
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Function Main() As Long`nMain = 23`nEnd Function") | Out-Null
    Write-Fixture 'NoMain.bas' (Native-Module 'NoMain' "Function Other() As Long`nOther = 0`nEnd Function") | Out-Null
    Test-Project 'library-entry' (Exe-Project 'Probe' 'Source = "NoMain.bas"' $reference) '' 'UBE5025'
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Function Value() As Long`nValue = Helper()`nEnd Function") | Out-Null
    Write-Fixture 'Helper.bas' (Native-Module 'Helper' "Function Helper() As Long`nHelper = 9`nEnd Function") | Out-Null
    Test-Project 'library-reverse-visibility' (Exe-Project 'Probe' ($source + "`nSource = `"Helper.bas`"") $reference) '' 'UBE5024'
    Write-Fixture 'library/Library.bas' (Native-Module 'Library' "Function Value() As Long`nValue = 23`nEnd Function") | Out-Null
    Write-Fixture 'Qualified.bas' (Native-Module 'Qualified' "Function Main() As Long`nPrint ProbeLibrary.Library.Value()`nMain = 0`nEnd Function") | Out-Null
    Test-Project 'package-qualification' (Exe-Project 'Probe' 'Source = "Qualified.bas"' $reference) '' 'UBE5026'
    Write-Fixture 'Duplicate.bas' (Native-Module 'main' "Function Other() As Long`nOther = 0`nEnd Function") | Out-Null
    Test-Project 'module-identity' (Exe-Project 'Probe' ($source + "`nSource = `"Duplicate.bas`"") $reference) '' 'UBE5027'
    foreach ($case in @(@('version',"UBE SOURCE 2 MODULE`nAttribute UBE_Name = `"Main`"`n",'UBE5020'),@('kind',"UBE SOURCE 1 CLASS`nAttribute UBE_Name = `"Main`"`n",'UBE5020'),@('name',"UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Bad Name`"`n",'UBE5021'),@('attribute',"UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Main`"`nAttribute UBE_Unknown = `"x`"`n",'UBE5022'),@('bare','', 'UBE5020'))) {
        Write-Fixture 'Invalid.bas' ($case[1]+"Function Main() As Long`nMain = 0`nEnd Function`n") | Out-Null
        Test-Project ('envelope-'+$case[0]) (Exe-Project 'Probe' 'Source = "Invalid.bas"' $reference) '' $case[2]
    }
    $consumer = @'
Function Main() As Long
    Dim Buffer As ByteBuffer
    Dim Snapshot() As Byte
    Dim Scalars As Long = 0
    If TryAppendByte(Buffer, 65) = False Or TryAppendByte(Buffer, 194) = False Or TryAppendByte(Buffer, 162) = False Then
        Main = 10
        Exit Function
    End If
    If TryCountUtf8Scalars(Buffer, Scalars) = False Or TrySnapshotByteBuffer(Buffer, Snapshot) = False Then
        Main = 11
        Exit Function
    End If
    Buffer.Storage(0) = 66
    Print Scalars
    Print ByteStorageLength(Snapshot)
    Print Snapshot(0)
    Main = 0
End Function
'@
    Write-Fixture 'Consumer.bas' (Native-Module 'Consumer' $consumer) | Out-Null
    Test-Project 'actual-ubecore' (Exe-Project 'Probe' 'Source = "Consumer.bas"' 'Reference = "../../../../std-lib/UBECore.UBE"') "2`n3`n65`n"
    foreach ($identity in $inputs) { if ((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256) { throw "Input changed: $($identity.path)" } }
    $success = $true
} catch { $failure = $_.Exception.Message }
finally {
    $path = Join-Path $run 'report.json'
    [pscustomobject]@{schema='ube-direct-source-reference-proof-1';success=$success;failure=$failure;acceptedSelection=$selection;inputs=$inputs;checks=$checks;commands=$commands;fixtureSnapshots=$fixtureSnapshots;artifacts=@(Get-ChildItem -LiteralPath $run -Recurse -File | ForEach-Object {Get-ArtifactIdentity $_.FullName});limits='Direct independent Public-only libraries; no standalone shared-library output or complete package/name-lookup semantics'} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Output "Evidence: $path"
}
if (-not $success) { throw $failure }
Write-Output "PASS: $($checks.Count) direct source-reference assertions."
