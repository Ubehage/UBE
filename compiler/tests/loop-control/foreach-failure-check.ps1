param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube foreach failed values '+[guid]::NewGuid())
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
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$library=Join-Path $evidence 'kernel32.lib'
$r=Run (Join-Path (Split-Path -Parent $Clang) 'llvm-dlltool.exe') @('-m','i386:x86-64','-d',(Join-Path $repo 'compiler/llvm/kernel32.def'),'-l',$library) 'imports'
if($r.Code -ne 0){throw "Import library failed $($r.Log)"}
# A synthetic failing primitive isolates the source continuation from allocation policy.
# The native Variant storage gate separately tests actual allocation refusal and publication.
foreach($failedCall in @(1,2)){foreach($handler in @($false,$true)){
 $name="fail$failedCall-handler$handler"
 $handlerStart='';$handlerEnd=''
 if($handler){$handlerStart='On Error GoTo FailedHeader';$handlerEnd="Main = 90`r`nExit Function`r`nFailedHeader:"}
 $source=@"
UBE SOURCE 1 MODULE
Attribute UBE_Name = "Probe"
Private Intrinsic Function Tag(ByVal Value As Variant) As Long
Attribute Tag.UBE_Primitive = "Variant.Tag"
End Function
Public Function Main() As Long
 Dim Values(0 To 1) As Long
 Dim Item As Variant
 Dim Seen As Long
 Dim Observed As Long
 Dim ActualTag As Long
 Values(0) = 17
 Values(1) = 29
 $handlerStart
 For Each Item In Values
  Seen = Seen + 1
 Next Item
 $handlerEnd
 Main = 91
 If Seen <> $($failedCall-1) Or Err.Number <> 7 Then Exit Function
 If Seen = 0 Then
  ActualTag = -1
  ActualTag = Tag(Item)
  If ActualTag <> 0 Then Exit Function
 Else
  Observed = Item
  If Observed <> 17 Then Exit Function
 End If
 Main = 0
End Function
"@
 [IO.File]::WriteAllText((Join-Path $evidence ($name+'.bas')),$source,$encoding)
 $project=Join-Path $evidence ($name+'.UBE');$llvm=Join-Path $evidence ($name+'.ll')
 [IO.File]::WriteAllText($project,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nSource = `"$name.bas`"`r`n",$encoding)
 $r=Run $CompilerExe @('--emit-llvm',$project,$llvm) ($name+'-emit')
 if($r.Code){throw "Emit failed $name $($r.Log)"}
 $text=[IO.File]::ReadAllText($llvm)
 if(-not $text.Contains('call i1 @ube.variant.box(')){throw 'Missing expected boxing call site'}
 $text=$text.Replace('call i1 @ube.variant.box(', 'call i1 @test.variant.box(')
 $wrapper=@"

@test.variant.calls = internal global i64 0
define i1 @test.variant.box(ptr %ctx, i64 %tag, i64 %raw, ptr %layout, ptr %output) {
entry:
 %before = load i64, ptr @test.variant.calls
 %count = add i64 %before, 1
 store i64 %count, ptr @test.variant.calls
 %fail = icmp eq i64 %count, $failedCall
 br i1 %fail, label %refuse, label %box
refuse:
 store atomic i64 7, ptr %ctx monotonic, align 8
 ret i1 false
box:
 %result = call i1 @ube.variant.box(ptr %ctx, i64 %tag, i64 %raw, ptr %layout, ptr %output)
 ret i1 %result
}
"@
 [IO.File]::WriteAllText($llvm,$text+$wrapper,$encoding)
 foreach($level in @('0','2')){
  $exe=Join-Path $evidence ($name+'-o'+$level+'.exe')
  $r=Run $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-O'+$level),$llvm,$library,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608') ($name+'-clang'+$level)
  if($r.Code){throw "Clang failed $name $($r.Log)"}
  $r=Run $exe @() ($name+'-run'+$level)
  if($r.Code -ne 0 -or $r.ErrorText.Length -ne 0){throw "Failure continuation assertion $name O$level exit=$($r.Code) $($r.Log)"}
  Write-Output "PASS $name O${level}: failed value unused, construct/handler continuation, prior Item preserved"
 }
}}
