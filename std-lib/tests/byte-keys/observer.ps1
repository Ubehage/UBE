# Test-only instrumentation. Production runtime sources are never modified.
function Assert-StorageObserverSource([string]$Text) {
    $heap = @([regex]::Matches($Text,'\bube_gc_live_bytes\s*(?:\+\+|--|<<=|>>=|[+*/%&|^-]=|=(?!=))[^;\r\n]*;') | ForEach-Object { $_.Value.Trim() })
    $expected = @('ube_gc_live_bytes += layout->size;','ube_gc_live_bytes += size;','ube_gc_live_bytes -= item->payload_size;','ube_gc_live_bytes -= item->payload_size;','ube_gc_live_bytes = 0;')
    if ((($heap | Sort-Object) -join "`n") -cne (($expected | Sort-Object) -join "`n")) { throw 'Heap mutation inventory changed' }
    if ([regex]::IsMatch($Text,'(?:\+\+|--)\s*ube_gc_live_bytes|(?<!&)&(?!&)\s*ube_gc_live_bytes')) { throw 'Heap counter prefix mutation/address escape' }
    $sites = @(
        ('if(__atomic_compare_exchange_n(&ube_root_registry.state,&current,current+1,0,'+"`n"+'                __ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST))return 1;'),
        '(void)__atomic_fetch_sub(&ube_root_registry.state,UINT64_C(1),__ATOMIC_SEQ_CST);',
        '(void)__atomic_fetch_or(&ube_root_registry.state,UBE_ROOT_CLOSED,__ATOMIC_SEQ_CST);',
        '__atomic_store_n(&ube_root_registry.state,UBE_ROOT_CLOSED,__ATOMIC_SEQ_CST);')
    foreach ($site in $sites) { if ([regex]::Matches($Text,[regex]::Escape($site)).Count -ne 1) { throw 'Root mutation site changed' } }
    if ([regex]::Matches($Text,'ube_root_registry\.state').Count -ne 7) { throw 'Root state access inventory changed' }
    foreach ($spec in @(@('load_n',3),@('compare_exchange_n',1),@('fetch_sub',1),@('fetch_or',1),@('store_n',1))) {
        if ([regex]::Matches($Text,'__atomic_'+$spec[0]+'\(&ube_root_registry\.state\b').Count -ne $spec[1]) { throw 'Root atomic access inventory changed' }
    }
    foreach ($definition in @('#define UBE_ROOT_CLOSED (UINT64_C(1)<<63)','#define UBE_ROOT_COUNT_MASK (UBE_ROOT_CLOSED-1u)','#define ube_gc_root_count ((size_t)(__atomic_load_n(&ube_root_registry.state,__ATOMIC_SEQ_CST)&UBE_ROOT_COUNT_MASK))')) {
        if ([regex]::Matches($Text,[regex]::Escape($definition)).Count -ne 1) { throw 'Root mask definition changed' }
    }
    return $sites
}

function Test-StorageObserverControls([string]$Text, [object[]]$Sites) {
    $controls=@()
    # Every mutation class is covered, including subtraction/reset and flag-only closure.
    $mutations=@(@('heap-increment','ube_gc_live_bytes += size;','ube_gc_live_bytes += size + 1;'),@('heap-subtraction','ube_gc_live_bytes -= item->payload_size;','ube_gc_live_bytes += item->payload_size;'),@('heap-reset','ube_gc_live_bytes = 0;','ube_gc_live_bytes = 1;'),@('heap-address','static size_t ube_gc_live_bytes;','static size_t ube_gc_live_bytes; void* escaped = &ube_gc_live_bytes;'),@('root-reserve','current+1,0,','current+2,0,'),@('root-removal',$Sites[1],$Sites[1].Replace('UINT64_C(1)','UINT64_C(2)')),@('root-close',$Sites[2],$Sites[2].Replace('UBE_ROOT_CLOSED','UINT64_C(1)')),@('root-reset',$Sites[3],$Sites[3].Replace('UBE_ROOT_CLOSED','UINT64_C(1)')),@('root-extra-access','static size_t ube_gc_live_bytes;','static size_t ube_gc_live_bytes; /* ube_root_registry.state */'))
    foreach($mutation in $mutations) {
        if (-not $Text.Contains($mutation[1])) { throw "Absent observer control target $($mutation[0])" }
        $rejected=$false
        try { $null=Assert-StorageObserverSource ($Text.Replace($mutation[1],$mutation[2])) } catch { $rejected=$true }
        $controls+= [pscustomobject]@{assertion=$mutation[0];passed=$rejected}
        if(-not $rejected) { throw "Observer audit accepted corruption $($mutation[0])" }
    }
    return $controls
}

