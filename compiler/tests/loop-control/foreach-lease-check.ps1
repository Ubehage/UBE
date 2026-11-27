param([Parameter(Mandatory=$true)][string]$CompilerExe,[string]$Clang='C:\Program Files\LLVM\bin\clang.exe',[ValidateRange(0,4)][int[]]$Modes=@(0,1,2,3,4))
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube foreach lease check '+[guid]::NewGuid())
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
$fixture=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'foreach-lease-control.bas'))
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'foreach-lease-probe.ll'))
foreach($mode in $Modes){
 $controls=@('none');if($mode -eq 0){$controls+= 'balance'};if($mode -eq 4){$controls+= 'root'}
 foreach($negative in $controls){
  $name="mode$mode-negative$negative"
  $source=$fixture.Replace('Private Const Mode As Long = 0',"Private Const Mode As Long = $mode")
  if($negative -eq 'balance'){$source=$source.Replace('If Observe() <> 2 Then Exit Function','If Observe() <> 3 Then Exit Function')}
  [IO.File]::WriteAllText((Join-Path $evidence ($name+'.bas')),$source,$encoding)
  $project=Join-Path $evidence ($name+'.UBE');$llvm=Join-Path $evidence ($name+'.ll')
  [IO.File]::WriteAllText($project,"UBE-Project 1`r`nName = `"Probe`"`r`nKind = `"Exe`"`r`nStartup = `"Main`"`r`nSource = `"$name.bas`"`r`n",$encoding)
  $r=Run $CompilerExe @('--emit-llvm',$project,$llvm) ($name+'-emit')
  if($r.Code -ne 0){throw "Emit failed $name $($r.Log)"}
  $text=[IO.File]::ReadAllText($llvm).Replace("`r`n","`n")
  $capture='(?m)(^  %enumeration\.snapshot\.[0-9]+ = call \{ i64, i64, ptr, ptr \} )@ube\.array\.snapshot'
  $captures=[regex]::Matches($text,$capture).Count
  if($captures -ne 6){throw "Expected six emitted enumeration capture sites; found $captures"}
  $text=[regex]::Replace($text,$capture,'$1@test.enum.snapshot')
  $drop='(?s)(?<prefix>  %v(?<value>[0-9]+) = load atomic ptr, ptr %enumeration\.owner\.(?<node>[0-9]+) acquire, align 8\n.*?)  call void @ube\.block\.drop\(ptr %ctx, ptr %v\k<value>\)'
  $drops=[regex]::Matches($text,$drop).Count
  if($drops -lt $captures){throw "Missing emitted enumeration release sites: $drops"}
  $text=[regex]::Replace($text,$drop,{
   param($match)
   $match.Groups['prefix'].Value+'  call void @test.enum.drop(ptr %ctx, ptr %v'+$match.Groups['value'].Value+', ptr %temp.'+$match.Groups['node'].Value+')'
  })
  if(-not $text.Contains('@ube.thread.current(ptr %ctx)')){throw 'Missing source assertion-hook wrapper'}
  $text=$text.Replace('call { i1, i64 } @ube.thread.current(ptr %ctx)','call { i1, i64 } @test.enum.observe(ptr %ctx)')
  $text=$text.Replace('call i1 @ube.variant.box(', 'call i1 @test.enum.box(')
  $fail=0;if($mode -eq 1){$fail=1}
  $oracle=$probe.Replace('FAIL_BOX_CALL',[string]$fail)
  if($negative -eq 'root'){$oracle=$oracle.Replace('%a = icmp eq i64 %lower, 0','%a = icmp eq i64 %lower, 1')}
  [IO.File]::WriteAllText($llvm,$text+$oracle,$encoding)
  foreach($level in @('0','2')){
   $exe=Join-Path $evidence ($name+'-o'+$level+'.exe')
   $r=Run $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-O'+$level),$llvm,$library,'-o',$exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608') ($name+'-clang'+$level)
   if($r.Code -ne 0){throw "Clang failed $name $($r.Log)"}
   $expected=0;if($negative -ne 'none'){$expected=1}
   $r=Run $exe @() ($name+'-run'+$level)
   if($r.Code -ne $expected -or $r.ErrorText.Length -ne 0){throw "Lease assertion $name O$level expected=$expected actual=$($r.Code) $($r.Log)"}
   Write-Output "PASS $name O${level}: exact owner ledger and cleared descriptor roots; exit=$expected"
  }
 }
}
