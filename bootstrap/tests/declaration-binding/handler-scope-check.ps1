# Verifies invocation-local handler modes and active state independently of sticky Err.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube handler scopes ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $artifacts -Force
$script:processNumber = 0
$BootstrapExe = [IO.Path]::GetFullPath($BootstrapExe)

# Stops on a failed independently authored acceptance assertion.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Writes deterministic UTF-8 source and IR, never the host's default text encoding.
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

# Quotes literal Windows command-line arguments including quotes and trailing backslashes.
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

# Retains a hidden child handle, bounds execution and saves each fresh process observation.
function Invoke-BoundedProcess([string]$File, [string[]]$Arguments) {
    $script:processNumber++
    $prefix = Join-Path $artifacts ('process-' + $script:processNumber)
    $start = @{ FilePath=$File; WorkingDirectory=$artifacts; WindowStyle='Hidden'; PassThru=$true; RedirectStandardOutput=($prefix + '.stdout'); RedirectStandardError=($prefix + '.stderr') }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @start
    try {
        $handle = $process.Handle
        if (-not $process.WaitForExit(30000)) { $process.Kill(); $null = $process.WaitForExit(5000); throw "Process timeout. Evidence: $prefix" }
        $process.Refresh()
        Require ($null -ne $process.ExitCode) "Missing exit code for retained handle $handle"
        return [pscustomobject]@{ ExitCode=$process.ExitCode; Stdout=[IO.File]::ReadAllText($prefix + '.stdout',$utf8); Stderr=[IO.File]::ReadAllText($prefix + '.stderr',$utf8); Evidence=$prefix }
    } finally { $process.Dispose() }
}

. (Join-Path $PSScriptRoot '../NativeMemory.ps1')

# Compiles the same emitted library plus observation harness and checks AMD64 PE framing.
function Build-Harness([string]$IR, [string]$Exe, [string]$Level) {
    $link = @(Get-NativeMemoryLinkArguments $IR $Clang $artifacts)
    $result = Invoke-BoundedProcess $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR) + $link + @('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608'))
    Require ($result.ExitCode -eq 0) "Harness compilation failed. Evidence: $($result.Evidence)"
    $bytes = [IO.File]::ReadAllBytes($Exe)
    Require ($bytes.Length -ge 64 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) 'Invalid native DOS header'
    $offset = [BitConverter]::ToInt32($bytes,0x3c)
    Require ($offset -ge 64 -and $offset -le $bytes.Length - 6) 'Invalid native PE offset'
    Require ([BitConverter]::ToUInt32($bytes,$offset) -eq 0x4550 -and [BitConverter]::ToUInt16($bytes,$offset+4) -eq 0x8664) 'Expected AMD64 PE executable'
}

Write-Output "Artifacts retained: $artifacts"
$source = Join-Path $PSScriptRoot 'HandlerScopeProbe.bas'
$destination = Join-Path $artifacts 'HandlerScopeProbe.bas'
Copy-Item -LiteralPath $source -Destination $destination
Require ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash) 'Copied handler probe changed'
$manifest = Join-Path $artifacts 'project.UBE'
Write-Text $manifest "UBE-Project 1`r`nName = `"HandlerScopes`"`r`nKind = `"Library`"`r`nSource = `"HandlerScopeProbe.bas`"`r`n"
$bound = Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0 -and $bound.Stderr.Length -eq 0 -and $bound.Stdout -match '(?m)^ANALYZE OK\r?$') "Binding failed. Evidence: $($bound.Evidence)"
$matches = @($bound.Stdout -split '\r?\n' | Where-Object { $_ -match '^SYMBOL [0-9]+\|function\|Run\|' })
Require ($matches.Count -eq 1) 'Expected exactly one Run declaration'
$symbol = ($matches[0] -split '\|')[0].Substring(7)
$ir = Join-Path $artifacts 'handler-scopes.ll'
$emitted = Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$manifest,$ir)
Require ($emitted.ExitCode -eq 0 -and $emitted.Stderr.Length -eq 0 -and $emitted.Stdout -match '(?m)^EMIT OK\r?$') "Emission failed. Evidence: $($emitted.Evidence)"
$harness = @'
@test.context = private global %ube.context zeroinitializer, align 8
@test.depth = global i64 3
define i32 @main() {
entry:
  call void @ube.context.init(ptr @test.context)
  %initialized = call i1 @ube.project.init(ptr @test.context)
  %depth = load volatile i64, ptr @test.depth
  %pair = call { i1, i64 } @ube.proc.PROBE(ptr @test.context, i64 %depth)
  %fresh = extractvalue { i1, i64 } %pair, 0
  %value = extractvalue { i1, i64 } %pair, 1
  %disposed = call i1 @ube.context.dispose(ptr @test.context)
  %ready = and i1 %initialized, %disposed
  %valid = and i1 %ready, %fresh
  %code = trunc i64 %value to i32
  %result = select i1 %valid, i32 %code, i32 254
  ret i32 %result
}
'@
$combinedText = [IO.File]::ReadAllText($ir,$utf8) + "`r`n" + $harness.Replace('@ube.proc.PROBE','@ube.proc.' + $symbol)
$combined = Join-Path $artifacts 'handler-scopes-with-harness.ll'
Write-Text $combined $combinedText
foreach ($level in @('O0','O2')) {
    $exe = Join-Path $artifacts ('handler-scopes-' + $level + '.exe')
    Build-Harness $combined $exe $level
    $result = Invoke-BoundedProcess $exe @()
    Require ($result.ExitCode -eq 0) "Handler scope assertion $($result.ExitCode) failed at $level. Evidence: $($result.Evidence)"
    Write-Output "PASS invocation-local handler observations at $level"
}
$negative = Join-Path $artifacts 'handler-scopes-negative.ll'
Write-Text $negative ($combinedText.Replace('@test.depth = global i64 3','@test.depth = global i64 2'))
$negativeExe = Join-Path $artifacts 'handler-scopes-negative.exe'
Build-Harness $negative $negativeExe 'O2'
$control = Invoke-BoundedProcess $negativeExe @()
Require ($control.ExitCode -eq 23) "Changed recursion depth must fail exact recursive result assertion23; got $($control.ExitCode). Evidence: $($control.Evidence)"
Write-Output 'PASS changed-runtime-depth control failed exact assertion23'
Write-Output 'PASS 3 native handler-scope groups'