function New-StorageObservedRuntime([string]$Root, $Selection, [string]$Directory) {
    $null=New-Item -ItemType Directory -Path $Directory -Force
    $success=$false; $failure=$null; $commands=@(); $inputs=@(); $controls=@(); $object=$null; $sites=@()
    $report=Join-Path $Directory 'report.json'
    try {
        $runtime=Join-Path $Root 'bootstrap/runtime/bootstrap_runtime.c'
        foreach($path in @($runtime,(Join-Path $Root 'bootstrap/runtime/value_storage.h'),(Join-Path $Root 'std-lib/tests/managed-storage/copy-probe.h'),(Join-Path $Root 'std-lib/tests/byte-storage/allocation-probe.h'),(Join-Path $Root 'std-lib/tests/byte-keys/observer.ps1'))) { $inputs+=Get-ArtifactIdentity $path }
        $text=[IO.File]::ReadAllText($runtime).Replace([string][char]13,'')
        $sites=@(Assert-StorageObserverSource $text)
        $controls=@(Test-StorageObserverControls $text $sites)
        $observed="#include <stddef.h>`nvoid storage_root_changed(size_t);`nvoid storage_heap_changed(size_t);`n"+$text
        $observed=$observed.Replace($sites[0],$sites[0].Replace('return 1;','{storage_root_changed((size_t)((current+1)&UBE_ROOT_COUNT_MASK));return 1;}'))
        $observed=$observed.Replace($sites[1],'{uint64_t previous=__atomic_fetch_sub(&ube_root_registry.state,UINT64_C(1),__ATOMIC_SEQ_CST);storage_root_changed((size_t)((previous-1)&UBE_ROOT_COUNT_MASK));}')
        $observed=$observed.Replace($sites[3],$sites[3]+' storage_root_changed(0);')
        foreach($site in @('ube_gc_live_bytes += layout->size;','ube_gc_live_bytes += size;')) { $observed=$observed.Replace($site,$site+' storage_heap_changed(ube_gc_live_bytes);') }
        $observed+="`nsize_t storage_root_count(void){return ube_gc_root_count;}`nsize_t storage_root_limit(void){return UBE_GC_MAX_ROOTS;}`nsize_t storage_array_header(void){return sizeof(struct ube_array);}`nsize_t storage_gc_header(void){return sizeof(struct ube_gc_header);}`n"
        $source=Join-Path $Directory 'runtime-observed.c';$ir=Join-Path $Directory 'runtime-observed.ll';$objectPath=Join-Path $Directory 'runtime-observed.o'
        [IO.File]::WriteAllText($source,$observed,(New-Object Text.UTF8Encoding($false)))
        $compile=Invoke-BoundedProcess $Selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-I',(Join-Path $Root 'bootstrap/runtime'),'-include',(Join-Path $Root 'std-lib/tests/managed-storage/copy-probe.h'),'-S','-emit-llvm',$source,'-o',$ir) $Root 90
        $commands+=@($compile);if($compile.timedOut -or $compile.exit -ne 0){throw "Observed runtime emission failed: $($compile.stderr)"}
        $compile=Invoke-BoundedProcess $Selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-c','-x','ir',$ir,'-o',$objectPath) $Root 90
        $commands+=@($compile);if($compile.timedOut -or $compile.exit -ne 0){throw "Observed runtime assembly failed: $($compile.stderr)"}
        foreach($id in $inputs){if((Get-ArtifactIdentity $id.path).sha256 -cne $id.sha256){throw 'Observer input changed'}}
        $object=Get-ArtifactIdentity $objectPath;$success=$true
    } catch { $failure=$_.Exception.Message }
    finally {
        [pscustomobject]@{success=$success;failure=$failure;inputs=$inputs;checks=$controls;commands=$commands;object=$object;heapMutationSites=5;heapIncreasingSites=2;rootAtomicAccesses=7;rootCountMutationSites=3;artifacts=@(Get-ChildItem -LiteralPath $Directory -File|ForEach-Object{Get-ArtifactIdentity $_.FullName});limits='Private transformed runtime only. Complete heap/root mutation inventory; callbacks at both heap increments and all three root count changes. Root fetch_or sets the closed flag and cannot change masked count. Probe callbacks use only TLS scalar counters; no allocator, managed root, or runtime calls.'}|ConvertTo-Json -Depth 25|Set-Content -LiteralPath $report -Encoding UTF8
    }
    if(-not $success){throw $failure}
    return [pscustomobject]@{object=$object;report=(Get-ArtifactIdentity $report);inputs=$inputs;checks=$controls;commands=$commands}
}
