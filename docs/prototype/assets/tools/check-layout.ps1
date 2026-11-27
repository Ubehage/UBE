$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$files = Get-ChildItem -LiteralPath $root -Recurse -Filter '*.html'
$links = 0
foreach ($file in $files) {
    $html = [IO.File]::ReadAllText($file.FullName)
    if ([regex]::Matches($html, '<main\b').Count -ne 1) { throw "Expected one main: $($file.Name)" }
    if ($html -notmatch '<title>.+?</title>') { throw "Missing title: $($file.Name)" }
    foreach ($match in [regex]::Matches($html, '(?:href|src)="([^"]+)"')) {
        $url = $match.Groups[1].Value
        if ($url -match '^\w+:|^//') { throw "Non-local resource: $url" }
        $parts = $url.Split('#', 2)
        $target = if ($parts[0]) { [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $parts[0])) } else { $file.FullName }
        if (-not $target.StartsWith($root + [IO.Path]::DirectorySeparatorChar)) { throw "Link leaves prototype: $url" }
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing link: $url in $($file.Name)" }
        if ($parts.Count -eq 2 -and $parts[1]) {
            $destination = [IO.File]::ReadAllText($target)
            if ($destination -notmatch ('id="' + [regex]::Escape($parts[1]) + '"')) { throw "Missing anchor: $url" }
        }
        $links++
    }
}
$shell = [IO.File]::ReadAllText((Join-Path $root 'index.html'))
if ([regex]::Matches($shell, '<iframe\b').Count -ne 2 -or $shell -match '<header\b|<nav\b') { throw 'Shell must have two frames and no header/navigation bar.' }
$entry = [IO.File]::ReadAllText((Join-Path $root 'pages/if.html'))
foreach ($section in @('overview','details','example')) {
    if ($entry -notmatch ('<section id="'+$section+'"') -or $entry -notmatch ('href="#'+$section+'"')) { throw "Missing section/link: $section" }
}
if ((Test-Path (Join-Path $root 'pages/if-details.html')) -or (Test-Path (Join-Path $root 'pages/if-example.html'))) { throw 'Separate reference views remain.' }
if ($entry -match '\bPrint\b') { throw 'Obsolete bare Print sample remains.' }
Write-Output "PASS $($files.Count) HTML files, $links local links/assets/anchors, two-frame shell, and single-page reference sections."
