[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$docsRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$failures = [Collections.Generic.List[string]]::new()
$files = @(Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter '*.html' | Where-Object {
    $relative = $_.FullName.Substring($docsRoot.Length).TrimStart('\').Replace('\','/')
    $relative -notmatch '^(\.work|prototype)/'
})
$contents = @{}
$identities = @{}
$paths = [Collections.Generic.List[string]]::new()
$linkCount = 0
function Fail([string]$message) { $failures.Add($message) }
foreach ($file in $files) {
    $relative = $file.FullName.Substring($docsRoot.Length).TrimStart('\').Replace('\','/')
    $html = [IO.File]::ReadAllText($file.FullName)
    $contents[$file.FullName] = $html
    $paths.Add($relative)
    if ([regex]::Matches($html,'<main\b').Count -ne 1) { Fail "$relative needs exactly one main." }
    if ($html -notmatch '<html[^>]+lang="en"' -or $html -notmatch '<title>[^<]+</title>') { Fail "$relative needs English language and title." }
    if ($relative -in @('index.html','navigation/index.html')) { continue }
    if ([regex]::Matches($html,'<h1\b').Count -ne 1) { Fail "$relative needs exactly one h1." }
    $id = [regex]::Match($html,'data-article-id="([^"]+)"').Groups[1].Value
    if (-not $id) { Fail "$relative missing article identity." }
    elseif ($identities.ContainsKey($id)) { Fail "Duplicate article identity $id." }
    else { $identities[$id]=$relative }
    foreach ($required in @('class="page-nav"','class="skip-link"','id="overview"','class="breadcrumbs"','class="article-footer"')) {
        if (-not $html.Contains($required)) { Fail "$relative missing $required." }
    }
    $pageNav = [regex]::Match($html,'<nav class="page-nav"[^>]*>([\s\S]*?)</nav>').Groups[1].Value
    foreach ($destination in @('about/contents.html','language/words/index.html')) {
        if ($pageNav -notmatch ('href="(?:\.\./)*'+[regex]::Escape($destination)+'"')) { Fail "$relative missing standalone navigation to $destination." }
    }
    foreach ($section in @('overview','details','example')) {
        $hasSection = $html.Contains('id="'+$section+'"')
        $hasLink = $pageNav.Contains('href="#'+$section+'"')
        if ($hasSection -ne $hasLink) { Fail "$relative section/navigation mismatch for $section." }
    }
    foreach ($empty in [regex]::Matches($html,'<h([23])[^>]*>([^<]+)</h\1>\s*(?=<h\1\b|</section>)')) {
        Fail "$relative has empty heading: $($empty.Groups[2].Value)"
    }
    $status = [regex]::Match($html,'<span class="badge status">([^<]+)</span>').Groups[1].Value
    if ($status -notin @('Implemented','Partially implemented','Specified','Planned','Compatibility only','Deprecated','Unsupported')) { Fail "$relative invalid status $status." }
    if ($html -match '(?i)Compiler\s*v[1-4]\b|fresh[- ]v[1-4]\b|source-built v2|UBE_Compiler_v3|bootstrap/out/v3|preserved v[12]|archived previews?|syntax-only checker|cannot yet (?:build|produce|generate) (?:or run )?(?:native |executable )?programs') { Fail "$relative contains obsolete compiler wording." }
    foreach ($code in [regex]::Matches($html,'<pre[^>]*>\s*<code[^>]*>([\s\S]*?)</code>\s*</pre>')) {
        $text = [Net.WebUtility]::HtmlDecode([regex]::Replace($code.Groups[1].Value,'<[^>]*>',''))
        if ($text -match '(?im)(?:^\s*|\bThen\s+|\bElse\s+|:\s*)Print\s+(?!#)') { Fail "$relative contains a bare Print sample." }
    }
}
foreach ($file in $files) {
    $relative = $file.FullName.Substring($docsRoot.Length).TrimStart('\').Replace('\','/')
    $html = $contents[$file.FullName]
    foreach ($match in [regex]::Matches($html,'(?:href|src)="([^"]+)"')) {
        $url = [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
        if ($url -match '^\w+:|^//') { Fail "$relative uses a non-local URL: $url"; continue }
        $parts=$url.Split('#',2)
        try {
            $resolved=if($parts[0]){[IO.Path]::GetFullPath((Join-Path $file.DirectoryName $parts[0]))}else{$file.FullName}
        } catch { Fail "$relative has malformed URL $url"; continue }
        if (-not $resolved.StartsWith($docsRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { Fail "$relative links outside docs: $url"; continue }
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { Fail "$relative has missing target: $url"; continue }
        $linkCount++
        if($parts.Count -eq 2 -and $parts[1]){
            if($resolved -eq (Join-Path $docsRoot 'index.html')){
                $route=$parts[1].Split('#',2)[0]
                if($route -notin $paths){Fail "$relative has unknown shell route $url"}
            }else{
                $destination = if($contents.ContainsKey($resolved)){$contents[$resolved]}else{[IO.File]::ReadAllText($resolved)}
                if($destination -notmatch ('id="'+[regex]::Escape($parts[1])+'"')){Fail "$relative has missing anchor $url"}
            }
        }
    }
}
$shell = [IO.File]::ReadAllText((Join-Path $docsRoot 'index.html'))
if ([regex]::Matches($shell,'<iframe\b').Count -ne 2 -or $shell -match '<header\b|<nav\b') { Fail 'Index must have exactly two frames and no top bar.' }
$catalogText = [IO.File]::ReadAllText((Join-Path $docsRoot 'assets/js/navigation-data.js'))
$catalogJson = [regex]::Match($catalogText,'window\.UBE_DOCS\s*=\s*([\s\S]+);\s*$').Groups[1].Value
try { $catalog=$catalogJson | ConvertFrom-Json } catch { Fail 'Navigation catalogue is invalid JSON.'; $catalog=$null }
$catalogPaths=[Collections.Generic.List[string]]::new()
function Collect-Paths($items) { foreach($item in $items){ if($item.path){$catalogPaths.Add($item.path)}; if($item.children){Collect-Paths $item.children} } }
if($catalog){Collect-Paths $catalog.sections}
foreach($duplicate in $catalogPaths | Group-Object | Where-Object Count -gt 1){Fail "Duplicate catalogue path $($duplicate.Name)"}
foreach($entry in $catalogPaths){if($entry -notin $paths){Fail "Missing catalogue page $entry"}}
foreach($entry in $paths){if($entry -notin @('index.html','navigation/index.html','about/contents.html','about/not-found.html') -and $entry -notin $catalogPaths){Fail "Uncatalogued page $entry"}}
$nav = [IO.File]::ReadAllText((Join-Path $docsRoot 'navigation/index.html'))
foreach($entry in $catalogPaths){if(-not $nav.Contains('data-path="'+$entry+'"')){Fail "Left pane misses $entry"}}
$wordRoot=Join-Path $docsRoot 'language/words'
$wordFiles=@(Get-ChildItem -LiteralPath $wordRoot -Recurse -Filter '*.html' -File | Where-Object Name -ne 'index.html')
$wordNames=@()
foreach($file in $wordFiles){
    $html=[IO.File]::ReadAllText($file.FullName)
    $wordNames += [regex]::Match($html,'<h1>([^<]+)</h1>').Groups[1].Value.ToLowerInvariant()
    foreach($required in @('id="overview"','id="details"','id="example"','<h2>Syntax</h2>','<pre><code>','class="see-also"')){
        if(-not $html.Contains($required)){Fail "$($file.Name) missing reference element $required"}
    }
}
$grammar=[IO.File]::ReadAllText((Join-Path $docsRoot '../lang-doc/grammar/ube.ebnf'))
$fragments=@('a','b','c','d','e','f','i','l','r','s','ui','ul','us')
$expected=[regex]::Matches($grammar,'"([A-Za-z][A-Za-z ]*)"') | ForEach-Object {$_.Groups[1].Value -split ' '} | ForEach-Object {$_.ToLowerInvariant()} | Where-Object {$_ -and $_ -notin $fragments} | Sort-Object -Unique
foreach($word in $expected){if($word -notin $wordNames){Fail "Missing grammar word: $word"}}
$landing=[IO.File]::ReadAllText((Join-Path $wordRoot 'index.html'))
foreach($letter in [char[]]'abcdefghijklmnopqrstuvwxyz'){
    if(-not $landing.Contains('href="'+$letter+'/index.html"')){Fail "Missing A-Z letter $letter"}
    $letterPath=Join-Path $wordRoot "$letter/index.html"
    if(-not(Test-Path $letterPath)){Fail "Missing letter page $letter";continue}
    $letterText=[IO.File]::ReadAllText($letterPath)
    foreach($file in Get-ChildItem (Join-Path $wordRoot "$letter") -Filter '*.html' | Where-Object Name -ne 'index.html'){
        if([regex]::Matches($letterText,'href="'+[regex]::Escape($file.Name)+'"').Count -ne 1){Fail "Letter $letter must list $($file.Name) exactly once"}
    }
}
if($failures.Count){foreach($failure in $failures){Write-Output "FAIL $failure"};throw "$($failures.Count) documentation checks failed."}
Write-Output "PASS $($files.Count) public HTML files; $linkCount local links/assets/anchors; $($wordFiles.Count) word pages; all grammar words; catalogue and left-pane coverage; two-frame shell; no obsolete compiler claims."
