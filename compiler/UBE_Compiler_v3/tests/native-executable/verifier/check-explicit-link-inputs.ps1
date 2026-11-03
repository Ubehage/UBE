param([Parameter(Mandatory=$true)][string] $Clang,
      [Parameter(Mandatory=$true)][string] $Linker,
      [Parameter(Mandatory=$true)][string] $Readobj,
      [Parameter(Mandatory=$true)][string] $Ir,
      [Parameter(Mandatory=$true)][string] $Object,
      [Parameter(Mandatory=$true)][string] $ReferenceExecutable,
      [Parameter(Mandatory=$true)][string] $MingwLibraryDirectory,
      [Parameter(Mandatory=$true)][string] $GccLibraryDirectory,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$clangPath=(Resolve-Path -LiteralPath $Clang).Path
$linkerPath=(Resolve-Path -LiteralPath $Linker).Path
$readerPath=(Resolve-Path -LiteralPath $Readobj).Path
$irPath=(Resolve-Path -LiteralPath $Ir).Path
$objectPath=(Resolve-Path -LiteralPath $Object).Path
$referenceObject=$objectPath
$reference=(Resolve-Path -LiteralPath $ReferenceExecutable).Path
$mingw=(Resolve-Path -LiteralPath $MingwLibraryDirectory).Path
$gcc=(Resolve-Path -LiteralPath $GccLibraryDirectory).Path
$root=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
$windows=[Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$childEnvironment=@{SystemRoot=$windows;WINDIR=$windows;TEMP=$root;TMP=$root;PATH=(([IO.Path]::GetDirectoryName($clangPath)),([IO.Path]::GetDirectoryName($linkerPath)),(Join-Path $windows 'System32') -join ';')}
function Invoke-Tool([string[]] $Items, [string] $Program=$clangPath) {
    $tool=[Diagnostics.Process]::new()
    $tool.StartInfo.FileName=$Program
    # These test arguments cannot contain embedded quotes or end in a backslash.
    foreach ($item in $Items) { if ($item.Contains('"') -or $item.EndsWith('\')) { throw 'Unsupported test argument spelling' } }
    $tool.StartInfo.Arguments=(@($Items | ForEach-Object { '"'+$_+'"' }) -join ' ')
    $tool.StartInfo.UseShellExecute=$false; $tool.StartInfo.CreateNoWindow=$true
    $tool.StartInfo.WorkingDirectory=$root
    $tool.StartInfo.RedirectStandardOutput=$true; $tool.StartInfo.RedirectStandardError=$true
    $tool.StartInfo.EnvironmentVariables.Clear()
    foreach ($key in $childEnvironment.Keys) { $tool.StartInfo.EnvironmentVariables[$key]=$childEnvironment[$key] }
    try {
        if (-not $tool.Start()) { throw 'Clang did not start' }
        $stdout=$tool.StandardOutput.ReadToEndAsync(); $stderr=$tool.StandardError.ReadToEndAsync()
        if (-not $tool.WaitForExit(15000)) { $tool.Kill(); $tool.WaitForExit(); throw 'Test link timed out' }
        return @{exit=$tool.ExitCode;stdout=$stdout.Result;stderr=$stderr.Result}
    } finally { $tool.Dispose() }
}
$objectPath=Join-Path $root 'verified.o'
$compileArguments=@('--no-default-config','--target=x86_64-w64-windows-gnu','-O2','-mno-incremental-linker-compatible','-Xclang','-llvm-verify-each','-c','-x','ir',$irPath,'-o',$objectPath)
$compiled=Invoke-Tool $compileArguments
if ($compiled.exit -ne 0 -or (Get-FileHash -LiteralPath $objectPath).Hash -ne (Get-FileHash -LiteralPath $referenceObject).Hash) { throw 'Explicit environment changed object compilation' }
$prefix=@((Join-Path $mingw 'crt2.o'),(Join-Path $gcc 'crtbegin.o'))
$libraries=@('mingw32','gcc','gcc_eh','moldname','mingwex','msvcrt','advapi32','shell32','user32','kernel32','mingw32','gcc','gcc_eh','moldname','mingwex','msvcrt','kernel32')
$archives=@($libraries | ForEach-Object {
    $directory=if ($_ -in @('gcc','gcc_eh')) { $gcc } else { $mingw }
    Join-Path $directory ('lib'+$_+'.a')
})
foreach ($archive in @($archives | Select-Object -Unique)) {
    $stream=[IO.File]::OpenRead($archive)
    try {
        $magic=[byte[]]::new(8)
        if ($stream.Read($magic,0,8) -ne 8 -or [Text.Encoding]::ASCII.GetString($magic) -cne "!<arch>`n") { throw "Not an ordinary embedded-member archive: $archive" }
    } finally { $stream.Dispose() }
}
$suffix=Join-Path $gcc 'crtend.o'
$inputs=@($prefix)+@($objectPath)+@($archives)+@($suffix)
foreach ($inputPath in $inputs) { if (-not [IO.File]::Exists($inputPath)) { throw "Missing explicit input: $inputPath" } }
$candidate=Join-Path $root 'explicit.exe'
$reproducer=Join-Path $root 'link-inputs.tar'
$linkOptions=@('-Wl,--no-insert-timestamp','-Wl,--subsystem,console','-Wl,--threads=1','-Wl,--Xlink=/nodefaultlib')
$driverOptions=@('--no-default-config','--target=x86_64-w64-windows-gnu','-nostdlib',"--ld-path=$linkerPath")
$arguments=$driverOptions+$inputs+$linkOptions+@("-Wl,--reproduce=$reproducer",'-o',$candidate)
$normal=Invoke-Tool $arguments
if ($normal.exit -ne 0 -or -not [IO.File]::Exists($candidate) -or -not [IO.File]::Exists($reproducer)) { throw "Explicit link failed: $($normal.stderr)" }
if ((Get-FileHash -LiteralPath $candidate).Hash -ne (Get-FileHash -LiteralPath $reference).Hash) { throw 'Explicit support selection changed executable bytes' }
$process=[Diagnostics.Process]::new()
$process.StartInfo.FileName=$candidate; $process.StartInfo.UseShellExecute=$false; $process.StartInfo.CreateNoWindow=$true
try {
    if (-not $process.Start()) { throw 'Test fixture did not start' }
    if (-not $process.WaitForExit(10000)) { $process.Kill(); $process.WaitForExit(); throw 'Test fixture timed out' }
    if ($process.ExitCode -ne 7) { throw 'Test fixture did not return 7' }
} finally { $process.Dispose() }
$imports=Invoke-Tool -Items @('--coff-imports',$candidate) -Program $readerPath
if ($imports.exit -ne 0) { throw 'Could not inspect fixture imports' }
$expectedImports=@('KERNEL32.dll','api-ms-win-crt-environment-l1-1-0.dll','api-ms-win-crt-heap-l1-1-0.dll','api-ms-win-crt-locale-l1-1-0.dll','api-ms-win-crt-math-l1-1-0.dll','api-ms-win-crt-private-l1-1-0.dll','api-ms-win-crt-runtime-l1-1-0.dll','api-ms-win-crt-stdio-l1-1-0.dll','api-ms-win-crt-string-l1-1-0.dll')
$actualImports=@([regex]::Matches($imports.stdout,'(?m)^  Name: (.+)\r?$') | ForEach-Object { $_.Groups[1].Value.TrimEnd("`r") })
if (($actualImports -join ';') -cne ($expectedImports -join ';')) { throw 'Fixture imports differ from independently recorded kernel/UCRT list' }
[IO.File]::WriteAllText((Join-Path $root 'imports.txt'),$imports.stdout,[Text.UTF8Encoding]::new($false))
# A default configuration can change the command unless explicitly disabled.
$configuration=Join-Path $root 'clang.cfg'
[IO.File]::WriteAllText($configuration,"--ube-invalid-config-control`n",[Text.UTF8Encoding]::new($false))
$configCandidate=Join-Path $root 'config-disabled.exe'
$configArguments=$driverOptions+@("--config-user-dir=$root","--config-system-dir=$root")+$inputs+$linkOptions+@('-o',$configCandidate)
$configDisabled=Invoke-Tool $configArguments
if ($configDisabled.exit -ne 0 -or (Get-FileHash -LiteralPath $configCandidate).Hash -ne (Get-FileHash -LiteralPath $candidate).Hash) { throw 'Default config was not excluded' }
$configFailure=Join-Path $root 'config-enabled.exe'
$configEnabled=Invoke-Tool @($configArguments | Where-Object { $_ -ne '--no-default-config' } | ForEach-Object { if ($_ -eq $configCandidate) { $configFailure } else { $_ } })
if ($configEnabled.exit -eq 0 -or $configEnabled.stderr -notmatch 'ube-invalid-config-control' -or [IO.File]::Exists($configFailure)) { throw 'Enabled configuration control did not fail as expected' }
# Default-library directives are another search route, even with -nostdlib.
$directiveSource=Join-Path $root 'default-library.s'
$directiveObject=Join-Path $root 'default-library.o'
[IO.File]::WriteAllText($directiveSource,".section .drectve`n.ascii `" /DEFAULTLIB:ube_missing_control_library `"`n",[Text.UTF8Encoding]::new($false))
$assembly=Invoke-Tool @('--no-default-config','--target=x86_64-w64-windows-gnu','-c',$directiveSource,'-o',$directiveObject)
if ($assembly.exit -ne 0) { throw "Directive control assembly failed: $($assembly.stderr)" }
$directiveCandidate=Join-Path $root 'directive-disabled.exe'
$directiveArguments=$driverOptions+$inputs+@($directiveObject)+$linkOptions+@('-o',$directiveCandidate)
$directiveDisabled=Invoke-Tool $directiveArguments
if ($directiveDisabled.exit -ne 0 -or -not [IO.File]::Exists($directiveCandidate)) { throw 'Explicit libraries failed with default-library directives disabled' }
$directiveFailure=Join-Path $root 'directive-enabled.exe'
$directiveEnabled=Invoke-Tool @($directiveArguments | Where-Object { $_ -ne '-Wl,--Xlink=/nodefaultlib' } | ForEach-Object { if ($_ -eq $directiveCandidate) { $directiveFailure } else { $_ } })
if ($directiveEnabled.exit -eq 0 -or $directiveEnabled.stderr -notmatch 'ube_missing_control_library' -or [IO.File]::Exists($directiveFailure)) { throw 'Enabled default-library control did not fail as expected' }
# Only extract the archive just produced by this controlled link. Validate every
# member name first; do not accept traversal, absolute entries or links.
$listing=@(& tar -tf $reproducer)
if ($LASTEXITCODE -ne 0 -or -not $listing.Count) { throw 'Could not list reproduction archive' }
foreach ($entry in $listing) {
    if ([IO.Path]::IsPathRooted($entry) -or $entry.Contains(':') -or $entry -match '(^|[/\\])\.\.([/\\]|$)') { throw 'Unsafe archive entry' }
}
$details=@(& tar -tvf $reproducer)
if ($LASTEXITCODE -ne 0 -or @($details | Where-Object { $_ -notmatch '^[-d]' }).Count) { throw 'Unexpected archive entry type' }
$extract=Join-Path $root 'reproduced-inputs'; [IO.Directory]::CreateDirectory($extract) | Out-Null
& tar -xf $reproducer -C $extract
if ($LASTEXITCODE -ne 0) { throw 'Could not extract reproduction archive' }
$files=@(Get-ChildItem -LiteralPath $extract -File -Recurse)
$observed=@()
foreach ($inputPath in @($inputs | Select-Object -Unique)) {
    $hash=(Get-FileHash -LiteralPath $inputPath).Hash
    $matches=@($files | Where-Object { $_.Name -eq [IO.Path]::GetFileName($inputPath) -and (Get-FileHash -LiteralPath $_.FullName).Hash -eq $hash })
    if ($matches.Count -ne 1) { throw "Reproducer did not contain exactly one matching input: $inputPath" }
    $observed+=[pscustomobject]@{path=$inputPath;sha256=$hash;reproduced=$matches[0].FullName;bytes=$matches[0].Length}
}
$unexpected=@($files | Where-Object { $_.Name -notin @('response.txt','version.txt') -and $_.FullName -notin @($observed.reproduced) })
if ($unexpected.Count) { throw "Unexpected reproduced inputs: $($unexpected.FullName -join ', ')" }
$identityPaths=@($clangPath,$linkerPath,$readerPath,$irPath,$referenceObject,$objectPath,$reference,$PSCommandPath,$configuration,$directiveSource,$directiveObject)
$identities=@($identityPaths | ForEach-Object { [pscustomobject]@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash} })
[pscustomobject]@{identities=$identities;compileArguments=$compileArguments;arguments=$arguments;environment=$childEnvironment;inputs=$observed;imports=$actualImports;candidateSha256=(Get-FileHash -LiteralPath $candidate).Hash;expectedExit=7;byteIdentical=$true;configDisabled=$configDisabled;configEnabled=$configEnabled;directiveDisabled=$directiveDisabled;directiveEnabled=$directiveEnabled} |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $root 'report.json') -Encoding UTF8
Write-Output "Explicit support sequence: $($observed.Count) unique reproduced inputs, identical executable, exit 7."
Write-Output 'Default config and default-library controls: disabled passed; omitted flags failed with their independent markers and no output.'
Write-Output "Evidence: $root"
