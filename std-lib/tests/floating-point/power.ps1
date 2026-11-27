# Runs the independently generated exact algebraic oracle against ordinary UBE power.
param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$utf8=New-Object Text.UTF8Encoding($false,$true)
$artifacts=Join-Path ([IO.Path]::GetTempPath()) ('ube floating power '+[guid]::NewGuid())
$null=New-Item -ItemType Directory $artifacts;Write-Output "Evidence: $artifacts"
$oracle=Join-Path $artifacts 'oracle.json'
& (Join-Path $PSScriptRoot 'power-oracle.ps1') -Destination $oracle
$fixtures=Get-Content -LiteralPath $oracle -Raw | ConvertFrom-Json
$integerOracle=Join-Path $artifacts 'integer-oracle.json'
& (Join-Path $PSScriptRoot 'power-integer-oracle.ps1') -Destination $integerOracle
$fixtures+=Get-Content -LiteralPath $integerOracle -Raw | ConvertFrom-Json
$script:sequence=0
function Run([string]$File,[string[]]$Arguments,[int]$Expected=0){
 $script:sequence++;$prefix=Join-Path $artifacts ('process-'+$script:sequence)
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=($prefix+'.stdout');RedirectStandardError=($prefix+'.stderr')}
 if($Arguments.Count){$options.ArgumentList=(($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' ')}
 $timer=[Diagnostics.Stopwatch]::StartNew();$p=Start-Process @options
 try{$handle=$p.Handle;while(-not $p.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 600){$p.Kill();throw "Deadline: $prefix"}};$p.Refresh();$err=[IO.File]::ReadAllText($prefix+'.stderr');if($p.ExitCode -ne $Expected -or $err){throw "Exit $($p.ExitCode), expected $Expected`: $err Evidence $prefix"}}finally{$p.Dispose()}
 $timer.Stop();return $timer.Elapsed.TotalSeconds
}
$lines=New-Object 'Collections.Generic.List[string]'
$lines.Add(@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private Function Check(ByVal BaseBits As LongLong, ByVal PowerBits As LongLong, ByVal Expected As LongLong, ByVal Failure As Long) As Boolean
    Dim Value As LongLong = 42
    Dim Status As Boolean
    On Error GoTo Failed
    Status = FilePrimitives.SetError(57)
    Status = BinaryFloatPower.TryPower(BaseBits, PowerBits, Value)
    If Failure <> 0 Then
        Check = Not Status And Value = 42 And Err.Number = Failure
    Else
        Check = Status And Value = Expected And Err.Number = 57
    End If
    Exit Function
Failed:
    Check = False
End Function
Private Function EvaluateCases() As Boolean
    Dim Value As LongLong = 23
    Dim Status As Boolean
    On Error GoTo Failed
    Status = FilePrimitives.SetError(57)
    Value = BinaryFloatPower.Evaluate(4611686018427387904^, 4613937818241073152^)
    If Value <> 4620693217682128896^ Or Err.Number <> 57 Then Exit Function
    Value = 23
    Value = BinaryFloatPower.Evaluate(0, -4616189618054758400^)
    Exit Function
Failed:
    EvaluateCases = Value = 23 And Err.Number = 5
End Function
Public Function Main() As Long
    If Not EvaluateCases() Then Main = 250: Exit Function
'@)
$cases=0
foreach($f in $fixtures){$cases++;$lines.Add("If Not Check($($f.BaseBits)^, $($f.PowerBits)^, $($f.ExpectedBits)^, $($f.Error)) Then Main = $cases`: Exit Function")}
$extras=@(
 @('0','0','4607182418800017408',0),
 @('0','-4616189618054758400','42',5),
 @('-9223372036854775808','-4616189618054758400','42',5),
 @('-9223372036854775808','4613937818241073152','-9223372036854775808',0),
 @('-9223372036854775808','4602678819172646912','0',0),
 @('-4611686018427387904','4602678819172646912','42',5),
 @('-4611686018427387904','4613937818241073152','-4602678819172646912',0),
 @('-4611686018427387904','-4609434218613702656','-4629700416936869888',0),
 @('9218868437227405312','0','42',6),
 @('4607182418800017408','9221120237041090560','42',6),
 @('4607182418800017408','4841369599423283200','4607182418800017408',0),
 @('4611686018427387904','4841369599423283200','42',6),
 @('4602678819172646912','4841369599423283200','0',0)
)
foreach($f in $extras){$cases++;$lines.Add("If Not Check($($f[0])^, $($f[1])^, $($f[2])^, $($f[3])) Then Main = $cases`: Exit Function")}
$lines.Add('End Function')
$source=Join-Path $artifacts 'Probe.bas';[IO.File]::WriteAllText($source,($lines -join "`r`n")+"`r`n",$utf8)
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'));$modules=@('BinaryFloatPower','BinaryFloatValues','BufferPrimitives','FilePrimitives')
foreach($name in $modules){Copy-Item -LiteralPath (Join-Path $repo "std-lib/src/portable/$name.bas") -Destination $artifacts}
foreach($level in @('0','2')){
 $manifest=Join-Path $artifacts ('Project'+$level+'.UBE');$text="UBE-Project 1`r`nName = `"FloatingPowerTest`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`n"
 foreach($name in ($modules+@('Probe'))){$text+="Source = `"$name.bas`"`r`n"};[IO.File]::WriteAllText($manifest,$text,$utf8)
 $exe=Join-Path $artifacts ('Probe'+$level+'.exe');$build=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);$run=Run $exe @()
 Write-Output "PASS O$level $cases exact powers/domain checks, output preservation/staleErr; build $build sec; execution $run sec"
 $original=[IO.File]::ReadAllText($source,$utf8);$changed=$original.Replace('Value = Expected And Err.Number = 57','Value = Expected + 1 And Err.Number = 57')
 if($original -ceq $changed){throw 'Missing negative control marker'};[IO.File]::WriteAllText($source,$changed,$utf8)
 $exe=Join-Path $artifacts ('Negative'+$level+'.exe');$null=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);$null=Run $exe @() 1
 [IO.File]::WriteAllText($source,$original,$utf8);Write-Output "PASS O$level changed-oracle negative control"
}
$powerSource=Join-Path $artifacts 'BinaryFloatPower.bas'
$powerOriginal=[IO.File]::ReadAllText($powerSource,$utf8)
$powerRetry=$powerOriginal.Replace('Dim FractionBytes As Long = 8','Dim FractionBytes As Long = 7')
$powerRetry=$powerRetry.Replace('Attribute UBE_Name = "BinaryFloatPower"','Attribute UBE_Name = "BinaryFloatPower"'+"`r`n"+'Public RetryCount As Long')
$powerRetry=$powerRetry.Replace('FractionBytes = FractionBytes * 2','RetryCount = RetryCount + 1'+"`r`n"+'            FractionBytes = FractionBytes * 2')
if($powerRetry -ceq $powerOriginal){throw 'Missing refinement control marker'}
[IO.File]::WriteAllText($powerSource,$powerRetry,$utf8)
$probeRetry=$original.Insert($original.LastIndexOf('End Function'),'If BinaryFloatPower.RetryCount = 0 Then Main = 249: Exit Function'+"`r`n")
[IO.File]::WriteAllText($source,$probeRetry,$utf8)
$exe=Join-Path $artifacts 'Refinement.exe';$null=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);$refineTime=Run $exe @()
Write-Output "PASS O2 lower-start-precision refinement control, all $cases exact fixtures, retries asserted; $refineTime sec"
$allocationCall='BufferPrimitives.TryResizeBytes(A, Count, False)'
if(([regex]::Matches($powerOriginal,[regex]::Escape($allocationCall))).Count -ne 1){throw 'Expected one power workspace allocation site'}
$resourcePower=$powerOriginal.Replace($allocationCall,'ResourceResize(A, Count, False)')
$resourcePower=$resourcePower.Replace('Attribute UBE_Name = "BinaryFloatPower"','Attribute UBE_Name = "BinaryFloatPower"'+"`r`n"+'Public AllocationFailures As Long')
# Test-only failure at the real workspace call site, independent of machine RAM or former quotas.
$resourcePower+=@'

Private Function ResourceResize(ByRef A() As Byte, ByVal Count As Long, ByVal Preserve As Boolean) As Boolean
    If AllocationFailures = 0 Then
        AllocationFailures = 1
        ResourceResize = FilePrimitives.SetError(7)
        Exit Function
    End If
    ResourceResize = BufferPrimitives.TryResizeBytes(A, Count, Preserve)
End Function
'@
[IO.File]::WriteAllText($powerSource,$resourcePower,$utf8)
$resourceProbe=@'
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Public Function Main() As Long
    Dim Value As LongLong = 42
    Dim Status As Boolean = True
    On Error GoTo FirstFailure
    Status = BinaryFloatPower.TryPower(4611686018427387904^, 4602678819172646912^, Value)
    Main = 1
    Exit Function
FirstFailure:
    If Not Status Or Value <> 42 Or Err.Number <> 7 Or BinaryFloatPower.AllocationFailures <> 1 Then Main = 4: Exit Function
    On Error GoTo 0
    On Error GoTo Failed
    Status = BinaryFloatPower.TryPower(4611686018427387904^, 4602678819172646912^, Value)
    If Not Status Or Value <> 4609047870845172685^ Or Err.Number <> 7 Then Main = 2: Exit Function
    Exit Function
Failed:
    Main = 3
End Function
'@
[IO.File]::WriteAllText($source,$resourceProbe,$utf8)
foreach($level in @('0','2')){
 $manifest=Join-Path $artifacts ('Project'+$level+'.UBE')
 $exe=Join-Path $artifacts ('ResourceFailure'+$level+'.exe');$null=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang);$null=Run $exe @()
 Write-Output "PASS O$level injected workspace allocation failure reports Err7, preserves destination and recovers with sticky Err"
}
