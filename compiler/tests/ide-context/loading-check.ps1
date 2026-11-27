param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube context loading '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
# Same retained-process/deadline discipline as the companion binding gate.
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $out=Join-Path $evidence ($Name+'.stdout');$err=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;WorkingDirectory=$evidence;RedirectStandardOutput=$out;RedirectStandardError=$err}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(180000)){$p.Kill();throw "Deadline $Name"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing exit code $Name"};return [pscustomobject]@{Code=$p.ExitCode;Log=([IO.File]::ReadAllText($out)+[IO.File]::ReadAllText($err))}}finally{$p.Dispose()}
}
$dependencies=@()
foreach($module in @('BufferPrimitives','FilePrimitives','FileBytes','PathPrimitives','ThreadPrimitives','ByteText','Utf8','InvariantNumbers','BinaryFloat','BinaryFloatValues','BinaryFloatMath','BinaryFloatPower','BinaryFloatText')){$dependencies+=Join-Path $root ('std-lib/src/portable/'+$module+'.bas')}
$dependencies+=Join-Path $root 'std-lib/src/win-lib/WindowsPaths.bas'
foreach($module in @('SourceScanner','SyntaxTokens','SourceParser','ProjectSyntax','ProjectManifest','ProjectLoader','ManagedSourceAssets','ConstantValues','ConstantText','ConditionalExpressions','ConditionalSource')){$dependencies+=Join-Path $root ('compiler/src/'+$module+'.bas')}
foreach($path in $dependencies){Copy-Item -LiteralPath $path -Destination $evidence}
$inputDirectory=Join-Path $evidence 'input'
$null=New-Item -ItemType Directory -Path $inputDirectory
$source="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"First`"`r`n' "+[char]0x00e9+[char]::ConvertFromUtf32(0x1f642)+"`r`n#If IS_IN_IDE Then`r`nPublic Const Selected As Long = 1`r`n#Else`r`nPublic Const Selected As Long = 0`r`n#End If`r`n"
$spoof="UBE SOURCE 1 MODULE`r`nAttribute UBE_Name = `"Spoof`"`r`n#Const [is_in_ide] = True`r`n"
[IO.File]::WriteAllText((Join-Path $inputDirectory 'First.bas'),$source,$utf)
[IO.File]::WriteAllText((Join-Path $inputDirectory 'Second.bas'),$source.Replace('"First"','"Second"'),$utf)
[IO.File]::WriteAllText((Join-Path $inputDirectory 'Spoof.bas'),$spoof,$utf)
[IO.File]::WriteAllText((Join-Path $inputDirectory 'input.UBE'),"UBE-Project 1`r`nName = `"Input`"`r`nKind = `"Library`"`r`nSource = `"First.bas`"`r`n",$utf)
[IO.File]::WriteAllText((Join-Path $evidence 'RequestGate.cls'),"UBE SOURCE 1 CLASS`r`nAttribute UBE_Name = `"RequestGate`"`r`nOption Explicit`r`n",$utf)
$paths=@('input.UBE','Second.bas','Spoof.bas','First.bas')
$generated=New-Object Text.StringBuilder
for($index=0;$index -lt $paths.Count;$index++){
 $bytes=$utf.GetBytes((Join-Path $inputDirectory $paths[$index]))
 for($part=0;$part -lt $bytes.Length;$part+=24){
  $null=$generated.AppendLine("Private Sub Fill${index}Part$part(ByRef B() As Byte)")
  for($n=$part;$n -lt [Math]::Min($part+24,$bytes.Length);$n++){$null=$generated.AppendLine("B($n) = $($bytes[$n])")}
  $null=$generated.AppendLine('End Sub')
 }
 $null=$generated.AppendLine("Private Sub Path$index(ByRef B() As Byte)`r`nOn Error GoTo Failed`r`nIf Not BufferPrimitives.TryResizeBytes(B, $($bytes.Length), False) Then Err.Raise 7")
 for($part=0;$part -lt $bytes.Length;$part+=24){$null=$generated.AppendLine("Fill${index}Part$part B")}
 $null=$generated.AppendLine("Exit Sub`r`nFailed:`r`nErr.Raise Err.Number`r`nEnd Sub")
}
$null=$generated.AppendLine("Private Sub ConfigurePath(ByRef B() As Byte, ByVal Index As Long)`r`nOn Error GoTo Failed")
for($index=0;$index -lt $paths.Count;$index++){$null=$generated.AppendLine("If Index = $index Then Path$index B")}
$null=$generated.AppendLine("Exit Sub`r`nFailed:`r`nErr.Raise Err.Number`r`nEnd Sub")
$body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'loading-probe.bas'),$utf).Replace("' GENERATED PATHS",$generated.ToString())
foreach($item in @(@('TRUE','1'),@('FALSE','0'))){
 $unit=$source.IndexOf('= '+$item[1])+2
 $body=$body.Replace($item[0]+'_BYTE',[string]$utf.GetByteCount($source.Substring(0,$unit))).Replace($item[0]+'_UNIT',[string]($unit+1))
}
$body=$body.Replace('FIRST_LENGTH',[string]$utf.GetByteCount($source)).Replace('VALUE_COLUMN',[string]('Public Const Selected As Long = '.Length+1)).Replace('SPOOF_BYTE',[string]$utf.GetByteCount($spoof.Substring(0,$spoof.IndexOf('#Const'))))
foreach($level in @('0','2')){foreach($control in @(0,1,2)){
 $name="loading-o$level-control$control";$expected=0;$candidate=$body
 if($control -eq 1){$candidate=$candidate.Replace('Private Const Control As Long = 0','Private Const Control As Long = 1');$expected=1}
 if($control -eq 2){$candidate=$candidate.Replace('Passed = ParsedDefault()','Passed = UnexpectedFailure()');$expected=99}
 [IO.File]::WriteAllText((Join-Path $evidence ($name+'.bas')),$candidate,$utf)
 $lines=@('UBE-Project 1','Name = "ContextLoadingTests"','Kind = "Exe"','Startup = "Main"',('Optimization = "'+$level+'"'))
 $lines+=@($dependencies|ForEach-Object{'Source = "'+[IO.Path]::GetFileName($_)+'"'});$lines+='Source = "RequestGate.cls"';$lines+='Source = "'+$name+'.bas"'
 $project=Join-Path $evidence ($name+'.UBE');[IO.File]::WriteAllText($project,($lines -join "`r`n")+"`r`n",$utf)
 $exe=Join-Path $evidence ($name+'.exe');$r=Run $CompilerExe @('--build',$project,$exe,'--clang',$Clang) ($name+'-build')
 if($r.Code -ne 0 -or $r.Log -notmatch 'BUILD OK'){throw "Build failed $name $($r.Log)"}
 $r=Run $exe @() ($name+'-run');if($r.Code -ne $expected -or $r.Log.Length -ne 0){throw "Assertion failed $name expected=$expected actual=$($r.Code) $($r.Log)"}
 Write-Output "PASS $name default/True/False append checks and opposing-context workers; exit=$expected"
}}
