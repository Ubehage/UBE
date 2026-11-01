param(
    [string]$SelectionPath = (Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'),
    [string]$DevelopmentDirectory = ''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/path-bytes/'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory $run
$names=@('std-lib/tools/check-path-bytes.ps1','std-lib/tests/path-bytes/normalization.json',
    'std-lib/tests/path-bytes/assertions.bas','std-lib/tests/path-bytes/costs.c','std-lib/PATH-BYTES-PROPOSAL.md',
    'std-lib/src/portable/Utf8.bas','std-lib/src/portable/ByteBuffer.bas',
    'std-lib/src/portable/FileBytes.bas','std-lib/src/portable/PathBytes.bas','bootstrap/tools/verification.ps1',
    'bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c',
    'bootstrap/runtime/windows/thread_primitives.c','std-lib/tests/managed-storage/copy-probe.h',
    'std-lib/tests/byte-storage/allocation-probe.h')
$inputs=@($names | ForEach-Object {Get-ArtifactIdentity (Join-Path $root $_)})
$commands=@();$checks=@();$measurements=@();$success=$false;$failure=$null
function Invoke-PathCheck([string]$Program,[string[]]$Values){
    $record=Invoke-BoundedProcess $Program $Values $root 60
    $script:commands+=$record
    if($record.timedOut -or $record.exit -ne 0 -or $record.stderr -cne ''){throw ($record | ConvertTo-Json -Depth 5)}
    return $record
}
try {
    if($DevelopmentDirectory -ceq ''){
        $selection=Get-VerifiedBootstrapSelection $SelectionPath
        $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
        $runtime=$selection.runtime.path
        $inputs+=@($selection.manifest,$selection.runtime,$selection.unicodeRuntime,$selection.clang)
    } else {
        $developmentReport=Join-Path $DevelopmentDirectory 'report.json'
        $development=Get-Content $developmentReport -Raw | ConvertFrom-Json
        if(-not $development.success -or -not $development.developmentOnly){throw 'Not a successful development tool report'}
        foreach($identity in @($development.inputs)+@($development.artifacts)){
            if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw "Development input changed: $($identity.path)"}
        }
        $selection=$development.selection
        $stages=@((Join-Path $DevelopmentDirectory 'compiler.exe'))
        $runtime=Join-Path $DevelopmentDirectory 'runtime.o'
        $inputs+=@(Get-ArtifactIdentity $developmentReport)
        $inputs+=@($development.inputs)+@($development.artifacts)
    }
    $inputs+=@($stages | ForEach-Object {Get-ArtifactIdentity $_})
    $inputs+=@($selection.clang,$selection.unicodeRuntime)
    $source=New-Object Text.StringBuilder
    foreach($module in @('Utf8','ByteBuffer','FileBytes','PathBytes')){
        $lines=[IO.File]::ReadAllText((Join-Path $root ('std-lib/src/portable/'+$module+'.bas'))).Replace("`r`n","`n").Split("`n")
        if($lines[0] -cne 'UBE SOURCE 1 MODULE' -or $lines[1] -cne ('Attribute UBE_Name = "'+$module+'"')){throw "Unexpected module envelope: $module"}
        $null=$source.AppendLine(($lines[2..($lines.Length-1)] -join "`n"))
    }
    $null=$source.AppendLine([IO.File]::ReadAllText((Join-Path $root 'std-lib/tests/path-bytes/assertions.bas')))
    $cases=[IO.File]::ReadAllText((Join-Path $root 'std-lib/tests/path-bytes/normalization.json'),[Text.Encoding]::UTF8) | ConvertFrom-Json
    $null=$source.AppendLine("Function Main() As Long`n    Dim BaseBytes() As Byte`n    Dim InputBytes() As Byte`n    Dim Expected() As Byte")
    $caseNumber=0
    foreach($kind in @('relative','resolve')){
        foreach($case in $cases.$kind){
            $caseNumber++
            foreach($array in @('BaseBytes','InputBytes','Expected')){
                $bytes=[byte[]]@()
                if($array -ceq 'BaseBytes' -and $kind -ceq 'resolve'){$bytes=[Text.Encoding]::UTF8.GetBytes($case.base)}
                if($array -ceq 'InputBytes'){
                    if($null -ne $case.PSObject.Properties['hex']){
                        $bytes=[byte[]]@(for($offset=0;$offset -lt $case.hex.Length;$offset+=2){[Convert]::ToByte($case.hex.Substring($offset,2),16)})
                    }else{$bytes=[Text.Encoding]::UTF8.GetBytes($case.path)}
                }
                if($array -ceq 'Expected' -and $null -ne $case.PSObject.Properties['result']){$bytes=[Text.Encoding]::UTF8.GetBytes($case.result)}
                $null=$source.AppendLine(('    If TryResizeByteStorage('+ $array +', '+$bytes.Length+', False) = False Then'))
                $null=$source.AppendLine("        Main = 100`n        Exit Function`n    End If")
                for($index=0;$index -lt $bytes.Length;$index++){$null=$source.AppendLine(('    '+$array+'('+ $index +') = '+$bytes[$index]))}
            }
            $expectedFailure=0;$parents=0;$resolve='False'
            if($null -ne $case.PSObject.Properties['failure']){$expectedFailure=$case.failure}
            if($null -ne $case.PSObject.Properties['parents']){$parents=$case.parents}
            if($kind -ceq 'resolve'){$resolve='True'}
            $null=$source.AppendLine(('    If CheckBytePathCase('+ $resolve +', BaseBytes, InputBytes, Expected, '+$parents+', '+$expectedFailure+') = False Then'))
            $null=$source.AppendLine(('        Main = '+$caseNumber))
            $null=$source.AppendLine("        Exit Function`n    End If")
        }
    }
    $null=$source.AppendLine("    If CheckBytePathLimits() = False Then`n        Main = 101`n        Exit Function`n    End If")
    $null=$source.AppendLine(('    Print "path cases '+$caseNumber+' and limits"'))
    $null=$source.AppendLine("    Main = 0`nEnd Function")
    $fixture=Join-Path $run 'cases.bas'
    [IO.File]::WriteAllText($fixture,$source.ToString(),(New-Object Text.UTF8Encoding($false)))
    $procedures=@([regex]::Matches($source.ToString(),'(?m)^(?:Intrinsic )?(?:Sub|Function) ([A-Za-z_][A-Za-z_0-9]*)\b'))
    $observerIndex=-1
    for($index=0;$index -lt $procedures.Count;$index++){
        if($procedures[$index].Groups[1].Value -ceq 'ReadBytePathTestError'){$observerIndex=$index}
    }
    if($observerIndex -lt 0){throw 'Missing native Err observer bridge'}
    $symbols=@{}
    for($index=0;$index -lt $procedures.Count;$index++){$symbols[$procedures[$index].Groups[1].Value]='ube.p'+$index}
    $observedRuntime=Join-Path $run 'observed-runtime.c'
    $runtimeInclude=(Join-Path $root 'bootstrap/runtime/bootstrap_runtime.c').Replace('\','/')
    [IO.File]::WriteAllText($observedRuntime,('#include "'+$runtimeInclude+'"'+"`nsize_t path_test_roots(void) { ube_gc_enter_lock(); size_t count=ube_gc_root_count; ube_gc_leave_lock(); return count; }`n"),(New-Object Text.UTF8Encoding($false)))
    $null=Invoke-PathCheck $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c17','-Wall','-Wextra','-Werror','-include',(Join-Path $root 'std-lib/tests/managed-storage/copy-probe.h'),'-c',$observedRuntime,'-o',(Join-Path $run 'observed-runtime.o'))
    $hashes=@()
    for($index=0;$index -lt $stages.Count;$index++){
        $stem=Join-Path $run ('stage'+$index)
        $null=Invoke-PathCheck $stages[$index] @($fixture,($stem+'.ll'))
        $raw=[IO.File]::ReadAllText($stem+'.ll')
        $observer='ube.p'+$observerIndex
        $pattern='(?ms)^define i32 @'+[regex]::Escape($observer)+'\(\) \{.*?^\}'
        $matches=[regex]::Matches($raw,$pattern)
        if($matches.Count -ne 1 -or $matches[0].Value -match '\bcall\b'){throw 'Unexpected observer stub definition'}
        $adapted=[regex]::Replace($raw,$pattern,'')
        $adapted=$adapted.Replace('@'+$observer+'(', '@ube_err_number(')
        if($adapted -notmatch '(?m)^declare i32 @ube_err_number\(\)'){$adapted+="`ndeclare i32 @ube_err_number()`n"}
        [IO.File]::WriteAllText($stem+'-observed.ll',$adapted,(New-Object Text.UTF8Encoding($false)))
        $null=Invoke-PathCheck $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2',($stem+'-observed.ll'),$runtime,$selection.unicodeRuntime.path,'-o',($stem+'.exe'))
        $execute=Invoke-PathCheck ($stem+'.exe') @()
        if($execute.stdout.Replace("`r`n","`n") -cne "path cases $caseNumber and limits`n"){throw 'Incorrect exact case output'}
        $checks+=[pscustomobject]@{assertion="stage $index independent $caseNumber path vectors, exact status/Err, unchanged inputs and failure publication, ASCII/BMP/supplementary UTF-16 limits and byte limits";passed=$true}
        $costIr=$adapted.Replace('define i32 @main(', 'define i32 @path_unused_entry(')
        foreach($binding in @(@('FeedUtf8Byte','path_feed_body'),@('TryClassifyBytePathComponent','path_component_body'))){
            $symbol=$symbols[$binding[0]]
            $definition='(?m)^define i1 @'+[regex]::Escape($symbol)+'\('
            if([regex]::Matches($costIr,$definition).Count -ne 1){throw "Unexpected observer target: $symbol"}
            $costIr=[regex]::Replace($costIr,$definition,('define i1 @'+$binding[1]+'('))
        }
        $feed=$symbols.FeedUtf8Byte;$component=$symbols.TryClassifyBytePathComponent
        $normalize=$symbols.TryNormalizeRelativePathBytes;$resolve=$symbols.TryResolvePathBytes
        foreach($signature in @(('i1 @'+[regex]::Escape($normalize)+'\(ptr [^,]+, ptr [^,]+, ptr [^,]+, ptr [^)]+\)'), ('i1 @'+[regex]::Escape($resolve)+'\(ptr [^,]+, ptr [^,]+, ptr [^,]+, ptr [^)]+\)'))){
            if([regex]::Matches($costIr,'(?m)^define '+$signature+' \{').Count -ne 1){throw "Unexpected path ABI: $signature"}
        }
        $costIr+="`ndeclare void @path_feed_called()`ndeclare void @path_component_called()`n"+@"
define i1 @$feed(ptr %decoder, i8 %byte, ptr %scalar, ptr %complete) {
  call void @path_feed_called()
  %ok = call i1 @path_feed_body(ptr %decoder, i8 %byte, ptr %scalar, ptr %complete)
  ret i1 %ok
}
define i1 @$component(ptr %bytes, i32 %start, i32 %count, ptr %kind, ptr %failure) {
  call void @path_component_called()
  %ok = call i1 @path_component_body(ptr %bytes, i32 %start, i32 %count, ptr %kind, ptr %failure)
  ret i1 %ok
}
define i32 @path_normalize(ptr %input, ptr %output, ptr %parents, ptr %failure) {
  %ok = call i1 @$normalize(ptr %input, ptr %output, ptr %parents, ptr %failure)
  %result = zext i1 %ok to i32
  ret i32 %result
}
define i32 @path_resolve(ptr %base, ptr %input, ptr %output, ptr %failure) {
  %ok = call i1 @$resolve(ptr %base, ptr %input, ptr %output, ptr %failure)
  %result = zext i1 %ok to i32
  ret i32 %result
}
"@
        [IO.File]::WriteAllText($stem+'-costs.ll',$costIr,(New-Object Text.UTF8Encoding($false)))
        $null=Invoke-PathCheck $selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',($stem+'-costs.ll'),'-x','c',(Join-Path $root 'std-lib/tests/path-bytes/costs.c'),'-std=c17','-Wall','-Wextra','-Werror','-x','none',(Join-Path $run 'observed-runtime.o'),$selection.unicodeRuntime.path,'-o',($stem+'-costs.exe'))
        $costs=Invoke-PathCheck ($stem+'-costs.exe') @()
        $costLines=@($costs.stdout.TrimEnd("`r","`n").Replace("`r`n","`n").Split("`n"))
        if($costLines.Count -ne 13 -or $costLines[-1] -notmatch '^PASS path costs assertions:[0-9]+$'){throw 'Unexpected path costs output'}
        $measurements+=[pscustomobject]@{stage=$index;actual=@($costLines[0..11] | ForEach-Object {$_ | ConvertFrom-Json})}
        $checks+=[pscustomobject]@{assertion="stage $index observed allocation/copy/peak/linear-visit budgets, every reached payload allocation failure, nonzero input bound, atomic output, roots/payload cleanup and four workers";passed=$true;output=$costLines[-1]}
        $control=Invoke-BoundedProcess ($stem+'-costs.exe') @('corrupt') $root 30
        $commands+=$control
        if($control.timedOut -or $control.exit -ne 1 -or $control.stderr -notmatch 'at\(output,prefix\+i\)==at\(input,i\)'){throw 'Corrupted output was not rejected by the exact byte comparator'}
        $checks+=[pscustomobject]@{assertion="stage $index corrupted normalized byte rejected by exact comparison";passed=$true}
        $hashes+=(Get-ArtifactIdentity ($stem+'.ll')).sha256
    }
    if($stages.Count -eq 2){
        if($hashes[0] -cne $hashes[1]){throw 'Stage LLVM differs'}
        $checks+=[pscustomobject]@{assertion='both stages byte-identical raw LLVM';passed=$true}
    }
    foreach($identity in $inputs){if((Get-ArtifactIdentity $identity.path).sha256 -cne $identity.sha256){throw "Input changed: $($identity.path)"}}
    $success=$true
} catch {$failure=$_.Exception.Message}
[pscustomobject]@{schema='ube-path-bytes-proof-1';success=$success;failure=$failure;developmentOnly=($DevelopmentDirectory -cne '');acceptedSelection=$selection;inputs=$inputs;checks=$checks;measurements=$measurements;commands=$commands;artifacts=@(Get-ChildItem $run -File | ForEach-Object {Get-ArtifactIdentity $_.FullName})} | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $run 'report.json') -Encoding UTF8
Write-Output ('Evidence: '+(Join-Path $run 'report.json'))
if(-not $success){throw $failure}
