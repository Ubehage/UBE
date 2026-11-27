param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube context binding '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
$utf=New-Object Text.UTF8Encoding($false,$true)
Write-Output "Evidence: $evidence"
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $out=Join-Path $evidence ($Name+'.stdout');$err=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;WorkingDirectory=$evidence;RedirectStandardOutput=$out;RedirectStandardError=$err}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(180000)){$p.Kill();throw "Deadline $Name"};$p.Refresh();return [pscustomobject]@{Code=$p.ExitCode;Log=([IO.File]::ReadAllText($out)+[IO.File]::ReadAllText($err))}}finally{$p.Dispose()}
}
$cases=@(
 @('reads',"Const Flag As Boolean = IS_IN_IDE`nSub Run()`nDim Value As Boolean = [Is_In_IdE]`nEnd Sub",0,0,1,0),
 @('dependency',"Const Flag As Boolean = IS_IN_IDE`nConst Other As Boolean = Flag`nSub Run()`nDim Value As Boolean = IS_IN_IDE`nEnd Sub",0,0,2,0),
 @('grouped',"Sub Take(ByRef Value As Boolean)`nEnd Sub`nSub Run()`nTake (IS_IN_IDE)`nEnd Sub",0,0,0,1),
 @('byval',"Sub Take(ByVal Value As Boolean)`nEnd Sub`nSub Run()`nTake IS_IN_IDE`nEnd Sub",0,0,0,0),
 @('namespaces',"Type Record`nIS_IN_IDE As Boolean`nEnd Type`nSub Run()`nDim Item As Record`nItem.IS_IN_IDE = True`nGoTo IS_IN_IDE`nIS_IN_IDE:`nDim Value As Boolean = IS_IN_IDE`nEnd Sub",0,0,0,0),
 @('write',"Sub Run()`nIS_IN_IDE = True`nEnd Sub",3,21,0,0),
 @('directref',"Sub Take(ByRef Value As Boolean)`nEnd Sub`nSub Run()`nTake IS_IN_IDE`nEnd Sub",10,12,0,0),
 @('local',"Sub Run()`nDim [is_in_ide] As Boolean`nEnd Sub",1,2,0,0),
 @('constant',"Const IS_IN_IDE As Boolean = False",1,2,0,0),
 @('parameter',"Sub Run(ByVal IS_IN_IDE As Boolean)`nEnd Sub",1,2,0,0),
 @('procedure',"Sub IS_IN_IDE()`nEnd Sub",1,2,0,0),
 @('module',"Sub Run()`nEnd Sub",1,2,0,0),
 @('package',"Public Const Flag As Boolean = IS_IN_IDE`nSub Run()`nDim Qualified As Boolean = [is_in_ide].Sample.Flag`nDim Bare As Boolean = IS_IN_IDE`nEnd Sub",0,0,1,0)
)
$dependencies=@()
foreach($name in @('BufferPrimitives','FilePrimitives','ByteText','Utf8','InvariantNumbers','BinaryFloat','BinaryFloatValues','BinaryFloatMath','BinaryFloatPower','BinaryFloatText')){$dependencies+=Join-Path $root ('std-lib/src/portable/'+$name+'.bas')}
foreach($name in @('SourceScanner','SyntaxTokens','SourceParser','ProjectSyntax','DeclarationBinder','ConstantValues','ConstantText','ConditionalExpressions','ConditionalSource','ExpressionBinder','ManagedLayouts','AggregateLayout')){$dependencies+=Join-Path $root ('compiler/src/'+$name+'.bas')}
foreach($path in $dependencies){Copy-Item -LiteralPath $path -Destination $evidence}
$generated=New-Object Text.StringBuilder
for($i=0;$i -lt $cases.Count;$i++){
 $case=$cases[$i];$module='Sample';if($case[0] -eq 'module'){$module='IS_IN_IDE'}
 $source="UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"$module`"`n"+$case[1]+"`n"
 $bytes=[Text.Encoding]::UTF8.GetBytes($source)
 for($part=0;$part -lt $bytes.Length;$part+=24){
  $null=$generated.AppendLine("Private Sub Fill${i}Part$part(ByRef B() As Byte)")
  for($n=$part;$n -lt [Math]::Min($part+24,$bytes.Length);$n++){$null=$generated.AppendLine("B($n) = $($bytes[$n])")}
  $null=$generated.AppendLine('End Sub')
 }
 $null=$generated.AppendLine("Private Function Case$i(ByVal Hosted As Boolean) As Boolean`r`nDim B(0 To $($bytes.Length-1)) As Byte")
 for($part=0;$part -lt $bytes.Length;$part+=24){$null=$generated.AppendLine("Fill${i}Part$part B")}
 $contextPackage='False';if($case[0] -eq 'package'){$contextPackage='True'}
 $null=$generated.AppendLine("Case$i = Check(B, Hosted, $($case[2]), $($case[3]), $($case[4]), $($case[5]), $contextPackage)`r`nEnd Function")
}
$null=$generated.AppendLine("Public Function Main() As Long`r`nDim Passed As Boolean`r`nOn Error GoTo Unexpected")
for($i=0;$i -lt $cases.Count;$i++){foreach($hosted in @('False','True','False')){$null=$generated.AppendLine("Main = $($i+1)`r`nPassed = False`r`nPassed = Case$i($hosted)`r`nIf Not Passed Then Exit Function")}}
$null=$generated.AppendLine("Main = 0`r`nExit Function`r`nUnexpected:`r`nMain = 99`r`nEnd Function")
$body=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'binding-probe.bas'),$utf).Replace("' GENERATED CASES",$generated.ToString())
foreach($level in @('0','2')){foreach($control in @(0,1,2)){
 $name="binding-o$level-control$control";$expected=0;$candidate=$body
 if($control -eq 1){$candidate=$candidate.Replace('Private Const Control As Long = 0','Private Const Control As Long = 1');$expected=1}
 if($control -eq 2){$candidate=$candidate.Replace('Passed = Case0(False)','Passed = UnexpectedFailure()');$expected=99}
 [IO.File]::WriteAllText((Join-Path $evidence ($name+'.bas')),$candidate,$utf)
 $lines=@('UBE-Project 1','Name = "ContextTests"','Kind = "Exe"','Startup = "Main"',('Optimization = "'+$level+'"'))
 $lines+=@($dependencies|ForEach-Object{'Source = "'+[IO.Path]::GetFileName($_)+'"'});$lines+='Source = "'+$name+'.bas"'
 $project=Join-Path $evidence ($name+'.UBE');[IO.File]::WriteAllText($project,($lines -join "`r`n")+"`r`n",$utf)
 $exe=Join-Path $evidence ($name+'.exe');$r=Run $CompilerExe @('--build',$project,$exe,'--clang',$Clang) ($name+'-build')
 if($r.Code -ne 0){throw "Build failed $name $($r.Log)"}
 $r=Run $exe @() ($name+'-run');if($r.Code -ne $expected -or $r.Log.Length -ne 0){throw "Assertion failed $name expected=$expected actual=$($r.Code) $($r.Log)"}
 Write-Output "PASS $name cases=$($cases.Count) contexts=False,True,False exit=$expected"
}}
