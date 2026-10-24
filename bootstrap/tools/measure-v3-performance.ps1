param(
    [Parameter(Mandatory = $true)][string]$CompilerPath,
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\out\v3-phase0-baseline.json'),
    [ValidateRange(1, 20)][int]$Repetitions = 3,
    [string]$TargetTriple = 'x86_64-w64-windows-gnu'
)

$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$compiler = [System.IO.Path]::GetFullPath($CompilerPath)
$output = [System.IO.Path]::GetFullPath($OutputPath)
$outRoot = [System.IO.Path]::GetFullPath((Join-Path $root 'bootstrap\out'))
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw "Compiler does not exist: $compiler"
}
if (-not $output.StartsWith($outRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Performance output must be beneath $outRoot"
}

$benchmarkRoot = Join-Path $outRoot 'phase0-benchmarks'
New-Item -ItemType Directory -Path $benchmarkRoot -Force | Out-Null
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Write-Utf8File {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Get-RepoRelativePath {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    $prefix = $root + [System.IO.Path]::DirectorySeparatorChar
    if ($full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($prefix.Length).Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

function New-ManySourceBenchmark {
    param([string]$Directory, [int]$Count)
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $manifest = [System.Collections.Generic.List[string]]::new()
    $manifest.Add('UBE-Project 1')
    $manifest.Add('Name = "Phase0ManySource"')
    $manifest.Add('Kind = "Exe"')
    $manifest.Add('Startup = "Main"')
    for ($index = 1; $index -le $Count; $index++) {
        $name = 'Module{0:D3}' -f $index
        $file = "$name.bas"
        $manifest.Add("Source = `"$file`"")
        $body = @(
            'UBE SOURCE 1 MODULE'
            "Attribute UBE_Name = `"$name`""
            ''
            "Public Function Value$index(ByVal InputValue As Long) As Long"
            "    Value$index = InputValue + $index"
            'End Function'
            ''
        ) -join "`n"
        if ($index -eq 1) {
            $body += @(
                'Public Function Main() As Long'
                '    Main = Value1(0) - 1'
                'End Function'
                ''
            ) -join "`n"
        }
        Write-Utf8File -Path (Join-Path $Directory $file) -Text $body
    }
    $project = Join-Path $Directory 'many-source.UBE'
    Write-Utf8File -Path $project -Text (($manifest -join "`n") + "`n")
    return $project
}

function New-ManyProcedureBenchmark {
    param([string]$Directory, [int]$Count)
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('UBE SOURCE 1 MODULE')
    $lines.Add('Attribute UBE_Name = "ManyProcedures"')
    $lines.Add('')
    for ($index = 1; $index -le $Count; $index++) {
        $lines.Add("Public Function Procedure$index(ByVal InputValue As Long) As Long")
        $lines.Add("    Procedure$index = InputValue + $index")
        $lines.Add('End Function')
        $lines.Add('')
    }
    $lines.Add('Public Function Main() As Long')
    $lines.Add('    Main = Procedure1(0) - 1')
    $lines.Add('End Function')
    $source = Join-Path $Directory 'ManyProcedures.bas'
    Write-Utf8File -Path $source -Text (($lines -join "`n") + "`n")
    $project = Join-Path $Directory 'many-procedure.UBE'
    Write-Utf8File -Path $project -Text "UBE-Project 1`nName = `"Phase0ManyProcedure`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"ManyProcedures.bas`"`n"
    return $project
}

function Read-Profile {
    param([string]$Path)
    $lines = [System.IO.File]::ReadAllLines($Path)
    if ($lines.Count -lt 2 -or $lines[0] -ne 'UBE-COMPILER-PROFILE 1') {
        throw "Invalid compiler profile: $Path"
    }
    $values = [ordered]@{}
    foreach ($line in $lines | Select-Object -Skip 1) {
        $separator = $line.IndexOf('=')
        if ($separator -le 0) { throw "Invalid compiler profile field: $line" }
        $name = $line.Substring(0, $separator)
        $text = $line.Substring($separator + 1)
        if ($name -eq 'execution') {
            $values[$name] = $text
        } else {
            $values[$name] = [long]::Parse($text, [Globalization.CultureInfo]::InvariantCulture)
        }
    }
    return [pscustomobject]$values
}

function Get-MedianProfile {
    param([object[]]$Runs)
    $result = [ordered]@{ execution = 'sequential' }
    foreach ($property in $Runs[0].PSObject.Properties.Name | Where-Object { $_ -ne 'execution' }) {
        $ordered = @($Runs | ForEach-Object { [long]$_.$property } | Sort-Object)
        $result[$property] = $ordered[[int][Math]::Floor($ordered.Count / 2)]
    }
    return [pscustomobject]$result
}

function Measure-Benchmark {
    param([string]$Name, [string]$Project)
    $runs = [System.Collections.Generic.List[object]]::new()
    $artifactHashes = [System.Collections.Generic.List[string]]::new()
    for ($run = 1; $run -le $Repetitions; $run++) {
        $llvmPath = Join-Path $benchmarkRoot "$Name-$run.ll"
        $profilePath = Join-Path $benchmarkRoot "$Name-$run.profile"
        & $compiler '--profile' $Project $TargetTriple $llvmPath $profilePath
        if ($LASTEXITCODE -ne 0) { throw "$Name profile run $run failed with exit code $LASTEXITCODE" }
        $runs.Add((Read-Profile -Path $profilePath))
        $artifactHashes.Add((Get-FileHash -LiteralPath $llvmPath -Algorithm SHA256).Hash)
    }
    if (($artifactHashes | Select-Object -Unique).Count -ne 1) {
        throw "$Name emitted different LLVM across repeated measurements"
    }
    return [ordered]@{
        project = Get-RepoRelativePath -Path $Project
        project_sha256 = (Get-FileHash -LiteralPath $Project -Algorithm SHA256).Hash
        llvm_sha256 = $artifactHashes[0]
        repetitions = $Repetitions
        median = Get-MedianProfile -Runs $runs.ToArray()
        runs = $runs.ToArray()
    }
}

$manySourceProject = New-ManySourceBenchmark -Directory (Join-Path $benchmarkRoot 'many-source') -Count 128
$manyProcedureProject = New-ManyProcedureBenchmark -Directory (Join-Path $benchmarkRoot 'many-procedure') -Count 512
$cpu = Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0'
if (-not ('UbePhase0NativeMemory' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class UbePhase0NativeMemory {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct MemoryStatus {
        public uint Length;
        public uint MemoryLoad;
        public ulong TotalPhysical;
        public ulong AvailablePhysical;
        public ulong TotalPageFile;
        public ulong AvailablePageFile;
        public ulong TotalVirtual;
        public ulong AvailableVirtual;
        public ulong AvailableExtendedVirtual;
    }
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GlobalMemoryStatusEx(ref MemoryStatus status);
    public static ulong TotalPhysicalBytes() {
        var status = new MemoryStatus();
        status.Length = (uint)Marshal.SizeOf(status);
        if (!GlobalMemoryStatusEx(ref status)) {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }
        return status.TotalPhysical;
    }
}
'@
}
$physicalMemoryBytes = [UbePhase0NativeMemory]::TotalPhysicalBytes()
$record = [ordered]@{
    schema = 'ube-v3-phase0-performance-1'
    measured_utc = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    host = [ordered]@{
        os = [Environment]::OSVersion.VersionString
        architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        processor = $cpu.ProcessorNameString.Trim()
        logical_processors = [Environment]::ProcessorCount
        physical_memory_bytes = [long]$physicalMemoryBytes
        powershell = $PSVersionTable.PSVersion.ToString()
    }
    compiler = [ordered]@{
        path = Get-RepoRelativePath -Path $compiler
        sha256 = (Get-FileHash -LiteralPath $compiler -Algorithm SHA256).Hash
        target = $TargetTriple
        requested_jobs = 1
        effective_jobs = 1
    }
    benchmark_parameters = [ordered]@{
        repetitions = $Repetitions
        many_source_modules = 128
        many_procedure_functions = 512
    }
    benchmarks = [ordered]@{
        self_compile = Measure-Benchmark -Name 'self' -Project (Join-Path $root 'compiler\UBE_Compiler_v3\UBE_Compiler_v3.UBE')
        ubecore = Measure-Benchmark -Name 'ubecore' -Project (Join-Path $root 'source-library\UBECore.UBE')
        many_source = Measure-Benchmark -Name 'many-source' -Project $manySourceProject
        many_procedure = Measure-Benchmark -Name 'many-procedure' -Project $manyProcedureProject
    }
}

New-Item -ItemType Directory -Path (Split-Path -Parent $output) -Force | Out-Null
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $output -Encoding utf8
Write-Output $output
