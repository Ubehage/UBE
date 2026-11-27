param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube conditional scanner '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$encoding=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $stdout=Join-Path $evidence ($Name+'.stdout');$stderr=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr;WorkingDirectory=$evidence}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(120000)){$p.Kill();throw "Deadline $Name"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing exit code $Name"};return [pscustomobject]@{Code=$p.ExitCode;ErrorText=[IO.File]::ReadAllText($stderr);Log=([IO.File]::ReadAllText($stdout)+[IO.File]::ReadAllText($stderr))}}finally{$p.Dispose()}
}
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
Copy-Item -LiteralPath (Join-Path $root 'compiler/src/SourceScanner.bas') -Destination $evidence
Copy-Item -LiteralPath (Join-Path $root 'std-lib/src/portable/FileBytes.bas') -Destination $evidence
foreach($module in @('BufferPrimitives','FilePrimitives','Utf8')){Copy-Item -LiteralPath (Join-Path $root ('std-lib/src/portable/'+$module+'.bas')) -Destination $evidence}
$opaque='"unterminated '+[char]0x00e9+[char]::ConvertFromUtf32(0x1f642)+"`r`n  Asm ' open`r`n#End If _ ' raw`r`n"+'"End Asm"'+"`r`n End Asm Rem close`r`nValue"
$prefix=$opaque.Substring(0,$opaque.LastIndexOf('Value'))
$fixture=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'scanner-probe.bas')).Replace('EXPECT_BYTE',[string]$encoding.GetByteCount($prefix)).Replace('EXPECT_UTF16',[string]($prefix.Length+1))
$cases=@(
 [pscustomobject]@{Mode=1;Bytes=$encoding.GetBytes("Value = 1 _ ' comment`r`n + 2`r`nRem ignored`r`nText = `"a'_`"`"b`"`r`nIf True Then Rem comment _`r`nThing.Rem _`r`n (1)`r`nLast")},
 [pscustomobject]@{Mode=2;Bytes=$encoding.GetBytes($opaque)},
 [pscustomobject]@{Mode=3;Bytes=$encoding.GetBytes("#If 1# + _ ' comment`n  2 Then")},
 [pscustomobject]@{Mode=4;Bytes=$encoding.GetBytes("Value`n")},
 [pscustomobject]@{Mode=5;Bytes=[byte[]]@(192,128)},
 [pscustomobject]@{Mode=6;Bytes=$encoding.GetBytes("  Asm`n#Else`n")},
 [pscustomobject]@{Mode=7;Bytes=$encoding.GetBytes('"'+[char]0x00e9+'"')}
)
$range=$encoding.GetString($cases[2].Bytes)
$fixture=$fixture.Replace('ByteStart <> 21','ByteStart <> '+$range.IndexOf('2 Then'))
foreach($level in @('0','2')){foreach($control in @(0,1,2)){
 $name="scanner-o$level-control$control"
 $source=$fixture
 $runCases=$cases
 $expected=0
 if($control -eq 1){$source=$fixture.Replace('Private Const Control As Long = 0','Private Const Control As Long = 1');$expected=90}
 if($control -eq 2){$source=$fixture.Replace('    AllSelected = True',"    UnexpectedFailure`r`n    AllSelected = True");$runCases=@($cases[0]);$expected=90}
 [IO.File]::WriteAllText((Join-Path $evidence 'Probe.bas'),$source,$encoding)
 $project=Join-Path $evidence ($name+'.UBE')
 [IO.File]::WriteAllText($project,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nOptimization = `"$level`"`r`nSource = `"Probe.bas`"`r`nSource = `"SourceScanner.bas`"`r`nSource = `"FileBytes.bas`"`r`nSource = `"BufferPrimitives.bas`"`r`nSource = `"FilePrimitives.bas`"`r`nSource = `"Utf8.bas`"`r`n",$encoding)
 $exe=Join-Path $evidence ($name+'.exe')
 $r=Run $CompilerExe @('--build',$project,$exe,'--clang',$Clang) ($name+'-build')
 if($r.Code -ne 0 -or $r.Log -notmatch 'BUILD OK'){throw "Build failed $name $($r.Log)"}
 foreach($case in $runCases){
  [IO.File]::WriteAllBytes((Join-Path $evidence 'input.bin'),([byte[]]@($case.Mode)+$case.Bytes))
  $r=Run $exe @() ($name+'-case'+$case.Mode)
  if($r.Code -ne $expected -or $r.ErrorText.Length -ne 0){throw "Assertion failed $name case$($case.Mode) expected $expected got $($r.Code): $($r.Log)"}
  Write-Output "PASS $name case$($case.Mode) exit=$($r.Code)"
 }
}}
