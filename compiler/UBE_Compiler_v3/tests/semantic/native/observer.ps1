# Private native instrumentation only. Production runtime is never modified.
function New-FoundationObservedRuntime([string]$Repo,[string]$Run,$Selection){
 $source=Join-Path $Repo 'bootstrap/runtime/bootstrap_runtime.c';$runtime=[IO.File]::ReadAllText($source).Replace([string][char]13,'')
 $admission=@'
        if(__atomic_compare_exchange_n(&ube_root_registry.state,&current,current+1,0,
                __ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST))return 1;
'@
 $removal='(void)__atomic_fetch_sub(&ube_root_registry.state,UINT64_C(1),__ATOMIC_SEQ_CST);';$clear='__atomic_store_n(&ube_root_registry.state,UBE_ROOT_CLOSED,__ATOMIC_SEQ_CST);'
 foreach($site in @($admission,$removal,$clear)){if([regex]::Matches($runtime,[regex]::Escape($site)).Count -ne 1){throw 'Exact foundation root-counter mutation required'}}
 if([regex]::Matches($runtime,'__atomic_(?:compare_exchange_n|fetch_sub|store_n)\(&ube_root_registry\.state,').Count -ne 3){throw 'Root-counter mutation inventory changed'}
 $runtime=$runtime.Replace($admission,$admission.Replace('return 1;','{index_root_changed((size_t)((current+1)&UBE_ROOT_COUNT_MASK));return 1;}')).Replace($removal,'uint64_t index_previous=__atomic_fetch_sub(&ube_root_registry.state,UINT64_C(1),__ATOMIC_SEQ_CST); index_root_changed((size_t)((index_previous-1)&UBE_ROOT_COUNT_MASK));').Replace($clear,$clear+' index_root_changed(0);')
 $mutations=@([regex]::Matches($runtime,'(?m)^\s*ube_gc_live_bytes\s*(?:\+\+|--|<<=|>>=|[+*/%&|^-]=|=(?!=))[^;\r\n]*;')|ForEach-Object {$_.Value.Trim()});$expected=@('ube_gc_live_bytes += layout->size;','ube_gc_live_bytes += size;','ube_gc_live_bytes -= item->payload_size;','ube_gc_live_bytes -= item->payload_size;','ube_gc_live_bytes = 0;')
 if((($mutations|Sort-Object)-join "`n") -cne (($expected|Sort-Object)-join "`n")){throw 'GC live-byte mutation inventory changed'}
 if([regex]::Matches($runtime,'(?:\+\+|--)\s*ube_gc_live_bytes|(?<!&)&(?!&)\s*ube_gc_live_bytes').Count){throw 'GC live-byte counter address escape/prefix mutation changed'}
 foreach($site in @('ube_gc_live_bytes += layout->size;','ube_gc_live_bytes += size;')){if([regex]::Matches($runtime,[regex]::Escape($site)).Count -ne 1){throw 'Exact GC payload increment required'};$runtime=$runtime.Replace($site,$site+' name_heap_changed(ube_gc_live_bytes);')}
 $tail=@'

size_t index_root_count(void) { return ube_gc_root_count; }
size_t index_root_limit(void) { return UBE_GC_MAX_ROOTS; }
size_t index_array_header(void) { return sizeof(struct ube_array); }
size_t index_gc_header(void) { return sizeof(struct ube_gc_header); }
int32_t shared_is_live(void* value) { ube_gc_enter_lock(); int32_t alive=ube_gc_header_from_value(value)!=NULL; ube_gc_leave_lock(); return alive; }
'@
 $runtime="#include <stddef.h>`nvoid index_root_changed(size_t);`nvoid name_heap_changed(size_t);`n"+$runtime+$tail
 $directory=Join-Path $Run 'observer';$null=New-Item -ItemType Directory -Path $directory -Force;$generated=Join-Path $directory 'runtime-observed.c';$ir=Join-Path $directory 'runtime-observed.ll';$object=Join-Path $directory 'runtime-observed.o';[IO.File]::WriteAllText($generated,$runtime,(New-Object Text.UTF8Encoding($false)))
 $compile=Invoke-BoundedProcess $Selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-I',(Join-Path $Repo 'bootstrap/runtime'),'-include',(Join-Path $Repo 'std-lib/tests/managed-storage/copy-probe.h'),'-S','-emit-llvm',$generated,'-o',$ir) $Repo 90
 if($compile.timedOut -or $compile.exit -ne 0){throw "Foundation observer compile failed: $($compile.stderr)"}
 $link=Invoke-BoundedProcess $Selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-x','ir',$ir,'-c','-o',$object) $Repo 90;if($link.timedOut -or $link.exit -ne 0){throw "Foundation observer object failed: $($link.stderr)"}
 return [pscustomobject]@{source=(Get-ArtifactIdentity $source);generated=(Get-ArtifactIdentity $generated);ir=(Get-ArtifactIdentity $ir);object=(Get-ArtifactIdentity $object);rootMutationSites=3;heapMutationInventory=$mutations;increasingHeapSites=2;commands=@($compile,$link);limits='All exact root-count mutations and both actual GC payload increments observed; callbacks are scalar/TLS-only. Safe allocation-hash getter is used outside callbacks to avoid UAF in lifetime controls.'}
}
