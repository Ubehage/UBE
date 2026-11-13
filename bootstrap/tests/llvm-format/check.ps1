# Executes the actual UBE formatter and verifies generated catalog parity and exact ASCII output.
param(
    [Parameter(Mandatory=$true)][string]$BootstrapExe,
    [string]$Clang = 'C:\Program Files\LLVM\bin\clang.exe'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$artifacts = Join-Path ([IO.Path]::GetTempPath()) ('ube llvm format ' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $artifacts -Force
$script:processNumber = 0
$BootstrapExe = [IO.Path]::GetFullPath($BootstrapExe)

# Stops on a failed independently authored acceptance assertion.
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# Writes deterministic UTF-8 source and IR, never the host's default text encoding.
function Write-Text([string]$Path, [string]$Text) {
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

# Quotes literal Windows command-line arguments including quotes and trailing backslashes.
function Quote-Argument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

# Retains a hidden child handle, bounds execution and saves each fresh process observation.
function Invoke-BoundedProcess([string]$File, [string[]]$Arguments) {
    $script:processNumber++
    $prefix = Join-Path $artifacts ('process-' + $script:processNumber)
    $start = @{ FilePath=$File; WorkingDirectory=$artifacts; WindowStyle='Hidden'; PassThru=$true; RedirectStandardOutput=($prefix + '.stdout'); RedirectStandardError=($prefix + '.stderr') }
    if ($Arguments.Count) { $start.ArgumentList = (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $process = Start-Process @start
    try {
        $handle = $process.Handle
        if (-not $process.WaitForExit(60000)) { $process.Kill(); $null = $process.WaitForExit(5000); throw "Process timeout. Evidence: $prefix" }
        $process.Refresh()
        Require ($null -ne $process.ExitCode) "Missing exit code for retained handle $handle"
        return [pscustomobject]@{ ExitCode=$process.ExitCode; Stdout=[IO.File]::ReadAllText($prefix + '.stdout',$utf8); Stderr=[IO.File]::ReadAllText($prefix + '.stderr',$utf8); Evidence=$prefix }
    } finally { $process.Dispose() }
}

. (Join-Path $PSScriptRoot '../NativeMemory.ps1')

# Compiles the same emitted library plus observation harness and checks AMD64 PE framing.
function Build-Harness([string]$IR, [string]$Exe, [string]$Level) {
    $link = @(Get-NativeMemoryLinkArguments $IR $Clang $artifacts)
    $result = Invoke-BoundedProcess $Clang (@('--target=x86_64-pc-windows-msvc','-fuse-ld=lld','-nostdlib',('-' + $Level),$IR) + $link + @('-o',$Exe,'-Wl,/entry:main,/subsystem:console,/stack:8388608'))
    Require ($result.ExitCode -eq 0) "Harness compilation failed. Evidence: $($result.Evidence)"
    $bytes = [IO.File]::ReadAllBytes($Exe)
    Require ($bytes.Length -ge 64 -and $bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) 'Invalid native DOS header'
    $offset = [BitConverter]::ToInt32($bytes,0x3c)
    Require ($offset -ge 64 -and $offset -le $bytes.Length - 6) 'Invalid native PE offset'
    Require ([BitConverter]::ToUInt32($bytes,$offset) -eq 0x4550 -and [BitConverter]::ToUInt16($bytes,$offset+4) -eq 0x8664) 'Expected AMD64 PE executable'
}



$nl=[Environment]::NewLine
Write-Output "Artifacts retained: $artifacts"
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$generator=Join-Path $root 'bootstrap/tools/llvm-templates.ps1'
$parity=Invoke-BoundedProcess 'powershell.exe' @('-NoProfile','-File',$generator)
Require ($parity.ExitCode -eq 0) "Catalog parity failed $($parity.Evidence)"
$catalog=[IO.File]::ReadAllBytes((Join-Path $root 'compiler/llvm/templates.bin'))
$entries=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/templates.json'),$utf8))
$names=@('BufferPrimitives','FilePrimitives','FileBytes','ByteText','LLVMWriter','LLVMTemplates','LLVMFormat','FormatProbe')
$manifestLines=@('UBE-Project 1','Name = "FormatChecks"','Kind = "Library"')
foreach($name in $names){
 $source=Join-Path $root "std-lib/src/portable/$name.bas"
 if($name.StartsWith('LLVM')){$source=Join-Path $root "compiler/src/$name.bas"}
 if($name -eq 'FormatProbe'){$source=Join-Path $PSScriptRoot 'FormatProbe.bas'}
 Copy-Item -LiteralPath $source -Destination (Join-Path $artifacts "$name.bas")
 $manifestLines+='Source = "'+$name+'.bas"'
}
$manifest=Join-Path $artifacts 'project.UBE'
Write-Text $manifest (($manifestLines -join $nl)+$nl)
$bound=Invoke-BoundedProcess $BootstrapExe @('--dump-bound',$manifest)
Require ($bound.ExitCode -eq 0) "Binding failed $($bound.Evidence)"
$symbols=@{}
foreach($line in ($bound.Stdout -split '\r?\n')){
 if($line -match '^SYMBOL (\d+)\|function\|([^|]+)\|'){$symbols[$Matches[2]]=$Matches[1]}
}
$ir=Join-Path $artifacts 'format.ll'
$result=Invoke-BoundedProcess $BootstrapExe @('--emit-llvm',$manifest,$ir)
Require ($result.ExitCode -eq 0) "Emission failed $($result.Evidence)"
$production=[IO.File]::ReadAllText($ir,$utf8)
# Supplies independently specified immutable byte descriptors for the existing observation ABI.
function Descriptor([string]$Name,[byte[]]$Bytes){
 $cells=($Bytes|ForEach-Object{'i64 '+$_}) -join ', '
 return "@$Name.data = global [$($Bytes.Length) x i64] [$cells]"+$nl+"@$Name = global {i64,i64,ptr,ptr} {i64 0,i64 $($Bytes.Length-1),ptr @$Name.data,ptr null}"+$nl
}
$globals='@test.context = private global %ube.context zeroinitializer,align 8'+$nl
$globals+=Descriptor 'catalog' $catalog
$globals+='@test.input = global i64 -9223372036854775808'+$nl
$code=@('define i32 @main(){','entry:','call void @ube.context.init(ptr @test.context)','%init = call i1 @ube.project.init(ptr @test.context)','%input = load volatile i64,ptr @test.input','br i1 %init,label %case0,label %failed')
$serial=0
foreach($entry in $entries){
 $id=$serial+1
 $text=[string]$entry.text -replace '\r\n?',([string][char]10)
 $text=$text.Replace([string][char]10,$nl)
 # Fixed independent decimal strings, not the implementation's number formatter.
 $expected=$text.Replace('{0}','-9223372036854775808').Replace('{1}','9223372036854775807').Replace('{2}','-12').Replace('{3}','0')
 $endLine=0
 if(($serial -band 1) -eq 0){$expected+=$nl;$endLine=-1}
 $globals+=Descriptor "expected$serial" ([Text.Encoding]::ASCII.GetBytes($expected))
 $next='case'+($serial+1)
 $code+=@(('case'+$serial+':'),"%p$serial = call {i1,i64} @ube.proc.$($symbols['Check'])(ptr @test.context,ptr @catalog,ptr @expected$serial,i64 $id,i64 %input,i64 9223372036854775807,i64 -12,i64 0,i64 $endLine)","%f$serial = extractvalue {i1,i64} %p$serial,0","%v$serial = extractvalue {i1,i64} %p$serial,1","%z$serial = icmp eq i64 %v$serial,0","%g$serial = and i1 %f$serial,%z$serial","br i1 %g$serial,label %$next,label %failed")
 $serial++
}
$code+=@(('case'+$serial+':'),"%invalid = call {i1,i64} @ube.proc.$($symbols['CheckInvalid'])(ptr @test.context,ptr @catalog)",'%if = extractvalue {i1,i64} %invalid,0','%iv = extractvalue {i1,i64} %invalid,1','%iz = icmp eq i64 %iv,0','%ig = and i1 %if,%iz','br i1 %ig,label %done,label %failed','done:','%d = call i1 @ube.context.dispose(ptr @test.context)','%exit = select i1 %d,i32 0,i32 98','ret i32 %exit','failed:','%c = call i1 @ube.context.dispose(ptr @test.context)','ret i32 99','}')
$combined=$production+$nl+$globals+($code -join $nl)
$path=Join-Path $artifacts 'combined.ll'
Write-Text $path $combined
foreach($level in @('O0','O2')){
 $exe=Join-Path $artifacts "$level.exe"
 Build-Harness $path $exe $level
 $run=Invoke-BoundedProcess $exe @()
 Require ($run.ExitCode -eq 0) "Format assertions failed $level $($run.Evidence)"
 Write-Output "PASS $level :$serial exact templates, multiline/repeated placeholders, literal braces, extrema, malformed catalogs and failure publication"
}
$path=Join-Path $artifacts 'negative.ll'
Write-Text $path ($combined.Replace('@test.input = global i64 -9223372036854775808','@test.input = global i64 -9223372036854775807'))
$exe=Join-Path $artifacts 'negative.exe'
Build-Harness $path $exe 'O2'
$run=Invoke-BoundedProcess $exe @()
Require ($run.ExitCode -eq 99) 'Changed numeric input must fail unchanged formatter oracle'
Write-Output 'PASS exact runtime negative control'
# Runs generator rejection cases only in an isolated copied tool tree.
$toolRoot=Join-Path $artifacts 'generation'
foreach($directory in @('bootstrap/tools','compiler/llvm','compiler/src')){$null=New-Item -ItemType Directory -Path (Join-Path $toolRoot $directory) -Force}
$tool=Join-Path $toolRoot 'bootstrap/tools/llvm-templates.ps1'
Copy-Item -LiteralPath $generator -Destination $tool
Copy-Item -LiteralPath (Join-Path $root 'compiler/src/SyntaxTokens.bas') -Destination (Join-Path $toolRoot 'compiler/src/SyntaxTokens.bas')
$catalogJson=Join-Path $toolRoot 'compiler/llvm/templates.json'
foreach($case in @('name','duplicate','ascii','slot','wide-slot','property','oversized')){
 $items=@([pscustomobject]@{name='Branch';text='b{0}'})
 if($case -eq 'name'){$items[0].name='Sub'}
 if($case -eq 'duplicate'){$items+=[pscustomobject]@{name='Branch';text='x'}}
 if($case -eq 'ascii'){$items[0].text='x'+[char]233}
 if($case -eq 'slot'){$items[0].text='{4}'}
 if($case -eq 'wide-slot'){$items[0].text='{01}'}
 if($case -eq 'property'){$items[0]|Add-Member -NotePropertyName unknown -NotePropertyValue 1}
 if($case -eq 'oversized'){$items[0].text='x'*1048577}
 Write-Text $catalogJson (ConvertTo-Json -InputObject $items -Depth 5)
 $bad=Invoke-BoundedProcess 'powershell.exe' @('-NoProfile','-File',$tool,'-Write')
 Require ($bad.ExitCode -ne 0) "Generator accepted malformed $case"
}
Write-Text $catalogJson (ConvertTo-Json -InputObject @([pscustomobject]@{name='LongFragment';text=('x'*4097)}) -Depth 5)
$large=Invoke-BoundedProcess 'powershell.exe' @('-NoProfile','-File',$tool,'-Write')
Require ($large.ExitCode -eq 0) 'Catalog incorrectly inherited the source-token4096 limit'
Write-Text $catalogJson ([IO.File]::ReadAllText((Join-Path $root 'compiler/llvm/templates.json'),$utf8))
$good=Invoke-BoundedProcess 'powershell.exe' @('-NoProfile','-File',$tool,'-Write')
Require ($good.ExitCode -eq 0) 'Isolated generation failed'
$check=Invoke-BoundedProcess 'powershell.exe' @('-NoProfile','-File',$tool)
Require ($check.ExitCode -eq 0) 'Isolated exact parity failed'
$poolPath=Join-Path $toolRoot 'compiler/llvm/templates.bin'
$changed=[IO.File]::ReadAllBytes($poolPath)
$changed[0]=[byte]($changed[0]+1)
[IO.File]::WriteAllBytes($poolPath,$changed)
$bad=Invoke-BoundedProcess 'powershell.exe' @('-NoProfile','-File',$tool)
Require ($bad.ExitCode -ne 0) 'Parity accepted changed pool byte'
Write-Output 'PASS generator strict input rejection, deterministic rebuild and full-byte parity'
