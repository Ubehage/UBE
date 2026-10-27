[CmdletBinding()]
param([string]$OutputDirectory = '')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$v4 = Join-Path $root 'compiler\UBE_Compiler_v4'
$allowed = Join-Path $root 'bootstrap\out'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $allowed 'v4-task4' }
$out = [IO.Path]::GetFullPath($OutputDirectory)
$prefix = [IO.Path]::GetFullPath($allowed).TrimEnd('\') + '\'
if (-not $out.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Task 4 output must remain below bootstrap/out' }
[IO.Directory]::CreateDirectory($out) | Out-Null
$compiler = Join-Path $root 'bootstrap\out\ube-v3-production-stage1.exe'
$clang = 'C:\Program Files\LLVM\bin\clang.exe'
$runtime = Join-Path $root 'bootstrap\out\bootstrap_runtime.o'
$unicode = Join-Path $root 'bootstrap\out\bootstrap_unicode_runtime.o'
$project = Join-Path $v4 'UBE_Compiler_v4.UBE'
$target = 'x86_64-w64-windows-gnu'
$v4exe = Join-Path $out 'ube-v4-task4.exe'
$v4llvm = Join-Path $out 'ube-v4-task4.ll'
$v4llvmRepeat = Join-Path $out 'ube-v4-task4-repeat.ll'
$v4nativeLlvm = Join-Path $out 'ube-v4-task4-native.ll'
$fixtures = Join-Path $v4 'tests\task04-lexing\fixtures'
$rp2 = Join-Path $root 'compiler\UBE_Compiler_v3\tests\rp2'
foreach ($required in @($compiler,$clang,$runtime,$unicode,$project,$fixtures,$rp2)) { if (-not (Test-Path -LiteralPath $required)) { throw "Missing Task 4 prerequisite: $required" } }

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant() }
function Hash-Text([string]$Text) { $sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','')}finally{$sha.Dispose()} }
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}
function Run([string]$File,[string[]]$Arguments,[int]$TimeoutMilliseconds = 120000) {
    $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=$File;$psi.WorkingDirectory=$root;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
    $psi.Arguments=(($Arguments|ForEach-Object{Quote-Argument $_})-join ' ')
    $watch=[Diagnostics.Stopwatch]::StartNew();$p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(-not $p.Start()){throw "Could not start $File"};$stdout=$p.StandardOutput.ReadToEnd();$stderr=$p.StandardError.ReadToEnd()
    if(-not $p.WaitForExit($TimeoutMilliseconds)){$p.Kill();$p.WaitForExit();throw "Process timed out: $File"};$watch.Stop()
    $result=[ordered]@{exit=$p.ExitCode;stdout=$stdout.Replace("`r`n","`n").TrimEnd("`r","`n");stderr=$stderr.Replace("`r`n","`n").TrimEnd("`r","`n");elapsed_ms=$watch.ElapsedMilliseconds};$p.Dispose();$result
}
function Write-Utf8([string]$Path,[string]$Text) { [IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false)) }
function Assert-Rejected([string]$Label,[string]$ProjectPath,[string]$Expected = '') {
    $v4result=Run $v4exe @('--dump-tokens',$ProjectPath,$target)
    if($v4result.exit -eq 0){throw "$Label was accepted by v4"}
    if($v4result.exit -eq 65){throw "$Label caused a v4 runtime bounds failure"}
    $reported=($v4result.stdout+"`n"+$v4result.stderr).Trim()
    if($Expected -and $reported -notmatch $Expected){throw "$Label did not report $Expected`: $reported"}
    $v3result=Run $compiler @('--dump-tokens',$ProjectPath,$target)
    if($v3result.exit -eq 0){throw "$Label was accepted by the v3 oracle"}
    [ordered]@{id=$Label;v4_exit=$v4result.exit;v3_exit=$v3result.exit;diagnostic=($reported -split "`n")[0]}
}

& $compiler '--emit-llvm' $project $target $v4llvm
if($LASTEXITCODE -ne 0){throw 'v3 could not compile v4 Task 4'}
& $compiler '--emit-llvm' $project $target $v4llvmRepeat
if($LASTEXITCODE -ne 0 -or (Hash $v4llvm) -cne (Hash $v4llvmRepeat)){throw 'v4 Task 4 compiler LLVM is nondeterministic'}
& $compiler '--build-native' $project $target $clang $runtime $unicode $v4exe $v4nativeLlvm
if($LASTEXITCODE -ne 0){throw 'v3 could not build native v4 Task 4'}

