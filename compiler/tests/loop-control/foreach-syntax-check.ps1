param([Parameter(Mandatory=$true)][string]$CompilerExe)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube foreach syntax '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$encoding=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
function Check([string]$Name,[string]$Body,[string]$Expected) {
    if($Expected -eq 'E_TYPE'){$Expected='E_TYPE|E_UNSUPPORTED|operation/code/reason 0/3/21'}
    if($Expected -eq 'E_SYNTAX'){$Expected='E_SYNTAX|operation/code/reason 8/2/'}
    $source="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Probe`"`r`nPublic Function Main() As Long`r`nDim Values(0 To 1) As Long`r`nDim Item As Long`r`nDim Index As Long`r`n"+$Body+"`r`nEnd Function`r`n"
    [IO.File]::WriteAllText((Join-Path $evidence ($Name+'.bas')),$source,$encoding)
    $project=Join-Path $evidence ($Name+'.UBE')
    [IO.File]::WriteAllText($project,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nSource = `"$Name.bas`"`r`n",$encoding)
    $output=Join-Path $evidence ($Name+'.ll')
    [IO.File]::WriteAllText($output,'SENTINEL',$encoding)
    $stdout=Join-Path $evidence ($Name+'.stdout')
    $stderr=Join-Path $evidence ($Name+'.stderr')
    $process=Start-Process -FilePath $CompilerExe -ArgumentList @('--emit-llvm',('"'+$project+'"'),('"'+$output+'"')) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    try {
        $null=$process.Handle
        if(-not $process.WaitForExit(60000)){$process.Kill();throw "Deadline: $Name"}
        $process.Refresh()
        if($null -eq $process.ExitCode){throw "Missing exit code: $Name"}
        $log=[IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr)
        if($process.ExitCode -eq 0 -or $log -notmatch $Expected -or [IO.File]::ReadAllText($output) -cne 'SENTINEL'){throw "Unexpected result: $Name $log"}
        Write-Output "PASS $Name : $($log.Trim())"
    } finally {$process.Dispose()}
}
# A fixed numeric control variable must be rejected: array enumeration requires Variant.
# Bootstrap may reject the whole enumeration dependency before enforcing that type rule.
Check 'each-next' "For Each Item In Values`r`nExit Loop`r`nNext Item" 'E_TYPE'
Check 'each-next-list' "For Each Item In Values`r`nFor Index = 0 To 1`r`nExit For`r`nNext Index, Item" 'E_TYPE'
Check 'each-mixed' "Do`r`nWhile True`r`nFor Index = 0 To 1`r`nFor Each Item In Values`r`nExit Loop`r`nNext Item, Index`r`nWend`r`nLoop" 'E_TYPE'
Check 'each-missing-in' "For Each Item Values`r`nNext Item" 'E_SYNTAX'
Check 'each-missing-source' "For Each Item In`r`nNext Item" 'E_SYNTAX'
Check 'each-missing-next' "For Each Item In Values`r`nExit For" 'E_SYNTAX'
