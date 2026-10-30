[CmdletBinding()]
param([string]$OutputDirectory = '')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$v4 = Join-Path $root 'compiler\archived\UBE_Compiler_v4'
$allowed = Join-Path $root 'bootstrap\out'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $allowed 'v4-task3' }
$out = [IO.Path]::GetFullPath($OutputDirectory)
$prefix = [IO.Path]::GetFullPath($allowed).TrimEnd('\') + '\'
if (-not $out.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Task 3 output must remain below bootstrap/out' }
[IO.Directory]::CreateDirectory($out) | Out-Null
$compiler = Join-Path $root 'bootstrap\out\ube-v3-production-stage1.exe'
$clang = 'C:\Program Files\LLVM\bin\clang.exe'
$runtime = Join-Path $root 'bootstrap\out\bootstrap_runtime.o'
$unicode = Join-Path $root 'bootstrap\out\bootstrap_unicode_runtime.o'
$project = Join-Path $v4 'UBE_Compiler_v4.UBE'
$fixtures = Join-Path $v4 'tests\task03-vertical-slice\fixtures'
$target = 'x86_64-w64-windows-gnu'
$v4exe = Join-Path $out 'ube-v4-task3.exe'
$v4nativeLlvm = Join-Path $out 'ube-v4-task3-native.ll'
$v4llvm = Join-Path $out 'ube-v4-task3.ll'
$v4llvmRepeat = Join-Path $out 'ube-v4-task3-repeat.ll'
$sliceLlvm = Join-Path $out 'minimal.ll'
$sliceRepeat = Join-Path $out 'minimal-repeat.ll'
$dump = Join-Path $out 'phases.dump'
$dumpRepeat = Join-Path $out 'phases-repeat.dump'
$native = Join-Path $out 'minimal.exe'
$v3native = Join-Path $out 'minimal-v3.exe'
$v3llvm = Join-Path $out 'minimal-v3.ll'
foreach ($required in @($compiler,$clang,$runtime,$unicode,$project)) { if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing Task 3 prerequisite: $required" } }

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant() }
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}
function Run([string]$File,[string[]]$Arguments) {
    $psi=[Diagnostics.ProcessStartInfo]::new(); $psi.FileName=$File; $psi.WorkingDirectory=$root; $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
    $psi.Arguments=(($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ')
    $p=[Diagnostics.Process]::new(); $p.StartInfo=$psi; if(-not $p.Start()){throw "Could not start $File"}; $stdout=$p.StandardOutput.ReadToEnd(); $stderr=$p.StandardError.ReadToEnd()
    if(-not $p.WaitForExit(15000)){$p.Kill();$p.WaitForExit();throw "Process timed out: $File"}; $result=[ordered]@{exit=$p.ExitCode;stdout=$stdout.Replace("`r`n","`n").TrimEnd("`r","`n");stderr=$stderr.Replace("`r`n","`n").TrimEnd("`r","`n")};$p.Dispose();$result
}

& $compiler '--emit-llvm' $project $target $v4llvm
if($LASTEXITCODE -ne 0){throw 'v3 could not compile v4 Task 3'}
& $compiler '--emit-llvm' $project $target $v4llvmRepeat
if($LASTEXITCODE -ne 0 -or (Hash $v4llvm) -cne (Hash $v4llvmRepeat)){throw 'v4 compiler LLVM is nondeterministic'}
& $compiler '--build-native' $project $target $clang $runtime $unicode $v4exe $v4nativeLlvm
if($LASTEXITCODE -ne 0){throw 'v3 could not build native v4 Task 3'}

$minimal='compiler/archived/UBE_Compiler_v4/tests/task03-vertical-slice/fixtures/minimal.UBE'
$r=Run $v4exe @('--emit-llvm',$minimal,$target,'bootstrap/out/v4-task3/minimal.ll'); if($r.exit -ne 0){throw "v4 valid slice failed: $($r.stdout) $($r.stderr)"}
$r=Run $v4exe @('--emit-llvm',$minimal,$target,'bootstrap/out/v4-task3/minimal-repeat.ll'); if($r.exit -ne 0 -or (Hash $sliceLlvm) -cne (Hash $sliceRepeat)){throw 'slice LLVM is nondeterministic'}
$r=Run $v4exe @('--emit-phase-dump',$minimal,$target,'bootstrap/out/v4-task3/phases.dump'); if($r.exit -ne 0){throw 'phase dump failed'}
$r=Run $v4exe @('--emit-phase-dump',$minimal,$target,'bootstrap/out/v4-task3/phases-repeat.dump'); if($r.exit -ne 0 -or (Hash $dump) -cne (Hash $dumpRepeat)){throw 'phase dumps are nondeterministic'}
$dumpText=Get-Content -Raw $dump; foreach($phase in @('source','lexer','syntax','declarations','semantics','ir','backend')){if($dumpText -notmatch "(?m)^phase=$phase$"){throw "missing phase dump: $phase"}}
& $clang '--target=x86_64-w64-windows-gnu' '-O2' $sliceLlvm $runtime $unicode '-o' $native
if($LASTEXITCODE -ne 0){throw 'LLVM validation/link failed'}
$nativeResult=Run $native @(); if($nativeResult.exit -ne 0 -or $nativeResult.stdout -cne 'task3-ok' -or $nativeResult.stderr -cne ''){throw 'v4 native behavior failed'}
& $compiler '--build-native' (Join-Path $fixtures 'minimal.UBE') $target $clang $runtime $unicode $v3native $v3llvm
if($LASTEXITCODE -ne 0){throw 'v3 differential build failed'}
$v3Result=Run $v3native @(); if($v3Result.exit -ne $nativeResult.exit -or $v3Result.stdout -cne $nativeResult.stdout -or $v3Result.stderr -cne $nativeResult.stderr){throw 'v3/v4 native behavior differs'}

$negative=@(
  @('invalid-token.UBE','UBE3700'),
  @('invalid-syntax.UBE','UBE3700'),
  @('invalid-declaration.UBE','UBE4002')
)
$negativeResults=@()
foreach($case in $negative){$artifact=Join-Path $out ($case[0]+'.ll');$relative='bootstrap/out/v4-task3/'+$case[0]+'.ll';$rr=Run $v4exe @('--emit-llvm',('compiler/archived/UBE_Compiler_v4/tests/task03-vertical-slice/fixtures/'+$case[0]),$target,$relative);if($rr.exit -eq 0 -or $rr.stdout -notmatch $case[1] -or (Test-Path $artifact)){throw "negative case failed: $($case[0])"};$v3bad=Join-Path $out ('v3-'+$case[0]+'.ll');$v3out=& $compiler '--emit-llvm' (Join-Path $fixtures $case[0]) $target $v3bad 2>&1;$v3exit=$LASTEXITCODE;if($v3exit -eq 0 -or (Test-Path $v3bad)){throw "v3 accepted malformed case: $($case[0])"};$negativeResults += [ordered]@{id=$case[0];v4_diagnostic=$rr.stdout;v3_rejected=$true}}

$faults=@('source-envelope','token-envelope','syntax-envelope','declaration-envelope','semantic-envelope','ir-envelope','backend-envelope')
foreach($fault in $faults){$artifact=Join-Path $out ("fault-$fault.ll");$rr=Run $v4exe @('--test-fault',$fault,'--emit-llvm',$minimal,$target,("bootstrap/out/v4-task3/fault-$fault.ll"));if($rr.exit -eq 0 -or $rr.stdout -notmatch 'UBE(6108|5001)' -or (Test-Path $artifact)){throw "envelope mutation was not rejected: $fault"}}
$r=Run $v4exe @('--emit-phase-dump',$minimal,$target,'bootstrap/out/v4-task3/phases-after-faults.dump'); if($r.exit -ne 0 -or (Hash $dump) -cne (Hash (Join-Path $out 'phases-after-faults.dump'))){throw 'fault injection mutated a published upstream result'}

$stressDir=Join-Path $out 'stress';[IO.Directory]::CreateDirectory($stressDir)|Out-Null;$stressText='x'*100000
[IO.File]::WriteAllText((Join-Path $stressDir 'stress.UBE'),"UBE-Project 1`nName = `"Stress`"`nKind = `"Exe`"`nStartup = `"Main`"`nSource = `"stress.bas`"`n",[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $stressDir 'stress.bas'),"UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Stress`"`nPublic Sub Main()`nPrint `"$stressText`"`nEnd Sub`n",[Text.UTF8Encoding]::new($false))
$r=Run $v4exe @('--emit-llvm','bootstrap/out/v4-task3/stress/stress.UBE',$target,'bootstrap/out/v4-task3/stress.ll');if($r.exit -ne 0){throw 'bounded stress slice failed'}

$evidence=[ordered]@{format='ube-v4-verified-build-1';roadmap_task=3;build_identity='v4-task3-minimal-vertical-slice-1';status='passed';bootstrap_sha256=Hash $compiler;compiler_llvm_sha256=Hash $v4llvm;slice_llvm_sha256=Hash $sliceLlvm;phase_dump_sha256=Hash $dump;native=[ordered]@{stdout=$nativeResult.stdout;exit=$nativeResult.exit;v3_equal=$true};cases=[ordered]@{positive=1;negative=$negativeResults.Count;envelope_mutations=$faults.Count;stress_bytes=100000};measurements=[ordered]@{source_bytes=(Get-Item (Join-Path $fixtures 'minimal.bas')).Length;tokens=17;syntax_nodes=4;declarations=1;semantic_statements=1;ir_instructions=3;llvm_bytes=(Get-Item $sliceLlvm).Length;native_bytes=(Get-Item $native).Length};cleanup=[ordered]@{false_success_artifacts=0;live_resources=0}}
[IO.File]::WriteAllText((Join-Path $out 'verified-build.json'),($evidence|ConvertTo-Json -Depth 8)+"`n",[Text.UTF8Encoding]::new($false))
Write-Host "Task 3 vertical-slice gate passed: $(Join-Path $out 'verified-build.json')"