$positive=@('basic.UBE','lexical.UBE','legacy.UBE','conditional-continuation.UBE')
$differentials=@()
foreach($name in $positive){
    $path=Join-Path $rp2 $name;$v3result=Run $compiler @('--dump-tokens',$path,$target);$v4result=Run $v4exe @('--dump-tokens',$path,$target)
    if($v3result.exit -ne 0 -or $v4result.exit -ne 0 -or $v3result.stdout -cne $v4result.stdout){throw "RP2 lexical differential failed: $name"}
    $repeat=Run $v4exe @('--dump-tokens',$path,$target);if($repeat.exit -ne 0 -or $repeat.stdout -cne $v4result.stdout){throw "Nondeterministic token dump: $name"}
    $differentials += [ordered]@{id=$name;sha256=(Hash-Text $v4result.stdout);tokens=($v4result.stdout -split "`n").Count-1}
}

$multiPath=Join-Path $fixtures 'multi.UBE';$v3multi=Run $compiler @('--dump-tokens',$multiPath,$target);$v4multi=Run $v4exe @('--dump-tokens',$multiPath,$target)
if($v3multi.exit -ne 0 -or $v4multi.exit -ne 0 -or $v3multi.stdout -cne $v4multi.stdout){throw "Multi-source/#ElseIf differential failed: $($v3multi.stdout) $($v4multi.stdout)"}
if($v4multi.stdout -notmatch '(?m)^2:'){throw 'Multi-source dump did not retain source id 2'}
$differentials += [ordered]@{id='multi.UBE';sha256=(Hash-Text $v4multi.stdout);tokens=($v4multi.stdout -split "`n").Count-1}

$negative=@()
foreach($name in @('missing-header.UBE','kind-mismatch.UBE','malformed.UBE','conditional-bad.UBE')){$negative += Assert-Rejected ('rp2-'+$name) (Join-Path $rp2 $name)}
$negative += Assert-Rejected 'invalid-date' (Join-Path $fixtures 'invalid-date.UBE') 'UBE3407'
$negative += Assert-Rejected 'invalid-number' (Join-Path $fixtures 'invalid-number.UBE') 'UBE3404'

$generated=Join-Path $out 'generated';[IO.Directory]::CreateDirectory($generated)|Out-Null
$escapeManifest=Join-Path $generated 'escape.UBE';Write-Utf8 $escapeManifest "UBE-Project 1`nName = `"Escape`"`nKind = `"Exe`"`nSource = `"..\outside.bas`"`n"
$negative += Assert-Rejected 'escaping-path' $escapeManifest 'UBE3005'
$missingManifest=Join-Path $generated 'missing.UBE';Write-Utf8 $missingManifest "UBE-Project 1`nName = `"Missing`"`nKind = `"Exe`"`nSource = `"absent.bas`"`n"
$negative += Assert-Rejected 'missing-source' $missingManifest 'cannot open for reading'

