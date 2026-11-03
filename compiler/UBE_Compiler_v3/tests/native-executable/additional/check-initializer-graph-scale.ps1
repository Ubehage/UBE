param([Parameter(Mandatory=$true)][string] $Compiler,
      [Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
$compilerPath = (Resolve-Path -LiteralPath $Compiler).Path
$root = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
$encoding = [Text.UTF8Encoding]::new($false)
[IO.Directory]::CreateDirectory($root) | Out-Null
$checks = 0
foreach ($size in @(32,64,128)) {
    foreach ($cycle in @($false,$true)) {
        $directory = Join-Path $root "modules-$size-$cycle"
        [IO.Directory]::CreateDirectory($directory) | Out-Null
        $manifest = [Text.StringBuilder]::new()
        [void]$manifest.Append("UBE-Project 1`nName = `"Scale$size`"`nKind = `"Exe`"`nStartup = `"Main`"`n")
        for ($i = 0; $i -lt $size; $i++) {
            $module = 'M{0:D3}' -f $i
            $next = if ($i -lt $size - 1) { 'M{0:D3}.value + 1' -f ($i + 1) } elseif ($cycle) { 'M000.value + 1' } else { '1' }
            $source = "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"$module`"`nPublic value As Long = $next`n"
            [IO.File]::WriteAllText((Join-Path $directory "$module.bas"), $source, $encoding)
            [void]$manifest.Append("Source = `"$module.bas`"`n")
        }
        [IO.File]::WriteAllText((Join-Path $directory 'App.bas'), "UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"App`"`nFunction Main() As Long`n    Main = 0`nEnd Function`n", $encoding)
        [void]$manifest.Append("Source = `"App.bas`"`n")
        $project = Join-Path $directory 'Scale.UBE'
        [IO.File]::WriteAllText($project, $manifest.ToString(), $encoding)
        foreach ($jobs in @(1,4)) {
            $output = @(& $compilerPath --check $project --jobs $jobs 2>&1)
            if ($LASTEXITCODE -ne 0 -or $output.Count -ne 0) { throw "Admission failed: size=$size cycle=$cycle jobs=$jobs output=$output" }
            $checks++
        }
    }
}
Write-Output "Passed $checks generated acyclic/cyclic graph frontend admission checks; native warnings were not tested."
Write-Output "Test-owned fixtures: $root"
