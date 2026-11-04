param([string]$SelectionPath=(Join-Path $PSScriptRoot '../../bootstrap/out/v2/current.json'),
      [switch]$NativeOnly,
      [string]$Clang='C:\Program Files\LLVM\bin\clang.exe')
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
. (Join-Path $root 'bootstrap/tools/verification.ps1')
$run=Join-Path $root ('bootstrap/out/file-output/'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run)
$paths=@('bootstrap/runtime/bootstrap_runtime.c','bootstrap/runtime/error_support.c',
    'bootstrap/runtime/value_storage.h','bootstrap/runtime/windows/file_primitives.c',
    'bootstrap/runtime/windows/file_output.c','bootstrap/runtime/windows/thread_primitives.c',
    'std-lib/FILE-OUTPUT-CONTRACT.md','std-lib/src/portable/FileBytes.bas',
    'std-lib/tests/file-output/native.c','std-lib/tests/file-output/wrappers.bas','bootstrap/tools/verification.ps1')
$inputs=@($paths | ForEach-Object {Get-ArtifactIdentity (Join-Path $root $_)})
$inputs+=Get-ArtifactIdentity $PSCommandPath
$commands=[Collections.Generic.List[object]]::new(); $checks=@(); $selection=$null
$success=$false; $failure=$null
function Run([string]$File,[string[]]$Arguments,[string]$Directory,[int]$Expected=0) {
    $record=Invoke-BoundedProcess $File $Arguments $Directory 90
    $commands.Add($record)
    if($record.timedOut -or $record.exit -ne $Expected) {throw ('Unexpected output test result: '+($record|ConvertTo-Json -Compress -Depth 5))}
    return $record
}
try {
    if(-not $NativeOnly) {
        $selection=Get-VerifiedBootstrapSelection $SelectionPath
        $Clang=$selection.clang.path
        $inputs+=@($selection.manifest,$selection.compiler,$selection.runtime,$selection.unicodeRuntime)
        $inputs+=Get-ArtifactIdentity $SelectionPath
    }
    $inputs+=Get-ArtifactIdentity $Clang
    $controlFailures=@{
        OMIT_WRITE_CONTROL='contents(L"exact.bin",expected,65536)'
        CHANGED_BYTE_CONTROL='contents(L"exact.bin",expected,65536)'
        WRONG_COUNT_CONTROL='clean_cost() && writes==1 && count==65536 && failure==0 && ube_err_number()==77'
        IGNORE_FAILURE_CONTROL='!ube_file_try_write(token,&source,0,4,&count,&failure) && count==0 && failure==15 && ube_err_number()==57'
        LOST_OWNER_CONTROL='ube_file_try_close(&token,&failure) && token==0 && ube_file_test_open_handles()==0'
    }
    foreach($variant in @('normal','OMIT_WRITE_CONTROL','WRONG_COUNT_CONTROL','CHANGED_BYTE_CONTROL','IGNORE_FAILURE_CONTROL','LOST_OWNER_CONTROL')) {
        $directory=Join-Path $run $variant; $null=[IO.Directory]::CreateDirectory($directory)
        $exe=Join-Path $directory 'probe.exe'
        $flags=@(if($variant -ne 'normal') {"-D$variant"})
        $null=Run $Clang (@('--no-default-config','--target=x86_64-w64-windows-gnu','-std=c17','-O2',
            '-Wall','-Wextra','-Werror')+$flags+@((Join-Path $root 'std-lib/tests/file-output/native.c'),'-o',$exe)) $root
        $expected=if($variant -eq 'normal') {0} else {1}
        $record=Run $exe @() $directory $expected
        if($expected -eq 0) {
            if($record.stderr -cne '' -or $record.stdout -notmatch '^PASS counted file output [1-9][0-9]* assertions\n$') {throw 'Missing complete native oracle output'}
        } elseif($record.stdout -cne '' -or $record.stderr -notmatch ('^output oracle line [0-9]+: '+[regex]::Escape($controlFailures[$variant])+"`n$")) {throw 'Mutation did not fail its intended independent assertion'}
        $checks += [pscustomobject]@{assertion="native ${variant}: exact process disposition and byte/status/resource oracle";passed=$true;output=$record.stdout;error=$record.stderr}
    }
    if(-not $NativeOnly) {
        $stages=@((Join-Path (Split-Path $selection.compiler.path -Parent) 'ube-stage1-v2.exe'),$selection.compiler.path)
        $inputs+=@($stages|ForEach-Object {Get-ArtifactIdentity $_})
        $library=[IO.File]::ReadAllText((Join-Path $root 'std-lib/src/portable/FileBytes.bas')).Replace("`r`n","`n")
        $prefix="UBE SOURCE 1 MODULE`nAttribute UBE_Name = ""FileBytes""`n"
        if(-not $library.StartsWith($prefix,[StringComparison]::Ordinal)) {throw 'Unexpected FileBytes source envelope'}
        $body=$library.Substring($prefix.Length)+"`n"+[IO.File]::ReadAllText((Join-Path $root 'std-lib/tests/file-output/wrappers.bas'))
        $source=Join-Path $run 'output.bas'
        [IO.File]::WriteAllText($source,$body,[Text.UTF8Encoding]::new($false))
        $ordinals=@{}; $ordinal=0
        foreach($match in [regex]::Matches($body,'(?m)^(?:Intrinsic )?Function ([A-Za-z_][A-Za-z_0-9]*)')) {
            $ordinals[$match.Groups[1].Value]=$ordinal; ++$ordinal
        }
        $priorHash=''
        for($stage=0;$stage -lt 2;++$stage) {
            $directory=Join-Path $run ('stage'+($stage+1)); $null=[IO.Directory]::CreateDirectory($directory)
            $raw=Join-Path $directory 'raw.ll'
            $emission=Run $stages[$stage] @($source,$raw) $root
            if($emission.stdout -cne '' -or $emission.stderr -cne '') {throw 'Unexpected output binding diagnostics'}
            $identity=Get-ArtifactIdentity $raw
            if($priorHash -and $identity.sha256 -cne $priorHash) {throw 'Output binding raw LLVM differs across stages'}
            $priorHash=$identity.sha256
            $text=[IO.File]::ReadAllText($raw)
            foreach($call in @('call i32 @ube_file_try_write(i32','call i32 @ube_file_try_flush(i32')) {
                if([regex]::Matches($text,[regex]::Escape($call)).Count -ne 1) {throw "Missing unique production binding call: $call"}
            }
            $text=$text.Replace('define i32 @main(','define i32 @output_unused_main(')
            $write='ube.p'+$ordinals['OutputWrite']; $flush='ube.p'+$ordinals['OutputFlush']
            $text+="`ndefine i32 @output_bridge_write(i32 %token, ptr %bytes, i32 %start, i32 %count, ptr %written, ptr %failure) {`n %ok = call i1 @$write(i32 %token, ptr %bytes, i32 %start, i32 %count, ptr %written, ptr %failure)`n %result = zext i1 %ok to i32`n ret i32 %result`n}`n"
            $text+="define i32 @output_bridge_flush(i32 %token, ptr %failure) {`n %ok = call i1 @$flush(i32 %token, ptr %failure)`n %result = zext i1 %ok to i32`n ret i32 %result`n}`n"
            $adapted=Join-Path $directory 'adapter.ll'; [IO.File]::WriteAllText($adapted,$text,[Text.UTF8Encoding]::new($false))
            $exe=Join-Path $directory 'probe.exe'
            $null=Run $Clang @('--no-default-config','--target=x86_64-w64-windows-gnu','-O2',
                '-Wall','-Wextra','-Werror','-DUBE_OUTPUT_WRAPPERS',$adapted,
                (Join-Path $root 'std-lib/tests/file-output/native.c'),'-o',$exe) $root
            $record=Run $exe @() $directory
            if($record.stderr -cne '' -or $record.stdout -notmatch '^PASS counted file output [1-9][0-9]* assertions\n$') {throw 'Missing complete UBE output oracle'}
            $checks+=[pscustomobject]@{assertion="stage $($stage+1): actual FileBytes declarations and UBE call forwarding pass complete independent native oracle";passed=$true;output=$record.stdout;raw=$identity}
        }
        $checks+=[pscustomobject]@{assertion='Both source-built stages emit byte-identical raw LLVM for actual FileBytes and consumer';passed=$true}
        $writeHeader='Intrinsic Function DifferentSpelling(ByVal Token As Long, ByRef Bytes() As Byte, ByVal Start As Long, ByVal Count As Long, ByRef Written As Long, ByRef Failure As Long) As Boolean'
        $flushHeader='Intrinsic Function DifferentSpelling(ByVal Token As Long, ByRef Failure As Long) As Boolean'
        $cases=@(
            @('renamed-write',$writeHeader,'File.TryWrite',0,''),
            @('renamed-flush',$flushHeader,'fIlE.tRyFlUsH',0,''),
            @('write-byte-type',$writeHeader.Replace('As Byte','As Long'),'File.TryWrite',1,'UBE3232'),
            @('write-count-mode',$writeHeader.Replace('ByVal Count','ByRef Count'),'File.TryWrite',1,'UBE3232'),
            @('write-output-mode',$writeHeader.Replace('ByRef Written','ByVal Written'),'File.TryWrite',1,'UBE3232'),
            @('write-result',$writeHeader.Replace('As Boolean','As Long'),'File.TryWrite',1,'UBE3232'),
            @('flush-token-mode',$flushHeader.Replace('ByVal Token','ByRef Token'),'File.TryFlush',1,'UBE3232'),
            @('flush-failure-type',$flushHeader.Replace('Failure As Long','Failure As Integer'),'File.TryFlush',1,'UBE3232'),
            @('unknown-role',$writeHeader,'File.WriteUnreviewed',1,'UBE3230'),
            @('name-without-binding',$writeHeader.Replace('DifferentSpelling','TryWriteByteFile'),'',1,'UBE3232')
        )
        foreach($case in $cases) {
            $fixture=Join-Path $run ($case[0]+'.bas')
            $binding=if($case[2]) {'Attribute DifferentSpelling.UBE_Primitive = "'+$case[2]+'"'+"`n"} else {''}
            [IO.File]::WriteAllText($fixture,$case[1]+"`n"+$binding+"End Function`nFunction Main() As Long`nMain = 0`nEnd Function`n",[Text.UTF8Encoding]::new($false))
            for($stage=0;$stage -lt 2;++$stage) {
                $ir=Join-Path $run ($case[0]+'-'+$stage+'.ll')
                $record=Run $stages[$stage] @($fixture,$ir) $root $case[3]
                if($case[3] -eq 0) {
                    if(-not [IO.File]::Exists($ir) -or $record.stdout -cne '' -or $record.stderr -cne '') {throw 'Valid renamed binding failed'}
                } elseif([IO.File]::Exists($ir) -or ($record.stdout+$record.stderr) -notmatch $case[4]) {throw 'Binding rejection did not match independent expectation'}
            }
            $checks+=[pscustomobject]@{assertion="both stages: $($case[0]) declaration role/signature result and output disposition";passed=$true}
        }
        $null=Get-VerifiedBootstrapSelection $SelectionPath
    }
    foreach($input in $inputs) {if((Get-ArtifactIdentity $input.path).sha256 -cne $input.sha256) {throw "Changed output proof input: $($input.path)"}}
    $success=$true
} catch {$failure=$_.Exception.Message}
finally {
    $path=Join-Path $run 'report.json'
    [pscustomobject]@{success=$success;failure=$failure;nativeOnly=$NativeOnly.IsPresent;acceptedSelection=$selection;
        inputs=$inputs;checks=$checks;commands=$commands.ToArray();
        artifacts=@(Get-ChildItem -LiteralPath $run -Recurse -File | ForEach-Object {Get-ArtifactIdentity $_.FullName});
        scope='Counted writable-file token operations only; test-only producer, no guarded native-build path or executable publication proof'} |
        ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Output "Evidence: $path"
}
if(-not $success) {throw $failure}
Write-Output "PASS counted file output: $($checks.Count) grouped assertions"