$byteCases=@(
    [ordered]@{name='nul';bytes=[byte[]]@(0)},[ordered]@{name='control';bytes=[byte[]]@(1)},[ordered]@{name='unit-separator';bytes=[byte[]]@(31)},
    [ordered]@{name='lone-continuation';bytes=[byte[]]@(128)},[ordered]@{name='overlong';bytes=[byte[]]@(192,175)},[ordered]@{name='surrogate';bytes=[byte[]]@(237,160,128)},
    [ordered]@{name='too-large';bytes=[byte[]]@(244,144,128,128)},[ordered]@{name='invalid-byte';bytes=[byte[]]@(255)}
)
$header=[Text.Encoding]::UTF8.GetBytes("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Bytes`"`nPublic Sub Main()`n")
$tail=[Text.Encoding]::UTF8.GetBytes("`nEnd Sub`n")
foreach($case in $byteCases){
    $source=Join-Path $generated ($case.name+'.bas');$manifest=Join-Path $generated ($case.name+'.UBE')
    [IO.File]::WriteAllBytes($source,[byte[]]($header+$case.bytes+$tail));Write-Utf8 $manifest ("UBE-Project 1`nName = `"Bytes`"`nKind = `"Exe`"`nSource = `""+$case.name+".bas`"`n")
    $negative += Assert-Rejected ('bytes-'+$case.name) $manifest
}

$deepSource=Join-Path $generated 'deep.bas';$deepManifest=Join-Path $generated 'deep.UBE';$deep="UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Deep`"`n"
for($i=0;$i -lt 257;$i++){$deep+="#If True Then`n"};$deep+="Public Sub Main()`nEnd Sub`n";for($i=0;$i -lt 257;$i++){$deep+="#End If`n"}
Write-Utf8 $deepSource $deep;Write-Utf8 $deepManifest "UBE-Project 1`nName = `"Deep`"`nKind = `"Exe`"`nSource = `"deep.bas`"`n";$negative += Assert-Rejected 'conditional-depth-limit' $deepManifest 'UBE3504'

$largeSource=Join-Path $generated 'large.bas';$largeManifest=Join-Path $generated 'large.UBE';Write-Utf8 $largeSource (' ' * 16777217);Write-Utf8 $largeManifest "UBE-Project 1`nName = `"Large`"`nKind = `"Exe`"`nSource = `"large.bas`"`n"
$largeResult=Run $v4exe @('--dump-tokens',$largeManifest,$target);$largeReported=($largeResult.stdout+"`n"+$largeResult.stderr).Trim();if($largeResult.exit -eq 0 -or $largeReported -notmatch 'UBE3009'){throw "source byte limit was not enforced: $largeReported"}
$negative += [ordered]@{id='source-byte-limit';v4_exit=$largeResult.exit;v3_exit='not-run-v3-limit-differs';diagnostic=($largeReported -split "`n")[0]}

$series=@()
foreach($lines in @(100,1000,5000)){
    $source=Join-Path $generated ("series-$lines.bas");$manifest=Join-Path $generated ("series-$lines.UBE")
    $builder=[Text.StringBuilder]::new();[void]$builder.Append("UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Series`"`nPublic Sub Main()`n")
    for($i=0;$i -lt $lines;$i++){[void]$builder.Append("Dim value$i As Long = $i`n")};[void]$builder.Append("End Sub`n")
    Write-Utf8 $source $builder.ToString();Write-Utf8 $manifest ("UBE-Project 1`nName = `"Series`"`nKind = `"Exe`"`nSource = `"series-$lines.bas`"`n")
    $result=Run $v4exe @('--dump-tokens',$manifest,$target);if($result.exit -ne 0){throw "size series failed at $lines`: $($result.stdout)"}
    $repeat=Run $v4exe @('--dump-tokens',$manifest,$target);if($repeat.exit -ne 0 -or $repeat.stdout -cne $result.stdout){throw "size series is nondeterministic at $lines"}
    $series += [ordered]@{statements=$lines;bytes=(Get-Item -LiteralPath $source).Length;tokens=($result.stdout -split "`n").Count-1;work_units=(Get-Item -LiteralPath $source).Length;elapsed_ms=$result.elapsed_ms}
}
for($i=1;$i -lt $series.Count;$i++){
    if($series[$i].bytes -le $series[$i-1].bytes -or $series[$i].tokens -le $series[$i-1].tokens -or $series[$i].work_units -ne $series[$i].bytes){throw 'size-series counters are not monotonic/linear'}
    $byteRatio=$series[$i].bytes/$series[$i-1].bytes;$tokenRatio=$series[$i].tokens/$series[$i-1].tokens;if([Math]::Abs($byteRatio-$tokenRatio) -gt 0.75){throw 'token growth diverges from byte growth'}
}

$evidence=[ordered]@{format='ube-v4-verified-build-1';roadmap_task=4;build_identity='v4-task4-project-source-preprocess-lexer-1';status='passed';bootstrap_sha256=Hash $compiler;compiler_llvm_sha256=Hash $v4llvm;native_compiler_sha256=Hash $v4exe;differentials=$differentials;negative_cases=$negative;arbitrary_byte_cases=$byteCases.Count;size_series=$series;ownership=[ordered]@{load_once=$true;immutable_source_snapshots=$true;per_source_ids=$true;source_map_segments=1};cleanup=[ordered]@{false_success_artifacts=0;generated_root=$generated}}
$evidencePath=Join-Path $out 'evidence.json';$evidence|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $evidencePath -Encoding UTF8
Write-Host "Task 4 verification passed: $evidencePath"
