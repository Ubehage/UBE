param([string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$utf=New-Object Text.UTF8Encoding($false,$true)
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$evidence=Join-Path ([IO.Path]::GetTempPath()) ('ube IDE guard '+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $evidence
Write-Output "Evidence: $evidence"
$runtime=[IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/windows-runtime.ll'),$utf)
$start=$runtime.IndexOf('; Hosted startup validates a live named job')
$entry=$runtime.IndexOf('define i1 @ube.ide.session.check() {',$start)
$finish=$runtime.IndexOf("`r`n}`r`n",$entry)
if($start -lt 0 -or $entry -lt $start -or $finish -lt $entry){throw 'Missing actual generated guard'}
$guard=$runtime.Substring($start,$finish+5-$start)
$guard=[regex]::Replace($guard,'(?m)^declare dllimport [^\r\n]+\r?\n','')
$probe=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'guard-probe.ll'),$utf)
function Run([string]$File,[string[]]$Arguments,[string]$Name){
 $options=@{FilePath=$File;WindowStyle='Hidden';PassThru=$true;RedirectStandardOutput=(Join-Path $evidence ($Name+'.stdout'));RedirectStandardError=(Join-Path $evidence ($Name+'.stderr'))}
 if($Arguments.Count){$options.ArgumentList=($Arguments|ForEach-Object{if($_ -match '\s'){'"'+$_+'"'}else{$_}}) -join ' '}
 $p=Start-Process @options
 try{$null=$p.Handle;if(-not $p.WaitForExit(60000)){$p.Kill();throw "Deadline $Name"};$p.Refresh();return [pscustomobject]@{Code=$p.ExitCode;Error=[IO.File]::ReadAllText($options.RedirectStandardError);Out=[IO.File]::ReadAllText($options.RedirectStandardOutput)}}finally{$p.Dispose()}
}
foreach($level in @('0','2')){foreach($control in @(0,1,2)){
 $name="guard-o$level-control$control";$expected=0;$candidate=$guard;$driver=$probe
 if($control -eq 1){$driver=$driver.Replace('@control = global i1 false','@control = global i1 true');$expected=1}
 if($control -eq 2){$candidate=$candidate.Replace('br i1 %member.ok, label %limits, label %close','br i1 true, label %limits, label %close');if($candidate -ceq $guard){throw 'Missing membership control'};$expected=8}
 $ir=Join-Path $evidence ($name+'.ll');[IO.File]::WriteAllText($ir,$candidate+"`r`n"+$driver,$utf)
 $exe=Join-Path $evidence ($name+'.exe')
 $r=Run $Clang @('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-O'+$level),$ir,'-Wl,/entry:main,/subsystem:console','-o',$exe) ($name+'-build')
 if($r.Code -ne 0){throw "Build failure $name $($r.Error)"}
 $r=Run $exe @() ($name+'-run')
 if($r.Code -ne $expected -or $r.Error.Length -ne 0 -or $r.Out.Length -ne 0){throw "Assertion failure $name expected=$expected actual=$($r.Code) $($r.Error)"}
 Write-Output "PASS $name expected=$expected actual=$($r.Code)"
}}
