function Get-ProofOption($Object, [string]$Name, $Default = $null) {
    if ($null -ne $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $Default
}

function Write-NativeTypeCases([string]$Fixtures, [string]$Destination, $Suite) {
    if ($Suite.schema -ne 1 -or $Suite.status -cne 'adopted-acceptance') { throw 'Native-value corpus is not the adopted acceptance schema' }
    $names = @{}
    $rendered = @()
    foreach ($case in $Suite.cases) {
        if ($case.name -notmatch '^[a-z][a-z0-9-]*$' -or $names.ContainsKey($case.name)) { throw 'Invalid or duplicate proof name' }
        $names[$case.name] = $true
        if ($case.expect -notin @('native','reject')) { throw 'Unknown native proof expectation' }
        $files = @{}
        foreach ($name in $Suite.templateFiles) {
            if ($name -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Invalid template name' }
            $files[$name] = [IO.File]::ReadAllText((Join-Path $Fixtures $name)).Replace("`r`n","`n")
        }
        $overrides = Get-ProofOption $case 'files'
        if ($null -ne $overrides) {
            foreach ($property in $overrides.PSObject.Properties) {
                if (-not $files.ContainsKey($property.Name)) { throw 'Unknown overridden proof file' }
                $files[$property.Name] = $property.Value
            }
        }
        $rename = Get-ProofOption $case 'rename'
        if ($null -ne $rename) {
            foreach ($name in @($files.Keys)) { $files[$name] = $files[$name].Replace($rename.old,$rename.new) }
        }
        $mutations = @()
        $mutation = Get-ProofOption $case 'mutation'
        if ($null -ne $mutation) { $mutations += $mutation }
        $mutations += @(Get-ProofOption $case 'mutations' @())
        foreach ($mutation in $mutations) {
            if (-not $files.ContainsKey($mutation.source)) { throw 'Unknown mutated proof file' }
            $actual = [regex]::Matches($files[$mutation.source],[regex]::Escape($mutation.old)).Count
            if ($actual -ne $mutation.count) { throw "Mutation count differs: $($case.name): expected $($mutation.count), got $actual" }
            $files[$mutation.source] = $files[$mutation.source].Replace($mutation.old,$mutation.new)
        }
        $append = Get-ProofOption $case 'append'
        if ($null -ne $append) { $files['ValueType.bas'] += $append }
        $directory = Join-Path $Destination $case.name
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        foreach ($name in $files.Keys) {
            [IO.File]::WriteAllText((Join-Path $directory $name),$files[$name],(New-Object Text.UTF8Encoding($false)))
        }
        $rendered += [pscustomobject]@{ specification = $case; directory = $directory; project = (Join-Path $directory 'NativeValue.UBE') }
    }
    return $rendered
}
