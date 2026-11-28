param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$utf=[Text.UTF8Encoding]::new($false,$true)
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube conditional selection '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
$cases=New-Object Collections.Generic.List[object]
function Case([string]$Name,[string[]]$Lines,[string]$Expected='chosen',[bool]$Hosted=$false,[bool]$Reject=$false) {
 $cases.Add([pscustomobject]@{Name=$Name;Source=($Lines -join "`r`n")+"`r`n";Expected=$Expected;Hosted=$Hosted;Reject=$Reject})
}
Case 'standalone' @('#If IS_IN_IDE Then','wrong','#Else','chosen','#End If')
Case 'hosted-facts' @('#If IS_IN_IDE Then','chosen','#Else','wrong','#End If') 'chosen' $true
Case 'local-arithmetic' @('#Const Count = 2 + 3 * 4','#If Count = 14 Then','chosen','#Else','wrong','#End If')
Case 'local-not-exported' @('#If Count = 14 Then','wrong','#End If') '' $false $true
Case 'case-insensitive' @('#cOnSt FLAG = True','#iF flag tHeN','chosen','#eNd iF')
Case 'numeric-condition' @('#If 1 Then','chosen','#End If')
Case 'text-condition' @('#If "True" Then','chosen','#End If')
Case 'elseif' @('#If False Then','wrong','#ElseIf 2 < 3 Then','chosen','#ElseIf Missing / 0 Then','wrong','#Else','wrong','#End If')
Case 'inactive-nesting' @('#If False Then','#If Missing / 0 Then','not valid !!!','#End If','#Else','chosen','#End If')
Case 'inactive-constant' @('#If False Then','#Const Local = Missing / 0','#Else','chosen','#End If')
Case 'continued-directive' @('#If False Or _ '' continued','  True Then','chosen','#End If')
Case 'directive-comment' @('#If True Then '' ignored','chosen','#End If '' ignored')
Case 'inactive-assembly' @('#If False Then','Asm','#End If','#Else','_ '' opaque','End Asm','#Else','chosen','#End If')
Case 'inactive-unicode' @('#If False Then',('bad '+[char]0xE5+' '+[char]::ConvertFromUtf32(0x1F600)),'#Else','chosen','#End If')
Case 'short-circuit' @('#If False AndAlso (1 \ 0 = 0) Then','wrong','#Else','chosen','#End If')
Case 'eager-and' @('#If False And (1 \ 0 = 0) Then','wrong','#End If') '' $false $true
Case 'supplied-redefinition' @('#Const IS_IN_IDE = False','chosen') '' $false $true
Case 'local-redefinition' @('#Const Item = 1','#Const ITEM = 2','chosen') '' $false $true
Case 'forward-name' @('#Const A = B','#Const B = 1','chosen') '' $false $true
Case 'stray-else' @('#Else','chosen') '' $false $true
Case 'double-else' @('#If False Then','#Else','#Else','#End If') '' $false $true
Case 'elseif-after-else' @('#If False Then','#Else','#ElseIf True Then','#End If') '' $false $true
Case 'unclosed-if' @('#If True Then','chosen') '' $false $true
Case 'trailing-statement' @('#If False Then','#Else: chosen','#End If') '' $false $true
Case 'unclosed-inactive-assembly' @('#If False Then','Asm','#End If') '' $false $true
$initializers=New-Object Collections.Generic.List[string]
function Bytes([string]$Name,[string]$Text,[string]$Prefix) {
 $bytes=$utf.GetBytes($Text)
 if($bytes.Length -eq 0){return "Dim $Name() As Byte`r`n"}
 $lines=New-Object Collections.Generic.List[string]
 $lines.Add("Dim $Name(0 To $($bytes.Length-1)) As Byte")
 for($i=0;$i -lt $bytes.Length;$i+=24){
  $helper=$Prefix+$Name+[string]$i
  $assignments=New-Object Collections.Generic.List[string]
  for($j=$i;$j -lt [Math]::Min($i+24,$bytes.Length);$j++){$assignments.Add("Value($j) = $($bytes[$j])")}
  $initializers.Add("Private Sub $helper(ByRef Value() As Byte)`r`n"+($assignments -join "`r`n")+"`r`nEnd Sub`r`n")
  $lines.Add("$helper $Name")
 }
 return ($lines -join "`r`n")+"`r`n"
}
$functions=New-Object Collections.Generic.List[string]
$calls=New-Object Collections.Generic.List[string]
for($i=0;$i -lt $cases.Count;$i++) {
 $case=$cases[$i];$name='Check'+($i+1);$hosted='False';$reject='False'
 if($case.Hosted){$hosted='True'};if($case.Reject){$reject='True'}
 $functions.Add("Private Function $name() As Boolean`r`nOn Error GoTo Failed`r`n"+(Bytes 'Source' $case.Source $name)+(Bytes 'Expected' $case.Expected $name)+"$name = Matches(Source, Expected, $hosted, $reject)`r`nExit Function`r`nFailed:`r`n$name = False`r`nEnd Function`r`n")
 $calls.Add("Passed = False`r`nPassed = $name()`r`nIf Not Passed Then Main = $($i+2): Exit Function")
}
$template=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'selection-probe.bas'),$utf)
$source=$template.Replace("' CASE FUNCTIONS",(($initializers -join "`r`n")+"`r`n"+($functions -join "`r`n"))).Replace("    ' CASE CALLS",($calls -join "`r`n"))
$results=New-Object Collections.Generic.List[object]
function Run([string]$File,[string[]]$Arguments,[string]$Name) {
 $stdout=Join-Path $evidence ($Name+'.stdout');$stderr=Join-Path $evidence ($Name+'.stderr')
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=$stdout;RedirectStandardError=$stderr}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(120000)){$p.Kill();throw "Deadline: $Name"};$p.Refresh();if($null -eq $p.ExitCode){throw "Missing status: $Name"};return [pscustomobject]@{Code=$p.ExitCode;Out=[IO.File]::ReadAllText($stdout,$utf);Error=[IO.File]::ReadAllText($stderr,$utf)}}finally{$p.Dispose()}
}
$success=$false
try {
 $dependencies=@()
 foreach($module in @('BufferPrimitives','FilePrimitives','ByteText','Utf8','InvariantNumbers','BinaryFloat','BinaryFloatValues','BinaryFloatMath','BinaryFloatPower','BinaryFloatText','ThreadPrimitives')){$dependencies+=Join-Path $root ('std-lib/src/portable/'+$module+'.bas')}
 foreach($module in @('SourceScanner','SyntaxTokens','SourceParser','ConstantValues','ConstantText','ConditionalExpressions','ConditionalSource')){$dependencies+=Join-Path $root ('compiler/src/'+$module+'.bas')}
 foreach($dependency in $dependencies){Copy-Item -LiteralPath $dependency -Destination $evidence}
 foreach($optimization in @('0','2')) {foreach($control in @(0,1,2)) {
  $name="selection-o$optimization-control$control"
  $body=$source
  $expected=0
  if($control -eq 1){
   # Change an independently expected source byte; the comparison must detect it.
   $anchor="Private Sub Check1Expected0(ByRef Value() As Byte)`r`nValue(0) = 99"
   if(-not $body.Contains($anchor)){throw 'Missing expected-source negative-control anchor'}
   $body=$body.Replace($anchor,"Private Sub Check1Expected0(ByRef Value() As Byte)`r`nValue(0) = 119")
   $expected=2
  }
  if($control -eq 2){$expected=99;$body=$body.Replace('Passed = Check1()','Passed = UnexpectedFailure()')+"`r`nPrivate Function UnexpectedFailure() As Boolean`r`nErr.Raise 5`r`nEnd Function`r`n"}
  $probe=Join-Path $evidence ($name+'.bas')
  [IO.File]::WriteAllText($probe,$body,$utf)
  $manifest=Join-Path $evidence ($name+'.UBE')
  $lines=@('UBE-Project 1','Name = "Probe"','Kind = "Exe"','Startup = "Main"',"Optimization = `"$optimization`"","Source = `"$name.bas`"")
  $lines+=@($dependencies|ForEach-Object{'Source = "'+[IO.Path]::GetFileName($_)+'"'})
  [IO.File]::WriteAllText($manifest,($lines -join "`r`n")+"`r`n",$utf)
  $exe=Join-Path $evidence ($name+'.exe')
  $run=Run $CompilerExe @('--build',$manifest,$exe,'--clang',$Clang) ($name+'-build')
  if($run.Code -ne 0){throw "Build failed $name : $($run.Out) $($run.Error)"}
  $run=Run $exe @() ($name+'-run')
  if($run.Code -ne $expected -or $run.Out.Length -ne 0 -or $run.Error.Length -ne 0){throw "Expected $expected, got $($run.Code) for $name : $($run.Out) $($run.Error)"}
  $results.Add([pscustomobject]@{Name=$name;Expected=$expected;Actual=$run.Code;Pass=$true})
  Write-Output "PASS $name exit=$expected ($($cases.Count) source cases)"
 }}
 $success=$true
} finally {
 $report=[pscustomobject]@{Success=$success;Compiler=$CompilerExe;CompilerSha256=(Get-FileHash -LiteralPath $CompilerExe -Algorithm SHA256).Hash;Cases=$cases.ToArray();Runs=$results.ToArray()}
 [IO.File]::WriteAllText((Join-Path $evidence 'report.json'),($report|ConvertTo-Json -Depth 5),$utf)
}
